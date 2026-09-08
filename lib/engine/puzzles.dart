/// Drills — procedural puzzle generator + heuristic grader.
///
/// Ported 1:1 from the desktop `src/engine/puzzles.ts`. Preflop answers come
/// from position-based opening/defending charts (heuristic top-% ranges —
/// honest label, not GTO). Postflop answers come from equity vs a plausible
/// continuing range compared to pot odds (a fundamentals heuristic, not a
/// solver). The UI labels which is which.
///
/// Randomness: every generator takes an optional [Random]; the desktop calls
/// `Math.random()` in exactly the order these functions call `rng`, so a
/// [Mulberry32] seed reproduces the desktop's deal, spot parameters and text
/// bit-for-bit (the equity sims are self-seeded from the spot).
///
/// Rationale strings are product copy (see `docs/TONE.md`) and are kept
/// verbatim, including JavaScript number formatting (`2.5`, `3`, never `3.0`).
library;

import 'dart:math';

import '../data/icm_scenarios.g.dart';
import '../data/preflop_charts.g.dart';
import '../data/pushfold_tables.g.dart';
import 'cards.dart';
import 'equity.dart';
import 'format.dart';
import 'notation.dart';
import 'prng.dart';
import 'ranges.dart';
import 'types.dart';

/* ------------------------------ Data model ------------------------------ */

/// Spot family. The string forms are load-bearing: review-card ids embed them
/// and persisted puzzles serialise them.
enum PuzzleKind {
  rfi('rfi'),
  vsRaise('vs-raise'),
  postflopBet('postflop-bet'),
  postflopCheck('postflop-check'),
  threebetPot('threebet-pot'),
  checkRaise('check-raise'),
  riverDecision('river-decision'),
  pushfold('pushfold'),
  exploit('exploit'),
  leak('leak');

  const PuzzleKind(this.label);
  final String label;

  static PuzzleKind fromLabel(String label) =>
      PuzzleKind.values.firstWhere((k) => k.label == label);
}

/// Where the answer key comes from (`"chart"` | `"heuristic"`).
enum PuzzleSource {
  chart('chart'),
  heuristic('heuristic');

  const PuzzleSource(this.label);
  final String label;

  static PuzzleSource fromLabel(String label) =>
      PuzzleSource.values.firstWhere((s) => s.label == label);
}

class DrillSeatView {
  const DrillSeatView({
    required this.pos,
    required this.isHero,
    required this.folded,
    required this.active,
  });
  final Position pos;
  final bool isHero;
  final bool folded;

  /// Still in the hand and not hero.
  final bool active;

  Map<String, Object?> toJson() => {
    'pos': pos.label,
    'isHero': isHero,
    'folded': folded,
    'active': active,
  };
  static DrillSeatView fromJson(Map<String, Object?> j) => DrillSeatView(
    pos: Position.fromLabel(j['pos'] as String),
    isHero: j['isHero'] as bool,
    folded: j['folded'] as bool,
    active: j['active'] as bool,
  );
}

/// One step of the "Hand replay" navigator.
class DrillFrame {
  const DrillFrame({
    required this.text,
    required this.street,
    required this.board,
    required this.pot,
  });
  final String text;
  final Street street;
  final List<Card> board;
  final double pot;

  Map<String, Object?> toJson() => {
    'text': text,
    'street': street.label,
    'board': board,
    'pot': _jsonNum(pot),
  };
  static DrillFrame fromJson(Map<String, Object?> j) => DrillFrame(
    text: j['text'] as String,
    street: Street.fromLabel(j['street'] as String),
    board: (j['board'] as List).cast<String>(),
    pot: (j['pot'] as num).toDouble(),
  );
}

class Puzzle {
  const Puzzle({
    required this.id,
    required this.kind,
    required this.source,
    required this.street,
    required this.heroPos,
    required this.hole,
    required this.handLabel,
    required this.board,
    required this.pot,
    required this.toCall,
    required this.bb,
    required this.seats,
    required this.frames,
    required this.options,
    required this.best,
    required this.accept,
    required this.rationale,
    this.equity,
    this.potOdds,
    required this.difficulty,
    this.gradeRange,
    this.gradeRangeTitle,
    this.lessonId,
    this.lessonTitle,
    this.icm,
  });

  final int id;
  final PuzzleKind kind;
  final PuzzleSource source;
  final Street street;
  final Position heroPos;

  /// Exactly two cards.
  final List<Card> hole;
  final HandLabel handLabel;
  final List<Card> board;

  /// Pot hero faces (incl. any bet to call).
  final double pot;
  final double toCall;
  final double bb;
  final List<DrillSeatView> seats;
  final List<DrillFrame> frames;
  final List<DrillOption> options;
  final DrillAction best;
  final List<DrillAction> accept;
  final String rationale;
  final double? equity;
  final double? potOdds;

  /// 1..3
  final int difficulty;

  /// The range this spot was graded against, for the feedback matrix.
  final List<HandLabel>? gradeRange;
  final String? gradeRangeTitle;

  /// Study lesson that teaches this spot's concept.
  final String? lessonId;
  final String? lessonTitle;

  /// ICM bubble spot (graded in tournament $EV, not chips).
  final bool? icm;

  /// The hole cards as a [Combo] record (for the equity helpers).
  Combo get holeCombo => (hole[0], hole[1]);

  /// Same shape (and key order) as the desktop `JSON.stringify(puzzle)`, so
  /// persisted review cards are interchangeable.
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.label,
    'source': source.label,
    'street': street.label,
    'heroPos': heroPos.label,
    'hole': hole,
    'handLabel': handLabel,
    'board': board,
    'pot': _jsonNum(pot),
    'toCall': _jsonNum(toCall),
    'bb': _jsonNum(bb),
    'seats': seats.map((s) => s.toJson()).toList(),
    'frames': frames.map((f) => f.toJson()).toList(),
    'options': options.map(_optionJson).toList(),
    'best': best.label,
    'accept': accept.map((a) => a.label).toList(),
    'rationale': rationale,
    if (equity != null) 'equity': _jsonNum(equity!),
    if (potOdds != null) 'potOdds': _jsonNum(potOdds!),
    'difficulty': difficulty,
    if (gradeRange != null) 'gradeRange': gradeRange,
    if (gradeRangeTitle != null) 'gradeRangeTitle': gradeRangeTitle,
    if (lessonId != null) 'lessonId': lessonId,
    if (lessonTitle != null) 'lessonTitle': lessonTitle,
    if (icm != null) 'icm': icm,
  };

  static Puzzle fromJson(Map<String, Object?> j) => Puzzle(
    id: (j['id'] as num).toInt(),
    kind: PuzzleKind.fromLabel(j['kind'] as String),
    source: PuzzleSource.fromLabel(j['source'] as String),
    street: Street.fromLabel(j['street'] as String),
    heroPos: Position.fromLabel(j['heroPos'] as String),
    hole: (j['hole'] as List).cast<String>(),
    handLabel: j['handLabel'] as String,
    board: (j['board'] as List).cast<String>(),
    pot: (j['pot'] as num).toDouble(),
    toCall: (j['toCall'] as num).toDouble(),
    bb: (j['bb'] as num).toDouble(),
    seats:
        (j['seats'] as List)
            .map(
              (s) => DrillSeatView.fromJson((s as Map).cast<String, Object?>()),
            )
            .toList(),
    frames:
        (j['frames'] as List)
            .map((f) => DrillFrame.fromJson((f as Map).cast<String, Object?>()))
            .toList(),
    options:
        (j['options'] as List)
            .map(
              (o) => DrillOption.fromJson((o as Map).cast<String, Object?>()),
            )
            .toList(),
    best: DrillAction.fromLabel(j['best'] as String),
    accept:
        (j['accept'] as List)
            .map((a) => DrillAction.fromLabel(a as String))
            .toList(),
    rationale: j['rationale'] as String,
    equity: (j['equity'] as num?)?.toDouble(),
    potOdds: (j['potOdds'] as num?)?.toDouble(),
    difficulty: (j['difficulty'] as num).toInt(),
    gradeRange: (j['gradeRange'] as List?)?.cast<String>(),
    gradeRangeTitle: j['gradeRangeTitle'] as String?,
    lessonId: j['lessonId'] as String?,
    lessonTitle: j['lessonTitle'] as String?,
    icm: j['icm'] as bool?,
  );
}

class GradeResult {
  const GradeResult({
    required this.correct,
    required this.best,
    required this.accept,
    required this.rationale,
    this.evLossBb,
  });
  final bool correct;
  final DrillAction best;
  final List<DrillAction> accept;
  final String rationale;

  /// How much the chosen action costs vs the best line, in bb — computable
  /// for pot-odds spots; null for chart spots.
  final double? evLossBb;
}

/* ------------------------------ Constants ------------------------------ */

/// Seat order the drill table renders (desktop `ORDER`).
const List<Position> kDrillOrder = [
  Position.utg,
  Position.mp,
  Position.co,
  Position.btn,
  Position.sb,
  Position.bb,
];
const List<Position> _order = kDrillOrder;
const double _sb = 0.5;
const double _bbv = 1;

/// Villain "continuing range" top-% by street (desktop `STREET_RANGE_PCT`).
const Map<Street, int> kStreetRangePct = {
  Street.flop: 45,
  Street.turn: 38,
  Street.river: 32,
};

/// Stacks the push/fold drill draws from (desktop `PF_STACKS`).
const List<int> kPushFoldDrillStacks = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

int _seq = 1;

/// Reset the session-local puzzle id counter (tests). Ids are not persisted.
void resetPuzzleSeq([int next = 1]) => _seq = next;

/* ------------------------------- Helpers ------------------------------- */

/// JavaScript `${number}` formatting: integral values print without a
/// decimal point, everything else in shortest round-trip form.
String jsNum(num v) {
  if (v is int) return v.toString();
  final d = v.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e21) {
    return jsIntString(d);
  }
  return d.toString();
}

/// JSON value for a bb amount: an int when integral (as `JSON.stringify`).
/// Delegates to the shared [jsonNum] so every module encodes numbers alike.
Object _jsonNum(double v) => jsonNum(v);

Map<String, Object?> _optionJson(DrillOption o) => {
  'action': o.action.label,
  'label': o.label,
  if (o.amount != null) 'amount': _jsonNum(o.amount!),
};

/// `Math.round(chartWidth(chart) * 100)`.
int pctOf(Map<String, num> chart) => jsRound(chartWidth(chart) * 100).toInt();

/// Labels a frequency chart plays at least half the time (chart order).
List<HandLabel> chartLabels05(Map<String, num> chart) => [
  for (final e in chart.entries)
    if (e.value >= 0.5) e.key,
];

/// Re-key a chart in JavaScript object enumeration order: integer-like keys
/// (the pairs `22`..`99`) first in ascending numeric order, then every other
/// key in insertion order. The generated charts in `lib/data` are already
/// emitted this way; this is only needed for maps built at runtime (the
/// desktop's `{ ...call, ...threebet }` spread), because label order feeds
/// [strengthSlice]'s stable sort and hence the grade range.
Map<String, T> jsObjectKeyOrder<T>(Map<String, T> m) {
  final numeric = <String>[];
  final other = <String>[];
  for (final k in m.keys) {
    (_isJsArrayIndex(k) ? numeric : other).add(k);
  }
  numeric.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  return {
    for (final k in numeric) k: m[k] as T,
    for (final k in other) k: m[k] as T,
  };
}

final RegExp _jsArrayIndex = RegExp(r'^(0|[1-9][0-9]*)$');
bool _isJsArrayIndex(String k) =>
    _jsArrayIndex.hasMatch(k) && k.length <= 10 && int.parse(k) < 4294967295;

int _rint(Random rng, int a, int b) => a + rng.nextInt(b - a + 1);
double _r1(double x) => jsRound(x * 10) / 10;
int _pct(double x) => jsRound(x * 100).toInt();
String _capital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

List<DrillSeatView> _fullSeats(
  Position heroPos,
  List<Position> foldedPos,
  List<Position> activePos,
) => [
  for (final pos in _order)
    DrillSeatView(
      pos: pos,
      isHero: pos == heroPos,
      folded: foldedPos.contains(pos),
      active: activePos.contains(pos) && pos != heroPos,
    ),
];

/// Expand a set of grid labels into int combos, removing blocked cards.
List<IntCombo> _rangeToCombos(Iterable<HandLabel> labels, Set<Card> blocked) {
  final out = <IntCombo>[];
  for (final lab in labels) {
    for (final (a, b) in labelToCombos(lab)) {
      if (blocked.contains(a) || blocked.contains(b)) continue;
      out.add(comboToInts((a, b)));
    }
  }
  return out;
}

/// Stable descending sort by [key] (JS `Array.prototype.sort` is stable;
/// Dart's is not guaranteed to be).
List<T> _stableSortedDesc<T>(List<T> items, double Function(T) key) {
  final idx = List<int>.generate(items.length, (i) => i);
  idx.sort((a, b) {
    final c = key(items[b]).compareTo(key(items[a]));
    return c != 0 ? c : a.compareTo(b);
  });
  return [for (final i in idx) items[i]];
}

List<Position> _nonBlinds(Iterable<Position> ps) => [
  for (final p in ps)
    if (p != Position.sb && p != Position.bb) p,
];

List<int> _ints(List<Card> cards) =>
    cards.map(cardToInt).toList(growable: false);

List<Card> _postflopBoard(List<Card> deck, Street street) {
  final n =
      street == Street.flop
          ? 3
          : street == Street.turn
          ? 4
          : 5;
  return deck.sublist(2, 2 + n);
}

/* ------------------------------- Preflop ------------------------------- */

Puzzle _genRfi(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  // hero in any non-BB seat, folded to them
  final heroIdx = _rint(rng, 0, 4); // UTG..SB
  final heroPos = _order[heroIdx];
  final foldedBefore = _nonBlinds(_order.sublist(0, heroIdx));
  // SB/BB before hero still post blinds (not "folded") — only non-blind earlier seats fold
  final heroIsSB = heroPos == Position.sb;
  final toCall = heroIsSB ? _bbv - _sb : _bbv;
  const pot = _sb + _bbv;

  final seats = _fullSeats(heroPos, foldedBefore, [
    for (final p in _order)
      if ((p == Position.sb || p == Position.bb) && p != heroPos) p,
  ]);

  final frames = <DrillFrame>[
    DrillFrame(
      text: 'Blinds posted (${jsNum(_sb)}/${jsNum(_bbv)} bb).',
      street: Street.preflop,
      board: const [],
      pot: pot,
    ),
    for (final p in foldedBefore)
      DrillFrame(
        text: '${p.label} folds.',
        street: Street.preflop,
        board: const [],
        pot: pot,
      ),
    DrillFrame(
      text: 'Folded to you in the ${heroPos.label}. Action on you.',
      street: Street.preflop,
      board: const [],
      pot: pot,
    ),
  ];

  final chart = kRfi100[heroPos.label] ?? const <String, double>{};
  final freq = chart[label] ?? 0;
  final mixed = freq > 0.2 && freq < 0.8;
  final best = freq >= 0.5 ? DrillAction.raise : DrillAction.fold;
  final accept = mixed ? [DrillAction.fold, DrillAction.raise] : [best];
  final openTo = _r1(2.5 * _bbv);
  final pct = pctOf(chart);

  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.rfi,
    source: PuzzleSource.chart,
    street: Street.preflop,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: const [],
    pot: pot,
    toCall: toCall,
    bb: _bbv,
    seats: seats,
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Limp ${jsNum(_r1(toCall))}',
        amount: toCall,
      ),
      DrillOption(
        action: DrillAction.raise,
        label: 'Open ${jsNum(openTo)}',
        amount: openTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale:
        mixed
            ? '${heroPos.label} opens about $pct% of hands here, and $label is a true mixed hand — the chart opens it ${_pct(freq)}% of the time, so raising and folding are both fine (just calling the minimum — limping — still isn\'t).'
            : freq >= 0.5
            ? '${heroPos.label} opens about $pct% of hands. $label is in that range, so the chart play is to raise (just calling the minimum — "limping" — isn\'t part of a solid opening strategy).'
            : '${heroPos.label} opens about $pct% of hands. $label isn\'t in that range, so fold — just calling the minimum (limping) here loses money over time.',
    difficulty: mixed ? 3 : 1,
    gradeRange: chartLabels05(chart),
    gradeRangeTitle: '${heroPos.label} opening range (~$pct%)',
    lessonId: 'opening-ranges',
    lessonTitle: 'Opening Ranges by Position',
  );
}

String _actName(DrillAction a) => a == DrillAction.raise ? '3-bet' : a.label;

Puzzle _genVsRaise(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final heroIdx = _rint(rng, 2, 5); // CO..BB
  final heroPos = _order[heroIdx];
  final raiserIdx = _rint(rng, 0, heroIdx - 1);
  final raiserPos = _order[raiserIdx];
  final heroInBlinds = heroPos == Position.bb || heroPos == Position.sb;
  final raiseTo = _r1(heroInBlinds ? 3 : 2.5);
  final heroBlind =
      heroPos == Position.sb
          ? _sb
          : heroPos == Position.bb
          ? _bbv
          : 0.0;
  final toCall = _r1(raiseTo - heroBlind);
  final pot = _r1(_sb + _bbv + raiseTo);

  final foldedBefore = [
    for (final p in _order.sublist(0, heroIdx))
      if (p != raiserPos && p != Position.sb && p != Position.bb) p,
  ];
  final seats = _fullSeats(heroPos, foldedBefore, [raiserPos]);

  final frames = <DrillFrame>[
    DrillFrame(
      text: 'Blinds posted (${jsNum(_sb)}/${jsNum(_bbv)} bb).',
      street: Street.preflop,
      board: const [],
      pot: _sb + _bbv,
    ),
  ];
  var p = _sb + _bbv;
  for (final fp in _nonBlinds(_order.sublist(0, raiserIdx))) {
    frames.add(
      DrillFrame(
        text: '${fp.label} folds.',
        street: Street.preflop,
        board: const [],
        pot: p,
      ),
    );
  }
  p = _r1(_sb + _bbv + raiseTo);
  frames.add(
    DrillFrame(
      text: '${raiserPos.label} raises to ${jsNum(raiseTo)} bb.',
      street: Street.preflop,
      board: const [],
      pot: p,
    ),
  );
  for (final fp in _nonBlinds(_order.sublist(raiserIdx + 1, heroIdx))) {
    frames.add(
      DrillFrame(
        text: '${fp.label} folds.',
        street: Street.preflop,
        board: const [],
        pot: p,
      ),
    );
  }
  frames.add(
    DrillFrame(
      text: 'Action on you in the ${heroPos.label}, facing a raise.',
      street: Street.preflop,
      board: const [],
      pot: p,
    ),
  );

  // Charts are keyed by hero AND raiser position — a BTN open gets
  // defended very differently from an UTG open.
  final charts = kVsRfi100['${heroPos.label}_vs_${raiserPos.label}'];
  final threebet = charts?['threebet'] ?? const <String, double>{};
  final call = charts?['call'] ?? const <String, double>{};
  final f3 = threebet[label] ?? 0.0;
  final fc = call[label] ?? 0.0;
  final ff = max(0.0, 1 - f3 - fc);
  final freqs = _stableSortedDesc<(DrillAction, double)>([
    (DrillAction.raise, f3),
    (DrillAction.call, fc),
    (DrillAction.fold, ff),
  ], (e) => e.$2);
  final best = freqs[0].$1;
  final accept = [
    for (final (a, f) in freqs)
      if (f >= 0.25) a,
  ];
  if (!accept.contains(best)) accept.insert(0, best);
  final mixed = accept.length > 1;
  String rationale;
  if (mixed) {
    final parts = [
      for (final (a, f) in freqs)
        if (f >= 0.25) '${_actName(a)}s ${_pct(f)}%',
    ].join(' / ');
    rationale =
        'Facing a ${raiserPos.label} open from the ${heroPos.label}, $label is a genuine mix: the chart $parts of the time. Any of those is fine.';
  } else if (best == DrillAction.raise) {
    rationale =
        'Facing a ${raiserPos.label} open, $label is in the ${heroPos.label} 3-bet range (~${pctOf(threebet)}% of hands) — re-raise for value/pressure.';
  } else if (best == DrillAction.call) {
    rationale =
        'Facing a ${raiserPos.label} open, $label is too weak to 3-bet but inside the ${heroPos.label} calling range (~${pctOf(call)}%), so call and see a flop.';
  } else {
    rationale =
        '$label is outside the ${heroPos.label} continuing range vs a ${raiserPos.label} open (~${pctOf(threebet) + pctOf(call)}% continues) — fold.';
  }
  final threeBetTo = _r1(raiseTo * (heroInBlinds ? 3.5 : 3));

  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.vsRaise,
    source: PuzzleSource.chart,
    street: Street.preflop,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: const [],
    pot: pot,
    toCall: toCall,
    bb: _bbv,
    seats: seats,
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Call ${jsNum(toCall)}',
        amount: toCall,
      ),
      DrillOption(
        action: DrillAction.raise,
        label: '3-bet ${jsNum(threeBetTo)}',
        amount: threeBetTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale: rationale,
    difficulty: mixed ? 3 : 2,
    gradeRange: {...chartLabels05(threebet), ...chartLabels05(call)}.toList(),
    gradeRangeTitle:
        '${heroPos.label} continue range vs a ${raiserPos.label} open',
    lessonId: 'three-betting',
    lessonTitle: '3-Betting',
  );
}

/* ------------------------------- Postflop ------------------------------- */

Puzzle _genPostflopBet(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final street =
      const [Street.flop, Street.turn, Street.river][_rint(rng, 0, 2)];
  final board = _postflopBoard(deck, street);

  final heroPos = rng.nextDouble() < 0.5 ? Position.bb : Position.btn;
  final villainPos = heroPos == Position.bb ? Position.co : Position.bb;
  final potBeforeBet = _r1(
    5 + _rint(rng, 0, 8).toDouble(),
  ); // single-raised-ish pot
  final betFrac = const [0.5, 0.66, 1.0][_rint(rng, 0, 2)];
  final bet = _r1(potBeforeBet * betFrac);
  final pot = _r1(potBeforeBet + bet);
  final toCall = bet;

  final blocked = <Card>{...hole, ...board};
  final villRange = topPercentRange(kStreetRangePct[street]!);
  final combos = _rangeToCombos(villRange, blocked);
  final heroInts = comboToInts((hole[0], hole[1]));
  final boardInts = _ints(board);
  // Seeded by the spot itself: re-grading the same puzzle always gives
  // the same answer. Turn/river spots are enumerated exactly.
  final r =
      combos.isNotEmpty
          ? equityVsRange(
            heroInts,
            boardInts,
            combos,
            iters: 3000,
            seed: hashSeed('${hole.join()}|${board.join()}'),
          )
          : null;
  final eq = r?.equity ?? 0.5;
  final breakEven = toCall / (pot + toCall);
  final band = max(0.02, 2 * (r?.se ?? 0));

  DrillAction best;
  List<DrillAction> accept;
  var closeCall = false;
  if (eq >= breakEven + band) {
    best = DrillAction.call;
    accept =
        eq > 0.72 ? [DrillAction.call, DrillAction.raise] : [DrillAction.call];
  } else if (eq <= breakEven - band) {
    best = DrillAction.fold;
    accept = [DrillAction.fold];
  } else {
    // Inside the noise/indifference band: either answer is accepted.
    closeCall = true;
    best = eq >= breakEven ? DrillAction.call : DrillAction.fold;
    accept = [DrillAction.fold, DrillAction.call];
  }

  final seats = _fullSeats(
    heroPos,
    [
      for (final pp in _order)
        if (pp != heroPos && pp != villainPos) pp,
    ],
    [villainPos],
  );

  final frames = <DrillFrame>[
    DrillFrame(
      text:
          'Pre-flop: ${villainPos.label} raised, you called from the ${heroPos.label}. Heads-up.',
      street: Street.preflop,
      board: const [],
      pot: potBeforeBet,
    ),
    DrillFrame(
      text: '${_capital(street.label)}: ${board.join(' ')}',
      street: street,
      board: [...board],
      pot: potBeforeBet,
    ),
    DrillFrame(
      text: '${villainPos.label} bets ${jsNum(bet)} bb.',
      street: street,
      board: [...board],
      pot: pot,
    ),
    DrillFrame(
      text: 'Action on you.',
      street: street,
      board: [...board],
      pot: pot,
    ),
  ];

  final raiseTo = _r1(pot + bet);
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.postflopBet,
    source: PuzzleSource.heuristic,
    street: street,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: board,
    pot: pot,
    toCall: toCall,
    bb: _bbv,
    seats: seats,
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Call ${jsNum(toCall)}',
        amount: toCall,
      ),
      DrillOption(
        action: DrillAction.raise,
        label: 'Raise ${jsNum(raiseTo)}',
        amount: raiseTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale:
        closeCall
            ? 'Razor-thin: ~${_pct(eq)}% equity against a plausible ${street.label} continuing range vs ${_pct(breakEven)}% pot odds. That\'s inside the margin where folding and calling are both fine — ${best == DrillAction.call ? 'calling' : 'folding'} is marginally better.'
            : 'You have ~${_pct(eq)}% equity against a plausible ${street.label} continuing range, and your call needs to win ${_pct(breakEven)}% to break even (your pot odds). ${best == DrillAction.call ? (eq > 0.72 ? 'That\'s a clear call — and strong enough to raise for value.' : 'Equity beats the price, so call.') : 'Equity is below the price, so fold.'}',
    equity: eq,
    potOdds: breakEven,
    difficulty: eq > breakEven - 0.06 && eq < breakEven + 0.06 ? 3 : 2,
    gradeRange: villRange.toList(),
    gradeRangeTitle:
        '${villainPos.label}\'s assumed ${street.label} continuing range',
    lessonId: 'pot-odds',
    lessonTitle: 'Pot Odds, Break-even & EV',
  );
}

Puzzle _genPostflopCheck(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final street = const [Street.flop, Street.turn][_rint(rng, 0, 1)];
  final board = _postflopBoard(deck, street);

  const heroPos = Position.btn;
  const villainPos = Position.bb;
  final pot = _r1(5 + _rint(rng, 0, 6).toDouble());

  final blocked = <Card>{...hole, ...board};
  final combos = _rangeToCombos(
    topPercentRange(kStreetRangePct[street]!),
    blocked,
  );
  final r =
      combos.isNotEmpty
          ? equityVsRange(
            comboToInts((hole[0], hole[1])),
            _ints(board),
            combos,
            iters: 3000,
            seed: hashSeed('${hole.join()}|${board.join()}'),
          )
          : null;
  final eq = r?.equity ?? 0.5;
  final band = max(0.02, 2 * (r?.se ?? 0));

  DrillAction best;
  List<DrillAction> accept;
  if (eq > 0.6 + band) {
    best = DrillAction.bet;
    accept = [DrillAction.bet];
  } else if (eq > 0.5 - band) {
    best = eq > 0.5 ? DrillAction.bet : DrillAction.check;
    accept = [DrillAction.bet, DrillAction.check];
  } else {
    best = DrillAction.check;
    accept = [DrillAction.check];
  }

  final seats = _fullSeats(
    heroPos,
    [
      for (final pp in _order)
        if (pp != heroPos && pp != villainPos) pp,
    ],
    [villainPos],
  );
  final betTo = _r1(pot * 0.66);
  final frames = <DrillFrame>[
    DrillFrame(
      text:
          'Pre-flop: you raised from the ${heroPos.label}, ${villainPos.label} called. Heads-up.',
      street: Street.preflop,
      board: const [],
      pot: pot,
    ),
    DrillFrame(
      text: '${_capital(street.label)}: ${board.join(' ')}',
      street: street,
      board: [...board],
      pot: pot,
    ),
    DrillFrame(
      text: '${villainPos.label} checks. Action on you.',
      street: street,
      board: [...board],
      pot: pot,
    ),
  ];

  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.postflopCheck,
    source: PuzzleSource.heuristic,
    street: street,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: board,
    pot: pot,
    toCall: 0,
    bb: _bbv,
    seats: seats,
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.check, label: 'Check'),
      DrillOption(
        action: DrillAction.bet,
        label: 'Bet ${jsNum(betTo)}',
        amount: betTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale:
        'With ~${_pct(eq)}% equity vs ${villainPos.label}\'s range, ${accept.length == 2
            ? 'betting and checking are both fine — it\'s a marginal value/pot-control spot.'
            : best == DrillAction.bet
            ? 'you\'re ahead often enough to bet for value.'
            : 'you don\'t have enough to value bet; check and keep the pot small.'}',
    equity: eq,
    difficulty: 2,
    gradeRange: topPercentRange(kStreetRangePct[street]!).toList(),
    gradeRangeTitle: '${villainPos.label}\'s assumed ${street.label} range',
    lessonId: 'bet-sizing',
    lessonTitle: 'Bet Sizing',
  );
}

/* ------------- Late-street families (3-bet pots, check-raises,
   river-as-aggressor) — the spots where the money changes hands ------------- */

/// Rank a label set by strength on a board (seeded, deterministic) and
/// keep the strongest fraction, optionally with a bluff tail.
List<HandLabel> strengthSlice(
  List<HandLabel> labels,
  List<Card> board,
  double topFrac,
  bool bluffTail,
) {
  final boardInts = _ints(board);
  final blocked = <Card>{...board};
  // Deterministic per (label, board): seeded 80-iter equity vs random.
  final scored = <(HandLabel, double)>[];
  for (final l in labels) {
    Combo? first;
    for (final c in labelToCombos(l)) {
      if (!blocked.contains(c.$1) && !blocked.contains(c.$2)) {
        first = c;
        break;
      }
    }
    if (first == null) continue;
    final eq =
        equityVsRandom(
          comboToInts(first),
          boardInts,
          iters: 80,
          seed: hashSeed('$l|${board.join()}'),
        ).equity;
    scored.add((l, eq));
  }
  final ranked = _stableSortedDesc(scored, (x) => x.$2);
  final keep = max(4, jsRound(ranked.length * topFrac).toInt());
  final top = [for (final x in ranked.take(keep)) x.$1];
  if (!bluffTail) return top;
  final tail = [
    for (final x in ranked.skip(jsRound(ranked.length * 0.85).toInt())) x.$1,
  ];
  return [...top, ...tail];
}

/// 3-bet pot: hero opened, got 3-bet, called; now faces a c-bet at low SPR.
Puzzle _genThreeBetPot(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final street = rng.nextDouble() < 0.7 ? Street.flop : Street.turn;
  final board = _postflopBoard(deck, street);
  final heroPos = rng.nextDouble() < 0.5 ? Position.co : Position.btn;
  final villainPos = rng.nextDouble() < 0.5 ? Position.sb : Position.bb;

  // Villain's 3-bet range (hero position is what they 3-bet against).
  final key = '${villainPos.label}_vs_${heroPos.label}';
  final tbChart =
      kVsRfi100[key]?['threebet'] ?? kVsRfi100['BB_vs_BTN']!['threebet']!;
  final villLabels = chartLabels05(tbChart);

  const pot = 20.0; // ~3-bet pot in bb
  final bet = _r1(pot * const [0.4, 0.66][_rint(rng, 0, 1)]);
  final totalPot = _r1(pot + bet);
  final blocked = <Card>{...hole, ...board};
  final combos = _rangeToCombos(villLabels, blocked);
  final r =
      combos.isNotEmpty
          ? equityVsRange(
            comboToInts((hole[0], hole[1])),
            _ints(board),
            combos,
            iters: 3000,
            seed: hashSeed('3bp|${hole.join()}|${board.join()}'),
          )
          : null;
  final eq = r?.equity ?? 0.5;
  final breakEven = bet / (totalPot + bet);
  final band = max(0.02, 2 * (r?.se ?? 0));

  DrillAction best;
  List<DrillAction> accept;
  var closeCall = false;
  if (eq >= breakEven + band) {
    best = DrillAction.call;
    accept =
        eq > 0.62 ? [DrillAction.call, DrillAction.raise] : [DrillAction.call];
  } else if (eq <= breakEven - band) {
    best = DrillAction.fold;
    accept = [DrillAction.fold];
  } else {
    closeCall = true;
    best = eq >= breakEven ? DrillAction.call : DrillAction.fold;
    accept = [DrillAction.fold, DrillAction.call];
  }

  final frames = <DrillFrame>[
    DrillFrame(
      text:
          'You open ${heroPos.label} to 2.5 bb; ${villainPos.label} 3-bets to 9 bb; you call. Heads-up.',
      street: Street.preflop,
      board: const [],
      pot: pot,
    ),
    DrillFrame(
      text:
          '${_capital(street.label)}: ${board.join(' ')} (pot 20 bb — stacks are only ~4.5 pots deep: a low SPR).',
      street: street,
      board: [...board],
      pot: pot,
    ),
    DrillFrame(
      text: '${villainPos.label} c-bets ${jsNum(bet)} bb. Action on you.',
      street: street,
      board: [...board],
      pot: totalPot,
    ),
  ];

  final raiseTo = _r1(totalPot + bet);
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.threebetPot,
    source: PuzzleSource.heuristic,
    street: street,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: board,
    pot: totalPot,
    toCall: bet,
    bb: _bbv,
    seats: _fullSeats(
      heroPos,
      [
        for (final p in _order)
          if (p != heroPos && p != villainPos) p,
      ],
      [villainPos],
    ),
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Call ${jsNum(bet)}',
        amount: bet,
      ),
      DrillOption(
        action: DrillAction.raise,
        label: 'Raise ${jsNum(raiseTo)}',
        amount: raiseTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale:
        closeCall
            ? 'Razor-thin in a 3-bet pot: ~${_pct(eq)}% equity vs a 3-betting range, ${_pct(breakEven)}% needed — both answers are fine. Remember the low SPR: whatever continues here is often committed.'
            : 'In a 3-bet pot your opponent\'s range is strong (big pairs, big cards) — your $label has ~${_pct(eq)}% equity against it, and you need ${_pct(breakEven)}%. ${best == DrillAction.call ? 'That\'s enough — and with stacks this shallow (SPR ~4), plan for the rest going in on many turn and river cards.' : 'Not enough against this range at this price — fold and keep the 9 bb loss small.'}',
    equity: eq,
    potOdds: breakEven,
    difficulty: (eq - breakEven).abs() < 0.06 ? 3 : 2,
    gradeRange: villLabels,
    gradeRangeTitle: '${villainPos.label}\'s 3-bet range vs ${heroPos.label}',
    lessonId: 'threebet-pots',
    lessonTitle: 'Playing 3-Bet Pots',
  );
}

/// Facing a check-raise: hero c-bet, the caller check-raised.
Puzzle _genFacingCheckRaise(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final board = _postflopBoard(deck, Street.flop);
  const heroPos = Position.btn;
  const villainPos = Position.bb;

  // BB defended, then check-raised: strong slice of the defend range + bluff tail.
  // (Object spread: a label in both charts takes the 3-bet frequency, and the
  // merged keys enumerate in JS order — pairs 22..99 first — as desktop.)
  final bbVsBtn = kVsRfi100['BB_vs_BTN']!;
  final defend = chartLabels05(
    jsObjectKeyOrder({...bbVsBtn['call']!, ...bbVsBtn['threebet']!}),
  );
  final villLabels = strengthSlice(defend, board, 0.3, true);

  const potPre = 5.5;
  const cbet = 2.5;
  const raiseTo = 8.0;
  const toCall = raiseTo - cbet;
  final pot = _r1(potPre + cbet + raiseTo);
  final blocked = <Card>{...hole, ...board};
  final combos = _rangeToCombos(villLabels, blocked);
  final r =
      combos.isNotEmpty
          ? equityVsRange(
            comboToInts((hole[0], hole[1])),
            _ints(board),
            combos,
            iters: 3000,
            seed: hashSeed('xr|${hole.join()}|${board.join()}'),
          )
          : null;
  final eq = r?.equity ?? 0.5;
  final breakEven = toCall / (pot + toCall);
  final band = max(0.02, 2 * (r?.se ?? 0));

  DrillAction best;
  List<DrillAction> accept;
  if (eq >= breakEven + band) {
    best = DrillAction.call;
    accept =
        eq > 0.68 ? [DrillAction.call, DrillAction.raise] : [DrillAction.call];
  } else if (eq <= breakEven - band) {
    best = DrillAction.fold;
    accept = [DrillAction.fold];
  } else {
    best = eq >= breakEven ? DrillAction.call : DrillAction.fold;
    accept = [DrillAction.fold, DrillAction.call];
  }

  final frames = <DrillFrame>[
    DrillFrame(
      text:
          'You open the ${heroPos.label} to 2.5 bb, ${villainPos.label} calls. Heads-up.',
      street: Street.preflop,
      board: const [],
      pot: potPre,
    ),
    DrillFrame(
      text:
          'Flop: ${board.join(' ')}. ${villainPos.label} checks, you c-bet ${jsNum(cbet)} bb.',
      street: Street.flop,
      board: [...board],
      pot: _r1(potPre + cbet),
    ),
    DrillFrame(
      text:
          '${villainPos.label} check-raises to ${jsNum(raiseTo)} bb. Action on you.',
      street: Street.flop,
      board: [...board],
      pot: pot,
    ),
  ];

  final threeBetTo = _r1(raiseTo * 2.6);
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.checkRaise,
    source: PuzzleSource.heuristic,
    street: Street.flop,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: board,
    pot: pot,
    toCall: toCall,
    bb: _bbv,
    seats: _fullSeats(
      heroPos,
      [
        for (final p in _order)
          if (p != heroPos && p != villainPos) p,
      ],
      [villainPos],
    ),
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Call ${jsNum(_r1(toCall))}',
        amount: toCall,
      ),
      DrillOption(
        action: DrillAction.raise,
        label: '3-bet ${jsNum(threeBetTo)}',
        amount: threeBetTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale:
        'A check-raise represents the strong part of ${villainPos.label}\'s defend range plus some draws. Your $label has ~${_pct(eq)}% equity against that, needing ${_pct(breakEven)}%. ${best == DrillAction.call
            ? 'Continue — folding here would let check-raises print money against your c-bets.'
            : best == DrillAction.fold
            ? 'Let this one go — c-betting means sometimes folding to check-raises; that\'s fine when the hand has this little.'
            : 'Continue.'}',
    equity: eq,
    potOdds: breakEven,
    difficulty: (eq - breakEven).abs() < 0.06 ? 3 : 2,
    gradeRange: villLabels,
    gradeRangeTitle:
        '${villainPos.label}\'s check-raising range (strong hands + draws)',
    lessonId: 'check-raising',
    lessonTitle: 'Check-Raising',
  );
}

/// River as the aggressor: you bet flop and turn; villain called twice
/// and checks the river to you. Value bet or check back?
Puzzle _genRiverDecision(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final board = _postflopBoard(deck, Street.river);
  const heroPos = Position.btn;
  const villainPos = Position.bb;

  // Called flop AND turn: the middle-strength slice of the defend range
  // (twice narrowed; the very top would have raised, the air folded).
  final defend = chartLabels05(kVsRfi100['BB_vs_BTN']!['call']!);
  final once = strengthSlice(defend, board.sublist(0, 3), 0.65, false);
  final villLabels = strengthSlice(once, board.sublist(0, 4), 0.65, false);

  const pot = 14.0;
  final betTo = _r1(pot * 0.66);
  final blocked = <Card>{...hole, ...board};
  final combos = _rangeToCombos(villLabels, blocked);
  final r =
      combos.isNotEmpty
          ? equityVsRange(
            comboToInts((hole[0], hole[1])),
            _ints(board),
            combos,
            iters: 10,
            seed: hashSeed('rv|${hole.join()}|${board.join()}'),
          )
          : null;
  final eq = r?.equity ?? 0.5; // river = exact enumeration
  final band = max(0.02, 2 * (r?.se ?? 0));

  DrillAction best;
  List<DrillAction> accept;
  if (eq > 0.6 + band) {
    best = DrillAction.bet;
    accept = [DrillAction.bet];
  } else if (eq > 0.48 - band) {
    best = eq > 0.54 ? DrillAction.bet : DrillAction.check;
    accept = [DrillAction.bet, DrillAction.check];
  } else {
    best = DrillAction.check;
    accept = [DrillAction.check];
  }

  final frames = <DrillFrame>[
    DrillFrame(
      text:
          'You open the ${heroPos.label}, ${villainPos.label} calls. You bet the flop and turn; ${villainPos.label} called both.',
      street: Street.preflop,
      board: const [],
      pot: 5.5,
    ),
    DrillFrame(
      text: 'River: ${board.join(' ')} (pot ${jsNum(pot)} bb).',
      street: Street.river,
      board: [...board],
      pot: pot,
    ),
    DrillFrame(
      text: '${villainPos.label} checks. Value bet or check back?',
      street: Street.river,
      board: [...board],
      pot: pot,
    ),
  ];

  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.riverDecision,
    source: PuzzleSource.heuristic,
    street: Street.river,
    heroPos: heroPos,
    hole: hole,
    handLabel: label,
    board: board,
    pot: pot,
    toCall: 0,
    bb: _bbv,
    seats: _fullSeats(
      heroPos,
      [
        for (final p in _order)
          if (p != heroPos && p != villainPos) p,
      ],
      [villainPos],
    ),
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.check, label: 'Check back'),
      DrillOption(
        action: DrillAction.bet,
        label: 'Bet ${jsNum(betTo)}',
        amount: betTo,
      ),
    ],
    best: best,
    accept: accept,
    rationale:
        accept.length == 2
            ? 'Against the hands that called twice, your $label wins ~${_pct(eq)}% — right on the value/showdown border, so betting thin and checking back are both fine.'
            : best == DrillAction.bet
            ? 'The hands that called flop and turn still pay off a river bet often enough: ~${_pct(eq)}% equity against that range. Name the worse hands that call — here there are plenty — and bet.'
            : 'Against the range that called two streets, your $label only wins ~${_pct(eq)}% — worse hands rarely call a third bet. Take the showdown; betting would mostly get called when you\'re beaten.',
    equity: eq,
    difficulty: (eq - 0.55).abs() < 0.08 ? 3 : 2,
    gradeRange: villLabels,
    gradeRangeTitle: '${villainPos.label}\'s range after calling flop + turn',
    lessonId: 'turn-river',
    lessonTitle: 'Turn & River Play',
  );
}

/* --------------- Exploit drills: best deviation vs a KNOWN type ---------------
   The coach's play-mode verdicts grade vs the specific bot's likely
   hands (an exploitative baseline). These drills teach the concept
   explicitly: spots where the right play vs THIS opponent differs
   from the balanced play, with both numbers shown. --------------- */

Puzzle generateExploit({Random? rng}) {
  rng ??= Random();
  final template = _rint(rng, 0, 2);
  final deck = shuffle(makeDeck(), rng: rng);

  if (template == 0) {
    // Thin value vs a Station: they call river bets with far too much.
    late List<Card> hole;
    late List<Card> board;
    late double eqStation;
    late double eqBalanced;
    var tries = 0;
    // Deal until hero has a modest-but-ahead river hand (the thin-value zone).
    do {
      final d = shuffle(makeDeck(), rng: rng);
      hole = [d[0], d[1]];
      board = d.sublist(2, 7);
      final blocked = <Card>{...hole, ...board};
      final stationRange = _rangeToCombos(
        topPercentRange(60),
        blocked,
      ); // calls with almost anything playable
      final balancedRange = _rangeToCombos(
        topPercentRange(28),
        blocked,
      ); // a sane calling range
      final bInts = _ints(board);
      final heroInts = comboToInts((hole[0], hole[1]));
      eqStation =
          stationRange.isNotEmpty
              ? equityVsRange(
                heroInts,
                bInts,
                stationRange,
                iters: 10,
                seed: hashSeed('ex0|${hole.join()}|${board.join()}'),
              ).equity
              : 0.5;
      eqBalanced =
          balancedRange.isNotEmpty
              ? equityVsRange(
                heroInts,
                bInts,
                balancedRange,
                iters: 10,
                seed: hashSeed('ex0b|${hole.join()}|${board.join()}'),
              ).equity
              : 0.5;
    } while ((eqStation < 0.56 || eqStation > 0.75) && ++tries < 80);
    final label = cardsToLabel(hole[0], hole[1]);
    const pot = 9.0;
    final betTo = _r1(pot * 0.6);
    final gain = _r1((eqStation - 0.5) * betTo * 2 * 10) / 10;
    return Puzzle(
      id: _seq++,
      kind: PuzzleKind.exploit,
      source: PuzzleSource.heuristic,
      street: Street.river,
      heroPos: Position.btn,
      hole: hole,
      handLabel: label,
      board: board,
      pot: pot,
      toCall: 0,
      bb: _bbv,
      seats: _fullSeats(
        Position.btn,
        [
          for (final p in _order)
            if (p != Position.btn && p != Position.bb) p,
        ],
        [Position.bb],
      ),
      frames: [
        const DrillFrame(
          text:
              'The BB is a CALLING STATION (calls ~60% of hands to the river). You bet flop and turn; they called both.',
          street: Street.preflop,
          board: [],
          pot: 5,
        ),
        DrillFrame(
          text:
              'River: ${board.join(' ')} (pot ${jsNum(pot)} bb). The Station checks.',
          street: Street.river,
          board: [...board],
          pot: pot,
        ),
        DrillFrame(
          text:
              'Your hand wins ~${_pct(eqStation)}% against THEIR calling range. Action on you.',
          street: Street.river,
          board: [...board],
          pot: pot,
        ),
      ],
      options: [
        const DrillOption(action: DrillAction.check, label: 'Check back'),
        DrillOption(
          action: DrillAction.bet,
          label: 'Bet ${jsNum(betTo)}',
          amount: betTo,
        ),
      ],
      best: DrillAction.bet,
      accept: const [DrillAction.bet],
      rationale:
          'THE EXPLOIT: vs a balanced player your $label (${_pct(eqBalanced)}% vs a sane calling range) is a check — worse hands rarely pay a third bet. But a Station calls with almost anything, so the same hand wins ~${_pct(eqStation)}% against what they\'ll CALL with. Bet thin, every time — that\'s roughly +${jsNum(gain)} bb the balanced line leaves behind. Vs Stations: value bet more, never bluff.',
      equity: eqStation,
      difficulty: 2,
      gradeRange: topPercentRange(60).toList(),
      gradeRangeTitle: 'What a Station calls a river bet with (~60%)',
      lessonId: 'exploits',
      lessonTitle: 'Exploiting the Archetypes',
      icm: false,
    );
  }

  if (template == 1) {
    // Respect the Nit's raise: their aggression is value-heavy.
    late List<Card> hole;
    late List<Card> board;
    late double eqNit;
    late double eqBalanced;
    var tries = 0;
    do {
      final d = shuffle(makeDeck(), rng: rng);
      hole = [d[0], d[1]];
      board = d.sublist(2, 6);
      final blocked = <Card>{...hole, ...board};
      final nitRaise = _rangeToCombos(
        topPercentRange(4),
        blocked,
      ); // near-nuts only
      final balancedRaise = _rangeToCombos(topPercentRange(11), blocked);
      final bInts = _ints(board);
      final heroInts = comboToInts((hole[0], hole[1]));
      eqNit =
          nitRaise.isNotEmpty
              ? equityVsRange(
                heroInts,
                bInts,
                nitRaise,
                iters: 10,
                seed: hashSeed('ex1|${hole.join()}|${board.join()}'),
              ).equity
              : 0.5;
      eqBalanced =
          balancedRaise.isNotEmpty
              ? equityVsRange(
                heroInts,
                bInts,
                balancedRaise,
                iters: 10,
                seed: hashSeed('ex1b|${hole.join()}|${board.join()}'),
              ).equity
              : 0.5;
    } while ((eqNit > 0.38 || eqBalanced < 0.42) && ++tries < 80);
    final label = cardsToLabel(hole[0], hole[1]);
    const pot = 16.0;
    const toCall = 10.0;
    const breakEven = toCall / (pot + toCall);
    return Puzzle(
      id: _seq++,
      kind: PuzzleKind.exploit,
      source: PuzzleSource.heuristic,
      street: Street.turn,
      heroPos: Position.co,
      hole: hole,
      handLabel: label,
      board: board,
      pot: _r1(pot + toCall),
      toCall: toCall,
      bb: _bbv,
      seats: _fullSeats(
        Position.co,
        [
          for (final p in _order)
            if (p != Position.co && p != Position.bb) p,
        ],
        [Position.bb],
      ),
      frames: [
        const DrillFrame(
          text:
              'The BB is a NIT (raises only with hands close to the best possible). You bet the turn with a decent hand.',
          street: Street.preflop,
          board: [],
          pot: pot,
        ),
        DrillFrame(
          text:
              'Turn: ${board.join(' ')}. The Nit RAISES to ${jsNum(toCall + 6)} bb.',
          street: Street.turn,
          board: [...board],
          pot: _r1(pot + toCall),
        ),
        DrillFrame(
          text: 'Action on you — it costs ${jsNum(toCall)} bb more.',
          street: Street.turn,
          board: [...board],
          pot: _r1(pot + toCall),
        ),
      ],
      options: [
        const DrillOption(action: DrillAction.fold, label: 'Fold'),
        DrillOption(
          action: DrillAction.call,
          label: 'Call ${jsNum(toCall)}',
          amount: toCall,
        ),
      ],
      best: DrillAction.fold,
      accept: const [DrillAction.fold],
      rationale:
          'THE EXPLOIT: vs a balanced raiser your $label has ~${_pct(eqBalanced)}% equity — enough for the ${_pct(breakEven)}% price, so balanced play calls. But a Nit\'s raise means close to the best possible hand: against THAT range you have ~${_pct(eqNit)}%. Folding "too much" here isn\'t a leak — it\'s the profit. When a Nit wakes up, believe them.',
      equity: eqNit,
      potOdds: breakEven,
      difficulty: 2,
      gradeRange: topPercentRange(4).toList(),
      gradeRangeTitle: 'What a Nit raises the turn with (~4%)',
      lessonId: 'exploits',
      lessonTitle: 'Exploiting the Archetypes',
      icm: false,
    );
  }

  // Template 2: steal relentlessly from a Nit's blind.
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final baseline = kRfi100['SB']![label] ?? 0.0;
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.exploit,
    source: PuzzleSource.chart,
    street: Street.preflop,
    heroPos: Position.sb,
    hole: hole,
    handLabel: label,
    board: const [],
    pot: _sb + _bbv,
    toCall: _bbv - _sb,
    bb: _bbv,
    seats: _fullSeats(
      Position.sb,
      const [Position.utg, Position.mp, Position.co, Position.btn],
      const [Position.bb],
    ),
    frames: [
      const DrillFrame(
        text:
            'The BB is a NIT — they defend their blind with only ~12% of hands and fold the rest.',
        street: Street.preflop,
        board: [],
        pot: _sb + _bbv,
      ),
      DrillFrame(
        text: 'Folded to you in the SB with $label. Action on you.',
        street: Street.preflop,
        board: const [],
        pot: _sb + _bbv,
      ),
    ],
    options: const [
      DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(action: DrillAction.raise, label: 'Raise 3 bb', amount: 3),
    ],
    best: DrillAction.raise,
    accept:
        baseline >= 0.5 ? const [DrillAction.raise] : const [DrillAction.raise],
    rationale:
        'THE EXPLOIT: the balanced SB chart ${baseline >= 0.5 ? 'already raises $label' : 'folds $label (it opens ~41% of hands)'} — but this Nit folds their blind ~88% of the time. Raising ANY TWO wins 1.5 bb immediately at a cost of 3, needing only ~67% folds to profit before the flop is even dealt. Against blind-folders, attack relentlessly with everything.',
    difficulty: 1,
    gradeRange: topPercentRange(100).toList(),
    gradeRangeTitle: 'The exploit raise-range vs a Nit\'s blind: any two',
    lessonId: 'exploits',
    lessonTitle: 'Exploiting the Archetypes',
    icm: false,
  );
}

/// Generate a random puzzle (weighted across all spot families).
Puzzle generatePuzzle({Random? rng}) {
  rng ??= Random();
  final roll = rng.nextDouble();
  if (roll < 0.22) return _genRfi(rng);
  if (roll < 0.42) return _genVsRaise(rng);
  if (roll < 0.62) return _genPostflopBet(rng);
  if (roll < 0.72) return _genPostflopCheck(rng);
  if (roll < 0.84) return _genThreeBetPot(rng);
  if (roll < 0.92) return _genFacingCheckRaise(rng);
  return _genRiverDecision(rng);
}

/* --------------- Push/Fold (computed Nash equilibrium tables) --------------- */

/// Grade + accept-set + beginner-first rationale from an equilibrium
/// frequency. True mixed-frequency hands accept either answer.
({DrillAction best, List<DrillAction> accept, String rationale}) gradeFromFreq(
  double freq,
  String label,
  int stack,
  DrillAction aggressive,
  String aggroWord,
  String context,
) {
  final best = freq >= 0.5 ? aggressive : DrillAction.fold;
  final mixed = freq > 0.2 && freq < 0.8;
  final accept = mixed ? [DrillAction.fold, aggressive] : [best];
  String rationale;
  if (freq >= 0.98) {
    rationale =
        '$context $label is clearly inside the equilibrium $aggroWord range at $stack bb — $aggroWord.';
  } else if (freq <= 0.02) {
    rationale =
        '$context $label is outside the equilibrium $aggroWord range at $stack bb — fold.';
  } else {
    rationale =
        '$context A true mixed spot: the equilibrium ${aggroWord}s $label about ${_pct(freq)}% of the time here, so either answer is fine.';
  }
  return (best: best, accept: accept, rationale: rationale);
}

/// ICM bubble push/fold: 4 players, 3 paid — graded in $EV.
Puzzle _generateIcmPushFold(Random rng) {
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final sc = kIcmScenarios[_rint(rng, 0, kIcmScenarios.length - 1)];
  final heroIsSB = rng.nextDouble() < 0.55;
  final sbStack = sc.stacks[0];
  final bbStack = sc.stacks[1];
  final o1 = sc.stacks[2];
  final o2 = sc.stacks[3];

  const icmNote =
      'Bubble: 4 players left, 3 get paid (50/30/20). Chips you might WIN are worth less than the chips you\'d LOSE — busting here costs everything.';

  if (heroIsSB) {
    final freq = sc.jam[label] ?? 0.0;
    final g = gradeFromFreq(
      freq,
      label,
      sbStack,
      DrillAction.raise,
      'shove',
      '${sc.name}: folded to you in the SB with $sbStack bb (ICM, \$EV). $icmNote',
    );
    return Puzzle(
      id: _seq++,
      kind: PuzzleKind.pushfold,
      source: PuzzleSource.chart,
      street: Street.preflop,
      heroPos: Position.sb,
      hole: hole,
      handLabel: label,
      board: const [],
      pot: _sb + _bbv,
      toCall: _bbv - _sb,
      bb: _bbv,
      seats: _fullSeats(
        Position.sb,
        const [Position.utg, Position.mp],
        const [Position.bb],
      ),
      frames: [
        DrillFrame(
          text:
              '${sc.name} — stacks: you (SB) $sbStack bb, BB $bbStack bb, others $o1/$o2 bb.',
          street: Street.preflop,
          board: const [],
          pot: _sb + _bbv,
        ),
        DrillFrame(
          text: sc.blurb,
          street: Street.preflop,
          board: const [],
          pot: _sb + _bbv,
        ),
        const DrillFrame(
          text: 'Folded to you in the SB. Shove or fold?',
          street: Street.preflop,
          board: [],
          pot: _sb + _bbv,
        ),
      ],
      options: [
        const DrillOption(action: DrillAction.fold, label: 'Fold'),
        DrillOption(
          action: DrillAction.raise,
          label: 'Shove $sbStack bb',
          amount: sbStack.toDouble(),
        ),
      ],
      best: g.best,
      accept: g.accept,
      rationale: g.rationale,
      difficulty: freq > 0.2 && freq < 0.8 ? 3 : 2,
      gradeRange: chartLabels05(sc.jam),
      gradeRangeTitle: 'ICM SB shoving range — ${sc.name}',
      lessonId: 'spr',
      lessonTitle: 'SPR & Commitment',
      icm: true,
    );
  }

  final freq = sc.call[label] ?? 0.0;
  final g = gradeFromFreq(
    freq,
    label,
    bbStack,
    DrillAction.call,
    'call',
    '${sc.name}: the SB ($sbStack bb) jams into your BB ($bbStack bb) on the bubble (ICM, \$EV). $icmNote',
  );
  final effective = min(sbStack, bbStack);
  final callAmt = _r1(effective - _bbv);
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.pushfold,
    source: PuzzleSource.chart,
    street: Street.preflop,
    heroPos: Position.bb,
    hole: hole,
    handLabel: label,
    board: const [],
    pot: _r1(_sb + _bbv + effective),
    toCall: callAmt,
    bb: _bbv,
    seats: _fullSeats(
      Position.bb,
      const [Position.utg, Position.mp],
      const [Position.sb],
    ),
    frames: [
      DrillFrame(
        text:
            '${sc.name} — stacks: SB $sbStack bb, you (BB) $bbStack bb, others $o1/$o2 bb.',
        street: Street.preflop,
        board: const [],
        pot: _sb + _bbv,
      ),
      DrillFrame(
        text: sc.blurb,
        street: Street.preflop,
        board: const [],
        pot: _sb + _bbv,
      ),
      DrillFrame(
        text: 'The SB moves all-in. Call for your tournament life, or fold?',
        street: Street.preflop,
        board: const [],
        pot: _r1(_sb + _bbv + effective),
      ),
    ],
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Call ${jsNum(callAmt)} bb',
        amount: callAmt,
      ),
    ],
    best: g.best,
    accept: g.accept,
    rationale: g.rationale,
    difficulty: freq > 0.2 && freq < 0.8 ? 3 : 2,
    gradeRange: chartLabels05(sc.call),
    gradeRangeTitle: 'ICM BB calling range — ${sc.name}',
    lessonId: 'spr',
    lessonTitle: 'SPR & Commitment',
    icm: true,
  );
}

Puzzle generatePushFold({Random? rng}) {
  rng ??= Random();
  // A third of push/fold reps are ICM bubbles.
  if (rng.nextDouble() < 0.33) return _generateIcmPushFold(rng);
  final deck = shuffle(makeDeck(), rng: rng);
  final hole = <Card>[deck[0], deck[1]];
  final label = cardsToLabel(hole[0], hole[1]);
  final stack =
      kPushFoldDrillStacks[_rint(
        rng,
        0,
        kPushFoldDrillStacks.length - 1,
      )]; // bb

  if (rng.nextDouble() < 0.6) {
    // Open-shove: folded to hero late
    final heroPos =
        const [Position.mp, Position.co, Position.btn, Position.sb][_rint(
          rng,
          0,
          3,
        )];
    final table = kNashShove[stack]?[heroPos.label];
    final freq = table?[label] ?? 0.0;
    final g = gradeFromFreq(
      freq,
      label,
      stack,
      DrillAction.raise,
      'shove',
      'Folded to you in the ${heroPos.label} with $stack bb (Nash, chip-EV, no antes).',
    );
    final heroIdx = _order.indexOf(heroPos);
    final foldedBefore = _nonBlinds(_order.sublist(0, heroIdx));
    const pot = _sb + _bbv;
    final frames = <DrillFrame>[
      DrillFrame(
        text: '$stack bb stacks. Blinds ${jsNum(_sb)}/${jsNum(_bbv)}.',
        street: Street.preflop,
        board: const [],
        pot: pot,
      ),
      for (final p in foldedBefore)
        DrillFrame(
          text: '${p.label} folds.',
          street: Street.preflop,
          board: const [],
          pot: pot,
        ),
      DrillFrame(
        text:
            'Folded to you in the ${heroPos.label} with $stack bb. Shove or fold?',
        street: Street.preflop,
        board: const [],
        pot: pot,
      ),
    ];

    return Puzzle(
      id: _seq++,
      kind: PuzzleKind.pushfold,
      source: PuzzleSource.chart,
      street: Street.preflop,
      heroPos: heroPos,
      hole: hole,
      handLabel: label,
      board: const [],
      pot: pot,
      toCall: heroPos == Position.sb ? _bbv - _sb : _bbv,
      bb: _bbv,
      seats: _fullSeats(heroPos, foldedBefore, [
        for (final p in _order)
          if ((p == Position.sb || p == Position.bb) && p != heroPos) p,
      ]),
      frames: frames,
      options: [
        const DrillOption(action: DrillAction.fold, label: 'Fold'),
        DrillOption(
          action: DrillAction.raise,
          label: 'Shove $stack bb',
          amount: stack.toDouble(),
        ),
      ],
      best: g.best,
      accept: g.accept,
      rationale: g.rationale,
      difficulty: freq > 0.2 && freq < 0.8 ? 3 : 2,
      gradeRange: chartLabels05(table ?? const <String, double>{}),
      gradeRangeTitle: 'Nash ${stack}bb ${heroPos.label} shoving range',
      lessonId: 'spr',
      lessonTitle: 'SPR & Commitment',
    );
  }

  // Call a shove from the BB
  final shoverPos =
      const [Position.btn, Position.co, Position.sb][_rint(rng, 0, 2)];
  final table = kNashCall[stack]?['${shoverPos.label}>BB'];
  final freq = table?[label] ?? 0.0;
  final g = gradeFromFreq(
    freq,
    label,
    stack,
    DrillAction.call,
    'call',
    'Facing a $stack bb all-in from the ${shoverPos.label} (Nash, chip-EV, no antes).',
  );
  final pot = _r1(_sb + _bbv + stack);
  final frames = <DrillFrame>[
    DrillFrame(
      text: '$stack bb stacks. Blinds ${jsNum(_sb)}/${jsNum(_bbv)}.',
      street: Street.preflop,
      board: const [],
      pot: _sb + _bbv,
    ),
    DrillFrame(
      text: '${shoverPos.label} moves all-in for $stack bb.',
      street: Street.preflop,
      board: const [],
      pot: pot,
    ),
    DrillFrame(
      text: 'Action on you in the BB. Call or fold?',
      street: Street.preflop,
      board: const [],
      pot: pot,
    ),
  ];
  final callAmt = _r1(stack - _bbv);
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.pushfold,
    source: PuzzleSource.chart,
    street: Street.preflop,
    heroPos: Position.bb,
    hole: hole,
    handLabel: label,
    board: const [],
    pot: pot,
    toCall: callAmt,
    bb: _bbv,
    seats: _fullSeats(
      Position.bb,
      [
        for (final p in _order)
          if (p != Position.bb && p != shoverPos) p,
      ],
      [shoverPos],
    ),
    frames: frames,
    options: [
      const DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(
        action: DrillAction.call,
        label: 'Call ${jsNum(callAmt)} bb',
        amount: callAmt,
      ),
    ],
    best: g.best,
    accept: g.accept,
    rationale: g.rationale,
    difficulty: freq > 0.2 && freq < 0.8 ? 3 : 2,
    gradeRange: chartLabels05(table ?? const <String, double>{}),
    gradeRangeTitle:
        'Nash BB calling range vs ${stack}bb ${shoverPos.label} shove',
    lessonId: 'spr',
    lessonTitle: 'SPR & Commitment',
  );
}

/* ----------------------------- Leak replay ----------------------------- */

/// Rebuild a playable puzzle from a saved leak spot.
Puzzle puzzleFromLeak(LeakSpot spot) {
  final folded = [
    for (final p in _order)
      if (p != spot.heroPos && !spot.oppActive.contains(p)) p,
  ];
  final streetLabel = _capital(spot.street.label);
  final frames = <DrillFrame>[
    DrillFrame(
      text:
          spot.board.isNotEmpty
              ? '$streetLabel: ${spot.board.join(' ')}'
              : 'Pre-flop.',
      street: spot.street,
      board: [...spot.board],
      pot: spot.pot.toDouble(),
    ),
    DrillFrame(
      text:
          'Action on you in the ${spot.heroPos.label}${spot.toCall > 0 ? ' facing ${jsToFixed(spot.toCall / spot.bb, 1)} bb' : ''}. What\'s the play?',
      street: spot.street,
      board: [...spot.board],
      pot: spot.pot.toDouble(),
    ),
  ];
  return Puzzle(
    id: _seq++,
    kind: PuzzleKind.leak,
    source: PuzzleSource.heuristic,
    street: spot.street,
    heroPos: spot.heroPos,
    hole: spot.hole,
    handLabel: cardsToLabel(spot.hole[0], spot.hole[1]),
    board: spot.board,
    pot: spot.pot.toDouble(),
    toCall: spot.toCall.toDouble(),
    bb: spot.bb.toDouble(),
    seats: _fullSeats(spot.heroPos, folded, spot.oppActive),
    frames: frames,
    options: spot.options,
    best: spot.best,
    accept: [spot.best],
    rationale: spot.rationale,
    equity: spot.equity,
    potOdds: spot.potOdds,
    difficulty: 2,
  );
}

/* ------------------------------- Grading ------------------------------- */

GradeResult gradePuzzle(Puzzle p, DrillAction action) {
  final correct = p.accept.contains(action);
  double? evLossBb;
  final equity = p.equity;
  if (!correct && equity != null && p.toCall > 0) {
    // Two-option EV: calling wins equity×finalPot − cost; folding is 0.
    final evCall = equity * (p.pot + p.toCall) - p.toCall;
    double? evOf(DrillAction a) =>
        a == DrillAction.fold
            ? 0
            : a == DrillAction.call
            ? evCall
            : null;
    final chosen = evOf(action);
    final best = evOf(p.best);
    if (chosen != null && best != null) evLossBb = max(0, best - chosen);
  }
  return GradeResult(
    correct: correct,
    best: p.best,
    accept: p.accept,
    rationale: p.rationale,
    evLossBb: evLossBb,
  );
}

/* --------------- Drill-store helpers (desktop drillStore.ts) ---------------
   Pure pieces of the desktop store, kept here so the notifier only
   orchestrates. --------------- */

/// Starting rating for a new player (desktop `allin.drills.v1` default).
const int kDefaultRating = 1000;

/// Elo K-factor and rating floor.
const int kEloK = 24;
const int kMinRating = 100;

/// Review-queue capacity (desktop `allin.review.v1`).
const int kReviewCap = 80;

/// A puzzle's implied rating: 1000 / 1200 / 1400 by difficulty.
int puzzleRating(int difficulty) => 800 + difficulty * 200;

/// Rating change after answering (`Math.round(24 * (score − expected))`).
int eloDelta(int rating, int difficulty, bool correct) {
  final expected = 1 / (1 + pow(10, (puzzleRating(difficulty) - rating) / 400));
  return jsRound(kEloK * ((correct ? 1 : 0) - expected)).toInt();
}

/// New rating after applying [delta] (floored at [kMinRating]).
int applyRatingDelta(int rating, int delta) =>
    max(kMinRating, jsRound((rating + delta).toDouble()).toInt());

/// Review-card key that de-duplicates missed drills
/// (`"{kind}|{handLabel}|{board joined}|{heroPos}"`).
String reviewCardId(Puzzle p) =>
    '${p.kind.label}|${p.handLabel}|${p.board.join()}|${p.heroPos.label}';

/// Adaptive difficulty: serve spots near the edge of the user's rating —
/// strong players mostly see close (difficulty-3) spots, beginners mostly
/// clear ones.
Puzzle adaptivePuzzle(int rating, {Random? rng}) {
  rng ??= Random();
  final int target;
  if (rating < 1050) {
    target = rng.nextDouble() < 0.7 ? 1 : 2;
  } else if (rating < 1250) {
    target =
        rng.nextDouble() < 0.55
            ? 2
            : rng.nextDouble() < 0.5
            ? 1
            : 3;
  } else {
    target = rng.nextDouble() < 0.6 ? 3 : 2;
  }
  for (var i = 0; i < 25; i++) {
    final p = generatePuzzle(rng: rng);
    if (p.difficulty == target) return p;
  }
  return generatePuzzle(rng: rng);
}

/// "Drill similar": keep dealing until the same spot family shows up
/// (up to 60 tries), else any puzzle.
Puzzle generatePuzzleOfKind(PuzzleKind kind, {Random? rng}) {
  rng ??= Random();
  for (var i = 0; i < 60; i++) {
    final p = generatePuzzle(rng: rng);
    if (p.kind == kind) return p;
  }
  return generatePuzzle(rng: rng);
}
