import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/os_notification_provider.dart';

/// Global Notification Overlay that wraps screens or app shells.
/// Listens to OsNotificationProvider.activeBanner and animates an authentic
/// heads-up drop-down notification from the top of the smartphone screen.
/// Tapping the banner triggers navigation to the respective target app and clears the banner.
class GlobalNotificationOverlay extends ConsumerWidget {
  final Widget child;

  const GlobalNotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final osState = ref.watch(osNotificationProvider);
    final banner = osState.activeBanner;
    final hasBanner = banner != null;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Main Screen Content
        child,

        // Animated Drop-Down Heads-Up Notification Banner
        AnimatedPositioned(
          duration: const Duration(milliseconds: 380),
          curve: hasBanner ? Curves.easeOutBack : Curves.easeInCubic,
          top: hasBanner ? (topPadding > 0 ? topPadding + 6 : 14) : -160,
          left: 14,
          right: 14,
          child: IgnorePointer(
            ignoring: !hasBanner,
            child: banner != null
                ? _HeadsUpNotificationCard(
                    notification: banner,
                    onTap: () {
                      final notifier = ref.read(osNotificationProvider.notifier);
                      notifier.dismissBanner();
                      _navigateToTargetApp(context, ref, banner);
                    },
                    onDismiss: () {
                      ref.read(osNotificationProvider.notifier).dismissBanner();
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  void _navigateToTargetApp(BuildContext context, WidgetRef ref, OsNotification banner) {
    final target = banner.targetApp.trim().toLowerCase();
    final notifier = ref.read(osNotificationProvider.notifier);

    if (target.contains('whatsapp') || target.contains('fwhatsapp')) {
      notifier.clearBadge('FWhatsApp');
      context.push('/practice/whatsapp', extra: {
        'initialMessage': banner.body,
        'title': banner.title.isNotEmpty ? banner.title : banner.sender,
        'persona': banner.sender,
      });
    } else if (target.contains('sms') || target.contains('message')) {
      notifier.clearBadge('Messages');
      context.push('/practice/sms', extra: {
        'initialMessage': banner.body,
        'title': banner.title.isNotEmpty ? banner.title : banner.sender,
        'persona': banner.sender,
      });
    } else if (target.contains('phone') || target.contains('call')) {
      notifier.clearBadge('Phone');
      context.push('/practice/call', extra: {
        'startActive': true,
      });
    } else if (target.contains('web') || target.contains('browser')) {
      notifier.clearBadge('Browser');
      context.push('/practice/web');
    } else {
      // Default fallback to FWhatsApp or Messages
      notifier.clearBadge('FWhatsApp');
      context.push('/practice/whatsapp');
    }
  }
}

/// Authentic smartphone heads-up notification card with swipe-to-dismiss & tap action
class _HeadsUpNotificationCard extends StatelessWidget {
  final OsNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _HeadsUpNotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveAppStyle(notification.targetApp);

    return Dismissible(
      key: ValueKey(notification.eventId),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.96), // Twilight Slate
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: style.accentColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Icon Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: style.accentColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: style.accentColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    style.icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Notification Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subheader line: App Name • NOW
                      Row(
                        children: [
                          Text(
                            style.appName.toUpperCase(),
                            style: TextStyle(
                              color: style.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'NOW',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (notification.payloadType != 'text') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notification.payloadType.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Title
                      Text(
                        notification.title.isNotEmpty ? notification.title : notification.sender,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Body text
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Dismiss button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _AppStyle _resolveAppStyle(String target) {
    final lower = target.toLowerCase();
    if (lower.contains('whatsapp') || lower.contains('fwhatsapp')) {
      return const _AppStyle(
        appName: 'WhatsApp',
        accentColor: Color(0xFF25D366),
        icon: Icons.chat_rounded,
      );
    } else if (lower.contains('sms') || lower.contains('message')) {
      return const _AppStyle(
        appName: 'Messages',
        accentColor: Color(0xFF1A73E8),
        icon: Icons.textsms_rounded,
      );
    } else if (lower.contains('phone') || lower.contains('call')) {
      return const _AppStyle(
        appName: 'Phone',
        accentColor: Color(0xFF00875A),
        icon: Icons.phone_rounded,
      );
    } else if (lower.contains('web') || lower.contains('browser')) {
      return const _AppStyle(
        appName: 'Browser',
        accentColor: Color(0xFFEA4335),
        icon: Icons.public_rounded,
      );
    }
    return const _AppStyle(
      appName: 'System',
      accentColor: Color(0xFF0284C7),
      icon: Icons.notifications_active_rounded,
    );
  }
}

class _AppStyle {
  final String appName;
  final Color accentColor;
  final IconData icon;

  const _AppStyle({
    required this.appName,
    required this.accentColor,
    required this.icon,
  });
}

