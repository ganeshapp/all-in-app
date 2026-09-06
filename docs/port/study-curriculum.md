# Study curriculum — port specification

Source subsystem of "All-In · Poker Dojo" (desktop/web, React + TypeScript + Zustand).
This document is the complete, self-contained specification of the **Study tab**: the
5-level / 31-lesson curriculum, its inline interactive widgets (calculators, trainers,
range explorer, equity calculator), the optional quizzes, the glossary, the cheat sheet,
and the progress-tracking model. A Flutter/Dart engineer should be able to re-implement
the whole subsystem from this file without opening the TypeScript.

Source files (all relative to `/Users/gapp/Documents/Code/poker`):

| File | Lines | Role |
|---|---|---|
| `src/components/study/lessons.tsx` | 1240 | The curriculum: `LEVELS`, `ALL_LESSON_IDS`, every lesson body, every quiz |
| `src/components/study/Quiz.tsx` | 143 | Optional practice quiz widget |
| `src/components/study/Term.tsx` | 55 | `GLOSSARY` (single source of truth) + hover `Term` |
| `src/components/study/HandRankings.tsx` | 41 | Static 10-row hand-ranking table |
| `src/components/study/PotOddsCalculator.tsx` | 95 | Pot odds / break-even / EV sliders |
| `src/components/study/BluffCalculator.tsx` | 54 | Bluff break-even fold % / caller's price |
| `src/components/study/MultiwayEquityTrainer.tsx` | 132 | Equity vs 1–5 opponents bar chart |
| `src/components/study/RangeExplorer.tsx` | 51 | Paintable 13×13 matrix with presets and combo count |
| `src/components/study/EquityCalculator.tsx` | 256 | Free-form range-vs-range / exact-hand-vs-range calculator with blockers |
| `src/components/study/RangeBoardBreakdown.tsx` | 122 | "How does this range hit this board" (Flopzilla-style) + draw flags |
| `src/store/studyStore.ts` | 87 | Progress + quiz-result persistence |
| `src/views/StudyView.tsx` | 135 | Two-pane Study screen: path nav + lesson body |

Related but **out of scope here** (documented by other port docs): the three drills embedded
in the Practice level (`PotOddsDrill`, `OutsDrill`, `RangeBuildDrill` from
`src/components/study/Drills.tsx`), the poker engine (`evaluateInts`, the equity
Monte-Carlo functions, `topPercentRange`), the 13×13 `RangeMatrix` widget, the pre-flop
chart data file, and the bot archetypes. Where a lesson depends on those, this document
states the exact contract and the exact values the lesson displays so the port does not
need them to be finished first.

Tone: all user-facing strings below follow `TONE.md` (plain English first, "your opponent"
not "villain", "you" not "hero", jargon defined in the same breath or hover-glossed). Quote
them **verbatim** in the port; do not paraphrase.

---

## 1. Data model

```dart
class Lesson {
  final String id;        // stable, referenced by deep links from other tabs
  final String title;
  final int minutes;      // shown as "{minutes}m" in nav and "{minutes} min read" in header
  final Widget Function() body;
}

class Level {
  final String id;
  final String title;
  final IconName icon;    // "book" | "cards" | "target" | "bolt"
  final String blurb;     // currently NOT rendered anywhere in StudyView (kept for parity)
  final List<Lesson> lessons;
}

const List<Level> LEVELS = [...];                     // 5 levels, in order
final List<String> ALL_LESSON_IDS = LEVELS.expand((l) => l.lessons.map((x) => x.id)).toList();
```

`ALL_LESSON_IDS` is the flat ordering used for "Next lesson", the progress fraction, and
deep-link validation. Its length is **31**.

### 1.1 The curriculum table

| # | Level (id / title / icon / blurb) | Lesson id | Title | min |
|---|---|---|---|---|
| 1 | `basics` / Basics / `book` / "Rules, rankings, position and bankroll." | `hand-rankings` | Hand Rankings | 4 |
| 2 | | `position` | Position & the Button | 5 |
| 3 | | `bankroll` | Bankroll & Mindset | 4 |
| 4 | `preflop` / Pre-flop / `cards` / "The 13×13 matrix and opening ranges." | `matrix` | The 13×13 Matrix | 5 |
| 5 | | `opening-ranges` | Opening Ranges by Position | 6 |
| 6 | | `three-betting` | 3-Betting | 5 |
| 7 | | `hud-reading` | Reading the HUD: VPIP & PFR | 5 |
| 8 | `postflop` / Post-flop / `target` / "Board texture, pot odds and c-betting." | `board-texture` | Reading Board Texture | 5 |
| 9 | | `counting-outs` | Counting Outs & the 2/4 Rule | 5 |
| 10 | | `estimating-equity` | Estimating Equity | 5 |
| 11 | | `pot-odds` | Pot Odds, Break-even & EV | 6 |
| 12 | | `implied-odds` | Implied & Reverse-Implied Odds | 5 |
| 13 | | `bet-sizing` | Bet Sizing | 6 |
| 14 | | `cbetting` | Continuation Betting | 4 |
| 15 | | `mdf` | Minimum Defense Frequency | 5 |
| 16 | | `check-raising` | Check-Raising | 5 |
| 17 | `advanced` / Advanced / `bolt` / "Combinatorics, blockers and exploits." | `combinatorics` | Combinatorics & Blockers | 6 |
| 18 | | `hand-reading` | Hand Reading: Narrowing a Range | 7 |
| 19 | | `exploits` | Exploiting the Archetypes | 6 |
| 20 | | `multiway` | Playing Multiway | 6 |
| 21 | | `spr` | SPR & Commitment | 5 |
| 22 | | `threebet-pots` | Playing 3-Bet Pots | 6 |
| 23 | | `equity-realization` | Equity Realization | 5 |
| 24 | | `turn-river` | Turn & River Play | 6 |
| 25 | | `synthesis` | Putting It Together | 3 |
| 26 | `practice` / Practice / `target` / "Hands-on drills and a range explorer." | `cheat-sheet` | Quick Reference | 4 |
| 27 | | `range-explorer` | Range Explorer | 5 |
| 28 | | `equity-calculator` | Equity Calculator | 5 |
| 29 | | `drill-potodds` | Pot-Odds Drill | 5 |
| 30 | | `drill-outs` | Outs → Equity Drill | 5 |
| 31 | | `drill-range` | Range-Building Drill | 6 |

Total minutes: 161. Level lesson counts: 3 / 4 / 9 / 9 / 6.

### 1.2 Lesson ids are a public contract

Other subsystems deep-link into Study by lesson id. **Do not rename these ids.** Known
external references:

- Onboarding placement result → `hand-rankings` (score ≤ 2), `pot-odds` (score ≤ 5), `threebet-pots` (otherwise).
- Drill puzzles carry an optional `lessonId` (`opening-ranges`, `three-betting`, `pot-odds`, `bet-sizing`, `check-raising`, `turn-river`, `exploits`, `spr`, `threebet-pots`) and the drill feedback panel offers a "go to lesson" button.
- Lesson prose itself cross-references "Practice → Quick Reference" (the `cheat-sheet` lesson) and the Play / Stats tabs.

---

## 2. StudyView — screen behaviour

Two-pane layout: a 310 px-wide scrollable **path nav** on the left and the **lesson body**
on the right (max content width 760 px, padding 32 px horizontal / 28 px vertical).
On mobile this becomes a drawer / list-then-detail; the behaviours below are what matter.

### 2.1 State

- `activeId: String` — initial value `LEVELS[0].lessons[0].id` (= `hand-rankings`).
- Reads `completed: List<String>` and `complete(id)` from the study store.
- Reads the navigation store's one-shot `lessonId` request. On mount / whenever it changes:
  `if (requestedLesson != null && ALL_LESSON_IDS.contains(requestedLesson)) { activeId = requestedLesson; nav.consumeLesson(); }`
  (unknown ids are ignored and left unconsumed — harmless).
- Derived: `lesson`/`level` found by scanning `LEVELS` for `activeId`; fall back to the first lesson of the first level if not found.
- `idx = ALL_LESSON_IDS.indexOf(activeId)`, `nextId = ALL_LESSON_IDS[idx + 1]` (null past the end).
- `done = completed.contains(activeId)`.
- `pct = completed.length / ALL_LESSON_IDS.length * 100`.

### 2.2 Path nav (left)

1. Header row: label **"Your progress"** and, right-aligned monospace, `"{completed.length}/{ALL_LESSON_IDS.length}"` (e.g. `7/31`). Beneath: a `ProgressBar(value: pct)` (0–100, gold fill, 2 px tall track, clamps to [0,100], 500 ms width animation).
2. For each level `lv` at index `li`:
   - Row with the level icon in a 28×28 gold-tinted rounded square, then bold text `"L{li+1} {lv.title}"` where the `L{n}` prefix is rendered in the faint colour (e.g. **L1 Basics**), and right-aligned faint monospace `"{lvDone}/{lv.lessons.length}"` where `lvDone` is the number of that level's lessons in `completed`.
   - Under it (indented, with a 1 px left border line) one button per lesson:
     - a 16 px circle: if done → filled "good" green with a white check icon; else an empty circle with a strong outline.
     - the lesson title (single line, truncated with ellipsis),
     - right-aligned faint monospace `"{minutes}m"`.
     - Active lesson row is highlighted (gold 15 % background, full text colour); others are muted with a subtle hover.
     - Tap → `activeId = lesson.id` (no completion side effect).

### 2.3 Lesson body (right)

- Eyebrow: level title in uppercase, letter-spaced, gold at 80 % (e.g. `POST-FLOP`).
- H1: lesson title (display font, extra bold, ~30 px).
- Sub-line: `"{minutes} min read"` (faint).
- Then the lesson body blocks stacked with 16 px vertical gaps (`space-y-4`).
- The body is re-mounted from scratch whenever `activeId` changes (React `key={activeId}`) — all widget state (slider values, painted ranges, quiz picks) resets when you switch lessons. Preserve that: state is per-visit, not persisted (except quiz *results*, see §4).
- Footer (top border, margin-top 32 px, padding-top 20 px), a row with:
  - Left: a button. If not done: primary (gold) button labelled **"Mark complete"** → `complete(activeId)`. If done: secondary button showing a check icon + **"Completed"**, disabled.
  - Right (only if `nextId != null`): outline button **"Next lesson"** followed by an arrow-right icon → `activeId = nextId`. Navigation only — it does **not** mark anything complete. (Comment in source: "completion is an explicit choice, so clicking through 26 lessons no longer 'finishes' them.")
- Scroll position: the main pane scrolls independently and resets to top on lesson change (because it re-mounts).

---

## 3. Progress store (`studyStore`)

Persistent, app-global singleton. Two independent persisted records.

```dart
class QuizStat {
  int correct;       // cumulative correct answers for this question
  int wrong;         // cumulative wrong answers
  bool lastCorrect;  // outcome of the most recent answer
  int ts;            // Unix epoch milliseconds of the most recent answer
}

class StudyState {
  List<String> completed;                 // ordered list of completed lesson ids (insertion order)
  Map<String, QuizStat> quizResults;      // keyed by String(hashSeed(question.q)) — see §4.3
  void complete(String id);               // idempotent add; no-op if already present
  void toggle(String id);                 // remove if present else append (exists in store; NOT used by any UI today)
  void recordQuiz(String qKey, bool correct);
}
```

Persistence (web: `localStorage`; Dart: shared_preferences or equivalent):

| Key | Value | Load fallback |
|---|---|---|
| `allin.study.v1` | JSON array of lesson-id strings, e.g. `["hand-rankings","position"]` | `[]` on missing/parse error |
| `allin.quiz.v1` | JSON object `{ "<qKey>": {"correct":n,"wrong":n,"lastCorrect":bool,"ts":ms} }` | `{}` on missing/parse error |

Semantics:

- `complete(id)`: `if (completed.contains(id)) return; completed = [...completed, id]; save();`
- `toggle(id)`: `completed = completed.contains(id) ? completed.where((x) => x != id) : [...completed, id]; save();`
- `recordQuiz(qKey, correct)`:
  ```
  prev = quizResults[qKey] ?? QuizStat(correct: 0, wrong: 0, lastCorrect: false, ts: 0)
  quizResults[qKey] = QuizStat(
      correct: prev.correct + (correct ? 1 : 0),
      wrong:   prev.wrong   + (correct ? 0 : 1),
      lastCorrect: correct,
      ts: nowMs())
  saveQuiz()
  ```
- Save errors are swallowed silently.
- No entries are ever deleted from `completed` by the UI (there is no "un-complete" affordance); `toggle` exists for future use only.
- Completed ids that no longer exist in `ALL_LESSON_IDS` are harmless: they inflate `completed.length` in the `n/31` counter. (Port may filter on load; the original does not.)

---

## 4. Quiz widget

`Quiz({ required List<QuizQuestion> questions, String title = "Practice" })`

```dart
class QuizQuestion {
  final String q;             // question text
  final List<String> options; // 2–3 options in the curriculum (supports up to 5, letters A–E)
  final int answer;           // index into options of the correct one
  final String explain;       // shown after answering, right or wrong
}
```

Every quiz in the curriculum uses the default title "Practice". Quizzes are **optional** and
**never gate** lesson completion.

### 4.1 Layout and text (verbatim)

- Container: rounded 16 px card, info-blue 25 % border, info 6 % background, 16 px padding.
- Header row: target icon (16 px) + **"Practice"** (title) + a pill in uppercase tiny text: **"optional"**.
- Sub-line (faint, small): **"Test yourself — this doesn't affect lesson completion."**
  If `missedBefore > 0` append, in the warn colour: **"You missed {missedBefore} of these before — they're up first."**
  where `missedBefore` = count of questions whose stored result exists and has `lastCorrect == false`.
- Then each question, in display order, separated by 16 px:
  - `"{displayIdx + 1}. {q}"` in medium weight.
  - A vertical list of option buttons (6 px gap). Each button: a 20×20 rounded square badge on the left showing the letter `A`,`B`,`C`… (by **display** position, i.e. after shuffling), then the option text.
  - After answering (buttons disabled):
    - The correct option gets the "good" style (green border + 15 % green background), and its badge becomes a bold check icon.
    - If the picked option is wrong it gets the "bad" style (red border + 15 % red bg) and its badge becomes a bold X icon.
    - Other options keep the neutral style.
    - A feedback line under the options: a bold prefix **"Correct. "** (green) or **"Not quite. "** (warn/amber) followed by `explain`.
    - If wrong, a gold text button **"Try again"** is appended (margin-left 8 px).

### 4.2 Ordering and shuffling

- `keys[i] = String(hashSeed(questions[i].q))` — the persistence key per question (§4.3).
- **Question order** (computed once on mount):
  ```
  idx = [0..n-1]
  missed = idx.where((i) => results[keys[i]] != null && !results[keys[i]].lastCorrect)
  rest   = idx.where((i) => !missed.contains(i))
  order  = [...shuffled(missed), ...shuffled(rest)]
  ```
  Previously-missed questions come first; within each group order is random.
- **Option permutation** per question, computed once on mount: `perms[i] = shuffled([0..options.length-1])`. Displayed options are `perm.map((optIdx) => options[optIdx])`. Letter badges follow display position.
- `shuffled` is an unseeded Fisher–Yates (`Math.random`); no determinism required.
- Picking option at display position `oi` for question `qi`: `picked[qi] = oi; recordQuiz(keys[qi], perm[oi] == answer)`.
- `selCorrect = perm[picked[qi]] == answer`.
- **Try again**: deletes `picked[qi]` (re-enabling the buttons) and re-shuffles **only that question's** option permutation. The failed attempt has already been recorded as `wrong`; the retry will record another result (so a question can accumulate several `wrong` and then a `correct`, after which `lastCorrect == true` and it stops surfacing first).
- Question order does **not** re-sort while the widget is mounted (the `order` memo depends only on `questions`).

### 4.3 `hashSeed` — FNV-1a 32-bit over UTF-16 code units

```dart
int hashSeed(String s) {
  int h = 0x811c9dc5;
  for (final cu in s.codeUnits) {          // UTF-16 code units, like JS charCodeAt
    h ^= cu;
    h = (h * 0x01000193) & 0xFFFFFFFF;     // 32-bit wrapping multiply (JS Math.imul)
  }
  return h;                                // unsigned 32-bit
}
```

Key = decimal string of the result. Pin these values in Dart tests:

| Input | hashSeed |
|---|---|
| `""` | 2166136261 |
| `"a"` | 3826002220 |
| `"Which hand wins: a flush or a straight?"` | 617105294 |
| `"You hold A♦Q♣ on a board of A♠ K♦ 4♥ 9♣ 2♠. What's your hand?"` | 2008304561 |
| `"A player is 45/7. What kind of opponent is this?"` | 4116581697 |
| `"Can a player have a PFR higher than their VPIP?"` | 1094179878 |
| `"Bigger bets mean your MDF…"` | 163546800 |

The full list of all 34 question keys is in §14.3. Because keys derive from the question
text, **editing a question's wording orphans its stored stats** (they simply stop matching).
Persisted values need not survive a change of platform; the important property is stability
across app restarts on the same platform.

---

## 5. Glossary and hover terms

`GLOSSARY` is the single source of truth: it feeds both the hover definitions (`Term`) and
the glossary section of the Quick Reference lesson. Order matters (the cheat sheet lists
them in this order). Keys, display term and definition, verbatim:

| key | term | def |
|---|---|---|
| `UTG` | UTG | Under the Gun — the first seat to act pre-flop, just left of the big blind. The tightest position. |
| `MP` | MP | Middle Position — a seat between the early players and the cutoff. |
| `CO` | CO | Cutoff — the seat to the right of the button; a strong late position. |
| `BTN` | BTN | Button — the dealer seat. Acts last on every post-flop street; the best position. |
| `SB` | SB | Small Blind — posts the smaller forced bet and acts first after the flop. |
| `BB` | BB | Big Blind — posts the larger forced bet; last to act pre-flop. Also the unit we measure stacks and win-rate in. |
| `HUD` | HUD | Heads-Up Display — a small stats overlay on each opponent (here, their VPIP/PFR) that you read while playing. |
| `VPIP` | VPIP | Voluntarily Put $ In Pot — how often a player chooses to play a hand pre-flop (call or raise). |
| `PFR` | PFR | Pre-Flop Raise — how often a player raises pre-flop. Always ≤ VPIP. |
| `overcard` | overcard | A card higher in rank than your opponent's pair. AK vs 88 = two overcards (both beat the 8); A8 vs 99 = one overcard (only the ace beats the 9). |
| `set` | set | Three of a kind made when your pocket pair matches a board card (you hold 99, a 9 flops). Very strong and well disguised. |
| `kicker` | kicker | A side card that breaks ties within the same category. A-K beats A-Q on an ace because the king outkicks the queen. |
| `equity` | equity | Your share of the pot — how often your hand wins if all remaining cards were dealt out. |
| `potOdds` | pot odds | The price the pot offers you on a call: your call ÷ the final pot. Compare it to your equity. |
| `EV` | EV | Expected Value — the average chips a decision wins or loses over the long run. |
| `SPR` | SPR | Stack-to-Pot Ratio — effective stack ÷ pot on the flop; tells you how committed you are. |
| `polarized` | polarized | A range of very strong hands and bluffs with little in between — usually bet large. |
| `cbet` | c-bet | Continuation bet — a follow-up bet on the flop by whoever raised pre-flop. |
| `range` | range | All the hands a player could have right now — not one specific holding. |
| `combo` | combo | One specific two-card holding. 1,326 exist; AKs has 4 combos, AKo has 12, a pair has 6. |
| `blocker` | blocker | A card in your hand that removes combos from the opponent's range (you hold a card they'd need). |
| `outs` | outs | Cards still to come that improve you to a likely winner. |
| `threeBet` | 3-bet | A re-raise of the first pre-flop raise. |
| `draw` | draw | An unmade hand that can improve — e.g. four to a flush or a straight. |
| `nuts` | the nuts | The best possible hand on a given board. |

`Term({ id, child })`: if `id` is not in `GLOSSARY`, render the child (or the id) as plain
text. Otherwise render the child (or the term) with a **dotted gold underline** (underline
offset 2 px, `cursor: help`) wrapped in a tooltip (250 ms delay, max width 260 px, dark
popover with arrow) whose content is the term in bold gold-light on the first line and the
definition below. On mobile, tap-to-show is the natural equivalent.

Actual `Term` usages in lessons (everything else in the glossary is only listed on the
cheat sheet): `UTG`, `MP`, `CO`, `BTN`, `SB`, `BB` (Position lesson seat cards), `overcard`
and `set` (Estimating Equity lesson).

---

## 6. Prose building blocks

Lessons are composed of these blocks (all stacked with 16 px gaps):

| Block | Rendering |
|---|---|
| `Lead(text)` | Slightly larger paragraph (~16.3 px), relaxed line-height, full text colour. The first paragraph of every lesson. |
| `P(text)` | Normal paragraph, muted colour, relaxed line-height. May contain **bold** runs, inline `mono` gold code spans and `Term` hovers. |
| `H(text)` | h3, display font, bold, ~18 px, full text colour. |
| `Callout(title?, text)` | Rounded 12 px box, gold 25 % border, gold 8 % background, 16 px padding. First line: bolt icon (15 px) + title in small semibold gold-light; **default title "Key idea"**. Body ~14 px muted. |
| `Diagram(range, title, note?)` | Centered column in a rounded card (line border, ink-850 bg, 16 px padding): title (small semibold), a **read-only** 13×13 `RangeMatrix` of size 360 with `highlight = range`, a `RangeLegend` (Pairs / Suited / Offsuit swatches), then the optional note (max width 440 px, centered, ~12.5 px faint). |
| "Info card" | Rounded 12 px card (line border, ink-850 bg, 16 px padding) containing an `H` and a `P`. Used in 2-column grids. |
| "Stat row" | A rounded 8 px card (line border, ink-850 bg, 12 px × 8 px padding) laid out `flex` with a label on the left and a mono gold-light value on the right. |

`RangeMatrix` contract as used here (the widget itself is ported elsewhere): 13×13 grid,
rows and columns in `RANKS_DESC = A K Q J T 9 8 7 6 5 4 3 2` order; cell `(r,c)` label is
`labelAt(r,c)`: pair `"AA"` on the diagonal, suited `"AKs"` when `c > r` (upper-right),
offsuit `"AKo"` when `r > c` (lower-left). Read-only + highlight: highlighted cells use the
kind colour (`--combo-pair` / `--combo-suited` / `--combo-offsuit`) with white text; other
cells are dim ink-700 with faint text at 92 % opacity. Interactive (value + onChange): press
on a cell toggles it and starts a paint stroke whose mode (add/remove) is the opposite of the
first cell's state; entering further cells while pressed applies the same mode; pointer-up
anywhere ends the stroke. `RangeLegend()` (mode "kind") shows three 12 px swatches with the
texts **Pairs**, **Suited**, **Offsuit**.

---

## 7. Lesson content — Level 1 "Basics"

Level: id `basics`, title **Basics**, icon `book`, blurb "Rules, rankings, position and bankroll."

### 7.1 `hand-rankings` — Hand Rankings (4 min)

Summary: introduces the ten hand categories with example cards, kicker rules and the wheel, then a two-question quiz.

Body, in order:

1. Lead: "Every hand of Texas Hold'em is a race to make the best five-card hand from your two hole cards and the five community cards. Memorising the ranking order is non-negotiable."
2. `HandRankings` widget (§12.1).
3. Callout (title "Key idea"): "When two players share the same category, the higher cards (kickers) decide it. Aces are high, except in the "wheel" straight 5-4-3-2-A where the ace plays low."
4. Quiz:
   - Q: "Which hand wins: a flush or a straight?" — options ["Straight", "Flush", "They tie"] — answer index 1 ("Flush") — explain: "A flush (five of one suit) beats a straight (five in a row, mixed suits)."
   - Q: "You hold A♦Q♣ on a board of A♠ K♦ 4♥ 9♣ 2♠. What's your hand?" — options ["Two pair", "A pair of Aces, Queen kicker", "Ace high"] — answer 1 — explain: "You pair your Ace; your second card (Q) is the kicker. No second pair is on board for you."

### 7.2 `position` — Position & the Button (5 min)

Summary: names the six seats of a 6-max table, why the button is best, with hover-glossed seat abbreviations and a rule of thumb.

1. Lead: "Position is the single most undervalued edge for new players. Acting last means you make every decision with more information than your opponents."
2. H: "The six seats"
3. P: "Each seat has a name and acts in a fixed order. The dealer **button** is the best seat because it acts last in every betting round after the flop. Moving clockwise from it, the **small blind** and **big blind** post forced bets, then play runs through the early and middle seats to the cutoff and back to the button. (Hover the dotted terms for a definition; the full glossary lives in Practice → Quick Reference.)"
   (Mobile port: change "Hover" to "Tap" if the tooltip is tap-triggered.)
4. A 2-column grid (1 column on narrow screens) of six seat cards. Each card: rounded 8 px, line border, ink-850 bg, 12×8 px padding; first line = the abbreviation as a `Term` hover (display font, bold, 14 px) followed by the full name in gold-light ~12.5 px; second line = the note in faint ~11 px.

   | abbr (Term id) | name | note |
   |---|---|---|
   | UTG | Under the Gun | Earliest — acts first, play tightest |
   | MP | Middle Position | Early / middle |
   | CO | Cutoff | Late — raise more hands |
   | BTN | Button (dealer) | Latest — best seat, most hands playable |
   | SB | Small Blind | Forced bet, acts first post-flop |
   | BB | Big Blind | Forced bet, last to act pre-flop |
5. Callout (title **"Rule of thumb"**): "Play fewer hands up front, more hands on the button."

No quiz.

### 7.3 `bankroll` — Bankroll & Mindset (4 min)

Summary: variance, thinking in big blinds, the bb/100 win-rate metric and where it appears in the app.

1. Lead: "Poker is a game of edges realised over thousands of hands. Variance means even perfect play loses regularly in the short run."
2. P: "Think in big blinds (bb), not chips — it makes decisions stake-independent. A solid winner earns only a few bb per 100 hands, so protect against tilt and never risk money you can't afford to lose. In this trainer your stack auto-resets, so focus on decision quality, not the scoreboard."
3. H: "Win-rate: bb/100"
4. P: "Win-rate is measured in big blinds won per 100 hands ("bb/100"). It's stake-independent, so you can compare any games. A strong winner makes only a few bb/100; anything from −5 to +10 is normal, and over small samples it swings wildly. The Stats page and the session rail both show your bb/100."
5. Callout (Key idea): "Results are noise; decisions are signal. The EV Coach grades the decision."

No quiz.

---

## 8. Lesson content — Level 2 "Pre-flop"

Level: id `preflop`, title **Pre-flop**, icon `cards`, blurb "The 13×13 matrix and opening ranges."

### 8.1 `matrix` — The 13×13 Matrix (5 min)

Summary: how 169 starting hands map onto the grid, combo counts per cell type, and a highlighted ~15 % range diagram.

1. Lead: "The 169 distinct starting hands fit neatly into a 13×13 grid — the standard way to describe a range: the set of hands a player would choose to play."
2. P: "Pairs run down the diagonal. Suited hands sit in the upper-right triangle (e.g. AKs), and offsuit hands in the lower-left (AKo). There are 1,326 actual two-card combos: 6 per pair, 4 per suited hand, 12 per offsuit hand."
3. Diagram: `range = topPercentRange(15)` (37 labels / 204 combos — exact set in §14.1), title **"A tight ~15% range"**, note "Highlighted = hands you'd play. Notice how strong pairs and big suited cards (A, K, Q, J, 10) dominate."

No quiz.

### 8.2 `opening-ranges` — Opening Ranges by Position (6 min)

Summary: two side-by-side diagrams of the authored 100 bb UTG and BTN raise-first-in charts, with a callout on why.

1. Lead: "How wide you open (raise when no one has bet yet) should grow as you get closer to the button."
2. A 2-column grid (1 column on narrow) of two Diagrams:
   - `range = chartToSet(PREFLOP_100.rfi.UTG)` (min 0.5 → 35 labels / 206 combos, §14.2), title **"UTG open · ~15%"**, no note.
   - `range = chartToSet(PREFLOP_100.rfi.BTN)` (97 labels / 654 combos, §14.2), title **"Button open · ~45%"**, no note.
   (The titles' percentages are hand-written approximations; the real combo widths are 15.5 % and 49.3 %. Keep the titles as written.)
3. Callout (Key idea): "From UTG you're under the gun with five players still to act — only premium hands profit. On the button just two blinds remain, so you can attack with a huge range."

No quiz.

### 8.3 `three-betting` — 3-Betting (5 min)

Summary: what a 3-bet is, a diagram of the BTN-vs-CO 3-bet chart, and how to adjust vs tight/loose openers.

1. Lead: "A 3-bet is a re-raise of an opener. Used well it builds pots with your best hands and steals the chips already in the pot with the right bluffs."
2. Diagram: `range = chartToSet(PREFLOP_100.vsRfi.BTN_vs_CO.threebet, 0.4)` (**note the 0.4 threshold**, which admits the 0.5-frequency hands but excludes the 0.25 ones; 14 labels / 82 combos, §14.2), title **"BTN 3-bet vs a CO open · ~5%"**, note "Big pairs and AK to build the pot, plus small suited aces as bluffs — your ace makes AA/AK less likely, and can still make the best possible flush."
3. P: "Against a tight opener (a Nit), 3-bet only your premiums — they fold everything else and call only when they crush you. Against a loose-aggressive opener, widen for value."

No quiz.

### 8.4 `hud-reading` — Reading the HUD: VPIP & PFR (5 min)

Summary: defines the two HUD stats, reads the gap between them, lists the four bot archetypes' numbers, then a quiz.

1. Lead: "A **HUD** (Heads-Up Display) is the small stats overlay shown on each opponent. In All-In it displays two numbers like `22/18` — the two most important stats for reading a player." (`22/18` is a mono gold-light span.)
2. A 2-column grid of two info cards:
   - H "VPIP"; P: "*Voluntarily Put $ In Pot* — the % of hands a player chooses to play (call or raise) pre-flop. Posting a blind doesn't count. High VPIP = loose; low = tight." (The italic phrase is rendered in the full text colour rather than muted.)
   - H "PFR"; P: "*Pre-Flop Raise* — the % of hands they raise pre-flop. PFR is always ≤ VPIP. A big gap between them means a passive caller."
3. P: "The gap tells the story. VPIP ≈ PFR is an aggressive, raise-or-fold player. A wide gap (e.g. 45/7) is a passive Calling Station who limps (just calls the minimum instead of raising) and calls. Here's how the four bots look:"
4. A vertical list of four archetype rows, in the order TAG, LAG, Nit, Station. Each row (rounded 8 px card, line border, ink-850 bg, 12×8 px padding, horizontal flex with 12 px gaps): a 10 px colour dot, mono bold gold-light `"{vpip}/{pfr}"` (fixed width 56 px), the archetype name (semibold, 14 px), then the blurb (muted, ~12.5 px). Values come from the archetype config; they are:

   | key | color | vpip/pfr | name | blurb |
   |---|---|---|---|---|
   | TAG | `#2f6fd0` | 22/18 | Tight-Aggressive | Plays few hands but bets and raises them hard. The textbook winner. |
   | LAG | `#8a5cd1` | 34/27 | Loose-Aggressive | Plays many hands with relentless pressure. Hard to put on a hand. |
   | Nit | `#2faa66` | 12/9 | Nit | Extremely tight. If a Nit raises, believe them. |
   | Station | `#d23b3b` | 46/7 | Calling Station | Calls far too much, rarely raises. Value-bet relentlessly, never bluff. |
5. Callout (Key idea): "Hover a bot's HUD in the game to see these numbers and a reminder of what they mean."
6. Quiz:
   - Q: "A player is 45/7. What kind of opponent is this?" — options ["A tight, aggressive regular", "A loose, passive calling station", "A maniac who raises everything"] — answer 1 — explain: "High VPIP (45) but very low PFR (7) = plays many hands but rarely raises — a calling station. Value bet, never bluff."
   - Q: "Can a player have a PFR higher than their VPIP?" — options ["Yes", "No"] — answer 1 ("No") — explain: "Raising pre-flop is a way of voluntarily putting money in, so every raise is also counted in VPIP. PFR ≤ VPIP always."

---

## 9. Lesson content — Level 3 "Post-flop"

Level: id `postflop`, title **Post-flop**, icon `target`, blurb "Board texture, pot odds and c-betting."

### 9.1 `board-texture` — Reading Board Texture (5 min)

Summary: dry vs wet flops with an example of each and a sizing callout.

1. Lead: "Flops are either dry or wet, and that changes everything about how you bet."
2. 2-column grid of two info cards:
   - H "Dry boards"; P: "K♠ 7♦ 2♣ — disconnected, three different suits. Few draws exist, so the pre-flop raiser can follow up with a small bet very often."
   - H "Wet boards"; P: "J♥ T♥ 9♠ — connected and suited. Many draws hit it; bet bigger with strong hands and check more marginal ones."
3. Callout (Key idea): "The wetter the board, the larger your bets should be — and the more they should be strong hands or bluffs, not the in-between."

No quiz.

### 9.2 `counting-outs` — Counting Outs & the 2/4 Rule (5 min)

Summary: what an out is, the ×4 / ×2 rule, a six-cell table of common draws, a caveat for big draws, quiz.

1. Lead: "An "out" is a card that improves you to a likely winner. Counting outs lets you estimate your equity in seconds — no computer required."
2. H: "The 2 & 4 rule"
3. P: "On the flop (two cards to come) multiply your outs by 4. On the turn (one card to come) multiply by 2. It closely approximates the real percentage."
4. A grid (2 columns, 3 on wider screens) of six cells. Each cell: rounded 12 px card, line border, ink-850 bg; first line the draw name (semibold 14 px); second line mono faint ~11.5 px: `"{o} outs · {f}% flop / {t}% turn"` with the flop percentage in gold-light.

   | d | o | f | t |
   |---|---|---|---|
   | Flush draw | 9 | 36 | 18 |
   | Open-ended straight | 8 | 32 | 16 |
   | Gutshot | 4 | 16 | 8 |
   | Two overcards | 6 | 24 | 12 |
   | Flush + gutshot | 12 | 48 | 24 |
   | Pair → set | 2 | 8 | 4 |
5. Callout (Key idea): "Very big draws (12+ outs) slightly beat the ×4 cap — shade huge numbers down a little."
6. Quiz:
   - Q: "You flop a flush draw (9 outs). Roughly what's your equity by the river?" — options ["~18%", "~36%", "~50%"] — answer 1 — explain: "Two cards to come → outs × 4 = 9 × 4 ≈ 36%."
   - Q: "On the turn you have a gutshot (4 outs). Your equity?" — options ["~8%", "~16%", "~24%"] — answer 0 — explain: "One card to come → outs × 2 = 4 × 2 = 8%."

### 9.3 `estimating-equity` — Estimating Equity (5 min)

Summary: overcards defined (hover term), six classic match-ups with equities, explanation of set-over-set, shortcut callout, quiz.

1. Lead: "For made hands, memorise a handful of classic match-ups and you'll estimate equity at the table instantly — no simulation needed."
2. H: "First, what's an "overcard"?"
3. P: "An <Term overcard>overcard</Term> is a card higher in rank than your opponent's pair. **AK vs 88** has two overcards — both beat the 8 — so it's nearly a coin flip (a "race"). **A8 vs 99** has just one overcard (only the ace beats the 9), so the pair is a much bigger favourite. The more, and higher, the overcards, the closer to 50/50."
4. Vertical list of six stat rows (label left ~13.8 px full colour, value right mono gold-light ~12.5 px):

   | m | e |
   |---|---|
   | Overpair vs underpair (KK vs 99) | ~82% / 18% |
   | Pair vs two overcards / a race (88 vs AKo) | ~55% / 45% |
   | Dominated (AK vs AQ) | ~73% / 27% |
   | Big suited vs pair (AKs vs QQ) | ~46% / 54% |
   | Pair vs one overcard (99 vs A8) | ~70% / 30% |
   | Set over set, flopped (an unavoidable collision) | ~90% / 10% |
5. P: "The first five are pre-flop all-in match-ups. The last is an unavoidable post-flop collision: a <Term set>set</Term> is a pocket pair that pairs the board, and when two players both flop sets the loser has almost no way to win (only the last card of their rank can make four-of-a-kind), hence ~90/10."
6. Callout (Key idea): "Shortcuts: races ≈ 50/50, domination ≈ 70/30, a pair over a pair ≈ 80/20."
7. Quiz:
   - Q: "KK vs 99 all-in pre-flop — about how often does KK win?" — options ["~60%", "~82%", "~95%"] — answer 1 — explain: "A bigger pair over a smaller pair is roughly an 80/20 favourite."
   - Q: "AK vs QQ pre-flop — who's ahead?" — options ["AK, clearly", "QQ, slightly (~54%)", "Exactly 50/50"] — answer 1 — explain: "The pair is a small favourite over two overcards — about 54/46."

### 9.4 `pot-odds` — Pot Odds, Break-even & EV (6 min)

Summary: the two formulas (break-even equity, EV of calling), the interactive PotOddsCalculator, a coach callout, quiz.

1. Lead: "Calling is profitable when your equity beats the price the pot is offering you. Two formulas run the whole decision."
2. H: "From odds to a decision"
3. P: "**Break-even equity** — the minimum chance of winning that makes a call profitable — is your call divided by the final pot: `call ÷ (pot + 2 × bet)`. The **value of calling** is `EV = equity × (final pot) − your call`. If EV is positive, call. Drag the sliders — including your own equity estimate — and watch the verdict flip." (Both formulas are mono gold-light spans.)
4. `PotOddsCalculator` widget (§12.2).
5. Callout (Key idea): "The EV Coach during play computes your exact equity against each bot's range with a Monte Carlo simulation — this is the same maths, automated."
6. Quiz:
   - Q: "The pot is 10 bb and your opponent bets 5 bb. What equity do you need to call?" — options ["About 25%", "About 33%", "About 50%"] — answer 0 — explain: "You call 5 to win 15 (10 + their 5). Break-even = 5 / (10 + 5 + 5) = 5/20 = 25%."
   - Q: "A pot-sized bet always offers you what pot odds to call?" — options ["2-to-1 (need 33%)", "1-to-1 (need 50%)", "3-to-1 (need 25%)"] — answer 0 — explain: "Against a pot-sized bet you're getting 2-to-1, so you need ~33% equity to break even."

### 9.5 `implied-odds` — Implied & Reverse-Implied Odds (5 min)

1. Lead: "Pot odds only count the chips in the middle right now. Implied odds count the extra you expect to win on later streets when you complete your hand."
2. P: "A draw that's slightly too expensive on direct odds can still be a profitable call if you'll get paid off when you hit. The deeper the stacks and the more disguised your draw, the larger your implied odds — which is why suited connectors and small pairs (set-mining) love deep stacks."
3. H: "Reverse-implied odds"
4. P: "The flip side: hands that win a small pot but lose a big one — a weak top pair, or a dominated draw (a low flush draw against a higher one). When you'll often be second-best as the money goes in, shade toward folding even when the immediate price looks okay."
5. Callout (Key idea): "Implied odds reward hands that can make the best possible hand (sets, straights, flushes). Reverse-implied odds punish hands that make a second-best hand (weak aces, dominated draws)."
6. Quiz:
   - Q: "Implied odds are largest when…" — options ["Stacks are deep and your draw is hidden", "Stacks are shallow", "You're drawing to a small flush"] — answer 0 — explain: "Deep stacks mean more to win on later streets; a hidden draw means you get paid when you hit."
   - Q: "Which hand suffers most from reverse-implied odds?" — options ["The ace-high flush draw", "A king-high flush draw against aggression", "A set"] — answer 1 — explain: "A flush draw without the ace can complete and still lose a big pot to a higher flush — classic reverse-implied odds."

### 9.6 `bet-sizing` — Bet Sizing (6 min)

1. Lead: "Your bet size should follow your goal: get value, push out hands that could catch up, or fold out better hands."
2. 2-column grid of two info cards:
   - H "Polarized → big"; P: "When your range is the best possible hand or a bluff (and little in between), bet large — you want max value and max fold pressure."
   - H "Merged → small"; P: "When you hold many decent-but-not-great hands, bet small to get called by worse and keep the pot manageable."
3. P: "Size also **denies equity**: a bigger bet charges draws more to continue, so size up on wet boards. And your bluff size sets the price — a bet only profits as a bluff if your opponent folds often enough. Drag the sliders:"
4. `BluffCalculator` widget (§12.3).
5. Callout (Key idea): "Pure-bluff rule of thumb: a pot-sized bet needs your opponent to fold about 50% of the time; a half-pot bet about 33%; a third-pot about 25%."
6. Quiz:
   - Q: "A pot-sized bluff needs your opponent to fold roughly how often to break even?" — options ["~33%", "~50%", "~67%"] — answer 1 — explain: "Risk = pot, reward = pot, so break-even fold frequency = bet/(bet+pot) = 50%."
   - Q: "With a polarized range (best possible hands or bluffs), you should bet…" — options ["Small", "Big"] — answer 1 — explain: "Polarized ranges want big sizes — maximum value when called, maximum pressure to fold."

### 9.7 `cbetting` — Continuation Betting (4 min)

1. Lead: "A continuation bet (c-bet) is a follow-up bet on the flop by the pre-flop aggressor. It wins pots whether or not you connected."
2. P: "C-bet more on dry boards that favour your range, and on boards where you can credibly represent the strongest hands. Slow down on wet boards that smash the caller's range, and against calling stations who never fold — value bet them instead."

No callout, no quiz.

### 9.8 `mdf` — Minimum Defense Frequency (5 min)

1. Lead: "How often must you continue against a bet so opponents can't profit by bluffing you with any two cards? That number is your minimum defense frequency (MDF)."
2. P: "A bluff risks the bet to win the pot. If you fold too often, ANY bluff shows a profit. The break-even point: `MDF = pot / (pot + bet)`. Against a half-pot bet you must continue 10/(10+5) = 67% of the time; against a pot-sized bet, 50%."
3. H: "When to use MDF vs pot odds"
4. P: "**Pot odds** answer "is THIS hand profitable to call?" — the right question against players who rarely bluff. **MDF** answers "am I folding so much that bluffing me prints money?" — the right question against aggressive players. Against the app's bots, pot odds usually rule: a Nit's big bet is almost never a bluff, so "mathematically exploitable" folding is actually correct against them."
5. Callout (title "Key idea", explicitly passed): "MDF is a shield, not a hammer. Reach for it when someone keeps betting at you street after street; ignore it when the bettor is honest. Knowing WHICH question to ask is the skill."
6. Quiz (three questions):
   - Q: "The pot is 12 bb and your opponent bets 6 bb (half pot). Roughly how often must you continue so they can't bluff any two cards profitably?" — options ["About 67%", "About 50%", "About 33%"] — answer 0 — explain: "MDF = pot / (pot + bet) = 12 / 18 = 67%. Fold more than a third and any-two bluffs profit."
   - Q: "A Calling Station almost never bluffs. Which number should drive your call/fold decision vs their river bet?" — options ["Pot odds (is my hand good often enough?)", "MDF (am I folding too much?)", "Neither — always call"] — answer 0 — explain: "MDF protects you from bluffers. When there are no bluffs to defend against, just ask whether your hand beats their value range often enough for the price."
   - Q: "Bigger bets mean your MDF…" — options ["goes down — you can fold more", "goes up — you must call more", "doesn't change"] — answer 0 — explain: "MDF = pot/(pot+bet): as the bet grows the fraction shrinks. Big bets let you fold more; tiny bets demand wide defense."

### 9.9 `check-raising` — Check-Raising (5 min)

1. Lead: "Check with the intention of raising a bet — the strongest move you can make out of position, and one this course's bots respect."
2. P: "Out of position you act first, which is a disadvantage. The check-raise flips that: you invite the in-position player's near-automatic continuation bet, then punish it. Your check-raising range should be built from two ends: **big hands** (sets, two pair, strong top pair on wet boards) that want a bigger pot, and **strong draws** (flush draws, open-enders — often with 8+ outs) that profit from folds now and can still hit when called."
3. H: "Where it works"
4. P: "Best on boards that favor the checker's range — low, connected flops that miss the raiser's big-card range. Size it meaningfully: around 3× their bet. Check-raising a dry A-K-x flop where the opener has all the aces mostly just donates information."
5. Callout (title **"Beware"**): "Never check-raising is itself a leak: it makes your checks an invitation to steal. Against auto-c-bettors, adding check-raises with draws is often the single most profitable adjustment."
6. Quiz:
   - Q: "Which hand type makes the best check-raise BLUFF on a 8♠7♠3♦ flop?" — options ["A♠9♠ (flush draw + overcard)", "K♦Q♣ (two overcards, no draw)", "3♣3♥ (bottom set)"] — answer 0 — explain: "A set is a value raise, not a bluff. The ace-high flush draw has huge equity when called AND wins outright when they fold — the perfect semi-bluff (a bluff that can still improve to the best hand). KQ-high has too little to fall back on."
   - Q: "Why is the check-raise strongest OUT of position?" — options ["It converts acting first into a trap for automatic c-bets", "It hides your hand for later streets", "It's cheaper than betting"] — answer 0 — explain: "Acting first is normally a cost. Checking invites the c-bet, and the raise punishes it — position's disadvantage becomes bait."

---

## 10. Lesson content — Level 4 "Advanced"

Level: id `advanced`, title **Advanced**, icon `bolt`, blurb "Combinatorics, blockers and exploits."

### 10.1 `combinatorics` — Combinatorics & Blockers (6 min)

1. Lead: "Counting combos turns "I feel like he has it" into a number. There are 6 ways to make any pocket pair, 4 ways for a suited hand, 12 for an offsuit hand."
2. P: "A blocker is a card in your hand that removes combos from your opponent's range. Holding the A♠ on a flush-draw board means they can't have the ace-high flush draw (you hold the A♠) — fewer of their bluffs and value hands exist, which makes your bluffs and calls work more often."
3. H: "Worked example"
4. P: "The board is K♠ 9♦ 4♣. How many combos of top pair (a King) can your opponent have? Normally KK = 6 and each non-paired King hand like KQ = 16 combos — but the K♠ on the board is a blocker. With one King gone, KK drops to 3 combos and KQ to 12. Counting this way tells you there are far fewer value hands than it feels like."
5. A 3-column grid of three centred cells (rounded 12 px, line border, ink-850 bg, 8×12 px padding): big mono bold gold-light number on top, faint ~11 px label below.

   | n (top) | h (label) |
   |---|---|
   | 6 combos | Any pocket pair |
   | 4 combos | Suited (e.g. AKs) |
   | 12 combos | Offsuit (e.g. AKo) |
6. Callout (Key idea): "Holding one card of a pair cuts their pair combos from 6 down to 3."
7. Quiz (three questions):
   - Q: "How many combos of pocket Aces (AA) are there before any cards are dealt?" — options ["4", "6", "12"] — answer 1 — explain: "Choose 2 of the 4 aces: C(4,2) = 6 combos. Every pocket pair has 6."
   - Q: "You hold A♠. How many combos of AA can your opponent now have?" — options ["6", "3", "1"] — answer 1 — explain: "Your A♠ removes one ace, leaving 3 aces → C(3,2) = 3 combos. That's the power of a blocker."
   - Q: "How many combos does an offsuit hand like KQo have?" — options ["4", "12", "16"] — answer 1 — explain: "4 kings × 3 non-matching-suit queens = 12 offsuit combos."

### 10.2 `hand-reading` — Hand Reading: Narrowing a Range (7 min)

1. Lead: "Good players don't guess one hand — they track a whole range and shrink it street by street as the story unfolds. Here's the repeatable method."
2. H: "The four steps"
3. P: "1. **Start wide** from their position and type — a Nit's UTG range is tiny; a LAG's button range is huge. 2. **Subtract on every action**: a raise keeps value plus chosen bluffs; a call removes both the very top (they'd raise) and the bottom (they'd fold). 3. **Apply the board**: ask "which of their hands improved, and would they keep betting or calling it?" Remove the complete misses they'd give up. 4. **Compare** your hand to the handful of combos left — not to one imagined holding."
4. A 3-column grid (1 column on narrow) of three Diagrams, no notes:
   - `topPercentRange(40)` — title **"Pre-flop: opens ~40%"** (80 labels / 538 combos)
   - `topPercentRange(20)` — title **"Continues flop ~20%"** (47 labels / 270 combos)
   - `topPercentRange(10)` — title **"Bets again on turn ~10%"** (23 labels / 138 combos)
5. Callout (Key idea): "By the river, big aggressive lines are often **polarized** — the best possible hand or a bluff. Don't pay off the value half with a hand that only beats bluffs unless the price is right."
6. Quiz:
   - Q: "A call (rather than a raise) usually removes which hands from a range?" — options ["Only the weakest hands", "Both the strongest (would raise) and the weakest (would fold)", "Nothing — calls are random"] — answer 1 — explain: "Calling trims a range at both ends: the strongest hands raise, the weakest fold, leaving the middle."
   - Q: "A tight player check-raises the river. Their range is best described as…" — options ["Wide and weak", "Polarized — very strong hands and a few bluffs", "Exactly one hand"] — answer 1 — explain: "Big river aggression from a tight player is polarized: value or bluff, little in between."

### 10.3 `exploits` — Exploiting the Archetypes (6 min)

1. Lead: "The bots in the Sandbox play four classic styles. Each leaks differently."
2. A vertical list of four archetype cards (rounded 12 px, line border, ink-850 bg, 16 px padding), order TAG, LAG, Nit, Station. Header row: 12 px colour dot, semibold `"{name} ({key})"`, then faint mono ~11 px `"VPIP {vpip} / PFR {pfr}"`. Below (margin-top 4 px, ~13.8 px muted): the advice text.

   | key | header | stats line | advice |
   |---|---|---|---|
   | TAG | Tight-Aggressive (TAG) | VPIP 22 / PFR 18 | Solid and balanced. Respect their raises; pick spots, don't bluff into strength. |
   | LAG | Loose-Aggressive (LAG) | VPIP 34 / PFR 27 | Hyper-aggressive. Trap with strong hands and let them keep betting into you. |
   | Nit | Nit (Nit) | VPIP 12 / PFR 9 | Folds too much. Steal relentlessly, but believe them when they finally raise. |
   | Station | Calling Station (Station) | VPIP 46 / PFR 7 | Calls everything. Never bluff — value bet thin and bet big with strong hands. |

No callout, no quiz.

### 10.4 `multiway` — Playing Multiway (6 min)

1. Lead: "Almost everything else assumes one opponent. Add players and the maths shifts — this is the piece most training tools skip."
2. H: "Your equity to win drops"
3. P: "A hand that wins ~55% heads-up might win only ~30% against three opponents — more players means more ways to be beaten. Drawing hands also get paid less reliably because someone may already have the made hand you're drawing to."
4. H: "Pot odds still hold, but realised equity is lower"
5. P: "Break-even equity (call ÷ final pot) is unchanged, but your real chance of winning is lower multiway and players still to act can wake up with a hand. So continue with a stronger range, bluff less (someone usually calls), and value-bet your big hands bigger. Speculative hands — suited connectors, small pairs — go up in value because implied odds are huge when you hit."
6. H: "See it for yourself"
7. P: "Pick a hand and slide the opponent count — watch equity fall as the field grows."
8. `MultiwayEquityTrainer` widget (§12.4).
9. Callout (Key idea): "The in-game EV Coach now computes your equity against the whole field in multiway pots (not just heads-up), so its numbers already reflect this. Stronger hands still matter more the more players are in."
10. Quiz:
    - Q: "As more players enter the pot, your continuing range should get…" — options ["Wider", "Tighter", "Unchanged"] — answer 1 — explain: "More opponents = more ways to lose, so tighten up and continue with stronger hands."
    - Q: "Multiway, should you bluff more or less than heads-up?" — options ["More", "Less"] — answer 1 — explain: "With more players, it's far likelier someone calls — bluffs get through much less often."

### 10.5 `spr` — SPR & Commitment (5 min)

1. Lead: "Stack-to-Pot Ratio (SPR) = the effective stack divided by the pot on the flop. One number tells you how committed you are and which hands are worth stacking off (putting your whole stack in)."
2. Vertical list of three stat rows; left column mono bold gold-light fixed width 112 px, right muted ~13.4 px:

   | r | g |
   |---|---|
   | SPR ≤ 3 (low) | Committed — get it in with top pair / overpair or better. |
   | SPR 4–6 (medium) | Top pair good kicker is playable, but big draws and two pair want the money in. |
   | SPR 7+ (high) | Stack off only with two pair, sets and better — one pair rarely justifies 100bb. |
3. P: "SPR is set **before** the flop: more raises and callers build a bigger pot and shrink the SPR, widening what you'll commit. 3-bet pots are low-SPR (commit lighter); limped (everyone just called the minimum) and single-raised pots are high-SPR (need a stronger hand to stack off)."
4. Callout (Key idea): "Decide your stack-off threshold on the flop from the SPR — then stop agonising street by street."
5. Quiz:
   - Q: "A high SPR means you should commit your stack with…" — options ["Any top pair", "Stronger hands (two pair, sets+)", "Any pair"] — answer 1 — explain: "Deep relative to the pot, one pair is rarely worth stacking off — you want two pair or better."
   - Q: "A 3-bet pot tends to create a…" — options ["Low SPR", "High SPR"] — answer 0 — explain: "The bigger pre-flop pot relative to remaining stacks means a low SPR, so you commit lighter."

### 10.6 `threebet-pots` — Playing 3-Bet Pots (6 min)

1. Lead: "Re-raised pots are a different game: ranges are tighter, the pot is bigger relative to stacks, and one bet can commit you."
2. P: "After a 3-bet and call, the pot is ~20 bb with ~90 bb behind — an SPR around 4-5 instead of 12+. That changes everything: **top pair good kicker becomes a stack-off hand** where in a single-raised pot you'd keep the pot small with it. Meanwhile hands that love deep stacks (small pairs hunting sets, suited connectors) lose value — there isn't enough money behind to pay off their big hits."
3. H: "Who has the range advantage?"
4. P: "The 3-bettor's range is packed with big pairs and big cards, so A-high and K-high flops favor them massively — c-bet small and often. Low connected flops hit the CALLER's pairs and suited hands more; as the 3-bettor, slow down there. This "who does the flop help?" question decides most 3-bet pots."
5. Callout (title "Key idea"): "Before the flop comes down, know your plan: with QQ+ in a 3-bet pot at SPR 4, the answer is usually "all the chips are going in". Deciding this early stops you from talking yourself into a fold on a scary-looking turn."
6. Quiz:
   - Q: "In a 3-bet pot at SPR ~4 you hold A♥K♦ and flop K♠8♦3♣. Your default plan is…" — options ["Value bet and be willing to stack off", "Check to keep the pot small", "Bet once, then give up unimproved"] — answer 0 — explain: "Top pair top kicker at low SPR in a range-vs-range battle you're winning is a stack-off hand. Small pots are for single-raised, deep-stack situations."
   - Q: "Which hand LOSES the most value moving from a single-raised pot to a 3-bet pot?" — options ["6♥6♣ (set mining)", "Q♥Q♦ (overpair potential)", "A♠K♠"] — answer 0 — explain: "Set mining needs ~10x implied odds. In a 3-bet pot there isn't enough money behind relative to the price — small pairs hate re-raised pots."

### 10.7 `equity-realization` — Equity Realization (5 min)

1. Lead: "Raw equity is what your hand would win at showdown with no more betting. You never get that — position and playability decide how much of it you actually collect."
2. P: "9♠8♠ has ~38% equity against a big-card hand, but it **realizes** more than that in position (you see cheap turns, bluff good rivers, fold before big mistakes) and less out of position. As a rule: in position with a playable hand you realize 100%+ of raw equity; out of position with a weak offsuit hand you might realize only 70-80%."
3. H: "What this changes"
4. P: "It's the hidden reason behind chart shapes you've seen: suited and connected hands defend wide IN POSITION; offsuit junk folds even at "correct" pot odds OUT of position. When the coach says a call is marginal, ask: am I in position to realize my share? A break-even call by raw equity is a losing call if you'll only realize 80% of it."
5. Callout (title **"Rule of thumb"**): "Discount your equity ~10-20% when out of position with a hand that plays poorly (offsuit, disconnected). Marginal calls need that margin."
6. Quiz:
   - Q: "Which hand realizes its raw equity BEST?" — options ["T♠9♠ on the button", "T♠9♠ in the small blind", "K♣3♦ in the small blind"] — answer 0 — explain: "Suited, connected, and in position: it sees cheap cards, wins extra pots with bluffs, and escapes cheaply when beaten. The same hand out of position realizes less; K3o out of position is the worst of all worlds."
   - Q: "You're getting exactly break-even pot odds out of position with a weak offsuit hand. The call is…" — options ["A losing call — you won't realize full equity", "Exactly break-even", "Profitable — pot odds are all that matter"] — answer 0 — explain: "Pot-odds math assumes you collect your full showdown equity. Out of position with a poorly-playing hand you won't — so break-even by the formula is losing in practice."

### 10.8 `turn-river` — Turn & River Play (6 min)

1. Lead: "Each street, ranges get narrower and equities move toward the extremes. By the river there are no draws left — only value bets, bluffs, and bluff-catchers."
2. H: "The turn: the pressure street"
3. P: "Calling the flop is cheap; calling the turn is not. Bet again on turns that improve your range or dent theirs (overcards to their pairs, completing YOUR draws). With one card to come, draws are worth roughly **2% per out** — half their flop value — so the price to chase gets worse exactly as the bets get bigger. That's why the coach's turn verdicts flip to fold more often than beginners expect."
4. H: "The river: pure decisions"
5. P: "River betting is binary: **value** (worse hands call) or **bluff** (better hands fold). Before betting, name the actual hands that call you while losing — if you can't, it isn't a value bet. Facing a bet, your hand is usually a bluff-catcher: it beats bluffs, loses to value. Then the only question is "does this player bluff here often enough?" — count the price (a pot-sized bet needs them bluffing 1 time in 3), then judge the player."
6. Callout (title "Key idea"): ""What am I trying to get called by / what am I trying to fold out?" If a river bet has no answer to either question, check."
7. Quiz:
   - Q: "You river a weak top pair. Your opponent (a Nit who never bluffs) bets the pot. Your hand beats bluffs but loses to all their value hands. Call or fold?" — options ["Fold — no bluffs means no bluff-catching", "Call — you need to defend your MDF", "Raise as a bluff"] — answer 0 — explain: "A bluff-catcher is only worth calling if there are bluffs to catch. Against a player who has them, the same call is fine — the player, not the formula, decides river calls."
   - Q: "A flush draw (9 outs) on the TURN is worth roughly what equity?" — options ["~18% (2% per out)", "~36% (4% per out)", "~9%"] — answer 0 — explain: "With one card to come it's ~2% per out. The 4% shortcut is for flop-to-river with both cards — a common and expensive mix-up."

### 10.9 `synthesis` — Putting It Together (3 min)

1. Lead: "You now have the full toolkit: rankings, position, ranges, odds and exploits."
2. P: "Head to the Sandbox. Before each decision, use Guess Range to test your read, then act and let the EV Coach grade you. Watch your bb/100 and read accuracy climb on the Stats page over time. That feedback loop — decide, measure, adjust — is how real players improve."
3. Callout (title **"Your move"**): "Open the Play tab and run 50 hands focusing only on position."

No quiz.

---

## 11. Lesson content — Level 5 "Practice"

Level: id `practice`, title **Practice**, icon `target`, blurb "Hands-on drills and a range explorer."

### 11.1 `cheat-sheet` — Quick Reference (4 min)

Summary: the one-page memorisation sheet: outs-to-equity, common all-in match-ups, prices, SPR/position numbers, and the full glossary.

Layout: a Lead, then five `H` headings each followed by a 2-column grid (1 column on narrow) of `Row(k, v)` items. `Row` = rounded 8 px card, line border, ink-850 bg, 12×6 px padding, `k` left (~13 px full colour), `v` right (mono ~12.5 px gold-light).

1. Lead: "Everything worth memorising, on one page. Come back to it any time."
2. H "Equity from outs (2 / 4 rule)"

   | k | v |
   |---|---|
   | Per out — flop (×4) / turn (×2) | ≈ 4% / 2% |
   | Flush draw (9 outs) | ≈ 36% / 18% |
   | Open-ender (8) | ≈ 32% / 16% |
   | Gutshot (4) | ≈ 16% / 8% |
3. H "Common all-in matchups"

   | k | v |
   |---|---|
   | Pair vs lower pair | ≈ 80 / 20 |
   | Pair vs two overcards (race) | ≈ 55 / 45 |
   | Dominated (AK vs AQ) | ≈ 70 / 30 |
   | Set over set (flopped) | ≈ 90 / 10 |
4. H "Prices"

   | k | v |
   |---|---|
   | Break-even equity to call | call ÷ (pot + 2×bet) |
   | Pot bet → need | 33% |
   | Half-pot → need | 25% |
   | Bluff: pot bet → fold % | 50% (½-pot: 33%) |
5. H "SPR & position"

   | k | v |
   |---|---|
   | SPR ≤ 3 → commit with | top pair+ |
   | SPR 7+ → commit with | two pair / sets+ |
   | UTG / CO / BTN opens | ~14% / 27% / 45% |
   | BB defend vs a raise | ~55% |
6. H "Glossary"
7. Faint ~11.8 px line: "Every term below is also hoverable wherever it appears in a lesson."
8. One paragraph per `GLOSSARY` entry, in glossary order (§5), ~13 px muted, formatted `**{term}** — {def}` with the term in the full text colour.

No quiz.

### 11.2 `range-explorer` — Range Explorer (5 min)

1. Lead: "Build ranges by hand. Load a position preset to see how a target percentage becomes real cells, or paint your own and watch the combo count — the same count the EV Coach quotes."
2. `RangeExplorer` widget (§12.5).

### 11.3 `equity-calculator` — Equity Calculator (5 min)

1. Lead: "A free-form equity tool. Paint any two ranges, set a board, and the same Monte-Carlo engine the coach uses tells you how often you win."
2. `EquityCalculator` widget (§12.6).

### 11.4 `drill-potodds` — Pot-Odds Drill (5 min)

1. Lead: "Random spots — compute the break-even equity in your head, then check yourself."
2. `PotOddsDrill` widget (documented in the drills port doc).

### 11.5 `drill-outs` — Outs → Equity Drill (5 min)

1. Lead: "Practise the 2/4 rule on random draws until it's automatic."
2. `OutsDrill` widget (drills port doc).

### 11.6 `drill-range` — Range-Building Drill (6 min)

1. Lead: "Paint a position's opening range from memory, then score it against the standard."
2. `RangeBuildDrill` widget (drills port doc). For reference, its targets are `chartToSet(PREFLOP_100.rfi.UTG)`, `chartToSet(PREFLOP_100.rfi.CO)`, `chartToSet(PREFLOP_100.rfi.BTN)` and the union of `chartToSet(BB_vs_BTN.call)` ∪ `chartToSet(BB_vs_BTN.threebet)`, scored by combo-weighted F1 — the same `chartToSet` described in §13.2.

---

## 12. Interactive widgets

Shared conventions:

- **Slider** = a single-thumb horizontal slider (Radix). Props `value, min, max, step`; the
  value is clamped into `[min, max(min,max)]` for display. Gold range fill, gold 16 px thumb.
- **fmtPct(frac, digits = 0)** = `"${(frac * 100).toStringAsFixed(digits)}%"` (JS `toFixed`
  semantics: round half up; Dart's `toStringAsFixed` matches).
- **fmtSigned(n, digits = 1)** = round to `digits` decimals, prefix `"+"` when `>= 0`
  (so `0` renders `+0.0`), e.g. `+5.0`, `-1.5`.
- **Number interpolation** of slider values mimics JS: integers print without a decimal
  point (`7 bb`), halves print as `6.5 bb`.
- A "Field" = label row (label left in muted 14 px, value right in mono semibold 14 px) above a Slider.
- A "Result" tile = rounded 12 px card (line border, ink-800 bg) with a tiny uppercase faint label and a mono bold value.
- **PlayingCard(card, w)** renders a card face at width `w` px (height `round(w*1.4)`).
- Card strings are two characters: rank `2 3 4 5 6 7 8 9 T J Q K A` + suit `c d h s` (e.g. `Ah`, `Td`).
  Suit glyphs: `s→♠ h→♥ d→♦ c→♣`. Rank `T` is displayed as `10` in the card pickers.

### 12.1 HandRankings (static)

Ten rows, strongest first. Each row: rounded 12 px card (line border, ink-850 bg, 12×8 px
padding), a 28 px gold-tinted circle with the 1-based rank number in mono bold gold, five
`PlayingCard`s at width 30, then name (semibold 14 px) and note (faint ~11.5 px).

| # | name | cards | note |
|---|---|---|---|
| 1 | Royal Flush | Ah Kh Qh Jh Th | A-K-Q-J-T, one suit |
| 2 | Straight Flush | 9s 8s 7s 6s 5s | Five in a row, one suit |
| 3 | Four of a Kind | Qh Qd Qc Qs 3d | All four of a rank |
| 4 | Full House | Jh Jd Jc 8s 8h | Three of a kind + a pair |
| 5 | Flush | Ad Jd 8d 5d 2d | Five of one suit |
| 6 | Straight | 9h 8s 7d 6c 5h | Five in a row, mixed suits |
| 7 | Three of a Kind | 7h 7d 7c Ks 2d | Three of a rank |
| 8 | Two Pair | Ah Ad 9c 9s 4d | Two different pairs |
| 9 | One Pair | Th Td As 7c 3d | A single pair |
| 10 | High Card | Ah Jd 8c 5s 2d | Nothing — highest card plays |

### 12.2 PotOddsCalculator

State: `pot = 10` (int), `bet = 6.5`, `eq = 50` (int percent).

Derived (all in bb):
```
toWin     = pot + bet
finalPot  = pot + 2 * bet
breakEven = bet / finalPot
ratio     = bet > 0 ? toWin / bet : 0
ev        = (eq / 100) * finalPot - bet        // EV of calling
call      = ev > 0.02                          // NOTE the 0.02 bb epsilon, not 0
```

Layout (rounded 16 px card, line border, ink-850 bg, 20 px padding):

1. 2-column grid of Fields:
   - Field label **"Pot before the bet"**, value `"{pot} bb"`, Slider min 1, max 60, step 1, aria "Pot".
   - Field label **"Opponent's bet"**, value `"{bet} bb"`, Slider min 0.5, max 60, step 0.5, aria "Bet".
2. 3-column grid of Result tiles (centred):
   - **"You risk"** → `"{bet} bb"`
   - **"To win"** → `"{toWin.toFixed(1)} bb"`
   - **"Getting"** → `"{ratio.toFixed(1)} : 1"`
3. Gold-tinted box (gold 10 % bg, centred): tiny uppercase gold label **"Break-even equity"**, big display number `fmtPct(breakEven)` (gold-light, ~30 px extra-bold), and a muted line:
   `"= your call ({bet}) ÷ final pot ({finalPot.toFixed(1)}). Call when your equity beats this."`
4. Field label **"Your equity estimate"**, value `"{eq}%"`, Slider min 0, max 100, step 1, aria "Your equity".
5. Verdict box (rounded 12 px, 16 px padding; border and 10 % background in green `rgba(63,191,127,0.1)` when `call`, red `rgba(236,90,90,0.1)` otherwise). Left column: tiny uppercase muted **"EV of calling"**, mono ~24 px extra-bold `"{fmtSigned(ev)} bb"` coloured good/bad, faint line `"{eq}% × {finalPot.toFixed(1)} − {bet} = {ev.toFixed(1)}"`. Right column (right-aligned): tiny uppercase muted **"Decision"**, display ~20 px bold **"Call"** or **"Fold"** in the same colour.

Worked defaults (pin as a test): pot 10, bet 6.5, eq 50 → toWin `16.5`, finalPot `23.0`,
break-even `28%`, getting `2.5 : 1`, EV `+5.0 bb`, formula line `50% × 23.0 − 6.5 = 5.0`, decision Call.
Other pins: pot 10, bet 5, eq 25 → break-even `25%`, EV `+0.0 bb`, `ev = 0` → **Fold** (epsilon). pot 10, bet 10, eq 34 → EV `+0.2`, Call.

### 12.3 BluffCalculator

State: `pot = 10`, `bet = 7`.

```
foldNeeded  = bet / (bet + pot)       // pure-bluff break-even fold frequency
callerNeeds = bet / (pot + 2 * bet)   // equity the caller needs
```

Layout (same card style):

1. 2-column grid of Fields:
   - **"Pot"** → `"{pot} bb"`, Slider 1..60 step 1, aria "Pot".
   - **"Your bet"** → `"{bet} bb ({fmtPct(bet / pot)} pot)"`, Slider **0.5..90** step 0.5, aria "Bet".
2. 2-column grid:
   - Gold box: tiny uppercase gold **"If you're bluffing"**, big `fmtPct(foldNeeded)` (gold-light), muted line **"they must fold at least this often for the bluff to make money"**.
   - Plain tile (line border, ink-800): tiny uppercase faint **"If they call you"**, big `fmtPct(callerNeeds)` (text colour), muted line **"they only need to win this often for their call to make money"**.

Pins: defaults → `7 bb (70% pot)`, fold needed `41%` (7/17), caller needs `29%` (7/24).
pot 10 / bet 10 → `100% pot`, `50%`, `33%`. pot 10 / bet 5 → `50% pot`, `33%`, `25%`.
pot 1 / bet 90 → `9000% pot`, `99%`, `50%`.

### 12.4 MultiwayEquityTrainer

Six fixed scenarios (index order matters, first is default):

| idx | name | hero | board |
|---|---|---|---|
| 0 | Two pair (top two) | Ah Kh | Ad Kc 7s |
| 1 | Top pair top kicker | Ah Kd | Ac 9h 4s |
| 2 | A set | 7h 7d | 7s Kc 2d |
| 3 | Overpair (QQ) | Qh Qd | 9s 6c 2d |
| 4 | Flush draw | Ah Kh | Qh 7h 2s |
| 5 | Pocket Aces (pre-flop) | Ah Ad | (empty) |

State: `idx = 0`, `opp = 2`, `series = [0,0,0,0,0]` (equity vs 1..5 opponents).

Effect on `idx` change (and on mount): fire five concurrent
`engine.equityVsField(hero, board, n, 1200)` for `n = 1..5` (unseeded Monte-Carlo, 1200
trials each), and when **all five** resolve set `series = results.map((r) => r.equity)`.
A `live` guard discards results that arrive after the scenario has changed again. Until
results arrive the bars show 0 %.

Derived: `cur = series[opp - 1]`; `curColor = cur >= 0.6 ? good : cur >= 0.4 ? gold : bad`.

Layout (card, 16 px gaps):

1. Wrapping row of scenario chips (rounded 6 px, ~11.8 px semibold): active = gold bg / dark text; others ink-600 bg muted. Tap → `idx = i`.
2. Row: hero cards as `PlayingCard(w: 40)`, the word **"on"** (faint), then board cards at `w: 36`, or the faint text **"(pre-flop)"** when the board is empty.
3. Field **"Opponents"** with value `"{opp}"`; Slider min 1, max 5, step 1, aria "Opponents".
4. Row, items bottom-aligned:
   - Big display number `fmtPct(cur)` (~36 px extra-bold, `curColor`) with the tiny uppercase faint caption `"equity vs {opp}"`.
   - A 110 px-tall bar chart with five columns (8 px gaps), each a button (tap → `opp = n`) with a native tooltip `"{n} opponent{n > 1 ? "s" : ""}: {fmtPct(e)}"`. Column content, top to bottom: mono ~10.5 px label `"{round(e*100)}%"` (full colour when active, faint otherwise); a bar of height `max(4, e * 90)` px (gold when active, ink-500 otherwise, top corners rounded); faint ~10 px label `"{n}"`.
5. Footer paragraph (~12.5 px faint): "Each extra opponent is another chance someone holds a better hand, so equity falls — fast for one-pair hands, more slowly for the nuts (the best possible hand). This is why you tighten up and value-bet more carefully the more players are in the pot."

Reference equities (20 000-trial run; expect ±2 pts at 1 200 trials) for vs 1 / 2 / 3 / 4 / 5:

| scenario | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Two pair (top two) | 95 | 90 | 86 | 80 | 77 |
| Top pair top kicker | 89 | 79 | 70 | 63 | 56 |
| A set | 98 | 95 | 92 | 90 | 88 |
| Overpair (QQ) | 82 | 67 | 55 | 46 | 38 |
| Flush draw | 73 | 60 | 52 | 49 | 46 |
| Pocket Aces (pre-flop) | 85 | 73 | 64 | 56 | 49 |

Tests should assert monotonic decrease with opponents and tolerance bands, not exact values.

### 12.5 RangeExplorer

Presets (button label → `topPercentRange(pct)`):

| label | pct | labels / combos |
|---|---|---|
| UTG ~14% | 14 | 35 / 188 |
| MP ~19% | 19 | 45 / 254 |
| CO ~27% | 27 | 58 / 362 |
| BTN ~45% | 45 | 91 / 598 |
| BB defend ~55% | 55 | 110 / 738 |

State: `painted = topPercentRange(14)` initially. `combos = combosInSet(painted)`.

Layout (card):

1. Wrapping row: the five preset buttons (secondary, small) then a ghost small **"Clear"** button (→ empty set).
2. Interactive `RangeMatrix(value: painted, onChange, size: 440)`.
3. Row: `RangeLegend()` left; right, mono semibold gold-light: `"{combos} combos · {fmtPct(combos / 1326)} of all hands"` (default: `188 combos · 14% of all hands`).
4. Paragraph (~13 px muted): "Load a preset to see how a target percentage maps to actual cells, or paint your own and watch the combo count. There are 1,326 total combos; that running count is exactly what the EV Coach means when it says an opponent's range is "≈ 450 combos.""

### 12.6 EquityCalculator

State:
```
mode: "range" | "hand" = "range"
hero: Set<HandLabel> = {}          // range mode
heroCards: List<Card> = []         // hand mode, max 2
vill: Set<HandLabel> = {}
board: List<Card> = []             // max 5
result: EquityResult? = null
busy: bool = false
```

Helper (used everywhere in this widget):
```dart
/// Concrete int-encoded combos of `range`, skipping any combo that shares a card with `board`.
List<(int,int)> expand(Set<String> range, List<String> board) {
  final blocked = board.toSet();
  final out = <(int,int)>[];
  for (final lab in range)                     // iteration order = insertion order of the set
    for (final (a, b) in labelToCombos(lab))   // §13.3
      if (!blocked.contains(a) && !blocked.contains(b)) out.add((cardToInt(a), cardToInt(b)));
  return out;
}
```

Every state mutation below also sets `result = null` (the result panel disappears until
"Calculate equity" is pressed again).

Interactions:
- Mode toggle (segmented "Range" / "Hand", gold active pill).
- Range mode, left column titled **"Your range"**: interactive `RangeMatrix(hero, size 320)`; beneath, two faint text buttons **"Any two"** (hero = all 169 labels) and **"Clear"** (hero = {}).
- Hand mode, left column titled **"Your exact hand"**: a row showing the picked cards as `PlayingCard(w: 40)` or the faint text **"Pick two cards below."**, plus a faint **"Clear"** text button on the right when any card is picked. Then a 52-button card grid (RANKS_DESC × SUITS order: Ac Ad Ah As Kc …; 28×28 px, bold ~11.5 px, rank `T` displayed `10`, suit glyph appended, suit-coloured text when unselected, gold bg when selected). A button is disabled when the card is on the board, or when 2 cards are already picked and this one isn't. Tap toggles membership (max 2).
- Right column titled **"Opponent's range"**: interactive `RangeMatrix(vill, size 320)` with the same **"Any two"** / **"Clear"** buttons.
- `RangeLegend()` below the two columns.
- **Board** section: header `"Board ({board.length}/5)"` with a faint **"Clear board"** button when non-empty; a 52-card grid like the hero picker; a button is disabled when 5 cards are selected and it isn't one of them. Tap toggles (max 5). Note the board picker does **not** disable hero's cards — a clash is prevented on the hero side only (hero buttons disable cards used on the board); if a board card is later chosen that equals a hero card the calculation still runs with a duplicate. (Port may guard this; original doesn't.)
- Footer row: faint summary text and the run button.
  - Range mode text: `"{expand(hero, board).length} vs {expand(vill, board).length} combos"`.
  - Hand mode text: `"{heroCards.join(" ") or "—"} vs {expand(vill, [...board, ...heroCards]).length} combos"`.
  - Primary button labelled **"Calculate equity"** (with a target icon), or **"Calculating…"** while busy. Disabled when `busy || vill.isEmpty || (mode == range ? hero.isEmpty : heroCards.length != 2)`.

`run()`:
```
busy = true
try {
  if (mode == "hand") {
    if (heroCards.length != 2 || vill.isEmpty) return;
    result = await engine.equityVsRange(heroCards, board, vill.toList(), 5000);
        // exact enumeration when board has >= 4 cards, else 5000 Monte-Carlo trials
  } else {
    heroCombos = expand(hero, board); villCombos = expand(vill, board);
    if (heroCombos.isEmpty || villCombos.isEmpty) return;
    result = await engine.equityRangeVsRange(heroCombos, board.map(cardToInt), villCombos, 5000);
  }
} finally { busy = false }
```

Blocker info (hand mode only, needs 2 hero cards and a non-empty villain range):
```
all      = expand(vill, board).length
withHero = expand(vill, [...board, ...heroCards]).length
if (all == 0) null else { removed: all - withHero, all }
```

Result panel (shown when `result != null`; fades/slides up):
- Row: **"Your equity"** (semibold) left; right mono ~18 px extra-bold gold-light `fmtPct(result.equity)`.
- A 12 px-tall rounded stacked bar: green `win/samples`, amber `tie/samples`, red `lose/samples` widths.
- Row of small muted stats: `Win {fmtPct(win/samples)}`, `Tie {fmtPct(tie/samples)}`, `Lose {fmtPct(lose/samples)}` (the words Win/Tie/Lose coloured good/warn/bad) and, right-aligned faint:
  `"{samples with thousands separator} matchups · exact"` when `result.exact`, else `"{samples} trials · ±{(2 * se * 100).toStringAsFixed(1)}%"` (e.g. `5,000 trials · ±1.4%`).
- If `blockerInfo != null && removed > 0`, a muted line: **"Blockers:"** (semibold gold-light) followed by
  `" your cards remove {removed} of {all} opponent combos ({fmtPct(removed / all)}) — holding their cards makes their strong hands rarer."`

Board breakdown (shown whenever `board.length >= 3`, independent of `result`), a 2-column grid:
- In range mode, if `hero` non-empty: `RangeBoardBreakdown(title: "Your range on this board", range: hero, board)`.
- If `vill` non-empty: `RangeBoardBreakdown(title: "Opponent's range on this board", range: vill, board, dead: mode == "hand" ? heroCards : [])`.

### 12.7 RangeBoardBreakdown and `breakdownRange`

Pure function (export it separately; unit-test it):

```dart
class Breakdown { Map<int,int> catCount; int flushDraws; int oesds; int total; }

Breakdown breakdownRange(Set<String> range, List<String> board, [List<String> dead = const []]) {
  final boardInts = board.map(cardToInt).toList();
  final blocked = {...board, ...dead}.map(cardToInt).toSet();
  final catCount = <int,int>{};
  int flushDraws = 0, oesds = 0, total = 0;
  for (final label in range) {
    for (final (a, b) in labelToCombos(label)) {
      final ai = cardToInt(a), bi = cardToInt(b);
      if (blocked.contains(ai) || blocked.contains(bi)) continue;
      total++;
      final cat = evaluateInts([ai, bi, ...boardInts]).category;   // best 5-of-(2+board) category
      catCount[cat] = (catCount[cat] ?? 0) + 1;
      if (board.length < 5) {
        final d = drawFlags((ai, bi), boardInts);
        if (d.flushDraw) flushDraws++;
        if (d.oesd) oesds++;
      }
    }
  }
  return Breakdown(catCount, flushDraws, oesds, total);
}
```

`drawFlags` — deliberately simple heuristics, reproduce exactly (including their quirks):

```dart
({bool flushDraw, bool oesd}) drawFlags((int,int) hole, List<int> boardInts) {
  final all = [hole.$1, hole.$2, ...boardInts];
  final suits = [0,0,0,0];
  int mask = 0;
  for (final c in all) { suits[c & 3]++; mask |= 1 << ((c >> 2) + 2); }   // bits 2..14 = ranks 2..A
  final holeSuits = [hole.$1 & 3, hole.$2 & 3];
  // flush draw: exactly 4 of one suit among hole+board AND at least one hole card is of that suit
  final flushDraw = [0,1,2,3].any((si) => suits[si] == 4 && holeSuits.contains(si));
  if (mask & (1 << 14) != 0) mask |= 1 << 1;                                // ace also plays low (bit 1)
  int run = 0, best = 0;
  for (int r = 1; r <= 14; r++) { run = (mask & (1 << r)) != 0 ? run + 1 : 0; if (run > best) best = run; }
  return (flushDraw: flushDraw, oesd: best >= 4);   // 4+ consecutive ranks anywhere in hole+board
}
```

Quirks to preserve: `oesd` is true for any 4-in-a-row of distinct ranks among all cards,
so it also fires for a made straight (5 in a row), for a one-ended A-K-Q-J or A-2-3-4, and
even when the hole cards don't participate in the run. `flushDraw` requires exactly four
of a suit (a made flush with 5 is not a "draw"). Card int encoding is `rankIndex*4 + suitIndex`
with ranks `2..A → 0..12` and suits `c d h s → 0..3` (§13.4).

Widget `RangeBoardBreakdown({ title, range, board, dead = [] })`:
- Returns nothing if `board.length < 3 || range.isEmpty`, or if `total == 0`.
- Category buckets in this fixed order, showing only non-zero ones:
  `StraightFlush(8), Quads(7), FullHouse(6), Flush(5), Straight(4), Trips(3), TwoPair(2), Pair(1), HighCard(0)`
  with display names `Straight Flush, Four of a Kind, Full House, Flush, Straight, Three of a Kind, Two Pair, Pair, High Card`.
- Tone (bar colour): category ≥ Straight → good (green); ≥ Pair → gold; High Card → ink-500 (grey).
- `max = max(bucket.combos)`; each bar's width = `combos / max * 100 %` (so the biggest bucket is always full width).
- Layout: rounded 12 px card (line border, ink-850, 12 px padding). Header: title (~12.8 px semibold) left, faint ~10.9 px `"{total} combos on {board.join(" ")}"` right (e.g. `183 combos on Ks 9d 4c`). Rows (~11.5 px): label in an 86 px column (muted), a 10 px-tall rounded track with the tone-coloured fill, then a 56 px right-aligned mono `fmtPct(combos / total)`.
- If `board.length < 5` and either count is > 0, a footer row (faint ~11.2 px, 16 px gaps): `"Flush draws: {fmtPct(flushDraws / total)}"` if > 0 and `"Open-enders: {fmtPct(oesds / total)}"` if > 0.

---

## 13. Engine contracts the curriculum depends on

These functions live in the engine subsystem (ported separately) but the Study tab's
observable output depends on their exact behaviour, so the contract is restated here.

### 13.1 `topPercentRange(pct)` — Chen-formula strength ordering

```dart
double chenScore(String label) {
  int rankValue(String r) => RANKS.indexOf(r) + 2;             // '2'..'A' → 2..14
  double high(int v) => v == 14 ? 10 : v == 13 ? 8 : v == 12 ? 7 : v == 11 ? 6 : v / 2;
  final kind = kindOf(label);
  final hi = rankValue(label[0]);
  if (kind == pair) return max(5, high(hi) * 2);
  final lo = rankValue(label[1]);
  var score = high(hi);
  if (kind == suited) score += 2;
  final gap = hi - lo - 1;
  if (gap == 1) score -= 1; else if (gap == 2) score -= 2; else if (gap == 3) score -= 4; else if (gap >= 4) score -= 5;
  if (gap <= 1 && hi < 12) score += 1;                          // straight bonus: 0/1 gap and both below Queen
  return score;
}

List<RankedHand> rankedHands() => allLabels()          // 169 labels in grid order (row-major)
    .map((l) => (label: l, score: chenScore(l), combos: comboCount(l)))
    .sortedBy: score desc, then kind (pair < suited < offsuit), then high-card rank desc.
    // The sort must be STABLE (JS Array.sort is stable): remaining ties keep grid order.

Set<String> topPercentRange(num pct) {
  final target = clamp(pct, 0, 100) / 100 * 1326;
  final out = <String>{}; var acc = 0;
  for (final h in rankedHands()) { if (acc >= target) break; out.add(h.label); acc += h.combos; }
  return out;   // insertion order = strength order
}
```

Note the loop adds a hand *before* checking whether it overshoots, so the result is the
smallest strength-prefix whose combo total reaches the target (e.g. 15 % → 204 combos = 15.4 %).
`topPercentRange(100).length == 169`, `rankedHands()[0].label == "AA"`.

The full ranked order (1-based rank: label (score)) — pin this list in a Dart test; the
golden file `scripts/golden/charts.json` (`ranked`: array of 169 labels; `topPct`: object
`"1".."100"` → sorted label arrays) is the mechanical source for all 100 percentages:

```
1:AA(20) 2:KK(16) 3:QQ(14) 4:JJ(12) 5:AKs(12) 6:AQs(11) 7:TT(10) 8:AJs(10) 9:KQs(10) 10:AKo(10)
11:99(9) 12:KJs(9) 13:QJs(9) 14:JTs(9) 15:AQo(9) 16:88(8) 17:ATs(8) 18:KTs(8) 19:QTs(8) 20:J9s(8)
21:T9s(8) 22:AJo(8) 23:KQo(8) 24:98s(7.5) 25:77(7) 26:A9s(7) 27:A8s(7) 28:A7s(7) 29:A6s(7) 30:A5s(7)
31:A4s(7) 32:A3s(7) 33:A2s(7) 34:Q9s(7) 35:T8s(7) 36:87s(7) 37:KJo(7) 38:QJo(7) 39:JTo(7) 40:97s(6.5)
41:76s(6.5) 42:66(6) 43:K9s(6) 44:J8s(6) 45:86s(6) 46:65s(6) 47:ATo(6) 48:KTo(6) 49:QTo(6) 50:J9o(6)
51:T9o(6) 52:75s(5.5) 53:54s(5.5) 54:98o(5.5) 55:55(5) 56:44(5) 57:33(5) 58:22(5) 59:K8s(5) 60:K7s(5)
61:K6s(5) 62:K5s(5) 63:K4s(5) 64:K3s(5) 65:K2s(5) 66:Q8s(5) 67:T7s(5) 68:64s(5) 69:43s(5) 70:A9o(5)
71:A8o(5) 72:A7o(5) 73:A6o(5) 74:A5o(5) 75:A4o(5) 76:A3o(5) 77:A2o(5) 78:Q9o(5) 79:T8o(5) 80:87o(5)
81:96s(4.5) 82:53s(4.5) 83:32s(4.5) 84:97o(4.5) 85:76o(4.5) 86:Q7s(4) 87:Q6s(4) 88:Q5s(4) 89:Q4s(4) 90:Q3s(4)
91:Q2s(4) 92:J7s(4) 93:85s(4) 94:42s(4) 95:K9o(4) 96:J8o(4) 97:86o(4) 98:65o(4) 99:74s(3.5) 100:75o(3.5)
101:54o(3.5) 102:J6s(3) 103:J5s(3) 104:J4s(3) 105:J3s(3) 106:J2s(3) 107:T6s(3) 108:63s(3) 109:K8o(3) 110:K7o(3)
111:K6o(3) 112:K5o(3) 113:K4o(3) 114:K3o(3) 115:K2o(3) 116:Q8o(3) 117:T7o(3) 118:64o(3) 119:43o(3) 120:95s(2.5)
121:52s(2.5) 122:96o(2.5) 123:53o(2.5) 124:32o(2.5) 125:T5s(2) 126:T4s(2) 127:T3s(2) 128:T2s(2) 129:84s(2) 130:Q7o(2)
131:Q6o(2) 132:Q5o(2) 133:Q4o(2) 134:Q3o(2) 135:Q2o(2) 136:J7o(2) 137:85o(2) 138:42o(2) 139:94s(1.5) 140:93s(1.5)
141:92s(1.5) 142:73s(1.5) 143:74o(1.5) 144:83s(1) 145:82s(1) 146:62s(1) 147:J6o(1) 148:J5o(1) 149:J4o(1) 150:J3o(1)
151:J2o(1) 152:T6o(1) 153:63o(1) 154:72s(0.5) 155:95o(0.5) 156:52o(0.5) 157:T5o(0) 158:T4o(0) 159:T3o(0) 160:T2o(0)
161:84o(0) 162:94o(-0.5) 163:93o(-0.5) 164:92o(-0.5) 165:73o(-0.5) 166:83o(-1) 167:82o(-1) 168:62o(-1) 169:72o(-1.5)
```

### 13.2 `chartToSet(chart, min = 0.5)` and the pre-flop charts

`PREFLOP_100` (file `src/data/preflop.ts`, auto-generated from `scripts/preflop_gen.ts`) has the schema:

```
PreflopCharts { rfi: { UTG, MP, CO, BTN, SB: ChartFreqs }, vsRfi: { "<pos>_vs_<opener>": { threebet: ChartFreqs, call: ChartFreqs } } }
ChartFreqs = Map<HandLabel, double 0..1>   // frequency the hand takes that action; absent = 0
```

`chartToSet(chart, min)` = `{ label | chart[label] >= min }` in chart key order. The
curriculum uses only these three charts; they are small enough to embed verbatim:

`rfi.UTG` (35 entries):
```
22:1 33:1 44:1 55:1 66:1 77:1 88:1 99:1 TT:1 JJ:1 QQ:1 KK:1 AA:1 A9s:1 ATs:1 AJs:1 AQs:1 AKs:1
A5s:0.5 A4s:0.5 A3s:0.5 A2s:0.5 KTs:1 KJs:1 KQs:1 QTs:1 QJs:1 JTs:1 T9s:1 98s:0.5
ATo:1 AJo:1 AQo:1 AKo:1 KQo:1
```
→ `chartToSet` at 0.5 keeps all 35 (206 combos, 15.5 %).

`rfi.BTN` (97 entries):
```
22:1 33:1 44:1 55:1 66:1 77:1 88:1 99:1 TT:1 JJ:1 QQ:1 KK:1 AA:1
A2s:1 A3s:1 A4s:1 A5s:1 A6s:1 A7s:1 A8s:1 A9s:1 ATs:1 AJs:1 AQs:1 AKs:1
K2s:1 K3s:1 K4s:1 K5s:1 K6s:1 K7s:1 K8s:1 K9s:1 KTs:1 KJs:1 KQs:1
Q4s:1 Q5s:1 Q6s:1 Q7s:1 Q8s:1 Q9s:1 QTs:1 QJs:1 Q3s:0.5 Q2s:0.5
J7s:1 J8s:1 J9s:1 JTs:1 J6s:0.5 J5s:0.5 T7s:1 T8s:1 T9s:1 96s:1 97s:1 98s:1 86s:1 87s:1 75s:1 76s:1
64s:0.5 65s:0.5 54s:1 53s:0.5 43s:0.5
A2o:1 A3o:1 A4o:1 A5o:1 A6o:1 A7o:1 A8o:1 A9o:1 ATo:1 AJo:1 AQo:1 AKo:1
K8o:1 K9o:1 KTo:1 KJo:1 KQo:1 K7o:0.5 K6o:0.5 K5o:0.5 Q9o:1 QTo:1 QJo:1 Q8o:0.5 J9o:1 JTo:1 J8o:0.5 T9o:1 T8o:0.5 98o:0.5
```
→ all 97 kept (654 combos, 49.3 %).

`vsRfi.BTN_vs_CO.threebet` (16 entries):
```
TT:1 JJ:1 QQ:1 KK:1 AA:1 AJs:1 AQs:1 AKs:1 AKo:1 AQo:0.5 A5s:0.5 A4s:0.5 A3s:0.5 KQs:0.5 76s:0.25 65s:0.25
```
→ at min 0.4: 14 labels (drops `76s`, `65s`), 82 combos, 6.2 %.

### 13.3 Notation helpers

- `RANKS = 2 3 4 5 6 7 8 9 T J Q K A` (ascending), `RANKS_DESC` = reverse, `SUITS = c d h s`.
- `labelAt(row, col)`: `hi = RANKS_DESC[min(row,col)]`, `lo = RANKS_DESC[max(row,col)]`; `row == col → "$hi$hi"`, `col > row → "$hi${lo}s"`, else `"$hi${lo}o"`.
- `kindOf(label)`: length 2 → pair; ends with `s` → suited; else offsuit.
- `comboCount(label)`: pair 6, suited 4, offsuit 12. `combosInSet(labels)` = sum. `TOTAL_COMBOS = 1326`.
- `allLabels()`: row-major over the 13×13 grid (`AA AKs AQs … A2s AKo KK KQs … 22`).
- `labelToCombos(label)` ordering (matters only for determinism of seeded sampling):
  - pair: for `i < j` over SUITS: `[hi+SUITS[i], hi+SUITS[j]]` → `cd cH cs dh ds hs` (6).
  - suited: for each suit `s`: `[hi+s, lo+s]` (4).
  - offsuit: for `s1` in SUITS, `s2` in SUITS, `s1 != s2`: `[hi+s1, lo+s2]` (12).

### 13.4 Card ints

`cardToInt("Ah") = RANKS.indexOf('A') * 4 + SUITS.indexOf('h') = 12*4 + 2 = 50`. `rank = (i >> 2) + 2` (2..14), `suit = i & 3`.

### 13.5 `evaluateInts(List<int> cards) → { category, score, name }`

Best 5-card hand from 5–7 ints. `category` uses the enum `HighCard 0, Pair 1, TwoPair 2,
Trips 3, Straight 4, Flush 5, FullHouse 6, Quads 7, StraightFlush 8`; `score` is a monotonic
integer comparable across hands. Only `category` (breakdown) and `score` (equity) are used here.

### 13.6 Equity functions

```dart
class EquityResult { double equity; int win, tie, lose, samples; double se; bool exact; }
// equity = (win + tie/2) / samples  (or the pot-share sum / samples for equityVsField)
// se = sqrt(max(equity*(1-equity), 1e-9) / samples) when sampled; 0 when exact
// samples == 0 (no valid villain combos) → equity 0.5, se 0, exact false
```

- `equityVsRange(hero: [Card,Card], board, range: List<HandLabel>, iters = 1500, seed?)` — the UI-facing wrapper expands labels to combos, drops combos clashing with hero/board, then: if `board.length >= 4` **enumerate exactly** every (combo × runout) and return `exact: true`; else run `iters` Monte-Carlo trials, each picking a uniform villain combo and a uniform runout. The calculator calls it with `iters = 5000`.
- `equityRangeVsRange(heroCombos, boardInts, villCombos, iters = 3000, seed?)` — always sampled (never exact). Each trial: pick a hero combo uniformly, pick a villain combo uniformly, re-pick villain up to 8 times if it shares a card with hero; if still clashing **skip the trial** (it is not counted in `samples`), else deal the runout and compare. The calculator calls it with `iters = 5000`, so `samples` may be < 5000 when ranges overlap heavily (e.g. AA vs AA).
- `equityVsField(hero, board, numOpponents, iters = 1500, seed?)` — `n = clamp(floor(numOpponents), 1, 8)`; each trial deals `2n` opponent cards then the runout; hero's share is 1 if best, 0 if beaten, `1/(tied+1)` on a top tie; `equity` = mean share. The trainer calls it with `iters = 1200`.
- RNG: `mulberry32(seed)` when a seed is provided, otherwise the platform RNG. The Study widgets never pass a seed, so their Monte-Carlo outputs are nondeterministic by design.
- Backend routing (`engineClient`): native Rust under Tauri for `equityVsRange`/`equityVsField`; a Web Worker running the TS mirror otherwise; `equityRangeVsRange` has no Rust command and always runs in the worker. Results are asynchronous; the UI shows a busy state. For Flutter: run in an isolate (or FFI to `poker-core`); the Rust twin exposes `equity_vs_range(hero:[u32;2], board:&[u32], range:&[[u32;2]], iters:u32, seed:Option<u64>)` and `equity_vs_field(hero, board, num_opponents:u32, iters, seed)` with identical semantics.

---

## 14. Expected values to pin in Dart tests

### 14.1 `topPercentRange` sets (strength order; size / combos / actual %)

| pct | labels | combos | % | set |
|---|---|---|---|---|
| 10 | 23 | 138 | 10.4 | AA KK QQ JJ AKs AQs TT AJs KQs AKo 99 KJs QJs JTs AQo 88 ATs KTs QTs J9s T9s AJo KQo |
| 14 | 35 | 188 | 14.2 | …(10 % set)… 98s 77 A9s A8s A7s A6s A5s A4s A3s A2s Q9s T8s |
| 15 | 37 | 204 | 15.4 | …(14 % set)… 87s KJo |
| 19 | 45 | 254 | 19.2 | …(15 % set)… QJo JTo 97s 76s 66 K9s J8s 86s |
| 20 | 47 | 270 | 20.4 | …(19 % set)… 65s ATo |
| 27 | 58 | 362 | 27.3 | …(20 % set)… KTo QTo J9o T9o 75s 54s 98o 55 44 33 22 |
| 40 | 80 | 538 | 40.6 | …(27 % set)… K8s K7s K6s K5s K4s K3s K2s Q8s T7s 64s 43s A9o A8o A7o A6o A5o A4o A3o A2o Q9o T8o 87o |
| 45 | 91 | 598 | 45.1 | …(40 % set)… 96s 53s 32s 97o 76o Q7s Q6s Q5s Q4s Q3s Q2s |
| 55 | 110 | 738 | 55.7 | …(45 % set)… J7s 85s 42s K9o J8o 86o 65o 74s 75o 54o J6s J5s J4s J3s J2s T6s 63s K8o K7o |

(Each set is a prefix of the ranked list in §13.1; "…" means the previous row's set.)
Also: `topPercentRange(100).length == 169`; `combosInSet(allLabels()) == 1326`; `labelToCombos("AKs").length == 4`.

### 14.2 `chartToSet` sets

- `chartToSet(rfi.UTG)` → 35 labels, 206 combos (the whole chart, §13.2).
- `chartToSet(rfi.BTN)` → 97 labels, 654 combos.
- `chartToSet(vsRfi.BTN_vs_CO.threebet, 0.4)` → `TT JJ QQ KK AA AJs AQs AKs AKo AQo A5s A4s A3s KQs` (14 labels, 82 combos). With the default 0.5 it is the same set (no entries between 0.4 and 0.5 exist); with 0.25 it would add `76s 65s`.

### 14.3 Quiz keys — `hashSeed(q)` for all 34 questions (curriculum order)

```
 1  617105294   Which hand wins: a flush or a straight?
 2  2008304561  You hold A♦Q♣ on a board of A♠ K♦ 4♥ 9♣ 2♠. What's your hand?
 3  4116581697  A player is 45/7. What kind of opponent is this?
 4  1094179878  Can a player have a PFR higher than their VPIP?
 5  2239394530  You flop a flush draw (9 outs). Roughly what's your equity by the river?
 6  4216001583  On the turn you have a gutshot (4 outs). Your equity?
 7  2584359107  KK vs 99 all-in pre-flop — about how often does KK win?
 8  2891277353  AK vs QQ pre-flop — who's ahead?
 9  1568364613  The pot is 10 bb and your opponent bets 5 bb. What equity do you need to call?
10  4138432920  A pot-sized bet always offers you what pot odds to call?
11  3318780267  Implied odds are largest when…
12  593661914   Which hand suffers most from reverse-implied odds?
13  4018534960  A pot-sized bluff needs your opponent to fold roughly how often to break even?
14  3147454345  With a polarized range (best possible hands or bluffs), you should bet…
15  1591037257  The pot is 12 bb and your opponent bets 6 bb (half pot). Roughly how often must you continue so they can't bluff any two cards profitably?
16  196823071   A Calling Station almost never bluffs. Which number should drive your call/fold decision vs their river bet?
17  163546800   Bigger bets mean your MDF…
18  2458647031  Which hand type makes the best check-raise BLUFF on a 8♠7♠3♦ flop?
19  2186033529  Why is the check-raise strongest OUT of position?
20  2736866688  How many combos of pocket Aces (AA) are there before any cards are dealt?
21  4257061044  You hold A♠. How many combos of AA can your opponent now have?
22  752656569   How many combos does an offsuit hand like KQo have?
23  736915909   A call (rather than a raise) usually removes which hands from a range?
24  3678871636  A tight player check-raises the river. Their range is best described as…
25  3211098311  As more players enter the pot, your continuing range should get…
26  3396015054  Multiway, should you bluff more or less than heads-up?
27  4208627659  A high SPR means you should commit your stack with…
28  2161957192  A 3-bet pot tends to create a…
29  1658599676  In a 3-bet pot at SPR ~4 you hold A♥K♦ and flop K♠8♦3♣. Your default plan is…
30  723546982   Which hand LOSES the most value moving from a single-raised pot to a 3-bet pot?
31  2717033830  Which hand realizes its raw equity BEST?
32  1260342208  You're getting exactly break-even pot odds out of position with a weak offsuit hand. The call is…
33  878263801   You river a weak top pair. Your opponent (a Nit who never bluffs) bets the pot. Your hand beats bluffs but loses to all their value hands. Call or fold?
34  3208885858  A flush draw (9 outs) on the TURN is worth roughly what equity?
```
(Suit glyphs are single UTF-16 code units U+2660–U+2666; "…" is U+2026; apostrophes are ASCII `'`.)

### 14.4 `breakdownRange` / `drawFlags` / blockers

`breakdownRange` (catCount shown as `{category: combos}`):

| range | board | dead | total | catCount | flushDraws | oesds |
|---|---|---|---|---|---|---|
| chartToSet(rfi.UTG) | Ks 9d 4c | — | 183 | {Trips 9, Pair 102, HighCard 72} | 0 | 0 |
| chartToSet(rfi.UTG) | Ks 9d 4c | Ah Kh | 149 | {Trips 7, Pair 85, HighCard 57} | 0 | 0 |
| topPercentRange(15) | Jh Th 9s | — | 174 | {Straight 20, Trips 9, TwoPair 7, Pair 78, HighCard 60} | 14 | 67 |
| {AKs, QQ} | Qh 7h 2s 3d 8c | — | 7 | {Trips 3, HighCard 4} | 0 (river: not computed) | 0 |

Rendered example for row 1: header `183 combos on Ks 9d 4c`; rows `Three of a Kind 5%`
(bar 9/102 of full width, green), `Pair 56%` (full width, gold), `High Card 39%` (72/102, grey); no draws line.

`drawFlags(hole, board)`:

| hole | board | flushDraw | oesd |
|---|---|---|---|
| Ah Kh | Qh 7h 2s | true | false |
| As Kd | Qh 7h 2s | false | false |
| 9s 8s | 7h Td 2c | false | true |
| 9s 8s | 7h Jd 2c | false | false (gutshot only) |
| Ah 2d | 3c 4s 9h | false | true (A-2-3-4 wheel run) |
| Ad Kd | Qh Jh 9h | false (only 3 hearts, 2 diamonds) | true (A-K-Q-J) |
| Ah Kd | Qh Jh Th | true (Ah + 3 hearts) | true (made straight) |
| 9s 8s | 7h 6d Tc 5c | false | true (made straight) |

Blocker counts (`expand`): `chartToSet(rfi.BTN)` on an empty board = 654 combos; with hero `Ah Kh` dead → 562 (removed 92 = 14 %).
`chartToSet(rfi.UTG)` on `Ks 9d 4c` = 183; with hero `As Kd` dead → 149 (removed 34 = 19 %).

### 14.5 Seeded equity references (TypeScript mirror, `mulberry32`; only reproducible if the Dart RNG and sampling order are ported bit-for-bit — otherwise assert tolerance bands)

- `equityVsRange(AhKh, [], QQ combos, 5000, seed 7)` → equity 0.4555 (win 2269, tie 17, lose 2714, se 0.00704, exact false).
- `equityVsRange(AhKh, [Qs 7d 2c 3h], {QQ, AA} combos, 5000, seed 7)` → exact: samples 264, win 0, tie 0, lose 264, equity 0, se 0, exact true (turn → enumeration: 2 unblocked QQ combos… actually 3 QQ + 3 AA = 6 combos × 44 rivers = 264).
- `equityRangeVsRange(AKs combos, [], QQ combos, 5000, seed 7)` → equity 0.4652 (win 2317, tie 18, lose 2665).

### 14.6 Existing script tests (Node) touching this subsystem

- `scripts/multiway_test.ts` (`node --experimental-transform-types scripts/multiway_test.ts`), 8000-trial runs:
  - `equityVsField(AhAd, [], 1)` ≈ 0.85 (±0.03); AA equity strictly decreases from 1 → 2 → 4 opponents.
  - `equityVsField(AhKh, [Ad Kc 7s], 1) > 0.8` and `> equityVsField(…, 3)`.
  - Results within [0, 1].
  - `equityRangeVsRange(AA, [], all 1326 combos)` ≈ 0.85 (±0.03); `equityRangeVsRange(AKs, [], QQ)` ≈ 0.46 (±0.04).
- `scripts/engine_test.ts`: `combosInSet(allLabels()) == 1326`; `labelToCombos("AKs").length == 4`; `rankedHands()[0].label == "AA"`; `topPercentRange(100).size == 169`.
- `scripts/golden_test.ts` vs `scripts/golden/charts.json`: the 169-label `ranked` order and every `topPct[1..100]` set must match exactly (this is the guard that "every chart derives from").

No script tests exist for `Quiz`, `studyStore`, `breakdownRange`, `drawFlags`, or the calculators; the values in §12 and §14.4 were produced by running the TypeScript for this document and should become the Dart unit tests.

---

## 15. Porting notes, invariants and open questions

Invariants:

1. `ALL_LESSON_IDS.length == 31`; ids are stable and referenced by onboarding and drill deep links (§1.2).
2. Lesson completion is explicit ("Mark complete"); "Next lesson" and quizzes never change `completed`.
3. Quizzes are optional; their only side effect is `recordQuiz`. Stored quiz results only influence question ordering and the "You missed N of these before" line.
4. Widget state is per-visit (re-created when the lesson changes); only `completed` and `quizResults` persist.
5. `GLOSSARY` is the single source of truth for hover definitions and the cheat-sheet glossary — do not duplicate the strings.
6. Per TONE.md, text is beginner-first; keep the wording exactly as quoted (it was user-tested).

Design decisions the mobile port must make:

- **Hover → tap.** `Term` tooltips, the multiway bar tooltips and the "Hover a bot's HUD…" / "Hover the dotted terms…" sentences assume a pointer. Decide on tap-to-reveal and adjust those two sentences ("Tap") — a deliberate copy change, flag it.
- **Two-pane layout.** The 310 px path nav + 760 px content does not fit a phone; a list → detail flow with the progress bar on the list and a "Next lesson" footer on the detail is the natural mapping.
- **13×13 matrices at 320–440 px** with 2 px gaps and painting-by-drag need touch handling; the read-only 360 px diagrams in lessons must shrink to the viewport (the source caps at `maxWidth: 100%`).
- **52-card pickers** (2 in the equity calculator) are 28 px buttons — too small for touch; regroup by suit or enlarge.
- **Async equity.** `Calculate equity` (5000 trials) and the multiway trainer (5 × 1200 trials on every scenario tap) must run off the UI thread (isolate or FFI to `poker-core`). The Rust core has no range-vs-range command; either add one or port the TS sampler (§13.6).
- **Number formatting** must mimic JS (`7 bb` vs `6.5 bb`, `toFixed(1)` → `23.0`, `toLocaleString` thousands separators in the trials line).
- The `Level.blurb` strings are defined but never rendered in the current UI; the mobile list view may use them as subtitles.

Open questions for the product owner:

- The Opening Ranges diagram titles say "~15%" / "~45%" while the charts are 15.5 % / 49.3 % wide; the Range Explorer preset "UTG ~14%" uses the Chen-formula range while the drills use the authored chart (206 vs 188 combos). Keep as-is for parity or reconcile?
- Equity calculator: should the board picker disable cards already chosen as hero's exact hand (currently only the reverse is enforced)?
- Should stale `completed` ids (from renamed lessons) be filtered on load, and should `toggle` (un-complete) be exposed in the UI?
