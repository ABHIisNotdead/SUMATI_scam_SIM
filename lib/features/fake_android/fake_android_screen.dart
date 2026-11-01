import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/scenario.dart';
import '../../core/providers/os_notification_provider.dart';
import '../../core/utils/simulation_trigger.dart';
import '../../core/widgets/global_notification_overlay.dart';
import '../../core/widgets/practice_tag.dart';

/// Simulated Smartphone Operating System Home Screen for SUMATI Scam Simulations.
/// Features authentic Android status bar (5G, Battery, Time), realistic non-interactive filler icons,
/// and a fixed bottom dock with 4 functional apps (Phone, Messages, FWhatsApp, Browser)
/// wrapped in dynamic red Badge widgets listening to [osNotificationProvider.appBadges].
class FakeAndroidScreen extends ConsumerStatefulWidget {
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
  ConsumerState<FakeAndroidScreen> createState() => _FakeAndroidScreenState();
}

class _FakeAndroidScreenState extends ConsumerState<FakeAndroidScreen> {
  Timer? _initialSimulationTimer;

  @override
  void initState() {
    super.initState();
    // Simulate initial scenario prompt drop-down after 2 seconds if scenario is loaded
    _initialSimulationTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        SimulationTrigger.startSimulation(context, widget.scenario);
      }
    });
  }

  @override
  void dispose() {
    _initialSimulationTimer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    super.dispose();
  }

  void _openFunctionalApp(String appKey) {
    _initialSimulationTimer?.cancel();
    SimulationTrigger.cancelActiveSimulation();

    final notifier = ref.read(osNotificationProvider.notifier);
    notifier.setActiveApp(appKey);

    switch (appKey) {
      case 'Phone':
        notifier.clearBadge('Phone');
        context.push('/practice/call', extra: {
          'scenario': widget.scenario,
          'startActive': true,
        });
        break;
      case 'Messages':
        notifier.clearBadge('Messages');
        context.push('/practice/sms', extra: widget.scenario);
        break;
      case 'FWhatsApp':
        notifier.clearBadge('FWhatsApp');
        context.push('/practice/whatsapp', extra: widget.scenario);
        break;
      case 'Browser':
        notifier.clearBadge('Browser');
        context.push('/practice/web', extra: widget.scenario);
        break;
      default:
        context.push('/practice/whatsapp', extra: widget.scenario);
    }
  }

  void _showFillerNotice(String appName) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$appName is non-interactive in this drill. Practice with Phone, Messages, FWhatsApp, or Browser.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _exitToHome() {
    _initialSimulationTimer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final osState = ref.watch(osNotificationProvider);
    final badges = osState.appBadges;

    return GlobalNotificationOverlay(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Column(
          children: [
            // Legal Practice Safety Tag
            const PracticeTag(),

            Expanded(
              child: Stack(
                children: [
                  // Twilight Material You Wallpaper
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0F172A), // Slate 900
                          Color(0xFF1E293B), // Slate 800
                          Color(0xFF0E3A40), // Deep Cyan Teal
                          Color(0xFF07232B), // Deep Midnight
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // 1. Android Status Bar (5G, Battery, Time)
                          _buildAuthenticStatusBar(),

                          const SizedBox(height: 12),

                          // 2. Android "At a Glance" Date & Weather
                          _buildAtAGlanceWidget(),

                          const SizedBox(height: 16),

                          // 3. Android Google Search Pill Widget
                          _buildGoogleSearchBar(),

                          const SizedBox(height: 20),

                          // 4. Grid of Non-Interactive Realistic Filler Icons
                          Expanded(child: _buildFillerAppGrid()),

                          // 5. Fixed Bottom Dock with 4 Functional Apps + Dynamic Badges
                          _buildFixedBottomDock(badges),

                          // 6. Navigation Gesture Bar
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
                            color: const Color(0xFFC62828), // High Contrast Alert Red
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
      ),
    );
  }

  /// 1. Android Status Bar with Time, 5G, Wi-Fi, and Battery
  Widget _buildAuthenticStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
      child: Row(
        children: [
          // Clock Time
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

          // Left notification preview dots
          const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 13),
          const SizedBox(width: 5),
          const Icon(Icons.mail_rounded, color: Colors.white60, size: 13),

          const Spacer(),

          // 5G Network Indicator
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

          // Battery Percentage + Icon
          Row(
            children: const [
              Text(
                '88%',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 3),
              Icon(Icons.battery_full_rounded, color: Colors.white, size: 15),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Android "At a Glance" Widget
  Widget _buildAtAGlanceWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22.0),
      child: Row(
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
    );
  }

  /// 3. Google Search Bar Pill
  Widget _buildGoogleSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
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
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const Icon(Icons.mic, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  /// 4. Grid of Realistic Non-Interactive Filler Icons
  Widget _buildFillerAppGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.count(
        crossAxisCount: 4,
        physics: const BouncingScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        children: [
          // Gallery / Photos
          _AppIcon(
            label: 'Gallery',
            icon: Icons.photo_library_rounded,
            bgColor: const Color(0xFF8B5CF6),
            onTap: () => _showFillerNotice('Gallery'),
          ),

          // Settings
          _AppIcon(
            label: 'Settings',
            icon: Icons.settings_rounded,
            bgColor: const Color(0xFF64748B),
            onTap: () => _showFillerNotice('Settings'),
          ),

          // Camera
          _AppIcon(
            label: 'Camera',
            icon: Icons.camera_alt_rounded,
            bgColor: const Color(0xFF334155),
            onTap: () => _showFillerNotice('Camera'),
          ),

          // Calculator
          _AppIcon(
            label: 'Calculator',
            icon: Icons.calculate_rounded,
            bgColor: const Color(0xFF0284C7),
            onTap: () => _showFillerNotice('Calculator'),
          ),

          // Gmail
          _AppIcon(
            label: 'Gmail',
            icon: Icons.mail_rounded,
            bgColor: const Color(0xFFEA4335),
            onTap: () => _showFillerNotice('Gmail'),
          ),

          // Clock
          _AppIcon(
            label: 'Clock',
            icon: Icons.access_time_filled_rounded,
            bgColor: const Color(0xFF059669),
            onTap: () => _showFillerNotice('Clock'),
          ),

          // Notes
          _AppIcon(
            label: 'Notes',
            icon: Icons.edit_note_rounded,
            bgColor: const Color(0xFFD97706),
            onTap: () => _showFillerNotice('Notes'),
          ),

          // Play Store
          _AppIcon(
            label: 'Play Store',
            icon: Icons.shopping_bag_rounded,
            bgColor: const Color(0xFF00A0E9),
            onTap: () => _showFillerNotice('Play Store'),
          ),
        ],
      ),
    );
  }

  /// 5. Fixed Bottom Dock with 4 Functional Apps + Dynamic Red Badges
  Widget _buildFixedBottomDock(Map<String, int> badges) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Phone App
          _buildDockItem(
            appName: 'Phone',
            label: 'Phone',
            icon: Icons.phone_rounded,
            bgColor: const Color(0xFF00875A), // Emerald Green
            unreadCount: badges['Phone'] ?? 0,
            onTap: () => _openFunctionalApp('Phone'),
          ),

          // 2. Messages (SMS) App
          _buildDockItem(
            appName: 'Messages',
            label: 'Messages',
            icon: Icons.textsms_rounded,
            bgColor: const Color(0xFF1A73E8), // Google Blue
            unreadCount: badges['Messages'] ?? 0,
            onTap: () => _openFunctionalApp('Messages'),
          ),

          // 3. FWhatsApp App
          _buildDockItem(
            appName: 'FWhatsApp',
            label: 'WhatsApp',
            icon: Icons.chat_rounded,
            bgColor: const Color(0xFF25D366), // WhatsApp Green
            unreadCount: badges['FWhatsApp'] ?? 0,
            onTap: () => _openFunctionalApp('FWhatsApp'),
          ),

          // 4. Web Browser App
          _buildDockItem(
            appName: 'Browser',
            label: 'Browser',
            icon: Icons.public_rounded,
            bgColor: const Color(0xFFEA4335), // Browser Red
            unreadCount: badges['Browser'] ?? 0,
            onTap: () => _openFunctionalApp('Browser'),
          ),
        ],
      ),
    );
  }

  /// Dock icon wrapped in a dynamic Badge widget
  Widget _buildDockItem({
    required String appName,
    required String label,
    required IconData icon,
    required Color bgColor,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: const Color(0xFFBA1A1A), // Red badge
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 6. Modern Android Navigation Gesture Bar
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

/// Generic Android app icon widget for filler apps
class _AppIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _AppIcon({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
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
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
