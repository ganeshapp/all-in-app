/// The quiet daily goal (DESIGN.md §3.3, §5.4, §7.11; docs/port/
/// drill-ux-srs-leaks.md §7).
///
/// One rule, three surfaces: **20 drill answers or 30 hands** meets a day;
/// meeting days back-to-back is the day-streak; every day is a cell of the
/// practice heatmap. The counter is incremented by `answer()` in **every**
/// drill mode, Review included — a review answer is practice even though it
/// never touches the rating (§12 quirk 6).
///
/// The streak never counts down and is never coloured: it is a nudge, not a
/// score. It is computed from today backwards, skipping today when today is
/// not met yet, so opening the app in the morning does not show a broken
/// streak (§3.3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/persistence.dart';
import 'drill_stores.dart';

/// Today's counts, the streak and the heatmap, in one immutable read.
class GoalsState {
  const GoalsState({
    required this.today,
    required this.dayStreak,
    required this.activity,
  });

  static const GoalsState empty = GoalsState(
    today: DailyActivity(),
    dayStreak: 0,
    activity: <String, DailyActivity>{},
  );

  /// Drills and hands recorded today (local day key).
  final DailyActivity today;

  /// Consecutive met days ending today, or yesterday when today is not met.
  final int dayStreak;

  /// The whole `dayKey → counts` map — the §7.11 heatmap reads it.
  final Map<String, DailyActivity> activity;

  /// The Drills "Today" stat: `min(drills, 20)`.
  int get todayDrills => today.drills;

  /// 20 drills **or** 30 hands.
  bool get met => metGoal(today);

  /// The §3.3 bar fill, clamped to 1.
  double get progress {
    final drills = today.drills / kDailyDrillGoal;
    final hands = today.hands / kDailyHandGoal;
    final value = drills > hands ? drills : hands;
    return value > 1 ? 1 : value;
  }
}

/// Reads and writes `allin.goals.v1`.
class GoalsNotifier extends Notifier<GoalsState> {
  @override
  GoalsState build() {
    ref.watch(drillGoalsStoreProvider);
    ref.watch(drillClockProvider);
    return _read();
  }

  GoalsStore get _store => ref.read(drillGoalsStoreProvider);
  int get _nowMs => ref.read(drillClockProvider).nowMs;

  GoalsState _read() {
    final store = _store;
    final now = _nowMs;
    return GoalsState(
      today: store.today(nowMs: now),
      dayStreak: store.streak(nowMs: now),
      activity: store.load(),
    );
  }

  /// Re-reads the map — Play records hands through its own store instance.
  void refresh() => state = _read();

  /// One drill answer, in every mode (§7, §12 quirk 6).
  Future<void> recordDrill() => _record(ActivityKind.drill);

  /// One finished hand. Play owns the call site; this exists so a test (and
  /// any future Home surface) can drive the same rule.
  Future<void> recordHand() => _record(ActivityKind.hand);

  Future<void> _record(ActivityKind kind) async {
    final now = _nowMs;
    await _store.record(kind, nowMs: now);
    state = _read();
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, GoalsState>(
  GoalsNotifier.new,
);
