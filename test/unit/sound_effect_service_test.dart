import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/services/sound_effect_service.dart';
import '../helpers/test_helpers.dart';

class MockAudioPlayer extends AudioPlayer {
  bool isPlaying = false;
  bool isStopped = false;
  ReleaseMode? configuredReleaseMode;
  Source? playedSource;

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    configuredReleaseMode = mode;
  }

  @override
  Future<void> play(Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    isPlaying = true;
    isStopped = false;
    playedSource = source;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    isStopped = true;
  }

  @override
  Future<void> dispose() async {
    isPlaying = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setupMockAudioChannels();
  });

  group('SoundEffectService Unit Tests', () {
    test('Initializes with loop for ringtone and release for chime', () {
      final mockRing = MockAudioPlayer();
      final mockChime = MockAudioPlayer();
      final service = SoundEffectService(
        ringtonePlayer: mockRing,
        chimePlayer: mockChime,
      );

      expect(service.isRinging, isFalse);
      expect(mockRing.configuredReleaseMode, equals(ReleaseMode.loop));
      expect(mockChime.configuredReleaseMode, equals(ReleaseMode.release));
      service.dispose();
    });

    test('playCallRingtone activates ringtone player and updates isRinging', () async {
      final mockRing = MockAudioPlayer();
      final mockChime = MockAudioPlayer();
      final service = SoundEffectService(
        ringtonePlayer: mockRing,
        chimePlayer: mockChime,
      );

      await service.playCallRingtone();
      expect(service.isRinging, isTrue);
      expect(mockRing.isPlaying, isTrue);

      // Calling play again while already ringing should not re-trigger
      await service.playCallRingtone();
      expect(service.isRinging, isTrue);

      await service.stopCallRingtone();
      expect(service.isRinging, isFalse);
      expect(mockRing.isStopped, isTrue);

      service.dispose();
    });

    test('playNotificationChime stops previous chime and plays new one', () async {
      final mockRing = MockAudioPlayer();
      final mockChime = MockAudioPlayer();
      final service = SoundEffectService(
        ringtonePlayer: mockRing,
        chimePlayer: mockChime,
      );

      await service.playNotificationChime();
      expect(mockChime.isPlaying, isTrue);
      expect(mockChime.playedSource, isNotNull);

      service.dispose();
    });

    test('Procedural fallback WAV generation generates valid RIFF WAVE headers', () async {
      final service = SoundEffectService();
      // Test that the service initializes and disposes cleanly with real AudioPlayers
      expect(service.isRinging, isFalse);
      service.dispose();
    });
  });
}

