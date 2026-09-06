# Play loop and EV coach — port specification

Source subsystem of the desktop app "All-In · Poker Dojo" (React + TypeScript + Zustand).
This document is the complete behavioural specification of the **play session loop**, the
**EV coach**, the **guess-range / peek** flow, the **HUD**, the **range matrix**, the
**session summary**, the **hand replayer model**, the **daily goals / streak** logic and the
**settings** that these depend on. It is written so that the Flutter/Dart port can be built
without reading the TypeScript.

Source files covered (paths relative to the desktop repo `/Users/gapp/Documents/Code/poker`):

| File | Role |
|---|---|
| `src/store/gameStore.ts` | Session lifecycle, bot scheduling, coach evaluation (`evaluateHero`), bot-move explanations, guess/peek scoring |
| `src/store/settingsStore.ts` | App-wide persisted settings + `coachThresholds` |
| `src/store/goalStore.ts` | Daily activity, goal, streak |
| `src/lib/format.ts` | Number/phrase formatters used by every user-facing string |
| `src/components/coach/EVCoachPanel.tsx` | Coach note UI (three TONE layers) |
| `src/components/coach/RangeViewModal.tsx` | Read-only "assumed range" popup |
| `src/components/play/ResultOverlay.tsx` | End-of-hand card with the learning reveal |
| `src/components/play/SessionSummaryModal.tsx` | Session debrief |
| `src/components/play/HandReplayModal.tsx` | Frame-by-frame replayer |
| `src/components/play/SideRail.tsx` | Session stats, pace, coach toggle, hand log |
| `src/components/table/*.tsx` | Table, seats, HUD, cards, pot, board, action bar |
| `src/components/range/*.tsx` | Guess modal + 13×13 range matrix |
| `src/views/PlayView.tsx` | Composition + start-session overlay |
| `TONE.md` | Writing rules for all coach copy (summarised in §14) |

Related subsystems that this one *calls* but does not own (documented elsewhere; only their
contracts are restated here): the hand engine (`src/game/engine.ts`), the bot brain
(`src/game/botBrain.ts`), the equity engine (`src/engine/equity.ts` / Rust twin), hand
notation (`src/engine/notation.ts`), preflop charts (`src/data/preflop.ts`), the stats store
and its DB, the leak store (spaced-repetition review queue), the hand-history exporter.

Notation used below: `{slot}` marks a variable inserted into a template. Formatter names
(`fmtBb`, `fmtTimes`, …) are defined in §11. All money is in **chips** internally; the user
sees **big blinds** (bb) almost everywhere.

---

## 1. Domain types this subsystem relies on

These come from `src/types/poker.ts`. The Dart port must model at least these fields.

```
Card       = String              // "Ah", "Td", "2c" — rank char + suit char (c d h s)
HandLabel  = String              // 13×13 grid label: "AA", "AKs", "AKo"
Position   = UTG | MP | CO | BTN | SB | BB
Street     = preflop | flop | turn | river | showdown
ActionType = fold | check | call | bet | raise | post
Archetype  = TAG | LAG | Nit | Station

Action { type: ActionType; amount?: int /* TOTAL chips in front of the player on this street for bet/raise; for call the store passes callAmount */; allIn?: bool }

PlayerLastAction { label: String /* "Raise","Call","Check","Fold","All-In","Bet","SB","BB" */; street: Street }

Player {
  id: int                 // seat index 0..n-1; seat 0 is ALWAYS the hero
  name: String            // hero: "You"; bots: see §4.3
  isHero: bool
  archetype?: Archetype   // undefined for hero
  stack: int
  hole: [Card, Card]?     // null between hands
  revealed: bool          // cards face-up (showdown or end-of-hand learning reveal)
  foldedStreet?: Street   // set when the player folds
  hasFolded: bool
  isAllIn: bool
  committed: int          // chips put in on the CURRENT street
  committedTotal: int     // chips put in this hand (incl. antes)
  acted: bool
  position: Position
  lastAction: PlayerLastAction?
  handsSeen: int          // incremented for every player at every startHand
  vpipCount: int          // +1 the first time the player calls/bets/raises preflop in a hand
  pfrCount: int           // +1 the first time the player bets/raises preflop in a hand
  dials?: { aggression: double; stickiness: double; cbetFlop: double }  // per-session jitter (§4.2)
  sittingOut: bool
}

GamePhase = idle | betting | street-end | showdown | hand-over

PotResult     { winners: int[]; amount: int; potLabel: String /* "Pot" | "Main pot" | "Side pot n" */ }
ShowdownEntry { playerId: int; hole: [Card,Card]; hand: EvaluatedHand?; hadToShow: bool }
EvaluatedHand { category: int; score: int; name: String }   // name e.g. "Two Pair, Aces & Kings"
HandSummary   { handNumber: int; potResults: PotResult[]; showdown: ShowdownEntry[]; board: Card[]; heroNetChips: int }
LogEntry      { id: int; street: Street; text: String; kind: action | deal | result | info }
GameConfig    { seats: int /*2|6|9*/; startingStack: int; smallBlind: int; bigBlind: int; ante?: int }

LegalActions {
  toCall: int          // currentBet - player.committed (may be <= 0)
  canFold, canCheck, canCall, canBet, canRaise: bool
  callAmount: int      // min(toCall, stack)
  minRaiseTo: int      // total-to; currentBet==0 ? min(bb, committed+stack) : min(currentBet+lastRaiseSize, committed+stack)
  maxRaiseTo: int      // committed + stack
  potSize: int; bigBlind: int
}

GameState {
  config: GameConfig; players: Player[]; button: int; street: Street; board: Card[]; deck: Card[]
  pot: int; currentBet: int; lastRaiseSize: int
  aggressor: int?      // seat of the last bettor/raiser this street; = BB seat at hand start; null after a street closes
  toAct: int?          // null when nobody can act
  handNumber: int; smallBlind: int; bigBlind: int; phase: GamePhase
  log: LogEntry[]      // engine keeps the last 200 entries
  logSeq: int
  botRanges: Map<int, HandLabel[]>   // per-bot perceived range, written by the store after every bot action; reset to {} at startHand
  stacksAtStart: int[]               // per seat, after auto-rebuy, before blinds/antes
  summary: HandSummary?              // set at hand-over
}
```

Engine facts the play loop depends on (from `src/game/engine.ts`):

* `createTable(config)`: seats players; hero at seat 0 named "You"; bots named by
  `botNameFor(seat)` = `["Ivey","Negreanu","Polk","Selbst","Hellmuth","Brunson","Antonius","Dwan","Galfond","Chidwick"][(seat-1) mod 10]`;
  archetype pre-assigned by `archetypeForSeat` (the store overrides this, see §4.2); random button;
  phase `idle`; handNumber 0.
* `startHand(prev)`: handNumber += 1; button moves +1 (except for hand 1); **every player with
  stack ≤ 0 is refilled to `config.startingStack`** (engine-level auto-rebuy); per-hand player
  fields reset; `handsSeen += 1` for everyone; fresh shuffled deck; two hole cards each;
  `stacksAtStart` captured **after** rebuy and **before** antes/blinds; antes (if any) go to the pot
  and to `committedTotal` only; blinds posted (heads-up: the button posts the SB and acts first
  preflop; otherwise SB = button+1, BB = button+2); `aggressor = bbSeat`; `currentBet = bb`;
  `botRanges = {}`; `phase = betting`; log entry `Hand #{n} · blinds {sb}/{bb}` plus ` · ante {a}`
  when antes are on; first to act = button+3 (or the SB seat heads-up).
* Positions: 6-max labels by offset from the button `[BTN, SB, BB, UTG, MP, CO]`; 9-max is
  approximated onto the same six labels `[BTN, SB, BB, UTG, UTG, MP, MP, CO, CO]`; heads-up is
  `BTN` (button/SB) and `BB`.
* `applyAction(state, seat, action)` returns a new state; ignores the call if `phase != betting`
  or `toAct != seat`. Labels written to `lastAction`: Fold / Check / Call / Bet / Raise, or
  `All-In` whenever the call/bet/raise leaves the player with 0 chips. Log lines:
  `{name} folds`, `{name} checks`, `{name} calls {amt}[ (all-in)]`, `{name} bets {to}[ (all-in)]`,
  `{name} raises to {to}[ (all-in)]`. A bet's amount is coerced to at least `min(bb, committed+stack)`
  and at most `committed+stack`.
* When a street closes: committed reset to 0, `currentBet = 0`, `lastRaiseSize = bb`,
  `aggressor = null`, `lastAction` cleared for players still able to act, log
  `Flop — {c1} {c2} {c3}` / `Turn — …` / `River — …` (`kind: deal`); if ≤ 1 player can still act,
  remaining streets are run out immediately to showdown.
* Hand end: `settleByFold` (log `{name} wins {amount} (uncontested)`) or `settleShowdown`
  (log per pot `{names joined ", "} wins {amount} ({potLabel})`, street `showdown`). Both set
  `revealed = true` for every player who has hole cards (learning reveal), `toAct = null`,
  `phase = hand-over`, and `summary.heroNetChips = players[0].stack - stacksAtStart[0]`.

---

## 2. Constants and magic numbers

| Name | Value | Where used |
|---|---|---|
| `BASE_CONFIG` | `{ seats: 6, startingStack: 2000, smallBlind: 10, bigBlind: 20 }` | table creation (seats/ante overridden by table options) |
| `TABLE_KEY` | `"allin.table.v1"` | localStorage key for `{seats, ante}` |
| `ARCHE_POOL` | `["TAG","LAG","Nit","Station"]` | random archetype per bot per session |
| jitter (aggression) | ×U[0.8, 1.2], clamp [0.05, 0.95] | §4.2 |
| jitter (stickiness) | ×U[0.8, 1.2], clamp [0.05, 0.95] | §4.2 |
| jitter (cbetFlop) | ×U[0.85, 1.15], clamp [20, 95] | §4.2 |
| default play settings | `coachEnabled: true, mode: "manual", speedMs: 700` | not persisted |
| `SPEEDS` | Slow 1100 ms · Normal 700 ms · Fast 360 ms | auto-pace delay between bot actions |
| `baseIters` | 1600 (`simQuality: standard`) / 4000 (`high`) | Monte-Carlo trials per verdict |
| escalation | ×4 trials, seed+1 | when `|equity − threshold| < 2·se` and not exact and costNow > 0 |
| `margin` | `2 · se` | ~95 % half-width used in all verdict guards |
| `coachThresholds` | relaxed `{mistakeBb: −0.6, foldFlagBb: 2.5}` · standard `{−0.3, 1.5}` · strict `{−0.15, 1.0}` | §7 |
| call "thin" band | `equity < potOdds + 0.04` | §7.3 |
| call "great" | `equity > 0.70` | §7.3 |
| check flag floor | board ≥ 3 cards and `equity ≥ 0.65`; "strong" = `equity − margin > 0.75` | §7.4 |
| value-bet size hint | `round(pot × 0.66)` | §7.4, leak options |
| bluff mistake | `equity + margin < 0.32` and `evBluff < −0.75 bb` | §7.5 |
| continue-rate model | `continueFrac = clamp(0.62 − 0.2·betFrac, 0.30, 0.75)` | §7.5 |
| bet "great" | `equity > 0.60`; bet "thin" | `equity < 0.38 && cost > 0.5·pot` | §7.5 |
| `MIN_SAMPLE` (HUD) | 8 hands | §16 |
| hero style row | shown when `hero.handsSeen ≥ 8` | §19 |
| guess grades | ≥0.80 "Sharp read" · ≥0.60 "Solid" · ≥0.40 "Rough" · else "Way off" | §13 |
| `DAILY_DRILL_GOAL` | 20 | §22 |
| `DAILY_HAND_GOAL` | 30 | §22 |
| stats rolling windows | last 800 hands / guesses / decisions kept in memory | stats store |
| leak cap | 60 spots | leak store |
| `TOTAL_COMBOS` | 1326 | range percentages |
| combos per label | pair 6 · suited 4 · offsuit 12 | scoring, combo counts |
| ActionBar default size | 66 % of (pot + toCall), added on top of currentBet when facing a bet | §17 |
| ActionBar slider step | `max(1, bb / 2)` chips | §17 |
| replay/table seat geometry | angle `π/2 − 2πi/n`; left `50 + 42cos`, top `48 + 41sin` (table) / `46 + 41sin` (replay), in % | §15 |

---

## 3. Store shape (`useGame`)

```
GameStore {
  table: GameState                       // initial: createTable(BASE_CONFIG) (phase idle)
  thinking: bool                         // auto-pace "dealing" spinner; initial false
  paused: bool                           // blocks hero + bot actions; initial false
  guess: GuessSession?                   // null when the peek modal is closed
  settings: { coachEnabled: bool; mode: "manual"|"auto"; speedMs: int }   // {true, "manual", 700}
  session: { active: bool; startedAt: epochMs; hands: int; netChips: int; history: HHHand[] }
  sessionEnded: bool                     // summary modal visible
  reviewLog: CoachReview[]               // notes for the CURRENT hand (cleared on deal)
  activeReviewId: int?                   // which note the panel shows; null = collapsed pill
  rangeView: { name: String; range: HandLabel[] }?   // read-only matrix popup
  lastActorSeat: int?                    // seat that acted last (any seat, incl. hero)

  newSession(opts?: TableOptions)
  endSession()
  closeSummary()
  deal()
  heroAction(a: Action): Future<void>
  stepBot()
  explainLastBotMove()
  reopenReview(id?: int)
  dismissReview()
  openRangeView(name, range) / closeRangeView()
  openGuess(botId) / peek(painted: HandLabel[]) / closeGuess()
  setSettings(partial)
}

Verdict = mistake | thin | ok | great | info

CoachReview {
  id: int                       // monotonically increasing per app run (reviewSeq starts at 1)
  kind: "decision" | "bot"
  blocking: bool                // true ⇒ pauses play until dismissed
  verdict: Verdict
  title: String
  equity?: double; potOdds?: double; evChips?: double
  villainName?: String; villainArchetype?: Archetype; villainRange?: HandLabel[]
  board: Card[]
  plain?: String                // TONE layer 1 (always shown first)
  text: String                  // layer-2 summary line (may use poker terms)
  steps?: String[]              // layer 2 "Show me the math"
  expert?: String[]             // layer 3 "Expert detail"
  opponents?: int; multiway?: bool
}

GuessSession {
  open: bool; botId: int; street: Street
  revealed: bool; scored: bool
  actualRange: HandLabel[]
  accuracy: double?; precision: double?; recall: double?
}

TableOptions { seats: 2 | 6 | 9; ante: int /* chips: 0 or 5 */ }
```

Private (closure) state: `loopToken: int` (cancels stale auto loops), `reviewSeq: int`,
`currentHH: HHHand?` (the hand-history record being built for the current hand).

### 3.1 Table options persistence

```
loadTableOptions(): read JSON at "allin.table.v1"; seats = v.seats if 2 or 9 else 6; ante = 5 if v.ante == 5 else 0.
                    Any parse error → { seats: 6, ante: 0 }.
saveTableOptions(o): write JSON {seats, ante}; ignore errors.
```

Only the values 2/6/9 and 0/5 are ever accepted; anything else is normalised.

---

## 4. Session lifecycle

### 4.1 `newSession(opts?)`

1. `table = opts ?? loadTableOptions()`; `saveTableOptions(table)`.
2. `base = createTable({ ...BASE_CONFIG, seats: table.seats, ante: table.ante })`.
3. For every non-hero player: pick `archetype = ARCHE_POOL[floor(random()*4)]` (uniform,
   independent per seat — duplicates are normal), and set `dials`:
   ```
   jitter(v, frac, lo, hi) = min(hi, max(lo, v * (1 - frac + random() * 2 * frac)))
   aggression = jitter(cfg.aggression, 0.20, 0.05, 0.95)
   stickiness = jitter(cfg.stickiness, 0.20, 0.05, 0.95)
   cbetFlop   = jitter(cfg.cbetFlop,   0.15, 20,   95)
   ```
   where `cfg = ARCHETYPES[archetype]` (table in §4.3).
4. Set: `table` (with the new players), `session = {active: true, startedAt: now, hands: 0, netChips: 0, history: []}`,
   `sessionEnded=false`, `reviewLog=[]`, `activeReviewId=null`, `guess=null`, `paused=false`, `thinking=false`.
5. Call `deal()`.

Note that `newSession()` with no argument (from the Action bar, the Space key with no session, and
the summary modal's "New session") uses the last saved options.

### 4.2 `deal()`

```
if !session.active: return
if table.players[0].stack <= 0: sessionEnded = true; return           // hero busted → summary (§20)
players = players.map(p => !p.isHero && p.stack <= 0 ? {...p, stack: config.startingStack} : p)   // bot auto-rebuy (store level; engine does it again)
nt = startHand({...table, players})
currentHH = {
  id: nt.handNumber, startedAt: now, button: nt.button, sb: nt.smallBlind, bb: nt.bigBlind,
  sbSeat: seats==2 ? button : (button+1) % seats,
  bbSeat: seats==2 ? (button+1) % seats : (button+2) % seats,
  seats: players.map(p => {seat: p.id, name, stack: nt.stacksAtStart[p.id], isHero, position}),
  holes: { 0: hero.hole },        // bots' holes are added at hand end
  actions: [], board: [], potResults: [], heroNet: 0
}
set table=nt, reviewLog=[], activeReviewId=null, rangeView=null, guess=null, paused=false, thinking=false, lastActorSeat=null
maybeAutoLoop()
```

The hero is **never** auto-rebought: a busted hero ends the session (the summary modal opens with
the "busted" title and no close button; only "New session" continues).

### 4.3 Archetype table (`src/game/archetypes.ts`, verbatim)

| Archetype | name | blurb | vpip | pfr | cbetFlop | aggression | stickiness | color |
|---|---|---|---|---|---|---|---|---|
| TAG | Tight-Aggressive | Plays few hands but bets and raises them hard. The textbook winner. | 22 | 18 | 65 | 0.72 | 0.28 | #2f6fd0 |
| LAG | Loose-Aggressive | Plays many hands with relentless pressure. Hard to put on a hand. | 34 | 27 | 72 | 0.86 | 0.34 | #8a5cd1 |
| Nit | Nit | Extremely tight. If a Nit raises, believe them. | 12 | 9 | 55 | 0.5 | 0.2 | #2faa66 |
| Station | Calling Station | Calls far too much, rarely raises. Value-bet relentlessly, never bluff. | 46 | 7 | 32 | 0.18 | 0.82 | #d23b3b |

### 4.4 `endSession()` / `closeSummary()`

* `endSession()` only sets `sessionEnded = true` (opens the summary modal). **The session stays
  active**; closing the modal (`closeSummary`, `sessionEnded = false`) lets the user keep playing
  the same session. A truly new table only happens through `newSession()`.
* When the hero busted, the modal cannot be closed (see §20).

### 4.5 `applyStep(seat, action, range?)` (internal)

```
t = table
recordAction(t, seat, action)            // hand-history bookkeeping, §4.7
nt = applyAction(t, seat, action)
if range != null: nt.botRanges[seat] = range      // bot's perceived range (§6)
set table = nt, lastActorSeat = seat
if nt.phase == hand-over: finalizeHand(nt)
return nt
```

### 4.6 `heroAction(a)` (async)

```
t = table
if t.phase != betting || t.toAct != 0: return
id = reviewSeq++
coachEnabled = settings.coachEnabled
applyStep(0, a)                          // the action is applied IMMEDIATELY
maybeAutoLoop()                          // bots may start acting while the coach thinks
if !coachEnabled: return
review = await evaluateHero(t, a, id)    // NOTE: evaluated against the PRE-action state t
if review == null: return
if table.handNumber == t.handNumber: pushReview(review)     // panel + possible blocking pause, only if still the same hand
if review.kind == "decision":
  stats.recordDecision({ verdict, action: a.type, equity: review.equity ?? 0, potOdds: review.potOdds ?? 0,
                         evBb: (review.evChips ?? 0) / t.bigBlind, street: t.street,
                         villainArchetype: review.villainArchetype ?? null, position: t.players[0].position, ts: now })
  if review.verdict == "mistake": add a leak spot (below)
```

Leak spot captured for every `mistake` verdict (`useLeaks.add`, cap 60, newest first):

```
la2 = legalActions(t); bb = t.bigBlind
best = a.type == call ? fold : a.type == fold ? call : a.type == check ? bet : a.type == bet ? check : fold
options = la2.toCall > 0
  ? [ {fold, "Fold"}, {call, "Call {(callAmount/bb).toFixed(1)} bb", amount: callAmount}, {raise, "Raise", amount: round(pot + callAmount)} ]
  : [ {check, "Check"}, {bet, "Bet", amount: round(pot * 0.66)} ]
LeakSpot { id: "{handNumber}-{street}-{nowMs}", street, heroPos, hole, board, pot, toCall: callAmount, bb,
           oppActive: positions of non-hero non-folded players, options, best, rationale: review.text,
           equity: review.equity, potOdds: review.potOdds, ts: now }
```

`pushReview(review)`: append to `reviewLog`, `activeReviewId = review.id`, and if `review.blocking`
then `paused = true`.

Timing consequences worth preserving: because the action is applied before the coach finishes,
in auto mode bots can act (and even end the hand) while the sim runs. A blocking verdict pauses
whatever is in flight at the next loop tick. If the user has already dealt the next hand when
the verdict resolves, the note is *not* shown but stats and leaks are still recorded.

### 4.7 Hand-history recording (`recordAction`, `finalizeHand`)

```
recordAction(t, seat, action):
  if currentHH == null: return
  p = t.players[seat]; la = legalActions(t)
  amount = 0; allIn = false
  if action.type == call:            amount = la.callAmount; allIn = amount >= p.stack
  if action.type == bet or raise:    amount = action.amount ?? 0; allIn = amount >= p.committed + p.stack
  currentHH.actions.push({ street: t.street, seat, name: p.name, type: action.type, amount, allIn })

finalizeHand(nt):                       // called once when phase becomes hand-over
  if currentHH != null:
    currentHH.board = nt.board; potResults = nt.summary.potResults; heroNet = nt.summary.heroNetChips
    for every player: currentHH.holes[p.id] = p.hole
    hh = currentHH; currentHH = null; handJson = JSON(hh)
    session.hands += 1; session.netChips += heroNetChips; session.history.push(hh)
  goals.record("hand")                                                  // §22
  if nt.summary:
    stats.recordHand({
      n: handNumber, netBb: heroNet / bb, potBb: sum(potResults.amount) / bb,
      showdown: summary.showdown.length > 0,
      won: any pot's winners include seat 0,
      archetypes: archetypes of bots with committedTotal > bb,       // "involved" bots
      position: hero.position,
      sawFlop: hero.foldedStreet != "preflop",                        // true also when hero never folded
      handJson, ts: now
    }, heroNetChips)
```

`HHHand` (from `src/game/handHistory.ts`):

```
HHAction { street; seat; name; type: ActionType; amount /* call: chips called; bet/raise: total "to" */; allIn }
HHSeat   { seat; name; stack /* at hand start */; isHero; position }
HHHand   { id; startedAt; button; sb; bb; sbSeat; bbSeat; seats: HHSeat[]; holes: Map<int,[Card,Card]?>;
           actions: HHAction[]; board: Card[]; potResults: PotResult[]; heroNet: int }
```

### 4.8 Manual pace — `stepBot()`

```
if paused || guess?.open: return
if table.phase != betting || toAct == null || toAct == 0: return
dec = decideBot(table, toAct)          // bot brain: {action, range}
applyStep(toAct, dec.action, dec.range)
```

One bot action per call. Triggered by the "Next action" button or the → key. `thinking` is not
touched in manual mode.

### 4.9 Auto pace — `scheduleLoop()` / `maybeAutoLoop()`

```
maybeAutoLoop(): if settings.mode == "auto": scheduleLoop()

scheduleLoop():
  myToken = ++loopToken                       // any newer schedule invalidates this one
  step():
    if myToken != loopToken: return           // stale
    s = state; t = s.table
    if s.settings.mode != "auto": return      // (quirk: does NOT reset thinking)
    if s.paused || s.guess?.open: thinking = false; return
    if t.phase != betting || t.toAct == null || t.toAct == 0: thinking = false; return
    thinking = true
    dec = decideBot(t, t.toAct)
    nt = applyStep(t.toAct, dec.action, dec.range)
    if nt.phase == hand-over || nt.toAct == 0: thinking = false; return
    setTimeout(step, settings.speedMs)        // speed read at scheduling time
  setTimeout(step, settings.speedMs)
```

Callers of `maybeAutoLoop`: `deal()`, `heroAction()` (right after applying), `dismissReview()`
(only if the dismissed note was blocking), `closeGuess()`, `setSettings({mode:"auto"})`.
Every bot action in auto mode is therefore preceded by a `speedMs` delay, including the first
one after the hero acts or after the deal. There is no delay for the hero's own action and no
auto-deal: the hand-over state always waits for the user ("Next hand" / Enter / Space).

Known quirk to decide on in the port: switching to manual while a tick is pending leaves
`thinking` true (spinner) until the next deal/pause. The port should clear `thinking` whenever
the loop exits for any reason.

### 4.10 Other actions

```
explainLastBotMove():
  seat = lastActorSeat; if seat == null || seat == 0: return
  p = players[seat]; if !p.archetype: return
  pushReview({ id: reviewSeq++, kind: "bot", blocking: false, verdict: "info",
               title: "{p.name}'s {(p.lastAction?.label ?? "move").toLowerCase()}",
               villainName: p.name, villainArchetype: p.archetype, villainRange: villainRangeFor(table, p),
               board, text: interpretBot(p) })

reopenReview(id?): activeReviewId = id ?? last reviewLog entry's id ?? null
dismissReview():   wasBlocking = reviewLog[activeReviewId]?.blocking; activeReviewId = null; paused = false; if wasBlocking: maybeAutoLoop()
openRangeView(name, range): rangeView = {name, range};  closeRangeView(): rangeView = null
setSettings(p): settings = {...settings, ...p}; if p.mode == "auto": maybeAutoLoop()
```

Quirk: when a street has just closed, the last actor's `lastAction` has been cleared by the
engine, so the title becomes `"{name}'s move"` and `interpretBot` falls through to the
bet/raise wording (label `"acts"` matches none of Fold/Check/Call/All-In). Port may want to
remember the last action label in the store instead.

---

## 5. Bot-move interpretations (`interpretBot`, verbatim)

`label = p.lastAction?.label ?? "acts"`, `a = p.archetype`.

| Condition | Text |
|---|---|
| no archetype | `""` |
| label == "Fold" | `{name} folds — their range no longer matters this hand.` |
| label == "Check" | `A check from {name} usually means a weak hand — or keeping the pot small. Consider betting to take the pot now.` |
| label ∈ {Call, All-In}, Station | `{name} (Station) calls with almost anything — their possible hands stay very wide and weak. Bet your good hands relentlessly; never bluff.` |
| label ∈ {Call, All-In}, Nit | `Even a Nit's call means a fairly strong hand — though they'd raise their very best. Slow down with so-so hands.` |
| label ∈ {Call, All-In}, LAG | `{name} (LAG) calls with lots of hands, often planning to steal the pot later — keep betting your good hands; expect them to call you down with medium ones.` |
| label ∈ {Call, All-In}, TAG | `A call keeps {name}'s possible hands wide — their strongest hands included — proceed with caution.` |
| otherwise (Bet/Raise/…), Nit | `A raise from a Nit is a red flag — expect a premium. Fold your marginal hands.` |
| otherwise, Station | `{name} (Station) almost never raises — when they do, it's usually close to the best possible hand.` |
| otherwise, LAG | `{name} (LAG) raises very wide; this is often a bluff or a bet with only a slim edge. Don't fold too often.` |
| otherwise, TAG | `{name} (TAG) raises mostly genuinely strong hands, few bluffs. Take it seriously unless you have a strong hand too.` |

---

## 6. Villain perceived ranges

### 6.1 `villainRangeFor(state, p)`

```
stored = state.botRanges[p.id]
if stored != null && stored.length > 0: return stored
if p.archetype: cfg = ARCHETYPES[p.archetype]; return buildPreflopRanges(cfg.vpip, cfg.pfr, p.position).play (as a list)
return []
```

So before a bot has acted this hand (or if its stored range is empty), the coach and the peek
feature use a **generic archetype/position range**; afterwards they use the range the bot brain
says it is representing.

### 6.2 Fallback: `buildPreflopRanges(vpip, pfr, pos)` (`src/engine/ranges.ts`)

* All 169 labels are ordered by the **Chen formula** score (ties: pairs > suited > offsuit,
  then higher top card):
  ```
  highCardScore(v) = v==14 ? 10 : v==13 ? 8 : v==12 ? 7 : v==11 ? 6 : v/2      // v = rank 2..14
  pair:     max(5, 2 * highCardScore(hi))
  nonpair:  s = highCardScore(hi); if suited s += 2
            gap = hi - lo - 1; gap==1 → −1; gap==2 → −2; gap==3 → −4; gap>=4 → −5
            if gap <= 1 && hi < 12: s += 1
  ```
* `positionMultiplier`: UTG 0.5 · MP 0.68 · CO 0.9 · BTN 1.25 · SB 0.85 · BB 1.0.
* `playPct = clamp(vpip * mult, 4, 90)`; `raisePct = clamp(pfr * mult, 2, playPct)`.
* `topPercentRange(pct)`: walk the ranked list adding labels until the accumulated combo count
  reaches `pct/100 × 1326` (the label that crosses the target is included).
* `.play` is the range used here.

### 6.3 Ranges written by the bot brain (`decideBot`)

Every bot decision returns `{action, range}`; the store writes `range` into `botRanges[seat]`
whenever it is non-null. **Invariant (tested in `scripts/bot_test.ts`)**: whenever the action is
not a fold, the returned range contains the bot's actual hand label (`decideBot` appends it if
missing). A fold returns `[]`.

Preflop ranges come from the 100 bb charts in `src/data/preflop.ts`
(`PREFLOP_100.rfi[pos]` and `PREFLOP_100.vsRfi["{pos}_vs_{raiserPos}"].{threebet,call}` — maps of
label → frequency 0..1; schema `ChartFreqs = Map<String,double>`). `chartLabels(chart, min)` =
labels with frequency ≥ min. Which slice is stored:

| Preflop situation | Stored range |
|---|---|
| BB checks its option | all 169 labels minus `chartLabels(BB_vs_SB.threebet, 0.5)` |
| BB raises over limps | `chartLabels(BB_vs_SB.threebet, 0.25)` |
| Open-raise (unopened pot) | `chartLabels(rfi[pos] ?? rfi.SB, 0.4)` |
| Limp (LAG/Station only, when the call costs ≤ 1 bb) | `chartLabels(rfi chart, 0.01)` |
| 3-bet vs a single raise | `chartLabels(vsRfi.threebet, 0.25)` |
| Call vs a single raise | `chartLabels(vsRfi.call, 0.25)` |
| Premium safety-net call | `["AA","KK","QQ","AKs","AKo"]` |
| vs 3-bet+: AA/KK raise or call, QQ/AK-class continue | `["AA","KK","QQ","AKs","AKo"]` |
| vs 3-bet+: speculative call | `chartLabels(vsRfi.threebet ?? {}, 0.25)` |

Postflop the stored range is **narrowed** by `narrowRange(stored, board, kind, actualLabel)` with
`kind = "aggro"` for bets/raises, `"call"` for calls, `"check"` for checks:

```
narrowRange(stored, board, kind, actualLabel):
  if stored.length <= 8: return stored ∪ {actualLabel}          // tiny ranges are never narrowed
  blocked = set(board cards)
  isRiver = board.length == 5
  scored = []
  for l in stored:
    combo = first combo of l with neither card on the board; skip label if none
    v = isRiver ? evaluateInts(combo + board).score                                    // exact made-hand strength
               : equityVsRandom(combo, board, iters 80, seed hashSeed("{l}|{board joined}")).equity  // sees draws
    scored.push({l, v})
  sort scored descending by v
  n = scored.length
  aggro: kept = top max(5, round(0.45 n)) labels  ++  labels from index round(0.85 n) to end   // value + bluff tail
  call:  kept = top max(6, round(0.65 n))
  check: kept = labels from index round(0.12 n) to end                                        // shed the very top
  if actualLabel ∉ kept && actualLabel ∈ stored: kept.push(actualLabel)
  return kept
```

Test invariants from `bot_test.ts` that the port must keep: over 1200 six-handed hands, the
stored range never excludes the acting bot's hand (`rangeExclusions == 0`), postflop actions
narrow ranges (> 200 narrowings when the previous range had > 8 labels) and **never grow** them.

### 6.4 Who is "the villain" for the coach

```
villId = (state.aggressor != null && state.aggressor != 0) ? state.aggressor : firstOpponentInHand(state)
firstOpponentInHand = id of the first player (by seat order) that is not the hero and has not folded; fallback 1
```

Preflop the aggressor starts as the BB seat, so an unraised pot grades vs the big blind's
range; after a raise it grades vs the raiser. Postflop with no bet yet, it is the first live
opponent by seat index.

---

## 7. EV coach — `evaluateHero(state, action, id)`

Runs **only for hero actions** (`heroAction`), only when `settings.coachEnabled`, against the
state *before* the action. Returns `null` when the coach has nothing to say. All Monte-Carlo
work goes through the equity engine (§8).

### 7.1 Shared preamble

```
hero = players[0]; if hero.hole == null: return null
la = legalActions(state)
vill = players[villId] (§6.4); arche = vill.archetype; cfg = ARCHETYPES[arche] or null
range = villainRangeFor(state, vill); combos = combosInSet(range)
bb = bigBlind; heroLabel = cardsToLabel(hole)               // e.g. "AKs"
boardStr = board.length ? board.join(" ") : "a pre-flop board"
opponents = count of players that are not hero and not folded
fieldMode = opponents > 1
oppDesc = fieldMode ? "the {opponents}-player field" : "{vill.name}'s range"

costNow = action.type == check ? 0
        : action.type ∈ {fold, call} ? la.callAmount
        : (action.amount ?? 0) − hero.committed                 // bet/raise: extra chips to put in
finalPotNow = pot + costNow
threshold = finalPotNow > 0 ? costNow / finalPotNow : 0        // break-even equity

seedBase = hashSeed("{handNumber}|{street}|{action.type}|{hole[0]}{hole[1]}|{board joined with ''}")   // FNV-1a 32-bit (§8)

run(iters, seed) = fieldMode      ? equityVsField(hole, board, opponents, iters, seed)
                 : range.nonEmpty ? equityVsRange(hole, board, range, iters, seed)
                 :                  equityVsRandom(hole, board, iters, seed)

{mistakeBb, foldFlagBb} = coachThresholds(settings.coachStrictness)
baseIters = simQuality == "high" ? 4000 : 1600
equity = 0.5; trials = 0; se = 0; exact = false
try:
  r = run(baseIters, seedBase)
  if !r.exact && costNow > 0 && |r.equity − threshold| < 2 * r.se:      // near the line and noisy → tighten
    r = run(baseIters * 4, seedBase + 1)
  equity = r.equity; trials = r.samples; se = r.se; exact = r.exact
catch: equity = 0.5
margin = 2 * se
pct = round(equity * 100)
```

Layer-3 sentences built once (verbatim):

* `baselineNote` = `Baseline: verdicts grade vs THIS opponent's likely hands (exploitative). Vs a balanced player the answer can differ — most sharply against extreme types like Stations (value-bet wider, never bluff) and Nits (respect their raises).`
* `marginNote` = exact ? `Exact count — every possible holding and runout was enumerated, so there's no simulation noise.`
  : `Simulation precision: ±{(margin*100).toFixed(1)}% on the equity ({trials.toLocaleString()} trials).`
  (`toLocaleString` inserts thousands separators, e.g. `1,600`.)
* `sourceLine` = fieldMode ? `Equity is run against {opponents} opponents as random hands ({trials}-trial sim) — more players, lower equity.`
  : `{vill.name}{cfg ? " (" + cfg.archetype + ")" : ""} range ≈ {combos} combos (position + action).`
  (note: `{trials}` here is unformatted, no separator.)

Fields common to every returned review (`base`): `id`, `kind: "decision"`, `villainName`,
`villainArchetype`, `villainRange: range`, `board` (copy), `opponents`, `multiway: opponents > 1`.

### 7.2 FOLD

```
if la.toCall <= 0: return null                                  // folding when a check was free is not graded
cost = la.callAmount; finalPot = pot + cost; potOdds = cost / finalPot
evCall = equity * finalPot − cost
evCallLow = (equity − margin) * finalPot − cost
if evCall <= foldFlagBb * bb || evCallLow <= 0: return null     // flag only when the call was clearly +EV even pessimistically
```

Returned: `blocking: false`, `verdict: "mistake"`, `title: "Fold spills value"`, `equity`, `potOdds`, `evChips: evCall`.

* plain: `You folded a moneymaker. Calling {fmtBb(cost)} bb to win a {fmtBb(finalPot)} bb pot only needs a win {fmtNeed(potOdds)} — and your hand wins {fmtTimes(equity)}. That call was worth about +{(evCall/bb).toFixed(1)} bb.`
* text: `Against {oppDesc} your {heroLabel} has {pct}% equity and you're getting {round(potOdds*100)}% pot odds — calling is worth about +{(evCall/bb).toFixed(1)} bb.`
* steps:
  1. `{heroLabel} vs {oppDesc} on {boardStr} → {pct}% equity.`
  2. `Pot {pot} + call {cost} = {finalPot}; pot odds = {round(potOdds*100)}%.`
  3. `EV(call) = {pct}% × {finalPot} − {cost} ≈ +{evCall.toFixed(0)} chips ({(evCall/bb).toFixed(1)} bb) > EV(fold)=0.`
* expert: `[sourceLine, marginNote, baselineNote]`

### 7.3 CALL

```
cost = la.callAmount; finalPot = pot + cost; potOdds = finalPot > 0 ? cost/finalPot : 0
evAction = equity * finalPot − cost
evActionHigh = (equity + margin) * finalPot − cost
priceLine = "You paid {fmtBb(cost)} bb to win a pot of {fmtBb(finalPot)} bb — you need to win {fmtNeed(potOdds)}."
```

| Order | Condition | verdict | blocking | plain | text |
|---|---|---|---|---|---|
| 1 | `evAction < mistakeBb*bb && evActionHigh < 0` | mistake | **true** | `{priceLine} Your hand wins {fmtTimes(equity)} — not enough. Over time this call loses money; folding is better.` | `Against {oppDesc} your {heroLabel} has only {pct}% equity, but calling needs {round(potOdds*100)}%. This call costs about {(evAction/bb).toFixed(1)} bb — folding is better.` |
| 2 | `evAction < mistakeBb*bb` (but inside the noise band) | thin | false | `Genuinely too close to call: the numbers say roughly break-even here. Either choice is fine.` | `Looks slightly losing (~{(evAction/bb).toFixed(1)} bb), but it's within the simulation's margin of error — either choice is reasonable here.` |
| 3 | `equity < potOdds + 0.04` | thin | false | `{priceLine} Your hand wins {fmtTimes(equity)} — just barely enough. A close call, not a mistake.` | `{pct}% equity vs ~{round(potOdds*100)}% needed — a marginal, close call against {oppDesc}.` |
| 4 | otherwise | `equity > 0.7 ? great : ok` | false | `{priceLine} Your hand wins {fmtTimes(equity)} — comfortably more than you need. Good call.` | `{pct}% equity vs {oppDesc}, needing {round(potOdds*100)}% — a clear call worth +{(evAction/bb).toFixed(1)} bb.` |

(`(evAction/bb).toFixed(1)` in row 1 carries its own minus sign, e.g. `-1.3`.)

Returned: `title: "Your call"`, `equity`, `potOdds`, `evChips: evAction`, steps:
1. `{heroLabel} vs {oppDesc} on {boardStr} → {pct}% equity.`
2. `Pot {pot} + your call {cost} = {finalPot}; pot odds = {cost}/{finalPot} = {round(potOdds*100)}%.`
3. `EV(call) = {pct}% × {finalPot} − {cost} ≈ {evAction.toFixed(0)} chips ({(evAction/bb).toFixed(1)} bb). EV(fold) = 0.`
4. `evAction < 0` ? `Because EV < 0, folding is the higher-EV play.` : `Because EV > 0, calling beats folding.`

expert: `[sourceLine, marginNote, baselineNote]`. This is the **only blocking** verdict in the app.

### 7.4 CHECK

```
if board.length < 3 || equity < 0.65: return null       // preflop checks and weak hands are never graded
strong = (equity − margin) > 0.75
if !strong && street != "river": return null            // medium-strong hands may pot-control before the river
betTo = round(pot * 0.66)
```

Returned: `blocking: false`, `verdict: strong ? "mistake" : "thin"`, `title: "Missed value"`, `equity` (no potOdds, no evChips).

* plain (strong): `Your hand wins {fmtTimes(equity)} — that's a hand that wants to bet. Checking here gives up a clear value bet: when you're ahead this often, put chips in and get paid.`
* plain (not strong): `Your hand wins {fmtTimes(equity)} — usually strong enough for a small value bet here. Checking is cautious but leaves some money behind.`
* text: `{pct}% equity checked {street == "river" ? "on the river" : "back"} — a value bet (~{betTo} chips) was available.`
* steps:
  1. `{heroLabel} vs {oppDesc} on {boardStr} → {pct}% equity.`
  2. `A ~66% pot bet ({betTo}) gets called by enough worse hands to profit when you win this often.`
  3. `Checking wins the same pot but never builds it — EV left behind grows with your win chance.`
* expert: `[sourceLine, marginNote, baselineNote, "Post-flop aggression verdicts are heuristic (no solver) — treat as guidance, not gospel."]`

Note: a check-verdict "mistake" is non-blocking but still creates a leak spot (§4.6) and counts in stats.

### 7.5 BET / RAISE

```
cost = (action.amount ?? 0) − hero.committed          // == costNow
finalPot = pot + cost; potOdds = finalPot > 0 ? cost/finalPot : 0
evAction = equity * finalPot − cost

// fold-equity model
betFrac = costNow / max(1, pot)
continueFrac = min(0.75, max(0.30, 0.62 − 0.2 * betFrac))
pAllFold = (1 − continueFrac) ^ opponents
foldsNeeded = costNow / (pot + costNow)
evBluff = pAllFold * pot + (1 − pAllFold) * (equity * (pot + 2*costNow) − costNow)
```

**Expensive bluff** (`equity + margin < 0.32 && evBluff < −0.75 * bb`): `blocking: false`,
`verdict: "mistake"`, `title: "Expensive bluff"`, `equity`, `potOdds`, `evChips: evBluff`.

* plain: `A very expensive bluff: if anyone calls, your hand wins only {fmtTimes(equity)}{opponents > 1 ? ", and with {opponents} opponents someone usually calls" : ""}. You'd need folds {fmtTimes(foldsNeeded)} just to break even — this bet loses money over time.`
* text: `Bluffing {round(betFrac*100)}% pot with {pct}% equity vs {oppDesc}: estimated EV {(evBluff/bb).toFixed(1)} bb.`
* steps:
  1. `{heroLabel} vs {oppDesc} on {boardStr} → {pct}% equity when called.`
  2. `Break-even fold rate = bet / (pot + bet) = {round(foldsNeeded*100)}%.`
  3. `Assuming each opponent continues ~{round(continueFrac*100)}% vs this size, everyone folds only {round(pAllFold*100)}% of the time.`
  4. `EV ≈ {round(pAllFold*100)}% × {pot} + {round((1−pAllFold)*100)}% × ({pct}% × {pot + 2*costNow} − {costNow}) ≈ {evBluff.toFixed(0)} chips.`
* expert: `[sourceLine, marginNote, baselineNote, "The fold-equity model is heuristic (fixed continue rates by bet size, no ranges) — aggression verdicts are approximate by design."]`

Otherwise, in order:

| Condition | verdict | plain | text |
|---|---|---|---|
| `equity > 0.6` | great | `Betting with the goods: if someone calls, your hand wins {fmtTimes(equity)}. Money goes in with the best of it — and every fold is profit too.` | `Strong value — {pct}% equity vs {oppDesc}. Betting is correct.` |
| `equity < 0.38 && cost > pot * 0.5` | thin | `This is a bluff: if you get called, your hand only wins {fmtTimes(equity)}. The bet makes money only when opponents fold — fine as a plan, just know that's the plan.` | `Aggressive: only {pct}% equity if called. Works as a bluff but relies on folds.` |
| else | ok | `A solid bet: when called, your hand wins {fmtTimes(equity)}, and every fold you pick up is pure profit on top.` | `{pct}% equity vs {oppDesc} — a reasonable bet — worse hands may call, and every fold wins you the pot.` |

Returned: `blocking: false`, `title: action.type == "bet" ? "Your bet" : "Your raise"`, `equity`, `potOdds`, `evChips: evAction`, steps:
1. `{heroLabel} vs {oppDesc} on {boardStr} → {pct}% equity when called.`
2. `A bet also wins when opponents fold — fold equity isn't shown here, so treat this as the "called" floor.`

expert: `[sourceLine, marginNote, baselineNote]`.

### 7.6 Verdict summary

| verdict | Panel label | Colour token | Icon | Blocking? | Creates leak? |
|---|---|---|---|---|---|
| mistake | Mistake | `--bad` (rgb 236 90 90) | x | only for calls | yes |
| thin | Thin spot | `--warn` (232 181 74) | info | no | no |
| ok | Reasonable | `--info` (79 155 232) | check | no | no |
| great | Nice play | `--good` (63 191 127) | check | no | no |
| info | Read | `--info` | eye | no | no (bot reads are never recorded) |

Worked examples (bb = 20, `se = 0` so `margin = 0`, standard strictness):

* Call: pot 200, call 100, equity 0.40 → finalPot 300, potOdds 0.333, EV = +20 chips (+1.0 bb);
  not a mistake (−6 chips threshold), `0.40 ≥ 0.373` → **ok**. `pct` 40, `round(potOdds*100)` 33.
* Call: same pot, equity 0.25 → EV = −25 chips = −1.25 bb < −6 and `evActionHigh < 0` → **mistake, blocking**;
  text shows `-1.3 bb` (toFixed(1) of −1.25 gives `-1.3` in JS; see §11 rounding caveat).
* Fold: pot 200, call 50, equity 0.50 → EV(call) = +75 chips = 3.75 bb > 30 chips (1.5 bb) → **"Fold spills value"**;
  with equity 0.30 → EV = +25 chips < 30 → no note.
* Bet: pot 100, bet 100 (costNow 100), equity 0.20, 1 opponent → betFrac 1, continueFrac 0.42,
  pAllFold 0.58, foldsNeeded 0.5, evBluff = 58 + 0.42·(60 − 100) = 41.2 → not a mistake → `cost > 50` and `equity < 0.38` → **thin** ("This is a bluff…").
  Same bet with 3 opponents → pAllFold 0.074, evBluff = 7.4 + 0.926·(−40) = −29.6 < −15 → **"Expensive bluff"**.

---

## 8. Equity engine contract used by the coach

The store calls an async facade (`engine.equityVsRange/equityVsRandom/equityVsField`) that
returns:

```
EquityResult { equity: double /* win + tie/2 */; win, tie, lose: int; samples: int; se: double /* 0 when exact */; exact: bool }
```

Behaviour the coach relies on (TypeScript reference implementation; the Rust twin matches):

* `equityVsRange(hero, board, rangeLabels, iters, seed)`: the range is expanded to concrete
  combos, dropping any combo that shares a card with the hero's hand or the board. If no combo
  survives → `{equity: 0.5, samples: 0, se: 0, exact: false}`. **Board of 4 or 5 cards ⇒ exact
  enumeration** (every villain combo × every runout card); otherwise `iters` Monte-Carlo trials
  (each trial: uniform combo from the range, random runout), `se = sqrt(max(e(1−e), 1e-9) / samples)`.
* `equityVsRandom(hero, board, iters, seed)`: **5-card board ⇒ exact** over all 1225 opponent
  combos; otherwise Monte-Carlo.
* `equityVsField(hero, board, n, iters, seed)`: `n = clamp(floor(n), 1, 8)`; never exact;
  per trial hero's share is 1 on a win, `1/(tied+1)` on a tie; `equity = mean(share)`,
  `se` from that mean as above.
* `hashSeed(s)`: FNV-1a 32-bit — `h = 0x811c9dc5; for each UTF-16 code unit c: h ^= c; h = (h * 0x01000193) mod 2^32`; result unsigned.
  Given a seed the sampler uses `mulberry32(seed)`; without a seed, `Math.random`. Determinism
  matters: "same spot + same action = same verdict".

The settings copy promises: "Late streets are always computed exactly either way" — true for
heads-up verdicts (range/random paths) on turn and river; multiway (`equityVsField`) is always sampled.

---

## 9. EV coach panel (`EVCoachPanel`)

Positioned top-right over the table (340 px wide, max height `min(74vh, 580px)`), slides in.

* **Collapsed state** (`activeReviewId == null` but `reviewLog` non-empty): a pill button
  `Coach notes ({reviewLog.length})` with the coach icon; tap → `reopenReview()` (latest note).
  Nothing is rendered when the log is empty.
* **Header**: coloured circle with the verdict icon; line 1 `{META.label}` in the verdict colour;
  line 2 `{kind == "bot" ? "Bot read" : "EV Coach"} · {review.title}`. A close "×" is shown only
  when not blocking.
* **Body** (scrollable), in order:
  1. Paragraph: `review.plain ?? review.text` (layer 1).
  2. If `equity != null`: row `Win chance vs {villainName}` (the label has a hover tooltip:
     **Win chance (equity)** — `how often your hand ends up best if the rest of the cards were dealt out with nobody folding.`)
     with `{equityPct}%` on the right in the verdict colour; a bar filled to `equityPct`; if
     `potOdds > 0` a white 2 px marker at `oddsPct` with title `Need {oddsPct}%`, and a caption
     `White line = {oddsPct}% needed (pot odds)` where "(pot odds)" has the tooltip
     **Pot odds** — `the share of the final pot your call pays for. Win more often than this and the call makes money.`
     (`equityPct = round(equity*100)`, `oddsPct = round(potOdds*100)`.)
  3. If `review.multiway`: warning box `Multiway pot ({opponents} opponents). With more players someone hits the board more often, so you need a stronger hand to continue. The numbers here are a rough estimate against random hands — treat close verdicts loosely.`
  4. If `steps` non-empty: toggle `Show me the math` / `Hide the math` revealing a numbered list of `steps`.
  5. If `expert` non-empty **or** `plain` exists: toggle `Expert detail` / `Hide expert detail`
     revealing a bullet list: first `review.text` (only when `plain` exists — the layer-2 line moves
     here), then each `expert` string.
  6. If `evChips != null`: row `Expected value` — `{fmtSigned(evChips / bb)} bb`, coloured bad when
     `< −0.05`, good when `> 0.05`, muted otherwise.
  7. Buttons: `View range` (secondary; only if `villainRange` non-empty) → `openRangeView(villainName ?? "Your opponent", villainRange)`;
     then `Got it` (primary, when blocking) or `Close` (ghost) → `dismissReview()`.

Both toggles are local UI state that persists across notes while the panel stays mounted.

---

## 10. Range view modal (`RangeViewModal`)

Opened by "View range". Modal (max width 560): title `{name}'s assumed range`, description
`This is the range the coach used for its equity estimate, based on archetype, position and action so far.`
Body: read-only `RangeMatrix` highlighting the range (500 px), the kind legend
(Pairs / Suited / Offsuit) and `{combos} combos · {fmtPct(combos/1326)} of all hands`.
Close → `closeRangeView()`.

---

## 11. Formatters (`src/lib/format.ts`) — exact semantics and pinned values

```
fmtBb(chips, bb):    v = chips / bb; r = round(v * 10) / 10; integer(r) ? "{r}" : r.toFixed(1)
fmtChips(n):         round(n).toLocaleString()                       // "1,235" in en-US
fmtSigned(n, d=1):   v = round(n * 10^d) / 10^d; (v >= 0 ? "+" : "") + v.toFixed(d)
fmtPct(frac, d=0):   "{(frac*100).toFixed(d)}%"
fmtTimes(p):         p >= 0.93 → "almost every time"
                     p <= 0.04 → "almost never"
                     p >= 0.45 → "about {round(p*10)} times in 10"
                     else      → "about 1 time in {round(1/p)}"
fmtNeed(potOdds):    potOdds <= 0 → "any win rate"
                     n = 1/potOdds; r = round(n*2)/2; "about 1 time in {integer(r) ? r : r.toFixed(1)}"
```

`round` is JavaScript `Math.round` (half rounds toward +∞: `round(-12.5) = -12`, `round(12.5) = 13`).
Dart's `num.round()` rounds half **away from zero** (`(-12.5).round() = -13`). They agree for
all non-negative inputs and differ for negative exact halves; `fmtBb(-25, 20)` gives `"-1.2"` on
desktop and would give `"-1.3"` with a naive Dart port, and `fmtSigned(-0.05)` gives `"+0.0"` on
desktop (`Math.round(-0.5) = -0`, which prints as `0.0` with a `+`). Decide whether to replicate
JS semantics (recommended: implement `jsRound(x) = (x + 0.5).floorToDouble()`) — the values
below assume JS semantics.

| Call | Result |
|---|---|
| `fmtBb(60, 20)` | `"3"` |
| `fmtBb(30, 20)` | `"1.5"` |
| `fmtBb(25, 20)` | `"1.3"` |
| `fmtBb(5, 20)` | `"0.3"` |
| `fmtBb(0, 20)` | `"0"` |
| `fmtBb(-30, 20)` | `"-1.5"` |
| `fmtSigned(1.25)` | `"+1.3"` |
| `fmtSigned(2)` | `"+2.0"` |
| `fmtSigned(-3.14)` | `"-3.1"` |
| `fmtSigned(-0.04)` | `"+0.0"` |
| `fmtSigned(0)` | `"+0.0"` |
| `fmtPct(0.256)` | `"26%"` |
| `fmtPct(0.5, 1)` | `"50.0%"` |
| `fmtTimes(0.95)` | `"almost every time"` |
| `fmtTimes(0.93)` | `"almost every time"` |
| `fmtTimes(0.92)` | `"about 9 times in 10"` |
| `fmtTimes(0.72)` | `"about 7 times in 10"` |
| `fmtTimes(0.5)` | `"about 5 times in 10"` |
| `fmtTimes(0.45)` | `"about 5 times in 10"` |
| `fmtTimes(0.44)` | `"about 1 time in 2"` |
| `fmtTimes(0.33)` | `"about 1 time in 3"` |
| `fmtTimes(0.25)` | `"about 1 time in 4"` |
| `fmtTimes(0.10)` | `"about 1 time in 10"` |
| `fmtTimes(0.05)` | `"about 1 time in 20"` |
| `fmtTimes(0.041)` | `"about 1 time in 24"` |
| `fmtTimes(0.04)` | `"almost never"` |
| `fmtNeed(0)` | `"any win rate"` |
| `fmtNeed(0.25)` | `"about 1 time in 4"` |
| `fmtNeed(0.3)` | `"about 1 time in 3.5"` |
| `fmtNeed(0.33)` | `"about 1 time in 3"` |
| `fmtNeed(0.35)` | `"about 1 time in 3"` |
| `fmtNeed(0.4)` | `"about 1 time in 2.5"` |
| `fmtNeed(0.5)` | `"about 1 time in 2"` |
| `fmtNeed(0.2)` | `"about 1 time in 5"` |

`toFixed(1)` of a negative like −1.25 yields `"-1.3"` in JS (it rounds the decimal expansion,
which for −1.25 exactly is half → away from zero in `toFixed`). Dart `toStringAsFixed(1)` gives
the same `"-1.3"`. `(-0).toFixed(1)` is `"0.0"` (no sign).

---

## 12. Guess-range / peek flow

### 12.1 Store

```
openGuess(botId):
  guess = { open: true, botId, street: table.street, revealed: false, scored: false, actualRange: [], accuracy: null, precision: null, recall: null }
  paused = true                              // hero cannot act; auto loop halts on its next tick; stepBot refuses

peek(painted: HandLabel[]):
  g = guess; if g == null: return
  bot = players[g.botId]; actual = villainRangeFor(table, bot)      // §6.1
  scored = painted.length > 0
  score = scored ? scoreGuess(painted, actual) : {null, null, null}
  guess = {...g, revealed: true, scored, actualRange: actual, accuracy, precision, recall}
  if scored && bot.archetype && accuracy != null:
    stats.recordGuess({ accuracy, archetype: bot.archetype, street: g.street, ts: now })

closeGuess(): guess = null; paused = false; maybeAutoLoop()
```

### 12.2 `scoreGuess(painted, actual)` — combo-weighted precision / recall / F1

```
pSet = set(painted); aSet = set(actual)
inter = Σ comboCount(l) for l in pSet where l ∈ aSet
pc = combosInSet(pSet); ac = combosInSet(aSet)
precision = pc > 0 ? inter / pc : 0
recall    = ac > 0 ? inter / ac : 0
accuracy  = precision + recall > 0 ? 2·precision·recall / (precision + recall) : 0      // F1
return {accuracy, precision, recall}
```

Pinned values:

| painted | actual | precision | recall | accuracy |
|---|---|---|---|---|
| `["AA","KK"]` | `["AA","AKs"]` | 6/12 = 0.5 | 6/10 = 0.6 | 0.6/1.1 = 0.545454… |
| `["AKo"]` | `["AKo"]` | 1 | 1 | 1 |
| `["72o"]` | `["AA"]` | 0 | 0 | 0 |
| `["AA","AA"]` (dupes) | `["AA"]` | 1 | 1 | 1 |
| `["AKs","AKo","AA"]` | `["AA"]` | 6/22 = 0.2727… | 1 | 0.428571… |
| `[]` | anything | 0 | 0 | 0 (store never scores an empty guess) |

### 12.3 Where the "eye" button lives

Each bot seat shows a round gold "eye" button (title `Guess {name}'s range`) when
`phase == betting && !isHero && !hasFolded && hole != null`. Tapping it calls `openGuess(id)`.
Available at any time during betting, not only on the hero's turn.

### 12.4 Guess modal (`GuessModal`)

Modal max width 620. Title: eye icon + `Read {bot.name}'s range`. Description:
`{bot.position} · {cfg ? "{cfg.name} ({cfg.archetype})" : "Player"} · {Street with first letter capitalised}. Optionally paint your guess, or just peek to study their range.`

Local state `painted: Set<HandLabel>`, reset to empty whenever the modal opens (open/botId/street change).

Before reveal:
* editable `RangeMatrix(value: painted, onChange, size 520)`;
* legend mode `kind`; right caption `{combosInSet(painted)} combos selected`;
* left hint `Guessing is optional — peek any time.`;
* `Clear` (ghost, disabled when nothing painted) and a primary button
  `Peek & score` when something is painted, else `Peek` → `peek([...painted])`.

After reveal:
* matrix in **compare** mode if scored (`{painted, actual}`), else read-only highlighting `actual`;
* legend mode `compare` when scored else `kind`; caption `Their range: {combosInSet(actual)} combos`;
* result box: if scored → big `{fmtPct(accuracy)}` + grade label (both in the grade colour) and
  `Coverage (recall): {fmtPct(recall)}` / `Precision: {fmtPct(precision)}`;
  else `Here's {bot.name}'s assumed range. Paint a guess first next time for an accuracy score.`;
* right side: `Everyone's exact cards are revealed when the hand ends.` + `Continue` → `closeGuess()`.

Dismissing the modal by any other means (×, Esc, overlay) also calls `closeGuess()`.

Grades: `acc ≥ 0.8` → `Sharp read` (good) · `≥ 0.6` → `Solid` (gold) · `≥ 0.4` → `Rough` (warn) · else `Way off` (bad).

The side rail's **Read accuracy** stat is the mean `accuracy` over all lifetime guess records
(`"—"` when none), shown as a whole percent.

---

## 13. Range matrix (`RangeMatrix`, `RangeLegend`)

Grid: 13 × 13, row-major, `GRID[r][c] = labelAt(r, c)` with ranks in descending order
`A K Q J T 9 8 7 6 5 4 3 2`: `r == c` → pair `"{R}{R}"`; `c > r` (upper-right triangle) → suited
`"{hi}{lo}s"`; `r > c` → offsuit `"{hi}{lo}o"`, where `hi = RANKS_DESC[min(r,c)]`, `lo = RANKS_DESC[max(r,c)]`.
`kindOf(label)`: length 2 → pair; ends with `s` → suited; else offsuit. `comboCount`: 6 / 4 / 12.

Props: `value?`, `onChange?`, `readOnly?`, `highlight?`, `compare? {painted, actual}`, `size = 520`.
`interactive = !readOnly && !compare && onChange != null`. Cell = `size/13`, font `max(8, cell*0.32)`,
2 px gap, square cells, 3 px radius, `user-select: none`, `touch-action: none`.

Painting interaction (the thing to replicate on touch):
* pointer-down on a cell: `add = !value.has(label)`; remember `addMode = add`; `painting = true`; apply to that cell.
* pointer-enter on any cell while `painting`: apply `addMode` to it (drag-paint, never toggles back within one stroke).
* window pointer-up anywhere: `painting = false`.
* `apply(label, add)`: no-op if already in that state; otherwise emit a new Set via `onChange`.

Colouring:
* compare mode: in both → `bg-good` with dark text; actual only → `bg-warn` dark text; painted only → `bg-chip-red` white text; neither → dim (`bg-ink-700`, faint text).
* read-only: in `highlight` → kind colour (pair `--combo-pair` rgb 184 68 47, suited `--combo-suited` 47 143 92, offsuit `--combo-offsuit` 44 58 74 dark / 150 161 174 light) with white text; else dim.
* interactive: selected → kind colour + white; unselected → dim with hover.
Dim cells render at 0.92 opacity. Each cell shows its label and `aria-pressed` when selected.

Legend items: kind → `Pairs`, `Suited`, `Offsuit` (kind colours); compare → `Correct` (good), `Missed` (warn), `Extra` (chip-red).

---

## 14. Writing rules (TONE.md) — what every coach string obeys

1. Layer 1 (`plain`) is always visible: one or two sentences, no jargon, **chances as counts**
   (`fmtTimes`) and money in big blinds.
2. Layer 2 ("Show me the math") may use percentages and terms like equity / pot odds, each
   self-explaining or tooltip-defined.
3. Layer 3 ("Expert detail") carries ranges, combo counts, formulas, simulation precision, caveats.
4. Banned words: "laying odds", "villain", "hero" (user-facing), "stab / barrel / fire",
   unglossed "air / nutted / the nuts", "OOP / IP", "denies equity", "stack off".
5. Judge the decision, never the person ("This call loses money over time", never "bad play").
6. Be honest about confidence: inside the margin of error say "genuinely too close to call".
7. One concept per note; approximations are labelled (post-flop heuristics say so, exact
   enumerations say "Exact count").

Any new copy in the port must follow the same rules; reuse the templates above verbatim.

---

## 15. Table rendering (`PokerTable`, `Seat`, `Pot`, `Board`, `PlayingCard`)

Desktop geometry (for reference; mobile will be redesigned):

* Container max width 1000 px; felt = 90 % × 80 % ellipse (`border-radius 46%/50%`), 12 px
  dark-brown rim, an inner 84 % × 72 % hairline.
* Centre column at (50 %, 39 %): `Pot` (street label + chip pill `{fmtBb(pot)} bb`), `Board`
  (5 slots, 56 px cards, dashed placeholders for undealt cards, deal-in animation staggered 55 ms),
  and a 20 px line that shows a spinner + `dealing` while `thinking`.
* Seat *i* of *n* sits at angle `π/2 − 2πi/n`: `left = 50 + 42·cos`, `top = 48 + 41·sin` (percent).
  Seat 0 (hero) is bottom-centre; seat order runs counter-clockwise on screen (seat 1 lower-right,
  seat 2 upper-right, …). Action order follows seat index, so the button also travels
  counter-clockwise visually.
* Street labels (`Pot`): `Pre-flop`, `Flop`, `Turn`, `River`, `Showdown`.

Seat (`Seat`):
* Hole cards above the plate: hero 46 px, bots 36 px; shown face-up when `isHero || (revealed && !(realisticReveal && hasFolded))`,
  otherwise face-down; when `hole == null` an empty spacer of the same height. Folded → 30 % opacity + grayscale.
* Plate 128 px wide: ring gold + pulse when it is this seat's turn (`phase == betting && toAct == id`);
  ring green when `isWinner` (any pot winner at hand-over); folded → 55 % opacity.
* Avatar circle with the initial (`Y` for hero, else first letter of the name) tinted in the
  archetype colour (hero: gold). Name (truncated) + position chip. Stack `{fmtBb(stack)} bb`.
  Dealer badge `D` when `button == id`.
* Second row: `HUD` for bots (§16) or the text `HERO`; on the right the last action label, coloured
  Raise/Bet gold, All-In red, Call info-blue, Fold faint, others muted.
* Under the plate: a pill `{fmtBb(committed)} bb` while `committed > 0` (current-street chips).
* Eye button for guessing (§12.3).

`PlayingCard(card, faceDown, w=46, dim)`: height `round(1.4w)`, radius `max(4, round(0.13w))`.
Face-down: green gradient (`#11805a → #0a4f34 → #073a2a`), inset gold hairline and a ring.
Face-up: white gradient; rank top-left (font `0.36w`, `T` displayed as `10`), small suit symbol
under it (`0.26w`), large suit bottom-right (`0.5w`, 92 % opacity). Suit colours via
`--suit-{c|d|h|s}`: hearts/diamonds red (216 58 58), spades/clubs near-black (27 34 48);
four-colour deck overrides diamonds `#2f7fd6`, clubs `#2fa066`. Symbols ♠ ♥ ♦ ♣. `dim` → 55 % opacity.

---

## 16. HUD (`HUD`)

Shown under each bot's name. `n = player.handsSeen`, `enough = n ≥ 8`.
`vpip = round(vpipCount / n × 100)`, `pfr = round(pfrCount / n × 100)` when enough, else hidden.

Chip: archetype-coloured dot + mono text `{vpip}/{pfr} {n}h` (e.g. `24/18 12h`) or, before the
sample is reached, `–/– · {n}h` (en dashes).

Tooltip (hover): `{cfg.name} ({cfg.archetype})`, the archetype blurb, then
* enough: `Observed over {n} hands this session — VPIP = how often they put money in pre-flop, PFR = how often they raise. Each player's exact numbers vary, so watch them settle.`
* else: `Stats appear after 8 observed hands ({n} so far) — reads are earned, not given.`

`handsSeen` counts every hand dealt this session (all players increment together at `startHand`),
so it equals the session's hand count including the current one.

---

## 17. Action bar (`ActionBar`)

Derived flags: `heroToAct = phase == betting && toAct == 0 && !paused`;
`botToAct = phase == betting && toAct != null && toAct != 0`;
`canExplain = lastActorSeat != null && lastActorSeat != 0 && players[lastActorSeat].archetype != null`;
`canAggro = la.canBet || la.canRaise`; `aggroVerb = currentBet == 0 ? "Bet" : "Raise to"`.

Left block (230 px):
* hero's two cards (38 px) when a session is active and cards are dealt;
* line 1: `cardsToLabel(hole)` (e.g. `AKs`) or `—`; when no session: `All-In`;
* line 2: if hero to act and `toCall > 0`: `To call {fmtBb(callAmount)} bb · need to win {fmtPct(toCall / (pot + toCall))}`;
  else `{fmtBb(stack)} bb stack` (session active) or `Start a session to play`.

Right block:
* no session → primary `Start session` → `newSession()` (saved options).
* hand-over → `[Explain last move]` (ghost, only if `canExplain`; title tooltip `Ask the coach to interpret the last action`) + primary `Next hand` → `deal()`.
* bot to act → `[Explain last move]` + (`mode == manual && !paused` ? secondary `Next action` → `stepBot()` : text `Waiting for {players[toAct].name}…`).
* hero to act → `Fold` (danger); `Check` or `Call {fmtBb(callAmount)}`; and when `canAggro` a sizing box:
  quick buttons `½`, `¾`, `Pot`, `All-in`; a slider (`min = minRaiseTo`, `max = maxRaiseTo`, `step = max(1, bb/2)`);
  a 46 px numeric text field in bb; and the primary button `{aggroVerb} {fmtBb(raiseTo)}`
  → `heroAction({type: currentBet == 0 ? "bet" : "raise", amount: raiseTo})`.

Sizing state `raiseTo` (chips, integer):
```
clamp(x) = round(max(minRaiseTo, min(maxRaiseTo, x)))
default (recomputed whenever toAct/street/currentBet/phase/handNumber change and hero is to act):
  base = pot + toCall
  def  = currentBet > 0 ? currentBet + round(base * 0.66) : round(pot * 0.66)
  raiseTo = clamp(def); betText = null
quick fraction f (½ = 0.5, ¾ = 0.75, Pot = 1):
  add = round((pot + toCall) * f); raiseTo = clamp(currentBet > 0 ? currentBet + add : add)
All-in: raiseTo = maxRaiseTo
slider: raiseTo = value; betText = null
text field: shows betText ?? "{round(raiseTo/bb*10)/10}"; on blur or Enter: v = parseFloat(text); if finite → raiseTo = clamp(v * bb); betText = null
```

Keyboard (ignored when focus is in an input/textarea/select/contenteditable or a modifier is held):
* `→` : `stepBot()` if manual pace, a bot is to act and not paused.
* `Enter` : `deal()` if session active and hand-over; otherwise, when hero to act and `canAggro`, bet/raise `raiseTo`.
* `F` : fold. `C` : check if `canCheck` else call. `R` : bet/raise `raiseTo` (if `canAggro`).
* `Space` (PlayView): `newSession()` when no session; `deal()` when hand-over.
* `?` : global shortcut overlay. Its Play section lists: F Fold · C Check / call · R Bet / raise the selected size · Enter Confirm bet · next hand · → Next bot action (manual pace) · Space Start session · next hand.

---

## 18. End-of-hand overlay (`ResultOverlay`) and reveal notes

Rendered when `phase == hand-over && summary != null`, centred at 44 % height, 600 px max.

```
netBb = heroNetChips / bb
won = any potResult.winners contains 0
mainWinners = potResults[0]?.winners ?? []
winnerNames = mainWinners.map(name).join(", ")
winnerHand = first showdown entry whose playerId ∈ mainWinners → .hand
colour = netBb > 0.01 ? good : netBb < −0.01 ? bad : muted
bots = players.filter(!isHero && hole != null && !(realisticReveal && hasFolded))
```

Top row: big `{fmtSigned(netBb)} bb`; caption `You won the pot` if `won` else `Hand over`;
sentence `{winnerNames} wins with {winnerHand.name.toLowerCase()}.` when a showdown hand exists,
else `{winnerNames} takes it down.`; primary `Next` → `deal()`.

Learning reveal grid (two columns on wide screens): for each bot — its two cards at 24 px
(folded → 45 % opacity + grayscale), then `{name} {revealNote(p, summary.board, summary)}`.

`revealNote` (verbatim templates; hand names are lower-cased evaluator names such as
`pair of queens`, `two pair, aces & kings`, `flush, king high`, `ace high`, `royal flush`):

```
FOLD_PHRASE: preflop "before the flop" · flop "on the flop" · turn "on the turn" · river "on the river" · showdown "at showdown"
winners = union of all pots' winners
if !p.hasFolded:
  sd = showdown entry for p
  winner: sd?.hand ? "Won with {hand}."  : "Won — everyone else folded."
  else:   sd?.hand ? "Showed {hand}."    : "Reached the end without showing."
base = "Folded {FOLD_PHRASE[p.foldedStreet ?? preflop]}"
if folded preflop:
  if p.hole:
    label = cardsToLabel(hole)
    chart = p.position == "BB" ? {...PREFLOP_100.vsRfi.BB_vs_BTN.call, ...PREFLOP_100.vsRfi.BB_vs_BTN.threebet}
                               : PREFLOP_100.rfi[p.position]        // may be undefined → treated as {}
    inRange = (chart[label] ?? 0) > 0
    inRange ? "{base} — playable, but gave it up." : "{base} — too weak to play from {p.position}."
  else "{base}."
else if p.hole && board.length >= 3:
  "{base} — the full board would have given them {evaluateCards(hole + board).name.toLowerCase()}."
else "{base}."
```

(`summary.board` is whatever was dealt when the hand ended — 0, 3, 4 or 5 cards.)

---

## 19. Side rail (`SideRail`)

300 px column, right of the table.

**This session** card: `End` button (visible while `session.active`) → `endSession()`. Three stats:
`Hands` = `session.hands`; `Net` = `fmtSigned(session.netChips / bb)` with unit `bb`, good when ≥ 0;
`bb/100` = `fmtSigned(hands > 0 ? (netBb / hands) × 100 : 0)` with tooltip
`bb / 100` — `Big blinds won per 100 hands — the standard poker win-rate, independent of stake. +5 is strong; pros live roughly between −5 and +10. Small samples swing wildly.`
When `hero.handsSeen ≥ 8` a row `Your style` → `{round(vpipCount/handsSeen×100)}/{round(pfrCount/handsSeen×100)} · {handsSeen}h`
with tooltip `Your VPIP / PFR` — `How often YOU voluntarily put money in pre-flop, and how often you raise. Most winning 6-max players sit around 22–28 VPIP and 16–22 PFR. Much higher = too loose; a big gap between the numbers = too passive.`
Then `Read accuracy` = `{round(avg×100)}%` or `—` (§12.4).

**Pace** card: segmented `manual` / `auto` → `setSettings({mode})`; helper text
`Step through each player's action yourself (→ key, or Next action).` (manual) or
`Bots act automatically at the chosen speed.` (auto); in auto mode three buttons
`Slow` (1100) / `Normal` (700) / `Fast` (360) → `setSettings({speedMs})`. Below: `EV Coach` switch → `setSettings({coachEnabled})`.

**Hand log** card: `table.log` newest first; empty text `Actions will appear here.`; styling by
kind — result: bold gold-light; deal: info tint; action: muted; info: faint.

---

## 20. Session summary (`SessionSummaryModal`)

Visible while `sessionEnded`. `heroBusted = players[0].stack ≤ 0`.
Modal max width 520; `hideClose = heroBusted`; title `Session over — you busted` or `Session summary`;
description `{hands} hand{hands == 1 ? "" : "s"} played this session.` with `hands = session.history.length`.
Closing (only when not busted) → `closeSummary()`; the session continues.

Computations:
```
allDecisions = lifetime decision records (stats store); sessionDecisions = those with ts >= session.startedAt
sMistakes = verdict == mistake; sGreat = verdict == great
sessionRate = sessionDecisions.length ? sMistakes.length / sessionDecisions.length : null
lifeRate = allDecisions.length ? (#lifetime mistakes) / allDecisions.length : null
worstDecision = sMistakes with the lowest evBb; bestDecision = sGreat with the highest evBb
netBb = session.netChips / bb; bb100 = hands > 0 ? netBb / hands × 100 : 0
nets = history.map(h.heroNet / bb); best = max(nets) or 0; worst = min(nets) or 0
showdowns = count of history hands with board.length == 5     // approximation: "reached the river"
```

Blocks, in order:
1. If any session decisions — gold box headed `How you played (before how it paid)`:
   `{n} coached decision{n==1?"":"s"}, {m} flagged as mistakes` and, only when `allDecisions.length > sessionDecisions.length`
   and both rates exist, ` ({round(sessionRate×100)}% vs your usual {round(lifeRate×100)}%{sessionRate <= lifeRate ? " — cleaner than average" : " — a rougher one"})`, then `.`
   Then `Best: a {street} {action} worth {fmtSigned(evBb)} bb.` (if any great) and
   `Costliest: a {street} {action} ({fmtSigned(evBb)} bb) — it's in your Review queue.` (if any mistake).
2. Four stat tiles: `Net` `{fmtSigned(netBb)} bb` (good if ≥ 0) · `bb / 100` `{fmtSigned(bb100)}` · `Biggest win` `{fmtSigned(best)} bb` (good) · `Biggest loss` `{fmtSigned(worst)} bb` (bad).
3. `{showdowns} hand{s} reached showdown. Replay any hand below, or export the full history for a poker tracker.`
4. `Review hands` list (newest first, max height 170 px): `Hand #{id}` · `{fmtSigned(heroNet/bb)} bb` (good/bad by sign) · note icon (gold when a note exists for `handKey(startedAt)`; opens the note editor) · `Replay` → replayer (§21).
5. Message banner (after copy/export).
6. Buttons: `Copy` (ghost; disabled when 0 hands) → clipboard text of `formatSession(history)`; message `Hand history copied to clipboard.` / `Copy failed.`.
   `Export hands (.txt)` (secondary; disabled when 0 hands) → file `all-in-session-{ISO timestamp of startedAt, first 19 chars, ":" and "T" replaced by "-"}.txt`
   (e.g. `all-in-session-2026-09-06-19-20-31.txt`); message `Saved to {path}` (native) / `Downloaded {name}` (web) / `Save failed: …` / `Download failed: …`.
   `New session` (primary) → `newSession()`.

Note editor (`HandNoteEditor`, keyed by `String(hand.startedAt)`): title `Note on hand #{id}`,
description = local date-time; textarea placeholder
`What happened, and what's the lesson? (e.g. 'called the river with a bluff-catcher vs a Nit — their range had no bluffs')`;
preset tags `review later`, `bluff-catch`, `thin value`, `weird line`, `big pot` plus custom tags
(`+ custom, Enter`, lower-cased); `Remove note` when one exists; `Cancel` / `Save` (disabled when
both text and tags are empty). Persisted under `allin.handnotes.v1` as `{note, tags, ts}`.

---

## 21. Hand replayer model (`buildReplayFrames`, `HandReplayModal`)

```
ReplayFrame { text: String; street: Street; board: Card[]; pot: int; folded: int[]; revealAll?: bool }

buildReplayFrames(h):
  committed[seat] = 0 for all; committed[sbSeat] = sb; committed[bbSeat] = bb
  pot = sb + bb; folded = []
  bb(chips) = v = chips / h.bb; integer(v) ? "{v}" : v.toFixed(1)        // note: NOT fmtBb (no rounding to 0.1 first)
  frames = [ { text: "Blinds {bb(sb)}/{bb(bb)} bb posted.", street: preflop, board: [], pot, folded: [] } ]
  for street in [preflop, flop, turn, river]:
    boardForStreet = preflop → []; flop → board[0..3] if board.length >= 3 else null; turn → board[0..4] if >= 4 else null; river → board[0..5] if >= 5 else null
    if street != preflop:
      if boardForStreet == null: continue
      committed[*] = 0
      frames.push({ text: "{Street capitalised}: {boardForStreet joined ' '}", street, board: boardForStreet, pot, folded: copy })
    vis = boardForStreet ?? []
    for a in actions where a.street == street:
      fold:  folded.push(a.seat);                              text = "{name} folds"
      check:                                                   text = "{name} checks"
      call:  pot += a.amount; committed[seat] += a.amount;     text = "{name} calls {bb(amount)} bb{allIn ? " (all-in)" : ""}"
      bet:   pot += a.amount − committed[seat]; committed = a.amount;  text = "{name} bets {bb(amount)} bb{…}"
      raise: pot += a.amount − committed[seat]; committed = a.amount;  text = "{name} raises to {bb(amount)} bb{…}"
      frames.push({ text, street, board: vis, pot, folded: copy })
  winnerIds = unique winners across pots; names = their seat names (fallback "Seat {id+1}")
  total = Σ potResults.amount
  endStreet = board.length >= 5 ? showdown : 4 ? turn : 3 ? flop : preflop
  frames.push({ text: names.length ? "{names joined ', '} win {bb(total)} bb." : "Hand over.", street: endStreet, board: full board, pot, folded, revealAll: true })
```

Antes are not part of the replay pot (only blinds + actions), so the replay pot can be smaller
than the real one in ante games — accepted approximation.

`HandReplayModal(hand)`: modal max width 760, title `Hand #{id} replay`, description = current
frame's `text`. A 330 px felt with `Pot(frame.pot, street)` and `Board(frame.board, 44px)` at 40 %
height; seats ordered hero first then the rest, positioned with the same polar layout
(`top = 46 + 41·sin`); each seat shows hole cards when `holes[seat]` exists and (`isHero || frame.revealAll`),
face-down cards when not folded and not revealed, nothing when folded without reveal; folded →
25 % opacity; plate: position + `{fmtBb(seat.stack)} bb` (stack at hand start), hero plate ringed gold.
Controls: first / previous / slider (0..last) / next / last. The index starts at the **last frame**
when a hand is opened (`useEffect` sets `idx = frames.length − 1`).

Expectations from `scripts/hh_test.ts` for the sample hand there (6 seats, hero BTN with As Ks,
Dwan UTG Qh Qd, actions raise 60 / call 60 preflop, bet 80 / call 80 flop, check/check turn,
check / bet 120 / call 120 river, board `Ah Kd 7c 2s 9h`, pot result 520 to seat 0):
`frames.length > 4`; `frames[0].text` contains `Blinds`; last frame has a 5-card board and
`revealAll == true`; `last.pot >= frames[0].pot`; some frame has `street == flop` and a 3-card board.
Concretely the frame texts are: `Blinds 0.5/1 bb posted.` · `Dwan raises to 3 bb` · `You calls 3 bb` ·
`Flop: Ah Kd 7c` · `Dwan bets 4 bb` · `You calls 4 bb` · `Turn: Ah Kd 7c 2s` · `Dwan checks` ·
`You checks` · `River: Ah Kd 7c 2s 9h` · `Dwan checks` · `You bets 6 bb` · `Dwan calls 6 bb` ·
`You win 26 bb.` (pots: 30 → 90 → 150 → 250 → 330 → 330 → 330 → 450 → 570; final frame pot 570
because uncalled-bet logic is not applied in frames; `total` 520 → `26 bb`).

---

## 22. Daily goals and streak (`goalStore`)

```
DAILY_DRILL_GOAL = 20; DAILY_HAND_GOAL = 30
activity: Map<"YYYY-MM-DD" (LOCAL date), {drills: int, hands: int}>   persisted at "allin.goals.v1"
dayKey(ts) = local year-month-day, zero-padded month/day
record(kind):  today = activity[dayKey(now)] ?? {0,0}; increment drills or hands by 1; save
today():       activity[dayKey(now)] ?? {drills: 0, hands: 0}
metGoal(day):  day != null && (day.drills >= 20 || day.hands >= 30)
streak():
  n = 0; t = now
  if !metGoal(activity[dayKey(t)]): t -= 86_400_000          // today not yet met → start from yesterday
  while metGoal(activity[dayKey(t)]): n++; t -= 86_400_000
  return n
```

This subsystem calls `record("hand")` once per completed hand (in `finalizeHand`). Drills are
recorded by the drills subsystem. Pinned behaviour:

| activity (relative to today T) | streak() |
|---|---|
| `{}` | 0 |
| `{T: {hands: 30}}` | 1 |
| `{T: {hands: 29, drills: 19}}` | 0 |
| `{T-1: {drills: 20}}` (today empty) | 1 |
| `{T-1: {hands: 30}, T-2: {hands: 30}}` (today empty) | 2 |
| `{T: {hands: 30}, T-2: {hands: 30}}` | 1 (gap at T-1 breaks it) |
| `{T-2: {hands: 30}}` | 0 |

Port note: the 24 h subtraction across a DST change can skip or repeat a local date; using a
calendar-date decrement in Dart is the more correct interpretation of "consecutive days".

---

## 23. Settings

### 23.1 App settings (`settingsStore`, persisted at `"allin.settings.v1"`, merged over defaults on load)

| Key | Type | Default | Meaning |
|---|---|---|---|
| `fourColorDeck` | bool | false | ♠ black · ♥ red · ♦ blue · ♣ green |
| `reducedMotion` | bool | false | disable animations (also honours the OS preference) |
| `coachStrictness` | `relaxed` \| `standard` \| `strict` | `standard` | see thresholds |
| `simQuality` | `standard` \| `high` | `standard` | 1600 vs 4000 base trials |
| `realisticReveal` | bool | false | hide folded players' cards at hand end |

`coachThresholds(s)`: relaxed → `{mistakeBb: −0.6, foldFlagBb: 2.5}`; strict → `{−0.15, 1.0}`;
standard (and anything else) → `{−0.3, 1.5}`. `mistakeBb` is the EV (in bb) below which a call is
a mistake; `foldFlagBb` is the EV(call) (in bb) a fold must have thrown away before it is flagged.

Settings screen copy (verbatim):
* Section **Table & cards** — `Four-color deck`: `♠ black · ♥ red · ♦ blue · ♣ green. Makes suits unmistakable at a glance — recommended, and essential if you have trouble telling red suits apart.` (with a preview of As Ah Ad Ac)
  · `Realistic reveals`: `By default the app shows everyone's cards when a hand ends — folded hands included — because seeing what people folded builds intuition. Turn this on to hide folded hands, like a real table.`
  · `Theme`: `Light or dark — also switchable from the sidebar.` · `Reduce motion`: `Disables animations and transitions. Also honors your system's reduced-motion preference automatically.`
* Section **Coach** — `Strictness`: `How eagerly the coach interrupts. Relaxed only flags clear blunders; strict calls out smaller EV losses too.` (Relaxed / Standard / Strict)
  · `Simulation quality`: `High runs 2.5× more Monte-Carlo trials per verdict — slightly slower, tighter error bars. Late streets are always computed exactly either way.` (Standard / High)
* Section **Keyboard** — `Tour & placement`: `Re-run the first-launch tour and the placement quiz (recalibrates your drill rating).` (`Run again`) · `Shortcuts`: `Play and drill without touching the mouse. F fold · C check/call · R raise · 1/2/3 drill answers · Enter next.` (`View all shortcuts`)
* Page header: `Settings` / `Everything is saved on this device.`

### 23.2 Play settings (in `useGame.settings`, **not persisted**)

`coachEnabled = true`, `mode = "manual"`, `speedMs = 700`. Resetting on app start is intentional.

### 23.3 Other persisted keys touched by this subsystem

`allin.table.v1` (table options), `allin.goals.v1` (activity), `allin.leaks.v1` (leak spots,
cap 60, with SRS state), `allin.handnotes.v1` (notes). Stats (hands, guesses, decisions) go
through the stats DB (another subsystem); this subsystem only calls `recordHand`, `recordGuess`,
`recordDecision` and reads `decisions` / `guesses`.

---

## 24. Desktop layout (for orientation; mobile will be redesigned)

```
┌ nav 212px ┬──────────────── main ─────────────────────────────┐
│ Logo      │ ┌── table area (flex) ─────────────┐ ┌ SideRail 300 ┐ │
│ Play      │ │  PokerTable (felt, seats, pot)   │ │ This session │ │
│ Drills    │ │  ResultOverlay (centre, 44%)     │ │ Pace / Coach │ │
│ Study     │ │  EVCoachPanel (top-right 340px)  │ │ Hand log     │ │
│ Stats     │ │  Start overlay (when no session) │ │              │ │
│ Settings  │ └──────────────────────────────────┘ └──────────────┘ │
│ About     │ ┌── ActionBar (bottom, full width) ───────────────────┐ │
│ theme,tip │ │ cards+label | Fold Check/Call [sizing] Bet/Raise    │ │
└───────────┴─┴─────────────────────────────────────────────────────┘
Modals (portal, centred): GuessModal 620 · RangeViewModal 560 · SessionSummaryModal 520 · HandReplayModal 760 · HandNoteEditor 440
```

Start overlay (no active session), verbatim: heading `Ready to play?`; paragraph
`A session deals hand after hand against a fixed table of bots. Your stack carries over, so wins and losses stick until you end the session.`;
`Table` segmented `Heads-up` / `6-max` / `9-max`; `Antes` segmented `None` / `0.25 bb` (= 5 chips);
when seats ≠ 6: `Coach charts assume 6-max — verdicts at other table sizes use the nearest position as an approximation.`;
primary `Start session` → `newSession(tableOpts)`. The nav's tip box reads
`Use Guess Range before you act, then let the EV Coach grade the decision.` and the footer
`All-In · offline poker dojo · press ? for shortcuts`.

---

## 25. Edge cases and invariants (checklist for the port)

1. Hero is always seat 0; `heroAction` is ignored unless `phase == betting && toAct == 0`.
2. `paused` gates the hero (Action bar hides hero controls), `stepBot`, and the auto loop; it is set by a blocking review and by opening the guess modal, cleared by `dismissReview`, `closeGuess`, `deal`, `newSession`.
3. The coach evaluates the pre-action state; the action itself is never delayed by the sim.
4. A review is displayed only if the hand number is unchanged when the sim finishes; stats/leaks record regardless.
5. Only call-mistakes block. Fold/check/bet mistakes are non-blocking but still become leaks.
6. Folding when `toCall <= 0` is never graded; checking preflop or with `< 0.65` equity is never graded.
7. Escalation to 4× trials happens at most once, only when not exact, `costNow > 0`, and `|equity − threshold| < 2·se`.
8. Every verdict guard that says "mistake" uses the pessimistic/optimistic edge (`± margin`) so noise can never produce a mistake; exact enumerations have `margin = 0`.
9. Bots at 0 chips are refilled to the starting stack before each deal (store and engine both do it); the hero is not — `deal()` opens the busted summary instead.
10. `session.hands` / `netChips` / `history` update only in `finalizeHand` when a `currentHH` exists (always true for hands dealt via `deal()`).
11. `reviewLog` is cleared on every `deal()`; note ids keep increasing across hands.
12. `botRanges` is reset by `startHand`; a bot fold stores `[]`, which makes `villainRangeFor` fall back to the archetype range (only relevant for peeking at folded players, which the UI prevents).
13. The stored range always contains the acting bot's real hand; postflop it never grows (bot tests).
14. `handsSeen`, `vpipCount`, `pfrCount` persist across hands within a session and reset with `newSession` (fresh table).
15. `table.log` is capped at 200 entries by the engine.
16. Auto pace: no auto-deal at hand-over; the first bot action after any trigger waits `speedMs`.
17. The summary's "End" does not end the session; it shows the modal. Only `newSession` rebuilds the table.
18. `scoreGuess` is combo-weighted (6/4/12), and an empty painted set is "peek only" (no score, no stat).
19. `fmtTimes` boundaries: `≥ 0.93`, `≤ 0.04`, `≥ 0.45` (10-scale), else `1-in-N`.
20. All text templates in §5, §7, §9, §12, §18–§20 are user-facing and must be kept verbatim (TONE.md).

---

## 26. Existing automated tests touching this subsystem

There are no unit tests for `gameStore`, `format.ts`, `goalStore` or `scoreGuess` in the desktop
repo; the values tabulated in §11, §12.2, §21, §22 and the worked examples in §7.6 were derived
by hand from the code and are the recommended pins for the Dart tests. Existing scripts that
exercise the pieces this subsystem depends on:

* `scripts/hh_test.ts` — `buildReplayFrames` assertions listed in §21; also pins the PokerStars
  export format used by "Copy"/"Export" (e.g. `Dwan: raises 40 to 60`, `Uncalled bet (40) returned to Dwan`, `Total pot 520`).
* `scripts/bot_test.ts` — over 1200 hands: AA/KK never fold preflop; junk never calls ≥ 8 bb;
  `rangeExclusions == 0`; `postflopNarrowings > 200`; `postflopGrowths == 0`; ≥ 3 distinct bet
  sizings; check-raises occur; a "stab every check" hero and an "open-jam every hand" hero both lose money.
* `scripts/sim_test.ts` (600 hands, 6-max) and `scripts/table_config_test.ts` (heads-up 250,
  6-max+ante 250, 9-max 200, 9-max+ante 150): hand completes, chip conservation, no negative
  stacks, pot fully distributed, valid board lengths {0,3,4,5}; heads-up button posts the SB and
  acts first; antes = `sb + bb + ante × seats` in the pot and count toward `committedTotal` only.
