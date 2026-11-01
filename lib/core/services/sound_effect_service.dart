import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound effect provider for managing ringing and notification chimes
final soundEffectServiceProvider = Provider<SoundEffectService>((ref) {
  final service = SoundEffectService.instance;
  return service;
});

/// Service responsible for playing incoming call ringtones (looping)
/// and one-shot notification chimes for SMS / WhatsApp / OS alerts.
class SoundEffectService {
  static SoundEffectService? _instance;
  static SoundEffectService get instance => _instance ??= SoundEffectService();
  static set instance(SoundEffectService val) => _instance = val;

  AudioPlayer? _ringtonePlayer;
  AudioPlayer? _chimePlayer;

  bool _isRinging = false;
  bool get isRinging => _isRinging;

  Uint8List? _cachedRingBytes;
  Uint8List? _cachedChimeBytes;
  final bool _hasCustomPlayers;

  SoundEffectService({
    AudioPlayer? ringtonePlayer,
    AudioPlayer? chimePlayer,
  })  : _ringtonePlayer = ringtonePlayer,
        _chimePlayer = chimePlayer,
        _hasCustomPlayers = (ringtonePlayer != null || chimePlayer != null) {
    try {
      _ringtonePlayer?.setReleaseMode(ReleaseMode.loop);
    } catch (_) {}
    try {
      _chimePlayer?.setReleaseMode(ReleaseMode.release);
    } catch (_) {}
  }

  AudioPlayer? _getOrCreateRingtonePlayer() {
    if (_ringtonePlayer != null) return _ringtonePlayer;
    try {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.loop);
      _ringtonePlayer = player;
      return player;
    } catch (e) {
      debugPrint('[SoundEffectService] AudioPlayer creation error: $e');
      return null;
    }
  }

  AudioPlayer? _getOrCreateChimePlayer() {
    if (_chimePlayer != null) return _chimePlayer;
    try {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.release);
      _chimePlayer = player;
      return player;
    } catch (e) {
      debugPrint('[SoundEffectService] AudioPlayer creation error: $e');
      return null;
    }
  }

  static bool get isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// Start playing the incoming call ringtone on continuous loop.
  Future<void> playCallRingtone() async {
    final player = _getOrCreateRingtonePlayer();
    if (player == null) return;

    if (_isRinging && player.state == PlayerState.playing) {
      return;
    }
    _isRinging = true;

    if (isTestEnvironment && !_hasCustomPlayers) {
      return;
    }

    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1.0);

      // 1. Try loading from Flutter rootBundle first (most robust cross-platform asset loader)
      if (_cachedRingBytes == null) {
        try {
          final data = await rootBundle.load('assets/audio/phone_ringtone.wav');
          _cachedRingBytes = data.buffer.asUint8List();
        } catch (e) {
          debugPrint('[SoundEffectService] rootBundle load failed for ringtone: $e');
        }
      }

      if (_cachedRingBytes != null && _cachedRingBytes!.isNotEmpty) {
        await player.play(BytesSource(_cachedRingBytes!), volume: 1.0);
        return;
      }

      // 2. Fallback to AssetSource
      await player.play(AssetSource('audio/phone_ringtone.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[SoundEffectService] AssetSource error for ringtone, attempting fallback bytes: $e');
      try {
        _cachedRingBytes ??= _generatePcmTelephoneRingWav();
        await player.setVolume(1.0);
        await player.play(BytesSource(_cachedRingBytes!), volume: 1.0);
      } catch (fallbackError) {
        debugPrint('[SoundEffectService] Fallback ringtone error: $fallbackError');
      }
    }
  }

  /// Stop the incoming call ringtone immediately.
  Future<void> stopCallRingtone() async {
    _isRinging = false;
    if (isTestEnvironment && !_hasCustomPlayers) {
      return;
    }
    if (_ringtonePlayer == null) return;
    try {
      await _ringtonePlayer!.stop();
    } catch (e) {
      debugPrint('[SoundEffectService] Error stopping ringtone: $e');
    }
  }

  /// Play a one-shot notification chime for an incoming message or banner.
  Future<void> playNotificationChime() async {
    final player = _getOrCreateChimePlayer();
    if (player == null) return;

    if (isTestEnvironment && !_hasCustomPlayers) {
      return;
    }

    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(1.0);

      // 1. Try loading from Flutter rootBundle first
      if (_cachedChimeBytes == null) {
        try {
          final data = await rootBundle.load('assets/audio/notification_chime.wav');
          _cachedChimeBytes = data.buffer.asUint8List();
        } catch (e) {
          debugPrint('[SoundEffectService] rootBundle load failed for chime: $e');
        }
      }

      if (_cachedChimeBytes != null && _cachedChimeBytes!.isNotEmpty) {
        await player.play(BytesSource(_cachedChimeBytes!), volume: 1.0);
        return;
      }

      // 2. Fallback to AssetSource
      await player.play(AssetSource('audio/notification_chime.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[SoundEffectService] AssetSource error for chime, attempting fallback bytes: $e');
      try {
        _cachedChimeBytes ??= _generatePcmNotificationChimeWav();
        await player.setVolume(1.0);
        await player.play(BytesSource(_cachedChimeBytes!), volume: 1.0);
      } catch (fallbackError) {
        debugPrint('[SoundEffectService] Fallback chime error: $fallbackError');
      }
    }
  }

  /// Dispose of audio players on cleanup
  void dispose() {
    _isRinging = false;
    try {
      _ringtonePlayer?.dispose();
    } catch (_) {}
    try {
      _chimePlayer?.dispose();
    } catch (_) {}
    _ringtonePlayer = null;
    _chimePlayer = null;
  }

  /// Procedural fallback generator for telephone dual-frequency ring (440Hz + 480Hz)
  static Uint8List _generatePcmTelephoneRingWav() {
    const int sampleRate = 22050;
    const double duration = 2.0; // 2 seconds
    final int numSamples = (sampleRate * duration).toInt();
    final ByteData pcmData = ByteData(numSamples * 2);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double sample = 0.0;
      if (t < 1.0) {
        final double env = math.min(1.0, t * 10) * math.max(0.0, math.min(1.0, (1.0 - t) * 10));
        sample = 0.4 * (math.sin(2 * math.pi * 440 * t) + math.sin(2 * math.pi * 480 * t)) * env;
      }
      final int intSample = (sample * 32767).clamp(-32768, 32767).toInt();
      pcmData.setInt16(i * 2, intSample, Endian.little);
    }

    return _buildWavHeader(pcmData.buffer.asUint8List(), sampleRate, 1, 16);
  }

  /// Procedural fallback generator for notification chime (880Hz -> 1320Hz)
  static Uint8List _generatePcmNotificationChimeWav() {
    const int sampleRate = 22050;
    const double duration = 0.35; // 350ms
    final int numSamples = (sampleRate * duration).toInt();
    final ByteData pcmData = ByteData(numSamples * 2);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double sample = 0.0;
      if (t < 0.1) {
        final double env = math.exp(-t * 15);
        sample = 0.5 * math.sin(2 * math.pi * 880 * t) * env;
      } else {
        final double t2 = t - 0.1;
        final double env = math.exp(-t2 * 10);
        sample = 0.55 * math.sin(2 * math.pi * 1320 * t) * env;
      }
      final int intSample = (sample * 32767).clamp(-32768, 32767).toInt();
      pcmData.setInt16(i * 2, intSample, Endian.little);
    }

    return _buildWavHeader(pcmData.buffer.asUint8List(), sampleRate, 1, 16);
  }

  /// Helper to wrap PCM data into standard RIFF WAV container bytes
  static Uint8List _buildWavHeader(Uint8List pcmBytes, int sampleRate, int channels, int bitsPerSample) {
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    final int subChunk2Size = pcmBytes.length;
    final int chunkSize = 36 + subChunk2Size;

    final ByteData header = ByteData(44);
    // "RIFF"
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, chunkSize, Endian.little);
    // "WAVE"
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // "fmt "
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    header.setUint16(20, 1, Endian.little);  // AudioFormat 1 = PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // "data"
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, subChunk2Size, Endian.little);

    final Uint8List wavBytes = Uint8List(44 + subChunk2Size);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + subChunk2Size, pcmBytes);
    return wavBytes;
  }
}
