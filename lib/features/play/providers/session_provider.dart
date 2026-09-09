/// `SessionNotifier` — the whole play loop (DESIGN.md §4.1–§4.14,
/// docs/port/play-loop-and-coach.md §3–§4).
///
/// It owns the desktop `useGame` store: the table, pace, the auto-play
/// scheduler with cancellation, hand-history recording, the coach hand-off to
/// [EquityService] and the mobile-only snapshot contract of §4.14 (a write
/// after **every** hero action and **every** hand boundary).
///
/// Two rules the rest of the feature depends on:
///
/// * **The engine is pure.** Every table this notifier publishes came out of
///   `startHand` / `applyAction`; nothing mutates a `TableState` that has
///   already been in `state`.
/// * **Nothing over ~2 ms runs on the UI thread.** `evaluateHero` goes through
///   [EquityService] (isolates, 5 s give-up, cancellation) — §14.
library;

import 'dart:async';
import 'dart:math';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/services/persistence/goals_store.dart';
import 'package:allin/services/persistence/records.dart';
import 'package:allin/services/persistence/serialization.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `BASE_CONFIG` (port §2): 6 seats, 2000 chips, blinds 10/20.
const int kStartingStack = 2000;
const int kSmallBlind = 10;
const int kBigBlind = 20;

/// `ARCHE_POOL` — uniform, independent per seat; duplicates are normal.
const List<Archetype> kArchePool = [
  Archetype.tag,
  Archetype.lag,
  Archetype.nit,
  Archetype.station,
];

/// The `⏭` cadence (§4.5 D): "runs the remaining bot actions at 120 ms".
const Duration kSkipCadence = Duration(milliseconds: 120);

/// Hold "Next action" fast-forwards at the Fast delay (§4.5 C).
const Duration kFastForwardCadence = Duration(milliseconds: PaceSpeed.fastMs);

/// The auto-deal countdown (§4.5 E).
const Duration kAutoDealCountdown = Duration(seconds: 3);

/// Session counters kept beside the table (port §3 `session`).
@immutable
class SessionCounters {
  const SessionCounters({
    this.hands = 0,
    this.netChips = 0,
    this.biggestWinChips = 0,
    this.biggestLossChips = 0,
    this.coachedDecisions = 0,
    this.flaggedDecisions = 0,
    this.bestEvBb,
    this.bestEvLabel,
    this.worstEvBb,
    this.worstEvLabel,
  });

  final int hands;
  final int netChips;
  final int biggestWinChips;
  final int biggestLossChips;

  /// Decisions the coach graded this session, and how many it flagged.
  final int coachedDecisions;
  final int flaggedDecisions;

  /// Highest / lowest EV among this session's coached decisions, with the
  /// "{street} {action}" label §4.13's debrief quotes.
  final double? bestEvBb;
  final String? bestEvLabel;
  final double? worstEvBb;
  final String? worstEvLabel;

  SessionCounters copyWith({
    int? hands,
    int? netChips,
    int? biggestWinChips,
    int? biggestLossChips,
    int? coachedDecisions,
    int? flaggedDecisions,
    double? bestEvBb,
    String? bestEvLabel,
    double? worstEvBb,
    String? worstEvLabel,
  }) => SessionCounters(
    hands: hands ?? this.hands,
    netChips: netChips ?? this.netChips,
    biggestWinChips: biggestWinChips ?? this.biggestWinChips,
    biggestLossChips: biggestLossChips ?? this.biggestLossChips,
    coachedDecisions: coachedDecisions ?? this.coachedDecisions,
    flaggedDecisions: flaggedDecisions ?? this.flaggedDecisions,
    bestEvBb: bestEvBb ?? this.bestEvBb,
    bestEvLabel: bestEvLabel ?? this.bestEvLabel,
    worstEvBb: worstEvBb ?? this.worstEvBb,
    worstEvLabel: worstEvLabel ?? this.worstEvLabel,
  );

  Map<String, Object?> toJson() => {
    'hands': hands,
    'netChips': netChips,
    'biggestWinChips': biggestWinChips,
    'biggestLossChips': biggestLossChips,
    'coachedDecisions': coachedDecisions,
    'flaggedDecisions': flaggedDecisions,
    'bestEvBb': bestEvBb,
    'bestEvLabel': bestEvLabel,
    'worstEvBb': worstEvBb,
    'worstEvLabel': worstEvLabel,
  };

  static SessionCounters fromJson(Object? json) {
    if (json is! Map) return const SessionCounters();
    final j = json.cast<String, Object?>();
    return SessionCounters(
      hands: (j['hands'] as num?)?.toInt() ?? 0,
      netChips: (j['netChips'] as num?)?.toInt() ?? 0,
      biggestWinChips: (j['biggestWinChips'] as num?)?.toInt() ?? 0,
      biggestLossChips: (j['biggestLossChips'] as num?)?.toInt() ?? 0,
      coachedDecisions: (j['coachedDecisions'] as num?)?.toInt() ?? 0,
      flaggedDecisions: (j['flaggedDecisions'] as num?)?.toInt() ?? 0,
      bestEvBb: (j['bestEvBb'] as num?)?.toDouble(),
      bestEvLabel: j['bestEvLabel'] as String?,
      worstEvBb: (j['worstEvBb'] as num?)?.toDouble(),
      worstEvLabel: j['worstEvLabel'] as String?,
    );
  }
}

/// Everything the table, the lobby and the shell read.
@immutable
class SessionState {
  const SessionState({
    this.table,
    this.options = TableOptions.defaults,
    this.active = false,
    this.startedAt = 0,
    this.counters = const SessionCounters(),
    this.history = const [],
    this.thinking = false,
    this.paused = false,
    this.surfacesOpen = 0,
    this.sessionEnded = false,
    this.busted = false,
    this.reviewLog = const [],
    this.activeReviewId,
    this.pendingBlocking,
    this.lastActorSeat,
    this.lastActorLabel,
    this.coachComputing = false,
    this.coachOffThisSession = false,
    this.resumeCaption,
    this.saveFailed = false,
    this.rebought = const {},
    this.needsFreshHand = false,
    this.autoDealDeadline,
    this.skipping = false,
    this.savedAt = 0,
  });

  /// The live table; null before the first session of the app's life.
  final TableState? table;
  final TableOptions options;

  /// A session exists (paused or on screen) — the Resume card's condition.
  final bool active;

  /// Epoch ms the session was dealt.
  final int startedAt;
  final SessionCounters counters;

  /// This session's finished hands, oldest first (P2's Log and P10's rows).
  final List<HHHand> history;

  /// Auto pace: a bot's think delay is running.
  final bool thinking;

  /// The desktop `paused` flag: blocks hero and bot actions.
  final bool paused;

  /// How many sheets / modals are open over the table. Auto never runs while
  /// one is (§14: "Auto + any sheet / P7 / blocking note → loop paused").
  final int surfacesOpen;

  /// P10 is up. The session stays active (port §4.4).
  final bool sessionEnded;

  /// The hero busted: P10 has no ✕ and only "New session" continues.
  final bool busted;

  /// The coach's notes for the **current** hand, oldest first.
  final List<CoachReview> reviewLog;
  final int? activeReviewId;

  /// A blocking verdict that resolved while a sheet was open (§4.8). The loop
  /// is already paused; P3 opens on the next frame after the sheet closes.
  final CoachReview? pendingBlocking;

  final int? lastActorSeat;

  /// The last actor's action label, remembered so "Explain last move" never
  /// degrades to "Ivey's move" after a street closes (§4.10).
  final String? lastActorLabel;

  /// §14: the ≤ 1.5 s shimmer in the chip zone.
  final bool coachComputing;

  /// §14: the coach failed twice — off for this session, setting untouched.
  final bool coachOffThisSession;

  /// The 2 s caption under the top bar after a restore (§4.14).
  final String? resumeCaption;

  /// A snapshot write failed: P14 on leave + the persistent ticker line.
  final bool saveFailed;

  /// Bots rebuilt to 100 bb at this deal — one hand of "rebought" (§4.3).
  final Set<int> rebought;

  /// The snapshot's table half could not be decoded: deal a fresh hand.
  final bool needsFreshHand;

  /// Epoch ms the auto-deal countdown ends, or null (§4.5 E).
  final int? autoDealDeadline;

  /// `⏭` / hold-to-fast-forward is running.
  final bool skipping;

  /// Epoch ms of the last snapshot write — the lobby's "8 min ago" (§4.1).
  final int savedAt;

  SessionState copyWith({
    TableState? table,
    TableOptions? options,
    bool? active,
    int? startedAt,
    SessionCounters? counters,
    List<HHHand>? history,
    bool? thinking,
    bool? paused,
    int? surfacesOpen,
    bool? sessionEnded,
    bool? busted,
    List<CoachReview>? reviewLog,
    int? activeReviewId,
    bool clearActiveReview = false,
    CoachReview? pendingBlocking,
    bool clearPendingBlocking = false,
    int? lastActorSeat,
    String? lastActorLabel,
    bool clearLastActor = false,
    bool? coachComputing,
    bool? coachOffThisSession,
    String? resumeCaption,
    bool clearResumeCaption = false,
    bool? saveFailed,
    Set<int>? rebought,
    bool? needsFreshHand,
    int? autoDealDeadline,
    bool clearAutoDeal = false,
    bool? skipping,
    int? savedAt,
  }) => SessionState(
    table: table ?? this.table,
    options: options ?? this.options,
    active: active ?? this.active,
    startedAt: startedAt ?? this.startedAt,
    counters: counters ?? this.counters,
    history: history ?? this.history,
    thinking: thinking ?? this.thinking,
    paused: paused ?? this.paused,
    surfacesOpen: surfacesOpen ?? this.surfacesOpen,
    sessionEnded: sessionEnded ?? this.sessionEnded,
    busted: busted ?? this.busted,
    reviewLog: reviewLog ?? this.reviewLog,
    activeReviewId:
        clearActiveReview ? null : (activeReviewId ?? this.activeReviewId),
    pendingBlocking:
        clearPendingBlocking ? null : (pendingBlocking ?? this.pendingBlocking),
    lastActorSeat:
        clearLastActor ? null : (lastActorSeat ?? this.lastActorSeat),
    lastActorLabel:
        clearLastActor ? null : (lastActorLabel ?? this.lastActorLabel),
    coachComputing: coachComputing ?? this.coachComputing,
    coachOffThisSession: coachOffThisSession ?? this.coachOffThisSession,
    resumeCaption:
        clearResumeCaption ? null : (resumeCaption ?? this.resumeCaption),
    saveFailed: saveFailed ?? this.saveFailed,
    rebought: rebought ?? this.rebought,
    needsFreshHand: needsFreshHand ?? this.needsFreshHand,
    autoDealDeadline:
        clearAutoDeal ? null : (autoDealDeadline ?? this.autoDealDeadline),
    skipping: skipping ?? this.skipping,
    savedAt: savedAt ?? this.savedAt,
  );

  /* ------------------------------------------------------------- selectors */

  int get bigBlind => table?.bigBlind ?? kBigBlind;
  int get seats => options.seats;

  /// `legalActions()` for whoever is to act, or null off-turn.
  LegalActions? get legal {
    final t = table;
    if (t == null || t.phase != GamePhase.betting || t.toAct == null) {
      return null;
    }
    return legalActions(t);
  }

  bool get heroToAct =>
      table?.phase == GamePhase.betting && table?.toAct == 0 && !paused;

  bool get handOver => table?.phase == GamePhase.handOver;

  /// The hero folded or is all-in while bots play it out (§4.5 C/D).
  bool get heroOutOfHand {
    final t = table;
    if (t == null || t.phase != GamePhase.betting) return false;
    final hero = t.players[0];
    return hero.hasFolded || hero.isAllIn;
  }

  /// Nothing may advance: a blocking note, an open sheet, or an explicit pause.
  bool get loopBlocked =>
      paused || surfacesOpen > 0 || pendingBlocking != null || sessionEnded;

  double get netBb => counters.netChips / bigBlind;

  /// `bb/100` (port §19): net bb per hand × 100.
  double get bb100 => counters.hands > 0 ? netBb / counters.hands * 100 : 0;

  /// The last actor is a bot → "Explain last move" is live (§4.10).
  bool get canExplain {
    final seat = lastActorSeat;
    final t = table;
    if (seat == null || seat == 0 || t == null) return false;
    return t.players[seat].archetype != null;
  }

  /// The newest note that has not been folded into the badge.
  CoachReview? get activeReview {
    final id = activeReviewId;
    if (id == null) return null;
    for (final r in reviewLog) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/* ========================================================================== */

class SessionNotifier extends Notifier<SessionState> {
  int _reviewSeq = 1;
  int _loopToken = 0;
  Timer? _loopTimer;
  Timer? _autoDealTimer;
  Timer? _skipTimer;
  HHHand? _currentHH;

  /// The roster restored from a snapshot whose table half was unreadable.
  List<Player>? _restoredRoster;

  /// False once the provider is disposed — every async continuation checks it
  /// before touching `state` (Riverpod 2 has no `ref.mounted`).
  bool _alive = true;

  AppSettings get _settings => ref.read(settingsProvider);
  Random get _rng => ref.read(playRandomProvider);
  int get _now => ref.read(playClockProvider).nowMs;
  SessionRepository get _sessions => ref.read(sessionRepositoryProvider);

  bool get _coachOn => _settings.coachEnabled && !state.coachOffThisSession;

  @override
  SessionState build() {
    ref.onDispose(() {
      _alive = false;
      _loopTimer?.cancel();
      _autoDealTimer?.cancel();
      _skipTimer?.cancel();
      _loopToken++;
    });
    return _restore();
  }

  /* ------------------------------------------------------------- restoring */

  SessionState _restore() {
    final options = ref.read(tableOptionsStoreProvider).load();
    final snapshot = _sessions.loadSnapshot();
    if (snapshot == null) return SessionState(options: options);

    final counters = SessionCounters.fromJson(snapshot.session['counters']);
    final history = <HHHand>[];
    for (final raw in (snapshot.session['history'] as List?) ?? const []) {
      if (raw is! Map) continue;
      try {
        history.add(HHHand.fromJson(raw.cast<String, Object?>()));
      } catch (_) {
        // A hand this build cannot read is dropped; the session still resumes.
      }
    }
    final startedAt = (snapshot.session['startedAt'] as num?)?.toInt() ?? 0;
    final table = snapshot.table;

    if (table != null) {
      // The hand in progress, so `_finalizeHand` still counts it, files it in
      // the session history and stores its JSON (§4.14). A hand whose history
      // cannot be decoded falls back to a fresh shell built from the restored
      // table: the money is never dropped from the counters.
      _currentHH = _restoreCurrentHand(snapshot.session['currentHand'], table);
      return SessionState(
        table: table,
        options: snapshot.options,
        active: true,
        startedAt: startedAt,
        counters: counters,
        history: history,
        paused: true,
        resumeCaption: _resumedCaption(table),
        savedAt: snapshot.savedAt,
      );
    }

    // §4.14: the mid-hand state is unreadable — keep the roster, abandon the
    // hand, deal a fresh one on the first frame of the table.
    _restoredRoster = snapshot.players.isEmpty ? null : snapshot.players;
    return SessionState(
      options: snapshot.options,
      active: _restoredRoster != null,
      startedAt: startedAt,
      counters: counters,
      history: history,
      needsFreshHand: _restoredRoster != null,
      savedAt: snapshot.savedAt,
      resumeCaption:
          _restoredRoster == null
              ? null
              : "Resumed — that hand couldn't be restored, dealing a fresh one",
    );
  }

  /// The stored hand-in-progress, or a shell rebuilt from [table] when there
  /// is none (an older snapshot) or it cannot be decoded. The rebuilt shell
  /// has no action list, so its replay is partial — but the hand still counts,
  /// which is the part the user's money depends on.
  HHHand _restoreCurrentHand(Object? raw, TableState table) {
    if (raw is Map) {
      try {
        return HHHand.fromJson(raw.cast<String, Object?>());
      } catch (_) {
        // Fall through to the shell below.
      }
    }
    final seats = table.config.seats;
    return HHHand(
      id: table.handNumber,
      startedAt: _now,
      button: table.button,
      sb: table.smallBlind,
      bb: table.bigBlind,
      sbSeat: seats == 2 ? table.button : (table.button + 1) % seats,
      bbSeat:
          seats == 2 ? (table.button + 1) % seats : (table.button + 2) % seats,
      seats: [
        for (final p in table.players)
          HHSeat(
            seat: p.id,
            name: p.name,
            stack: table.stacksAtStart[p.id],
            isHero: p.isHero,
            position: p.position,
          ),
      ],
      holes: {0: table.players[0].hole},
    );
  }

  static String _resumedCaption(TableState t) {
    final street = switch (t.street) {
      Street.preflop => 'pre-flop',
      Street.flop => 'flop',
      Street.turn => 'turn',
      Street.river => 'river',
      Street.showdown => 'showdown',
    };
    return 'Resumed — Hand #${t.handNumber}, $street';
  }

  /// Called by the table on its first frame: deals the abandoned hand's
  /// replacement, or nothing at all.
  void ensureHand() {
    if (!state.needsFreshHand) return;
    final roster = _restoredRoster;
    _restoredRoster = null;
    state = state.copyWith(needsFreshHand: false);
    if (roster == null) return;

    final base = createTable(_configFor(state.options), rng: _rng);
    final table = base.clone();
    for (var i = 0; i < table.players.length && i < roster.length; i++) {
      final saved = roster[i];
      final p = table.players[i];
      p.name = saved.name;
      p.archetype = saved.archetype;
      p.dials = saved.dials;
      p.stack = saved.stack > 0 ? saved.stack : table.config.startingStack;
      p.handsSeen = saved.handsSeen;
      p.vpipCount = saved.vpipCount;
      p.pfrCount = saved.pfrCount;
    }
    table.handNumber = state.counters.hands;
    state = state.copyWith(table: table, active: true);
    deal();
  }

  /// Clears the 2 s restore caption (§4.14).
  void clearResumeCaption() => state = state.copyWith(clearResumeCaption: true);

  /* -------------------------------------------------------- session set-up */

  GameConfig _configFor(TableOptions o) => GameConfig(
    seats: o.seats,
    startingStack: kStartingStack,
    smallBlind: kSmallBlind,
    bigBlind: kBigBlind,
    ante: o.ante,
  );

  static double _jitter(
    double v,
    double frac,
    double lo,
    double hi,
    Random rng,
  ) => min(hi, max(lo, v * (1 - frac + rng.nextDouble() * 2 * frac)));

  /// Port §4.1. `opts == null` uses the last saved table options.
  void newSession([TableOptions? opts]) {
    _cancelLoop();
    _cancelAutoDeal();
    final store = ref.read(tableOptionsStoreProvider);
    final options = opts ?? store.load();
    unawaited(store.save(options));

    final rng = _rng;
    final table = createTable(_configFor(options), rng: rng).clone();
    for (final p in table.players) {
      if (p.isHero) continue;
      final archetype = kArchePool[rng.nextInt(kArchePool.length)];
      final cfg = kArchetypes[archetype]!;
      p.archetype = archetype;
      p.dials = Dials(
        aggression: _jitter(cfg.aggression, 0.20, 0.05, 0.95, rng),
        stickiness: _jitter(cfg.stickiness, 0.20, 0.05, 0.95, rng),
        cbetFlop: _jitter(cfg.cbetFlop, 0.15, 20, 95, rng),
      );
    }

    _reviewSeq = 1;
    _currentHH = null;
    _restoredRoster = null;
    state = SessionState(
      table: table,
      options: options,
      active: true,
      startedAt: _now,
    );
    deal();
  }

  /* ------------------------------------------------------------------ deal */

  /// Port §4.2.
  void deal() {
    final current = state.table;
    if (current == null || !state.active) return;
    _cancelLoop();
    _cancelAutoDeal();

    if (current.players[0].stack <= 0) {
      // The hero is never auto-rebought: a bust ends the session (§4.12).
      state = state.copyWith(sessionEnded: true, busted: true);
      return;
    }

    final pre = current.clone();
    final rebought = <int>{};
    for (final p in pre.players) {
      if (!p.isHero && p.stack <= 0) {
        p.stack = pre.config.startingStack;
        rebought.add(p.id);
      }
    }

    final next = startHand(pre, rng: _rng);
    final seats = next.config.seats;
    _currentHH = HHHand(
      id: next.handNumber,
      startedAt: _now,
      button: next.button,
      sb: next.smallBlind,
      bb: next.bigBlind,
      sbSeat: seats == 2 ? next.button : (next.button + 1) % seats,
      bbSeat:
          seats == 2 ? (next.button + 1) % seats : (next.button + 2) % seats,
      seats: [
        for (final p in next.players)
          HHSeat(
            seat: p.id,
            name: p.name,
            stack: next.stacksAtStart[p.id],
            isHero: p.isHero,
            position: p.position,
          ),
      ],
      holes: {0: next.players[0].hole},
    );

    state = state.copyWith(
      table: next,
      reviewLog: const [],
      clearActiveReview: true,
      clearPendingBlocking: true,
      clearLastActor: true,
      clearAutoDeal: true,
      paused: false,
      thinking: false,
      coachComputing: false,
      rebought: rebought,
      skipping: false,
    );
    unawaited(_persist());
    _maybeAutoLoop();
  }

  /* ---------------------------------------------------------- applying one */

  TableState _applyStep(int seat, Action action, [List<HandLabel>? range]) {
    final t = state.table!;
    _recordAction(t, seat, action);
    final next = applyAction(t, seat, action);
    if (range != null) next.botRanges[seat] = range;

    final label =
        next.players[seat].lastAction?.label ?? _fallbackLabel(t, seat, action);
    state = state.copyWith(
      table: next,
      lastActorSeat: seat,
      lastActorLabel: label,
    );
    if (next.phase == GamePhase.handOver) _finalizeHand(next);
    return next;
  }

  static String _fallbackLabel(TableState t, int seat, Action action) {
    final p = t.players[seat];
    final la = legalActions(t);
    final allIn = switch (action.type) {
      ActionType.call => la.callAmount >= p.stack,
      ActionType.bet ||
      ActionType.raise => (action.amount ?? 0) >= p.committed + p.stack,
      _ => false,
    };
    if (allIn) return 'All-In';
    return switch (action.type) {
      ActionType.fold => 'Fold',
      ActionType.check => 'Check',
      ActionType.call => 'Call',
      ActionType.bet => 'Bet',
      ActionType.raise => 'Raise',
      ActionType.post => 'Post',
    };
  }

  /* ---------------------------------------------------- hand-history (§4.7) */

  void _recordAction(TableState t, int seat, Action action) {
    final hh = _currentHH;
    if (hh == null) return;
    final p = t.players[seat];
    final la = legalActions(t);
    var amount = 0;
    var allIn = false;
    switch (action.type) {
      case ActionType.call:
        amount = la.callAmount;
        allIn = amount >= p.stack;
      case ActionType.bet:
      case ActionType.raise:
        amount = action.amount ?? 0;
        allIn = amount >= p.committed + p.stack;
      default:
        break;
    }
    hh.actions.add(
      HHAction(
        street: t.street,
        seat: seat,
        name: p.name,
        type: action.type,
        amount: amount,
        allIn: allIn,
      ),
    );
  }

  void _finalizeHand(TableState next) {
    final summary = next.summary;
    final hh = _currentHH;
    var counters = state.counters;
    var history = state.history;

    if (hh != null) {
      hh.board = List<Card>.of(next.board);
      hh.potResults = List<PotResult>.of(summary?.potResults ?? const []);
      hh.heroNet = summary?.heroNetChips ?? 0;
      for (final p in next.players) {
        hh.holes[p.id] = p.hole;
      }
      _currentHH = null;

      final net = summary?.heroNetChips ?? 0;
      counters = counters.copyWith(
        hands: counters.hands + 1,
        netChips: counters.netChips + net,
        biggestWinChips: max(counters.biggestWinChips, net),
        biggestLossChips: min(counters.biggestLossChips, net),
      );
      history = [...history, hh];
    }

    unawaited(ref.read(playGoalsStoreProvider).record(ActivityKind.hand));

    if (summary != null) {
      final bb = next.bigBlind;
      final heroWon = summary.potResults.any((p) => p.winners.contains(0));
      unawaited(
        ref
            .read(statsRepositoryProvider)
            .persistHand(
              HandRecord(
                n: next.handNumber,
                netBb: summary.heroNetChips / bb,
                potBb:
                    summary.potResults.fold<num>(0, (a, p) => a + p.amount) /
                    bb,
                showdown: summary.showdown.isNotEmpty,
                won: heroWon,
                archetypes: [
                  for (final p in next.players)
                    if (!p.isHero &&
                        p.archetype != null &&
                        p.committedTotal > bb)
                      p.archetype!,
                ],
                position: next.players[0].position,
                sawFlop: next.players[0].foldedStreet != Street.preflop,
                handJson: hh == null ? null : _handJson(hh),
                ts: _now,
              ),
              summary.heroNetChips,
            ),
      );
    }

    state = state.copyWith(counters: counters, history: history);
    unawaited(_persist());
    _scheduleAutoDeal();
  }

  /// The stored payload carries this hand's coach notes (§16.4).
  String _handJson(HHHand hh) {
    final json = hh.toJson();
    json['coachNotes'] = [
      for (final r in state.reviewLog)
        if (r.kind == ReviewKind.decision) _noteRecord(r).toJson(),
    ];
    return encodeJsonMap(json);
  }

  CoachNoteRecord _noteRecord(CoachReview r) => CoachNoteRecord(
    street: (state.table?.street ?? Street.preflop).label,
    action: r.title,
    verdict: r.verdict.label,
    title: r.title,
    plain: r.plain ?? r.text,
    text: r.text,
    steps: r.steps ?? const [],
    expert: r.expert?.join('\n'),
    equity: r.equity,
    potOdds: r.potOdds,
    evBb: r.evChips == null ? null : r.evChips! / state.bigBlind,
    villainName: r.villainName,
    villainRange: r.villainRange,
  );

  /* ------------------------------------------------------------ hero acts */

  /// Port §4.6. The action is applied immediately; the coach runs after.
  Future<void> heroAction(Action action) async {
    final t = state.table;
    if (t == null || t.phase != GamePhase.betting || t.toAct != 0) return;
    if (state.loopBlocked) return;

    final id = _reviewSeq++;
    final coachOn = _coachOn;
    ref.read(hapticsProvider).actionCommitted();

    _applyStep(0, action);
    unawaited(_persist()); // §4.14: after EVERY hero action.
    _maybeAutoLoop();
    if (!coachOn) return;

    state = state.copyWith(coachComputing: true);
    final review = await ref
        .read(equityServiceProvider)
        .evaluateHero(t, action, id, settings: _settings.coachSettings);
    if (!_alive) return;
    state = state.copyWith(coachComputing: false);

    if (review == null) {
      _noteCoachFailure(t);
      return;
    }

    // §4.8: a verdict that resolves after the hand changed is recorded but
    // never shown as a chip.
    if (state.table?.handNumber == t.handNumber) {
      _pushReview(review);
    }

    if (review.kind != ReviewKind.decision) return;
    _recordDecision(t, action, review);
  }

  void _noteCoachFailure(TableState t) {
    final service = ref.read(equityServiceProvider);
    if (service.coachFailures < 2) return;
    // §14: a second failure switches the coach off for this session only.
    state = state.copyWith(coachOffThisSession: true);
    service.resetCoachFailures();
  }

  void _recordDecision(TableState t, Action action, CoachReview review) {
    final bb = t.bigBlind;
    final evBb = (review.evChips ?? 0) / bb;
    final counters = state.counters;
    final label = '${t.street.label} ${action.type.label}';
    // Desktop parity (`SessionSummaryModal.tsx:35-36`): "best" is the highest
    // EV among the **great** plays and "costliest" the lowest among the
    // **mistakes**. Ranking every coached decision together made §4.13 call a
    // flagged mistake the session's best play.
    final isGreat = review.verdict == Verdict.great;
    final isMistake = review.verdict == Verdict.mistake;
    final newBest =
        isGreat && (counters.bestEvBb == null || evBb > counters.bestEvBb!);
    final newWorst =
        isMistake && (counters.worstEvBb == null || evBb < counters.worstEvBb!);
    state = state.copyWith(
      counters: counters.copyWith(
        coachedDecisions: counters.coachedDecisions + 1,
        flaggedDecisions: counters.flaggedDecisions + (isMistake ? 1 : 0),
        bestEvBb: newBest ? evBb : counters.bestEvBb,
        bestEvLabel: newBest ? label : counters.bestEvLabel,
        worstEvBb: newWorst ? evBb : counters.worstEvBb,
        worstEvLabel: newWorst ? label : counters.worstEvLabel,
      ),
    );

    unawaited(
      ref
          .read(statsRepositoryProvider)
          .persistDecision(
            DecisionRecord(
              verdict: review.verdict.label,
              action: action.type.label,
              equity: review.equity ?? 0,
              potOdds: review.potOdds ?? 0,
              evBb: evBb,
              street: t.street.label,
              villainArchetype: review.villainArchetype?.label,
              position: t.players[0].position.label,
              ts: _now,
            ),
          ),
    );

    if (review.verdict == Verdict.mistake) {
      unawaited(
        ref.read(playLeakQueueProvider).add(_leakSpot(t, action, review)),
      );
    }
  }

  /// Port §4.6's leak capture, verbatim.
  LeakSpot _leakSpot(TableState t, Action action, CoachReview review) {
    final la = legalActions(t);
    final bb = t.bigBlind;
    final best = switch (action.type) {
      ActionType.call => DrillAction.fold,
      ActionType.fold => DrillAction.call,
      ActionType.check => DrillAction.bet,
      ActionType.bet => DrillAction.check,
      _ => DrillAction.fold,
    };
    final options =
        la.toCall > 0
            ? <DrillOption>[
              const DrillOption(action: DrillAction.fold, label: 'Fold'),
              DrillOption(
                action: DrillAction.call,
                label: 'Call ${jsToFixed(la.callAmount / bb, 1)} bb',
                amount: la.callAmount.toDouble(),
              ),
              DrillOption(
                action: DrillAction.raise,
                label: 'Raise',
                amount: jsRound((t.pot + la.callAmount).toDouble()),
              ),
            ]
            : <DrillOption>[
              const DrillOption(action: DrillAction.check, label: 'Check'),
              DrillOption(
                action: DrillAction.bet,
                label: 'Bet',
                amount: jsRound(t.pot * 0.66),
              ),
            ];
    return LeakSpot(
      id: '${t.handNumber}-${t.street.label}-$_now',
      street: t.street,
      heroPos: t.players[0].position,
      hole: List<Card>.of(t.players[0].hole ?? const []),
      board: List<Card>.of(t.board),
      pot: t.pot,
      toCall: la.callAmount,
      bb: bb,
      oppActive: [
        for (final p in t.players)
          if (!p.isHero && !p.hasFolded) p.position,
      ],
      options: options,
      best: best,
      rationale: review.text,
      equity: review.equity,
      potOdds: review.potOdds,
      ts: _now,
    );
  }

  /* ------------------------------------------------------------ the coach */

  void _pushReview(CoachReview review) {
    final log = [...state.reviewLog, review];
    ref.read(hapticsProvider).verdict(review.verdict);
    if (review.blocking) {
      // §4.8: pause immediately. If a surface is open the note queues instead
      // of replacing it; the queue holds exactly one.
      if (state.surfacesOpen > 0) {
        state = state.copyWith(
          reviewLog: log,
          paused: true,
          pendingBlocking: review,
        );
      } else {
        state = state.copyWith(
          reviewLog: log,
          paused: true,
          activeReviewId: review.id,
        );
      }
      _cancelLoop();
      return;
    }
    state = state.copyWith(reviewLog: log, activeReviewId: review.id);
  }

  /// The chip's 4 s / 8 s lifetime elapsed: fold it into the badge.
  void dismissChip() => state = state.copyWith(clearActiveReview: true);

  /// P3's "Got it" / a non-blocking note's "Close" (port §4.10).
  void dismissReview() {
    final wasBlocking = state.activeReview?.blocking ?? false;
    state = state.copyWith(
      clearActiveReview: true,
      paused: wasBlocking ? false : state.paused,
    );
    if (wasBlocking) _maybeAutoLoop();
  }

  void reopenReview([int? id]) {
    final target =
        id ?? (state.reviewLog.isEmpty ? null : state.reviewLog.last.id);
    state = state.copyWith(
      activeReviewId: target,
      clearActiveReview: target == null,
    );
  }

  /// A sheet / modal opened or closed over the table. While one is open the
  /// auto loop is off; closing it releases a queued blocking note (§4.8).
  void setSurfaceOpen(bool open) {
    final count = max(0, state.surfacesOpen + (open ? 1 : -1));
    state = state.copyWith(surfacesOpen: count);
    if (open) {
      _cancelLoop();
      return;
    }
    if (count > 0) return;
    final queued = state.pendingBlocking;
    if (queued != null) {
      state = state.copyWith(
        clearPendingBlocking: true,
        activeReviewId: queued.id,
        paused: true,
      );
      return;
    }
    _maybeAutoLoop();
  }

  /// §4.10. Uses the remembered action label so the title never degrades.
  void explainLastBotMove() {
    final t = state.table;
    final seat = state.lastActorSeat;
    if (t == null || seat == null || seat == 0) return;
    final player = t.players[seat].clone();
    if (player.archetype == null) return;
    player.lastAction ??= PlayerLastAction(
      state.lastActorLabel ?? 'move',
      t.street,
    );
    if (state.lastActorLabel != null) {
      player.lastAction = PlayerLastAction(state.lastActorLabel!, t.street);
    }
    final review = botMoveReview(t, player, _reviewSeq++);
    if (review == null) return;
    state = state.copyWith(
      reviewLog: [...state.reviewLog, review],
      activeReviewId: review.id,
    );
  }

  /* -------------------------------------------------------------- stepping */

  /// Port §4.8 — exactly one bot action.
  void stepBot() {
    if (_consumePause()) return;
    if (state.loopBlocked) return;
    final t = state.table;
    if (t == null ||
        t.phase != GamePhase.betting ||
        t.toAct == null ||
        t.toAct == 0) {
      return;
    }
    final decision = decideBot(t, t.toAct!, rng: _rng);
    _applyStep(t.toAct!, decision.action, decision.range);
  }

  /* ----------------------------------------------------------- the auto loop */

  void _cancelLoop() {
    _loopToken++;
    _loopTimer?.cancel();
    _loopTimer = null;
    _skipTimer?.cancel();
    _skipTimer = null;
    if (state.thinking || state.skipping) {
      state = state.copyWith(thinking: false, skipping: false);
    }
  }

  /// Port §4.9. Also called after every deal, hero action, dismissed blocking
  /// note and pace change.
  void _maybeAutoLoop() {
    if (_settings.paceMode != PaceMode.auto) return;
    _scheduleLoop(Duration(milliseconds: _settings.speedMs));
  }

  void _scheduleLoop(Duration delay) {
    final token = ++_loopToken;
    _loopTimer?.cancel();
    _loopTimer = Timer(delay, () => _loopStep(token, delay));
  }

  void _loopStep(int token, Duration delay) {
    if (token != _loopToken || !_alive) return;
    if (_settings.paceMode != PaceMode.auto) {
      state = state.copyWith(thinking: false);
      return;
    }
    if (state.loopBlocked) {
      state = state.copyWith(thinking: false);
      return;
    }
    final t = state.table;
    if (t == null ||
        t.phase != GamePhase.betting ||
        t.toAct == null ||
        t.toAct == 0) {
      state = state.copyWith(thinking: false);
      return;
    }
    state = state.copyWith(thinking: true);
    final decision = decideBot(t, t.toAct!, rng: _rng);
    final next = _applyStep(t.toAct!, decision.action, decision.range);
    if (next.phase == GamePhase.handOver || next.toAct == 0) {
      state = state.copyWith(thinking: false);
      return;
    }
    _loopTimer = Timer(
      Duration(milliseconds: _settings.speedMs),
      () => _loopStep(token, delay),
    );
  }

  /// `⏭` (§4.5 D, and §4.5 C once the hero is out): run the remaining bot
  /// actions at 120 ms without changing any ordering.
  void skipToMyTurn() => _runCadence(kSkipCadence);

  /// Hold "Next action" (§4.5 C): bots act at the Fast delay while held.
  void startFastForward() => _runCadence(kFastForwardCadence);

  void stopFastForward() {
    _skipTimer?.cancel();
    _skipTimer = null;
    if (state.skipping) state = state.copyWith(skipping: false);
    ref.read(hapticsProvider).actionCommitted();
  }

  void _runCadence(Duration cadence) {
    if (state.loopBlocked) return;
    _skipTimer?.cancel();
    state = state.copyWith(skipping: true);
    void tick() {
      if (!_alive) return;
      final t = state.table;
      if (state.loopBlocked ||
          t == null ||
          t.phase != GamePhase.betting ||
          t.toAct == null ||
          t.toAct == 0) {
        _skipTimer = null;
        state = state.copyWith(skipping: false);
        ref.read(hapticsProvider).actionCommitted();
        return;
      }
      final decision = decideBot(t, t.toAct!, rng: _rng);
      _applyStep(t.toAct!, decision.action, decision.range);
      _skipTimer = Timer(cadence, tick);
    }

    _skipTimer = Timer(cadence, tick);
  }

  /* ------------------------------------------------------- pause / pace */

  /// Tap the felt in Auto, or the action row's Pause button (§4.5 D).
  void togglePause() {
    if (state.paused) {
      state = state.copyWith(paused: false);
      _maybeAutoLoop();
    } else {
      _cancelLoop();
      state = state.copyWith(paused: true);
    }
  }

  /// Backgrounding pauses immediately; the first tap resumes after 700 ms
  /// so the user can re-orient (§4.6).
  void pauseForBackground() {
    if (state.paused) return;
    _cancelLoop();
    state = state.copyWith(paused: true);
  }

  void resumeAfterBackground() {
    if (!state.paused) return;
    state = state.copyWith(paused: false);
    if (_settings.paceMode == PaceMode.auto) {
      _scheduleLoop(const Duration(milliseconds: 700));
    }
  }

  /// The first table gesture after a pause only lifts the pause — §4.6/§4.14:
  /// "the first tap re-enables the loop after 700 ms so the user can
  /// re-orient". Without this a Manual-pace session restored from a snapshot
  /// (which always resumes paused) could never be advanced at all.
  bool _consumePause() {
    if (!state.paused) return false;
    state = state.copyWith(paused: false);
    if (_settings.paceMode == PaceMode.auto) {
      _scheduleLoop(const Duration(milliseconds: 700));
    }
    return true;
  }

  /// The felt was tapped somewhere that is not a prop (§4.5 C/D).
  void tapFelt() {
    if (_consumePause()) return;
    if (state.loopBlocked) return;
    if (_settings.paceMode == PaceMode.auto) {
      togglePause();
      return;
    }
    stepBot();
  }

  Future<void> setPace(PaceMode mode) async {
    await ref.read(settingsProvider.notifier).update(paceMode: mode);
    _cancelLoop();
    if (mode == PaceMode.auto) _maybeAutoLoop();
  }

  Future<void> setSpeed(int ms) =>
      ref.read(settingsProvider.notifier).update(speedMs: ms);

  Future<void> setCoachEnabled(bool value) async {
    if (value) state = state.copyWith(coachOffThisSession: false);
    await ref.read(settingsProvider.notifier).update(coachEnabled: value);
  }

  Future<void> setAutoDeal(bool value) async {
    await ref.read(settingsProvider.notifier).update(autoDeal: value);
    if (!value) cancelAutoDeal();
  }

  /* ------------------------------------------------------------ auto-deal */

  void _scheduleAutoDeal() {
    if (!_settings.autoDeal || _settings.paceMode != PaceMode.auto) return;
    _autoDealTimer?.cancel();
    state = state.copyWith(
      autoDealDeadline: _now + kAutoDealCountdown.inMilliseconds,
    );
    _autoDealTimer = Timer(kAutoDealCountdown, () {
      if (!_alive || state.autoDealDeadline == null) return;
      state = state.copyWith(clearAutoDeal: true);
      deal();
    });
  }

  /// Touching the results card cancels the countdown (§4.12).
  void cancelAutoDeal() {
    if (state.autoDealDeadline == null) return;
    _autoDealTimer?.cancel();
    _autoDealTimer = null;
    state = state.copyWith(clearAutoDeal: true);
  }

  void _cancelAutoDeal() {
    _autoDealTimer?.cancel();
    _autoDealTimer = null;
  }

  /* ----------------------------------------------------- end of a session */

  /// Port §4.4: opens P10. The session stays active.
  void endSession() {
    _cancelLoop();
    _cancelAutoDeal();
    state = state.copyWith(sessionEnded: true);
  }

  /// P10's ✕ — the session continues (§4.13).
  void closeSummary() {
    if (state.busted) return;
    state = state.copyWith(sessionEnded: false);
    _maybeAutoLoop();
  }

  /// P10's "Done": the session is written to the `sessions` table, the
  /// snapshot is cleared and the lobby shows Recent sessions. Returns the
  /// `sessions` row id so the caller can push the read-only P10 for it.
  Future<int?> finishSession() => closeCurrentSession();

  /// Records the live session, clears the snapshot and resets to "no session".
  /// Safe to call with nothing running (returns null and changes nothing).
  Future<int?> closeCurrentSession() async {
    final id = await _recordEndedSession();
    _cancelLoop();
    _cancelAutoDeal();
    _currentHH = null;
    await _sessions.clearSnapshot();
    if (!_alive) return id;
    state = SessionState(options: state.options);
    return id;
  }

  Future<int?> _recordEndedSession() async {
    if (!state.active) return null;
    final counters = state.counters;
    final id = await _sessions.recordEndedSession(
      SessionRecord(
        startedAt: state.startedAt,
        endedAt: _now,
        seats: state.options.seats,
        ante: state.options.ante,
        hands: counters.hands,
        netBb: state.netBb,
        bb100: state.bb100,
        mistakes: counters.flaggedDecisions,
        summary: {
          'counters': counters.toJson(),
          'startedAt': state.startedAt,
          'endedAt': _now,
          'seats': state.options.seats,
          'hands': [for (final h in state.history) h.toJson()],
        },
      ),
    );
    ref.read(sessionsRevisionProvider.notifier).bump();
    return id;
  }

  /// The lobby's "New table" over a paused session, and P10's "New session":
  /// the old session is summarised and closed first (§4.1). Returns the closed
  /// session's row id so the lobby can show its P10 before dealing.
  Future<int?> startNewTable(TableOptions options) async {
    final id = state.active ? await _recordEndedSession() : null;
    await _sessions.clearSnapshot();
    if (!_alive) return id;
    newSession(options);
    return id;
  }

  /* ---------------------------------------------------- snapshot (§4.14) */

  Future<void> _persist() async {
    if (!state.active) return;
    final table = state.table;
    final savedAt = _now;
    final ok = await _sessions.saveSnapshot(
      SessionSnapshot(
        options: state.options,
        table: table,
        players: table?.players ?? const [],
        session: {
          'startedAt': state.startedAt,
          'counters': state.counters.toJson(),
          'history': [for (final h in state.history) h.toJson()],
          // §4.14: the snapshot restores the exact table, so it has to carry
          // the hand-in-progress too. Without it a resumed mid-hand session
          // finished the hand with no `HHHand`, and `_finalizeHand` skipped
          // the counters, the history and the stored hand JSON entirely.
          if (_currentHH != null) 'currentHand': _currentHH!.toJson(),
        },
        playSettings: _settings,
        reviewLog: [
          for (final r in state.reviewLog)
            if (r.kind == ReviewKind.decision) _noteRecord(r).toJson(),
        ],
        savedAt: savedAt,
      ),
    );
    if (!_alive) return;
    state = state.copyWith(saveFailed: !ok, savedAt: ok ? savedAt : null);
  }

  /// Leaving the table (`‹`, system back): pause and keep the snapshot.
  void leaveTable() {
    _cancelLoop();
    _cancelAutoDeal();
    state = state.copyWith(paused: true);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

/* ------------------------------------------------------------- selectors */

/// The shell's session signal (§2.1) — replaces the stub in `app_providers`.
final playShellSessionProvider = Provider<ShellSession?>((ref) {
  final s = ref.watch(sessionProvider);
  if (!s.active) return null;
  return ShellSession(hands: s.counters.hands, netBb: s.netBb);
});

/// Cheap watch for "is there a table on screen".
final tableStateProvider = Provider<TableState?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.table)),
);

final legalActionsProvider = Provider<LegalActions?>(
  (ref) => ref.watch(sessionProvider).legal,
);
