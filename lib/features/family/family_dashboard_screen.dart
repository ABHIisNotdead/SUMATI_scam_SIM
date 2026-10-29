import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scam_shield_app_bar.dart';

class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatChannel(String channel, String lang) {
    switch (channel.toLowerCase()) {
      case 'call':
        return UiStrings.get(lang, 'phone_call');
      case 'whatsapp':
        return 'WhatsApp';
      case 'sms':
        return UiStrings.get(lang, 'sms_message');
      case 'web':
        return UiStrings.get(lang, 'web_security');
      default:
        return channel.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(preferencesProvider).appLanguage;
    final box = Hive.isBoxOpen('simulation_results')
        ? Hive.box('simulation_results')
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: ScamShieldAppBar(
        title: UiStrings.get(lang, 'family_dashboard'),
        hideExit: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, semanticLabel: 'Home'),
            tooltip: UiStrings.get(lang, 'back_home'),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: box == null
          ? FutureBuilder(
              future: Hive.openBox('simulation_results'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return _buildDashboardContent(context, Hive.box('simulation_results'), lang);
                }
                return const Center(child: CircularProgressIndicator());
              },
            )
          : ValueListenableBuilder<Box>(
              valueListenable: box.listenable(),
              builder: (context, currentBox, _) {
                return _buildDashboardContent(context, currentBox, lang);
              },
            ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, Box box, String lang) {
    final items = <SimulationResult>[];
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item is SimulationResult) {
        items.add(item);
      } else if (item is Map) {
        items.add(SimulationResult.fromMap(item));
      }
    }

    // Sort most recent first
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final totalFaced = items.length;
    final avoidedCount = items.where((r) => r.isAvoided).length;
    final compromisedCount = items.where((r) => r.isCompromised).length;
    final scoreRate = totalFaced > 0 ? ((avoidedCount / totalFaced) * 100).round() : 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Safety Score Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UiStrings.get(lang, 'safety_scorecard'),
                  style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  UiStrings.get(lang, 'family_guardian'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Circular score + metrics side by side
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated circular progress indicator
                    _AnimatedScoreRing(score: scoreRate, lang: lang),
                    const SizedBox(width: 24),
                    // Metric tiles column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricRow(
                          label: UiStrings.get(lang, 'total_faced'),
                          value: '$totalFaced',
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        _buildMetricRow(
                          label: UiStrings.get(lang, 'avoided'),
                          value: '$avoidedCount',
                          color: const Color(0xFF4ADE80),
                        ),
                        const SizedBox(height: 12),
                        _buildMetricRow(
                          label: UiStrings.get(lang, 'fallen_for'),
                          value: '$compromisedCount',
                          color: const Color(0xFFF87171),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── 2. Practice History Header ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                UiStrings.get(lang, 'recent_history'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(UiStrings.get(lang, 'clear_history_title')),
                        content: Text(UiStrings.get(lang, 'clear_history_body')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(UiStrings.get(lang, 'cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              UiStrings.get(lang, 'clear'),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await box.clear();
                    }
                  },
                  child: Text(UiStrings.get(lang, 'clear_all'), style: const TextStyle(color: Colors.grey)),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 3. History List ────────────────────────────────────────────────
          if (items.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.history, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    UiStrings.get(lang, 'no_simulations'),
                    style: const TextStyle(fontSize: 17, color: Colors.black87, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    UiStrings.get(lang, 'no_simulations_sub'),
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final result = items[index];
                final isAvoided = result.isAvoided;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                    border: Border.all(
                      color: isAvoided
                          ? AppTheme.green.withValues(alpha: 0.3)
                          : AppTheme.red.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAvoided
                              ? AppTheme.green.withValues(alpha: 0.12)
                              : AppTheme.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAvoided ? Icons.shield : Icons.warning_amber_rounded,
                          color: isAvoided ? AppTheme.green : AppTheme.red,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Scenario Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.scenarioTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatChannel(result.channel, lang)} • ${_formatDate(result.timestamp)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),

                      // Status Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAvoided
                              ? AppTheme.green.withValues(alpha: 0.12)
                              : AppTheme.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAvoided
                              ? UiStrings.get(lang, 'avoided_badge')
                              : UiStrings.get(lang, 'fallen_badge'),
                          style: TextStyle(
                            color: isAvoided ? AppTheme.green : AppTheme.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 28),

          // ── 4. Back Button ────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.arrow_back),
            label: Text(
              UiStrings.get(lang, 'back_home'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }
}

// ── Animated Circular Safety Score Ring ──────────────────────────────────────

class _AnimatedScoreRing extends StatefulWidget {
  final int score;
  final String lang;
  const _AnimatedScoreRing({required this.score, required this.lang});

  @override
  State<_AnimatedScoreRing> createState() => _AnimatedScoreRingState();
}

class _AnimatedScoreRingState extends State<_AnimatedScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedScoreRing old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _animation = Tween<double>(begin: _animation.value, end: widget.score / 100)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.score >= 70
        ? const Color(0xFF4ADE80)
        : widget.score >= 40
            ? AppTheme.amber
            : const Color(0xFFF87171);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _RingPainter(progress: _animation.value, ringColor: ringColor),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_animation.value * 100).round()}%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: ringColor,
                    ),
                  ),
                  Text(
                    UiStrings.get(widget.lang, 'safe'),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;

  _RingPainter({required this.progress, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 12.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
