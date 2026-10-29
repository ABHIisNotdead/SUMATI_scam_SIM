import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  @override
  AiChatState build() {
    ref.onDispose(() {
      _channel?.sink.close();
    });
    return AiChatState(messages: []);
  }

  void connect(String persona, String initialMessage) {
    final encodedPersona = Uri.encodeComponent(persona);
    final encodedMsg = Uri.encodeComponent(initialMessage);
    final wsUrl = Uri.parse('ws://127.0.0.1:8000/ws/chat?persona=$encodedPersona&initial_message=$encodedMsg');
    
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen(
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
        state = state.copyWith(
          messages: [...state.messages, ChatMessage(text: "Connection lost. Please make sure backend is running.", isUser: false)],
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
