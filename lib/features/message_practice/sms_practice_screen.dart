import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/services/realistic_voice_service.dart';
import '../../core/widgets/global_notification_overlay.dart';
import '../../core/widgets/practice_tag.dart';
import 'providers/message_session_provider.dart';
import 'widgets/payload_widgets.dart';

/// Authentic Android Material 3 SMS Clone with two-tier navigation structure:
/// 1. Home Page: Standard SMS conversation list with official sender headers (AX-SBIBNK, VM-ELEC-PAY).
/// 2. Chat Page: Thread view with timestamped bubbles, quick OTP copy buttons,
///    phishing links rendered with [MaliciousLinkWidget], and quick replies.
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
  String _searchQuery = '';
  bool _isTtsSpeakerEnabled = false;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _lastSpokenMessageId;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scenario != null) {
        ref.read(messageSessionProvider.notifier).loadScenario(widget.scenario, 'Messages', autoOpenChat: true);
      } else if (widget.title != null || widget.initialMessage != null) {
        final dummyScenario = Scenario(
          id: 'custom_sms_drill',
          language: 'en',
          title: widget.title ?? 'Electricity Bill Alert',
          channel: 'sms',
          difficulty: 'medium',
          debriefSuccess: 'Stayed safe',
          debriefFailure: 'Compromised',
          scammerName: widget.title ?? 'VM-ELEC-PAY',
          initialMessage: widget.initialMessage ?? 'Power will be disconnected tonight at 9:30 PM. Pay now.',
        );
        ref.read(messageSessionProvider.notifier).loadScenario(dummyScenario, 'Messages', autoOpenChat: true);
      }
    });
  }

  @override
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (e) {
      debugPrint('[SmsPractice] Speech init error: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
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
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: true,
            partialResults: true,
          ),
        );
      }
    }
  }

  void _onReportScam(ConversationThread thread) {
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? thread.subtitle,
      channel: 'sms',
      status: 'deflected',
    );

    context.replace('/debrief', extra: {
      'outcome': 'success:deflected',
      'scenarioId': widget.scenario?.id,
      'hook': 'Artificial urgency and manipulative messaging',
      'leak': 'None! You reported the fake SMS sender.',
      'giveaway': 'Suspicious sender identity and demands for OTP or links.',
      'customMessage': 'Excellent defense! You reported the fake SMS scammer and passed the practice drill.',
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(messageSessionProvider.notifier).sendUserReply(
      app: 'Messages',
      text: text,
    );
    _textController.clear();
    _scrollToBottom();
  }

  void _copyOtpToClipboard(String otp) {
    Clipboard.setData(ClipboardData(text: otp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copied OTP $otp. ⚠️ Never share OTPs over call or message!',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFBA1A1A), // Warning red
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String? _extractOtp(String text) {
    final match = RegExp(r'\b\d{4,8}\b').firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MessageSessionState>(messageSessionProvider, (previous, next) {
      if (!_isTtsSpeakerEnabled) return;
      final activeThreadId = next.activeThreadId;
      if (activeThreadId == null) return;
      final activeThread = next.smsThreads.firstWhere(
        (t) => t.id == activeThreadId,
        orElse: () => next.smsThreads.first,
      );
      if (activeThread.messages.isNotEmpty) {
        final lastMsg = activeThread.messages.last;
        if (!lastMsg.isUser && lastMsg.id != _lastSpokenMessageId) {
          _lastSpokenMessageId = lastMsg.id;
          final lang = widget.scenario?.language ?? 'en';
          ref.read(realisticVoiceProvider).speakRealistic(lastMsg.text, lang);
        }
      }
    });

    final sessionState = ref.watch(messageSessionProvider);
    final activeThreadId = sessionState.activeThreadId;

    return GlobalNotificationOverlay(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Legal Practice Safety Tag
            const PracticeTag(),

            Expanded(
              child: activeThreadId == null
                  ? _buildHomePage(sessionState)
                  : _buildChatPage(sessionState, activeThreadId),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TIER 1: HOME PAGE (SMS INBOX)
  // ==========================================
  Widget _buildHomePage(MessageSessionState sessionState) {
    final threads = sessionState.smsThreads.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Material 3 Search Bar Pill
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search conversations',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF1E88E5),
                    child: Text('U', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Messages',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // SMS Threads List
            Expanded(
              child: ListView.separated(
                itemCount: threads.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, endIndent: 20, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  return _buildSmsListItem(thread);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Start chat', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {},
      ),
    );
  }

  Widget _buildSmsListItem(ConversationThread thread) {
    final timeStr = _formatTimestamp(thread.lastTimestamp);

    return InkWell(
      onTap: () {
        final notifier = ref.read(messageSessionProvider.notifier);
        notifier.selectThread(thread.id);
        notifier.markThreadRead('Messages', thread.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            // Sender Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: thread.avatarColor,
              child: Text(
                thread.avatarText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),

            // Header & Snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        thread.sender,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: thread.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: thread.unreadCount > 0 ? const Color(0xFF1A73E8) : const Color(0xFF64748B),
                          fontWeight: thread.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (thread.isScamActive)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                        ),
                      Expanded(
                        child: Text(
                          thread.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (thread.unreadCount > 0)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A73E8),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TIER 2: CHAT PAGE (SMS THREAD VIEW)
  // ==========================================
  Widget _buildChatPage(MessageSessionState sessionState, String threadId) {
    final thread = sessionState.smsThreads.firstWhere(
      (t) => t.id == threadId,
      orElse: () => sessionState.smsThreads.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (thread.isScamActive) {
              SimulationResult.recordResult(
                scenarioTitle: widget.scenario?.title ?? thread.subtitle,
                channel: 'sms',
                status: 'deflected',
              );
              context.replace('/debrief', extra: {
                'outcome': 'success:deflected',
                'scenarioId': widget.scenario?.id,
                'hook': 'Artificial urgency and panic via SMS',
                'leak': 'None! You safely left the suspicious SMS thread.',
                'giveaway': 'Generic sender ID, urgent demand for payment or links.',
                'customMessage': 'Smart choice! Ignoring and exiting suspicious SMS threads keeps you safe.',
              });
            } else {
              ref.read(messageSessionProvider.notifier).selectThread(null);
            }
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: thread.avatarColor,
              child: Text(
                thread.avatarText,
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.sender,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'SMS • Standard Network',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Report Scam Action Button
          TextButton.icon(
            key: const Key('sms_report_scam_button'),
            onPressed: () => _onReportScam(thread),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            icon: const Icon(Icons.shield_rounded, size: 16),
            label: const Text(
              'Report',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          IconButton(
            key: const Key('sms_tts_toggle_button'),
            icon: Icon(
              _isTtsSpeakerEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _isTtsSpeakerEnabled ? const Color(0xFF1A73E8) : const Color(0xFF64748B),
            ),
            tooltip: _isTtsSpeakerEnabled ? 'Mute AI voice readout' : 'Read AI messages aloud',
            onPressed: () {
              setState(() {
                _isTtsSpeakerEnabled = !_isTtsSpeakerEnabled;
              });
              if (!_isTtsSpeakerEnabled) {
                ref.read(realisticVoiceProvider).stop();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.phone_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          if (sessionState.isScamDetected)
            _buildScamDetectedBanner(sessionState.detectedScamReason),

          // Spam & Security Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF92400E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Practice Drill: Never share OTPs or click links from unknown numbers.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: thread.messages.length,
              itemBuilder: (context, index) {
                final message = thread.messages[index];
                return _buildSmsBubble(message);
              },
            ),
          ),

          // Quick Replies
          _buildQuickRepliesBar(),

          // SMS Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildScamDetectedBanner(String? reason) {
    return Container(
      key: const Key('sms_scam_detected_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFDCFCE7),
        border: Border(bottom: BorderSide(color: Color(0xFF86EFAC))),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF15803D), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason ?? 'Fraud Recognized! You detected this scam attempt.',
              style: const TextStyle(
                color: Color(0xFF15803D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              context.push('/debrief', extra: {
                'outcome': 'success:deflected',
                'scenarioId': widget.scenario?.id,
                'hook': 'Artificial urgency and manipulative messaging',
                'leak': 'None! You identified the scam and called out the scammer.',
                'giveaway': 'Suspicious sender, abnormal demand for payment or codes.',
                'customMessage': 'Splendid defense! You identified the scammer in the SMS thread and refused to fall for the trick.',
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Debrief', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsBubble(ChatMessageItem message) {
    final isUser = message.isUser;
    final timeStr = _formatTimestamp(message.timestamp);
    final detectedOtp = _extractOtp(message.text);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1A73E8) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Phishing / Malicious Link or multi-modal payload
            if (message.payloadType == MessagePayloadType.link || message.text.contains('http')) ...[
              MaliciousLinkWidget(
                url: message.payloadUrl ?? _extractFirstUrl(message.text),
                title: message.payloadTitle ?? 'Urgent Verification Link',
                description: message.payloadDescription ?? 'Click to resolve immediately',
                onTap: () {
                  context.push('/practice/web', extra: widget.scenario);
                },
              ),
              const SizedBox(height: 8),
            ],

            // 2. Message Text
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: isUser ? Colors.white : const Color(0xFF0F172A),
                height: 1.35,
              ),
            ),

            // 3. Quick OTP Copy Button (if OTP found in text)
            if (!isUser && detectedOtp != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _copyOtpToClipboard(detectedOtp),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        'Copy OTP ($detectedOtp)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 4),

            // 4. Timestamp
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isUser ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    return match?.group(0) ?? 'https://mseb-bill-pay.in/verify';
  }

  Widget _buildQuickRepliesBar() {
    final replies = [
      'I will verify with official customer care.',
      'Do not send spam messages to my number.',
      'I am reporting this to 1930.',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: replies.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                backgroundColor: const Color(0xFFF1F5F9),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                label: Text(
                  reply,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  ref.read(messageSessionProvider.notifier).sendUserReply(
                    app: 'Messages',
                    text: reply,
                  );
                  _scrollToBottom();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 8),

          // Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Text (SMS)...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    key: const Key('sms_mic_button'),
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? Colors.redAccent : const Color(0xFF64748B),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Tap to speak',
                    onPressed: _toggleListening,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF1A73E8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
