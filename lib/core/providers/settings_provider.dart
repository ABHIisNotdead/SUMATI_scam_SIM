import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Default to English. Later, we can load this from Hive local storage.
    return const Locale('en');
  }

  void setLocale(Locale locale) {
    state = locale;
  }

  void updateLocale(String languageCode) {
    state = Locale(languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() => LocaleNotifier());

class TextScaleNotifier extends Notifier<double> {
  @override
  double build() {
    return 18.0;
  }

  void updateScale(double scale) {
    state = scale;
  }
}

final textScaleProvider = NotifierProvider<TextScaleNotifier, double>(() => TextScaleNotifier());
