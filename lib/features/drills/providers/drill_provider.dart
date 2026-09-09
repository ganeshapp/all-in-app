/// The drill session state machine (DESIGN.md §5; docs/port/
/// drill-ux-srs-leaks.md §6, drills-charts-icm.md §4).
///
/// Two notifiers, deliberately split:
///
/// * [DrillScoreboardNotifier] owns the **persisted** five numbers of
///   `allin.drills.v1` — rating, solved, correct, streak, best. The placement
///   test (D5) writes the rating through it without ever dealing a spot.
/// * [DrillNotifier] owns the **session** — mode, current puzzle, replay
///   index, answer, grade, rating delta and the "Drill 5 similar" focus.
///   None of that is persisted: every launch starts in Mixed on a fresh,
///   *non-adaptive* `generatePuzzle()` (§6.2, §12 quirk 14).
///
/// The engine stays pure: this file never mutates a [Puzzle], it orchestrates
/// `gradePuzzle`, `eloDelta`, the two SRS queues and the daily goal.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../engine/engine.dart';
import '../../../services/persistence.dart';
import '../content/drill_copy.dart';
import 'drill_generator.dart';
import 'drill_stores.dart';
import 'goals_provider.dart';
import 'review_provider.dart';

/* ------------------------------------------------------------ scoreboard */

/// `allin.drills.v1` — the only persisted drill numbers.
class DrillScoreboardNotifier extends Notifier<DrillState> {
  @override
  DrillState build() => ref.watch(drillStoreProvider).load();

  DrillStore get _store => ref.read(drillStoreProvider);

  /// Applies one practice answer: Elo step, streak, best, counters. Returns
  /// the rating delta so the feedback header can print it (§5.3).
  Future<int> recordPractice({
    required int difficulty,
    required bool correct,
  }) async {
    final rating = state.rating.round();
    final delta = eloDelta(rating, difficulty, correct);
    final streak = correct ? state.streak + 1 : 0;
    final next = state.copyWith(
      rating: applyRatingDelta(rating, delta).toDouble(),
      streak: streak,
      best: streak > state.best ? streak : state.best,
      solved: state.solved + 1,
      correct: state.correct + (correct ? 1 : 0),
    );
    state = next;
    await _store.save(next);
    return delta;
  }

  /// D5's `seedRating` — the rating only; solved / correct / streak / best
  /// survive (§6.10).
  Future<void> seedRating(double rating) async {
    state = await _store.seedRating(rating);
  }

  /// `round(correct / solved × 100)`, 0 when nothing is solved (§5.4).
  int get accuracy =>
      state.solved > 0 ? (state.correct / state.solved * 100).round() : 0;
}

final drillScoreboardProvider =
    NotifierProvider<DrillScoreboardNotifier, DrillState>(
      DrillScoreboardNotifier.new,
    );

/// "{acc} %" for the stats strip.
final drillAccuracyProvider = Provider<int>((ref) {
  final s = ref.watch(drillScoreboardProvider);
  return s.solved > 0 ? (s.correct / s.solved * 100).round() : 0;
});

/* --------------------------------------------------------------- session */

/// What D0 is showing.
enum DrillPhase {
  /// Dealing the first (or next) spot — §14's loading row.
  loading,

  /// A spot is on screen.
  ready,

  /// Review mode with nothing due — §5.5's empty state.
  empty,

  /// Generation threw; the screen offers "Try again".
  error,
}

/// The whole session, immutable.
class DrillSession {
  const DrillSession({
    this.phase = DrillPhase.loading,
    this.mode = DrillMode.mixed,
    this.puzzle,
    this.leakId,
    this.reviewId,
    this.navIndex = 0,
    this.answered,
    this.result,
    this.ratingDelta = 0,
    this.scheduleLine,
    this.focusKind,
    this.focusLeft = 0,
    this.answerToken = 0,
    this.setSize,
    this.setAnswered = 0,
    this.setCorrect = 0,
    this.setDelta = 0,
    this.touchingTable = false,
    this.showSwipeHint = false,
  });

  final DrillPhase phase;
  final DrillMode mode;

  /// Null only before the first deal and in [DrillPhase.empty].
  final Puzzle? puzzle;

  /// The leak-queue id this spot came from (Review mode only).
  final String? leakId;

  /// The review-queue id this spot came from (Review mode only).
  final String? reviewId;

  /// The replay frame on screen; the spot opens on the decision frame.
  final int navIndex;

  /// The chosen action, or null while unanswered.
  final DrillAction? answered;
  final GradeResult? result;

  /// Practice modes only; Review always shows 0 (§6.6).
  final int ratingDelta;

  /// §5.5's schedule line after a Review answer.
  final String? scheduleLine;

  /// "Drill 5 similar" (§6.8).
  final PuzzleKind? focusKind;
  final int focusLeft;

  /// Bumped once per answer — drives the strip's roll and pulse (§11).
  final int answerToken;

  /// Bounded set from a Home quick-set card (§5.1); null in the endless loop.
  final int? setSize;
  final int setAnswered;
  final int setCorrect;
  final int setDelta;

  /// A finger is on the drill table: the panel drops to compact (§5.2).
  final bool touchingTable;

  /// The one-time "swipe to replay the action" hint (§5.2).
  final bool showSwipeHint;

  bool get isAnswered => answered != null && result != null;

  /// The set's last answer just landed — the header shows "Set done —…".
  bool get setJustFinished =>
      setSize != null && isAnswered && setAnswered >= setSize!;

  /// The frame the table renders.
  DrillFrame? get frame {
    final p = puzzle;
    if (p == null || p.frames.isEmpty) return null;
    return p.frames[navIndex.clamp(0, p.frames.length - 1)];
  }

  DrillSession copyWith({
    DrillPhase? phase,
    DrillMode? mode,
    Puzzle? puzzle,
    bool clearPuzzle = false,
    bool setQueueIds = false,
    String? leakId,
    String? reviewId,
    int? navIndex,
    DrillAction? answered,
    GradeResult? result,
    bool clearAnswer = false,
    int? ratingDelta,
    String? scheduleLine,
    bool clearScheduleLine = false,
    PuzzleKind? focusKind,
    bool clearFocus = false,
    int? focusLeft,
    int? answerToken,
    int? setSize,
    bool clearSet = false,
    int? setAnswered,
    int? setCorrect,
    int? setDelta,
    bool? touchingTable,
    bool? showSwipeHint,
  }) => DrillSession(
    phase: phase ?? this.phase,
    mode: mode ?? this.mode,
    puzzle: clearPuzzle ? null : (puzzle ?? this.puzzle),
    leakId: setQueueIds ? leakId : this.leakId,
    reviewId: setQueueIds ? reviewId : this.reviewId,
    navIndex: navIndex ?? this.navIndex,
    answered: clearAnswer ? null : (answered ?? this.answered),
    result: clearAnswer ? null : (result ?? this.result),
    ratingDelta: ratingDelta ?? this.ratingDelta,
    scheduleLine:
        clearScheduleLine ? null : (scheduleLine ?? this.scheduleLine),
    focusKind: clearFocus ? null : (focusKind ?? this.focusKind),
    focusLeft: clearFocus ? 0 : (focusLeft ?? this.focusLeft),
    answerToken: answerToken ?? this.answerToken,
    setSize: clearSet ? null : (setSize ?? this.setSize),
    setAnswered: clearSet ? 0 : (setAnswered ?? this.setAnswered),
    setCorrect: clearSet ? 0 : (setCorrect ?? this.setCorrect),
    setDelta: clearSet ? 0 : (setDelta ?? this.setDelta),
    touchingTable: touchingTable ?? this.touchingTable,
    showSwipeHint: showSwipeHint ?? this.showSwipeHint,
  );
}

/// One resolved spot plus the queue ids it came from.
class _Spot {
  const _Spot(this.puzzle, {this.leakId, this.reviewId});
  final Puzzle puzzle;
  final String? leakId;
  final String? reviewId;
}

class DrillNotifier extends Notifier<DrillSession> {
  final Random _rng = Random();
  int _generation = 0;
  bool _disposed = false;
  String? _appliedRoute;

  @override
  DrillSession build() {
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(_dealFirst);
    return const DrillSession();
  }

  /* ------------------------------------------------------------- helpers */

  int get _nowMs => ref.read(drillClockProvider).nowMs;

  void _set(DrillSession next) {
    if (_disposed) return;
    state = next;
  }

  /// The launch spot is `generatePuzzle()` — not adaptive (§12 quirk 14).
  /// Skipped when something already asked for a spot between `build()` and
  /// this microtask (a `/drills?mode=…` deep link, say).
  Future<void> _dealFirst() async {
    if (_generation != 0) return;
    await _deal(
      state.mode,
      request:
          state.mode == DrillMode.mixed
              ? const DrillGenRequest(kind: DrillGenKind.mixed)
              : null,
    );
  }

  /// §6.4 `genFor(mode, focusKind)`.
  Future<_Spot?> _genFor(
    DrillMode mode,
    PuzzleKind? focus, {
    DrillGenRequest? request,
  }) async {
    final generator = ref.read(drillGeneratorProvider);
    switch (mode) {
      case DrillMode.pushfold:
        return _Spot(
          await generator.generate(
            request ?? const DrillGenRequest(kind: DrillGenKind.pushfold),
          ),
        );
      case DrillMode.exploit:
        return _Spot(
          await generator.generate(
            request ?? const DrillGenRequest(kind: DrillGenKind.exploit),
          ),
        );
      case DrillMode.leaks:
        final leaks = ref.read(leakQueueProvider.notifier)..refresh();
        final cards = ref.read(reviewQueueProvider.notifier)..refresh();
        final now = _nowMs;
        final picked = pickDueSpot(
          dueLeaks: leaks.due(now),
          dueCards: cards.due(now),
          rng: _rng,
        );
        if (picked == null) return null;
        return _Spot(
          picked.puzzle,
          leakId: picked.leakId,
          reviewId: picked.reviewId,
        );
      case DrillMode.mixed:
        final req =
            request ??
            (focus != null
                ? DrillGenRequest(
                  kind: DrillGenKind.ofKind,
                  focusKind: focus.label,
                )
                : DrillGenRequest(
                  kind: DrillGenKind.adaptive,
                  rating: ref.read(drillScoreboardProvider).rating.round(),
                ));
        return _Spot(await generator.generate(req));
    }
  }

  /// Deals into [mode], keeping the focus counter when one is running.
  Future<void> _deal(
    DrillMode mode, {
    PuzzleKind? focus,
    DrillGenRequest? request,
  }) async {
    final token = ++_generation;
    _set(
      state.copyWith(
        phase: DrillPhase.loading,
        mode: mode,
        clearAnswer: true,
        clearScheduleLine: true,
        ratingDelta: 0,
      ),
    );
    _Spot? spot;
    try {
      spot = await _genFor(mode, focus, request: request);
    } catch (_) {
      if (token != _generation) return;
      _set(state.copyWith(phase: DrillPhase.error));
      return;
    }
    if (token != _generation || _disposed) return;
    if (spot == null) {
      // Only reachable in Review mode: nothing is due (§6.7).
      _set(
        state.copyWith(
          phase: DrillPhase.empty,
          clearPuzzle: true,
          setQueueIds: true,
          clearAnswer: true,
          clearScheduleLine: true,
          ratingDelta: 0,
        ),
      );
      return;
    }
    final hints = ref.read(drillHintStoreProvider);
    final owed = hints.owed;
    if (owed) unawaited(hints.markShown());
    _set(
      state.copyWith(
        phase: DrillPhase.ready,
        puzzle: spot.puzzle,
        setQueueIds: true,
        leakId: spot.leakId,
        reviewId: spot.reviewId,
        navIndex: spot.puzzle.frames.length - 1,
        clearAnswer: true,
        clearScheduleLine: true,
        ratingDelta: 0,
        showSwipeHint: owed,
      ),
    );
  }

  /* --------------------------------------------------------------- intents */

  /// `/drills?mode=…&set=…` (§2.6). Idempotent: re-applying the same query
  /// never re-deals.
  Future<void> applyRoute({String? mode, int? setSize}) async {
    final key = '${mode ?? ''}|${setSize ?? ''}';
    final target = mode == null ? state.mode : DrillMode.fromId(mode);
    final needsMode = target != state.mode;
    final needsSet = setSize != null && setSize != state.setSize;
    // Re-tapping the same Home card after switching mode by hand must still
    // land in the mode the link asks for, so the guard is "nothing to do",
    // not "same URL".
    if (key == _appliedRoute && !needsMode && !needsSet) return;
    _appliedRoute = key;
    if (needsSet) {
      _set(
        state.copyWith(
          setSize: setSize,
          setAnswered: 0,
          setCorrect: 0,
          setDelta: 0,
        ),
      );
    }
    if (needsMode) await setMode(target);
  }

  /// §6.9. The desktop leaves the focus running across a mode change; we
  /// reset it, which the port doc explicitly allows (§6.9 note).
  Future<void> setMode(DrillMode mode) async {
    if (_disposed) return;
    _set(state.copyWith(mode: mode, clearFocus: true));
    await _deal(mode);
  }

  /// §6.11 — clamped, allowed before and after answering.
  void setNav(int index) {
    final p = state.puzzle;
    if (p == null) return;
    final clamped = index.clamp(0, p.frames.length - 1);
    if (clamped == state.navIndex) return;
    _set(state.copyWith(navIndex: clamped, showSwipeHint: false));
  }

  void nextFrame() => setNav(state.navIndex + 1);
  void previousFrame() => setNav(state.navIndex - 1);

  /// The panel drops to compact while a finger is on the table (§5.2).
  void setTouchingTable(bool touching) {
    if (touching == state.touchingTable) return;
    _set(state.copyWith(touchingTable: touching));
  }

  void dismissSwipeHint() {
    if (!state.showSwipeHint) return;
    _set(state.copyWith(showSwipeHint: false));
  }

  /// §6.6 `answer(a)`. One answer per spot; answering snaps to the decision
  /// frame.
  Future<void> answer(DrillAction action) async {
    final puzzle = state.puzzle;
    if (puzzle == null || state.isAnswered) return;
    final result = gradePuzzle(puzzle, action);
    final haptics = ref.read(hapticsProvider);
    final now = _nowMs;

    // The daily goal counts every mode, Review included (§7, §12 quirk 6).
    await ref.read(goalsProvider.notifier).recordDrill();

    if (state.mode == DrillMode.leaks) {
      SrsState? srs;
      final leakId = state.leakId;
      final reviewId = state.reviewId;
      if (leakId != null) {
        srs = await ref
            .read(leakQueueProvider.notifier)
            .review(leakId, result.correct, nowMs: now);
      }
      if (reviewId != null) {
        srs = await ref
            .read(reviewQueueProvider.notifier)
            .review(reviewId, result.correct, nowMs: now);
      }
      await ref
          .read(drillStoreProvider)
          .recordAnswer(
            DrillAnswer(
              ts: now,
              mode: DrillMode.leaks.ringId,
              kind: puzzle.kind.label,
              correct: result.correct,
              ratingAfter: ref.read(drillScoreboardProvider).rating,
            ),
          );
      if (result.correct) {
        haptics.drillCorrect();
      } else {
        haptics.drillWrong();
      }
      _set(
        state.copyWith(
          answered: action,
          result: result,
          ratingDelta: 0,
          scheduleLine:
              srs == null ? null : DrillCopy.scheduleLine(srs, result.correct),
          clearScheduleLine: srs == null,
          navIndex: puzzle.frames.length - 1,
          answerToken: state.answerToken + 1,
          showSwipeHint: false,
        ),
      );
      return;
    }

    // Practice modes.
    if (!result.correct && puzzle.kind != PuzzleKind.leak) {
      await ref.read(reviewQueueProvider.notifier).addMiss(puzzle, nowMs: now);
    }
    final delta = await ref
        .read(drillScoreboardProvider.notifier)
        .recordPractice(difficulty: puzzle.difficulty, correct: result.correct);
    await ref
        .read(drillStoreProvider)
        .recordAnswer(
          DrillAnswer(
            ts: now,
            mode: state.mode.ringId,
            kind: puzzle.kind.label,
            correct: result.correct,
            ratingAfter: ref.read(drillScoreboardProvider).rating,
          ),
        );
    if (result.correct) {
      haptics.drillCorrect();
    } else {
      haptics.drillWrong();
    }

    final inSet = state.setSize != null;
    _set(
      state.copyWith(
        answered: action,
        result: result,
        ratingDelta: delta,
        clearScheduleLine: true,
        navIndex: puzzle.frames.length - 1,
        answerToken: state.answerToken + 1,
        showSwipeHint: false,
        setAnswered: inSet ? state.setAnswered + 1 : null,
        setCorrect: inSet ? state.setCorrect + (result.correct ? 1 : 0) : null,
        setDelta: inSet ? state.setDelta + delta : null,
      ),
    );
  }

  /// §6.7 `next()`.
  Future<void> next() async {
    final focus = state.focusLeft > 0 ? state.focusKind : null;
    if (state.setJustFinished) _set(state.copyWith(clearSet: true));
    await _deal(state.mode, focus: focus);
    if (_disposed || state.phase != DrillPhase.ready) return;
    final left = focus != null ? state.focusLeft - 1 : 0;
    _set(state.copyWith(focusLeft: left, clearFocus: left <= 0));
  }

  /// §6.8 `drillSimilar()` — five more of the same family, not adaptive.
  Future<void> drillSimilar() async {
    final puzzle = state.puzzle;
    if (puzzle == null) return;
    if (state.mode == DrillMode.leaks || puzzle.kind == PuzzleKind.leak) return;
    _set(state.copyWith(focusKind: puzzle.kind, focusLeft: 5));
    await next();
  }

  /// §14 — the error state's "Try again".
  Future<void> retry() => _deal(state.mode, focus: state.focusKind);
}

final drillProvider = NotifierProvider<DrillNotifier, DrillSession>(
  DrillNotifier.new,
);
