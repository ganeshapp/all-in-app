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
`src/styles/tokens.css`, and `docs/port/*.md` (`play-loop-and-coach`, `drill-ux-srs-leaks`,
`drills-charts-icm`, `study-curriculum`).

Copy in quotes is either verbatim from the desktop app (keep it — it has been user-tested
against TONE.md) or newly proposed and marked *(new)*. Sizes are in pt. Every tappable
thing is ≥ 44×44 pt unless explicitly called out as a paint surface (the range matrix).

Table of contents: 1 Principles · 2 Information architecture · 3 Today (home) · 4 Play ·
5 Drills · 6 Study · 7 Progress (stats) · 8 Onboarding · 9 Settings + About ·
10 Component library · 11 Motion + haptics · 12 Gestures + reachability · 13 Accessibility ·
14 Edge / empty / error states · 15 Feature disposition table.

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
   status and things you touch rarely (leave, coach notes, table options). Bot seats are
   read, not tapped, except to open one sheet.

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
   glossary terms, rating — becomes a ≥ 44 pt tap target that opens a definition popover or
   sheet. Long-press is only ever a shortcut for something that also has a visible tap
   path.

7. **Ranges are a touch surface.** The 13×13 matrix is a first-class finger-painting
   control: 26 pt cells, a loupe under the finger, per-cell haptic ticks, stroke-level
   undo, presets, and a live combo counter. It is never a scaled-down desktop grid.

---

## 2. Information architecture

### 2.1 Root tabs

Bottom tab bar, 49 pt + bottom safe area, five tabs, line icons with a filled active state
in gold. Labels always visible (no icon-only tabs).

| Tab | Icon | What it is |
|---|---|---|
| **Today** | sun/chip | The plan: daily goal, due review, next lesson, quick session, Coach's note |
| **Play** | play | Table lobby (setup / resume / recent sessions) → full-screen session |
| **Drills** | target | Mode picker + stats strip → full-screen drill run |
| **Study** | book | Level path, tools, quick reference → lesson reader |
| **Progress** | stats | Lifetime stats, coaching review, hands, heatmap; gear → Settings |

Settings and About are not tabs (they are visited rarely). A gear icon in the Today and
Progress headers opens Settings as a push; About is a row inside Settings.

### 2.2 Presentation types (and the rule for choosing)

| Type | Behaviour | Use when |
|---|---|---|
| **Tab root** | Tab bar visible, scrolls | Browsing / choosing |
| **Push** | Slides from right, system back, tab bar hidden if it is a "reader" | Drilling into one item (lesson, hand detail, settings) |
| **Sheet** | Bottom sheet with detents S (30 %), M (60 %), L (92 %); scrim 55 %; grabber; swipe-down to dismiss | Context stays useful underneath (coach note over the table, drill feedback over the spot, definitions) |
| **Full-screen modal ("focus mode")** | Covers the tab bar; explicit Leave/Close; back gesture asks before losing state | Anything with a live state machine: a play session, a drill run, the guess-range painter, the hand replayer, the placement test, onboarding |
| **Popover** | Small anchored card ≤ 260 pt wide; tap outside to dismiss | One-line definitions (glossary term, HUD line, stat label) |
| **Toast** | 44 pt pill at the top of the content area, 2.5 s, non-interactive except an optional action | Confirmations ("Hand history copied") |

Rule: if the thing underneath is still meaningful while the new thing is open, use a
sheet. If the user is "inside" an activity with its own state, use focus mode. If it is a
single fact, use a popover.

### 2.3 Screen inventory

| ID | Screen | Type | Opened from |
|---|---|---|---|
| T0 | Today | tab root | tab |
| T1 | Coach's note detail | sheet M | T0 note card |
| P0 | Play lobby (new session setup / resume / recent sessions / empty state) | tab root | tab |
| P0a | Table setup (seats, ante, pace, coach) | inline in P0 (expandable card) | P0 |
| P1 | Table session | focus mode | P0 "Deal me in" / "Resume", T0 "Play 20 hands" |
| P1a | Session sheet (this session, your style, read accuracy, End session) | sheet M | P1 title tap |
| P1b | Table options (pace, speed, EV coach, realistic reveals, four-colour deck, auto-deal) | sheet M | P1 "⋯" |
| P1c | Hand log | sheet L | P1 ticker tap, P1b row |
| P1d | Seat sheet (archetype, HUD explained, read their range, explain last move) | sheet S/M | P1 opponent seat tap |
| P1e | Coach note (blocking: non-dismissable until "Got it") | sheet M→L | auto, P1 coach chip, P1f |
| P1f | Coach notes list (this hand) | sheet M | P1 "Coach · n" badge |
| P1g | Assumed range viewer | in-sheet push (L) | P1e "View their likely hands" |
| P1h | Bet-size ruler | overlay on P1 (transient) | swipe-up on Raise, tap on the amount |
| P1i | Bet amount keypad | sheet S | P1h "Exact…" |
| P2 | Guess range painter | focus mode | P1d "Read their range", seat eye button |
| P2a | Peek result (score) | same screen, state | P2 "Peek" / "Peek & score" |
| P3 | Hand-over results | inline overlay replacing the action bar | auto at hand-over |
| P3a | Everyone's cards (learning reveal) | sheet L | P3 "See what everyone had" |
| P4 | Session summary | focus mode | End session, hero busts |
| P5 | Leave the table? | sheet S | P1 back / "‹" |
| D0 | Drills home (stat strip, mode cards, daily goal) | tab root | tab |
| D1 | Drill run (card stack, 10 per set) | focus mode | D0 mode card, T0 |
| D1a | Feedback | sheet M→L | auto on answer |
| D1b | Graded range | in-sheet expander | D1a |
| D1c | Set summary (after 10 or when the queue empties) | card in D1 | auto |
| D2 | Placement test | focus mode | onboarding, Settings |
| S0 | Study home (continue, level path, tools, quick reference) | tab root | tab |
| S1 | Lesson reader | push (tab bar hidden) | S0, drill feedback, T0, placement result |
| S1a | Definition popover | popover | any glossary term |
| S2 | Tools: Range explorer / Equity calculator / Pot odds / Bluff / Multiway / Hand rankings | push | S0 tools grid, lessons |
| S3 | Quick reference + glossary (searchable) | push | S0 pinned row, S1a "More" |
| G0 | Progress home | tab root | tab |
| G1 | Stat explanation | sheet S | any stat tile / row |
| G2 | Hands list (filter by tag, session, imported) | push | G0 "All hands" |
| G3 | Hand replayer | focus mode | G2 row, P4 row, G0 recent hand |
| G4 | Hand note editor | sheet M | G2 / G3 / P4 note button |
| G5 | Import hands (picker → progress → result) | sheet M | G0 / G2 "Import" |
| G6 | Export / share (session .txt, backup .json) | system share sheet | P4, G0, X0 |
| X0 | Settings | push | gear |
| X1 | About (how it works, methodology, roadmap, version) | push | X0 row |
| X2 | Reset all progress (typed confirm) | sheet M | X0 |
| O0 | Onboarding tour (4 pages) | focus mode | first run, X0 "Run again" |
| O1 | Table coach-marks (3) | overlay | first P1 |

### 2.4 Navigation graph

```
                     ┌──────────── tab bar ────────────┐
   Today ──── Play ──── Drills ──── Study ──── Progress ──(gear)── Settings ── About
     │          │          │          │           │                   │
     │          ▼          ▼          ▼           ├─▶ G1 Stat sheet   ├─▶ X2 Reset sheet
     │     P0 Lobby    D0 Home    S0 Home         ├─▶ G2 Hands ─▶ G3 Replayer ─▶ G4 Note
     │          │          │          │           ├─▶ G5 Import result   ▲
     │          ▼          ▼          ▼           └─▶ Recent hand ───────┘
     │     P1 Session  D1 Run    S1 Lesson ◀──────────────┐
     │      │  │  │       │  │        │ S1a popover ─▶ S3 │
     │      │  │  │       │  └─▶ D1a Feedback ─ "Read the lesson" ─┘ (returns to D1)
     │      │  │  │       └─▶ D1c Set summary ─▶ D0 | another set
     │      │  │  └─▶ P1e Coach note ─▶ P1g Range viewer
     │      │  └─▶ P2 Guess painter ─▶ P2a Peek result ─▶ back to P1
     │      └─▶ P3 Hand-over ─▶ P3a reveal | next hand | P4 Summary ─▶ G3 Replayer / P0
     │
     ├─▶ "Start review" ─▶ D1 (mode: Review)
     ├─▶ "Continue lesson" ─▶ S1
     ├─▶ "Quick set" ─▶ D1 (mode: chosen)
     └─▶ "Play 20 hands" / "Resume" ─▶ P1 (saved table options)
```

Deep links (internal + URL scheme): `allin://today`, `allin://play`,
`allin://drills/{mixed|pushfold|exploit|leaks}`, `allin://study/{lessonId}`, `allin://progress`,
`allin://hand/{startedAt}`. Drill feedback → lesson is a push on top of the drill run; the
system back returns to the same answered spot (the run state is preserved in memory).

### 2.5 Focus-mode etiquette

- Focus modes hide the tab bar and own the bottom 220 pt.
- System back / edge-swipe inside a focus mode with live state opens a small sheet:
  "Leave the table?" — "Your session pauses; resume any time from Play." [Keep playing]
  [Leave]. The drill run leaves without asking if the current spot is unanswered (nothing
  is lost); a painted-but-not-peeked range asks "Discard your guess?".
- Interruptions (phone call, app backgrounded): the game loop pauses immediately; on
  return the same screen is shown with a one-line ticker "Paused — tap to continue".
- **Session persistence (port requirement).** The desktop keeps a session in memory only.
  On mobile the session snapshot (table options, stacks, archetypes + dials, session
  counters, hand history, HUD counters) is written at every hand boundary. Leaving
  mid-hand abandons that hand (not counted, stacks restored to the hand's start); resuming
  deals a fresh hand. This is what makes "Resume: 12 hands, +4.5 bb" on Today possible.

---

## 3. Today (home / entry experience)

### 3.1 Purpose

Answer "what should I do in the next five minutes?" with one primary suggestion and two or
three alternates, show the daily goal as something being filled, and let the Coach say one
useful sentence.

### 3.2 Wireframe (390×844)

```
┌──────────────────────────────────────────────┐ 59  safe
│ Good evening                            [⚙]  │  ← display 28pt; gear 44pt target
│ Wednesday · 4 days in a row                   │  ← muted 13pt; hidden when streak = 0
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ Today                                    │ │
│ │ ████████████░░░░░░░░░░░░░░   8 of 20     │ │  ← bar 8pt, gold; label mono 15pt
│ │ drills · or 30 hands — either counts     │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ NEXT UP                                      │  ← section label 13pt uppercase, faint
│ ┌──────────────────────────────────────────┐ │
│ │ ◔ Clear your review               ~2 min │ │  ← PRIMARY card, gold 1.5pt border
│ │ 5 spots due · 2 are coach-flagged calls  │ │
│ │                          [ Start review ]│ │  ← 44pt button; whole card tappable
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
│ │ ▶ Resume your table               ~6 min │ │  ← "Play 20 hands · 6-max" when nothing
│ │ 12 hands, +4.5 bb · Coach on             │ │     is paused
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
│ PRACTICE                                     │
│ ▢▢▢▢▢ ▢▢▢▣▣ ▣▢▢▣▣ ▣▣▣▢▣ ▣▣■■■   5 weeks    │  ← 12pt cells, 3pt gaps; gold = goal met
│ 14 active days · gold = daily goal met       │
├──────────────────────────────────────────────┤
│  ● Today    ▶ Play    ◎ Drills   ▤ Study  ⌇  │ 49 + 34 safe
└──────────────────────────────────────────────┘
```

Card anatomy: 16 pt padding, 16 pt radius, icon 20 pt in a 32 pt gold-tinted square, title
17 pt semibold, subtitle 14 pt muted, time estimate mono 13 pt right-aligned. Minimum card
height 72 pt. The primary card additionally carries a 44 pt button so the action is
obvious to a first-day user; every other card is tappable as a whole.

### 3.3 Plan logic (what appears, in what order)

Cards are built from live state, at most four shown, the first is styled primary:

1. **Review due** — if `dueCount > 0` (due leaks + due missed drills). Estimate = 20 s per
   spot, rounded up to the minute. Subtitle names the mix: "5 spots due · 2 are
   coach-flagged calls" *(new)*.
2. **Resume session** — if a session snapshot exists with `hands > 0`.
3. **Continue lesson** — first incomplete lesson in path order, or the placement result's
   suggested lesson on the first day. Estimate = the lesson's `minutes`.
4. **Quick set** — 10 drills in the mode with the weakest recent accuracy (min 5 answers),
   otherwise Mixed. Subtitle shows rating and 7-day accuracy.
5. **Play 20 hands** — uses the saved table options. Estimate assumes Auto/Normal pace
   (≈ 18 s per hand).

If the daily goal is already met, a calm line "Goal met — anything else is a bonus" *(new)*
appears above the same list; nothing is hidden and nothing celebrates.

### 3.4 Coach's note

One sentence chosen from, in priority: a leak line from `leaksFromDecisions` (verbatim:
"You fold too often when you're getting the right price — look for more +EV calls." /
"You call too wide for the pot odds — fold your weakest hands more." / "No clear −EV
mistakes flagged — solid discipline. Keep refining the thin spots."), the read-accuracy
line ("Your range reads are often off — drill Guess & Peek and the Range-Building
exercise."), yesterday's session debrief ("Costliest: a river call (−2.1 bb) — it's in your
Review queue."), or, with no data, "Play a session with the EV Coach on and I'll start
noticing patterns." *(new)*. "Show me why ›" opens T1: the same sentence (layer 1), the
numbers behind it (layer 2: "12 of your last 80 coached decisions were folds the coach
flagged — 15 %"), and a button to the relevant lesson or review.

### 3.5 States

- **First run (no data):** goal bar at 0 with caption "Do 20 drills or play 30 hands to
  fill this — either counts" *(new)*; cards: Continue lesson (placement suggestion),
  Quick set, Play 20 hands; Coach card shows the no-data line; heatmap hidden until the
  first active day.
- **Goal met:** see 3.3.
- **Offline:** identical — everything is local. There is no network state anywhere in the
  app except the optional About-screen version check.
- **Late night (after 22:00 local):** greeting becomes "Good evening" still; no "you should
  sleep" nudges — the app never comments on time spent.

---

## 4. Play

The table is the app's most-used surface and the one where the desktop layout translates
worst. The redesign keeps every behaviour of `gameStore` (manual/auto pace, blocking
mistakes, guess/peek scoring, explain-last-move, learning reveal, session summary) and
rebuilds the surface around three facts about a phone: it is tall and narrow, it is held in
one hand, and the thumb rests on the bottom 220 pt.

### 4.1 Vertical budget (390×844, 6-max)

```
y   0– 59   status bar (safe)
y  59–103   top bar (44)            ‹ leave · hand/table title · Coach badge · ⋯
y 103–622   felt (519)              ticker, 5 opponent seats, pot, board, hero cards
y 630–686   hero strip (56)         hand label · stack · to-call / need-to-win line
y 694–738   context row (44)        bet presets  |  pace pill + Explain last move  |  "thinking"
y 746–810   action row (64)         Fold · Check/Call · Raise   |  Next action  |  Next hand
y 810–844   bottom safe area
```

At 360×780 the felt shrinks to 455 pt (board cards 40×56, seat plates 96×44); the three
bottom rows keep their heights. On 430×932 the felt grows; nothing else scales up except
card sizes (board 48×67, hero 76×106).

### 4.2 Play lobby (P0) — table setup before a session

```
┌──────────────────────────────────────────────┐ 59
│ Play                                         │  display 28pt
│ Six seats, four kinds of opponent, one coach.│  muted 14pt (new)
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ ▶ Resume your table                      │ │  ← only when a snapshot exists
│ │ 6-max · 12 hands · +4.5 bb · 8 min ago   │ │
│ │                            [ Resume › ]  │ │  56pt primary
│ └──────────────────────────────────────────┘ │
│                                              │
│ NEW TABLE                                    │
│ ┌──────────────────────────────────────────┐ │
│ │ Seats     [ Heads-up ] [ 6-max ] [ 9-max ]│ │  segmented, 44pt
│ │ Ante      [ Off ] [ 0.25 bb ]             │ │  segmented, 44pt  ("5 chips" internally)
│ │ Pace      [ Manual ] [ Auto ]  Normal ▾   │ │  speed menu only when Auto
│ │ EV Coach  Grades every decision    (●  )  │ │  toggle
│ │ Stacks    100 bb each · blinds 0.5 / 1    │ │  static caption (BASE_CONFIG)
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │             Deal me in                   │ │  56pt primary, full width
│ └──────────────────────────────────────────┘ │
│                                              │
│ RECENT SESSIONS                              │
│ Today 18:10   6-max · 31 hands    +12.5 bb ›│  rows 56pt → P4 (read-only)
│ Yesterday     9-max · 18 hands     −3.0 bb ›│
│ Mon           Heads-up · 40 hands  +8.0 bb ›│
├──────────────────────────────────────────────┤
│  ● Today    ▶ Play    ◎ Drills   ▤ Study  ⌇  │
└──────────────────────────────────────────────┘
```

- Seats / ante are the persisted `TableOptions` (`allin.table.v1`, values 2 / 6 / 9 and
  0 / 5). Pace and coach are play settings; on mobile they are also remembered (deliberate
  deviation from the desktop's non-persisted `{manual, 700, coach on}` — a phone user should
  not have to re-toggle Auto every launch). Realistic reveals and the four-colour deck stay
  in Settings and in the table's ⋯ sheet.
- "Deal me in" → `newSession(opts)` → P1. Archetypes are assigned randomly per seat as on
  desktop; the lobby never shows them (reads are earned at the table).
- A resume card and a "Deal me in" both present: starting a new table while a snapshot
  exists asks "Start a new table? Your paused session (12 hands) will be summarised and
  closed." [Keep paused one] [New table] *(new)*.

### 4.3 Table layout — 6-max (P1)

```
┌──────────────────────────────────────────────┐ 59
│ ‹   Hand #12 · 6-max ▾          (C)·1    ⋯   │ 44   ‹ = leave (P5); title → P1a; badge → P1f
├──────────────────────────────────────────────┤ 103
│ · · · Negreanu raises to 3 bb · · ·          │ 18   ticker (last log line) → P1c
│                 ┌──┐┌──┐                     │      seat 3 cards 30×42 (face-down)
│                 │  ││  │                     │
│              ┌────────────┐                  │
│              │S Selbst  CO│ D                 │      plate 104×48
│              │98.5 bb 22/18│                  │
│              └────────────┘                  │
│  ┌──┐┌──┐                       ┌──┐┌──┐     │
│ ┌────────────┐              ┌────────────┐   │      seat 4 (upper-left), seat 2 (upper-right)
│ │H Hellmuth MP│              │P Polk    BTN│   │
│ │ 96 bb  –/–  │  [Raise 3]   │ 100 bb 34/27│   │      last-action pill sits inside, toward centre
│ └────────────┘              └────────────┘   │
│           ( PRE-FLOP · Pot 2.5 bb )          │      pot pill, 28pt tall, mono
│        ┌────┐┌────┐┌────┐┌────┐┌────┐        │
│        │    ││    ││    ││    ││    │        │      board 5 × 44×62, dashed placeholders
│        └────┘└────┘└────┘└────┘└────┘        │
│  ┌──┐┌──┐                       ┌──┐┌──┐     │
│ ┌────────────┐              ┌────────────┐   │      seat 5 (lower-left), seat 1 (lower-right)
│ │B Brunson UTG│   (1 bb)     │I Ivey    SB │   │      "(1 bb)" = committed-chips pill
│ │ 100 bb 12/9 │              │ 99 bb  46/7 │   │
│ └────────────┘              └────────────┘   │
│                    ┌──────┐┌──────┐          │
│                    │  Q♠  ││  Q♥  │          │      hero cards 68×95, overlapping felt edge
│                    │      ││      │          │
├────────────────────┴──────┴┴──────┴──────────┤ 622
│  QQ  ·  BB  ·  98.5 bb        To call 2 bb   │ 56   hero strip (turn ring gold when to act)
│                                need 1 in 4    │      right side only when facing a bet
├──────────────────────────────────────────────┤
│ [Min] [½] [¾] [Pot] [All-in]        7.5 bb ▲ │ 44   context row (state A: sizing)
├──────────────────────────────────────────────┤
│ [  Fold  ] [  Call 2  ] [   Raise to 7.5   ] │ 64   action row
└──────────────────────────────────────────────┘ 810 (+34 safe)
```

Geometry (felt rounded-rect 374×500 at x 8, y 110; radius 120; 3 pt rim in the brand's
dark brown; inner hairline 84 % / 92 %):

| Element | Centre / box | Notes |
|---|---|---|
| Ticker | y 108–126, full width | 12 pt faint, single line, fades on change; tap → P1c |
| Seat 3 (top) | plate centre (195, 198); cards above at y 130–172 | opposite the hero |
| Seats 4 / 2 | plate centre (66, 258) / (324, 258) | upper-left / upper-right |
| Pot pill | centre (195, 310), 28 pt tall, ≤ 180 wide | street label + `{fmtBb(pot)} bb` |
| Board | y 334–396, five 44×62 cards, 6 pt gaps, x 73–317 | dashed slots for undealt cards |
| Seats 5 / 1 | plate centre (66, 446) / (324, 446) | lower-left / lower-right |
| Hero cards | 68×95, x 124–266, y 505–600 | overlap the felt's bottom edge by 22 pt |

Seat order is counter-clockwise from the hero exactly as on desktop (seat 1 lower-right,
2 upper-right, 3 top, 4 upper-left, 5 lower-left), so the dealer button travels the same
way and the desktop mental model ports.

### 4.4 Adapting to 9-max and heads-up

**9-max (8 opponents).** Plates shrink to 92×44; the HUD line drops to 9 pt mono; board
cards 40×56 (five cards = 220 pt, x 85–305).

```
│ · · ticker · ·                               │ 108–126
│     ┌────────┐            ┌────────┐         │      seats 5, 4 (top row), centres (120,178) (270,178)
│     │Antonius│            │Dwan    │         │
│ ┌────────┐                    ┌────────┐     │      seats 6, 3 (upper sides), y 250
│ │Galfond │   (PRE-FLOP · 2.5) │Selbst  │     │      pot pill y 276–296 (between upper sides and board)
│ └────────┘ ┌───┐┌───┐┌───┐┌───┐┌───┐ └───────┘     │
│            │   ││   ││   ││   ││   │         │      board y 300–356
│ ┌────────┐ └───┘└───┘└───┘└───┘└───┘ ┌────────┐     │
│ │Chidwick│                    │Polk    │     │      seats 7, 2 (mid sides), y 400
│ └────────┘                    └────────┘     │
│ ┌────────┐                    ┌────────┐     │      seats 8, 1 (lower sides), y 480
│ │Brunson │                    │Ivey    │     │
│ └────────┘   ┌──────┐┌──────┐ └────────┘     │      hero cards unchanged (x 124–266)
```

Position labels use the desktop's 9-max approximation (`BTN SB BB UTG UTG MP MP CO CO`).
Two seats can share a label; the plate shows it as-is. Last-action pills sit on the inner
edge of each plate; committed-chip pills are 18 pt and may be hidden behind a "+" when a
side column would collide (never happens at 390 wide; at 360 the mid-side pills move
below the plate).

**Heads-up (1 opponent).** One large opponent seat at the top: cards 44×62, plate 176×56
with the archetype's full name under the HUD ("Tight-Aggressive · 24/18 · 12h"); board
cards 56×78 (five = 312 pt); pot pill 32 pt tall; hero cards 76×106. The dealer button
alternates between the two plates. Because the hero posts the SB on the button and acts
first pre-flop, the hero strip adds the caption "You're the button — you act first
pre-flop, last after it" *(new)* for the first three hands of a heads-up session.

### 4.5 Seat component

Opponent plate (104×48, radius 12, surface `ink-800` at 92 %, 1 pt line):

```
┌─────────────────────┐
│ (S) Selbst      CO  │  row 1: avatar 20pt disc (archetype colour, initial), name 13pt semibold
│  98.5 bb   24/18·12h│         truncated, position chip 16pt tall mono 10pt
└─────────────────────┘  row 2: stack mono 13pt; HUD mono 10pt "vpip/pfr·nh" or "–/– · 3h"
   [Raise 3]             last-action pill: 20pt tall, sits 4pt inside the plate edge that faces
                         the table centre; Raise/Bet gold · Call info-blue · Fold faint ·
                         All-In red · Check muted
   (3 bb)                committed pill: 18pt, chip glyph + amount, between plate and centre
   D                     dealer disc 18pt gold, on the plate corner facing the centre
```

- **Cards** above the plate: 30×42 face-down (green back with gold hairline); face-up at
  hand-over per the learning-reveal rule (`isHero || (revealed && !(realisticReveal && hasFolded))`).
- **Folded**: plate 55 % opacity, cards 30 % + greyscale, last-action pill "Fold".
- **Turn indicator**: 2 pt gold ring + soft 1.6 s breathing glow (static ring under reduced
  motion). Exactly one seat carries it while `phase == betting`.
- **Winner**: green ring at hand-over; pot pill travels to this seat.
- **All-in**: red "All-In" pill and the stack shows "0 bb".
- **Sitting out / busted bot**: greyed plate "rebuying…" for one hand (bots auto-rebuy).
- **Eye affordance**: a 14 pt eye glyph at the plate's outer top corner, visible while
  `phase == betting && !hasFolded && hole != null`; its invisible hit box is 44×44. Tap →
  P2 directly (desktop parity: the eye opens Guess Range).
- **Tap on the plate** (anywhere else) → P1d seat sheet:

```
┌──────────────────── P1d (S) ─────────────────┐
│ ━━                                           │
│ (S) Selbst · CO · Tight-Aggressive (TAG)     │
│ "Plays few hands but bets and raises them    │
│  hard. The textbook winner."                 │
│ HUD 24/18 over 12 hands                      │
│ "Observed over 12 hands this session — VPIP  │
│  = how often they put money in pre-flop, PFR │
│  = how often they raise. Each player's exact │
│  numbers vary, so watch them settle."        │
│ [ 👁 Read their range ]  [ Explain last move ]│  44pt secondary buttons
└──────────────────────────────────────────────┘
```

  Before 8 hands the HUD line reads "–/– · 3h" and the sheet says "Stats appear after 8
  observed hands (3 so far) — reads are earned, not given." The archetype name is shown in
  the sheet from hand 1 — the desktop tooltip does the same, and hiding it would make the
  Exploits drills feel disconnected from play.
- **Long-press on a plate** (500 ms) is a shortcut to P2 (same as the eye).

### 4.6 The hero: cards, strip, and turn state

- Hero cards 68×95 always face-up, rank 24 pt, suit glyphs per the (four-colour) deck.
  They overlap the felt's bottom edge so the eye reads "my cards, my side".
- Hero strip (56 pt): left `QQ · BB · 98.5 bb` (hand label display 17 pt bold, position
  chip, stack mono); right, only when hero is to act and `toCall > 0`:
  `To call 2 bb` (mono, gold) over `need 1 in 4` — i.e. `fmtNeed(toCall / (pot + toCall))`
  written as a count per TONE (the desktop shows `need to win 25%`; the percentage moves to
  the coach note's layer 2).
- When it is the hero's turn: the strip gets the gold turn ring, the felt's bottom edge
  glows, and a medium haptic fires once. No countdown, ever.
- Hero committed chips show as the same 18 pt pill just above the hero cards.
- Dealer button on the hero: 18 pt disc on the strip's left edge.
- Hero self-stats ("Your style" VPIP/PFR after 8 hands) live in P1a, not on the strip.

### 4.7 Action bar — states, sizing, gestures

Row heights: context 44, action 64. Horizontal margins 16, gaps 8. Labels 17 pt semibold;
amounts mono.

**State A — hero to act, can bet/raise** (`heroToAct && canAggro`):

```
│ [Min] [½] [¾] [Pot] [All-in]        7.5 bb ▲ │   presets: 44pt chips; amount label 44pt target
│ [  Fold  ] [  Call 2  ] [   Raise to 7.5   ] │   96 · 118 · 144 wide
```

- Fold: secondary surface, label in `--bad`. Check/Call: secondary surface. Raise/Bet:
  primary gold ("Bet 5" when `currentBet == 0`, "Raise to 7.5" otherwise, amounts via
  `fmtBb`). Tapping any of the three commits immediately — no confirm step. A 120 ms
  press-down scale (0.97) and a medium haptic acknowledge the commit.
- **Presets** set `raiseTo` exactly as desktop `setFraction`: `add = round((pot + toCall) × f)`,
  `raiseTo = clamp(currentBet > 0 ? currentBet + add : add)`; Min = `minRaiseTo`; All-in =
  `maxRaiseTo`. The ½ / ¾ / Pot chips keep desktop parity; Min is added because the min-raise
  is the most common pre-flop size on a phone where sliding to it is fiddly. The selected chip
  is filled gold; a custom size deselects all chips.
- **Default size** = desktop rule (66 % of pot + toCall on top of the current bet), recomputed
  whenever `toAct / street / currentBet / phase / handNumber` change.
- **Fine sizing — the ruler (P1h).** Touch the Raise button and drag **up** (≥ 12 pt of
  vertical travel before the press would otherwise commit on release): a vertical ruler
  (64 pt wide, x 318–382, y 200–690) fades in over the felt's right edge. The amount follows
  the finger: 1 pt of travel = one step of `max(1, bb/2)` chips per 6 pt, with magnetic snap
  (±5 pt) at Min / ½ / ¾ / Pot / 2×Pot / All-in marks, each labelled. A 56 pt bubble above the
  thumb shows `7.5 bb · 66 % pot`. Light haptic per step, medium at marks. Releasing anywhere
  **sets** the size (the Raise label updates) and dismisses the ruler; it never commits the
  raise — a second, deliberate tap does. Dragging back down below the button before release
  cancels (size unchanged). Under reduced motion the ruler appears without the fade.
- **Exact number.** Tap the amount label `7.5 bb ▲` → P1i (S sheet): numeric field (decimal
  keyboard, prefilled, selected), `−0.5` / `+0.5` steppers 44 pt, the same preset chips, and
  `Set 9 bb`. Commit clamps to `[minRaiseTo, maxRaiseTo]` like the desktop text field.
- The action row never moves: Fold is always leftmost, the aggressive action always
  rightmost, so muscle memory forms.

**State B — hero to act, cannot raise** (facing an all-in, or `!canAggro`): the Raise
button is removed and Call/Check grows to 262 pt; context row shows `All-in call — 45 bb
to win 120 bb` *(new)* or nothing.

**State C — bot to act, Manual pace**:

```
│ [ Manual ▾ ]                  [ Explain last move ] │   pace pill 44pt (tap → toggle Auto; menu for speed)
│ [               Next action  ›                 ] │   full width, secondary, 64pt
```

- Tap = `stepBot()` — one bot action. **Long-press (500 ms) = "hold to fast-forward"**: bots
  act at the Fast delay (360 ms) while held, stopping at the hero's turn or hand-over.
- "Explain last move" is present whenever `canExplain` (last actor is a bot); it creates an
  info note (see 4.9). Hidden when the last actor is the hero.

**State D — bot to act, Auto pace**:

```
│ ◌ Ivey is thinking…                 [ Explain ] ⏭ │   ring spinner 16pt; ⏭ = skip to my turn
│ [            Waiting for Ivey …                ] │   disabled look, 64pt, subtle shimmer
```

The auto loop uses `speedMs` between bot actions (Slow 1100 / Normal 700 / Fast 360). ⏭
runs the remaining bot actions at 120 ms until the hero's turn (a mobile addition; it does
not alter any game state ordering). Switching Manual ↔ Auto mid-hand takes effect at the
next tick, matching `setSettings`.

**State E — hand over**: see 4.12; the action row is a single primary `Next hand ›` with
`Explain last move` as a ghost button on the left when `canExplain`.

**State F — paused** (blocking note, guess painter open, backgrounded): the bar dims to 40 %
and ignores taps; the reason is on screen (the sheet, or the "Paused — tap to continue"
ticker).

### 4.8 Pace, "hand in progress" feel, and bot animation

A hand should feel like a sequence of small, legible events rather than a state dump:

| Event | What moves | Duration | Manual | Auto |
|---|---|---|---|---|
| Deal | Two cards fly from the pot centre to each seat, seat order, 55 ms stagger; hero's arrive last and flip face-up | 220 ms per card | yes | yes |
| Blinds/antes | Committed pills appear at SB/BB (and every seat for antes) | 180 ms pop | yes | yes |
| Bot acts | Turn ring jumps (120 ms crossfade); action pill pops (180 ms, scale 0.8→1); committed pill slides plate→centre (220 ms); stack text updates at the end | ≈ 300 ms total | on tap | after `speedMs` |
| Street closes | All committed pills converge on the pot pill (260 ms); pot value counts up (200 ms); new board cards deal in (220 ms each, 55 ms stagger) | ≈ 500 ms | yes | yes |
| Hero acts | Same as bot acts, no delay; medium haptic | ≈ 300 ms | — | — |
| Hand over | Winner ring green; pot pill slides to the winner (420 ms); learning reveal flips (300 ms, 40 ms stagger); results card rises (240 ms) | ≈ 900 ms | yes | yes |

In Auto pace the ticker line shows each log line as it happens, so a user who looks up
from the action bar can read what just occurred. In Manual pace nothing happens until
"Next action" — the ring on the acting seat breathes so it is clear who the app is waiting
for. Sound is off by default; an optional "card sounds" toggle is deferred (see §15).

The "thinking" spinner is cleared whenever the loop exits for any reason (fixes the desktop
quirk where switching to Manual mid-tick left it spinning).
