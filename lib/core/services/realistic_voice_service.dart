import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../providers/tts_provider.dart';

class RealisticVoiceService {
  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  RealisticVoiceService(this._ref) {
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });
  }

  bool get isPlaying => _isPlaying;

  /// Plays studio-quality Edge-TTS neural voice from base64 string
  Future<void> playBase64Audio(String base64Str, {VoidCallback? onComplete}) async {
    try {
      await stop();
      final bytes = base64Decode(base64Str);
      await _player.play(BytesSource(bytes));
      if (onComplete != null) {
        _player.onPlayerComplete.first.then((_) => onComplete());
      }
    } catch (e) {
      debugPrint('[RealisticVoiceService] Error playing base64 audio: $e');
    }
  }

  /// Speaks using the realistic Edge-TTS backend endpoint, with local TTS fallback
  Future<void> speakRealistic(String text, String lang, {VoidCallback? onComplete, String rate = '+18%'}) async {
    if (text.trim().isEmpty) return;

    await stop();

    // Try backend Edge-TTS endpoint first
    try {
      final encodedText = Uri.encodeComponent(text);
      final voice = (lang == 'hi' || lang == 'mr') ? 'hi-IN-MadhurNeural' : 'en-IN-PrabhatNeural';
      final encodedRate = Uri.encodeComponent(rate);
      final url = '${AppConfig.apiBaseUrl}/tts?text=$encodedText&voice=$voice&rate=$encodedRate';

      await _player.play(UrlSource(url));
      if (onComplete != null) {
        _player.onPlayerComplete.first.then((_) => onComplete());
      }
      return;
    } catch (e) {
      debugPrint('[RealisticVoiceService] Backend TTS unreachable, falling back to local TTS: $e');
    }

    // Fallback: device TTS
    try {
      await _ref.read(ttsProvider).speak(text);
      if (onComplete != null) {
        onComplete();
      }
    } catch (e) {
      debugPrint('[RealisticVoiceService] Local TTS error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _ref.read(ttsProvider).stop();
    } catch (_) {}
    _isPlaying = false;
  }

  void dispose() {
    _playerStateSubscription?.cancel();
    _player.dispose();
  }
}

final realisticVoiceProvider = Provider<RealisticVoiceService>((ref) {
  final service = RealisticVoiceService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

