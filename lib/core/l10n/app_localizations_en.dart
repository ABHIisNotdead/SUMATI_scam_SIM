// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sumati';

  @override
  String get homeWelcome => 'Welcome back';

  @override
  String get choosePractice => 'Choose a Practice';

  @override
  String get familyDashboard => 'Family Dashboard';

  @override
  String get emergencyChecklist => 'Emergency Checklist';

  @override
  String get askAi => 'Ask AI Checker';

  @override
  String get roleSenior => 'I am a Senior (Practice)';

  @override
  String get roleFamily => 'I am a Family Member (Setup)';
}
