import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../services/sound_effect_service.dart';

/// Represents a cross-app event or notification payload delivered to the simulated OS.
class OsNotification {
  final String eventId;
  final String event;
  final String targetApp;
  final String sender;
  final String title;
  final String body;
  final String payloadType; // 'text', 'link', 'apk', 'qr', 'zip', 'image'
  final String? payloadUrl;
  final int badgeIncrement;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final bool isRead;

  const OsNotification({
    required this.eventId,
    required this.event,
    required this.targetApp,
    required this.sender,
    required this.title,
    required this.body,
    this.payloadType = 'text',
    this.payloadUrl,
    this.badgeIncrement = 1,
    required this.timestamp,
    this.metadata = const {},
    this.isRead = false,
  });

  factory OsNotification.fromJson(Map<String, dynamic> json) {
    return OsNotification(
      eventId: json['event_id']?.toString() ?? UniqueKey().toString(),
      event: json['event']?.toString() ?? 'trigger_notification',
      targetApp: json['target_app']?.toString() ?? 'Messages',
      sender: json['sender']?.toString() ?? 'Notification',
      title: json['title']?.toString() ?? 'Alert',
      body: json['body']?.toString() ?? '',
      payloadType: json['payload_type']?.toString() ?? 'text',
      payloadUrl: json['payload_url']?.toString(),
      badgeIncrement: (json['badge_increment'] as num?)?.toInt() ?? 1,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              ((json['timestamp'] as num) * 1000).toInt(),
            )
          : DateTime.now(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'event': event,
        'target_app': targetApp,
        'sender': sender,
        'title': title,
        'body': body,
        'payload_type': payloadType,
        'payload_url': payloadUrl,
        'badge_increment': badgeIncrement,
        'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
        'metadata': metadata,
        'is_read': isRead,
      };

  OsNotification copyWith({bool? isRead}) {
    return OsNotification(
      eventId: eventId,
      event: event,
      targetApp: targetApp,
      sender: sender,
      title: title,
      body: body,
      payloadType: payloadType,
      payloadUrl: payloadUrl,
      badgeIncrement: badgeIncrement,
      timestamp: timestamp,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Global State for the Simulated Mobile OS notification and badge system.
class OsNotificationState {
  final Map<String, int> appBadges;
  final OsNotification? activeBanner;
  final List<OsNotification> notificationHistory;
  final String activeApp;
  final bool isConnected;
  final String? compromiseReason;
  final String? activeSessionId;

  const OsNotificationState({
    this.appBadges = const {
      'Phone': 0,
      'Messages': 0,
      'FWhatsApp': 0,
      'Browser': 0,
    },
    this.activeBanner,
    this.notificationHistory = const [],
    this.activeApp = 'Home',
    this.isConnected = false,
    this.compromiseReason,
    this.activeSessionId,
  });

  OsNotificationState copyWith({
    Map<String, int>? appBadges,
    OsNotification? activeBanner,
    bool clearBanner = false,
    List<OsNotification>? notificationHistory,
    String? activeApp,
    bool? isConnected,
    String? compromiseReason,
    bool clearCompromise = false,
    String? activeSessionId,
  }) {
    return OsNotificationState(
      appBadges: appBadges ?? this.appBadges,
      activeBanner: clearBanner ? null : (activeBanner ?? this.activeBanner),
      notificationHistory: notificationHistory ?? this.notificationHistory,
      activeApp: activeApp ?? this.activeApp,
      isConnected: isConnected ?? this.isConnected,
      compromiseReason: clearCompromise ? null : (compromiseReason ?? this.compromiseReason),
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }
}

/// Riverpod Notifier managing cross-app event stream, badge counters, and banners.
class OsNotificationNotifier extends Notifier<OsNotificationState> {
  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  Timer? _bannerDismissTimer;

  @override
  OsNotificationState build() {
    ref.onDispose(() {
      _bannerDismissTimer?.cancel();
      _socketSub?.cancel();
      _channel?.sink.close();
    });
    return const OsNotificationState();
  }

  /// Connect to the backend Orchestrator WebSocket session
  void connectToSession(String sessionId, {String scenarioId = 'call_digital_arrest'}) {
    _socketSub?.cancel();
    _channel?.sink.close();

    final baseWs = AppConfig.wsBaseUrl;
    final wsUrl = Uri.parse('$baseWs/ws/os_session?session_id=$sessionId&scenario_id=$scenarioId');

    debugPrint('[OsNotificationProvider] Connecting to Orchestrator: $wsUrl');
    try {
      _channel = WebSocketChannel.connect(wsUrl);
      state = state.copyWith(isConnected: true, activeSessionId: sessionId);

      _socketSub = _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final type = parsed['type'] as String?;
            if (type == 'cross_app_event' && parsed['data'] is Map) {
              final eventMap = Map<String, dynamic>.from(parsed['data'] as Map);
              handleCrossAppEvent(eventMap);
            }
          } catch (e) {
            debugPrint('[OsNotificationProvider] Error parsing event: $e');
          }
        },
        onError: (err) {
          debugPrint('[OsNotificationProvider] WebSocket error: $err');
          state = state.copyWith(isConnected: false);
        },
        onDone: () {
          debugPrint('[OsNotificationProvider] WebSocket closed');
          state = state.copyWith(isConnected: false);
        },
      );
    } catch (e) {
      debugPrint('[OsNotificationProvider] Connection exception: $e');
      state = state.copyWith(isConnected: false);
    }
  }

  /// Process an incoming CrossAppEvent emitted by a backend AI agent
  void handleCrossAppEvent(Map<String, dynamic> rawEvent) {
    final notification = OsNotification.fromJson(rawEvent);

    // Check for trap compromise events
    if (notification.event == 'compromise_alert') {
      state = state.copyWith(
        compromiseReason: notification.body,
        activeBanner: notification,
      );
      return;
    }

    // Increment badge on targeted app
    final currentBadges = Map<String, int>.from(state.appBadges);
    final target = notification.targetApp;
    final currentCount = currentBadges[target] ?? 0;
    currentBadges[target] = currentCount + notification.badgeIncrement;

    // Show heads-up banner
    _bannerDismissTimer?.cancel();
    _bannerDismissTimer = Timer(const Duration(seconds: 5), () {
      dismissBanner();
    });

    try {
      ref.read(soundEffectServiceProvider).playNotificationChime();
    } catch (_) {}

    state = state.copyWith(
      appBadges: currentBadges,
      activeBanner: notification,
      notificationHistory: [notification, ...state.notificationHistory],
    );
  }

  /// Dismiss the active top-screen notification banner
  void dismissBanner() {
    _bannerDismissTimer?.cancel();
    if (state.activeBanner != null) {
      state = state.copyWith(clearBanner: true);
    }
  }

  /// Reset all OS badges, active banners, and compromise states upon drill conclusion
  void resetAll() {
    _bannerDismissTimer?.cancel();
    state = state.copyWith(
      appBadges: const {
        'Phone': 0,
        'Messages': 0,
        'FWhatsApp': 0,
        'Browser': 0,
      },
      clearBanner: true,
      clearCompromise: true,
    );
  }

  /// Reset/clear the unread badge count for a specific app (e.g. when opening FWhatsApp)
  void clearBadge(String appName) {
    final updated = Map<String, int>.from(state.appBadges);
    if ((updated[appName] ?? 0) > 0) {
      updated[appName] = 0;
      state = state.copyWith(appBadges: updated);
    }
  }

  /// Set the active app currently open in foreground
  void setActiveApp(String appName) {
    state = state.copyWith(activeApp: appName);
    clearBadge(appName);
  }

  /// Send user interaction/action from an app back to the central Orchestrator
  void sendAppAction({
    required String sourceApp,
    required String action,
    String text = '',
    Map<String, dynamic>? extra,
  }) {
    if (_channel != null) {
      final payload = {
        'action': action,
        'source_app': sourceApp,
        'text': text,
        'extra': extra ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  /// Local test simulation trigger for automated widget tests and offline testing
  void triggerLocalNotification({
    required String targetApp,
    required String sender,
    required String title,
    required String body,
    String payloadType = 'text',
    String? payloadUrl,
    Map<String, dynamic> metadata = const {},
  }) {
    handleCrossAppEvent({
      'event': 'trigger_notification',
      'target_app': targetApp,
      'sender': sender,
      'title': title,
      'body': body,
      'payload_type': payloadType,
      'payload_url': payloadUrl,
      'badge_increment': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'metadata': metadata,
    });
  }
}

/// Global provider for OS Notifications and Badges
final osNotificationProvider =
    NotifierProvider<OsNotificationNotifier, OsNotificationState>(() {
  return OsNotificationNotifier();
});

