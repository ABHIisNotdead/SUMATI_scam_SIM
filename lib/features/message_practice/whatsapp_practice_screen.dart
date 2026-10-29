import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/localization/ui_strings.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/realistic_voice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/i_feel_worried_button.dart';
import '../../core/widgets/practice_tag.dart';

class WhatsAppPracticeScreen extends ConsumerStatefulWidget {
  final Scenario? scenario;
  final String? persona;
  final String? initialMessage;
  final String? title;

  const WhatsAppPracticeScreen({
    super.key,
    this.scenario,
    this.persona,
    this.initialMessage,
    this.title,
  });

  @override
  ConsumerState<WhatsAppPracticeScreen> createState() => _WhatsAppPracticeScreenState();
}

class _WhatsAppPracticeScreenState extends ConsumerState<WhatsAppPracticeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  String? _speakingMsgText; // Currently playing speech

  late final String _activePersona;
  late final String _activeInitialMsg;
  late final String _contactName;

  @override
  void initState() {
    super.initState();
    _activePersona = widget.persona ?? widget.scenario?.persona ?? 'a scammer attempting fraud';
    _activeInitialMsg = widget.initialMessage ??
        widget.scenario?.initialMessage ??
        'Hello. Urgent action is required regarding your account.';
    _contactName = widget.title ??
        widget.scenario?.scammerName ??
        widget.scenario?.title ??
        '+91 98201 54321';

    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(preferencesProvider).appLanguage;
      ref.read(aiChatProvider.notifier).connect(
            _activePersona,
            _activeInitialMsg,
            lang: lang,
          );
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechAvailable = false;
    }
  }

  // ── Toggle Mic (Works on Mobile, Web & Desktop with Modal Fallback) ────────
  void _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      if (_textController.text.trim().isNotEmpty) {
        _sendMessage();
      }
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_speechAvailable) {
      await _initSpeech();
    }

    if (_speechAvailable) {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              setState(() => _isListening = false);
              _sendMessage(result.recognizedWords);
            }
          }
        },
      );
    } else {
      // Fallback voice input modal for browser/unsupported platforms
      _showVoiceSimulationModal();
    }
  }

  void _showVoiceSimulationModal() {
    final lang = ref.read(preferencesProvider).appLanguage;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Color(0xFF008069), size: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  lang == 'hi' ? 'बोलकर जवाब दें (Voice Reply)' : 'Speak Reply (Voice Input)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              lang == 'hi'
                  ? 'अपनी आवाज से इनमें से कोई भी उत्तर तुरंत भेजें:'
                  : 'Tap any spoken response to send instantly via voice:',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            _buildVoiceOption('Who are you? I will not share OTP.', 'आप कौन हैं? मैं ओटीपी नहीं दूँगा।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('I am going to the police station now.', 'मैं अभी पुलिस स्टेशन जाकर पता करूँगा।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('I will visit the bank branch in person.', 'मैं खुद बैंक शाखा जाकर बात करूँगा।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('Please stop messaging me. I am blocking you.', 'मुझे मैसेज करना बंद करें। मैं आपको ब्लॉक कर रहा हूँ।', ctx),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceOption(String enText, String hiText, BuildContext ctx) {
    final lang = ref.read(preferencesProvider).appLanguage;
    final text = lang == 'hi' ? hiText : enText;

    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _sendMessage(text);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0DDD6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over_rounded, color: Color(0xFF008069), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.send_rounded, size: 16, color: Color(0xFF008069)),
          ],
        ),
      ),
    );
  }

  // ── Realistic Studio Neural Voice Aloud (Big Speaker Button) ───────────────
  void _toggleMessageSpeech(String text, String lang) async {
    final voiceService = ref.read(realisticVoiceProvider);
    if (_speakingMsgText == text) {
      await voiceService.stop();
      setState(() => _speakingMsgText = null);
    } else {
      setState(() => _speakingMsgText = text);
      await voiceService.speakRealistic(text, lang, onComplete: () {
        if (mounted) setState(() => _speakingMsgText = null);
      });
    }
  }

  // ── Delete & Report Chat Action ───────────────────────────────────────────
  void _confirmReportAndDelete(String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.report_problem_rounded, color: Color(0xFFC62828), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang == 'hi' ? 'ब्लॉक व चैट हटाएं?' : 'Report & Delete Chat?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          lang == 'hi'
              ? 'क्या आप इस नंबर ($_contactName) को ब्लॉक करना चाहते हैं और चैट हटाना चाहते हैं? यह साइबर सुरक्षा का सही और अनुशंसित कदम है।'
              : 'Do you want to report this contact as a scammer and delete the chat? This is the recommended cyber defense reflex.',
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              UiStrings.get(lang, 'cancel'),
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endChatAsReported(lang);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              lang == 'hi' ? 'ब्लॉक व हटाएं (Report)' : 'Report & Delete',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _endChatAsReported(String lang) {
    // Record successful deflection in Hive
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? _contactName,
      channel: 'whatsapp',
      status: 'deflected',
    );

    final evaluation = lang == 'hi'
        ? 'उत्कृष्ट निर्णय! आपने जालसाज से बात करने या पैसे देने के बजाय चैट को तुरंत ब्लॉक और डिलीट कर दिया। आपका सुरक्षा स्कोर बढ़ गया है!'
        : 'Outstanding defense! You refused to comply, blocked the scammer, and deleted the fraudulent chat. Your Senior Safety Score has increased!';

    _showDebriefDialog('deflected', evaluation, lang);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    ref.read(realisticVoiceProvider).stop();
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

  void _sendMessage([String? textToSend]) {
    final text = textToSend ?? _textController.text;
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
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuccess
                    ? UiStrings.get(lang, 'scam_avoided')
                    : UiStrings.get(lang, 'simulation_ended'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          evaluation,
          style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? const Color(0xFF008069) : AppTheme.tertiary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    // Listen for Game Over to record result and trigger debrief
    ref.listen<AiChatState>(aiChatProvider, (previous, next) {
      if (next.status != 'ongoing' && next.evaluation != null && previous?.status == 'ongoing') {
        SimulationResult.recordResult(
          scenarioTitle: widget.scenario?.title ?? _contactName,
          channel: 'whatsapp',
          status: next.status,
        );
        _showDebriefDialog(next.status, next.evaluation!, lang);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // Authentic WhatsApp beige chat background
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069), // Authentic WhatsApp Android Teal
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Row(
          children: [
            // WhatsApp Contact Avatar
            Stack(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFDFE5E7),
                  child: Icon(Icons.person, color: Colors.white, size: 26),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF008069), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _contactName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'online',
                    style: TextStyle(fontSize: 12, color: Color(0xFFD1F4EC)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 🚨 APPBAR ACTION: Quick Report & End Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: InkWell(
              onTap: () => _confirmReportAndDelete(lang),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.block_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Report',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _confirmReportAndDelete(lang),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Safety Practice Tag Ribbon
          const PracticeTag(),

          // 2. Chat Conversation View
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // Authentic WhatsApp Date Pill
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF54656F),
                      ),
                    ),
                  ),
                ),

                // Authentic WhatsApp End-to-End Encryption Notice Pill
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5C4),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_rounded, size: 12, color: Color(0xFF54656F)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Messages and calls are end-to-end encrypted. No one outside of this chat can read them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF54656F),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🚨 AUTHENTIC WHATSAPP UNKNOWN CONTACT SCAM WARNING BANNER
                // Allows user to Delete & Report Chat immediately to end the simulation safely
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFCDD2), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security_update_warning_rounded, color: Color(0xFFC62828), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang == 'hi'
                                  ? 'यह नंबर आपकी कांटेक्ट लिस्ट में नहीं है। क्या यह फ्रॉड है?'
                                  : 'This sender is not in your contacts. Suspicious activity?',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Primary Red "Block & Report" Button
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmReportAndDelete(lang),
                                icon: const Icon(Icons.block_rounded, size: 16),
                                label: Text(
                                  lang == 'hi' ? 'ब्लॉक व रिपोर्ट (Report)' : 'Block & Report',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC62828),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Secondary "Delete Chat" Button
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: OutlinedButton.icon(
                                onPressed: () => _confirmReportAndDelete(lang),
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: Text(
                                  lang == 'hi' ? 'चैट हटाएं (Delete)' : 'Delete Chat',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF54656F),
                                  side: const BorderSide(color: Color(0xFFB0BEC5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Messages Stream
                ...messages.map((msg) {
                  final isUser = msg.isUser;
                  final isPlayingThis = _speakingMsgText == msg.text;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFFD9FDD3) : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: isUser ? const Radius.circular(14) : Radius.zero,
                          topRight: isUser ? Radius.zero : const Radius.circular(14),
                          bottomLeft: const Radius.circular(14),
                          bottomRight: const Radius.circular(14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Message Text
                          Text(
                            msg.text,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF111B21),
                              height: 1.35,
                            ),
                          ),

                          // 🔊 BIG ACCESSIBLE SPEAKER BUTTON FOR INCOMING MESSAGES
                          if (!isUser) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _toggleMessageSpeech(msg.text, lang),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPlayingThis ? const Color(0xFFFFDAD7) : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPlayingThis ? const Color(0xFFC62828) : const Color(0xFF008069),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPlayingThis ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                      size: 20,
                                      color: isPlayingThis ? const Color(0xFFC62828) : const Color(0xFF008069),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPlayingThis
                                          ? (lang == 'hi' ? 'आवाज रोकें (Stop)' : 'Stop Voice')
                                          : (lang == 'hi' ? 'बोलकर सुनें (Listen)' : 'Listen Aloud'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isPlayingThis ? const Color(0xFFC62828) : const Color(0xFF008069),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 4),

                          // Timestamp & Read Receipt
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              const Text(
                                '10:42 AM',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF667781),
                                ),
                              ),
                              if (isUser) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.done_all_rounded,
                                  size: 16,
                                  color: Color(0xFF53BDEB), // WhatsApp blue double tick
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // 3. Dynamic WhatsApp Quick Reply Chips (Senior Friendly)
          if (suggestions.isNotEmpty && chatState.status == 'ongoing')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white.withValues(alpha: 0.95),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF008069)),
                      const SizedBox(width: 6),
                      Text(
                        UiStrings.get(lang, 'tap_to_reply'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF008069),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions.map((s) {
                      return InkWell(
                        onTap: () => _sendMessage(s),
                        onLongPress: () => ref.read(realisticVoiceProvider).speakRealistic(s, lang),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF008069), width: 1.2),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF008069),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // 4. Authentic WhatsApp Bottom Input Bar with Working Mic Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.transparent,
            child: Row(
              children: [
                // Input Pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF8696A0), size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(fontSize: 16),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? (lang == 'hi' ? 'माइक सुन रहा है... बोलिए' : 'Listening... Speak now')
                                  : 'Message',
                              hintStyle: TextStyle(
                                color: _isListening ? const Color(0xFFC62828) : const Color(0xFF8696A0),
                                fontSize: 16,
                                fontWeight: _isListening ? FontWeight.w700 : FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Color(0xFF8696A0), size: 22),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Color(0xFF8696A0), size: 22),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // WhatsApp Green Action Circle (Mic Toggle / Send)
                InkWell(
                  onTap: () {
                    if (_textController.text.trim().isNotEmpty) {
                      _sendMessage();
                    } else {
                      _toggleListening();
                    }
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFC62828) : const Color(0xFF008069),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? const Color(0xFFC62828) : const Color(0xFF008069))
                              .withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _textController.text.trim().isNotEmpty
                          ? Icons.send_rounded
                          : (_isListening ? Icons.mic : Icons.mic_rounded),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Emergency Panic Shield Button
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: IFeelWorriedButton(),
          ),
        ],
      ),
    );
  }
}
