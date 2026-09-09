/// The few things Home owns outright: its clock and the derived goal card.
///
/// Everything else on this screen is composed from the other features'
/// providers (DESIGN.md §3.2 is a *view* over live state, never a second copy
/// of it): the review queues from `features/drills`, the daily goal from
/// `goalsProvider`, the course from `features/study`, the session from
/// `features/play` and the lifetime numbers from `features/stats`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/clock.dart';
import '../../../services/persistence/goals_store.dart';
import '../../drills/providers/goals_provider.dart';
import '../../play/providers/lobby_providers.dart';
import '../home_copy.dart';

/// Wall clock for the greeting, the weekday line and "today". Tests override
/// it with a [FakeClock] (alongside `drillClockProvider`, which the goal and
/// the queues read).
final homeClockProvider = Provider<Clock>((ref) => Clock.system);

/// The §3.3 goal card, already resolved to the four strings it renders.
class HomeGoal {
  const HomeGoal({
    required this.progress,
    required this.count,
    required this.caption,
    required this.met,
    required this.streak,
  });

  /// 0–1, `max(drills / 20, hands / 30)` clamped (`GoalsState.progress`).
  final double progress;

  /// "8 of 20" — whichever half is closer to completion (§3.3).
  final String count;

  /// The caption under the bar, matching [count].
  final String caption;

  final bool met;

  /// The quiet day-streak; 0 hides the fragment in the header line.
  final int streak;
}

/// Derived, so a drill answer or a finished hand updates the card live.
final homeGoalProvider = Provider<HomeGoal>((ref) {
  final goals = ref.watch(goalsProvider);
  final today = goals.today;
  final drills = today.drills / kDailyDrillGoal;
  final hands = today.hands / kDailyHandGoal;
  // §3.3: "whichever is closer to completion"; drills win a tie, which is also
  // the first-run reading (0 and 0).
  final showDrills = drills >= hands;
  return HomeGoal(
    progress: goals.progress,
    count:
        showDrills
            ? HomeCopy.goalCount(today.drills, kDailyDrillGoal)
            : HomeCopy.goalCount(today.hands, kDailyHandGoal),
    caption:
        showDrills ? HomeCopy.goalCaptionDrills : HomeCopy.goalCaptionHands,
    met: goals.met,
    streak: goals.dayStreak,
  );
});

/// §3.5's "Last session" row — the newest **ended** session, or null while
/// none has ended (the row is hidden then, §3.6).
@immutable
class HomeLastSession {
  const HomeLastSession({
    required this.id,
    required this.line,
    required this.netBb,
    this.costliest,
  });

  /// The `sessions` row id — the read-only P10 at `/home/session/:id`.
  final int? id;

  /// "+12.5 bb · 41 hands · 2 mistakes".
  final String line;

  /// The signed result the line opens with, carried as a number so the card
  /// colours it through the one money helper (§13). The card used to sniff a
  /// leading "−" off [line], which painted a flat "+0.0 bb" session in the
  /// win green.
  final double netBb;

  /// "Costliest: a river call (−3.1 bb)", or null when nothing was flagged.
  final String? costliest;
}

final homeLastSessionProvider = Provider<HomeLastSession?>((ref) {
  final rows = ref.watch(recentSessionsProvider).valueOrNull;
  if (rows == null || rows.isEmpty) return null;
  final row = rows.first;
  final counters = row.summary?['counters'];
  String? costliest;
  if (counters is Map) {
    final label = counters['worstEvLabel'];
    final ev = (counters['worstEvBb'] as num?)?.toDouble();
    if (label is String && label.isNotEmpty && ev != null && ev < 0) {
      costliest = HomeCopy.lastSessionCostliest(label, ev);
    }
  }
  return HomeLastSession(
    id: row.id,
    line: HomeCopy.lastSessionLine(
      netBb: row.netBb,
      hands: row.hands,
      mistakes: row.mistakes,
    ),
    netBb: row.netBb,
    costliest: costliest,
  );
});
