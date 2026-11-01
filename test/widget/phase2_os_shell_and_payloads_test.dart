import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/providers/os_notification_provider.dart';
import 'package:sumati/core/widgets/global_notification_overlay.dart';
import 'package:sumati/features/fake_android/fake_android_screen.dart';
import 'package:sumati/features/message_practice/widgets/payload_widgets.dart';

void main() {
  group('Phase 2 Step 1: OS Shell (FakeAndroidScreen)', () {
    testWidgets('Renders Status Bar (Time, 5G, Battery) and Filler Icons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FakeAndroidScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Status Bar
      expect(find.text('10:45'), findsOneWidget);
      expect(find.text('5G'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);

      // Verify Non-interactive filler icons
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);

      // Verify 4 Dock Functional Apps
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);

      // Verify Exit button
      expect(find.text('Exit • बाहर निकलें'), findsOneWidget);
    });

    testWidgets('Dynamically updates red badge on dock apps via OsNotificationProvider', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FakeAndroidScreen(),
          ),
        ),
      );
      await tester.pump();

      // Initial state: no badge visible
      expect(find.text('3'), findsNothing);

      // Trigger incoming notification for FWhatsApp with 3 badge increment
      container.read(osNotificationProvider.notifier).handleCrossAppEvent({
        'event': 'trigger_sms',
        'target_app': 'FWhatsApp',
        'sender': '+91 98765 43210',
        'title': 'SBI Fraud Alert',
        'body': 'Your account has been locked. Verify immediately.',
        'badge_increment': 3,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      await tester.pump();

      // Badge on FWhatsApp should now show '3'
      expect(find.text('3'), findsOneWidget);

      // Clean up auto-dismiss timer
      container.read(osNotificationProvider.notifier).dismissBanner();
      await tester.pump();
    });
  });

  group('Phase 2 Step 2: GlobalNotificationOverlay', () {
    testWidgets('Heads-up notification drops down and can be dismissed', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GlobalNotificationOverlay(
              child: Scaffold(
                body: Center(child: Text('Underlying Screen Content')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Banner is not visible initially
      expect(find.text('Underlying Screen Content'), findsOneWidget);
      expect(find.text('URGENT NOTICE'), findsNothing);

      // Trigger cross-app banner
      container.read(osNotificationProvider.notifier).handleCrossAppEvent({
        'event': 'trigger_notification',
        'target_app': 'Messages',
        'sender': 'Electricity Board',
        'title': 'URGENT NOTICE',
        'body': 'Power will be disconnected tonight at 9:30 PM.',
        'badge_increment': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Banner is now visible
      expect(find.text('URGENT NOTICE'), findsOneWidget);
      expect(find.text('Power will be disconnected tonight at 9:30 PM.'), findsOneWidget);

      // Dismiss banner via dismiss button
      final dismissBtn = find.byTooltip('Dismiss');
      expect(dismissBtn, findsOneWidget);
      await tester.tap(dismissBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(osNotificationProvider).activeBanner, isNull);
    });
  });

  group('Phase 2 Step 3: Reusable Payload Widgets', () {
    testWidgets('MaliciousLinkWidget renders domain, title, and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MaliciousLinkWidget(
                url: 'https://mseb-bill-pay.in/verify',
                title: 'Electricity Bill Verification Portal',
                description: 'Pay pending bill of Rs. 1450',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Electricity Bill Verification Portal'), findsOneWidget);
      expect(find.text('https://mseb-bill-pay.in/verify'), findsOneWidget);
      expect(find.text('mseb-bill-pay.in'), findsOneWidget);

      await tester.tap(find.byType(MaliciousLinkWidget));
      expect(tapped, isTrue);
    });

    testWidgets('BlurredImageWidget renders blur overlay, download icon, and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BlurredImageWidget(
                caption: 'Official CBI Arrest Order #892/2026',
                fileSize: '2.1 MB',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tap to Download'), findsOneWidget);
      expect(find.text('2.1 MB'), findsOneWidget);
      expect(find.text('Official CBI Arrest Order #892/2026'), findsOneWidget);

      await tester.tap(find.byType(BlurredImageWidget));
      expect(tapped, isTrue);
    });

    testWidgets('QrCodePayloadWidget renders UPI info, amount, and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QrCodePayloadWidget(
                payeeName: 'Court Verification Escrow',
                upiId: 'escrow.bail@okhdfc',
                amount: '₹50,000.00',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Court Verification Escrow'), findsOneWidget);
      expect(find.text('escrow.bail@okhdfc'), findsOneWidget);
      expect(find.text('₹50,000.00'), findsOneWidget);
      expect(find.text('Tap to Scan / Pay'), findsOneWidget);

      await tester.tap(find.byType(QrCodePayloadWidget));
      expect(tapped, isTrue);
    });

    testWidgets('DummyApkWidget renders Android icon, .apk file name, and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DummyApkWidget(
                fileName: 'Digital_Safety_Update.apk',
                fileSize: '12.4 MB',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Digital_Safety_Update.apk'), findsOneWidget);
      expect(find.text('APK'), findsOneWidget);
      expect(find.text('12.4 MB'), findsOneWidget);
      expect(find.byIcon(Icons.android_rounded), findsOneWidget);

      await tester.tap(find.byType(DummyApkWidget));
      expect(tapped, isTrue);
    });

    testWidgets('DummyZipWidget renders zip icon, file count, and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DummyZipWidget(
                fileName: 'Seized_Account_Ledger.zip',
                fileSize: '5.1 MB',
                fileCount: 4,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Seized_Account_Ledger.zip'), findsOneWidget);
      expect(find.text('ZIP'), findsOneWidget);
      expect(find.text('5.1 MB • 4 files'), findsOneWidget);
      expect(find.byIcon(Icons.folder_zip_rounded), findsOneWidget);

      await tester.tap(find.byType(DummyZipWidget));
      expect(tapped, isTrue);
    });
  });
}
