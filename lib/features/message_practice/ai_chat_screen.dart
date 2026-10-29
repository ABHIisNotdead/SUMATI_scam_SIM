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
import '../../core/services/realistic_voice_service.dart';
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
      final lang = ref.read(preferencesProvider).appLanguage;
      ref.read(aiChatProvider.notifier).connect(
            widget.persona,
            widget.initialMessage,
            lang: lang,
          );
    });
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _startListening() async {
    FocusScope.of(context).unfocus(); // hide keyboard
    try {
      await _speechToText.listen(onResult: (result) {
        if (mounted) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        }
      });
      if (mounted) setState(() => _isListening = true);
    } catch (_) {}
  }

  void _stopListening() async {
    try {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    } catch (_) {}
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

  void _sendMessage([String? predefinedText]) {
    final text = predefinedText ?? _textController.text;
    if (text.trim().isNotEmpty) {
      ref.read(aiChatProvider.notifier).sendMessage(text.trim());
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSuccess ? AppTheme.primaryFixed : AppTheme.tertiaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: isSuccess ? AppTheme.primary : AppTheme.tertiary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuccess
                    ? UiStrings.get(lang, 'scam_avoided')
                    : UiStrings.get(lang, 'simulation_ended'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
              ),
            ),
          ],
        ),
        content: Text(
          evaluation,
          style: const TextStyle(fontSize: 16, height: 1.4, color: AppTheme.onSurfaceVariant),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? AppTheme.primaryContainer : AppTheme.tertiary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                UiStrings.get(lang, 'finish_practice'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
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
    final screenTitle = widget.title ?? UiStrings.get(lang, 'unknown_number');

    // Listen for Game Over (Compromised or Deflected) to record result and show debrief
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
      backgroundColor: AppTheme.surface,
      appBar: ScamShieldAppBar(
        title: screenTitle,
      ),
      body: Column(
        children: [
          const PracticeTag(),

          // 1. Chat History Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg.isUser;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppTheme.primaryContainer
                          : AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: const Color(0xFFE2E6E2), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.tertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                screenTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                            color: isUser ? Colors.white : AppTheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                        if (!isUser) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => ref.read(realisticVoiceProvider).speakRealistic(msg.text, lang),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryFixed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    UiStrings.get(lang, 'listen_aloud'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Dynamic Suggested Replies Grid (Tremble-Safe Senior Cards)
          if (suggestions.isNotEmpty && chatState.status == 'ongoing')
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E6E2), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        UiStrings.get(lang, 'tap_to_reply'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 2.3,
                    ),
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return Material(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onLongPress: () {
                            ref.read(realisticVoiceProvider).speakRealistic(suggestion, lang);
                          },
                          onTap: () => _sendMessage(suggestion),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            alignment: Alignment.center,
                            child: Text(
                              suggestion,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // 3. Senior Push-to-Talk and Text Input Bar
          Container(
            color: AppTheme.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? UiStrings.get(lang, 'listening_chat')
                          : UiStrings.get(lang, 'type_or_talk'),
                      hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Microphone Push-to-Talk Button
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  onTapCancel: () => _stopListening(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isListening ? AppTheme.tertiary : AppTheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: _isListening ? Colors.white : AppTheme.primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),

          // 4. Emergency Panic Station
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: IFeelWorriedButton(),
          ),
        ],
      ),
    );
  }
}
