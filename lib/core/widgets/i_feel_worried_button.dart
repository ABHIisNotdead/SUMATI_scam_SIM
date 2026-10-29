import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/ui_strings.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_theme.dart';
import 'large_button.dart';

class IFeelWorriedButton extends ConsumerWidget {
  const IFeelWorriedButton({super.key});

  void _showWorriedDialog(BuildContext context, String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield, color: AppTheme.green, size: 32),
            const SizedBox(width: 12),
            Text(UiStrings.get(lang, 'you_are_safe')),
          ],
        ),
        content: Text(
          UiStrings.get(lang, 'worried_body'),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              UiStrings.get(lang, 'continue_practice'),
              style: const TextStyle(fontSize: 18, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 8),
          LargeButton(
            text: UiStrings.get(lang, 'stop_practice'),
            backgroundColor: AppTheme.red,
            onPressed: () {
              context.pop();
              context.go('/home');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(preferencesProvider).appLanguage;

    return ElevatedButton.icon(
      onPressed: () => _showWorriedDialog(context, lang),
      icon: const Icon(Icons.pan_tool),
      label: Text(UiStrings.get(lang, 'i_feel_worried')),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.red,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppTheme.red, width: 2),
      ),
    );
  }
}
