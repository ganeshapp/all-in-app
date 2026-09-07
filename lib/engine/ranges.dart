/// Preflop hand strength + range construction — ported 1:1 from the desktop
/// `src/engine/ranges.ts`.
///
/// We use the Chen formula (a well-known preflop heuristic) to order the 169
/// starting hands, then build position/archetype-aware ranges by taking the
/// strongest hands up to a target % of all combos. This keeps ranges
/// principled and explainable (and reusable in the Study module) without
/// hardcoding 169 hands by hand.
library;

import 'notation.dart';
import 'types.dart';

int _rankValue(String r) => kRanksDesc.length - 1 - kRanksDesc.indexOf(r) + 2;

/// Base value of the highest card (Chen).
double _highCardScore(int v) {
  if (v == 14) return 10; // Ace
  if (v == 13) return 8; // King
  if (v == 12) return 7; // Queen
  if (v == 11) return 6; // Jack
  return v / 2; // Ten=5, Nine=4.5, ... Two=1
}

/// Chen formula score for a starting-hand label. Higher = stronger.
///
/// A multiple of 0.5; may be negative (e.g. `72o` = -1.5). This is the classic
/// Chen formula WITHOUT the "round half up" step, exactly as the desktop.
double chenScore(HandLabel label) {
  final kind = kindOf(label);
  final hi = label[0];
  final hiVal = _rankValue(hi);

  if (kind == ComboKind.pair) {
    final s = _highCardScore(hiVal) * 2;
    return s > 5 ? s : 5;
  }

  final lo = label[1];
  final loVal = _rankValue(lo);
  double score = _highCardScore(hiVal);
  if (kind == ComboKind.suited) score += 2;

  final gap = hiVal - loVal - 1;
  if (gap == 1) {
    score -= 1;
  } else if (gap == 2) {
    score -= 2;
  } else if (gap == 3) {
    score -= 4;
  } else if (gap >= 4) {
    score -= 5;
  }

  // Straight bonus: 0/1 gap and both cards below Queen.
  if (gap <= 1 && hiVal < 12) score += 1;

  return score;
}

/// One entry of [rankedHands] (desktop `RankedHand`).
class RankedHand {
  const RankedHand({
    required this.label,
    required this.score,
    required this.combos,
  });

  final HandLabel label;
  final double score;
  final int combos;

  @override
  String toString() => 'RankedHand($label, $score, $combos)';
}

List<RankedHand>? _ranked;

/// All 169 hands sorted strongest → weakest (cached, unmodifiable).
///
/// Sort keys: score desc; then pair < suited < offsuit; then high card desc;
/// then original grid order (JS `Array.sort` is stable — Dart's is not, so
/// the grid index is an explicit final tie-break).
List<RankedHand> rankedHands() {
  final cached = _ranked;
  if (cached != null) return cached;
  final labels = allLabels();
  final idx = List<int>.generate(labels.length, (i) => i);
  final hands = [
    for (final label in labels)
      RankedHand(
        label: label,
        score: chenScore(label),
        combos: comboCount(label),
      ),
  ];
  const order = {ComboKind.pair: 0, ComboKind.suited: 1, ComboKind.offsuit: 2};
  idx.sort((ia, ib) {
    final a = hands[ia];
    final b = hands[ib];
    if (b.score != a.score) return b.score > a.score ? 1 : -1;
    // tie-break: pairs > suited > offsuit, then high card
    final ka = order[kindOf(a.label)]!;
    final kb = order[kindOf(b.label)]!;
    if (ka != kb) return ka - kb;
    final ra = _rankValue(a.label[0]);
    final rb = _rankValue(b.label[0]);
    if (ra != rb) return rb - ra;
    return ia - ib;
  });
  final out = List<RankedHand>.unmodifiable([for (final i in idx) hands[i]]);
  _ranked = out;
  return out;
}

/// Map of label -> 1-based strength rank (1 = AA, 169 = 72o).
Map<HandLabel, int> strengthRankMap() {
  final m = <HandLabel, int>{};
  final ranked = rankedHands();
  for (int i = 0; i < ranked.length; i++) {
    m[ranked[i].label] = i + 1;
  }
  return m;
}

/// Strongest hands up to `pct`% of all 1326 combos.
///
/// Insertion order = strength order. The hand that crosses the target is
/// included; `pct <= 0` -> empty; `pct >= 100` -> all 169.
Set<HandLabel> topPercentRange(num pct) {
  final clamped = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
  final target = clamped / 100 * kTotalCombos;
  final out = <HandLabel>{};
  int acc = 0;
  for (final h in rankedHands()) {
    if (acc >= target) break;
    out.add(h.label);
    acc += h.combos;
  }
  return out;
}

/// Position widens/tightens a base frequency. 1.0 = neutral.
double positionMultiplier(Position pos) {
  switch (pos) {
    case Position.utg:
      return 0.5;
    case Position.mp:
      return 0.68;
    case Position.co:
      return 0.9;
    case Position.btn:
      return 1.25;
    case Position.sb:
      return 0.85;
    case Position.bb:
      return 1.0;
  }
}

/// A player's preflop ranges (desktop `PreflopRanges`).
class PreflopRanges {
  const PreflopRanges({required this.play, required this.raise});

  /// Hands the player will voluntarily play (call or raise).
  final Set<HandLabel> play;

  /// Hands the player will raise / re-raise with.
  final Set<HandLabel> raise;
}

/// Build a player's preflop ranges from archetype VPIP/PFR and seat position.
/// VPIP sizes the play range; PFR sizes the (stronger) raising range.
///
/// The products are computed in doubles exactly as the desktop does
/// (e.g. TAG:SB raisePct = 15.299999999999999) — never rounded.
PreflopRanges buildPreflopRanges(num vpip, num pfr, Position pos) {
  final mult = positionMultiplier(pos);
  final playPct = _clamp(vpip * mult, 4, 90);
  final raisePct = _clamp(pfr * mult, 2, playPct);
  return PreflopRanges(
    play: topPercentRange(playPct),
    raise: topPercentRange(raisePct),
  );
}

double _clamp(double v, double lo, double hi) {
  final m = v < hi ? v : hi;
  return m > lo ? m : lo;
}

/// Labels a frequency chart plays at least `min` of the time, as a set
/// (for 13×13 matrix display and range-building drills).
Set<HandLabel> chartToSet(Map<String, num> chart, [double min = 0.5]) {
  final out = <HandLabel>{};
  for (final e in chart.entries) {
    if (e.value >= min) out.add(e.key);
  }
  return out;
}

/// Combo-weighted width of a frequency chart (fraction of all 1326).
double chartWidth(Map<String, num> chart) {
  double w = 0;
  for (final e in chart.entries) {
    final l = e.key;
    w += e.value * (l.length == 2 ? 6 : (l.endsWith('s') ? 4 : 12));
  }
  return w / 1326;
}

/// One canonical example range used by the Study curriculum.
class StudyRange {
  const StudyRange({
    required this.title,
    required this.pct,
    required this.note,
  });

  final String title;
  final int pct;
  final String note;
}

/// Canonical example ranges used by the Study curriculum (desktop
/// `STUDY_RANGES`, copy verbatim).
const List<StudyRange> kStudyRanges = [
  StudyRange(
    title: 'UTG Open (~14%)',
    pct: 14,
    note: 'Tightest opening range — premium pairs, big broadways, AK–AQ.',
  ),
  StudyRange(
    title: 'CO Open (~27%)',
    pct: 27,
    note: 'Widen with suited connectors and more broadways.',
  ),
  StudyRange(
    title: 'BTN Open (~45%)',
    pct: 45,
    note: 'Steal wide — any pair, most suited hands, many offsuit broadways.',
  ),
  StudyRange(
    title: 'BB Defend (~55%)',
    pct: 55,
    note: 'Closing the action with a price; defend wide vs a single raise.',
  ),
];
