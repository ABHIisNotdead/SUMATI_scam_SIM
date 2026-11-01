import 'package:flutter/material.dart';
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

/// Authentic FWhatsApp Clone with two-tier navigation structure:
/// 1. Home Page: Recent chats list, search bar, tabs, avatars, previews, unread badges.
/// 2. Chat Page: Signature WhatsApp header, encryption notice, read receipts, and
///    multi-modal payload cards (Link, Blurred Image, QR, APK, ZIP).
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

class _WhatsAppPracticeScreenState extends ConsumerState<WhatsAppPracticeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isTtsSpeakerEnabled = false;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _lastSpokenMessageId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scenario != null) {
        ref.read(messageSessionProvider.notifier).loadScenario(widget.scenario, 'FWhatsApp', autoOpenChat: true);
      } else if (widget.title != null || widget.initialMessage != null) {
        // Direct route with custom parameters
        final dummyScenario = Scenario(
          id: 'custom_drill',
          language: 'en',
          title: widget.title ?? 'Bank Security Verification',
          channel: 'whatsapp',
          difficulty: 'medium',
          debriefSuccess: 'Stayed safe',
          debriefFailure: 'Compromised',
          scammerName: widget.title ?? 'SBI Support Desk',
          initialMessage: widget.initialMessage ?? 'Your account is scheduled for verification.',
        );
        ref.read(messageSessionProvider.notifier).loadScenario(dummyScenario, 'FWhatsApp', autoOpenChat: true);
      }
    });
  }

  @override
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _tabController.dispose();
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
      debugPrint('[WhatsAppPractice] Speech init error: $e');
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
      channel: 'whatsapp',
      status: 'deflected',
    );

    context.replace('/debrief', extra: {
      'outcome': 'success:deflected',
      'scenarioId': widget.scenario?.id,
      'hook': 'Artificial urgency and manipulative messaging',
      'leak': 'None! You reported the fake scammer.',
      'giveaway': 'Suspicious sender identity and coercive requests.',
      'customMessage': 'Excellent defense! You reported the fake WhatsApp scammer and passed the practice drill.',
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
      app: 'FWhatsApp',
      text: text,
    );
    _textController.clear();
    _scrollToBottom();
  }

  void _onPayloadTapped(ChatMessageItem message) {
    if (message.payloadType == MessagePayloadType.link) {
      context.push('/practice/web', extra: widget.scenario);
      return;
    }

    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'WhatsApp Scam Practice',
      channel: 'whatsapp',
      status: 'compromised',
    );

    context.replace('/debrief', extra: {
      'outcome': 'failure:compromised',
      'scenarioId': widget.scenario?.id,
      'hook': 'Artificial urgency and manipulated file/link attachment',
      'leak': 'Device Malware / Credential Exposure: Interacted with dangerous ${message.payloadType.name.toUpperCase()} payload.',
      'giveaway': 'Unknown sender sent an executable APK/ZIP/QR payload demanding immediate installation or payment.',
      'customMessage': 'Caution! Installing unknown APK/ZIP files or scanning unverified QR codes compromises your mobile security.',
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MessageSessionState>(messageSessionProvider, (previous, next) {
      if (!_isTtsSpeakerEnabled) return;
      final activeThreadId = next.activeThreadId;
      if (activeThreadId == null) return;
      final activeThread = next.whatsappThreads.firstWhere(
        (t) => t.id == activeThreadId,
        orElse: () => next.whatsappThreads.first,
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
        body: Column(
          children: [
            // Legal Practice Safety Ribbon
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
  // TIER 1: HOME PAGE (RECENT CHATS LIST)
  // ==========================================
  Widget _buildHomePage(MessageSessionState sessionState) {
    final threads = sessionState.whatsappThreads.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54), // Signature WhatsApp Teal Green
        foregroundColor: Colors.white,
        elevation: 1,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text(
                'WhatsApp',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.2),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Chats Tab
          ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, endIndent: 16),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return _buildChatListItem(thread);
            },
          ),

          // 2. Status Tab (Authentic filler)
          Center(
            child: Text(
              'No recent status updates',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),

          // 3. Calls Tab (Authentic filler)
          Center(
            child: Text(
              'To start a call, tap the Phone app in the OS Shell',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        onPressed: () {},
        child: const Icon(Icons.message_rounded),
      ),
    );
  }

  Widget _buildChatListItem(ConversationThread thread) {
    final timeStr = _formatTimestamp(thread.lastTimestamp);

    return InkWell(
      onTap: () {
        final notifier = ref.read(messageSessionProvider.notifier);
        notifier.selectThread(thread.id);
        notifier.markThreadRead('FWhatsApp', thread.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: thread.avatarColor,
              child: Text(
                thread.avatarText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),

            // Name & Subtitle Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          thread.sender,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: thread.unreadCount > 0 ? const Color(0xFF25D366) : Colors.grey.shade600,
                          fontWeight: thread.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (thread.isScamActive)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                        ),
                      Expanded(
                        child: Text(
                          thread.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (thread.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${thread.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
  // TIER 2: CHAT PAGE (ACTIVE CONVERSATION)
  // ==========================================
  Widget _buildChatPage(MessageSessionState sessionState, String threadId) {
    final thread = sessionState.whatsappThreads.firstWhere(
      (t) => t.id == threadId,
      orElse: () => sessionState.whatsappThreads.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // Authentic WhatsApp Chat Wallpaper tint
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        leadingWidth: 70,
        leading: InkWell(
          onTap: () {
            if (thread.isScamActive) {
              SimulationResult.recordResult(
                scenarioTitle: widget.scenario?.title ?? thread.subtitle,
                channel: 'whatsapp',
                status: 'deflected',
              );
              context.replace('/debrief', extra: {
                'outcome': 'success:deflected',
                'scenarioId': widget.scenario?.id,
                'hook': 'Artificial urgency and manipulative messaging',
                'leak': 'None! You safely backed out of the suspicious chat.',
                'giveaway': 'Unknown sender claiming urgent action required.',
                'customMessage': 'Safe move! Backing out of suspicious chats prevents fraudulent manipulation.',
              });
            } else {
              ref.read(messageSessionProvider.notifier).selectThread(null);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              const Icon(Icons.arrow_back, size: 22),
              const SizedBox(width: 2),
              CircleAvatar(
                radius: 17,
                backgroundColor: thread.avatarColor,
                child: Text(
                  thread.avatarText,
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thread.sender,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'online',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Report Scam Action Button
          TextButton.icon(
            key: const Key('whatsapp_report_scam_button'),
            onPressed: () => _onReportScam(thread),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFDE047),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            icon: const Icon(Icons.shield_rounded, size: 16),
            label: const Text(
              'Report',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          IconButton(
            key: const Key('whatsapp_tts_toggle_button'),
            icon: Icon(
              _isTtsSpeakerEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _isTtsSpeakerEnabled ? const Color(0xFF25D366) : Colors.white70,
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
          IconButton(icon: const Icon(Icons.videocam_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          if (sessionState.isScamDetected)
            _buildScamDetectedBanner(sessionState.detectedScamReason),

          // Chat Stream Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: thread.messages.length + 1, // +1 for encryption notice banner
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildEncryptionNotice();
                }
                final message = thread.messages[index - 1];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Seniors Quick Response Pills
          _buildQuickRepliesBar(),

          // WhatsApp Bottom Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildScamDetectedBanner(String? reason) {
    return Container(
      key: const Key('whatsapp_scam_detected_banner'),
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
                'customMessage': 'Splendid defense! You identified the scammer in the messaging thread and refused to fall for the trick.',
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

  Widget _buildEncryptionNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4), // Amber tint encryption banner
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lock_rounded, size: 13, color: Color(0xFF856404)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Messages and calls are end-to-end encrypted. No one outside of this chat, not even WhatsApp, can read or listen to them.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF856404),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem message) {
    final isUser = message.isUser;
    final timeStr = _formatTimestamp(message.timestamp);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFE7FFDB) : Colors.white, // WhatsApp green vs white bubble
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Multi-modal Payload Widget (if any)
            if (message.payloadType != MessagePayloadType.text) ...[
              _buildPayloadCard(message),
              const SizedBox(height: 6),
            ],

            // 2. Message Text Body
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),

            const SizedBox(height: 3),

            // 3. Time + Double Checkmarks
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 15,
                    color: Color(0xFF34B7F1), // Read blue double ticks
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadCard(ChatMessageItem message) {
    switch (message.payloadType) {
      case MessagePayloadType.link:
        return MaliciousLinkWidget(
          url: message.payloadUrl ?? message.text,
          title: message.payloadTitle,
          description: message.payloadDescription,
          onTap: () => _onPayloadTapped(message),
        );
      case MessagePayloadType.image:
        return BlurredImageWidget(
          caption: message.text,
          fileSize: message.fileSize ?? '1.8 MB',
          previewLabel: message.payloadTitle,
          onTap: () => _onPayloadTapped(message),
        );
      case MessagePayloadType.qr:
        return QrCodePayloadWidget(
          payeeName: message.payloadTitle ?? 'Official Verification Pool',
          upiId: message.upiId ?? 'mseb.verify@oksbi',
          amount: message.amount ?? '₹1,450.00',
          purpose: message.text,
          onTap: () => _onPayloadTapped(message),
        );
      case MessagePayloadType.apk:
        return DummyApkWidget(
          fileName: message.fileName ?? 'KSEB_Quick_Pay.apk',
          fileSize: message.fileSize ?? '14.8 MB',
          onTap: () => _onPayloadTapped(message),
        );
      case MessagePayloadType.zip:
        return DummyZipWidget(
          fileName: message.fileName ?? 'COURT_EVIDENCE.zip',
          fileSize: message.fileSize ?? '6.4 MB',
          onTap: () => _onPayloadTapped(message),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuickRepliesBar() {
    final replies = [
      'Who is speaking and what is your ID?',
      'I will verify this with my local branch directly.',
      'I will not click any unknown links.',
    ];

    return Container(
      color: Colors.white.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: replies.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                backgroundColor: const Color(0xFFE8F5E9),
                side: const BorderSide(color: Color(0xFF81C784)),
                label: Text(
                  reply,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  ref.read(messageSessionProvider.notifier).sendUserReply(
                    app: 'FWhatsApp',
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      color: Colors.transparent,
      child: Row(
        children: [
          // Rounded Text Input Pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const Icon(Icons.attach_file_rounded, color: Colors.grey, size: 22),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('whatsapp_mic_button'),
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? Colors.redAccent : Colors.grey,
                      size: 22,
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
          const SizedBox(width: 6),

          // Green Send / Mic Circle
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF00A884), // WhatsApp Send Teal
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
