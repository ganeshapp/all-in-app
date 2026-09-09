/// The storage adapters and the clock the Drills feature reads
/// (DESIGN.md §16.3 `features/drills/providers/`, §16.4).
///
/// Every store is a thin, already-ported object from `services/persistence`;
/// nothing here does I/O itself. They live in their own file so the notifiers
/// below can be tested by overriding one provider
/// ([keyValueStoreProvider]) and nothing else.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../services/clock.dart';
import '../../../services/persistence.dart';

/// Wall clock. Tests override this with a [FakeClock] so "due", "Next due"
/// and the day-streak are reproducible.
final drillClockProvider = Provider<Clock>((ref) => Clock.system);

/// `allin.drills.v1` (rating / solved / correct / streak / best) plus the
/// `allin.drill_answers.v1` ring behind the D3 sparkline.
final drillStoreProvider = Provider<DrillStore>(
  (ref) => DrillStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.leaks.v1` — the coach's flagged spots, written by Play and by the
/// hand-history importer, served by Review mode.
final drillLeakQueueProvider = Provider<LeakQueueStore>(
  (ref) => LeakQueueStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.review.v1` — the missed-drill cards.
final drillReviewQueueProvider = Provider<ReviewQueueStore>(
  (ref) => ReviewQueueStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.goals.v1` — the daily goal, the quiet day-streak and the activity
/// map (§3.3, §5.4, §7.11).
final drillGoalsStoreProvider = Provider<GoalsStore>(
  (ref) => GoalsStore(ref.watch(keyValueStoreProvider)),
);

/// How many times the §5.2 "swipe to replay the action" hint has been shown.
///
/// *(mobile addition)* It gets its own key rather than a field of
/// `allin.hints.v1`, whose `swipeHint` counter belongs to the table's
/// hero-strip mark (§4.2) — two different hints must not retire each other.
const String kDrillSwipeHintKey = 'allin.hints.drill_swipe.v1';

/// The hint stops after this many spots (§5.2).
const int kDrillSwipeHintLimit = 5;

/// Reads and bumps [kDrillSwipeHintKey].
class DrillHintStore {
  const DrillHintStore(this._store);

  final KeyValueStore _store;

  int shown() {
    final v = _store.getJson(kDrillSwipeHintKey);
    return v is num ? v.toInt() : 0;
  }

  bool get owed => shown() < kDrillSwipeHintLimit;

  Future<void> markShown() async {
    await _store.setJson(kDrillSwipeHintKey, shown() + 1);
  }
}

final drillHintStoreProvider = Provider<DrillHintStore>(
  (ref) => DrillHintStore(ref.watch(keyValueStoreProvider)),
);
