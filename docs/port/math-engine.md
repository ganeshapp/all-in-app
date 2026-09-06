# Port spec: math-engine (cards, evaluator, equity, notation, ranges, engine client)

This document is the complete specification of the poker-math subsystem of
"All-In · Poker Dojo" so that it can be re-implemented in Dart/Flutter without
reading the TypeScript or Rust sources. Every function, constant, algorithm,
user-visible string, edge case and pinned test value is here.

Source files this document replaces (paths relative to the desktop repo
`/Users/gapp/Documents/Code/poker`):

| File | Role |
|---|---|
| `src/types/poker.ts` | shared types/constants (RANKS, SUITS, RANKS_DESC, HandCategory, EvaluatedHand, Position, HandLabel) |
| `src/engine/cards.ts` | card string <-> int encoding, deck, Fisher-Yates shuffle, suit symbols |
| `src/engine/evaluator.ts` | 5/6/7-card hand evaluator with monotonic integer score + human name |
| `src/engine/equity.ts` | PRNG (mulberry32), string hash (hashSeed), Monte-Carlo + exact equity (vs range, vs random, vs field/multiway, range vs range) |
| `src/engine/notation.ts` | 13x13 grid labels (AKs/AKo/TT), combo expansion, combo counts |
| `src/engine/ranges.ts` | Chen-formula hand ranking, top-% ranges, position multipliers, archetype preflop ranges, chart helpers, study range list |
| `src/engine/engineClient.ts` | backend abstraction (Rust via Tauri -> Web Worker -> sync TS); the API surface the UI uses |
| `src/engine/equityWorker.ts` | Web Worker message protocol for the TS fallback |
| `poker-core/src/lib.rs` | Rust twin of evaluator + equity (used under Tauri) |
| `poker-core/examples/equity_matrix.rs` | generator of the 169x169 preflop label-vs-label equity matrix |
| `poker-core/examples/parity.rs` | stdin/stdout harness used by the TS<->Rust parity test |
| `scripts/engine_test.ts`, `golden_test.ts`, `golden_gen.ts`, `parity_test.ts`, `multiway_test.ts` | tests (all expectations reproduced in section 11) |
| `scripts/golden/evaluator.json`, `equity_matrix.json`, `charts.json` | golden data (schemas in section 12) |

A Dart transcription of the PRNG, hash, evaluator and all three seeded
Monte-Carlo loops was run against the TS engine while writing this document
and reproduced every pinned value bit-for-bit (section 11.7). The Dart
snippets below are those verified transcriptions.

---

## 1. Shared types and constants

```dart
// Suits and ranks. ORDER IS LOAD-BEARING (it defines the int encoding).
const List<String> SUITS = ['c', 'd', 'h', 's'];                 // index 0..3
const List<String> RANKS = ['2','3','4','5','6','7','8','9','T','J','Q','K','A']; // index 0..12
// Descending ranks: used ONLY for the 13x13 matrix / labels (A top-left).
const List<String> RANKS_DESC = ['A','K','Q','J','T','9','8','7','6','5','4','3','2'];
```

* `Card` is a 2-character string: rank char + suit char, e.g. `"Ah"`, `"Td"`, `"2c"`.
  Ten is always `T` (never `10`). Suit letters are lowercase.
* `HandLabel` is a 2- or 3-character string for the 13x13 grid: `"AA"`, `"AKs"`, `"AKo"`.
  The higher rank always comes first (`"AKs"`, never `"KAs"`).
* `Position` is one of `"UTG" | "MP" | "CO" | "BTN" | "SB" | "BB"`.

Hand categories (integers, weakest -> strongest) and their display names:

| value | enum name | `HAND_CATEGORY_NAMES` |
|---|---|---|
| 0 | HighCard | `"High Card"` |
| 1 | Pair | `"Pair"` |
| 2 | TwoPair | `"Two Pair"` |
| 3 | Trips | `"Three of a Kind"` |
| 4 | Straight | `"Straight"` |
| 5 | Flush | `"Flush"` |
| 6 | FullHouse | `"Full House"` |
| 7 | Quads | `"Four of a Kind"` |
| 8 | StraightFlush | `"Straight Flush"` |

```dart
class EvaluatedHand {
  final int category;  // 0..8 above
  final int score;     // monotonic, higher is better, comparable across ANY 5-7 card hands
  final String name;   // human name, templates in section 3.4
}
```

---

## 2. Cards (`cards.ts`)

### 2.1 Integer encoding (0..51)

```
int = rankIndex * 4 + suitIndex
rankIndex = index in RANKS (0 = '2' ... 12 = 'A')
suitIndex = index in SUITS (0 = 'c', 1 = 'd', 2 = 'h', 3 = 's')
```

| function | signature | semantics |
|---|---|---|
| `cardToInt` | `int cardToInt(String card)` | `RANKS.indexOf(card[0]) * 4 + SUITS.indexOf(card[1])` |
| `intToCard` | `String intToCard(int i)` | `RANKS[i >> 2] + SUITS[i & 3]` |
| `rankOf` | `int rankOf(int i)` | `(i >> 2) + 2` -> rank value 2..14 (Ace = 14) |
| `suitOf` | `int suitOf(int i)` | `i & 3` |
| `makeDeckInts` | `List<int> makeDeckInts()` | `[0, 1, ..., 51]` in that order |
| `makeDeck` | `List<String> makeDeck()` | for r in RANKS, for s in SUITS: `r + s` -> `["2c","2d","2h","2s","3c",...,"As"]` (same order as ints) |
| `shuffle` | `List<T> shuffle<T>(List<T> arr)` | in-place Fisher-Yates using `Math.random` (UNSEEDED): `for i = n-1 down to 1: j = floor(random() * (i + 1)); swap(arr[i], arr[j])`; returns the same list |
| `cardRank` | `String cardRank(String c)` | `c[0]` |
| `cardSuit` | `String cardSuit(String c)` | `c[1]` |
| `isRedSuit` | `bool isRedSuit(String s)` | `s == 'h' || s == 'd'` |

Pinned values: `2c=0 2d=1 2h=2 2s=3 Ac=48 As=51 Th=34 Kd=45`; `intToCard(0)="2c"`,
`intToCard(51)="As"`, `intToCard(33)="Td"`.

`SUIT_SYMBOL` (user-visible): `s -> "♠"`, `h -> "♥"`, `d -> "♦"`, `c -> "♣"`.

`shuffle` is used by the game engine to shuffle the deck each hand
(`s.deck = shuffle(makeDeck())`) and by drills to shuffle answer options. It is
NOT seeded; only the equity functions are deterministic.

---

## 3. Evaluator (`evaluator.ts`, mirrored exactly in Rust `evaluate`)

### 3.1 Score encoding (the golden JSON pins depend on this exactly)

```
CAT   = 16^5 = 1_048_576
score = category * CAT + pack(tiebreaks)
pack(k) : t = 0; for i in 0..4: t = t * 16 + (i < k.length ? k[i] : 0)
          i.e. up to five rank values (2..14) packed big-endian in base 16,
          zero-padded on the right to exactly five nibbles.
```

Maximum score is a royal flush: `8 * 1_048_576 + pack([14]) = 8_388_608 + 14 * 16^4 = 9_306_112`.
Everything fits comfortably in a 32-bit int (and in a JS double).

Tiebreak lists per category (most significant first):

| category | tiebreaks packed |
|---|---|
| 8 StraightFlush | `[high card of the straight]` (5 for the wheel A-2-3-4-5, 14 for royal) |
| 7 Quads | `[quad rank, best kicker rank]` |
| 6 FullHouse | `[trips rank, pair rank]` |
| 5 Flush | `[top 5 ranks of the flush suit, descending]` |
| 4 Straight | `[high card of the straight]` |
| 3 Trips | `[trips rank, kicker1, kicker2]` |
| 2 TwoPair | `[high pair, low pair, kicker]` |
| 1 Pair | `[pair rank, kicker1, kicker2, kicker3]` |
| 0 HighCard | `[top 5 ranks descending]` |

Kickers are always the highest-ranked cards not already used, by rank
(suit never matters). With fewer than five cards available the missing
slots are 0 (the evaluator is not validated for < 5 cards but does not crash).

### 3.2 Algorithm (step by step)

Input: a list of 5, 6 or 7 card ints (no validation of duplicates or length).

1. Build `counts[r]` for r in 2..14, `rankMask` (bit r set if any card of rank r),
   per-suit `suitRankMask[s]` and `suitCount[s]`.
2. `flushSuit` = the LAST suit s (0..3) with `suitCount[s] >= 5`, else -1.
   (With at most 7 cards only one suit can qualify.)
3. **Straight flush**: if `flushSuit >= 0` and `straightHigh(suitRankMask[flushSuit]) > 0`
   -> category 8, `pack([sfHigh])`.
4. `ranksDesc` = ranks present, descending. `topKickers(exclude, n)` = first n
   entries of ranksDesc not in `exclude`.
5. Scan r from 14 down to 2: `counts[r]==4 -> quad = r`; `==3 -> trips.add(r)`;
   `==2 -> pairs.add(r)`. (Lists therefore come out descending.)
6. **Quads**: if `quad != 0` -> category 7, `pack([quad, topKickers({quad},1)[0] ?? 0])`.
7. **Full house**: if `trips` non-empty: `tripRank = trips[0]`;
   `pairRank = trips.length > 1 ? trips[1] : 0`; if `pairs` non-empty and
   `pairs[0] > pairRank` then `pairRank = pairs[0]`. If `pairRank > 0` ->
   category 6, `pack([tripRank, pairRank])`. (Two trips in 6/7 cards -> the
   lower trips acts as the pair.)
8. **Flush**: if `flushSuit >= 0` -> the top five ranks present in
   `suitRankMask[flushSuit]`, descending -> category 5, `pack(those five)`.
9. **Straight**: `sHigh = straightHigh(rankMask)`; if > 0 -> category 4, `pack([sHigh])`.
10. **Trips**: if `trips` non-empty -> category 3, `pack([trips[0], ...topKickers({trips[0]}, 2)])`.
11. **Two pair**: if `pairs.length >= 2` -> category 2,
    `pack([pairs[0], pairs[1], topKickers({pairs[0],pairs[1]},1)[0] ?? 0])`
    (with three pairs in 6/7 cards the third pair's rank may itself be the kicker).
12. **Pair**: if `pairs.length == 1` -> category 1, `pack([p, ...topKickers({p}, 3)])`.
13. **High card**: category 0, `pack(topKickers({}, 5))`.

`straightHigh(mask)`:
```
m = mask; if (m has bit 14) m |= bit 1          // Ace also plays low for the wheel
for hi = 14 down to 5:
  need = bits hi, hi-1, hi-2, hi-3, hi-4
  if (m & need) == need return hi
return 0
```

### 3.3 Verified Dart transcription

```dart
const int CAT = 1048576; // 16^5
int pack(List<int> k) { int t = 0; for (int i = 0; i < 5; i++) t = t * 16 + (i < k.length ? k[i] : 0); return t; }
int straightHigh(int mask) {
  int m = mask; if (m & (1 << 14) != 0) m |= 1 << 1;
  for (int hi = 14; hi >= 5; hi--) {
    final need = (1 << hi) | (1 << (hi - 1)) | (1 << (hi - 2)) | (1 << (hi - 3)) | (1 << (hi - 4));
    if (m & need == need) return hi;
  }
  return 0;
}
/// returns (category, score); see 3.4 for the name.
(int, int) evaluateInts(List<int> cards) {
  final counts = List<int>.filled(15, 0); final srm = [0,0,0,0]; final sc = [0,0,0,0]; int rankMask = 0;
  for (final c in cards) { final r = (c >> 2) + 2; final s = c & 3; counts[r]++; rankMask |= 1 << r; srm[s] |= 1 << r; sc[s]++; }
  int flushSuit = -1; for (int s = 0; s < 4; s++) if (sc[s] >= 5) flushSuit = s;
  if (flushSuit >= 0) { final sf = straightHigh(srm[flushSuit]); if (sf > 0) return (8, 8 * CAT + pack([sf])); }
  final ranksDesc = <int>[]; for (int r = 14; r >= 2; r--) if (counts[r] > 0) ranksDesc.add(r);
  List<int> topKickers(Set<int> ex, int n) { final o = <int>[]; for (final r in ranksDesc) { if (ex.contains(r)) continue; o.add(r); if (o.length == n) break; } return o; }
  int quad = 0; final trips = <int>[]; final pairs = <int>[];
  for (int r = 14; r >= 2; r--) { if (counts[r] == 4) quad = r; else if (counts[r] == 3) trips.add(r); else if (counts[r] == 2) pairs.add(r); }
  if (quad != 0) { final k = topKickers({quad}, 1); return (7, 7 * CAT + pack([quad, k.isEmpty ? 0 : k[0]])); }
  if (trips.isNotEmpty) { final t = trips[0]; int p = trips.length > 1 ? trips[1] : 0; if (pairs.isNotEmpty && pairs[0] > p) p = pairs[0]; if (p > 0) return (6, 6 * CAT + pack([t, p])); }
  if (flushSuit >= 0) { final fr = <int>[]; for (int r = 14; r >= 2 && fr.length < 5; r--) if (srm[flushSuit] & (1 << r) != 0) fr.add(r); return (5, 5 * CAT + pack(fr)); }
  final sh = straightHigh(rankMask); if (sh > 0) return (4, 4 * CAT + pack([sh]));
  if (trips.isNotEmpty) { final t = trips[0]; return (3, 3 * CAT + pack([t, ...topKickers({t}, 2)])); }
  if (pairs.length >= 2) { final k = topKickers({pairs[0], pairs[1]}, 1); return (2, 2 * CAT + pack([pairs[0], pairs[1], k.isEmpty ? 0 : k[0]])); }
  if (pairs.length == 1) { final p = pairs[0]; return (1, CAT + pack([p, ...topKickers({p}, 3)])); }
  return (0, pack(topKickers({}, 5)));
}
```

`evaluateCards(List<String>)` = `evaluateInts(cards.map(cardToInt))`.
`compareHands(a, b)` = `a.score - b.score` (positive when a is better).

### 3.4 Hand name templates (user-visible; quote verbatim)

Rank words: `14 "Ace" 13 "King" 12 "Queen" 11 "Jack" 10 "Ten" 9 "Nine" 8 "Eight" 7 "Seven" 6 "Six" 5 "Five" 4 "Four" 3 "Three" 2 "Two"`.
Plurals: `"Aces" "Kings" "Queens" "Jacks" "Tens" "Nines" "Eights" "Sevens" "Sixes" "Fives" "Fours" "Threes" "Twos"`.

| category | template (`{R}` = singular rank word, `{Rs}` = plural) |
|---|---|
| 8, high = 14 | `Royal Flush` |
| 8, other | `Straight Flush, {R} high` e.g. `Straight Flush, Nine high` |
| 7 | `Four of a Kind, {Rs}` e.g. `Four of a Kind, Aces` |
| 6 | `Full House, {Rs} full of {Rs}` e.g. `Full House, Aces full of Kings` |
| 5 | `Flush, {R} high` e.g. `Flush, Ace high` |
| 4 | `Straight, {R} high` e.g. `Straight, Five high` (wheel), `Straight, Six high` |
| 3 | `Three of a Kind, {Rs}` |
| 2 | `Two Pair, {Rs} & {Rs}` (high pair first) e.g. `Two Pair, Aces & Kings` |
| 1 | `Pair of {Rs}` e.g. `Pair of Aces` |
| 0 | `{R} High` (capital H, no comma) e.g. `Ace High` |

Note the casing difference: `"Ace High"` for high card vs `"Flush, Ace high"`.
Downstream consumers: the hand-history exporter replaces `" & "` with `" and "`
(`"Two Pair, Aces and Kings"`); the result overlay lowercases the whole name
(`"would have had pair of aces"`-style sentences). The Rust twin returns only
the bare category name (`"Straight Flush"`, `"Pair"`, ...) from `evaluate_hand`,
but the UI never calls the native `evaluate` (see section 9), it always uses
the TS `evaluateCards` names above. The port should produce the TS names.

### 3.5 Pinned evaluator vectors (cards, ints, category, score, name)

```
Ah Kh Qh Jh Th   ints=[50,46,42,38,34]      -> cat=8 score=9306112 "Royal Flush"
9c 8c 7c 6c 5c   ints=[28,24,20,16,12]      -> cat=8 score=8978432 "Straight Flush, Nine high"
Ah Ad Ac As Kd   ints=[50,49,48,51,45]      -> cat=7 score=8310784 "Four of a Kind, Aces"
Ah Ad Ac Kd Ks   ints=[50,49,48,45,47]      -> cat=6 score=7262208 "Full House, Aces full of Kings"
Ah Jh 9h 5h 2h   ints=[50,38,30,14,2]       -> cat=5 score=6207826 "Flush, Ace high"
9c 8d 7h 6s 5c   ints=[28,25,22,19,12]      -> cat=4 score=4784128 "Straight, Nine high"
5h 4d 3c 2s Ah   ints=[14,9,4,3,50]         -> cat=4 score=4521984 "Straight, Five high"
6h 5d 4c 3s 2h   ints=[18,13,8,7,2]         -> cat=4 score=4587520 "Straight, Six high"
Ah Ad Ac Kd Qs   ints=[50,49,48,45,43]      -> cat=3 score=4119552 "Three of a Kind, Aces"
Ah Ad Kc Kd Qs   ints=[50,49,44,45,43]      -> cat=2 score=3070976 "Two Pair, Aces & Kings"
2c 2d 3h 3s Ac   ints=[0,1,6,7,48]          -> cat=2 score=2305536 "Two Pair, Threes & Twos"
Ah Ad Kc Qd Js   ints=[50,49,44,41,39]      -> cat=1 score=2022576 "Pair of Aces"
Ah Ad Kc Qd Ts   ints=[50,49,44,41,35]      -> cat=1 score=2022560 "Pair of Aces"
Ah Jd 9c 5d 3s   ints=[50,37,28,13,7]       -> cat=0 score=964947  "Ace High"
Ah Kh Qh Jh 9h   ints=[50,46,42,38,30]      -> cat=5 score=6216889 "Flush, Ace high"
Ah Kh Qh Th 9h   ints=[50,46,42,34,30]      -> cat=5 score=6216873 "Flush, Ace high"
2h 7d Ah Kh Qh Jh Th  ints=[2,21,50,46,42,38,34]  -> cat=8 score=9306112 "Royal Flush"
7h 2c As Ks Qs Js Ts  ints=[22,0,51,47,43,39,35]  -> cat=8 score=9306112 "Royal Flush"   (board plays)
As Ad Kh Kd Kc 2s 3d  ints=[51,49,46,45,44,3,5]   -> cat=6 score=7200768 "Full House, Kings full of Aces"
Ah Ad Ac Kd Kc Ks 2h  ints=[50,49,48,45,44,47,2]  -> cat=6 score=7262208 "Full House, Aces full of Kings" (two trips)
9c 9d 9h 9s 2c 3d 4h  ints=[28,29,30,31,0,5,10]   -> cat=7 score=7946240 "Four of a Kind, Nines"
2c 3c 4c 5c 7c 8d 9d  ints=[0,4,8,12,20,25,29]    -> cat=5 score=5723186 "Flush, Seven high"
Ac Kc Qc Jc 9c 2c 2d  ints=[48,44,40,36,28,0,1]   -> cat=5 score=6216889 "Flush, Ace high"  (flush beats the pair)
Ah Ad Kc Kd Qs Qh 2c  ints=[50,49,44,45,43,42,0]  -> cat=2 score=3070976 "Two Pair, Aces & Kings" (Q pair is the kicker)
```

Worked example: `Ah Ad Kc Qd Js` -> pair of aces, kickers K Q J ->
`1*1048576 + pack([14,13,12,11]) = 1048576 + (14*16^4 + 13*16^3 + 12*16^2 + 11*16 + 0) = 1048576 + 974000 = 2022576`.

The 600-hand golden corpus (section 12.1) pins 600 more (cards, category, score) triples.

---

## 4. Deterministic randomness (`equity.ts`)

### 4.1 `mulberry32(seed) -> () => double`

32-bit state PRNG returning doubles in [0, 1). The exact bit operations must be
reproduced; all arithmetic is modulo 2^32.

```dart
int _imul(int a, int b) => ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF; // JS Math.imul (low 32 bits)

class Mulberry32 {
  int _a;
  Mulberry32(int seed) : _a = seed & 0xFFFFFFFF;   // JS: seed >>> 0
  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}
```

(On the Dart VM `int` is 64-bit and wraps, so the masked multiply is exact.
Do NOT compile this to JS/double arithmetic without a BigInt or Int32 path.)

Pinned outputs (first five calls, full double precision):
```
seed=0          : 0.26642920868471265, 0.00032974570058286190, 0.22327202744781971, 0.14620214793831110, 0.46732782293111086
seed=1          : 0.62707394058816135, 0.0027357211802154779, 0.52744703995995224, 0.98105096747167408, 0.96837789821438491
seed=42         : 0.60110375192016363, 0.44829055899754167,   0.85246579349040985, 0.66973404143936932, 0.17481389874592423
seed=0xa11a     : 0.47259869566187263, 0.048300619237124920,  0.68552115233615041, 0.13719032658264041, 0.48508235835470259
seed=0xffffffff : 0.89642261411063373, 0.18947825673967600,   0.71565267816185951, 0.94405990932136774, 0.84523643157444894
```

### 4.2 `hashSeed(String) -> int` (FNV-1a, 32-bit)

```dart
int hashSeed(String s) {
  int h = 0x811c9dc5;
  for (int i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & 0xFFFFFFFF;   // JS charCodeAt = UTF-16 code unit
    h = _imul(h, 0x01000193);
  }
  return h & 0xFFFFFFFF;                        // JS: h >>> 0, i.e. 0..4294967295
}
```

Pinned values:
```
hashSeed("")                         = 2166136261
hashSeed("a")                        = 3826002220
hashSeed("abc")                      = 440920331
hashSeed("hello")                    = 1335831723
hashSeed("AsKs|Kh7d2c")              = 2906473402
hashSeed("1|flop|call|AhKh|Ks7d2c")  = 1366682787
hashSeed("QQ|")                      = 1506056881
hashSeed("imp|0|flop|10")            = 1531391887
```

### 4.3 How seeds are derived by callers (so behaviour stays reproducible)

* EV coach (game store): `seed = hashSeed("${handNumber}|${street}|${actionType}|${hole[0]}${hole[1]}|${board.join("")}")`.
  The first run uses `seed`; an escalation re-run (see section 9.4) uses `seed + 1`.
* Bot range narrowing (botBrain): `equityVsRandom(combo, boardInts, 80, hashSeed("${label}|${board.join("")}"))`.
* Hand-history import: `hashSeed("imp|${startedAt}|${street}|${amount}")`.
* Study quiz uses `String(hashSeed(questionText))` merely as a stable React key.
* Drills/puzzles (separate subsystem) also call `hashSeed`, `equityVsRange`, `equityVsRandom` directly.
* When `seed` is omitted the TS engine uses `Math.random` (non-reproducible).

`rngFor(seed)`: `seed == null ? Math.random : mulberry32(seed)`.

Integer draws everywhere are `(rand() * n) | 0`, i.e. `(rand() * n).toInt()`
(truncation toward zero; rand < 1 so the result is 0..n-1).

---

## 5. Equity (`equity.ts`; Rust twin in `lib.rs`)

### 5.1 Result type

```dart
class EquityResult {
  final double equity;  // hero share of the pot, 0..1  (= win + tie/2 over samples, except vs-field, see 5.6)
  final int win, tie, lose;
  final int samples;    // win + tie + lose
  final double se;      // standard error of `equity`; 0 when exact
  final bool exact;     // true when computed by full enumeration, false when sampled
}
```

Helpers:

```
mcResult(win, tie, lose, [equitySum]):
  samples = win + tie + lose
  equity  = samples == 0 ? 0.5 : (equitySum != null ? equitySum / samples : (win + tie / 2) / samples)
  se      = samples == 0 ? 0 : sqrt(max(equity * (1 - equity), 1e-9) / samples)
  exact   = false

exactResult(win, tie, lose):
  samples = win + tie + lose
  equity  = samples == 0 ? 0.5 : (win + tie / 2) / samples
  se = 0, exact = true

EMPTY = {equity: 0.5, win: 0, tie: 0, lose: 0, samples: 0, se: 0, exact: false}
```

`IntCombo` = `[int, int]` (two card ints). `comboToInts([Card, Card])` maps both with `cardToInt`.

Streets by board length: 0 = preflop, 3 = flop, 4 = turn, 5 = river.
`need = 5 - board.length` cards still to come.

### 5.2 `exactVsCombos(hero, board, combos)` (private; turn/river only)

```
used     = {hero[0], hero[1], ...board}          // a Set, so accidental duplicates collapse
heroBase = [hero[0], hero[1], ...board]
need     = 5 - board.length                       // 0 (river) or 1 (turn)
for v in combos:
  if need == 0: compare(v, [])
  else: for c in 0..51: if c in used or c == v[0] or c == v[1]: skip; compare(v, [c])
compare(v, runout):
  hs = evaluate(heroBase + runout).score
  vs = evaluate([v[0], v[1]] + board + runout).score
  hs > vs ? win++ : hs < vs ? lose++ : tie++
return exactResult(win, tie, lose)
```
Sample counts: river = number of combos; turn = combos x (52 - |used| - 2) = combos x 44 on a clean 4-card board.

### 5.3 `equityVsRange(hero, board, range, iters = 1500, seed?)`

Hero's two cards vs a list of villain combos (already expanded from labels).

```
used  = {hero[0], hero[1], ...board}
valid = range.where(c => c[0] not in used && c[1] not in used)   // dead-card / blocker filter
if valid.isEmpty: return EMPTY
if board.length >= 4: return exactVsCombos(hero, board, valid)   // turn & river are EXACT
rand = rngFor(seed)
baseAvail = [i for i in 0..51 if i not in used]                  // ascending
heroBase  = [hero[0], hero[1], ...board]
for it in 0..iters-1:
  villain = valid[(rand() * valid.length).toInt()]               // uniform over COMBOS (labels weight themselves)
  work = copy(baseAvail); len = work.length
  for vc in [villain[0], villain[1]]:                             // in this order
    idx = work.indexOf(vc)                                        // search the whole array
    if idx >= 0: len--; swap(work[idx], work[len])                // move to the dead tail
  draw = []
  for k in 0..need-1:
    j = (rand() * (len - k)).toInt(); last = len - 1 - k
    pick = work[j]; work[j] = work[last]; work[last] = pick; draw.add(pick)
  hs = evaluate(heroBase + draw).score
  vs = evaluate([villain[0], villain[1]] + board + draw).score
  hs > vs ? win++ : hs < vs ? lose++ : tie++
return mcResult(win, tie, lose)
```
The RNG call order per iteration is: 1 call for the villain index, then `need`
calls for the runout. This ordering and the swap-to-tail bookkeeping are what
make the pinned counts reproducible; keep them exactly.

### 5.4 `equityVsRandom(hero, board, iters = 1200, seed?)`

Hero vs ONE uniformly random opponent hand.

```
used = {hero[0], hero[1], ...board}
if board.length == 5:
  combos = all [a, b] with a < b, a,b in 0..51, neither in used      // C(52 - |used|, 2), e.g. C(45,2) = 990
  return exactVsCombos(hero, board, combos)                          // river is EXACT
rand = rngFor(seed); avail = [i not in used]; need = 5 - board.length
for it in 0..iters-1:
  work = copy(avail); len = work.length
  drawDistinct(count): repeat count times: j = (rand()*len).toInt(); len--; swap(work[j], work[len]); out.add(work[len])
  villain = drawDistinct(2)
  runout  = drawDistinct(need)
  compare evaluate(heroBase + runout) vs evaluate(villain + board + runout)
return mcResult(win, tie, lose)
```
(Note: turn vs random is NOT enumerated, only river. Turn vs a range is.)

### 5.5 `equityRangeVsRange(heroRange, board, villRange, iters = 3000, seed?)`

Free-form calculator: one combo sampled from each range per trial.

```
boardSet = Set(board)
hero = heroRange.where(c => neither card in boardSet)
vill = villRange.where(c => neither card in boardSet)
if hero.isEmpty || vill.isEmpty: return EMPTY
need = 5 - board.length
for it in 0..iters-1:
  h = hero[(rand()*hero.length).toInt()]
  v = vill[(rand()*vill.length).toInt()]
  tries = 0
  while (h shares a card with v) && tries < 8: v = vill[(rand()*vill.length).toInt()]; tries++
  if (h still shares a card with v): continue                        // trial DROPPED: samples < iters is possible
  used  = {...board, h[0], h[1], v[0], v[1]}
  avail = [i in 0..51 not in used]; len = avail.length
  draw = need cards via the same swap-to-tail draw as 5.4 (j = (rand()*len).toInt(); len--; swap; take avail[len])
  compare evaluate([h0,h1] + board + draw) vs evaluate([v0,v1] + board + draw)
return mcResult(win, tie, lose)
```
Never exact (even on the river). `samples` may be less than `iters`.

### 5.6 `equityVsField(hero, board, numOpponents, iters = 1500, seed?)` (multiway)

Hero vs N uniformly random opponents; ties split the pot.

```
n = clamp(floor(numOpponents), 1, 8)
used = {hero[0], hero[1], ...board}; avail = [i not in used]; need = 5 - board.length
for it in 0..iters-1:
  work = copy(avail); len = work.length
  oppCards = drawDistinct(n * 2)          // opponent o holds oppCards[2o], oppCards[2o+1]
  runout   = drawDistinct(need)
  heroScore = evaluate(heroBase + runout).score
  best = -1; oppScores = []
  for o in 0..n-1: os = evaluate([opp[2o], opp[2o+1]] + board + runout).score; oppScores.add(os); best = max(best, os)
  if heroScore > best:      win++;  equitySum += 1
  else if heroScore < best: lose++
  else: tied = count of oppScores == heroScore; tie++; equitySum += 1 / (tied + 1)
return mcResult(win, tie, lose, equitySum)      // equity = equitySum / samples, NOT (win + tie/2)/samples
```
Never exact. `se` is computed from that share-weighted equity.

### 5.7 Pinned Monte-Carlo results (seeded; reproduce EXACTLY)

```
equityVsRange(AsKs, [], QQ(6 combos), 2000, seed 42) -> win=948  tie=12 lose=1040 equity=0.477   se=0.011168504823833851
equityVsRange(AsKs, [], QQ, 2000, seed 43)           -> win=907  tie=10 lose=1083
equityVsRange(AsKs, [], QQ, 2000, seed 5)            -> win=953  tie=9  lose=1038 se=0.011170238079378612
equityVsRandom(AhAd, [Ks,7d,2c], 2000, seed 7)       -> win=1783 tie=1  lose=216  equity=0.89175
equityVsRandom(AhAd, [], 1000, seed 1)               -> win=846  tie=3  lose=151  equity=0.8475
equityVsField(AsKs, [], 3 opponents, 2000, seed 7)   -> win=874  tie=38 lose=1088 equity=0.4455 se=0.011113724623185514
equityVsField(AhAd, [Ks,7d,2c], 2, 500, seed 99)     -> win=403  tie=0  lose=97   equity=0.806
equityRangeVsRange(AA combos, [], QQ combos, 1000, seed 1)               -> win=827 tie=3  lose=170 samples=1000 equity=0.8285
equityRangeVsRange(AKs combos, [Ks,7d,2c], KQs combos, 1000, seed 3)     -> win=841 tie=12 lose=147 samples=1000 equity=0.847
equityVsRandom(7h2c, [Ks,7d,2c], 100, seed 1)  (hero card also on board; used-set collapses it) -> win=88 tie=0 lose=12
equityVsRange(AhAd, [], [only AA combos containing Ah or Ad], 100, seed 1) -> EMPTY {0.5,0,0,0,0,0,false}
```

### 5.8 Pinned exact-enumeration results (no RNG involved; both TS and Rust agree)

`iters` is irrelevant for these (the tests pass 10).

```
case0  hero AhKh board Ad Kc 7s 2d 9h  vs random            -> win=975 tie=4   lose=11  samples=990 equity=0.9868686868686869
case1  hero 7h2c board As Ks Qs Js Ts  vs random (board plays) -> win=0 tie=990 lose=0  samples=990 equity=0.5
case2  hero 9c9d board 9h 9s 2c 3d 4h  vs random (quads)    -> win=990 tie=0   lose=0   samples=990 equity=1
case3  hero AhAd board Kc Qd Js 3d 2h  vs [AKs,AKo,TT,T9s]  -> win=12  tie=0   lose=4   samples=16  equity=0.75
case4  hero QsJd board Th 9c 2d 8s Kd  vs [QQ,JJ,TT,AKo,AQs]-> win=21  tie=0   lose=0   samples=21  equity=1
case5  hero 2c2d board Ac Kc Qc Jc 9c  vs [A2s,KQo,55]      -> win=0   tie=14  lose=0   samples=14  equity=0.5
case6  hero AhKh board Ad Kc 7s 2d     vs [QQ,JJ,AKo]       -> win=504 tie=132 lose=24  samples=660 equity=0.8636363636363636
case7  hero 8h7h board 6h 5c Kd 2s     vs [AA,KK,AKs,66]    -> win=120 tie=0   lose=540 samples=660 equity=0.18181818181818182
case8  hero AsQs board Qc 7d 3h As     vs [77,A7s,KQs,JTs]  -> win=355 tie=0   lose=140 samples=495 equity=0.7171717171717171
case9  hero TdTs board 9c 8c 2h 7c     vs [A9s,JTo,65s,QQ]  -> win=189 tie=15  lose=632 samples=836 equity=0.23504784688995214
extra  hero AhKh board Ad Kc 7s 2d     vs [QQ]              -> win=252 tie=0   lose=12  samples=264 equity=0.9545454545454546
```
All have `exact=true, se=0`. Case 8 deliberately (by accident in the original
test) repeats `As` on the board: the used-set has 5 distinct cards, 11 villain
combos survive blocking, 45 rivers each -> 495. The engine performs no
duplicate validation; the port must behave the same to keep parity pins.

### 5.9 Sanity expectations (loose, unseeded; from `engine_test.ts`/`multiway_test.ts`)

* `equityVsRandom(AhAd, [], 6000).equity` ~ 0.85 +/- 0.03
* `equityVsRange(AsKs, [], QQ, 8000).equity` ~ 0.46 +/- 0.04
* `equityVsRange(KhKd, [], AA, 8000).equity` ~ 0.18 +/- 0.04
* MC result: `exact == false`, `0 < se < 0.02` at 2000 iters.
* `equityVsField(AhAd, [], n, 8000)`: n=1 ~ 0.85 +/- 0.03; strictly decreasing for n = 1, 2, 4.
* Top two pair `AhKh` on `Ad Kc 7s`: vs 1 > 0.8, and vs 1 > vs 3.
* `equityRangeVsRange(AA, [], all 1326 combos, 8000)` ~ 0.85 +/- 0.03; `(AKs vs QQ)` ~ 0.46 +/- 0.04.

---

## 6. Notation: labels, grid, combos (`notation.ts`)

### 6.1 13x13 grid convention

Rows and columns are both indexed by `RANKS_DESC` (row 0 / col 0 = Ace,
row 12 / col 12 = Two). Row-major order.

```
r == c        -> pair    "AA"
c  > r (upper triangle) -> suited  "AKs"
r  > c (lower triangle) -> offsuit "AKo"
labelAt(row, col): hi = RANKS_DESC[min(row,col)], lo = RANKS_DESC[max(row,col)]
```
Pins: `labelAt(0,1)="AKs"`, `labelAt(1,0)="AKo"`, `labelAt(12,12)="22"`,
`labelAt(4,9)="T5s"`, `labelAt(9,4)="T5o"`.

`allLabels()` = all 169 labels in row-major grid order:
```
row 0 : AA,AKs,AQs,AJs,ATs,A9s,A8s,A7s,A6s,A5s,A4s,A3s,A2s
row 1 : AKo,KK,KQs,KJs,KTs,K9s,K8s,K7s,K6s,K5s,K4s,K3s,K2s
...
row 12: A2o,K2o,Q2o,J2o,T2o,92o,82o,72o,62o,52o,42o,32o,22
```
This order is also the tie-break order for the Chen ranking (section 7.2), so
it is load-bearing.

### 6.2 Functions

| function | semantics |
|---|---|
| `kindOf(label)` | `label.length == 2 ? "pair" : label.endsWith("s") ? "suited" : "offsuit"` |
| `comboCount(label)` | pair 6, suited 4, offsuit 12 |
| `combosInSet(labels)` | sum of `comboCount` |
| `TOTAL_COMBOS` | 1326 (= C(52,2); 13*6 + 78*4 + 78*12) |
| `labelToCombos(label)` | concrete `[Card, Card]` pairs, ORDER below |
| `cardsToLabel(a, b)` | two cards -> label; higher rank first (by RANKS_DESC index); same rank -> pair; same suit -> `s` else `o` |
| `prettyLabel(label)` | identity (returns the label unchanged) |

`labelToCombos` order (hi = first rank char, lo = second; suits iterate `c,d,h,s`):
* pair: `for i in 0..3, for j in i+1..3: [hi+SUITS[i], hi+SUITS[j]]`
  -> `AA = [Ac Ad],[Ac Ah],[Ac As],[Ad Ah],[Ad As],[Ah As]`
* suited: `for s: [hi+s, lo+s]` -> `AKs = [Ac Kc],[Ad Kd],[Ah Kh],[As Ks]`
* offsuit: `for s1, for s2, s1 != s2: [hi+s1, lo+s2]`
  -> `AKo = [Ac Kd],[Ac Kh],[Ac Ks],[Ad Kc],[Ad Kh],[Ad Ks],[Ah Kc],[Ah Kd],[Ah Ks],[As Kc],[As Kd],[As Kh]`

The Rust `label_to_combos` produces the same combos in the same order as ints
(`hi*4+s1, lo*4+s2`). This ordering matters because `equityVsRange` indexes
into the expanded list with the PRNG.

Pins: `cardsToLabel("As","Kd")="AKo"`, `("As","Ks")="AKs"`, `("Ts","Td")="TT"`,
`("Kd","As")="AKo"`, `("2c","7c")="72s"`. `allLabels().length == 169`,
`combosInSet(allLabels()) == 1326`, `labelToCombos("AKs").length == 4`.

There is no textual range parser/serializer (no "22+, A2s+" syntax): ranges are
always `Set<HandLabel>` / `List<HandLabel>` built from the grid or from
frequency charts (`Record<label, 0..1>`), see 7.6.

---

## 7. Preflop hand ranking and ranges (`ranges.ts`)

### 7.1 Chen score

```
rankValue(r) = 12 - RANKS_DESC.indexOf(r) + 2        // 'A' -> 14 ... '2' -> 2
highCardScore(v): v == 14 -> 10; 13 -> 8; 12 -> 7; 11 -> 6; otherwise v / 2   (T=5, 9=4.5, ..., 2=1)

chenScore(label):
  hiVal = rankValue(label[0])
  if pair:   return max(5, highCardScore(hiVal) * 2)
  loVal = rankValue(label[1])
  score = highCardScore(hiVal)
  if suited: score += 2
  gap = hiVal - loVal - 1                             // 0 for connectors (AK, 98), 1 for one-gappers
  if gap == 1: score -= 1
  else if gap == 2: score -= 2
  else if gap == 3: score -= 4
  else if gap >= 4: score -= 5
  if gap <= 1 && hiVal < 12: score += 1               // straight bonus: 0/1 gap and high card below Queen
  return score                                        // a multiple of 0.5; may be negative
```
This is the classic Chen formula WITHOUT the "round half up" step.

Pinned scores:
```
AA=20 KK=16 QQ=14 JJ=12 TT=10 99=9 88=8 77=7 66=6 55=5 44=5 33=5 22=5
AKs=12 AKo=10 AQs=11 AQo=9 AJs=10 ATs=8 A9s=7 A5s=7 A2s=7
KQs=10 KQo=8 KJs=9 KTs=8 K9s=6 K2s=5 QJs=9 JTs=9 T9s=8 98s=7.5 87s=7 76s=6.5 65s=6 54s=5.5 43s=5 32s=4.5
J9s=8 T8s=7 97s=6.5 86s=6 75s=5.5 64s=5 53s=4.5 42s=4 Q9s=7 J8s=6
ATo=6 KTo=6 QTo=6 J9o=6 T9o=6 98o=5.5
72s=0.5 72o=-1.5 62o=-1 82o=-1 83o=-1 73o=-0.5 92o=-0.5 93o=-0.5 94o=-0.5 84o=0 T2o=0 T3o=0 T4o=0 T5o=0 52o=0.5 95o=0.5
```

### 7.2 `rankedHands()` — all 169 hands strongest -> weakest (cached)

Sort `allLabels()` (grid order) by:
1. `score` descending;
2. kind: pair (0) < suited (1) < offsuit (2), i.e. pairs first;
3. `rankValue(label[0])` descending (higher top card first);
4. ORIGINAL GRID ORDER (JS `Array.sort` is stable). Dart's `List.sort` is NOT
   stable: sort by `(score desc, kind asc, hiRank desc, gridIndex asc)` explicitly.

Each entry is `{label, score, combos: comboCount(label)}`.

The full pinned order (1 = AA ... 169 = 72o):
```
  1:AA    2:KK    3:QQ    4:JJ    5:AKs   6:AQs   7:TT    8:AJs   9:KQs  10:AKo
 11:99   12:KJs  13:QJs  14:JTs  15:AQo  16:88   17:ATs  18:KTs  19:QTs  20:J9s
 21:T9s  22:AJo  23:KQo  24:98s  25:77   26:A9s  27:A8s  28:A7s  29:A6s  30:A5s
 31:A4s  32:A3s  33:A2s  34:Q9s  35:T8s  36:87s  37:KJo  38:QJo  39:JTo  40:97s
 41:76s  42:66   43:K9s  44:J8s  45:86s  46:65s  47:ATo  48:KTo  49:QTo  50:J9o
 51:T9o  52:75s  53:54s  54:98o  55:55   56:44   57:33   58:22   59:K8s  60:K7s
 61:K6s  62:K5s  63:K4s  64:K3s  65:K2s  66:Q8s  67:T7s  68:64s  69:43s  70:A9o
 71:A8o  72:A7o  73:A6o  74:A5o  75:A4o  76:A3o  77:A2o  78:Q9o  79:T8o  80:87o
 81:96s  82:53s  83:32s  84:97o  85:76o  86:Q7s  87:Q6s  88:Q5s  89:Q4s  90:Q3s
 91:Q2s  92:J7s  93:85s  94:42s  95:K9o  96:J8o  97:86o  98:65o  99:74s 100:75o
101:54o 102:J6s 103:J5s 104:J4s 105:J3s 106:J2s 107:T6s 108:63s 109:K8o 110:K7o
111:K6o 112:K5o 113:K4o 114:K3o 115:K2o 116:Q8o 117:T7o 118:64o 119:43o 120:95s
121:52s 122:96o 123:53o 124:32o 125:T5s 126:T4s 127:T3s 128:T2s 129:84s 130:Q7o
131:Q6o 132:Q5o 133:Q4o 134:Q3o 135:Q2o 136:J7o 137:85o 138:42o 139:94s 140:93s
141:92s 142:73s 143:74o 144:83s 145:82s 146:62s 147:J6o 148:J5o 149:J4o 150:J3o
151:J2o 152:T6o 153:63o 154:72s 155:95o 156:52o 157:T5o 158:T4o 159:T3o 160:T2o
161:84o 162:94o 163:93o 164:92o 165:73o 166:83o 167:82o 168:62o 169:72o
```
(Also pinned as `charts.json.ranked`.) `strengthRankMap()` returns
`Map<label, 1-based index in this list>` (AA -> 1, 72o -> 169).

### 7.3 `topPercentRange(pct) -> Set<HandLabel>`

```
target = clamp(pct, 0, 100) / 100 * 1326
acc = 0; out = {}
for h in rankedHands():
  if acc >= target: break
  out.add(h.label); acc += h.combos
return out            // insertion order = strength order
```
The hand that crosses the target IS included; pct <= 0 -> empty set; pct >= 100
-> all 169. Pins:
```
pct=0.5 -> 2 labels / 12 combos       pct=1  -> {AA,KK,QQ} (18 combos, target 13.26)
pct=2   -> {AA,KK,QQ,JJ,AKs} (28)     pct=3  -> 8 labels / 42 combos
pct=5   -> 12 labels / 68 combos: 99,AA,AJs,AKo,AKs,AQs,JJ,KJs,KK,KQs,QQ,TT (sorted)
pct=10  -> 23 labels / 138: AA,KK,QQ,JJ,AKs,AQs,TT,AJs,KQs,AKo,99,KJs,QJs,JTs,AQo,88,ATs,KTs,QTs,J9s,T9s,AJo,KQo
pct=14  -> 35 labels / 188            pct=20 -> 47 / 270      pct=22 -> 49 / 294
pct=27  -> 58 / 362                   pct=45 -> 91 / 598      pct=55 -> 110 / 738
pct=90  -> 158 / 1194                 pct=100 -> 169 / 1326   pct=150 -> 169 (clamped)
label counts for p = 2,3,4,6,8,10,12,15,18,20,22,25,27,30,35,40,45,50,55,60,70,80,90:
                     5,8,10,15,20,23,28,37,42,47,49,54,58,67,74,80,91,100,110,115,131,147,158
```
`charts.json.topPct[p]` pins the sorted label list for every integer p in 1..100.

### 7.4 `positionMultiplier(pos)`

| UTG | MP | CO | BTN | SB | BB |
|---|---|---|---|---|---|
| 0.5 | 0.68 | 0.9 | 1.25 | 0.85 | 1.0 |

### 7.5 `buildPreflopRanges(vpip, pfr, pos) -> {play: Set, raise: Set}`

```
mult     = positionMultiplier(pos)
playPct  = max(4, min(90, vpip * mult))
raisePct = max(2, min(playPct, pfr * mult))
play  = topPercentRange(playPct)
raise = topPercentRange(raisePct)          // always a subset of play (same ordering, smaller target)
```
Archetype inputs (from `src/game/archetypes.ts`, needed for the golden pins):

| archetype | vpip | pfr |
|---|---|---|
| TAG | 22 | 18 |
| LAG | 34 | 27 |
| Nit | 12 | 9 |
| Station | 46 | 7 |

Pinned table (`playPct/raisePct` are the exact doubles; sizes are label count / combo count):
```
TAG:UTG  mult=0.5  playPct=11    raisePct=9      play=25/148  raise=22/126
TAG:MP   0.68      14.96         12.24           37/204       29/164
TAG:CO   0.9       19.8          16.2            47/270       38/216
TAG:BTN  1.25      27.5          22.5            59/366       50/306
TAG:SB   0.85      18.7          15.299999999999999  44/250   37/204
TAG:BB   1         22            18              49/294       42/242
LAG:UTG  0.5       17            13.5            39/228       33/180
LAG:MP   0.68      23.12         18.360000000000003  51/318   43/246
LAG:CO   0.9       30.6          24.3            69/406       53/326
LAG:BTN  1.25      42.5          33.75           85/574       73/454
LAG:SB   0.85      28.9          22.95           64/386       50/306
LAG:BB   1         34            27              73/454       58/362
Nit:UTG  0.5       6             4.5             15/88        11/64
Nit:MP   0.68      8.16          6.12            20/110       15/88
Nit:CO   0.9       10.8          8.1             25/148       20/110
Nit:BTN  1.25      15            11.25           37/204       26/152
Nit:SB   0.85      10.2          7.6499999999999995  23/138   18/102
Nit:BB   1         12            9               28/160       22/126
Station:UTG 0.5    23            3.5             50/306       10/58
Station:MP  0.68   31.28         4.760000000000001   70/418   11/64
Station:CO  0.9    41.4          6.3             83/550       15/88
Station:BTN 1.25   57.5          8.75            113/774      22/126
Station:SB  0.85   39.1          5.95            79/526       15/88
Station:BB  1      46            7               94/610       16/94
```
Exact label sets, e.g. `TAG:UTG.play` (sorted) =
`77,88,98s,99,AA,AJo,AJs,AKo,AKs,AQo,AQs,ATs,J9s,JJ,JTs,KJs,KK,KQo,KQs,KTs,QJs,QQ,QTs,T9s,TT`
and `TAG:UTG.raise` =
`88,99,AA,AJo,AJs,AKo,AKs,AQo,AQs,ATs,J9s,JJ,JTs,KJs,KK,KQs,KTs,QJs,QQ,QTs,T9s,TT`;
`Nit:UTG.play` = `99,AA,AJs,AKo,AKs,AQo,AQs,JJ,JTs,KJs,KK,KQs,QJs,QQ,TT`,
`Nit:UTG.raise` = `99,AA,AJs,AKo,AKs,AQs,JJ,KK,KQs,QQ,TT`. All 24 are in `charts.json.bots`.

Beware the floating-point products (e.g. `15.299999999999999`): compute
`vpip * mult` in doubles exactly as written; do not round.

### 7.6 Frequency-chart helpers

Charts elsewhere in the app are `Map<HandLabel, double frequency 0..1>`.

* `chartToSet(chart, min = 0.5)`: labels whose frequency `>= min`.
* `chartWidth(chart)`: `sum(f * comboCount(label)) / 1326` — e.g.
  `chartWidth({AA:1, AKs:0.5, 72o:0.25}) = (6 + 2 + 3)/1326 = 0.008295625942684766`.

### 7.7 `STUDY_RANGES` (user-visible, verbatim)

```
{ title: "UTG Open (~14%)", pct: 14, note: "Tightest opening range — premium pairs, big broadways, AK–AQ." }
{ title: "CO Open (~27%)",  pct: 27, note: "Widen with suited connectors and more broadways." }
{ title: "BTN Open (~45%)", pct: 45, note: "Steal wide — any pair, most suited hands, many offsuit broadways." }
{ title: "BB Defend (~55%)", pct: 55, note: "Closing the action with a price; defend wide vs a single raise." }
```
(The dashes are em dashes `—` and the AK–AQ dash is an en dash `–`.)

---

## 8. Rust twin (`poker-core`) — what differs and what is shared

* Same card encoding, same `evaluate` (category, score) — verified identical on
  the 600-hand golden corpus and on the exact-enumeration cases.
* `evaluate_named` returns `name = category_name(category)` only:
  `"Straight Flush" | "Four of a Kind" | "Full House" | "Flush" | "Straight" | "Three of a Kind" | "Two Pair" | "Pair" | "High Card"`.
* RNG is `rand::rngs::StdRng` (rand 0.8 = ChaCha12) seeded with `seed_from_u64`
  (or entropy when `None`). Its sampled results are NOT reproducible from
  mulberry32; the two engines only agree on exact paths. The seed is `u64`
  there and a 32-bit unsigned in TS (`hashSeed` output fits both).
* `equity_vs_range` / `equity_vs_random` / `equity_vs_field` mirror sections
  5.3/5.4/5.6 exactly (same used-set filtering, exact on turn/river, same
  clamp 1..8, same share-weighted multiway equity). There is no Rust
  range-vs-range.
* `draw_distinct` is the same swap-to-tail draw.

### 8.1 Tauri command layer (`src-tauri/src/lib.rs`)

| command | args (JSON) | behaviour |
|---|---|---|
| `evaluate_hand` | `cards: string[]` | `evaluate_named(cards_to_ints)` |
| `equity_vs_range` | `hero: string[2]`, `board: string[]`, `range: label[]`, `iters: u32`, `seed: u64 \| null` | expands labels with `label_to_combos` (no blocker filtering here; the core filters), `iters.max(1)`; `hero.len() < 2` -> EMPTY |
| `equity_vs_random` | `hero, board, iters, seed` | idem |
| `equity_vs_field` | `hero, board, opponents: u32, iters, seed` | idem |

### 8.2 `examples/equity_matrix.rs` — 169x169 preflop matrix generator

Produces `scripts/golden/equity_matrix.json`, consumed by the push/fold and ICM
push/fold solvers (`scripts/pushfold_gen.ts`, `scripts/icm_pushfold_gen.ts`).

```
labels: for i in 0..12, for j in i..12: i == j ? "RiRi" : "RiRjs" then "RiRjo"   (Ri from "AKQJT98765432")
        -> AA, AKs, AKo, AQs, AQo, ..., A2s, A2o, KK, KQs, KQo, ..., 33, 32s, 32o, 22   (NOT grid row-major order)
rng = StdRng::seed_from_u64(0xa11a_2026); ITERS = 40_000 per unordered pair
eq[i][i] = 0.5
for i < j:
  repeat until 40_000 accepted trials:
    a = random combo of label i, b = random combo of label j (uniform over combos)
    if a and b share a card: reject (do not count)
    board = 5 distinct cards drawn by rejection from 0..51 excluding a, b
    compare evaluate(a + board) vs evaluate(b + board)
  eq[i][j] = (win + tie/2) / 40_000 ; eq[j][i] = 1 - eq[i][j]
output: {"labels":[...169...],"equity":[[...169 rows of 169 numbers formatted "%.4f"...]]}
```
SE per entry ~ 0.25%. Because the generator is not mulberry32-based, a Dart port
should ship the JSON file as data rather than regenerate it.

### 8.3 `examples/parity.rs`

Reads `{evals: number[][], equities: [{hero: string[], board: string[], range: label[]}]}`
on stdin and writes `{evals: [{category, score}], equities: [{win, tie, lose, exact}]}`.
An empty `range` means "vs random" (iters 10, exact on the river); otherwise
`equity_vs_range` with the expanded labels (iters 10, exact on turn/river).

---

## 9. Engine client (`engineClient.ts`) — the API surface the UI relies on

### 9.1 Backend selection

```
isNative(): window exists && ("__TAURI_INTERNALS__" in window || "__TAURI__" in window)   (memoised)
EngineBackend = "rust" | "worker" | "ts"
```
Order per call: native Rust (`invoke`) -> on any throw fall through -> Web
Worker running the TS engine -> if the worker cannot be created / errors ->
synchronous TS. The first backend actually used is logged once:
`console.info("[engine] equity backend: " + backend)`.

Worker protocol (`equityWorker.ts`):
```
EquityJob =
  | {kind:"range",        hero:[int,int], board:int[], range:[int,int][], iters:int, seed?:int}
  | {kind:"random",       hero:[int,int], board:int[], iters:int, seed?:int}
  | {kind:"field",        hero:[int,int], board:int[], opponents:int, iters:int, seed?:int}
  | {kind:"rangeVsRange", heroRange:[int,int][], board:int[], villRange:[int,int][], iters:int, seed?:int}
EquityRequest  = {id:int, job:EquityJob}       EquityResponse = {id:int, result:EquityResult}
```
Ids are a monotonically increasing counter starting at 1; the worker is a
single shared instance; on `onerror` it is terminated, all pending promises
are dropped (they never resolve), and the client permanently falls back to
sync TS. NOTE: the synchronous fallback path in `fallback()` does NOT pass
`seed` (a minor bug in the original: sync-TS results are unseeded even when a
seed was given). The worker and Rust paths do pass the seed. The port should
pass the seed everywhere.

### 9.2 Public API (`engine` object; the UI imports it as `math`)

```ts
engine.evaluate(cards: Card[]): Promise<EvaluatedHand>                                   // native or evaluateCards; UNUSED by UI
engine.equityVsRange(hero: [Card,Card], board: Card[], range: HandLabel[], iters = 1500, seed?): Promise<EquityResult>
engine.equityVsRandom(hero, board, iters = 1200, seed?): Promise<EquityResult>
engine.equityVsField(hero, board, numOpponents: number, iters = 1500, seed?): Promise<EquityResult>
engine.equityRangeVsRange(heroCombos: [int,int][], boardInts: int[], villCombos: [int,int][], iters = 5000, seed?): Promise<EquityResult>  // never native
```
Note the mixed argument conventions: the first three take card STRINGS and
LABELS; range-vs-range takes already-expanded INT combos and an int board.

`expandRange(range, hero, board)` (TS path only): for each label, each
`labelToCombos` pair, skip combos containing a hero or board card, map to ints.
(The Rust path gets raw labels and filters inside.)

### 9.3 Non-async engine functions used directly by the rest of the app

`evaluateCards` (game engine showdown, hand history text, result overlay),
`evaluateInts` (bot range narrowing on the river; study range-vs-board
breakdown), `equityVsRandom` + `hashSeed` (bot range narrowing, 80 iters),
`cardToInt`, `makeDeck`, `shuffle`, `labelToCombos`, `cardsToLabel`,
`comboCount`, `combosInSet`, `allLabels`, `labelAt`, `kindOf`, `chenScore`,
`rankedHands`, `strengthRankMap`, `topPercentRange`, `buildPreflopRanges`,
`positionMultiplier`, `chartToSet`, `chartWidth`, `STUDY_RANGES`,
`SUIT_SYMBOL`, `isRedSuit`, `cardRank`, `cardSuit`, `rankOf`, `suitOf`,
`makeDeckInts`. All must exist as synchronous pure functions in the port.

### 9.4 Call sites and their iteration counts (behaviour to preserve)

* **EV coach** (game store, every hero decision): chooses
  `equityVsField(hole, board, opponents, iters, seed)` in multiway ("field")
  mode, else `equityVsRange(hole, board, range, iters, seed)` when a villain
  range is known, else `equityVsRandom`. `baseIters = simQuality == "high" ? 4000 : 1600`.
  If the result is not exact, the action costs chips (`costNow > 0`), and
  `|equity - threshold| < 2 * se` (threshold = `costNow / (pot + costNow)`),
  it re-runs with `baseIters * 4` and `seed + 1`.
* **Equity calculator** (study): hand vs range -> `equityVsRange(heroCards, board, [...villLabels], 5000)`;
  range vs range -> `equityRangeVsRange(heroCombos, boardInts, villCombos, 5000)`; unseeded.
* **Multiway equity trainer** (study): `equityVsField(hero, board, n, 1200)` for n = 1..5 in parallel.
* **Bot brain** `narrowRange`: river -> `evaluateInts(combo + board).score`; earlier
  streets -> `equityVsRandom(combo, board, 80, hashSeed(label + "|" + board)).equity`.

---

## 10. Invariants and edge cases (checklist for the port)

1. Score monotonicity: any better hand has a strictly larger score; equal
   hands (same category and same five ranks) have equal scores regardless of suits.
2. `evaluateInts` accepts 5..7 cards; the 7-card best hand is found implicitly
   (no 21-combination search). Board-plays-for-both gives a tie.
3. No input validation anywhere (duplicate cards, bad strings). Duplicates in
   hero/board collapse in the used-set; duplicates inside the card list passed
   to the evaluator are simply counted twice.
4. Turn/river vs range and river vs random are exact (`exact = true, se = 0`).
   Flop/preflop vs range, all vs-field, all range-vs-range, and turn vs random are sampled.
5. Empty valid villain range (all blocked) -> EMPTY result (equity 0.5, samples 0, exact false).
6. `equity` is `(win + tie/2)/samples` except vs-field, which uses the
   pot-share sum `1/(tied + 1)` per tie.
7. `se = sqrt(max(p(1-p), 1e-9) / samples)`; the 1e-9 floor keeps se > 0 when p is 0 or 1.
8. `equityVsField` clamps opponents to 1..8 after `floor`.
9. `equityRangeVsRange` may return `samples < iters` (dropped clashing trials).
10. Same seed => identical `win/tie/lose`; different seed => (almost surely) different counts.
11. `topPercentRange` includes the hand that crosses the target; `raise ⊆ play`.
12. `rankedHands()[0].label == "AA"`; `topPercentRange(100).size == 169`.
13. `buildPreflopRanges(22,18,"BTN").play` is wider (more combos) than `buildPreflopRanges(22,18,"UTG").play`.

---

## 11. Existing tests and their concrete expectations

Run in the original repo with `node --experimental-transform-types scripts/<name>.ts`.

### 11.1 `engine_test.ts` (categories, ordering, tie-breaks, notation, ranges, equity)
* Category of each 5-card hand in section 3.5 (royal, straight flush, quads, full
  house, flush, straight, wheel, trips, two pair, pair, high card) is as listed.
* Ordering: `sf > quads > fh > flush > straight > trips > twoPair > pair > high` on those hands.
* `score(Ah Ad Kc Qd Js) > score(Ah Ad Kc Qd Ts)` (pair kicker J > T).
* `score(6h 5d 4c 3s 2h) > score(5h 4d 3c 2s Ah)` (six-high straight beats wheel).
* `score(Ah Kh Qh Jh 9h) > score(Ah Kh Qh Th 9h)` (flush second kicker).
* 7-card: `2h 7d Ah Kh Qh Jh Th` is StraightFlush; `As Ad Kh Kd Kc 2s 3d` is FullHouse.
* `comboCount("AA")==6, ("AKs")==4, ("AKo")==12`; `allLabels().length==169`;
  `combosInSet(allLabels())==1326`; `labelToCombos("AKs").length==4`;
  `cardsToLabel("As","Kd")=="AKo"`, `("As","Ks")=="AKs"`, `("Ts","Td")=="TT"`.
* `rankedHands()[0].label=="AA"`; `topPercentRange(100).size==169`;
  `combosInSet(buildPreflopRanges(22,18,"BTN").play) > combosInSet(buildPreflopRanges(22,18,"UTG").play)`;
  `combosInSet(utg.raise) <= combosInSet(utg.play)`.
* Equity sanity (unseeded): AA vs random 6000 iters ~0.85 +/- 0.03; AKs vs QQ 8000 ~0.46 +/- 0.04; KK vs AA 8000 ~0.18 +/- 0.04.
* Determinism: `equityVsRange(AsKs,[],QQ,2000,42)` twice -> identical win/tie/lose
  (pinned 948/12/1040); `equityVsRandom(AhAd,[Ks7d2c],2000,7)` twice -> identical
  equity (pinned 0.89175); seed 43 -> different counts (907/10/1083).
* Exact: `equityVsRandom(AhKh, [Ad Kc 7s 2d 9h], 10)` -> exact, se 0, samples 990, equity > 0.85 (pinned 975/4/11);
  `equityVsRange(AhKh, [Ad Kc 7s 2d], QQ, 10)` -> exact, samples 6*44 = 264, equity > 0.9 (pinned 252/0/12).
* `equityVsRange(AsKs,[],QQ,2000,5)`: exact false, 0 < se < 0.02 (pinned se 0.011170238079378612).

### 11.2 `golden_test.ts`
* Every corpus entry of `evaluator.json` (600) must give identical `category` and `score`.
* `rankedHands().map(label)` must equal `charts.json.ranked` (section 7.2 list).
* For p in 1..100, `sorted(topPercentRange(p))` must equal `charts.json.topPct[p]`.
* For each archetype x position, `sorted(play)` / `sorted(raise)` must equal `charts.json.bots["Name:POS"]`.

### 11.3 `golden_gen.ts` (how the corpus was made — reproducible with the Dart Mulberry32)
```
rand = mulberry32(0xa11a)           // ONE generator shared across all 600 hands
for i in 0..599:
  deck = [0..51]
  for k = 51 down to 1: j = (rand() * (k + 1)).toInt(); swap(deck[k], deck[j])
  cards = deck[0 .. 5 + (i % 3))    // 5, 6, 7, 5, 6, 7, ...
  corpus.add({cards, category, score})
```
First entries: `[18,16,9,27,1] -> (1, 1475616)`, `[26,24,14,50,7,16] -> (1, 1631824)`,
`[8,26,23,34,51,11,33] -> (2, 2772480)`, `[26,37,39,1,35] -> (1, 1812512)`,
`[15,3,21,13,18,29] -> (1, 1415008)`. Last two: `[23,37,48,18,49,20] -> (2, 3046144)`,
`[16,47,22,10,35,24,15] -> (4, 4718592)`.

### 11.4 `parity_test.ts`
* All 600 corpus hands: TS and Rust `(category, score)` identical.
* The 10 `EQ_CASES` of section 5.8 (cases 0..9): both sides exact and identical win/tie/lose.

### 11.5 `multiway_test.ts`
* `equityVsField(AhAd, [], n, 8000)`: n=1 within 0.03 of 0.85; `e1 > e2 > e4`.
* `equityVsField(AhKh, [Ad Kc 7s], 1, 8000) > 0.8` and `> equityVsField(..., 3, 8000)`.
* `0 <= equity <= 1`.
* `equityRangeVsRange(AA, [], all 1326 combos, 8000)` within 0.03 of 0.85;
  `equityRangeVsRange(AKs, [], QQ, 8000)` within 0.04 of 0.46.

### 11.6 Rust unit tests (`lib.rs`)
Categories/ordering as in 11.1; `equity_vs_random(AhAd, [], 30000)` ~0.85 +/- 0.02;
`equity_vs_range(AsKs, [], QQ, 40000)` ~0.46 +/- 0.03; AA vs 1 opponent > AA vs 4;
seeded runs identical; river vs random exact with samples 990; turn vs range exact.

### 11.7 Dart verification performed for this document
A Dart program implementing sections 3.3, 4.1, 4.2, 5.3, 5.4, 5.6 and 6.2
reproduced: `mulberry32(42)` = 0.6011037519201636, 0.44829055899754167,
0.8524657934904099; `hashSeed("hello")` = 1335831723; the royal / pair / wheel /
7-card full-house scores; golden corpus entries 0 and 2; and the three seeded
MC pins `948/12/1040`, `1783/1/216`, `874/38/1088 (0.4455)`. Use those as the
first Dart tests.

---

## 12. Golden data files (copy as-is into the Dart test assets)

### 12.1 `scripts/golden/evaluator.json` (~30 KB, one line)
```
{ "corpus": [ { "cards": int[5|6|7], "category": int 0..8, "score": int }, ... 600 entries ] }
```
200 hands each of 5, 6 and 7 cards. Category histogram: 0: 208, 1: 257, 2: 90,
3: 16, 4: 15, 5: 8, 6: 5, 8: 1 (no quads in the corpus).

### 12.2 `scripts/golden/equity_matrix.json` (201,290 bytes, one line)
```
{ "labels": string[169], "equity": number[169][169] }      // equity[i][j] = P(label i beats label j) + ties/2, 4 decimals
```
Label order: `AA, AKs, AKo, AQs, AQo, AJs, AJo, ATs, ATo, A9s, A9o, ..., A2s, A2o, KK, KQs, KQo, ..., 42o, 33, 32s, 32o, 22`.
Samples: `equity[AA][AA] = 0.5`; `equity[AA][KK] = 0.8188`, `equity[KK][AA] = 0.1812`;
`equity[AKs][QQ] = 0.4597`; `equity[KK][AKs] = 0.664`; `equity[72o][AA] = 0.1203`;
row 0 begins `0.5, 0.8745, 0.9294, 0.8773, 0.9262, 0.8713, 0.9252, 0.8697, 0.9182, 0.8832`.
Consumers weight labels by `comboCount/1326` and index by `labels.indexOf`.

### 12.3 `scripts/golden/charts.json`
```
{ "ranked": string[169],                       // section 7.2 order
  "topPct": { "1": string[], ..., "100": string[] },   // sorted (JS default string sort) label lists
  "bots":   { "TAG:UTG": {"play": string[], "raise": string[]}, ... 24 keys (TAG|LAG|Nit|Station x UTG|MP|CO|BTN|SB|BB) } }
```
Sorted lists use JavaScript's default `Array.sort()` (UTF-16 code-unit order:
digits < uppercase letters, so `"22" < "77" < "98s" < "A2s" < "AA" < "AJo" < "AJs" < "AKo"`).
Dart's default `String.compareTo` gives the same order for these ASCII labels.

---

## 13. Port notes / design decisions for mobile

* Use mulberry32 + hashSeed as THE seeded RNG on all platforms (the Rust StdRng
  path is the only non-reproducible backend and does not need to exist on
  mobile). All coach verdicts, bot range narrowing and drills then become
  reproducible across desktop-TS and mobile-Dart for the same seed.
* Replace the Rust/Worker/sync tiering with a single Dart implementation run in
  an isolate (`compute`) for the async `engine.*` calls; keep the synchronous
  functions of 9.3 callable on the main isolate (they are cheap except the
  80-iteration `equityVsRandom` calls in bot narrowing, which are fine).
* Keep the EquityResult field names (`equity, win, tie, lose, samples, se, exact`)
  — other subsystems and hand-history exports read them.
* `List.sort` instability: implement the four-key comparator in 7.2 explicitly.
* Ints: scores < 2^24, card ints < 52, seeds < 2^32 — all safe in Dart `int`;
  mask to 32 bits in the PRNG/hash only.
* Performance: the evaluator allocates small lists per call; the coach runs up
  to 16,000 iterations x 2 evaluations (or x (n+1) for multiway) per decision.
  A straightforward Dart port handles this in well under a second on a phone;
  micro-optimise (fixed-size Int32Lists, no closures) only if profiling says so,
  and never in a way that changes draw order.
