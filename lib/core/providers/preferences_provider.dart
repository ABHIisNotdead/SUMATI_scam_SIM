import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'settings_provider.dart';

class AppPreferences {
  final bool isFirstLaunch;
  final String appLanguage;

  const AppPreferences({
    this.isFirstLaunch = true,
    this.appLanguage = 'en',
  });

  AppPreferences copyWith({
    bool? isFirstLaunch,
    String? appLanguage,
  }) {
    return AppPreferences(
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      appLanguage: appLanguage ?? this.appLanguage,
    );
  }
}

class PreferencesNotifier extends Notifier<AppPreferences> {
  Box get _box => Hive.box('preferences');

  @override
  AppPreferences build() {
    final box = Hive.isBoxOpen('preferences') ? _box : null;
    final isFirst = box?.get('isFirstLaunch', defaultValue: true) as bool? ?? true;
    final lang = box?.get('appLanguage', defaultValue: 'en') as String? ?? 'en';

    return AppPreferences(
      isFirstLaunch: isFirst,
      appLanguage: lang,
    );
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isFirstLaunch: false);
    if (Hive.isBoxOpen('preferences')) {
      await _box.put('isFirstLaunch', false);
    }
  }

  Future<void> setLanguage(String lang) async {
    if (lang != 'en' && lang != 'hi' && lang != 'mr') return;
    state = state.copyWith(appLanguage: lang);
    if (Hive.isBoxOpen('preferences')) {
      await _box.put('appLanguage', lang);
    }
    // Synchronize with localeProvider so MaterialApp delegates update
    ref.read(localeProvider.notifier).updateLocale(lang);
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, AppPreferences>(() {
  return PreferencesNotifier();
});

