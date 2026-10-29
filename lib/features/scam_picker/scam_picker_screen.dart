import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/scenario_provider.dart';
import '../../core/models/scenario.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scam_shield_app_bar.dart';
import '../../core/widgets/practice_action_card.dart';
import '../../core/widgets/practice_tag.dart';

class ScamPickerScreen extends ConsumerStatefulWidget {
  const ScamPickerScreen({super.key});

  @override
  ConsumerState<ScamPickerScreen> createState() => _ScamPickerScreenState();
}

class _ScamPickerScreenState extends ConsumerState<ScamPickerScreen> {
  String _selectedChannel = 'all';

  void _navigateToScenario(BuildContext context, Scenario scenario) {
    String title = scenario.title;
    String persona = scenario.persona ?? "a scammer trying to trick the user";
    String initialMsg = scenario.initialMessage ?? "Hello. Please respond urgently.";

    if (scenario.channel == 'call') {
      title = "Incoming Call: ${scenario.scammerName ?? scenario.title}";
    } else if (scenario.channel == 'whatsapp') {
      title = "WhatsApp: ${scenario.scammerName ?? scenario.title}";
    } else if (scenario.channel == 'sms') {
      title = "SMS: ${scenario.scammerName ?? scenario.title}";
    } else if (scenario.channel == 'web') {
      title = "Browser Warning: ${scenario.title}";
    }

    context.push('/fake_android', extra: {
      'scenario': scenario,
      'title': title,
      'persona': persona,
      'initialMsg': initialMsg,
      'channel': scenario.channel,
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenariosAsync = ref.watch(scenarioListProvider);
    final currentLang = ref.watch(preferencesProvider).appLanguage;

    // Language label displayed on the pill
    final langLabel = {'en': 'EN', 'hi': 'हि', 'mr': 'म'}[currentLang] ?? 'EN';

    return Scaffold(
      appBar: ScamShieldAppBar(
        title: UiStrings.get(currentLang, 'choose_practice'),
        actions: [
          // Pill-shaped Language Switcher
          PopupMenuButton<String>(
            initialValue: currentLang,
            onSelected: (newLang) {
              ref.read(preferencesProvider.notifier).setLanguage(newLang);
            },
            tooltip: 'Change Language',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    langLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                ],
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'en', child: Text('🇬🇧  English')),
              PopupMenuItem(value: 'hi', child: Text('🇮🇳  हिंदी')),
              PopupMenuItem(value: 'mr', child: Text('🇮🇳  मराठी')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.family_restroom, semanticLabel: 'Family Dashboard'),
            tooltip: UiStrings.get(currentLang, 'family_dashboard'),
            onPressed: () => context.push('/family_dashboard'),
          ),
        ],
      ),
      body: Column(
        children: [
          const PracticeTag(),

          // ── Practice Category Cards ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              children: [
                PracticeActionCard(
                  icon: Icons.phone_in_talk_rounded,
                  title: UiStrings.get(currentLang, 'call_practice'),
                  subtitle: UiStrings.get(currentLang, 'call_practice_sub'),
                  color: AppTheme.primaryTeal,
                  onTap: () => setState(() => _selectedChannel = 'call'),
                ),
                const SizedBox(height: 10),
                PracticeActionCard(
                  icon: Icons.chat_bubble_rounded,
                  title: UiStrings.get(currentLang, 'message_practice'),
                  subtitle: UiStrings.get(currentLang, 'message_practice_sub'),
                  color: const Color(0xFF1565C0),
                  onTap: () => setState(() => _selectedChannel = 'whatsapp'),
                ),
                const SizedBox(height: 10),
                PracticeActionCard(
                  icon: Icons.public_rounded,
                  title: UiStrings.get(currentLang, 'website_practice'),
                  subtitle: UiStrings.get(currentLang, 'website_practice_sub'),
                  color: const Color(0xFF6A1B9A),
                  onTap: () => setState(() => _selectedChannel = 'web'),
                ),
              ],
            ),
          ),

          // ── Channel Filter Tabs ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'all',
                    label: Text(UiStrings.get(currentLang, 'all')),
                  ),
                  ButtonSegment(
                    value: 'call',
                    label: Text(UiStrings.get(currentLang, 'call_practice')),
                  ),
                  ButtonSegment(
                    value: 'whatsapp',
                    label: Text(UiStrings.get(currentLang, 'message_practice')),
                  ),
                  ButtonSegment(
                    value: 'sms',
                    label: Text(UiStrings.get(currentLang, 'sms')),
                  ),
                  ButtonSegment(
                    value: 'web',
                    label: Text(UiStrings.get(currentLang, 'website_practice')),
                  ),
                ],
                selected: {_selectedChannel},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _selectedChannel = newSelection.first);
                },
              ),
            ),
          ),

          // ── Scenario List ────────────────────────────────────────────────
          Expanded(
            child: scenariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading scenarios: $err')),
              data: (scenarios) {
                final filtered = _selectedChannel == 'all'
                    ? scenarios
                    : scenarios.where((s) => s.channel == _selectedChannel).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No scenarios found for this category.',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildScenarioCard(filtered[index], currentLang),
                  ),
                );
              },
            ),
          ),

          // ── Bottom Quick Navigation ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/ask_ai'),
                    icon: const Icon(Icons.psychology, size: 20),
                    label: Text(
                      UiStrings.get(currentLang, 'ask_ai'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: AppTheme.amber,
                      foregroundColor: AppTheme.deepTeal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/i_was_scammed'),
                    icon: const Icon(Icons.shield_outlined, size: 20),
                    label: Text(
                      UiStrings.get(currentLang, 'emergency_checklist'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildScenarioCard(Scenario scenario, String currentLang) {
    final channelColor = _channelColor(scenario.channel);
    final diffLabel = UiStrings.get(currentLang, scenario.difficulty.toLowerCase());
    final chanLabel = UiStrings.get(currentLang, scenario.channel.toLowerCase());

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _navigateToScenario(context, scenario),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: channelColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_channelIcon(scenario.channel), color: channelColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildBadge(diffLabel.toUpperCase(), AppTheme.amber),
                        const SizedBox(width: 6),
                        _buildBadge(chanLabel.toUpperCase(), channelColor),
                        const SizedBox(width: 6),
                        _buildBadge(scenario.language.toUpperCase(), Colors.grey.shade600),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: channelColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _channelColor(String channel) {
    switch (channel) {
      case 'call':
        return AppTheme.primaryTeal;
      case 'whatsapp':
        return const Color(0xFF1565C0);
      case 'sms':
        return const Color(0xFFE65100);
      case 'web':
        return const Color(0xFF6A1B9A);
      default:
        return AppTheme.primaryTeal;
    }
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'call':
        return Icons.phone_in_talk_rounded;
      case 'whatsapp':
        return Icons.chat_bubble_rounded;
      case 'sms':
        return Icons.sms_rounded;
      case 'web':
        return Icons.public_rounded;
      default:
        return Icons.devices;
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
