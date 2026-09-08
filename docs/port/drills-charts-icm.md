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

---

## 3. Spot generators (`src/engine/puzzles.ts`)

Every generator: `deck = shuffle(makeDeck()); hole = [deck[0], deck[1]]; label = cardsToLabel(hole[0], hole[1])`.
Postflop boards: `postflopBoard(deck, street)` = `deck.slice(2, 2+n)` with n = 3 / 4 / 5 for flop / turn / river.
All puzzles have `bb = 1`. `id = SEQ++`.

### 3.1 `genRfi()` — raise-first-in (kind `rfi`, source `chart`)

```
heroIdx = rint(0, 4)                       // UTG, MP, CO, BTN or SB (never BB)
heroPos = ORDER[heroIdx]
foldedBefore = ORDER[0..heroIdx) minus SB/BB      // the non-blind seats before hero
toCall = heroPos == SB ? 0.5 : 1
pot = 1.5
seats = fullSeats(heroPos, foldedBefore, [SB, BB] minus heroPos)
frames:
  "Blinds posted (0.5/1 bb)."                      preflop, [], pot 1.5
  for p in foldedBefore: "{p} folds."              preflop, [], pot 1.5
  "Folded to you in the {heroPos}. Action on you." preflop, [], pot 1.5
chart = PREFLOP_100.rfi[heroPos]  (empty map if missing)
freq  = chart[label] ?? 0
mixed = freq > 0.2 && freq < 0.8
best  = freq >= 0.5 ? raise : fold
accept = mixed ? [fold, raise] : [best]
openTo = 2.5
options: fold "Fold"; call "Limp {toCall}" amount toCall; raise "Open 2.5" amount 2.5
difficulty = mixed ? 3 : 1
gradeRange = chartLabels05(chart); gradeRangeTitle = "{heroPos} opening range (~{pctOf(chart)}%)"
lessonId "opening-ranges", lessonTitle "Opening Ranges by Position"
```
Rationale (verbatim; `{pct}` = `pctOf(chart)`, `{f}` = `round(freq*100)`):
* mixed: `{heroPos} opens about {pct}% of hands here, and {label} is a true mixed hand — the chart opens it {f}% of the time, so raising and folding are both fine (just calling the minimum — limping — still isn't).`
* freq >= 0.5: `{heroPos} opens about {pct}% of hands. {label} is in that range, so the chart play is to raise (just calling the minimum — "limping" — isn't part of a solid opening strategy).`
* else: `{heroPos} opens about {pct}% of hands. {label} isn't in that range, so fold — just calling the minimum (limping) here loses money over time.`

`pctOf` per position with the shipped charts: UTG 15, MP 19, CO 26, BTN 45, SB 41.
Note "Limp" is never accepted; it is offered so the player can get it wrong.

### 3.2 `genVsRaise()` — facing an open (kind `vs-raise`, source `chart`)

```
heroIdx  = rint(2, 5)                       // CO, BTN, SB, BB
heroPos  = ORDER[heroIdx]
raiserIdx = rint(0, heroIdx-1); raiserPos = ORDER[raiserIdx]
raiseTo  = (heroPos is BB or SB) ? 3 : 2.5  // depends on HERO seat (quirk; keep)
heroBlind = SB->0.5, BB->1, else 0
toCall   = r1(raiseTo - heroBlind)
pot      = r1(1.5 + raiseTo)
foldedBefore = ORDER[0..heroIdx) minus raiserPos minus SB/BB
seats = fullSeats(heroPos, foldedBefore, [raiserPos])
frames:
  "Blinds posted (0.5/1 bb)."                              pot 1.5
  for fp in ORDER[0..raiserIdx) minus SB/BB: "{fp} folds." pot 1.5
  "{raiserPos} raises to {raiseTo} bb."                    pot r1(1.5+raiseTo)
  for fp in ORDER(raiserIdx+1..heroIdx) minus SB/BB: "{fp} folds."   pot same
  "Action on you in the {heroPos}, facing a raise."        pot same
charts = PREFLOP_100.vsRfi["{heroPos}_vs_{raiserPos}"] ?? {threebet:{}, call:{}}
f3 = charts.threebet[label] ?? 0; fc = charts.call[label] ?? 0; ff = max(0, 1 - f3 - fc)
freqs = [(raise,f3),(call,fc),(fold,ff)] sorted by freq DESC (stable: raise before call before fold on ties)
best   = freqs[0].action
accept = actions with freq >= 0.25 (in sorted order); if best not included, prepend it
mixed  = accept.length > 1
threeBetTo = r1(raiseTo * ((heroPos is BB or SB) ? 3.5 : 3))    // 7.5 in position, 10.5 from the blinds
options: fold "Fold"; call "Call {toCall}" amount toCall; raise "3-bet {threeBetTo}" amount threeBetTo
difficulty = mixed ? 3 : 2
gradeRange = unique(chartLabels05(threebet) ++ chartLabels05(call))
gradeRangeTitle = "{heroPos} continue range vs a {raiserPos} open"
lessonId "three-betting", lessonTitle "3-Betting"
```
`actName(a)` = `"3-bet"` for raise, else the action word (`call`, `fold`).
Rationale:
* mixed: `Facing a {raiserPos} open from the {heroPos}, {label} is a genuine mix: the chart {parts} of the time. Any of those is fine.`
  where `{parts}` = for each (action, f) with f >= 0.25 in sorted order: `"{actName}s {round(f*100)}%"` joined by `" / "`
  (e.g. `3-bets 50% / calls 50%`, `calls 75% / 3-bets 25%`, `folds 50% / calls 50%`).
* best == raise: `Facing a {raiserPos} open, {label} is in the {heroPos} 3-bet range (~{pctOf(threebet)}% of hands) — re-raise for value/pressure.`
* best == call: `Facing a {raiserPos} open, {label} is too weak to 3-bet but inside the {heroPos} calling range (~{pctOf(call)}%), so call and see a flop.`
* best == fold: `{label} is outside the {heroPos} continuing range vs a {raiserPos} open (~{pctOf(threebet) + pctOf(call)}% continues) — fold.`

The 14 hero/raiser pairs this generator can produce all exist in the chart set
(`MP_vs_UTG` exists too but is only used by the bots).

### 3.3 `genPostflopBet()` — facing a bet, single-raised pot (kind `postflop-bet`, source `heuristic`)

```
street = one of [flop, turn, river] uniformly (rint(0,2))
board  = postflopBoard(deck, street)
heroPos = random() < 0.5 ? BB : BTN;  villainPos = heroPos == BB ? CO : BB
potBeforeBet = r1(5 + rint(0, 8))            // 5..13
betFrac = [0.5, 0.66, 1][rint(0,2)]
bet = r1(potBeforeBet * betFrac); pot = r1(potBeforeBet + bet); toCall = bet
blocked = {hole, board}
villRange = topPercentRange(STREET_RANGE_PCT[street])       // 45 / 38 / 32 %
combos = rangeToCombos(villRange, blocked)
r = combos.isEmpty ? null : equityVsRange(comboToInts(hole), board ints, combos, 3000, hashSeed("{hole[0]}{hole[1]}|{board joined with no separator}"))
eq = r?.equity ?? 0.5
breakEven = toCall / (pot + toCall)
band = max(0.02, 2 * (r?.se ?? 0))
if eq >= breakEven + band:        best = call; accept = eq > 0.72 ? [call, raise] : [call]
elif eq <= breakEven - band:      best = fold; accept = [fold]
else (closeCall):                 best = eq >= breakEven ? call : fold; accept = [fold, call]
seats = fullSeats(heroPos, ORDER minus hero minus villain, [villainPos])
frames:
  "Pre-flop: {villainPos} raised, you called from the {heroPos}. Heads-up."   preflop, [], potBeforeBet
  "{Capital(street)}: {board.join(" ")}"                                        street, board, potBeforeBet
  "{villainPos} bets {bet} bb."                                                 street, board, pot
  "Action on you."                                                              street, board, pot
options: fold "Fold"; call "Call {toCall}" amount toCall; raise "Raise {r1(pot + bet)}" amount r1(pot+bet)
equity = eq; potOdds = breakEven
difficulty = (eq > breakEven - 0.06 && eq < breakEven + 0.06) ? 3 : 2
gradeRange = [...villRange]; gradeRangeTitle = "{villainPos}'s assumed {street} continuing range"
lessonId "pot-odds", lessonTitle "Pot Odds, Break-even & EV"
```
Rationale (`{E}` = round(eq*100), `{B}` = round(breakEven*100)):
* closeCall: `Razor-thin: ~{E}% equity against a plausible {street} continuing range vs {B}% pot odds. That's inside the margin where folding and calling are both fine — {"calling"|"folding"} is marginally better.` (word chosen by `best`)
* else: `You have ~{E}% equity against a plausible {street} continuing range, and your call needs to win {B}% to break even (your pot odds). ` followed by
  * best call and eq > 0.72: `That's a clear call — and strong enough to raise for value.`
  * best call otherwise: `Equity beats the price, so call.`
  * best fold: `Equity is below the price, so fold.`

Board strings are cards joined by a single space (`"As 7c 2d"`); the seed string joins them with NO separator.

### 3.4 `genPostflopCheck()` — checked to hero in position (kind `postflop-check`, source `heuristic`)

```
street = [flop, turn][rint(0,1)]; board = postflopBoard(deck, street)
heroPos = BTN; villainPos = BB
pot = r1(5 + rint(0, 6))                    // 5..11
combos = rangeToCombos(topPercentRange(STREET_RANGE_PCT[street]), {hole, board})
r = combos.isEmpty ? null : equityVsRange(hero, board, combos, 3000, hashSeed("{hole joined}|{board joined}"))
eq = r?.equity ?? 0.5; band = max(0.02, 2*(r?.se ?? 0))
if eq > 0.6 + band:        best = bet;   accept = [bet]
elif eq > 0.5 - band:      best = eq > 0.5 ? bet : check; accept = [bet, check]
else:                      best = check; accept = [check]
betTo = r1(pot * 0.66)
frames:
  "Pre-flop: you raised from the {heroPos}, {villainPos} called. Heads-up."  preflop, [], pot
  "{Capital(street)}: {board}"                                                street, board, pot
  "{villainPos} checks. Action on you."                                       street, board, pot
options: check "Check"; bet "Bet {betTo}" amount betTo
toCall = 0; equity = eq; potOdds absent; difficulty = 2
gradeRange = topPercentRange(pct) as list; gradeRangeTitle = "{villainPos}'s assumed {street} range"
lessonId "bet-sizing", lessonTitle "Bet Sizing"
```
Rationale: `With ~{E}% equity vs {villainPos}'s range, ` +
* accept has 2 entries: `betting and checking are both fine — it's a marginal value/pot-control spot.`
* best bet: `you're ahead often enough to bet for value.`
* best check: `you don't have enough to value bet; check and keep the pot small.`

### 3.5 `strengthSlice(labels, board, topFrac, bluffTail)` — helper for late-street families

Ranks a label set by a cheap seeded strength estimate on the given board and keeps the
strongest fraction, optionally adding a weak "bluff tail".

```
boardInts = board ints; blocked = Set(board)
ranked = for each label l in order:
    combos = labelToCombos(l) minus combos touching blocked
    if none -> skip label
    c = comboToInts(combos[0])                       // FIRST unblocked combo
    eq = equityVsRandom(c, boardInts, 80, hashSeed("{l}|{board joined}")).equity
    -> {l, eq}
  sorted by eq DESC (stable)
top = first max(4, round(ranked.length * topFrac)) labels
if !bluffTail return top
tail = ranked[round(ranked.length * 0.85) .. end]
return top ++ tail
```

### 3.6 `genThreeBetPot()` — calling a c-bet in a 3-bet pot (kind `threebet-pot`, source `heuristic`)

```
street = random() < 0.7 ? flop : turn; board = postflopBoard(deck, street)
heroPos = random() < 0.5 ? CO : BTN; villainPos = random() < 0.5 ? SB : BB
key = "{villainPos}_vs_{heroPos}"       // villain's 3-bet range vs hero's open
tbChart = PREFLOP_100.vsRfi[key]?.threebet ?? PREFLOP_100.vsRfi.BB_vs_BTN.threebet
villLabels = chartLabels05(tbChart)
pot = 20
bet = r1(pot * [0.4, 0.66][rint(0,1)])        // 8 or 13.2
totalPot = r1(pot + bet)
combos = rangeToCombos(villLabels, {hole, board})
r = combos.isEmpty ? null : equityVsRange(hero, board, combos, 3000, hashSeed("3bp|{hole joined}|{board joined}"))
eq = r?.equity ?? 0.5; breakEven = bet / (totalPot + bet); band = max(0.02, 2*(r?.se ?? 0))
if eq >= breakEven + band:   best = call; accept = eq > 0.62 ? [call, raise] : [call]
elif eq <= breakEven - band: best = fold; accept = [fold]
else closeCall:              best = eq >= breakEven ? call : fold; accept = [fold, call]
frames:
  "You open {heroPos} to 2.5 bb; {villainPos} 3-bets to 9 bb; you call. Heads-up."           preflop, [], 20
  "{Capital(street)}: {board} (pot 20 bb — stacks are only ~4.5 pots deep: a low SPR)."       street, board, 20
  "{villainPos} c-bets {bet} bb. Action on you."                                              street, board, totalPot
options: fold "Fold"; call "Call {bet}" amount bet; raise "Raise {r1(totalPot + bet)}" amount r1(totalPot+bet)
pot = totalPot; toCall = bet; equity = eq; potOdds = breakEven
difficulty = |eq - breakEven| < 0.06 ? 3 : 2
gradeRange = villLabels; gradeRangeTitle = "{villainPos}'s 3-bet range vs {heroPos}"
lessonId "threebet-pots", lessonTitle "Playing 3-Bet Pots"
seats = fullSeats(heroPos, ORDER minus hero minus villain, [villainPos])
```
Rationale:
* closeCall: `Razor-thin in a 3-bet pot: ~{E}% equity vs a 3-betting range, {B}% needed — both answers are fine. Remember the low SPR: whatever continues here is often committed.`
* else: `In a 3-bet pot your opponent's range is strong (big pairs, big cards) — your {label} has ~{E}% equity against it, and you need {B}%. ` +
  * best call: `That's enough — and with stacks this shallow (SPR ~4), plan for the rest going in on many turn and river cards.`
  * best fold: `Not enough against this range at this price — fold and keep the 9 bb loss small.`

### 3.7 `genFacingCheckRaise()` — hero c-bet, BB check-raised (kind `check-raise`, source `heuristic`)

```
board = flop (3 cards); heroPos = BTN; villainPos = BB
defend = chartLabels05( {...BB_vs_BTN.call, ...BB_vs_BTN.threebet} )
   // map spread: a label in BOTH charts takes the THREEBET frequency. With the shipped
   // charts this EXCLUDES QTs, JTs, 87s, 76s (call .75 / 3bet .25) and INCLUDES A2s-A5s (.75),
   // K9s (.5), KQo (.5). Replicate exactly.
villLabels = strengthSlice(defend, board, 0.3, true)     // top 30% by strength + bottom 15% tail
potPre = 5.5; cbet = 2.5; raiseTo = 8; toCall = 5.5
pot = r1(potPre + cbet + raiseTo) = 16
combos = rangeToCombos(villLabels, {hole, board})
r = combos.isEmpty ? null : equityVsRange(hero, board, combos, 3000, hashSeed("xr|{hole joined}|{board joined}"))
eq = r?.equity ?? 0.5; breakEven = toCall/(pot+toCall) = 5.5/21.5 ≈ 0.2558; band = max(0.02, 2*se)
if eq >= breakEven + band:   best = call; accept = eq > 0.68 ? [call, raise] : [call]
elif eq <= breakEven - band: best = fold; accept = [fold]
else:                        best = eq >= breakEven ? call : fold; accept = [fold, call]
frames:
  "You open the BTN to 2.5 bb, BB calls. Heads-up."                        preflop, [], 5.5
  "Flop: {board}. BB checks, you c-bet 2.5 bb."                            flop, board, 8
  "BB check-raises to 8 bb. Action on you."                                flop, board, 16
options: fold "Fold"; call "Call 5.5" amount 5.5; raise "3-bet 20.8" amount r1(8*2.6)=20.8
equity = eq; potOdds = breakEven; difficulty = |eq - breakEven| < 0.06 ? 3 : 2
gradeRange = villLabels; gradeRangeTitle = "BB's check-raising range (strong hands + draws)"
lessonId "check-raising", lessonTitle "Check-Raising"
```
Rationale: `A check-raise represents the strong part of {villainPos}'s defend range plus some draws. Your {label} has ~{E}% equity against that, needing {B}%. ` +
* best call: `Continue — folding here would let check-raises print money against your c-bets.`
* best fold: `Let this one go — c-betting means sometimes folding to check-raises; that's fine when the hand has this little.`
* (unreachable `Continue.` fallback)

Note the option labels for this spot do not carry a " bb" suffix; template strings above are exact.

### 3.8 `genRiverDecision()` — river as the aggressor (kind `river-decision`, source `heuristic`)

```
board = river (5 cards); heroPos = BTN; villainPos = BB
defend = chartLabels05(BB_vs_BTN.call)                    // call freq >= 0.5
once   = strengthSlice(defend, board[0..3), 0.65, false)  // called the flop
villLabels = strengthSlice(once, board[0..4), 0.65, false) // called the turn too
pot = 14; betTo = r1(14 * 0.66) = 9.2
combos = rangeToCombos(villLabels, {hole, board})
r = combos.isEmpty ? null : equityVsRange(hero, board, combos, 10, hashSeed("rv|{hole joined}|{board joined}"))   // river => exact, iters ignored
eq = r?.equity ?? 0.5; band = max(0.02, 2*se) (= 0.02, exact)
if eq > 0.6 + band:      best = bet; accept = [bet]
elif eq > 0.48 - band:   best = eq > 0.54 ? bet : check; accept = [bet, check]
else:                    best = check; accept = [check]
frames:
  "You open the BTN, BB calls. You bet the flop and turn; BB called both."   preflop, [], 5.5
  "River: {board} (pot 14 bb)."                                              river, board, 14
  "BB checks. Value bet or check back?"                                      river, board, 14
options: check "Check back"; bet "Bet 9.2" amount 9.2
toCall = 0; equity = eq; difficulty = |eq - 0.55| < 0.08 ? 3 : 2
gradeRange = villLabels; gradeRangeTitle = "BB's range after calling flop + turn"
lessonId "turn-river", lessonTitle "Turn & River Play"
```
Rationale:
* two accepted: `Against the hands that called twice, your {label} wins ~{E}% — right on the value/showdown border, so betting thin and checking back are both fine.`
* best bet: `The hands that called flop and turn still pay off a river bet often enough: ~{E}% equity against that range. Name the worse hands that call — here there are plenty — and bet.`
* best check: `Against the range that called two streets, your {label} only wins ~{E}% — worse hands rarely call a third bet. Take the showdown; betting would mostly get called when you're beaten.`

### 3.9 `generatePuzzle()` — the Mixed-mode roll

```
roll = random()
< 0.22 rfi | < 0.42 vs-raise | < 0.62 postflop-bet | < 0.72 postflop-check
| < 0.84 threebet-pot | < 0.92 check-raise | else river-decision
```
(weights 22 / 20 / 20 / 10 / 12 / 8 / 8 %).

### 3.10 `generateExploit()` — best deviation vs a KNOWN archetype (kind `exploit`)

`template = rint(0, 2)`.

**Template 0 — thin value vs a Calling Station (river, hero BTN vs BB).**
```
repeat (max 80 tries, re-dealing a fresh shuffled deck each time):
  hole = d[0..2), board = d[2..7)
  stationRange  = rangeToCombos(topPercentRange(60), {hole, board})
  balancedRange = rangeToCombos(topPercentRange(28), {hole, board})
  eqStation  = equityVsRange(hero, board, stationRange, 10, hashSeed("ex0|{hole}|{board}")).equity   (0.5 if empty)
  eqBalanced = equityVsRange(hero, board, balancedRange, 10, hashSeed("ex0b|{hole}|{board}")).equity  (0.5 if empty)
until 0.56 <= eqStation <= 0.75      // "modest but ahead"; last deal is used after 80 tries regardless
pot = 9; betTo = r1(9*0.6) = 5.4
gain = r1((eqStation - 0.5) * betTo * 2 * 10) / 10       // i.e. round((eqStation-0.5)*1080)/100 → a two-decimal bb figure (e.g. 0.65 -> 1.62)
source heuristic, street river, heroPos BTN, seats = fullSeats(BTN, all but BTN/BB folded, [BB])
frames:
  "The BB is a CALLING STATION (calls ~60% of hands to the river). You bet flop and turn; they called both."   preflop, [], 5
  "River: {board} (pot 9 bb). The Station checks."                                                           river, board, 9
  "Your hand wins ~{round(eqStation*100)}% against THEIR calling range. Action on you."                      river, board, 9
options: check "Check back"; bet "Bet 5.4" amount 5.4
best bet; accept [bet]; equity = eqStation; toCall 0; difficulty 2; icm false
gradeRange = topPercentRange(60); gradeRangeTitle "What a Station calls a river bet with (~60%)"
lessonId "exploits", lessonTitle "Exploiting the Archetypes"
```
Rationale: `THE EXPLOIT: vs a balanced player your {label} ({round(eqBalanced*100)}% vs a sane calling range) is a check — worse hands rarely pay a third bet. But a Station calls with almost anything, so the same hand wins ~{round(eqStation*100)}% against what they'll CALL with. Bet thin, every time — that's roughly +{gain} bb the balanced line leaves behind. Vs Stations: value bet more, never bluff.`

**Template 1 — respect the Nit's raise (turn, hero CO vs BB).**
```
repeat (max 80 tries): hole = d[0..2), board = d[2..6) (4 cards)
  nitRaise      = rangeToCombos(topPercentRange(4), blocked)
  balancedRaise = rangeToCombos(topPercentRange(11), blocked)
  eqNit      = equityVsRange(hero, board, nitRaise, 10, hashSeed("ex1|{hole}|{board}")).equity   (turn => exact)
  eqBalanced = equityVsRange(hero, board, balancedRaise, 10, hashSeed("ex1b|{hole}|{board}")).equity
until eqNit <= 0.38 && eqBalanced >= 0.42
pot = 16; toCall = 10; breakEven = 10/26 ≈ 0.3846
puzzle.pot = r1(pot + toCall) = 26; street turn; heroPos CO; seats = fullSeats(CO, all but CO/BB folded, [BB])
frames:
  "The BB is a NIT (raises only with hands close to the best possible). You bet the turn with a decent hand."   preflop, [], 16
  "Turn: {board}. The Nit RAISES to 16 bb."                                                                    turn, board, 26
  "Action on you — it costs 10 bb more."                                                                       turn, board, 26
options: fold "Fold"; call "Call 10" amount 10
best fold; accept [fold]; equity = eqNit; potOdds = breakEven; difficulty 2; icm false
gradeRange = topPercentRange(4); gradeRangeTitle "What a Nit raises the turn with (~4%)"
```
Rationale: `THE EXPLOIT: vs a balanced raiser your {label} has ~{round(eqBalanced*100)}% equity — enough for the {round(breakEven*100)}% price, so balanced play calls. But a Nit's raise means close to the best possible hand: against THAT range you have ~{round(eqNit*100)}%. Folding "too much" here isn't a leak — it's the profit. When a Nit wakes up, believe them.`

**Template 2 — steal any two from a Nit's blind (preflop, hero SB vs BB).**
```
hole = deck[0..2); baseline = PREFLOP_100.rfi.SB[label] ?? 0
source chart; street preflop; heroPos SB; pot 1.5; toCall 0.5
seats = fullSeats(SB, [UTG, MP, CO, BTN], [BB])
frames:
  "The BB is a NIT — they defend their blind with only ~12% of hands and fold the rest."   preflop, [], 1.5
  "Folded to you in the SB with {label}. Action on you."                                   preflop, [], 1.5
options: fold "Fold"; raise "Raise 3 bb" amount 3
best raise; accept [raise] (both branches of the ternary yield [raise]); difficulty 1; icm false
gradeRange = all 169 labels; gradeRangeTitle "The exploit raise-range vs a Nit's blind: any two"
```
Rationale: `THE EXPLOIT: the balanced SB chart {X} — but this Nit folds their blind ~88% of the time. Raising ANY TWO wins 1.5 bb immediately at a cost of 3, needing only ~67% folds to profit before the flop is even dealt. Against blind-folders, attack relentlessly with everything.`
where `{X}` = `already raises {label}` if baseline >= 0.5 else `folds {label} (it opens ~41% of hands)`.

### 3.11 `gradeFromFreq(freq, label, stack, aggressive, aggroWord, context)` — push/fold grader

```
best   = freq >= 0.5 ? aggressive : fold
mixed  = freq > 0.2 && freq < 0.8
accept = mixed ? [fold, aggressive] : [best]
rationale:
  freq >= 0.98: "{context} {label} is clearly inside the equilibrium {aggroWord} range at {stack} bb — {aggroWord}."
  freq <= 0.02: "{context} {label} is outside the equilibrium {aggroWord} range at {stack} bb — fold."
  else:         "{context} A true mixed spot: the equilibrium {aggroWord}s {label} about {round(freq*100)}% of the time here, so either answer is fine."
```
Note the middle band 0.02 < freq <= 0.2 and 0.8 <= freq < 0.98 produce the "mixed spot"
sentence while `accept` is still a single action — intentional (the text is honest about
the frequency; the grade follows the majority action).

### 3.12 `generatePushFold()` — Nash chip-EV drill (kind `pushfold`, source `chart`)

```
if random() < 0.33 -> return generateIcmPushFold()        // one third of reps are ICM bubbles
stack = PF_STACKS[rint(0, 10)]                            // 5..15 bb
if random() < 0.6:   // OPEN-SHOVE
  heroPos = [MP, CO, BTN, SB][rint(0,3)]
  freq = NASH_SHOVE[stack][heroPos][label] ?? 0
  (best, accept, rationale) = gradeFromFreq(freq, label, stack, raise, "shove",
        "Folded to you in the {heroPos} with {stack} bb (Nash, chip-EV, no antes).")
  foldedBefore = ORDER[0..heroIdx) minus SB/BB; pot = 1.5
  frames:
    "{stack} bb stacks. Blinds 0.5/1."                                pot 1.5
    for p in foldedBefore: "{p} folds."                                pot 1.5
    "Folded to you in the {heroPos} with {stack} bb. Shove or fold?"  pot 1.5
  toCall = heroPos == SB ? 0.5 : 1
  seats = fullSeats(heroPos, foldedBefore, [SB, BB] minus heroPos)
  options: fold "Fold"; raise "Shove {stack} bb" amount stack
  difficulty = (0.2 < freq < 0.8) ? 3 : 2
  gradeRange = chartLabels05(NASH_SHOVE[stack][heroPos] ?? {}); gradeRangeTitle "Nash {stack}bb {heroPos} shoving range"
  lessonId "spr", lessonTitle "SPR & Commitment"
else:                // CALL A SHOVE FROM THE BB
  shoverPos = [BTN, CO, SB][rint(0,2)]
  freq = NASH_CALL[stack]["{shoverPos}>BB"][label] ?? 0
  (best, accept, rationale) = gradeFromFreq(freq, label, stack, call, "call",
        "Facing a {stack} bb all-in from the {shoverPos} (Nash, chip-EV, no antes).")
  pot = r1(1.5 + stack)
  frames:
    "{stack} bb stacks. Blinds 0.5/1."              pot 1.5
    "{shoverPos} moves all-in for {stack} bb."      pot
    "Action on you in the BB. Call or fold?"        pot
  heroPos BB; toCall = r1(stack - 1); seats = fullSeats(BB, ORDER minus BB minus shover, [shoverPos])
  options: fold "Fold"; call "Call {r1(stack-1)} bb" amount r1(stack-1)
  difficulty as above; gradeRange = chartLabels05(NASH_CALL[stack]["{shoverPos}>BB"] ?? {})
  gradeRangeTitle "Nash BB calling range vs {stack}bb {shoverPos} shove"; lesson "spr" / "SPR & Commitment"
```

### 3.13 `generateIcmPushFold()` — ICM bubble (kind `pushfold`, source `chart`, `icm: true`)

```
sc = ICM_SCENARIOS[rint(0, 4)]; [sbStack, bbStack, o1, o2] = sc.stacks
heroIsSB = random() < 0.55
icmNote = "Bubble: 4 players left, 3 get paid (50/30/20). Chips you might WIN are worth less than the chips you'd LOSE — busting here costs everything."
if heroIsSB:
  freq = sc.jam[label] ?? 0
  gradeFromFreq(freq, label, sbStack, raise, "shove",
     "{sc.name}: folded to you in the SB with {sbStack} bb (ICM, $EV). {icmNote}")
  heroPos SB; pot 1.5; toCall 0.5; seats = fullSeats(SB, [UTG, MP], [BB])   // CO/BTN neither folded nor active (4-handed table: they show "In hand")
  frames:
    "{sc.name} — stacks: you (SB) {sbStack} bb, BB {bbStack} bb, others {o1}/{o2} bb."   pot 1.5
    sc.blurb                                                                             pot 1.5
    "Folded to you in the SB. Shove or fold?"                                            pot 1.5
  options: fold "Fold"; raise "Shove {sbStack} bb" amount sbStack
  difficulty = (0.2<freq<0.8) ? 3 : 2; gradeRange = chartLabels05(sc.jam); gradeRangeTitle "ICM SB shoving range — {sc.name}"
else:
  freq = sc.call[label] ?? 0
  gradeFromFreq(freq, label, bbStack, call, "call",
     "{sc.name}: the SB ({sbStack} bb) jams into your BB ({bbStack} bb) on the bubble (ICM, $EV). {icmNote}")
  effective = min(sbStack, bbStack)
  heroPos BB; pot = r1(1.5 + effective); toCall = r1(effective - 1); seats = fullSeats(BB, [UTG, MP], [SB])
  frames:
    "{sc.name} — stacks: SB {sbStack} bb, you (BB) {bbStack} bb, others {o1}/{o2} bb."   pot 1.5
    sc.blurb                                                                             pot 1.5
    "The SB moves all-in. Call for your tournament life, or fold?"                       pot r1(1.5+effective)
  options: fold "Fold"; call "Call {r1(effective-1)} bb" amount r1(effective-1)
  gradeRange = chartLabels05(sc.call); gradeRangeTitle "ICM BB calling range — {sc.name}"
lessonId "spr", lessonTitle "SPR & Commitment"; icm = true
```

### 3.14 `puzzleFromLeak(spot)` — replay a saved leak (kind `leak`, source `heuristic`)

```
folded = ORDER minus heroPos minus spot.oppActive
streetLabel = Capital(spot.street)
frames:
  { text: board non-empty ? "{streetLabel}: {board}" : "Pre-flop.", street, board copy, pot: spot.pot }
  { text: "Action on you in the {heroPos}{X}. What's the play?", same street/board/pot }
     where X = toCall > 0 ? " facing {(toCall / bb).toFixed(1)} bb" : ""      // toFixed(1): always one decimal, e.g. "2.0"
puzzle: id SEQ++, kind leak, source heuristic, street/heroPos/hole/board/pot/toCall/bb copied,
  handLabel = cardsToLabel(hole), seats = fullSeats(heroPos, folded, oppActive),
  options = spot.options (as saved), best = spot.best, accept = [spot.best], rationale = spot.rationale,
  equity/potOdds copied, difficulty 2, no gradeRange/lesson.
```
Note: leak `pot`/`toCall` may be in chips (coach leaks carry `bb` = table big blind);
`gradePuzzle`'s EV maths and the UI's "Calling: … bb" line then operate in chips —
a known imprecision in the original; keep or fix deliberately.

### 3.15 `gradePuzzle(p, action) -> GradeResult`

```
correct = p.accept.contains(action)
evLossBb = undefined
if !correct && p.equity != null && p.toCall > 0:
    evCall = p.equity * (p.pot + p.toCall) - p.toCall       // calling: win equity × final pot, pay toCall
    evOf(a) = a == fold ? 0 : a == call ? evCall : undefined  // raise/bet/check have no EV model
    chosen = evOf(action); best = evOf(p.best)
    if both defined: evLossBb = max(0, best - chosen)
return { correct, best: p.best, accept: p.accept, rationale: p.rationale, evLossBb }
```
Example (`puzzles_test.ts` leak case): hole `Ah Kd`, board `As 7c 2d`, pot 120, toCall 40,
bb 20, best fold, no equity -> `gradePuzzle(lp, fold).correct == true`,
`gradePuzzle(lp, call).correct == false`, `evLossBb` undefined (no equity).

---

## 4. Drill store: modes, adaptive difficulty, rating, navigator (`src/store/drillStore.ts`)

### 4.1 Persisted state

Key `"allin.drills.v1"` (localStorage JSON): `{ rating, solved, correct, streak, best }`.
Default when absent/invalid: `{ rating: 1000, solved: 0, correct: 0, streak: 0, best: 0 }`
(a stored record is accepted iff `rating` is a number).

Runtime state: `mode: DrillMode ("mixed"|"pushfold"|"exploit"|"leaks")`, `puzzle`,
`currentLeakId`, `currentReviewId`, `navIndex`, `answered: DrillAction?`,
`result: GradeResult?`, `ratingDelta`, `focusKind: PuzzleKind?`, `focusLeft: int`.
Initial: `mode = mixed`, `puzzle = generatePuzzle()` (NOT adaptive for the very first one),
`navIndex = frames.length - 1`, everything else null/0.

### 4.2 `genFor(mode, focusKind?)`

```
pushfold -> generatePushFold()
exploit  -> generateExploit()
leaks    -> now = Date.now()
            dueLeaks = leakStore.dueSpots(now); dueCards = reviewStore.dueCards(now)
            total = |dueLeaks| + |dueCards|; if 0 -> puzzle null (empty state)
            pick = (random()*total)|0
            pick < |dueLeaks| -> puzzleFromLeak(dueLeaks[pick]), leakId = spot.id
            else              -> dueCards[pick-|dueLeaks|].puzzle (the ORIGINAL saved Puzzle object), reviewId = card.id
mixed with focusKind -> up to 60 × generatePuzzle() until kind == focusKind, else any
mixed                -> adaptivePuzzle(rating)
```

### 4.3 `adaptivePuzzle(rating)`

```
target = rating < 1050 ? (random() < 0.7 ? 1 : 2)
       : rating < 1250 ? (random() < 0.55 ? 2 : (random() < 0.5 ? 1 : 3))
       : (random() < 0.6 ? 3 : 2)
up to 25 × generatePuzzle() returning the first with difficulty == target; else generatePuzzle()
```
Difficulty by kind: rfi 1 (or 3 if mixed-frequency); vs-raise 2/3; postflop-bet 2/3;
postflop-check always 2; threebet-pot 2/3; check-raise 2/3; river-decision 2/3. So
difficulty-1 spots are exclusively clear-cut RFI spots; beginners see mostly those.

### 4.4 `answer(a)` — grading, Elo, streaks

```
if answered != null -> ignore
res = gradePuzzle(puzzle, a)
goals.record("drill")                                  // daily-goal counter (DAILY_DRILL_GOAL = 20)
if mode == leaks:
    if currentLeakId   -> leakStore.review(currentLeakId, res.correct)
    if currentReviewId -> reviewStore.review(currentReviewId, res.correct)
    set answered=a, result=res, ratingDelta=0, navIndex=last;  return    // rating untouched
if !res.correct && puzzle.kind != leak -> reviewStore.addMiss(puzzle)
puzzleRating = 800 + difficulty*200                    // 1000 / 1200 / 1400
expected = 1 / (1 + 10^((puzzleRating - rating)/400))  // standard Elo expectation
delta  = Math.round(24 * ((correct ? 1 : 0) - expected))   // K = 24; JS round = floor(x+0.5)
rating = max(100, Math.round(rating + delta))
streak = correct ? streak+1 : 0;  best = max(best, streak)
solved += 1;  correct += (correct ? 1 : 0)
persist; set answered, result, ratingDelta=delta, rating, streak, best, solved, correct, navIndex=last
```
Worked values: rating 1000 vs difficulty 2 (1200): expected = 1/(1+10^0.5) = 0.2403;
correct -> +18, wrong -> -6. Rating 1000 vs difficulty 1: expected 0.5 -> ±12.
Rating 1400 vs difficulty 3: ±12. Rating 1250 vs difficulty 3 (1400): expected 0.2966
-> +17 / -7. Use `(x + 0.5).floorToDouble()` semantics for negative `.5` cases
(JS `Math.round(-11.5) == -11`; Dart `(-11.5).round() == -12`).

Placement quiz (onboarding, 8 questions, each `answer` index 0) seeds the rating:
`score <= 2 -> 900`, `score <= 5 -> 1050`, else `1250` via `seedRating(r)` which
overwrites only `rating` and persists.

### 4.5 `next()`, `setMode(m)`, `drillSimilar()`, `setNav(i)`

```
next():  focus = focusLeft > 0 ? focusKind : null
         {puzzle, leakId, reviewId} = genFor(mode, focus)
         if puzzle null -> set answered=null, result=null, ratingDelta=0, currentLeakId=null, currentReviewId=null (old puzzle object stays but UI shows the empty state)
         focusLeft' = focus ? focusLeft-1 : 0
         set puzzle, currentLeakId, currentReviewId, navIndex=last, answered=null, result=null, ratingDelta=0,
             focusLeft', focusKind = focusLeft' > 0 ? focusKind : null
setMode(m): set mode=m; genFor(m) (no focus); same null handling; does NOT reset focusKind/focusLeft (quirk)
drillSimilar(): if mode == leaks or puzzle.kind == leak -> no-op; else focusKind = puzzle.kind, focusLeft = 5; next()
setNav(i): navIndex = clamp(i, 0, frames.length-1)
```
The "Hand replay" navigator is purely `frames[navIndex]`: the table renders that frame's
`board`, `pot` and `street`; the text list highlights index `navIndex`; the last frame
is the decision point. Answering always snaps `navIndex` to the last frame.

### 4.6 Review queue (missed drills) — `src/store/reviewStore.ts`

Key `"allin.review.v1"`, cap 80 cards, `ReviewCard { id, puzzle: Puzzle, srs }`.
`addMiss(p)`: `id = "{kind}|{handLabel}|{board joined}|{heroPos}"`; skip if an id already
exists; prepend `{id, puzzle: p, srs: newSrs(now)}`; truncate to 80.
`review(id, correct)`: `srs = reviewSrs(srs, correct, now)`; drop the card if
`correct && isGraduated(srs)`. `dueCards(now)` = cards with `srs.due <= now`.

Leak queue — `src/store/leakStore.ts`: key `"allin.leaks.v1"`, cap 60, same
`add`/`review`/`dueSpots` semantics on `LeakSpot` (spots saved without `srs` get
`newSrs(spot.ts ?? now)` on load, i.e. due immediately).

SRS (`src/lib/srs.ts`, SM-2-style, tiny):
```
RETIRE_REPS = 3
newSrs(now) = { due: now, intervalDays: 0, ease: 2.3, reps: 0, lapses: 0 }
reviewSrs(s, correct, now):
  wrong  -> { due: now + 10 min, intervalDays 0, ease max(1.3, ease-0.2), reps 0, lapses+1 }
  right  -> intervalDays = reps==0 ? 1 : reps==1 ? 3 : max(4, round(intervalDays*ease))
            { due: now + intervalDays days, intervalDays, ease min(3, ease+0.05), reps+1, lapses }
isDue(s, now) = s == null || s.due <= now;   isGraduated(s) = s.reps >= 3
```

LeakSpot producers (for schema fidelity):
* Play-mode coach (`gameStore.ts`), when a verdict is `"mistake"`:
  `id = "{handNumber}-{street}-{Date.now()}"`, `pot`/`toCall` in chips, `bb = table bigBlind`,
  `best` = call->fold, fold->call, check->bet, bet->check, raise->fold;
  options when facing a bet: `Fold` / `Call {(callAmount/bb).toFixed(1)} bb` (amount callAmount) / `Raise` (amount round(pot+callAmount));
  otherwise `Check` / `Bet` (amount round(pot*0.66)); `rationale` = the coach's text; equity/potOdds from the review.
* Hand-history import (`hhImport.ts`): `id = "imp-{startedAt}-{street}"`, values in bb (`bb = 1`),
  options `Fold` / `Call {x.toFixed(1)} bb`, best fold, rationale
  `Imported hand: you called {x} bb needing {N}% but {label} wins only ~{E}% even against a random hand — real ranges make it worse.`

---

## 5. UI strings (quote verbatim)

### 5.1 Mode tabs (`DrillsView.tsx`)

| mode | label | blurb |
|---|---|---|
| mixed | `Mixed` | `Pre-flop charts + post-flop pot-odds/equity. Opponent type is irrelevant — play solid baseline poker.` |
| pushfold | `Push / Fold` | `Short-stack shove/fold and call-a-shove spots, graded by computed Nash equilibrium tables (chip-EV, no antes).` |
| exploit | `Exploits` | `Best deviation vs a KNOWN opponent type — the spots where the right play differs from balanced, with both numbers shown.` |
| leaks | `Review` | `Your coach-flagged leaks and missed drills on a spaced schedule — beat a spot 3 times over days to retire it.` |

The Review tab label gets ` ({dueCount} due)` appended when dueCount > 0, where
dueCount = leak spots with `!srs || srs.due <= now` + review cards with `srs.due <= now`.
Header: `Drills`. Stats (hidden in Review mode): `Rating` (tooltip
`A self-adjusting puzzle rating (like a chess puzzle ELO). Right answers raise it, wrong ones lower it, weighted by difficulty.`),
`Accuracy` = `round(correct/solved*100)%` (0% when solved==0), `Streak`, `Best`,
`Today` = `min(todayDrills,20)/20` (tooltip `A quiet daily goal: 20 drill answers (or 30 hands) keeps the day-streak alive. No reminders, no guilt — just a nudge to come back tomorrow.`), `Day streak` when > 0.

Empty Review state: title `Nothing due right now` (if any cards exist) else `No spots to review yet`;
body `All {totalCards} of your review spots are scheduled for later — spaced practice sticks best when you come back to it. Play or drill in the meantime.`
else `Play a session with the EV Coach on, or miss a practice drill, and the spot lands here on a spaced-repetition schedule until you've beaten it three times.`

### 5.2 Controls (`DrillControls.tsx`)

* `Your hand: {handLabel}` and a source pill:
  leak -> `Your flagged spot`; exploit -> `Exploit · vs a known type`;
  pushfold & icm -> `Push/Fold · ICM bubble`; pushfold -> `Push/Fold · computed Nash`;
  source chart -> `Pre-flop chart · 100bb baseline`; else `Post-flop heuristic · fundamentals`.
* Option buttons show `option.label`; keys `1`/`2`/`3` answer options 0..2; `Enter` = next.
  After answering: accepted options green, the chosen wrong one red, others dimmed.
* Result headline: `Correct` / `Not optimal`, plus `fmtSigned(ratingDelta, 0)` (`+18`, `-6`) when non-zero.
* If wrong and `evLossBb > 0.05`: `That choice costs about {evLossBb.toFixed(1)} bb every time — {size}.`
  with size `a small leak` (< 0.5), `a real leak` (< 1.5), else `a blunder-sized leak`.
* Rationale paragraph.
* When `equity`, `potOdds` present and `toCall > 0`:
  `Folding: 0 bb — costs nothing more.`
  `Calling: {fmtSigned(equity*(pot+toCall) - toCall)} bb per try — your hand wins {fmtTimes(equity)} and you need {fmtNeed(potOdds)}.`
* When either is present: `Equity: {fmtPct(equity)}` and/or `Pot odds: {fmtPct(potOdds)}`.
* If `gradeRange` non-empty: toggle `See the range it was graded against` / `Hide the range`,
  showing a read-only 13x13 matrix highlighting `gradeRange` with caption `gradeRangeTitle`.
* Buttons: lesson link labelled `lessonTitle` (fallback `Read the lesson`);
  `Drill 5 similar` (hidden in Review mode / for leak puzzles); when `focusLeft > 0`:
  `{focusLeft} more of this spot type coming up`; `Next puzzle`.

Formatters (`src/lib/format.ts`):
```
fmtSigned(n, digits=1): v = round(n*10^d)/10^d; (v >= 0 ? "+" : "") + v.toFixed(d)
fmtPct(frac, digits=0): (frac*100).toFixed(d) + "%"
fmtTimes(p): p >= 0.93 -> "almost every time"; p <= 0.04 -> "almost never";
             p >= 0.45 -> "about {round(p*10)} times in 10"; else "about 1 time in {round(1/p)}"
fmtNeed(potOdds): <= 0 -> "any win rate"; n = 1/potOdds; r = round(n*2)/2;
             "about 1 time in {r as int if integral else r.toFixed(1)}"
```
`round` above is JS `Math.round` (half toward +inf), and `fmtSigned` has a negative-zero
case this block omits — `fmtSigned(n)` prints `+0.0` for every `n` in `[-0.05, 0)`, which
the `Calling:` line above reaches. **See §11.3** for the exact behaviour, the two Dart
traps (`"+-0.0"`, and `round()` being half-away-from-zero), and the `jsRound` fix.

### 5.3 Navigator and table

`MoveNavigator`: heading `Hand replay`; buttons with aria-labels `First`, `Previous`, `Next`, `Decision`;
each frame row shows `{i+1}` and `frame.text`; the last row is bold with a target icon.
`DrillTable`: hero seat first at the bottom, then the other five seats in ORDER
(minus hero) around the table; hero shows the two hole cards, others two face-down cards
(25% opacity + grayscale when folded); seat badge `{pos}` and `You` / `Folded` / `In hand`
(`active` is not consulted). Centre shows `frame.pot` and `frame.board`.

---

## 6. Preflop chart data (`src/data/preflop.ts`, generated by `scripts/preflop_gen.ts`)

### 6.1 Schema

```
ChartFreqs     = Map<HandLabel, double>            // frequency 0 < f <= 1; absent label = 0
VsRfiChart     = { threebet: ChartFreqs, call: ChartFreqs }
PreflopCharts  = { rfi: Map<Position, ChartFreqs>, vsRfi: Map<"HERO_vs_RAISER", VsRfiChart> }
PREFLOP_BY_DEPTH: Map<int, PreflopCharts>  // only key 100 today; new depths must ship their own charts, never rescaled
PREFLOP_100 = PREFLOP_BY_DEPTH[100]
```
`rfi` keys: `UTG MP CO BTN SB` (no BB). `vsRfi` keys (15): `MP_vs_UTG CO_vs_UTG CO_vs_MP
BTN_vs_UTG BTN_vs_MP BTN_vs_CO SB_vs_UTG SB_vs_MP SB_vs_CO SB_vs_BTN BB_vs_UTG BB_vs_MP
BB_vs_CO BB_vs_BTN BB_vs_SB`. ~~Map insertion order = token expansion order (matters only
for `gradeRange` display order).~~ **SUPERSEDED by §11.1: both halves of that sentence are
false — the shipped key order is not the expansion order (18 of 35 charts differ), and no
consumer reads the order at all. Any label ordering is acceptable.** Convert the file mechanically: the single long line is
`export const PREFLOP_BY_DEPTH: Record<number, PreflopCharts> = { 100: <JSON> };` — the
`<JSON>` is valid JSON.

### 6.2 Range-string notation and expander (`expandToken`)

Tokens are whitespace/comma separated; each token optionally ends in `:freq` (0 < freq <= 1,
default 1). `RANKS = "AKQJT98765432"` (index 0 = A). Writing into the chart uses
`chart[label] = max(existing ?? 0, freq)` — overlapping tokens keep the HIGHER frequency.

* Pairs (`core` matches `^([rank])\1`):
  `TT+` -> every pair from TT up to AA; `77-99` -> the inclusive run (either input order —
  emission order pinned in §11.2: high-to-low, so `88-JJ` -> `JJ TT 99 88`);
  `22` -> that pair only.
* Two-rank `^([rank])([rank])([so])(\+?)$`: kicker index must be > high index (else error).
  `A2s+` -> `A2s A3s ... AKs` (kicker up to one below the high card); `A5s` -> single.
* Kicker run `^([rank])([rank])([so])-([rank])([rank])([so])$`: same high card required;
  `Q9s-Q6s` -> `Q9s Q8s Q7s Q6s` (either order). NOTE: the suit letter of the second
  half is not checked against the first (both parts are matched but only the first
  suit letter is used).
* Anything else -> error.

### 6.3 The source range strings (verbatim; these ARE the answer key)

RFI (2.5bb opens):
```
UTG: 22+ A9s+ A5s-A2s:0.5 KTs+ QTs+ JTs T9s 98s:0.5 ATo+ KQo
MP:  22+ A2s+ KTs+ K9s:0.5 QTs+ Q9s:0.5 J9s+ T9s 98s 87s:0.5 ATo+ KJo+ QJo:0.5
CO:  22+ A2s+ K8s+ K7s-K5s:0.5 Q9s+ Q8s:0.5 J9s+ T8s+ 97s+ 87s 76s 65s:0.5 A8o+ A5o:0.5 KTo+ QTo+ JTo
BTN: 22+ A2s+ K2s+ Q4s+ Q3s-Q2s:0.5 J7s+ J6s-J5s:0.5 T7s+ 96s+ 86s+ 75s+ 64s+:0.5 54s 53s:0.5 43s:0.5 A2o+ K8o+ K7o-K5o:0.5 Q9o+ Q8o:0.5 J9o+ J8o:0.5 T9o T8o:0.5 98o:0.5
SB:  22+ A2s+ K2s+ Q4s+ J7s+ T7s+ 97s+ 86s+ 75s+ 65s 54s A2o+ K8o+ Q9o+ J9o+ T9o 98o:0.5
```
Facing an open (`threebet` / `call`):
```
MP_vs_UTG   3bet: QQ+ AKs AKo:0.5 A5s:0.5
            call: 88-JJ 77:0.5 AQs AJs ATs:0.5 KQs QJs:0.5 JTs T9s:0.5 AQo:0.5
CO_vs_UTG   3bet: QQ+ AKs AKo A5s:0.5
            call: 77-JJ 22-66:0.5 AQs AJs ATs KQs KJs:0.5 QJs JTs T9s 98s:0.5 AQo
CO_vs_MP    3bet: JJ+ AQs+ AKo A5s-A4s:0.5
            call: 66-TT 22-55:0.5 AJs ATs KJs+ QJs JTs T9s AQo AJo:0.5
BTN_vs_UTG  3bet: QQ+ AKs AKo A5s:0.5
            call: 55-JJ 22-44:0.5 AQs AJs ATs:0.5 KQs KJs:0.5 QJs JTs T9s 98s:0.5 AQo
BTN_vs_MP   3bet: JJ+ AQs+ AKo A5s-A4s:0.5
            call: 44-TT 22-33:0.5 ATs+ KTs+ QTs+ JTs T9s 98s 87s:0.5 76s:0.5 AJo+ KQo:0.5
BTN_vs_CO   3bet: TT+ AJs+ AKo AQo:0.5 A5s-A3s:0.5 KQs:0.5 76s:0.25 65s:0.25
            call: 22-99 A2s+ KTs+ QTs+ J9s+ T8s+ 97s+ 87s 76s 65s ATo+ KJo+ QJo:0.5
SB_vs_UTG   3bet: QQ+ AKs AKo:0.5 A5s:0.5
            call: 88-JJ 77:0.5 AQs AJs:0.5 KQs QJs:0.5 JTs:0.5 AQo:0.5
SB_vs_MP    3bet: JJ+ AQs+ AKo A5s:0.5
            call: 66-TT AJs ATs:0.5 KJs+ QJs JTs T9s:0.5 AQo
SB_vs_CO    3bet: TT+ AJs+ AQo+ A5s-A4s:0.5 KQs 99:0.5
            call: 55-99 22-44:0.5 ATs KTs+ QTs+ JTs T9s 98s:0.5 AJo KQo
SB_vs_BTN   3bet: 99+ ATs+ AJo+ A5s-A2s:0.5 KJs+ QJs:0.5 JTs:0.5 88:0.5 T9s:0.25
            call: 22-88 A9s-A6s:0.5 KTs QTs J9s+ T8s+ 98s 87s 76s ATo KJo QJo:0.5
BB_vs_UTG   3bet: QQ+ AKs AKo:0.5 A5s-A4s:0.5
            call: 22-JJ A2s+ K9s+ K8s:0.5 Q9s+ J9s+ T8s+ 97s+ 87s 76s 65s 54s ATo+ KJo+ QJo:0.5 JTo:0.5
BB_vs_MP    3bet: JJ+ AQs+ AKo A5s-A4s:0.5 76s:0.25 65s:0.25
            call: 22-TT A2s+ K8s+ Q9s+ J8s+ T8s+ 97s+ 86s+ 76s 65s 54s A9o+ KTo+ QTo+ JTo
BB_vs_CO    3bet: TT+ AJs+ AQo+ A5s-A2s:0.5 KQs T9s:0.25 98s:0.25
            call: 22-99 A2s+ K5s+ Q8s+ J8s+ T7s+ 97s+ 86s+ 75s+ 65s 54s A8o+ A5o:0.5 KTo+ QTo+ JTo T9o:0.5
BB_vs_BTN   3bet: 99+ ATs+ AJo+ KQo:0.5 A5s-A2s:0.75 K9s:0.5 QTs:0.25 JTs:0.25 87s:0.25 76s:0.25
            call: 22-88 A2s+ K2s+ Q4s+ J7s+ T7s+ 96s+ 86s+ 75s+ 64s+ 54s 43s A2o+ K9o+ Q9o+ J9o+ T8o+ 98o 87o:0.5
BB_vs_SB    3bet: 88+ A9s+ ATo+ KQo A5s-A2s:0.75 KTs+ QJs:0.5 JTs:0.5 T9s:0.5 77:0.5
            call: 22-77 A2s+ K2s+ Q2s+ J4s+ T6s+ 95s+ 85s+ 74s+ 64s+ 53s+ 43s A2o+ K7o+ Q8o+ J8o+ T8o+ 97o+ 87o 76o:0.5
```

### 6.4 Post-processing: clip call by 3-bet

For each vsRfi pair, after expanding both strings: for each label in `call`,
`room = round((1 - (threebet[l] ?? 0)) * 100) / 100`; if `call[l] > room`:
delete the label when `room <= 0`, else set `call[l] = room`. Guarantees
`threebet[l] + call[l] <= 1` for every label. Resulting overlaps in the shipped data
(3bet, call): BTN_vs_CO A3s/A4s/A5s/KQs/AQo (0.5, 0.5), 76s/65s (0.25, 0.75);
SB_vs_CO 99 (0.5, 0.5); SB_vs_BTN 88/JTs (0.5, 0.5), T9s (0.25, 0.75);
BB_vs_UTG A4s/A5s/AKo (0.5, 0.5); BB_vs_MP A4s/A5s (0.5, 0.5), 76s/65s (0.25, 0.75);
BB_vs_CO A2s-A5s (0.5, 0.5), T9s/98s (0.25, 0.75);
BB_vs_BTN A2s-A5s (0.75, 0.25), K9s/KQo (0.5, 0.5), QTs/JTs/87s/76s (0.25, 0.75);
BB_vs_SB 77/QJs/JTs/T9s (0.5, 0.5), A2s-A5s (0.75, 0.25).

### 6.5 Shipped widths (regression targets)

RFI: UTG 35 labels 14.8%, MP 44 / 18.6%, CO 59 / 26.4%, BTN 97 / 44.9%, SB 83 / 41.0%.
vsRfi (3bet labels/width · call labels/width):
MP_vs_UTG 6/2.3% · 13/4.1%; CO_vs_UTG 6/2.7% · 20/6.7%; CO_vs_MP 9/3.6% · 18/6.6%;
BTN_vs_UTG 6/2.7% · 20/7.0%; BTN_vs_MP 9/3.6% · 24/9.2%; BTN_vs_CO 16/5.3% · 37/14.3%;
SB_vs_UTG 6/2.3% · 11/3.5%; SB_vs_MP 8/3.5% · 13/5.0%; SB_vs_CO 14/5.8% · 18/6.8%;
SB_vs_BTN 23/8.4% · 23/8.3%; BB_vs_UTG 7/2.4% · 47/18.7%; BB_vs_MP 11/3.8% · 49/21.7%;
BB_vs_CO 17/6.0% · 54/23.1%; BB_vs_BTN 23/8.4% · 74/34.4%; BB_vs_SB 28/11.7% · 83/39.6%.

---

## 7. Nash push/fold tables (`src/data/pushfold.ts`, generated by `scripts/pushfold_gen.ts`)

### 7.1 Schema

```
PushFoldPos = UTG | MP | CO | BTN | SB
PUSHFOLD_STACKS = [2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,20,22,25]     // 20 stacks (bb)
NASH_SHOVE: Map<int stack, Map<PushFoldPos, Map<HandLabel, double>>>        // 20 × 5 = 100 tables
NASH_CALL:  Map<int stack, Map<"SHOVER>CALLER", Map<HandLabel, double>>>    // 20 × 15 = 300 tables
```
Call keys per stack (15): `UTG>MP UTG>CO UTG>BTN UTG>SB UTG>BB MP>CO MP>BTN MP>SB MP>BB
CO>BTN CO>SB CO>BB BTN>SB BTN>BB SB>BB`. Frequencies are sparse: labels with weight
< 0.05 are omitted; weights > 0.95 become exactly 1; others rounded to 2 decimals.
Label order inside each table follows `equity_matrix.json.labels` order (section 8).
Convert mechanically: two long lines `export const NASH_SHOVE: ... = <JSON>;` and
`export const NASH_CALL: ... = <JSON>;`.

### 7.2 Solver (fictitious play, chip EV, blinds 0.5/1, no antes, equal stacks S)

Inputs: `labels[169]`, `E[h][l]` = equity of label h vs label l (from `equity_matrix.json`),
`W[l] = comboCount(l)/1326`.
Model: first caller takes it heads-up (overcalls ignored); label-level ranges (blockers ignored).

```
SEATS_BEHIND = { UTG:[MP,CO,BTN,SB,BB], MP:[CO,BTN,SB,BB], CO:[BTN,SB,BB], BTN:[SB,BB], SB:[BB] }
blind(p) = SB:0.5, BB:1, else 0
weightedEquity(strat): vec[h] = Σ_l strat[l]*W[l]*E[h][l]; mass = Σ_l strat[l]*W[l]

solveStack(S):
  strength[h] = Σ_l W[l]*E[h][l]; order = labels sorted by strength desc
  init: shove[p][h] = 1 for the top 50 of `order`, else 0     (for each shover p)
        call["p>c"][h] = 1 for the top 15, else 0              (for each c behind p)
  for t = 1..200:
    // shovers best-respond to the AVERAGE calling ranges
    for p in [UTG,MP,CO,BTN,SB]:
      callers = for c in SEATS_BEHIND[p]: {vec, mass} = weightedEquity(call["p>c"]);
                dead = (c != SB && p != SB ? 0.5 : 0) + (c != BB ? 1 : 0); pot = 2S + dead
      for h: pAllFold = 1; ev = 0
             for each caller c in order: pCall = c.mass; eq = pCall > 0 ? c.vec[h]/pCall : 0.5
                 ev += pAllFold * pCall * (eq * c.pot - (S - blind(p)))
                 pAllFold *= (1 - pCall)
             ev += pAllFold * 1.5
             br[h] = ev > 0 ? 1 : 0
      shove[p][h] += (br[h] - shove[p][h]) / t                 // running average
    // callers best-respond to the AVERAGE shove ranges
    for p: {vec, mass} = weightedEquity(shove[p])
      for c in SEATS_BEHIND[p]: dead/pot as above
        for h: eq = mass > 0 ? vec[h]/mass : 0.5
               br = (eq * pot - (S - blind(c)) > 0) ? 1 : 0
               call["p>c"][h] += (br - call["p>c"][h]) / t
  return shove, call
sparse(v): skip w < 0.05; w > 0.95 -> 1; else round(w*100)/100
```
The `dead` money term: the blinds not involved in the confrontation (SB's 0.5 when neither
party is the SB; BB's 1 when the caller is not the BB). Note `pCall` is a label mass
(fraction of all hands), so overcall/heads-up simplifications are baked in.

### 7.3 Shipped widths (% of all combos) — regression targets

```
stack  UTG   MP    CO    BTN   SB   | BB call vs SB  vs BTN  vs CO
   2   82.6  82.6  82.5  82.2  90.3 |  100.0  100.0  100.0
   3   45.5  47.1  49.9  55.7  77.8 |   91.9   96.6   95.8
   4   30.6  32.4  36.5  43.7  74.4 |   72.6   65.4   60.6
   5   24.6  27.7  32.2  39.1  71.5 |   61.8   43.8   38.7
   6   20.6  24.0  29.7  37.1  68.6 |   54.2   35.2   30.2
   7   17.2  21.0  27.4  34.7  66.6 |   48.5   30.0   24.9
   8   16.4  19.2  25.8  34.0  62.4 |   44.3   26.7   20.7
   9   14.8  17.7  23.6  32.7  60.6 |   40.0   24.1   18.3
  10   14.7  17.6  22.3  31.8  58.2 |   37.1   21.9   15.5
  11   13.6  16.3  20.4  30.5  55.3 |   35.0   19.4   14.3
  12   11.5  15.3  19.6  29.0  52.1 |   32.7   18.0   12.0
  13   10.7  14.9  18.7  27.2  49.6 |   30.8   16.4   10.8
  14    9.0  14.1  18.0  25.9  48.3 |   28.7   15.1   10.5
  15    9.3  11.2  16.8  24.5  46.4 |   27.4   13.9    9.3
  16    7.8  11.1  15.9  23.7  44.0 |   25.8   13.2    8.3
  17    7.5   9.6  15.4  22.8  43.3 |   24.1   12.2    8.3
  18    8.1   9.1  15.2  21.7  43.0 |   22.7   11.1    8.3
  20    7.3   7.9  13.2  19.2  40.4 |   20.9   10.5    6.7
  22    6.3   7.3  11.4  18.5  38.7 |   18.8    8.9    6.0
  25    5.2   7.2   9.0  16.0  35.3 |   16.5    8.3    5.5
```

### 7.4 Sample tables verbatim (10 bb)

`NASH_SHOVE[10].SB` = every label at 1 EXCEPT these 51 absent (0): `Q6o Q5o Q4o Q3o Q2o J7o J6o J5o J4o J3o J2o T7o T6o T5o T4o T3s T3o T2s T2o 96o 95o 94s 94o 93s 93o 92s 92o 85o 84o 83s 83o 82s 82o 75o 74o 73s 73o 72s 72o 64o 63o 62s 62o 54o 53o 52o 43o 42s 42o 32s 32o`
and these mixed: `Q7o 0.25, J4s 0.95, J3s 0.93, J2s 0.24, T5s 0.93, T4s 0.91, 97o 0.82, 95s 0.94, 87o 0.94, 86o 0.27, 84s 0.91, 76o 0.93, 74s 0.94, 65o 0.35, 63s 0.91, 53s 0.94, 52s 0.15, 43s 0.93`.

`NASH_CALL[10]["SB>BB"]` (72 labels):
```
22 33 44 55 66 77 88 99 AA AKs AKo AQs AQo AJs AJo ATs ATo A9s A9o A8s A8o A7s A7o A6s A6o A5s A5o
A4s A4o A3s A3o A2s A2o KK KQs KQo KJs KJo KTs KTo K9s K9o K8s K8o K7s K7o K6s K5s K4s K3s QQ QJs
QJo QTs QTo Q9s Q9o Q8s JJ JTs JTo J9s TT              -> all 1
K6o 0.95  K5o 0.37  K2s 0.88  Q8o 0.06  Q7s 0.84  Q6s 0.42  J9o 0.44  J8s 0.86  T9s 0.94
```

---

## 8. ICM (`src/lib/icm.ts`, `src/data/icmPushfold.ts`, `scripts/icm_pushfold_gen.ts`)

### 8.1 `icmShares(stacks: List<double>, payouts: List<double>) -> List<double>` (Malmuth-Harville)

Probability a player finishes next is proportional to stack, applied recursively
down the paid places.

```dart
List<double> icmShares(List<double> stacks, List<double> payouts) {
  final n = stacks.length; final shares = List.filled(n, 0.0);
  void rec(List<int> remaining, int place, double prob) {
    if (prob < 1e-12 || place >= payouts.length) return;
    final total = remaining.fold(0.0, (a, i) => a + stacks[i]);
    if (total <= 0) return;
    for (final i in remaining) {
      if (stacks[i] <= 0) continue;
      final p = prob * (stacks[i] / total);
      shares[i] += p * payouts[place];
      rec(remaining.where((x) => x != i).toList(), place + 1, p);
    }
  }
  rec([for (var i = 0; i < n; i++) if (stacks[i] > 0) i], 0, 1.0);
  return shares;
}
```
Reference values (payouts `[0.5, 0.3, 0.2]`):
* `[25,25,25,25]` -> `[0.25, 0.25, 0.25, 0.25]` (sum 1)
* `[90,4,3,3]` -> `[0.47927, 0.19683, 0.16195, 0.16195]`
* `[0,40,30,30]` -> `[0, 0.35429, 0.32286, 0.32286]` (sum 1; busted stack = 0)
* `[20,20,30,30][0]` = `0.21786`; `[40,0,30,30][0]` = `0.35429` (< 2 × 0.21786: doubling is worth less than 2x)
* `[50,30,20]` -> `[0.38393, 0.32750, 0.28857]`; `[70,30]` -> `[0.44, 0.36]` (fewer players than payouts: unpaid places simply don't distribute)

### 8.2 Scenario schema and the five shipped scenarios

```
IcmScenario { id, name, blurb, stacks: [SB, BB, other, other] (bb), jam: ChartFreqs, call: ChartFreqs }
ICM_SCENARIOS: List<IcmScenario> (5)
PAYOUTS = [0.5, 0.3, 0.2]; SBLIND = 0.5; BBLIND = 1
```
| id | name | stacks | blurb (as SHIPPED in `src/data/icmPushfold.ts`) |
|---|---|---|---|
| even | `Even bubble` | [25,25,25,25] | `Four even stacks, three get paid — the purest bubble.` |
| big-sb | `Big stack in the SB` | [45,15,20,20] | `You have the biggest stack — you cover everyone; the BB can't afford to bust.` |
| short-sb | `Short stack in the SB` | [10,30,30,30] | `You're the one who can't afford mistakes — but folding blinds away is dying slowly.` |
| big-bb | `Chip leader in the BB` | [20,45,17,18] | `The BB has more chips than you — they cover you: every all-in threatens YOUR tournament life, not theirs.` |
| mid-vs-short | `Medium vs short` | [28,8,32,32] | `You have chips to pressure with; the BB is nearly dead anyway.` |

DISCREPANCY: `scripts/icm_pushfold_gen.ts` still has the older blurbs for `big-sb`
(`You cover everyone; the BB can't afford to bust.`) and `big-bb`
(`The BB covers you: every all-in threatens YOUR tournament life, not theirs.`).
The data file (what users see) was edited after generation to the plain-language
versions in the table above. Port the DATA-FILE text; if you regenerate, update the script first.

Shipped widths: even jam 153 labels 74.7% / call 13 labels 5.9%; big-sb jam 169 / 100.0% (any two) / call 17 / 8.3%;
short-sb jam 117 / 48.3% / call 50 / 24.3%; big-bb jam 80 / 22.0% / call 15 / 6.9%; mid-vs-short jam 147 / 76.3% / call 64 / 34.8%.

Call tables verbatim:
```
even:         77 0.5, 88 1, 99 1, AA 1, AKs 1, AKo 1, AQs 1, AQo 0.77, AJs 1, KK 1, QQ 1, JJ 1, TT 1
big-sb:       66 77 88 99 AA AKs AKo AQs AQo AJs AJo ATs KK KQs QQ JJ TT  (all 1)
short-sb:     33 44 55 66 77 88 99 AA AKs AKo AQs AQo AJs AJo ATs ATo A9s A9o A8s A8o A7s A7o A6s A6o A5s A4s A3s A2s
              KK KQs KQo KJs KJo KTs KTo K9s QQ QJs QTs JJ TT (all 1);
              A5o 0.95, A4o 0.24, K9o 0.92, K8s 0.93, K7s 0.14, QJo 0.93, QTo 0.1, Q9s 0.2, JTs 0.93
big-bb:       99 AA AKs AKo AQs KK QQ JJ TT (all 1); 77 0.6, 88 0.94, AQo 0.9, AJs 0.87, AJo 0.73, ATs 0.69
mid-vs-short: 33 44 55 66 77 88 99 AA AKs AKo AQs AQo AJs AJo ATs ATo A9s A9o A8s A8o A7s A7o A6s A6o A5s A5o A4s A4o
              A3s A3o A2s A2o KK KQs KQo KJs KJo KTs KTo K9s K9o K8s K8o K7s K7o K6s K6o K5s K4s QQ QJs QJo QTs QTo
              Q9s Q9o Q8s JJ JTs JTo J9s TT (all 1); Q7s 0.58, T9s 0.94
```
Jam tables: `big-sb` = all 169 labels at 1. For the others, "absent" labels (0) are:
* even (16 absent): `T3o T2o 94o 93o 92o 84o 83o 82o 74o 73o 72o 63o 62o 52o 42o 32o`; mixed: `K3o .94 K2o .9 Q7o .68 Q6o .75 Q5o .94 Q4o .55 Q3o .33 Q2o .09 J6o .49 J5o .7 J4o .17 J3o .11 J2o .07 T6o .87 T5o .07 T4o .07 96o .85 95o .09 86o .94 85o .1 83s .91 82s .93 76o .94 75o .66 73s .94 72s .36 64o .79 62s .94 53o .81 43o .4`; everything else 1.
* short-sb (52 absent): `K3o K2o Q7o Q6o Q5o Q4o Q3o Q2o J7o J6o J5o J4o J3o J2o T6o T5o T4o T3o T2s T2o 96o 95o 94s 94o 93s 93o 92s 92o 85o 84o 83s 83o 82s 82o 75o 74o 73s 73o 72s 72o 64o 63o 62s 62o 54o 53o 52o 43o 42s 42o 32s 32o`; mixed: `K7o .23 K6o .15 K5o .1 K4o .06 Q8o .13 Q3s .79 Q2s .45 J8o .12 J6s .95 J5s .94 J4s .53 J3s .1 J2s .07 T8o .94 T7o .06 T6s .95 T5s .11 T4s .1 T3s .06 98o .95 97o .11 95s .94 87o .94 86o .08 85s .95 84s .33 76o .6 74s .94 65o .08 64s .95 63s .36 53s .94 52s .06 43s .61`.
* big-bb (89 absent — every offsuit below KQo except ATo/A9o/A8o/A7o/A6o/A5o/A4o/A3o/A2o/KJo/KTo/K9o/QJo/QTo/JTo/T9o, plus weak suited): absent list = `K8o K7o K6o K5o K4o K3o K2o Q9o Q8o Q7o Q6o Q5o Q4s Q4o Q3s Q3o Q2s Q2o J9o J8o J7o J6s J6o J5s J5o J4s J4o J3s J3o J2s J2o T8o T7o T6s T6o T5s T5o T4s T4o T3s T3o T2s T2o 98o 97o 96o 95s 95o 94s 94o 93s 93o 92s 92o 87o 86o 85s 85o 84s 84o 83s 83o 82s 82o 76o 75o 74s 74o 73s 73o 72s 72o 65o 64o 63s 63o 62s 62o 54o 53s 53o 52s 52o 43s 43o 42s 42o 32s 32o`; at 1: `88 99 AA AKs AKo AQs AQo AJs AJo KK QQ JJ TT`; all other 67 present labels are mixed (e.g. `22 .88 33 .88 44 .9 55 .91 66 .93 77 .95 ATs .94 ATo .63 A9s .91 A9o .24 A8s .9 A8o .15 A7s .53 A7o .11 A6s .42 A6o .08 A5s .88 A5o .13 A4s .88 A4o .11 A3s .57 A3o .09 A2s .44 A2o .06 KQs .93 KQo .9 KJs .91 KJo .88 KTs .9 KTo .86 K9s .87 K9o .06 K8s .85 K7s .56 K6s .57 K5s .46 K4s .25 K3s .17 K2s .11 QJs .9 QJo .54 QTs .88 QTo .46 Q9s .86 Q8s .56 Q7s .11 Q6s .12 Q5s .09 JTs .88 JTo .56 J9s .86 J8s .55 J7s .13 T9s .86 T9o .09 T8s .85 T7s .21 98s .86 97s .37 96s .09 87s .78 86s .15 76s .36 75s .11 65s .35 64s .07 54s .39`).
* mid-vs-short (22 absent): `Q2o J4o J3o J2o T5o T4o T3o T2o 94o 93o 92o 84o 83o 82o 73o 72o 63o 62o 52o 43o 42o 32o`; mixed: `Q3o .18 J6o .17 J5o .27 95o .09 74o .12`; everything else 1.

Read the full tables from the data file for the conversion; the lists above are the
regression fingerprint.

### 8.3 ICM solver (fictitious play in $EV)

```
solveScenario(sc): [sb0, bb0, o1, o2] = sc.stacks; eff = min(sb0, bb0)
  icmOf(sb, bb) = icmShares([sb, bb, o1, o2], PAYOUTS)
  sbFold  = icmOf(sb0 - 0.5, bb0 + 0.5)     // SB folds, BB collects the small blind
  jamFold = icmOf(sb0 + 1,   bb0 - 1)       // SB jams, BB folds the big blind
  sbWins  = icmOf(sb0 + eff, bb0 - eff)
  sbLoses = icmOf(sb0 - eff, bb0 + eff)
  strength/order as in 7.2; init jam[h] = 1 for top 68, call[h] = 1 for top 17
  for t = 1..200:
    // SB best response vs average call range
    callMass = Σ_l call[l]*W[l]; eVec[h] = Σ_l call[l]*W[l]*E[h][l]
    for h: eq = callMass > 0 ? eVec[h]/callMass : 0.5
           evJam = (1 - callMass)*jamFold[0] + callMass*(eq*sbWins[0] + (1-eq)*sbLoses[0])
           br = evJam > sbFold[0] ? 1 : 0;  jam[h] += (br - jam[h])/t
    // BB best response vs average jam range
    jamMass = Σ_l jam[l]*W[l]; eVec[h] = Σ_l jam[l]*W[l]*E[h][l]
    for h: eqBb = jamMass > 0 ? eVec[h]/jamMass : 0.5
           evCall = eqBb*sbLoses[1] + (1-eqBb)*sbWins[1]
           br = evCall > jamFold[1] ? 1 : 0;  call[h] += (br - call[h])/t
  sparse() as in 7.2 (drop < 0.05, > 0.95 -> 1, else 2 decimals)
```
Outcome vectors per scenario (baseline / sbFold / jamFold / sbWins / sbLoses, index 0 = SB, 1 = BB):
```
even:         base [.25 .25 .25 .25]        sbFold [.24676 .25321 …] jamFold [.25638 .24349 …] sbWins [.38333 0 .30833 .30833] sbLoses [0 .38333 .30833 .30833]
big-sb:       base [.35148 .18666 .23093 .23093] sbFold [.34939 .19064] jamFold [.35563 .17845] sbWins [.41 0 .295 .295] sbLoses [.28214 .28214 .21786 .21786]
short-sb:     base [.12714 .29095 …]        sbFold [.12189 .29431] jamFold [.1374 .28417] sbWins [.21786 .21786 .28214 .28214] sbLoses [0 .35429 .32286 .32286]
big-bb:       base [.23006 .35114 .20498 .21382] sbFold [.2268 .35308] jamFold [.23642 .34722] sbWins [.33105 .25997 .20001 .20896] sbLoses [0 .42258 .2863 .29112]
mid-vs-short: base [.28543 .1058 .30438 .30438] sbFold [.28171 .11145] jamFold [.2928 .09424] sbWins [.34188 0 .32906 .32906] sbLoses [.22232 .18716 .29526 .29526]
```

### 8.4 `scripts/golden/equity_matrix.json` (solver input)

`{ labels: string[169], equity: number[169][169] }`; `equity[i][j]` = preflop all-in
equity of `labels[i]` vs `labels[j]` (4 decimals, symmetric: `E[i][j] + E[j][i] = 1`,
diagonal 0.5). Examples: `E[AA][72o] = 0.8797`, `E[AA][KK] = 0.8188`. Label order
(also the order of every generated push/fold table):
```
AA AKs AKo AQs AQo AJs AJo ATs ATo A9s A9o A8s A8o A7s A7o A6s A6o A5s A5o A4s A4o A3s A3o A2s A2o
KK KQs KQo KJs KJo KTs KTo K9s K9o K8s K8o K7s K7o K6s K6o K5s K5o K4s K4o K3s K3o K2s K2o
QQ QJs QJo QTs QTo Q9s Q9o Q8s Q8o Q7s Q7o Q6s Q6o Q5s Q5o Q4s Q4o Q3s Q3o Q2s Q2o
JJ JTs JTo J9s J9o J8s J8o J7s J7o J6s J6o J5s J5o J4s J4o J3s J3o J2s J2o
TT T9s T9o T8s T8o T7s T7o T6s T6o T5s T5o T4s T4o T3s T3o T2s T2o
99 98s 98o 97s 97o 96s 96o 95s 95o 94s 94o 93s 93o 92s 92o
88 87s 87o 86s 86o 85s 85o 84s 84o 83s 83o 82s 82o
77 76s 76o 75s 75o 74s 74o 73s 73o 72s 72o
66 65s 65o 64s 64o 63s 63o 62s 62o
55 54s 54o 53s 53o 52s 52o
44 43s 43o 42s 42o
33 32s 32o
22
```
(i.e. for high rank A..2: the pair, then for each lower rank the suited then offsuit label).
Generated by `poker-core/examples/equity_matrix.rs`; ship the JSON as an asset or
convert it once to a Dart constant.

### 8.5 `scripts/golden/charts.json` (golden snapshot, 70 KB)

```
{ ranked: string[169],                        // rankedHands() order (section 0.2)
  topPct: { "1".."100": string[] },           // topPercentRange(p) contents, SORTED alphabetically
  bots:   { "<Archetype>:<Position>": { play: string[], raise: string[] } } }   // 24 entries
```
Archetypes TAG (vpip 22, pfr 18), LAG (34, 27), Nit (12, 9), Station (46, 7) ×
positions UTG MP CO BTN SB BB; `buildPreflopRanges(vpip, pfr, pos)`:
`mult = {UTG .5, MP .68, CO .9, BTN 1.25, SB .85, BB 1}`;
`playPct = clamp(vpip*mult, 4, 90)`; `raisePct = clamp(pfr*mult, 2, playPct)`;
play = topPercentRange(playPct), raise = topPercentRange(raisePct), each sorted.
`golden_test.ts` asserts all three parts are reproduced exactly (1 + 100 + 24 checks).

---

## 9. Test expectations to pin in Dart

### 9.1 `puzzles_test.ts` (9348 assertions today)
* `PREFLOP_100.rfi.UTG["AA"] == 1`; `rfi.UTG["72o"]` absent (0); `chartWidth(rfi.BTN) > chartWidth(rfi.UTG)`.
* 800 × `generatePuzzle()`: the invariants in section 1; all 7 cash kinds seen.
* 400 × `generatePushFold()`: kind pushfold, preflop, empty board, exactly 2 options, best offered & accepted, best grades correct.
* Leak replay example in 3.15: kind `leak`, best `fold`, hero seat BTN present, frames >= 2.

### 9.2 `preflop_test.ts` (52)
* Depth 100 present; RFI charts for UTG MP CO BTN SB each have > 20 labels; all 15 vsRfi pairs have both charts.
* All frequencies in (0, 1]; for every label `call + threebet <= 1.001`.
* RFI widths strictly increase UTG < MP < CO < BTN; UTG in (0.10, 0.20); BTN in (0.38, 0.52).
* `cont(BB_vs_BTN) > cont(BB_vs_UTG) + 0.1`; `cont(BTN_vs_CO) > cont(BTN_vs_UTG)`; `width(SB_vs_BTN.threebet) > width(SB_vs_UTG.threebet)` (cont = 3bet width + call width).
* `BB_vs_BTN.threebet["A5s"] > 0`; `BB_vs_UTG.threebet["KJo"] == 0`; `CO_vs_UTG.threebet["KJo"] == 0`; `threebet["AA"] == 1` for all 15 pairs; `rfi.UTG["72o"] == 0 && rfi.BTN["72o"] == 0`; `BTN_vs_CO.call["76s"] > 0`; `rfi.UTG["A5s"] > 0`.
* 800 generated puzzles: best among options and accepted; > 100 rfi and > 100 vs-raise among them.

### 9.3 `pushfold_test.ts` (111)
* For every stack in PUSHFOLD_STACKS: `NASH_SHOVE[S].SB` and `.BTN` exist; `NASH_CALL[S]["SB>BB"]` exists; `width(SB shove) > width(BTN shove)`; `SB shove["AA"] == 1`; `SB>BB call["AA"] == 1`.
* 10bb widths: UTG < MP < CO < BTN < SB.
* `width(SHOVE[5].SB) > width(SHOVE[10].SB) > width(SHOVE[20].SB)`; `width(CALL[5]["SB>BB"]) > width(CALL[15]["SB>BB"])`.
* `width(SHOVE[10].SB)` in (0.45, 0.68) (shipped 0.582); `width(CALL[10]["SB>BB"])` in (0.28, 0.48) (shipped 0.371).
* `SHOVE[10].BTN["72o"] == 0`; `SHOVE[10].SB["A2o"] == 1`; `width(CALL[10]["SB>BB"]) > width(CALL[10]["BTN>BB"])`.
* All weights in (0, 1]. 500 generated push/fold puzzles coherent.

### 9.4 `icm_test.ts` (23)
* The `icmShares` reference values of 8.1 (equal split within 1e-9; sums to 1; `dom[0]` in (0.4, 0.5); busted = 0; doubling < 2×).
* `ICM_SCENARIOS.length >= 5`; `width(even.call) < 0.6 × width(NASH_CALL[25]["SB>BB"])` (0.059 vs 0.165);
  `width(big-sb.jam) > 0.95`; `width(big-bb.jam) < 0.5 × width(even.jam)`; `width(even.jam) > width(NASH_SHOVE[25].SB)` (0.747 vs 0.353);
  `jam["AA"] == 1` and `call["AA"] == 1` for every scenario; all weights in (0, 1].

---

## 10. Port risks and deliberate quirks

1. **JS number formatting** in every template (`2.5` vs `3`, never `3.0`); **JS `Math.round`** (half toward +inf) for `r1`, Elo delta, and `round(freq*100)`.
2. **Bit-identical equity** requires porting `mulberry32`, `hashSeed`, the exact draw sequence in 0.3, and the same evaluator scores. If you accept a different estimator, the `band = max(0.02, 2·se)` logic still yields honest grades but individual deals may grade differently from the TS app.
3. **`equityVsRange` on turn/river is exhaustive** (up to ~1300 combos × 48 runouts × 2 evaluations on the turn) and `strengthSlice` runs 80-iteration MC per label — fine on desktop, measure on mobile; consider an isolate. The exploit templates loop up to 80 deals × 2 exact river/turn evaluations.
4. **Spread-merge quirk** in `genFacingCheckRaise` (3-bet freq overrides call freq for labels in both charts) — replicate or fix knowingly.
5. **`raiseTo` in `genVsRaise` keyed on hero seat**, not raiser seat (3 bb from the blinds, 2.5 otherwise).
6. **Leak spots in chips** (coach) vs bb (import) flow through the same EV/label code; `bb` field carries the unit.
7. **`active` seat flag** is computed but unused by the table UI; keep for fidelity or drop.
8. **`setMode` does not clear `focusKind/focusLeft`**; a pending "Drill 5 similar" resumes if you return to Mixed.
9. **ICM blurb text drift** between generator script and shipped data (8.2) — ship the data-file strings.
10. **Data volume**: preflop.ts ~9 KB JSON, pushfold.ts ~185 KB (400 tables), icmPushfold.ts ~8 KB, equity_matrix.json ~200 KB. Convert to Dart constants or bundled JSON assets; ~~label order inside maps must be preserved only for `gradeRange` display order~~ — **corrected in §11.1: label order need not be preserved at all.**
11. **Persistence keys** `allin.drills.v1`, `allin.review.v1`, `allin.leaks.v1` — review cards store whole `Puzzle` objects (with frames/options/rationale) so old puzzles replay verbatim after upgrades; keep the Puzzle JSON shape stable.
12. **Puzzle `id`** is a session-local counter (not persisted, restarts at 1); identity for de-duplication uses the review-card key string, not `id`.

---

## 11. Errata and addenda (verified against the shipped TS)

These three sections supersede or complete the paragraphs they name. Everything
below was checked by running the TS sources and, where a Dart divergence is
claimed, by running Dart. Nothing here changes the answer key or any width.

### 11.1 SUPERSEDES §6.1 ("Map insertion order = token expansion order") and §10.10

**Correct rule: chart key order is not load-bearing. Any label ordering is
acceptable in the Dart port.** Use a plain `Map<String, double>` literal, a
`HashMap`, a sorted map, whatever is convenient. Do not write a golden test that
asserts key order, and do not try to reproduce the order in the shipped file.

The old note was wrong twice over.

**(a) The shipped key order is NOT the expansion order.** The generator ends with
`JSON.stringify({ rfi, vsRfi })`, and JS/V8 own-property ordering puts
*canonical integer-index* string keys first, in ascending numeric order, ahead of
all other string keys (which then follow in insertion order). `JSON.stringify`
emits keys in that same order. Among hand labels, exactly eight are
integer-index-like — the pair labels `22 33 44 55 66 77 88 99`. `TT JJ QQ KK AA`
are not numeric, and neither are three-character labels such as `98s` / `98o`.
So in every chart the 22–99 pairs get hoisted to the front in ascending order,
and everything else keeps insertion order.

Worked examples (`expand` = the order `expandToken` actually calls `put()` in;
`shipped` = `Object.keys()` of the chart in `src/data/preflop.ts`):

```
MP_vs_UTG.call   ← "88-JJ 77:0.5 AQs AJs ATs:0.5 KQs QJs:0.5 JTs T9s:0.5 AQo:0.5"
  expand : JJ TT 99 88 77 AQs AJs ATs KQs QJs JTs T9s AQo
  shipped: 77 88 99 JJ TT AQs AJs ATs KQs QJs JTs T9s AQo

BTN_vs_CO.call   ← "22-99 A2s+ KTs+ ..."
  expand : 99 88 77 66 55 44 33 22 A2s A3s ...
  shipped: 22 33 44 55 66 77 88 99 A2s A3s ...

BB_vs_SB.threebet ← "88+ A9s+ ATo+ KQo A5s-A2s:0.75 KTs+ QJs:0.5 JTs:0.5 T9s:0.5 77:0.5"
  expand : 88 99 TT JJ QQ KK AA A9s ... QJs JTs T9s 77      (77 emitted LAST)
  shipped: 77 88 99 TT JJ QQ KK AA A9s ... QJs JTs T9s      (77 ships FIRST)
```

**18 of the 35 shipped charts** (5 rfi + 15×2 vsRfi) have a key order that differs
from their expansion order: `MP_vs_UTG.call, CO_vs_UTG.call, CO_vs_MP.call,
BTN_vs_UTG.call, BTN_vs_MP.call, BTN_vs_CO.call, SB_vs_UTG.call, SB_vs_MP.call,
SB_vs_CO.threebet, SB_vs_CO.call, SB_vs_BTN.threebet, SB_vs_BTN.call,
BB_vs_UTG.call, BB_vs_MP.call, BB_vs_CO.call, BB_vs_BTN.call, BB_vs_SB.threebet,
BB_vs_SB.call`. (The five `rfi` charts happen to match only because every one of
them starts with `22+`, which already emits 22→AA ascending.)

**(b) Nothing consumes chart key order.** There are exactly three read sites for a
`ChartFreqs` map, and all three are order-free:

| Site | What it does | Order-sensitive? |
|---|---|---|
| `chartLabels05` (`puzzles.ts:91`) | `Object.entries(chart).filter(f >= 0.5).map(l)` → `HandLabel[]` | list order is produced, never read (see below) |
| `chartToSet` (`ranges.ts:135`) | builds a `Set<HandLabel>` | no |
| `chartWidth` (`ranges.ts:141`) | `w += f * comboCount(l)`, then `/1326` | no — see the float note below |

The `HandLabel[]` from `chartLabels05` is the only thing that ever reaches the UI,
as `Puzzle.gradeRange`, and `DrillControls.tsx:161` converts it straight back to a
set before rendering:

```tsx
<RangeMatrix highlight={new Set(puzzle.gradeRange)} readOnly size={260} />
```

`RangeMatrix` then walks its own fixed 13×13 grid and only ever asks
`highlight?.has(label)` (`RangeMatrix.tsx:77`). The list order is discarded. The
same applies to the merged forms `[...new Set([...chartLabels05(a), ...chartLabels05(b)])]`
(`puzzles.ts:270`) and `chartLabels05({ ...call, ...threebet })` (`puzzles.ts:585`,
`:671`) — for those two the *spread-merge value* precedence still matters (quirk
§10.4), but the resulting key order still does not.

Float note on `chartWidth`: summing doubles is order-sensitive in general, but not
here. The only frequencies in the shipped data are `0.25, 0.5, 0.75, 1` and the only
combo counts are `4, 6, 12`, so every addend is an exact multiple of `0.5` below `12`
and every partial sum stays well inside the exactly-representable range. Verified:
all 35 charts give a bit-identical (`Object.is`) width under 400 random key
shufflings each. So `chartWidth` is safe to compute over an unordered Dart map.

**Porting guidance.** Either paste the JSON from `src/data/preflop.ts` (hoisted
order and all — harmless) or regenerate the maps from the §6.3 range strings with
your own expander. Both produce the same map; only iteration order differs, and
that is unobservable. §10.10's clause *"label order inside maps must be preserved
only for `gradeRange` display order"* should be read as **"label order inside maps
need not be preserved at all."**

### 11.2 COMPLETES §6.2 — the pair-run token emits high-to-low

§6.2 pins the emission order of three of the four token forms by example but
leaves the pair run as "`77-99` -> the inclusive run (either order)". Pinned:

```js
} else if (core.includes("-")) {
  const r2 = ri(core.split("-")[1][0]);
  const [lo, hi] = [Math.max(r, r2), Math.min(r, r2)];   // NB: names are inverted —
  for (let i = hi; i <= lo; i++) put(RANKS[i] + RANKS[i]); //  `lo` holds the LARGER index
}
```

`RANKS = "AKQJT98765432"`, so a larger index is a *lower* rank. The loop walks
indices ascending, i.e. **ranks descending**:

```
88-JJ  ->  JJ TT 99 88          (ri('J')=3 .. ri('8')=6)
77-99  ->  99 88 77
22-88  ->  88 77 66 55 44 33 22
```

"Either order" refers only to the *input*: `JJ-88` and `88-JJ` are normalised by
the `max`/`min` and emit the identical sequence `JJ TT 99 88`. The *output* order
is fixed.

All four token forms, unified — the `+` forms walk the `RANKS` index **descending**
(low rank → high rank); the `-` run forms walk it **ascending** (high rank → low rank):

| Form | Loop | Example | Emission order |
|---|---|---|---|
| pair `+` | `for (i = r; i >= 0; i--)` | `TT+` | `TT JJ QQ KK AA` (low→high) |
| pair run `-` | `for (i = hi; i <= lo; i++)` | `88-JJ` | `JJ TT 99 88` (high→low) |
| kicker `+` | `for (i = l; i > h; i--)` | `A2s+` | `A2s A3s … AKs` (low→high) |
| kicker run `-` | `for (i = min(a,b); i <= max(a,b); i++)` | `Q9s-Q6s` | `Q9s Q8s Q7s Q6s` (high→low) |

Kicker runs are likewise input-order-agnostic (`Q6s-Q9s` == `Q9s-Q6s`).

Consequence is confined to the JSON key order of the generated file and hence to
the `chartLabels05` / `gradeRange` list order — which §11.1 shows is cosmetic. The
expander is now fully specified: matching this table is sufficient, not necessary.

### 11.3 COMPLETES §5.2 — `fmtSigned` and negative zero; JS vs Dart `round`

§5.2's formatter block gives `fmtSigned(n, digits=1): v = round(n*10^d)/10^d;
(v >= 0 ? "+" : "") + v.toFixed(d)` and omits two behaviours that a literal Dart
transcription gets wrong. (`drill-ux-srs-leaks.md` §8.7 and §12.11 already carry
the fix; this section makes this document self-contained and matches it.)

**What JS actually does.** `Math.round(x)` returns `-0` for every `x` in
`[-0.5, 0)` — including the endpoint, because JS rounds halves toward `+∞`
(`Math.round(-0.5) === -0`). Then `-0 >= 0` is `true`, so the `"+"` branch is
taken, and `(-0).toFixed(1) === "0.0"` (no sign). Net effect:

```
fmtSigned(-0.04)  === "+0.0"       fmtSigned(-0.05)  === "+0.0"
fmtSigned(-0.049) === "+0.0"       fmtSigned(-0.051) === "-0.1"
fmtSigned(-0.4, 0) === "+0"        fmtSigned(-0.5, 0) === "+0"
```
i.e. **`fmtSigned(n)` prints `+0.0` for every `n` in `[-0.05, 0)`**, and
`fmtSigned(n, 0)` prints `+0` for every `n` in `[-0.5, 0)`.

**Two distinct Dart traps.**

1. *Sign of zero.* `-0.0 >= 0` is `true` in Dart too, so the `"+"` is prepended —
   but `(-0.0).toStringAsFixed(1)` is `"-0.0"`, which already carries a sign. A
   port using `(n * pow(10, d)).roundToDouble() / pow(10, d)` therefore renders the
   literal string **`"+-0.0"`**, not `"-0.0"`. Verified in Dart for
   `-0.003, -0.02, -0.049, -0.0`.
2. *Half-rounding direction.* Dart's `num.round()` rounds halves **away from zero**;
   JS's `Math.round` rounds them toward `+∞`. They disagree on every negative half:
   `Math.round(-0.5) === -0` vs `(-0.5).round() == -1`; `Math.round(-1.5) === -1`
   vs `(-1.5).round() == -2`. Note this also rescues trap 1 by accident when the
   port uses the *integer*-returning `.round()` (Dart ints have no `-0`), which is
   why the two traps must be fixed together rather than one at a time.

**The fix** — use `jsRound` (defined in `drill-ux-srs-leaks.md` §12) plus the `-0`
normalisation from its §8.7:

```dart
double jsRound(num x) => (x + 0.5).floorToDouble();   // == JS Math.round

String fmtSigned(num n, [int digits = 1]) {
  var v = jsRound(n * pow(10, digits)) / pow(10, digits);
  if (v == 0) v = 0;                     // normalise -0.0 → 0.0
  return (v >= 0 ? "+" : "") + v.toStringAsFixed(digits);
}
```

`jsRound` never returns `-0.0` (for `x` in `[-0.5, 0)`, `x + 0.5` is in `[0.0, 0.5)`
and `floorToDouble()` gives `+0.0`), so the `if (v == 0) v = 0;` line is
belt-and-braces once `jsRound` is used — keep it anyway, and keep it mandatory if
you use any other rounding.

**Verification sweep** (`n = i/1000` for `i` in `[-2000, 2000]`, 4001 values, both
`digits == 1` and `digits == 0`, compared against the TS output):

* `jsRound` + `-0` normalisation: **0 / 4001 mismatches**.
* naive `(n * pow(10, d)).roundToDouble() / pow(10, d)`: **516 / 4001 mismatches**
  (the `"+-0.0"` band plus every negative half-step: `-1.95 → "-2.0"` where JS
  gives `"-1.9"`, `-1.85 → "-1.9"` vs `"-1.8"`, and so on).

**Where this is user-visible.** `DrillControls.tsx:136`, the postflop math block
shown whenever `equity`, `potOdds` are present and `toCall > 0`:

```
Calling: {fmtSigned(equity * (pot + toCall) - toCall)} bb per try — …
```

Marginal calls cluster right at break-even pot odds, so the `[-0.05, 0)` band is
routinely hit. Concrete reachable case — `equity = 0.333`, `pot = 6`, `toCall = 3`
(raw EV `-0.003`), which renders verbatim in the TS app as:

```
Folding: 0 bb — costs nothing more.
Calling: +0.0 bb per try — your hand wins about 1 time in 3 and you need about 1 time in 3.
Equity: 33%
Pot odds: 33%
```

A naive Dart port renders `Calling: +-0.0 bb per try — …` for the same spot.

The other `fmtSigned` call site, `fmtSigned(ratingDelta, 0)` at
`DrillControls.tsx:113`, is guarded by `ratingDelta !== 0`, and `-0 !== 0` is
`false` in JS, so a `-0` Elo delta hides the badge rather than printing `+0`.
Dart agrees (`-0.0 == 0` is `true`), and an `int` delta can never be `-0`, so
there is no divergence there — but only if you compare with `!= 0` and not with
`identical(...)` or a sign test.

**Rest of `src/lib/format.ts`, for completeness** (so the port never needs the TS):
every remaining helper rounds via `Math.round` and needs the same `jsRound`
substitution — `fmtBb`, `fmtTimes`, `fmtNeed` (all specified in §5.2 /
`drill-ux-srs-leaks.md` §8.7), plus one helper this subsystem never calls:

```
fmtBb(chips, bb):   v = chips/bb; r = round(v*10)/10;
                    Number.isInteger(r) ? String(r) : r.toFixed(1)     // "12" or "12.5"
fmtChips(n):        Math.round(n).toLocaleString()                     // NOT USED anywhere
                    // outside format.ts — the drills/table UI is all bb. If you do port it,
                    // note toLocaleString() uses the JS runtime's default locale
                    // (en-US → "1,500"); pick an explicit Dart NumberFormat rather than
                    // inheriting the device locale.
```

`fmtPct` (`(frac*100).toFixed(d) + "%"`) does no rounding of its own and ports
directly to `toStringAsFixed`. JS `Number.prototype.toFixed` and Dart
`num.toStringAsFixed` agree: both round decimal halves away from zero
(`(-0.5).toFixed(0) === "-1"`, `(-0.125).toFixed(2) === "-0.13"`, same in Dart).
Verified over 400,001 values (`n = i/10000`, `i` in `[-200000, 200000]`, at
`digits` 0, 1 and 2): **0 mismatches**. This is the one rounding path in
`format.ts` that does NOT need `jsRound` — `Math.round` is half-toward-`+inf`,
`toFixed` is half-away-from-zero, and only the former diverges from Dart.
