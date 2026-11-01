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

  group('Tiers 3 & 4: E2E Call Simulation & Cross-Feature Integration Tests', () {
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
    // Tier 3: Cross-Feature Interactions
    // -------------------------------------------------------------

    testWidgets('CF1: Digital Arrest Full Flow: No OTP -> AI Speaks -> User Turn -> Hang Up -> Direct Debrief',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Scam',
        scammerName: 'Inspector Sharma',
        initialMessage: 'You are accused of money laundering. Do not disconnect.',
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

      // Step 1: Verify Call Start - No OTP or Link push banner
      expect(find.text('AX-SBIBNK'), findsNothing);
      expect(find.text('VM-ELEC-PAY'), findsNothing);

      // Step 2: Verify AI Speaking phase
      expect(find.text('Inspector Sharma'), findsOneWidget);
      expect(find.text('🔊 Scammer Speaking...'), findsOneWidget);

      // Step 3: Scammer completes speech -> User turn begins
      fakeAiNotifier.setSpeaking(false);
      await tester.pump();
      expect(find.text('📞 Connected • Listening'), findsOneWidget);

      // Step 4: User recognizes scam and taps Hang Up
      final hangUpBtn = find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें');
      expect(hangUpBtn, findsOneWidget);
      await tester.tap(hangUpBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Step 5: Direct debrief routing achieved without emergency checklist detour
      expect(find.text('Debrief Route Reached'), findsOneWidget);
      expect(find.text('Scammed Checklist Route Reached'), findsNothing);
    });

    testWidgets('CF2: Hands-Free Scammer Speech Completion transitions to listening without button touch',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        scammerName: 'Inspector Sharma',
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

      // State is speaking
      expect(fakeAiNotifier.state.isSpeaking, isTrue);

      // AI speech completes naturally
      fakeAiNotifier.setSpeaking(false);
      await tester.pump();

      // State transitions to listening turn
      expect(fakeAiNotifier.state.isSpeaking, isFalse);
      expect(find.text('📞 Connected • Listening'), findsOneWidget);

      // Manual mic button remains available as fallback
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('CF3: Manual Choice Sheet Fallback during active call',
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
      expect(find.textContaining('Speak or Choose Response'), findsOneWidget);
    });

    testWidgets('CF4: AI deflection event cleanly completes simulation drill',
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

      // Backend AI evaluates deflection
      fakeAiNotifier.updateState(
        fakeAiNotifier.state.copyWith(
          status: 'deflected',
          evaluation: 'User resisted fake police demands.',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Direct debrief reached
      expect(find.text('Debrief Route Reached'), findsOneWidget);
      expect(fakeAiNotifier.endCallCalled, isTrue);
    });

    testWidgets('CF5: Incoming call answered transitions to active drill with audio controls',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        scammerName: 'Inspector Sharma',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: false, // Incoming state
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Incoming Call...'), findsOneWidget);

      // Tap Green Answer button (Icons.call with size 36)
      final answerFinder = find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.call && w.size == 36);
      expect(answerFinder, findsOneWidget);
      await tester.tap(answerFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Should now be in active call state
      expect(find.text('Inspector Sharma'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Tier 4: Real-World Scenarios
    // -------------------------------------------------------------

    testWidgets('RW1: Real-World Digital Arrest Coercion Simulation',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Scam',
        persona: 'Officer investigating money laundering from Delhi Crime Branch',
        scammerName: 'Inspector Sharma',
        initialMessage:
            'This is Crime Branch Delhi. A non-bailable arrest warrant has been issued in your name.',
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

      // Non-OTP scenario: verify no bank OTP banner
      expect(find.text('AX-SBIBNK'), findsNothing);

      // Verify authentic scammer persona and dialogue displayed
      expect(find.text('Inspector Sharma'), findsOneWidget);

      // Senior challenges officer and hangs up safely
      await tester.tap(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('RW2: Real-World Electricity Cutoff Urgency Simulation',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_electricity_scam',
        title: 'Electricity Bill Cutoff',
        scammerName: 'Power Dept Officer',
        initialMessage:
            'Your electricity power line will be disconnected tonight at 9:30 PM.',
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

      // Verify no premature link popup at t=0
      expect(find.text('VM-ELEC-PAY'), findsNothing);

      // Verify persona
      expect(find.text('Power Dept Officer'), findsOneWidget);

      // Senior safely hangs up
      await tester.tap(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('RW3: Real-World Bank KYC Simulation with Direct Protective Debrief',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_bank_kyc',
        title: 'Bank KYC Verification',
        scammerName: 'SBI Customer Support',
        initialMessage: 'Dear customer, your bank account is blocked due to incomplete KYC.',
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

      expect(find.text('SBI Customer Support'), findsOneWidget);

      // Deflect the scam safely
      fakeAiNotifier.setStatus('deflected');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('RW4: Real-World Hindi Native Language Simulation Journey',
        (tester) async {
      setTallViewport(tester);
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        language: 'hi',
        title: 'डिजिटल अरेस्ट कॉल',
        scammerName: 'इंस्पेक्टर शर्मा',
        initialMessage: 'यह दिल्ली पुलिस क्राइम ब्रांच है। आप डिजिटल अरेस्ट में हैं।',
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

      // Caller details rendered in Devanagari
      expect(find.text('इंस्पेक्टर शर्मा'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'), findsOneWidget);

      // Hang up
      await tester.tap(find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });
  });
}
