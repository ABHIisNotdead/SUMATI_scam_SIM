import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sumati/core/models/simulation_result.dart';
import 'package:sumati/core/services/user_sync_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupMockAudioChannels();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SimulationResultAdapter());
    }
    await initTestHive();
  });

  setUp(() async {
    final prefBox = Hive.box('preferences');
    await prefBox.clear();
    final resBox = Hive.box('simulation_results');
    await resBox.clear();
  });

  group('Phase 1: Family Connect PIN & Historical Sync Tests', () {
    test('getSavedPin returns null when user has not saved profile yet', () {
      expect(UserSyncService.getSavedPin(), isNull);
      expect(UserSyncService.getOrCreatePin(), equals('----'));
    });

    test('getSavedPin returns database PIN after profile is saved', () async {
      final prefBox = Hive.box('preferences');
      await prefBox.put('userPhone', '9820123456');
      await prefBox.put('userPin', '7492');

      expect(UserSyncService.getSavedPin(), equals('7492'));
      expect(UserSyncService.getOrCreatePin(), equals('7492'));
    });

    test('syncHistoricalDrills with empty phone returns 0 immediately', () async {
      final count = await UserSyncService.syncHistoricalDrills('');
      expect(count, equals(0));
    });

    test('syncHistoricalDrills with empty simulation_results box returns 0', () async {
      final count = await UserSyncService.syncHistoricalDrills('9820123456');
      expect(count, equals(0));
    });

    test('simulation_results stores historical drills properly for batch sync', () async {
      final resBox = Hive.box('simulation_results');
      
      // Simulate drills run before senior saved phone number
      final drill1 = SimulationResult(
        id: 'drill_1',
        scenarioTitle: 'Electricity Cutoff Fraud',
        channel: 'call',
        status: 'deflected',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final drill2 = SimulationResult(
        id: 'drill_2',
        scenarioTitle: 'Fake CBI Digital Arrest',
        channel: 'call',
        status: 'deflected',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await resBox.add(drill1);
      await resBox.add(drill2);

      expect(resBox.length, equals(2));
      final first = resBox.getAt(0) as SimulationResult;
      expect(first.scenarioTitle, equals('Electricity Cutoff Fraud'));
      expect(first.isAvoided, isTrue);
    });
  });
}
