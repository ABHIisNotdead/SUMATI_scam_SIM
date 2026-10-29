import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AiCheckerState {
  final bool isLoading;
  final String? verdict;
  final String? color;
  final String? error;

  AiCheckerState({this.isLoading = false, this.verdict, this.color, this.error});
}

class AiCheckerNotifier extends AutoDisposeNotifier<AiCheckerState> {
  @override
  AiCheckerState build() => AiCheckerState();

  Future<void> checkMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    state = AiCheckerState(isLoading: true);

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/check'); 
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = AiCheckerState(
          isLoading: false,
          verdict: data['verdict'],
          color: data['color'],
        );
      } else {
        state = AiCheckerState(
          isLoading: false,
          error: "Failed to verify message. Error code: ${response.statusCode}",
        );
      }
    } catch (e) {
      state = AiCheckerState(
        isLoading: false,
        error: "Connection error: Could not reach the AI detection service.",
      );
    }
  }
}

final aiCheckerProvider = NotifierProvider.autoDispose<AiCheckerNotifier, AiCheckerState>(() {
  return AiCheckerNotifier();
});
