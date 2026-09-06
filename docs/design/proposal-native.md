# All-In · Poker Dojo — Mobile UX Proposal ("Native idioms first")

Target: Flutter, iOS + Android phones, portrait. Design canvas **390×844 pt** (iPhone 15/16 class);
must also hold at **360×780** (compact Android) and stretch cleanly to **430×932**.
Brand: green felt + gold accent. Fonts: **Bricolage Grotesque** (display), **Inter** (body),
**JetBrains Mono** (every number that changes).

This document re-imagines the desktop app for one hand and one thumb. Every desktop feature is
accounted for in §15. Sizes are in pt; every tappable target is ≥ 44×44 pt unless a note says why
it is a paint surface rather than a button. Copy in quotes is exact and, where it comes from the
desktop app, verbatim (TONE.md forbids paraphrasing coach copy).

Sections: 1 Principles · 2 Information architecture · 3 Home · 4 Play · 5 Drills · 6 Study ·
7 Stats · 8 Onboarding · 9 Settings + About · 10 Component library · 11 Motion + haptics ·
12 Gestures + reachability · 13 Accessibility · 14 Edge / empty / error states ·
15 Feature disposition table.

---

## 1. Design principles

1. **The next decision is always under the thumb.** Fold / Check-Call / Raise, "Next action",
   "Next hand", drill answers and "Next puzzle" live in the bottom 180 pt of the screen. Nothing
   used more than once a minute is above the midline. Every screen has exactly one primary action
   and it is pinned above the home indicator.

2. **One immersive surface for play; everything else is a sheet on top of it.** The table is a
   full-screen route with no tab bar. Coach notes, player reads, the hand log, session stats and
   pace all arrive as bottom sheets that never cover the action bar, so the user never loses the
   felt. Drills follow the same rule: the spot stays visible under the feedback panel.

3. **Three layers, always visible as three layers.** Every coach note, drill rationale and stat
   explanation renders as: plain-English paragraph (open) → "Show me the math" disclosure →
   "Expert detail" disclosure. The two collapsed rows are always present, even when there is
   nothing extra to show ("No math for a read"), so the structure teaches itself (TONE.md).

4. **Interrupt only for money.** Non-blocking verdicts are a slim chip that folds itself away;
   only a blocking mistake stops the hand and demands "Got it". No toasts for praise, no confetti,
   no streak nagging, no notifications — the app judges the decision, never the person.

5. **Touch replaces hover, never removes it.** Every hover affordance on desktop (HUD tooltip,
   glossary term, stat hint, eye-to-guess, chart tooltip) has a tap target (player sheet, term
   callout, explanation sheet, seat tap, scrub). Nothing is only discoverable by hovering or by a
   keyboard shortcut.

6. **Platform-honest, brand-consistent.** Material 3 navigation bar, modal bottom sheets and
   predictive back on Android; Cupertino sheet grabbers, edge-swipe back, large-title scrolling and
   the iOS haptic vocabulary on iOS. The felt, cards, matrix, coach card and typography are
   identical on both. Nothing looks like a shrunken web page.

7. **Numbers are mono, chances are counts.** Every changing number (stack, pot, bb, %, rating,
   timer) is JetBrains Mono with tabular figures so columns never jitter. Layer-1 copy says "about
   1 time in 4", never "25 %" (`fmtTimes` / `fmtNeed`).

---

## 2. Information architecture

### 2.1 Root tabs (bottom navigation, 5 items)

| Tab | Icon | Root screen | Notes |
|---|---|---|---|
| Home | house | **Today** | Daily goal, streak, due reviews, continue lesson, quick/resume session, last session, coach's note. Gear → Settings. |
| Play | cards | **Lobby** (table setup / resume) | If a session is live, tapping the tab opens the **Table** route directly (the lobby is skipped). |
| Drills | target | **Drills** | Mode chips + current spot. Tab badge shows the Review due count. |
| Study | book | **Study path** | 5 levels / 31 lessons + Tools row (Range explorer, Equity calculator, Cheat sheet, Glossary). |
| Stats | chart | **Progress** | Overview, breakdowns, hands, heatmap, import/export/backup. |

Tab bar: Material 3 `NavigationBar` (80 pt incl. label) on Android; `CupertinoTabBar`-styled
49 pt + home indicator on iOS. Active colour gold, inactive muted. Labels always visible (no
icon-only bar). Re-tapping the active tab scrolls its root to top. The bar is hidden on the
Table route, in Guess Range, in the Range editor, in Onboarding / Placement and in every
full-screen modal.

### 2.2 Screen inventory and navigation graph

```
TabScaffold
├─ Home / Today ──────────────┬─ push  Settings ── push About
│                             ├─ modal TABLE (if "Quick session" / "Resume")
│                             ├─ tab-jump Drills (Review mode)
│                             ├─ tab-jump Study → push Lesson
│                             └─ push  Session summary (last session, read-only)
├─ Play / Lobby ──────────────┬─ modal TABLE (full-screen, tab bar hidden)
│                             │    ├─ sheet  Coach note (2 detents: 55 % / 92 %)
│                             │    │     └─ in-sheet push  Assumed range (13×13, read-only)
│                             │    ├─ sheet  Player card (archetype, HUD, actions)
│                             │    ├─ modal  GUESS RANGE (full-screen) → Peek result (same route)
│                             │    ├─ sheet  Session & log  (segments: Log · Session · Pace)
│                             │    ├─ sheet  Hand reveal (hand-over teaching lines)
│                             │    ├─ sheet  Bet keypad (numeric bb entry)
│                             │    ├─ sheet  Explanation (any ⓘ stat)
│                             │    ├─ modal  SESSION SUMMARY (full-screen, on End / bust)
│                             │    │     ├─ push  Hand replayer
│                             │    │     ├─ sheet Note editor
│                             │    │     └─ system Share sheet (.txt)
│                             │    └─ dialog Leave table? (only when a hand is mid-action)
│                             └─ push  Session summary (of a past session)
├─ Drills ────────────────────┬─ panel Feedback (bottom panel, 2 detents; not dismissable by scrim)
│                             │    ├─ in-panel disclosure Grading range (13×13 read-only)
│                             │    └─ modal Lesson reader (from "Read the lesson")
│                             ├─ sheet Frame list (long-press the move navigator)
│                             ├─ sheet Stat explanation (rating / today / streak)
│                             └─ modal PLACEMENT TEST (from Settings deep link)
├─ Study ─────────────────────┬─ push  Lesson reader
│                             │    ├─ popover Glossary term callout
│                             │    ├─ sheet  Card keypad (equity calculator, hand mode / board)
│                             │    ├─ modal  RANGE EDITOR (equity calculator ranges, full-screen)
│                             │    └─ push   Glossary (from a callout's "Open glossary")
│                             ├─ push  Range explorer · Equity calculator · Cheat sheet (Tools row)
│                             └─ push  Glossary (searchable)
└─ Stats ─────────────────────┬─ sheet Stat explanation (every KPI / row with ⓘ)
                              ├─ sheet Chart value (scrub)
                              ├─ push  Hand replayer ── sheet Note editor
                              ├─ push  All hands (filter by tag, paginated)
                              ├─ system File picker → sheet Import result
                              ├─ sheet Paste hand history (text field)
                              ├─ system Share sheet (export .txt / backup .json)
                              ├─ system File picker → dialog Restore backup?
                              └─ dialog Reset all progress? (typed confirmation)
Onboarding (first run, full-screen modal over everything): Tour(4) → Placement intro → Quiz(8) → Result
```

### 2.3 Sheet vs push vs full-screen modal

| Use | Pattern | Why |
|---|---|---|
| Something *about* what is on screen (coach note, player read, stat meaning, hand log, note, keypad) | **Bottom sheet**, draggable, grabber, scrim 40 %, never covers the action bar when the table is the parent (max detent leaves 120 pt) | Keeps context visible; one swipe closes |
| Reading content with hierarchy (lesson, replayer, settings, about, all-hands list, glossary, tools) | **Push** with back chevron / edge-swipe / predictive back | Linear reading; back is natural |
| A task with its own completion (live session, painting a range, editing a range, summary, onboarding, placement, lesson opened from a drill) | **Full-screen modal** with explicit Close/Done, tab bar hidden | Focus; the system back gesture maps to "leave/close" |
| Confirming a destructive or irreversible action (leave mid-hand, erase data, restore backup, start a new session over a suspended one) | **Alert dialog** (adaptive: Cupertino alert / M3 dialog) | Interrupts on purpose |
| A tiny definition (glossary term) | **Anchored popover** (max 280×160), tap outside to dismiss | Reading flow is not broken |

System back gesture / back button mapping: sheet → close; popover → close; Table → "Leave
table" (suspends the session — never ends it); Guess Range → close without peeking; blocking
coach sheet → equals "Got it"; drill feedback panel → collapses to compact detent (never
dismisses the verdict); Range editor → "Done" (keeps edits); Onboarding → next-less (back
goes to the previous tour page; on page 1 it does nothing).

### 2.4 Deep links used inside the app

`allin://study/{lessonId}` (drill feedback, onboarding result, coach's note), `allin://drills?mode=leaks`
(Home review card, Stats coaching review), `allin://stats/hand/{startedAt}` (session summary rows),
`allin://settings/data` (import result). These are internal routes; no external URL scheme is
exposed in v1.

---

## 3. HOME — the "Today" screen

Purpose: get the user to the right practice in one tap and show the quiet daily loop
(goal, streak, due reviews). Nothing here nags; the streak is informational.

```
┌──────────────────────────────────────────┐ 390×844
│ ▮▮▮ 9:41                         ●●● ▮▮ │ status
│ All-In                              [⚙]  │ 44 title bar (Bricolage 28)
│                                          │
│ Good evening.                            │ Inter 17
│ ┌────────────────────────────────────┐   │
│ │  ◔ 14 / 20        Day streak  6    │   │ Goal card 88 pt
│ │  drill answers today (or 30 hands) │   │ ring 56 pt, gold when met
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ ▶  Quick session · 6-max · no ante │   │ Primary 56 pt (gold)
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ ↻  Review   3 spots due        ›   │   │ Secondary 56 pt, badge
│ └────────────────────────────────────┘   │
│ Continue learning                        │ section label
│ ┌────────────────────────────────────┐   │
│ │ L3 · Pot Odds, Break-even & EV     │   │ Lesson card 72 pt
│ │ 6 min · 14 / 31 lessons done  ━━━━ │   │
│ └────────────────────────────────────┘   │
│ Last session                             │
│ ┌────────────────────────────────────┐   │
│ │ +12.5 bb · 41 hands · 2 mistakes › │   │ → Session summary
│ │ Costliest: a river call (−3.1 bb)  │   │
│ └────────────────────────────────────┘   │
│ Coach's note                             │
│ ┌────────────────────────────────────┐   │
│ │ ⚡ You call too wide for the pot    │   │ from leak detection; tap → Stats
│ │ odds — fold your weakest hands…    │   │
│ └────────────────────────────────────┘   │
│                                          │
│ ┌────┬────┬────┬────┬────┐               │
│ │Home│Play│Drll│Stdy│Stat│  tab bar      │
└──────────────────────────────────────────┘
```

- "Quick session" uses the last table options (seats/ante) and opens the Table modal immediately.
- If a session is suspended, the primary card becomes **"Resume · Hand #13 · +8.5 bb"** and a
  secondary "New session" text button appears under it.
- The Review card is hidden when nothing is due (a small "Nothing due — next in 2 days" caption
  replaces it under the goal card).
- The goal card's ring counts whichever of the two goals is closer to completion (drills /20 or
  hands /30) and labels it accordingly; tap → explanation sheet with the verbatim "quiet daily
  goal" copy.
- Greeting copy: "Good morning/afternoon/evening." The first run after onboarding says
  "Start with a session — the coach explains as you go."
- Tip card (desktop sidebar tip) is folded into "Coach's note": a leak sentence if any
  (`leaksFromDecisions`, verbatim), otherwise a rotating one-liner from the cheat sheet
  ("Half-pot bet → you need to win about 1 time in 4").
- Pull-to-refresh is not used (everything is local and live).

---

## 4. PLAY

### 4.1 Lobby (Play tab root, empty state and table setup)

```
┌──────────────────────────────────────────┐
│ Play                                     │ 44
│                                          │
│         ╭──────────────────────╮         │
│         │      (felt preview)  │         │ 160 pt illustration of the
│         │   6 seats · 100 bb   │         │ chosen layout (live-updates)
│         ╰──────────────────────╯         │
│                                          │
│ Table                                    │
│ ┌──────────┬──────────┬──────────┐       │ Segmented 44 pt
│ │ Heads-up │  6-max ● │  9-max   │       │
│ └──────────┴──────────┴──────────┘       │
│ Antes                                    │
│ ┌────────────────┬────────────────┐      │
│ │    None ●      │    0.25 bb     │      │
│ └────────────────┴────────────────┘      │
│ ⓘ Coach charts assume 6-max — verdicts   │ shown only when ≠ 6 (verbatim)
│   at other table sizes use the nearest   │
│   position as an approximation.          │
│                                          │
│ Pace          Manual ● │ Auto            │ small segmented (remembered)
│ EV Coach                          [ on ] │
│                                          │
│ A session deals hand after hand against  │ verbatim start-overlay copy
│ a fixed table of bots. Your stack        │
│ carries over, so wins and losses stick   │
│ until you end the session.               │
│ ┌────────────────────────────────────┐   │
│ │ ▶          Start session           │   │ Primary 56, pinned above tab bar
│ └────────────────────────────────────┘   │
│ ┌────┬────┬────┬────┬────┐               │
└──────────────────────────────────────────┘
```

- The felt preview redraws seat plates as the Table segment changes (2 / 6 / 9), so the user sees
  what they are about to get. Antes toggle adds a tiny "ante" chip to each seat in the preview.
- If a session is suspended: a **Resume** card sits above the setup ("Hand #13 · +8.5 bb ·
  41 hands · Resume ›") and "Start session" becomes "Start a new session" (destroys the suspended
  one after a confirmation alert: "End the current session? You'll get its summary first." —
  Cancel / End & start new).
- Pace and EV Coach are the desktop's non-persisted play settings; on mobile they are remembered
  across sessions (deliberate deviation: re-choosing pace every session is friction on a phone).
- **Empty state** (no session ever played): the preview shows a dashed board and the caption
  "Your first table. The coach explains every decision in plain English." under the preview.

### 4.2 Table — 6-max portrait wireframe (hero to act, can raise)

```
┌──────────────────────────────────────────┐  y (pt)
│ ▮▮▮ 9:41                         ●●● ▮▮ │   0–59 safe inset
│ ‹ Leave   Hand #12 · +8.5 bb   [◉ 2] [≡] │  59–103 top bar 44
│ ┌──────────────────────────────────────┐ │
│ │ ✓ Nice play — Betting with the goods…│ │ 103–139 coach chip (transient, 36)
│ └──────────────────────────────────────┘ │
│   ╭──────────────────────────────────╮   │ 139–590 table canvas ≈ 450
│   │            ┌──────────┐          │   │
│   │   ▯▯       │Ⓘ Ivey    │   ▯▯     │   │  seat 3 (top-centre, y≈165)
│   │ ┌──────┐   │ UTG 97.5 │ ┌──────┐ │   │
│   │ │Ⓝ Polk│   │ 22/18·14h│ │ⓁDwan │ │   │  seats 4 (upper-left) / 2 (upper-right)
│   │ │MP  102│   └──────────┘ │CO 88.5│ │   │  y≈235
│   │ │12/9·14h    ⟨Fold⟩      │34/27  │ │   │
│   │ └──────┘                 └──────┘ │   │
│   │        ⟨Raise 2.5⟩                │   │  action bubbles float toward pot
│   │             PRE-FLOP              │   │
│   │            ◎ 3.5 bb               │   │  pot pill (y≈330)
│   │     ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐      │   │  board 5×(44×62), y≈350–412
│   │     └──┘ └──┘ └──┘ └──┘ └──┘      │   │
│   │ ┌──────┐                 ┌──────┐ │   │  seats 5 (lower-left) / 1 (lower-right)
│   │ │ⓈSelb.│                 │ⓉIvey │ │   │  y≈470
│   │ │SB 99 │       ⟨Call 2.5⟩│BB  D │ │   │  D = dealer disc on plate corner
│   │ │46/7  │                 │ –/–·3h│ │   │
│   │ └──────┘                 └──────┘ │   │
│   ╰──────────────────────────────────╯   │
│ ┌────┐┌────┐  You · BTN        98.5 bb   │ 590–686 hero strip 96
│ │ Q♠ ││ Q♥ │  QQ · pocket queens  ⟨2 bb⟩ │  cards 64×90, committed pill
│ └────┘└────┘  Your style 24/19 · 12h     │  self-stats after 8 hands
│  To call 2.5 bb · need to win ~1 in 4    │ 686–706 price hint 20
│  Min    ⅓     ½     ⅔    Pot     All-in  │ 706–754 sizing rail 48
│  ○──────●─────○─────○─────○─────────○    │  (labels 11 pt, rail 6 pt, knob 28)
│ ┌────────┐┌────────────┐┌──────────────┐ │ 754–810 action row 56
│ │  Fold  ││ Call 2.5   ││ Raise to 8 ▴ │ │  30 % / 33 % / 37 % widths
│ └────────┘└────────────┘└──────────────┘ │
│              ▬▬▬▬▬▬                      │ 810–844 home indicator
└──────────────────────────────────────────┘
```

Seat geometry (fractions of the table canvas, hero excluded; canvas ≈ 366×450 after 12 pt insets):

| Seats | Positions (x %, y %) clockwise from hero's left → screen right |
|---|---|
| 6-max | s1 (84, 74) · s2 (84, 30) · s3 (50, 8) · s4 (16, 30) · s5 (16, 74) |
| Heads-up | s1 (50, 12); plate grows to 140×64, cards 36×50 |
| 9-max | s1 (86, 78) · s2 (88, 54) · s3 (84, 30) · s4 (66, 8) · s5 (34, 8) · s6 (16, 30) · s7 (12, 54) · s8 (14, 78); plates 84×40, HUD collapses to the colour dot + "14h" (numbers live in the player sheet) |

At 360 pt width the 6-max plates shrink from 96×44 to 88×42 and names truncate at 6 characters
("Negrea…"); at 9-max on 360 pt the board drops to 40×56. Seat order runs clockwise on screen
from the hero's left, matching the engine's counter-clockwise seat indices mirrored so the
button visibly travels clockwise (a deliberate visual choice; action order is unchanged).

**Heads-up** (the felt shrinks to a rounded rectangle 366×300 so the opponent is close and the
board is large; the freed 150 pt go to a taller hand-log peek line):

```
│ ‹ Leave   Hand #4 · −1.5 bb    [◉ 1] [≡] │
│   ╭──────────────────────────────────╮   │
│   │        ▯▯  ┌────────────────┐    │   │ opponent plate 140×64, cards 36×50
│   │            │ Ⓛ Dwan   BB    │    │   │ archetype name spelled out: "Loose-Aggressive"
│   │            │ 34/27 · 4h     │    │   │
│   │            └────────────────┘    │   │
│   │            ⟨Raise 3⟩              │   │
│   │               FLOP                │   │
│   │             ◎ 6.5 bb              │   │
│   │    ┌───┐ ┌───┐ ┌───┐ ┌──┐ ┌──┐    │   │ board 52×73 (larger than 6-max)
│   │    │A♠ │ │7♦ │ │2♣ │ └──┘ └──┘    │   │
│   ╰──────────────────────────────────╯   │
│  • Dwan raises to 3 bb                   │ last two log lines (tap → Session sheet)
│  • You check                             │
│ ┌────┐┌────┐  You · BTN(SB)     98.5 bb  │ hero strip
```

**9-max** (plates compact; the HUD is one dot + hands; two extra seats on the vertical sides):

```
│   ╭──────────────────────────────────╮   │
│   │   ▯▯ ┌─────┐        ┌─────┐ ▯▯   │   │ s5 (34,8) · s4 (66,8)
│   │      │Ⓝ Polk│        │ⓉIvey │     │   │ plates 84×40: initial, name(5), pos, stack
│   │ ▯▯   └─────┘        └─────┘  ▯▯  │   │
│   │┌─────┐                    ┌─────┐│   │ s6 (16,30) · s3 (84,30)
│   ││ⓁDwan│                    │ⓈSelb││   │
│   │└─────┘      PRE-FLOP       └─────┘│   │
│   │┌─────┐     ◎ 4.5 bb        ┌─────┐│   │ s7 (12,54) · s2 (88,54)
│   ││ⓉGalf│ ┌─┐┌─┐┌─┐┌─┐┌─┐     │ⓃChid││   │ board 40×56
│   │└─────┘ └─┘└─┘└─┘└─┘└─┘     └─────┘│   │
│   │┌─────┐                    ┌─────┐│   │ s8 (14,78) · s1 (86,78)
│   ││ⓈAnto│                    │ⓁHell││   │
│   │└─────┘                    └─────┘│   │
│   ╰──────────────────────────────────╯   │
```
Position labels on 9-max follow the engine's 6-label approximation (two UTG, two MP, two CO);
the plate shows the label, the player sheet adds "(approximate — 9-max uses 6-max labels)".

### 4.3 Seat component

```
      ▯▯            two face-down cards 28×39, overlapping 6 pt, sit above the plate
 ┌────────────┐     plate 96×44, radius 12, ink-800 @ 90 %, 1 pt line
 │Ⓣ Ivey  UTG │     avatar 28 (archetype-coloured ring + initial) · name 12 semibold · position chip 9 caps
 │  97.5 bb  D│     stack mono 12 gold-light · dealer disc 18 pt white "D" pinned to the right edge
 └────────────┘
   22/18 · 14h      HUD chip 10 pt mono on black 45 %: VPIP/PFR · hands seen ("–/– · 3h" under 8 hands)
    ⟨Raise 2.5⟩     action bubble 24 pt tall, floats 20 pt toward the pot; colour by action
```

- **Turn indicator**: gold 2 pt ring + soft pulse (1.7 s) on the acting plate, and the plate lifts
  2 pt. In auto mode a three-dot "thinking" shimmer replaces the HUD line while the bot delays.
- **Folded**: cards fade to 30 % and grey; plate to 55 %; action bubble "Fold" in faint.
- **Winner** (hand-over): green ring, pot chips animate to the plate, "+6.5 bb" floats up.
- **All-in**: red "ALL-IN" chip replaces the stack.
- **Committed chips**: small pill next to the bubble ("2.5 bb"), animates to the pot at street end.
- **Action bubble colours** (as desktop): Raise/Bet gold, All-in red, Call info-blue, Check muted,
  Fold faint. Bubbles persist until the street closes, then fade with the chips.
- **Tap plate** → **Player sheet** (below). **Long-press plate** (500 ms) → Guess Range directly
  (shortcut; haptic medium). Both are ≥ 44 pt because the plate is 96×44 and the cards add 39 pt.
- **Tap action bubble** → Explain last move for that player (if it was the last action).
- **Sitting out** (never in v1 — bots always play) is not designed.

Player sheet (half detent, 380 pt):

```
┌──────────────────────────────────────────┐
│               ▬▬▬                        │ grabber
│ Ⓣ Ivey · UTG · Tight-Aggressive (TAG)    │
│ Plays few hands but bets and raises      │ archetype blurb (verbatim)
│ them hard. The textbook winner.          │
│ ┌──────────────┬───────────────────────┐ │
│ │ VPIP 22 %    │ PFR 18 %   · 14 hands │ │ stat tiles; tap → what VPIP/PFR mean
│ └──────────────┴───────────────────────┘ │
│ Observed over 14 hands this session —    │ HUD tooltip text (verbatim)
│ VPIP = how often they put money in       │
│ pre-flop, PFR = how often they raise.    │
│ Each player's exact numbers vary, so     │
│ watch them settle.                       │
│ ┌────────────────────────────────────┐   │
│ │ 👁  Read their range               │   │ Primary → Guess Range (only while in hand)
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ ◉  Explain their last move         │   │ Secondary (only if they acted last)
│ └────────────────────────────────────┘   │
└──────────────────────────────────────────┘
```
Under 8 hands the stat tiles read "–" and the paragraph is the verbatim "Stats appear after 8
observed hands (3 so far) — reads are earned, not given."

### 4.4 Hero strip

64×90 cards (rank Bricolage 800 at 23 pt, suit glyph 17 pt + big corner suit 32 pt at 92 %),
overlapping by 8 pt with a 4° fan; tap either card to un-fan (cosmetic). To the right: "You · BTN"
(13 semibold), "98.5 bb" (mono 15 gold-light), hand label "QQ" (Bricolage 15) with the plain name
("pocket queens", "ace-king suited"), committed pill, and after 8 hands the self-stats line
"Your style 24/19 · 12h" (tap → explanation sheet with the "Your VPIP / PFR" tooltip copy).
Dealer disc appears here when hero is BTN. At hand-over, the hero strip shows the made hand
("Two pair, queens and sevens"). Between hands (before the deal) the card slots are empty
outlines for ≤ 300 ms.

### 4.5 Action bar — states and the bet-sizing control

**Hero to act.** Three buttons, 56 pt tall, 8 pt gaps, full-width row 8 pt above the home
indicator:

| Button | Width | Style | Label |
|---|---|---|---|
| Fold | 30 % | ink-700 fill, chip-red text and 1 pt red @ 40 % border | "Fold" |
| Check / Call | 33 % | ink-600 fill, text | "Check" · "Call 2.5" (mono amount) · "Call all-in" |
| Bet / Raise | 37 % | gold fill, ink text | "Bet 4" · "Raise to 8 ▴" — the ▴ hints the keypad |

**Sizing rail** (48 pt, above the row; only when betting/raising is legal):

- A horizontal rail with labelled snap ticks: `Min · ⅓ · ½ · ⅔ · Pot · All-in` (fractions of
  pot-after-call, added on top of the current bet when facing one — identical math to the
  desktop quick buttons; ⅓ and ⅔ are additions, ¾ is dropped because ⅔ is the coach's own
  value-bet size). Default selection = ⅔ (desktop's 0.66 default).
- **Gesture**: touch anywhere on the 48 pt band and drag horizontally; the knob follows the finger
  with 0.5 bb quantisation (`max(1, bb/2)` chips), snapping (magnet ±6 pt) to ticks with a
  `selectionClick` haptic on each tick. **Tap** a tick label to jump. Release does **not**
  commit — the Raise button commits.
- The Raise button label updates live ("Raise to 8"); the price hint line updates to what the
  opponent would need ("If they call they need to win about 1 time in 3").
- **Tap the Raise amount text (or long-press the button)** → **Bet keypad sheet**: a mono display
  "8.0 bb", ±0.5 stepper, numeric keypad (0–9, ".", ⌫), and the same preset chips; "Set" returns
  to the table with the amount selected (still not committed). Clamped to `[minRaiseTo,
  maxRaiseTo]` with an inline "min 5 bb / max 98.5 bb" caption; out-of-range entries snap on Set.
- **All-in** tick turns the Raise button red-gold ("All-in 98.5") and the commit requires a second
  tap within 2 s ("Tap again to confirm") — the only two-step commit on the table. A "Confirm
  all-in" setting can turn this off.
- Reachability: the rail sits at y 706–754, inside the thumb arc of a right- or left-handed grip;
  ticks nearest the thumb (right side) are Pot/All-in for right-handers — mirrored when the
  "Left-handed layout" setting flips the action row to Raise · Check · Fold and the rail's ticks.

**Bot to act, Manual pace:**

```
│ ◉ Explain last move          (ghost)     │
│ ┌────────────────────────────────────┐   │
│ │ Next action                     ›  │   │ Secondary 56, full width
│ └────────────────────────────────────┘   │
```
Also: **tap anywhere on the felt** (not on a seat) advances one bot action (same as the
button) — the felt is the biggest target on screen. A caption "Tap the table or Next action to
step through" shows under the button for the first three hands of the user's life, then never
again. Holding a finger on the felt does nothing (no auto-repeat) so a rest never fires actions.

**Bot to act, Auto pace:**

```
│ Ivey is thinking…      Speed  ●●○  Pause │ 56 pt strip: name + dots, speed pips (tap cycles
                                             Slow/Normal/Fast = 1100/700/360 ms), Pause → Manual
```

**Paused by the coach** (blocking): the action zone shows "Paused — read the coach note" in
muted text; the coach sheet is up.

**Hand over:**

```
│ ◉ Explain last move          (ghost)     │
│ ┌────────────────────────────────────┐   │
│ │ Next hand                        › │   │ Primary 56 (gold)
│ └────────────────────────────────────┘   │
```
Optional setting "Auto-deal next hand after 3 s" (off by default; a thin progress line runs
along the top of the button when on; tapping cancels the countdown and deals).

**Session over / busted:** the Session summary modal opens; the table behind stays visible.

### 4.6 What "a hand in progress" feels like

1. Deal: hero cards slide from the centre and flip (280 ms, staggered 60 ms); opponents' backs
   pop in around the ring (40 ms stagger). Blinds' committed pills appear. Street label
   "PRE-FLOP" fades in over the pot. Light haptic on the hero's second card landing.
2. Turn passes: the gold ring hops seat to seat. In manual mode nothing moves until the user
   taps; in auto mode the acting seat shows the thinking dots for the pace delay, then the
   action bubble springs out toward the pot (180 ms) with a light haptic for raises only.
3. Street change: all committed pills slide into the pot pill (320 ms), the pot number ticks up
   (mono roll), then the new board cards deal (280 ms each, 60 ms stagger).
4. Hero's turn: action row slides up from the bottom (200 ms), price hint appears, sizing rail
   knob lands on the default with a `selectionClick`.
5. Hero acts: button press scales 0.97, medium haptic; the hero's bubble appears; the coach
   evaluates in the background (never blocks the UI); a verdict chip appears within ~300 ms
   (or the blocking sheet).
6. Showdown: remaining players' cards flip face-up in seat order (240 ms flip, 120 ms stagger),
   winner ring, pot slides to the winner (450 ms), net delta floats up on the hero strip.

### 4.7 Bot action animation and speed

| Pace | Delay between bot actions | Bubble in | Chips to pot |
|---|---|---|---|
| Manual | user tap | 180 ms | 320 ms |
| Auto · Slow | 1100 ms | 180 ms | 320 ms |
| Auto · Normal | 700 ms | 180 ms | 320 ms |
| Auto · Fast | 360 ms | 120 ms | 200 ms |

Auto-play never runs while any sheet is open, while Guess Range is open, or while a blocking
note is up (mirrors `paused || guess.open` in the store). Backgrounding the app pauses the
loop; returning resumes it after a 700 ms grace so the user can re-orient. `thinking` is
cleared whenever the loop exits for any reason (fixes the desktop quirk).

### 4.8 The EV Coach on mobile

**Non-blocking notes → the coach chip.** A 36 pt chip slides down under the top bar (never over
the action bar), 260 ms spring. Content: verdict badge + label ("Nice play" / "Reasonable" /
"Thin spot" / "Mistake" / "Read") + the first clause of the plain sentence, ellipsised. It stays
4 s (8 s at "Slow" pace), then folds into the top-bar **Coach badge** `[◉ 2]` (count = notes this
hand). Tap chip → coach sheet at 55 %. Chips never stack: a second note replaces the first with a
crossfade, the badge count increments. Non-blocking *mistakes* (fold / check / bet verdicts)
use the red badge and stay 8 s regardless of pace, but still never pause the hand — as desktop.

**Blocking mistakes → the coach sheet opens itself.** The hand pauses (auto-play stops, the
action zone greys). The sheet opens at 55 % with a red header; swipe-down and "Got it" both
dismiss and resume. The sheet cannot be dismissed by tapping the scrim (the scrim is 40 % but
non-interactive for blocking notes) so the acknowledgement is deliberate. Haptic: `warning`
notification pattern once, on open.

Coach sheet (blocking example, 55 % detent expands to 92 % on drag or when a disclosure opens):

```
┌──────────────────────────────────────────┐
│               ▬▬▬                        │
│ ┌──────────────────────────────────────┐ │
│ │ ✕  Mistake                           │ │ header tinted bad @ 12 %
│ │    EV Coach · Your call · River      │ │
│ └──────────────────────────────────────┘ │
│ You paid 8 bb to win a pot of 24 bb —    │ LAYER 1 · Inter 16/24, always open
│ you need to win about 1 time in 4. Your  │
│ hand wins about 1 time in 6 — not        │
│ enough. Over time this call loses money; │
│ folding is better.                       │
│                                          │
│ Win chance vs Ivey              17 %     │ equity bar 10 pt, marker at 25 % "needed"
│ ████████░░░░░░░░░░│░░░░░░░░░░░░░░░░░░    │ tap "Win chance" → glossary callout
│ White line = 25 % needed (pot odds)      │ tap "(pot odds)" → glossary callout
│                                          │
│ ▸ Show me the math                       │ LAYER 2 · disclosure row 48 pt
│ ▸ Expert detail                          │ LAYER 3 · disclosure row 48 pt
│                                          │
│ Expected value              −2.0 bb      │ EV tile (bad < −0.05, good > +0.05)
│ ┌───────────────┐ ┌────────────────────┐ │
│ │ 👁 View range │ │      Got it        │ │ 48 pt; Got it is primary
│ └───────────────┘ └────────────────────┘ │
└──────────────────────────────────────────┘
```

- Opening "Show me the math" expands a numbered list (steps verbatim from the store) and grows
  the sheet to 92 %; "Expert detail" adds the bullet list (layer-2 `text` line first, then the
  source line, precision, baseline note). Labels toggle to "Hide the math" / "Hide expert
  detail". The two disclosure states persist for the session (as desktop).
- Multiway warning renders as an amber callout between layer 1 and the equity bar (verbatim).
- **View range** pushes, inside the sheet, a read-only 13×13 matrix titled "Ivey's assumed range"
  with the desktop description ("This is the range the coach used for its equity estimate, based
  on archetype, position and action so far.") and the "{combos} combos · {pct} of all hands"
  line; a back chevron returns to the note.
- **Reopening past notes**: tap the top-bar Coach badge → the sheet opens on a list of this hand's
  notes (verdict badge, title, street, one-line plain text); tap a row to expand it. Notes are
  per hand (as on desktop: `reviewLog` resets on deal). Mobile additionally persists each hand's
  notes with the hand record so the Stats replayer can show them (new; see §7.7).
- **Explain last move** produces a "Read" note (blue eye badge) in the same sheet; its layer 2 and
  3 rows read "No math for a read — this is an interpretation of their style" and the range
  button shows their assumed range.
- Coach off: the badge disappears; the Pace segment of the Session sheet holds the toggle.

### 4.9 Guess Range → Peek

Entry: Player sheet → "Read their range", long-press a seat, or the Coach note's "View range"
(read-only variant). Available for any bot with cards while `phase == betting`, on any street,
not only on the hero's turn. Opens a **full-screen modal** (the matrix needs the full width).
Opening pauses the hand (as desktop).

```
┌──────────────────────────────────────────┐
│ ✕      Read Ivey's range           Peek  │ 44 top bar; Peek = primary text button
│ UTG · Tight-Aggressive (TAG) · Flop      │ 13 muted
│ Optionally paint your guess, or just     │ verbatim description
│ peek to study their range.               │
│    A  K  Q  J  T  9  8  7  6  5  4  3  2 │ header row 20 pt (tap = select column)
│ A ▓▓ ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ K ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ 13×13 grid, cells 26 pt + 2 pt gap
│ Q ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ = 362 pt square at 390 wide
│ J ▓▓ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ (25 pt cells at 360 wide)
│ T ░░ ░░ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ 9 ░░ ░░ ░░ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ pairs = combo-pair red-brown
│ 8 ░░ ░░ ░░ ░░ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ │ suited (upper-right) = combo-suited green
│ 7 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ │ offsuit (lower-left) = combo-offsuit slate
│ 6 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ unpainted = ink-700 with faint label
│ 5 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ 4 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ 3 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ 2 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ ■ Pairs  ■ Suited  ■ Offsuit   148 combos│ legend + live count · 11 % of hands
│ ⟨Top 10%⟩⟨15%⟩⟨25%⟩⟨40%⟩⟨UTG open⟩⟨CO⟩… │ preset chips, horizontal scroll, 36 pt
│ ┌────────┐ ┌────────┐ ┌────────────────┐ │
│ │ ↶ Undo │ │ Clear  │ │  Peek & score  │ │ 48 pt; "Peek" when nothing is painted
│ └────────┘ └────────┘ └────────────────┘ │
│ Guessing is optional — peek any time.    │ verbatim hint
└──────────────────────────────────────────┘
```

Painting with a finger (the exact gesture spec):

- **Cell size** 26×26 pt (+2 gap) at 390 wide, 25 at 360, 29 at 430. These are below 44 pt on
  purpose: the matrix is a paint surface, not 169 buttons. Precision comes from drag-paint, the
  loupe and the row/column selectors.
- **Touch-down** on a cell decides the stroke mode: if the cell is empty → *add* mode, else
  *remove* mode (identical to desktop `addMode`). The cell toggles immediately.
- **Drag** paints every cell the finger crosses in that mode. Pointer samples are interpolated
  along the segment between consecutive events so a fast diagonal swipe never skips cells.
  Each newly painted cell fires a `selectionClick` haptic (throttled to ≥ 30 ms apart).
- **Loupe**: while the finger is down, a 56 pt magnifier bubble appears 48 pt above the fingertip
  showing the cell label under the finger and its current state (Apple text-selection style).
- **Tap** (no move, < 150 ms) toggles a single cell.
- **Header taps**: tap a rank in the top header to toggle its whole column; the left header its
  whole row; tap the "A" corner to toggle all pairs (the diagonal). Long-press a header selects
  "this and better" (e.g. long-press "9" on the left header paints 99+).
- **Undo** reverts the last stroke (stack of 20); **Clear** empties (with a 3 s "Undo clear"
  snackbar). Preset chips replace the current paint (also undoable). Presets: Top 10 / 15 / 25 /
  40 / 55 % (`topPercentRange`) and the six position opens from the 100 bb chart.
- The grid never scrolls; the content below it does not scroll either (everything fits in
  844 pt; at 780 pt the preset row and legend merge into one 36 pt line).
- Two-finger pinch is *not* used for zoom (conflicts with paint). Accessibility zoom users get the
  OS zoom; VoiceOver/TalkBack users get the row/column/cell semantics described in §13.

**Peek / Reveal screen** (same route, content crossfades 200 ms):

```
┌──────────────────────────────────────────┐
│ ✕      Ivey's range revealed             │
│ ┌──────────────────────────────────────┐ │
│ │        72 %          SOLID           │ │ Bricolage 44 gold; grade label (Sharp read /
│ │ You caught about 8 in 10 of their    │ │ Solid / Rough / Way off, same thresholds)
│ │ hands (coverage 81 %). About 7 in 10 │ │ plain-English recall / precision, then the
│ │ of what you painted was right        │ │ desktop lines "Coverage (recall): 81%" /
│ │ (precision 68 %).                    │ │ "Precision: 68%" in mono underneath
│ └──────────────────────────────────────┘ │
│    (13×13 compare matrix)                │ green = correct · amber = missed · red = extra
│ ■ Correct ■ Missed ■ Extra  Their range: │
│                             182 combos   │
│ Everyone's exact cards are revealed when │ verbatim
│ the hand ends.                           │
│ ┌────────────────────────────────────┐   │
│ │             Continue               │   │ Primary 56 → closes, resumes hand
│ └────────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

If nothing was painted: the matrix shows the highlighted actual range and the score card reads
"Here's Ivey's assumed range. Paint a guess first next time for an accuracy score." Peek reveal
gets a medium haptic; a "Sharp read" gets the success pattern. Closing by ✕ or the back gesture
after a reveal counts as Continue; before a reveal it closes without scoring (as desktop).

### 4.10 Explain last move

Available whenever the last actor was a bot: ghost button in the bot-turn and hand-over action
zones; "Explain their last move" in the Player sheet; tapping a bot's action bubble. It opens the
coach sheet with a "Read" note (blue eye) built from `interpretBot` text (title
"{name}'s {action}"), and the "View range" button. The store remembers the last action label
so the title never degrades to "{name}'s move" after a street closes (fixes the desktop quirk).
It never pauses auto-play for more than the time the sheet is open.

### 4.11 Hand log and session stats access

Top-bar `[≡]` → **Session sheet**, 3 segments (remembers the last one). Swiping up on the hero
strip also opens it (secondary gesture; discoverable via the first-hands caption).

```
┌──────────────────────────────────────────┐
│               ▬▬▬                        │
│ ┌────────┬──────────┬──────────┐         │ segmented 36
│ │  Log ● │ Session  │   Pace   │         │
│ └────────┴──────────┴──────────┘         │
│ Hand #12                                 │
│  • Ivey raises to 2.5 bb                 │ action rows, newest at the bottom, auto-scrolls
│  • Dwan folds                            │
│  • Polk folds                            │
│  • You call 2.5 bb                       │ hero lines in text colour, results gold
│  • Selbst folds                          │
│  Flop: 7♠ 8♦ K♣                          │ deal lines in info blue
│  • Ivey bets 2 bb                        │
│ ▸ Hand #11 (+4 bb)                       │ collapsed previous hands (this session)
│ ▸ Hand #10 (−1 bb)                       │
└──────────────────────────────────────────┘
Session segment: tiles Hands 12 · Net +8.5 bb · bb/100 +71 · Read accuracy 64 % · Your style
24/19 (each tile tappable → explanation sheet with the desktop tooltip copy) and a red
"End session" button (48 pt, ink-700 fill, red text) at the bottom.
Pace segment: Manual/Auto segmented with the verbatim helper line, Slow/Normal/Fast (visible
only for Auto), EV Coach switch, Auto-deal next hand switch, Realistic reveals switch
(mirrors Settings).
```
Log empty state (first hand, before any action): "Actions will appear here." (verbatim).

### 4.12 Hand-over: reveal, results, next hand

Sequence (all skippable by tapping Next hand):

1. Cards flip for everyone still in and — unless "Realistic reveals" is on — for folded players
   too (dimmed 45 %). 240 ms flips, 120 ms stagger in seat order.
2. Pot pill morphs into the **result banner** at the table centre (pop 250 ms):

```
   ┌──────────────────────────────┐
   │      +4.5 bb                 │ Bricolage 26, good/bad/muted colour
   │ You won the pot              │ or "Hand over"
   │ Ivey wins with a flush.      │ or "Ivey takes it down." (verbatim templates)
   │ See everyone's cards  ›      │ tap → Hand reveal sheet
   └──────────────────────────────┘
```
3. Chips slide to the winner(s) (450 ms), stacks tick. Side pots animate one after another
   with their "Main pot / Side pot n" label shown for 600 ms.
4. Action zone shows **Next hand** (primary) + Explain last move.

**Hand reveal sheet** (55 %): one row per opponent — two 20×28 cards (folded rows dimmed) +
name + the teaching line from `revealNote` ("Folded before the flop — too weak to play from MP.",
"Folded on the turn — the full board would have given them a straight.", "Won with two pair,
queens and sevens."). Swiping the sheet down or tapping Next hand deals the next hand; the sheet
re-opens automatically at the next hand-over only if the user opened it on 2 consecutive hands
(learn-by-reveal mode), otherwise stays as the banner link. With "Realistic reveals" on, folded
players' rows show face-down cards and only "Folded on the turn."

### 4.13 Session stats, end session, summary

End session: Session sheet → "End session", or Leave → "End session" from the Lobby's resume
card. Busting opens the summary automatically with the title "Session over — you busted" and
no close button (only "New session" continues, as desktop).

Session summary (full-screen modal):

```
┌──────────────────────────────────────────┐
│ ✕            Session summary             │
│ 41 hands played this session.            │
│ ┌──────────────────────────────────────┐ │
│ │ HOW YOU PLAYED (BEFORE HOW IT PAID)  │ │ gold-outlined card (verbatim copy)
│ │ 18 coached decisions, 2 flagged as   │ │
│ │ mistakes (11% vs your usual 14% —    │ │
│ │ cleaner than average).               │ │
│ │ Best: a turn raise worth +3.2 bb.    │ │
│ │ Costliest: a river call (−3.1 bb) —  │ │
│ │ it's in your Review queue.           │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────┬──────────┐                  │
│ │ Net      │ bb / 100 │                  │ 2×2 stat tiles
│ │ +12.5 bb │ +30.5    │                  │
│ ├──────────┼──────────┤                  │
│ │ Big win  │ Big loss │                  │ ("Biggest win" / "Biggest loss")
│ │ +18 bb   │ −9.5 bb  │                  │
│ └──────────┴──────────┘                  │
│ 6 hands reached showdown. Replay any     │
│ hand below, or export the full history   │
│ for a poker tracker.                     │
│ Review hands                             │
│  Hand #41   +6.0 bb        ▷ Replay  ✎   │ rows 48 pt; ✎ = note/tag (gold when set)
│  Hand #40   −1.0 bb        ▷ Replay  ✎   │ swipe left on a row → "Note" action
│  …                                       │
│ ┌────────────┐ ┌───────────────────────┐ │
│ │ ⇪ Share    │ │     New session       │ │ Share → system share sheet (.txt)
│ └────────────┘ └───────────────────────┘ │
└──────────────────────────────────────────┘
```
"Share" replaces desktop's Copy + Export: the share sheet offers Copy, Save to Files, AirDrop,
Mail, Nearby Share etc. with the PokerStars-style `all-in-session-{timestamp}.txt` attached and
the same text as the clipboard payload. Closing the summary with ✕ returns to the table and the
session continues (as desktop: "End" opens the summary; only "New session" rebuilds the table).

### 4.14 Empty states on the table

- No hand yet (just started): the felt shows dashed board slots and the pot pill "0 bb"; the deal
  starts within 300 ms so this is transitional.
- Session suspended and resumed mid-hand: the table restores exactly; a 2 s caption "Resumed —
  Hand #13, flop" under the top bar.
- Coach disabled: the Coach badge is absent; the Session sheet Pace segment shows the switch.
- Leaving mid-hand: "Leave table?" alert — "Your session is kept. Come back any time from Home
  or Play." / Cancel · Leave. Leaving between hands needs no confirmation.

---

## 5. DRILLS

Chess-puzzle rhythm on a phone: see the spot, scrub the story if you need it, answer with one
tap, read the verdict, next. One puzzle per screen, answer row always under the thumb, feedback
rises from the bottom without hiding the table.

### 5.1 Drills root (mode picker + spot)

```
┌──────────────────────────────────────────┐
│ Drills                             [ⓘ]   │ 44 title; ⓘ → mode blurb sheet
│ ⟨ Mixed ● ⟩⟨ Push / Fold ⟩⟨ Exploits ⟩⟨ Review 3 ⟩│ mode chips 36 pt, h-scroll, badge on Review
│ Rating 1084 · 71 % · streak 4 · best 9   │ stats strip 32 pt (mono); tap → explanation sheet
│ ◔ Today 14/20        Day streak 6        │ hidden in Review mode (as desktop)
│   ╭──────────────────────────────────╮   │ drill table 300 pt (same felt, 6 fixed seats)
│   │      ┌────┐                      │   │
│   │ ┌────┐ UTG │ ┌────┐              │   │ plates 72×36: position + "Folded"/"In hand"
│   │ │ MP │Fold│ │ CO ▯▯│             │   │ seat with cards = still in hand
│   │ │Fold│    │ │In hd │             │   │
│   │ └────┘    └────┘                 │   │
│   │            FLOP · 7.5 bb         │   │ street caption + pot pill (frame values)
│   │        ┌──┐ ┌──┐ ┌──┐            │   │ board 44×62 (frame board)
│   │        │A♠│ │7♦│ │2♣│            │   │
│   │ ┌────┐            ┌────┐         │   │
│   │ │ SB │            │ BB │         │   │
│   │ │Fold│            │Fold│         │   │
│   │ └────┘   ┌──┐┌──┐ └────┘         │   │ hero cards 48×67 face-up, gold-ringed plate
│   │          │K♥││Q♥│  You · BTN     │   │
│   ╰──────────────────────────────────╯   │
│ ‹‹  ‹   ● 5 / 6  "CO bets 5 bb"    ›  ›› │ move navigator 44 pt (see 5.2)
│ Your hand  KQs         Post-flop heuristic · fundamentals │ 20 pt: label (gold Bricolage) + source pill
│ ┌──────────┐┌──────────┐┌──────────────┐ │ answer row 56 pt (2 or 3 options)
│ │   Fold   ││  Call 5  ││ Raise to 16  │ │
│ └──────────┘└──────────┘└──────────────┘ │
│ ┌────┬────┬────┬────┬────┐               │ tab bar
└──────────────────────────────────────────┘
```

- Mode chips carry the verbatim labels; **"Review"** shows a count pill ("3") when due > 0 —
  the same number badges the Drills tab. Tapping a chip calls `setMode` and swaps the spot
  with a 200 ms crossfade. Long-press a chip → its verbatim blurb in a sheet.
- The stats strip is one line so the table gets the height. Each stat is a 44 pt-tall tap target
  → explanation sheet with the verbatim tooltip (Rating: "A self-adjusting puzzle rating…";
  Today: "A quiet daily goal…"). "Day streak" appears only when > 0.
- The drill table uses the fixed 6-seat anchors (hero bottom-centre, others clockwise from
  lower-right), plates 72×36 with position code bold and the caption `Folded` (faint) or
  `In hand` (info); folded seats 25 % opacity + greyscale. Seat plates are not tappable (no
  archetype to inspect — Exploit spots put the archetype in the frame text instead).
- Answer row: 2 options → two equal buttons; 3 options → 30/33/37 % like the table so the muscle
  memory (Fold left, aggressive right) carries over. Labels verbatim from `option.label` ("Fold",
  "Call 2.5 bb", "Raise to 7.5 bb", "Shove 12 bb"). A keycap "1/2/3" is **not** shown (no
  keyboard) but hardware keyboards still map 1/2/3 and Enter.
- Source pill is verbatim: "Pre-flop chart · 100bb baseline" / "Post-flop heuristic ·
  fundamentals" / "Push/Fold · computed Nash" / "Push/Fold · ICM bubble" / "Exploit · vs a known
  type" / "Your flagged spot". Tap → a one-line explanation sheet of what graded the spot (from
  About's "How the grading works", the matching paragraph).
- At 360×780 the table shrinks to 264 pt and the stats strip merges with the Today line.

### 5.2 Move navigator (replaying the action to the decision)

The desktop list of frames becomes a **scrubber row**: `‹‹` (first), `‹` (previous), a centre
pill "● 5 / 6 · CO bets 5 bb" showing the current frame index and its text, `›` (next),
`››` (Decision). Buttons are 44×44. The current frame's text is what the user reads; the table
above re-renders that frame's board, pot and folded seats.

- **Swipe left/right anywhere on the drill table** = next / previous frame (horizontal drag,
  40 pt threshold, `selectionClick` per frame). This is the primary way to "watch the hand"
  with one thumb.
- **Long-press the centre pill** → **Frame list sheet**: all frames as rows (index in mono, text;
  last row bold with a target icon = the decision point); tap a row jumps. This is the desktop
  list, on demand.
- The spot always opens **on the decision frame** (as desktop, `navIndex = last`); a 1.2 s
  "◂ swipe to replay the action" hint appears on the table the first five times only.
- Answering snaps to the decision frame. Scrubbing after answering is allowed (the feedback
  panel collapses to its compact detent while the finger is on the table).

### 5.3 Answering and the feedback panel

Tap an option → `answer(action)`; the button scales 0.97 with a medium haptic; all options
lock; the accepted option(s) turn green, a wrong pick turns red, the rest dim (as desktop).
Then the **Feedback panel** slides up (280 ms spring) from behind the answer row:

```
┌──────────────────────────────────────────┐
│   (table still visible, dimmed 20 %)     │
│ ┌──────────────────────────────────────┐ │
│ │ ✕  Not optimal                  −6   │ │ header: red X badge / green check; rating delta
│ │    That choice costs about 1.2 bb    │ │ mono, flies up to the stats strip after 600 ms
│ │    every time — a real leak.         │ │ EV-loss line (verbatim; only when wrong & > 0.05)
│ │──────────────────────────────────────│ │
│ │ You're getting 3:1 and this hand     │ │ LAYER 1 · rationale paragraph (verbatim)
│ │ wins about 1 time in 3 — the call    │ │
│ │ makes money.                         │ │
│ │ Folding: 0 bb — costs nothing more.  │ │ per-option outcomes box (pot-odds spots)
│ │ Calling: +2.6 bb per try — your hand │ │
│ │ wins about 1 time in 3 and you need  │ │
│ │ about 1 time in 4.                   │ │
│ │ ▸ Show me the math                   │ │ LAYER 2 · "Equity: 33% · Pot odds: 25%" + EV line
│ │ ▸ See the range it was graded against│ │ LAYER 3 · 13×13 read-only matrix + gradeRangeTitle
│ │ ┌───────────────┐ ┌────────────────┐ │ │
│ │ │ 📖 Pot Odds… │ │ ◎ Drill 5 similar│ │ │ secondary row (lesson title / hidden in Review)
│ │ └───────────────┘ └────────────────┘ │ │
│ │ ┌──────────────────────────────────┐ │ │
│ │ │          Next puzzle           › │ │ │ Primary 56, pinned at the panel's bottom
│ │ └──────────────────────────────────┘ │ │
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

- **Detents**: compact (header + EV line + rationale + Next, ≈ 300 pt) and expanded (92 %).
  The panel opens compact; opening a disclosure expands it. Dragging down past compact does not
  dismiss — the verdict stays until Next (the desktop feedback never disappears either).
- **Three layers, always**: layer 1 = verdict + rationale (+ the per-option outcome box when
  `equity`/`potOdds`/`toCall` exist); "Show me the math" = the "Equity: 33%" / "Pot odds: 25%"
  line plus the EV arithmetic rewritten as steps ("Pot 24 + call 8 = 32; 33 % × 32 − 8 ≈ +2.6
  bb"); the third row is "See the range it was graded against" (or "Expert detail: no range for
  this spot" for leak puzzles). Labels toggle to "Hide the math" / "Hide the range".
- **Rating delta**: "+12" / "−6" in the header (only in practice modes), then animates to the
  stats strip whose Rating number rolls to the new value. Review mode shows no delta.
- **Lesson link**: secondary button labelled with `lessonTitle` (fallback "Read the lesson") →
  opens the lesson reader as a full-screen modal over Drills (Done returns to the same puzzle).
- **"Drill 5 similar"** (practice, non-leak only) → `drillSimilar()`; the caption "4 more of
  this spot type coming up" (verbatim `{n} more…`) shows under the answer row for the run.
- **Next puzzle**: primary; also reachable by swiping the panel up past the expanded detent
  (overscroll) — a small "release for next" hint — for one-thumb chains.
- Streak: a correct answer pulses the "streak" number; a wrong one resets it with a 200 ms
  shake. No sounds. Success haptic on correct, `warning` on wrong.

### 5.4 Rating, streak, daily goal display

| Element | Where | Copy / behaviour |
|---|---|---|
| Rating | stats strip (gold mono) | "Rating 1084"; tap → sheet with the verbatim tooltip and a 30-day sparkline of the rating (new) |
| Accuracy | stats strip | "71 %" = `round(correct/solved×100)`; "0 %" when nothing solved |
| Streak / Best | stats strip | "streak 4 · best 9" |
| Today | second line, ring 20 pt | "14/20" (`min(today,20)/20`), gold ring when met; tap → tooltip sheet |
| Day streak | second line | "Day streak 6"; hidden at 0 |
| Tab badge | Drills tab | Review due count |

The whole strip is hidden in Review mode (desktop parity) and replaced by "Review · 3 due ·
7 scheduled" so the user knows the queue size.

### 5.5 Review / "My leaks" queue

Review mode serves a uniform random pick from due leak spots and due missed drills. Presentation
is the standard spot with two differences: the source pill reads "Your flagged spot" for leak
puzzles (frames: "Flop: Ah 7d 2c" → "Action on you in the CO facing 2.0 bb. What's the play?")
and the feedback header gets a schedule line: "Back in 10 minutes" (wrong) / "Next in 1 day ·
1 of 3" / "Next in 3 days · 2 of 3" / "Retired — beaten 3 times" (correct, graduated). The
feedback for the last due card stays visible until Next (fixes the desktop vanishing-feedback
quirk); Next then shows the empty state.

Empty state (centred block, 48 pt green check badge):

```
┌──────────────────────────────────────────┐
│ Drills                                   │
│ ⟨ Mixed ⟩⟨ Push / Fold ⟩⟨ Exploits ⟩⟨ Review ● ⟩│
│                                          │
│                 ✓                        │
│        Nothing due right now             │ or "No spots to review yet"
│  All 7 of your review spots are          │ verbatim bodies
│  scheduled for later — spaced practice   │
│  sticks best when you come back to it.   │
│  Play or drill in the meantime.          │
│  Next due: tomorrow 09:14                │ new: earliest `srs.due`, local time
│ ┌────────────────┐ ┌───────────────────┐ │
│ │ ▶ Play a session│ │ ◎ Drill Mixed     │ │ two 48 pt secondary buttons
│ └────────────────┘ └───────────────────┘ │
└──────────────────────────────────────────┘
```

### 5.6 Push/Fold and ICM specifics

Push/fold spots always have exactly two options, so the answer row is two 56 pt buttons
("Fold" · "Shove 12 bb" / "Call 11 bb"). Extra context lives in a **stacks strip** between the
table and the navigator:

```
│   ╭──────────────────────────────────╮   │
│   │  UTG Fold   MP Fold   CO Fold    │   │ folded-before seats
│   │        (BTN) ▯▯  In hand         │   │
│   │        PRE-FLOP · 1.5 bb         │   │
│   │  SB  You ◆ 12 bb      BB  ▯▯ In hand│ │
│   ╰──────────────────────────────────╯   │
│ Stacks 12 bb · Blinds 0.5/1 · Nash chip-EV, no antes │ stacks strip 28 pt (verbatim frame text)
│ ‹‹  ‹  ● 3 / 3 "Folded to you in the SB with 12 bb. Shove or fold?"  ›  ›› │
│ Your hand  A5s            Push/Fold · computed Nash │
│ ┌───────────────────┐┌───────────────────┐ │
│ │       Fold        ││    Shove 12 bb    │ │
│ └───────────────────┘└───────────────────┘ │
```

ICM bubble spots (a third of push/fold reps, `icm: true`) add a **bubble banner** above the
stacks strip: gold-outlined, "BUBBLE · 4 left, 3 paid · 50 / 30 / 20" and the scenario name
("Chip leader in the BB"); the frame text carries the verbatim stacks line and the scenario
blurb. The table shows the four live stacks as labels on the SB/BB/other plates ("45 bb", "15 bb")
and CO/BTN plates read "In hand" (as desktop: neither folded nor active). The feedback panel's
layer-1 rationale includes the verbatim `icmNote` ("Bubble: 4 players left, 3 get paid…"), and
the grading-range disclosure is titled "ICM SB shoving range — Chip leader in the BB". Mixed-
frequency hands (0.2 < freq < 0.8) accept either answer; the feedback then says "Either answer
is fine here — this hand is a mix in the equilibrium." (verbatim from `gradeFromFreq`).

### 5.7 Exploits mode

Exploit spots name the opponent type in the frame text ("The button is a Calling Station…").
The drill table colours that seat's plate ring with the archetype colour and shows its
"46/7" numbers, so the HUD-reading skill from Play carries over. Feedback shows both numbers
the desktop shows (balanced vs exploitative) in layer 2.

### 5.8 Placement test (from Onboarding and Settings → "Run again")

Full-screen modal, no tab bar. Eight questions, one per screen, auto-advance:

```
┌──────────────────────────────────────────┐
│ ✕                          ▰▰▰▱▱▱▱▱     │ 8-segment progress (3 of 8 done)
│ QUESTION 4 OF 8                          │ eyebrow (verbatim "Question 4 of 8")
│                                          │
│ A flush draw on the flop (9 outs, two    │ Bricolage 22
│ cards to come) has roughly what chance   │
│ of hitting?                              │
│                                          │
│ ┌────────────────────────────────────┐   │
│ │ About 18%                          │   │ options 56 pt, full width, shuffled order
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ About 36%                          │   │ picked → green/red flash 350 ms then advance
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ About 9%                           │   │
│ └────────────────────────────────────┘   │
│                                          │
│ No grade, no judgment — you can stop     │ faint footer
│ any time.                                │
└──────────────────────────────────────────┘
```

Intro page (verbatim): "Eight quick questions calibrate the drills to your level — harder spots
if you're experienced, clearer ones if you're new. No grade, no judgment, and you can skip it."
Buttons "Skip — start playing" (ghost) / "Calibrate me" (primary). Result page: gold card with
the level line ("You know the basics.") and "{score}/8 — drills are calibrated to match. {advice}";
buttons "Take me there" (secondary → the advised lesson) and "Start playing" (primary → Home).
Seeding: ≤ 2 → 900, ≤ 5 → 1050, else 1250 (`seedRating`). Closing with ✕ mid-quiz keeps the
current rating untouched.
