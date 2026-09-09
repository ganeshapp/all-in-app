/// Shared fixtures for the Drills tests: a deterministic generator, a fixed
/// spot, and a container/pump helper wired to an in-memory key-value store.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/drills/providers/drill_generator.dart';
import 'package:allin/features/drills/providers/drill_stores.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A generator that hands back whatever the test set, without an isolate.
class FakeDrillGenerator extends DrillGenerator {
  FakeDrillGenerator(this.puzzle);

  /// Called once per draw; return the spot the test wants.
  Puzzle Function(DrillGenRequest request) puzzle;

  final List<DrillGenRequest> requests = <DrillGenRequest>[];

  /// Set to throw the §14 "couldn't be dealt" state.
  bool fail = false;

  @override
  Future<Puzzle> generate(DrillGenRequest request) async {
    requests.add(request);
    if (fail) throw StateError('generator down');
    return puzzle(request);
  }
}

/// A pot-odds spot with every optional field populated, so D1 can render all
/// three layers, the outcomes box, the grading matrix and the lesson link.
Puzzle testPuzzle({
  int id = 1,
  PuzzleKind kind = PuzzleKind.postflopBet,
  PuzzleSource source = PuzzleSource.heuristic,
  Street street = Street.flop,
  Position heroPos = Position.bb,
  List<String> hole = const ['Kh', 'Qh'],
  List<String> board = const ['As', '7d', '2c'],
  double pot = 24,
  double toCall = 8,
  double? equity = 0.33,
  double? potOdds = 0.25,
  int difficulty = 2,
  List<String>? gradeRange = const ['AKs', 'QQ', 'JJ'],
  String? gradeRangeTitle = 'CO opening range — 100 bb baseline',
  String? lessonId = 'pot-odds',
  String? lessonTitle = 'Pot Odds & EV',
  bool? icm,
  List<DrillOption>? options,
  DrillAction best = DrillAction.call,
  List<DrillAction>? accept,
  String rationale =
      "You're getting 3:1 and this hand wins about 1 time in 3 — the call "
          'makes money.',
  List<DrillFrame>? frames,
}) => Puzzle(
  id: id,
  kind: kind,
  source: source,
  street: street,
  heroPos: heroPos,
  hole: hole,
  handLabel: cardsToLabel(hole[0], hole[1]),
  board: board,
  pot: pot,
  toCall: toCall,
  bb: 1,
  seats: [
    for (final p in kDrillOrder)
      DrillSeatView(
        pos: p,
        isHero: p == heroPos,
        folded: p != heroPos && p != Position.co,
        active: p == Position.co,
      ),
  ],
  frames:
      frames ??
      [
        DrillFrame(
          text: 'Blinds posted (0.5/1 bb).',
          street: Street.preflop,
          board: const [],
          pot: 1.5,
        ),
        DrillFrame(
          text: 'CO raises to 3 bb.',
          street: street,
          board: board,
          pot: pot - toCall,
        ),
        DrillFrame(
          text: 'CO bets 5 bb.',
          street: street,
          board: board,
          pot: pot,
        ),
      ],
  options:
      options ??
      const [
        DrillOption(action: DrillAction.fold, label: 'Fold'),
        DrillOption(action: DrillAction.call, label: 'Call 8 bb', amount: 8),
        DrillOption(
          action: DrillAction.raise,
          label: 'Raise to 24 bb',
          amount: 24,
        ),
      ],
  best: best,
  accept: accept ?? [best],
  rationale: rationale,
  equity: equity,
  potOdds: potOdds,
  difficulty: difficulty,
  gradeRange: gradeRange,
  gradeRangeTitle: gradeRangeTitle,
  lessonId: lessonId,
  lessonTitle: lessonTitle,
  icm: icm,
);

/// A container with an in-memory store, a fake clock and no real haptics.
ProviderContainer drillContainer({
  KeyValueStore? store,
  Clock? clock,
  DrillGenerator? generator,
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store ?? KeyValueStore.memory()),
      drillClockProvider.overrideWithValue(clock ?? Clock.system),
      hapticDriverProvider.overrideWithValue(RecordingHapticDriver()),
      if (generator != null)
        drillGeneratorProvider.overrideWithValue(generator),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps the drills screen at [size] with the given overrides.
Future<void> pumpDrills(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = true,
  // The tab scaffold hands every branch a bottom padding for the nav bar +
  // session pill (§2.1); a fixed-height screen must budget around it.
  double bottomInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // A fresh container per pump: a loop over sizes/themes must not inherit
      // the previous iteration's answered session.
      key: UniqueKey(),
      overrides: [
        hapticDriverProvider.overrideWithValue(RecordingHapticDriver()),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AllInAppTheme.dark() : AllInAppTheme.light(),
        home: Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  padding: MediaQuery.paddingOf(
                    context,
                  ).copyWith(bottom: bottomInset),
                ),
                child: child,
              ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Let the §5.2 swipe hint retire so no timer outlives the test.
  await tester.pump(const Duration(milliseconds: 1400));
}
