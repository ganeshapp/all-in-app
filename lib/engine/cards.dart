/// Card helpers — ported 1:1 from the desktop `src/engine/cards.ts`.
///
/// Card <-> integer encoding (0..51): `int = rankIndex * 4 + suitIndex`
/// where rankIndex 0..12 maps 2..A ([kRanks]) and suitIndex follows
/// [kSuits] (c, d, h, s).
library;

import 'dart:math';
import 'dart:typed_data';

import 'types.dart';

/// Code-unit → rank index (0..12) lookup; -1 for anything else.
final Int8List _rankIndex = () {
  final t = Int8List(128)..fillRange(0, 128, -1);
  for (int i = 0; i < kRanks.length; i++) {
    t[kRanks[i].codeUnitAt(0)] = i;
  }
  return t;
}();

/// Code-unit → suit index (0..3) lookup; -1 for anything else.
final Int8List _suitIndex = () {
  final t = Int8List(128)..fillRange(0, 128, -1);
  for (int i = 0; i < kSuits.length; i++) {
    t[kSuits[i].codeUnitAt(0)] = i;
  }
  return t;
}();

/// `RANKS.indexOf(card[0]) * 4 + SUITS.indexOf(card[1])`.
int cardToInt(Card card) {
  final rc = card.codeUnitAt(0);
  final sc = card.codeUnitAt(1);
  final r = rc < 128 ? _rankIndex[rc] : -1;
  final s = sc < 128 ? _suitIndex[sc] : -1;
  return r * 4 + s;
}

/// `RANKS[i >> 2] + SUITS[i & 3]`.
Card intToCard(int i) => kRanks[i >> 2] + kSuits[i & 3];

/// Rank value 2..14 (Ace high) from an int card.
int rankOf(int i) => (i >> 2) + 2;

/// Suit index 0..3 from an int card.
int suitOf(int i) => i & 3;

/// `[0, 1, ..., 51]`.
List<int> makeDeckInts() => List<int>.generate(52, (i) => i, growable: true);

/// All 52 cards, for r in [kRanks], for s in [kSuits] — same order as ints.
List<Card> makeDeck() {
  final d = <Card>[];
  for (final r in kRanks) {
    for (final s in kSuits) {
      d.add(r + s);
    }
  }
  return d;
}

/// In-place Fisher–Yates shuffle (also returns the list).
///
/// `for i = n-1 down to 1: j = floor(random() * (i + 1)); swap(i, j)`.
/// The desktop uses the unseeded `Math.random`; here the RNG is injectable
/// (pass a `Mulberry32` to reproduce a TypeScript shuffle sequence exactly).
List<T> shuffle<T>(List<T> arr, {Random? rng}) {
  final r = rng ?? Random();
  for (int i = arr.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

/// User-visible suit glyphs (desktop `SUIT_SYMBOL`).
const Map<String, String> kSuitSymbol = {
  's': '♠',
  'h': '♥',
  'd': '♦',
  'c': '♣',
};

bool isRedSuit(String s) => s == 'h' || s == 'd';

String cardRank(Card card) => card[0];

String cardSuit(Card card) => card[1];
