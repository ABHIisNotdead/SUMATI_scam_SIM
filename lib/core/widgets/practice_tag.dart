import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/ui_strings.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_theme.dart';

class PracticeTag extends ConsumerWidget {
  const PracticeTag({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(preferencesProvider).appLanguage;
    return Container(
      width: double.infinity,
      color: AppTheme.amber,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        UiStrings.get(lang, 'practice_banner'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.deepTeal,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
