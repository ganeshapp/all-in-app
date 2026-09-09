/// The two spaced-repetition queues behind Review mode (DESIGN.md §5.5;
/// docs/port/drill-ux-srs-leaks.md §3, §4, §9).
///
/// [LeakNotifier] owns `allin.leaks.v1` — spots the EV coach flagged in play
/// and the hand-history importer flagged on import. [ReviewNotifier] owns
/// `allin.review.v1` — whole puzzles the user missed in a practice mode. They
/// are twins: one scheduler ([reviewSrs]), one due test ([isDue]), one
/// retirement rule ([isGraduated] after [kRetireReps] **spaced** successes).
///
/// Review mode serves a uniform pick over the union of both due lists (§6.4),
/// which is why the counts live here and not in the drill notifier: the mode
/// chip's pill, the Drills tab badge and the empty state all read the same
/// two lists, and they must update the instant a graded card is rescheduled.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine.dart';
import '../../../services/persistence.dart';
import 'drill_stores.dart';

/* ------------------------------------------------------------ leak queue */

/// `allin.leaks.v1`, newest first.
class LeakNotifier extends Notifier<List<LeakSpot>> {
  @override
  List<LeakSpot> build() => ref.watch(drillLeakQueueProvider).load();

  LeakQueueStore get _store => ref.read(drillLeakQueueProvider);

  /// Re-reads the queue — Play and the importer write it behind our back.
  void refresh() => state = _store.load();

  /// Spots whose schedule has come due (a spot with no schedule is due).
  List<LeakSpot> due(int nowMs) =>
      state.where((s) => isDue(s.srs, nowMs)).toList();

  /// The earliest not-yet-due schedule, or null.
  int? nextDueAt(int nowMs) {
    int? best;
    for (final s in state) {
      final srs = s.srs;
      if (srs == null || srs.due <= nowMs) continue;
      if (best == null || srs.due < best) best = srs.due;
    }
    return best;
  }

  /// Applies one review. Returns the post-review schedule so the feedback
  /// header can print §5.5's line even when the card just retired.
  Future<SrsState> review(String id, bool correct, {required int nowMs}) async {
    SrsState? current;
    for (final s in state) {
      if (s.id == id) {
        current = s.srs;
        break;
      }
    }
    final next = reviewSrs(current ?? newSrs(nowMs), correct, nowMs);
    state = await _store.review(id, correct, nowMs: nowMs);
    return next;
  }
}

final leakQueueProvider = NotifierProvider<LeakNotifier, List<LeakSpot>>(
  LeakNotifier.new,
);

/* ---------------------------------------------------------- review queue */

/// `allin.review.v1`, newest first.
class ReviewNotifier extends Notifier<List<ReviewCard>> {
  @override
  List<ReviewCard> build() => ref.watch(drillReviewQueueProvider).load();

  ReviewQueueStore get _store => ref.read(drillReviewQueueProvider);

  void refresh() => state = _store.load();

  List<ReviewCard> due(int nowMs) =>
      state.where((c) => isDue(c.srs, nowMs)).toList();

  int? nextDueAt(int nowMs) {
    int? best;
    for (final c in state) {
      if (c.srs.due <= nowMs) continue;
      if (best == null || c.srs.due < best) best = c.srs.due;
    }
    return best;
  }

  /// One card per spot identity; a spot already queued keeps its schedule.
  Future<void> addMiss(Puzzle puzzle, {required int nowMs}) async {
    state = await _store.addMiss(puzzle, nowMs: nowMs);
  }

  Future<SrsState> review(String id, bool correct, {required int nowMs}) async {
    SrsState? current;
    for (final c in state) {
      if (c.id == id) {
        current = c.srs;
        break;
      }
    }
    final next = reviewSrs(current ?? newSrs(nowMs), correct, nowMs);
    state = await _store.review(id, correct, nowMs: nowMs);
    return next;
  }
}

final reviewQueueProvider = NotifierProvider<ReviewNotifier, List<ReviewCard>>(
  ReviewNotifier.new,
);

/* --------------------------------------------------------------- derived */

/// What Review mode is holding right now.
class ReviewQueueCounts {
  const ReviewQueueCounts({
    required this.due,
    required this.total,
    required this.nextDueAt,
  });

  /// Due leaks + due cards — the chip pill and the tab badge.
  final int due;

  /// Every scheduled spot, due or not — the empty state's "All {n} …".
  final int total;

  /// Earliest not-yet-due schedule (epoch ms), or null.
  final int? nextDueAt;

  /// "Review · {due} due · {scheduled} scheduled" (§5.1).
  int get scheduled => total - due;
}

/// Recomputed whenever either queue changes, so the pill count stays live
/// while an answered card is still on screen (§12 quirk 1).
final reviewCountsProvider = Provider<ReviewQueueCounts>((ref) {
  final now = ref.watch(drillClockProvider).nowMs;
  final leaks = ref.watch(leakQueueProvider);
  final cards = ref.watch(reviewQueueProvider);
  final dueLeaks = leaks.where((s) => isDue(s.srs, now)).length;
  final dueCards = cards.where((c) => isDue(c.srs, now)).length;

  int? next;
  for (final due in [
    ...leaks.map((s) => s.srs?.due).nonNulls,
    ...cards.map((c) => c.srs.due),
  ]) {
    if (due <= now) continue;
    if (next == null || due < next) next = due;
  }

  return ReviewQueueCounts(
    due: dueLeaks + dueCards,
    total: leaks.length + cards.length,
    nextDueAt: next,
  );
});

/// The Drills tab badge (§5.4). `app_providers.drillsDueBadgeProvider`
/// delegates here.
final drillsDueCountProvider = Provider<int>(
  (ref) => ref.watch(reviewCountsProvider).due,
);

/* ------------------------------------------------------------ the picker */

/// One due entry of the union, already resolved to a playable puzzle.
class DueSpot {
  const DueSpot({required this.puzzle, this.leakId, this.reviewId});

  final Puzzle puzzle;

  /// Set when the spot came from `allin.leaks.v1`.
  final String? leakId;

  /// Set when it came from `allin.review.v1`.
  final String? reviewId;
}

/// §6.4's uniform pick over both due queues, in queue order (leaks first).
/// Returns null when nothing is due.
DueSpot? pickDueSpot({
  required List<LeakSpot> dueLeaks,
  required List<ReviewCard> dueCards,
  required Random rng,
}) {
  final total = dueLeaks.length + dueCards.length;
  if (total == 0) return null;
  final pick = rng.nextInt(total);
  if (pick < dueLeaks.length) {
    final spot = dueLeaks[pick];
    return DueSpot(puzzle: puzzleFromLeak(spot), leakId: spot.id);
  }
  final card = dueCards[pick - dueLeaks.length];
  return DueSpot(puzzle: card.puzzle, reviewId: card.id);
}
