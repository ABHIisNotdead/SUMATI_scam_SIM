import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'preferences_provider.dart';
import '../models/scenario.dart';

final scenarioListProvider = FutureProvider<List<Scenario>>((ref) async {
  final currentLocale = ref.watch(preferencesProvider).appLanguage;
  final Map<String, Scenario> scenarioMap = {};

  // 1. Primary Source: Load all scenarios from the central file: assets/scenarios/scenarios.json
  try {
    final String masterJson = await rootBundle.loadString('assets/scenarios/scenarios.json');
    final List<dynamic> list = jsonDecode(masterJson);
    for (var item in list) {
      if (item is Map<String, dynamic>) {
        final s = Scenario.fromJson(item);
        scenarioMap[s.id] = s;
      }
    }
  } catch (e) {
    debugPrint('Could not load central scenarios.json: $e');
  }

  // 2. Locale Overlay: If user selected Hindi or Marathi, overlay localized files if available
  if (currentLocale != 'en') {
    for (String id in scenarioMap.keys.toList()) {
      final String path = 'assets/scenarios/$currentLocale/$id.json';
      try {
        final String jsonString = await rootBundle.loadString(path);
        scenarioMap[id] = Scenario.fromJson(jsonDecode(jsonString));
      } catch (_) {
        // Keeps English default from master scenarios.json
      }
    }
  }

  return scenarioMap.values.toList();
});
