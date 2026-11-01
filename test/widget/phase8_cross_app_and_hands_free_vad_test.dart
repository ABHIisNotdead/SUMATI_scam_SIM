import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/providers/os_notification_provider.dart';
import 'package:sumati/features/call_practice/active_call_screen.dart';
import 'package:sumati/features/call_practice/providers/call_audio_provider.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupMockAudioChannels();
  });

  final testScenario = Scenario(
    id: 'call_digital_arrest',
    language: 'en',
    title: 'Digital Arrest Cyber Threat',
    channel: 'call',
    difficulty: 'high',
    debriefSuccess: 'Stayed safe',
    debriefFailure: 'Compromised',
    scammerName: 'Inspector Rathore',
    initialMessage: 'You are under digital arrest.',
  );

  group('Phase 8 Step 1: Cross-App Notification Routing During Active Call', () {
    test('trigger_sms event during call dispatches to OsNotificationNotifier without polluting call transcript', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final callNotifier = container.read(callAudioProvider.notifier);
      callNotifier.prepareIncomingCall(testScenario);

      // Verify initial badge is 0
      expect(container.read(osNotificationProvider).appBadges['Messages'] ?? 0, 0);

      // Backend emits cross-app trigger_sms event during call
      final smsEvent = {
        'event': 'trigger_sms',
        'target_app': 'Messages',
        'sender': 'AX-SBIBNK',
        'title': 'DEBIT CARD NOTICE',
        'body': 'Your card is frozen. Verification code: 894102',
        'badge_increment': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      await callNotifier.handleBackendMessageForTesting(jsonEncode(smsEvent));

      // 1. Must dispatch directly to OsNotificationNotifier
      final osState = container.read(osNotificationProvider);
      expect(osState.appBadges['Messages'], 1);
      expect(osState.activeBanner, isNotNull);
      expect(osState.activeBanner?.title, 'DEBIT CARD NOTICE');
      expect(osState.activeBanner?.body, 'Your card is frozen. Verification code: 894102');

      // 2. Must NOT pollute active call transcript or latestAiReply with the SMS payload
      final callState = container.read(callAudioProvider);
      expect(callState.latestAiReply, isNot(contains('DEBIT CARD NOTICE')));
      expect(callState.latestAiReply, isNot(contains('Verification code: 894102')));
    });

    test('trigger_whatsapp event during call updates FWhatsApp badge and shows banner', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final callNotifier = container.read(callAudioProvider.notifier);
      callNotifier.prepareIncomingCall(testScenario);

      expect(container.read(osNotificationProvider).appBadges['FWhatsApp'] ?? 0, 0);

      final waEvent = {
        'event': 'trigger_whatsapp',
        'target_app': 'FWhatsApp',
        'sender': 'CBI Mumbai Cell',
        'title': 'LEGAL NOTICE ATTACHED',
        'body': 'Download warrant file immediately.',
        'badge_increment': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      await callNotifier.handleBackendMessageForTesting(jsonEncode(waEvent));

      final osState = container.read(osNotificationProvider);
      expect(osState.appBadges['FWhatsApp'], 1);
      expect(osState.activeBanner?.title, 'LEGAL NOTICE ATTACHED');

      final callState = container.read(callAudioProvider);
      expect(callState.latestAiReply, isNot(contains('LEGAL NOTICE ATTACHED')));
    });
  });

  group('Phase 8 Step 2: Passive Pulsing Visualizer Ring & Hands-Free VAD', () {
    testWidgets('ActiveCallScreen renders passive pulsing visualizer ring and MIC HOT indicator', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set call status to active and listening (mic hot)
      container.read(callAudioProvider.notifier).prepareIncomingCall(testScenario);
      container.read(callAudioProvider.notifier).setActiveCallForTesting(isListening: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ActiveCallScreen(
              scenario: testScenario,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Caller details & Timer
      expect(find.text('Inspector Rathore'), findsOneWidget);

      // Verify Passive Audio Activity Indicator
      expect(find.byType(AnimatedBuilder), findsWidgets);

      // Verify Passive Pulsing Status Pill indicates mic is hot
      expect(find.text('MIC HOT • Speak hands-free (VAD Active)'), findsOneWidget);

      // No manual 'Tap to Speak' button exists
      expect(find.text('Tap to Speak'), findsNothing);
    });
  });
}
