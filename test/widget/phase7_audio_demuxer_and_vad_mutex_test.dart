import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/services/realistic_voice_service.dart';
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
    scammerName: 'Officer Sharma (CBI)',
    initialMessage: 'This is Crime Branch officer Sharma.',
  );

  group('Phase 7 Step 1: Demuxer Crash Fix (RealisticVoiceService POST with BytesSource)', () {
    test('RealisticVoiceService is available and handles empty/stop cleanly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final voiceService = container.read(realisticVoiceProvider);
      expect(voiceService.isPlaying, isFalse);

      // Empty text does not crash and finishes cleanly
      bool completed = false;
      await voiceService.speakRealistic('', 'en', onComplete: () {
        completed = true;
      });
      expect(completed, isTrue);

      await voiceService.stop();
      expect(voiceService.isPlaying, isFalse);
    });
  });

  group('Phase 7 Step 2: VAD Mutex Lock & AI Double-Talking Prevention', () {
    test('sendUserMessage sets isProcessing = true and locks microphone input', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(callAudioProvider.notifier);

      expect(notifier.isProcessing, isFalse);

      // Transmitting user speech to WebSocket activates strict mutex lock
      notifier.sendUserMessage('I am hanging up the call now.');

      expect(notifier.isProcessing, isTrue);
      expect(container.read(callAudioProvider).recognizedText, 'I am hanging up the call now.');
      expect(container.read(callAudioProvider).isUserSpeaking, isFalse);
    });

    test('startDynamicListening aborts immediately while mutex lock is active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(callAudioProvider.notifier);
      notifier.prepareIncomingCall(testScenario);

      // Lock mutex
      notifier.sendUserMessage('Stop calling me.');
      expect(notifier.isProcessing, isTrue);

      // Attempting to engage mic while locked should be completely ignored
      await notifier.startDynamicListening();
      expect(container.read(callAudioProvider).isListening, isFalse);
    });

    test('Ending or declining call releases the mutex lock and cleans up audio', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(callAudioProvider.notifier);
      notifier.prepareIncomingCall(testScenario);

      notifier.sendUserMessage('I refuse to comply.');
      expect(notifier.isProcessing, isTrue);

      notifier.endCall();
      expect(notifier.isProcessing, isFalse);
      expect(container.read(callAudioProvider).status, CallEngineStatus.completed);
    });
  });
}
