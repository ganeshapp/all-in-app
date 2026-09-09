/// Shared scaffolding for the Home tests: a hermetic container (in-memory
/// store, fixed clock, no isolates), seed helpers for the state the plan reads
/// out of other features, and a pump that runs the real router at `/home`.
library;

import 'dart:math';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/router.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/drills/providers/drill_generator.dart';
import 'package:allin/features/drills/providers/drill_stores.dart';
import 'package:allin/features/home/providers/home_providers.dart';
import 'package:allin/features/play/providers/lobby_providers.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The three supported widths (§4.2.3, §13).
const Size phone360 = Size(360, 780);
const Size phone390 = Size(390, 844);
const Size phone430 = Size(430, 932);

/// A Wednesday, 19:30 local — "Good evening" and a stable day key.
DateTime homeNow() => DateTime(2026, 9, 9, 19, 30);

/// A container whose every source of nondeterminism is pinned. [sessions] is
/// what `recentSessionsProvider` resolves to (the ended-session table is
/// sqflite-only and there is no database in a widget test).
ProviderContainer homeContainer({
  KeyValueStore? store,
  Clock? clock,
  List<SessionRecord> sessions = const [],
  List<Override> overrides = const [],
}) {
  final kv = store ?? KeyValueStore.memory();
  final fixed = clock ?? FakeClock(homeNow());
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      appDatabaseProvider.overrideWithValue(null),
      homeClockProvider.overrideWithValue(fixed),
      drillClockProvider.overrideWithValue(fixed),
      playClockProvider.overrideWithValue(fixed),
      playRandomProvider.overrideWithValue(Random(7)),
      hapticDriverProvider.overrideWithValue(RecordingHapticDriver()),
      equityServiceProvider.overrideWith(
        (ref) => EquityService.inProcess(timeout: const Duration(seconds: 5)),
      ),
      drillGeneratorProvider.overrideWithValue(
        InProcessDrillGenerator(seed: 11),
      ),
      recentSessionsProvider.overrideWith((ref) async => sessions),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps the real router at [location] with [container] as the scope, and
/// returns the router so a test can read the location a card navigated to.
Future<GoRouter> pumpHome(
  WidgetTester tester, {
  required ProviderContainer container,
  String location = '/home',
  Size size = phone390,
  double textScale = 1.0,
  bool dark = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = createRouter(initialLocation: location);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AllInAppTheme.light(),
        darkTheme: AllInAppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

/// The router's current location. `go` switches branches, so this is what the
/// plan cards' navigation asserts on; anything *pushed* is asserted on the
/// widget tree instead (go_router still reports the declarative location
/// underneath an imperative push).
String locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/* ------------------------------------------------------------- seeding */

/// [n] drill answers and [hands] played hands recorded today.
Future<void> seedGoals(
  KeyValueStore store, {
  int drills = 0,
  int hands = 0,
  DateTime? day,
}) async {
  final goals = GoalsStore(store);
  final now = (day ?? homeNow()).millisecondsSinceEpoch;
  for (var i = 0; i < drills; i++) {
    await goals.record(ActivityKind.drill, nowMs: now);
  }
  for (var i = 0; i < hands; i++) {
    await goals.record(ActivityKind.hand, nowMs: now);
  }
}

/// A due leak spot. `best: DrillAction.fold` makes it one of §3.2's
/// "coach-flagged calls".
LeakSpot leakSpot({
  required String id,
  DrillAction best = DrillAction.call,
  int? nowMs,
}) => LeakSpot(
  id: id,
  street: Street.flop,
  heroPos: Position.bb,
  hole: const ['Kh', 'Qh'],
  board: const ['As', '7d', '2c'],
  pot: 24,
  toCall: 8,
  bb: 1,
  oppActive: const [Position.co],
  options: const [
    DrillOption(action: DrillAction.fold, label: 'Fold'),
    DrillOption(action: DrillAction.call, label: 'Call 8 bb', amount: 8),
  ],
  best: best,
  rationale: 'Test spot.',
  equity: 0.33,
  potOdds: 0.25,
  ts: nowMs ?? homeNow().millisecondsSinceEpoch,
);

/// Adds [spots] to `allin.leaks.v1`, all due now.
Future<void> seedLeaks(KeyValueStore store, List<LeakSpot> spots) async {
  final queue = LeakQueueStore(store);
  for (final spot in spots) {
    await queue.add(spot, nowMs: homeNow().millisecondsSinceEpoch);
  }
}

/// A paused session with [hands] hands and [netChips] chips of result. The
/// table half is deliberately absent: §4.14 restores the roster and the
/// counters, which is all Home's Resume card reads.
Future<void> seedSession(
  KeyValueStore store, {
  int hands = 12,
  int netChips = 90,
  int seats = 6,
}) async {
  final table = createTable(
    GameConfig(
      seats: seats,
      startingStack: kStartingStack,
      smallBlind: kSmallBlind,
      bigBlind: kBigBlind,
    ),
    rng: Random(3),
  );
  final repository = SessionRepository(database: AppDatabase(), store: store);
  await repository.saveSnapshot(
    SessionSnapshot(
      options: TableOptions(seats: seats),
      players: table.players,
      session: {
        'counters': SessionCounters(hands: hands, netChips: netChips).toJson(),
        'startedAt': homeNow().millisecondsSinceEpoch,
        'history': const [],
      },
      savedAt: homeNow().millisecondsSinceEpoch,
    ),
  );
}

/// An ended session for the "Last session" row and the §3.4 debrief line.
SessionRecord endedSession({
  int id = 4,
  int hands = 41,
  double netBb = 12.5,
  int mistakes = 2,
  String? worstLabel = 'river call',
  double worstEvBb = -3.1,
}) => SessionRecord(
  id: id,
  startedAt: homeNow().millisecondsSinceEpoch - 3600000,
  endedAt: homeNow().millisecondsSinceEpoch - 600000,
  seats: 6,
  hands: hands,
  netBb: netBb,
  bb100: hands == 0 ? 0 : netBb / hands * 100,
  mistakes: mistakes,
  summary: {
    'counters': {
      'hands': hands,
      'flaggedDecisions': mistakes,
      if (worstLabel != null) 'worstEvLabel': worstLabel,
      if (worstLabel != null) 'worstEvBb': worstEvBb,
    },
  },
);

/// Coached decisions for `leaksFromDecisions` — [folds] flagged folds among
/// [total] decisions.
Future<void> seedDecisions(
  KeyValueStore store, {
  required int total,
  int folds = 0,
  int calls = 0,
}) async {
  final repository = StatsRepository(database: AppDatabase(), store: store);
  final now = homeNow().millisecondsSinceEpoch;
  for (var i = 0; i < total; i++) {
    final isFold = i < folds;
    final isCall = !isFold && i < folds + calls;
    await repository.persistDecision(
      DecisionRecord(
        verdict: isFold || isCall ? 'mistake' : 'great',
        action:
            isFold
                ? 'fold'
                : isCall
                ? 'call'
                : 'raise',
        equity: 0.4,
        potOdds: 0.25,
        evBb: isFold || isCall ? -1.5 : 0.8,
        street: 'flop',
        villainArchetype: 'TAG',
        position: 'BB',
        ts: now - i * 1000,
      ),
    );
  }
}

/// Scrolls [finder] into view. Home always scrolls (§3.1: the wireframe sums
/// to ~963 pt against a 671 pt viewport), so anything below the coach card has
/// to be revealed before it can be tapped — a plain `scrollUntilVisible`
/// leaves the widget built but off-screen, so `ensureVisible` follows it.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120, maxScrolls: 30);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// The location of the last *imperative* push, or null when nothing was
/// pushed. `currentConfiguration.uri` keeps reporting the declarative location
/// under a push, so the pushed match is where the real target lives (§16.1's
/// duplicated P10/P11 hosts are all pushes).
String? pushedLocation(GoRouter router) {
  final last = router.routerDelegate.currentConfiguration.last;
  return last is ImperativeRouteMatch ? last.matches.uri.toString() : null;
}
