import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../localization/ui_strings.dart';
import '../models/scenario.dart';
import '../models/simulation_result.dart';
import '../theme/app_theme.dart';

class SimulationTrigger {
  static OverlayEntry? _activeOverlay;
  static Timer? _autoOpenTimer;

  /// Reads the current app language from the Hive 'preferences' box.
  static String _lang() {
    if (Hive.isBoxOpen('preferences')) {
      return Hive.box('preferences').get('appLanguage', defaultValue: 'en') as String;
    }
    return 'en';
  }

  static void cancelActiveSimulation() {
    _autoOpenTimer?.cancel();
    _autoOpenTimer = null;
    _activeOverlay?.remove();
    _activeOverlay = null;
  }

  static void startSimulation(BuildContext context, Scenario? scenario) {
    cancelActiveSimulation();
    if (scenario == null) return;

    final lang = _lang();
    final channel = scenario.channel.toLowerCase();

    // If web: Route immediately to the web practice screen without a banner
    if (channel == 'web') {
      context.replace('/practice/web', extra: scenario);
      return;
    }

    final title = scenario.scammerName ?? scenario.title;
    final persona = scenario.persona ?? 'a scammer attempting fraud';
    final initialMsg = scenario.initialMessage ?? 'Hello. Please respond urgently.';

    IconData icon = Icons.message;
    Color iconBg = AppTheme.primaryTeal;
    String appName = 'Messages';
    String previewText = initialMsg;

    if (channel == 'call') {
      icon = Icons.phone_in_talk;
      iconBg = Colors.green.shade700;
      appName = UiStrings.get(lang, 'incoming_phone_call');
      previewText = '${UiStrings.get(lang, 'incoming_call_from')} $title';
    } else if (channel == 'whatsapp') {
      icon = Icons.chat;
      iconBg = const Color(0xFF25D366);
      appName = 'WhatsApp';
      previewText = initialMsg;
    } else if (channel == 'sms') {
      icon = Icons.textsms;
      iconBg = Colors.blue.shade700;
      appName = UiStrings.get(lang, 'sms_alert');
      previewText = initialMsg;
    }

    final overlayState = Overlay.of(context);

    _activeOverlay = OverlayEntry(
      builder: (ctx) => _TopHeadsUpNotification(
        title: title,
        subtitle: previewText,
        appName: appName,
        channel: channel,
        icon: icon,
        iconBg: iconBg,
        lang: lang,
        onTap: () {
          cancelActiveSimulation();
          if (channel == 'call') {
            context.replace('/practice/call', extra: {'scenario': scenario, 'startActive': false});
          } else {
            context.push('/ai_chat', extra: {
              'persona': persona,
              'initialMessage': initialMsg,
              'title': title,
            });
          }
        },
        onDismissed: () {
          cancelActiveSimulation();
        },
        onDeclineCall: () {
          cancelActiveSimulation();
          SimulationResult.recordResult(
            scenarioTitle: scenario.title,
            channel: 'call',
            status: 'success:hung_up',
          );
          final debriefMsg = scenario.debriefSuccess;
          context.replace('/debrief', extra: {
            'outcome': 'success:hung_up',
            'message': debriefMsg,
          });
        },
        onAcceptCall: () {
          cancelActiveSimulation();
          context.replace('/practice/call', extra: {'scenario': scenario, 'startActive': true});
        },
      ),
    );

    overlayState.insert(_activeOverlay!);

    // Auto-open after 5 seconds if ignored by the user
    _autoOpenTimer = Timer(const Duration(seconds: 5), () {
      if (context.mounted && _activeOverlay != null) {
        cancelActiveSimulation();
        if (channel == 'call') {
          // If no interaction in 5 seconds, navigate to /practice/call (startActive: false)
          context.replace('/practice/call', extra: {'scenario': scenario, 'startActive': false});
        } else {
          // whatsapp or sms -> 5-second timeout routes to /ai_chat
          context.push('/ai_chat', extra: {
            'persona': persona,
            'initialMessage': initialMsg,
            'title': title,
          });
        }
      }
    });
  }

  static void startMessageSimulation(BuildContext context, String title, String persona, String initialMsg) {
    triggerScenarioSimulation(
      context: context,
      title: title,
      persona: persona,
      initialMsg: initialMsg,
      channel: 'whatsapp',
    );
  }

  static void triggerScenarioSimulation({
    required BuildContext context,
    required String title,
    required String persona,
    required String initialMsg,
    required String channel,
    Scenario? scenario,
  }) {
    if (scenario != null) {
      startSimulation(context, scenario);
    } else {
      final fallbackScenario = Scenario(
        id: 'generic_sim',
        language: 'en',
        title: title,
        channel: channel,
        difficulty: 'medium',
        debriefSuccess: 'Great job avoiding the scam!',
        debriefFailure: 'Be cautious of unsolicited messages and calls.',
        persona: persona,
        initialMessage: initialMsg,
      );
      startSimulation(context, fallbackScenario);
    }
  }
}

class _TopHeadsUpNotification extends StatefulWidget {
  final String title;
  final String subtitle;
  final String appName;
  final String channel;
  final IconData icon;
  final Color iconBg;
  final String lang;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final VoidCallback? onDeclineCall;
  final VoidCallback? onAcceptCall;

  const _TopHeadsUpNotification({
    required this.title,
    required this.subtitle,
    required this.appName,
    required this.channel,
    required this.icon,
    required this.iconBg,
    required this.lang,
    required this.onTap,
    required this.onDismissed,
    this.onDeclineCall,
    this.onAcceptCall,
  });

  @override
  State<_TopHeadsUpNotification> createState() => _TopHeadsUpNotificationState();
}

class _TopHeadsUpNotificationState extends State<_TopHeadsUpNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Drops down smoothly from above the top edge
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isCall = widget.channel == 'call';
    final l = widget.lang;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnimation,
        child: GestureDetector(
          onTap: isCall ? widget.onAcceptCall : widget.onTap,
          onVerticalDragUpdate: (details) {
            // Dismiss on upward swipe
            if (details.primaryDelta != null && details.primaryDelta! < -4) {
              _dismiss();
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isCall ? Colors.green.shade300 : Colors.grey.shade300,
                  width: isCall ? 1.5 : 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: App icon + App Name + Timestamp
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: widget.iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.appName} • now',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.drag_handle, color: Colors.grey, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Caller / Sender info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isCall) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            UiStrings.get(l, 'open'),
                            style: const TextStyle(
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Call Action Buttons: Decline (Hang Up) and Accept (Answer)
                  if (isCall) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Decline / Hang Up Button
                        InkWell(
                          onTap: widget.onDeclineCall,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.red,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.red.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.call_end, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  UiStrings.get(l, 'decline'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Accept / Answer Button
                        InkWell(
                          onTap: widget.onAcceptCall,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.green,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.green.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.call, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  UiStrings.get(l, 'answer'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
