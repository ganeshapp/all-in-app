/// Monte-Carlo equity and coach verdicts, off the UI thread —
/// ARCHITECTURE.md ("Heavy simulations run off the UI thread via `compute()`;
/// `lib/services/equity_service.dart` is the only place that spawns
/// isolates") and DESIGN.md §4.8 (the coach chip), §6.5 (the equity
/// calculators) and the two §14 rows about a slow or crashed coach.
///
/// **The 16 ms budget.** A phone frame is 16.7 ms (8.3 ms at 120 Hz), and the
/// felt animates while the coach thinks. So: **nothing that can take more than
/// ~2 ms runs on the UI thread.** A 1 600-trial verdict is tens of
/// milliseconds and a 4 000-trial "High" verdict on a 9-max table is well past
/// 100 ms — either would drop frames mid-deal. Every call here therefore hands
/// an [EquityJob] to `compute`, and the engine's own synchronous functions are
/// reserved for the ≤ 320-trial bot sims that are genuinely below the budget.
/// The three things this service adds on top of `compute` all exist for the
/// same reason:
///
/// * **Coalescing + cancellation.** A newer request for the same `key`
///   supersedes the older one: if the older job has not started it is dropped
///   before the isolate is ever spawned, and its future completes with
///   [EquityCancelled]. Scrubbing the sizing rail or re-picking a range
///   therefore costs one simulation, not one per frame.
/// * **Memoisation.** Results are keyed by (hand, board, range, iters, seed)
///   in a small LRU, so re-opening a coach note (§4.8 chip → badge → sheet) or
///   flipping back to a calculator is instant instead of a second 4 000-trial
///   run. Unseeded jobs are never cached — they are not reproducible, so a
///   cache hit would silently freeze a "random" answer.
/// * **The 5 s give-up rule (§14).** Every [evaluateHero] is raced against a
///   timer; on timeout or isolate error the caller gets `null`, and *nothing*
///   is recorded.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../engine/coach.dart' as coach;
import '../engine/engine.dart';

/// Which engine entry point an [EquityJob] runs.
enum EquityJobKind {
  /// Hero combo vs a villain range (exact on turn/river).
  vsRange,

  /// Hero combo vs one uniformly random hand (exact on the river).
  vsRandom,

  /// Hero combo vs N random hands, pot-share on ties.
  vsField,

  /// Hero range vs villain range (the §6.5 equity calculator).
  rangeVsRange,
}

/// One unit of equity work: plain strings and ints, so it crosses an isolate
/// boundary as-is.
@immutable
class EquityJob {
  const EquityJob._({
    required this.kind,
    required this.hero,
    required this.heroRange,
    required this.board,
    required this.range,
    required this.opponents,
    required this.iters,
    required this.seed,
  });

  /// Hero's two cards vs [range] (label list, e.g. `['AKs', 'QQ']`).
  factory EquityJob.vsRange({
    required List<Card> hero,
    List<Card> board = const <Card>[],
    required List<HandLabel> range,
    int iters = 1500,
    int? seed,
  }) => EquityJob._(
    kind: EquityJobKind.vsRange,
    hero: List<Card>.unmodifiable(hero),
    heroRange: const <HandLabel>[],
    board: List<Card>.unmodifiable(board),
    range: List<HandLabel>.unmodifiable(range),
    opponents: 1,
    iters: iters,
    seed: seed,
  );

  /// Hero's two cards vs one random hand.
  factory EquityJob.vsRandom({
    required List<Card> hero,
    List<Card> board = const <Card>[],
    int iters = 1200,
    int? seed,
  }) => EquityJob._(
    kind: EquityJobKind.vsRandom,
    hero: List<Card>.unmodifiable(hero),
    heroRange: const <HandLabel>[],
    board: List<Card>.unmodifiable(board),
    range: const <HandLabel>[],
    opponents: 1,
    iters: iters,
    seed: seed,
  );

  /// Hero's two cards vs [opponents] random hands (clamped 1..8 by the engine).
  factory EquityJob.vsField({
    required List<Card> hero,
    List<Card> board = const <Card>[],
    required int opponents,
    int iters = 1500,
    int? seed,
  }) => EquityJob._(
    kind: EquityJobKind.vsField,
    hero: List<Card>.unmodifiable(hero),
    heroRange: const <HandLabel>[],
    board: List<Card>.unmodifiable(board),
    range: const <HandLabel>[],
    opponents: opponents,
    iters: iters,
    seed: seed,
  );

  /// A hero range vs a villain range on [board].
  factory EquityJob.rangeVsRange({
    required List<HandLabel> heroRange,
    List<Card> board = const <Card>[],
    required List<HandLabel> villainRange,
    int iters = 3000,
    int? seed,
  }) => EquityJob._(
    kind: EquityJobKind.rangeVsRange,
    hero: const <Card>[],
    heroRange: List<HandLabel>.unmodifiable(heroRange),
    board: List<Card>.unmodifiable(board),
    range: List<HandLabel>.unmodifiable(villainRange),
    opponents: 1,
    iters: iters,
    seed: seed,
  );

  /// The coach's own request shape (`engine/coach.dart`), so [evaluateHero]
  /// can route it through this service unchanged.
  factory EquityJob.fromRequest(coach.EquityRequest request) {
    switch (request.mode) {
      case coach.EquityMode.range:
        return EquityJob.vsRange(
          hero: request.hero,
          board: request.board,
          range: request.range,
          iters: request.iters,
          seed: request.seed,
        );
      case coach.EquityMode.random:
        return EquityJob.vsRandom(
          hero: request.hero,
          board: request.board,
          iters: request.iters,
          seed: request.seed,
        );
      case coach.EquityMode.field:
        return EquityJob.vsField(
          hero: request.hero,
          board: request.board,
          opponents: request.opponents,
          iters: request.iters,
          seed: request.seed,
        );
    }
  }

  final EquityJobKind kind;

  /// Hero hole cards (two) — empty for [EquityJobKind.rangeVsRange].
  final List<Card> hero;

  /// Hero range labels — only [EquityJobKind.rangeVsRange].
  final List<HandLabel> heroRange;
  final List<Card> board;

  /// Villain range labels — [EquityJobKind.vsRange] and `rangeVsRange`.
  final List<HandLabel> range;

  /// Live opponents — only [EquityJobKind.vsField].
  final int opponents;
  final int iters;

  /// Deterministic when set; `null` means "let the engine use `Random()`",
  /// which also opts the job out of the memo cache.
  final int? seed;

  /// Run the job in the current isolate. This is what the isolate executes;
  /// call it directly only from a test or a benchmark.
  EquityResult run() {
    switch (kind) {
      case EquityJobKind.vsRange:
        return equityVsRangeCards(
          (hero[0], hero[1]),
          board,
          range,
          iters: iters,
          seed: seed,
        );
      case EquityJobKind.vsRandom:
        return equityVsRandomCards(
          (hero[0], hero[1]),
          board,
          iters: iters,
          seed: seed,
        );
      case EquityJobKind.vsField:
        return equityVsFieldCards(
          (hero[0], hero[1]),
          board,
          opponents,
          iters: iters,
          seed: seed,
        );
      case EquityJobKind.rangeVsRange:
        return equityRangeVsRange(
          _expand(heroRange),
          board.map(cardToInt).toList(growable: false),
          _expand(range),
          iters: iters,
          seed: seed,
        );
    }
  }

  /// Memo key: (kind, hand, board, range, iters, seed) — the tuple the doc
  /// comment promises. Unseeded jobs are excluded by the service, not here.
  String get cacheKey =>
      '${kind.name}|${hero.join()}|${heroRange.join(',')}|${board.join()}|'
      '${range.join(',')}|$opponents|$iters|$seed';

  static List<IntCombo> _expand(List<HandLabel> labels) {
    final combos = <IntCombo>[];
    for (final label in labels) {
      for (final combo in labelToCombos(label)) {
        combos.add(comboToInts(combo));
      }
    }
    return combos;
  }

  @override
  String toString() => 'EquityJob($cacheKey)';
}

/// Runs a job somewhere. The default ships it to an isolate; tests inject a
/// synchronous or gated runner.
typedef EquityJobRunner = Future<EquityResult> Function(EquityJob job);

/// Isolate entry point — top-level, as `compute` requires.
EquityResult runEquityJob(EquityJob job) => job.run();

/// Thrown into the future of a request that a newer request superseded, or
/// that [EquityService.cancel] dropped. It is not an error: the caller simply
/// no longer wants the answer.
class EquityCancelled implements Exception {
  const EquityCancelled([this.key]);

  /// The coalescing key that superseded this request, when there was one.
  final Object? key;

  @override
  String toString() => 'EquityCancelled(${key ?? 'no key'})';
}

/// Counters for tests and the debug overlay; cheap enough to always keep.
@immutable
class EquityServiceStats {
  const EquityServiceStats({
    required this.hits,
    required this.misses,
    required this.started,
    required this.dropped,
    required this.timeouts,
    required this.errors,
  });

  /// Requests answered from the LRU or joined onto an identical in-flight job.
  final int hits;

  /// Requests that had to run.
  final int misses;

  /// Jobs actually handed to the runner (isolate spawns).
  final int started;

  /// Requests superseded *before* their job started — work never done.
  final int dropped;
  final int timeouts;
  final int errors;

  @override
  String toString() =>
      'EquityServiceStats(hits: $hits, misses: $misses, started: $started, '
      'dropped: $dropped, timeouts: $timeouts, errors: $errors)';
}

class _Pending {
  _Pending(this.job, this.key);

  final EquityJob job;
  final Object? key;
  final Completer<EquityResult> completer = Completer<EquityResult>();
  bool cancelled = false;
}

/// The app's single equity service. Hold one per `ProviderScope`.
class EquityService {
  EquityService({
    EquityJobRunner? runner,
    this.cacheSize = 64,
    this.maxConcurrent = 2,
    this.timeout = giveUp,
  }) : _runner = runner ?? _computeRunner,
       assert(cacheSize > 0),
       assert(maxConcurrent > 0);

  /// Runs every job in the calling isolate. For tests, benchmarks and the
  /// small synchronous sims — never for a coach verdict on a real device.
  EquityService.inProcess({int cacheSize = 64, Duration? timeout = giveUp})
    : this(
        runner: _inProcessRunner,
        cacheSize: cacheSize,
        maxConcurrent: 1,
        timeout: timeout,
      );

  /// §14: "every `evaluateHero` / `explainLastBotMove` is raced against a 5 s
  /// timer".
  static const Duration giveUp = Duration(seconds: 5);

  /// Default coalescing key for coach verdicts: one decision at a time, so a
  /// new action supersedes a verdict the user has already moved past.
  static const Object coachKey = 'coach';

  /// Entries kept in the memo cache.
  final int cacheSize;

  /// How many jobs may occupy isolates at once. Two keeps a calculator
  /// responsive while the coach thinks without thrashing a phone's cores.
  final int maxConcurrent;

  /// Per-request give-up window; `null` disables it.
  final Duration? timeout;

  final EquityJobRunner _runner;
  final LinkedHashMap<String, EquityResult> _cache =
      LinkedHashMap<String, EquityResult>();
  final Map<String, Future<EquityResult>> _inflight =
      <String, Future<EquityResult>>{};
  final Map<Object, _Pending> _byKey = <Object, _Pending>{};
  final Queue<_Pending> _queue = Queue<_Pending>();

  int _active = 0;
  int _hits = 0;
  int _misses = 0;
  int _started = 0;
  int _dropped = 0;
  int _timeouts = 0;
  int _errors = 0;
  int _coachFailures = 0;
  bool _disposed = false;

  /// Counters since construction (or [resetStats]).
  EquityServiceStats get stats => EquityServiceStats(
    hits: _hits,
    misses: _misses,
    started: _started,
    dropped: _dropped,
    timeouts: _timeouts,
    errors: _errors,
  );

  /// How many coach evaluations gave up or failed (§14: one failure respawns,
  /// a second switches the coach off for the session — that policy lives in
  /// the play provider, this is the number it reads).
  int get coachFailures => _coachFailures;

  void resetStats() {
    _hits = _misses = _started = _dropped = _timeouts = _errors = 0;
  }

  void resetCoachFailures() => _coachFailures = 0;

  /* --------------------------------------------------------- the four calls */

  /// Hero's hand vs a villain range (§4.8, §6.5, §6.6 range explorer).
  Future<EquityResult> vsRange({
    required List<Card> hero,
    List<Card> board = const <Card>[],
    required List<HandLabel> range,
    int iters = 1500,
    int? seed,
    Object? key,
  }) => run(
    EquityJob.vsRange(
      hero: hero,
      board: board,
      range: range,
      iters: iters,
      seed: seed,
    ),
    key: key,
  );

  /// Hero's hand vs one random hand (the price line when a villain has no
  /// readable range).
  Future<EquityResult> vsRandom({
    required List<Card> hero,
    List<Card> board = const <Card>[],
    int iters = 1200,
    int? seed,
    Object? key,
  }) => run(
    EquityJob.vsRandom(hero: hero, board: board, iters: iters, seed: seed),
    key: key,
  );

  /// Hero's hand vs a multiway field (§6.5 MultiwayTrainer, multiway pots).
  Future<EquityResult> vsField({
    required List<Card> hero,
    List<Card> board = const <Card>[],
    required int opponents,
    int iters = 1500,
    int? seed,
    Object? key,
  }) => run(
    EquityJob.vsField(
      hero: hero,
      board: board,
      opponents: opponents,
      iters: iters,
      seed: seed,
    ),
    key: key,
  );

  /// Range vs range (§6.5 equity calculator).
  Future<EquityResult> rangeVsRange({
    required List<HandLabel> heroRange,
    List<Card> board = const <Card>[],
    required List<HandLabel> villainRange,
    int iters = 3000,
    int? seed,
    Object? key,
  }) => run(
    EquityJob.rangeVsRange(
      heroRange: heroRange,
      board: board,
      villainRange: villainRange,
      iters: iters,
      seed: seed,
    ),
    key: key,
  );

  /* ---------------------------------------------------------- the coach hook */

  /// Grade the hero's [action] against [state] with the engine's coach, doing
  /// the simulation off-thread (§4.8).
  ///
  /// Returns `null` when there is nothing to say, when the request was
  /// superseded (the user acted again), and — per the §14 give-up rule — when
  /// the work timed out or the isolate failed. In those last two cases nothing
  /// may be recorded by the caller: no chip, no `reviewLog` entry, no leak.
  Future<coach.CoachReview?> evaluateHero(
    TableState state,
    Action action,
    int id, {
    coach.CoachSettings settings = coach.CoachSettings.defaults,
    Object? key = coachKey,
    Duration? timeout,
  }) async {
    Object? failure;
    Future<EquityResult> runEquity(coach.EquityRequest request) async {
      try {
        return await run(EquityJob.fromRequest(request), key: key);
      } catch (e) {
        // The engine swallows equity errors and falls back to 50 % equity;
        // §14 says a failed simulation must produce no verdict at all, so we
        // remember the failure and drop the review below.
        failure = e;
        rethrow;
      }
    }

    final give = timeout ?? this.timeout;
    try {
      final future = coach.evaluateHero(
        state,
        action,
        id,
        settings: settings,
        runEquity: runEquity,
      );
      final review = give == null ? await future : await future.timeout(give);
      final f = failure;
      if (f != null) {
        if (f is! EquityCancelled) _coachFailures++;
        return null;
      }
      return review;
    } on TimeoutException {
      _timeouts++;
      _coachFailures++;
      return null;
    } catch (_) {
      _coachFailures++;
      return null;
    }
  }

  /* ------------------------------------------------------------- scheduling */

  /// Submit [job]. When [key] is given, any earlier unfinished request with
  /// the same key is superseded: dropped if it has not started, and its future
  /// completed with [EquityCancelled] either way.
  Future<EquityResult> run(EquityJob job, {Object? key}) {
    if (_disposed) {
      return Future<EquityResult>.error(
        StateError('EquityService used after dispose()'),
      );
    }
    if (key != null) _supersede(key);

    final cacheable = job.seed != null;
    if (cacheable) {
      final cached = _cacheGet(job.cacheKey);
      if (cached != null) {
        _hits++;
        return Future<EquityResult>.value(cached);
      }
    }

    final pending = _Pending(job, key);
    if (key != null) _byKey[key] = pending;
    _queue.add(pending);
    _pump();
    return pending.completer.future;
  }

  /// Drop the pending request registered under [key], if any.
  void cancel(Object key) => _supersede(key);

  /// Drop every pending request (leaving the LRU intact).
  void cancelAll() {
    for (final key in _byKey.keys.toList()) {
      _supersede(key);
    }
    for (final pending in _queue.toList()) {
      pending.cancelled = true;
      if (!pending.completer.isCompleted) {
        _dropped++;
        pending.completer.completeError(
          const EquityCancelled(),
          StackTrace.current,
        );
      }
    }
    _queue.clear();
  }

  /// Forget every memoised result (after Reset all progress, §7.10, or when
  /// the sim-quality setting changes the iteration count).
  void clearCache() => _cache.clear();

  /// Cancel everything and refuse further work.
  void dispose() {
    cancelAll();
    _cache.clear();
    _disposed = true;
  }

  void _supersede(Object key) {
    final previous = _byKey.remove(key);
    if (previous == null || previous.completer.isCompleted) return;
    previous.cancelled = true;
    previous.completer.completeError(EquityCancelled(key), StackTrace.current);
  }

  void _pump() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final pending = _queue.removeFirst();
      if (pending.cancelled) {
        // Superseded before it ever reached an isolate: the whole point of
        // the queue — this simulation is never run.
        _dropped++;
        continue;
      }
      unawaited(_execute(pending));
    }
  }

  Future<void> _execute(_Pending pending) async {
    final job = pending.job;
    final ck = job.cacheKey;
    final cacheable = job.seed != null;

    if (cacheable) {
      final cached = _cacheGet(ck);
      if (cached != null) {
        _hits++;
        _finish(pending, cached);
        return;
      }
    }

    var future = cacheable ? _inflight[ck] : null;
    final owner = future == null;
    if (owner) {
      _misses++;
      _started++;
      _active++;
      future = _runner(job);
      if (cacheable) _inflight[ck] = future;
      // Never let a late error from an abandoned job go unhandled.
      unawaited(future.then((_) {}, onError: (Object _, StackTrace __) {}));
    } else {
      // An identical job is already running: ride along instead of paying for
      // a second isolate.
      _hits++;
    }

    try {
      final EquityResult result;
      final Duration? give = timeout;
      final Future<EquityResult> pendingFuture = future;
      result =
          give == null
              ? await pendingFuture
              : await pendingFuture.timeout(give);
      if (cacheable && owner) _cachePut(ck, result);
      _finish(pending, result);
    } on TimeoutException catch (e, st) {
      _timeouts++;
      _fail(pending, e, st);
    } catch (e, st) {
      _errors++;
      _fail(pending, e, st);
    } finally {
      if (owner) {
        _active--;
        if (cacheable) _inflight.remove(ck);
        _pump();
      }
    }
  }

  void _finish(_Pending pending, EquityResult result) {
    if (pending.key != null && identical(_byKey[pending.key], pending)) {
      _byKey.remove(pending.key);
    }
    // A cancelled request's result is still cached above — the work is kept,
    // only the delivery is dropped.
    if (pending.cancelled || pending.completer.isCompleted) return;
    pending.completer.complete(result);
  }

  void _fail(_Pending pending, Object error, StackTrace stackTrace) {
    if (pending.key != null && identical(_byKey[pending.key], pending)) {
      _byKey.remove(pending.key);
    }
    if (pending.cancelled || pending.completer.isCompleted) return;
    pending.completer.completeError(error, stackTrace);
  }

  EquityResult? _cacheGet(String key) {
    final value = _cache.remove(key);
    if (value != null) _cache[key] = value; // refresh recency
    return value;
  }

  void _cachePut(String key, EquityResult value) {
    _cache.remove(key);
    _cache[key] = value;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  static Future<EquityResult> _computeRunner(EquityJob job) =>
      compute(runEquityJob, job, debugLabel: 'equity:${job.kind.name}');

  static Future<EquityResult> _inProcessRunner(EquityJob job) async =>
      job.run();
}
