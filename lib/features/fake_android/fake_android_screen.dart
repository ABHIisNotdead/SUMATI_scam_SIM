import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/scenario.dart';
import '../../core/utils/simulation_trigger.dart';
import '../../core/widgets/practice_tag.dart';

class FakeAndroidScreen extends StatefulWidget {
  final Scenario? scenario;
  final String title;
  final String persona;
  final String initialMsg;
  final String channel;

  const FakeAndroidScreen({
    super.key,
    this.scenario,
    this.title = 'Unknown Number',
    this.persona = 'a scammer attempting fraud',
    this.initialMsg = 'Hello. Please respond urgently.',
    this.channel = 'whatsapp',
  });

  @override
  State<FakeAndroidScreen> createState() => _FakeAndroidScreenState();
}

class _FakeAndroidScreenState extends State<FakeAndroidScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulate realistic heads-up notification sliding from top after 1.8 seconds
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        SimulationTrigger.startSimulation(context, widget.scenario);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    super.dispose();
  }

  void _openDirectPractice(String targetChannel) {
    _timer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    if (targetChannel == 'web') {
      context.replace('/practice/web', extra: widget.scenario);
    } else if (targetChannel == 'call') {
      context.replace('/practice/call', extra: {'scenario': widget.scenario, 'startActive': true});
    } else if (targetChannel == 'sms') {
      context.replace('/practice/sms', extra: widget.scenario);
    } else {
      context.replace('/practice/whatsapp', extra: widget.scenario);
    }
  }

  void _exitToHome() {
    _timer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Safety Ribbon (Legal simulation indicator)
          const PracticeTag(),

          Expanded(
            child: Stack(
              children: [
                Container(
                  // Authentic Material You Twilight Wallpaper
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF0E3A40),
                        Color(0xFF07232B),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // 1. Authentic Android System Status Bar
                        _buildAuthenticStatusBar(),

                        const SizedBox(height: 12),

                        // 2. Android "At a Glance" Date & Weather Widget
                        _buildAtAGlanceWidget(),

                        const SizedBox(height: 18),

                        // 3. Android Google Search Pill Widget
                        _buildGoogleSearchBar(),

                        const SizedBox(height: 22),

                        // 4. Authentic Android App Icons Grid (4 columns)
                        Expanded(child: _buildAppGrid()),

                        // 5. Authentic Android Bottom Dock
                        _buildBottomDock(),

                        // 6. Modern Android Navigation Gesture Bar
                        _buildGestureBar(),
                      ],
                    ),
                  ),
                ),

                // Floating Senior Exit Button
                Positioned(
                  top: 48,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _exitToHome,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828), // Vibrant Alert Red
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Exit • बाहर निकलें',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
      child: Row(
        children: [
          // Current Time
          const Text(
            '10:45',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),

          // Notification Icons on left
          const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 14),
          const SizedBox(width: 6),
          const Icon(Icons.mail_rounded, color: Colors.white70, size: 14),

          const Spacer(),

          // Right Status Icons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 0.8),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              '5G',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.wifi, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          const Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Row(
            children: const [
              Text(
                '88%',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 3),
              Icon(Icons.battery_full, color: Colors.white, size: 15),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAtAGlanceWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                'Wednesday, Oct 29',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
              Spacer(),
              Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFFFFD54F)),
              SizedBox(width: 4),
              Text(
                '28°C Mumbai',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Google G Logo
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            alignment: Alignment.center,
            child: const Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Search or type URL...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const Icon(Icons.mic, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildAppGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.count(
        crossAxisCount: 4,
        physics: const BouncingScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        children: [
          // Phone App
          _AndroidAppIcon(
            label: 'Phone',
            icon: Icons.phone_rounded,
            bgColor: const Color(0xFF00875A),
            onTap: () => _openDirectPractice('call'),
          ),

          // Messages (SMS) App
          _AndroidAppIcon(
            label: 'Messages',
            icon: Icons.textsms_rounded,
            bgColor: const Color(0xFF1A73E8),
            onTap: () => _openDirectPractice('sms'),
          ),

          // WhatsApp App
          _AndroidAppIcon(
            label: 'WhatsApp',
            icon: Icons.chat_rounded,
            bgColor: const Color(0xFF25D366),
            onTap: () => _openDirectPractice('whatsapp'),
          ),

          // Chrome App
          _AndroidAppIcon(
            label: 'Chrome',
            icon: Icons.public_rounded,
            bgColor: const Color(0xFFEA4335),
            onTap: () => _openDirectPractice('web'),
          ),

          // Secondary Android Apps
          _AndroidAppIcon(
            label: 'Gmail',
            icon: Icons.mail_rounded,
            bgColor: const Color(0xFFD93025),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'Photos',
            icon: Icons.photo_library_rounded,
            bgColor: const Color(0xFF4285F4),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'Camera',
            icon: Icons.camera_alt_rounded,
            bgColor: const Color(0xFF333333),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'YouTube',
            icon: Icons.play_arrow_rounded,
            bgColor: const Color(0xFFFF0000),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'Settings',
            icon: Icons.settings_rounded,
            bgColor: const Color(0xFF5F6368),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'GPay',
            icon: Icons.account_balance_wallet_rounded,
            bgColor: const Color(0xFF1E88E5),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'Maps',
            icon: Icons.map_rounded,
            bgColor: const Color(0xFF34A853),
            onTap: () {},
          ),
          _AndroidAppIcon(
            label: 'Play Store',
            icon: Icons.shopping_bag_rounded,
            bgColor: const Color(0xFF00A0E9),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _AndroidAppIcon(
            label: '',
            icon: Icons.phone_rounded,
            bgColor: const Color(0xFF00875A),
            onTap: () => _openDirectPractice('call'),
          ),
          _AndroidAppIcon(
            label: '',
            icon: Icons.textsms_rounded,
            bgColor: const Color(0xFF1A73E8),
            onTap: () => _openDirectPractice('sms'),
          ),
          _AndroidAppIcon(
            label: '',
            icon: Icons.chat_rounded,
            bgColor: const Color(0xFF25D366),
            onTap: () => _openDirectPractice('whatsapp'),
          ),
          _AndroidAppIcon(
            label: '',
            icon: Icons.public_rounded,
            bgColor: const Color(0xFFEA4335),
            onTap: () => _openDirectPractice('web'),
          ),
          _AndroidAppIcon(
            label: '',
            icon: Icons.camera_alt_rounded,
            bgColor: const Color(0xFF333333),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildGestureBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: 140,
      height: 4.5,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _AndroidAppIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _AndroidAppIcon({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
