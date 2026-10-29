// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'सुमति';

  @override
  String get homeWelcome => 'वापसी पर स्वागत है';

  @override
  String get choosePractice => 'अभ्यास चुनें';

  @override
  String get familyDashboard => 'परिवार डैशबोर्ड';

  @override
  String get emergencyChecklist => 'आपातकालीन चेकलिस्ट';

  @override
  String get askAi => 'एआई से पूछें';

  @override
  String get roleSenior => 'मैं एक वरिष्ठ नागरिक हूँ (अभ्यास)';

  @override
  String get roleFamily => 'मैं परिवार का सदस्य हूँ (सेटअप)';
}
