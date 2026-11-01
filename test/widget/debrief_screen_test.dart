import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/providers/preferences_provider.dart';
import 'package:sumati/features/debrief/debrief_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupMockAudioChannels();
    await initTestHive();
  });

  tearDownAll(() async {
    await cleanTestHive();
  });

  group('F8, F9, F10: Debrief Screen Components & Voice Guidance Tests', () {
    void setTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // -------------------------------------------------------------
    // Tier 1: Feature Coverage (Requirement R4, F8, F9, F10)
    // -------------------------------------------------------------

    testWidgets('F9-T1-01: Successful defense renders celebratory Well Done headline and green icon',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
          ),
        ),
      );

      await tester.pump();

      // Successful defense must render celebratory headline
      expect(find.textContaining('Well Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('F9-T1-02: Compromised outcome renders Be Careful warning and warning icon',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'failure:compromised',
          ),
        ),
      );

      await tester.pump();

      // Compromised outcome must render caution headline
      expect(find.textContaining('Be Careful'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('F8-T1-03: Debrief screen renders custom explanation of the scam attempt',
        (tester) async {
      setTallViewport(tester);
      const customExplanation =
          'You successfully challenged the fake police officer and demanded physical paperwork.';

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
            customMessage: customExplanation,
          ),
        ),
      );

      await tester.pump();

      expect(find.text(customExplanation), findsOneWidget);
    });

    testWidgets('F8-T1-04: Debrief screen renders safety takeaways breakdown section',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
          ),
        ),
      );

      await tester.pump();

      // Key takeaways title with colon
      expect(find.text('Key Takeaways:'), findsOneWidget);

      // Checkmarks for takeaways
      expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
    });

    testWidgets('F8-T1-05: Navigation buttons are available for Practice Again and Choose Another Scam',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Practice Again'), findsOneWidget);
      expect(find.text('Choose Another Scam'), findsOneWidget);

      // Tap Practice Again
      await tester.tap(find.text('Practice Again'));
      await tester.pumpAndSettle();

      expect(find.text('Practice Call Route Reached'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    testWidgets('F8-T2-01: Boundary - Null customMessage renders localized default message',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
            customMessage: null,
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('warning signs'), findsOneWidget);
    });

    testWidgets('F8-T2-02: Boundary - Hindi language mode displays localized celebratory text',
        (tester) async {
      setTallViewport(tester);

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
          ),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('hi')),
          ],
        ),
      );

      await tester.pump();

      expect(find.textContaining('बहुत बढ़िया'), findsOneWidget);
    });

    testWidgets('F8-T2-03: Boundary - Marathi language mode displays localized cautionary text',
        (tester) async {
      setTallViewport(tester);

      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'failure:compromised',
          ),
          overrides: [
            preferencesProvider.overrideWith(() => FakePreferencesNotifier('mr')),
          ],
        ),
      );

      await tester.pump();

      expect(find.textContaining('सावध राहा'), findsAtLeastNWidgets(1));
    });

    testWidgets('F9-T2-04: Boundary - hung_up outcome is recognized as success defense',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:hung_up',
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('Well Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('F10-T2-05: Boundary - Choose Another Scam routes to /scam_picker',
        (tester) async {
      setTallViewport(tester);
      await tester.pumpWidget(
        createTestAppWithRouter(
          child: const DebriefScreen(
            outcome: 'success:survived',
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.text('Choose Another Scam'));
      await tester.pumpAndSettle();

      expect(find.text('Scam Picker Route Reached'), findsOneWidget);
    });
  });
}
