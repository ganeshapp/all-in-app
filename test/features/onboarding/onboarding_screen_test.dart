/// O0 · the tour and its gate (DESIGN.md §8, §2.5).
///
/// The behaviours the spec is explicit about: the four verbatim pages in
/// order, paging by button and by swipe, the descriptor counting, the
/// blocked-back response on page 1 (and its two degradations), page 4's live
/// coach note, the placement hand-off, and — the one that matters most — that
/// every close path marks the tour seen so it is never shown again.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/onboarding/content/tour_copy.dart';
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/features/onboarding/screens/onboarding_screen.dart';
import 'package:allin/features/onboarding/widgets/onboarding_gate.dart';
import 'package:allin/features/onboarding/widgets/tour_page.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/onboarding_store.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Size kPhone = Size(390, 844);

class TourHarness {
  TourHarness(this.container, this.router, this.haptics);

  final ProviderContainer container;
  final GoRouter router;
  final RecordingHapticDriver haptics;

  /// O0 is pushed imperatively, so `currentConfiguration.uri` still reads the
  /// declarative location underneath it — the tree is the honest witness.
  bool get tourIsOpen => find.byType(OnboardingScreen).evaluate().isNotEmpty;
}

/// Mounts Home with O0 pushed on top, the way the gate presents it.
Future<TourHarness> pumpTour(
  WidgetTester tester, {
  KeyValueStore? store,
  Size size = kPhone,
  double textScale = 1.0,
  bool gate = false,
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final kv = store ?? KeyValueStore.memory();
  await SettingsStore(kv).save(settings);
  final haptics = RecordingHapticDriver();

  final router = GoRouter(
    initialLocation: AllInRoutes.todayPath,
    routes: [
      GoRoute(
        path: AllInRoutes.todayPath,
        builder: (context, state) => const Scaffold(body: Text('H0')),
      ),
      GoRoute(
        path: AllInRoutes.onboardingPath,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AllInRoutes.placementPath,
        builder: (context, state) => const Scaffold(body: Text('D5')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kv),
        hapticDriverProvider.overrideWithValue(haptics),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AllInAppTheme.dark(),
        routerConfig: router,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child:
                  gate
                      ? OnboardingGate(
                        router: router,
                        child: child ?? const SizedBox.shrink(),
                      )
                      : (child ?? const SizedBox.shrink()),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (!gate) {
    router.push(AllInRoutes.onboardingPath);
    await tester.pumpAndSettle();
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return TourHarness(container, router, haptics);
}

/// The Android hardware back button / iOS edge swipe, as the engine delivers
/// it: a `popRoute` on the navigation channel.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(AllInButton, TourCopy.next));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('page 1 is the verbatim desktop copy, with the a11y footer', (
    tester,
  ) async {
    await pumpTour(tester);

    expect(find.text(TourCopy.title), findsOneWidget);
    expect(find.text(TourCopy.tourDescriptor(1)), findsOneWidget);
    expect(find.text(TourCopy.pages[0].title), findsOneWidget);
    expect(find.text(TourCopy.pages[0].body), findsOneWidget);
    expect(
      find.text(TourCopy.fourColourFootnote),
      findsOneWidget,
      reason: '§13 puts the four-colour offer in page 1\'s footer',
    );
    expect(find.text(TourCopy.skip), findsOneWidget);
  });

  testWidgets('Next walks all four pages, then Continue reaches placement', (
    tester,
  ) async {
    final h = await pumpTour(tester);

    for (var i = 0; i < TourCopy.pages.length - 1; i++) {
      expect(find.text(TourCopy.pages[i].title), findsOneWidget);
      expect(find.text(TourCopy.tourDescriptor(i + 1)), findsOneWidget);
      await tapNext(tester);
    }

    // Page 4 reads "Continue" and shows the live three-layer coach note.
    expect(find.text(TourCopy.pages.last.title), findsOneWidget);
    expect(find.text(TourCopy.next), findsNothing);
    expect(find.text(TourCopy.continueLabel), findsOneWidget);
    expect(find.byType(TourCoachNotePreview), findsOneWidget);
    expect(
      find.text(TourCoachNotePreview.review.plain!),
      findsOneWidget,
      reason: 'the TONE.md example, layer 1, verbatim',
    );

    await tester.tap(find.widgetWithText(AllInButton, TourCopy.continueLabel));
    await tester.pumpAndSettle();

    // §8.2: the descriptor and the page title are the same words, so both
    // appear — the descriptor under the ✕ row and the title on the page.
    expect(find.text(TourCopy.placementDescriptor), findsNWidgets(2));
    expect(find.text(TourCopy.placementBody), findsOneWidget);
    expect(find.text(TourCopy.placementSkip), findsOneWidget);
    expect(find.text(TourCopy.placementStart), findsOneWidget);
    expect(h.tourIsOpen, isTrue);
  });

  testWidgets('swiping pages both ways works', (tester) async {
    await pumpTour(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(TourCopy.pages[1].title), findsOneWidget);
    expect(find.text(TourCopy.tourDescriptor(2)), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(TourCopy.pages[0].title), findsOneWidget);
  });

  group('system back (§2.5)', () {
    testWidgets('goes to the previous page', (tester) async {
      final h = await pumpTour(tester);
      await tapNext(tester);
      expect(find.text(TourCopy.pages[1].title), findsOneWidget);

      await systemBack(tester);
      await tester.pumpAndSettle();

      expect(find.text(TourCopy.pages[0].title), findsOneWidget);
      expect(h.tourIsOpen, isTrue, reason: 'back paged, it did not close');
      expect(find.text('H0'), findsNothing);
    });

    testWidgets('on page 1 it is refused: shake + selectionClick', (
      tester,
    ) async {
      final h = await pumpTour(tester);
      final rest = tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx;

      await systemBack(tester);
      await tester.pump();

      var travelled = 0.0;
      for (var i = 0; i < 12; i++) {
        travelled = math.max(
          travelled,
          (tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx - rest)
              .abs(),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(
        travelled,
        greaterThan(0.5),
        reason: 'the page content shakes; §2.5 asks for 4 pt',
      );
      expect(
        travelled,
        lessThanOrEqualTo(OnboardingScreen.shakeAmplitude + 0.01),
        reason: 'no further than 4 pt',
      );
      expect(
        tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx,
        closeTo(rest, 0.01),
        reason: 'and it ends exactly where it started',
      );
      expect(h.haptics.played, contains(HapticPattern.selection));
      expect(h.tourIsOpen, isTrue);
      expect(find.text('H0'), findsNothing);
    });

    testWidgets('reduced motion drops the shake, keeping the haptic', (
      tester,
    ) async {
      final h = await pumpTour(
        tester,
        settings: const AppSettings(reducedMotion: true),
      );

      final before = tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx;
      await systemBack(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final during = tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx;

      expect(during, closeTo(before, 0.01), reason: 'motion is dropped');
      expect(h.haptics.played, [HapticPattern.selection]);
      await tester.pumpAndSettle();
    });

    testWidgets('with haptics off too, nothing happens at all', (tester) async {
      final h = await pumpTour(
        tester,
        settings: const AppSettings(reducedMotion: true, haptics: false),
      );

      final before = tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx;
      await systemBack(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(
        tester.getTopLeft(find.text(TourCopy.pages[0].title)).dx,
        closeTo(before, 0.01),
      );
      expect(h.haptics.played, isEmpty);
      expect(h.tourIsOpen, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('every close path marks the tour seen (§8)', () {
    Future<void> expectClosed(WidgetTester tester, TourHarness h) async {
      expect(h.container.read(onboardingSeenProvider), isTrue);
      expect(
        h.container.read(onboardingStoreProvider).hasOnboarded(),
        isTrue,
        reason: 'allin.onboarded.v1 is written, not just held in memory',
      );
      expect(find.byType(OnboardingScreen), findsNothing);
    }

    testWidgets('the ✕', (tester) async {
      final h = await pumpTour(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('H0'), findsOneWidget);
      await expectClosed(tester, h);
    });

    testWidgets('"Skip"', (tester) async {
      final h = await pumpTour(tester);
      await tester.tap(find.widgetWithText(AllInButton, TourCopy.skip));
      await tester.pumpAndSettle();
      await expectClosed(tester, h);
    });

    testWidgets('"Skip — start playing" on the placement page', (tester) async {
      final h = await pumpTour(tester);
      for (var i = 0; i < TourCopy.pages.length - 1; i++) {
        await tapNext(tester);
      }
      await tester.tap(
        find.widgetWithText(AllInButton, TourCopy.continueLabel),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AllInButton, TourCopy.placementSkip),
      );
      await tester.pumpAndSettle();

      expect(find.text('H0'), findsOneWidget);
      await expectClosed(tester, h);
    });

    testWidgets('"Calibrate me" hands off to D5 in the same modal slot', (
      tester,
    ) async {
      final h = await pumpTour(tester);
      for (var i = 0; i < TourCopy.pages.length - 1; i++) {
        await tapNext(tester);
      }
      await tester.tap(
        find.widgetWithText(AllInButton, TourCopy.continueLabel),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AllInButton, TourCopy.placementStart),
      );
      await tester.pumpAndSettle();

      expect(find.text('D5'), findsOneWidget);
      expect(
        find.text('H0'),
        findsNothing,
        reason: 'D5 replaces O0 in the same modal slot, over Home',
      );
      await expectClosed(tester, h);
    });
  });

  group('the first-run gate (§8)', () {
    testWidgets('presents O0 once, then never again', (tester) async {
      final store = KeyValueStore.memory();

      final first = await pumpTour(tester, store: store, gate: true);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(
        first.container.read(onboardingStoreProvider).hasOnboarded(),
        isTrue,
      );

      // A completely fresh launch over the same storage: no tour.
      await pumpTour(tester, store: store, gate: true);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('H0'), findsOneWidget);
    });

    testWidgets('storage that cannot answer never nags', (tester) async {
      final store = KeyValueStore.memory(const {kOnboardedKey: '1'});
      await pumpTour(tester, store: store, gate: true);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  testWidgets('renders at every supported size and text scale', (tester) async {
    for (final size in const [Size(360, 780), Size(390, 844), Size(430, 932)]) {
      for (final scale in const [1.0, 1.3]) {
        await pumpTour(tester, size: size, textScale: scale);
        // Walk every page; nothing may overflow at any of them.
        for (var i = 0; i < TourCopy.pages.length - 1; i++) {
          await tapNext(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: 'page ${i + 2} at $size / $scale',
          );
        }
        await tester.tap(
          find.widgetWithText(AllInButton, TourCopy.continueLabel),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
