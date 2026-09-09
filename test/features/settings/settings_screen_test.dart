/// X0 / X1 / X2 / X3 widget tests (DESIGN.md §9, §7.9, §7.10).
///
/// What the spec is explicit about and therefore what is asserted here:
/// every control writes through `SettingsStore` and reads back after a
/// remount; the theme and reduce-motion rows change the *running* app; the
/// reset dialog's danger button only wakes up on the exact typed word; the
/// four-colour preview follows its switch; and the Data rows map onto the
/// three service calls with the §14 wording on every failure.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/settings/content/about_copy.dart';
import 'package:allin/features/settings/screens/about_screen.dart';
import 'package:allin/features/settings/screens/settings_screen.dart';
import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/features/settings/widgets/reset_dialog.dart';
import 'package:allin/features/settings/widgets/setting_rows.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Size kPhone = Size(390, 844);

/// Mounts X0 alone on a tiny router so `context.push`/`pop` work.
Future<ProviderContainer> pumpSettings(
  WidgetTester tester, {
  required KeyValueStore store,
  Size size = kPhone,
  double textScale = 1.0,
  List<Override> overrides = const [],
  String? section,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AllInRoutes.settingsPath,
    routes: [
      GoRoute(
        path: AllInRoutes.progressPath,
        builder: (context, state) => const Scaffold(body: Text('T0')),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => SettingsScreen(section: section),
            routes: [
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AllInRoutes.onboardingPath,
        builder: (context, state) => const Scaffold(body: Text('O0')),
      ),
    ],
  );

  final key = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store), ...overrides],
      child: _ThemedApp(routerKey: key, router: router, textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
}

/// The real theme wiring: `themeModeProvider` drives `MaterialApp`, so a tap
/// on the Theme row must repaint the whole app inside one test.
class _ThemedApp extends ConsumerWidget {
  const _ThemedApp({
    required this.routerKey,
    required this.router,
    this.textScale = 1.0,
  });

  final GlobalKey routerKey;
  final GoRouter router;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    key: routerKey,
    debugShowCheckedModeBanner: false,
    theme: AllInAppTheme.light(),
    darkTheme: AllInAppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: router,
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
  );
}

/// Brings [target] into the viewport. `scrollUntilVisible` only guarantees the
/// widget is *built* (a lazy `ListView` builds a cache extent past the fold),
/// so `ensureVisible` finishes the job before anything is tapped.
Future<Finder> reveal(WidgetTester tester, Finder target) async {
  if (!tester.any(target)) await tester.scrollUntilVisible(target, 200);
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  return target;
}

Finder rowNamed(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SettingRow));

/// Taps the switch that sits in the row titled [title].
Future<void> toggleRow(WidgetTester tester, String title) async {
  await reveal(tester, find.text(title));
  final control = find.descendant(
    of: rowNamed(title),
    matching: find.byType(AllInSwitch),
  );
  expect(control, findsOneWidget, reason: 'row "$title" has a switch');
  await tester.tap(control);
  await tester.pumpAndSettle();
}

/// Taps segment [label] inside the row titled [title].
Future<void> tapSegment(WidgetTester tester, String title, String label) async {
  await reveal(tester, find.text(title));
  final segment = find.descendant(
    of: rowNamed(title),
    matching: find.text(label),
  );
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

void main() {
  test('the four-colour caption paints each suit in the colour it names', () {
    // As a flat string the caption contradicted itself: "♦ blue" printed with
    // a red diamond, "♣ green" with a grey club, and ♥ fell through to the
    // colour-emoji font. Colours come from the deck itself.
    List<TextSpan> glyphs(bool on) =>
        SettingsCopy.fourColourSpans(on: on)
            .whereType<TextSpan>()
            .expand(
              (s) => s.children?.whereType<TextSpan>() ?? const <TextSpan>[],
            )
            .where((s) => s.style?.color != null)
            .toList();

    final on = glyphs(true);
    expect(on.map((s) => s.style!.color), [
      AllInColors.suitBlack,
      AllInColors.suitRed,
      AllInColors.suitBlue,
      AllInColors.suitGreen,
    ]);
    // U+FE0E forces text presentation so ♥ never renders as an emoji.
    for (final span in on) {
      expect(span.text, contains('\uFE0E'));
    }

    // With the setting off the caption follows the two-colour deck instead.
    expect(glyphs(false).map((s) => s.style!.color), [
      AllInColors.suitBlack,
      AllInColors.suitRed,
      AllInColors.suitRed,
      AllInColors.suitBlack,
    ]);
    final wordsOff =
        SettingsCopy.fourColourSpans(on: false)
            .whereType<TextSpan>()
            .expand(
              (s) => s.children?.whereType<TextSpan>() ?? const <TextSpan>[],
            )
            .where((s) => s.style?.color == null)
            .map((s) => s.text)
            .toList();
    expect(wordsOff, ['black', 'red', 'red', 'black']);
  });

  testWidgets('renders every group in both themes and at 1.3x text', (
    tester,
  ) async {
    for (final size in const [Size(360, 780), Size(390, 844), Size(430, 932)]) {
      for (final scale in const [1.0, 1.3]) {
        await pumpSettings(
          tester,
          store: KeyValueStore.memory(),
          size: size,
          textScale: scale,
        );
        expect(find.text(SettingsCopy.subtitle), findsOneWidget);
        // Every group is reachable — the list is lazy, so each one is
        // scrolled to in turn rather than expected to exist up front.
        for (final group in const [
          SettingsCopy.tableGroup,
          SettingsCopy.coachGroup,
          SettingsCopy.playGroup,
          SettingsCopy.learningGroup,
          SettingsCopy.dataGroup,
          SettingsCopy.aboutGroup,
        ]) {
          await reveal(tester, find.text(group.toUpperCase()));
          expect(
            find.text(group.toUpperCase()),
            findsOneWidget,
            reason: '$group at $size / $scale',
          );
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  group('every control persists and re-reads', () {
    testWidgets('the switches', (tester) async {
      final store = KeyValueStore.memory();
      await pumpSettings(tester, store: store);

      await toggleRow(tester, SettingsCopy.fourColour);
      await toggleRow(tester, SettingsCopy.realisticReveals);
      await toggleRow(tester, SettingsCopy.reduceMotion);
      await toggleRow(tester, SettingsCopy.haptics);
      await toggleRow(tester, SettingsCopy.alwaysExpand);
      await toggleRow(tester, SettingsCopy.evCoach);
      await toggleRow(tester, SettingsCopy.autoDeal);

      // Written through to storage…
      final saved = SettingsStore(store).load();
      expect(saved.fourColorDeck, isTrue);
      expect(saved.realisticReveal, isTrue);
      expect(saved.reducedMotion, isTrue);
      expect(saved.haptics, isFalse, reason: 'haptics default on');
      expect(saved.alwaysExpandMath, isTrue);
      expect(saved.coachEnabled, isFalse, reason: 'EV Coach defaults on');
      expect(saved.autoDeal, isTrue);

      // …and read back by a completely fresh container over the same store.
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).toJson(), saved.toJson());
    });

    testWidgets('the segmented controls', (tester) async {
      final store = KeyValueStore.memory();
      await pumpSettings(tester, store: store);

      await tapSegment(tester, SettingsCopy.strictness, 'Strict');
      await tapSegment(tester, SettingsCopy.simQuality, 'High');
      await tapSegment(tester, SettingsCopy.pace, 'Auto');
      await tapSegment(tester, SettingsCopy.speed, 'Fast');

      final saved = SettingsStore(store).load();
      expect(saved.coachStrictness, CoachStrictness.strict);
      expect(saved.simQuality, SimQuality.high);
      expect(saved.paceMode, PaceMode.auto);
      expect(saved.speedMs, PaceSpeed.all.last);
    });

    testWidgets('Speed is inert while Pace is Step, and says why', (
      tester,
    ) async {
      final store = KeyValueStore.memory();
      await pumpSettings(tester, store: store);

      expect(find.text(SettingsCopy.speedStepDesc), findsOneWidget);
      await tapSegment(tester, SettingsCopy.pace, 'Auto');
      expect(find.text(SettingsCopy.speedAutoDesc), findsOneWidget);
      expect(find.text(SettingsCopy.speedStepDesc), findsNothing);
    });
  });

  testWidgets('theme takes effect immediately — the app repaints', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    final container = await pumpSettings(tester, store: store);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    await tapSegment(tester, SettingsCopy.theme, 'Light');

    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.light,
      reason: 'the live MaterialApp switched, not just the store',
    );
    expect(ThemeStore(store).load(), AppThemeMode.light);
  });

  testWidgets('reduce motion takes effect immediately', (tester) async {
    final store = KeyValueStore.memory();
    final container = await pumpSettings(tester, store: store);

    expect(container.read(reducedMotionProvider), isFalse);
    await toggleRow(tester, SettingsCopy.reduceMotion);
    expect(container.read(reducedMotionProvider), isTrue);
    expect(SettingsStore(store).load().reducedMotion, isTrue);
  });

  testWidgets('haptics off silences the Haptics service everywhere', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    final container = await pumpSettings(tester, store: store);

    expect(container.read(hapticsEnabledProvider), isTrue);
    await toggleRow(tester, SettingsCopy.haptics);
    expect(container.read(hapticsEnabledProvider), isFalse);
    expect(container.read(hapticsProvider).enabled, isFalse);
  });

  testWidgets('the four-colour preview follows its switch', (tester) async {
    final store = KeyValueStore.memory();
    await pumpSettings(tester, store: store);

    FourColourDeckPreview preview() => tester.widget<FourColourDeckPreview>(
      find.byType(FourColourDeckPreview),
    );

    expect(preview().fourColorDeck, isFalse);
    await toggleRow(tester, SettingsCopy.fourColour);
    expect(preview().fourColorDeck, isTrue);
  });

  group('X2 · reset all progress', () {
    testWidgets('the danger button only wakes on the exact word', (
      tester,
    ) async {
      final store = KeyValueStore.memory();
      await pumpSettings(tester, store: store);

      await reveal(tester, find.text(SettingsCopy.reset));
      await tester.tap(find.text(SettingsCopy.reset));
      await tester.pumpAndSettle();
      expect(find.text(ResetCopy.title), findsOneWidget);

      TextButton confirm() => tester.widget<TextButton>(
        find.widgetWithText(TextButton, ResetCopy.confirmLabel),
      );
      expect(confirm().onPressed, isNull, reason: 'disabled while empty');

      for (final wrong in const ['RESE', 'reset', 'RESET ', 'RESETT']) {
        await tester.enterText(find.byType(TextField), wrong);
        await tester.pump();
        expect(
          confirm().onPressed,
          isNull,
          reason: '"$wrong" is not the confirmation word',
        );
        // §14: a wrong entry shows no error text, deliberately.
        expect(find.textContaining('Type RESET'), findsOneWidget);
      }

      await tester.enterText(find.byType(TextField), ResetCopy.confirmWord);
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
    });

    testWidgets('confirming erases stats and toasts', (tester) async {
      final store = KeyValueStore.memory();
      await pumpSettings(tester, store: store);

      await reveal(tester, find.text(SettingsCopy.reset));
      await tester.tap(find.text(SettingsCopy.reset));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ResetCopy.confirmWord);
      await tester.pump();
      await tester.tap(find.text(ResetCopy.confirmLabel));
      await tester.pumpAndSettle();

      expect(find.text(ResetCopy.title), findsNothing);
      expect(
        find.text(SettingsDataService.progressErased),
        findsOneWidget,
        reason: '§7.10 confirmation toast',
      );
      // Let the toast retire so no timer outlives the tree.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('cancelling erases nothing', (tester) async {
      final store = KeyValueStore.memory();
      await pumpSettings(tester, store: store);

      await reveal(tester, find.text(SettingsCopy.reset));
      await tester.tap(find.text(SettingsCopy.reset));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ResetCopy.cancelLabel));
      await tester.pumpAndSettle();

      expect(find.text(ResetCopy.title), findsNothing);
      expect(find.text(SettingsDataService.progressErased), findsNothing);
    });
  });

  testWidgets('"Import hands" hands the user to the Stats tab (§7.8)', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    final container = await pumpSettings(tester, store: store);

    expect(container.read(importRequestProvider), 0);
    await reveal(tester, find.text(SettingsCopy.importHands));
    await tester.tap(find.text(SettingsCopy.importHands));
    await tester.pumpAndSettle();

    expect(container.read(importRequestProvider), 1);
    expect(find.text('T0'), findsOneWidget);
  });

  testWidgets('"Run again" clears the flag, re-arms O1 and presents O0', (
    tester,
  ) async {
    final store = KeyValueStore.memory(const {
      'allin.onboarded.v1': '1',
      'allin.hints.v1': '{"firstHands":3,"swipeHint":0,"revealCollapse":0}',
    });
    final container = await pumpSettings(tester, store: store);

    await reveal(tester, find.text(SettingsCopy.runAgain));
    await tester.tap(find.text(SettingsCopy.runAgain));
    await tester.pumpAndSettle();

    expect(container.read(onboardingStoreProvider).hasOnboarded(), isFalse);
    expect(container.read(hintsStoreProvider).load().firstHands, 0);
    expect(find.text('O0'), findsOneWidget);
  });

  testWidgets('?section=data scrolls to and flashes the DATA group (§2.6)', (
    tester,
  ) async {
    await pumpSettings(tester, store: KeyValueStore.memory(), section: 'data');
    // The group is on screen after the reveal…
    expect(find.text(SettingsCopy.dataGroup.toUpperCase()), findsOneWidget);
    expect(find.text(SettingsCopy.reset), findsOneWidget);
    // …and the flash clears itself.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('About is reachable and shows the honesty notes (X1)', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpSettings(
      tester,
      store: KeyValueStore.memory(),
      overrides: [
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );

    await reveal(tester, find.text(SettingsCopy.about));
    await tester.tap(find.text(SettingsCopy.about));
    await tester.pumpAndSettle();

    expect(find.text(AboutCopy.appName), findsOneWidget);
    await reveal(tester, find.text(AboutCopy.goodToKnowHeading));
    expect(
      find.textContaining('play-money trainer', findRichText: true),
      findsOneWidget,
      reason: 'the honesty note survives the port',
    );
    expect(
      find.textContaining('not a solver', findRichText: true),
      findsOneWidget,
      reason: 'grading is stated as heuristics, not solver output',
    );

    await reveal(tester, find.text(AboutCopy.gradingHeading));
    expect(
      find.textContaining('Monte-Carlo', findRichText: true),
      findsWidgets,
      reason: 'post-flop coaching is stated as a heuristic, not a solver',
    );

    await reveal(tester, find.text(AboutCopy.authorLabel));
    await tester.tap(find.text(AboutCopy.authorLabel));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(AboutCopy.authorUrl)]);
  });

  testWidgets('a link that will not open says so instead of failing silently', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      store: KeyValueStore.memory(),
      overrides: [urlOpenerProvider.overrideWithValue((uri) async => false)],
    );

    await reveal(tester, find.text(SettingsCopy.about));
    await tester.tap(find.text(SettingsCopy.about));
    await tester.pumpAndSettle();

    await reveal(tester, find.text(AboutCopy.rateTitle));
    await tester.tap(find.text(AboutCopy.rateTitle));
    await tester.pumpAndSettle();
    expect(find.text(AboutCopy.linkFailed), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
