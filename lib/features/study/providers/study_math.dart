/// The pure arithmetic behind the Study widgets — every formula, generator and
/// threshold the desktop uses, with no Flutter in sight so it can be pinned by
/// plain unit tests.
///
/// Sources: docs/port/study-curriculum.md §12 (the calculators), §12.7
/// (`breakdownRange` / `drawFlags`) and §16 (the three mini-drills).
library;

import 'dart:math' as math;

import 'package:allin/data/preflop_charts.g.dart';
import 'package:allin/engine/cards.dart';
import 'package:allin/engine/evaluator.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';

/* -------------------------------------------------------------- §12.2 pot odds */

/// Everything `PotOddsCalculator` derives from (pot, bet, equity). All chip
/// values are big blinds (§12.2).
class PotOddsMath {
  const PotOddsMath({required this.pot, required this.bet, required this.eq});

  /// Pot before the bet, 1..60 in steps of 1.
  final int pot;

  /// The opponent's bet, 0.5..60 in steps of 0.5.
  final double bet;

  /// The user's equity estimate as an integer percentage, 0..100.
  final int eq;

  double get toWin => pot + bet;
  double get finalPot => pot + 2 * bet;
  double get breakEven => bet / finalPot;
  double get ratio => bet > 0 ? toWin / bet : 0;

  /// EV of calling, in big blinds.
  double get ev => (eq / 100) * finalPot - bet;

  /// Desktop's 0.02 bb epsilon — an EV of exactly 0 reads "Fold" (§12.2).
  bool get call => ev > 0.02;

  String get decision => call ? 'Call' : 'Fold';

  /// "= your call (6.5) ÷ final pot (23.0). Call when your equity beats this."
  String get breakEvenFormula =>
      '= your call (${bbText(bet)}) ÷ final pot (${jsToFixed(finalPot, 1)}). '
      'Call when your equity beats this.';

  /// "50% × 23.0 − 6.5 = 5.0"
  String get evFormula =>
      '$eq% × ${jsToFixed(finalPot, 1)} − ${bbText(bet)} = ${jsToFixed(ev, 1)}';
}

/* ------------------------------------------------------------------ §12.3 bluff */

/// `BluffCalculator`'s two numbers (§12.3).
class BluffMath {
  const BluffMath({required this.pot, required this.bet});

  final int pot;
  final double bet;

  /// Break-even fold frequency for a pure bluff.
  double get foldNeeded => bet / (bet + pot);

  /// The equity the caller needs for the call to break even.
  double get callerNeeds => bet / (pot + 2 * bet);

  /// The bet as a fraction of the pot ("70% pot").
  double get betAsPot => bet / pot;
}

/* ------------------------------------------------------- §12 number formatting */

/// Slider numbers print like JS: integers with no decimal point (`10 bb`),
/// halves with one (`6.5 bb`).
String bbText(num v) =>
    v == v.roundToDouble() ? '${v.round()}' : jsToFixed(v.toDouble(), 1);

/* ------------------------------------------------------------ §12.4 scenarios */

/// One `MultiwayEquityTrainer` scenario; index order is load-bearing (§12.4).
class MultiwayScenario {
  const MultiwayScenario({
    required this.name,
    required this.hero,
    required this.board,
  });

  final String name;
  final List<Card> hero;
  final List<Card> board;
}

const List<MultiwayScenario> kMultiwayScenarios = <MultiwayScenario>[
  MultiwayScenario(
    name: 'Two pair (top two)',
    hero: <Card>['Ah', 'Kh'],
    board: <Card>['Ad', 'Kc', '7s'],
  ),
  MultiwayScenario(
    name: 'Top pair top kicker',
    hero: <Card>['Ah', 'Kd'],
    board: <Card>['Ac', '9h', '4s'],
  ),
  MultiwayScenario(
    name: 'A set',
    hero: <Card>['7h', '7d'],
    board: <Card>['7s', 'Kc', '2d'],
  ),
  MultiwayScenario(
    name: 'Overpair (QQ)',
    hero: <Card>['Qh', 'Qd'],
    board: <Card>['9s', '6c', '2d'],
  ),
  MultiwayScenario(
    name: 'Flush draw',
    hero: <Card>['Ah', 'Kh'],
    board: <Card>['Qh', '7h', '2s'],
  ),
  MultiwayScenario(
    name: 'Pocket Aces (pre-flop)',
    hero: <Card>['Ah', 'Ad'],
    board: <Card>[],
  ),
];

/* ------------------------------------------------------- §12.5 explorer presets */

/// A `RangeExplorer` preset chip: label → `topPercentRange(pct)` (§12.5).
class RangePresetSpec {
  const RangePresetSpec(this.label, this.pct);
  final String label;
  final int pct;
}

const List<RangePresetSpec> kExplorerPresets = <RangePresetSpec>[
  RangePresetSpec('UTG ~14%', 14),
  RangePresetSpec('MP ~19%', 19),
  RangePresetSpec('CO ~27%', 27),
  RangePresetSpec('BTN ~45%', 45),
  RangePresetSpec('BB defend ~55%', 55),
];

/* ------------------------------------------------------------ §12.6 expansion */

/// Concrete combos of [range] with every combo that shares a card with [board]
/// dropped — the equity calculator's `expand()` (§12.6). Set iteration order is
/// insertion order, exactly as the TypeScript's.
List<Combo> expandAgainstBoard(Set<HandLabel> range, List<Card> board) {
  final blocked = board.toSet();
  final out = <Combo>[];
  for (final label in range) {
    for (final combo in labelToCombos(label)) {
      if (!blocked.contains(combo.$1) && !blocked.contains(combo.$2)) {
        out.add(combo);
      }
    }
  }
  return out;
}

/* -------------------------------------------------- §12.7 board breakdown */

/// How many combos of a range make each category on a board (§12.7).
class Breakdown {
  const Breakdown({
    required this.catCount,
    required this.flushDraws,
    required this.oesds,
    required this.total,
  });

  /// Keyed by [HandCategory.index] (0 high card … 8 straight flush).
  final Map<int, int> catCount;
  final int flushDraws;
  final int oesds;
  final int total;
}

/// Desktop `drawFlags` — deliberately simple heuristics, quirks preserved:
/// `oesd` fires on any four consecutive distinct ranks among hole + board
/// (so a made straight counts), and `flushDraw` needs *exactly* four of a suit
/// with at least one hole card in it (§12.7).
({bool flushDraw, bool oesd}) drawFlags(Combo hole, List<int> boardInts) {
  final a = cardToInt(hole.$1);
  final b = cardToInt(hole.$2);
  final all = <int>[a, b, ...boardInts];
  final suits = <int>[0, 0, 0, 0];
  var mask = 0;
  for (final c in all) {
    suits[c & 3]++;
    mask |= 1 << ((c >> 2) + 2);
  }
  final holeSuits = <int>[a & 3, b & 3];
  final flushDraw = <int>[
    0,
    1,
    2,
    3,
  ].any((si) => suits[si] == 4 && holeSuits.contains(si));
  if (mask & (1 << 14) != 0) mask |= 1 << 1; // the ace also plays low
  var run = 0;
  var best = 0;
  for (var r = 1; r <= 14; r++) {
    run = (mask & (1 << r)) != 0 ? run + 1 : 0;
    if (run > best) best = run;
  }
  return (flushDraw: flushDraw, oesd: best >= 4);
}

/// "How does this range hit this board" (§12.7). [dead] removes further cards
/// (the hero's exact hand in hand mode).
Breakdown breakdownRange(
  Set<HandLabel> range,
  List<Card> board, [
  List<Card> dead = const <Card>[],
]) {
  final boardInts = board.map(cardToInt).toList(growable: false);
  final blocked = <Card>{...board, ...dead}.map(cardToInt).toSet();
  final catCount = <int, int>{};
  var flushDraws = 0;
  var oesds = 0;
  var total = 0;
  for (final label in range) {
    for (final combo in labelToCombos(label)) {
      final ai = cardToInt(combo.$1);
      final bi = cardToInt(combo.$2);
      if (blocked.contains(ai) || blocked.contains(bi)) continue;
      total++;
      final cat = evaluateInts(<int>[ai, bi, ...boardInts]).category.index;
      catCount[cat] = (catCount[cat] ?? 0) + 1;
      if (board.length < 5) {
        final d = drawFlags(combo, boardInts);
        if (d.flushDraw) flushDraws++;
        if (d.oesd) oesds++;
      }
    }
  }
  return Breakdown(
    catCount: catCount,
    flushDraws: flushDraws,
    oesds: oesds,
    total: total,
  );
}

/* ------------------------------------------------------------- §16 mini-drills */

/// Uniform integer in `[a, b]`, inclusive (desktop `randInt`).
int randInt(math.Random rng, int a, int b) => a + rng.nextInt(b - a + 1);

/// Fisher–Yates on a copy, descending, exactly as the desktop's `shuffle`.
List<T> shuffleList<T>(List<T> arr, math.Random rng) {
  final out = List<T>.of(arr);
  for (var i = out.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// One `PotOddsDrill` spot (§16.2).
class PotOddsSpot {
  const PotOddsSpot({
    required this.pot,
    required this.bet,
    required this.correct,
    required this.options,
  });

  final int pot;
  final double bet;

  /// Break-even equity as an integer percentage.
  final int correct;

  /// Four answers in display order (the correct one is among them).
  final List<int> options;

  /// "The pot is 10 bb and your opponent bets 5 bb. What equity do you need to
  /// call?" — bold runs marked with `**`.
  String get prompt =>
      'The pot is **${bbText(pot)} bb** and your opponent bets '
      '**${bbText(bet)} bb**. What equity do you need to call?';

  /// "Break-even = call ÷ final pot = 5 ÷ (10 + 2×5) = 25%."
  String get explanation =>
      'Break-even = call ÷ final pot = ${bbText(bet)} ÷ '
      '(${bbText(pot)} + 2×${bbText(bet)}) = ${fmtPct(bet / (pot + 2 * bet))}.';
}

const List<double> _kPotFracs = <double>[0.33, 0.5, 0.66, 1.0];
const List<int> _kPotDeltas = <int>[-15, -10, -7, 7, 10, 15];

/// §16.2's generator. [rng] makes it testable; the widget passes `Random()`.
PotOddsSpot makePotSpot(math.Random rng) {
  final pot = randInt(rng, 4, 40);
  final frac = _kPotFracs[randInt(rng, 0, 3)];
  final bet = math.max(1.0, jsRound(pot * frac * 2) / 2);
  final correct = jsRound(bet / (pot + 2 * bet) * 100).toInt();
  final set = <int>{correct};
  // Probabilistic in the original; the bounded loop plus the ordered fallback
  // below is behaviourally identical (§16.2's lint note).
  for (var guard = 0; set.length < 4 && guard < 100; guard++) {
    final d = correct + _kPotDeltas[randInt(rng, 0, _kPotDeltas.length - 1)];
    if (d > 2 && d < 60) set.add(d);
  }
  for (final delta in _kPotDeltas) {
    if (set.length >= 4) break;
    final d = correct + delta;
    if (d > 2 && d < 60) set.add(d);
  }
  return PotOddsSpot(
    pot: pot,
    bet: bet,
    correct: correct,
    options: shuffleList(set.toList(), rng),
  );
}

/// One entry of §16.3's `DRAWS`; order is load-bearing.
class OutsDraw {
  const OutsDraw(this.name, this.outs);
  final String name;
  final int outs;
}

const List<OutsDraw> kOutsDraws = <OutsDraw>[
  OutsDraw('a flush draw', 9),
  OutsDraw('an open-ended straight draw', 8),
  OutsDraw('a gutshot', 4),
  OutsDraw('two overcards', 6),
  OutsDraw('a flush draw + gutshot', 12),
  OutsDraw('a pocket pair hoping to flop/turn a set', 2),
  OutsDraw('a flush draw + open-ender', 15),
];

const List<int> _kOutsDeltas = <int>[-16, -12, -8, 8, 12, 16];

/// One `OutsDrill` spot (§16.3).
class OutsSpot {
  const OutsSpot({
    required this.draw,
    required this.mult,
    required this.street,
    required this.correct,
    required this.options,
  });

  final OutsDraw draw;

  /// 4 on the flop, 2 on the turn.
  final int mult;

  /// "flop (two cards to come)" / "turn (one card to come)".
  final String street;
  final int correct;
  final List<int> options;

  String get prompt =>
      'On the **$street** you have **${draw.name}** (${draw.outs} outs). '
      "Using the rule of thumb, roughly what's your equity?";

  String get explanation =>
      'Multiply outs by $mult '
      '(${mult == 4 ? 'two cards to come' : 'one card to come'}): '
      '${draw.outs} × $mult ≈ $correct%. The ×4 rule slightly over-counts big '
      'draws, so shade large numbers down a touch.';
}

/// §16.3's generator.
OutsSpot makeOutsSpot(math.Random rng) {
  final draw = kOutsDraws[randInt(rng, 0, kOutsDraws.length - 1)];
  final onFlop = rng.nextDouble() < 0.5;
  final mult = onFlop ? 4 : 2;
  final correct = math.min(95, draw.outs * mult);
  final set = <int>{correct};
  for (var guard = 0; set.length < 4 && guard < 100; guard++) {
    final v = correct + _kOutsDeltas[randInt(rng, 0, _kOutsDeltas.length - 1)];
    if (v > 2 && v < 99) set.add(v);
  }
  for (final delta in _kOutsDeltas) {
    if (set.length >= 4) break;
    final v = correct + delta;
    if (v > 2 && v < 99) set.add(v);
  }
  return OutsSpot(
    draw: draw,
    mult: mult,
    street: onFlop ? 'flop (two cards to come)' : 'turn (one card to come)',
    correct: correct,
    options: shuffleList(set.toList(), rng),
  );
}

/// One `RangeBuildDrill` target (§16.4); order is load-bearing.
class RangeTarget {
  RangeTarget(this.desc, this.labels);
  final String desc;
  final Set<HandLabel> labels;
}

/// Built once — four `chartToSet` calls plus one union (§16.4).
final List<RangeTarget>
kRangeTargets = List<RangeTarget>.unmodifiable(<RangeTarget>[
  RangeTarget('UTG opening range (~15% of hands)', chartToSet(kRfi100['UTG']!)),
  RangeTarget('CO opening range (~26% of hands)', chartToSet(kRfi100['CO']!)),
  RangeTarget('BTN opening range (~45% of hands)', chartToSet(kRfi100['BTN']!)),
  RangeTarget(
    'BB continue range vs a BTN open (calls + 3-bets, ~40%)',
    <HandLabel>{
      ...chartToSet(kVsRfi100['BB_vs_BTN']!['call']!),
      ...chartToSet(kVsRfi100['BB_vs_BTN']!['threebet']!),
    },
  ),
]);

/// The pass mark for the range-building drill — used by both the score
/// increment and the colour of the match percentage (§16.4).
const double kRangePassThreshold = 0.7;

/// Combo-weighted F1 of a painted range against the standard (§16.4).
double scoreRange(Set<HandLabel> painted, Set<HandLabel> actual) {
  var inter = 0;
  for (final label in painted) {
    if (actual.contains(label)) inter += comboCount(label);
  }
  final pc = combosInSet(painted);
  final ac = combosInSet(actual);
  final precision = pc > 0 ? inter / pc : 0.0;
  final recall = ac > 0 ? inter / ac : 0.0;
  return precision + recall > 0
      ? (2 * precision * recall) / (precision + recall)
      : 0.0;
}
