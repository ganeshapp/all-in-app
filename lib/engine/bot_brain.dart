/// Bot decision policy — ported 1:1 from the desktop `src/game/botBrain.ts`.
///
/// Preflop: the real 100bb baseline charts (`lib/data/preflop_charts.g.dart`)
/// drive open / 3-bet / call / fold, with each archetype applying principled
/// deviations (Nit continues tighter, Station calls wide but rarely raises,
/// LAG adds bluffs) — bots are exploitable BY DESIGN, never absurd: premiums
/// never fold preflop, junk never stacks off cold.
/// Postflop: Monte-Carlo hand strength (small synchronous sims) combined with
/// the archetype's aggression and "stickiness" knobs. Also returns the
/// perceived range it is representing, which the store records for the Peek
/// feature.
///
/// Randomness is injected: every `Math.random()` draw of the desktop becomes
/// `rng.nextDouble()` on the [Random] passed to [decideBot] (and the same
/// generator feeds the unseeded equity samples), so tests are deterministic.
library;

import 'dart:math';

import '../data/preflop_charts.g.dart';
import 'archetypes.dart';
import 'cards.dart';
import 'equity.dart';
import 'evaluator.dart';
import 'format.dart';
import 'hand_engine.dart';
import 'notation.dart';
import 'prng.dart';
import 'types.dart';

/// Preflop multipliers per archetype (desktop `PreflopDials` / `DIALS`).
class PreflopDials {
  const PreflopDials({
    required this.open,
    required this.threebet,
    required this.call,
    required this.limpWide,
  });

  /// Multiplier on RFI frequencies (only actually applied for LAG).
  final double open;

  /// Multiplier on 3-bet frequencies.
  final double threebet;

  /// Multiplier on calling frequencies.
  final double call;

  /// Limps playable-but-not-opened hands when cheap.
  final bool limpWide;
}

const Map<Archetype, PreflopDials> kDials = {
  Archetype.tag: PreflopDials(
    open: 1.0,
    threebet: 1.0,
    call: 1.0,
    limpWide: false,
  ),
  Archetype.lag: PreflopDials(
    open: 1.3,
    threebet: 1.6,
    call: 1.15,
    limpWide: true,
  ),
  Archetype.nit: PreflopDials(
    open: 0.7,
    threebet: 0.55,
    call: 0.8,
    limpWide: false,
  ),
  Archetype.station: PreflopDials(
    open: 0.45,
    threebet: 0.3,
    call: 1.6,
    limpWide: true,
  ),
};

/// Hands that never fold preflop, whatever the price.
const Set<HandLabel> kPremium = {'AA', 'KK', 'QQ', 'AKs', 'AKo'};
const List<HandLabel> kPremiumList = ['AA', 'KK', 'QQ', 'AKs', 'AKo'];

/// Labels a chart plays at least [min] of the time (perceived-range lists),
/// in chart key order.
List<HandLabel> chartLabels(Map<String, num> chart, double min) {
  final out = <HandLabel>[];
  for (final e in chart.entries) {
    if (e.value >= min) out.add(e.key);
  }
  return out;
}

class BotDecision {
  const BotDecision({required this.action, required this.range});

  final Action action;

  /// Perceived holding range (grid labels). null = leave stored range unchanged.
  final List<HandLabel>? range;

  @override
  String toString() => 'BotDecision($action, range: $range)';
}

/// How a postflop action narrows the stored range (desktop `"aggro" | "call" | "check"`).
enum NarrowKind { aggro, call, check }

final List<HandLabel> _allLabels = allLabels();

/// `Math.round(Math.max(lo, Math.min(hi, x)))` with JS rounding.
int _clampInt(num x, int lo, int hi) =>
    jsRound(max(lo, min(hi, x)).toDouble()).toInt();

List<HandLabel> _setDiff(Iterable<HandLabel> a, Set<HandLabel> b) {
  final out = <HandLabel>[];
  for (final x in a) {
    if (!b.contains(x)) out.add(x);
  }
  return out;
}

Action _betOrRaise(TableState s, int to) =>
    s.currentBet == 0 ? Action.bet(to) : Action.raise(to);

const Map<String, num> _emptyChart = {};

Map<String, double> _bbVsSbThreebet() => kVsRfi100['BB_vs_SB']!['threebet']!;

/// Bot decision plus the range it's representing. The stored range is
/// guaranteed to contain the bot's actual hand whenever it continues —
/// mixed-frequency actions would otherwise "prove" impossible holdings
/// and corrupt Peek grading and the coach.
BotDecision decideBot(TableState s, int seat, {Random? rng}) {
  final d = _decideBotInner(s, seat, rng ?? Random());
  final p = s.players[seat];
  final range = d.range;
  final hole = p.hole;
  if (range != null && d.action.type != ActionType.fold && hole != null) {
    final label = cardsToLabel(hole[0], hole[1]);
    if (!range.contains(label)) {
      return BotDecision(action: d.action, range: [...range, label]);
    }
  }
  return d;
}

BotDecision _decideBotInner(TableState s, int seat, Random rng) {
  final p = s.players[seat];
  final archetype = p.archetype;
  final hole = p.hole;
  if (archetype == null || hole == null) {
    return const BotDecision(action: Action.fold(), range: []);
  }
  // Per-session jittered dials keep the archetype label from being a
  // full spoiler: two Nits won't play identically.
  final base = kArchetypes[archetype]!;
  final aggression = p.dials?.aggression ?? base.aggression;
  final stickiness = p.dials?.stickiness ?? base.stickiness;
  final cbetFlop = p.dials?.cbetFlop ?? base.cbetFlop;
  final la = legalActions(s);
  final label = cardsToLabel(hole[0], hole[1]);
  final bb = s.bigBlind;
  final rnd = rng.nextDouble();

  if (s.street == Street.preflop) {
    final dial = kDials[archetype]!;
    final facingRaise = s.currentBet > bb;

    if (!facingRaise) {
      if (la.canCheck) {
        // BB with the option: raise premiums over limps, otherwise check.
        final f = min(1.0, (_bbVsSbThreebet()[label] ?? 0) * dial.threebet);
        if (rnd < f && la.canRaise) {
          final limpers = _limpers(s, bb);
          final to = _clampInt(
            (3 + limpers) * bb,
            la.minRaiseTo,
            la.maxRaiseTo,
          );
          return BotDecision(
            action: _betOrRaise(s, to),
            range: chartLabels(_bbVsSbThreebet(), 0.25),
          );
        }
        return BotDecision(
          action: const Action.check(),
          range: _setDiff(
            _allLabels,
            chartLabels(_bbVsSbThreebet(), 0.5).toSet(),
          ),
        );
      }

      final chart = kRfi100[p.position.label] ?? kRfi100['SB']!;
      final baseFreq = chart[label] ?? 0;
      // Deviations trim the BOTTOM of the range, never the top:
      // premiums always open; Nit/Station kill marginal opens, LAG
      // rounds its mixed opens up.
      double openFreq;
      if (kPremium.contains(label)) {
        openFreq = 1;
      } else if (baseFreq == 0) {
        openFreq = 0;
      } else if (archetype == Archetype.lag) {
        openFreq = max(baseFreq * dial.open, 0.9);
      } else if (archetype == Archetype.nit) {
        openFreq = baseFreq >= 1 ? 0.92 : baseFreq * 0.35;
      } else if (archetype == Archetype.station) {
        openFreq = baseFreq >= 1 ? 0.55 : baseFreq * 0.25;
      } else {
        openFreq = baseFreq;
      }
      openFreq = min(1, openFreq);
      if (rnd < openFreq) {
        final limpers = _limpers(s, bb);
        final to = _clampInt(
          (2.5 + limpers) * bb,
          la.minRaiseTo,
          la.maxRaiseTo,
        );
        return BotDecision(
          action: _betOrRaise(s, to),
          range: chartLabels(chart, 0.4),
        );
      }
      // Loose types limp playable hands when the price is a limp.
      if (dial.limpWide && la.canCall && la.callAmount <= bb && baseFreq > 0) {
        return BotDecision(
          action: Action.call(amount: la.callAmount),
          range: chartLabels(chart, 0.01),
        );
      }
      return const BotDecision(action: Action.fold(), range: []);
    }

    // ---- Facing a raise ----
    final aggSeat = s.aggressor;
    final raiserPos =
        aggSeat != null && aggSeat != seat
            ? s.players[aggSeat].position
            : Position.co;
    final facing3bet = s.currentBet > 4.5 * bb; // beyond a standard single open
    final charts = kVsRfi100['${p.position.label}_vs_${raiserPos.label}'];

    if (!facing3bet && charts != null) {
      final threebetChart = charts['threebet']!;
      final callChart = charts['call']!;
      double f3 = threebetChart[label] ?? 0;
      double fc = callChart[label] ?? 0;
      if (archetype == Archetype.station) {
        // Stations flat their whole continue range and only raise monsters.
        fc = min(1, (f3 + fc) * dial.call);
        f3 = label == 'AA' || label == 'KK' ? 0.5 : 0;
      } else {
        if (archetype == Archetype.nit && f3 < 0.9) {
          f3 *= 0.3; // drop bluff 3-bets
        }
        f3 = min(1, f3 * dial.threebet);
        fc = min(1 - f3, fc * dial.call);
      }
      if (kPremium.contains(label)) {
        f3 = max(f3, 0.85); // premiums stay aggressive
      }
      if (rnd < f3 && la.canRaise) {
        final to = _clampInt(s.currentBet * 3.2, la.minRaiseTo, la.maxRaiseTo);
        return BotDecision(
          action: _betOrRaise(s, to),
          range: chartLabels(threebetChart, 0.25),
        );
      }
      if (rnd < f3 + fc && la.canCall) {
        return BotDecision(
          action: Action.call(amount: la.callAmount),
          range: chartLabels(callChart, 0.25),
        );
      }
      if (kPremium.contains(label) && la.canCall) {
        // Safety net: a premium may never fold preflop.
        return BotDecision(
          action: Action.call(amount: la.callAmount),
          range: kPremiumList,
        );
      }
      return const BotDecision(action: Action.fold(), range: []);
    }

    // ---- Facing a 3-bet or bigger (or an uncharted spot) ----
    if (label == 'AA' || label == 'KK') {
      if (la.canRaise && rnd < 0.8) {
        final to = _clampInt(s.currentBet * 2.6, la.minRaiseTo, la.maxRaiseTo);
        return BotDecision(action: _betOrRaise(s, to), range: kPremiumList);
      }
      if (la.canCall) {
        return BotDecision(
          action: Action.call(amount: la.callAmount),
          range: kPremiumList,
        );
      }
      if (la.canRaise) {
        return BotDecision(
          action: _betOrRaise(s, la.maxRaiseTo),
          range: kPremiumList,
        );
      }
    }
    final Map<String, num> threebetVs = charts?['threebet'] ?? _emptyChart;
    final double f3vs =
        (charts?['threebet']?[label] ?? (kPremium.contains(label) ? 1 : 0))
            .toDouble();
    if (f3vs >= 0.9) {
      // QQ / AK class: continue — occasionally 4-bet, mostly call.
      if (la.canRaise && rnd < 0.1 + 0.35 * aggression) {
        final to = _clampInt(s.currentBet * 2.6, la.minRaiseTo, la.maxRaiseTo);
        return BotDecision(action: _betOrRaise(s, to), range: kPremiumList);
      }
      if (la.canCall) {
        return BotDecision(
          action: Action.call(amount: la.callAmount),
          range: kPremiumList,
        );
      }
    }
    // Speculative continues vs a 3-bet: only at a sane price, by the
    // hand's own 3-bet-chart frequency, never with pure junk.
    if (f3vs > 0 &&
        la.canCall &&
        la.callAmount <= 12 * bb &&
        rnd < f3vs * (0.4 + stickiness)) {
      return BotDecision(
        action: Action.call(amount: la.callAmount),
        range: chartLabels(threebetVs, 0.25),
      );
    }
    return const BotDecision(action: Action.fold(), range: []);
  }

  // ---- Postflop ----
  final holeInts = comboToInts((hole[0], hole[1]));
  final boardInts = s.board.map(cardToInt).toList();
  final facingBet = la.toCall > 0;
  // Perceived-range bookkeeping: whatever this bot does, its stored
  // range narrows consistently with the policy that produced the
  // action (and is guaranteed to contain its actual hand).
  final stored = s.botRanges[p.id] ?? <HandLabel>[];
  List<HandLabel> narrowed(NarrowKind kind) =>
      narrowRange(stored, s.board, kind, label);

  // Equity vs the opponent's NARROWED range heads-up; vs random as the
  // multiway / no-range fallback.
  final liveOpps =
      s.players.where((q) => !q.hasFolded && q.id != seat).toList();
  final soleOppRange =
      liveOpps.length == 1 ? s.botRanges[liveOpps[0].id] : null;
  double e;
  if (soleOppRange != null && soleOppRange.isNotEmpty) {
    final blocked = <int>{...holeInts, ...boardInts};
    final combos = <IntCombo>[];
    for (final l in soleOppRange) {
      for (final (a, b) in labelToCombos(l)) {
        final ai = cardToInt(a);
        final bi = cardToInt(b);
        if (!blocked.contains(ai) && !blocked.contains(bi)) {
          combos.add([ai, bi]);
        }
      }
    }
    e =
        combos.isNotEmpty
            ? equityVsRange(
              holeInts,
              boardInts,
              combos,
              iters: 260,
              rng: rng,
            ).equity
            : equityVsRandom(holeInts, boardInts, iters: 320, rng: rng).equity;
  } else {
    e = equityVsRandom(holeInts, boardInts, iters: 320, rng: rng).equity;
  }

  final tex = boardTexture(boardInts);
  final draw = drawStrength(holeInts, boardInts);
  final multiDamp = 1 / max(1, liveOpps.length); // bluff less multiway

  if (!facingBet) {
    if (la.canBet) {
      if (e > 0.8) {
        // Monster: usually bet big, but slowplay dry boards sometimes.
        final slowplayP = tex.wet ? 0.08 : 0.28;
        if (rnd < slowplayP && s.street != Street.river) {
          return BotDecision(
            action: const Action.check(),
            range: narrowed(NarrowKind.check),
          );
        }
        final frac =
            tex.wet ? 1.0 : const [0.66, 0.75, 1.25][_clampInt(rnd * 3, 0, 2)];
        final to = _clampInt(s.pot * frac, la.minRaiseTo, la.maxRaiseTo);
        return BotDecision(
          action: Action.bet(to),
          range: narrowed(NarrowKind.aggro),
        );
      }
      if (e > 0.6) {
        // Solid value: size up on wet boards to charge draws.
        final to = _clampInt(
          s.pot * (tex.wet ? 0.75 : 0.55),
          la.minRaiseTo,
          la.maxRaiseTo,
        );
        return BotDecision(
          action: Action.bet(to),
          range: narrowed(NarrowKind.aggro),
        );
      }
      if (e > 0.4 &&
          s.street == Street.flop &&
          rnd < (cbetFlop / 100) * (tex.wet ? 0.7 : 1) * multiDamp) {
        // Small range-style c-bet on favorable, drier flops.
        final to = _clampInt(s.pot * 0.33, la.minRaiseTo, la.maxRaiseTo);
        return BotDecision(
          action: Action.bet(to),
          range: narrowed(NarrowKind.aggro),
        );
      }
      // Bluffs need a reason: a real draw, or a scare-card barrel.
      final bluffP =
          draw == 2
              ? aggression * 0.55
              : draw == 1
              ? aggression * 0.28
              : tex.highCard >= 12 && s.street != Street.flop
              ? aggression * 0.12
              : 0.0;
      if (rng.nextDouble() < bluffP * multiDamp) {
        final to = _clampInt(s.pot * 0.66, la.minRaiseTo, la.maxRaiseTo);
        return BotDecision(
          action: Action.bet(to),
          range: narrowed(NarrowKind.aggro),
        );
      }
    }
    return BotDecision(
      action: const Action.check(),
      range: narrowed(NarrowKind.check),
    );
  }

  // ---- Facing a bet ----
  final needed = la.callAmount / (s.pot + la.callAmount);
  // Value raises from 0.72 (non-nutted included), sized up on wet boards.
  if (e > 0.72 &&
      la.canRaise &&
      rng.nextDouble() < aggression * (e > 0.85 ? 1 : 0.6)) {
    final frac = tex.wet ? 1.0 : 0.8;
    final to = _clampInt(
      s.currentBet + s.pot * frac,
      la.minRaiseTo,
      la.maxRaiseTo,
    );
    return BotDecision(
      action: Action.raise(to),
      range: narrowed(NarrowKind.aggro),
    );
  }
  // Semi-bluff (check-)raise with strong draws.
  if (draw == 2 &&
      s.street != Street.river &&
      la.canRaise &&
      rng.nextDouble() < aggression * 0.3 * multiDamp) {
    final to = _clampInt(
      s.currentBet + s.pot * 0.9,
      la.minRaiseTo,
      la.maxRaiseTo,
    );
    return BotDecision(
      action: Action.raise(to),
      range: narrowed(NarrowKind.aggro),
    );
  }
  // Draws call a little wider (implied-odds proxy); rivers don't.
  final effE = min(0.95, e + (s.street != Street.river ? draw * 0.05 : 0));
  final callThreshold = needed * (1 - stickiness * 0.5);
  if (effE >= callThreshold && la.canCall) {
    return BotDecision(
      action: Action.call(amount: la.callAmount),
      range: narrowed(NarrowKind.call),
    );
  }
  if (stickiness > 0.7 &&
      la.canCall &&
      la.callAmount <= s.pot * 0.5 &&
      rng.nextDouble() < 0.7) {
    return BotDecision(
      action: Action.call(amount: la.callAmount),
      range: narrowed(NarrowKind.call),
    );
  }
  return const BotDecision(action: Action.fold(), range: []);
}

/// Players still in who have exactly a big blind in front of them and are
/// not the BB — i.e. limpers.
int _limpers(TableState s, int bb) =>
    s.players
        .where(
          (q) => !q.hasFolded && q.committed == bb && q.position != Position.bb,
        )
        .length;

/* ---- Board texture + draw detection (cheap bitmask heuristics) ---- */

class BoardTexture {
  const BoardTexture({
    required this.wet,
    required this.paired,
    required this.highCard,
  });

  /// Flushy (3+ of a suit, or monotone flop) or connected.
  final bool wet;

  /// Any rank appears twice or more (computed but unused by the policy).
  final bool paired;

  /// Highest board rank as a value 2..14 (0 on an empty board).
  final int highCard;

  @override
  String toString() =>
      'BoardTexture(wet: $wet, paired: $paired, highCard: $highCard)';
}

BoardTexture boardTexture(List<int> boardInts) {
  final suits = [0, 0, 0, 0];
  final rankCounts = <int, int>{};
  int rankMask = 0;
  int highCard = 0;
  for (final c in boardInts) {
    suits[c & 3]++;
    final r = (c >> 2) + 2;
    rankCounts[r] = (rankCounts[r] ?? 0) + 1;
    rankMask |= 1 << r;
    if (r > highCard) highCard = r;
  }
  final flushy = suits.reduce(max) >= min(3, boardInts.length);
  // Connected: any 5-rank window holding 3+ board ranks.
  bool straighty = false;
  final m = rankMask | ((rankMask & (1 << 14)) != 0 ? 1 << 1 : 0);
  for (int lo = 1; lo <= 10; lo++) {
    int n = 0;
    for (int r = lo; r < lo + 5; r++) {
      if ((m & (1 << r)) != 0) n++;
    }
    if (n >= 3) straighty = true;
  }
  final paired = rankCounts.values.any((n) => n >= 2);
  return BoardTexture(
    wet: flushy || straighty,
    paired: paired,
    highCard: highCard,
  );
}

/// 0 = none, 1 = weak (gutshot / flop 3-flush), 2 = strong (flush draw / OESD).
int drawStrength(List<int> holeInts, List<int> boardInts) {
  if (boardInts.length >= 5) return 0;
  final suits = [0, 0, 0, 0];
  int mask = 0;
  void add(int c) {
    suits[c & 3]++;
    mask |= 1 << ((c >> 2) + 2);
  }

  for (final c in holeInts) {
    add(c);
  }
  for (final c in boardInts) {
    add(c);
  }
  final holeSuit0 = holeInts[0] & 3;
  final holeSuit1 = holeInts[1] & 3;
  bool holdsSuit(int si) => si == holeSuit0 || si == holeSuit1;
  bool flushDraw = false;
  for (int si = 0; si < 4; si++) {
    if (suits[si] == 4 && holdsSuit(si)) flushDraw = true;
  }
  if ((mask & (1 << 14)) != 0) mask |= 1 << 1;
  bool fourToStraight = false;
  for (int lo = 1; lo <= 10; lo++) {
    int n = 0;
    for (int r = lo; r < lo + 5; r++) {
      if ((mask & (1 << r)) != 0) n++;
    }
    if (n >= 4) fourToStraight = true;
  }
  int run = 0;
  int bestRun = 0;
  for (int r = 1; r <= 14; r++) {
    run = (mask & (1 << r)) != 0 ? run + 1 : 0;
    bestRun = max(bestRun, run);
  }
  final oesd = bestRun >= 4;
  final gutshot = fourToStraight && !oesd;
  bool threeFlush = false;
  if (boardInts.length == 3) {
    for (int si = 0; si < 4; si++) {
      if (suits[si] == 3 && holdsSuit(si)) threeFlush = true;
    }
  }
  if (flushDraw || oesd) return 2;
  if (gutshot || threeFlush) return 1;
  return 0;
}

/* ==================================================================
   Street-by-street range narrowing.

   Ranks every label in the stored range by its strength on the board
   (exact made-hand score on the river; a short seeded equity sample —
   which sees draws — on the flop/turn) and keeps the slice consistent
   with the action: aggression keeps the strong part plus a bluff tail,
   calling keeps the middle-and-up, checking sheds the very top. The
   bot's actual label is always retained.
   ================================================================== */

IntCombo? _representativeCombo(HandLabel label, Set<int> blocked) {
  for (final (a, b) in labelToCombos(label)) {
    final ai = cardToInt(a);
    final bi = cardToInt(b);
    if (!blocked.contains(ai) && !blocked.contains(bi)) return [ai, bi];
  }
  return null;
}

class _Scored {
  _Scored(this.label, this.v, this.idx);
  final HandLabel label;
  final double v;
  final int idx;
}

/// Narrow [stored] on [board] consistently with the action [kind]. Returns
/// [stored] itself (same list) when it holds 8 labels or fewer and already
/// contains [actualLabel], like the desktop.
List<HandLabel> narrowRange(
  List<HandLabel> stored,
  List<Card> board,
  NarrowKind kind,
  HandLabel actualLabel,
) {
  if (stored.length <= 8) {
    return stored.contains(actualLabel) ? stored : [...stored, actualLabel];
  }
  final boardInts = board.map(cardToInt).toList();
  final blocked = boardInts.toSet();
  final isRiver = board.length == 5;

  final scored = <_Scored>[];
  for (final l in stored) {
    final combo = _representativeCombo(l, blocked);
    if (combo == null) continue; // fully blocked by the board
    final v =
        isRiver
            ? evaluateInts([combo[0], combo[1], ...boardInts]).score.toDouble()
            : equityVsRandom(
              combo,
              boardInts,
              iters: 80,
              seed: hashSeed('$l|${board.join()}'),
            ).equity;
    scored.add(_Scored(l, v, scored.length));
  }
  // Descending by strength; ties keep stored order (JS sort is stable).
  scored.sort((a, b) {
    if (a.v != b.v) return a.v > b.v ? -1 : 1;
    return a.idx - b.idx;
  });

  final n = scored.length;
  List<HandLabel> slice(int start, int end) => [
    for (int i = max(0, min(start, n)); i < min(end, n); i++) scored[i].label,
  ];
  List<HandLabel> kept;
  if (kind == NarrowKind.aggro) {
    // Value region + a thin bluff tail from the bottom (bots do bluff).
    final top = slice(0, max(5, jsRound(n * 0.45).toInt()));
    final tail = slice(jsRound(n * 0.85).toInt(), n);
    kept = [...top, ...tail];
  } else if (kind == NarrowKind.call) {
    kept = slice(0, max(6, jsRound(n * 0.65).toInt()));
  } else {
    // Checking sheds the very strongest slice, keeps the rest.
    kept = slice(jsRound(n * 0.12).toInt(), n);
  }
  if (!kept.contains(actualLabel) && stored.contains(actualLabel)) {
    kept.add(actualLabel);
  }
  return kept;
}
