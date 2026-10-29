import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/scam_shield_app_bar.dart';
import '../../core/widgets/large_button.dart';

class ScammedChecklistScreen extends ConsumerStatefulWidget {
  const ScammedChecklistScreen({super.key});

  @override
  ConsumerState<ScammedChecklistScreen> createState() => _ScammedChecklistScreenState();
}

class _ScammedChecklistScreenState extends ConsumerState<ScammedChecklistScreen> {
  final List<bool> _completedSteps = [false, false, false, false];

  void _toggleStep(int index) {
    setState(() {
      _completedSteps[index] = !_completedSteps[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(preferencesProvider).appLanguage;

    final steps = [
      {
        'title': UiStrings.get(lang, 'step_helpline_title'),
        'subtitle': UiStrings.get(lang, 'step_helpline_sub'),
      },
      {
        'title': UiStrings.get(lang, 'step_bank_title'),
        'subtitle': UiStrings.get(lang, 'step_bank_sub'),
      },
      {
        'title': UiStrings.get(lang, 'step_pin_title'),
        'subtitle': UiStrings.get(lang, 'step_pin_sub'),
      },
      {
        'title': UiStrings.get(lang, 'step_complaint_title'),
        'subtitle': UiStrings.get(lang, 'step_complaint_sub'),
      },
    ];

    return Scaffold(
      appBar: ScamShieldAppBar(title: UiStrings.get(lang, 'emergency_checklist')),
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.red, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emergency, color: AppTheme.red, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        UiStrings.get(lang, 'act_fast_title'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        UiStrings.get(lang, 'act_fast_sub'),
                        style: const TextStyle(fontSize: 17),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  UiStrings.get(lang, 'immediate_steps'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: CheckboxListTile(
                      value: _completedSteps[index],
                      onChanged: (val) => _toggleStep(index),
                      activeColor: AppTheme.primaryTeal,
                      title: Text(
                        step['title']!,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(step['subtitle']!, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                LargeButton(
                  text: UiStrings.get(lang, 'call_1930'),
                  backgroundColor: AppTheme.red,
                  onPressed: () {
                    // Future implementation: url_launcher to launch tel:1930
                  },
                ),
                const SizedBox(height: 16),
                LargeButton(
                  text: UiStrings.get(lang, 'return_home'),
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppTheme.primaryTeal,
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
