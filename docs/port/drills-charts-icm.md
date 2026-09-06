# Port spec: Drills, Preflop Charts, Push/Fold Nash tables, ICM

Subsystem: `drills-charts-icm` of "All-In · Poker Dojo".
Source of truth (TypeScript, do not need to open it after reading this):

| File | Role |
|---|---|
| `src/engine/puzzles.ts` (1229 lines) | Puzzle generators, grading, data model, leak replay |
| `src/store/drillStore.ts` | Drill modes, adaptive difficulty, Elo rating, replay navigator state, review queue wiring |
| `src/data/preflop.ts` | Generated 100bb 6-max preflop charts (RFI + vs-RFI) |
| `src/data/pushfold.ts` | Generated Nash push/fold tables (chip EV) |
| `src/data/icmPushfold.ts` | Generated ICM bubble push/fold tables ($EV) |
| `src/lib/icm.ts` | Malmuth-Harville ICM |
| `scripts/preflop_gen.ts` | Range-string source of the preflop charts + expander |
| `scripts/pushfold_gen.ts` | Fictitious-play Nash solver |
| `scripts/icm_pushfold_gen.ts` | Fictitious-play ICM solver |
| `scripts/golden/equity_matrix.json` | Pinned 169x169 preflop equity matrix the two solvers consume |
| `scripts/golden/charts.json` | Golden snapshot of the Chen-ranked hand order, top-% slices and bot ranges |
| `scripts/puzzles_test.ts`, `preflop_test.ts`, `pushfold_test.ts`, `icm_test.ts` | Tests (all pass today: 9348 / 52 / 111 / 23 assertions) |
| `src/components/drills/*.tsx`, `src/views/DrillsView.tsx` | UI text quoted in section 9 |

The Rust twin (`poker-core/`) contains ONLY the evaluator/equity engine and the
`equity_matrix` example. There is no Rust version of puzzles, charts, Nash, or
ICM; everything in this document is TypeScript-only and must be ported from here.

Everything the user reads is written to `TONE.md` (plain English first, chances
as counts, judge the decision not the person, honesty about close calls). Quote
the strings in this doc verbatim; do not "improve" them.

---

## 0. Shared primitives this subsystem depends on

These live in other subsystems (cards/notation/ranges/equity) but the drills
depend on their exact behaviour. Summarised here so the port can be checked.

### 0.1 Cards and labels

* `Card` = 2-char string, rank then suit: ranks `2 3 4 5 6 7 8 9 T J Q K A`,
  suits `c d h s`. Example `"Ah"`, `"Td"`.
* `RANKS` (ascending) = `2..A`; `SUITS` = `[c, d, h, s]`; `RANKS_DESC` = `A..2`.
* `cardToInt(card) = rankIndex*4 + suitIndex` with rankIndex 0 for `2` .. 12 for `A`.
* `makeDeck()` = for r in RANKS, for s in SUITS push r+s (52 cards, `2c,2d,2h,2s,3c,...,As`).
* `shuffle(arr)` = in-place Fisher-Yates using `Math.random()`:
  `for i = n-1 down to 1: j = floor(random*(i+1)); swap(arr[i], arr[j])`.
* `HandLabel` = 13x13 grid label: pair `"AA"`, suited `"AKs"`, offsuit `"AKo"`.
  High rank first. 169 labels total.
* `cardsToLabel(a, b)`: hi = the card whose rank has the smaller index in
  RANKS_DESC; if ranks equal -> `hi+hi`; else `hi+lo+("s" if same suit else "o")`.
* `kindOf(label)`: length 2 -> pair; ends with `s` -> suited; else offsuit.
* `comboCount(label)`: pair 6, suited 4, offsuit 12. `TOTAL_COMBOS = 1326`.
* `labelToCombos(label)` -> concrete `[Card, Card][]` in THIS order (order matters
  for `strengthSlice`, which uses the first non-blocked combo):
  * pair: for i in 0..3, for j in i+1..3: `[hi+SUITS[i], hi+SUITS[j]]`
    (cd, ch, cs, dh, ds, hs)
  * suited: for s in SUITS: `[hi+s, lo+s]` (c, d, h, s)
  * offsuit: for s1 in SUITS, for s2 in SUITS, s1 != s2: `[hi+s1, lo+s2]`
* `allLabels()` = row-major grid order: row r, col c over RANKS_DESC;
  `labelAt(r,c)`: hi = RANKS_DESC[min(r,c)], lo = RANKS_DESC[max(r,c)];
  r==c pair; c>r suited; r>c offsuit.

### 0.2 Chen ranking and `topPercentRange` (used by every postflop drill)

`chenScore(label)`:

```
rankValue(r) = 2..14 (2=2, T=10, J=11, Q=12, K=13, A=14)
highCardScore(v): A->10, K->8, Q->7, J->6, else v/2
pair: max(5, highCardScore(hi)*2)
non-pair: score = highCardScore(hi); if suited score += 2
  gap = hi - lo - 1
  gap==1: -1; gap==2: -2; gap==3: -4; gap>=4: -5
  if gap <= 1 and hi < 12 (below Queen): +1
```

`rankedHands()` = all 169 labels sorted by score desc; ties broken by kind
(pair < suited < offsuit, i.e. pairs first) then by higher first rank.
The resulting order is pinned in `scripts/golden/charts.json.ranked` and is
reproduced verbatim here (strongest first, 169 entries):

```
AA KK QQ JJ AKs AQs TT AJs KQs AKo 99 KJs QJs JTs AQo 88 ATs KTs QTs J9s T9s AJo KQo 98s 77
A9s A8s A7s A6s A5s A4s A3s A2s Q9s T8s 87s KJo QJo JTo 97s 76s 66 K9s J8s 86s 65s ATo KTo
QTo J9o T9o 75s 54s 98o 55 44 33 22 K8s K7s K6s K5s K4s K3s K2s Q8s T7s 64s 43s A9o A8o A7o
A6o A5o A4o A3o A2o Q9o T8o 87o 96s 53s 32s 97o 76o Q7s Q6s Q5s Q4s Q3s Q2s J7s 85s 42s K9o
J8o 86o 65o 74s 75o 54o J6s J5s J4s J3s J2s T6s 63s K8o K7o K6o K5o K4o K3o K2o Q8o T7o 64o
43o 95s 52s 96o 53o 32o T5s T4s T3s T2s 84s Q7o Q6o Q5o Q4o Q3o Q2o J7o 85o 42o 94s 93s 92s
73s 74o 83s 82s 62s J6o J5o J4o J3o J2o T6o 63o 72s 95o 52o T5o T4o T3o T2o 84o 94o 93o 92o
73o 83o 82o 62o 72o
```

`topPercentRange(pct)`: `target = clamp(pct,0,100)/100 * 1326`; walk
`rankedHands()` in order, adding labels while `acc < target`
(check BEFORE adding; then `acc += comboCount`). Returns a Set of labels.
Slices the drills use (label counts): 4% -> 10 labels (`AA..AKo`), 11% -> 25,
28% -> 61, 32% -> 71, 38% -> 78, 45% -> 91, 60% -> 115, 100% -> 169.
Full contents of each are the prefix of the ranked list above of that length.

`chartWidth(chart)` = `sum(freq * comboCount(label)) / 1326` over the chart's
entries (fraction 0..1). `pctOf(chart) = round(chartWidth*100)`.

`chartLabels05(chart)` (alias `nashLabels`) = labels whose frequency `>= 0.5`,
in the chart's insertion order.

### 0.3 RNG, seeds, equity

* `rint(a,b) = a + floor(Math.random() * (b-a+1))` (inclusive ints).
* `r1(x) = Math.round(x*10)/10` (one decimal; JS `Math.round` = half toward +inf).
* `hashSeed(s)`: FNV-1a 32-bit: `h = 0x811c9dc5; for each UTF-16 code unit c: h ^= c; h = imul(h, 0x01000193)`; return `h >>> 0`.
* `mulberry32(seed)`: `a = seed>>>0; next(): a = (a + 0x6d2b79f5)>>>0; t = a; t = imul(t ^ (t>>>15), t|1); t ^= t + imul(t ^ (t>>>7), t|61); return ((t ^ (t>>>14))>>>0) / 4294967296`.
  All ops are 32-bit unsigned (mask with `& 0xFFFFFFFF` in Dart; `imul` is 32-bit
  wrapping multiply of the low 32 bits).
* `comboToInts([a,b]) = [cardToInt(a), cardToInt(b)]`.
* `EquityResult { equity, win, tie, lose, samples, se, exact }`; `equity = (win + tie/2)/samples`
  (0.5 when samples==0); `se = sqrt(max(equity*(1-equity), 1e-9)/samples)` for
  sampled results, `0` for exact.
* `equityVsRange(hero: [int,int], board: int[], range: [int,int][], iters=1500, seed?)`:
  1. `used = {hero, board}`; `valid = range minus combos touching used`.
  2. `valid` empty -> `{equity 0.5, samples 0, se 0, exact false}`.
  3. `board.length >= 4` -> EXACT: for each villain combo, for each remaining card
     (turn) or none (river), compare 7-card evaluator scores; count win/tie/lose.
     (Iteration order: villain combos in given order; runout card ints 0..51 ascending,
     skipping used and villain cards.)
  4. else Monte Carlo with `rand = mulberry32(seed)` (or `Math.random` if no seed):
     `baseAvail` = ints 0..51 not in used (ascending). Per iteration:
     `villain = valid[(rand()*valid.length)|0]`; `work = copy(baseAvail)`;
     `len = work.length`; for each villain card found at `idx` in work:
     `len--; swap(work[idx], work[len])`; then draw `need = 5 - board.length`
     cards: for k in 0..need-1: `j = (rand()*(len-k))|0; last = len-1-k;
     pick = work[j]; work[j] = work[last]; work[last] = pick; draw.push(pick)`.
     Compare `evaluate(hero+board+draw)` vs `evaluate(villain+board+draw)`.
* `equityVsRandom(hero, board, iters=1200, seed?)`: river (5 board cards) -> exact
  enumeration over all C(unused,2) combos ascending; otherwise MC:
  `avail` ascending unused; per iteration `work = copy(avail); len = work.length;
  drawDistinct(2)` for villain then `drawDistinct(need)` for runout, each draw
  `j = (rand()*len)|0; len--; swap(work[j], work[len]); out.push(work[len])`.

Bit-identical equity numbers are only needed if you want to reproduce the exact
grades of the TS app for a given deal; the grading logic itself is robust to a
different (but honest) estimator because of the `band` (section 4.3).

---

## 1. Data model (Dart-like)

```dart
enum DrillAction { fold, check, call, bet, raise }   // serialised as lowercase strings

enum PuzzleKind {
  rfi, vsRaise /* "vs-raise" */, postflopBet /* "postflop-bet" */,
  postflopCheck /* "postflop-check" */, threebetPot /* "threebet-pot" */,
  checkRaise /* "check-raise" */, riverDecision /* "river-decision" */,
  pushfold, exploit, leak
}
// String forms are load-bearing: review-card ids embed them (section 7.4).

class DrillOption {
  DrillAction action;
  String label;          // button text, e.g. "Open 2.5", "3-bet 7.5", "Shove 10 bb"
  double? amount;        // total bet/raise size in bb for bet/raise/call; absent for fold/check
}

class DrillSeatView {
  Position pos;          // UTG MP CO BTN SB BB
  bool isHero;
  bool folded;
  bool active;           // still in the hand and not hero (computed; the table UI does NOT read it)
}

class DrillFrame {       // one step of the "Hand replay" navigator
  String text;
  Street street;         // preflop flop turn river
  List<Card> board;      // cards visible at this step (copy)
  double pot;            // pot shown at this step (bb)
}

class Puzzle {
  int id;                        // module-global counter SEQ, starts at 1, increments per puzzle built
  PuzzleKind kind;
  String source;                 // "chart" | "heuristic"
  Street street;
  Position heroPos;
  List<Card> hole;               // exactly 2
  HandLabel handLabel;
  List<Card> board;              // 0/3/4/5 cards
  double pot;                    // pot hero faces INCLUDING the bet to call
  double toCall;                 // 0 when hero is not facing a bet
  double bb;                     // always 1 for generated puzzles; leak spots carry the table's bb
  List<DrillSeatView> seats;     // always 6, in ORDER = [UTG, MP, CO, BTN, SB, BB]
  List<DrillFrame> frames;       // >= 2; last frame is the decision point
  List<DrillOption> options;     // 2 or 3
  DrillAction best;
  List<DrillAction> accept;      // always contains best
  String rationale;
  double? equity;                // hero equity vs the graded range (postflop + exploit spots)
  double? potOdds;               // break-even fraction toCall/(pot+toCall)
  int difficulty;                // 1..3
  List<HandLabel>? gradeRange;   // the range shown in the 13x13 "graded against" matrix
  String? gradeRangeTitle;
  String? lessonId;              // Study lesson deep link
  String? lessonTitle;
  bool? icm;                     // true for ICM bubble push/fold spots (explicitly false on exploit spots)
}

class LeakSpot {                 // produced by the play-mode coach and by hand-history import
  String id;
  Street street;
  Position heroPos;
  List<Card> hole;
  List<Card> board;
  double pot;                    // in CHIPS for coach leaks (bb = table big blind); in bb for imports (bb = 1)
  double toCall;
  double bb;
  List<Position> oppActive;
  List<DrillOption> options;
  DrillAction best;
  String rationale;
  double? equity;
  double? potOdds;
  int ts;                        // ms epoch
  SrsState? srs;                 // { due:int ms, intervalDays:double, ease:double, reps:int, lapses:int }
}

class GradeResult {
  bool correct;
  DrillAction best;
  List<DrillAction> accept;
  String rationale;
  double? evLossBb;              // only for pot-odds spots when the answer was wrong
}
```

Invariants (asserted by `puzzles_test.ts` over 800 mixed + 400 push/fold puzzles):
`hole[0] != hole[1]`; `board.length` = 0 / 3 / 4 / 5 for preflop / flop / turn / river;
`pot > 0 && toCall >= 0`; `frames.length >= 2`; `options.length >= 2`;
`accept` non-empty and contains `best`; `best` is one of the offered options;
`gradePuzzle(p, p.best).correct == true`; any offered option not in `accept` grades wrong;
`postflop-bet` puzzles have both `equity` and `potOdds`; push/fold puzzles are preflop,
no board, exactly 2 options; the seven cash kinds all appear within 800 draws.

---

## 2. Constants

```
ORDER      = [UTG, MP, CO, BTN, SB, BB]      // seat order, index 0..5
SB         = 0.5                              // small blind in bb
BBV        = 1                                // big blind in bb
STREET_RANGE_PCT = { flop: 45, turn: 38, river: 32 }   // villain "continuing range" top-% by street
PF_STACKS  = [5,6,7,8,9,10,11,12,13,14,15]    // stacks the push/fold DRILL draws from (tables cover 2..25)
SEQ        = 1                                // puzzle id counter (module global)
```

`fullSeats(heroPos, foldedPos, activePos)` -> for each pos in ORDER:
`{pos, isHero: pos==heroPos, folded: foldedPos.contains(pos), active: activePos.contains(pos) && pos != heroPos}`.

`rangeToCombos(labels, blocked: Set<Card>)` -> for each label, for each combo from
`labelToCombos`, skip if either card is in `blocked`, else push `comboToInts(combo)`.

`capital(s)` = first char upper-cased + rest.

Number-to-text: every `${x}` interpolation uses JavaScript number formatting:
integral doubles print WITHOUT a decimal point (`3` not `3.0`), otherwise the
shortest round-trip form (`2.5`, `7.5`, `0.5`). Implement a `jsNum(double)`
helper in Dart and use it in every template below.
