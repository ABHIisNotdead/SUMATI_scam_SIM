import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sumati/features/message_practice/whatsapp_practice_screen.dart';
import 'package:sumati/features/message_practice/sms_practice_screen.dart';
import 'package:sumati/features/message_practice/providers/message_session_provider.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupMockAudioChannels();
  });
  group('Phase 6 Step 1: AI Context Bleed Prevention', () {
    test('Family Emergency thread receives medical/clinic responses, never legal/electricity threats', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(messageSessionProvider.notifier);

      // Inject Family Emergency active thread into WhatsApp
      notifier.dispatchAiPayload(
        app: 'FWhatsApp',
        text: 'Dad, I had an accident, please help me!',
        payloadType: MessagePayloadType.text,
      );

      // User sends a reply in family emergency thread
      notifier.sendUserReply(
        app: 'FWhatsApp',
        text: 'Are you okay? Who is this and where are you?',
      );

      // Wait for simulated scammer reply timer (1400ms)
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      final state = container.read(messageSessionProvider);
      final activeThread = state.whatsappThreads.firstWhere((t) => t.isScamActive);
      final lastMsg = activeThread.messages.last;

      // Must NOT contain legal threats or warrants
      expect(lastMsg.text, isNot(contains('Strict legal action')));
      expect(lastMsg.text, isNot(contains('High Court Warrant')));
      expect(lastMsg.text, isNot(contains('CBI')));
    });

    test('Electricity thread receives bill cutoff responses, never legal arrest threats', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(messageSessionProvider.notifier);

      // Send user reply in default MSEB Electricity thread
      notifier.sendUserReply(
        app: 'Messages',
        text: 'I already paid my electricity bill yesterday!',
        threadId: 'sms_scam_drill',
      );

      // Wait for simulated scammer reply timer (1400ms)
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      final state = container.read(messageSessionProvider);
      final elecThread = state.smsThreads.firstWhere((t) => t.id == 'sms_scam_drill');
      final lastMsg = elecThread.messages.last;

      // Must be related to electricity / bill / meter, NOT legal arrest
      expect(lastMsg.text, isNot(contains('Strict legal action')));
      expect(lastMsg.text, isNot(contains('High Court Warrant')));
      expect(lastMsg.text, anyOf(contains('Sharma'), contains('bill'), contains('feeder'), contains('disconnect'), contains('cutoff')));
    });

    test('Bank KYC thread receives card unfreeze responses, never power cuts or legal threats', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(messageSessionProvider.notifier);

      // Send user reply in Bank thread
      notifier.sendUserReply(
        app: 'Messages',
        text: 'Why is my card blocked? Who is calling?',
        threadId: 'sms_bank',
      );

      // Wait for simulated scammer reply timer (1400ms)
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      final state = container.read(messageSessionProvider);
      final bankThread = state.smsThreads.firstWhere((t) => t.id == 'sms_bank');
      final lastMsg = bankThread.messages.last;

      expect(lastMsg.text, isNot(contains('Strict legal action')));
      expect(lastMsg.text, isNot(contains('power supply will be cut')));
      expect(lastMsg.text, anyOf(contains('Deshmukh'), contains('KYC'), contains('debit card'), contains('verification')));
    });
  });

  group('Phase 6 Step 2 & 3: WhatsApp Accessibility UI (TTS Toggle & STT Mic)', () {
    testWidgets('Renders TTS Speaker toggle and STT Mic icon in WhatsApp Chat Page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WhatsAppPracticeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the first chat to view Chat Page
      final chatItem = find.text('Power Corp Notice (MSEB)');
      expect(chatItem, findsOneWidget);
      await tester.tap(chatItem);
      await tester.pumpAndSettle();

      // Verify TTS Speaker toggle exists in AppBar
      final ttsToggle = find.byKey(const Key('whatsapp_tts_toggle_button'));
      expect(ttsToggle, findsOneWidget);

      // Tap TTS toggle to enable neural voice readout
      await tester.tap(ttsToggle);
      await tester.pumpAndSettle();

      // Verify STT Microphone button exists in input pill
      final micButton = find.byKey(const Key('whatsapp_mic_button'));
      expect(micButton, findsOneWidget);

      // Tap microphone button
      await tester.tap(micButton);
      await tester.pumpAndSettle();
    });
  });

  group('Phase 6 Step 2 & 3: SMS Accessibility UI (TTS Toggle & STT Mic)', () {
    testWidgets('Renders TTS Speaker toggle and STT Mic icon in SMS Chat Page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmsPracticeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the SMS conversation thread
      final threadItem = find.text('VM-ELEC-PAY');
      expect(threadItem, findsOneWidget);
      await tester.tap(threadItem);
      await tester.pumpAndSettle();

      // Verify TTS Speaker toggle exists in AppBar
      final ttsToggle = find.byKey(const Key('sms_tts_toggle_button'));
      expect(ttsToggle, findsOneWidget);

      // Tap TTS toggle
      await tester.tap(ttsToggle);
      await tester.pumpAndSettle();

      // Verify STT Microphone button exists in input bar
      final micButton = find.byKey(const Key('sms_mic_button'));
      expect(micButton, findsOneWidget);

      // Tap microphone button
      await tester.tap(micButton);
      await tester.pumpAndSettle();
    });
  });
}
