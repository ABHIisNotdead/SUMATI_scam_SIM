import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/scenario.dart';
import '../../core/services/sound_effect_service.dart';
import '../../core/widgets/practice_tag.dart';
import 'active_call_screen.dart';
import 'providers/call_audio_provider.dart';

/// Full-screen Android Incoming Call UI matching standard mobile paradigms.
/// Features twilight gradient, pulsing caller avatar, and dual tap/swipe-to-answer controls.
class IncomingCallScreen extends ConsumerStatefulWidget {
  final Scenario? scenario;
  final String callerName;
  final String callerSubtitle;

  const IncomingCallScreen({
    super.key,
    this.scenario,
    this.callerName = 'Unknown, Number',
    this.callerSubtitle = 'Suspected Fraud Call',
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  SoundEffectService? _soundService;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize call engine & play ringtone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _soundService = ref.read(soundEffectServiceProvider);
      ref.read(callAudioProvider.notifier).prepareIncomingCall(widget.scenario);
      _soundService?.playCallRingtone();
    });
  }

  @override
  void dispose() {
    _soundService?.stopCallRingtone();
    _pulseController.dispose();
    super.dispose();
  }

  void _onAccept() {
    _soundService?.stopCallRingtone();
    ref.read(callAudioProvider.notifier).answerCall(
      scenario: widget.scenario,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(scenario: widget.scenario),
      ),
    );
  }

  void _onDecline() {
    _soundService?.stopCallRingtone();
    ref.read(callAudioProvider.notifier).declineCall();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/fake_android');
    }
  }

  void _onQuickMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Sent auto-reply: 'I cannot talk right now. Please message.'"),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    _onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.scenario?.callerName ?? widget.callerName;
    final displaySubtitle = widget.scenario?.title ?? widget.callerSubtitle;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Authentic twilight/navy gradient matching reference
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B2A), // Deep Midnight
              Color(0xFF1B263B), // Dark Navy
              Color(0xFF243B55), // Steel Blue
              Color(0xFF141E30), // Dark Base
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Legal safety tag
              const PracticeTag(),

              // Realistic Phone Status Bar
              _buildStatusBar(),

              const Spacer(flex: 1),

              // Pulsing Avatar Silhouette
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 68,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Caller ID
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      displaySubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Secondary actions: Message & Reminder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSecondaryAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Message',
                      onTap: _onQuickMessage,
                    ),
                    _buildSecondaryAction(
                      icon: Icons.alarm_rounded,
                      label: 'Reminder',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Reminder set for 15 minutes'),
                            backgroundColor: const Color(0xFF1E293B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Primary Call Controls: Decline (Red) & Accept (Green)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline Button with swipe-to-decline support
                    _buildCallActionButton(
                      icon: Icons.call_end_rounded,
                      color: const Color(0xFFDC2626), // Alert Red
                      label: 'Decline',
                      onTap: _onDecline,
                      onSwipeUp: _onDecline,
                    ),

                    // Accept Button with swipe-to-answer support
                    _buildCallActionButton(
                      icon: Icons.call_rounded,
                      color: const Color(0xFF16A34A), // Emerald Green
                      label: 'Answer',
                      onTap: _onAccept,
                      onSwipeUp: _onAccept,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Android Navigation Indicator
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 1.5),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Airtel | Airtel',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.security_rounded, size: 12, color: Colors.white70),
          const Spacer(),
          const Icon(Icons.wifi, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          const Text(
            '100%',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.battery_full_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          const Text(
            '3:06 PM',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onSwipeUp,
  }) {
    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
          onSwipeUp();
        }
      },
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

