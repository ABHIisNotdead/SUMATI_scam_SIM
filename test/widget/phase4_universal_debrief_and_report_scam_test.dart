import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/models/simulation_result.dart';
import 'package:sumati/core/providers/preferences_provider.dart';
import 'package:sumati/core/services/sound_effect_service.dart';
import 'package:sumati/features/call_practice/active_call_screen.dart';
import 'package:sumati/features/call_practice/providers/call_audio_provider.dart';
import 'package:sumati/features/message_practice/whatsapp_practice_screen.dart';
import 'package:sumati/features/message_practice/sms_practice_screen.dart';
import 'package:sumati/features/web_practice/web_practice_screen.dart';
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
    final box = Hive.box('simulation_results');
    await box.clear();
  });

  void setTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Phase 3 & 4: Universal Debrief & Report Scam Across All 4 Scam Channels', () {
    testWidgets('Voice Call: Report Scam button navigates to /debrief', (tester) async {
      setTallViewport(tester);
      final scenario = Scenario(
        id: 'fake_police_call',
        language: 'en',
        title: 'Fake Police Call',
        channel: 'call',
        difficulty: 'medium',
        debriefSuccess: 'Deflected',
        debriefFailure: 'Compromised',
        scammerName: 'Delhi Police Dept',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: ActiveCallScreen(scenario: scenario),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('en')),
            soundEffectServiceProvider.overrideWithValue(FakeSoundEffectService()),
          ],
        ),
      );
      await tester.pump();

      final element = tester.element(find.byType(ActiveCallScreen));
      final container = ProviderScope.containerOf(element);
      container.read(callAudioProvider.notifier).setActiveCallForTesting(isListening: false);

      // Tap Report Scam button
      final reportBtn = find.byKey(const Key('call_report_scam_button'));
      expect(reportBtn, findsOneWidget);
      await tester.tap(reportBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));

      expect(find.text('Debrief Route Reached'), findsOneWidget);

      final box = Hive.box('simulation_results');
      expect(box.length, equals(1));
      final result = box.getAt(0) as SimulationResult;
      expect(result.status, equals('deflected'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Voice Call: Hang up button navigates to /debrief', (tester) async {
      setTallViewport(tester);
      final scenario = Scenario(
        id: 'fake_police_call_2',
        language: 'en',
        title: 'Fake Police Call',
        channel: 'call',
        difficulty: 'medium',
        debriefSuccess: 'Deflected',
        debriefFailure: 'Compromised',
        scammerName: 'Delhi Police Dept',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: ActiveCallScreen(scenario: scenario),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('en')),
            soundEffectServiceProvider.overrideWithValue(FakeSoundEffectService()),
          ],
        ),
      );
      await tester.pump();

      final element = tester.element(find.byType(ActiveCallScreen));
      final container = ProviderScope.containerOf(element);
      container.read(callAudioProvider.notifier).setActiveCallForTesting(isListening: false);

      final endBtn = find.byKey(const Key('call_end_button'));
      expect(endBtn, findsOneWidget);
      await tester.tap(endBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('WhatsApp: Report button in chat navigates to /debrief', (tester) async {
      final scenario = Scenario(
        id: 'cbi_wa_scam',
        language: 'en',
        title: 'CBI Warrant Notice',
        channel: 'whatsapp',
        difficulty: 'medium',
        debriefSuccess: 'Deflected',
        debriefFailure: 'Compromised',
        scammerName: 'CBI Cyber Cell',
        initialMessage: 'Immediate arrest warrant issued against your Aadhaar.',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: WhatsAppPracticeScreen(scenario: scenario),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('en')),
            soundEffectServiceProvider.overrideWithValue(FakeSoundEffectService()),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final reportBtn = find.byKey(const Key('whatsapp_report_scam_button'));
      expect(reportBtn, findsOneWidget);

      await tester.tap(reportBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('SMS: Report button in SMS thread navigates to /debrief', (tester) async {
      final scenario = Scenario(
        id: 'elec_sms_scam',
        language: 'en',
        title: 'Electricity Cutoff Notice',
        channel: 'sms',
        difficulty: 'medium',
        debriefSuccess: 'Deflected',
        debriefFailure: 'Compromised',
        scammerName: 'VM-ELEC-PAY',
        initialMessage: 'Electricity will be cut off tonight at 9:30 PM.',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: SmsPracticeScreen(scenario: scenario),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('en')),
            soundEffectServiceProvider.overrideWithValue(FakeSoundEffectService()),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final reportBtn = find.byKey(const Key('sms_report_scam_button'));
      expect(reportBtn, findsOneWidget);

      await tester.tap(reportBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('Web: Close & Exit button and Report Scam button navigate to /debrief', (tester) async {
      final scenario = Scenario(
        id: 'bank_kyc_web',
        language: 'en',
        title: 'Bank KYC Portal',
        channel: 'web',
        difficulty: 'medium',
        debriefSuccess: 'Deflected',
        debriefFailure: 'Compromised',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: WebPracticeScreen(scenario: scenario),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('en')),
          ],
        ),
      );
      await tester.pump();

      // Verify Close and Exit button
      final closeBtn = find.byKey(const Key('web_close_button'));
      expect(closeBtn, findsOneWidget);

      // Verify Report button
      final reportBtn = find.byKey(const Key('web_report_scam_button'));
      expect(reportBtn, findsOneWidget);

      // Tap Close button
      await tester.tap(closeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });
  });
}

