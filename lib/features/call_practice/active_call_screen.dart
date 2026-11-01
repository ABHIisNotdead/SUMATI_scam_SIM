import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/widgets/global_notification_overlay.dart';
import '../../core/widgets/practice_tag.dart';
import 'providers/call_audio_provider.dart';

/// Full-screen Android Active Call Screen.
/// Displays ongoing call timer, dynamic VAD speaking indicator, live scammer subtitles,
/// standard control grid (Mute, Keypad, Speaker, Quick Response, End Call), and is
/// fully wrapped in [GlobalNotificationOverlay] to receive real-time cross-app banners.
class ActiveCallScreen extends ConsumerStatefulWidget {
  final Scenario? scenario;

  const ActiveCallScreen({
    super.key,
    this.scenario,
  });

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _onEndCall() {
    _waveController.stop();
    ref.read(callAudioProvider.notifier).endCall();
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Voice Call Security Practice',
      channel: 'call',
      status: 'deflected',
    );
    context.replace('/debrief', extra: {
      'outcome': 'success:deflected',
      'scenarioId': widget.scenario?.id,
      'hook': 'Urgency and authority intimidation over voice call',
      'leak': 'None! You hung up and refused to comply.',
      'giveaway': 'High pressure demand for sensitive information or money.',
      'customMessage': 'Great job! Hanging up on suspicious callers is the safest defense.',
    });
  }

  void _onReportScam() {
    _waveController.stop();
    ref.read(callAudioProvider.notifier).endCall();
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Voice Call Security Practice',
      channel: 'call',
      status: 'deflected',
    );

    context.replace('/debrief', extra: {
      'outcome': 'success:deflected',
      'scenarioId': widget.scenario?.id,
      'hook': 'Caller pressure and urgency tactics',
      'leak': 'None! You identified the scammer and reported fraud.',
      'giveaway': 'High-pressure demand for sensitive information or money.',
      'customMessage': 'Excellent defense! You reported the fake caller and passed the practice drill.',
    });
  }

  void _showKeypadModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Keypad',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 14,
                childAspectRatio: 1.8,
                children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map((k) {
                  return InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dialed $k'),
                          duration: const Duration(milliseconds: 600),
                          backgroundColor: const Color(0xFF0F172A),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        k,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showTapResponseSheet() {
    final quickChoices = [
      'Who is speaking and what is your ID?',
      'I will verify this with my local branch directly.',
      'I cannot share any OTP or financial details on a call.',
      'I am hanging up now.',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tap-a-Response (Safe Senior Answers)',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Type custom reply / यहाँ टाइप करें...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (typed) {
                          if (typed.trim().isNotEmpty) {
                            Navigator.of(ctx).pop();
                            ref.read(callAudioProvider.notifier).sendUserMessage(typed.trim());
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.dialpad_rounded, color: Colors.white70),
                    tooltip: 'Keypad',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showKeypadModal();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...quickChoices.map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(callAudioProvider.notifier).sendUserMessage(text);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallAudioState>(callAudioProvider, (prev, next) {
      if (next.isScamDetected && prev?.isScamDetected != true) {
        Future.microtask(() {
          if (mounted) {
            context.replace('/debrief', extra: {
              'outcome': 'success:deflected',
              'scenarioId': widget.scenario?.id,
              'hook': 'Caller pressure and urgency tactics',
              'leak': 'None! You recognized the fraud attempt and called out the scammer.',
              'giveaway': 'High-pressure demand for sensitive information or money.',
              'customMessage': 'Outstanding victory! You recognized the scam call in real-time and called out the fraudster.',
            });
          }
        });
      }
    });

    final callState = ref.watch(callAudioProvider);
    final callerName = widget.scenario?.callerName ?? callState.callerName ?? 'Unknown Number';

    return GlobalNotificationOverlay(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A), // Slate 900
                Color(0xFF1E293B), // Slate 800
                Color(0xFF0D1B2A), // Deep Navy
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Practice Safety Ribbon
                const PracticeTag(),

                const SizedBox(height: 12),

                // Active Call Header (Caller Name, Duration Timer)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimer(callState.callDurationSeconds),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8), // Sky Blue
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Passive Pulsing Audio Visualizer Ring (Mic Hot Indicator)
                _buildPulsingVisualizerRing(callState),

                const SizedBox(height: 12),

                // Dynamic Audio Activity Status Pill
                Builder(
                  builder: (context) {
                    final isMicHot = callState.isListening && !callState.isMuted && !callState.isAiSpeaking;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMicHot
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: callState.isAiSpeaking
                                  ? const Color(0xFFEF4444)
                                  : (isMicHot
                                      ? const Color(0xFF22C55E)
                                      : Colors.white38),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            callState.isAiSpeaking
                                ? 'Caller is speaking...'
                                : (callState.isUserSpeaking
                                    ? 'Hearing your voice...'
                                    : (isMicHot
                                        ? 'MIC HOT • Speak hands-free (VAD Active)'
                                        : 'Tap Mic to Speak (बोलने के लिए माइक दबाएं)')),
                            style: TextStyle(
                              color: isMicHot ? const Color(0xFF34D399) : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Live Transcript & Subtitle Box
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (callState.latestAiReply.isNotEmpty) ...[
                            Row(
                              children: const [
                                Icon(Icons.record_voice_over_rounded, color: Color(0xFFF87171), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'CALLER:',
                                  style: TextStyle(
                                    color: Color(0xFFF87171),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              callState.latestAiReply,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (callState.recognizedText.isNotEmpty || callState.isListening) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF134E4A).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.mic, color: Color(0xFF34D399), size: 14),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'YOU (SPEECH-TO-TEXT):',
                                        style: TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (callState.recognizedText.isNotEmpty)
                                        InkWell(
                                          onTap: () {
                                            ref.read(callAudioProvider.notifier).sendUserMessage(callState.recognizedText);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.send_rounded, size: 12, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Send',
                                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    callState.recognizedText.isEmpty
                                        ? '🎙️ बोलिए, आपकी आवाज़ टेक्स्ट में रिकॉर्ड हो रही है... (Speak now, auto-recording...)'
                                        : callState.recognizedText,
                                    style: TextStyle(
                                      color: callState.recognizedText.isEmpty ? Colors.white54 : Colors.white,
                                      fontSize: 13,
                                      fontStyle: callState.recognizedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Standard Android In-Call Controls Grid with Mic Talk & Choose Reply
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Mic Talk Button (Auto-Mic / Tap to Speak)
                      _buildControlItem(
                        icon: callState.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        label: callState.isListening ? 'Mic On' : 'Tap Speak',
                        isActive: callState.isListening,
                        onTap: () => ref.read(callAudioProvider.notifier).toggleListening(),
                      ),

                      // Speaker Button
                      _buildControlItem(
                        icon: callState.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: 'Speaker',
                        isActive: callState.isSpeakerOn,
                        onTap: () => ref.read(callAudioProvider.notifier).toggleSpeaker(),
                      ),

                      // Mute Button
                      _buildControlItem(
                        icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: callState.isMuted ? 'Unmute' : 'Mute',
                        isActive: callState.isMuted,
                        onTap: () => ref.read(callAudioProvider.notifier).toggleMute(),
                      ),

                      // Senior Choose / Type Reply Sheet
                      _buildControlItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Text Reply',
                        isActive: false,
                        onTap: _showTapResponseSheet,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Action Row: End Call and Report Scam
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // End Call Button
                      GestureDetector(
                        key: const Key('call_end_button'),
                        onTap: _onEndCall,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626), // Red
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'End Call',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      // Report Scam Button
                      GestureDetector(
                        key: const Key('call_report_scam_button'),
                        onTap: _onReportScam,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706), // Amber Warning
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 34),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Report Scam',
                              style: TextStyle(color: Color(0xFFFCD34D), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingVisualizerRing(CallAudioState callState) {
    final isMicHot = callState.isListening && !callState.isMuted && !callState.isAiSpeaking;

    return Center(
      child: GestureDetector(
        key: const Key('call_avatar_mic_button'),
        onTap: () => ref.read(callAudioProvider.notifier).toggleListening(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            final pulse = _waveController.value;
            final levelFactor = (callState.isUserSpeaking && callState.soundLevel > 0)
                ? (callState.soundLevel.clamp(0.0, 10.0) / 10.0)
                : 0.0;
            final outerSize = 118.0 + (isMicHot || callState.isUserSpeaking || callState.isAiSpeaking
                ? (pulse * 24.0 + levelFactor * 14.0)
                : 0.0);
            final midSize = 106.0 + (isMicHot || callState.isUserSpeaking || callState.isAiSpeaking
                ? (pulse * 12.0 + levelFactor * 8.0)
                : 0.0);

            Color ringColor;
            if (callState.isAiSpeaking) {
              ringColor = const Color(0xFFEF4444); // Red when scammer speaks
            } else if (callState.isUserSpeaking) {
              ringColor = const Color(0xFF22C55E); // Green when user voice detected
            } else if (isMicHot) {
              ringColor = const Color(0xFF10B981); // Emerald when mic is hot & listening hands-free
            } else {
              ringColor = Colors.white24;
            }

            return SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Pulsing Audio Visualizer Ring (Passive)
                  if (isMicHot || callState.isUserSpeaking || callState.isAiSpeaking)
                    Container(
                      width: outerSize,
                      height: outerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor.withValues(alpha: 0.25 * (1.0 - pulse * 0.5)),
                          width: 2.0,
                        ),
                      ),
                    ),

                  // Middle Pulsing Ring
                  if (isMicHot || callState.isUserSpeaking || callState.isAiSpeaking)
                    Container(
                      width: midSize,
                      height: midSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor.withValues(alpha: 0.45 * (1.0 - pulse * 0.3)),
                          width: 2.5,
                        ),
                      ),
                    ),

                  // Core Visualizer Ring & Avatar
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ringColor.withValues(alpha: 0.2),
                      border: Border.all(
                        color: ringColor,
                        width: 3.0,
                      ),
                      boxShadow: [
                        if (isMicHot || callState.isUserSpeaking || callState.isAiSpeaking)
                          BoxShadow(
                            color: ringColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Icon(
                      callState.isAiSpeaking
                          ? Icons.volume_up_rounded
                          : (callState.isUserSpeaking
                              ? Icons.mic_rounded
                              : (isMicHot ? Icons.mic_rounded : Icons.mic_none_rounded)),
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF0F172A) : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
