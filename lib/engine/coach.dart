/// EV coach — ported 1:1 from the desktop `src/store/gameStore.ts`
/// (`evaluateHero`, `interpretBot`, `scoreGuess`, `villainRangeFor`,
/// `firstOpponentInHand`) plus `coachThresholds` and the coach defaults from
/// `src/store/settingsStore.ts`.
///
/// Every string here is product copy (see docs/TONE.md) and is reproduced
/// verbatim, including the JavaScript number formatting (`Math.round`,
/// `toFixed`, `toLocaleString`) via `format.dart`.
///
/// The equity work is injected: [evaluateHero] takes an [EquityRunner] so the
/// app can run the Monte-Carlo off the UI thread (an isolate) and tests can
/// stub it. [runEquitySync] is the in-process default.
library;

import 'dart:async';
import 'dart:math' as math;

import 'archetypes.dart';
import 'equity.dart';
import 'format.dart';
import 'hand_engine.dart';
import 'notation.dart';
import 'prng.dart';
import 'ranges.dart';
import 'types.dart';

/* ---------------------------------------------------------------- verdicts */

/// Desktop `Verdict`.
enum Verdict {
  mistake('mistake'),
  thin('thin'),
  ok('ok'),
  great('great'),
  info('info');

  const Verdict(this.label);
  final String label;

  static Verdict fromLabel(String label) =>
      Verdict.values.firstWhere((v) => v.label == label);

  /// Null rather than a throw, for labels read back off disk.
  static Verdict? fromLabelOrNull(String? label) {
    for (final v in Verdict.values) {
      if (v.label == label) return v;
    }
    return null;
  }

  /// How loudly a verdict asks for attention when a whole hand is reduced to
  /// one mark in a list. "Reasonable" and a bot read say nothing worth one.
  int get severity => switch (this) {
    Verdict.mistake => 3,
    Verdict.thin => 2,
    Verdict.great => 1,
    Verdict.ok || Verdict.info => 0,
  };

  /// The single verdict that stands for a whole hand — the most severe one it
  /// collected — or null when none of them is worth a mark.
  static Verdict? worst(Iterable<Verdict> verdicts) {
    Verdict? worst;
    var best = 0;
    for (final v in verdicts) {
      if (v.severity > best) {
        best = v.severity;
        worst = v;
      }
    }
    return worst;
  }
}

/// `CoachReview.kind`.
enum ReviewKind {
  decision('decision'),
  bot('bot');

  const ReviewKind(this.label);
  final String label;

  static ReviewKind fromLabel(String label) =>
      ReviewKind.values.firstWhere((k) => k.label == label);
}

/// One coach note (desktop `CoachReview`).
class CoachReview {
  const CoachReview({
    required this.id,
    required this.kind,
    required this.blocking,
    required this.verdict,
    required this.title,
    this.equity,
    this.potOdds,
    this.evChips,
    this.villainName,
    this.villainArchetype,
    this.villainRange,
    required this.board,
    this.plain,
    required this.text,
    this.steps,
    this.expert,
    this.opponents,
    this.multiway,
  });

  /// Monotonically increasing per app run (desktop `reviewSeq` starts at 1).
  final int id;
  final ReviewKind kind;

  /// True ⇒ play pauses until the note is dismissed (only bad calls).
  final bool blocking;
  final Verdict verdict;
  final String title;
  final double? equity;
  final double? potOdds;
  final double? evChips;
  final String? villainName;
  final Archetype? villainArchetype;
  final List<HandLabel>? villainRange;
  final List<Card> board;

  /// Layer 1 (TONE.md): plain English, no jargon, chances as counts.
  final String? plain;

  /// Layer 2 summary line (may use poker terms).
  final String text;

  /// Layer 2: the step-by-step derivation.
  final List<String>? steps;

  /// Layer 3: ranges, precision, formulas, methodology.
  final List<String>? expert;
  final int? opponents;
  final bool? multiway;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.label,
    'blocking': blocking,
    'verdict': verdict.label,
    'title': title,
    if (equity != null) 'equity': equity,
    if (potOdds != null) 'potOdds': potOdds,
    if (evChips != null) 'evChips': evChips,
    if (villainName != null) 'villainName': villainName,
    if (villainArchetype != null) 'villainArchetype': villainArchetype!.label,
    if (villainRange != null) 'villainRange': villainRange,
    'board': board,
    if (plain != null) 'plain': plain,
    'text': text,
    if (steps != null) 'steps': steps,
    if (expert != null) 'expert': expert,
    if (opponents != null) 'opponents': opponents,
    if (multiway != null) 'multiway': multiway,
  };

  static CoachReview fromJson(Map<String, Object?> j) => CoachReview(
    id: (j['id'] as num).toInt(),
    kind: ReviewKind.fromLabel(j['kind'] as String),
    blocking: j['blocking'] as bool,
    verdict: Verdict.fromLabel(j['verdict'] as String),
    title: j['title'] as String,
    equity: (j['equity'] as num?)?.toDouble(),
    potOdds: (j['potOdds'] as num?)?.toDouble(),
    evChips: (j['evChips'] as num?)?.toDouble(),
    villainName: j['villainName'] as String?,
    villainArchetype:
        j['villainArchetype'] == null
            ? null
            : Archetype.fromLabel(j['villainArchetype'] as String),
    villainRange: (j['villainRange'] as List?)?.cast<String>(),
    board: (j['board'] as List).cast<String>(),
    plain: j['plain'] as String?,
    text: j['text'] as String,
    steps: (j['steps'] as List?)?.cast<String>(),
    expert: (j['expert'] as List?)?.cast<String>(),
    opponents: (j['opponents'] as num?)?.toInt(),
    multiway: j['multiway'] as bool?,
  );
}

/* ---------------------------------------------------------------- settings */

/// Desktop `CoachStrictness`.
enum CoachStrictness {
  relaxed('relaxed'),
  standard('standard'),
  strict('strict');

  const CoachStrictness(this.label);
  final String label;

  static CoachStrictness fromLabel(String label) => CoachStrictness.values
      .firstWhere((s) => s.label == label, orElse: () => standard);
}

/// Desktop `SimQuality`.
enum SimQuality {
  standard('standard'),
  high('high');

  const SimQuality(this.label);
  final String label;

  static SimQuality fromLabel(String label) => SimQuality.values.firstWhere(
    (s) => s.label == label,
    orElse: () => standard,
  );
}

/// Coach thresholds in big blinds (desktop `coachThresholds` return shape).
class CoachThresholds {
  const CoachThresholds({required this.mistakeBb, required this.foldFlagBb});

  /// EV (bb) below which a call is a (blocking) mistake.
  final double mistakeBb;

  /// EV(call) (bb) a fold must have thrown away before it is flagged.
  final double foldFlagBb;
}

/// Desktop `coachThresholds(s)`: relaxed → {−0.6, 2.5}; strict → {−0.15, 1.0};
/// standard (and anything else) → {−0.3, 1.5}.
CoachThresholds coachThresholds(CoachStrictness s) {
  if (s == CoachStrictness.relaxed) {
    return const CoachThresholds(mistakeBb: -0.6, foldFlagBb: 2.5);
  }
  if (s == CoachStrictness.strict) {
    return const CoachThresholds(mistakeBb: -0.15, foldFlagBb: 1.0);
  }
  return const CoachThresholds(mistakeBb: -0.3, foldFlagBb: 1.5);
}

/// Base Monte-Carlo trials per verdict: `simQuality == "high" ? 4000 : 1600`.
int baseItersFor(SimQuality q) => q == SimQuality.high ? 4000 : 1600;

/// The two app settings the coach reads (desktop `settingsStore` defaults:
/// `coachStrictness: "standard"`, `simQuality: "standard"`).
class CoachSettings {
  const CoachSettings({
    this.strictness = CoachStrictness.standard,
    this.simQuality = SimQuality.standard,
  });

  final CoachStrictness strictness;
  final SimQuality simQuality;

  static const CoachSettings defaults = CoachSettings();

  CoachThresholds get thresholds => coachThresholds(strictness);
  int get baseIters => baseItersFor(simQuality);

  CoachSettings copyWith({
    CoachStrictness? strictness,
    SimQuality? simQuality,
  }) => CoachSettings(
    strictness: strictness ?? this.strictness,
    simQuality: simQuality ?? this.simQuality,
  );
}

/* ------------------------------------------------------- villain + reads */

/// Desktop `villainRangeFor`: the range the bot brain says it represents,
/// else the archetype/position preflop play range, else `[]`.
List<HandLabel> villainRangeFor(TableState state, Player p) {
  final stored = state.botRanges[p.id];
  if (stored != null && stored.isNotEmpty) return stored;
  final arche = p.archetype;
  if (arche != null) {
    final cfg = kArchetypes[arche]!;
    return buildPreflopRanges(cfg.vpip, cfg.pfr, p.position).play.toList();
  }
  return <HandLabel>[];
}

/// Desktop `firstOpponentInHand`: first non-hero, non-folded seat; fallback 1.
int firstOpponentInHand(TableState state) {
  for (final p in state.players) {
    if (!p.isHero && !p.hasFolded) return p.id;
  }
  return 1;
}

/// Desktop `interpretBot` — verbatim bot-move interpretations.
String interpretBot(Player p) {
  final a = p.archetype;
  if (a == null) return '';
  final label = p.lastAction?.label ?? 'acts';
  if (label == 'Fold') {
    return '${p.name} folds — their range no longer matters this hand.';
  }
  if (label == 'Check') {
    return 'A check from ${p.name} usually means a weak hand — or keeping the pot small. Consider betting to take the pot now.';
  }
  if (label == 'Call' || label == 'All-In') {
    if (a == Archetype.station) {
      return '${p.name} (Station) calls with almost anything — their possible hands stay very wide and weak. Bet your good hands relentlessly; never bluff.';
    }
    if (a == Archetype.nit) {
      return "Even a Nit's call means a fairly strong hand — though they'd raise their very best. Slow down with so-so hands.";
    }
    if (a == Archetype.lag) {
      return '${p.name} (LAG) calls with lots of hands, often planning to steal the pot later — keep betting your good hands; expect them to call you down with medium ones.';
    }
    return "A call keeps ${p.name}'s possible hands wide — their strongest hands included — proceed with caution.";
  }
  // Bet / Raise
  if (a == Archetype.nit) {
    return 'A raise from a Nit is a red flag — expect a premium. Fold your marginal hands.';
  }
  if (a == Archetype.station) {
    return "${p.name} (Station) almost never raises — when they do, it's usually close to the best possible hand.";
  }
  if (a == Archetype.lag) {
    return "${p.name} (LAG) raises very wide; this is often a bluff or a bet with only a slim edge. Don't fold too often.";
  }
  return '${p.name} (TAG) raises mostly genuinely strong hands, few bluffs. Take it seriously unless you have a strong hand too.';
}

/// The "Bot read" note built by the desktop `explainLastBotMove` for a bot
/// seat (`null` when the seat has no archetype, e.g. the hero).
CoachReview? botMoveReview(TableState state, Player p, int id) {
  final arche = p.archetype;
  if (arche == null) return null;
  return CoachReview(
    id: id,
    kind: ReviewKind.bot,
    blocking: false,
    verdict: Verdict.info,
    title: "${p.name}'s ${(p.lastAction?.label ?? 'move').toLowerCase()}",
    villainName: p.name,
    villainArchetype: arche,
    villainRange: villainRangeFor(state, p),
    board: List<Card>.of(state.board),
    text: interpretBot(p),
  );
}

/* -------------------------------------------------------------- scoreGuess */

/// Result of [scoreGuess]: combo-weighted precision / recall / F1.
class GuessScore {
  const GuessScore({
    required this.accuracy,
    required this.precision,
    required this.recall,
  });

  /// F1 of precision and recall.
  final double accuracy;
  final double precision;
  final double recall;

  @override
  String toString() =>
      'GuessScore(accuracy: $accuracy, precision: $precision, recall: $recall)';
}

/// Desktop `scoreGuess(painted, actual)` — duplicates are ignored (sets).
GuessScore scoreGuess(List<HandLabel> painted, List<HandLabel> actual) {
  final pSet = painted.toSet();
  final aSet = actual.toSet();
  int inter = 0;
  for (final l in pSet) {
    if (aSet.contains(l)) inter += comboCount(l);
  }
  final pc = combosInSet(pSet);
  final ac = combosInSet(aSet);
  final precision = pc > 0 ? inter / pc : 0.0;
  final recall = ac > 0 ? inter / ac : 0.0;
  final f1 =
      precision + recall > 0
          ? (2 * precision * recall) / (precision + recall)
          : 0.0;
  return GuessScore(accuracy: f1, precision: precision, recall: recall);
}

/* ------------------------------------------------------------ equity hook */

/// Which desktop facade call the coach would make.
enum EquityMode {
  field('field'),
  range('range'),
  random('random');

  const EquityMode(this.label);
  final String label;

  static EquityMode fromLabel(String label) =>
      EquityMode.values.firstWhere((m) => m.label == label);
}

/// One equity job requested by [evaluateHero]. Plain data (strings, ints,
/// lists) so it can cross an isolate boundary as-is or via [toJson].
class EquityRequest {
  const EquityRequest({
    required this.hero,
    required this.board,
    required this.mode,
    required this.range,
    required this.opponents,
    required this.iters,
    required this.seed,
  });

  /// Hero hole cards (two).
  final List<Card> hero;
  final List<Card> board;
  final EquityMode mode;

  /// Villain range labels (only used by [EquityMode.range]).
  final List<HandLabel> range;

  /// Live opponents (only used by [EquityMode.field]).
  final int opponents;
  final int iters;
  final int seed;

  /// Run the job synchronously with the engine's own equity functions — the
  /// same dispatch as the desktop `run(iters, seed)` closure.
  EquityResult run() {
    final h = (hero[0], hero[1]);
    switch (mode) {
      case EquityMode.field:
        return equityVsFieldCards(
          h,
          board,
          opponents,
          iters: iters,
          seed: seed,
        );
      case EquityMode.range:
        return equityVsRangeCards(h, board, range, iters: iters, seed: seed);
      case EquityMode.random:
        return equityVsRandomCards(h, board, iters: iters, seed: seed);
    }
  }

  Map<String, Object?> toJson() => {
    'hero': hero,
    'board': board,
    'mode': mode.label,
    'range': range,
    'opponents': opponents,
    'iters': iters,
    'seed': seed,
  };

  static EquityRequest fromJson(Map<String, Object?> j) => EquityRequest(
    hero: (j['hero'] as List).cast<String>(),
    board: (j['board'] as List).cast<String>(),
    mode: EquityMode.fromLabel(j['mode'] as String),
    range: (j['range'] as List).cast<String>(),
    opponents: (j['opponents'] as num).toInt(),
    iters: (j['iters'] as num).toInt(),
    seed: (j['seed'] as num).toInt(),
  );

  @override
  String toString() =>
      'EquityRequest(${mode.label}, ${hero.join()} on ${board.join()}, '
      'iters $iters, seed $seed)';
}

/// Injected equity runner: the app wraps it in an isolate, tests stub it.
/// Throwing makes the coach fall back to equity 0.5 (as the desktop's
/// `try/catch` does).
typedef EquityRunner = FutureOr<EquityResult> Function(EquityRequest request);

/// Default in-process runner.
EquityResult runEquitySync(EquityRequest request) => request.run();

/* ------------------------------------------------------------ evaluateHero */

int _round(double x) => jsRound(x).toInt();

String _fixed(double x, int digits) => jsToFixed(x, digits);

/// Desktop `evaluateHero(state, action, id)`: grade the hero's [action] against
/// the state *before* it is applied. Returns `null` when the coach has
/// nothing to say.
Future<CoachReview?> evaluateHero(
  TableState state,
  Action action,
  int id, {
  CoachSettings settings = CoachSettings.defaults,
  EquityRunner runEquity = runEquitySync,
}) async {
  final hero = state.players[0];
  final hole = hero.hole;
  if (hole == null) return null;
  final la = legalActions(state);
  // Checks are evaluated too (below) — half the game used to be
  // invisible to the coach.

  final villId =
      state.aggressor != null && state.aggressor != 0
          ? state.aggressor!
          : firstOpponentInHand(state);
  final vill = state.players[villId];
  final arche = vill.archetype;
  final cfg = arche != null ? kArchetypes[arche] : null;
  final range = villainRangeFor(state, vill);
  final combos = combosInSet(range);
  final bb = state.bigBlind;
  final heroLabel = cardsToLabel(hole[0], hole[1]);
  final boardStr =
      state.board.isNotEmpty ? state.board.join(' ') : 'a pre-flop board';
  final opponents =
      state.players.where((p) => !p.isHero && !p.hasFolded).length;
  final fieldMode = opponents > 1;
  final oppDesc =
      fieldMode ? 'the $opponents-player field' : "${vill.name}'s range";

  // Price of the decision — known before simulating, and used both for
  // verdicts and to decide whether the estimate needs tightening.
  final costNow =
      action.type == ActionType.check
          ? 0
          : action.type == ActionType.fold || action.type == ActionType.call
          ? la.callAmount
          : (action.amount ?? 0) - hero.committed;
  final finalPotNow = state.pot + costNow;
  final threshold = finalPotNow > 0 ? costNow / finalPotNow : 0.0;

  // Deterministic per decision: same spot + same action = same verdict.
  final seedBase = hashSeed(
    '${state.handNumber}|${state.street.label}|${action.type.label}|${hole.join()}|${state.board.join()}',
  );
  final mode =
      fieldMode
          ? EquityMode.field
          : range.isNotEmpty
          ? EquityMode.range
          : EquityMode.random;
  FutureOr<EquityResult> run(int iters, int seed) => runEquity(
    EquityRequest(
      hero: List<Card>.of(hole),
      board: List<Card>.of(state.board),
      mode: mode,
      range: range,
      opponents: opponents,
      iters: iters,
      seed: seed,
    ),
  );

  final thresholds = settings.thresholds;
  final mistakeBb = thresholds.mistakeBb;
  final foldFlagBb = thresholds.foldFlagBb;
  final baseIters = settings.baseIters;
  double equity = 0.5;
  int trials = 0;
  double se = 0;
  bool exact = false;
  try {
    var r = await run(baseIters, seedBase);
    // Near the break-even line and still noisy? Escalate before judging.
    if (!r.exact && costNow > 0 && (r.equity - threshold).abs() < 2 * r.se) {
      r = await run(baseIters * 4, seedBase + 1);
    }
    equity = r.equity;
    trials = r.samples;
    se = r.se;
    exact = r.exact;
  } catch (_) {
    equity = 0.5;
  }
  final margin = 2 * se; // ~95% confidence half-width
  final pct = _round(equity * 100);
  const baselineNote =
      "Baseline: verdicts grade vs THIS opponent's likely hands (exploitative). Vs a balanced player the answer can differ — most sharply against extreme types like Stations (value-bet wider, never bluff) and Nits (respect their raises).";
  final marginNote =
      exact
          ? "Exact count — every possible holding and runout was enumerated, so there's no simulation noise."
          : 'Simulation precision: ±${_fixed(margin * 100, 1)}% on the equity (${fmtChips(trials)} trials).';
  final sourceLine =
      fieldMode
          ? 'Equity is run against $opponents opponents as random hands ($trials-trial sim) — more players, lower equity.'
          : '${vill.name}${cfg != null ? ' (${cfg.archetype.label})' : ''} range ≈ $combos combos (position + action).';

  final board = List<Card>.of(state.board);

  if (action.type == ActionType.fold) {
    if (la.toCall <= 0) return null;
    final cost = la.callAmount;
    final finalPot = state.pot + cost;
    final potOdds = cost / finalPot;
    final evCall = equity * finalPot - cost;
    // Only flag a fold when the call is profitable even at the
    // pessimistic edge of the estimate — never on simulation noise.
    final evCallLow = (equity - margin) * finalPot - cost;
    if (evCall <= foldFlagBb * bb || evCallLow <= 0) return null;
    return CoachReview(
      id: id,
      kind: ReviewKind.decision,
      villainName: vill.name,
      villainArchetype: arche,
      villainRange: range,
      board: board,
      opponents: opponents,
      multiway: opponents > 1,
      blocking: false,
      verdict: Verdict.mistake,
      title: 'Fold spills value',
      equity: equity,
      potOdds: potOdds,
      evChips: evCall,
      plain:
          'You folded a moneymaker. Calling ${fmtBb(cost, bb)} bb to win a ${fmtBb(finalPot, bb)} bb pot only needs a win ${fmtNeed(potOdds)} — and your hand wins ${fmtTimes(equity)}. That call was worth about +${_fixed(evCall / bb, 1)} bb.',
      text:
          "Against $oppDesc your $heroLabel has $pct% equity and you're getting ${_round(potOdds * 100)}% pot odds — calling is worth about +${_fixed(evCall / bb, 1)} bb.",
      steps: [
        '$heroLabel vs $oppDesc on $boardStr → $pct% equity.',
        'Pot ${state.pot} + call $cost = $finalPot; pot odds = ${_round(potOdds * 100)}%.',
        'EV(call) = $pct% × $finalPot − $cost ≈ +${_fixed(evCall, 0)} chips (${_fixed(evCall / bb, 1)} bb) > EV(fold)=0.',
      ],
      expert: [sourceLine, marginNote, baselineNote],
    );
  }

  final cost =
      action.type == ActionType.call
          ? la.callAmount
          : (action.amount ?? 0) - hero.committed;
  final finalPot = state.pot + cost;
  final potOdds = finalPot > 0 ? cost / finalPot : 0.0;
  final evAction = equity * finalPot - cost;

  if (action.type == ActionType.call) {
    Verdict verdict;
    bool blocking = false;
    String text;
    String plain;
    final priceLine =
        'You paid ${fmtBb(cost, bb)} bb to win a pot of ${fmtBb(finalPot, bb)} bb — you need to win ${fmtNeed(potOdds)}.';
    // A "mistake" needs the call to lose money even at the optimistic
    // edge of the estimate; inside the noise band it's just "close".
    final evActionHigh = (equity + margin) * finalPot - cost;
    if (evAction < mistakeBb * bb && evActionHigh < 0) {
      verdict = Verdict.mistake;
      blocking = true;
      plain =
          '$priceLine Your hand wins ${fmtTimes(equity)} — not enough. Over time this call loses money; folding is better.';
      text =
          'Against $oppDesc your $heroLabel has only $pct% equity, but calling needs ${_round(potOdds * 100)}%. This call costs about ${_fixed(evAction / bb, 1)} bb — folding is better.';
    } else if (evAction < mistakeBb * bb) {
      verdict = Verdict.thin;
      plain =
          'Genuinely too close to call: the numbers say roughly break-even here. Either choice is fine.';
      text =
          "Looks slightly losing (~${_fixed(evAction / bb, 1)} bb), but it's within the simulation's margin of error — either choice is reasonable here.";
    } else if (equity < potOdds + 0.04) {
      verdict = Verdict.thin;
      plain =
          '$priceLine Your hand wins ${fmtTimes(equity)} — just barely enough. A close call, not a mistake.';
      text =
          '$pct% equity vs ~${_round(potOdds * 100)}% needed — a marginal, close call against $oppDesc.';
    } else {
      verdict = equity > 0.7 ? Verdict.great : Verdict.ok;
      plain =
          '$priceLine Your hand wins ${fmtTimes(equity)} — comfortably more than you need. Good call.';
      text =
          '$pct% equity vs $oppDesc, needing ${_round(potOdds * 100)}% — a clear call worth +${_fixed(evAction / bb, 1)} bb.';
    }
    return CoachReview(
      id: id,
      kind: ReviewKind.decision,
      villainName: vill.name,
      villainArchetype: arche,
      villainRange: range,
      board: board,
      opponents: opponents,
      multiway: opponents > 1,
      blocking: blocking,
      verdict: verdict,
      title: 'Your call',
      equity: equity,
      potOdds: potOdds,
      evChips: evAction,
      plain: plain,
      text: text,
      steps: [
        '$heroLabel vs $oppDesc on $boardStr → $pct% equity.',
        'Pot ${state.pot} + your call $cost = $finalPot; pot odds = $cost/$finalPot = ${_round(potOdds * 100)}%.',
        'EV(call) = $pct% × $finalPot − $cost ≈ ${_fixed(evAction, 0)} chips (${_fixed(evAction / bb, 1)} bb). EV(fold) = 0.',
        evAction < 0
            ? 'Because EV < 0, folding is the higher-EV play.'
            : 'Because EV > 0, calling beats folding.',
      ],
      expert: [sourceLine, marginNote, baselineNote],
    );
  }

  if (action.type == ActionType.check) {
    // Only speak up when checking left clear money behind: strong
    // hands any street, medium-strong only on the river (earlier
    // streets can legitimately pot-control).
    if (state.board.length < 3 || equity < 0.65) return null;
    final strong = equity - margin > 0.75;
    if (!strong && state.street != Street.river) return null;
    final betTo = _round(state.pot * 0.66);
    return CoachReview(
      id: id,
      kind: ReviewKind.decision,
      villainName: vill.name,
      villainArchetype: arche,
      villainRange: range,
      board: board,
      opponents: opponents,
      multiway: opponents > 1,
      blocking: false,
      verdict: strong ? Verdict.mistake : Verdict.thin,
      title: 'Missed value',
      equity: equity,
      plain:
          strong
              ? "Your hand wins ${fmtTimes(equity)} — that's a hand that wants to bet. Checking here gives up a clear value bet: when you're ahead this often, put chips in and get paid."
              : 'Your hand wins ${fmtTimes(equity)} — usually strong enough for a small value bet here. Checking is cautious but leaves some money behind.',
      text:
          '$pct% equity checked ${state.street == Street.river ? 'on the river' : 'back'} — a value bet (~$betTo chips) was available.',
      steps: [
        '$heroLabel vs $oppDesc on $boardStr → $pct% equity.',
        'A ~66% pot bet ($betTo) gets called by enough worse hands to profit when you win this often.',
        'Checking wins the same pot but never builds it — EV left behind grows with your win chance.',
      ],
      expert: [
        sourceLine,
        marginNote,
        baselineNote,
        'Post-flop aggression verdicts are heuristic (no solver) — treat as guidance, not gospel.',
      ],
    );
  }

  // bet / raise
  Verdict verdict = Verdict.ok;
  String text;
  String plain;
  // Honest little fold-equity model: opponents continue less often vs
  // bigger bets; a pure bluff needs foldsNeeded to break even.
  final betFrac = costNow / math.max(1, state.pot);
  final continueFrac = math.min(0.75, math.max(0.3, 0.62 - 0.2 * betFrac));
  final pAllFold = math.pow(1 - continueFrac, opponents).toDouble();
  final foldsNeeded = costNow / (state.pot + costNow);
  final evBluff =
      pAllFold * state.pot +
      (1 - pAllFold) * (equity * (state.pot + 2 * costNow) - costNow);
  if (equity + margin < 0.32 && evBluff < -0.75 * bb) {
    return CoachReview(
      id: id,
      kind: ReviewKind.decision,
      villainName: vill.name,
      villainArchetype: arche,
      villainRange: range,
      board: board,
      opponents: opponents,
      multiway: opponents > 1,
      blocking: false,
      verdict: Verdict.mistake,
      title: 'Expensive bluff',
      equity: equity,
      potOdds: potOdds,
      evChips: evBluff,
      plain:
          "A very expensive bluff: if anyone calls, your hand wins only ${fmtTimes(equity)}${opponents > 1 ? ', and with $opponents opponents someone usually calls' : ''}. You'd need folds ${fmtTimes(foldsNeeded)} just to break even — this bet loses money over time.",
      text:
          'Bluffing ${_round(betFrac * 100)}% pot with $pct% equity vs $oppDesc: estimated EV ${_fixed(evBluff / bb, 1)} bb.',
      steps: [
        '$heroLabel vs $oppDesc on $boardStr → $pct% equity when called.',
        'Break-even fold rate = bet / (pot + bet) = ${_round(foldsNeeded * 100)}%.',
        'Assuming each opponent continues ~${_round(continueFrac * 100)}% vs this size, everyone folds only ${_round(pAllFold * 100)}% of the time.',
        'EV ≈ ${_round(pAllFold * 100)}% × ${state.pot} + ${_round((1 - pAllFold) * 100)}% × ($pct% × ${state.pot + 2 * costNow} − $costNow) ≈ ${_fixed(evBluff, 0)} chips.',
      ],
      expert: [
        sourceLine,
        marginNote,
        baselineNote,
        'The fold-equity model is heuristic (fixed continue rates by bet size, no ranges) — aggression verdicts are approximate by design.',
      ],
    );
  }
  if (equity > 0.6) {
    verdict = Verdict.great;
    plain =
        'Betting with the goods: if someone calls, your hand wins ${fmtTimes(equity)}. Money goes in with the best of it — and every fold is profit too.';
    text = 'Strong value — $pct% equity vs $oppDesc. Betting is correct.';
  } else if (equity < 0.38 && cost > state.pot * 0.5) {
    verdict = Verdict.thin;
    plain =
        "This is a bluff: if you get called, your hand only wins ${fmtTimes(equity)}. The bet makes money only when opponents fold — fine as a plan, just know that's the plan.";
    text =
        'Aggressive: only $pct% equity if called. Works as a bluff but relies on folds.';
  } else {
    plain =
        'A solid bet: when called, your hand wins ${fmtTimes(equity)}, and every fold you pick up is pure profit on top.';
    text =
        '$pct% equity vs $oppDesc — a reasonable bet — worse hands may call, and every fold wins you the pot.';
  }
  return CoachReview(
    id: id,
    kind: ReviewKind.decision,
    villainName: vill.name,
    villainArchetype: arche,
    villainRange: range,
    board: board,
    opponents: opponents,
    multiway: opponents > 1,
    blocking: false,
    verdict: verdict,
    title: action.type == ActionType.bet ? 'Your bet' : 'Your raise',
    equity: equity,
    potOdds: potOdds,
    evChips: evAction,
    plain: plain,
    text: text,
    steps: [
      '$heroLabel vs $oppDesc on $boardStr → $pct% equity when called.',
      'A bet also wins when opponents fold — fold equity isn\'t shown here, so treat this as the "called" floor.',
    ],
    expert: [sourceLine, marginNote, baselineNote],
  );
}
