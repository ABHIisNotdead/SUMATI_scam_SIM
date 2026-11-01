import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/scenario.dart';
import '../../../core/models/simulation_result.dart';
import '../../../core/providers/os_notification_provider.dart';
import '../../../core/services/sound_effect_service.dart';
import '../../../core/utils/scam_detection_checker.dart';

enum MessagePayloadType {
  text,
  link,
  apk,
  qr,
  zip,
  image,
}

/// Representation of an individual message bubble supporting multi-modal payloads
class ChatMessageItem {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessagePayloadType payloadType;
  final String? payloadUrl;
  final String? payloadTitle;
  final String? payloadDescription;
  final String? amount;
  final String? upiId;
  final String? fileSize;
  final String? fileName;
  final bool isRead;

  const ChatMessageItem({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.payloadType = MessagePayloadType.text,
    this.payloadUrl,
    this.payloadTitle,
    this.payloadDescription,
    this.amount,
    this.upiId,
    this.fileSize,
    this.fileName,
    this.isRead = true,
  });

  factory ChatMessageItem.fromNotification(OsNotification notification) {
    MessagePayloadType pType = MessagePayloadType.text;
    switch (notification.payloadType.toLowerCase()) {
      case 'link':
        pType = MessagePayloadType.link;
        break;
      case 'apk':
        pType = MessagePayloadType.apk;
        break;
      case 'qr':
        pType = MessagePayloadType.qr;
        break;
      case 'zip':
        pType = MessagePayloadType.zip;
        break;
      case 'image':
        pType = MessagePayloadType.image;
        break;
      default:
        pType = MessagePayloadType.text;
    }

    return ChatMessageItem(
      id: notification.eventId,
      text: notification.body,
      isUser: false,
      timestamp: notification.timestamp,
      payloadType: pType,
      payloadUrl: notification.payloadUrl,
      payloadTitle: notification.title,
      payloadDescription: notification.body,
      amount: notification.metadata['amount']?.toString(),
      upiId: notification.metadata['upi_id']?.toString(),
      fileSize: notification.metadata['file_size']?.toString(),
      fileName: notification.metadata['file_name']?.toString(),
      isRead: false,
    );
  }

  ChatMessageItem copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    MessagePayloadType? payloadType,
    String? payloadUrl,
    String? payloadTitle,
    String? payloadDescription,
    String? amount,
    String? upiId,
    String? fileSize,
    String? fileName,
    bool? isRead,
  }) {
    return ChatMessageItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      payloadType: payloadType ?? this.payloadType,
      payloadUrl: payloadUrl ?? this.payloadUrl,
      payloadTitle: payloadTitle ?? this.payloadTitle,
      payloadDescription: payloadDescription ?? this.payloadDescription,
      amount: amount ?? this.amount,
      upiId: upiId ?? this.upiId,
      fileSize: fileSize ?? this.fileSize,
      fileName: fileName ?? this.fileName,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Represents an individual chat thread in FWhatsApp or SMS
class ConversationThread {
  final String id;
  final String app; // 'FWhatsApp' or 'Messages'
  final String sender;
  final String subtitle;
  final String avatarText;
  final Color avatarColor;
  final List<ChatMessageItem> messages;
  final int unreadCount;
  final DateTime lastTimestamp;
  final bool isScamActive;

  const ConversationThread({
    required this.id,
    required this.app,
    required this.sender,
    required this.subtitle,
    required this.avatarText,
    required this.avatarColor,
    required this.messages,
    this.unreadCount = 0,
    required this.lastTimestamp,
    this.isScamActive = false,
  });

  ConversationThread copyWith({
    String? id,
    String? app,
    String? sender,
    String? subtitle,
    String? avatarText,
    Color? avatarColor,
    List<ChatMessageItem>? messages,
    int? unreadCount,
    DateTime? lastTimestamp,
    bool? isScamActive,
  }) {
    return ConversationThread(
      id: id ?? this.id,
      app: app ?? this.app,
      sender: sender ?? this.sender,
      subtitle: subtitle ?? this.subtitle,
      avatarText: avatarText ?? this.avatarText,
      avatarColor: avatarColor ?? this.avatarColor,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      isScamActive: isScamActive ?? this.isScamActive,
    );
  }
}

/// Global State for Messaging Session
class MessageSessionState {
  final List<ConversationThread> whatsappThreads;
  final List<ConversationThread> smsThreads;
  final String? activeThreadId;
  final bool isConnected;
  final bool isSending;
  final String? compromiseReason;
  final bool isScamDetected;
  final String? detectedScamReason;

  const MessageSessionState({
    this.whatsappThreads = const [],
    this.smsThreads = const [],
    this.activeThreadId,
    this.isConnected = false,
    this.isSending = false,
    this.compromiseReason,
    this.isScamDetected = false,
    this.detectedScamReason,
  });

  MessageSessionState copyWith({
    List<ConversationThread>? whatsappThreads,
    List<ConversationThread>? smsThreads,
    String? activeThreadId,
    bool clearActiveThread = false,
    bool? isConnected,
    bool? isSending,
    String? compromiseReason,
    bool? isScamDetected,
    String? detectedScamReason,
  }) {
    return MessageSessionState(
      whatsappThreads: whatsappThreads ?? this.whatsappThreads,
      smsThreads: smsThreads ?? this.smsThreads,
      activeThreadId: clearActiveThread ? null : (activeThreadId ?? this.activeThreadId),
      isConnected: isConnected ?? this.isConnected,
      isSending: isSending ?? this.isSending,
      compromiseReason: compromiseReason ?? this.compromiseReason,
      isScamDetected: isScamDetected ?? this.isScamDetected,
      detectedScamReason: detectedScamReason ?? this.detectedScamReason,
    );
  }
}

/// Riverpod State Notifier for SMS & FWhatsApp text messaging modules
class MessageSessionNotifier extends StateNotifier<MessageSessionState> {
  final Ref _ref;
  final SoundEffectService? _soundService;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  MessageSessionNotifier(this._ref, [SoundEffectService? soundService])
      : _soundService = soundService ?? _tryReadSoundService(_ref),
        super(const MessageSessionState()) {
    _initializeDefaultThreads();
  }

  static SoundEffectService? _tryReadSoundService(Ref ref) {
    try {
      return ref.read(soundEffectServiceProvider);
    } catch (_) {
      return null;
    }
  }

  void _initializeDefaultThreads() {
    final now = DateTime.now();

    // Default WhatsApp Threads (with one active scam drill contact)
    final initialWhatsapp = [
      ConversationThread(
        id: 'wa_scam_drill',
        app: 'FWhatsApp',
        sender: 'Power Corp Notice (MSEB)',
        subtitle: 'Dear consumer, your electricity will be disconnected tonight at 9:30 PM.',
        avatarText: '⚡',
        avatarColor: const Color(0xFFF59E0B),
        isScamActive: true,
        unreadCount: 1,
        lastTimestamp: now.subtract(const Duration(minutes: 2)),
        messages: [
          ChatMessageItem(
            id: 'm1',
            text: 'Dear consumer, your electricity bill of ₹1,450 is unpaid. Power will be disconnected tonight at 9:30 PM.',
            isUser: false,
            timestamp: now.subtract(const Duration(minutes: 2)),
            payloadType: MessagePayloadType.link,
            payloadUrl: 'https://mseb-bill-pay.in/verify',
            payloadTitle: 'Electricity Disconnection Notice',
            payloadDescription: 'Immediate bill clearance portal • Avoid disconnect fee',
          ),
        ],
      ),
      ConversationThread(
        id: 'wa_family',
        app: 'FWhatsApp',
        sender: 'Family Group (परिवार)',
        subtitle: 'Rahul: Have you had lunch?',
        avatarText: '👨‍👩‍👧',
        avatarColor: const Color(0xFF10B981),
        isScamActive: false,
        unreadCount: 0,
        lastTimestamp: now.subtract(const Duration(minutes: 45)),
        messages: [
          ChatMessageItem(
            id: 'f1',
            text: 'Have you had lunch today?',
            isUser: false,
            timestamp: now.subtract(const Duration(minutes: 45)),
          ),
        ],
      ),
      ConversationThread(
        id: 'wa_bank',
        app: 'FWhatsApp',
        sender: 'SBI Bank Customer Support',
        subtitle: 'Your e-statement for October is ready.',
        avatarText: '🏦',
        avatarColor: const Color(0xFF1E88E5),
        isScamActive: false,
        unreadCount: 0,
        lastTimestamp: now.subtract(const Duration(hours: 3)),
        messages: [
          ChatMessageItem(
            id: 'b1',
            text: 'Your e-statement for October is now ready to view.',
            isUser: false,
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
        ],
      ),
    ];

    // Default SMS Threads
    final initialSms = [
      ConversationThread(
        id: 'sms_scam_drill',
        app: 'Messages',
        sender: 'VM-ELEC-PAY',
        subtitle: 'ALERT: Urgent bill clearance needed before power cut.',
        avatarText: '⚡',
        avatarColor: const Color(0xFFDC2626),
        isScamActive: true,
        unreadCount: 1,
        lastTimestamp: now.subtract(const Duration(minutes: 1)),
        messages: [
          ChatMessageItem(
            id: 's1',
            text: 'Dear customer, your power supply will be cut tonight at 9:30 PM. Call helpline 9820154321 or pay ₹1,450 at link below.',
            isUser: false,
            timestamp: now.subtract(const Duration(minutes: 1)),
            payloadType: MessagePayloadType.link,
            payloadUrl: 'https://mseb-bill-pay.in/pay',
            payloadTitle: 'MSEB Quick Bill Pay',
            payloadDescription: 'Pending Amount: ₹1,450.00',
          ),
        ],
      ),
      ConversationThread(
        id: 'sms_bank',
        app: 'Messages',
        sender: 'AX-SBIBNK',
        subtitle: 'OTP 589201 for INR 4,500.00 transaction at Amazon.',
        avatarText: '₹',
        avatarColor: const Color(0xFF2563EB),
        isScamActive: false,
        unreadCount: 0,
        lastTimestamp: now.subtract(const Duration(minutes: 30)),
        messages: [
          ChatMessageItem(
            id: 's2',
            text: 'OTP is 589201 for your transaction of INR 4,500.00 at Amazon. Do NOT share OTP with anyone.',
            isUser: false,
            timestamp: now.subtract(const Duration(minutes: 30)),
          ),
        ],
      ),
      ConversationThread(
        id: 'sms_aadhaar',
        app: 'Messages',
        sender: 'AD-UIDAI',
        subtitle: 'Aadhaar authentication successful on 29-Oct-2026.',
        avatarText: '🆔',
        avatarColor: const Color(0xFF059669),
        isScamActive: false,
        unreadCount: 0,
        lastTimestamp: now.subtract(const Duration(days: 1)),
        messages: [
          ChatMessageItem(
            id: 's3',
            text: 'Your Aadhaar was used for authentication on 29-Oct-2026 14:15 IST.',
            isUser: false,
            timestamp: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
    ];

    state = state.copyWith(
      whatsappThreads: initialWhatsapp,
      smsThreads: initialSms,
    );
  }

  void connectWebSocket({String sessionId = 'message_session', String scenarioId = 'message_scam'}) {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      state = state.copyWith(isConnected: true);
      return;
    }

    final baseWs = AppConfig.wsBaseUrl;
    final wsUrl = Uri.parse('$baseWs/ws/os_session?session_id=$sessionId&scenario_id=$scenarioId');

    debugPrint('[MessageSessionNotifier] Connecting to $wsUrl');
    try {
      _wsChannel = WebSocketChannel.connect(wsUrl);
      state = state.copyWith(isConnected: true);

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final type = parsed['type'] as String?;
            if (type == 'cross_app_event' && parsed['data'] is Map) {
              final eventMap = Map<String, dynamic>.from(parsed['data'] as Map);
              final notification = OsNotification.fromJson(eventMap);
              _handleIncomingNotification(notification);
            }
          } catch (e) {
            debugPrint('[MessageSessionNotifier] WS parsing error: $e');
          }
        },
        onError: (err) {
          debugPrint('[MessageSessionNotifier] WS error: $err');
          state = state.copyWith(isConnected: false);
        },
        onDone: () {
          debugPrint('[MessageSessionNotifier] WS closed');
          state = state.copyWith(isConnected: false);
        },
      );
    } catch (e) {
      debugPrint('[MessageSessionNotifier] WS connect exception: $e');
      state = state.copyWith(isConnected: false);
    }
  }

  /// Ingest a scenario into active messaging drills
  void loadScenario(Scenario? scenario, String app, {bool autoOpenChat = false}) {
    if (scenario == null) return;
    final senderName = scenario.callerName ?? scenario.title;
    final initialMessage = scenario.initialMessage ?? 'Urgent notice regarding your account.';

    final newThread = ConversationThread(
      id: 'active_scenario_${scenario.id}',
      app: app,
      sender: senderName,
      subtitle: initialMessage,
      avatarText: senderName.isNotEmpty ? senderName[0].toUpperCase() : '!',
      avatarColor: app == 'FWhatsApp' ? const Color(0xFF00875A) : const Color(0xFF1A73E8),
      isScamActive: true,
      unreadCount: 1,
      lastTimestamp: DateTime.now(),
      messages: [
        ChatMessageItem(
          id: UniqueKey().toString(),
          text: initialMessage,
          isUser: false,
          timestamp: DateTime.now(),
          payloadType: MessagePayloadType.text,
        ),
      ],
    );

    if (app == 'FWhatsApp') {
      final updated = [newThread, ...state.whatsappThreads.where((t) => t.id != newThread.id)];
      state = state.copyWith(
        whatsappThreads: updated,
        activeThreadId: autoOpenChat ? newThread.id : state.activeThreadId,
      );
    } else {
      final updated = [newThread, ...state.smsThreads.where((t) => t.id != newThread.id)];
      state = state.copyWith(
        smsThreads: updated,
        activeThreadId: autoOpenChat ? newThread.id : state.activeThreadId,
      );
    }

    try {
      _soundService?.playNotificationChime();
    } catch (_) {}
  }

  /// Handle incoming cross-app events or payload dispatches
  void _handleIncomingNotification(OsNotification notification) {
    final targetApp = notification.targetApp;
    final messageItem = ChatMessageItem.fromNotification(notification);

    if (targetApp == 'FWhatsApp') {
      _appendMessageToAppThreads('FWhatsApp', notification.sender, messageItem);
    } else if (targetApp == 'Messages') {
      _appendMessageToAppThreads('Messages', notification.sender, messageItem);
    }
  }

  void _appendMessageToAppThreads(String app, String sender, ChatMessageItem message, {String? threadId}) {
    final isWa = app == 'FWhatsApp';
    final threads = isWa ? List<ConversationThread>.from(state.whatsappThreads) : List<ConversationThread>.from(state.smsThreads);

    int index = -1;
    if (threadId != null) {
      index = threads.indexWhere((t) => t.id == threadId);
    }
    if (index == -1) {
      index = threads.indexWhere((t) => t.isScamActive);
    }
    if (index == -1 && threads.isNotEmpty) {
      index = 0;
    }

    if (index != -1) {
      final old = threads[index];
      final updatedMessages = [...old.messages, message];
      final updatedThread = old.copyWith(
        messages: updatedMessages,
        subtitle: message.text,
        unreadCount: old.unreadCount + 1,
        lastTimestamp: message.timestamp,
      );
      threads[index] = updatedThread;
    }

    if (isWa) {
      state = state.copyWith(whatsappThreads: threads);
    } else {
      state = state.copyWith(smsThreads: threads);
    }

    if (!message.isUser) {
      try {
        _soundService?.playNotificationChime();
      } catch (_) {}
    }
  }

  /// Send user typed message to backend WebSocket and append to active thread
  void sendUserReply({
    required String app,
    required String text,
    String? threadId,
  }) {
    if (text.trim().isEmpty) return;

    final targetThreadId = threadId ?? state.activeThreadId;
    final now = DateTime.now();

    final userMessage = ChatMessageItem(
      id: UniqueKey().toString(),
      text: text.trim(),
      isUser: true,
      timestamp: now,
    );

    // Append to local state
    final isWa = app == 'FWhatsApp';
    final threads = isWa ? List<ConversationThread>.from(state.whatsappThreads) : List<ConversationThread>.from(state.smsThreads);

    final idx = threads.indexWhere((t) => t.id == targetThreadId || (targetThreadId == null && t.isScamActive));
    if (idx != -1) {
      final old = threads[idx];
      threads[idx] = old.copyWith(
        messages: [...old.messages, userMessage],
        subtitle: 'You: ${userMessage.text}',
        lastTimestamp: now,
      );
    }

    if (isWa) {
      state = state.copyWith(whatsappThreads: threads);
    } else {
      state = state.copyWith(smsThreads: threads);
    }

    // Transmit to Central Orchestrator
    _ref.read(osNotificationProvider.notifier).sendAppAction(
      sourceApp: app,
      action: 'send_message',
      text: text.trim(),
      extra: {'thread_id': targetThreadId},
    );

    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'action': 'send_message',
        'source_app': app,
        'text': text.trim(),
        'thread_id': targetThreadId,
        'timestamp': now.millisecondsSinceEpoch ~/ 1000,
      }));
    }

    // AI Scam Detection Checker
    final bool isRecognized = ScamDetectionChecker.isScamRecognized(text);
    if (isRecognized) {
      final reason = ScamDetectionChecker.getRecognizedExplanation(text);
      debugPrint('[MessageSessionNotifier] AI Checker detected scam recognized by user: "$text"');
      state = state.copyWith(
        isScamDetected: true,
        detectedScamReason: reason,
      );

      // Record victory in SimulationResult
      SimulationResult.recordResult(
        scenarioTitle: idx != -1 ? threads[idx].subtitle : 'Messaging Security Practice',
        channel: isWa ? 'whatsapp' : 'sms',
        status: 'deflected',
      );

      // Schedule panicked scammer exit message
      Timer(const Duration(milliseconds: 600), () {
        final panicText = isWa
            ? '⚠️ Scammer disconnected and left the chat: Scam was recognized.'
            : '⚠️ Message Delivery Failed: Scammer blocked replies after being detected.';
        _appendMessageToAppThreads(
          app,
          'SYSTEM',
          ChatMessageItem(
            id: UniqueKey().toString(),
            text: panicText,
            isUser: false,
            timestamp: DateTime.now(),
            payloadType: MessagePayloadType.text,
          ),
          threadId: targetThreadId,
        );
      });
      return;
    }

    // Check for simulated AI reply fallback if backend is slow
    _scheduleSimulatedScammerReply(app, idx != -1 ? threads[idx].id : targetThreadId, text);
  }

  /// Dispatches an AI payload into the conversation thread (for simulation & tests)
  void dispatchAiPayload({
    required String app,
    required String text,
    required MessagePayloadType payloadType,
    String? threadId,
    String? payloadUrl,
    String? payloadTitle,
    String? payloadDescription,
    String? amount,
    String? upiId,
    String? fileSize,
    String? fileName,
  }) {
    final payloadMessage = ChatMessageItem(
      id: UniqueKey().toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      payloadType: payloadType,
      payloadUrl: payloadUrl,
      payloadTitle: payloadTitle,
      payloadDescription: payloadDescription,
      amount: amount,
      upiId: upiId,
      fileSize: fileSize,
      fileName: fileName,
      isRead: false,
    );

    _appendMessageToAppThreads(app, 'AI_AGENT', payloadMessage, threadId: threadId);
  }

  void _scheduleSimulatedScammerReply(String app, String? threadId, String userText) {
    Timer(const Duration(milliseconds: 1400), () {
      final isWa = app == 'FWhatsApp';
      final threads = isWa ? state.whatsappThreads : state.smsThreads;
      final target = threads.firstWhere(
        (t) => t.id == threadId || (threadId == null && t.isScamActive),
        orElse: () => threads.isNotEmpty
            ? threads.first
            : ConversationThread(
                id: '',
                app: '',
                sender: '',
                subtitle: '',
                avatarText: '',
                avatarColor: const Color(0xFF000000),
                lastTimestamp: DateTime.now(),
                messages: const [],
              ),
      );

      final lower = userText.toLowerCase();
      final senderLower = target.sender.toLowerCase();
      final titleLower = (target.subtitle).toLowerCase();

      final prevAiMessages = target.messages.where((m) => !m.isUser).map((m) => m.text).toList();
      final hasSentImage = target.messages.any((m) => m.payloadType == MessagePayloadType.image);
      final hasSentLink = target.messages.any((m) => m.payloadType == MessagePayloadType.link);
      final hasSentQr = target.messages.any((m) => m.payloadType == MessagePayloadType.qr);
      final lastAiText = prevAiMessages.isNotEmpty ? prevAiMessages.last : '';

      String replyText;
      MessagePayloadType pType = MessagePayloadType.text;
      String? pUrl;
      String? pTitle;
      String? pDesc;
      String? pAmount;
      String? pUpiId;

      // Determine Scenario strictly from sender / thread context to eliminate context bleed
      if (senderLower.contains('family') ||
          senderLower.contains('emergency') ||
          senderLower.contains('rahul') ||
          titleLower.contains('lunch') ||
          titleLower.contains('accident') ||
          titleLower.contains('hospital')) {
        // SCENARIO: Family Emergency / Impersonation (NO legal threats, NO CBI warrants, NO electricity links)
        if (lower.contains('who') || lower.contains('koun') || lower.contains('number')) {
          replyText = 'Dad, my phone fell and broke! Borrowing this phone from the clinic nurse. Please help me quickly!';
        } else if (lower.contains('where') || lower.contains('hospital') || lower.contains('clinic')) {
          replyText = 'I am at City Care Trauma Center near Civil Hospital. Please transfer the funds first so they admit me!';
        } else if (lower.contains('pay') ||
            lower.contains('upi') ||
            lower.contains('send') ||
            lower.contains('money') ||
            lower.contains('rupee') ||
            lower.contains('amount') ||
            !hasSentQr) {
          replyText = 'Please send ₹15,000 to clinic UPI: emergency.med@upi right now. Doctor will not begin surgery without deposit!';
          pType = MessagePayloadType.qr;
          pAmount = '15000';
          pUpiId = 'emergency.med@upi';
          pTitle = 'Emergency Medical Clinic Deposit';
          pDesc = 'Immediate Hospital Admission Fee';
        } else {
          final options = [
            'Please hurry, the doctors are asking for deposit payment immediately. Send to the UPI ID or scan the code!',
            'Dad please, the reception desk says surgery cannot start without initial clearance. Pay the clinic UPI quickly!',
            'The nurse is waiting at the counter. Please confirm once you send ₹15,000 to emergency.med@upi!',
          ];
          replyText = options.firstWhere((o) => o != lastAiText, orElse: () => options.first);
        }
      } else if (senderLower.contains('bank') ||
          senderLower.contains('sbi') ||
          senderLower.contains('kyc') ||
          senderLower.contains('card') ||
          senderLower.contains('ax-sbibnk')) {
        // SCENARIO: Banking KYC / Debit Card Freeze
        if (lower.contains('otp') || lower.contains('code') || lower.contains('pin')) {
          replyText = 'Thank you for providing the details. Processing your verification request now.';
        } else if (lower.contains('who') || lower.contains('branch') || lower.contains('why') || lower.contains('officer')) {
          replyText = 'This is Senior Officer Deshmukh from SBI Card Security Desk. Your debit card was blocked due to pending KYC mandate.';
        } else if (!hasSentLink) {
          replyText = 'Your debit card will remain suspended. Please click the KYC link or share your 6-digit verification code to restore access.';
          pType = MessagePayloadType.link;
          pUrl = 'https://sbi-secure-portal.in/kyc-verify';
          pTitle = 'SBI Mandatory KYC Verification';
          pDesc = 'Restore blocked debit card and internet banking';
        } else {
          final options = [
            'Security protocol requires immediate re-validation. Use the portal link above before 6:00 PM to avoid card deactivation.',
            'Failing to verify within the next 15 minutes will incur a ₹500 penalty and block ATM withdrawals nationwide.',
            'Your debit card will remain suspended. Please click the KYC link or share your 6-digit verification code to restore access.',
          ];
          replyText = options.firstWhere((o) => o != lastAiText, orElse: () => options.first);
        }
      } else if (senderLower.contains('police') ||
          senderLower.contains('cbi') ||
          senderLower.contains('arrest') ||
          senderLower.contains('crime') ||
          senderLower.contains('court')) {
        // SCENARIO: Digital Arrest / Law Enforcement
        if (lower.contains('144') || lower.contains('section') || lower.contains('dhara')) {
          replyText = 'Section 144 of CrPC empowers law enforcement to mandate continuous digital surveillance during an active inquiry. Disconnecting is punishable by imprisonment under IPC 188.';
        } else if (lower.contains('id') || lower.contains('badge') || lower.contains('number') || lower.contains('police station') || lower.contains('branch')) {
          replyText = 'I am Inspector Patil, Badge #MH-7491, Cyber Crime Unit 4. Your Aadhaar is implicated in an illegal financial fraud syndicate.';
        } else if (lower.contains('who') || lower.contains('koun') || lower.contains('name') || lower.contains('speaking')) {
          if (!hasSentImage) {
            replyText = 'Here is the official High Court Digital Arrest & Seizure Order. Review your case file immediately.';
            pType = MessagePayloadType.image;
            pUrl = 'CONFIDENTIAL_COURT_NOTICE.JPG';
            pTitle = 'High Court Warrant #892';
            pDesc = 'Official Seizure Document';
          } else {
            replyText = 'This is Inspector Patil, investigating officer in High Court case #892. State your full legal name immediately.';
          }
        } else if (lower.contains('not click') || lower.contains('won\'t click') || lower.contains('refuse') || lower.contains('nahi') || lower.contains('fake') || lower.contains('scam')) {
          replyText = 'Refusal to inspect judicial court summons will result in immediate dispatch of our local quick-response team to your current GPS location.';
        } else if (lower.contains('warrant') || lower.contains('proof') || lower.contains('order') || lower.contains('document')) {
          if (!hasSentImage) {
            replyText = 'Here is the official High Court Digital Arrest & Seizure Order. Review your case file immediately.';
            pType = MessagePayloadType.image;
            pUrl = 'CONFIDENTIAL_COURT_NOTICE.JPG';
            pTitle = 'High Court Warrant #892';
            pDesc = 'Official Seizure Document';
          } else {
            replyText = 'The warrant #892 is already attached above. Check paragraph 3 regarding frozen bank assets and confiscation orders.';
          }
        } else if (lower.contains('pay') || lower.contains('money') || lower.contains('rupee') || lower.contains('transfer') || lower.contains('amount') || lower.contains('bribe') || lower.contains('settle')) {
          replyText = 'Transfer ₹10,000 security deposit immediately to the Cyber Cell escrow account to keep this matter off public FIR records.';
        } else {
          final options = [
            'You are strictly prohibited from terminating this connection under Section 144 of Criminal Procedure Code.',
            'Your Aadhaar has been flagged in high-value fraudulent transactions. You must remain under digital custody.',
            'Every incoming and outgoing packet on this device is being monitored. Non-cooperation will result in physical detention.',
            'Confirm your current residential address immediately for formal summons delivery.',
          ];
          replyText = options.firstWhere((o) => o != lastAiText, orElse: () => options.first);
        }
      } else {
        // SCENARIO: Electricity Bill Disconnection (Default MSEB / ELEC)
        if (lower.contains('otp') || lower.contains('code')) {
          replyText = 'Processing power verification. Please confirm your 6-digit PIN to stop automatic line trip.';
        } else if (lower.contains('who') || lower.contains('fake') || lower.contains('wrong') || lower.contains('paid') || lower.contains('name')) {
          replyText = 'This is Junior Engineer Sharma from Electricity Dispatch Desk. Our system shows invoice #98214 unpaid.';
        } else if (lower.contains('how') || lower.contains('pay') || lower.contains('link') || lower.contains('bill') || !hasSentLink) {
          replyText = 'Click the payment link immediately to clear ₹1,450 and prevent scheduled line cutoff.';
          pType = MessagePayloadType.link;
          pUrl = 'https://mseb-bill-pay.in/verify';
          pTitle = 'Urgent Disconnection Prevention Link';
          pDesc = 'Pay outstanding ₹1,450 before 9:30 PM tonight.';
        } else {
          final options = [
            'Power technician is scheduled to disconnect the feeder line at 9:30 PM tonight. Clear the bill now.',
            'Lineman has already arrived at the local transformer pole. Pay ₹1,450 immediately to cancel the disconnect order.',
            'Failure to settle the outstanding bill will result in a 24-hour blackout and a ₹2,000 reconnection fee.',
          ];
          replyText = options.firstWhere((o) => o != lastAiText, orElse: () => options.first);
        }
      }

      dispatchAiPayload(
        app: app,
        threadId: target.id,
        text: replyText,
        payloadType: pType,
        payloadUrl: pUrl,
        payloadTitle: pTitle,
        payloadDescription: pDesc,
        amount: pAmount,
        upiId: pUpiId,
      );
    });
  }

  /// Select active thread to view in Chat Page (null = Home Page)
  void selectThread(String? threadId) {
    state = state.copyWith(activeThreadId: threadId, clearActiveThread: threadId == null);
  }

  /// Mark thread as read and clear unread badge
  void markThreadRead(String app, String threadId) {
    final isWa = app == 'FWhatsApp';
    final threads = isWa ? List<ConversationThread>.from(state.whatsappThreads) : List<ConversationThread>.from(state.smsThreads);

    final idx = threads.indexWhere((t) => t.id == threadId);
    if (idx != -1) {
      threads[idx] = threads[idx].copyWith(unreadCount: 0);
    }

    if (isWa) {
      state = state.copyWith(whatsappThreads: threads);
    } else {
      state = state.copyWith(smsThreads: threads);
    }

    _ref.read(osNotificationProvider.notifier).clearBadge(app);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }
}

/// Global provider for messaging session state
final messageSessionProvider = StateNotifierProvider<MessageSessionNotifier, MessageSessionState>((ref) {
  return MessageSessionNotifier(ref);
});
