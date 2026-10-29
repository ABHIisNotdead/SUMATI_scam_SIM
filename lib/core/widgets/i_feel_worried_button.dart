import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/ui_strings.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_theme.dart';

class IFeelWorriedButton extends ConsumerWidget {
  const IFeelWorriedButton({super.key});

  void _showWorriedDialog(BuildContext context, String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                UiStrings.get(lang, 'you_are_safe'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          UiStrings.get(lang, 'worried_body'),
          style: const TextStyle(fontSize: 16, height: 1.45, color: AppTheme.onSurfaceVariant),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    context.pop();
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tertiary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    UiStrings.get(lang, 'stop_practice'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    UiStrings.get(lang, 'continue_practice'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(preferencesProvider).appLanguage;

    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _showWorriedDialog(context, lang),
        icon: const Icon(Icons.pan_tool_rounded, size: 20),
        label: Text(
          UiStrings.get(lang, 'i_feel_worried'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.tertiary,
          side: const BorderSide(color: AppTheme.tertiary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
      ),
    );
  }
}
