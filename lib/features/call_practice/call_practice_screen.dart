import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/ai_call_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/realistic_voice_service.dart';
import '../../core/services/sound_effect_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/i_feel_worried_button.dart';

enum CallState { incoming, active }

class CallPracticeScreen extends ConsumerStatefulWidget {
  final Scenario? scenario;
  final bool startActive;

  const CallPracticeScreen({
    super.key,
    this.scenario,
    this.startActive = false,
  });

  @override
  ConsumerState<CallPracticeScreen> createState() => _CallPracticeScreenState();
}

class _CallPracticeScreenState extends ConsumerState<CallPracticeScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  late CallState _currentState;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _recognizedText = '';
  int _secondsElapsed = 0;
  Timer? _callTimer;
  Timer? _silenceDebounceTimer;
  Timer? _autoListenInitTimer;
  Timer? _rearmTimer;
  bool _isProcessingSpeech = false;

  // Dynamic notification artifact state (driven by backend AI)
  bool _artifactDismissed = false;

  late AnimationController _pulseController;
  RealisticVoiceService? _voiceService;
  SoundEffectService? _soundService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(realisticVoiceProvider);
    _soundService = ref.read(soundEffectServiceProvider);
    _currentState = widget.startActive ? CallState.active : CallState.incoming;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (_currentState == CallState.incoming) {
      _pulseController.repeat();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentState == CallState.incoming) {
          _soundService?.playCallRingtone();
        }
      });
    }

    _initSpeech();

    if (_currentState == CallState.active) {
      _startCallTimer();
      _connectAiCall();
      _autoListenInitTimer?.cancel();
      _autoListenInitTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _currentState == CallState.active && !ref.read(aiCallProvider).isSpeaking && !_isListening) {
          _startListening();
        }
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) {
          debugPrint('[STT Error] $val');
          if (mounted && _currentState == CallState.active && !_isProcessingSpeech) {
            final aiState = ref.read(aiCallProvider);
            if (!aiState.isSpeaking && !aiState.isThinking) {
              _rearmTimer?.cancel();
              _rearmTimer = Timer(const Duration(milliseconds: 300), () {
                if (mounted && _currentState == CallState.active && !_isListening && !_isProcessingSpeech) {
                  _startListening();
                }
              });
            }
          }
        },
        onStatus: (status) {
          debugPrint('[STT Status] $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              final textToSend = _recognizedText.trim();
              if (textToSend.isNotEmpty && !_isProcessingSpeech) {
                _finalizeAndSend(textToSend);
              } else if (_currentState == CallState.active && !_isProcessingSpeech) {
                // Auto re-arm so mic NEVER dies while user is thinking or waiting
                final aiState = ref.read(aiCallProvider);
                if (!aiState.isSpeaking && !aiState.isThinking) {
                  _rearmTimer?.cancel();
                  _rearmTimer = Timer(const Duration(milliseconds: 250), () {
                    if (mounted && _currentState == CallState.active && !_isListening && !_isProcessingSpeech) {
                      _startListening();
                    }
                  });
                }
              }
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[STT Init Exception] $e');
      _speechEnabled = false;
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _connectAiCall() {
    final persona = widget.scenario?.persona ?? 'a scammer attempting fraud';
    final initialMessage = widget.scenario?.initialMessage ?? 'Hello. Please respond urgently.';
    final lang = ref.read(preferencesProvider).appLanguage;
    final scenarioId = widget.scenario?.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(aiCallProvider.notifier).connect(
          persona,
          initialMessage,
          lang: lang,
          scenarioId: scenarioId,
        );
      }
    });
  }

  void _acceptCall() {
    _soundService?.stopCallRingtone();
    _pulseController.stop();
    setState(() => _currentState = CallState.active);
    _startCallTimer();
    _connectAiCall();
    _autoListenInitTimer?.cancel();
    _autoListenInitTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _currentState == CallState.active && !ref.read(aiCallProvider).isSpeaking && !_isListening) {
        _startListening();
      }
    });
  }

  void _declineCall() {
    _soundService?.stopCallRingtone();
    _callTimer?.cancel();
    _silenceDebounceTimer?.cancel();
    _autoListenInitTimer?.cancel();
    _rearmTimer?.cancel();
    _isProcessingSpeech = true;
    if (_speechToText.isListening) {
      _speechToText.cancel();
    }
    ref.read(aiCallProvider.notifier).endCall();

    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Suspicious Voice Call',
      channel: 'call',
      status: 'deflected',
    );

    final debriefText = widget.scenario?.debriefSuccess ??
        'Great job! You hung up on the suspicious call. Never entertain unverified callers asking for money or secret OTPs.';
    context.replace('/debrief', extra: {
      'outcome': 'success:hung_up',
      'message': debriefText,
      'scenario_id': widget.scenario?.id,
      'scenario_title': widget.scenario?.title,
    });
  }

  // ── Hands-Free Continuous Auto-Listening with Dynamic Silence Debounce ────
  void _startListening() async {
    final aiState = ref.read(aiCallProvider);
    if (_currentState != CallState.active || aiState.isSpeaking || aiState.isThinking || _isProcessingSpeech) {
      return;
    }

    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_speechEnabled && mounted) {
      setState(() {
        _isListening = true;
      });

      try {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted && !_isProcessingSpeech) {
              setState(() {
                _recognizedText = result.recognizedWords;
              });

              // Reset silence debounce timer: 1.5s after speaking ceases -> auto-submit!
              _silenceDebounceTimer?.cancel();
              _silenceDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
                if (mounted && _recognizedText.trim().isNotEmpty && !_isProcessingSpeech) {
                  _finalizeAndSend(_recognizedText.trim());
                }
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            pauseFor: const Duration(milliseconds: 1800),
            cancelOnError: false,
            partialResults: true,
          ),
        );
      } catch (e) {
        debugPrint('[STT Listen Exception] $e');
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  void _finalizeAndSend(String text) async {
    _silenceDebounceTimer?.cancel();
    _isProcessingSpeech = true;
    setState(() {
      _isListening = false;
    });
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    _handleUserSpeechOrText(text);
  }

  void _toggleListening() async {
    ref.read(aiCallProvider.notifier).stopTts();

    if (_isListening) {
      _silenceDebounceTimer?.cancel();
      final textToSend = _recognizedText.trim();
      if (textToSend.isNotEmpty) {
        _finalizeAndSend(textToSend);
      } else {
        setState(() => _isListening = false);
        try {
          if (_speechToText.isListening) {
            await _speechToText.stop();
          }
        } catch (_) {}
      }
      return;
    }

    _isProcessingSpeech = false;
    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_speechEnabled) {
      _startListening();
    } else {
      _showVoiceChoiceSheet();
    }
  }

  void _cancelListening() async {
    _silenceDebounceTimer?.cancel();
    setState(() {
      _isListening = false;
      _recognizedText = '';
    });
    try {
      await _speechToText.stop();
    } catch (_) {}
  }

  // ── Scammer Trap Evaluation (Detects OTP Sharing or Phishing Link Clicks) ──
  void _handleUserSpeechOrText(String text) {
    final clean = text.replaceAll('“', '').replaceAll('”', '').replaceAll('"', '').trim();
    final lower = clean.toLowerCase();

    // Check if the user complied with the scammer by sharing OTP, link, or trap phrases
    final sharedOtp = lower.contains('482910') ||
        (lower.contains('otp') && (lower.contains('hai') || lower.contains('is') || lower.contains('le lo') || lower.contains('ye') || lower.contains('mera otp')));
    final clickedPhishing = lower.contains('clicked link') || lower.contains('paid') || lower.contains('payment done');

    if (sharedOtp || clickedPhishing) {
      _triggerScamCompromisedTrap(
        sharedOtp
            ? 'You shared your secret verification code with the caller!'
            : 'You agreed to pay / clicked the fraudulent link!',
      );
      return;
    }

    // Forward legitimate response to AI
    ref.read(aiCallProvider.notifier).sendVoiceMessage(clean);
    if (mounted) {
      setState(() {
        _recognizedText = '';
      });
    }
  }

  void _triggerScamCompromisedTrap(String trapReason) {
    _soundService?.stopCallRingtone();
    _callTimer?.cancel();
    _silenceDebounceTimer?.cancel();
    _autoListenInitTimer?.cancel();
    _rearmTimer?.cancel();
    _isProcessingSpeech = true;
    if (_speechToText.isListening) {
      _speechToText.cancel();
    }
    ref.read(aiCallProvider.notifier).endCall();

    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Suspicious Voice Call',
      channel: 'call',
      status: 'compromised',
    );

    final lang = ref.read(preferencesProvider).appLanguage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A), size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'hi' ? '🚨 चेतावनी: आप ठगे गए!' : (lang == 'mr' ? '🚨 सावध: फसवणूक झाली!' : '🚨 SCAMMED! Trap Triggered!'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFBA1A1A),
                    ),
                  ),
                  Text(
                    lang == 'hi' ? 'गोपनीय जानकारी साझा हो गई' : 'Sensitive information was compromised',
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Text(
                lang == 'hi'
                    ? '⚠️ $trapReason\n\nअसल जीवन में आपके खाते से पैसे तुरंत कट जाते! बैंक या पुलिस कभी भी फोन पर ओटीपी नहीं मांगते।'
                    : '⚠️ $trapReason\n\nIn real life, money would have been stolen from your account immediately! Real authorities never ask for OTPs or wire transfers over phone.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35, color: Color(0xFF900000)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              lang == 'hi'
                  ? 'आइए अब देखें कि इस स्कैम में असली ठग कैसे दिमाग से खेलते हैं और सुरक्षा के सही नियम क्या हैं!'
                  : 'Now review the full educational debrief to understand the psychological tricks used by scammers and what to do next!',
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.replace('/debrief', extra: {
                  'outcome': 'failure:compromised',
                  'message': trapReason,
                  'scenario_id': widget.scenario?.id,
                  'scenario_title': widget.scenario?.title,
                });
              },
              icon: const Icon(Icons.school_outlined, size: 22),
              label: Text(
                lang == 'hi' ? '🚨 डिब्रीफ देखें (Emergency Checklist)' : '🚨 Open Debrief (Emergency Checklist)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceChoiceSheet() {
    final lang = ref.read(preferencesProvider).appLanguage;
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryFixedDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.record_voice_over, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang == 'hi' ? 'बोलकर या चुनकर जवाब दें' : 'Speak or Choose Response',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildVoiceOption('Who is your superior officer? Give badge number.', 'आपके वरिष्ठ अधिकारी कौन हैं? बैच नंबर बताइए।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('I will visit the local police station myself.', 'मैं खुद थाने जाकर पता करूँगा।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('I never share OTP or bank details on phone.', 'मैं फोन पर कभी भी ओटीपी या बैंक विवरण नहीं देता।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('My OTP is 482910.', 'मेरा ओटीपी 482910 है।', ctx, isTrap: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: lang == 'hi' ? 'या अपना जवाब यहाँ टाइप करें...' : 'Or type custom reply...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primaryContainer),
                  onPressed: () {
                    final t = textController.text.trim();
                    if (t.isNotEmpty) {
                      Navigator.pop(ctx);
                      _handleUserSpeechOrText(t);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceOption(String enText, String hiText, BuildContext ctx, {bool isTrap = false}) {
    final lang = ref.read(preferencesProvider).appLanguage;
    final text = lang == 'hi' ? hiText : enText;

    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _handleUserSpeechOrText(text);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isTrap ? const Color(0xFFFFF0F0) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isTrap ? const Color(0xFFFFCDD2) : const Color(0xFFD3E3FD)),
        ),
        child: Row(
          children: [
            Icon(
              isTrap ? Icons.warning_rounded : Icons.record_voice_over_rounded,
              color: isTrap ? Colors.red : AppTheme.primaryContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isTrap ? const Color(0xFFB71C1C) : Colors.black87,
                ),
              ),
            ),
            Icon(Icons.send_rounded, size: 16, color: isTrap ? Colors.red : AppTheme.primaryContainer),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _autoListenInitTimer?.cancel();
    _rearmTimer?.cancel();
    _soundService?.stopCallRingtone();
    _callTimer?.cancel();
    _silenceDebounceTimer?.cancel();
    _isProcessingSpeech = true;
    try {
      _speechToText.cancel();
    } catch (_) {}
    _pulseController.dispose();
    _voiceService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiCallState>(aiCallProvider, (previous, next) {
      if (next.status == 'compromised' || next.status == 'deflected') {
        _soundService?.stopCallRingtone();
        _callTimer?.cancel();
        _silenceDebounceTimer?.cancel();
        _autoListenInitTimer?.cancel();
        _rearmTimer?.cancel();
        _isProcessingSpeech = true;
        if (_speechToText.isListening) {
          _speechToText.cancel();
        }
        ref.read(aiCallProvider.notifier).endCall();

        SimulationResult.recordResult(
          scenarioTitle: widget.scenario?.title ?? 'Suspicious Voice Call',
          channel: 'call',
          status: next.status,
        );

        final isSuccess = next.status == 'deflected';
        final outcome = isSuccess ? 'success:deflected' : 'failure:compromised';
        final message = next.evaluation ??
            (isSuccess
                ? (widget.scenario?.debriefSuccess ?? 'Great job defending against the scammer!')
                : (widget.scenario?.debriefFailure ?? 'You complied with the scammer. Watch out for urgent demands.'));

        context.replace('/debrief', extra: {
          'outcome': outcome,
          'message': message,
          'scenario_id': widget.scenario?.id,
          'scenario_title': widget.scenario?.title,
        });
        return;
      }

      // Dynamic artifact un-dismissal: when a new artifact arrives from the AI, ensure banner shows
      if (next.artifact != null && (previous?.artifact != next.artifact || _artifactDismissed)) {
        setState(() {
          _artifactDismissed = false;
        });
      }

      // Hands-Free Auto-Listening: When scammer finishes speaking or thinking, resume mic!
      if (previous?.isSpeaking == true && next.isSpeaking == false && _currentState == CallState.active && next.status == 'ongoing') {
        _isProcessingSpeech = false;
        if (!_isListening) {
          _startListening();
        }
      } else if (previous?.isThinking == true && next.isThinking == false && next.isSpeaking == false && _currentState == CallState.active && next.status == 'ongoing') {
        _isProcessingSpeech = false;
        if (!_isListening) {
          _startListening();
        }
      }

      if (next.isSpeaking == true) {
        _silenceDebounceTimer?.cancel();
        if (_isListening) {
          _speechToText.stop();
          setState(() => _isListening = false);
        }
      }
    });

    final callerTitle = widget.scenario?.scammerName ?? widget.scenario?.title ?? 'Inspector Patil';
    final lang = ref.watch(preferencesProvider).appLanguage;
    final aiState = ref.watch(aiCallProvider);
    final dynamicArtifact = aiState.artifact;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Active Simulation Drill',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tertiaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.call, color: AppTheme.tertiary, size: 16),
                SizedBox(width: 4),
                Text(
                  '1930',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Pinned bottom actions so Hang Up and I Feel Worried are NEVER scrolled out of view!
      bottomNavigationBar: _currentState == CallState.active
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    const Expanded(
                      child: IFeelWorriedButton(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _declineCall,
                        icon: const Icon(Icons.call_end, size: 20),
                        label: const Text(
                          '🛑 Hang Up\nफोन काटें',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.1),
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: AppTheme.tertiary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Practice Ribbon
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.security, size: 18, color: AppTheme.secondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PRACTICE – NOT A REAL CALL • यह केवल अभ्यास है',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.secondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'SAFE MODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _currentState == CallState.incoming
                      ? _buildStitchIncomingCall(callerTitle, lang)
                      : _buildStitchActiveCall(callerTitle, lang),
                ),
              ],
            ),

            // Authentic Android Floating Push Banner (Rendered dynamically if backend AI emits artifact)
            if (dynamicArtifact != null && !_artifactDismissed && _currentState == CallState.active)
              _buildFloatingAndroidNotificationBanner(dynamicArtifact, lang),
          ],
        ),
      ),
    );
  }

  // ── Authentic Android 14 Dynamic Scenario Notification Banner ────────────
  Widget _buildFloatingAndroidNotificationBanner(ScenarioArtifact artifact, String lang) {
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF202124),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A73E8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        artifact.title.isNotEmpty ? artifact.title : 'Messages • Just now',
                        style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () {
                      setState(() {
                        _artifactDismissed = true;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Sender & Message Body
              Text(
                artifact.sender,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                artifact.body,
                style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3),
              ),
              const SizedBox(height: 10),
              // Trap Quick Action Button
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFA4A2),
                        side: const BorderSide(color: Color(0xFFFFA4A2)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        artifact.type == 'otp'
                            ? Icons.copy
                            : (artifact.type == 'cutoff_link' ? Icons.link : Icons.description),
                        size: 16,
                      ),
                      label: Text(
                        artifact.actionLabel.isNotEmpty ? artifact.actionLabel : 'Open',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      onPressed: () {
                        // User clicked the trap!
                        _triggerScamCompromisedTrap(
                          'You clicked "${artifact.actionLabel}" on the simulated notification from ${artifact.sender}.',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _artifactDismissed = true;
                      });
                    },
                    child: Text(
                      lang == 'hi' ? 'हटाएं (Ignore)' : 'Dismiss',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stitch Incoming Call Screen ──────────────────────────────────────────
  Widget _buildStitchIncomingCall(String callerTitle, String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.inverseSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.ring_volume, color: AppTheme.secondaryFixedDim, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Incoming Call...',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.volume_up, color: AppTheme.primaryFixedDim, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '🔊 Audio On',
                            style: TextStyle(color: AppTheme.primaryFixed, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 100 + (_pulseController.value * 24),
                          height: 100 + (_pulseController.value * 24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.tertiaryContainer.withValues(alpha: 0.2 * (1 - _pulseController.value)),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.local_police,
                        size: 42,
                        color: AppTheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: AppTheme.tertiary, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'HIGH THREAT SIMULATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.tertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  callerTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.scenario?.persona ?? 'Cyber Crime Branch, Mumbai',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _declineCall,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.tertiary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.tertiary.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'लाल दबाएं',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const Text(
                          'DECLINE',
                          style: TextStyle(fontSize: 11, color: Colors.white60, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _acceptCall,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryContainer,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryContainer.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(Icons.call, color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'हरा दबाएं',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const Text(
                          'ANSWER',
                          style: TextStyle(fontSize: 11, color: AppTheme.primaryFixedDim, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const IFeelWorriedButton(),
        ],
      ),
    );
  }

  // ── Stitch Active AI Call Screen ─────────────────────────────────────────
  Widget _buildStitchActiveCall(String callerTitle, String lang) {
    final aiState = ref.watch(aiCallProvider);
    final displayedAiText = aiState.latestAiReply.isNotEmpty
        ? aiState.latestAiReply
        : (widget.scenario?.initialMessage ?? 'Hello, please listen carefully...');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        // 1. Caller Status Shell (Compact)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.inverseSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppTheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_off, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        callerTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        aiState.isSpeaking ? '🔊 Scammer Speaking...' : '📞 Connected • Listening',
                        style: TextStyle(
                          fontSize: 11,
                          color: aiState.isSpeaking ? AppTheme.secondaryFixed : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(_secondsElapsed),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    'Live AI Drill',
                    style: TextStyle(fontSize: 10, color: AppTheme.primaryFixedDim, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Threat Dialogue Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E9E6), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Threat Dialogue:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.secondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryFixed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Urgency Trap',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.tertiary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '“$displayedAiText”',
                style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  ref.read(realisticVoiceProvider).speakRealistic(displayedAiText, lang);
                },
                child: Row(
                  children: const [
                    Icon(Icons.replay, size: 16, color: AppTheme.primaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'Tap to replay voice / दोबारा सुनें',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. Compact Safety Tip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryFixed.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(Icons.shield, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'सुरक्षा सलाह: पुलिस या बैंक कभी भी फोन पर ओटीपी नहीं मांगते।',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // User's Response Card (Shows what the senior replied / tapped)
        if (aiState.lastUserMessage != null && aiState.lastUserMessage!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin, color: Color(0xFF2E7D32), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'hi' ? 'आपने कहा (You said):' : 'You replied:',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '“${aiState.lastUserMessage}”',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Scammer Thinking / Generating Indicator
        if (aiState.isThinking) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCC80)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang == 'hi' ? '⏳ कॉलर जवाब सोच रहा है... (Caller is replying...)' : '⏳ Scammer is replying to you...',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 4. Hero Auto-Mic Record-to-Text Live Console (Hands-Free Voice Recognition)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isListening ? const Color(0xFFFFF0F0) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isListening ? const Color(0xFFFF897D) : const Color(0xFFE0E0E0),
              width: _isListening ? 2 : 1,
            ),
            boxShadow: _isListening
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF897D).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              // Live Auto-Listening Status Header
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? const Color(0xFFD32F2F) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isListening
                          ? (lang == 'hi'
                              ? '🎙️ ऑटो-माइक सक्रिय • बोलिए (Hands-free recording)'
                              : '🎙️ AUTO-MIC ACTIVE • Speak naturally (Auto-record)')
                          : (lang == 'hi'
                              ? 'माइक तैयार • आवाज़ रिकॉर्डर (Mic Standby)'
                              : 'Mic Standby • Auto-recording ready'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _isListening ? AppTheme.tertiary : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_isListening)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: const Text(
                        'REC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD32F2F),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Live Speech-to-Text Transcription Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isListening ? const Color(0xFFFFCDD2) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.record_voice_over_rounded,
                          size: 16,
                          color: _isListening ? AppTheme.tertiary : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lang == 'hi' ? 'आपकी आवाज़ (Live Voice-to-Text):' : 'Live Voice-to-Text Transcript:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isListening ? AppTheme.tertiary : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _recognizedText.isEmpty
                          ? (lang == 'hi'
                              ? 'बोलिए, आपकी आवाज़ अपने आप टाइप होकर भेजी जाएगी...'
                              : 'Speak now, your words will be converted to text and auto-sent...')
                          : _recognizedText,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _recognizedText.isEmpty ? Colors.black38 : Colors.black87,
                        fontStyle: _recognizedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                        height: 1.3,
                      ),
                    ),
                    if (_recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        lang == 'hi'
                            ? '⚡ बोलने के बाद 1.5 सेकंड में अपने आप भेजा जाएगा...'
                            : '⚡ Auto-sends 1.5s after you finish talking...',
                        style: const TextStyle(fontSize: 10.5, color: Colors.black45, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Controls Row: Central Mic Button + Send Now + Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_recognizedText.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: _cancelListening,
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      label: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Central Mic Button with Icons.mic_rounded
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? AppTheme.tertiary : AppTheme.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? AppTheme.tertiary : AppTheme.primaryContainer).withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  if (_recognizedText.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_recognizedText.trim().isNotEmpty) {
                          _finalizeAndSend(_recognizedText.trim());
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _isListening ? 'माइक सुन रहा है... (Auto-listening)' : 'माइक दबाकर बोलें / Tap to Speak',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(height: 6),
              Center(
                child: InkWell(
                  onTap: _showVoiceChoiceSheet,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      '⌨️ माइक नहीं चल रहा? यहाँ टैप करके टाइप करें या विकल्प चुनें',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryContainer,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5. Quick Response Choices (Safe vs Trap!)
        const Text(
          'QUICK SAFE SHORTCUTS / त्वरित उत्तर:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.onSurfaceVariant, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),

        _buildQuickReplyCard(1, '“Who is your superior officer? Give badge number.”'),
        const SizedBox(height: 6),
        _buildQuickReplyCard(2, '“I never share Aadhaar or OTP on phone.”'),
        const SizedBox(height: 6),
        _buildQuickReplyCard(
          3,
          '“Mera OTP 482910 hai / My OTP is 482910”',
          isTrap: true,
        ),

        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildQuickReplyCard(int number, String text, {bool isTrap = false}) {
    final cleanDisplay = text.replaceAll('“', '').replaceAll('”', '').trim();
    return Material(
      color: isTrap ? const Color(0xFFFFF0F0) : AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _handleUserSpeechOrText(cleanDisplay);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isTrap ? const Color(0xFFFFDAD6) : AppTheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isTrap ? const Color(0xFFBA1A1A) : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cleanDisplay,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isTrap ? const Color(0xFFBA1A1A) : AppTheme.onSurface,
                  ),
                ),
              ),
              Icon(
                isTrap ? Icons.warning_rounded : Icons.send_rounded,
                size: 16,
                color: isTrap ? const Color(0xFFBA1A1A) : AppTheme.primaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
