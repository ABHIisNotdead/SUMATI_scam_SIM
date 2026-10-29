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

class SmsPracticeScreen extends ConsumerStatefulWidget {
  final Scenario? scenario;
  final String? persona;
  final String? initialMessage;
  final String? title;

  const SmsPracticeScreen({
    super.key,
    this.scenario,
    this.persona,
    this.initialMessage,
    this.title,
  });

  @override
  ConsumerState<SmsPracticeScreen> createState() => _SmsPracticeScreenState();
}

class _SmsPracticeScreenState extends ConsumerState<SmsPracticeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  String? _speakingMsgText;

  late final String _activePersona;
  late final String _activeInitialMsg;
  late final String _senderId;

  @override
  void initState() {
    super.initState();
    _activePersona = widget.persona ?? widget.scenario?.persona ?? 'a scammer attempting fraud via SMS';
    _activeInitialMsg = widget.initialMessage ??
        widget.scenario?.initialMessage ??
        'ALERT: Your electricity bill of ₹1,450 is overdue. Update urgently to avoid disconnection.';
    _senderId = widget.title ??
        widget.scenario?.scammerName ??
        widget.scenario?.title ??
        'VM-ELECT';

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
                    color: const Color(0xFFD3E3FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Color(0xFF0B57D0), size: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  lang == 'hi' ? 'एसएमएस का बोलकर जवाब दें' : 'Speak SMS Reply',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildVoiceOption('I will not click any links.', 'मैं किसी भी लिंक पर क्लिक नहीं करूँगा।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('I am reporting this SMS as spam.', 'मैं इस संदेश को स्पैम रिपोर्ट कर रहा हूँ।', ctx),
            const SizedBox(height: 8),
            _buildVoiceOption('I will pay my bill directly at the office.', 'मैं सीधे दफ्तर जाकर बिल भरूँगा।', ctx),
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
          color: const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD3E3FD)),
        ),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over_rounded, color: Color(0xFF0B57D0), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.send_rounded, size: 16, color: Color(0xFF0B57D0)),
          ],
        ),
      ),
    );
  }

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
                lang == 'hi' ? 'स्पैम रिपोर्ट व डिलीट करें?' : 'Report Spam & Delete?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          lang == 'hi'
              ? 'क्या आप इस प्रेषक ($_senderId) को स्पैम रिपोर्ट करके चैट हटाना चाहते हैं? यह साइबर सुरक्षा का सही कदम है।'
              : 'Do you want to report this SMS sender as spam and delete the thread? This is the recommended action.',
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(UiStrings.get(lang, 'cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
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
            child: Text(lang == 'hi' ? 'रिपोर्ट व हटाएं' : 'Report & Delete', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _endChatAsReported(String lang) {
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? _senderId,
      channel: 'sms',
      status: 'deflected',
    );

    final evaluation = lang == 'hi'
        ? 'शानदार बचाव! आपने फर्जी एसएमएस लिंक पर क्लिक करने के बजाय इसे स्पैम रिपोर्ट कर हटा दिया। आपका सुरक्षा स्कोर बढ़ गया है!'
        : 'Outstanding defense! You refused to click suspicious SMS links, reported it as spam, and deleted the threat. Your Safety Score increased!';

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
                backgroundColor: isSuccess ? const Color(0xFF0B57D0) : AppTheme.tertiary,
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

  String _getInitials(String name) {
    if (name.isEmpty) return 'S';
    final parts = name.split(RegExp(r'[\s\-_]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final messages = chatState.messages;
    final suggestions = chatState.suggestions;
    final lang = ref.watch(preferencesProvider).appLanguage;

    ref.listen<AiChatState>(aiChatProvider, (previous, next) {
      if (next.status != 'ongoing' && next.evaluation != null && previous?.status == 'ongoing') {
        SimulationResult.recordResult(
          scenarioTitle: widget.scenario?.title ?? _senderId,
          channel: 'sms',
          status: next.status,
        );
        _showDebriefDialog(next.status, next.evaluation!, lang);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F1F1F)),
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
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFD3E3FD),
              child: Text(
                _getInitials(_senderId),
                style: const TextStyle(
                  color: Color(0xFF0B57D0),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _senderId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1F1F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 16),
                    ],
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'SMS • SIM 1 (Airtel)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5E5E5E)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 🚨 Quick Report Action Pill
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
                    Text('Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1F1F1F)),
            onPressed: () => _confirmReportAndDelete(lang),
          ),
        ],
      ),
      body: Column(
        children: [
          const PracticeTag(),

          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAED),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '💬 Texting with $_senderId (SMS/MMS)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444746),
                      ),
                    ),
                  ),
                ),

                // Report Spam Banner
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_update_warning_rounded, color: Color(0xFFC62828), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lang == 'hi' ? 'संदिग्ध एसएमएस? इसे स्पैम रिपोर्ट करें।' : 'Suspected spam SMS?',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _confirmReportAndDelete(lang),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(lang == 'hi' ? 'रिपोर्ट' : 'Report Spam', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),

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
                        color: isUser ? const Color(0xFF0B57D0) : const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: isUser ? Colors.white : const Color(0xFF1F1F1F),
                              height: 1.35,
                            ),
                          ),

                          // 🔊 Big Accessible Speaker Button with Realistic Neural Voice
                          if (!isUser) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _toggleMessageSpeech(msg.text, lang),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPlayingThis ? const Color(0xFFFFDAD7) : const Color(0xFFD3E3FD),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPlayingThis ? const Color(0xFFC62828) : const Color(0xFF0B57D0),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPlayingThis ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                      size: 20,
                                      color: isPlayingThis ? const Color(0xFFC62828) : const Color(0xFF0B57D0),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPlayingThis
                                          ? (lang == 'hi' ? 'आवाज रोकें (Stop)' : 'Stop Voice')
                                          : (lang == 'hi' ? 'बोलकर सुनें (Listen)' : 'Listen Aloud'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isPlayingThis ? const Color(0xFFC62828) : const Color(0xFF0B57D0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 4),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Spacer(),
                              Text(
                                isUser ? 'Sent as SMS • 10:44 AM' : '10:43 AM • SIM 1',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isUser ? Colors.white70 : const Color(0xFF747775),
                                ),
                              ),
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

          if (suggestions.isNotEmpty && chatState.status == 'ongoing')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(
                          s,
                          style: const TextStyle(
                            color: Color(0xFF0B57D0),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: const Color(0xFFF1F3F4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFD3E3FD)),
                        ),
                        onPressed: () => _sendMessage(s),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(fontSize: 16),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? (lang == 'hi' ? 'माइक सुन रहा है... बोलिए' : 'Listening... Speak now')
                                  : 'Text message',
                              hintStyle: TextStyle(
                                color: _isListening ? const Color(0xFFC62828) : const Color(0xFF747775),
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
                          icon: const Icon(Icons.mood, color: Color(0xFF444746), size: 22),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                InkWell(
                  onTap: () {
                    if (_textController.text.trim().isNotEmpty) {
                      _sendMessage();
                    } else {
                      _toggleListening();
                    }
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFC62828) : const Color(0xFF0B57D0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _textController.text.trim().isNotEmpty
                          ? Icons.arrow_upward_rounded
                          : (_isListening ? Icons.mic : Icons.mic_rounded),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: IFeelWorriedButton(),
          ),
        ],
      ),
    );
  }
}
