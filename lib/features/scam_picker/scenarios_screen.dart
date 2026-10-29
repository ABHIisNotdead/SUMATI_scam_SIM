import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/models/scenario.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/scenario_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';

class ScenariosScreen extends ConsumerStatefulWidget {
  final String? initialChannel;

  const ScenariosScreen({super.key, this.initialChannel});

  @override
  ConsumerState<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends ConsumerState<ScenariosScreen> {
  late String _selectedChannel;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel ?? 'all';
  }

  @override
  void didUpdateWidget(covariant ScenariosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialChannel != null && widget.initialChannel != oldWidget.initialChannel) {
      setState(() {
        _selectedChannel = widget.initialChannel!;
      });
    }
  }

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

    final String pageTitle;
    if (currentLang == 'hi') {
      switch (_selectedChannel) {
        case 'call':
          pageTitle = 'कॉल अभ्यास (Call Practice)';
          break;
        case 'whatsapp':
          pageTitle = 'व्हाट्सएप अभ्यास (WhatsApp Practice)';
          break;
        case 'sms':
          pageTitle = 'एसएमएस अभ्यास (SMS Practice)';
          break;
        case 'web':
          pageTitle = 'वेबसाइट अभ्यास (Website Practice)';
          break;
        default:
          pageTitle = 'सारे अभ्यास (All Scenarios)';
      }
    } else if (currentLang == 'mr') {
      switch (_selectedChannel) {
        case 'call':
          pageTitle = 'कॉल सराव (Call Practice)';
          break;
        case 'whatsapp':
          pageTitle = 'व्हॉट्सअ‍ॅप सराव (WhatsApp Practice)';
          break;
        case 'sms':
          pageTitle = 'एसएमएस सराव (SMS Practice)';
          break;
        case 'web':
          pageTitle = 'वेबसाइट सराव (Website Practice)';
          break;
        default:
          pageTitle = 'सर्व सराव (All Scenarios)';
      }
    } else {
      switch (_selectedChannel) {
        case 'call':
          pageTitle = 'Call Practice Scenarios';
          break;
        case 'whatsapp':
          pageTitle = 'WhatsApp Practice Scenarios';
          break;
        case 'sms':
          pageTitle = 'SMS Practice Scenarios';
          break;
        case 'web':
          pageTitle = 'Website Practice Scenarios';
          break;
        default:
          pageTitle = 'All Practice Scenarios';
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary, size: 26),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          pageTitle,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Safety Ribbon
          const PracticeTag(),

          Expanded(
            child: scenariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (scenarios) {
                final filtered = _selectedChannel == 'all'
                    ? scenarios
                    : scenarios.where((s) => s.channel == _selectedChannel).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Horizontal Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All (${scenarios.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('call', 'Calls (${scenarios.where((s) => s.channel == 'call').length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('whatsapp', 'WhatsApp (${scenarios.where((s) => s.channel == 'whatsapp').length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('sms', 'SMS (${scenarios.where((s) => s.channel == 'sms').length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('web', 'Website (${scenarios.where((s) => s.channel == 'web').length})'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: const Text('No scenarios found in this category.', style: TextStyle(fontSize: 16)),
                      )
                    else
                      ...filtered.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildScenarioCard(s, currentLang),
                          )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String channelKey, String label) {
    final isSelected = _selectedChannel == channelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedChannel = channelKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryContainer : const Color(0xFFD6DDD8),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard(Scenario scenario, String currentLang) {
    final isHard = scenario.difficulty.toLowerCase() == 'hard';
    final isMedium = scenario.difficulty.toLowerCase() == 'medium';

    final diffKey = isHard ? 'hard' : (isMedium ? 'medium' : 'easy');
    final diffText = UiStrings.get(currentLang, diffKey);
    final diffLabel = currentLang == 'en' ? diffText : '${diffKey.toUpperCase()} • $diffText';

    final channelIcon = scenario.channel == 'call'
        ? Icons.phone_in_talk_rounded
        : scenario.channel == 'sms'
            ? Icons.textsms_rounded
            : scenario.channel == 'web'
                ? Icons.public_rounded
                : Icons.chat_rounded;

    final channelColor = scenario.channel == 'call'
        ? const Color(0xFF00875A)
        : scenario.channel == 'sms'
            ? const Color(0xFF0B57D0)
            : scenario.channel == 'web'
                ? const Color(0xFFC62828)
                : const Color(0xFF008069);

    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToScenario(context, scenario),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: channelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(channelIcon, color: channelColor, size: 24),
              ),
              const SizedBox(width: 12),

              // Title, Tag & CTA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Difficulty Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isHard
                                ? AppTheme.tertiaryFixed
                                : isMedium
                                    ? AppTheme.secondaryFixed
                                    : AppTheme.primaryFixed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            diffLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isHard
                                  ? AppTheme.tertiary
                                  : isMedium
                                      ? AppTheme.onSecondaryContainer
                                      : AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Channel Tag
                        Text(
                          scenario.channel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),

                        // Start CTA Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                UiStrings.get(currentLang, 'start_practice'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

