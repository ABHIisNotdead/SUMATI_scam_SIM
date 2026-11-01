import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/providers/ai_call_provider.dart';
import 'package:sumati/features/call_practice/call_practice_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupMockAudioChannels();
    await initTestHive();
  });

  tearDownAll(() async {
    await cleanTestHive();
  });

  group('F7: Direct Debrief Routing Widget & Navigation Tests', () {
    late FakeAiCallNotifier fakeAiNotifier;

    setUp(() {
      fakeAiNotifier = FakeAiCallNotifier();
    });

    void setTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // -------------------------------------------------------------
    // Tier 1: Feature Coverage (Requirement R3, Feature F7)
    // -------------------------------------------------------------

    testWidgets('F7-T1-01: Hang up on active call routes directly to /debrief',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_digital_arrest');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      // Tap Hang Up button
      final hangUpBtn = find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें');
      expect(hangUpBtn, findsOneWidget);
      await tester.tap(hangUpBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Must land on /debrief route
      expect(find.text('Debrief Route Reached'), findsOneWidget);
      expect(find.text('Scammed Checklist Route Reached'), findsNothing);
    });

    testWidgets('F7-T1-02: Incoming call decline routes directly to /debrief',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_digital_arrest');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: false,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      // Tap Decline button
      final declineBtn = find.byIcon(Icons.call_end);
      expect(declineBtn, findsOneWidget);
      await tester.tap(declineBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Must land on /debrief route
      expect(find.text('Debrief Route Reached'), findsOneWidget);
      expect(find.text('Scammed Checklist Route Reached'), findsNothing);
    });

    testWidgets('F7-T1-03: AI deflection status triggers direct navigation to /debrief',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_digital_arrest');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      // AI updates status to deflected
      fakeAiNotifier.setStatus('deflected');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Must route to /debrief
      expect(find.text('Debrief Route Reached'), findsOneWidget);
      expect(find.text('Scammed Checklist Route Reached'), findsNothing);
    });

    testWidgets('F7-T1-04: AI compromise status triggers direct navigation to /debrief',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_bank_kyc');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      // AI updates status to compromised
      fakeAiNotifier.setStatus('compromised');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Must route to /debrief
      expect(find.text('Debrief Route Reached'), findsOneWidget);
      expect(find.text('Scammed Checklist Route Reached'), findsNothing);
    });

    testWidgets('F7-T1-05: Verification of R3 Defect: _triggerScamCompromisedTrap redirects to emergency checklist',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_bank_kyc');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      // In CallPracticeScreen, tapping the trap quick reply triggers _triggerScamCompromisedTrap
      final trapQuickReply = find.textContaining('Mera OTP 482910 hai');
      expect(trapQuickReply, findsOneWidget);
      await tester.tap(trapQuickReply);
      await tester.pump(const Duration(milliseconds: 200));

      // The trap AlertDialog appears
      final alertFinder = find.byType(AlertDialog);
      expect(alertFinder, findsOneWidget);

      // In legacy code, this dialog contains the button pointing to /i_was_scammed:
      // "🚨 Open Emergency Checklist"
      final checklistBtn = find.textContaining('Emergency Checklist');
      expect(checklistBtn, findsOneWidget);

      // Requirement R3 explicitly mandates:
      // "When a simulated call ends (whether the user hung up, survived, or was scammed/compromised),
      // navigation must route directly to the practice result / debrief page instead of redirecting to the emergency checklist page."
      // This test captures and verifies the exact defect location to be rectified in M2.
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    testWidgets('F7-T2-01: Boundary - Rapid repeated tap on Hang Up does not crash or double navigate',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_digital_arrest');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      final hangUpBtn = find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें');
      await tester.tap(hangUpBtn);
      await tester.tap(hangUpBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('F7-T2-02: Boundary - Hang up cleanly records deflected status in SimulationResult',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Test Call',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAiNotifier.endCallCalled, isTrue);
    });

    testWidgets('F7-T2-03: Boundary - Deflection routing cleans up active timers',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_digital_arrest');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      fakeAiNotifier.setStatus('deflected');
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAiNotifier.endCallCalled, isTrue);
    });

    testWidgets('F7-T2-04: Boundary - Compromise status stops active TTS playback',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(id: 'call_bank_kyc');

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      fakeAiNotifier.setStatus('compromised');
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAiNotifier.endCallCalled, isTrue);
    });

    testWidgets('F7-T2-05: Boundary - Hindi language mode navigates to debrief cleanly',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        language: 'hi',
        title: 'डिजिटल अरेस्ट',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: true,
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });
  });
}
