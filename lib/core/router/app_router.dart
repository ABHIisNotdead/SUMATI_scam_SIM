import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/scenario.dart';
import '../../features/scam_picker/scam_picker_screen.dart';
import '../../features/call_practice/call_practice_screen.dart';
import '../../features/web_practice/web_practice_screen.dart';
import '../../features/debrief/debrief_screen.dart';
import '../../features/scammed_checklist/scammed_checklist_screen.dart';
import '../../features/scammed_checklist/scam_reports_feed_screen.dart';
import '../../features/scam_checker/ask_ai_screen.dart';
import '../../features/fake_android/fake_android_screen.dart';
import '../../features/family/family_dashboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/message_practice/whatsapp_practice_screen.dart';
import '../../features/message_practice/sms_practice_screen.dart';
import '../../features/scam_picker/scenarios_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Check preferences Hive box for isFirstLaunch
  bool isFirstLaunch = true;
  if (Hive.isBoxOpen('preferences')) {
    isFirstLaunch = Hive.box('preferences').get('isFirstLaunch', defaultValue: true) as bool;
  }

  return GoRouter(
    initialLocation: isFirstLaunch ? '/onboarding' : '/scam_picker',
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/root',
        builder: (context, state) => const ScamPickerScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const ScamPickerScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const ScamPickerScreen(),
      ),
      GoRoute(
        path: '/scam_picker',
        name: 'scam_picker',
        builder: (context, state) => const ScamPickerScreen(),
      ),
      GoRoute(
        path: '/scenarios',
        name: 'scenarios',
        builder: (context, state) {
          final channel = (state.extra as String?) ?? state.uri.queryParameters['channel'];
          return ScenariosScreen(initialChannel: channel);
        },
      ),
      GoRoute(
        path: '/fake_android',
        name: 'fake_android',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return FakeAndroidScreen(
            scenario: extra['scenario'] as Scenario?,
            title: extra['title'] as String? ?? 'Incoming Alert',
            persona: extra['persona'] as String? ?? 'a scammer attempting fraud',
            initialMsg: extra['initialMsg'] as String? ?? 'Hello. Please respond urgently.',
            channel: extra['channel'] as String? ?? 'call',
          );
        },
      ),
      GoRoute(
        path: '/practice/call',
        name: 'call_practice',
        builder: (context, state) {
          final extra = state.extra;
          Scenario? scenario;
          bool startActive = false;

          if (extra is Scenario) {
            scenario = extra;
          } else if (extra is Map<String, dynamic>) {
            scenario = extra['scenario'] as Scenario?;
            startActive = extra['startActive'] as bool? ?? false;
          }

          return CallPracticeScreen(
            scenario: scenario,
            startActive: startActive,
          );
        },
      ),
      GoRoute(
        path: '/practice/whatsapp',
        name: 'whatsapp_practice',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Scenario) {
            return WhatsAppPracticeScreen(scenario: extra);
          } else if (extra is Map<String, dynamic>) {
            return WhatsAppPracticeScreen(
              scenario: extra['scenario'] as Scenario?,
              title: extra['title'] as String?,
              persona: extra['persona'] as String?,
              initialMessage: extra['initialMessage'] as String?,
            );
          }
          return const WhatsAppPracticeScreen();
        },
      ),
      GoRoute(
        path: '/practice/sms',
        name: 'sms_practice',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Scenario) {
            return SmsPracticeScreen(scenario: extra);
          } else if (extra is Map<String, dynamic>) {
            return SmsPracticeScreen(
              scenario: extra['scenario'] as Scenario?,
              title: extra['title'] as String?,
              persona: extra['persona'] as String?,
              initialMessage: extra['initialMessage'] as String?,
            );
          }
          return const SmsPracticeScreen();
        },
      ),
      GoRoute(
        path: '/practice/web',
        name: 'web_practice',
        builder: (context, state) {
          final scenario = state.extra as Scenario?;
          return WebPracticeScreen(scenario: scenario);
        },
      ),
      GoRoute(
        path: '/debrief',
        name: 'debrief',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return DebriefScreen(
              outcome: extra['outcome'] ?? 'success:survived',
              customMessage: extra['message'],
            );
          } else if (extra is String) {
            return DebriefScreen(outcome: extra);
          }
          return const DebriefScreen(outcome: 'success:survived');
        },
      ),
      GoRoute(
        path: '/ask_ai',
        name: 'ask_ai',
        builder: (context, state) => const AskAiScreen(),
      ),
      GoRoute(
        path: '/i_was_scammed',
        name: 'i_was_scammed',
        builder: (context, state) => const ScammedChecklistScreen(),
      ),
      GoRoute(
        path: '/scam_reports_feed',
        name: 'scam_reports_feed',
        builder: (context, state) => const ScamReportsFeedScreen(),
      ),
      GoRoute(
        path: '/progress',
        name: 'progress',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Progress & Badges'))),
      ),
      GoRoute(
        path: '/family',
        name: 'family_dashboard',
        builder: (context, state) => const FamilyDashboardScreen(),
      ),
      GoRoute(
        path: '/family_dashboard',
        builder: (context, state) => const FamilyDashboardScreen(),
      ),
      GoRoute(
        path: '/ai_chat',
        name: 'ai_chat',
        builder: (context, state) {
          final extraMap = state.extra is Map ? (state.extra as Map) : null;
          final persona = extraMap?['persona']?.toString() ?? 'a scammer attempting fraud';
          final initialMessage = extraMap?['initialMessage']?.toString() ?? 'Hello, please respond immediately.';
          final title = extraMap?['title']?.toString();
          final channel = extraMap?['channel']?.toString();
          if (channel == 'sms') {
            return SmsPracticeScreen(
              persona: persona,
              initialMessage: initialMessage,
              title: title,
            );
          }
          return WhatsAppPracticeScreen(
            persona: persona,
            initialMessage: initialMessage,
            title: title,
          );
        },
      ),
    ],
  );
});

final appRouterProvider = routerProvider;
