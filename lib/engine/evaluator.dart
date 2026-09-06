/// Fast 5–7 card hand evaluator — ported from the desktop
/// `src/engine/evaluator.ts`.
///
/// Produces a monotonic `score` (higher = better) that is safe to compare
/// across any hands, plus a category and a human name.
///
/// Score packing (pinned by `test/golden/evaluator.json`):
/// `score = category * CAT + pack(tiebreaks)` with `CAT = 16^5` and
/// `pack` = up to five rank values (2..14) packed big-endian in base 16,
/// zero-padded on the right to exactly five nibbles.
///
/// [evaluateScore] is the allocation-free hot path used by the Monte-Carlo
/// loops; [evaluateInts] / [evaluateCards] wrap it into an [EvaluatedHand]
/// (the name is derived from the score, so it costs nothing in the sims).
library;

import 'dart:typed_data';

import 'cards.dart';
import 'types.dart';

/// `16^5` — one category tier.
const int kCat = 1048576;

const Map<int, String> _rankName = {
  14: 'Ace',
  13: 'King',
  12: 'Queen',
  11: 'Jack',
  10: 'Ten',
  9: 'Nine',
  8: 'Eight',
  7: 'Seven',
  6: 'Six',
  5: 'Five',
  4: 'Four',
  3: 'Three',
  2: 'Two',
};
const Map<int, String> _rankNamePlural = {
  14: 'Aces',
  13: 'Kings',
  12: 'Queens',
  11: 'Jacks',
  10: 'Tens',
  9: 'Nines',
  8: 'Eights',
  7: 'Sevens',
  6: 'Sixes',
  5: 'Fives',
  4: 'Fours',
  3: 'Threes',
  2: 'Twos',
};

// Scratch buffers: the engine is synchronous and each isolate has its own
// copy of these, so reusing them keeps the hot path allocation-free.
final Int32List _counts = Int32List(15); // index by rank 2..14
final Int32List _suitRankMask = Int32List(4); // per suit, bitmask of ranks
final Int32List _suitCount = Int32List(4);

/// Highest card of a 5-straight given a rank bitmask (bits 2..14). 0 if none.
int _straightHigh(int mask) {
  int m = mask;
  if (m & (1 << 14) != 0) m |= 1 << 1; // wheel: Ace plays low
  // A bit h set in `x` means bits h..h+4 are all set in m — a straight with
  // high card h+4. The highest such bit is the best straight (h+4 >= 5).
  final x = m & (m >> 1) & (m >> 2) & (m >> 3) & (m >> 4);
  if (x == 0) return 0;
  return x.bitLength - 1 + 4;
}

/// Pack the top [n] set bits (ranks, descending) of [mask] into base-16
/// nibbles, most significant first, zero-padded on the right to [n] nibbles
/// (= the TS `pack(topKickers(...))` semantics).
int _topKickers(int mask, int n) {
  int out = 0;
  int got = 0;
  for (int r = 14; r >= 2 && got < n; r--) {
    if (mask & (1 << r) != 0) {
      out = (out << 4) | r;
      got++;
    }
  }
  return out << (4 * (n - got));
}

/// Score of the best 5-card hand among [cards] (ints 0..51, length 5–7).
/// Only the first [length] entries are read when given, so callers can pass
/// a reusable scratch buffer. Allocation-free.
int evaluateScore(List<int> cards, [int? length]) {
  final n = length ?? cards.length;
  final counts = _counts;
  final suitRankMask = _suitRankMask;
  final suitCount = _suitCount;
  for (int r = 2; r <= 14; r++) {
    counts[r] = 0;
  }
  suitRankMask[0] = 0;
  suitRankMask[1] = 0;
  suitRankMask[2] = 0;
  suitRankMask[3] = 0;
  suitCount[0] = 0;
  suitCount[1] = 0;
  suitCount[2] = 0;
  suitCount[3] = 0;
  int rankMask = 0;

  for (int i = 0; i < n; i++) {
    final c = cards[i];
    final r = (c >> 2) + 2;
    final s = c & 3;
    counts[r]++;
    rankMask |= 1 << r;
    suitRankMask[s] |= 1 << r;
    suitCount[s]++;
  }

  // Flush suit (>=5)
  int flushSuit = -1;
  for (int s = 0; s < 4; s++) {
    if (suitCount[s] >= 5) flushSuit = s;
  }

  // 1) Straight flush
  if (flushSuit >= 0) {
    final sfHigh = _straightHigh(suitRankMask[flushSuit]);
    if (sfHigh > 0) return 8 * kCat + (sfHigh << 16);
  }

  // Find quads / trips / pairs (descending rank order, like the TS loop)
  int quad = 0;
  int trips0 = 0;
  int trips1 = 0;
  int pairs0 = 0;
  int pairs1 = 0;
  int pairCount = 0;
  for (int r = 14; r >= 2; r--) {
    final cnt = counts[r];
    if (cnt == 4) {
      quad = r;
    } else if (cnt == 3) {
      if (trips0 == 0) {
        trips0 = r;
      } else if (trips1 == 0) {
        trips1 = r;
      }
    } else if (cnt == 2) {
      if (pairs0 == 0) {
        pairs0 = r;
      } else if (pairs1 == 0) {
        pairs1 = r;
      }
      pairCount++;
    }
  }

  // 2) Quads
  if (quad != 0) {
    final kicker = _topKickers(rankMask & ~(1 << quad), 1);
    return 7 * kCat + (quad << 16) + (kicker << 12);
  }

  // 3) Full house (supports two trips)
  if (trips0 != 0) {
    int pairRank = trips1;
    if (pairs0 > pairRank) pairRank = pairs0;
    if (pairRank > 0) return 6 * kCat + (trips0 << 16) + (pairRank << 12);
  }

  // 4) Flush
  if (flushSuit >= 0) {
    return 5 * kCat + _topKickers(suitRankMask[flushSuit], 5);
  }

  // 5) Straight
  final sHigh = _straightHigh(rankMask);
  if (sHigh > 0) return 4 * kCat + (sHigh << 16);

  // 6) Trips
  if (trips0 != 0) {
    final ks = _topKickers(rankMask & ~(1 << trips0), 2);
    return 3 * kCat + (trips0 << 16) + (ks << 8);
  }

  // 7) Two pair
  if (pairCount >= 2) {
    final kicker = _topKickers(rankMask & ~(1 << pairs0) & ~(1 << pairs1), 1);
    return 2 * kCat + (pairs0 << 16) + (pairs1 << 12) + (kicker << 8);
  }

  // 8) Pair
  if (pairCount == 1) {
    final ks = _topKickers(rankMask & ~(1 << pairs0), 3);
    return kCat + (pairs0 << 16) + (ks << 4);
  }

  // 9) High card
  return _topKickers(rankMask, 5);
}

/// Category encoded in a [score] produced by [evaluateScore].
HandCategory categoryOfScore(int score) => HandCategory.values[score ~/ kCat];

/// Human name for a [score] produced by [evaluateScore] — the desktop
/// `EvaluatedHand.name` templates, verbatim.
String handName(int score) {
  final cat = score ~/ kCat;
  final k0 = (score >> 16) & 0xF;
  final k1 = (score >> 12) & 0xF;
  switch (cat) {
    case 8:
      return k0 == 14 ? 'Royal Flush' : 'Straight Flush, ${_rankName[k0]} high';
    case 7:
      return 'Four of a Kind, ${_rankNamePlural[k0]}';
    case 6:
      return 'Full House, ${_rankNamePlural[k0]} full of ${_rankNamePlural[k1]}';
    case 5:
      return 'Flush, ${_rankName[k0]} high';
    case 4:
      return 'Straight, ${_rankName[k0]} high';
    case 3:
      return 'Three of a Kind, ${_rankNamePlural[k0]}';
    case 2:
      return 'Two Pair, ${_rankNamePlural[k0]} & ${_rankNamePlural[k1]}';
    case 1:
      return 'Pair of ${_rankNamePlural[k0]}';
    default:
      return '${_rankName[k0]} High';
  }
}

/// Core evaluator operating on integer cards (0..51). Length 5–7.
EvaluatedHand evaluateInts(List<int> cards) {
  final score = evaluateScore(cards);
  return EvaluatedHand(
    category: categoryOfScore(score),
    score: score,
    name: handName(score),
  );
}

/// String-facing evaluator.
EvaluatedHand evaluateCards(List<Card> cards) {
  final ints = Int32List(cards.length);
  for (int i = 0; i < cards.length; i++) {
    ints[i] = cardToInt(cards[i]);
  }
  return evaluateInts(ints);
}

/// Compare two evaluated hands: positive if [a] is better.
int compareHands(EvaluatedHand a, EvaluatedHand b) => a.score - b.score;
