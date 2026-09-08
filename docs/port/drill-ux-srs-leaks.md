# Port spec — Drill session UX, spaced repetition (SRS), leak detection

Subsystem id: `drill-ux-srs-leaks`
Source app: All-In · Poker Dojo (React + TypeScript + Zustand), repo `/Users/gapp/Documents/Code/poker`
Target: Flutter/Dart mobile re-implementation. **This document is the only reference the porting engineer gets for this subsystem; nothing here requires opening the TypeScript.**

Source files covered (paths relative to the source repo):

| File | Lines | Role |
|---|---|---|
| `src/lib/srs.ts` | 50 | Pure SM-2-style scheduler (no deps, unit-tested) |
| `src/lib/leaks.ts` | 57 | Pure leak-detection rules over coached decisions (no deps, unit-tested) |
| `src/store/leakStore.ts` | 59 | Persisted queue of coach-flagged leak spots, scheduled by SRS |
| `src/store/reviewStore.ts` | 74 | Persisted queue of missed practice drills, scheduled by SRS (read for completeness; it is the twin of leakStore and the drill store depends on it) |
| `src/store/drillStore.ts` | 234 | Drill session state machine, mode selection, Elo rating, streaks, persistence |
| `src/store/goalStore.ts` | 76 | Daily activity / day-streak (only the parts the drill UI uses are specified here) |
| `src/views/DrillsView.tsx` | 134 | Drills tab: header stats, mode picker, empty Review state, layout |
| `src/components/drills/DrillTable.tsx` | 72 | Table rendering of the current replay frame |
| `src/components/drills/MoveNavigator.tsx` | 64 | "Hand replay" frame navigator |
| `src/components/drills/DrillControls.tsx` | 198 | Answer buttons, feedback panel, hotkeys |
| `src/components/study/Drills.tsx` | 315 | Three self-contained study-lesson mini-drills (pot odds, outs, range building) |
| `scripts/srs_test.ts` | 51 | 13 assertions — all pass |
| `scripts/leaks_test.ts` | 56 | 6 assertions — all pass |

Neighbouring subsystems referenced but **not** specified here (they get their own port docs): the puzzle generator/grader (`src/engine/puzzles.ts` — `generatePuzzle`, `generatePushFold`, `generateExploit`, `gradePuzzle`), the EV coach that produces decision verdicts (`src/store/gameStore.ts`), hand-history import (`src/lib/hhImport.ts`), the stats DB, the range matrix widget, Study lessons, onboarding. Where this subsystem *consumes* their types or *produces* data for them, the exact contract is written out below.

There is **no Rust twin** for anything in this subsystem (`poker-core/src/lib.rs` has no SRS/leak/rating code). Everything here is TypeScript-only and must be ported to Dart.

---

## 0. One-paragraph overview

The Drills tab shows one poker "puzzle" at a time on a 6-max table. The user can scrub through the hand's replay frames, then picks one of 2–3 actions. The store grades the pick, updates an Elo-style rating (in the three practice modes), a streak, lifetime solved/correct counters, and the daily-goal counter. Missed practice puzzles are stored as **review cards**. During play, the EV coach flags clear mistakes as **leak spots**; hand-history import can add more. Both queues are scheduled by one tiny SRS scheduler (1 day → 3 days → ~1 week; a miss brings the card back in 10 minutes; a card retires after 3 consecutive spaced successes). The fourth drill mode, "Review", serves due cards from both queues. Separately, `leaksFromDecisions` turns the coached-decision log into up to three plain-English leak sentences for the Stats page.

---

## 1. Shared domain types (contracts consumed from other subsystems)

All money values in generated puzzles are in **big blinds** (`bb = 1`). Cards are 2-char strings (`"Ah"`, `"Td"`). Positions are the fixed 6-max list. See §12 for a units caveat on leak spots.

```dart
// From the core types module.
typedef Card = String;          // "Ah", "Td", "2c"
typedef HandLabel = String;     // "AKs", "AKo", "TT"
enum Position { UTG, MP, CO, BTN, SB, BB }   // ORDER = [UTG, MP, CO, BTN, SB, BB]
enum Street { preflop, flop, turn, river, showdown }

// From the puzzle engine.
enum DrillAction { fold, check, call, bet, raise }

enum PuzzleKind {
  rfi, vsRaise /* "vs-raise" */, postflopBet /* "postflop-bet" */, postflopCheck /* "postflop-check" */,
  threebetPot /* "threebet-pot" */, checkRaise /* "check-raise" */, riverDecision /* "river-decision" */,
  pushfold, exploit, leak,
}
// String forms (used as JSON values and in review-card ids):
// "rfi" | "vs-raise" | "postflop-bet" | "postflop-check" | "threebet-pot" |
// "check-raise" | "river-decision" | "pushfold" | "exploit" | "leak"

class DrillOption {
  DrillAction action;
  String label;        // e.g. "Fold", "Call 2.5 bb", "Raise to 7.5 bb"
  double? amount;      // total bet/raise size in bb (bet/raise only)
}

class DrillSeatView {
  Position pos;
  bool isHero;
  bool folded;
  bool active;         // still in the hand and not hero
}

class DrillFrame {     // one step of the hand replay
  String text;         // human line shown in the navigator list
  Street street;
  List<Card> board;    // board as of this frame
  double pot;          // pot as of this frame (bb for generated puzzles)
}

class Puzzle {
  int id;                       // runtime sequence number (see §12 — NOT stable across launches)
  PuzzleKind kind;
  String source;                // "chart" | "heuristic"
  Street street;
  Position heroPos;
  List<Card> hole;              // exactly 2
  HandLabel handLabel;
  List<Card> board;
  double pot;                   // pot hero faces, INCLUDING any bet to call
  double toCall;
  double bb;                    // 1 for generated puzzles
  List<DrillSeatView> seats;    // always 6, in ORDER
  List<DrillFrame> frames;      // >= 1; LAST frame is the decision point
  List<DrillOption> options;    // 2 or 3
  DrillAction best;
  List<DrillAction> accept;     // answers graded correct (best is always included)
  String rationale;             // feedback paragraph, already plain-English
  double? equity;               // 0..1, pot-odds spots only
  double? potOdds;              // 0..1, pot-odds spots only
  int difficulty;               // 1..3
  List<HandLabel>? gradeRange;  // range the spot was graded against (feedback matrix)
  String? gradeRangeTitle;
  String? lessonId;             // Study lesson that teaches this concept
  String? lessonTitle;
  bool? icm;                    // push/fold spot graded in tournament $EV
}

class GradeResult {
  bool correct;
  DrillAction best;
  List<DrillAction> accept;
  String rationale;
  double? evLossBb;   // cost of the chosen action vs best, in bb; only for pot-odds spots
}
```

`gradePuzzle(p, action)` (engine, reproduced here because the feedback UI depends on its exact output):

```
correct = p.accept.contains(action)
evLossBb = null
if (!correct && p.equity != null && p.toCall > 0):
    evCall = p.equity * (p.pot + p.toCall) - p.toCall      // folding is worth 0
    evOf(a) = a == fold ? 0 : a == call ? evCall : null    // bet/raise/check: unknown
    chosen = evOf(action); bestEv = evOf(p.best)
    if (chosen != null && bestEv != null) evLossBb = max(0, bestEv - chosen)
return GradeResult(correct, p.best, p.accept, p.rationale, evLossBb)
```

### 1.1 Leak spot (produced by the coach / importer, consumed by leakStore)

```dart
class LeakSpot {
  String id;
  Street street;
  Position heroPos;
  List<Card> hole;             // 2
  List<Card> board;
  double pot;
  double toCall;
  double bb;
  List<Position> oppActive;    // opponents still in the hand
  List<DrillOption> options;
  DrillAction best;
  String rationale;
  double? equity;
  double? potOdds;
  int ts;                      // epoch ms when captured
  SrsState? srs;               // absent on records saved before scheduling existed
}
```

### 1.2 Coached decision record (produced by the coach, consumed by leak detection)

```dart
class DecisionRecord {
  String verdict;            // "mistake" | "thin" | "ok" | "great" | "info"
  String action;             // "fold" | "check" | "call" | "bet" | "raise" | "post"
  double equity;             // 0..1
  double potOdds;            // 0..1
  double evBb;
  String street;
  String? villainArchetype;  // "TAG" | "LAG" | "Nit" | "Station" | null
  String? position;          // hero's seat when the decision was made (optional)
  int ts;
}
```

These are appended by the game store on every coached decision (`useStats.recordDecision`) and persisted to SQLite (or a localStorage fallback) — in memory only the **last 800** are kept, and that in-memory list is what the leak report is computed from.

---

## 2. Spaced-repetition scheduler (`src/lib/srs.ts`)

Pure functions, no I/O. "SM-2 family, tuned small."

### 2.1 State

```dart
class SrsState {
  int due;             // epoch ms; the card is due when now >= due
  int intervalDays;    // last scheduled interval (0 until the first success / after a miss)
  double ease;         // growth factor, clamped to [1.3, 3.0]
  int reps;            // consecutive correct SPACED reviews
  int lapses;          // total misses ever
}
const int RETIRE_REPS = 3;
```

JSON shape (persisted verbatim inside leak spots and review cards):
`{"due":1750086400000,"intervalDays":1,"ease":2.35,"reps":1,"lapses":0}`

### 2.2 Functions

```dart
SrsState newSrs(int now) => SrsState(due: now, intervalDays: 0, ease: 2.3, reps: 0, lapses: 0);
// A brand-new card is due IMMEDIATELY.

SrsState reviewSrs(SrsState s, bool correct, int now) {
  if (!correct) {
    return SrsState(
      due: now + 10 * 60 * 1000,               // back in 10 minutes
      intervalDays: 0,
      ease: max(1.3, s.ease - 0.2),
      reps: 0,                                 // the ladder restarts
      lapses: s.lapses + 1,
    );
  }
  final intervalDays = s.reps == 0 ? 1
                     : s.reps == 1 ? 3
                     : max(4, jsRound(s.intervalDays * s.ease));
  return SrsState(
    due: now + intervalDays * 86400000,
    intervalDays: intervalDays,
    ease: min(3.0, s.ease + 0.05),
    reps: s.reps + 1,
    lapses: s.lapses,
  );
}

bool isDue(SrsState? s, int now) => s == null || s.due <= now;   // missing state == due
bool isGraduated(SrsState s) => s.reps >= RETIRE_REPS;
```

`jsRound(x)` = JavaScript `Math.round` = `(x + 0.5).floor()` (half rounds toward +∞). Here the argument is always positive so Dart's `round()` gives the same result, but use the helper everywhere for parity (see §12).

### 2.3 Invariants and behaviour to preserve

- The ladder is **1 day → 3 days → max(4, round(prev × ease))**. With the default ease the third interval is `round(3 × 2.4) = 7` days; a fourth success (if the card were kept) would be `round(7 × 2.45) = 17`.
- Ease only moves ±: +0.05 per success (ceiling 3.0), −0.2 per miss (floor 1.3). Ease is **never reset** by a miss, only decremented.
- `reps` resets to 0 on a miss; `lapses` only ever grows.
- A miss makes the card due again in exactly 600 000 ms.
- "Graduated" means `reps >= 3`. The *stores* delete a card when a review is correct **and** the post-review state is graduated (§3.2, §4.2). The scheduler itself never deletes anything.
- Floating-point: `ease` accumulates binary rounding (`2.3 + 0.05 = 2.3499999999999996` in IEEE-754 double). Dart doubles are IEEE-754 binary64 too, so performing the same operations in the same order reproduces the same bits; persisted JSON from the web app may contain such values and must parse fine.

### 2.4 Pinned ladder (from running the code, `t0 = 1_750_000_000_000`, `DAY = 86_400_000`)

| Step | Call | due | intervalDays | ease | reps | lapses |
|---|---|---|---|---|---|---|
| fresh | `newSrs(t0)` | t0 | 0 | 2.3 | 0 | 0 |
| r1 | `reviewSrs(fresh, true, t0)` | t0 + 1 DAY = 1750086400000 | 1 | 2.3499999999999996 | 1 | 0 |
| r2 | `reviewSrs(r1, true, t0 + 1 DAY)` | t0 + 4 DAY = 1750345600000 | 3 | 2.3999999999999995 | 2 | 0 |
| r3 | `reviewSrs(r2, true, t0 + 4 DAY)` | t0 + 11 DAY = 1750950400000 | 7 | 2.4499999999999993 | 3 (graduated) | 0 |
| miss | `reviewSrs(r2, false, t0 + 4 DAY)` | t0 + 4 DAY + 600000 = 1750346200000 | 0 | 2.1999999999999993 | 0 | 1 |
| rec | `reviewSrs(miss, true, t0 + 5 DAY)` | t0 + 6 DAY = 1750518400000 | 1 | 2.249999999999999 | 1 | 1 |
| r4 | `reviewSrs(r3, true, t0 + 11 DAY)` | t0 + 28 DAY | 17 | 2.499999999999999 | 4 | 0 |
| floor | 20 × miss from fresh, all at t0 | — | 0 | 1.3 (exact) | 0 | 20 |
| ceil | 20 × (success then force `reps = 1`) | — | 3 | 3 (exact) | — | 0 |

### 2.5 Test cases (`scripts/srs_test.ts`, 13 assertions, all must pass in Dart)

Using the states above:

1. `isDue(fresh, t0) == true` — "new card is due now"
2. `isGraduated(fresh) == false`
3. `r1.intervalDays == 1 && r1.due == t0 + DAY`
4. `isDue(r1, t0 + DAY / 2) == false` — not due before its date
5. `r2.intervalDays == 3`
6. `r3.intervalDays >= 4` (actual 7)
7. `r3.reps == RETIRE_REPS && isGraduated(r3)`
8. `miss.reps == 0 && miss.lapses == 1`
9. `miss.due - (t0 + 4 DAY) <= 15 * 60_000` (actual 600 000)
10. `miss.ease < r2.ease`
11. `rec.intervalDays == 1 && !isGraduated(rec)` — "one correct answer never retires a card"
12. After 20 consecutive misses from `newSrs(t0)`: `ease >= 1.3`
13. `g = newSrs(t0); repeat 20: g = reviewSrs(g, true, t0) with reps forced back to 1` → `g.ease <= 3`

---

## 3. Leak queue (`src/store/leakStore.ts`)

### 3.1 Persistence

- Key: `allin.leaks.v1` (localStorage). Value: JSON array of `LeakSpot`, **newest first**.
- Cap: `CAP = 60`. Adding beyond the cap drops the oldest (tail).
- Load migration: any spot without `srs` gets `newSrs(spot.ts ?? now)` — i.e. spots saved before scheduling existed become due immediately. Non-array or unparsable → `[]`.
- Every mutation saves synchronously; save errors (quota) are swallowed.

### 3.2 API

```dart
class LeakStore {
  List<LeakSpot> spots;

  void add(LeakSpot s) {
    // prepend; give it fresh SRS if it has none; cap at 60
    spots = [s.copyWith(srs: s.srs ?? newSrs(nowMs())), ...spots].take(60).toList();
    save();
  }

  /// Apply a spaced-repetition review. A leak only retires after RETIRE_REPS
  /// correct answers on the spaced ladder — one lucky answer never deletes it.
  void review(String id, bool correct) {
    final now = nowMs();
    spots = spots
      .map((x) => x.id == id ? x.copyWith(srs: reviewSrs(x.srs ?? newSrs(now), correct, now)) : x)
      .where((x) => !(x.id == id && correct && x.srs != null && isGraduated(x.srs!)))
      .toList();
    save();
  }

  List<LeakSpot> dueSpots(int now) => spots.where((s) => isDue(s.srs, now)).toList();

  void clear() { spots = []; save(); }   // NOTE: never called by any UI in the source app
}
```

No de-duplication on `add` — the same hand can produce several spots (one per street); ids are unique by construction (§3.3).

### 3.3 Producers of leak spots (what actually lands in the queue)

**(a) Live play — EV coach (`gameStore.ts`).** After every coached hero decision with `review.kind == "decision"`, a `DecisionRecord` is appended to stats (§1.2). If additionally `review.verdict == "mistake"`, a `LeakSpot` is added:

```
best action for the drill (by the mistake type):
  hero played call  -> best = fold      (bad call)
  hero played fold  -> best = call      (bad fold)
  hero played check -> best = bet       (missed value)
  hero played bet   -> best = check     (bad bluff)
  hero played raise -> best = fold      (bad raise)   // any other action also -> fold

options:
  if toCall > 0:  [ {fold,"Fold"}, {call, "Call ${(callAmount/bb).toFixed(1)} bb", amount: callAmount},
                    {raise, "Raise", amount: round(pot + callAmount)} ]
  else:           [ {check,"Check"}, {bet, "Bet", amount: round(pot * 0.66)} ]

spot = {
  id: "${handNumber}-${street}-${Date.now()}",
  street, heroPos: hero.position, hole: hero.hole, board: [...board],
  pot: table.pot,            // CHIPS
  toCall: callAmount,        // CHIPS
  bb: table.bigBlind,        // e.g. 20
  oppActive: positions of non-hero players who have not folded,
  options, best,
  rationale: review.text,    // the coach's plain-English verdict paragraph
  equity: review.equity, potOdds: review.potOdds,   // may be undefined
  ts: Date.now(),
}
```

Note the units: live-coach spots are in **chips** with `bb = bigBlind`. See §12.

**(b) Hand-history import (`hhImport.analyzeImported`).** For each imported hand where hero *called* a positive amount, equity is estimated vs a random hand (2 500 Monte-Carlo samples, seeded by `hashSeed("imp|${startedAt}|${street}|${amount}")`; exact on the river). Flag as a leak **only** if
`equity + 2 × standardError + 0.08 < needed` where `needed = amount / (pot + amount)`. The spot:

```
id: "imp-${startedAt}-${street}"
pot: pot / bb, toCall: amount / bb, bb: 1          // normalised to BB
oppActive: every non-hero seat (folds are not tracked)
options: [ {fold,"Fold"}, {call, "Call ${(amount/bb).toFixed(1)} bb", amount: amount/bb} ]
best: fold
rationale: "Imported hand: you called ${(amount/bb).toFixed(1)} bb needing ${round(needed*100)}% but ${handLabel} wins only ~${round(equity*100)}% even against a random hand — real ranges make it worse."
equity, potOdds: needed, ts: now
```

The import UI then reports (verbatim template):
`Imported ${n} hand${n==1?"":"s"}${skipped ? " (${skipped} skipped)" : ""} · reviewed ${reviewed} of your calls · ${leaks.length ? "${leaks.length} questionable one${leaks.length==1?"":"s"} added to the Review queue" : "no clear mistakes found"}. Imported hands never count toward your play stats.`

**(c)** Nothing else adds leak spots. Missed *practice drills* go to the review store (§4), not here.

### 3.4 Turning a leak spot into a playable puzzle (`puzzleFromLeak`, engine)

```
folded   = ORDER minus heroPos minus oppActive          // everyone not listed as active is shown folded
streetLabel = capitalise(street)                        // "Flop", "Preflop", ...
frames = [
  { text: board.isEmpty ? "Pre-flop." : "${streetLabel}: ${board.join(" ")}",   // e.g. "Flop: Ah 7d 2c"
    street, board, pot },
  { text: "Action on you in the ${heroPos}${toCall > 0 ? " facing ${(toCall/bb).toFixed(1)} bb" : ""}. What's the play?",
    street, board, pot },
]
puzzle = Puzzle(
  id: nextSeq(), kind: leak, source: "heuristic", street, heroPos, hole,
  handLabel: cardsToLabel(hole[0], hole[1]), board, pot, toCall, bb,
  seats: fullSeats(heroPos, folded, oppActive),   // 6 seats in ORDER; active = in oppActive && != hero
  frames, options, best, accept: [best], rationale, equity, potOdds,
  difficulty: 2,
  // gradeRange, lessonId, lessonTitle, icm: all absent
)
```

Consequences for the feedback UI: leak puzzles never show the range toggle or the lesson button; only `best` is accepted.

---

## 4. Review queue — missed practice drills (`src/store/reviewStore.ts`)

### 4.1 Persistence

- Key: `allin.review.v1`. Value: JSON array of `ReviewCard { id: String, puzzle: Puzzle, srs: SrsState }`, newest first. The **entire puzzle** (frames, seats, options, rationale, ranges…) is stored.
- Cap: `CAP = 80`. No load migration (`srs` is always present).

### 4.2 API

```dart
void addMiss(Puzzle p) {
  // One card per spot identity (kind + hand + board + hero seat).
  final key = "${p.kind}|${p.handLabel}|${p.board.join("")}|${p.heroPos}";   // e.g. "rfi|AJo||CO", "postflop-bet|KQs|Ah7d2c|BB"
  if (cards.any((c) => c.id == key)) return;          // already queued: keep the existing schedule
  cards = [ReviewCard(id: key, puzzle: p, srs: newSrs(nowMs())), ...cards].take(80).toList();
  save();
}

void review(String id, bool correct) {   // identical logic to leakStore.review
  final now = nowMs();
  cards = cards
    .map((c) => c.id == id ? c.copyWith(srs: reviewSrs(c.srs, correct, now)) : c)
    .where((c) => !(c.id == id && correct && isGraduated(c.srs)))
    .toList();
  save();
}

List<ReviewCard> dueCards(int now) => cards.where((c) => isDue(c.srs, now)).toList();
void clear() { cards = []; save(); }     // never called by any UI in the source app
```

---

## 5. Leak detection rules (`src/lib/leaks.ts`)

Pure function over the coached-decision log (in practice the in-memory last 800 decisions).

```dart
class LeakReport {
  int total;          // decisions excluding "info"
  int mistakes;
  int thin;
  int great;
  int foldMistakes;   // verdict == mistake && action == fold
  int callMistakes;   // verdict == mistake && action == call
  List<String> leaks; // 0..3 sentences, in the order below
}

LeakReport leaksFromDecisions(List<DecisionRecord> decisions) {
  final dec = decisions.where((d) => d.verdict != "info").toList();
  final mistakes = dec.where((d) => d.verdict == "mistake").toList();
  final thin  = dec.where((d) => d.verdict == "thin").length;
  final great = dec.where((d) => d.verdict == "great").length;
  final foldMistakes = mistakes.where((d) => d.action == "fold").length;
  final callMistakes = mistakes.where((d) => d.action == "call").length;
  final n = dec.length;
  final leaks = <String>[];
  if (n >= 8) {
    if (foldMistakes >= 3 && foldMistakes / n > 0.12) leaks.add(LEAK_FOLD);
    if (callMistakes >= 3 && callMistakes / n > 0.12) leaks.add(LEAK_CALL);
    if (mistakes.isEmpty)                              leaks.add(LEAK_CLEAN);
  }
  return LeakReport(n, mistakes.length, thin, great, foldMistakes, callMistakes, leaks);
}
```

The three sentences, **verbatim** (note the Unicode minus sign U+2212 in the third):

| Const | Rule | Text |
|---|---|---|
| `LEAK_FOLD` | `n ≥ 8 && foldMistakes ≥ 3 && foldMistakes/n > 0.12` | `You fold too often when you're getting the right price — look for more +EV calls.` |
| `LEAK_CALL` | `n ≥ 8 && callMistakes ≥ 3 && callMistakes/n > 0.12` | `You call too wide for the pot odds — fold your weakest hands more.` |
| `LEAK_CLEAN` | `n ≥ 8 && mistakes == 0` | `No clear −EV mistakes flagged — solid discipline. Keep refining the thin spots.` |

Edge cases: fewer than 8 non-info decisions → `leaks` is always empty, whatever the counts. Both "fold" and "call" sentences can appear together. The "clean" sentence is mutually exclusive with the other two (they require mistakes). The ratio uses integer division semantics in Dart only if you forget to cast — use doubles: `foldMistakes / n` where n is int → in Dart `foldMistakes / n` already yields double.

### 5.1 One extra rule that lives in the Stats view (not in `leaks.ts`)

The Stats page appends a fourth sentence after the report's list when the range-guess history has **≥ 5 guesses and mean accuracy < 0.5**:

`Your range reads are often off — drill Guess & Peek and the Range-Building exercise.`

### 5.2 Where the report is shown (Stats page, "Coaching review" card)

- If `report.total == 0`: `Play with the EV Coach on and your reviewed decisions, leaks and mistakes will appear here.`
- Else three count boxes labelled `Mistakes` (red), `Thin spots` (amber), `Great plays` (green); then the leak sentences each prefixed with a bolt icon; then a `Recent −EV decisions` list of the last 5 `mistake` records, newest first.

### 5.3 Test cases (`scripts/leaks_test.ts`, 6 assertions)

Helper `d(verdict, action)` builds a record with `equity 0.3, potOdds 0.25, evBb -1, street "flop", villainArchetype "TAG", ts 0`.

1. `leaksFromDecisions([])` → `total == 0`, `leaks` empty.
2. 4 × `d("mistake","fold")` + 6 × `d("ok","call")` → `total == 10`, `foldMistakes == 4`, and some leak contains `"fold too often"` (case-insensitive).
3. 4 × `d("mistake","call")` + 6 × `d("ok","check")` → `callMistakes == 4`, some leak contains `"call too wide"`.
4. 6 × `d("ok","call")` + 4 × `d("great","bet")` → `mistakes == 0`, `great == 4`, some leak contains `"No clear"`.
5. `[d("info","check"), d("info","check"), d("ok","call")]` → `total == 1`.
6. (implicit in 1) empty input has no leaks.

Extra pins worth adding in Dart: 7 decisions with 3 fold mistakes → no leaks (n < 8); 8 decisions with 2 fold mistakes → no leaks (count < 3); 25 decisions with 3 fold mistakes → no fold leak (3/25 = 0.12 is not > 0.12); 24 decisions with 3 fold mistakes → fold leak (0.125).

---

## 6. Drill store (`src/store/drillStore.ts`)

### 6.1 Modes

```dart
enum DrillMode { mixed, pushfold, exploit, leaks }   // JSON/strings: "mixed" | "pushfold" | "exploit" | "leaks"
```

UI names and blurbs (verbatim, `MODE_INFO`), in picker order:

| mode | label | blurb |
|---|---|---|
| mixed | `Mixed` | `Pre-flop charts + post-flop pot-odds/equity. Opponent type is irrelevant — play solid baseline poker.` |
| pushfold | `Push / Fold` | `Short-stack shove/fold and call-a-shove spots, graded by computed Nash equilibrium tables (chip-EV, no antes).` |
| exploit | `Exploits` | `Best deviation vs a KNOWN opponent type — the spots where the right play differs from balanced, with both numbers shown.` |
| leaks | `Review` | `Your coach-flagged leaks and missed drills on a spaced schedule — beat a spot 3 times over days to retire it.` |

### 6.2 Persisted record

- Key `allin.drills.v1`, JSON object `{ rating, solved, correct, streak, best }` (all ints).
- Load: accepted only if parsed value is an object with a numeric `rating`; otherwise defaults `{ rating: 1000, solved: 0, correct: 0, streak: 0, best: 0 }`.
- **Not persisted** (session only): mode, current puzzle, nav index, answer/result, focus state. Every app launch starts in `mixed` with a fresh, *non-adaptive* `generatePuzzle()`.

### 6.3 Full state

```dart
class DrillState {
  // persisted
  int rating;         // Elo-like, floor 100, default 1000
  int solved;         // answers given in practice modes (NOT review mode)
  int correct;        // correct answers in practice modes
  int streak;         // current consecutive-correct run (practice modes)
  int best;           // best streak ever
  // session
  DrillMode mode = mixed;
  Puzzle puzzle;                 // never null; initial = generatePuzzle()
  String? currentLeakId;         // set when the current puzzle came from the leak queue
  String? currentReviewId;       // set when it came from the review queue
  int navIndex;                  // replay frame shown; initial = frames.length - 1
  DrillAction? answered;         // null until the user answers
  GradeResult? result;
  int ratingDelta = 0;           // shown next to "Correct"/"Not optimal" when != 0
  PuzzleKind? focusKind;         // "Drill 5 similar": spot family
  int focusLeft = 0;             // remaining similar puzzles
}
```

### 6.4 Puzzle selection `genFor(mode, focusKind)`

Returns `(puzzle?, leakId?, reviewId?)`.

```
pushfold -> (generatePushFold(), null, null)
exploit  -> (generateExploit(),  null, null)
leaks    ->
    now = nowMs()
    dueLeaks = leakStore.dueSpots(now)         // queue order: newest first
    dueCards = reviewStore.dueCards(now)
    total = dueLeaks.length + dueCards.length
    if total == 0 -> (null, null, null)
    pick = floor(random() * total)             // uniform over BOTH queues combined
    if pick < dueLeaks.length -> (puzzleFromLeak(dueLeaks[pick]), dueLeaks[pick].id, null)
    else c = dueCards[pick - dueLeaks.length] -> (c.puzzle, null, c.id)
mixed with focusKind != null ->
    repeat up to 60 times: p = generatePuzzle(); if p.kind == focusKind return (p, null)
    return (generatePuzzle(), null)            // fallback: whatever comes
mixed, no focus -> (adaptivePuzzle(rating), null)
```

The review-card puzzle is the stored object as-is (its original `kind`, `gradeRange`, `lessonId`… all intact); it is not regenerated.

### 6.5 Adaptive difficulty `adaptivePuzzle(rating)`

Choose a target difficulty by rating band, then rejection-sample `generatePuzzle()` up to **25** times for that difficulty; fall back to the 26th draw unconditionally.

| rating band | P(target = 1) | P(target = 2) | P(target = 3) |
|---|---|---|---|
| `rating < 1050` | 0.70 | 0.30 | 0 |
| `1050 ≤ rating < 1250` | 0.225 | 0.55 | 0.225 |
| `rating ≥ 1250` | 0 | 0.40 | 0.60 |

Exact draw order (to reproduce with a seeded RNG):
```
if rating < 1050:        target = random() < 0.7 ? 1 : 2
else if rating < 1250:   target = random() < 0.55 ? 2 : (random() < 0.5 ? 1 : 3)   // second draw only if first fails
else:                    target = random() < 0.6 ? 3 : 2
```

Difficulty is assigned by the generator (1 = clear chart spot, 2 = standard, 3 = "close" — e.g. a pot-odds spot whose equity is within ±0.06 of break-even, or a chart hand played 20–80 % of the time).

### 6.6 `answer(a)`

```
if answered != null: return                         // one answer per puzzle
res = gradePuzzle(puzzle, a)
goals.record("drill")                               // daily-goal counter, ALL modes

if mode == leaks:
    if currentLeakId != null:   leakStore.review(currentLeakId, res.correct)
    if currentReviewId != null: reviewStore.review(currentReviewId, res.correct)
    answered = a; result = res; ratingDelta = 0; navIndex = frames.length - 1
    return                                          // rating/solved/correct/streak UNTOUCHED, nothing saved

// practice modes
if !res.correct && puzzle.kind != leak: reviewStore.addMiss(puzzle)

puzzleRating = 800 + puzzle.difficulty * 200        // 1000 / 1200 / 1400
expected = 1 / (1 + pow(10, (puzzleRating - rating) / 400))
delta = jsRound(24 * ((res.correct ? 1 : 0) - expected))
rating = max(100, jsRound(rating + delta))
streak = res.correct ? streak + 1 : 0
best = max(best, streak)
solved += 1
correct += res.correct ? 1 : 0
persist {rating, solved, correct, streak, best}
answered = a; result = res; ratingDelta = delta; navIndex = frames.length - 1
```

Elo K-factor 24. Pinned deltas (`win` when correct, `lose` when wrong):

| rating | d=1 (1000) | d=2 (1200) | d=3 (1400) |
|---|---|---|---|
| 900  | E=0.3599 win +15 lose −9  | E=0.1510 win +20 lose −4  | E=0.0532 win +23 lose −1 |
| 1000 | E=0.5000 win +12 lose −12 | E=0.2403 win +18 lose −6  | E=0.0909 win +22 lose −2 |
| 1050 | E=0.5715 win +10 lose −14 | E=0.2966 win +17 lose −7  | E=0.1177 win +21 lose −3 |
| 1250 | E=0.8083 win +5 lose −19  | E=0.5715 win +10 lose −14 | E=0.2966 win +17 lose −7 |
| 1400 | E=0.9091 win +2 lose −22  | E=0.7597 win +6 lose −18  | E=0.5000 win +12 lose −12 |

Invariants: rating never drops below 100; a wrong answer always gives `delta ≤ 0` and a right one `delta ≥ 0` (delta can be 0 only through rounding, e.g. never for these bands); answering always snaps the replay to the decision frame.

### 6.7 `next()`

```
focus = focusLeft > 0 ? focusKind : null
(p, leakId, reviewId) = genFor(mode, focus)
if p == null:                                        // only possible in Review mode
    answered = null; result = null; ratingDelta = 0; currentLeakId = null; currentReviewId = null
    return                                           // puzzle object left unchanged; view shows the empty state
focusLeft = focus != null ? focusLeft - 1 : 0
puzzle = p; currentLeakId = leakId; currentReviewId = reviewId
navIndex = p.frames.length - 1; answered = null; result = null; ratingDelta = 0
focusKind = focusLeft > 0 ? focusKind : null
```

### 6.8 `drillSimilar()`

```
if mode == leaks || puzzle.kind == leak: return
focusKind = puzzle.kind; focusLeft = 5
next()
```
So exactly 5 puzzles of the same `kind` follow (after the first one is dealt `focusLeft` is 4, then 3, 2, 1, 0). Not adaptive while focused.

### 6.9 `setMode(m)`

```
mode = m
(p, leakId, reviewId) = genFor(m)              // no focus passed…
if p == null: answered = null; result = null; currentLeakId = null; currentReviewId = null; return
puzzle = p; currentLeakId = leakId; currentReviewId = reviewId
navIndex = last; answered = null; result = null; ratingDelta = 0
```
…but `focusKind/focusLeft` are **not** reset. Quirk: if a focus was active in Mixed and the user switches to Push/Fold, each `next()` there still decrements `focusLeft` (ignored by the generator), so switching back to Mixed may resume with fewer (or zero) similar spots. Acceptable to reset focus on mode change in the port; note it as a deliberate deviation.

### 6.10 `seedRating(rating)`

Overwrites `rating` only, keeping solved/correct/streak/best, and persists. Called once by the onboarding placement quiz (§10).

### 6.11 `setNav(i)`

`navIndex = clamp(i, 0, frames.length - 1)`.

---

## 7. Daily goal integration (`src/store/goalStore.ts`) — only what the drill UI needs

- Key `allin.goals.v1`, JSON map `dayKey → { drills: int, hands: int }`.
- `dayKey(ts)` = local-time `YYYY-MM-DD` (zero-padded month/day).
- `DAILY_DRILL_GOAL = 20`, `DAILY_HAND_GOAL = 30`; `metGoal(day) = day != null && (day.drills >= 20 || day.hands >= 30)`.
- `record("drill")` increments today's `drills` by 1 and saves. Called by `answer()` in **every** mode, including Review (the daily goal counts review answers even though rating/solved do not).
- `today()` → today's counts or `{0,0}`.
- `streak()`: let `t = now`; if today's goal is not met, `t -= 1 day`; then count consecutive days going backwards (by subtracting 86 400 000 ms) whose goal is met. Port note: step by calendar day, not by 24 h, to be DST-safe — the source's ms stepping is a latent bug, not a feature.

---

## 8. Drills tab UX (`DrillsView.tsx`)

### 8.1 Header

- Title `Drills` (display font, xl). Under it the current mode's blurb (§6.1) in small faint text.
- Right side (hidden entirely in Review mode): a row of stat tiles, each a small bordered card with an uppercase caption and a monospace bold value:

| caption | value | tone / extras |
|---|---|---|
| `Rating` | `rating` as int | gold value; info-icon; tooltip: `A self-adjusting puzzle rating (like a chess puzzle ELO). Right answers raise it, wrong ones lower it, weighted by difficulty.` |
| `Accuracy` | `${acc}%` with `acc = solved > 0 ? round(correct / solved * 100) : 0` | |
| `Streak` | `streak` | |
| `Best` | `best` | |
| `Today` | `${min(todayDrills, 20)}/20` | gold when `todayDrills >= 20`; info-icon; tooltip: `A quiet daily goal: 20 drill answers (or 30 hands) keeps the day-streak alive. No reminders, no guilt — just a nudge to come back tomorrow.` |
| `Day streak` | `dayStreak` | only rendered when `dayStreak > 0` |

- Mode picker: four pill buttons in `MODE_INFO` order; selected = gold background, dark text; others = dark background, muted text. The Review button's label is `Review (${dueCount} due)` when `dueCount > 0`, else `Review`.
  - `dueCount = leakSpots.count(s => s.srs == null || s.srs.due <= now) + reviewCards.count(c => c.srs.due <= now)`
  - `totalCards = leakSpots.length + reviewCards.length`
  - These are recomputed on every render from the live queues (they update the instant a review answer reschedules a card — see §12 quirk).

### 8.2 Body

`emptyLeaks = mode == leaks && dueCount == 0`.

If `emptyLeaks`, a centred panel (max width 440) with a green check badge and:

- heading: `Nothing due right now` if `totalCards > 0`, else `No spots to review yet`
- body: if `totalCards > 0`: `All ${totalCards} of your review spots are scheduled for later — spaced practice sticks best when you come back to it. Play or drill in the meantime.`
  else: `Play a session with the EV Coach on, or miss a practice drill, and the spot lands here on a spaced-repetition schedule until you've beaten it three times.`

Otherwise a two-pane layout: the table (`DrillTable`) fills the left; a 360 px right aside (scrollable) stacks `DrillControls` above `MoveNavigator`. On mobile this becomes a vertical stack: table on top, controls, then the navigator (port decision; the desktop widths are not meaningful).

### 8.3 Table (`DrillTable`)

- Shows `frame = frames[navIndex] ?? frames.last`.
- Centre: `Pot` widget = street caption (`Pre-flop` / `Flop` / `Turn` / `River` / `Showdown`, uppercase, letter-spaced) over a gold chip pill reading `${fmtBb(frame.pot, puzzle.bb)} bb`; below it the board cards of the frame (face up, width 48).
- Six seats. Rendering order is **hero first, then the other five in `ORDER`**, placed at fixed anchors (percent of table box): hero `(50%, 85%)`, then `(89%, 60%)`, `(89%, 18%)`, `(50%, 7%)`, `(11%, 18%)`, `(11%, 60%)` — i.e. hero bottom centre, others clockwise from bottom-right.
- Hero seat: both hole cards face up (width 42); name plate with gold ring; caption `You` in gold.
- Other seats: two face-down cards (width 26); folded seats render the cards at 25 % opacity greyscale and the plate at 50 % opacity; caption `Folded` (faint) or `In hand` (info colour).
- Every plate shows the position code (`UTG`…`BB`) in bold.
- The `folded` flag comes from the puzzle's `seats`; `active` is not used for rendering.

### 8.4 Replay navigator (`MoveNavigator`)

- Caption `Hand replay`. Four icon buttons with accessibility labels `First`, `Previous`, `Next`, `Decision`:
  - First → `setNav(0)`; Previous → `setNav(navIndex - 1)`; both disabled when `navIndex == 0`.
  - Next → `setNav(navIndex + 1)`; Decision → `setNav(last)`; both disabled when `navIndex == last`.
- Below, a scrollable list (max height 150 px) of all frames: row = 1-based index in tiny mono, then `frame.text`; the current row is highlighted (gold tint); the **last** row is bold and carries a target icon (it is the decision point). Tapping a row → `setNav(i)`.
- Navigation is allowed before and after answering; answering snaps back to the last frame.

### 8.5 Answer panel and feedback (`DrillControls`)

Top row: `Your hand: ` followed by `puzzle.handLabel` in gold display font; on the right a pill with the **source label**:

```
kind == leak                    -> "Your flagged spot"
kind == exploit                 -> "Exploit · vs a known type"
kind == pushfold && icm == true -> "Push/Fold · ICM bubble"
kind == pushfold                -> "Push/Fold · computed Nash"
source == "chart"               -> "Pre-flop chart · 100bb baseline"
otherwise                       -> "Post-flop heuristic · fundamentals"
```

Option buttons: a 3-column grid of `puzzle.options` (2 or 3). Each shows `option.label`; the first three carry a small keycap `1`/`2`/`3` at top-left. Tapping calls `answer(option.action)`; all buttons are disabled once answered. Post-answer colouring:

- `accepted = result.accept.contains(option.action)` → green border/tint
- `chosenWrong = answered == option.action && !accepted` → red border/tint
- otherwise → dim/faint

Feedback block (rendered only when `result != null`, fades up), in order:

1. Verdict row: a filled round badge (green check / red X) and the word **`Correct`** (green) or **`Not optimal`** (red). If `ratingDelta != 0`, right-aligned mono `fmtSigned(ratingDelta, 0)` (e.g. `+12`, `-6`) coloured by sign. (Review mode always has delta 0 → nothing shown.)
2. EV-loss line, only if `!result.correct && result.evLossBb != null && result.evLossBb > 0.05`, in red:
   `That choice costs about ${evLossBb.toFixed(1)} bb every time — ${severity}.`
   with `severity = evLossBb < 0.5 ? "a small leak" : evLossBb < 1.5 ? "a real leak" : "a blunder-sized leak"`.
3. `result.rationale` paragraph (muted).
4. Per-option outcomes box, only if `puzzle.equity != null && puzzle.potOdds != null && puzzle.toCall > 0`:
   - `Folding: 0 bb — costs nothing more.` ("Folding:" bold)
   - `Calling: ${fmtSigned(equity * (pot + toCall) - toCall)} bb per try — your hand wins ${fmtTimes(equity)} and you need ${fmtNeed(potOdds)}.` ("Calling:" bold, the number mono)
   Example: equity 0.33, pot 24, toCall 8 → `Calling: +2.6 bb per try — your hand wins about 1 time in 3 and you need about 1 time in 4.`
5. Faint line, if either value exists: `Equity: ${fmtPct(equity)}` and/or `Pot odds: ${fmtPct(potOdds)}` (e.g. `Equity: 33%`, `Pot odds: 25%`).
6. Range reveal, only if `gradeRange` is non-empty: a gold text button with a chevron that rotates when open — label `See the range it was graded against` / `Hide the range`. When open: a read-only 13×13 range matrix (260 px) highlighting `gradeRange`, captioned by `gradeRangeTitle`. The open state resets to closed whenever the puzzle changes.
7. Button row (each fills half):
   - If `lessonId` present: secondary button with a book icon and label `lessonTitle ?? "Read the lesson"` → navigates to the Study tab and opens that lesson (`nav.go("study", lessonId)`).
   - If `mode != leaks && puzzle.kind != leak`: secondary button with a target icon, `Drill 5 similar` → `drillSimilar()`.
8. If `focusLeft > 0`: centred faint note `${focusLeft} more of this spot type coming up`.
9. Primary full-width button `Next puzzle` with an arrow icon → `next()`.

### 8.6 Keyboard shortcuts (desktop; map to nothing or to hardware-keyboard handling on mobile)

- Not yet answered: keys `1`, `2`, `3` choose `options[0..2]` (only if that index exists).
- Answered: `Enter` → `next()`.
- Ignored when focus is in a text field or a modifier (meta/ctrl/alt) is held.
- The global shortcut overlay lists under `Drills`: `1 / 2 / 3` — `Choose an answer`; `Enter` — `Next puzzle`.

### 8.7 Formatting helpers (`src/lib/format.ts`) used by this UI — exact behaviour

```dart
String fmtBb(num chips, num bb) {            // table pot pill
  final r = jsRound(chips / bb * 10) / 10;   // 1 decimal
  return r == r.truncate() ? r.toInt().toString() : r.toStringAsFixed(1);   // "12" or "12.5"
}
String fmtSigned(num n, [int digits = 1]) {  // "+2.6", "-6", "+0.0"
  var v = jsRound(n * pow(10, digits)) / pow(10, digits);
  if (v == 0) v = 0;                          // normalise -0 (JS prints "+0.0"; Dart would print "-0.0")
  return (v >= 0 ? "+" : "") + v.toStringAsFixed(digits);
}
String fmtPct(double frac, [int digits = 0]) => "${(frac * 100).toStringAsFixed(digits)}%";  // "33%"
String fmtTimes(double p) {                   // TONE.md: chances as counts
  if (p >= 0.93) return "almost every time";
  if (p <= 0.04) return "almost never";
  if (p >= 0.45) return "about ${jsRound(p * 10)} times in 10";
  return "about 1 time in ${jsRound(1 / p)}";  // (both branches of the source are identical)
}
String fmtNeed(double potOdds) {              // "you need to win ..."
  if (potOdds <= 0) return "any win rate";
  final r = jsRound(1 / potOdds * 2) / 2;     // nearest half
  return "about 1 time in ${r == r.truncate() ? r.toInt() : r.toStringAsFixed(1)}";
}
```
Pinned: `fmtTimes(0.33)="about 1 time in 3"`, `fmtTimes(0.5)="about 5 times in 10"`, `fmtTimes(0.2)="about 1 time in 5"`, `fmtTimes(0.07)="about 1 time in 14"`, `fmtTimes(0.95)="almost every time"`, `fmtTimes(0.03)="almost never"`; `fmtNeed(0.25)="about 1 time in 4"`, `fmtNeed(0.3)="about 1 time in 3.5"`, `fmtNeed(0.4)="about 1 time in 2.5"`, `fmtNeed(0)="any win rate"`; `fmtSigned(12,0)="+12"`, `fmtSigned(-6,0)="-6"`, `fmtSigned(1.234)="+1.2"`, `fmtSigned(-0.04)="+0.0"`.

### 8.8 Session flow, end to end

```
launch → mode=mixed, puzzle=generatePuzzle() (plain, not adaptive), navIndex=last
tap mode pill → setMode(m) → new puzzle for that mode (Review: random due card, or empty state)
scrub frames (buttons / list) → setNav(i)              [optional, any time]
tap an option (or key 1/2/3) → answer(a)
    practice modes: grade, Elo, streak, counters, daily goal, miss → review queue, persist
    review mode:    grade, reschedule that card (10 min / 1 d / 3 d / ≥4 d, retire at 3), daily goal
feedback panel; optional "Drill 5 similar" (practice, non-leak), optional lesson deep link
tap "Next puzzle" (or Enter) → next()
```

---

## 9. What "leaks become drills" means, precisely

1. Coach flags a `mistake` in play → `LeakSpot` (chips units, coach text as rationale) prepended to `allin.leaks.v1` with `srs = newSrs(now)` → due immediately.
2. Hand-history import flags a clearly bad call → `LeakSpot` (bb units, import text) likewise.
3. A wrong answer to any practice puzzle (Mixed/Push-Fold/Exploits) → the full `Puzzle` prepended to `allin.review.v1` keyed by `kind|handLabel|boardCards|heroPos`, due immediately (skipped if that key already exists).
4. The Review mode picker shows `(N due)`; `genFor(leaks)` picks uniformly among all due entries of both queues; leak spots are rebuilt into puzzles by `puzzleFromLeak` (§3.4), review cards are replayed verbatim.
5. Answering in Review mode reschedules only that card. Correct → up the ladder; on the 3rd consecutive spaced success the card is deleted. Wrong → back in 10 minutes, ladder reset, ease −0.2.
6. Nothing in the app ever empties either queue except the cap (60 / 80) and graduation. (`clear()` exists on both stores but has no caller; the Stats "Erase everything" reset clears hands/guesses/decisions only.)

---

## 10. Placement-test seeding (onboarding → `seedRating`)

The first-launch onboarding modal (key `allin.onboarded.v1`, value `"1"` once seen) offers an optional 8-question quiz. Each question's options are shuffled (Fisher–Yates per question) and shown in that order; the correct answer is always index 0 of the *unshuffled* list. Picking flashes green/red for 350 ms and auto-advances. Questions verbatim:

| # | q | options (correct first) |
|---|---|---|
| 1 | `Which beats which?` | `A flush beats a straight` / `A straight beats a flush` / `They tie` |
| 2 | `The best seat at the table is…` | `The button — you act last after the flop` / `Under the gun — you act first` / `The big blind — you've already paid` |
| 3 | `The pot is 10 bb and your opponent bets 5 bb. To call profitably you need to win about…` | `1 time in 4` / `1 time in 2` / `2 times in 3` |
| 4 | `A flush draw on the flop (9 outs, two cards to come) has roughly what chance of hitting?` | `About 36%` / `About 18%` / `About 9%` |
| 5 | `Why 3-bet (re-raise) before the flop?` | `Value with big hands, plus pressure with the right bluffs` / `Only ever with aces` / `To see a cheap flop` |
| 6 | `In a 3-bet pot with a low stack-to-pot ratio, top pair top kicker is usually…` | `A hand worth your whole stack` / `A fold to any bet` / `A hand to keep the pot tiny with` |
| 7 | `Against a player who never bluffs, their big river bet means you should…` | `Fold hands that only beat bluffs — even if folding is 'exploitable'` / `Call just often enough that bluffing can't profit` / `Always raise` |
| 8 | `With 10 big blinds in the small blind, folded to you, a solid strategy is…` | `Go all-in with over half your hands` / `Only go all-in with premium pairs` / `Just call the minimum and decide later` |

Intro copy: `Eight quick questions calibrate the drills to your level — harder spots if you're experienced, clearer ones if you're new. No grade, no judgment, and you can skip it.` Buttons `Skip — start playing` / `Calibrate me`. Progress caption `Question ${i+1} of 8`.

Seeding: `score <= 2 → seedRating(900)`; `score <= 5 → 1050`; else `1250`. (Compare the adaptive bands in §6.5: 900 → mostly difficulty 1; 1050 → mostly 2; 1250 → mostly 3.)

Result card: level line `Starting fresh — perfect.` / `You know the basics.` / `Solid foundations.`; body `${score}/8 — drills are calibrated to match. ${advice}` with advice `Begin with Level 1: Hand Rankings. The course assumes nothing.` (lesson `hand-rankings`) / `Start at Pot Odds & EV — the math that powers every decision here.` (lesson `pot-odds`) / `Jump into the advanced track — 3-bet pots and river play — and let the drills find your edges.` (lesson `threebet-pots`). Buttons `Take me there` (opens that lesson) and `Start playing`.

The onboarding tour slide about drills (verbatim, title `Drill like chess puzzles`): `Short spots with instant feedback: the answer, why, how much a mistake costs in big blinds, and the exact set of hands (the range) you were graded against. Anything you miss — and anything the coach flags in play — comes back on a spaced schedule until you've beaten it three times.`

---

## 11. Study-lesson mini-drills (`src/components/study/Drills.tsx`)

Three self-contained widgets embedded in Study lessons (`practice` level): `drill-potodds` "Pot-Odds Drill" (5 min), `drill-outs` "Outs → Equity Drill" (5 min), `drill-range` "Range-Building Drill" (6 min). They keep **no persistent state** — score resets whenever the widget is recreated — and do **not** touch the drill store, rating, goals or queues.

Lesson lead-ins (verbatim): `Random spots — compute the break-even equity in your head, then check yourself.` / `Practise the 2/4 rule on random draws until it's automatic.` / `Paint a position's opening range from memory, then score it against the standard.`

### 11.1 Shared shell

Bordered card (info tint). Header: target icon + title; right: mono `Score ${right}/${total}`. Body. Footer right-aligned action button.

`Options` = grid (2 cols, 4 on wide) of `${value}${suffix}` buttons (mono bold). After answering: the correct value → green tint; the picked wrong value → red tint; others unchanged; all disabled.

`Explain` = paragraph starting with bold `Correct. ` (green) or `Not quite. ` (amber) followed by the explanation.

Helpers: `randInt(a, b)` = uniform integer in `[a, b]` inclusive; `shuffle` = Fisher–Yates.

### 11.2 Pot-odds drill

```
makePotSpot():
  pot  = randInt(4, 40)
  bet  = max(1, jsRound(pot * [0.33, 0.5, 0.66, 1][randInt(0,3)] * 2) / 2)     // nearest half bb, ≥ 1
  correct = jsRound(bet / (pot + 2*bet) * 100)                                   // integer percent
  set = {correct}
  while set.size < 4: d = correct + [-15,-10,-7,7,10,15][randInt(0,5)]; if (d > 2 && d < 60) set.add(d)
  options = shuffle(set)
```
Prompt: `The pot is **${pot} bb** and your opponent bets **${bet} bb**. What equity do you need to call?` Options suffixed `%`. Footer button `New spot` (ghost until answered, primary after) → new spot, clear pick.
Score: `right += (picked == correct)`, `total += 1`.
Explanation: `Break-even = call ÷ final pot = ${bet} ÷ (${pot} + 2×${bet}) = ${fmtPct(bet / (pot + 2*bet))}.`
Pinned: pot 10, bet 5 → correct 25, text ends `5 ÷ (10 + 2×5) = 25%.`; pot 7 with fraction 0.66 → bet 4.5 → correct 28.

### 11.3 Outs → equity drill

`DRAWS` table (verbatim):

| name | outs |
|---|---|
| `a flush draw` | 9 |
| `an open-ended straight draw` | 8 |
| `a gutshot` | 4 |
| `two overcards` | 6 |
| `a flush draw + gutshot` | 12 |
| `a pocket pair hoping to flop/turn a set` | 2 |
| `a flush draw + open-ender` | 15 |

```
makeOutsSpot():
  d = DRAWS[randInt(0, 6)]
  onFlop = random() < 0.5; mult = onFlop ? 4 : 2
  correct = min(95, d.outs * mult)
  set = {correct}
  while set.size < 4: v = correct + [-16,-12,-8,8,12,16][randInt(0,5)]; if (v > 2 && v < 99) set.add(v)
  street = onFlop ? "flop (two cards to come)" : "turn (one card to come)"
```
Prompt: `On the **${street}** you have **${d.name}** (${d.outs} outs). Using the rule of thumb, roughly what's your equity?` Options suffixed `%`. Footer `New spot`.
Explanation: `Multiply outs by ${mult} (${mult == 4 ? "two cards to come" : "one card to come"}): ${outs} × ${mult} ≈ ${correct}%. The ×4 rule slightly over-counts big draws, so shade large numbers down a touch.`
Pinned: flush draw on flop → 36; 15 outs on flop → 60; pocket pair on turn → 4.

### 11.4 Range-building drill

Targets (label sets built from the 100 bb chart data by `chartToSet(chart, min = 0.5)` = labels whose frequency ≥ 0.5; data file `src/data/preflop.ts`, `PREFLOP_100.rfi[pos]` and `PREFLOP_100.vsRfi["BB_vs_BTN"].{call,threebet}` — a `Record<HandLabel, double 0..1>`; convert mechanically):

| desc (verbatim) | set |
|---|---|
| `UTG opening range (~15% of hands)` | `rfi.UTG` ≥ 0.5 |
| `CO opening range (~26% of hands)` | `rfi.CO` ≥ 0.5 |
| `BTN opening range (~45% of hands)` | `rfi.BTN` ≥ 0.5 |
| `BB continue range vs a BTN open (calls + 3-bets, ~40%)` | union of `vsRfi.BB_vs_BTN.call` ≥ 0.5 and `.threebet` ≥ 0.5 |

Score = combo-weighted F1 (pairs count 6 combos, suited 4, offsuit 12):
```
inter = Σ comboCount(l) for l in painted ∩ actual
precision = combos(painted) > 0 ? inter / combos(painted) : 0
recall    = combos(actual)  > 0 ? inter / combos(actual)  : 0
f1 = (precision + recall) > 0 ? 2·p·r / (p + r) : 0
pass = f1 >= 0.7
```
Prompt: `Paint the standard **${desc}**.` The user paints on an interactive 13×13 matrix (400 px; drag-paint, first cell decides add/remove). Footer `Check` (disabled while nothing is painted) → freezes the matrix in **compare** mode, adds `pass ? 1 : 0` to `right` and 1 to `total`; then the footer becomes `New drill` (random target, empty paint, unchecked).
Compare colouring: in both → green (`Correct`); in actual only → amber (`Missed`); in painted only → red (`Extra`); neither → dim. Legend switches from `Pairs / Suited / Offsuit` to `Correct / Missed / Extra`. Next to the legend: mono `${fmtPct(f1)} match`, green if `f1 >= 0.7` else amber.

---

## 12. Edge cases, invariants and known quirks (decide deliberately in the port)

1. **Review-mode last-card feedback vanishes.** `DrillsView` derives `dueCount` from the live queues. Answering the *only* due card reschedules it (10 min or ≥ 1 day) so `dueCount` becomes 0 and the view swaps to the "Nothing due right now" panel **immediately, hiding the feedback the user just earned**. Recommended port behaviour: keep showing the current puzzle + feedback until `next()` returns no puzzle, i.e. compute the empty state from the store's "no current puzzle" flag rather than from `dueCount` while a puzzle is answered. Keep the pill count live.
2. **Units of live-coach leak spots are chips** (`pot`, `toCall`, `options[].amount` in chips, `bb = bigBlind`), whereas generated puzzles and imported leaks use bb (`bb = 1`). The table pot (`fmtBb`) and the frame text divide by `bb` correctly, but `gradePuzzle.evLossBb` and the `Calling: … bb per try` line use raw `pot`/`toCall`, so for live-coach leaks they print chip amounts labelled "bb". Recommended: normalise at capture (divide pot/toCall/amount by bb, set `bb = 1`) and migrate existing spots on load when `bb != 1`.
3. `Puzzle.id` is an in-memory counter restarting at 1 each launch; review cards carry their old ids, so collisions are possible. It is only used to reset the range toggle on puzzle change — key that reset on object identity, not `id`.
4. `isDue(null) == true`: a leak spot with no `srs` is due. `DrillsView` duplicates this inline (`!sp.srs || sp.srs.due <= now`) — share one function.
5. `review(id, …)` with an unknown id is a silent no-op (still re-saves).
6. Review mode never touches `rating`, `solved`, `correct`, `streak`, `best`, but **does** count toward the daily goal, and a wrong Review answer never adds a review card (only practice misses do). A wrong practice answer to a puzzle that already has a review card keeps the existing card's schedule.
7. In practice modes `puzzle.kind` is never `leak`, so the `kind != leak` guard in `answer()`/`drillSimilar()`/the "Drill 5 similar" button only matters if a leak puzzle were ever shown outside Review mode. Keep the guards.
8. Rating floor is 100; there is no ceiling. `solved`/`correct` grow unbounded.
9. `setMode` does not reset focus (§6.9); `next()` decrements `focusLeft` in every mode.
10. Persisted-format validation is minimal: `allin.drills.v1` is accepted if `rating` is a number (other fields may be missing → treat as 0). Leak/review arrays are trusted as-is.
11. `Math.round` semantics: JS rounds .5 toward +∞ (`Math.round(-2.5) == -2`), Dart's `round()` rounds half away from zero. Use `jsRound(x) = (x + 0.5).floorToDouble()` for every rounding in this doc. Also normalise `-0.0` before `toStringAsFixed` (§8.7).
12. Randomness: `(Math.random() * total) | 0` is floor for non-negative values; use `Random.nextInt(total)` in Dart (uniform, same distribution). Rejection-sampling loops (25 / 60 iterations) must keep their exact iteration caps so distribution and worst-case cost match.
13. Both queues are prepended (newest first) and truncated at the tail; `dueSpots` preserves that order, which only matters for the uniform pick index.
14. The first puzzle after launch is `generatePuzzle()` without rating adaptation; the first `next()` is adaptive.
15. Streak (`streak`) counts consecutive correct practice answers across sessions (persisted) and resets on any wrong practice answer; Review answers don't affect it.

---

## 13. Persistence summary

| Key | Shape | Cap | Written by | Cleared by |
|---|---|---|---|---|
| `allin.drills.v1` | `{rating,solved,correct,streak,best}` | — | `answer()` (practice), `seedRating()` | nothing |
| `allin.leaks.v1` | `LeakSpot[]` newest first, each with `srs` | 60 | coach mistakes, HH import, `review()` | nothing (cap/graduation only) |
| `allin.review.v1` | `ReviewCard[]` `{id, puzzle, srs}` newest first | 80 | practice misses, `review()` | nothing |
| `allin.goals.v1` | `{ "YYYY-MM-DD": {drills, hands} }` | — | `record()` | nothing |
| `allin.onboarded.v1` | `"1"` | — | onboarding close | nothing |
| decisions (SQLite `decisions` table / local fallback) | `DecisionRecord` rows | 800 in memory | coach | Stats "Erase everything" |

Mobile mapping: shared_preferences/Hive/Isar are all fine; keep the JSON shapes so a desktop export can be imported.

---

## 14. Dart reference implementation sketch (core logic only)

```dart
double jsRound(num x) => (x + 0.5).floorToDouble();

// ---- SRS ----
class SrsState {
  final int due, intervalDays, reps, lapses; final double ease;
  const SrsState({required this.due, required this.intervalDays, required this.ease, required this.reps, required this.lapses});
  Map<String, dynamic> toJson() => {'due': due, 'intervalDays': intervalDays, 'ease': ease, 'reps': reps, 'lapses': lapses};
  factory SrsState.fromJson(Map<String, dynamic> j) => SrsState(
    due: (j['due'] as num).toInt(), intervalDays: (j['intervalDays'] as num).toInt(),
    ease: (j['ease'] as num).toDouble(), reps: (j['reps'] as num).toInt(), lapses: (j['lapses'] as num).toInt());
}
const retireReps = 3;
SrsState newSrs(int now) => SrsState(due: now, intervalDays: 0, ease: 2.3, reps: 0, lapses: 0);
SrsState reviewSrs(SrsState s, bool correct, int now) {
  if (!correct) return SrsState(due: now + 600000, intervalDays: 0, ease: math.max(1.3, s.ease - 0.2), reps: 0, lapses: s.lapses + 1);
  final d = s.reps == 0 ? 1 : s.reps == 1 ? 3 : math.max(4, jsRound(s.intervalDays * s.ease).toInt());
  return SrsState(due: now + d * 86400000, intervalDays: d, ease: math.min(3.0, s.ease + 0.05), reps: s.reps + 1, lapses: s.lapses);
}
bool isDue(SrsState? s, int now) => s == null || s.due <= now;
bool isGraduated(SrsState s) => s.reps >= retireReps;

// ---- Elo step (practice modes) ----
({int rating, int delta}) eloStep(int rating, int difficulty, bool correct) {
  final puzzleRating = 800 + difficulty * 200;
  final expected = 1 / (1 + math.pow(10, (puzzleRating - rating) / 400));
  final delta = jsRound(24 * ((correct ? 1 : 0) - expected)).toInt();
  return (rating: math.max(100, jsRound(rating + delta).toInt()), delta: delta);
}

// ---- Adaptive target ----
int adaptiveTarget(int rating, math.Random rng) {
  if (rating < 1050) return rng.nextDouble() < 0.7 ? 1 : 2;
  if (rating < 1250) return rng.nextDouble() < 0.55 ? 2 : (rng.nextDouble() < 0.5 ? 1 : 3);
  return rng.nextDouble() < 0.6 ? 3 : 2;
}

// ---- Leak rules ----
const leakFold  = "You fold too often when you're getting the right price — look for more +EV calls.";
const leakCall  = "You call too wide for the pot odds — fold your weakest hands more.";
const leakClean = "No clear −EV mistakes flagged — solid discipline. Keep refining the thin spots.";

// ---- Range drill F1 ----
int comboCount(String l) => l.length == 2 ? 6 : l.endsWith('s') ? 4 : 12;
double rangeF1(Set<String> painted, Set<String> actual) {
  var inter = 0; for (final l in painted) { if (actual.contains(l)) inter += comboCount(l); }
  final pc = painted.fold(0, (a, l) => a + comboCount(l)), ac = actual.fold(0, (a, l) => a + comboCount(l));
  final p = pc > 0 ? inter / pc : 0.0, r = ac > 0 ? inter / ac : 0.0;
  return p + r > 0 ? 2 * p * r / (p + r) : 0.0;
}
```

---

## 15. Complete list of user-facing strings owned by this subsystem

(For the localisation table; all verbatim, `${}` = interpolation.)

- Tab/heading: `Drills`
- Mode labels: `Mixed`, `Push / Fold`, `Exploits`, `Review`, `Review (${n} due)`
- Mode blurbs: see §6.1 (4 strings)
- Stat captions: `Rating`, `Accuracy`, `Streak`, `Best`, `Today`, `Day streak`; value `${min(today,20)}/20`, `${acc}%`
- Tooltips: Rating and Today (§8.1)
- Empty Review: `Nothing due right now`, `No spots to review yet`, and the two body texts (§8.2)
- Navigator: `Hand replay`; a11y `First`, `Previous`, `Next`, `Decision`
- Controls: `Your hand: `; source pills (§8.5, 6 strings); `Correct`; `Not optimal`; `That choice costs about ${x} bb every time — ${a small leak|a real leak|a blunder-sized leak}.`; `Folding: 0 bb — costs nothing more.`; `Calling: ${ev} bb per try — your hand wins ${times} and you need ${need}.`; `Equity: ${pct}`; `Pot odds: ${pct}`; `See the range it was graded against`; `Hide the range`; `Read the lesson`; `Drill 5 similar`; `${n} more of this spot type coming up`; `Next puzzle`
- Table: `You`, `Folded`, `In hand`; street captions `Pre-flop`/`Flop`/`Turn`/`River`/`Showdown`; `${bb} bb`
- Leak puzzle frames: `Pre-flop.`, `${Street}: ${cards}`, `Action on you in the ${pos} facing ${x} bb. What's the play?` / `Action on you in the ${pos}. What's the play?`
- Leak option labels (coach): `Fold`, `Call ${x} bb`, `Raise`, `Check`, `Bet`; (import): `Fold`, `Call ${x} bb`
- Import rationale and import summary message (§3.3)
- Leak report sentences (§5) + Stats extra sentence (§5.1) + Stats empty text and box labels (§5.2)
- Shortcut overlay: `1 / 2 / 3` — `Choose an answer`; `Enter` — `Next puzzle`
- Study drills: titles `Pot-odds drill`, `Outs → equity drill`, `Range-building drill`; `Score ${r}/${t}`; `New spot`; `New drill`; `Check`; `Correct. `; `Not quite. `; prompts and explanations (§11); `${pct} match`; legend `Correct`/`Missed`/`Extra`, `Pairs`/`Suited`/`Offsuit`; DRAWS names; target descs
- Onboarding placement (§10)

---

## 16. Verification checklist for the port

- [ ] `srs_test` 13 assertions (§2.5) and the pinned ladder table (§2.4) including the exact float values of `ease`.
- [ ] `leaks_test` 6 assertions (§5.3) plus the four boundary pins.
- [ ] Elo table (§6.6) for the 15 (rating, difficulty) pairs, both outcomes; rating floor at 100.
- [ ] Adaptive target distribution (§6.5) with a seeded RNG over ≥ 10 000 draws within ±1 %.
- [ ] Review pick is uniform over the union of due leaks and due cards; empty union → no puzzle and the empty-state texts.
- [ ] Practice miss → review card with the exact key format; duplicate miss keeps the old schedule; cap 80 / 60 truncation from the tail.
- [ ] Graduation: 3 spaced successes delete the card; success-after-miss does not.
- [ ] Format helpers pins (§8.7).
- [ ] Study drills: generator ranges, option-set construction (4 distinct, bounds), F1 threshold 0.7, texts.
- [ ] Persisted JSON shapes round-trip with data exported from the desktop app (including spots lacking `srs`).

---

## 17. Corrections to earlier sections (normative)

Three defects found when this document was re-checked line-by-line against the source repo on 2026-09-07. Where §1, §5.3 or the source-file inventory table at the top disagree with anything below, **this section wins**. Nothing here requires opening the TypeScript; the exact source evidence is reproduced inline.

### 17.1 `Puzzle.frames` — the invariant is `length >= 2`, not `>= 1` (corrects §1)

§1 declares:

```dart
List<DrillFrame> frames;      // >= 1; LAST frame is the decision point
```

The `>= 1` is wrong and must be read as **`>= 2`**. The sibling port doc `drills-charts-icm.md` has it right in its §1 (`// >= 2; last frame is the decision point`) and in its invariant list (`frames.length >= 2`). Use:

```dart
List<DrillFrame> frames;      // >= 2 (see 17.1); LAST frame is the decision point
```

Why it matters: the pinned test suite `scripts/puzzles_test.ts` rejects a 1-frame puzzle. It asserts, inside a 800-iteration loop over `generatePuzzle()`:

```ts
ok(p.frames.length >= 2, "has navigator frames");
```

and again for the leak replay built by `puzzleFromLeak(spot)`:

```ts
ok(lp.frames.length >= 2, "leak has frames");
```

A Dart port that trusted `>= 1` could ship a single-frame puzzle that passes its own tests and fails the ported `puzzles_test`. It would also break §8.4 (`MoveNavigator`), whose "First / Previous / Next / Decision" controls and highlighted-last-row list assume at least one non-decision frame ahead of the decision point.

**No generator in the source can emit fewer than 2 frames.** Exhaustive frame counts (`SB = 0.5`, `BBV = 1`, `ORDER = [UTG, MP, CO, BTN, SB, BB]`):

| Generator (kind) | Frame count | Why |
|---|---|---|
| `genRfi` (`rfi`) | **2 … 6** | `1 (blinds) + |foldedBefore| + 1 (action)`. `heroIdx = rint(0,4)` → UTG…SB; `foldedBefore = ORDER.slice(0, heroIdx)` minus SB/BB → 0,1,2,3,4 for UTG,MP,CO,BTN,SB. **Hero = UTG gives exactly 2 — the global minimum.** |
| `genVsRaise` (`vs-raise`) | 4 … 7 | `3 + |ORDER.slice(0, heroIdx) \ {raiserPos, SB, BB}|`. `heroIdx = rint(2,5)` → CO,BTN,SB,BB; `raiserIdx = rint(0, heroIdx-1)`. CO→4, BTN→5, SB→6, BB→6 (7 when the raiser is the SB). |
| `genPostflopBet` (`postflop-bet`) | exactly 4 | fixed array |
| `genPostflopCheck` (`postflop-check`) | exactly 3 | fixed array |
| `genThreeBetPot` (`threebet-pot`) | exactly 3 | fixed array |
| `genFacingCheckRaise` (`check-raise`) | exactly 3 | fixed array |
| `genRiverDecision` (`river-decision`) | exactly 3 | fixed array |
| `generateExploit` template 0 (Station river, `exploit`) | exactly 3 | fixed array |
| `generateExploit` template 1 (Nit turn raise, `exploit`) | exactly 3 | fixed array |
| `generateExploit` template 2 (Nit blind steal, `exploit`) | **exactly 2** | fixed array |
| `generatePushFold` open-shove (`pushfold`) | 3 … 6 | `1 + |foldedBefore| + 1`; `heroPos ∈ {MP, CO, BTN, SB}` → 1,2,3,4 folds |
| `generatePushFold` BB-call (`pushfold`) | exactly 3 | fixed array |
| `generateIcmPushFold` SB-shove / BB-call (`pushfold`) | exactly 3 each | fixed array |
| `puzzleFromLeak` (`leak`) | **exactly 2** | fixed array — see §3.4 |

So `frames.length ∈ [2, 7]` across the whole engine, and the three generators that hit the floor of 2 are: `genRfi` with hero UTG, `generateExploit` template 2, and `puzzleFromLeak`.

The two verbatim frames of the minimal `genRfi` case (hero UTG, `pot = SB + BBV = 1.5` on both frames, `street "preflop"`, `board []`):

```
frame[0].text = "Blinds posted (0.5/1 bb)."
frame[1].text = "Folded to you in the UTG. Action on you."     // `Folded to you in the ${heroPos}. Action on you.`
```

The intermediate fold frames, when hero is not UTG, are `` `${p} folds.` `` — e.g. `UTG folds.` — one per earlier non-blind seat, in `ORDER` sequence, all carrying the same `pot: 1.5`.

The two verbatim frames of `generateExploit` template 2 (hero SB, `pot = 1.5` on both, `street "preflop"`, `board []`):

```
frame[0].text = "The BB is a NIT — they defend their blind with only ~12% of hands and fold the rest."
frame[1].text = "Folded to you in the SB with ${label}. Action on you."   // ${label} = hero's HandLabel, e.g. "AJo"
```

(Note the U+2014 em dash in `frame[0]`.)

Structural rule that follows and is worth asserting in the port: **the last frame is always the "action is on you" prompt**, it always carries the puzzle's decision-point `street`, `board` and `pot`, and every earlier frame is narrative history. `navIndex` therefore initialises to `frames.length - 1` (§6.3, §6.6, §6.7) and that index is always `>= 1`.

Dart guard to put in the `Puzzle` constructor / factory:

```dart
assert(frames.length >= 2, 'Puzzle.frames must have >= 2 entries: history + decision point');
assert(frames.last.street == street, 'last frame is the decision point');
```

Add to the §16 checklist:

- [ ] Every generator emits `frames.length >= 2` (pin the 2-frame floor for `rfi` hero-UTG, `exploit` template 2, and `puzzleFromLeak`); a 1-frame puzzle is rejected.

### 17.2 `scripts/leaks_test.ts` — the exact six assertions (replaces the numbered list in §5.3)

The list in §5.3 does not map 1:1 onto the file's six `ok()` calls: its item 2 silently bundles two separate assertions (the count check and the "fold too often" check), and its item 6 is a placeholder ("implicit in 1") rather than a real assertion. Porting "the six assertions" from that list produces the wrong six. The authoritative list is below — six `ok()` calls, in source order, with the failure message each one prints.

The helper is unchanged from §5.3 and is reproduced verbatim (note there is **no** `position` field on these records):

```ts
const d = (verdict: DecisionRecord["verdict"], action: DecisionRecord["action"]): DecisionRecord => ({
  verdict,
  action,
  equity: 0.3,
  potOdds: 0.25,
  evBb: -1,
  street: "flop",
  villainArchetype: "TAG",
  ts: 0,
});
```

Four fixtures are built:

```ts
const empty  = leaksFromDecisions([]);
const folds  = leaksFromDecisions([ ...4× d("mistake","fold"), ...6× d("ok","call")   ]);   // n = 10
const calls  = leaksFromDecisions([ ...4× d("mistake","call"), ...6× d("ok","check")  ]);   // n = 10
const clean  = leaksFromDecisions([ ...6× d("ok","call"),      ...4× d("great","bet") ]);   // n = 10
const withInfo = leaksFromDecisions([ d("info","check"), d("info","check"), d("ok","call") ]);
```

(The `...4×` is shorthand for the source's `...Array(4).fill(0).map(() => d(...))`; the mistake records come **first** in each array, the non-mistakes after.)

The six assertions:

| # | Fixture | Condition (exact) | Failure message |
|---|---|---|---|
| 1 | `empty` | `empty.total === 0 && empty.leaks.length === 0` | `empty → no leaks` |
| 2 | `folds` | `folds.total === 10 && folds.foldMistakes === 4` | `fold counts` |
| 3 | `folds` | `folds.leaks.some((l) => l.toLowerCase().includes("fold too often"))` | `fold-too-often leak` |
| 4 | `calls` | `calls.callMistakes === 4 && calls.leaks.some((l) => l.toLowerCase().includes("call too wide"))` | `call-too-wide leak` |
| 5 | `clean` | `clean.mistakes === 0 && clean.great === 4 && clean.leaks.some((l) => l.includes("No clear"))` | `clean discipline note` |
| 6 | `withInfo` | `withInfo.total === 1` | `info verdicts excluded from total` |

Points a port must not lose:

- **Assertions 2 and 3 are separate.** They share the `folds` fixture but are two independent `ok()` calls; a Dart port that merges them into one `expect` drops an assertion and the count becomes 5.
- **Case handling differs between 3/4 and 5.** Assertions 3 and 4 lower-case the leak sentence before the substring test (`l.toLowerCase().includes(...)`); assertion 5 does **not** — it matches the substring `"No clear"` with its original capital `N` against the raw sentence. Do not "tidy" assertion 5 into a case-insensitive match, and do not lower-case the needle in 3/4 into the raw string.
- **Assertion 4 is a compound of the count and the sentence**, unlike the fold case which splits them. Keep the asymmetry so the assertion count stays 6.
- **Assertion 1 covers both `total` and `leaks.length`.** There is no separate "empty input has no leaks" assertion; §5.3's item 6 was a duplicate of item 1 and does not exist in the file.
- **Assertion 6 pins the `info` exclusion.** Two `info` records plus one `ok` gives `total == 1`; because `n = 1 < 8` the report's `leaks` is also empty, but the file does not assert that.
- The harness counts `passed`/`failed`, prints `` `\nLeak tests: ${passed} passed, ${failed} failed.` `` and exits `failed === 0 ? 0 : 1`. All six pass on the current source.

The four extra boundary pins recommended at the end of §5.3 (n < 8; count < 3; ratio exactly 0.12 not firing; 0.125 firing) remain worth adding in Dart — they are *additional* to these six, not part of them. The §16 checklist item "`leaks_test` 6 assertions (§5.3) plus the four boundary pins" is therefore correct in its arithmetic; only §5.3's enumeration was wrong. Read that checklist item as "§17.2".

### 17.3 Source-file inventory — corrected line counts

Two rows of the table at the top of this document are stale. Metadata only, no behavioural consequence, but they indicate the table was not refreshed after the last source edit; the corrected values are:

| File | Listed | **Actual** |
|---|---|---|
| `src/store/reviewStore.ts` | 74 | **71** |
| `src/store/goalStore.ts` | 76 | **75** |

Every other row verifies against the source as written: `src/lib/srs.ts` 50, `src/lib/leaks.ts` 57, `src/store/leakStore.ts` 59, `src/store/drillStore.ts` 234, `src/views/DrillsView.tsx` 134, `src/components/drills/DrillTable.tsx` 72, `src/components/drills/MoveNavigator.tsx` 64, `src/components/drills/DrillControls.tsx` 198, `src/components/study/Drills.tsx` 315, `scripts/srs_test.ts` 51, `scripts/leaks_test.ts` 56.

The behavioural specs for `reviewStore.ts` (§4) and `goalStore.ts` (§7) were re-checked against the current sources and are accurate — in particular `reviewStore.review` maps first and filters second, so the `isGraduated` test in the filter sees the **new** `SrsState`, which is what §4.2 describes.
