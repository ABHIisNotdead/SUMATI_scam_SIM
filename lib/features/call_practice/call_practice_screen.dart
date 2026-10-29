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

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentState = widget.startActive ? CallState.active : CallState.incoming;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

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

  void _startListening() async {
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

  void _stopListening() async {
    if (!_isListening) return;

    setState(() => _isListening = false);

    try {
      await _speechToText.stop();
    } catch (e) {
      debugPrint('[STT Stop Exception] $e');
    }

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiCallState>(aiCallProvider, (previous, next) {
      if (next.status == 'compromised' || next.status == 'deflected') {
        _callTimer?.cancel();
        _speechToText.stop();
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
        });
      }
    });

    final callerTitle = widget.scenario?.scammerName ?? widget.scenario?.title ?? 'Inspector Patil';
    final lang = ref.watch(preferencesProvider).appLanguage;

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
      body: SafeArea(
        child: Column(
          children: [
            // Top Practice Ribbon (Stitch style)
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
      ),
    );
  }

  // ── Stitch Incoming Call Screen ──────────────────────────────────────────
  Widget _buildStitchIncomingCall(String callerTitle, String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Main dark call shell
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
                // Top status bar inside card
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

                // Pulsing Center Avatar
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

                // Threat tag
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
                const SizedBox(height: 6),
                const Text(
                  '+91 98201 XXXXX • Suspected "Digital Arrest" Scam',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryFixedDim, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 20),

                // Sumati AI Reassurance Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppTheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lightbulb, size: 18, color: AppTheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sumati AI Reassurance • मार्गदर्शन',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.secondaryFixed),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Real police or CBI officers NEVER demand money, secret OTPs, or threaten digital arrest over video or phone. Stay calm!',
                              style: TextStyle(fontSize: 12.5, color: Colors.white, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Giant 76px Ergonomic Answer / Decline Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Decline
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _declineCall,
                          child: Container(
                            width: 76,
                            height: 76,
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

                    // Answer
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _acceptCall,
                          child: Container(
                            width: 76,
                            height: 76,
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

          // Panic Relief Button
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        // 1. Caller Status Shell
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.inverseSurface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_off, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            callerTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Simulated Scammer / फर्जी अधिकारी',
                            style: TextStyle(fontSize: 11, color: AppTheme.tertiaryFixed, fontWeight: FontWeight.w600),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const Text(
                        'Live AI Drill',
                        style: TextStyle(fontSize: 11, color: AppTheme.primaryFixedDim, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          aiState.isSpeaking ? Icons.volume_up : Icons.phone_in_talk,
                          size: 16,
                          color: AppTheme.secondaryFixed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          aiState.isSpeaking ? 'Scammer Speaking...' : 'Call Active (Listening)',
                          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryFixed, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 3,
                          height: aiState.isSpeaking ? (index % 2 == 0 ? 16 : 8) : 4,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryFixedDim,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Threat Dialogue Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.secondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Urgency Trap',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.tertiary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '“$displayedAiText”',
                style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  ref.read(realisticVoiceProvider).speakRealistic(displayedAiText, lang);
                },
                child: Row(
                  children: const [
                    Icon(Icons.replay, size: 18, color: AppTheme.primaryContainer),
                    SizedBox(width: 6),
                    Text(
                      'Tap to replay voice / दोबारा सुनें',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Recommended Action Shield Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryFixed.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛡️ Recommended Action / सुरक्षा सलाह',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scammers use fake authority. Remember: Indian law has NO ‘digital arrest’. Police never interrogate on phone or demand money. Never share OTP.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Tremble-Safe Response Cards
        const Text(
          'TAP A SAFE RESPONSE / उत्तर चुनें',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.onSurfaceVariant, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),

        _buildQuickReplyCard(1, '“Who is your superior officer? Give badge number.”'),
        const SizedBox(height: 8),
        _buildQuickReplyCard(2, '“I will visit the local police station myself.”'),
        const SizedBox(height: 8),
        _buildQuickReplyCard(3, '“I never share Aadhaar or OTP on phone.”'),

        const SizedBox(height: 20),

        // 5. Giant 88px Push-to-Talk Mic
        Column(
          children: [
            GestureDetector(
              onTapDown: (_) => _startListening(),
              onTapUp: (_) => _stopListening(),
              onTapCancel: _stopListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? AppTheme.tertiary : AppTheme.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? AppTheme.tertiary : AppTheme.primaryContainer).withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isListening ? '🎙️ Release to Send' : '🎙️ Hold to Speak / दबाकर बोलें',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Speak in Hindi, Marathi, or English',
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 6. Dual Bottom Actions (Hang Up + Worried)
        Row(
          children: [
            Expanded(
              child: const IFeelWorriedButton(),
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
                  minimumSize: const Size(0, 56),
                  backgroundColor: AppTheme.tertiary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuickReplyCard(int number, String text) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(aiCallProvider.notifier).sendVoiceMessage(text);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
