import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/localization/ui_strings.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/ai_call_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/i_feel_worried_button.dart';
import '../../core/widgets/practice_tag.dart';

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

class _CallPracticeScreenState extends ConsumerState<CallPracticeScreen> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  late CallState _currentState;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _recognizedText = '';
  int _secondsElapsed = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _currentState = widget.startActive ? CallState.active : CallState.incoming;
    _initSpeech();

    if (_currentState == CallState.active) {
      _startCallTimer();
      _connectAiCall();
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('[STT Error] $val'),
        onStatus: (val) => debugPrint('[STT Status] $val'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[STT Init Exception] $e');
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(aiCallProvider.notifier).connect(persona, initialMessage);
      }
    });
  }

  void _acceptCall() {
    setState(() => _currentState = CallState.active);
    _startCallTimer();
    _connectAiCall();
  }

  void _declineCall() {
    _callTimer?.cancel();
    _speechToText.stop();
    ref.read(aiCallProvider.notifier).endCall();

    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Suspicious Voice Call',
      channel: 'call',
      status: 'success:hung_up',
    );

    final debriefText = widget.scenario?.debriefSuccess ??
        'Great job! You hung up on the suspicious call. Never entertain unverified callers asking for money or details.';
    context.replace('/debrief', extra: {
      'outcome': 'success:hung_up',
      'message': debriefText,
    });
  }

  // Push-to-Talk: Start listening on tap down
  void _startListening() async {
    // 4. onTapDown -> Stop TTS via provider, start STT listening
    ref.read(aiCallProvider.notifier).stopTts();
    _recognizedText = '';
    setState(() => _isListening = true);

    try {
      if (!_speechEnabled) {
        _speechEnabled = await _speechToText.initialize();
      }

      if (_speechEnabled) {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _recognizedText = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('[STT Listen Exception] $e');
    }
  }

  // Push-to-Talk: Stop listening on release or cancel
  void _stopListening() async {
    // 5. onTapUp / onTapCancel -> Stop STT listening, capture recognized text, send to AI
    if (!_isListening) return;

    setState(() => _isListening = false);

    try {
      await _speechToText.stop();
    } catch (e) {
      debugPrint('[STT Stop Exception] $e');
    }

    // Small delay to let any last partial result finalize
    await Future.delayed(const Duration(milliseconds: 200));

    final textToSend = _recognizedText.trim();
    if (textToSend.isNotEmpty) {
      ref.read(aiCallProvider.notifier).sendVoiceMessage(textToSend);
      _recognizedText = '';
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 6. Listen to AiCallProvider state changes: if status is 'compromised' or 'deflected', route to debrief
    ref.listen<AiCallState>(aiCallProvider, (previous, next) {
      if (next.status == 'compromised' || next.status == 'deflected') {
        _callTimer?.cancel();
        _speechToText.stop();
        ref.read(aiCallProvider.notifier).endCall();

        // Save result to 'simulation_results' Hive box before navigating to /debrief
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
        });
      }
    });

    final callerTitle = widget.scenario?.scammerName ?? widget.scenario?.title ?? 'Suspicious Caller';
    final lang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            const PracticeTag(),
            Expanded(
              child: _currentState == CallState.incoming
                  ? _buildIncomingCall(callerTitle, lang)
                  : _buildActiveCall(callerTitle, lang),
            ),
          ],
        ),
      ),
    );
  }

  // Full Incoming Call Ringing Screen
  Widget _buildIncomingCall(String callerTitle, String lang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.person, size: 70, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                callerTitle,
                style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              UiStrings.get(lang, 'incoming_voice_call'),
              style: const TextStyle(fontSize: 18, color: Colors.white60, letterSpacing: 0.5),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCallButton(Icons.call_end, AppTheme.red, UiStrings.get(lang, 'decline'), _declineCall),
            _buildCallButton(Icons.call, AppTheme.green, UiStrings.get(lang, 'answer'), _acceptCall),
          ],
        ),
      ],
    );
  }

  // Active Call Screen with Push-to-Talk (STT + TTS)
  Widget _buildActiveCall(String callerTitle, String lang) {
    final aiState = ref.watch(aiCallProvider);
    final displayedAiText = aiState.latestAiReply.isNotEmpty
        ? aiState.latestAiReply
        : (widget.scenario?.initialMessage ?? 'Connected...');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          // Caller Avatar & Title
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.person, size: 44, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            callerTitle,
            style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(_secondsElapsed),
            style: const TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 8),

          // Live Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isListening
                  ? Colors.blue.withValues(alpha: 0.2)
                  : (aiState.isSpeaking ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isListening
                      ? Icons.mic
                      : (aiState.isSpeaking ? Icons.volume_up : Icons.phone_in_talk),
                  size: 16,
                  color: _isListening
                      ? Colors.lightBlueAccent
                      : (aiState.isSpeaking ? Colors.greenAccent : Colors.white70),
                ),
                const SizedBox(width: 6),
                Text(
                  _isListening
                      ? UiStrings.get(lang, 'listening')
                      : (aiState.isSpeaking
                          ? UiStrings.get(lang, 'ai_speaking')
                          : UiStrings.get(lang, 'call_connected')),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isListening
                        ? Colors.lightBlueAccent
                        : (aiState.isSpeaking ? Colors.greenAccent : Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Caller Speech Bubble (AI Voice Message Display)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.record_voice_over, color: Colors.white60, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      UiStrings.get(lang, 'ai_caller_says'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  displayedAiText,
                  style: const TextStyle(fontSize: 17, color: Colors.white, height: 1.3),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Live recognition preview while user speaks
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${UiStrings.get(lang, 'you_said')}: "$_recognizedText"',
                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const Spacer(),

          // Push-to-Talk Microphone Button
          GestureDetector(
            onTapDown: (_) => _startListening(),
            onTapUp: (_) => _stopListening(),
            onTapCancel: _stopListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? Colors.blueAccent : Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: _isListening ? Colors.white : Colors.white38,
                  width: _isListening ? 3 : 1.5,
                ),
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 46,
                color: _isListening ? Colors.white : Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening
                ? UiStrings.get(lang, 'release_mic')
                : UiStrings.get(lang, 'hold_mic'),
            style: TextStyle(
              color: _isListening ? Colors.lightBlueAccent : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Quick Fallback Chips (helpful for quick testing or if hardware mic is restricted)
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuickChip(UiStrings.get(lang, 'quick_who')),
                const SizedBox(width: 8),
                _buildQuickChip(UiStrings.get(lang, 'quick_visit_bank')),
                const SizedBox(width: 8),
                _buildQuickChip(UiStrings.get(lang, 'quick_otp')),
              ],
            ),
          ),

          const Spacer(),

          // Red Hang Up Button
          ElevatedButton.icon(
            onPressed: _declineCall,
            icon: const Icon(Icons.call_end, color: Colors.white),
            label: Text(
              UiStrings.get(lang, 'hang_up'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          const IFeelWorriedButton(),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        ref.read(aiCallProvider.notifier).sendVoiceMessage(text);
      },
    );
  }

  Widget _buildCallButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 36,
            backgroundColor: color,
            child: Icon(icon, size: 36, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
