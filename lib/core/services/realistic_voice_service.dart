import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class RealisticVoiceService {
  final AudioPlayer _player = AudioPlayer();
  http.Client? _activeClient;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  RealisticVoiceService() {
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
      onComplete?.call();
    }
  }

  /// Speaks exclusively using the studio-quality Edge-TTS neural voice endpoint via POST with JSON body and binary BytesSource
  Future<void> speakRealistic(String text, String lang, {VoidCallback? onComplete, String rate = '+18%'}) async {
    if (text.trim().isEmpty) {
      onComplete?.call();
      return;
    }

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      onComplete?.call();
      return;
    }

    await stop();

    try {
      final voice = (lang == 'hi' || lang == 'mr') ? 'hi-IN-MadhurNeural' : 'en-IN-PrabhatNeural';
      final client = http.Client();
      _activeClient = client;

      final url = Uri.parse('${AppConfig.apiBaseUrl}/tts');
      http.Response response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'voice': voice,
          'rate': rate,
        }),
      );

      // Backward compatibility: If deployed backend returns 405 (prior to pushing & redeploying new POST endpoint), fallback to GET with query params
      if (response.statusCode == 405) {
        final getUri = Uri.parse('${AppConfig.apiBaseUrl}/tts').replace(
          queryParameters: {
            'text': text,
            'voice': voice,
            'rate': rate,
          },
        );
        response = await client.get(getUri);
      }

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await _player.play(BytesSource(response.bodyBytes));
        if (onComplete != null) {
          _player.onPlayerComplete.first.then((_) => onComplete());
        }
        return;
      }
      onComplete?.call();
    } catch (e) {
      debugPrint('[RealisticVoiceService] Edge-TTS POST playback error: $e');
      onComplete?.call();
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  Future<void> stop() async {
    try {
      _activeClient?.close();
      _activeClient = null;
      await _player.stop();
      await _player.release();
    } catch (_) {}
    _isPlaying = false;
  }

  void dispose() {
    _activeClient?.close();
    _activeClient = null;
    _playerStateSubscription?.cancel();
    _player.stop();
    _player.release();
    _player.dispose();
  }
}

final realisticVoiceProvider = Provider<RealisticVoiceService>((ref) {
  final service = RealisticVoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});
