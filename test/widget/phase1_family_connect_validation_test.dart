import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sumati/core/providers/preferences_provider.dart';
import 'package:sumati/features/family/family_dashboard_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupMockAudioChannels();
    await initTestHive();
  });

  setUp(() async {
    final box = Hive.box('preferences');
    await box.clear();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        preferencesProvider.overrideWith(() => FakePreferencesNotifier('en')),
      ],
      child: const MaterialApp(
        home: FamilyDashboardScreen(),
      ),
    );
  }

  group('Phase 1: Family Dashboard 10-Digit & 4-Digit Validation Tests', () {
    testWidgets('enforces 10-digit mobile number constraint and rejects invalid phone', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find mobile number input and PIN input
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      final phoneFinder = textFields.first;
      final pinFinder = textFields.last;

      // 1. Enter an 8-digit phone number and 4-digit PIN
      await tester.enterText(phoneFinder, '98201234');
      await tester.enterText(pinFinder, '1234');
      await tester.pumpAndSettle();

      // Tap Connect button
      final connectBtn = find.widgetWithText(ElevatedButton, 'Connect & View Safety Report');
      expect(connectBtn, findsOneWidget);
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      // Should display 10-digit validation error
      expect(find.text('Please enter a valid 10-digit mobile number.'), findsOneWidget);

      // 2. Try entering more than 10 digits
      await tester.enterText(phoneFinder, '9820123456789');
      await tester.pumpAndSettle();

      final phoneWidget = tester.widget<TextField>(phoneFinder);
      expect(phoneWidget.controller?.text.length, lessThanOrEqualTo(10));
    });

    testWidgets('enforces 4-digit PIN constraint and rejects 3-digit PIN', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final phoneFinder = textFields.first;
      final pinFinder = textFields.last;

      // Enter valid 10-digit phone but invalid 3-digit PIN
      await tester.enterText(phoneFinder, '9820123456');
      await tester.enterText(pinFinder, '123');
      await tester.pumpAndSettle();

      final connectBtn = find.widgetWithText(ElevatedButton, 'Connect & View Safety Report');
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      // Should display 4-digit PIN validation error
      expect(find.text('Please enter a valid 4-digit security PIN.'), findsOneWidget);

      // Verify maxLength on PIN TextField is 4
      final pinWidget = tester.widget<TextField>(pinFinder);
      expect(pinWidget.maxLength, equals(4));
    });
  });
}
