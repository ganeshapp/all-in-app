/// D5 · Placement test (DESIGN.md §5.8): eight questions one per screen,
/// auto-advance, the seeded rating, and the §2.5 blocked back on Q1.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/drills/content/placement_test.dart';
import 'package:allin/features/drills/screens/placement_screen.dart';
import 'package:allin/features/drills/widgets/placement_pages.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _pumpPlacement(
  WidgetTester tester, {
  required KeyValueStore store,
  RecordingHapticDriver? haptics,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/placement',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('HOME')),
      GoRoute(path: '/placement', builder: (_, _) => const PlacementScreen()),
      GoRoute(
        path: '/study/lesson/:id',
        builder: (_, state) => Text('LESSON ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  if (reducedMotion) {
    await SettingsStore(
      store,
    ).save(SettingsStore(store).load().copyWith(reducedMotion: true));
  }

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        hapticDriverProvider.overrideWithValue(
          haptics ?? RecordingHapticDriver(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AllInAppTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Answers question [i]; [correct] picks the verbatim right option.
Future<void> _answer(
  WidgetTester tester,
  int i, {
  required bool correct,
}) async {
  final question = kPlacementQuestions[i];
  final label =
      correct
          ? question.answer
          : question.options.firstWhere((o) => o != question.answer);
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(PlacementCopy.advanceDelay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first question renders with its eyebrow, options and '
      'footer', (tester) async {
    await _pumpPlacement(tester, store: KeyValueStore.memory());

    expect(find.text(PlacementCopy.progress(0).toUpperCase()), findsOneWidget);
    expect(find.text(kPlacementQuestions.first.question), findsOneWidget);
    for (final option in kPlacementQuestions.first.options) {
      expect(find.text(option), findsOneWidget);
    }
    expect(find.text(PlacementCopy.footer), findsOneWidget);
    expect(find.byType(PlacementProgress), findsOneWidget);
  });

  testWidgets('a tap tints, then auto-advances to the next question', (
    tester,
  ) async {
    await _pumpPlacement(tester, store: KeyValueStore.memory());
    await tester.tap(find.text(kPlacementQuestions.first.answer));
    await tester.pump();

    // Still on Q1 during the 350 ms tint.
    expect(find.text(kPlacementQuestions.first.question), findsOneWidget);
    await tester.pump(PlacementCopy.advanceDelay);
    await tester.pumpAndSettle();

    expect(find.text(kPlacementQuestions[1].question), findsOneWidget);
    expect(find.text(PlacementCopy.progress(1).toUpperCase()), findsOneWidget);
  });

  testWidgets('a perfect run seeds the rating to 1250 and offers the advanced '
      'lesson', (tester) async {
    final store = KeyValueStore.memory();
    await _pumpPlacement(tester, store: store);
    for (var i = 0; i < kPlacementQuestions.length; i++) {
      await _answer(tester, i, correct: true);
    }

    final result = PlacementResult.forScore(8);
    expect(find.text(result.headline), findsOneWidget);
    expect(find.text(result.body(8)), findsOneWidget);
    expect(find.text(PlacementCopy.takeMeThere), findsOneWidget);
    expect(find.text(PlacementCopy.startPlaying), findsOneWidget);
    expect(DrillStore(store).load().rating, 1250);
    expect(OnboardingStore(store).hasOnboarded(), isTrue);

    await tester.tap(find.text(PlacementCopy.takeMeThere));
    await tester.pumpAndSettle();
    expect(find.text('LESSON threebet-pots'), findsOneWidget);
  });

  testWidgets('a blank run seeds 900 and keeps the other counters', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await DrillStore(store).save(
      const DrillState(
        rating: 1000,
        solved: 30,
        correct: 21,
        streak: 4,
        best: 11,
      ),
    );
    await _pumpPlacement(tester, store: store);
    for (var i = 0; i < kPlacementQuestions.length; i++) {
      await _answer(tester, i, correct: false);
    }

    expect(find.text('Starting fresh — perfect.'), findsOneWidget);
    final saved = DrillStore(store).load();
    expect(saved.rating, 900);
    expect(saved.solved, 30);
    expect(saved.correct, 21);
    expect(saved.streak, 4);
    expect(saved.best, 11);
  });

  testWidgets('the middle band seeds 1050', (tester) async {
    final store = KeyValueStore.memory();
    await _pumpPlacement(tester, store: store);
    for (var i = 0; i < kPlacementQuestions.length; i++) {
      await _answer(tester, i, correct: i < 4);
    }

    expect(find.text('You know the basics.'), findsOneWidget);
    expect(DrillStore(store).load().rating, 1050);
  });

  testWidgets('"Start playing" leaves for Home', (tester) async {
    final store = KeyValueStore.memory();
    await _pumpPlacement(tester, store: store);
    for (var i = 0; i < kPlacementQuestions.length; i++) {
      await _answer(tester, i, correct: true);
    }
    await tester.tap(find.text(PlacementCopy.startPlaying));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('✕ mid-quiz marks the tour seen and never touches the rating', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await _pumpPlacement(tester, store: store);
    await _answer(tester, 0, correct: true);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(OnboardingStore(store).hasOnboarded(), isTrue);
    expect(
      store.getJson(kDrillStateKey),
      isNull,
      reason: 'the rating is untouched by an abandoned quiz',
    );
  });

  testWidgets('system back steps to the previous question, and is refused on '
      'Q1 with a haptic', (tester) async {
    final haptics = RecordingHapticDriver();
    await _pumpPlacement(
      tester,
      store: KeyValueStore.memory(),
      haptics: haptics,
    );
    await _answer(tester, 0, correct: true);
    expect(find.text(kPlacementQuestions[1].question), findsOneWidget);

    await _systemBack(tester);
    expect(find.text(kPlacementQuestions.first.question), findsOneWidget);
    expect(haptics.played, isNot(contains(HapticPattern.selection)));

    // Q1: refused — a shake plus the haptic, and the screen stays put.
    await _systemBack(tester);
    expect(find.text(kPlacementQuestions.first.question), findsOneWidget);
    expect(haptics.played, contains(HapticPattern.selection));
  });

  testWidgets('under reduced motion the refusal is the haptic alone', (
    tester,
  ) async {
    final haptics = RecordingHapticDriver();
    await _pumpPlacement(
      tester,
      store: KeyValueStore.memory(),
      haptics: haptics,
      reducedMotion: true,
    );
    await _systemBack(tester);
    await tester.pump(const Duration(milliseconds: 60));

    // No shake: the page content has not moved (§11 "a refusal is never
    // motion-only" — and never motion-first under reduced motion).
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(PlacementScreen),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getTranslation().x, 0);
    expect(haptics.played, contains(HapticPattern.selection));
    await tester.pumpAndSettle();
  });

  testWidgets('every question renders at 360 and at 1.3× text', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (var i = 0; i < kPlacementQuestions.length; i++) {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AllInAppTheme.dark(),
            home: Builder(
              builder:
                  (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: Scaffold(
                      body: PlacementQuestionPage(
                        index: i,
                        question: kPlacementQuestions[i],
                        options: kPlacementQuestions[i].options,
                        onPick: (_) {},
                      ),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}
