/// Monte-Carlo + exact equity — ported 1:1 from the desktop
/// `src/engine/equity.ts`.
///
/// Determinism: every sampled function takes an optional `seed`; the same
/// seed always produces the same result (and the same result as the desktop
/// TypeScript, because [Mulberry32] reproduces its PRNG bit-for-bit and the
/// deck-walking order is identical). Late-street spots skip sampling
/// entirely — vs-range equity is enumerated exactly on the turn and river,
/// vs-random on the river — so those results carry no noise at all
/// (`se == 0`, `exact == true`).
///
/// Hot loops are allocation-free: cards live in reusable `Int32List` scratch
/// buffers and hands are scored with [evaluateScore] (no `EvaluatedHand`, no
/// name string). The engine is synchronous; each isolate has its own copy of
/// the scratch buffers.
library;

import 'dart:math';
import 'dart:typed_data';

import 'cards.dart';
import 'evaluator.dart';
import 'notation.dart';
import 'prng.dart';
import 'types.dart';

/// A two-card combo as int cards (0..51) — the desktop `[number, number]`.
typedef IntCombo = List<int>;

/// Desktop `comboToInts`: `[cardToInt(a), cardToInt(b)]`.
IntCombo comboToInts(Combo combo) => [cardToInt(combo.$1), cardToInt(combo.$2)];

/// Result of an equity computation (desktop `EquityResult`).
class EquityResult {
  const EquityResult({
    required this.equity,
    required this.win,
    required this.tie,
    required this.lose,
    required this.samples,
    required this.se,
    required this.exact,
  });

  /// `{ equity: 0.5, win: 0, tie: 0, lose: 0, samples: 0, se: 0, exact: false }`
  /// — what the desktop returns when nothing could be sampled.
  static const EquityResult empty = EquityResult(
    equity: 0.5,
    win: 0,
    tie: 0,
    lose: 0,
    samples: 0,
    se: 0,
    exact: false,
  );

  /// win + tie/2 (or the pot-share average for multiway), as a fraction 0..1.
  final double equity;
  final int win;
  final int tie;
  final int lose;
  final int samples;

  /// Standard error of the equity estimate (0 when exact).
  final double se;

  /// True when computed by exhaustive enumeration, not sampling.
  final bool exact;

  Map<String, Object> toJson() => {
    'equity': equity,
    'win': win,
    'tie': tie,
    'lose': lose,
    'samples': samples,
    'se': se,
    'exact': exact,
  };

  factory EquityResult.fromJson(Map<String, dynamic> json) => EquityResult(
    equity: (json['equity'] as num).toDouble(),
    win: (json['win'] as num).toInt(),
    tie: (json['tie'] as num).toInt(),
    lose: (json['lose'] as num).toInt(),
    samples: (json['samples'] as num).toInt(),
    se: (json['se'] as num).toDouble(),
    exact: json['exact'] as bool,
  );

  @override
  bool operator ==(Object other) =>
      other is EquityResult &&
      other.equity == equity &&
      other.win == win &&
      other.tie == tie &&
      other.lose == lose &&
      other.samples == samples &&
      other.se == se &&
      other.exact == exact;

  @override
  int get hashCode => Object.hash(equity, win, tie, lose, samples, se, exact);

  @override
  String toString() =>
      'EquityResult(equity: $equity, win: $win, tie: $tie, lose: $lose, '
      'samples: $samples, se: $se, exact: $exact)';
}

/* ------------------------------------------------------------------
   Internals
   ------------------------------------------------------------------ */

/// Desktop `rngFor(seed)`: `Math.random` when no seed, else `mulberry32`.
/// An explicit [rng] stands in for `Math.random` so tests stay deterministic
/// even on the unseeded path; a [seed] always wins.
Random _rngFor(int? seed, Random? rng) =>
    seed != null ? Mulberry32(seed) : (rng ?? Random());

/// `(rand() * n) | 0` — uniform index in `[0, n)`.
@pragma('vm:prefer-inline')
int _pick(Random rng, int n) => (rng.nextDouble() * n).toInt();

EquityResult _mcResult(int win, int tie, int lose, [double? equitySum]) {
  final samples = win + tie + lose;
  final equity =
      samples != 0
          ? (equitySum != null
              ? equitySum / samples
              : (win + tie / 2) / samples)
          : 0.5;
  final se =
      samples != 0 ? sqrt(max(equity * (1 - equity), 1e-9) / samples) : 0.0;
  return EquityResult(
    equity: equity,
    win: win,
    tie: tie,
    lose: lose,
    samples: samples,
    se: se,
    exact: false,
  );
}

EquityResult _exactResult(int win, int tie, int lose) {
  final samples = win + tie + lose;
  return EquityResult(
    equity: samples != 0 ? (win + tie / 2) / samples : 0.5,
    win: win,
    tie: tie,
    lose: lose,
    samples: samples,
    se: 0,
    exact: true,
  );
}

// Scratch buffers shared by every function in this file (engine is
// synchronous, one copy per isolate).
final Uint8List _used = Uint8List(52);
final Int32List _avail = Int32List(52);
final Int32List _work = Int32List(52);
final Int32List _heroBuf = Int32List(7);
final Int32List _villBuf = Int32List(7);
final Int32List _oppCards = Int32List(16);
final Int32List _oppScores = Int32List(8);

/// Mark hero + board in [_used]; returns nothing, callers read [_used].
void _markUsed(IntCombo hero, List<int> board) {
  _used.fillRange(0, 52, 0);
  _used[hero[0]] = 1;
  _used[hero[1]] = 1;
  for (int i = 0; i < board.length; i++) {
    _used[board[i]] = 1;
  }
}

/// Fill [_avail] with every card not flagged in [_used]; returns the count.
int _fillAvail() {
  int n = 0;
  for (int i = 0; i < 52; i++) {
    if (_used[i] == 0) _avail[n++] = i;
  }
  return n;
}

/// Preload hero + board into [_heroBuf] and board into [_villBuf] (from
/// index 2). Returns the board length.
int _loadBases(IntCombo hero, List<int> board) {
  _heroBuf[0] = hero[0];
  _heroBuf[1] = hero[1];
  for (int i = 0; i < board.length; i++) {
    _heroBuf[2 + i] = board[i];
    _villBuf[2 + i] = board[i];
  }
  return board.length;
}

/// Exhaustive equity vs a set of villain combos on a turn or river board
/// (runouts of length 0 or 1). Desktop `exactVsCombos`.
EquityResult _exactVsCombos(
  IntCombo hero,
  List<int> board,
  List<IntCombo> combos,
) {
  _markUsed(hero, board);
  final bl = _loadBases(hero, board);
  final need = 5 - bl;
  final total = 2 + bl + need;
  int win = 0;
  int tie = 0;
  int lose = 0;

  for (int ci = 0; ci < combos.length; ci++) {
    final v = combos[ci];
    _villBuf[0] = v[0];
    _villBuf[1] = v[1];
    if (need == 0) {
      final hs = evaluateScore(_heroBuf, total);
      final vs = evaluateScore(_villBuf, total);
      if (hs > vs) {
        win++;
      } else if (hs < vs) {
        lose++;
      } else {
        tie++;
      }
    } else {
      for (int c = 0; c < 52; c++) {
        if (_used[c] != 0 || c == v[0] || c == v[1]) continue;
        _heroBuf[2 + bl] = c;
        _villBuf[2 + bl] = c;
        final hs = evaluateScore(_heroBuf, total);
        final vs = evaluateScore(_villBuf, total);
        if (hs > vs) {
          win++;
        } else if (hs < vs) {
          lose++;
        } else {
          tie++;
        }
      }
    }
  }
  return _exactResult(win, tie, lose);
}

/* ------------------------------------------------------------------
   Public API
   ------------------------------------------------------------------ */

/// Hero equity vs a villain range on a (partial) board.
///
/// Turn and river boards (`board.length >= 4`) are enumerated exactly;
/// earlier streets are Monte-Carlo sampled with [iters] trials — deterministic
/// when [seed] is given (identical to the desktop for the same seed). Combos
/// clashing with hero or the board are dropped first; if none remain the
/// result is [EquityResult.empty].
///
/// [rng] is only consulted when [seed] is null (defaults to `Random()`).
EquityResult equityVsRange(
  IntCombo hero,
  List<int> board,
  List<IntCombo> range, {
  int iters = 1500,
  int? seed,
  Random? rng,
}) {
  _markUsed(hero, board);
  final valid = <IntCombo>[];
  for (int i = 0; i < range.length; i++) {
    final c = range[i];
    if (_used[c[0]] == 0 && _used[c[1]] == 0) valid.add(c);
  }
  if (valid.isEmpty) return EquityResult.empty;

  if (board.length >= 4) return _exactVsCombos(hero, board, valid);

  final rand = _rngFor(seed, rng);
  final baseLen = _fillAvail();
  final bl = _loadBases(hero, board);
  final need = 5 - bl;
  final total = 2 + bl + need;
  final work = _work;
  int win = 0;
  int tie = 0;
  int lose = 0;

  for (int it = 0; it < iters; it++) {
    final villain = valid[_pick(rand, valid.length)];

    // Working copy of available cards, then remove villain's two cards
    // (indexOf + swap-to-tail, exactly as the desktop).
    work.setRange(0, baseLen, _avail);
    int len = baseLen;
    for (int k = 0; k < 2; k++) {
      final vc = villain[k];
      int idx = -1;
      for (int i = 0; i < baseLen; i++) {
        if (work[i] == vc) {
          idx = i;
          break;
        }
      }
      if (idx >= 0) {
        len--;
        final t = work[idx];
        work[idx] = work[len];
        work[len] = t;
      }
    }

    // Draw `need` runout cards from the active region.
    for (int k = 0; k < need; k++) {
      final j = _pick(rand, len - k);
      final last = len - 1 - k;
      final pick = work[j];
      work[j] = work[last];
      work[last] = pick;
      _heroBuf[2 + bl + k] = pick;
      _villBuf[2 + bl + k] = pick;
    }

    _villBuf[0] = villain[0];
    _villBuf[1] = villain[1];
    final heroScore = evaluateScore(_heroBuf, total);
    final villScore = evaluateScore(_villBuf, total);

    if (heroScore > villScore) {
      win++;
    } else if (heroScore < villScore) {
      lose++;
    } else {
      tie++;
    }
  }

  return _mcResult(win, tie, lose);
}

/// Hero equity vs a field of N uniformly-random opponents (multiway).
/// Ties at the top split the pot, so hero's share is 1/(tied players).
/// [numOpponents] is clamped to 1..8. Always Monte-Carlo.
EquityResult equityVsField(
  IntCombo hero,
  List<int> board,
  int numOpponents, {
  int iters = 1500,
  int? seed,
  Random? rng,
}) {
  final n = max(1, min(8, numOpponents));
  final rand = _rngFor(seed, rng);
  _markUsed(hero, board);
  final availLen = _fillAvail();
  final bl = _loadBases(hero, board);
  final need = 5 - bl;
  final total = 2 + bl + need;
  final work = _work;
  final oppCards = _oppCards;
  final oppScores = _oppScores;
  int win = 0;
  int tie = 0;
  int lose = 0;
  double equitySum = 0;

  for (int it = 0; it < iters; it++) {
    work.setRange(0, availLen, _avail);
    int len = availLen;
    // drawN(n * 2): opponents' hole cards.
    for (int k = 0; k < n * 2; k++) {
      final j = _pick(rand, len);
      len--;
      final t = work[j];
      work[j] = work[len];
      work[len] = t;
      oppCards[k] = t;
    }
    // drawN(need): the runout.
    for (int k = 0; k < need; k++) {
      final j = _pick(rand, len);
      len--;
      final t = work[j];
      work[j] = work[len];
      work[len] = t;
      _heroBuf[2 + bl + k] = t;
      _villBuf[2 + bl + k] = t;
    }
    final heroScore = evaluateScore(_heroBuf, total);

    int best = -1;
    for (int o = 0; o < n; o++) {
      _villBuf[0] = oppCards[o * 2];
      _villBuf[1] = oppCards[o * 2 + 1];
      final os = evaluateScore(_villBuf, total);
      oppScores[o] = os;
      if (os > best) best = os;
    }

    if (heroScore > best) {
      win++;
      equitySum += 1;
    } else if (heroScore < best) {
      lose++;
    } else {
      int tied = 0;
      for (int o = 0; o < n; o++) {
        if (oppScores[o] == heroScore) tied++;
      }
      tie++;
      equitySum += 1 / (tied + 1);
    }
  }

  return _mcResult(win, tie, lose, equitySum);
}

/// Equity of a hero range vs a villain range on a (partial) board.
/// Each trial samples one combo from each range (rejecting card clashes with
/// up to 8 re-draws, then skipping the trial — so `samples` may be below
/// [iters]), deals the runout, and compares. Powers the free-form equity
/// calculator. Always Monte-Carlo.
EquityResult equityRangeVsRange(
  List<IntCombo> heroRange,
  List<int> board,
  List<IntCombo> villRange, {
  int iters = 3000,
  int? seed,
  Random? rng,
}) {
  final rand = _rngFor(seed, rng);
  final boardSet = Uint8List(52);
  for (int i = 0; i < board.length; i++) {
    boardSet[board[i]] = 1;
  }
  final hero = <IntCombo>[];
  for (int i = 0; i < heroRange.length; i++) {
    final c = heroRange[i];
    if (boardSet[c[0]] == 0 && boardSet[c[1]] == 0) hero.add(c);
  }
  final vill = <IntCombo>[];
  for (int i = 0; i < villRange.length; i++) {
    final c = villRange[i];
    if (boardSet[c[0]] == 0 && boardSet[c[1]] == 0) vill.add(c);
  }
  if (hero.isEmpty || vill.isEmpty) return EquityResult.empty;

  final bl = board.length;
  final need = 5 - bl;
  final total = 2 + bl + need;
  for (int i = 0; i < bl; i++) {
    _heroBuf[2 + i] = board[i];
    _villBuf[2 + i] = board[i];
  }
  final used = _used;
  final avail = _avail;
  int win = 0;
  int tie = 0;
  int lose = 0;

  for (int it = 0; it < iters; it++) {
    final h = hero[_pick(rand, hero.length)];
    IntCombo v = vill[_pick(rand, vill.length)];
    int tries = 0;
    while ((h[0] == v[0] || h[0] == v[1] || h[1] == v[0] || h[1] == v[1]) &&
        tries < 8) {
      v = vill[_pick(rand, vill.length)];
      tries++;
    }
    if (h[0] == v[0] || h[0] == v[1] || h[1] == v[0] || h[1] == v[1]) {
      continue;
    }

    used.setRange(0, 52, boardSet);
    used[h[0]] = 1;
    used[h[1]] = 1;
    used[v[0]] = 1;
    used[v[1]] = 1;
    int len = 0;
    for (int i = 0; i < 52; i++) {
      if (used[i] == 0) avail[len++] = i;
    }

    for (int k = 0; k < need; k++) {
      final j = _pick(rand, len);
      len--;
      final t = avail[j];
      avail[j] = avail[len];
      avail[len] = t;
      _heroBuf[2 + bl + k] = t;
      _villBuf[2 + bl + k] = t;
    }

    _heroBuf[0] = h[0];
    _heroBuf[1] = h[1];
    _villBuf[0] = v[0];
    _villBuf[1] = v[1];
    final hs = evaluateScore(_heroBuf, total);
    final vs = evaluateScore(_villBuf, total);
    if (hs > vs) {
      win++;
    } else if (hs < vs) {
      lose++;
    } else {
      tie++;
    }
  }

  return _mcResult(win, tie, lose);
}

/// Hero equity vs a single uniformly-random opponent hand.
/// River boards are enumerated exactly (C(45,2) = 990 villain combos);
/// earlier streets are Monte-Carlo sampled.
EquityResult equityVsRandom(
  IntCombo hero,
  List<int> board, {
  int iters = 1200,
  int? seed,
  Random? rng,
}) {
  _markUsed(hero, board);

  if (board.length == 5) {
    final combos = <IntCombo>[];
    for (int a = 0; a < 52; a++) {
      if (_used[a] != 0) continue;
      for (int b = a + 1; b < 52; b++) {
        if (_used[b] == 0) combos.add([a, b]);
      }
    }
    return _exactVsCombos(hero, board, combos);
  }

  final rand = _rngFor(seed, rng);
  final availLen = _fillAvail();
  final bl = _loadBases(hero, board);
  final need = 5 - bl;
  final total = 2 + bl + need;
  final work = _work;
  int win = 0;
  int tie = 0;
  int lose = 0;

  for (int it = 0; it < iters; it++) {
    work.setRange(0, availLen, _avail);
    int len = availLen;
    // drawDistinct(2): villain.
    for (int k = 0; k < 2; k++) {
      final j = _pick(rand, len);
      len--;
      final t = work[j];
      work[j] = work[len];
      work[len] = t;
      _villBuf[k] = t;
    }
    // drawDistinct(need): runout.
    for (int k = 0; k < need; k++) {
      final j = _pick(rand, len);
      len--;
      final t = work[j];
      work[j] = work[len];
      work[len] = t;
      _heroBuf[2 + bl + k] = t;
      _villBuf[2 + bl + k] = t;
    }
    final heroScore = evaluateScore(_heroBuf, total);
    final villScore = evaluateScore(_villBuf, total);
    if (heroScore > villScore) {
      win++;
    } else if (heroScore < villScore) {
      lose++;
    } else {
      tie++;
    }
  }
  return _mcResult(win, tie, lose);
}

/* ------------------------------------------------------------------
   Card-level conveniences (desktop `engineClient.ts`)
   ------------------------------------------------------------------ */

/// Desktop `expandRange`: every combo of every label, minus those sharing a
/// card with [hero] or [board], as int combos in label/combo order.
List<IntCombo> expandRange(
  Iterable<HandLabel> range,
  Combo hero,
  List<Card> board,
) {
  final blocked = <Card>{hero.$1, hero.$2, ...board};
  final combos = <IntCombo>[];
  for (final label in range) {
    for (final (a, b) in labelToCombos(label)) {
      if (blocked.contains(a) || blocked.contains(b)) continue;
      combos.add(comboToInts((a, b)));
    }
  }
  return combos;
}

/// `engine.equityVsRange` with cards and labels (the coach's call shape).
EquityResult equityVsRangeCards(
  Combo hero,
  List<Card> board,
  Iterable<HandLabel> range, {
  int iters = 1500,
  int? seed,
  Random? rng,
}) => equityVsRange(
  comboToInts(hero),
  board.map(cardToInt).toList(growable: false),
  expandRange(range, hero, board),
  iters: iters,
  seed: seed,
  rng: rng,
);

/// `engine.equityVsRandom` with cards.
EquityResult equityVsRandomCards(
  Combo hero,
  List<Card> board, {
  int iters = 1200,
  int? seed,
  Random? rng,
}) => equityVsRandom(
  comboToInts(hero),
  board.map(cardToInt).toList(growable: false),
  iters: iters,
  seed: seed,
  rng: rng,
);

/// `engine.equityVsField` with cards.
EquityResult equityVsFieldCards(
  Combo hero,
  List<Card> board,
  int numOpponents, {
  int iters = 1500,
  int? seed,
  Random? rng,
}) => equityVsField(
  comboToInts(hero),
  board.map(cardToInt).toList(growable: false),
  numOpponents,
  iters: iters,
  seed: seed,
  rng: rng,
);
