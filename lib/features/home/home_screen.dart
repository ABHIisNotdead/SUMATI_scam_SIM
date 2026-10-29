import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/large_button.dart';
import '../../core/widgets/scam_shield_app_bar.dart';
import '../../core/widgets/pin_entry_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showFamilyPinGate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const PinEntryWidget(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      appBar: const ScamShieldAppBar(title: 'Sumati', hideExit: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accessible Language Switcher
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English', style: TextStyle(fontSize: 16))),
                  ButtonSegment(value: 'hi', label: Text('हिंदी', style: TextStyle(fontSize: 16))),
                  ButtonSegment(value: 'mr', label: Text('मराठी', style: TextStyle(fontSize: 16))),
                ],
                selected: {currentLang},
                onSelectionChanged: (Set<String> newSelection) {
                  ref.read(preferencesProvider.notifier).setLanguage(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppTheme.deepTeal,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                UiStrings.get(currentLang, 'choose_practice'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              LargeButton(
                text: UiStrings.get(currentLang, 'call_practice'),
                onPressed: () => context.go('/scam_picker'),
              ),
              const SizedBox(height: 16),
              LargeButton(
                text: UiStrings.get(currentLang, 'message_practice'),
                onPressed: () => context.go('/scam_picker'),
              ),
              const SizedBox(height: 16),
              LargeButton(
                text: UiStrings.get(currentLang, 'website_practice'),
                onPressed: () => context.go('/scam_picker'),
              ),
              const SizedBox(height: 16),
              LargeButton(
                text: UiStrings.get(currentLang, 'ask_ai'),
                backgroundColor: AppTheme.amber,
                foregroundColor: AppTheme.deepTeal,
                onPressed: () => context.go('/ask_ai'),
              ),
              const SizedBox(height: 16),
              LargeButton(
                text: UiStrings.get(currentLang, 'emergency_checklist'),
                backgroundColor: AppTheme.red,
                onPressed: () => context.go('/i_was_scammed'),
              ),
              const SizedBox(height: 48),
              
              Center(
                child: TextButton.icon(
                  onPressed: () => _showFamilyPinGate(context),
                  icon: const Icon(Icons.lock, color: AppTheme.deepTeal),
                  label: Text(
                    UiStrings.get(currentLang, 'family_dashboard'),
                    style: const TextStyle(
                      color: AppTheme.deepTeal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
