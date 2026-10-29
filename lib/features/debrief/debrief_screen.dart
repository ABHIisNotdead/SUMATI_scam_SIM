import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/large_button.dart';
import '../../core/widgets/scam_shield_app_bar.dart';

class DebriefScreen extends ConsumerWidget {
  final String outcome;
  final String? customMessage;

  const DebriefScreen({
    super.key,
    required this.outcome,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSuccess = outcome.startsWith('success');
    final lang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      appBar: ScamShieldAppBar(title: UiStrings.get(lang, 'practice_debrief')),
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 80,
                      color: isSuccess ? AppTheme.green : AppTheme.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSuccess
                        ? UiStrings.get(lang, 'well_done_safe')
                        : UiStrings.get(lang, 'be_careful_trap'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? AppTheme.green : AppTheme.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      customMessage ?? (isSuccess
                          ? (lang == 'hi'
                              ? 'बहुत बढ़िया! आपने चेतावनी के संकेतों को पहचान लिया। असली बैंक और अधिकारी कभी भी धमकी नहीं देते।'
                              : lang == 'mr'
                                  ? 'छान! तुम्ही धोक्याचे इशारे ओळखले. खरी बँक आणि अधिकारी कधीही धमकी देत नाहीत.'
                                  : 'Great job recognizing the warning signs. Real banks and authorities will never threaten you or ask for sensitive details over an unverified call.')
                          : (lang == 'hi'
                              ? 'सावधान! ऐसे निर्देशों का पालन करने से आपके पैसे का नुकसान हो सकता था। हमेशा कॉल काटें और स्वतंत्र रूप से सत्यापन करें।'
                              : lang == 'mr'
                                  ? 'सावध राहा! अशा सूचनांचे पालन केल्यास तुमचे नुकसान झाले असते. नेहमी कॉल कट करा आणि खात्री करा.'
                                  : 'In a real situation, following these instructions could have put your accounts or money at risk. Remember: hang up and verify independently.')),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    UiStrings.get(lang, 'key_takeaways'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTakeawayRow(UiStrings.get(lang, 'takeaway_1')),
                  _buildTakeawayRow(UiStrings.get(lang, 'takeaway_2')),
                  _buildTakeawayRow(UiStrings.get(lang, 'takeaway_3')),
                  const SizedBox(height: 40),
                  LargeButton(
                    text: UiStrings.get(lang, 'practice_again'),
                    onPressed: () => context.go('/practice/call'),
                  ),
                  const SizedBox(height: 16),
                  LargeButton(
                    text: UiStrings.get(lang, 'choose_another_scam'),
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.primaryTeal,
                    onPressed: () => context.go('/scam_picker'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeawayRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: AppTheme.primaryTeal, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18))),
        ],
      ),
    );
  }
}
