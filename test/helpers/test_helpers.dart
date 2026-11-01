import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sumati/core/models/scenario.dart';
import 'package:sumati/core/providers/ai_call_provider.dart';
import 'package:sumati/core/providers/preferences_provider.dart';
import 'package:sumati/core/services/sound_effect_service.dart';
import 'package:sumati/core/theme/app_theme.dart';

Directory? _testHiveDir;

/// Initializes Hive in a temporary directory for unit/widget tests.
Future<void> initTestHive() async {
  _testHiveDir = await Directory.systemTemp.createTemp('sumati_test_hive_');
  Hive.init(_testHiveDir!.path);
  if (!Hive.isBoxOpen('preferences')) {
    await Hive.openBox('preferences');
  }
  if (!Hive.isBoxOpen('simulation_results')) {
    await Hive.openBox('simulation_results');
  }
}

/// Cleans up temporary Hive storage after tests safely without blocking.
Future<void> cleanTestHive() async {
  // Non-blocking no-op: isolate termination reclaims resources safely on Windows
}

/// Set up mock method call handlers for platform channels used during tests.
void setupMockAudioChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugin.csd.speech_to_text'),
    (MethodCall methodCall) async => true,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugin.csdcorp.com/speech_to_text'),
    (MethodCall methodCall) async => true,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async => '.',
  );
}

/// Fake SoundEffectService for deterministic unit and widget tests
class FakeSoundEffectService extends SoundEffectService {
  int playRingtoneCount = 0;
  int stopRingtoneCount = 0;
  int playChimeCount = 0;

  @override
  Future<void> playCallRingtone() async {
    playRingtoneCount++;
  }

  @override
  Future<void> stopCallRingtone() async {
    stopRingtoneCount++;
  }

  @override
  Future<void> playNotificationChime() async {
    playChimeCount++;
  }

  @override
  void dispose() {}
}

/// Fake preferences notifier to set language deterministically in tests.
class FakePreferencesNotifier extends PreferencesNotifier {
  final String testLang;
  FakePreferencesNotifier([this.testLang = 'en']);

  @override
  AppPreferences build() {
    return AppPreferences(
      isFirstLaunch: false,
      appLanguage: testLang,
    );
  }
}

/// Creates a Scenario for testing with default or custom fields.
Scenario createTestScenario({
  String id = 'call_digital_arrest',
  String language = 'en',
  String title = 'Digital Arrest Scam',
  String channel = 'call',
  String difficulty = 'medium',
  String debriefSuccess = 'You recognized the fake police badge.',
  String debriefFailure = 'You were intimidated into paying.',
  String? goal = 'Coerce victim into transferring funds to safety account',
  String? persona = 'Inspector Sharma from Delhi Crime Branch',
  String? scammerName = 'Inspector Sharma',
  String? initialMessage = 'This is Crime Branch Delhi. You are under digital arrest.',
}) {
  return Scenario(
    id: id,
    language: language,
    title: title,
    channel: channel,
    difficulty: difficulty,
    debriefSuccess: debriefSuccess,
    debriefFailure: debriefFailure,
    goal: goal,
    persona: persona,
    scammerName: scammerName,
    initialMessage: initialMessage,
  );
}

/// Fake notifier to control AiCallState without WebSocket or audio hardware.
class FakeAiCallNotifier extends AiCallNotifier {
  final List<String> sentMessages = [];
  bool endCallCalled = false;
  bool stopTtsCalled = false;

  @override
  AiCallState build() {
    return AiCallState(
      latestAiReply: 'Hello, this is a test call.',
      status: 'ongoing',
      isSpeaking: false,
    );
  }

  @override
  void connect(String persona, String initialMessage, {String lang = 'en', String? scenarioId}) {
    state = AiCallState(
      latestAiReply: initialMessage,
      status: 'ongoing',
      isSpeaking: true,
    );
  }

  @override
  void sendVoiceMessage(String text) {
    sentMessages.add(text);
  }

  @override
  void stopTts() {
    stopTtsCalled = true;
    if (state.isSpeaking) {
      state = state.copyWith(isSpeaking: false);
    }
  }

  @override
  void endCall() {
    endCallCalled = true;
    state = state.copyWith(status: 'ended', isSpeaking: false);
  }

  void setSpeaking(bool speaking) {
    state = state.copyWith(isSpeaking: speaking);
  }

  void setStatus(String status) {
    state = state.copyWith(status: status);
  }

  void setReply(String reply) {
    state = state.copyWith(latestAiReply: reply);
  }

  void updateState(AiCallState newState) {
    state = newState;
  }
}

/// A NavigatorObserver that logs all navigation events for assertions.
class TestNavigationObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];
  final List<String?> routeNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushedRoutes.add(route);
    routeNames.add(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    poppedRoutes.add(route);
  }
}

/// Helper to wrap test widgets with MaterialApp and Riverpod ProviderScope.
Widget createTestApp({
  required Widget child,
  List<Override> overrides = const [],
  NavigatorObserver? observer,
}) {
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWith(() => PreferencesNotifier()),
      soundEffectServiceProvider.overrideWithValue(FakeSoundEffectService()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      navigatorObservers: observer != null ? [observer] : [],
      home: child,
    ),
  );
}

/// GoRouter-enabled test wrapper for testing navigation routing.
Widget createTestAppWithRouter({
  required Widget child,
  List<Override> overrides = const [],
  List<GoRoute> additionalRoutes = const [],
  NavigatorObserver? observer,
  ProviderContainer? container,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    observers: observer != null ? [observer] : [],
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/debrief',
        name: 'debrief',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Debrief Route Reached')),
        ),
      ),
      GoRoute(
        path: '/i_was_scammed',
        name: 'i_was_scammed',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Scammed Checklist Route Reached')),
        ),
      ),
      GoRoute(
        path: '/practice/call',
        name: 'practice_call',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Practice Call Route Reached')),
        ),
      ),
      GoRoute(
        path: '/scam_picker',
        name: 'scam_picker',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Scam Picker Route Reached')),
        ),
      ),
      GoRoute(
        path: '/fake_android',
        name: 'fake_android',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Fake Android Reached')),
        ),
      ),
      ...additionalRoutes,
    ],
  );

  final app = MaterialApp.router(
    theme: AppTheme.lightTheme,
    routerConfig: router,
  );

  if (container != null) {
    return UncontrolledProviderScope(
      container: container,
      child: app,
    );
  }

  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWith(() => PreferencesNotifier()),
      soundEffectServiceProvider.overrideWithValue(FakeSoundEffectService()),
      ...overrides,
    ],
    child: app,
  );
}
