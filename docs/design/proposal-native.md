# All-In · Poker Dojo — Mobile UX Proposal ("Native idioms first")

Target: Flutter, iOS + Android phones, portrait. Design canvas 390×844 pt (iPhone 15/16 class);
must also hold at 360×780 (compact Android) and stretch cleanly to 430×932.
Brand: green felt + gold accent. Fonts: Bricolage Grotesque (display), Inter (body),
JetBrains Mono (every number that changes).

This document re-imagines the desktop app for one hand and one thumb. Every desktop feature is
accounted for in §15. Sizes are in pt; every tappable target is ≥ 44×44 pt unless a note says why
it is a paint surface rather than a button.

---

## 1. Design principles

1. **The next decision is always under the thumb.** Fold / Check-Call / Raise, "Next action",
   "Next hand", drill answers and "Next puzzle" live in the bottom 180 pt of the screen. Nothing
   used more than once a minute is above the midline.

2. **One immersive surface for play; everything else is a sheet on top of it.** The table is a
   full-screen route with no tab bar. Coach notes, player reads, the hand log, session stats and
   pace all arrive as bottom sheets that never cover the action bar, so the user never loses the
   felt.

3. **Three layers, always visible as three layers.** Every coach note, drill rationale and stat
   explanation renders as: plain-English paragraph (open) → "Show me the math" disclosure →
   "Expert detail" disclosure. The two collapsed rows are always present, even when empty of
   extra content, so the structure teaches itself (TONE.md).

4. **Interrupt only for money.** Non-blocking verdicts are a slim chip that folds itself away;
   only a blocking mistake stops the hand and demands "Got it". No toasts, no confetti, no
   streak nagging — the app judges the decision, never the person.

5. **Touch replaces hover, never removes it.** Every hover affordance on desktop (HUD tooltip,
   glossary term, stat hint, eye-to-guess) has a tap target (player sheet, term callout,
   explanation sheet, seat tap). Nothing is only discoverable by hovering or by keyboard.

6. **Platform-honest, brand-consistent.** Material 3 navigation bar, modal sheets and predictive
   back on Android; Cupertino sheet grabbers, edge-swipe back and iOS haptic vocabulary on iOS.
   The felt, cards, matrix and coach card are identical on both.

7. **Numbers are mono, chances are counts.** Every changing number (stack, pot, bb, %, rating)
   is JetBrains Mono so columns don't jitter. Layer-1 copy uses "about 1 time in 4", not "25 %".

---

## 2. Information architecture

### 2.1 Root tabs (bottom navigation, 5 items)

| Tab | Icon | Root screen | Notes |
|---|---|---|---|
| Home | house | **Today** | Daily goal, streak, due reviews, continue lesson, quick session, last session. Gear → Settings. |
| Play | cards | **Lobby** (table setup / resume) | If a session is live, tapping the tab opens the **Table** route directly. |
| Drills | target | **Drills** | Mode chips + spot. Badge shows Review due count. |
| Study | book | **Study path** | 5 levels / 31 lessons + Practice tools. |
| Stats | chart | **Progress** | Overview, breakdowns, hands, heatmap, import/export. |

Tab bar: Material 3 `NavigationBar` (80 pt incl. label) on Android; `CupertinoTabBar`-styled 49 pt +
home indicator on iOS. Active colour gold, inactive muted. The bar is hidden on the Table route,
in Guess Range, in Onboarding and in full-screen modals.

### 2.2 Screen inventory and navigation graph

```
TabScaffold
├─ Home / Today ──────────────┬─ push  Settings ── push About
│                             ├─ modal Table (if "Quick session")
│                             ├─ tab-jump Drills(Review)
│                             ├─ tab-jump Study → push Lesson
│                             └─ push Session summary (last session)
├─ Play / Lobby ──────────────┬─ modal TABLE (full-screen, tab bar hidden)
│                             │    ├─ sheet  Coach note (2 detents: 55 % / 92 %)
│                             │    │     └─ in-sheet push  Assumed range (13×13, read-only)
│                             │    ├─ sheet  Player card (archetype, HUD, actions)
│                             │    ├─ modal  GUESS RANGE (full-screen) → Peek result (same route)
│                             │    ├─ sheet  Session & log  (segments: Log · Session · Pace)
│                             │    ├─ sheet  Hand reveal (hand-over teaching lines)
│                             │    ├─ sheet  Bet keypad (numeric bb entry)
│                             │    ├─ modal  SESSION SUMMARY (full-screen, on End / bust)
│                             │    │     ├─ push  Hand replayer
│                             │    │     └─ sheet Note editor
│                             │    └─ dialog Leave table? (only when a hand is mid-action)
│                             └─ push  Session summary (of a past session)
├─ Drills ────────────────────┬─ modal Lesson reader (from feedback "Read the lesson")
│                             ├─ sheet Stat explanation (rating / today / streak)
│                             └─ modal Placement test (from Settings deep link)
├─ Study ─────────────────────┬─ push  Lesson reader
│                             │    ├─ popover Glossary term callout
│                             │    ├─ push  Glossary (searchable)
│                             │    └─ sheet Card picker (equity calculator)
│                             └─ push  Glossary
└─ Stats ─────────────────────┬─ sheet Stat explanation
                              ├─ push  Hand replayer ── sheet Note editor
                              ├─ push  All hands (filter by tag)
                              ├─ system File picker → sheet Import result
                              ├─ system Share sheet (export .txt / backup .json)
                              └─ push  Settings (Data section)
Onboarding (first run, full-screen modal over everything): Tour(4) → Placement intro → Quiz(8) → Result
```

### 2.3 Sheet vs push vs full-screen modal

| Use | Pattern | Why |
|---|---|---|
| Something *about* what is on screen (coach note, player read, stat meaning, hand log, note) | **Bottom sheet**, draggable, grabber, scrim 40 %, never covers the action bar when the table is the parent (max detent leaves 120 pt) | Keeps context visible; one swipe closes |
| Reading content with hierarchy (lesson, replayer, settings, about, all-hands list) | **Push** with back chevron / edge-swipe / predictive back | Linear reading, back is natural |
| A task with its own completion (live session, painting a range, summary, onboarding, placement, lesson opened from a drill) | **Full-screen modal** with explicit Close/Done, tab bar hidden | Focus; the system back gesture maps to "leave/close" |
| Confirming a destructive or irreversible action (leave mid-hand, erase data) | **Alert dialog** (adaptive) | Interrupts on purpose |

System back gesture: sheet → close; Table → "Leave table" (suspends the session — never ends
it); Guess Range → close without peeking; blocking coach sheet → equals "Got it".

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
- Greeting copy: "Good morning/afternoon/evening." The first run after onboarding says
  "Start with a session — the coach explains as you go."
- Tip card (desktop sidebar tip) is folded into "Coach's note": leak text if any, otherwise a
  rotating one-liner from the cheat sheet ("Half-pot bet → you need to win about 1 time in 4").

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
│ ⓘ Coach charts assume 6-max — verdicts   │ shown only when ≠ 6
│   at other table sizes use the nearest   │
│   position as an approximation.          │
│                                          │
│ Pace          Manual ● │ Auto            │ small segmented (remembered)
│ EV Coach                          [ on ] │
│                                          │
│ A session deals hand after hand against  │
│ a fixed table of bots. Your stack        │
│ carries over until you end the session.  │
│                                          │
│ ┌────────────────────────────────────┐   │
│ │ ▶          Start session           │   │ Primary 56, pinned above tab bar
│ └────────────────────────────────────┘   │
│ ┌────┬────┬────┬────┬────┐               │
└──────────────────────────────────────────┘
```

If a session is suspended: a **Resume** card sits above the setup ("Hand #13 · +8.5 bb ·
41 hands · Resume ›") and "Start session" becomes "Start a new session" (destroys the suspended
one after a confirmation alert: "End the current session? You'll get its summary first.").

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
("Negrea…"); at 9-max on 360 pt the board drops to 40×56.

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
- **Tap plate** → **Player sheet** (below). **Long-press plate** → Guess Range directly (shortcut;
  haptic medium). Both are ≥ 44 pt because the plate is 96×44 and the cards add 39 pt above.
- **Tap action bubble** → Explain last move for that player (if it was the last action).

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
│ pre-flop, PFR = how often they raise…    │
│ ┌────────────────────────────────────┐   │
│ │ 👁  Read their range               │   │ Primary → Guess Range (only while in hand)
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ ◉  Explain their last move         │   │ Secondary (only if they acted last)
│ └────────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

### 4.4 Hero strip

64×90 cards (rank Bricolage 800 at 23 pt, suit glyph 17 pt + big corner suit 32 pt at 92 %),
overlapping by 8 pt with a 4° fan; tap either card to un-fan (cosmetic). To the right: "You · BTN"
(13 semibold), "98.5 bb" (mono 15 gold-light), hand label "QQ" (Bricolage 15) with the plain name
("pocket queens", "ace-king suited"), committed pill, and after 8 hands the self-stats line
"Your style 24/19 · 12h" (tap → explanation sheet with the healthy-range text from the desktop
tooltip). Dealer disc appears here when hero is BTN. At hand-over, the hero strip shows the made
hand ("Two pair, queens and sevens").

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
  pot-after-call; identical math to the desktop `setFraction`). Default selection = ⅔ (desktop's
  0.66 default).
- **Gesture**: touch anywhere on the 48 pt band and drag horizontally; the knob follows the finger
  with 0.5 bb quantisation, snapping (magnet ±6 pt) to ticks with a `selectionClick` haptic on each
  tick. **Tap** a tick label to jump. Release does **not** commit — the Raise button commits.
- The Raise button label updates live ("Raise to 8"); the price hint line updates to what the
  opponent would need ("If they call they need to win about 1 time in 3").
- **Tap the Raise amount text (or long-press the button)** → **Bet keypad sheet**: a mono display
  "8.0 bb", ±0.5 stepper, numeric keypad, and the same preset chips; "Set" returns to the table
  with the amount selected (still not committed). Clamped to `[minRaiseTo, maxRaiseTo]` with an
  inline "min 5 bb / max 98.5 bb" caption.
- **All-in** tick turns the Raise button red-gold ("All-in 98.5") and the commit requires a second
  tap within 2 s ("Tap again to confirm") — the only two-step commit on the table.
- Reachability: the rail sits at y 706–754, inside the thumb arc of a right- or left-handed grip;
  ticks nearest the thumb (right side) are Pot/All-in for right-handers — mirrored when the
  "Left-handed layout" setting flips the action row to Raise · Check · Fold.

**Bot to act, Manual pace:**

```
│ ◉ Explain last move          (ghost)     │
│ ┌────────────────────────────────────┐   │
│ │ Next action                     ›  │   │ Secondary 56, full width
│ └────────────────────────────────────┘   │
```
Also: **tap anywhere on the felt** advances one bot action (same as the button) — the felt is
the biggest target on screen. A caption "Tap the table or Next action to step through" shows
under the button for the first three hands of the user's life, then never again.

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
   "PRE-FLOP" fades in over the pot.
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
note is up (mirrors `paused || guess.open` in the store).

### 4.8 The EV Coach on mobile

**Non-blocking notes → the coach chip.** A 36 pt chip slides down under the top bar (never over
the action bar), 260 ms spring. Content: verdict badge + "Nice play" + the first clause of the
plain sentence, ellipsised. It stays 4 s (8 s at "Slow" pace), then folds into the top-bar
**Coach badge** `[◉ 2]` (count = notes this hand). Tap chip → coach sheet at 55 %. Chips never
stack: a second note replaces the first with a crossfade, the badge count increments.

**Blocking mistakes → the coach sheet opens itself.** The hand pauses (auto-play stops, the
action zone greys). The sheet opens at 55 % with a red header; swipe-down and "Got it" both
dismiss and resume. The sheet cannot be dismissed by tapping the scrim (the scrim is 40 % but
non-interactive for blocking notes) so the acknowledgement is deliberate.

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
│ White line = 25 % needed (pot odds)      │
│                                          │
│ ▸ Show me the math                       │ LAYER 2 · disclosure row 48 pt
│ ▸ Expert detail                          │ LAYER 3 · disclosure row 48 pt
│                                          │
│ Expected value              −2.0 bb      │ EV tile
│ ┌───────────────┐ ┌────────────────────┐ │
│ │ 👁 View range │ │      Got it        │ │ 48 pt; Got it is primary
│ └───────────────┘ └────────────────────┘ │
└──────────────────────────────────────────┘
```

- Opening "Show me the math" expands a numbered list (steps verbatim from the store) and grows
  the sheet to 92 %; "Expert detail" adds the bullet list (source line, precision, baseline
  note). Labels toggle to "Hide the math" / "Hide expert detail".
- Multiway warning renders as an amber callout between layer 1 and the equity bar.
- **View range** pushes, inside the sheet, a read-only 13×13 matrix titled "Ivey's assumed range"
  with the desktop description and the combos/percent line; a back chevron returns to the note.
- **Reopening past notes**: tap the top-bar Coach badge → the sheet opens on a list of this hand's
  notes (verdict badge, title, street, one-line plain text); tap a row to expand it. Notes are
  per hand (as on desktop: `reviewLog` resets on deal); older hands' notes are reachable from
  the hand replayer's "Coach notes" segment in Stats.
- **Explain last move** produces a "Read" note (blue eye badge) in the same sheet; its layer 2 and
  3 rows read "No math for a read — this is an interpretation of their style" and the range
  button shows their assumed range.
- Coach off: the badge disappears; the Pace segment of the Session sheet holds the toggle.

### 4.9 Guess Range → Peek

Entry: Player sheet → "Read their range", long-press a seat, or the Coach note's "View range"
(read-only variant). Opens a **full-screen modal** (the matrix needs the full width). Opening
pauses the hand (as desktop).

```
┌──────────────────────────────────────────┐
│ ✕      Read Ivey's range           Peek  │ 44 top bar; Peek = primary text button
│ UTG · Tight-Aggressive · Flop            │ 13 muted
│ Paint the hands you think they have —    │
│ or just peek to study their range.       │
│    A  K  Q  J  T  9  8  7  6  5  4  3  2 │ header row 20 pt (tap = select column)
│ A ▓▓ ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │
│ K ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ 13×13 grid, cells 26 pt + 2 pt gap
│ Q ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ = 364 pt square at 390 wide
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
│ │ ↶ Undo │ │ Clear  │ │  Peek & score  │ │ 48 pt; Peek label changes when painted
│ └────────┘ └────────┘ └────────────────┘ │
│ Guessing is optional — peek any time.    │
└──────────────────────────────────────────┘
```

Painting with a finger (the exact gesture spec):

- **Cell size** 26×26 pt (+2 gap) at 390 wide, 25 at 360, 29 at 430. These are below 44 pt on
  purpose: the matrix is a paint surface, not 169 buttons. Precision comes from drag-paint, the
  loupe and row/column selectors.
- **Touch-down** on a cell decides the stroke mode: if the cell is empty → *add* mode, else
  *remove* mode (identical to desktop `addModeRef`). The cell toggles immediately.
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
  snackbar). Preset chips replace the current paint (also undoable).
- The grid never scrolls; the sheet content below it does not scroll either (everything fits in
  844 pt; at 780 pt the preset row and legend merge into one 36 pt line).
- Two-finger pinch is *not* used for zoom (conflicts with paint). Accessibility zoom users get the
  OS zoom.

**Peek / Reveal screen** (same route, content crossfades 200 ms):

```
┌──────────────────────────────────────────┐
│ ✕      Ivey's range revealed             │
│ ┌──────────────────────────────────────┐ │
│ │        72 %          SOLID           │ │ Bricolage 44 gold; grade label (Sharp read /
│ │ You caught about 8 in 10 of their    │ │ Solid / Rough / Way off, same thresholds)
│ │ hands (coverage 81 %). About 7 in 10 │ │ plain-English recall / precision
│ │ of what you painted was right        │ │
│ │ (precision 68 %).                    │ │
│ └──────────────────────────────────────┘ │
│    (13×13 compare matrix)                │ green = correct · amber = missed · red = extra
│ ■ Correct ■ Missed ■ Extra  Their range: │
│                             182 combos   │
│ Everyone's exact cards are revealed when │
│ the hand ends.                           │
│ ┌────────────────────────────────────┐   │
│ │             Continue               │   │ Primary 56 → closes, resumes hand
│ └────────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

If nothing was painted: the matrix shows the highlighted actual range and the score card reads
"Here's Ivey's assumed range. Paint a guess first next time for an accuracy score." Peek reveal
gets a medium haptic; a "Sharp read" gets the success pattern.

### 4.10 Explain last move

Available whenever the last actor was a bot: ghost button in the bot-turn and hand-over action
zones; "Explain their last move" in the Player sheet; tapping a bot's action bubble. It opens the
coach sheet with a "Read" note (blue eye) built from `interpretBot` text, and the "View range"
button. It never pauses auto-play for more than the time the sheet is open.

### 4.11 Hand log and session stats access

Top-bar `[≡]` → **Session sheet**, 3 segments (remembers the last one):

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
Pace segment: Manual/Auto segmented, Slow/Normal/Fast (visible only for Auto), EV Coach switch,
Auto-deal next hand switch, Realistic reveals switch (mirrors Settings).
```

### 4.12 Hand-over: reveal, results, next hand

Sequence (all skippable by tapping Next hand):

1. Cards flip for everyone still in and — unless "Realistic reveals" is on — for folded players
   too (dimmed 45 %). 240 ms flips, 120 ms stagger in seat order.
2. Pot pill morphs into the **result banner** at the table centre (pop 250 ms):

```
   ┌──────────────────────────────┐
   │      +4.5 bb                 │ Bricolage 26, good/bad colour
   │ You won with two pair.       │ or "Ivey wins with a flush." / "Ivey takes it down."
   │ See everyone's cards  ›      │ tap → Hand reveal sheet
   └──────────────────────────────┘
```
3. Chips slide to the winner(s) (450 ms), stacks tick.
4. Action zone shows **Next hand** (primary) + Explain last move.

**Hand reveal sheet** (55 %): one row per opponent — two 20×28 cards (folded rows dimmed) +
name + the teaching line from `revealNote` ("Folded before the flop — too weak to play from MP.",
"Folded on the turn — the full board would have given them a straight."). Swiping the sheet
down or tapping Next hand deals the next hand; the sheet remembers if it was open and re-opens
automatically at the next hand-over only if the user opened it on 2 consecutive hands
(learn-by-reveal mode), otherwise stays as the banner link.

### 4.13 Session stats, end session, summary

End session: Session sheet → "End session", or Leave → "End session" from the Lobby's resume
card. Busting opens the summary automatically with the title "Session over — you busted".

Session summary (full-screen modal):

```
┌──────────────────────────────────────────┐
│ ✕            Session summary             │
│ 41 hands played this session.            │
│ ┌──────────────────────────────────────┐ │
│ │ HOW YOU PLAYED (BEFORE HOW IT PAID)  │ │ gold-outlined card (verbatim copy)
│ │ 18 coached decisions, 2 flagged as   │ │
│ │ mistakes (11 % vs your usual 14 % —  │ │
│ │ cleaner than average).               │ │
│ │ Best: a turn raise worth +3.2 bb.    │ │
│ │ Costliest: a river call (−3.1 bb) —  │ │
│ │ it's in your Review queue.           │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────┬──────────┐                  │
│ │ Net      │ bb/100   │                  │ 2×2 stat tiles
│ │ +12.5 bb │ +30.5    │                  │
│ ├──────────┼──────────┤                  │
│ │ Big win  │ Big loss │                  │
│ │ +18 bb   │ −9.5 bb  │                  │
│ └──────────┴──────────┘                  │
│ 6 hands reached showdown. Replay any     │
│ hand below, or export the history.       │
│ Review hands                             │
│  Hand #41   +6.0 bb        ▷ Replay  ✎   │ rows 48 pt; ✎ = note/tag (gold when set)
│  Hand #40   −1.0 bb        ▷ Replay  ✎   │
│  …                                       │
│ ┌────────────┐ ┌───────────────────────┐ │
│ │ ⇪ Share    │ │     New session       │ │ Share → system share sheet (.txt)
│ └────────────┘ └───────────────────────┘ │
└──────────────────────────────────────────┘
```
"Share" replaces desktop's Copy + Export: the share sheet offers Copy, Save to Files, AirDrop,
Mail, etc. with the PokerStars-style `.txt` attached and the text in the clipboard payload.

### 4.14 Empty states on the table

- No hand yet (just started): the felt shows dashed board slots and the pot pill "0 bb"; the deal
  starts within 300 ms so this is transitional.
- Session suspended and resumed mid-hand: the table restores exactly; a 2 s caption "Resumed —
  Hand #13, flop" under the top bar.
- Coach disabled: the Coach badge is absent; the Session sheet Pace segment shows the switch.
