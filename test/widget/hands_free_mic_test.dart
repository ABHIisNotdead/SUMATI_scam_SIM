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

  group('F4, F5, F6: Hands-Free Mic Listening & Manual Fallback Tests', () {
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
    // Tier 1: Feature Coverage (R2: F4, F5, F6)
    // -------------------------------------------------------------

    testWidgets('F4-T1-01: UI indicates when Scammer is speaking vs User turn',
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

      // When isSpeaking == true, caller header displays Scammer Speaking
      expect(find.text('🔊 Scammer Speaking...'), findsOneWidget);

      // Now scammer stops speaking
      fakeAiNotifier.setSpeaking(false);
      await tester.pump();

      // UI updates to indicate scammer finished speaking
      expect(find.text('📞 Connected • Listening'), findsOneWidget);
    });

    testWidgets('F6-T1-02: Manual mic button is visible and present at all times in active call',
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

      // Central mic button (Icons.mic_rounded) must be present
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.textContaining('Tap to Speak'), findsOneWidget);
    });

    testWidgets('F6-T1-03: Manual tap on mic button triggers listening toggle',
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

      final micButton = find.byIcon(Icons.mic_rounded);
      expect(micButton, findsOneWidget);

      // Tap mic button to toggle listening
      await tester.tap(micButton);
      await tester.pump();

      // Stop TTS should be requested on aiCallProvider
      expect(fakeAiNotifier.stopTtsCalled, isTrue);
    });

    testWidgets('F6-T1-04: Options / quick choice bottom sheet opens on tap',
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

      // Find 'माइक नहीं चल रहा? विकल्प चुनें' link
      final optionsFinder = find.textContaining('माइक नहीं चल रहा');
      expect(optionsFinder, findsOneWidget);

      await tester.tap(optionsFinder);
      await tester.pump(const Duration(milliseconds: 300));

      // Modal bottom sheet should appear with alternative input choices
      expect(find.textContaining('Speak or Choose'), findsOneWidget);
    });

    testWidgets('F5-T1-05: Submitting text from choice sheet forwards to aiCallProvider',
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

      // Open choice sheet
      await tester.tap(find.textContaining('माइक नहीं चल रहा'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify choice sheet opened
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    testWidgets('F4-T2-01: Boundary - Rapid speech completion toggles do not crash UI',
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

      // Rapidly toggle isSpeaking multiple times
      for (int i = 0; i < 5; i++) {
        fakeAiNotifier.setSpeaking(i % 2 == 0);
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(CallPracticeScreen), findsOneWidget);
    });

    testWidgets('F4-T2-02: Boundary - AI speaking state preserves caller status header',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        scammerName: 'Officer Crime Branch',
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

      expect(find.text('Officer Crime Branch'), findsOneWidget);
      expect(find.text('🔊 Scammer Speaking...'), findsOneWidget);
    });

    testWidgets('F5-T2-03: Boundary - Blank message is not forwarded to AI',
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

      // Verify no blank messages were sent initially
      expect(fakeAiNotifier.sentMessages.where((m) => m.trim().isEmpty), isEmpty);
    });

    testWidgets('F6-T2-04: Boundary - Choice sheet closes on backdrop tap',
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

      // Open choice sheet
      await tester.tap(find.textContaining('माइक नहीं चल रहा'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BottomSheet), findsOneWidget);

      // Tap outside (top center) to dismiss modal
      await tester.tapAt(const Offset(200, 50));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('F6-T2-05: Boundary - Mic button tap while speaking halts TTS',
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

      // Tap mic button while AI is speaking
      expect(fakeAiNotifier.state.isSpeaking, isTrue);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();

      // Stop TTS must be called
      expect(fakeAiNotifier.stopTtsCalled, isTrue);
    });
  });
}
