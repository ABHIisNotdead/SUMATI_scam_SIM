import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'tts_provider.dart';

class AiCallState {
  final String latestAiReply;
  final String status;
  final String? evaluation;
  final bool isSpeaking;

  AiCallState({
    this.latestAiReply = '',
    this.status = 'ongoing',
    this.evaluation,
    this.isSpeaking = false,
  });

  AiCallState copyWith({
    String? latestAiReply,
    String? status,
    String? evaluation,
    bool? isSpeaking,
  }) {
    return AiCallState(
      latestAiReply: latestAiReply ?? this.latestAiReply,
      status: status ?? this.status,
      evaluation: evaluation ?? this.evaluation,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

class AiCallNotifier extends AutoDisposeNotifier<AiCallState> {
  WebSocketChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  AiCallState build() {
    _audioPlayer.onPlayerStateChanged.listen((playerState) {
      final isPlaying = playerState == PlayerState.playing;
      state = state.copyWith(isSpeaking: isPlaying);
    });

    ref.onDispose(() {
      _channel?.sink.close();
      _audioPlayer.stop();
      _audioPlayer.dispose();
      ref.read(ttsProvider).stop();
    });
    return AiCallState();
  }

  void connect(String persona, String initialMessage) {
    _channel?.sink.close();
    _audioPlayer.stop();

    final encodedPersona = Uri.encodeComponent(persona);
    final encodedMsg = Uri.encodeComponent(initialMessage);
    final wsUrl = Uri.parse('ws://127.0.0.1:8000/ws/chat?persona=$encodedPersona&initial_message=$encodedMsg');
    
    debugPrint("[AiCallProvider] Connecting to $wsUrl");
    _channel = WebSocketChannel.connect(wsUrl);

    state = AiCallState(
      latestAiReply: initialMessage,
      status: 'ongoing',
      isSpeaking: true,
    );

    _channel!.stream.listen(
      (message) async {
        try {
          final data = jsonDecode(message as String);
          final reply = data['reply'] as String? ?? '';
          final status = data['status'] as String? ?? 'ongoing';
          final evaluation = data['evaluation'] as String?;
          final audioB64 = data['audio_b64'] as String?;

          state = AiCallState(
            latestAiReply: reply,
            status: status,
            evaluation: evaluation,
            isSpeaking: true,
          );

          if (audioB64 != null && audioB64.isNotEmpty) {
            // Play studio-quality Edge-TTS neural voice audio
            try {
              final audioBytes = base64Decode(audioB64);
              await _audioPlayer.stop();
              await _audioPlayer.play(BytesSource(audioBytes));
            } catch (playErr) {
              debugPrint("[AiCallProvider] Audio playback error: $playErr");
              ref.read(ttsProvider).speak(reply);
            }
          } else if (reply.isNotEmpty) {
            // Fallback to local TTS if audio_b64 is missing
            ref.read(ttsProvider).speak(reply);
          }
        } catch (e) {
          debugPrint("[AiCallProvider] JSON Parsing Error: $e");
        }
      },
      onError: (err) {
        debugPrint("[AiCallProvider] WebSocket Error: $err");
      },
      onDone: () {
        debugPrint("[AiCallProvider] WebSocket Done");
      },
    );
  }

  void sendVoiceMessage(String text) {
    if (text.trim().isNotEmpty) {
      stopTts();
      if (_channel != null) {
        _channel!.sink.add(text);
      }
    }
  }

  void stopTts() {
    _audioPlayer.stop();
    ref.read(ttsProvider).stop();
    if (state.isSpeaking) {
      state = state.copyWith(isSpeaking: false);
    }
  }

  void endCall() {
    _channel?.sink.close();
    _channel = null;
    stopTts();
  }
}

final aiCallProvider = NotifierProvider.autoDispose<AiCallNotifier, AiCallState>(() {
  return AiCallNotifier();
});
