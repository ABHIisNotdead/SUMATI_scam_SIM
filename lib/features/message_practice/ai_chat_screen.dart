import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scam_shield_app_bar.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/i_feel_worried_button.dart';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/tts_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiChatScreen extends ConsumerStatefulWidget {
  final String persona;
  final String initialMessage;
  final String? title;

  const AiChatScreen({
    super.key,
    required this.persona,
    required this.initialMessage,
    this.title,
  });

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Voice recognition variables
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).connect(widget.persona, widget.initialMessage);
    });
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    FocusScope.of(context).unfocus(); // hide keyboard
    await _speechToText.listen(onResult: (result) {
      setState(() {
        _textController.text = result.recognizedWords;
      });
    });
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      ref.read(aiChatProvider.notifier).sendMessage(text);
      _textController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _showDebriefDialog(String status, String evaluation, String lang) {
    final isSuccess = status == 'deflected';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isSuccess ? Colors.green : AppTheme.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              isSuccess
                  ? UiStrings.get(lang, 'scam_avoided')
                  : UiStrings.get(lang, 'simulation_ended'),
            ),
          ],
        ),
        content: Text(evaluation, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to Home/Picker
            },
            child: Text(
              UiStrings.get(lang, 'finish_practice'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final messages = chatState.messages;
    final suggestions = chatState.suggestions;
    final lang = ref.watch(preferencesProvider).appLanguage;

    // Listen for Game Over (Compromised or Deflected) to show debrief
    ref.listen<AiChatState>(aiChatProvider, (previous, next) {
      if (next.status != 'ongoing' && next.evaluation != null && previous?.status == 'ongoing') {
        SimulationResult.recordResult(
          scenarioTitle: 'AI Chat: ${widget.persona}',
          channel: 'whatsapp',
          status: next.status,
        );
        _showDebriefDialog(next.status, next.evaluation!, lang);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: ScamShieldAppBar(
        title: widget.title ?? UiStrings.get(lang, 'unknown_number'),
      ),
      body: Column(
        children: [
          const PracticeTag(),

          // 1. Chat History List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFFDCF8C6) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(msg.text, style: const TextStyle(fontSize: 18, color: Colors.black87)),
                        ),
                        if (!msg.isUser) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              ref.read(ttsProvider).speak(msg.text);
                            },
                            child: const Icon(Icons.volume_up, color: AppTheme.primaryTeal, size: 22),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Dynamic Suggested Replies Grid (2x2 Layout)
          if (suggestions.isNotEmpty && chatState.status == 'ongoing')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio: 2.2,
                ),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return GestureDetector(
                    onLongPress: () {
                      ref.read(ttsProvider).speak(suggestion);
                    },
                    onTap: () {
                      ref.read(aiChatProvider.notifier).sendMessage(suggestion);
                      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                    },
                    child: Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
                      ),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Text(
                            suggestion,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTeal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 3. Input Area with Microphone
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? UiStrings.get(lang, 'listening_chat')
                          : UiStrings.get(lang, 'type_or_talk'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Microphone Button
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  onTapCancel: () => _stopListening(),
                  child: CircleAvatar(
                    backgroundColor: _isListening ? AppTheme.red : Colors.grey.shade600,
                    radius: 22,
                    child: const Icon(Icons.mic, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                CircleAvatar(
                  backgroundColor: AppTheme.primaryTeal,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: IFeelWorriedButton(),
          ),
        ],
      ),
    );
  }
}
