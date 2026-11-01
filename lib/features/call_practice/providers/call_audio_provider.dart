import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/scenario.dart';
import '../../../core/models/simulation_result.dart';
import '../../../core/providers/ai_call_provider.dart';
import '../../../core/providers/os_notification_provider.dart';
import '../../../core/services/realistic_voice_service.dart';
import '../../../core/services/sound_effect_service.dart';
import '../../../core/utils/scam_detection_checker.dart';

enum CallEngineStatus {
  idle,
  incoming,
  connecting,
  active,
  completed,
  compromised,
}

/// Comprehensive state for Live Call, Dynamic VAD, and Edge-TTS Streaming
class CallAudioState {
  final CallEngineStatus status;
  final bool isAiSpeaking;
  final bool isUserSpeaking;
  final bool isListening;
  final bool isMuted;
  final bool isSpeakerOn;
  final double soundLevel;
  final String recognizedText;
  final String latestAiReply;
  final int callDurationSeconds;
  final ScenarioArtifact? artifact;
  final String? compromiseReason;
  final bool isScamDetected;
  final String? scamDetectionReason;
  final String? callerName;
  final String? callerSubtitle;

  const CallAudioState({
    this.status = CallEngineStatus.idle,
    this.isAiSpeaking = false,
    this.isUserSpeaking = false,
    this.isListening = false,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.soundLevel = 0.0,
    this.recognizedText = '',
    this.latestAiReply = '',
    this.callDurationSeconds = 0,
    this.artifact,
    this.compromiseReason,
    this.isScamDetected = false,
    this.scamDetectionReason,
    this.callerName = 'Unknown Number',
    this.callerSubtitle = 'Suspected Fraud Call',
  });

  CallAudioState copyWith({
    CallEngineStatus? status,
    bool? isAiSpeaking,
    bool? isUserSpeaking,
    bool? isListening,
    bool? isMuted,
    bool? isSpeakerOn,
    double? soundLevel,
    String? recognizedText,
    String? latestAiReply,
    int? callDurationSeconds,
    ScenarioArtifact? artifact,
    bool clearArtifact = false,
    String? compromiseReason,
    bool? isScamDetected,
    String? scamDetectionReason,
    String? callerName,
    String? callerSubtitle,
  }) {
    return CallAudioState(
      status: status ?? this.status,
      isAiSpeaking: isAiSpeaking ?? this.isAiSpeaking,
      isUserSpeaking: isUserSpeaking ?? this.isUserSpeaking,
      isListening: isListening ?? this.isListening,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      soundLevel: soundLevel ?? this.soundLevel,
      recognizedText: recognizedText ?? this.recognizedText,
      latestAiReply: latestAiReply ?? this.latestAiReply,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      artifact: clearArtifact ? null : (artifact ?? this.artifact),
      compromiseReason: compromiseReason ?? this.compromiseReason,
      isScamDetected: isScamDetected ?? this.isScamDetected,
      scamDetectionReason: scamDetectionReason ?? this.scamDetectionReason,
      callerName: callerName ?? this.callerName,
      callerSubtitle: callerSubtitle ?? this.callerSubtitle,
    );
  }
}

/// Riverpod State Notifier managing Call State, Dynamic VAD, and Audio Playback
class CallAudioNotifier extends StateNotifier<CallAudioState> {
  final Ref _ref;
  final RealisticVoiceService _voiceService;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  StreamSubscription<PlayerState>? _playerSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  Timer? _durationTimer;
  Timer? _silenceTimer;

  bool _isProcessing = false;
  bool _sttInitialized = false;
  bool _sttStopped = false;
  String _activeLang = 'en';
  String _accumulatedSpeech = '';
  static const int _silenceDurationMs = 1500; // ~1.5s silence detection window for hands-free VAD

  bool get isProcessing => _isProcessing;
  final SoundEffectService? _soundService;

  CallAudioNotifier(Ref ref, {SoundEffectService? soundService})
      : _ref = ref,
        _voiceService = ref.read(realisticVoiceProvider),
        _soundService = soundService ?? _tryReadSoundService(ref),
        super(const CallAudioState()) {
    _initAudioPlayer();
    _initSpeech();
  }

  static SoundEffectService? _tryReadSoundService(Ref ref) {
    try {
      return ref.read(soundEffectServiceProvider);
    } catch (_) {
      return null;
    }
  }

  void _initAudioPlayer() {
    _playerSubscription = _audioPlayer.onPlayerStateChanged.listen((pState) {
      final isPlaying = pState == PlayerState.playing;
      if (isPlaying) {
        state = state.copyWith(isAiSpeaking: true);
      } else if (!_voiceService.isPlaying) {
        state = state.copyWith(isAiSpeaking: false);
      }
    });

    // Mutex unlock: Only unlock microphone after AI audio playback has completely finished
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _unlockProcessingAndResumeMic();
    });
  }

  void _unlockProcessingAndResumeMic() {
    _isProcessing = false;
    state = state.copyWith(isAiSpeaking: false);
    if (state.status == CallEngineStatus.active && !state.isMuted) {
      startDynamicListening();
    }
  }

  Future<void> _initSpeech() async {
    try {
      _sttInitialized = await _speechToText.initialize(
        onError: (err) {
          debugPrint('[CallAudioNotifier] STT Error: ${err.errorMsg}');
          state = state.copyWith(isListening: false, isUserSpeaking: false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (!_isProcessing && !state.isAiSpeaking && !_voiceService.isPlaying && state.status == CallEngineStatus.active && !state.isMuted) {
              if (_accumulatedSpeech.trim().isNotEmpty) {
                _finalizeAndSendSpeech();
              } else {
                // Continuous Hands-Free VAD: automatically re-arm so user never touches screen
                startDynamicListening();
              }
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[CallAudioNotifier] STT Initialization failed: $e');
    }
  }

  /// Initialize Incoming Call State for a Scenario
  void prepareIncomingCall(Scenario? scenario) {
    _durationTimer?.cancel();
    final name = scenario?.callerName ?? 'Unknown Number';
    final subtitle = scenario?.title ?? 'Incoming Voice Drill';

    state = CallAudioState(
      status: CallEngineStatus.incoming,
      callerName: name,
      callerSubtitle: subtitle,
    );
  }

  /// Accept Call and connect to backend WebSocket
  Future<void> answerCall({
    required Scenario? scenario,
    String lang = 'en',
    String persona = 'a scammer attempting fraud',
    String initialMsg = 'Hello. Please respond urgently.',
  }) async {
    _activeLang = lang;
    try {
      _soundService?.stopCallRingtone();
    } catch (_) {}
    final scenarioId = scenario?.id ?? 'call_digital_arrest';
    final resolvedPersona = scenario?.persona ?? persona;
    final resolvedMsg = scenario?.initialMessage ?? initialMsg;
    final resolvedCaller = scenario?.callerName ?? 'Unknown Number';

    state = state.copyWith(
      status: CallEngineStatus.connecting,
      callerName: resolvedCaller,
      callerSubtitle: 'Connecting secure channel...',
      callDurationSeconds: 0,
    );

    // Start Call Duration Timer
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == CallEngineStatus.active) {
        state = state.copyWith(callDurationSeconds: state.callDurationSeconds + 1);
      }
    });

    // Connect WebSocket
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();

    final encodedPersona = Uri.encodeComponent(resolvedPersona);
    final encodedMsg = Uri.encodeComponent(resolvedMsg);
    final encodedId = Uri.encodeComponent(scenarioId);
    final wsUrl = Uri.parse(
      '${AppConfig.wsBaseUrl}/ws/chat?persona=$encodedPersona&initial_message=$encodedMsg&lang=$lang&scenario_id=$encodedId',
    );

    debugPrint('[CallAudioNotifier] Connecting to $wsUrl');
    try {
      _wsChannel = WebSocketChannel.connect(wsUrl);
      state = state.copyWith(status: CallEngineStatus.active, callerSubtitle: '00:00');

      _wsSubscription = _wsChannel!.stream.listen(
        (message) => _handleBackendMessage(message),
        onError: (err) {
          debugPrint('[CallAudioNotifier] WS Error: $err');
        },
        onDone: () {
          debugPrint('[CallAudioNotifier] WS Stream closed');
        },
      );

      // Hands-free continuous VAD auto-starts immediately
      startDynamicListening();
    } catch (e) {
      debugPrint('[CallAudioNotifier] Connection error: $e');
      state = state.copyWith(status: CallEngineStatus.active);
      startDynamicListening();
    }
  }

  /// Decline Call
  void declineCall() {
    _cleanupCall();
    state = state.copyWith(
      status: CallEngineStatus.completed,
      isListening: false,
      isUserSpeaking: false,
      isAiSpeaking: false,
      soundLevel: 0.0,
    );
  }

  /// Hang Up / End Call
  void endCall() {
    _cleanupCall();
    state = state.copyWith(
      status: CallEngineStatus.completed,
      isListening: false,
      isUserSpeaking: false,
      isAiSpeaking: false,
      soundLevel: 0.0,
    );
  }

  /// Toggle Microphone Mute
  void toggleMute() {
    final newMute = !state.isMuted;
    state = state.copyWith(isMuted: newMute);
    if (newMute) {
      stopListening();
    } else if (!state.isAiSpeaking) {
      startDynamicListening();
    }
  }

  /// Toggle listening manually (Tap to Speak / Tap to Send)
  Future<void> toggleListening() async {
    if (state.isListening) {
      final speechToSend = _accumulatedSpeech.trim();
      if (speechToSend.isNotEmpty) {
        _isProcessing = true;
        await stopListening();
        sendUserMessage(speechToSend);
      } else {
        await stopListening();
      }
    } else {
      _isProcessing = false;
      state = state.copyWith(isMuted: false, isAiSpeaking: false);
      await startDynamicListening();
    }
  }

  /// Toggle Speakerphone
  void toggleSpeaker() {
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
  }

  /// Transmit explicit user message or quick choice
  void sendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    _isProcessing = true; // Strict VAD mutex lock
    _accumulatedSpeech = '';
    _silenceTimer?.cancel();
    stopListening();

    state = state.copyWith(
      recognizedText: text,
      isUserSpeaking: false,
    );

    // AI Scam Detection Checker
    if (ScamDetectionChecker.isScamRecognized(text)) {
      debugPrint('[CallAudioNotifier] AI Checker detected scam recognized by user: "$text"');
      final reason = ScamDetectionChecker.getRecognizedExplanation(text);
      state = state.copyWith(
        isScamDetected: true,
        scamDetectionReason: reason,
        status: CallEngineStatus.completed,
      );

      SimulationResult.recordResult(
        scenarioTitle: state.callerSubtitle ?? 'Voice Call Security Practice',
        channel: 'call',
        status: 'deflected',
      );

      _cleanupCall();
      return;
    }

    if (_wsChannel != null) {
      _wsChannel!.sink.add(text);
    }
  }

  /// Dynamic Voice Activity Detection: Monitor sound amplitude & silence window
  Future<void> startDynamicListening() async {
    // Strict Mutex Lock: If processing or AI is speaking, completely ignore microphone input
    if (_isProcessing || state.isMuted || state.isAiSpeaking || _voiceService.isPlaying || state.status != CallEngineStatus.active) {
      return;
    }

    if (!_sttInitialized) {
      await _initSpeech();
    }

    _accumulatedSpeech = '';
    _sttStopped = false;
    state = state.copyWith(isListening: true, isUserSpeaking: false);

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (_isProcessing || state.isAiSpeaking || _voiceService.isPlaying) return; // Completely ignore mic input if locked
          _accumulatedSpeech = result.recognizedWords;
          state = state.copyWith(
            recognizedText: result.recognizedWords,
            isUserSpeaking: true,
          );

          // Reset silence timer on every new word recognized
          _resetSilenceTimer();
        },
        onSoundLevelChange: (level) {
          if (_isProcessing || state.isAiSpeaking || _voiceService.isPlaying) return; // Completely ignore mic input if locked
          // Monitor amplitude level: level is typically -10 to +10 or 0 to 100
          state = state.copyWith(soundLevel: level);

          // If amplitude is prominent (> 15 dB equivalent)
          if (level > 2.0) {
            if (!state.isUserSpeaking) {
              state = state.copyWith(isUserSpeaking: true);
            }
            _resetSilenceTimer();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: _activeLang == 'hi' ? 'hi_IN' : (_activeLang == 'mr' ? 'mr_IN' : 'en_IN'),
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(milliseconds: _silenceDurationMs),
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('[CallAudioNotifier] Failed to start dynamic listening: $e');
      state = state.copyWith(isListening: false);
    }
  }

  /// Stop listening immediately
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    try {
      if (_speechToText.isListening && !_sttStopped) {
        _sttStopped = true;
        await _speechToText.stop();
      }
    } catch (_) {}
    state = state.copyWith(isListening: false, isUserSpeaking: false);
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: _silenceDurationMs), () {
      // 1.5s of silence detected -> lock mutex, pause mic, finalize and send speech chunk
      if (state.isListening && _accumulatedSpeech.trim().isNotEmpty && !_isProcessing && !state.isAiSpeaking && !_voiceService.isPlaying) {
        _isProcessing = true;
        stopListening();
        _finalizeAndSendSpeech();
      }
    });
  }

  void _finalizeAndSendSpeech() {
    final speechToSend = _accumulatedSpeech.trim();
    if (speechToSend.isNotEmpty) {
      sendUserMessage(speechToSend);
    } else {
      _isProcessing = false;
    }
  }

  /// Process incoming messages from backend AI scammer
  Future<void> _handleBackendMessage(dynamic raw) async {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;

      // Step 1: Detect cross-app triggers (trigger_sms, trigger_whatsapp, etc.)
      final eventType = data['event'] as String? ??
          (data['cross_app_event'] is Map ? data['cross_app_event']['event'] as String? : null);

      if (eventType != null &&
          (eventType.startsWith('trigger_') ||
           eventType == 'compromise_alert' ||
           eventType == 'badge_update')) {
        final crossAppMap = data['cross_app_event'] is Map
            ? Map<String, dynamic>.from(data['cross_app_event'] as Map)
            : data;

        // Dispatch directly to OsNotificationNotifier so GlobalNotificationOverlay drops the banner
        _ref.read(osNotificationProvider.notifier).handleCrossAppEvent(crossAppMap);

        // Scammer text or multi-modal payloads (Links, APKs) sent during a call must NOT appear in the Active Call UI.
        if (_isProcessing && !state.isAiSpeaking && !_voiceService.isPlaying) {
          _unlockProcessingAndResumeMic();
        }
        return;
      }

      final reply = data['reply'] as String? ?? '';
      final status = data['status'] as String? ?? 'ongoing';
      final audioB64 = data['audio_b64'] as String?;

      ScenarioArtifact? artifact;
      if (data['artifact'] is Map) {
        artifact = ScenarioArtifact.fromJson(Map<String, dynamic>.from(data['artifact'] as Map));
      }

      state = state.copyWith(
        latestAiReply: reply,
        artifact: artifact,
        isAiSpeaking: reply.isNotEmpty || (audioB64 != null && audioB64.isNotEmpty),
      );

      if (status == 'compromised') {
        state = state.copyWith(
          status: CallEngineStatus.compromised,
          compromiseReason: data['evaluation'] as String? ?? 'Scam trap triggered.',
        );
      }

      // Stop mic and lock mutex while scammer speaks
      _isProcessing = true;
      await stopListening();

      // Stop any current playback to prevent overlapping voices / double-talking
      await _audioPlayer.stop();
      await _voiceService.stop();

      // Play audio response using audioplayers / edge-tts
      if (audioB64 != null && audioB64.isNotEmpty && !kIsWeb) {
        try {
          final audioBytes = base64Decode(audioB64);
          await _audioPlayer.play(BytesSource(audioBytes));
        } catch (e) {
          debugPrint('[CallAudioNotifier] Error playing audio bytes: $e');
          _playFallbackSpeech(reply);
        }
      } else if (reply.isNotEmpty) {
        _playFallbackSpeech(reply);
      } else {
        _unlockProcessingAndResumeMic();
      }
    } catch (e) {
      debugPrint('[CallAudioNotifier] Error decoding backend message: $e');
      _unlockProcessingAndResumeMic();
    }
  }

  void _playFallbackSpeech(String text) {
    _voiceService.speakRealistic(
      text,
      _activeLang,
      onComplete: () {
        _unlockProcessingAndResumeMic();
      },
    );
  }

  @visibleForTesting
  Future<void> handleBackendMessageForTesting(dynamic raw) => _handleBackendMessage(raw);

  @visibleForTesting
  void setActiveCallForTesting({
    bool isListening = true,
    bool isMuted = false,
    bool isAiSpeaking = false,
  }) {
    state = state.copyWith(
      status: CallEngineStatus.active,
      isListening: isListening,
      isMuted: isMuted,
      isAiSpeaking: isAiSpeaking,
    );
  }

  void _cleanupCall() {
    _isProcessing = false;
    _durationTimer?.cancel();
    _silenceTimer?.cancel();
    _wsSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _wsChannel?.sink.close();
    try {
      if (_speechToText.isListening && !_sttStopped) {
        _sttStopped = true;
        _speechToText.stop();
      }
    } catch (_) {}
    try {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (!isTest) {
        _audioPlayer.stop();
        _audioPlayer.release();
      }
    } catch (_) {}
    try {
      _voiceService.stop();
    } catch (_) {}
    try {
      _soundService?.stopCallRingtone();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanupCall();
    _playerSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _audioPlayer.dispose();
    }
    super.dispose();
  }
}

/// Global provider for Live Call Engine
final callAudioProvider = StateNotifierProvider<CallAudioNotifier, CallAudioState>((ref) {
  return CallAudioNotifier(ref);
});
