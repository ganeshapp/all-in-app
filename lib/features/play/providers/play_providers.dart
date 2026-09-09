/// The few services `features/play` needs that the shell's
/// `app/providers/app_providers.dart` does not already publish: the clock, the
/// RNG the engine is seeded from, the equity isolate pool and the three
/// key-value stores only the table writes to.
///
/// Everything else (haptics, the stats and session repositories, the hints
/// store, settings) comes from `app_providers.dart` — one instance per scope.
/// Tests override the four at the top of this file to get a hermetic,
/// deterministic table.
library;

import 'dart:math';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/services/persistence/goals_store.dart';
import 'package:allin/services/persistence/leak_queue_store.dart';
import 'package:allin/services/persistence/notes_repository.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall clock. Overridden with a `FakeClock` in tests.
final playClockProvider = Provider<Clock>((ref) => const SystemClock());

/// The RNG every engine call is threaded through (`createTable`, `startHand`,
/// `decideBot`, the archetype draw and the dial jitter). Seed it in a test and
/// a whole session replays identically.
final playRandomProvider = Provider<Random>((ref) => Random());

/// The one isolate pool (ARCHITECTURE.md). Disposed with the scope.
final equityServiceProvider = Provider<EquityService>((ref) {
  final service = EquityService();
  ref.onDispose(service.dispose);
  return service;
});

/// `allin.table.v1` — seats + ante, the only lobby choices that persist.
final tableOptionsStoreProvider = Provider<TableOptionsStore>(
  (ref) => TableOptionsStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.leaks.v1` — a leak spot is captured for every `mistake` verdict.
final playLeakQueueProvider = Provider<LeakQueueStore>(
  (ref) => LeakQueueStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.goals.v1` — every finished hand records one "hand" activity (§22).
final playGoalsStoreProvider = Provider<GoalsStore>(
  (ref) => GoalsStore(ref.watch(keyValueStoreProvider)),
);

/// Bumped every time a session is written to the `sessions` table, so the
/// lobby's "Recent sessions" list (§4.1) refetches without every call site
/// having to invalidate it by hand. It lives here rather than beside
/// `recentSessionsProvider` so `SessionNotifier` can bump it without
/// importing the lobby.
class SessionsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final sessionsRevisionProvider =
    NotifierProvider<SessionsRevisionNotifier, int>(
      SessionsRevisionNotifier.new,
    );

/// P2's selected segment — "remembered for the session" (§4.11).
class SessionSheetSegmentNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final sessionSheetSegmentProvider =
    NotifierProvider<SessionSheetSegmentNotifier, int>(
      SessionSheetSegmentNotifier.new,
    );

/// `allin.notes.v1` — the hand notes P2's ✎ writes (§4.11, §7.6).
final playNotesProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(keyValueStoreProvider)),
);
