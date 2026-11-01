import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/providers/os_notification_provider.dart';
import 'package:sumati/core/services/sound_effect_service.dart';
import 'package:sumati/core/utils/simulation_trigger.dart';
import 'package:sumati/features/call_practice/call_practice_screen.dart';
import 'package:sumati/features/call_practice/incoming_call_screen.dart';
import 'package:sumati/features/call_practice/providers/call_audio_provider.dart';
import 'package:sumati/features/message_practice/providers/message_session_provider.dart';
import '../helpers/test_helpers.dart';

class FakeCallAudioNotifier extends CallAudioNotifier {
  final SoundEffectService? fakeSoundService;
  FakeCallAudioNotifier(super.ref, {this.fakeSoundService}) : super(soundService: fakeSoundService);

  @override
  Future<void> answerCall({
    required Scenario? scenario,
    String lang = 'en',
    String persona = 'a scammer attempting fraud',
    String initialMsg = 'Hello. Please respond urgently.',
  }) async {
    fakeSoundService?.stopCallRingtone();
    state = state.copyWith(status: CallEngineStatus.active);
  }

  @override
  void declineCall() {
    fakeSoundService?.stopCallRingtone();
    state = state.copyWith(status: CallEngineStatus.idle);
  }
}

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

  group('Call and Message Ringtone Tests', () {
    testWidgets('IncomingCallScreen plays ringtone on enter and stops on Answer', (tester) async {
      final fakeSound = FakeSoundEffectService();

      await tester.pumpWidget(
        createTestAppWithRouter(
          overrides: [
            soundEffectServiceProvider.overrideWithValue(fakeSound),
            callAudioProvider.overrideWith((ref) => FakeCallAudioNotifier(ref, fakeSoundService: fakeSound)),
          ],
          child: IncomingCallScreen(
            scenario: testScenario,
          ),
        ),
      );
      await tester.pump();

      // Ringtone should have started playing
      expect(fakeSound.playRingtoneCount, equals(1));
      expect(fakeSound.stopRingtoneCount, equals(0));

      // Tap Answer
      final answerFinder = find.text('Answer');
      expect(answerFinder, findsOneWidget);
      await tester.tap(answerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ringtone must stop immediately
      expect(fakeSound.stopRingtoneCount, greaterThanOrEqualTo(1));
    });

    testWidgets('IncomingCallScreen stops ringtone on Decline', (tester) async {
      final fakeSound = FakeSoundEffectService();

      await tester.pumpWidget(
        createTestAppWithRouter(
          overrides: [
            soundEffectServiceProvider.overrideWithValue(fakeSound),
            callAudioProvider.overrideWith((ref) => FakeCallAudioNotifier(ref, fakeSoundService: fakeSound)),
          ],
          child: IncomingCallScreen(
            scenario: testScenario,
          ),
        ),
      );
      await tester.pump();

      expect(fakeSound.playRingtoneCount, equals(1));

      // Tap Decline
      final declineFinder = find.text('Decline');
      expect(declineFinder, findsOneWidget);
      await tester.tap(declineFinder);
      await tester.pump();

      expect(fakeSound.stopRingtoneCount, greaterThanOrEqualTo(1));
    });

    testWidgets('CallPracticeScreen plays ringtone on incoming view and stops on dispose', (tester) async {
      final fakeSound = FakeSoundEffectService();
      SoundEffectService.instance = fakeSound;

      await tester.pumpWidget(
        createTestAppWithRouter(
          overrides: [
            soundEffectServiceProvider.overrideWithValue(fakeSound),
          ],
          child: CallPracticeScreen(
            scenario: testScenario,
            startActive: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeSound.playRingtoneCount, equals(1));

      // Pump replacement to trigger dispose
      await tester.pumpWidget(
        createTestAppWithRouter(
          overrides: [
            soundEffectServiceProvider.overrideWithValue(fakeSound),
          ],
          child: const SizedBox(),
        ),
      );
      await tester.pump();

      expect(fakeSound.stopRingtoneCount, greaterThanOrEqualTo(1));
    });

    testWidgets('SimulationTrigger triggers ringtone on call simulation and stops on cancel', (tester) async {
      final fakeSound = FakeSoundEffectService();
      SoundEffectService.instance = fakeSound;

      late BuildContext testContext;
      await tester.pumpWidget(
        createTestAppWithRouter(
          overrides: [
            soundEffectServiceProvider.overrideWithValue(fakeSound),
          ],
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      SimulationTrigger.startSimulation(testContext, testScenario);
      await tester.pump();

      expect(fakeSound.playRingtoneCount, equals(1));

      SimulationTrigger.cancelActiveSimulation(stopRingtone: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeSound.stopRingtoneCount, greaterThanOrEqualTo(1));
    });

    test('MessageSessionNotifier triggers chime on incoming scam message', () async {
      final fakeSound = FakeSoundEffectService();
      final container = ProviderContainer(
        overrides: [
          soundEffectServiceProvider.overrideWithValue(fakeSound),
        ],
      );
      addTearDown(container.dispose);

      final msgNotifier = container.read(messageSessionProvider.notifier);

      // Loading a new drill scenario should chime
      msgNotifier.loadScenario(testScenario, 'FWhatsApp');
      expect(fakeSound.playChimeCount, equals(1));

      // Dispatching an AI scammer reply should also trigger chime
      msgNotifier.dispatchAiPayload(
        app: 'FWhatsApp',
        text: 'This is urgent, pay now.',
        payloadType: MessagePayloadType.text,
      );
      expect(fakeSound.playChimeCount, equals(2));
    });

    test('OsNotificationNotifier triggers chime on cross-app banner event', () async {
      final fakeSound = FakeSoundEffectService();
      final container = ProviderContainer(
        overrides: [
          soundEffectServiceProvider.overrideWithValue(fakeSound),
        ],
      );
      addTearDown(container.dispose);

      final osNotifier = container.read(osNotificationProvider.notifier);

      final fakeEvent = {
        'event': 'trigger_whatsapp',
        'target_app': 'FWhatsApp',
        'sender': 'Electricity Dept',
        'title': 'Power Cut Notice',
        'body': 'Pay bill before 9:30 PM',
        'badge_increment': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      osNotifier.handleCrossAppEvent(fakeEvent);
      expect(fakeSound.playChimeCount, equals(1));
    });
  });
}
