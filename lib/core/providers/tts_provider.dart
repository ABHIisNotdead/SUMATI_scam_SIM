import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

final ttsProvider = Provider<FlutterTts>((ref) {
  final tts = FlutterTts();
  tts.setLanguage("en-IN");
  tts.setSpeechRate(0.52); // Natural human conversational pace
  tts.setPitch(1.0);
  
  ref.onDispose(() {
    tts.stop();
  });
  
  return tts;
});
