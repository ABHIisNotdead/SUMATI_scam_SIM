import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
      // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for iOS/Web
      final url = Uri.parse('http://127.0.0.1:8000/check'); 
      
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
        state = AiCheckerState(isLoading: false, error: 'Server error. Please try again.');
      }
    } catch (e) {
      state = AiCheckerState(isLoading: false, error: 'Connection failed. Is the server running?');
    }
  }
  
  void reset() {
    state = AiCheckerState();
  }
}

final aiCheckerProvider = NotifierProvider.autoDispose<AiCheckerNotifier, AiCheckerState>(
  () => AiCheckerNotifier(),
);