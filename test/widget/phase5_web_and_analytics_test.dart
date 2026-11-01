import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/providers/os_notification_provider.dart';
import 'package:sumati/features/debrief/debrief_screen.dart';
import 'package:sumati/features/web_practice/templates/digital_arrest_template.dart';
import 'package:sumati/features/web_practice/templates/electricity_payment_template.dart';
import 'package:sumati/features/web_practice/templates/kyc_verification_template.dart';
import 'package:sumati/features/web_practice/templates/virus_alert_template.dart';
import 'package:sumati/features/web_practice/web_practice_screen.dart';
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

  group('Phase 5 Step 1 & 2: Web Practice Screen & Phishing Templates', () {
    testWidgets('WebPracticeScreen renders Chrome top bar with Not Secure SSL indicator', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WebPracticeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Red "Not Secure" SSL warning badge
      expect(find.text('Not Secure'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Verify default KycVerificationTemplate renders inside browser
      expect(find.text('Global Citizen Bank'), findsOneWidget);
      expect(find.text('Customer Re-KYC Verification Portal'), findsOneWidget);
      expect(find.textContaining('SIMULATION ONLY'), findsOneWidget);
    });

    testWidgets('KycVerificationTemplate requests National ID and OTP, triggers onCompromise', (tester) async {
      bool compromised = false;
      List<String> leakedItems = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KycVerificationTemplate(
              onCompromise: (reason, leaks) {
                compromised = true;
                leakedItems = leaks;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('6-Digit One Time Password (OTP)'), findsOneWidget);
      expect(find.textContaining('SIMULATION ONLY'), findsOneWidget);

      // Submit form
      final submitBtn = find.text('Verify Credentials & Unfreeze Account');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);

      expect(compromised, isTrue);
      expect(leakedItems.any((l) => l.contains('Banking OTP')), isTrue);
    });

    testWidgets('ElectricityPaymentTemplate has fake payment tabs and triggers onCompromise', (tester) async {
      bool compromised = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectricityPaymentTemplate(
              onCompromise: (reason, leaks) => compromised = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Metro Power Co'), findsOneWidget);
      expect(find.text('₹1,450.00'), findsOneWidget);
      expect(find.text('UPI / QR Pay'), findsOneWidget);
      expect(find.text('Debit / Credit Card'), findsOneWidget);
      expect(find.textContaining('SIMULATION ONLY'), findsOneWidget);

      // Tap pay button
      final payBtn = find.text('Pay ₹1,450.00 & Avoid Power Disconnection');
      await tester.tap(payBtn);

      expect(compromised, isTrue);
    });

    testWidgets('DigitalArrestTemplate renders countdown timer and fake escrow clearance', (tester) async {
      bool compromised = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitalArrestTemplate(
              onCompromise: (reason, leaks) => compromised = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('National Security Dept'), findsOneWidget);
      expect(find.text('Warrant Enactment In:'), findsOneWidget);
      expect(find.text('₹50,000.00 (Refundable)'), findsOneWidget);
      expect(find.textContaining('SIMULATION ONLY'), findsOneWidget);

      // Submit bail clearance
      final signBtn = find.text('Sign Clearance & Deposit ₹50,000 Escrow');
      await tester.tap(signBtn);

      expect(compromised, isTrue);
    });

    testWidgets('web_digital_lock scenario renders DigitalArrestTemplate with law enforcement lock url', (tester) async {
      final scenario = Scenario(
        id: 'web_digital_lock',
        language: 'en',
        title: 'Police Digital Device Lock',
        channel: 'web',
        difficulty: 'hard',
        debriefSuccess: 'Success',
        debriefFailure: 'Failure',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: WebPracticeScreen(scenario: scenario),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DigitalArrestTemplate), findsOneWidget);
      expect(find.text('National Security Dept'), findsOneWidget);
      expect(find.textContaining('device-lock'), findsOneWidget);
    });

    testWidgets('web_virus_download scenario renders VirusAlertTemplate with malware apk download', (tester) async {
      final scenario = Scenario(
        id: 'web_virus_download',
        language: 'en',
        title: 'Fake Virus Alert & Harmful APK',
        channel: 'web',
        difficulty: 'medium',
        debriefSuccess: 'Success',
        debriefFailure: 'Failure',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: WebPracticeScreen(scenario: scenario),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirusAlertTemplate), findsOneWidget);
      expect(find.text('Android Security Scanner'), findsOneWidget);
      expect(find.textContaining('scan-results'), findsOneWidget);
      expect(find.text('⬇️ DOWNLOAD CLEANER APK NOW'), findsOneWidget);
    });

    testWidgets('web_bank_login scenario renders KycVerificationTemplate with NetBanking login portal', (tester) async {
      final scenario = Scenario(
        id: 'web_bank_login',
        language: 'en',
        title: 'Urgent Bank NetBanking Update',
        channel: 'web',
        difficulty: 'easy',
        debriefSuccess: 'Success',
        debriefFailure: 'Failure',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: WebPracticeScreen(scenario: scenario),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(KycVerificationTemplate), findsOneWidget);
      expect(find.text('Global Citizen Bank'), findsOneWidget);
      expect(find.textContaining('login'), findsOneWidget);
    });
  });

  group('Phase 5 Step 3: Post-Scam Analytics Report Dashboard (Debrief)', () {
    testWidgets('DebriefScreen renders The Hook, The Leak, and The Giveaway analytics cards', (tester) async {
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'failure:compromised',
            hook: 'Urgency Trap: Threatened to disconnect electricity within 2 hours.',
            leak: 'Submitted OTP 589201 and Credit Card number.',
            giveaway: 'Not Secure HTTP URL and mismatching official agency domain.',
          ),
        ),
      );
      await tester.pump();

      // Verify Section Header
      expect(find.text('🔍 Post-Scam Analytics Report'), findsOneWidget);

      // Verify The Hook
      expect(find.text('The Hook (मनोवैज्ञानिक चाल)'), findsOneWidget);
      expect(find.text('Urgency Trap: Threatened to disconnect electricity within 2 hours.'), findsOneWidget);

      // Verify The Leak
      expect(find.text('The Leak (लीक हुई संवेदनशील जानकारी)'), findsOneWidget);
      expect(find.text('Submitted OTP 589201 and Credit Card number.'), findsOneWidget);

      // Verify The Giveaway
      expect(find.text('The Giveaway (पहचान के मुख्य संकेत)'), findsOneWidget);
      expect(find.text('Not Secure HTTP URL and mismatching official agency domain.'), findsOneWidget);

      // Verify Voice Audio Guidance Bar
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    });

    testWidgets('DebriefScreen resets all OS notification badges and dismisses banner on entry', (tester) async {
      final container = ProviderContainer();

      // Pre-set badges in OsNotificationProvider
      container.read(osNotificationProvider.notifier).handleCrossAppEvent({
        'event': 'trigger_notification',
        'target_app': 'Messages',
        'sender': 'Alert',
        'title': 'Test',
        'body': 'Test unread badge',
        'badge_increment': 4,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      expect(container.read(osNotificationProvider).appBadges['Messages'], 4);

      // Enter Debrief Screen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: createTestAppWithRouter(
            child: const DebriefScreen(
              outcome: 'success:deflected',
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify badges have been reset to 0
      final badges = container.read(osNotificationProvider).appBadges;
      expect(badges['Messages'], 0);
      expect(badges['Phone'], 0);
      expect(badges['FWhatsApp'], 0);
      expect(badges['Browser'], 0);
      expect(container.read(osNotificationProvider).activeBanner, isNull);
    });
  });
}
