# All-In · Poker Dojo — Mobile UX proposal "Habit" (learning-loop first)

Target: Flutter, iOS + Android phones, portrait-first. Reference frame 390×844 pt
(iPhone 15/16 class, top safe area 59, bottom safe area 34). Must also work at 360×780
(compact Android, status bar 24–32, gesture inset 16–24) and on large phones (430×932).

Angle of this proposal: the app is a **daily practice loop**, not a poker client with a
course bolted on. The first screen answers "what should I do in the next five minutes?",
every activity is bite-sized with a clean stopping point, the Coach is one consistent
character across the whole app, and progress is something you can feel — quietly.
Streaks exist, guilt does not.

Sources read for this proposal: `README.md`, `TONE.md`, `Notes.md`, `src/views/*.tsx`,
`src/components/{play,table,coach,range,drills,study,stats,ui}/*.tsx`, all stores
(`gameStore` play loop, `drillStore` Elo + modes, `reviewStore`/`leakStore` SRS,
`goalStore` daily goal + quiet streak, `studyStore`, `noteStore`, `settingsStore`),
`src/lib/{srs,leaks,format}.ts`, `src/engine/puzzles.ts` (frame/option/rationale text),
`src/styles/tokens.css`, and `docs/port/*.md`.

Copy in quotes is either verbatim from the desktop app (keep it — it has been user-tested
against TONE.md) or newly proposed and marked *(new)*.

---

## 1. Design principles

1. **Five minutes, well spent.** "Today" is a plan, not a menu. It always proposes one
   next thing with a time estimate. Every loop — clear review, a set of 10 drills, one
   lesson, a 20-hand session — is designed to finish in under six minutes and to end on a
   summary card that is a natural place to stop. Nothing is endless by default; "keep
   going" is always one tap away.

2. **Thumb-first felt.** Anything pressed every few seconds (Fold / Check / Call / Raise,
   Next action, Next hand, drill answers, Next spot) lives in the bottom 220 pt of the
   screen and is at least 56 pt tall. The top third of the screen holds only glanceable
   status and things you touch rarely (leave, coach notes, table options).

3. **One coach, one voice, three layers.** The Coach is a single character: same gold
   roundel avatar, same five verdict badges (Mistake / Thin spot / Reasonable / Nice play /
   Read), same note anatomy — plain English first, then "Show me the math", then
   "Expert detail" — on the table, in drill feedback, in the review queue, in the session
   debrief, and behind every stat explanation. Layer 1 is always visible; layers 2 and 3
   are expanders whose open/closed state is remembered ("sticky curiosity").

4. **Quiet progress.** The daily goal is a bar you fill, never a fire you keep alive. No
   push notifications in v1, no "streak at risk", no red dots for missed days, no
   confetti, no leaderboards. A streak is shown only when it is non-zero, in muted text,
   and it never counts down. The practice heatmap is the only place the past is visible,
   and it only ever adds squares.

5. **Judge the decision, not the person, not the result.** Verdicts (expected value) and
   results (big blinds won) are separate components that never share a colour scale in
   the same row. The session debrief leads with "How you played (before how it paid)".
   Wrong drill answers say what the choice costs, never what the player is.

6. **Nothing lives behind hover.** Every desktop tooltip — HUD hints, bb/100, WTSD,
   glossary terms, rating — becomes a ≥44 pt tap target that opens a definition popover or
   sheet. Long-press is only ever a shortcut for something that also has a visible tap
   path.

7. **Ranges are a touch surface.** The 13×13 matrix is a first-class finger-painting
   control: 27 pt cells, a loupe under the finger, per-cell haptic ticks, stroke-level
   undo, presets, and a live combo counter. It is never a scaled-down desktop grid.

---

## 2. Information architecture

### 2.1 Root tabs

Bottom tab bar, 49 pt + bottom safe area, five tabs, SF Symbols-style line icons with
filled active state in gold:

| Tab | Icon | What it is |
|---|---|---|
| **Today** | sun/chip | The plan: daily goal, due review, next lesson, quick session, Coach's note |
| **Play** | play | Table lobby (setup / resume) → full-screen session |
| **Drills** | target | Mode picker + stats → full-screen drill run |
| **Study** | book | Level path, tools, quick reference → lesson reader |
| **Progress** | stats | Lifetime stats, coaching review, hands, heatmap; gear → Settings |

Settings and About are not tabs (they are visited rarely). A gear icon in the Today and
Progress headers opens Settings as a push; About is a row inside Settings.

### 2.2 Presentation types (and the rule for choosing)

| Type | Behaviour | Use when |
|---|---|---|
| **Tab root** | Tab bar visible, scrolls | Browsing / choosing |
| **Push** | Slides from right, system back, tab bar hidden if it is a "reader" | Drilling into one item (lesson, hand detail, settings) |
| **Sheet** | Bottom sheet with detents S (30 %), M (60 %), L (92 %); scrim 55 %; swipe-down to dismiss; grabber | Context stays useful underneath (coach note over the table, drill feedback over the spot, definitions) |
| **Full-screen modal ("focus mode")** | Covers the tab bar; explicit Leave/Close; back gesture asks before losing state | Anything with a live state machine: a play session, a drill run, the guess-range painter, the hand replayer, the placement test, onboarding |
| **Popover** | Small anchored card ≤260 pt wide; tap outside to dismiss | One-line definitions (glossary term, HUD line, stat label) |

Rule: if the thing underneath is still meaningful while the new thing is open, use a
sheet. If the user is "inside" an activity with its own state, use focus mode. If it is a
single fact, use a popover.

### 2.3 Screen inventory

| ID | Screen | Type | Opened from |
|---|---|---|---|
| T0 | Today | tab root | tab |
| T1 | Coach's note detail | sheet M | T0 note card |
| P0 | Play lobby (table setup / resume / empty state) | tab root | tab |
| P1 | Table session | focus mode | P0 Start/Resume, T0 quick session |
| P1a | Session sheet (this session, your style, End session) | sheet M | P1 title tap |
| P1b | Table options (pace, coach, reveals, deck, hand log, leave) | sheet M | P1 ⋯ |
| P1c | Hand log | sheet L | P1 ticker tap, P1b |
| P1d | Seat sheet (archetype, HUD explained, read range, explain move) | sheet S/M | P1 seat tap |
| P1e | Coach note | sheet M→L (blocking: non-dismissable until Got it) | auto, coach chip, P1f |
| P1f | Coach notes list (this hand) | sheet M | P1 "Coach ·n" badge |
| P1g | Assumed range viewer | in-sheet push (L) | P1e "View their likely hands" |
| P2 | Guess range painter | focus mode | P1d, seat eye button |
| P2a | Peek result | same screen, state | P2 Peek |
| P3 | Hand-over results | inline overlay replacing action bar | auto |
| P4 | Session summary | focus mode | End session, bust |
| P5 | Leave table? | sheet S | P1 back/leave |
| D0 | Drills home (stats strip, mode cards, daily goal) | tab root | tab |
| D1 | Drill run (card stack) | focus mode | D0 mode card, T0 |
| D1a | Feedback | sheet M→L | auto on answer |
| D1b | Graded range | in-sheet expander | D1a |
| D1c | Set summary (after 10) | card in D1 | auto |
| D2 | Placement test | focus mode | onboarding, Settings |
| S0 | Study home (continue, path, tools, quick reference) | tab root | tab |
| S1 | Lesson reader | push (tab bar hidden) | S0, drill feedback, T0 |
| S1a | Definition popover | popover | any glossary term |
| S2 | Tools: Range explorer / Equity calculator / Pot-odds / Bluff / Multiway / Hand rankings | push | S0 tools grid, lessons |
| S3 | Quick reference + glossary (searchable) | push | S0 pinned row, S1a "More" |
| G0 | Progress home | tab root | tab |
| G1 | Stat explanation | sheet S | any stat tile / row |
| G2 | Hands list (filter by tag, imported) | push | G0 "All hands" |
| G3 | Hand replayer | focus mode | G2 row, P4 row, G0 recent |
| G4 | Hand note editor | sheet M | G2/G3/P4 note button |
| G5 | Import hands result | sheet M | G0/G2 Import |
| X0 | Settings | push | gear |
| X1 | About | push | X0 row |
| X2 | Reset all progress | sheet M | X0 |
| O0 | Onboarding tour (4 pages) | focus mode | first run, X0 "Run again" |
| O1 | Table tour coach-marks (3) | overlay | first P1 |

### 2.4 Navigation graph

```
                     ┌──────────── tab bar ────────────┐
   Today ──── Play ──── Drills ──── Study ──── Progress ──(gear)── Settings ── About
     │          │          │          │           │                   │
     │          ▼          ▼          ▼           ├─▶ Stat sheet      ├─▶ Reset sheet
     │     P0 Lobby    D0 Home    S0 Home         ├─▶ Hands list ─▶ Replayer ─▶ Note
     │          │          │          │           ├─▶ Import result     ▲
     │          ▼          ▼          ▼           └─▶ Recent hand ──────┘
     │     P1 Session  D1 Run    S1 Lesson ◀──────────────┐
     │      │  │  │       │  │        │                   │
     │      │  │  │       │  └─▶ D1a Feedback ─ "Read the lesson" ─┘ (returns to D1)
     │      │  │  │       └─▶ D1c Set summary
     │      │  │  └─▶ P1e Coach note ─▶ P1g Range viewer
     │      │  └─▶ P2 Guess painter ─▶ P2a Peek result ─▶ back to P1
     │      └─▶ P3 Hand-over ─▶ next hand │ P4 Summary ─▶ Replayer / Lobby
     │
     ├─▶ "Clear review" ─▶ D1 (mode: Review)
     ├─▶ "Continue lesson" ─▶ S1
     ├─▶ "Quick set" ─▶ D1 (mode: chosen)
     └─▶ "Play 20 hands" ─▶ P1 (uses saved table options)
```

Deep links (internal + URL scheme): `allin://today`, `allin://play`, `allin://drills/{mixed|pushfold|exploit|leaks}`,
`allin://study/{lessonId}`, `allin://progress`, `allin://hand/{startedAt}`. Drill feedback →
lesson is a push on top of the drill run; the system back returns to the same unanswered
or answered spot (the run state is preserved).

### 2.5 Focus-mode etiquette

- Focus modes hide the tab bar and own the bottom 220 pt.
- System back / edge-swipe inside a focus mode with live state opens a small sheet:
  "Leave the table?" — "Your session pauses; resume any time from Play." [Keep playing]
  [Leave]. The drill run leaves without asking if the current spot is unanswered (nothing
  is lost); a painted-but-not-peeked range asks "Discard your guess?".
- Interruptions (phone call, app backgrounded): the game loop pauses immediately; on
  return the same screen is shown with a one-line ticker "Paused — tap to continue".

---

## 3. Today (home / entry experience)

### 3.1 Purpose

Answer "what should I do in the next five minutes?" with one primary suggestion and two
alternates, show the daily goal as something being filled, and let the Coach say one
useful sentence.

### 3.2 Wireframe (390×844)

```
┌──────────────────────────────────────────────┐ 59  safe
│ Good evening                            [⚙]  │
│ Wednesday · 4 days in a row                   │  ← muted 13pt; hidden when streak = 0
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ Today                                    │ │
│ │ ████████████░░░░░░░░░░░░░░   8 of 20     │ │  ← bar 8pt, gold; label mono
│ │ drills · or 30 hands — either counts     │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ Next up                                      │  ← section label 13pt uppercase
│ ┌──────────────────────────────────────────┐ │
│ │ ◔ Clear your review               ~2 min │ │  ← PRIMARY card, gold border
│ │ 5 spots due · 2 are coach-flagged calls  │ │
│ │                          [ Start review ]│ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ▤ Continue: Pot Odds, Break-even & EV    │ │
│ │ Level 3 · 6 min read · 7/31 done         │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ◎ A set of 10 mixed spots         ~4 min │ │
│ │ Rating 1,082 · 71 % this week            │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ▶ Play 20 hands · 6-max · Coach on ~6 min│ │
│ │ Resume: 12 hands, +4.5 bb                │ │  ← only if a paused session exists
│ └──────────────────────────────────────────┘ │
│                                              │
│ ┌──────────────────────────────────────────┐ │
│ │ (C) Coach                                │ │
│ │ "You fold too often when you're getting  │ │
│ │  the right price — look for more +EV     │ │
│ │  calls." 3 of those spots are in review. │ │
│ │                          Show me why ›   │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ Practice                                     │
│ ▢▢▢▢▢ ▢▢▢▣▣ ▣▢▢▣▣ ▣▣▣▢▣ ▣▣■■■   5 weeks    │  ← 12pt cells; gold = goal met
│ 14 active days · gold = daily goal met       │
├──────────────────────────────────────────────┤
│  ● Today    ▶ Play    ◎ Drills   ▤ Study  ⌇  │ 49 + 34 safe
└──────────────────────────────────────────────┘
```

### 3.3 Plan logic (what appears, in what order)

Cards are built from live state, at most four shown, the first is styled primary:

1. **Review due** — if `dueCount > 0` (due leaks + due missed drills). Estimate = 20 s per
   spot, rounded up to the minute. Subtitle names the mix: "5 spots due · 2 are
   coach-flagged calls" *(new)*.
2. **Resume session** — if a session is paused (left the table with hands played).
3. **Continue lesson** — first incomplete lesson in path order, or the placement result's
   suggested lesson on the first day. Estimate = the lesson's `minutes`.
4. **Quick set** — 10 drills in the mode with the weakest recent accuracy (min 5 answers),
   otherwise Mixed. Subtitle shows rating and 7-day accuracy.
5. **Play 20 hands** — uses the saved table options. Estimate assumes Auto/Normal pace.

If the daily goal is already met, the primary card becomes a calm "Goal met — anything
else is a bonus" *(new)* header line above the same list; nothing is hidden and nothing
celebrates.

### 3.4 Coach's note

One sentence chosen from, in priority: a leak line from `leaksFromDecisions` (verbatim), the
read-accuracy line ("Your range reads are often off — drill Guess & Peek and the
Range-Building exercise."), yesterday's session debrief ("Costliest: a river call
(−2.1 bb) — it's in your Review queue."), or, with no data, "Play a session with the EV
Coach on and I'll start noticing patterns." *(new)*. "Show me why ›" opens T1: the
same sentence, the numbers behind it (layer 2), and a button to the relevant lesson or
review.

### 3.5 States

- **First run (no data):** goal bar at 0 with caption "Do 20 drills or play 30 hands to
  fill this — either counts" *(new)*; cards: Continue lesson (placement suggestion),
  Quick set, Play 20 hands; Coach card shows the no-data line; heatmap hidden until the
  first active day.
- **Goal met:** see 3.3.
- **Offline:** identical — everything is local.

---
