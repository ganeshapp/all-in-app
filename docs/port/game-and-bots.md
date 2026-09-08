# Port spec: game engine, bots, and hand-history export

Source of truth (TypeScript, do not read unless this doc is ambiguous):

- `src/types/poker.ts` — domain types
- `src/game/engine.ts` — pure hand state machine
- `src/game/archetypes.ts` — the four bot archetypes, names, seat assignment
- `src/game/botBrain.ts` — bot decision policy + range narrowing
- `src/game/handHistory.ts` — PokerStars-style export + replay frames
- `scripts/sim_test.ts`, `scripts/bot_test.ts`, `scripts/hh_test.ts`, `scripts/table_config_test.ts` — the tests that pin behaviour
- `src/store/gameStore.ts` (only the parts that feed this subsystem: dial jitter, archetype pool, hand-history recording)

Everything below is written so a Dart engineer can re-implement the behaviour
exactly without opening the TypeScript. Where the TS is intricate, pseudocode
in a Dart-like style is given. All chip amounts are integers.

---

## 0. Dependencies on other subsystems (contracts this code relies on)

These live in `src/engine/*` and `src/data/preflop.ts` and are documented in
their own port docs; the engine and bots use them through these contracts.

| Symbol | Contract |
|---|---|
| `Card` | 2-char string: rank char + suit char. Ranks `2 3 4 5 6 7 8 9 T J Q K A`, suits `c d h s`. Example `"Ah"`, `"Td"`. |
| `RANKS` | `["2","3","4","5","6","7","8","9","T","J","Q","K","A"]` (ascending). |
| `SUITS` | `["c","d","h","s"]`. |
| `RANKS_DESC` | `["A","K","Q","J","T","9","8","7","6","5","4","3","2"]`. |
| `makeDeck()` | 52 cards in order: for each rank in `RANKS`, for each suit in `SUITS` → `"2c","2d","2h","2s","3c",…,"As"`. |
| `shuffle(list)` | In-place Fisher–Yates: `for i = n-1 down to 1: j = floor(random()*(i+1)); swap(i, j)`. Uses the global RNG (`Math.random`). |
| `cardToInt(card)` | `rankIndex*4 + suitIndex` where rankIndex = index in `RANKS` (0..12 for 2..A), suitIndex = index in `SUITS` (c=0,d=1,h=2,s=3). So `"2c"`=0, `"As"`=51. Rank value 2..14 of an int `c` is `(c >> 2) + 2`; suit index is `c & 3`. |
| `evaluateCards(cards)` / `evaluateInts(ints)` | 5–7 card evaluator returning `{category, score, name}`. `score` is a monotonic integer (higher = better), safe to compare across any hands. `name` strings are exactly: `"Royal Flush"`, `"Straight Flush, <R> high"`, `"Four of a Kind, <Rs>"`, `"Full House, <Rs> full of <Rs>"`, `"Flush, <R> high"`, `"Straight, <R> high"`, `"Three of a Kind, <Rs>"`, `"Two Pair, <Rs> & <Rs>"`, `"Pair of <Rs>"`, `"<R> High"`, where `<R>` is `Ace King Queen Jack Ten Nine Eight Seven Six Five Four Three Two` and `<Rs>` the plural (`Aces … Sixes … Twos`). |
| `equityVsRandom(hero:[int,int], board:[int], iters=1200, seed?)` | Hero equity (win + tie/2, fraction 0..1) vs one uniformly random opponent hand. **River (5 board cards) is enumerated exactly**; earlier streets are Monte-Carlo with `iters` samples. With a `seed` the result is deterministic (mulberry32 PRNG); without, uses the global RNG. |
| `equityVsRange(hero, board, rangeCombos:[[int,int]], iters=1500, seed?)` | Hero equity vs a uniformly weighted list of opponent combos. Combos sharing a card with hero/board are dropped first; if none remain, returns equity `0.5`. **Turn and river (board length ≥ 4) are enumerated exactly**; flop is Monte-Carlo. |
| `hashSeed(string)` | FNV-1a 32-bit: `h = 0x811c9dc5; for each UTF-16 code unit: h ^= code; h = (h * 0x01000193) mod 2^32`. Result unsigned 32-bit. |
| `comboToInts([Card,Card])` | `[cardToInt(a), cardToInt(b)]`. |
| `allLabels()` | The 169 grid labels in row-major order over `RANKS_DESC`: row r, col c → pair if r==c (`"AA"`), suited if c>r (`"AKs"`), offsuit if r>c (`"AKo"`). So the order starts `AA, AKs, AQs, …, A2s, AKo, KK, KQs, …`. |
| `cardsToLabel(a, b)` | Grid label of two concrete cards: higher rank first (by `RANKS_DESC` index), pair → `"QQ"`, same suit → `"AKs"`, else `"AKo"`. |
| `labelToCombos(label)` | Concrete combos, **in this order**: pair `XX` → `[Xc,Xd],[Xc,Xh],[Xc,Xs],[Xd,Xh],[Xd,Xs],[Xh,Xs]`; suited `XYs` → `[Xc,Yc],[Xd,Yd],[Xh,Yh],[Xs,Ys]`; offsuit `XYo` → for s1 in SUITS, for s2 in SUITS, s1≠s2 → `[X s1, Y s2]` (12 combos). The order matters for `narrowRange` (see §6.7). |
| `PREFLOP_100` | The 100bb 6-max chart set. Schema: `{ rfi: {POS: {label: freq}}, vsRfi: {KEY: {threebet: {label: freq}, call: {label: freq}}} }`. `freq` ∈ {0.25, 0.5, 0.75, 1}; absent label = 0. `rfi` keys: `UTG, MP, CO, BTN, SB` (**no BB**). `vsRfi` keys (exactly these 15): `MP_vs_UTG, CO_vs_UTG, CO_vs_MP, BTN_vs_UTG, BTN_vs_MP, BTN_vs_CO, SB_vs_UTG, SB_vs_MP, SB_vs_CO, SB_vs_BTN, BB_vs_UTG, BB_vs_MP, BB_vs_CO, BB_vs_BTN, BB_vs_SB`. File: `src/data/preflop.ts` (a single JSON literal, mechanically convertible). Key insertion order inside each chart is the JSON order in that file; `chartLabels()` (§6.2) preserves it. |

---

## 1. Domain types (`src/types/poker.ts`)

Dart-like rendering. Field comments are semantics the engine relies on.

```dart
typedef Card = String;                // "Ah"
enum Suit { c, d, h, s }
// Rank chars: 2..9, T, J, Q, K, A

const handCategory = {                // weakest → strongest
  HighCard: 0, Pair: 1, TwoPair: 2, Trips: 3, Straight: 4,
  Flush: 5, FullHouse: 6, Quads: 7, StraightFlush: 8 };
const handCategoryNames = {
  0: "High Card", 1: "Pair", 2: "Two Pair", 3: "Three of a Kind",
  4: "Straight", 5: "Flush", 6: "Full House", 7: "Four of a Kind",
  8: "Straight Flush" };

class EvaluatedHand { int category; int score; String name; }

typedef HandLabel = String;           // "AKs", "AKo", "TT"

enum Position { UTG, MP, CO, BTN, SB, BB }
enum Street   { preflop, flop, turn, river, showdown }
enum ActionType { fold, check, call, bet, raise, post }

class Action {
  ActionType type;
  int? amount;      // bet/raise: TOTAL chips in front of the player on this street ("raise to")
                    // call: the chips called (informational; the engine recomputes it)
  bool? allIn;      // informational only; the engine never reads it
}

enum Archetype { TAG, LAG, Nit, Station }

class ArchetypeConfig {
  Archetype archetype; String name; String blurb;
  int vpip; int pfr; int cbetFlop;    // percentages
  double aggression;                  // biases bet/raise vs call postflop
  double stickiness;                  // calldown tendency 0..1
  String color;                       // hex
}

class PlayerLastAction { String label; Street street; }
// label ∈ "SB","BB","Fold","Check","Call","Bet","Raise","All-In"

class Dials {                       // TS: dials?: { aggression, stickiness, cbetFlop }
  double aggression;                // 0.05..0.95 after jitter
  double stickiness;                // 0.05..0.95 after jitter
  double cbetFlop;                  // PERCENT, 20..95 after jitter; fractional (not int)
}
// All three are plain `number` in TS and always present together (the whole
// object is optional, never a partial). Built once per session in `newSession`
// (§5.1) and read in botBrain as `{...ARCHETYPES[archetype], ...(dials ?? {})}`,
// so a bot's dials override the archetype's aggression/stickiness/cbetFlop.

class Player {
  int id;                 // seat index 0..n-1; seat 0 is ALWAYS the hero
  String name;            // "You" for hero, else botNameFor(seat)
  bool isHero;
  Archetype? archetype;   // null for hero
  int stack;
  List<Card>? hole;       // exactly 2 when dealt
  bool revealed;          // cards shown (showdown, or end-of-hand learning reveal)
  Street? foldedStreet;   // set when the player folds
  bool hasFolded;
  bool isAllIn;
  int committed;          // chips put in on the CURRENT street (antes excluded)
  int committedTotal;     // chips put in this hand across all streets (antes included)
  bool acted;             // has acted since the last full bet/raise on this street
  Position position;
  PlayerLastAction? lastAction;
  int handsSeen;          // observed-stat counters for the HUD
  int vpipCount;
  int pfrCount;
  bool? vpipThisHand;     // transient per-hand flags behind the counters
  bool? pfrThisHand;
  Dials? dials;           // per-session jitter {aggression, stickiness, cbetFlop}
  bool sittingOut;        // always false; never read by the engine
}

enum GamePhase { idle, betting, streetEnd, showdown, handOver }
// The engine only ever produces "idle", "betting", "hand-over".

class PotResult { List<int> winners; int amount; String potLabel; } // "Pot" | "Main pot" | "Side pot 1" …
class ShowdownEntry { int playerId; List<Card> hole; EvaluatedHand? hand; bool hadToShow; }
class HandSummary {
  int handNumber; List<PotResult> potResults; List<ShowdownEntry> showdown;
  List<Card> board; int heroNetChips;   // hero stack now − hero stack at hand start (blinds/antes included)
}
class LogEntry { int id; Street street; String text; String kind; } // kind ∈ action|deal|result|info

class GameConfig {
  int seats;           // 2, 6, or 9
  int startingStack;   // chips
  int smallBlind; int bigBlind;
  int? ante;           // optional per-player ante in chips
}

class LegalActions {
  int toCall; bool canFold; bool canCheck; bool canCall; int callAmount;
  bool canBet; bool canRaise;
  int minRaiseTo;      // minimum legal TOTAL bet/raise this street
  int maxRaiseTo;      // all-in total
  int potSize; int bigBlind;
}

class GameState {
  GameConfig config; List<Player> players;
  int button;                       // seat index
  Street street; List<Card> board; List<Card> deck;
  int pot;                          // total chips in the middle (never zeroed at hand end; see §3.10)
  int currentBet;                   // highest `committed` on the current street
  int lastRaiseSize;                // size of the last FULL bet/raise (min-raise math)
  int? aggressor;                   // seat of the last bettor/raiser this street
  int? toAct;                       // seat to act, null when nobody
  int handNumber;
  int smallBlind; int bigBlind;     // copies of config values
  GamePhase phase;
  List<LogEntry> log; int logSeq;
  Map<int, List<HandLabel>> botRanges;   // per-bot perceived range (for Peek)
  List<int> stacksAtStart;          // per seat, captured at deal time (before antes/blinds)
  HandSummary? summary;
}
```

Immutability: every engine entry point (`startHand`, `applyAction`) deep-copies
the state it receives and returns the copy. The caller's previous state is
never mutated. In Dart, either copy the same way or use immutable value
classes; the important observable is that a caller can keep old states.

---

## 2. Constants and magic numbers (whole subsystem)

| Where | Value | Meaning |
|---|---|---|
| engine | `POS6 = [BTN, SB, BB, UTG, MP, CO]` | position by offset from button, 6 seats |
| engine | `POS9 = [BTN, SB, BB, UTG, UTG, MP, MP, CO, CO]` | 9 seats approximated onto the six chart labels |
| engine | log cap `200` | oldest entries dropped beyond 200 |
| engine | `logSeq` starts at `1` | |
| engine | burn 1 card before flop/turn/river | |
| archetypes | see §5 table | VPIP/PFR/cbet/aggression/stickiness per archetype |
| archetypes | `BOT_NAMES` (10) | `Ivey, Negreanu, Polk, Selbst, Hellmuth, Brunson, Antonius, Dwan, Galfond, Chidwick` |
| archetypes | seat order | `[TAG, Station, LAG, Nit, TAG, LAG]` |
| store | `BASE_CONFIG` | `{seats: 6, startingStack: 2000, smallBlind: 10, bigBlind: 20}` |
| store | `ARCHE_POOL` | `[TAG, LAG, Nit, Station]` (uniform random per bot seat per session) |
| store | dial jitter | aggression ±20% clamped [0.05, 0.95]; stickiness ±20% clamped [0.05, 0.95]; cbetFlop ±15% clamped [20, 95] |
| bot | `DIALS` | see §6.1 |
| bot | `PREMIUM` | `{AA, KK, QQ, AKs, AKo}` never fold preflop |
| bot | open raise size | `(2.5 + limpers) * bb` |
| bot | BB raise over limps | `(3 + limpers) * bb` |
| bot | 3-bet size | `currentBet * 3.2` |
| bot | 4-bet size | `currentBet * 2.6` |
| bot | `facing3bet` | `currentBet > 4.5 * bb` |
| bot | limp price | `callAmount <= bb` |
| bot | speculative 3-bet call cap | `callAmount <= 12 * bb` |
| bot | equity iterations | vs range `260`; vs random `320`; range-narrowing `80` |
| bot | monster / value / c-bet equity thresholds | `> 0.8`, `> 0.6`, `> 0.4` |
| bot | slowplay prob | wet `0.08`, dry `0.28` |
| bot | monster sizings | wet `1.0` pot; dry one of `[0.66, 0.75, 1.25]` pot |
| bot | value sizing | wet `0.75`, dry `0.55` pot |
| bot | c-bet sizing | `0.33` pot |
| bot | bluff sizing | `0.66` pot |
| bot | bluff prob | strong draw `aggression*0.55`, weak draw `aggression*0.28`, scare card (board high card ≥ Q, not flop) `aggression*0.12` |
| bot | value raise | `e > 0.72`, prob `aggression * (e > 0.85 ? 1 : 0.6)`, size `currentBet + pot*(wet ? 1.0 : 0.8)` |
| bot | semi-bluff raise | strong draw, not river, prob `aggression*0.3*multiDamp`, size `currentBet + pot*0.9` |
| bot | call rule | `min(0.95, e + draw*0.05 [not river]) >= potOdds * (1 - stickiness*0.5)` |
| bot | station call | `stickiness > 0.7 && callAmount <= pot*0.5` with prob `0.7` |
| bot | narrowRange | skip if range ≤ 8 labels; aggro keeps top `max(5, round(0.45n))` + tail from `round(0.85n)`; call keeps top `max(6, round(0.65n))`; check drops top `round(0.12n)` |
| bot | texture | flushy: `max suit count >= min(3, boardLen)`; straighty: some 5-rank window holds ≥ 3 board ranks |
| HH | `exportHandId = startedAt*100 + (id % 100)` | |
| HH | table name `'All-In Dojo'`, timezone suffix ` ET`, `Rake 0` | |
| HH | session separator | three newlines between hands (`"\n\n\n"`) |

---

## 3. Engine (`src/game/engine.ts`)

Public API:

```dart
GameState createTable(GameConfig config);
GameState startHand(GameState prev);
LegalActions legalActions(GameState s);
GameState applyAction(GameState prev, int seat, Action action);
Player heroSeat(GameState s);                   // players[0]
List<Player> playersLeftOfButtonOrder(GameState s); // seats (button+1 … button+n) mod n
bool isHeroTurn(GameState s);                   // phase == betting && toAct == 0
```

### 3.1 `createTable(config)`

- Creates `config.seats` players, ids `0..n-1`. Seat 0: `name "You"`, `isHero true`, `archetype null`. Other seats: `name = botNameFor(i)`, `archetype = archetypeForSeat(i)` (§5). All: `stack = startingStack`, `hole null`, flags false, `committed 0`, `committedTotal 0`, `position BTN` (placeholder), `lastAction null`, counters 0, `sittingOut false`.
- `button = floor(random() * seats)` (random first button).
- `street preflop`, `board []`, `deck []`, `pot 0`, `currentBet 0`, `lastRaiseSize = bigBlind`, `aggressor null`, `toAct null`, `handNumber 0`, `smallBlind/bigBlind` copied, `phase "idle"`, `log []`, `logSeq 1`, `botRanges {}`, `stacksAtStart = [stack of each player]`, `summary null`.

### 3.2 Positions — `assignPositions`

`off = (seat - button + n) mod n` for each seat.

| seats | rule |
|---|---|
| 2 | `off 0 → BTN`, `off 1 → BB`. (Heads-up: the button IS the small blind; there is no seat labelled SB.) |
| 6 | `POS6[off]` = `BTN, SB, BB, UTG, MP, CO` |
| 9 | `POS9[off]` = `BTN, SB, BB, UTG, UTG, MP, MP, CO, CO` |
| other | `off 0 → BTN, 1 → SB, 2 → BB, else MP` (defensive; not a supported config) |

### 3.3 `commit(s, p, amount)` (internal)

```
amt = max(0, min(amount, p.stack))
p.stack -= amt; p.committed += amt; p.committedTotal += amt; s.pot += amt
if (p.stack == 0) p.isAllIn = true
```

`postBlind(seat, amount, label)` = `commit` + `lastAction = {label, "preflop"}`.
A short blind is capped at the stack and may put the poster all-in.

### 3.4 `startHand(prev)`

1. Deep-copy; `handNumber += 1`; **if `handNumber > 1`** advance `button = (button + 1) mod seats` (the first hand keeps the random button from `createTable`).
2. For every player: `if stack <= 0 → stack = startingStack` (auto-rebuy for continuous training); `hole null`, `revealed false`, `hasFolded false`, `foldedStreet null`, `vpipThisHand false`, `pfrThisHand false`, `isAllIn false`, `committed 0`, `committedTotal 0`, `acted false`, `lastAction null`; **`handsSeen += 1`** (every seated player, every hand).
3. `board []`, `pot 0`, `currentBet = bigBlind`, `lastRaiseSize = bigBlind`, `aggressor null`, `summary null`, `street preflop`, `phase betting`, `botRanges {}`; `assignPositions`.
4. `deck = shuffle(makeDeck())`; then **for each player in seat order 0..n-1**: `hole = [deck.removeLast(), deck.removeLast()]`. (Cards come off the END of the deck list.)
5. `stacksAtStart = current stacks` — captured **after** rebuy and **before** antes/blinds.
6. Antes: `ante = config.ante ?? 0`; if `> 0`, for every player: `a = min(ante, stack)`; `stack -= a`; `committedTotal += a`; `pot += a`; `if stack == 0 → isAllIn = true`. **`committed` is NOT touched** — antes never count toward matching the street bet, only toward side-pot totals.
7. Blinds: heads-up → `sbSeat = button`, `bbSeat = button+1`; otherwise `sbSeat = button+1`, `bbSeat = button+2` (mod n). `postBlind(sb, smallBlind, "SB")`, `postBlind(bb, bigBlind, "BB")`. `aggressor = bbSeat`.
   Note `currentBet` was already set to `bigBlind` in step 3 and is not reduced if the BB is short.
8. Log (kind `deal`, street `preflop`): `` `Hand #${handNumber} · blinds ${smallBlind}/${bigBlind}` `` followed by `` ` · ante ${ante}` `` only when `ante > 0`. (The separator is ` · ` — space, U+00B7 middle dot, space.)
9. First to act: heads-up → `nextLiveActor(sbSeat, inclusive)` (button/SB acts first preflop); otherwise `nextLiveActor(button + 3, inclusive)` (UTG).

### 3.5 Seat iteration helpers

```
nextLiveActor(start, inclusive):
  // first seat from `start` that is neither folded nor all-in; checks n seats
  for k in (inclusive ? 0 : 1) .. (inclusive ? n-1 : n):
    q = (start + k) mod n
    if (!folded[q] && !allIn[q]) return q
  return null

nextToAct(fromSeat):
  // next seat that still owes an action on this street
  for k in 1..n:
    q = (fromSeat + k) mod n
    if (folded[q] || allIn[q]) continue
    if (!acted[q] || committed[q] < currentBet) return q
  return null

resetActedExcept(seat):
  for every player != seat that is not folded and not all-in: acted = false
```

`nextToAct` can return `fromSeat` itself at `k == n` only if that seat still
owes chips (never after a legal action).

### 3.6 `legalActions(s)`

If `toAct == null` return all-false/zero with `potSize = pot`, `bigBlind`.
Otherwise for `p = players[toAct]`, `toCall = currentBet - p.committed`,
`maxTotal = p.committed + p.stack`:

| field | value |
|---|---|
| `toCall` | `currentBet - committed` (may be ≤ 0) |
| `canFold` | **always `true`** (even when a check is free; the UI decides whether to offer it) |
| `canCheck` | `toCall <= 0` |
| `canCall` | `toCall > 0 && stack > 0` |
| `callAmount` | `min(toCall, stack)` |
| `canBet` | `currentBet == 0 && stack > 0` |
| `canRaise` | `currentBet > 0 && stack > toCall` (any extra chip allows a raise; a short all-in raise is legal) |
| `minRaiseTo` | `currentBet == 0 ? min(bigBlind, maxTotal) : min(currentBet + lastRaiseSize, maxTotal)` |
| `maxRaiseTo` | `maxTotal` |
| `potSize` | `pot` |
| `bigBlind` | `bigBlind` |

Preflop with no raise: `currentBet = bb`, `lastRaiseSize = bb` → `minRaiseTo = 2bb`.

**The engine does not validate legality in `applyAction`.** Callers (UI, bots,
tests) must only submit actions that `legalActions` allows, and must clamp
bet/raise amounts to `[minRaiseTo, maxRaiseTo]`. Submitting an illegal check
while chips are owed would leave the player re-selected by `nextToAct` forever.

### 3.7 `applyAction(prev, seat, action)`

Deep-copy to `s`. **If `phase != betting` or `toAct != seat`, return the copy
unchanged** (silent no-op). Let `p = players[seat]`, `toCall = currentBet -
p.committed`, `maxTotal = p.committed + p.stack`, `street = s.street`.

| type | effect | `lastAction.label` | log text (kind `action`) |
|---|---|---|---|
| `fold` | `hasFolded = true; foldedStreet = street; acted = true` | `"Fold"` | `` `${name} folds` `` |
| `check` | `acted = true` | `"Check"` | `` `${name} checks` `` |
| `call` | VPIP tick (§4); `amt = min(toCall, stack)`; `commit(amt)`; `acted = true` | `isAllIn ? "All-In" : "Call"` | `` `${name} calls ${amt}` `` + `" (all-in)"` if all-in |
| `bet` | VPIP+PFR tick (§4); `to = max(action.amount ?? 0, min(bb, maxTotal)); to = min(to, maxTotal)`; `commit(to - committed)`; `currentBet = to; lastRaiseSize = to; aggressor = seat; resetActedExcept(seat); acted = true` | `isAllIn ? "All-In" : "Bet"` | `` `${name} bets ${to}` `` + `" (all-in)"` |
| `raise` | VPIP+PFR tick; `to = action.amount ?? currentBet + lastRaiseSize; to = min(to, maxTotal); raiseSize = to - currentBet; commit(to - committed); fullRaise = raiseSize >= lastRaiseSize; if (to > currentBet) currentBet = to; if (fullRaise) { lastRaiseSize = raiseSize; resetActedExcept(seat); } aggressor = seat; acted = true` | `isAllIn ? "All-In" : "Raise"` | `` `${name} raises to ${to}` `` + `" (all-in)"` |
| `post` | nothing (falls through to advance). Not used by the live game; do not send. | — | — |

Then `advanceAfterAction(seat)`:

```
live = players where !hasFolded
if (live.length == 1) { settleByFold(live[0].id); return }
n = nextToAct(seat)
if (n != null) { toAct = n; return }
closeStreet()
```

Min-raise / short all-in semantics that follow from the table above:

- A raise whose increment `raiseSize` is at least `lastRaiseSize` is a full
  raise: it re-opens action for everyone else (`acted = false`) and becomes
  the new `lastRaiseSize`.
- A short all-in raise (`raiseSize < lastRaiseSize`) raises `currentBet` (so
  others must match it) but does **not** re-open action for players who
  already acted, and does not change `lastRaiseSize`.
- A bet's `lastRaiseSize` is the whole bet amount (`to`), since `currentBet` was 0.
- `aggressor` is set on every bet/raise, including a short all-in.
- The amount clamp `min(to, maxTotal)` means an over-stack request becomes an
  all-in; there is no lower clamp against `minRaiseTo` (caller's duty).

### 3.8 Street closing and run-outs — `closeStreet`

```
closeStreet():
  if (street == river) { settleShowdown(); return }
  if (street == preflop)    { burnDeal(3); street = flop }
  else if (street == flop)  { burnDeal(1); street = turn }
  else if (street == turn)  { burnDeal(1); street = river }
  for every player:
    committed = 0; acted = false
    if (!hasFolded && !isAllIn) lastAction = null   // folded / all-in labels persist
  currentBet = 0; lastRaiseSize = bigBlind; aggressor = null
  log(kind deal, street, `${Capitalized street} — ${board.join(" ")}`)   // e.g. "Flop — Ah Kd 7c", "Turn — Ah Kd 7c 2s"
  canAct = players where !hasFolded && !isAllIn
  if (canAct.length <= 1) { closeStreet(); return }   // run out remaining streets, then showdown
  toAct = nextLiveActor(button + 1, inclusive)        // first live seat left of the button

burnDeal(count): deck.removeLast() /* burn */; then push `count` cards from deck.removeLast() onto board
```

The dash in the deal log line is an em dash (U+2014) with spaces: `" — "`.
Postflop the first actor is the first non-folded, non-all-in seat starting at
`button+1` (SB; in heads-up that is the BB, which is correct).

All-in run-out: as soon as at most one player can still act, `closeStreet`
recurses, dealing every remaining street (each logged) and ending in
`settleShowdown`. This also covers "everyone but one is all-in".

### 3.9 Side pots — `buildSidePots(contribs)`

Input: one `{id, amt: committedTotal, folded}` per player (antes included in
`amt`). Output: ordered list of `{amount, eligible: [ids]}`.

```
rem = contribs where amt > 0 (copies)
pots = []; carry = 0
while (rem not empty):
  min = smallest amt in rem
  amount = min * rem.length + carry
  eligible = ids in rem where !folded
  if (eligible.isEmpty) carry = amount           // dead money rolls forward into the next level
  else { carry = 0; pots.add({amount, eligible}) }
  rem = rem.map(amt -= min).where(amt > 0)
return pots
```

Folded players' chips are dead money inside whichever level they reached.
Because the top contributor at showdown is always a live player, `eligible`
is never empty in practice; the `carry` branch is defensive. Uncalled excess
(one player committed more than anyone else) becomes a final pot whose only
eligible player is that player — it is "won back" at showdown, not returned
early (see §7 for how the export reports it as an uncalled bet).

### 3.10 Uncontested win — `settleByFold(winnerId)`

```
amount = pot; players[winner].stack += amount
summary = { handNumber, potResults: [{winners: [winner], amount, potLabel: "Pot"}],
            showdown: [], board: copy, heroNetChips: players[0].stack - stacksAtStart[0] }
log(kind result, current street, `${winner.name} wins ${amount} (uncontested)`)
for every player with hole != null: revealed = true      // LEARNING REVEAL: every dealt hand is shown, folds included
toAct = null; phase = handOver
```

`s.pot` is **not** zeroed: at `hand-over` it still equals the amount
distributed, and `sum(summary.potResults.amount) == s.pot` is a tested
invariant. `startHand` resets it.

### 3.11 Showdown — `settleShowdown`

```
liveIds = players where !hasFolded (seat order)
for every player with hole: revealed = true                 // learning reveal
evals[id] = evaluateCards(hole + board) for id in liveIds
pots = buildSidePots(players.map({id, amt: committedTotal, folded: hasFolded}))
potResults = []
for (idx, pot) in pots:
  contenders = pot.eligible ∩ liveIds
  if (contenders.isEmpty) continue                          // pot produces no result line
  best = max score among contenders; winners = all contenders with score == best (seat order)
  share = floor(pot.amount / winners.length); rem = pot.amount - share*winners.length
  each winner.stack += share
  if (rem > 0): the winner with the smallest seatOrderFromButton gets rem
       // seatOrderFromButton(id) = (id - button - 1 + n) mod n  → SB is 0, i.e. closest left of the button wins the odd chip
  potResults.add({winners, amount: pot.amount,
                  potLabel: pots.length > 1 ? (idx == 0 ? "Main pot" : "Side pot ${idx}") : "Pot"})
showdown = liveIds.map({playerId, hole, hand: evals[id], hadToShow: true})
summary = { handNumber, potResults, showdown, board, heroNetChips }
for pr in potResults: log(kind result, street "showdown",
     `${pr.winners.map(name).join(", ")} wins ${pr.amount} (${pr.potLabel})`)
toAct = null; phase = handOver
```

`s.street` stays `"river"`; only the log entries use street `"showdown"`.

### 3.12 Log

`pushLog(street, text, kind)` appends `{id: logSeq++, street, text, kind}` and
trims to the most recent 200 entries. All log strings are listed verbatim in
§3.4, §3.7, §3.8, §3.10, §3.11. The `info` kind is declared but never emitted
by the engine.

### 3.13 Engine invariants (tested; see §8)

1. Every hand driven by legal actions terminates in `phase == "hand-over"`.
2. No stack is ever negative.
3. Chip conservation: `sum(stacks after hand) == sum(stacksAtStart)`; with antes: `sum(stacks after) == sum(stacks after deal) + pot after deal`.
4. `board.length ∈ {0, 3, 4, 5}` at hand end.
5. `sum(summary.potResults[].amount) == state.pot` at hand end.
6. Heads-up: positions are exactly `{BTN, BB}`; the BTN posts the small blind and acts first preflop.
7. 9-max: exactly one `BTN`; at least 5 distinct position labels.
8. With antes: `pot after deal == sb + bb + ante * seats`; some non-blind player has `committed == 0 && committedTotal > 0`.

---

## 4. Observed-stat counters (VPIP / PFR / hands seen)

- `handsSeen += 1` for **every** player in `startHand` (dealt = seen).
- On a **preflop** `call`, `bet`, or `raise`: if `!vpipThisHand` → `vpipThisHand = true; vpipCount += 1`.
- On a **preflop** `bet` or `raise`: if `!pfrThisHand` → `pfrThisHand = true; pfrCount += 1`.
- Blind posts, checks, folds, and all postflop actions never tick the counters.
- Each counter ticks at most once per hand per player. The HUD derives `VPIP% = vpipCount / handsSeen`, `PFR% = pfrCount / handsSeen`.

---

## 5. Archetypes (`src/game/archetypes.ts`)

```dart
const ARCHETYPES = {
  TAG:     (name: "Tight-Aggressive",  vpip: 22, pfr: 18, cbetFlop: 65, aggression: 0.72, stickiness: 0.28, color: "#2f6fd0",
            blurb: "Plays few hands but bets and raises them hard. The textbook winner."),
  LAG:     (name: "Loose-Aggressive",  vpip: 34, pfr: 27, cbetFlop: 72, aggression: 0.86, stickiness: 0.34, color: "#8a5cd1",
            blurb: "Plays many hands with relentless pressure. Hard to put on a hand."),
  Nit:     (name: "Nit",               vpip: 12, pfr: 9,  cbetFlop: 55, aggression: 0.5,  stickiness: 0.2,  color: "#2faa66",
            blurb: "Extremely tight. If a Nit raises, believe them."),
  Station: (name: "Calling Station",   vpip: 46, pfr: 7,  cbetFlop: 32, aggression: 0.18, stickiness: 0.82, color: "#d23b3b",
            blurb: "Calls far too much, rarely raises. Value-bet relentlessly, never bluff."),
};
const ARCHETYPE_LIST = [TAG, LAG, Nit, Station];   // display order

const BOT_NAMES = ["Ivey","Negreanu","Polk","Selbst","Hellmuth","Brunson","Antonius","Dwan","Galfond","Chidwick"];
String botNameFor(int seat) => BOT_NAMES[(seat - 1 + 10) % 10];   // seat n → BOT_NAMES[n-1]; only seats 1..8 (Ivey..Dwan) occur live — see Appendix A.1
Archetype archetypeForSeat(int seat) => ["TAG","Station","LAG","Nit","TAG","LAG"][(seat - 1) % 6];
```

`botNameFor`: seat 1 Ivey, 2 Negreanu, 3 Polk, 4 Selbst, 5 Hellmuth, 6 Brunson, 7 Antonius, 8 Dwan, 9 Galfond.
`archetypeForSeat`: seat 1 TAG, 2 Station, 3 LAG, 4 Nit, 5 TAG, 6 LAG, 7 TAG, 8 Station, 9 LAG. (Note: `(seat-1) % 6` in JS; seat ≥ 1 always.)

`vpip`/`pfr` are only used for display and for the coach's fallback preflop
range (`buildPreflopRanges`, another subsystem); the bot policy uses the
charts plus `DIALS`, `cbetFlop`, `aggression`, `stickiness`.

### 5.1 Session setup in the store (`newSession`)

The live app **overrides** `archetypeForSeat`: each non-hero seat gets a
uniformly random archetype from `ARCHE_POOL = [TAG, LAG, Nit, Station]`, and
per-session jittered dials so two bots of the same archetype differ:

```
jitter(v, frac, lo, hi) = clamp(v * (1 - frac + random() * 2 * frac), lo, hi)
dials = {
  aggression: jitter(cfg.aggression, 0.20, 0.05, 0.95),
  stickiness: jitter(cfg.stickiness, 0.20, 0.05, 0.95),
  cbetFlop:   jitter(cfg.cbetFlop,   0.15, 20,   95),
}
```

The bot merges `dials` over the archetype config (`{...ARCHETYPES[a], ...dials}`),
so only those three knobs vary. Tests construct tables without dials.

The store also handles hero bust-out before calling `startHand`: if the hero's
stack is ≤ 0 the session ends instead of rebuying; bots with stack ≤ 0 are
reset to `startingStack` (the engine's own rebuy would do the same).

---

## 6. Bot brain (`src/game/botBrain.ts`)

Public API:

```dart
class BotDecision { Action action; List<HandLabel>? range; }   // range == null → leave stored range unchanged
BotDecision decideBot(GameState s, int seat);
List<HandLabel> narrowRange(List<HandLabel> stored, List<Card> board, String kind /* aggro|call|check */, HandLabel actualLabel);
```

Store contract: when the bot acts, the store first records the action for the
hand history (§7.1), then calls `applyAction`, then **if `range != null`** sets
`botRanges[seat] = range` on the resulting state. The hero's seat never gets a
`botRanges` entry.

### 6.1 Preflop dials

```dart
const DIALS = {
  TAG:     (open: 1.0,  threebet: 1.0,  call: 1.0,  limpWide: false),
  LAG:     (open: 1.3,  threebet: 1.6,  call: 1.15, limpWide: true),
  Nit:     (open: 0.7,  threebet: 0.55, call: 0.8,  limpWide: false),
  Station: (open: 0.45, threebet: 0.3,  call: 1.6,  limpWide: true),
};
const PREMIUM = {"AA","KK","QQ","AKs","AKo"};   // never fold preflop
const PREMIUM_LIST = ["AA","KK","QQ","AKs","AKo"];
```

`dial.open` is only actually applied for LAG (see 6.4); Nit and Station use
their own hard-coded multipliers.

### 6.2 Helpers

```
chartLabels(chart, min)  → labels with freq >= min, in chart key order
clampInt(x, lo, hi)      → round(max(lo, min(hi, x)))     // JS Math.round: halves round up
setDiff(a, b)            → elements of a not in b, in a's order
betOrRaise(s, to)        → currentBet == 0 ? {bet, amount: to} : {raise, amount: to}
ALL_LABELS               = allLabels()   (169)
```

### 6.3 `decideBot` wrapper — range always contains the real hand

```
d = decideBotInner(s, seat)
if (d.range != null && d.action.type != fold && p.hole != null):
  label = cardsToLabel(hole)
  if (!d.range.contains(label)) d.range = [...d.range, label]
return d
```

This guarantee ("stored range never excludes the bot's actual hand") is a
tested invariant.

### 6.4 `decideBotInner` — setup and preflop

```
p = players[seat]
if (p.archetype == null || p.hole == null) return {fold, range: []}
cfg = ARCHETYPES[p.archetype] merged with p.dials   // aggression, stickiness, cbetFlop may be jittered
la = legalActions(s); label = cardsToLabel(hole); bb = s.bigBlind
rnd = random()          // ONE draw, reused by several comparisons below
```

**Preflop** (`s.street == preflop`), `dial = DIALS[archetype]`, `facingRaise = currentBet > bb`.

**A. Not facing a raise (`currentBet == bb`)**

A1. If `la.canCheck` (the BB with the option after limps, or the HU BB after a
button limp):

```
f = min(1, (PREFLOP_100.vsRfi["BB_vs_SB"].threebet[label] ?? 0) * dial.threebet)
if (rnd < f && la.canRaise):
  limpers = count of players with !hasFolded && committed == bb && position != BB
  to = clampInt((3 + limpers) * bb, la.minRaiseTo, la.maxRaiseTo)
  return {betOrRaise(to), range: chartLabels(BB_vs_SB.threebet, 0.25)}
return {check, range: setDiff(ALL_LABELS, chartLabels(BB_vs_SB.threebet, 0.5))}
```

(The `BB_vs_SB` 3-bet chart is used as the "raise over limps" proxy whatever
the limpers' positions.)

A2. Otherwise open-raise / limp / fold (RFI):

```
chart = PREFLOP_100.rfi[p.position] ?? PREFLOP_100.rfi["SB"]    // BB has no rfi chart → SB chart
base = chart[label] ?? 0
openFreq =
  PREMIUM.contains(label) ? 1
  : base == 0            ? 0
  : archetype == LAG     ? max(base * 1.3, 0.9)
  : archetype == Nit     ? (base >= 1 ? 0.92 : base * 0.35)
  : archetype == Station ? (base >= 1 ? 0.55 : base * 0.25)
  : base                                                        // TAG
openFreq = min(1, openFreq)
if (rnd < openFreq):
  limpers = (same count as A1)
  to = clampInt((2.5 + limpers) * bb, la.minRaiseTo, la.maxRaiseTo)   // 2.5bb open; +1bb per limper
  return {betOrRaise(to), range: chartLabels(chart, 0.4)}
if (dial.limpWide && la.canCall && la.callAmount <= bb && base > 0):
  return {call callAmount, range: chartLabels(chart, 0.01)}           // LAG / Station limp playable hands cheaply
return {fold, range: []}
```

Deviations only trim the bottom of the range: premiums always open; Nit and
Station kill marginal (mixed-frequency) opens; LAG rounds its mixed opens up
to at least 90%.

**B. Facing a raise (`currentBet > bb`)**

```
aggSeat = s.aggressor
raiserPos = (aggSeat != null && aggSeat != seat) ? players[aggSeat].position : CO
facing3bet = currentBet > 4.5 * bb          // anything beyond a standard single open
charts = PREFLOP_100.vsRfi["${p.position}_vs_${raiserPos}"]   // may be null (uncharted pair; see §0 key list)
```

B1. Facing a single raise with a chart (`!facing3bet && charts != null`):

```
f3 = charts.threebet[label] ?? 0
fc = charts.call[label] ?? 0
if (archetype == Station):
  fc = min(1, (f3 + fc) * dial.call)             // flat the whole continue range
  f3 = (label == "AA" || label == "KK") ? 0.5 : 0
else:
  if (archetype == Nit && f3 < 0.9) f3 *= 0.3     // drop bluff 3-bets
  f3 = min(1, f3 * dial.threebet)
  fc = min(1 - f3, fc * dial.call)
if (PREMIUM.contains(label)) f3 = max(f3, 0.85)   // applies to ALL archetypes, Station included
if (rnd < f3 && la.canRaise):
  to = clampInt(currentBet * 3.2, la.minRaiseTo, la.maxRaiseTo)
  return {betOrRaise(to), range: chartLabels(charts.threebet, 0.25)}
if (rnd < f3 + fc && la.canCall):
  return {call callAmount, range: chartLabels(charts.call, 0.25)}
if (PREMIUM.contains(label) && la.canCall):
  return {call callAmount, range: PREMIUM_LIST}   // safety net: a premium never folds preflop
return {fold, range: []}
```

One draw `rnd` partitions `[0, f3)` raise, `[f3, f3+fc)` call, rest fold. If
`canRaise` is false with `rnd < f3`, it falls into the call test.

B2. Facing a 3-bet or bigger, **or** an uncharted spot (e.g. `UTG_vs_MP`,
`UTG_vs_UTG` in 9-max, any `X_vs_BB` when the BB raised over limps):

```
if (label == "AA" || label == "KK"):
  if (la.canRaise && rnd < 0.8): return {betOrRaise(clampInt(currentBet * 2.6, min, max)), range: PREMIUM_LIST}
  if (la.canCall):                return {call, range: PREMIUM_LIST}
  if (la.canRaise):               return {betOrRaise(la.maxRaiseTo), range: PREMIUM_LIST}
f3vs = charts?.threebet[label] ?? (PREMIUM.contains(label) ? 1 : 0)   // null charts OR missing label → fallback
if (f3vs >= 0.9):                                    // QQ / AK class: continue — occasionally 4-bet, mostly call
  if (la.canRaise && rnd < 0.1 + 0.35 * cfg.aggression):
    return {betOrRaise(clampInt(currentBet * 2.6, min, max)), range: PREMIUM_LIST}
  if (la.canCall): return {call, range: PREMIUM_LIST}
if (f3vs > 0 && la.canCall && la.callAmount <= 12 * bb && rnd < f3vs * (0.4 + cfg.stickiness)):
  return {call, range: chartLabels(charts?.threebet ?? {}, 0.25)}   // speculative continue at a sane price
return {fold, range: []}
```

`cfg.aggression` / `cfg.stickiness` here are the (possibly jittered) knobs.

### 6.5 Postflop — equity and features

```
holeInts = comboToInts(hole); boardInts = board.map(cardToInt)
facingBet = la.toCall > 0
stored = s.botRanges[p.id] ?? []
narrowed(kind) = narrowRange(stored, s.board, kind, label)

liveOpps = players where !hasFolded && id != seat
soleOppRange = liveOpps.length == 1 ? s.botRanges[liveOpps[0].id] : null   // hero never has one → null
if (soleOppRange != null && soleOppRange.isNotEmpty):
  blocked = set(holeInts + boardInts)
  combos = for each label in soleOppRange, for each [a,b] in labelToCombos(label):
             if neither cardToInt(a) nor cardToInt(b) in blocked → [ai, bi]
  e = combos.isNotEmpty ? equityVsRange(holeInts, boardInts, combos, 260).equity
                        : equityVsRandom(holeInts, boardInts, 320).equity
else:
  e = equityVsRandom(holeInts, boardInts, 320).equity
// no seed is passed → these samples use the global RNG (non-deterministic)

tex = boardTexture(boardInts)         // {wet, paired, highCard}; `paired` is computed but unused
draw = drawStrength(holeInts, boardInts)   // 0 | 1 | 2
multiDamp = 1 / max(1, liveOpps.length)    // bluff less multiway
```

Note `s.pot` already contains every chip committed so far on this street,
including the bet currently being faced.

### 6.6 Postflop decision ladders

**C. Not facing a bet** (`toCall <= 0`):

```
if (la.canBet):                                   // currentBet == 0 && stack > 0
  if (e > 0.8):                                   // monster
    slowplayP = tex.wet ? 0.08 : 0.28
    if (rnd < slowplayP && street != river) return {check, range: narrowed("check")}
    frac = tex.wet ? 1.0 : [0.66, 0.75, 1.25][clampInt(rnd * 3, 0, 2)]
         // index: rnd < 1/6 → 0.66 ; 1/6 <= rnd < 1/2 → 0.75 ; rnd >= 1/2 → 1.25  (rounding, then clamp to 2)
    return {bet clampInt(pot * frac, minRaiseTo, maxRaiseTo), range: narrowed("aggro")}
  if (e > 0.6):                                   // solid value; size up on wet boards to charge draws
    return {bet clampInt(pot * (tex.wet ? 0.75 : 0.55), min, max), range: narrowed("aggro")}
  if (e > 0.4 && street == flop && rnd < (cfg.cbetFlop / 100) * (tex.wet ? 0.7 : 1) * multiDamp):
    return {bet clampInt(pot * 0.33, min, max), range: narrowed("aggro")}     // small range-style c-bet
  bluffP = draw == 2 ? cfg.aggression * 0.55
         : draw == 1 ? cfg.aggression * 0.28
         : (tex.highCard >= 12 && street != flop) ? cfg.aggression * 0.12    // scare-card barrel (Q+ on board)
         : 0
  if (random() < bluffP * multiDamp)              // FRESH draw, not rnd
    return {bet clampInt(pot * 0.66, min, max), range: narrowed("aggro")}
return {check, range: narrowed("check")}
```

**D. Facing a bet** (`toCall > 0`):

```
needed = la.callAmount / (pot + la.callAmount)                       // pot odds as a fraction
if (e > 0.72 && la.canRaise && random() < cfg.aggression * (e > 0.85 ? 1 : 0.6)):   // value raise (fresh draw)
  frac = tex.wet ? 1.0 : 0.8
  return {raise clampInt(currentBet + pot * frac, min, max), range: narrowed("aggro")}
if (draw == 2 && street != river && la.canRaise && random() < cfg.aggression * 0.3 * multiDamp):   // semi-bluff (check-)raise
  return {raise clampInt(currentBet + pot * 0.9, min, max), range: narrowed("aggro")}
effE = min(0.95, e + (street != river ? draw * 0.05 : 0))            // draws call a little wider; rivers don't
callThreshold = needed * (1 - cfg.stickiness * 0.5)
if (effE >= callThreshold && la.canCall) return {call callAmount, range: narrowed("call")}
if (cfg.stickiness > 0.7 && la.canCall && la.callAmount <= pot * 0.5 && random() < 0.7)   // station calldown
  return {call callAmount, range: narrowed("call")}
return {fold, range: []}
```

Check-raises arise naturally: a bot that checked (ladder C) and then faces a
bet on the same street re-enters ladder D and may raise. The bot test requires
that this happens at least once over 1200 hands and that at least 3 distinct
bet-to-pot ratios (rounded to quarters) are observed.

Which random draws are used where (matters if you seed for tests):
`rnd` (one draw per decision) → all preflop frequency checks, slowplay,
monster sizing index, c-bet check. Fresh `random()` → bluff bet, value raise,
semi-bluff raise, station calldown. Equity sampling and `shuffle` also consume
the global RNG.

### 6.7 Board texture — `boardTexture(boardInts)`

```
suits = [0,0,0,0]; rankCounts = {}; rankMask = 0; highCard = 0
for c in board: suits[c & 3]++; r = (c >> 2) + 2; rankCounts[r]++; rankMask |= 1 << r; highCard = max(highCard, r)
flushy = max(suits) >= min(3, board.length)          // flop: monotone; turn/river: 3+ of a suit
m = rankMask | ((rankMask & (1 << 14)) != 0 ? (1 << 1) : 0)   // ace also counts low
straighty = exists lo in 1..10 such that popcount(m over bits lo..lo+4) >= 3
paired = any rankCounts value >= 2                    // unused by the policy
return {wet: flushy || straighty, paired, highCard}   // highCard is a rank value 2..14
```

### 6.8 Draw strength — `drawStrength(holeInts, boardInts)`

```
if (board.length >= 5) return 0
all = hole + board
suits = [0,0,0,0]; mask = 0
for c in all: suits[c & 3]++; mask |= 1 << ((c >> 2) + 2)
holeSuits = [hole[0] & 3, hole[1] & 3]
flushDraw = exists suit si with suits[si] == 4 && holeSuits.contains(si)     // exactly 4, and we hold at least one
if (mask & (1 << 14)) mask |= 1 << 1
fourToStraight = exists lo in 1..10 with popcount(mask over lo..lo+4) >= 4
bestRun = longest run of consecutive set bits in mask over r = 1..14
oesd = bestRun >= 4                      // note: includes made straights and board-only runs
gutshot = fourToStraight && !oesd
threeFlush = board.length == 3 && exists suit si with suits[si] == 3 && holeSuits.contains(si)   // backdoor flush draw on the flop
if (flushDraw || oesd) return 2          // strong
if (gutshot || threeFlush) return 1      // weak
return 0
```

Port these quirks as-is (they are part of the tuned behaviour): a run that
uses only board cards still counts as an OESD for the holder; a completed
straight also reads as `draw == 2` on flop/turn.

### 6.9 Range narrowing — `narrowRange(stored, board, kind, actualLabel)`

```
if (stored.length <= 8) return stored.contains(actual) ? stored : [...stored, actual]
boardInts = board.map(cardToInt); blocked = set(boardInts); isRiver = board.length == 5
scored = []
for l in stored:
  combo = first [a,b] in labelToCombos(l) (in the §0 order) with neither card in blocked; skip label if none
  v = isRiver ? evaluateInts([combo..., boardInts...]).score
              : equityVsRandom(combo, boardInts, 80, hashSeed("${l}|${board.join("")}")).equity   // deterministic
  scored.add({l, v})
scored.sort(descending by v)            // JS sort is stable; ties keep stored order
n = scored.length
kept =
  kind == "aggro" ? scored[0 : max(5, round(n * 0.45))] ++ scored[round(n * 0.85) : n]   // value region + thin bluff tail; PLAIN CONCAT, never deduped — see Appendix A.5
  kind == "call"  ? scored[0 : max(6, round(n * 0.65))]                                   // middle-and-up
  /* check */     : scored[round(n * 0.12) : n]                                           // sheds the very top
if (!kept.contains(actual) && stored.contains(actual)) kept.add(actual)
return kept (labels only)
```

The seed string is the label, a `|`, then the board cards concatenated with
no separator (e.g. `"AKs|AhKd7c"`). `equityVsRandom` on the flop/turn with a
seed must therefore be reproduced bit-for-bit (mulberry32 + same sampling
order) if you want identical narrowing; otherwise only the invariants below
are required.

Tested invariants (all-bot tables, 1200 hands): postflop the returned range
is never longer than the stored range once the stored range exceeds 8
labels ("ranges never grow"); it strictly shrinks at least 200 times; and it
always contains the bot's actual label.

### 6.10 Preflop property tests (behavioural contract)

- AA and KK **never** fold preflop at any price, for any archetype.
- "Junk" = `{72o, 82o, 92o, T2o, J2o, 83o, 73o, 62o, 52o, 42o, 32o}` never **calls** a raise of `callAmount >= 8 * bb`.
- A hero who open-jams 100bb every hand loses to the field (observed: about −856 bb/100 over 1000 hands).
- A hero who checks/limps preflop and bets 66% pot at every postflop opportunity (never raises) loses (observed: about −79 bb/100 over 1200 hands).

---

## 7. Hand history (`src/game/handHistory.ts`)

### 7.1 Record types and how the store fills them

```dart
class HHAction { Street street; int seat; String name; ActionType type; int amount; bool allIn; }
  // amount: call → chips called; bet/raise → total "to" on this street; fold/check → 0
class HHSeat   { int seat; String name; int stack /* at hand start */; bool isHero; Position position; }
class HHHand {
  int id;                 // session-local hand number (restarts at 1 each session)
  int startedAt;          // epoch milliseconds
  int button; int sb; int bb; int sbSeat; int bbSeat;
  List<HHSeat> seats;
  Map<int, List<Card>?> holes;   // seat → hole cards (all dealt hands after the learning reveal)
  List<HHAction> actions;
  List<Card> board;
  List<PotResult> potResults;
  int heroNet;
}
```

Store behaviour (`gameStore.ts`):

- On deal (after `startHand`): `id = handNumber`, `startedAt = now()`, `button`, `sb/bb = smallBlind/bigBlind`, `sbSeat = seats == 2 ? button : button+1`, `bbSeat = seats == 2 ? button+1 : button+2` (mod n), `seats = players.map({seat: id, name, stack: stacksAtStart[id], isHero, position})`, `holes = {0: hero hole}`, `actions []`, `board []`, `potResults []`, `heroNet 0`.
- Before every `applyAction` (hero or bot), `recordAction(state, seat, action)`:
  - `call` → `amount = legalActions.callAmount`, `allIn = amount >= p.stack`
  - `bet` / `raise` → `amount = action.amount ?? 0` (the requested "to"), `allIn = amount >= p.committed + p.stack`
  - `fold` / `check` → `amount 0`, `allIn false`
- At `hand-over`: `board`, `potResults = summary.potResults`, `heroNet = summary.heroNetChips`, `holes[id] = hole` for every player (folded players' cards are stored too, but the exporter never "shows" them).
- Antes are **not** represented in `HHHand` at all (no field, no action).

### 7.2 Small helpers

```
seatNo(seat) = seat + 1
exportHandId(h) = h.startedAt * 100 + (h.id % 100)        // globally unique, monotonic
pad2(n) = two-digit zero-padded
psDate(ts) = "YYYY/MM/DD HH:MM:SS" using LOCAL time components of `ts` (the trailing " ET" in the header is a literal)
psHandName(hole, board) = PokerStars-style lower-case descriptor of evaluateCards(hole + board).name:
```

| evaluator `name` | export descriptor |
|---|---|
| `Royal Flush` | `a royal flush` |
| `Straight Flush, King high` | `a straight flush, King high` (prefix `a straight flush` + `n.slice(14)`, i.e. `", King high"`) |
| `Four of a Kind, Aces` | `four of a kind, Aces` |
| `Full House, Aces full of Kings` | `a full house, Aces full of Kings` |
| `Flush, Ace high` | `a flush, Ace high` |
| `Straight, Ten high` | `a straight, Ten high` |
| `Three of a Kind, Queens` | `three of a kind, Queens` |
| `Two Pair, Aces & Kings` | `two pair, Aces and Kings` (first `" & "` → `" and "`, then prefix) |
| `Pair of Queens` | `a pair of Queens` |
| `Ace High` | `high card Ace` (`endsWith("High")` → drop the last 5 chars) |
| anything else | lower-cased |

Check order matters: `Pair of`, `Two Pair`, `Three of a Kind`, `Straight Flush`, `Straight`, `Flush`, `Full House`, `Four of a Kind`, exact `Royal Flush`, `endsWith High`. See Appendix A.4 for the evaluator's exact `name` strings (ranks are always spelled out: `King`, never `K`) and for every prefix length.

```
FOLD_STREET_PHRASE = { preflop: "before Flop", flop: "on the Flop", turn: "on the Turn", river: "on the River" }
actionLine(a, streetBet):
  all = a.allIn ? " and is all-in" : ""
  fold  → "${name}: folds"
  check → "${name}: checks"
  call  → "${name}: calls ${amount}${all}"                       streetBet unchanged
  bet   → "${name}: bets ${amount}${all}"                        streetBet = amount
  raise → "${name}: raises ${max(0, amount - streetBet)} to ${amount}${all}"   streetBet = amount
  other → "${name}: posts"
```

### 7.3 `formatHand(h)` — line by line

1. `` `PokerStars Hand #${exportHandId(h)}: Hold'em No Limit (${sb}/${bb}) - ${psDate(startedAt)} ET` ``
2. `` `Table 'All-In Dojo' ${seats.length}-max Seat #${button+1} is the button` ``
3. For each seat in order: `` `Seat ${seat+1}: ${name} (${stack} in chips)` ``
4. `` `${sbName}: posts small blind ${sb}` `` and `` `${bbName}: posts big blind ${bb}` `` (name lookup by `sbSeat`/`bbSeat`; fallback strings `"SB"`/`"BB"`).
5. `*** HOLE CARDS ***`; if a hero seat exists and has holes: `` `Dealt to ${hero.name} [${c1} ${c2}]` ``.
6. Fold bookkeeping: `foldedOn[seat] = street of the seat's FIRST fold action`. Defensive rule: a seat with no fold, that is not a winner, and that has **no actions at all** is treated as folded `preflop`. `live = seats not in foldedOn`.
7. Streets, in order `preflop, flop, turn, river`, with a per-seat `committed` map:
   - `preflop`: `committed[sbSeat] = sb; committed[bbSeat] = bb` (others absent = 0). No header line.
   - `flop`: if `board.length >= 3` print `` `*** FLOP *** [c1 c2 c3]` ``; `turn`: if `>= 4` print `` `*** TURN *** [c1 c2 c3] [c4]` ``; `river`: if `>= 5` print `` `*** RIVER *** [c1 c2 c3 c4] [c5]` ``. If the board is too short for the header **and** the street has no actions → skip the street. Then, **only if the street has actions**, reset every seat's `committed` to 0. (So on an all-in run-out the last betting street's commitments survive for the uncalled-bet computation.)
   - `streetBet = preflop ? bb : 0`. For each action of the street: update `committed` (`call` → `+= amount`; `bet`/`raise` → `= amount`), emit `actionLine`, update `streetBet`.
8. Uncalled bet: sort seats by `committed` descending; `uncalled = top - second` (0 if fewer than 2 seats). If `> 0`: `` `Uncalled bet (${uncalled}) returned to ${name}` ``.
9. `collected[seat]`: for each `potResults` entry, each winner gets `round(amount / winners.length)` added (**note: `round`, not the engine's floor-plus-odd-chip rule; can differ by 1 chip on uneven splits**). Then, if there was an uncalled bet, `collected[uncalledSeat] = max(0, collected - uncalled)`.
10. `wentToShowdown = board.length == 5 && live.length > 1`. If so: `*** SHOW DOWN ***`, then for each live seat (seat order) with known holes: `` `${name}: shows [${c1} ${c2}] (${psHandName})` ``. Folded players never show (muck semantics), whatever the in-app learning reveal displayed.
11. For each `collected` entry with amount `> 0`, in insertion order (= potResults winner order): `` `${name} collected ${amt} from pot` ``.
12. `*** SUMMARY ***`; `` `Total pot ${sum of collected} | Rake 0` ``; if `board` non-empty: `` `Board [${board.join(" ")}]` ``.
13. One line per seat, in seat order, with `tag` = `" (small blind)"` if `seat == sbSeat`, else `" (big blind)"` if `seat == bbSeat`, else `" (button)"` if `seat == button`, else `""` (so in heads-up the button line reads `(small blind)`):
    - folded: `` `Seat ${n}: ${name}${tag} folded ${FOLD_STREET_PHRASE[street] ?? "before Flop"}` `` (the `?? "before Flop"` default is in the source; see Appendix A.3)
    - showdown and holes known: `` `Seat ${n}: ${name}${tag} showed [${c1} ${c2}] and won (${won}) with ${psHandName}` `` or `… and lost with ${psHandName}`
    - won without showdown: `` `Seat ${n}: ${name}${tag} collected (${won})` ``
    - otherwise: `` `Seat ${n}: ${name}${tag} mucked` ``
14. Join with `"\n"` (no trailing newline).

`formatSession(hands)` = hands formatted and joined with `"\n\n\n"`.

### 7.4 Exact example (from `scripts/hh_test.ts`, run in a UTC+9 locale)

Input hand 1: `id 1`, `startedAt = Date.UTC(2026, 5, 19, 12, 0, 0)` (= 1781870400000), `button 0`, `sb 10`, `bb 20`, `sbSeat 1`, `bbSeat 2`, seats `You(BTN) Ivey(SB) Polk(BB) Dwan(UTG) Selbst(MP) Galfond(CO)` all 2000, holes `{0: [As Ks], 3: [Qh Qd]}`, actions:
`preflop Dwan raise 60; You call 60; flop Dwan bet 80; You call 80; turn Dwan check; You check; river Dwan check; You bet 120; Dwan call 120`, board `Ah Kd 7c 2s 9h`, potResults `[{winners:[0], amount 520, "Pot"}]`, heroNet 260.

Output (the date shows local time; the test only pins the hand id):

```
PokerStars Hand #178187040000001: Hold'em No Limit (10/20) - 2026/06/19 21:00:00 ET
Table 'All-In Dojo' 6-max Seat #1 is the button
Seat 1: You (2000 in chips)
Seat 2: Ivey (2000 in chips)
Seat 3: Polk (2000 in chips)
Seat 4: Dwan (2000 in chips)
Seat 5: Selbst (2000 in chips)
Seat 6: Galfond (2000 in chips)
Ivey: posts small blind 10
Polk: posts big blind 20
*** HOLE CARDS ***
Dealt to You [As Ks]
Dwan: raises 40 to 60
You: calls 60
*** FLOP *** [Ah Kd 7c]
Dwan: bets 80
You: calls 80
*** TURN *** [Ah Kd 7c] [2s]
Dwan: checks
You: checks
*** RIVER *** [Ah Kd 7c 2s] [9h]
Dwan: checks
You: bets 120
Dwan: calls 120
*** SHOW DOWN ***
You: shows [As Ks] (two pair, Aces and Kings)
Dwan: shows [Qh Qd] (a pair of Queens)
You collected 520 from pot
*** SUMMARY ***
Total pot 520 | Rake 0
Board [Ah Kd 7c 2s 9h]
Seat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings
Seat 2: Ivey (small blind) folded before Flop
Seat 3: Polk (big blind) folded before Flop
Seat 4: Dwan showed [Qh Qd] and lost with a pair of Queens
Seat 5: Selbst folded before Flop
Seat 6: Galfond folded before Flop
```

Note that Ivey, Polk, Selbst and Galfond have no recorded actions, so the
defensive rule in step 6 marks them folded preflop.

Input hand 2 (fold-out): `id 2`, `startedAt = hand1 + 60000`, same seats/blinds, holes `{0: [7h 2c], 3: [Ac Ad]}`, actions `preflop Dwan raise 60; Selbst fold; Galfond fold; You fold; Ivey fold; Polk fold`, board `[]`, potResults `[{winners:[3], amount 90, "Pot"}]`, heroNet 0.

```
PokerStars Hand #178187046000002: Hold'em No Limit (10/20) - 2026/06/19 21:01:00 ET
Table 'All-In Dojo' 6-max Seat #1 is the button
Seat 1: You (2000 in chips)
Seat 2: Ivey (2000 in chips)
Seat 3: Polk (2000 in chips)
Seat 4: Dwan (2000 in chips)
Seat 5: Selbst (2000 in chips)
Seat 6: Galfond (2000 in chips)
Ivey: posts small blind 10
Polk: posts big blind 20
*** HOLE CARDS ***
Dealt to You [7h 2c]
Dwan: raises 40 to 60
Selbst: folds
Galfond: folds
You: folds
Ivey: folds
Polk: folds
Uncalled bet (40) returned to Dwan
Dwan collected 50 from pot
*** SUMMARY ***
Total pot 50 | Rake 0
Seat 1: You (button) folded before Flop
Seat 2: Ivey (small blind) folded before Flop
Seat 3: Polk (big blind) folded before Flop
Seat 4: Dwan collected (50)
Seat 5: Selbst folded before Flop
Seat 6: Galfond folded before Flop
```

The engine's pot result says Dwan won 90 (it never returns uncalled bets); the
exporter reports the PokerStars view: 40 returned, 50 collected.

### 7.5 Replay frames — `buildReplayFrames(h)`

```dart
class ReplayFrame { String text; Street street; List<Card> board; int pot; List<int> folded; bool? revealAll; }
```

```
committed = {each seat: 0}; committed[sbSeat] = sb; committed[bbSeat] = bb
pot = sb + bb; folded = []
bbFmt(chips) = v = chips / bb; integer ? "$v" : v.toStringAsFixed(1)      // 10/20 → "0.5", 60/20 → "3", 50/20 → "2.5"
frames = [ {text: "Blinds ${bbFmt(sb)}/${bbFmt(bb)} bb posted.", street: preflop, board: [], pot, folded: []} ]
for street in [preflop, flop, turn, river]:
  boardForStreet = preflop → []; flop → board[0..3] if length >= 3 else null; turn → board[0..4] if >= 4 else null; river → board[0..5] if >= 5 else null
  if (street != preflop):
    if (boardForStreet == null) continue                     // street never dealt
    reset every committed to 0
    frames.add({text: "${Capitalized street}: ${boardForStreet.join(" ")}", street, board: boardForStreet, pot, folded: copy})
  vis = boardForStreet ?? []
  for a in actions of this street:
    fold  → folded.add(seat); text "${name} folds"
    check → text "${name} checks"
    call  → pot += amount; committed[seat] += amount; text "${name} calls ${bbFmt(amount)} bb" + (allIn ? " (all-in)" : "")
    bet   → pot += amount - committed[seat]; committed[seat] = amount; text "${name} bets ${bbFmt(amount)} bb" + all-in suffix
    raise → pot += amount - committed[seat]; committed[seat] = amount; text "${name} raises to ${bbFmt(amount)} bb" + all-in suffix
    frames.add({text, street, board: vis, pot, folded: copy})
winnerIds = distinct winners across potResults (first-seen order)
names = winnerIds.map(seat name ?? "Seat ${id+1}")
total = sum potResults.amount
endStreet = board.length >= 5 ? showdown : == 4 ? turn : == 3 ? flop : preflop
frames.add({text: names.isEmpty ? "Hand over." : "${names.join(", ")} win ${bbFmt(total)} bb.",
            street: endStreet, board: full board, pot, folded: copy, revealAll: true})
```

The final frame's `pot` is the running total (uncalled chips included), not
the engine's `pot`.

Tested: for hand 1 above, more than 4 frames; first frame text contains
`"Blinds"`; last frame has a 5-card board, `revealAll == true`, and `pot >=` the
first frame's pot; some frame has `street == flop` with a 3-card board.

---

## 8. Test scripts — inputs and expectations to pin in Dart

All four run under Node with the TS engine and pass at the time of writing.

### 8.1 `scripts/sim_test.ts` (observed: `3000 passed, 0 failed over 600 hands (130 showdowns, 24 all-in runouts)`)

- Config `{seats 6, startingStack 2000, sb 10, bb 20}`; `createTable`; default archetypes from `archetypeForSeat` (seat 0 is still `isHero` but with no archetype, so `decideBot` folds it every hand — that is what the test does).
- 600 hands; each: `startHand`, then loop `while phase == betting && toAct != null` applying `decideBot(state, toAct).action` (ranges are not stored in this test). Loop guard 5000 steps.
- Per hand assertions (5 × 600 = 3000): `phase == "hand-over"`; all stacks ≥ 0; `sum(stacks) == sum(stacksAtStart)`; `board.length ∈ {0,3,4,5}`; `sum(potResults.amount) == state.pot`.

### 8.2 `scripts/table_config_test.ts` (observed: `3422 passed, 0 failed`)

Configs and hand counts: heads-up `{2, 2000, 10, 20}` × 250; 6-max + ante `{6, 2000, 10, 20, ante 5}` × 250; 9-max `{9, 2000, 10, 20}` × 200; 9-max + ante `{9, 2000, 10, 20, ante 5}` × 150. Every seat is made a bot: `isHero false`, `archetype = [TAG, LAG, Nit, Station][i % 4]`.

Per hand: `totalBefore = sum(stacks after deal) + pot after deal`; run the hand with bots; assert `phase == hand-over`, `sum(stacks) == totalBefore`, no negative stacks, `sum(potResults.amount) == pot`.

On hands 0 and 1 only: heads-up → positions include `BTN` and `BB`, the BTN player's `committed == smallBlind`, `toAct == BTN id`; 9-max → exactly one `BTN`, ≥ 5 distinct labels; ante configs → `pot == sb + bb + ante * seats` and some player has `committed == 0 && committedTotal > 0`.

### 8.3 `scripts/hh_test.ts` (observed: `41 passed, 0 failed`)

Substring assertions on hand 1 output (must be present): `` `PokerStars Hand #${startedAt*100 + 1}: Hold'em No Limit (10/20)` ``, `Seat #1 is the button`, `Ivey: posts small blind 10`, `Polk: posts big blind 20`, `*** HOLE CARDS ***`, `Dealt to You [As Ks]`, `Dwan: raises 40 to 60`, `You: calls 60`, `*** FLOP *** [Ah Kd 7c]`, `Dwan: bets 80`, `*** TURN *** [Ah Kd 7c] [2s]`, `*** RIVER *** [Ah Kd 7c 2s] [9h]`, `You: bets 120`, `*** SHOW DOWN ***`, `You: shows [As Ks] (two pair, Aces and Kings)`, `Dwan: shows [Qh Qd] (a pair of Queens)`, `You collected 520 from pot`, `*** SUMMARY ***`, `Total pot 520`, `Board [Ah Kd 7c 2s 9h]`, `Seat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings`, `Seat 4: Dwan showed [Qh Qd] and lost with a pair of Queens`, `Seat 2: Ivey (small blind) folded before Flop`, `Seat 3: Polk (big blind) folded before Flop`. Must be absent: `Ivey: shows`, `Selbst: shows`.

Hand 2 (fold-out) present: `` `PokerStars Hand #${startedAt*100 + 2}:` ``, `Uncalled bet (40) returned to Dwan`, `Dwan collected 50 from pot`, `Total pot 50`, `Seat 4: Dwan collected (50)`, `Seat 1: You (button) folded before Flop`. Absent: `*** SHOW DOWN ***`, `Dwan: shows`, `Board [`.

Replay-frame assertions as in §7.5.

### 8.4 `scripts/bot_test.ts` (observed: `1210 passed, 0 failed`; `stab-every-check bot: -79 bb/100`; `open-jam maniac: -856 bb/100`)

Run A (1200 hands, all six seats bots with `archetype = [TAG, LAG, Nit, Station][i % 4]`, `isHero false`, ranges stored into `botRanges` after every decision exactly as the store does):
- every hand completes;
- `> 5000` preflop decisions observed;
- `0` folds of AA/KK preflop;
- `0` calls by junk labels (§6.10) of `callAmount >= 8 * bb`;
- `0` decisions where `range != null && action != fold` and the range lacks the actual label;
- `> 200` postflop decisions where the stored range had `> 8` labels and the new range is shorter;
- `0` postflop decisions where the stored range had `> 8` labels and the new range is longer;
- `>= 3` distinct values of `round((bet.amount / pot) * 4) / 4` over postflop bets;
- `> 0` postflop raises by a seat that had checked earlier on the same street (check-raise).

Run C (1200 hands, hero seat 0 plays: preflop check if possible, else call if `callAmount <= bb`, else fold; postflop bet `max(minRaiseTo, round(pot*0.66))` whenever `canBet`, else check, else fold; bots `[TAG, LAG, Nit, Station][(i-1) % 4]`): `sum(heroNetChips) < 0`.

Run B (1000 hands, hero raises to `maxRaiseTo` at every preflop opportunity, otherwise check → call → fold): `sum(heroNetChips) < 0`.

These are statistical; on a port, run them with a fixed seed and a comfortable
margin. The junk-call and premium-fold properties are exact (deterministic
consequences of the policy) and should hold with any seed.

---

## 9. Porting notes, quirks and risks

1. **Randomness is global and unseeded** (`Math.random` in `createTable` button, `shuffle`, every bot decision, unseeded equity sampling). Inject a `Random` into the engine and bot so Dart tests can be deterministic; keep the *order* of draws documented in §6.6 if you want to reproduce TS sessions.
2. **No legality validation** in `applyAction`; the UI and bots must clamp via `legalActions`. Decide whether the Dart engine should assert instead (recommended: throw in debug).
3. **`canFold` is always true**; the UI hides it when a check is free.
4. **Uncalled bets are not returned at showdown**; they ride as a single-eligible side pot, labelled `Side pot N`, and the pot label logic counts it. The exporter (§7) handles the PokerStars view separately.
5. **Odd chip**: engine gives it to the winner closest left of the button; the exporter uses `round(amount / winners)` per winner, which can differ by one chip. Keep both behaviours (or fix both together and update the tests).
6. **`psDate` uses local time** and hard-codes ` ET`. Decide on the mobile app's timezone policy (PokerStars imports do not care).
7. **Antes are invisible in the export** (no posts lines), so `Total pot` includes ante chips that never appear as posts.
8. **9-max positions** reuse `UTG`/`MP`/`CO` twice; `vsRfi` has no `UTG_vs_UTG`, `MP_vs_MP`, `CO_vs_CO`, or any `UTG_vs_*` / `MP_vs_CO` / `*_vs_BB` keys, so those spots fall into the "facing 3-bet or uncharted" branch even against a single open.
9. **Bots heads-up vs the hero use vs-random equity** because the hero never has a stored range; bot-vs-bot heads-up uses the narrowed range with 260 samples. Multiway always uses vs-random (320).
10. **Synchronous Monte-Carlo on the UI thread**: a postflop decision costs one 260/320-sample equity run plus, in `narrowRange`, up to ~169 × 80-sample seeded runs (flop/turn). On mobile run bot decisions in an isolate or precompute; the store already inserts a `speedMs` delay (default 700 ms) between bot actions in auto mode.
11. **Key/insertion order dependence**: `chartLabels` and `collected` iterate in insertion order (JSON order of `preflop.ts`, potResults order). Use `LinkedHashMap` semantics in Dart.
12. **`Math.round`** rounds halves toward +∞; Dart `round()` rounds halves away from zero — identical for the non-negative values used here.
13. **`GamePhase`** values `street-end` and `showdown` and `LogEntry.kind == info` are declared but never produced; `Player.sittingOut` is never read. `ActionType.post` is a no-op that still advances the turn — do not expose it.
14. **Learning reveal**: at every hand end (fold-out or showdown) all dealt hands get `revealed = true`, including folders. The exporter deliberately ignores this and only "shows" players who reached showdown.
15. **`pot` stays populated at hand-over** (equals the distributed total) — the UI relies on this to display the final pot; tests assert it.
16. **Auto-rebuy**: `startHand` resets any stack ≤ 0 to `startingStack` (including the hero); the store ends the session before this can happen to the hero.
17. `lastAction` labels persist across streets for folded and all-in players (they are cleared only for players who can still act), so the table can keep showing `Fold` / `All-In` badges.
18. The `Station` 3-bet override: because the `PREMIUM` clamp runs after the archetype branch, Stations 3-bet AA/KK/QQ/AKs/AKo at ≥ 85% frequency despite the "only raise monsters" comment. Port it as written; the tests were tuned against it.

---

## Appendix A. Errata and under-specified details (read with §1, §5, §6.9, §7)

This appendix pins down details that the sections above stated loosely or not
at all. Where it contradicts an earlier line, the appendix wins; the four
lines it supersedes have already been corrected in place and cross-reference
back here.

### A.1 `botNameFor` — only 8 of the 10 `BOT_NAMES` are reachable

Source: `src/game/archetypes.ts`, `src/game/engine.ts`.

```ts
const BOT_NAMES = [
  "Ivey", "Negreanu", "Polk", "Selbst", "Hellmuth",
  "Brunson", "Antonius", "Dwan", "Galfond", "Chidwick",
];
export function botNameFor(seat: number): string {
  return BOT_NAMES[(seat - 1 + BOT_NAMES.length) % BOT_NAMES.length];
}
```

The `+ BOT_NAMES.length` before the `%` exists only to keep `seat = 0` from
producing a negative JS index; it is never exercised, because the sole caller
is `createTable`:

```ts
for (let i = 0; i < config.seats; i++) {
  ...
  name: isHero ? "You" : botNameFor(i),      // i === player id; i === 0 is the hero, named "You"
```

So the `seat` parameter is the **player id** (0-based seat index), and
`botNameFor` is only ever called with `i >= 1`.

Reachability. The only supported table sizes are `seats ∈ {2, 6, 9}` (§2,
`GameConfig`; the store coerces anything else to 6). Player ids therefore run
`0..8` at most, id 0 is always the hero, and the bots occupy ids `1..8`:

| player id | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| `BOT_NAMES` index | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| name | Ivey | Negreanu | Polk | Selbst | Hellmuth | Brunson | Antonius | Dwan |

- 2-max: hero + `Ivey`.
- 6-max: hero + `Ivey, Negreanu, Polk, Selbst, Hellmuth`.
- 9-max: hero + `Ivey, Negreanu, Polk, Selbst, Hellmuth, Brunson, Antonius, Dwan`.

**`Galfond` (index 8) and `Chidwick` (index 9) can never appear in the live
game.** They would require player ids 9 and 10, i.e. a 10- or 11-seat table,
which the config does not allow. Keep both names in the ported `BOT_NAMES`
list anyway (the modulo and the list length are load-bearing for the mapping),
but do not treat their absence at a real table as a seat-indexing bug — a
9-max table's last bot is `Dwan`, not `Galfond`.

The earlier claim in §5 that seat 9 is `Galfond` is arithmetically correct for
`botNameFor(9)` and is only relevant to a hypothetical 10-seat table; no live
table ever calls it with 9.

**The §7.4 hand-history example is not `botNameFor` output.** Its seat list
`You(BTN) Ivey(SB) Polk(BB) Dwan(UTG) Selbst(MP) Galfond(CO)` is hand-written
fixture data in `scripts/hh_test.ts` (and likewise in
`scripts/hhimport_test.ts`), chosen to be readable rather than generated:
`botNameFor` for a 6-max table would give `Ivey, Negreanu, Polk, Selbst,
Hellmuth` at ids 1..5. `formatHand` only ever reads `HHSeat.name`, so any
names are valid input to the exporter. Do not reverse-engineer the seat→name
mapping from that example, and do not "fix" the fixture to match
`botNameFor` — the pinned substring assertions in §8.3 quote those exact
names (`Selbst: shows` must be **absent**, etc.). `scripts/_coach_wide.mts`
uses a third, different, hand-written name list for the same reason.

Also note the same seat parameter convention in `archetypeForSeat(i)`, called
with the same `i` (player id) in `createTable`. The live app then throws that
result away and re-rolls a uniform-random archetype per bot seat (§5.1), so
`archetypeForSeat` only determines the archetypes of a table built directly
with `createTable` — which is what the test scripts do.

### A.2 `Dials` (see §1)

Source: `src/types/poker.ts`.

```ts
dials?: { aggression: number; stickiness: number; cbetFlop: number };
```

There is no named TS interface — it is an inline object type on `Player`.
§1 now declares it as an explicit `Dials` class so the domain-types section is
self-contained. Notes for the port:

- The whole object is optional (`null` for the hero and for any bot built by
  `createTable` without going through `newSession`), but its three fields are
  **required** when it is present. Never model it as a partial/patchy map.
- `cbetFlop` is a **percentage** (`cfg.cbetFlop / 100` at the use site in
  `botBrain.ts`), and after jitter it is fractional — so it is a `double` in
  Dart even though `ArchetypeConfig.cbetFlop` is written as an `int`.
- Consumption is a spread-merge, not a field-by-field null check:
  `const cfg = { ...ARCHETYPES[p.archetype], ...(p.dials ?? {}) }`. In Dart,
  resolve it once per decision as
  `aggression = p.dials?.aggression ?? ARCHETYPES[p.archetype].aggression`
  (and the same for `stickiness` and `cbetFlop`); every other
  `ArchetypeConfig` field (`vpip`, `pfr`, `name`, `blurb`, `color`) always
  comes from the archetype, because `dials` carries only those three keys.
- Construction and the exact jitter formula are in §5.1; ranges after clamping
  are `aggression`/`stickiness` `[0.05, 0.95]` and `cbetFlop` `[20, 95]`.

### A.3 `FOLD_STREET_PHRASE` has a `?? "before Flop"` default (§7.3 step 13)

Source: `src/game/handHistory.ts`.

```ts
const FOLD_STREET_PHRASE: Record<string, string> = {
  preflop: "before Flop",
  flop: "on the Flop",
  turn: "on the Turn",
  river: "on the River",
};
...
lines.push(`Seat ${seatNo(s.seat)}: ${s.name}${tag} folded ${FOLD_STREET_PHRASE[foldStreet] ?? "before Flop"}`);
```

The map is keyed by `Street`, whose declared values also include `showdown`
(§1) — hence the fallback. In practice it is dead code: `foldedOn` is only
ever written from a `fold` action's `street` (never `showdown`) or from the
defensive "no actions at all" rule, which writes the literal `"preflop"`
(§7.3 step 6). The branch is nonetheless reachable in a Dart port for the
wrong reason: a `Map<Street, String>` lookup on an unmapped street returns
`null`, and string interpolation of `null` prints the four characters `null`,
producing `Seat 5: Selbst folded null` instead of a valid PokerStars line.

Port it with the default present:

```dart
const foldStreetPhrase = <Street, String>{
  Street.preflop: 'before Flop',
  Street.flop: 'on the Flop',
  Street.turn: 'on the Turn',
  Street.river: 'on the River',
};
final phrase = foldStreetPhrase[foldStreet] ?? 'before Flop';
```

The exact user-facing strings are `before Flop`, `on the Flop`, `on the Turn`,
`on the River` — capitalised street names, lower-case preposition, no trailing
punctuation. The full line is
`Seat ${seat + 1}: ${name}${tag} folded ${phrase}` with `tag` per §7.3 step 13.

### A.4 `psHandName` inputs are the evaluator's exact `name` strings (§7.2)

Source: `src/game/handHistory.ts` (`psHandName`), `src/engine/evaluator.ts`
(the `name` producers).

The §7.2 table's left column is the **verbatim** output of
`evaluateCards(...).name`. The evaluator spells ranks out in full:

```ts
const RANK_NAME = { 14:"Ace", 13:"King", 12:"Queen", 11:"Jack", 10:"Ten",
                    9:"Nine", 8:"Eight", 7:"Seven", 6:"Six", 5:"Five",
                    4:"Four", 3:"Three", 2:"Two" };
const RANK_NAME_PLURAL = { 14:"Aces", 13:"Kings", 12:"Queens", 11:"Jacks",
                    10:"Tens", 9:"Nines", 8:"Eights", 7:"Sevens", 6:"Sixes",
                    5:"Fives", 4:"Fours", 3:"Threes", 2:"Twos" };
```

so a king-high straight flush is named `Straight Flush, King high` — never
`Straight Flush, K high`. (Single-letter rank codes appear only inside `Card`
strings such as `"Kd"`, never in a hand name.) The `slice` offsets in
`psHandName` are the lengths of the matched prefixes, and they are what make
the transformation lossless:

| prefix test | prefix length / `slice` | remainder for the example |
|---|---|---|
| `startsWith("Pair of")` | 7 | `" Queens"` → `a pair of Queens` |
| `startsWith("Two Pair")` | 8 | `", Aces and Kings"` → `two pair, Aces and Kings` |
| `startsWith("Three of a Kind")` | 15 | `", Queens"` → `three of a kind, Queens` |
| `startsWith("Straight Flush")` | 14 | `", King high"` → `a straight flush, King high` |
| `startsWith("Straight")` | 8 | `", Ten high"` → `a straight, Ten high` |
| `startsWith("Flush")` | 5 | `", Ace high"` → `a flush, Ace high` |
| `startsWith("Full House")` | 10 | `", Aces full of Kings"` → `a full house, Aces full of Kings` |
| `startsWith("Four of a Kind")` | 14 | `", Aces"` → `four of a kind, Aces` |
| `=== "Royal Flush"` | — | `a royal flush` |
| `endsWith("High")` | `slice(0, -5)` | `"Ace High"` → `high card Ace` |
| fallback | — | `n.toLowerCase()` |

`"Straight Flush"` is 14 characters, so `n.slice(14)` on
`"Straight Flush, King high"` yields `", King high"` and the result is
`a straight flush, King high` — the offset is correct; §7.2's earlier
`K high` sample was the malformed part and has been corrected in place.

Two behaviours that are easy to lose in a port:

1. The `" & " → " and "` replacement runs **once, on the whole string, before
   any prefix test** (`.replace(" & ", " and ")` — JS string-pattern replace
   replaces only the first occurrence; hand names contain at most one `" & "`,
   in `Two Pair`).
2. The check order is exactly as listed above. `Straight Flush` must be tested
   before `Straight`, and `Flush` after both, or `"Straight Flush, King high"`
   would match the `Straight` branch and produce `a straight  Flush, King high`.
   `Royal Flush` is an equality test, and it sits after the `Flush`
   `startsWith` test in the source — but it is still reachable, because
   `"Royal Flush"` does not start with `"Flush"`.

### A.5 `narrowRange` aggro slices may overlap — do NOT dedupe (§6.9)

Source: `src/game/botBrain.ts`.

```ts
if (kind === "aggro") {
  const top = scored.slice(0, Math.max(5, Math.round(n * 0.45))).map((x) => x.label);
  const tail = scored.slice(Math.round(n * 0.85)).map((x) => x.label);
  kept = [...top, ...tail];
}
```

This is a plain concatenation with **no dedupe**, so when the two index ranges
intersect the returned range contains the same `HandLabel` twice. Overlap
happens when `round(n * 0.85) < max(5, round(n * 0.45))` **and** the tail is
non-empty (`round(n * 0.85) < n`), where `n = scored.length` — the number of
stored labels that survived the fully-blocked-by-board filter, which can be
smaller than `stored.length`:

| `n` | top end `max(5, round(0.45n))` | tail start `round(0.85n)` | duplicated? |
|---|---|---|---|
| 1–3 | 5 | ≥ `n` | no — tail slice is empty |
| 4 | 5 | 3 | **yes** — index 3 appears twice |
| 5 | 5 | 4 | **yes** — index 4 appears twice |
| 6 | 5 | 5 | no |
| 7 | 5 | 6 | no |
| 8 | 5 | 7 | no |
| 9 | 5 | 8 | no |
| ≥ 10 | `round(0.45n)` | `round(0.85n)` | no (`0.45n < 0.85n`) |

The function early-returns for `stored.length <= 8`, so a duplicate requires
`stored.length >= 9` **and** `n ∈ {4, 5}`, i.e. at least four stored labels
fully blocked by the board (every combo of the label using a board card).
That is vanishingly rare with real ranges and does not occur in the recorded
test runs — the tested invariant "postflop ranges never grow"
(`postflopGrowths === 0` in `scripts/bot_test.ts`) holds in practice.

Porting rule: **reproduce the concat verbatim; do not wrap it in a `Set`, do
not call `.toSet().toList()`, and do not use a `LinkedHashSet` accumulator.**
Reasons:

- `scripts/bot_test.ts` compares `dec.range.length` against the previous
  stored length to count narrowings and growths (`before > 8 && dec.range.length
  < before` → `postflopNarrowings`, `> before` → `postflopGrowths`, asserted
  `> 200` and `=== 0` respectively). A dedupe changes those lengths whenever
  the stored range itself already contained a duplicate, which flips
  no-change cases into narrowings and shifts the counts a Dart port is
  expected to match.
- The result is written straight back into `botRanges[seat]` and becomes the
  *next* decision's `stored`, so list-vs-set semantics compound across a hand:
  a duplicated label is scored twice on the following street and re-duplicated
  through subsequent slices.
- The opponent-range equity path reads the same list; `dec.range.length > 0`
  gates the "vs range" branch (§6.5/§9 note 9).

The final guard is already dedupe-aware and must keep its exact form —
`if (!kept.includes(actualLabel) && stored.includes(actualLabel)) kept.push(actualLabel)`
— i.e. it appends the bot's actual label only when the label is missing from
`kept` **and** was present in `stored`; it never removes anything.

The `call` and `check` kinds take a single slice each and can never duplicate.
