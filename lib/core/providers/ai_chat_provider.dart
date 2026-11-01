import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

// 1. Define the Message Model
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

// 2. Define the Game State Model
class AiChatState {
  final List<ChatMessage> messages;
  final List<String> suggestions;
  final String status;
  final String? evaluation;
  final bool isLoading;

  AiChatState({
    required this.messages,
    this.suggestions = const [],
    this.status = 'ongoing',
    this.evaluation,
    this.isLoading = false,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    List<String>? suggestions,
    String? status,
    String? evaluation,
    bool? isLoading,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      suggestions: suggestions ?? this.suggestions,
      status: status ?? this.status,
      evaluation: evaluation ?? this.evaluation,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 3. The Provider Notifier
class AiChatNotifier extends AutoDisposeNotifier<AiChatState> {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSub;
  Timer? _responseTimeoutTimer;

  String _persona = 'a scammer attempting fraud';
  String _lang = 'en';

  @override
  AiChatState build() {
    ref.onDispose(() {
      _responseTimeoutTimer?.cancel();
      _streamSub?.cancel();
      _channel?.sink.close();
    });
    return AiChatState(messages: []);
  }

  void connect(String persona, String initialMessage, {String lang = 'en'}) {
    _persona = persona;
    _lang = lang;

    _streamSub?.cancel();
    _channel?.sink.close();
    _responseTimeoutTimer?.cancel();

    final fallbackSuggestions = lang == 'hi'
        ? ["आप कौन हैं?", "मुझे पहले इसकी पुष्टि करनी होगी।", "ठीक है, भुगतान कैसे करूँ?"]
        : (lang == 'mr'
            ? ["तुम्ही कोण आहात?", "मला आधी हे तपासावे लागेल.", "ठीक आहे, पैसे कसे भरायचे?"]
            : ["Who is this?", "I need to verify this first.", "Okay, how do I pay?"]);

    state = AiChatState(
      messages: [ChatMessage(text: initialMessage, isUser: false)],
      suggestions: fallbackSuggestions,
      status: 'ongoing',
      isLoading: false,
    );

    final encodedPersona = Uri.encodeComponent(persona);
    final encodedMsg = Uri.encodeComponent(initialMessage);
    final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/ws/chat?persona=$encodedPersona&initial_message=$encodedMsg&lang=$lang');

    try {
      _channel = WebSocketChannel.connect(wsUrl);

      _streamSub = _channel!.stream.listen(
        (message) {
          _responseTimeoutTimer?.cancel();
          try {
            final data = jsonDecode(message.toString());
            if (data is Map<String, dynamic> || data is Map) {
              final reply = data['reply']?.toString() ?? 'Error: No reply';
              final suggestions = (data['suggestions'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ?? [];
              final status = data['status']?.toString() ?? 'ongoing';
              final evaluation = data['evaluation']?.toString();

              state = state.copyWith(
                messages: [...state.messages, ChatMessage(text: reply, isUser: false)],
                suggestions: suggestions,
                status: status,
                evaluation: evaluation,
                isLoading: false,
              );
              return;
            }
          } catch (e) {
            debugPrint('[AiChat] Parse exception: $e');
          }

          state = state.copyWith(
            messages: [...state.messages, ChatMessage(text: message.toString(), isUser: false)],
            suggestions: [],
            status: 'ongoing',
            isLoading: false,
          );
        },
        onError: (error) {
          debugPrint('[AiChat] WebSocket error: $error');
          _responseTimeoutTimer?.cancel();
          // We do not overwrite conversation with failure text; HTTP fallback handles turns seamlessly.
        },
        onDone: () {
          debugPrint('[AiChat] WebSocket stream closed');
        },
      );
    } catch (e) {
      debugPrint('[AiChat] WebSocket connect error: $e');
    }
  }

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1. Add user message to UI immediately and set isLoading = true
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: trimmed, isUser: true)],
      suggestions: [],
      isLoading: true,
    );

    bool wsSent = false;
    if (_channel != null) {
      try {
        _channel!.sink.add(trimmed);
        wsSent = true;
      } catch (e) {
        debugPrint('[AiChat] WS send failed: $e');
        wsSent = false;
      }
    }

    // Set a 4-second timer: if WebSocket did not respond or failed, trigger HTTP fallback
    _responseTimeoutTimer?.cancel();
    if (wsSent) {
      _responseTimeoutTimer = Timer(const Duration(milliseconds: 4000), () {
        if (state.isLoading) {
          debugPrint('[AiChat] WebSocket timed out, falling back to HTTP /api/chat');
          _sendViaHttpFallback(trimmed);
        }
      });
    } else {
      _sendViaHttpFallback(trimmed);
    }
  }

  Future<void> _sendViaHttpFallback(String userMessage) async {
    try {
      final payload = {
        'persona': _persona,
        'user_message': userMessage,
        'messages': state.messages.map((m) => {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text,
        }).toList(),
        'lang': _lang,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final reply = data['reply']?.toString() ?? 'Please proceed with caution.';
        final suggestions = (data['suggestions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        final status = data['status']?.toString() ?? 'ongoing';
        final evaluation = data['evaluation']?.toString();

        state = state.copyWith(
          messages: [...state.messages, ChatMessage(text: reply, isUser: false)],
          suggestions: suggestions,
          status: status,
          evaluation: evaluation,
          isLoading: false,
        );
        return;
      }
    } catch (e) {
      debugPrint('[AiChat] HTTP fallback error: $e');
    }

    // If both failed, provide a smart emergency fallback reply
    if (state.isLoading) {
      final fallbackReply = _lang == 'hi'
          ? "चेतावनी: आपके खाते पर तुरंत रोक लग सकती है। क्या आप भुगतान या ओटीपी साझा करना चाहते हैं?"
          : (_lang == 'mr'
              ? "चेतावणी: तुमचे खाते तात्काळ बंद केले जाऊ शकते. तुम्ही पैसे भरणार आहात का?"
              : "Warning: Immediate action is required. Will you share the verification code or proceed with payment?");
      final fallbackSuggestions = _lang == 'hi'
          ? ["मैं ओटीपी नहीं दूंगा", "मैं बैंक शाखा जाकर पुष्टि करूँगा", "यह नंबर स्पैम है"]
          : (_lang == 'mr'
              ? ["मी ओटीपी देणार नाही", "मी थेट बँकेत जाईन", "हा संदेश संशयास्पद आहे"]
              : ["I will never share OTP", "I will visit the bank branch", "I am reporting this number"]);

      state = state.copyWith(
        messages: [...state.messages, ChatMessage(text: fallbackReply, isUser: false)],
        suggestions: fallbackSuggestions,
        status: 'ongoing',
        isLoading: false,
      );
    }
  }
}

final aiChatProvider = NotifierProvider.autoDispose<AiChatNotifier, AiChatState>(() {
  return AiChatNotifier();
});
