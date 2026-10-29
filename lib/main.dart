import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/l10n/app_localizations.dart';
import 'core/models/simulation_result.dart';
import 'core/providers/preferences_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Hive
  await Hive.initFlutter();

  // 2. Register SimulationResultAdapter
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(SimulationResultAdapter());
  }

  // 3. Open generic boxes
  await Hive.openBox('simulation_results');
  await Hive.openBox('preferences');

  // 4. Initialize storage service (settings & secure storage)
  await StorageService.init();

  runApp(const ProviderScope(child: SumatiApp()));
}

class SumatiApp extends ConsumerWidget {
  const SumatiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final preferences = ref.watch(preferencesProvider);
    final currentLocale = Locale(preferences.appLanguage);

    return MaterialApp.router(
      title: 'Sumati',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: currentLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
