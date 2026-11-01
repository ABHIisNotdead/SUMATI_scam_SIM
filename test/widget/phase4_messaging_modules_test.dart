import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/features/message_practice/providers/message_session_provider.dart';
import 'package:sumati/features/message_practice/sms_practice_screen.dart';
import 'package:sumati/features/message_practice/whatsapp_practice_screen.dart';
import 'package:sumati/features/message_practice/widgets/payload_widgets.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupMockAudioChannels();
  });
  final testScenario = Scenario(
    id: 'mseb_bill_fraud',
    language: 'en',
    title: 'Electricity Power Disconnection',
    channel: 'whatsapp',
    difficulty: 'medium',
    debriefSuccess: 'Refused to click unknown link',
    debriefFailure: 'Clicked phishing link',
    scammerName: 'Power Corp Notice (MSEB)',
    initialMessage: 'Dear consumer, your electricity will be disconnected tonight at 9:30 PM.',
  );

  group('Phase 4 Step 1: FWhatsApp Clone (Home & Chat Page)', () {
    testWidgets('Renders WhatsApp Home Page with Chats, Tabs, and Unread Count', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WhatsAppPracticeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Header and Tabs
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('CHATS'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('CALLS'), findsOneWidget);

      // Verify Recent Chats List
      expect(find.text('Power Corp Notice (MSEB)'), findsOneWidget);
      expect(find.text('Family Group (परिवार)'), findsOneWidget);
      expect(find.text('SBI Bank Customer Support'), findsOneWidget);
    });

    testWidgets('Tapping chat item opens Chat Page with Encryption Notice & Bubbles', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WhatsAppPracticeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Tap on the active drill chat
      await tester.tap(find.text('Power Corp Notice (MSEB)'));
      await tester.pumpAndSettle();

      // Verify Chat Page Header
      expect(find.text('online'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Verify End-to-End Encryption Notice
      expect(find.textContaining('Messages and calls are end-to-end encrypted'), findsOneWidget);

      // Verify Malicious Link Payload is rendered
      expect(find.byType(MaliciousLinkWidget), findsOneWidget);
    });

    testWidgets('Renders Multi-Modal AI Payloads (APK, Image, QR, Zip) in WhatsApp', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WhatsAppPracticeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Dispatch simulated multi-modal payload into WhatsApp
      container.read(messageSessionProvider.notifier).dispatchAiPayload(
        app: 'FWhatsApp',
        text: 'Download and install official update tool',
        payloadType: MessagePayloadType.apk,
        fileName: 'KSEB_Support.apk',
        fileSize: '14.2 MB',
      );

      // Open chat page
      container.read(messageSessionProvider.notifier).selectThread('wa_scam_drill');
      await tester.pumpAndSettle();

      expect(find.byType(DummyApkWidget), findsOneWidget);
      expect(find.text('KSEB_Support.apk'), findsOneWidget);
    });
  });

  group('Phase 4 Step 2: SMS Clone (Home & Chat Page)', () {
    testWidgets('Renders SMS Home Page with Material 3 headers and Start chat FAB', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmsPracticeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Header
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Search conversations'), findsOneWidget);

      // Verify SMS Headers
      expect(find.text('VM-ELEC-PAY'), findsOneWidget);
      expect(find.text('AX-SBIBNK'), findsOneWidget);
      expect(find.text('AD-UIDAI'), findsOneWidget);

      // Verify FAB
      expect(find.text('Start chat'), findsOneWidget);
    });

    testWidgets('Tapping SMS thread opens Chat Page with OTP copy button and phishing link', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SmsPracticeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Tap on VM-ELEC-PAY thread
      await tester.tap(find.text('VM-ELEC-PAY'));
      await tester.pumpAndSettle();

      // Verify Thread view
      expect(find.text('SMS • Standard Network'), findsOneWidget);
      expect(find.byType(MaliciousLinkWidget), findsOneWidget);

      // Verify OTP Detection in Bank SMS thread
      container.read(messageSessionProvider.notifier).selectThread('sms_bank');
      await tester.pumpAndSettle();

      // In sms_bank, text has OTP 589201 -> should render 'Copy OTP (589201)' button
      expect(find.text('Copy OTP (589201)'), findsOneWidget);
    });
  });

  group('Phase 4 Step 3: MessageSessionNotifier State & Actions', () {
    test('Initializes with default WhatsApp and SMS threads', () {
      final container = ProviderContainer();
      final state = container.read(messageSessionProvider);

      expect(state.whatsappThreads.isNotEmpty, isTrue);
      expect(state.smsThreads.isNotEmpty, isTrue);
      expect(state.activeThreadId, isNull);
    });

    test('sendUserReply appends message to active thread', () {
      final container = ProviderContainer();
      final notifier = container.read(messageSessionProvider.notifier);

      notifier.sendUserReply(
        app: 'FWhatsApp',
        text: 'I am not going to pay without verification.',
        threadId: 'wa_scam_drill',
      );

      final thread = container.read(messageSessionProvider).whatsappThreads.firstWhere((t) => t.id == 'wa_scam_drill');
      expect(thread.messages.last.text, 'I am not going to pay without verification.');
      expect(thread.messages.last.isUser, isTrue);
    });

    test('markThreadRead resets unread count for target thread', () {
      final container = ProviderContainer();
      final notifier = container.read(messageSessionProvider.notifier);

      final threadBefore = container.read(messageSessionProvider).whatsappThreads.firstWhere((t) => t.id == 'wa_scam_drill');
      expect(threadBefore.unreadCount > 0, isTrue);

      notifier.markThreadRead('FWhatsApp', 'wa_scam_drill');

      final threadAfter = container.read(messageSessionProvider).whatsappThreads.firstWhere((t) => t.id == 'wa_scam_drill');
      expect(threadAfter.unreadCount, 0);
    });

    test('loadScenario ingests custom scenario thread', () {
      final container = ProviderContainer();
      final notifier = container.read(messageSessionProvider.notifier);

      notifier.loadScenario(testScenario, 'FWhatsApp');
      final state = container.read(messageSessionProvider);
      expect(state.whatsappThreads.any((t) => t.id == 'active_scenario_${testScenario.id}'), isTrue);
    });
  });
}
