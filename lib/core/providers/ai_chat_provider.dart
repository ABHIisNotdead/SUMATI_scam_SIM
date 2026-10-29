import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  AiChatState({
    required this.messages,
    this.suggestions = const [],
    this.status = 'ongoing',
    this.evaluation,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    List<String>? suggestions,
    String? status,
    String? evaluation,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      suggestions: suggestions ?? this.suggestions,
      status: status ?? this.status,
      evaluation: evaluation ?? this.evaluation,
    );
  }
}

// 3. The Provider Notifier
class AiChatNotifier extends AutoDisposeNotifier<AiChatState> {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSub;

  @override
  AiChatState build() {
    ref.onDispose(() {
      _streamSub?.cancel();
      _channel?.sink.close();
    });
    return AiChatState(messages: []);
  }

  void connect(String persona, String initialMessage, {String lang = 'en'}) {
    // Cancel any previous connection and subscription before opening a new one
    _streamSub?.cancel();
    _channel?.sink.close();

    final encodedPersona = Uri.encodeComponent(persona);
    final encodedMsg = Uri.encodeComponent(initialMessage);
    final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/ws/chat?persona=$encodedPersona&initial_message=$encodedMsg&lang=$lang');
    
    _channel = WebSocketChannel.connect(wsUrl);

    _streamSub = _channel!.stream.listen(
      (message) {
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
            );
            return;
          }
        } catch (e) {
          // If not a JSON object, display raw message gracefully
        }

        state = state.copyWith(
          messages: [...state.messages, ChatMessage(text: message.toString(), isUser: false)],
          suggestions: [],
          status: 'ongoing',
        );
      },
      onError: (error) {
        final errorText = lang == 'hi'
            ? "कनेक्शन टूट गया। कृपया जांचें कि बैकएंड चल रहा है।"
            : (lang == 'mr'
                ? "कनेक्शन गमावले. कृपया बॅकएंड चालू असल्याची खात्री करा."
                : "Connection lost. Please make sure backend is running.");
        final fallbackSuggestions = lang == 'hi'
            ? ["आप कौन हैं?", "मुझे पहले इसकी पुष्टि करनी होगी।", "ठीक है, भुगतान कैसे करूँ?"]
            : (lang == 'mr'
                ? ["तुम्ही कोण आहात?", "मला आधी हे तपासावे लागेल.", "ठीक आहे, पैसे कसे भरायचे?"]
                : ["Who is this?", "I need to verify this first.", "Okay, how do I pay?"]);

        state = state.copyWith(
          messages: [...state.messages, ChatMessage(text: errorText, isUser: false)],
          suggestions: fallbackSuggestions,
        );
      },
    );
  }

  void sendMessage(String text) {
    if (_channel == null || text.trim().isEmpty) return;

    // Add user message to UI immediately and clear old suggestions
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isUser: true)],
      suggestions: [], 
    );

    _channel!.sink.add(text);
  }
}

final aiChatProvider = NotifierProvider.autoDispose<AiChatNotifier, AiChatState>(() {
  return AiChatNotifier();
});
