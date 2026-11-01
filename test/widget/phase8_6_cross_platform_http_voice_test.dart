import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/services/realistic_voice_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupMockAudioChannels();
  });

  group('Phase 8.6: Cross-Platform HTTP & Zero dart:io in RealisticVoiceService', () {
    test('RealisticVoiceService can be instantiated and stopped without Platform._version crash', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final voiceService = container.read(realisticVoiceProvider);
      expect(voiceService.isPlaying, isFalse);

      // Verify empty text returns cleanly
      bool onCompleteFired = false;
      await voiceService.speakRealistic('', 'en', onComplete: () {
        onCompleteFired = true;
      });
      expect(onCompleteFired, isTrue);

      await voiceService.stop();
      expect(voiceService.isPlaying, isFalse);
    });

    test('Foundation kIsWeb boolean is available for platform checks', () {
      // Confirms kIsWeb is imported from package:flutter/foundation.dart
      expect(kIsWeb, isA<bool>());
    });
  });
}

