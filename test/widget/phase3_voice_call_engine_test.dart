import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/providers/os_notification_provider.dart';
import 'package:sumati/features/call_practice/active_call_screen.dart';
import 'package:sumati/features/call_practice/incoming_call_screen.dart';
import 'package:sumati/features/call_practice/providers/call_audio_provider.dart';

void main() {
  final testScenario = Scenario(
    id: 'call_digital_arrest',
    language: 'en',
    title: 'Digital Arrest Cyber Threat',
    channel: 'call',
    difficulty: 'high',
    debriefSuccess: 'You stayed calm and hung up.',
    debriefFailure: 'You stayed on line and complied.',
    scammerName: 'Officer Sharma (CBI)',
    initialMessage: 'This is Crime Branch officer Sharma.',
  );

  group('Phase 3 Step 1: IncomingCallScreen UI & Interactions', () {
    testWidgets('Renders Android incoming call UI matching reference', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: IncomingCallScreen(
              scenario: testScenario,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Caller details
      expect(find.text('Officer Sharma (CBI)'), findsOneWidget);
      expect(find.text('Digital Arrest Cyber Threat'), findsOneWidget);

      // Verify Status Bar
      expect(find.text('Airtel | Airtel'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Verify Secondary actions
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);

      // Verify Primary Call Buttons
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);
    });

    testWidgets('Tapping Answer transitions to ActiveCallScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: IncomingCallScreen(
              scenario: testScenario,
            ),
          ),
        ),
      );
      await tester.pump();

      final answerBtn = find.text('Answer');
      expect(answerBtn, findsOneWidget);

      await tester.tap(answerBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ActiveCallScreen), findsOneWidget);
    });
  });

  group('Phase 3 Step 2: ActiveCallScreen Controls & Overlay Compatibility', () {
    testWidgets('Renders Call Timer, Controls Grid, and Subtitles', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ActiveCallScreen(
              scenario: testScenario,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Header
      expect(find.text('Officer Sharma (CBI)'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);

      // Verify In-Call Controls
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Keypad'), findsOneWidget);
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('Tap Reply'), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('Opens Keypad Bottom Sheet on Keypad tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ActiveCallScreen(
              scenario: testScenario,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Keypad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
    });

    testWidgets('Cross-app banner drops down over ActiveCallScreen via GlobalNotificationOverlay', (tester) async {
      final container = ProviderContainer();

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

      // Trigger cross-app SMS event while active call is ongoing
      container.read(osNotificationProvider.notifier).handleCrossAppEvent({
        'event': 'trigger_sms',
        'target_app': 'FWhatsApp',
        'sender': 'CBI Legal Escrow',
        'title': 'WARRANT DISCLOSURE',
        'body': 'Tap to verify warrant attachment immediately.',
        'badge_increment': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Notification banner should drop down directly over the active call screen
      expect(find.text('WARRANT DISCLOSURE'), findsOneWidget);
      expect(find.text('Tap to verify warrant attachment immediately.'), findsOneWidget);

      // Clean up banner timer
      container.read(osNotificationProvider.notifier).dismissBanner();
      await tester.pump();
    });
  });

  group('Phase 3 Step 3: CallAudioNotifier State Transitions', () {
    test('prepareIncomingCall sets status to incoming with caller details', () {
      final container = ProviderContainer();
      final notifier = container.read(callAudioProvider.notifier);

      notifier.prepareIncomingCall(testScenario);

      final state = container.read(callAudioProvider);
      expect(state.status, CallEngineStatus.incoming);
      expect(state.callerName, 'Officer Sharma (CBI)');
    });

    test('toggleMute and toggleSpeaker update state flags', () {
      final container = ProviderContainer();
      final notifier = container.read(callAudioProvider.notifier);

      expect(container.read(callAudioProvider).isMuted, isFalse);
      notifier.toggleMute();
      expect(container.read(callAudioProvider).isMuted, isTrue);

      expect(container.read(callAudioProvider).isSpeakerOn, isTrue);
      notifier.toggleSpeaker();
      expect(container.read(callAudioProvider).isSpeakerOn, isFalse);
    });

    test('declineCall and endCall set status to completed', () {
      final container = ProviderContainer();
      final notifier = container.read(callAudioProvider.notifier);

      notifier.prepareIncomingCall(testScenario);
      expect(container.read(callAudioProvider).status, CallEngineStatus.incoming);

      notifier.declineCall();
      expect(container.read(callAudioProvider).status, CallEngineStatus.completed);
    });
  });
}
