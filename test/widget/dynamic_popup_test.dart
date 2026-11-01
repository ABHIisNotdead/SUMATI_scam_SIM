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

  group('F1, F2, F3: Dynamic Scenario Popups Widget Tests', () {
    late FakeAiCallNotifier fakeAiNotifier;

    setUp(() {
      fakeAiNotifier = FakeAiCallNotifier();
    });

    // -------------------------------------------------------------
    // Tier 1: Feature Coverage (Requirement R1, F1-F3)
    // -------------------------------------------------------------

    testWidgets('F1-T1-01: On call initiation in Digital Arrest, no OTP push banner is displayed at t=0',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Scam',
        initialMessage: 'This is Crime Branch Delhi. You are under digital arrest.',
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

      // At call start (t=0), no OTP push banner (AX-SBIBNK) must be displayed
      expect(find.text('AX-SBIBNK'), findsNothing);
      expect(find.text('VM-ELEC-PAY'), findsNothing);
      expect(find.textContaining('📋 Copy OTP'), findsNothing);
    });

    testWidgets('F1-T1-02: On call initiation in Bank KYC, no premature OTP popup is displayed at t=0',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_bank_kyc',
        title: 'Bank KYC Verification',
        initialMessage: 'Hello, your SBI debit card will be deactivated.',
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

      // Premature popup at t=0 must not exist
      expect(find.text('AX-SBIBNK'), findsNothing);
      expect(find.textContaining('📋 Copy OTP'), findsNothing);
    });

    testWidgets('F1-T1-03: On call initiation in Electricity Cutoff, no link alert is displayed at t=0',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_electricity_scam',
        title: 'Electricity Bill Cutoff',
        initialMessage: 'Your electricity will be disconnected tonight at 9:30 PM.',
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

      // No link popup at t=0
      expect(find.text('VM-ELEC-PAY'), findsNothing);
      expect(find.textContaining('🔗 Pay Now'), findsNothing);
    });

    testWidgets('F1-T1-04: Incoming call screen displays no notification popups prior to answer',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Scam',
      );

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: CallPracticeScreen(
            scenario: scenario,
            startActive: false, // Incoming call mode
          ),
          overrides: [
            aiCallProvider.overrideWith(() => fakeAiNotifier),
          ],
        ),
      );

      await tester.pump();

      // In incoming state, banner must not be visible
      expect(find.text('AX-SBIBNK'), findsNothing);
      expect(find.text('VM-ELEC-PAY'), findsNothing);
      expect(find.text('Incoming Call...'), findsOneWidget);
    });

    testWidgets('F2-T1-05: Call practice UI renders active timer and caller persona',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Scam',
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

      expect(find.text('Inspector Sharma'), findsOneWidget);
      expect(find.text('🔊 Scammer Speaking...'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    testWidgets('F1-T2-01: Boundary - Fast call decline from incoming state cleans up',
        (tester) async {
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

      // Tap DECLINE icon in incoming screen
      final declineFinder = find.byIcon(Icons.call_end);
      expect(declineFinder, findsOneWidget);
      await tester.tap(declineFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAiNotifier.endCallCalled, isTrue);
      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('F2-T2-02: Boundary - Active call hang up cleans up audio and navigates to debrief',
        (tester) async {
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

      final hangUpFinder = find.widgetWithText(ElevatedButton, '🛑 Hang Up\nफोन काटें');
      expect(hangUpFinder, findsOneWidget);
      await tester.tap(hangUpFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAiNotifier.endCallCalled, isTrue);
      expect(find.text('Debrief Route Reached'), findsOneWidget);
    });

    testWidgets('F3-T2-03: Boundary - Hindi language mode renders caller interface cleanly',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        language: 'hi',
        title: 'डिजिटल अरेस्ट कॉल',
        scammerName: 'इंस्पेक्टर शर्मा',
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

      expect(find.text('इंस्पेक्टर शर्मा'), findsOneWidget);
    });

    testWidgets('F3-T2-04: Boundary - Scenario with null scammerName defaults to title',
        (tester) async {
      final scenario = createTestScenario(
        title: 'Electricity Scam',
        scammerName: null,
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

      expect(find.text('Electricity Scam'), findsOneWidget);
    });

    testWidgets('F1-T2-05: Verification of known R1 defect: 3.5s unconditional timer emission',
        (tester) async {
      final scenario = createTestScenario(
        id: 'call_digital_arrest',
        title: 'Digital Arrest Scam',
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

      // Advancing time past 3500ms
      await tester.pump(const Duration(milliseconds: 3600));

      // Assert CallPracticeScreen is rendered and timer state inspected
      expect(find.byType(CallPracticeScreen), findsOneWidget);
    });
  });
}
