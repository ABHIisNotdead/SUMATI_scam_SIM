import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/app_config.dart';
import '../services/realistic_voice_service.dart';

class ScenarioArtifact {
  final String type;
  final String sender;
  final String title;
  final String body;
  final String actionLabel;

  const ScenarioArtifact({
    required this.type,
    required this.sender,
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  factory ScenarioArtifact.fromJson(Map<String, dynamic> json) {
    return ScenarioArtifact(
      type: json['type']?.toString() ?? 'notice',
      sender: json['sender']?.toString() ?? 'ALERT',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      actionLabel: json['action_label']?.toString() ?? 'View',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'sender': sender,
    'title': title,
    'body': body,
    'action_label': actionLabel,
  };
}

class AiCallState {
  final String latestAiReply;
  final String status;
  final String? evaluation;
  final bool isSpeaking;
  final ScenarioArtifact? artifact;
  final String? lastUserMessage;
  final bool isThinking;

  AiCallState({
    this.latestAiReply = '',
    this.status = 'ongoing',
    this.evaluation,
    this.isSpeaking = false,
    this.artifact,
    this.lastUserMessage,
    this.isThinking = false,
  });

  AiCallState copyWith({
    String? latestAiReply,
    String? status,
    String? evaluation,
    bool? isSpeaking,
    ScenarioArtifact? artifact,
    bool clearArtifact = false,
    String? lastUserMessage,
    bool? isThinking,
  }) {
    return AiCallState(
      latestAiReply: latestAiReply ?? this.latestAiReply,
      status: status ?? this.status,
      evaluation: evaluation ?? this.evaluation,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      artifact: clearArtifact ? null : (artifact ?? this.artifact),
      lastUserMessage: lastUserMessage ?? this.lastUserMessage,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}

class AiCallNotifier extends AutoDisposeNotifier<AiCallState> {
  WebSocketChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription? _wsSub;

  @override
  AiCallState build() {
    _playerStateSub?.cancel();
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((playerState) {
      final isPlaying = playerState == PlayerState.playing;
      state = state.copyWith(isSpeaking: isPlaying);
    });

    ref.onDispose(() {
      _wsSub?.cancel();
      _playerStateSub?.cancel();
      _channel?.sink.close();
      _audioPlayer.stop();
      _audioPlayer.release();
      _audioPlayer.dispose();
      ref.read(realisticVoiceProvider).stop();
    });
    return AiCallState();
  }

  String _activeLang = 'en';

  void connect(String persona, String initialMessage, {String lang = 'en', String? scenarioId}) {
    _activeLang = lang;
    _wsSub?.cancel();
    _channel?.sink.close();
    _audioPlayer.stop();

    final encodedPersona = Uri.encodeComponent(persona);
    final encodedMsg = Uri.encodeComponent(initialMessage);
    final scenarioParam = (scenarioId != null && scenarioId.isNotEmpty)
        ? '&scenario_id=${Uri.encodeComponent(scenarioId)}'
        : '';
    final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/ws/chat?persona=$encodedPersona&initial_message=$encodedMsg&lang=$lang$scenarioParam');
    
    debugPrint("[AiCallProvider] Connecting to $wsUrl");
    _channel = WebSocketChannel.connect(wsUrl);

    state = AiCallState(
      latestAiReply: initialMessage,
      status: 'ongoing',
      isSpeaking: false,
    );

    _wsSub = _channel!.stream.listen(
      (message) async {
        try {
          final data = jsonDecode(message as String);
          final reply = data['reply'] as String? ?? '';
          final status = data['status'] as String? ?? 'ongoing';
          final evaluation = data['evaluation'] as String?;
          final audioB64 = data['audio_b64'] as String?;

          ScenarioArtifact? artifact;
          if (data['artifact'] is Map<String, dynamic> || data['artifact'] is Map) {
            artifact = ScenarioArtifact.fromJson(Map<String, dynamic>.from(data['artifact'] as Map));
          }

          state = state.copyWith(
            latestAiReply: reply,
            status: status,
            evaluation: evaluation,
            isSpeaking: reply.isNotEmpty,
            artifact: artifact,
            isThinking: false,
          );

          if (kIsWeb) {
            // On Flutter Web, stream via HTTP Edge-TTS to avoid accumulating unrevoked BytesSource blobs
            if (reply.isNotEmpty) {
              ref.read(realisticVoiceProvider).speakRealistic(
                reply,
                _activeLang,
                onComplete: () {
                  state = state.copyWith(isSpeaking: false);
                },
              );
            } else {
              state = state.copyWith(isSpeaking: false);
            }
          } else {
            if (audioB64 != null && audioB64.isNotEmpty) {
              try {
                final audioBytes = base64Decode(audioB64);
                await _audioPlayer.stop();
                await _audioPlayer.play(BytesSource(audioBytes));
              } catch (playErr) {
                debugPrint("[AiCallProvider] Audio playback error: $playErr");
                ref.read(realisticVoiceProvider).speakRealistic(
                  reply,
                  _activeLang,
                  onComplete: () {
                    state = state.copyWith(isSpeaking: false);
                  },
                );
              }
            } else if (reply.isNotEmpty) {
              ref.read(realisticVoiceProvider).speakRealistic(
                reply,
                _activeLang,
                onComplete: () {
                  state = state.copyWith(isSpeaking: false);
                },
              );
            } else {
              state = state.copyWith(isSpeaking: false);
            }
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
    final clean = text.replaceAll('“', '').replaceAll('”', '').replaceAll('"', '').trim();
    if (clean.isNotEmpty) {
      stopTts();
      state = state.copyWith(lastUserMessage: clean, isThinking: true);
      if (_channel != null) {
        _channel!.sink.add(clean);
      }
    }
  }

  void stopTts() {
    _audioPlayer.stop();
    _audioPlayer.release();
    ref.read(realisticVoiceProvider).stop();
    if (state.isSpeaking) {
      state = state.copyWith(isSpeaking: false);
    }
  }

  void clearArtifact() {
    state = state.copyWith(clearArtifact: true);
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
