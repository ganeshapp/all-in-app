# All-In · Poker Dojo — Mobile UX Proposal (angle: table fidelity first)

Target: Flutter, iOS + Android phones, portrait-first. Reference frame 390×844 pt (iPhone 15/16);
must hold at 360×780 (small Android) and scale to 430×932 (large phones). Dark theme primary,
light parity. Brand: green felt + gold accent. Fonts: Bricolage Grotesque (display), Inter (body),
JetBrains Mono (numbers). All sizes below are in pt (logical pixels). Every tappable target is
≥ 44×44 pt unless stated otherwise (and then it has an extended hit slop that brings it to 44).

Sources read: `README.md`, `TONE.md`, `Notes.md`, `src/views/*.tsx`, `SideRail.tsx`,
`ActionBar.tsx`, `EVCoachPanel.tsx`, `GuessModal.tsx`, `RangeMatrix.tsx`, `drills/*.tsx`,
`study/*.tsx` (lessons skimmed), `StatsView.tsx`, `OnboardingModal.tsx`, `gameStore.ts`,
`Seat.tsx`/`PokerTable.tsx`/`HUD.tsx`/`PlayingCard.tsx`, `ResultOverlay.tsx`,
`SessionSummaryModal.tsx`, `HandReplayModal.tsx`, `SettingsView.tsx`, `AboutView.tsx`,
`tokens.css`, and `poker-zapp/docs/port/*.md`.

---

## 1. Design principles

1. **The table is the classroom.** Every pixel of the Play screen serves reading the table:
   seats, stacks, bets, board, pot, whose turn. The coach is layered *on top* of the table
   (chip → sheet), never beside it, and never covers the hero's cards or the action bar.
2. **The loop lives under the thumb.** Fold / Check-Call / Bet-Raise, "Next action", "Next hand",
   "Got it" all sit in the bottom 160 pt. Nothing you do every few seconds is above y = 650.
3. **One second to size a bet.** Six preset chips + a slider + a typed value; the primary button
   always shows the exact amount it will commit ("Raise to 7.5"). No modal, no confirm dialog.
4. **Plain English first, math on demand.** Every coach surface renders TONE.md's three layers
   as three visible tiers: layer 1 always open, "Show me the math" and "Expert detail" as
   disclosure rows. Never collapse layer 1; never auto-expand layer 3.
5. **Interrupt only for money.** Only a *blocking* mistake stops the hand (a sheet you must
   acknowledge). Everything else is a 4-second chip that shrinks into a badge you can reopen.
6. **Reads are earned, not given.** HUD numbers appear after 8 observed hands; the Guess Range
   flow always offers painting *before* peeking; hole cards are revealed only at hand end.
7. **Portrait-native, not shrunken.** Separate seat layouts for 2, 6 and 9 seats, a compact seat
   variant for 9-max, and card sizes chosen per slot. No pinch-zooming a desktop table.
8. **Quiet consistency.** No push notifications, no streak guilt. The daily goal is a small ring;
   the streak is a number that never nags.

---

## 2. Information architecture

### 2.1 Root tabs (bottom tab bar, 49 pt + safe area)

| Tab | Root screen | Notes |
|---|---|---|
| **Play** | Lobby (home / entry) | Table setup, resume-session card, today strip. The *table itself* is a full-screen route pushed from here with the tab bar hidden. |
| **Drills** | Drills home | Rating tiles, daily goal ring, mode cards, Review queue count. |
| **Study** | Level path | 5 levels / 31 lessons with progress. |
| **Stats** | Progress overview | KPIs, trend, breakdowns, hands, heatmap, import/export. |

Settings and About are not tabs: a gear icon in the Play-lobby and Stats headers opens
Settings (push); About is a row inside Settings. This keeps four tabs (thumb-reachable,
each ≥ 88 pt wide at 390) and gives the table a full-screen canvas.

A **"Session in progress"** pill (56 pt tall, above the tab bar) appears on every tab while a
session is paused off-table: `● 12 hands · +4.5 bb   Resume ›`. Tapping resumes the table.

### 2.2 Screen inventory + presentation type

Legend: **Tab** = tab root · **Push** = stacked route with back · **Sheet** = bottom sheet with
detents (drag to dismiss unless noted) · **Full** = full-screen modal (slides up, own close
button, system back dismisses) · **Mini** = small non-detent sheet (≤ 40 % height).

| # | Screen | Type | Reached from |
|---|---|---|---|
| P0 | Play lobby (home) | Tab | tab bar |
| P1 | Table (session) | Full (route `/table`) | P0 "Deal me in", Resume pill |
| P2 | Session sheet (stats · hand log · end) | Sheet (detents 45 % / 92 %) | P1 top-left pill, P1 ticker |
| P3 | Coach note | Sheet (45 % / 92 %; **blocking notes: no swipe-dismiss**) | coach chip, coach badge, notes list |
| P4 | Coach notes list (this hand) | Sheet (45 %) | P1 top-bar "Coach" badge |
| P5 | Assumed range viewer (read-only matrix) | Push-within-sheet (P3) or Full | P3 "View range" |
| P6 | Read range (Guess → Peek) | Full | tap an opponent seat |
| P7 | Seat card (about this player) | Mini | long-press seat, P6 "About" |
| P8 | Hand results (hand-over) | In-place overlay on the felt (not a sheet) | automatic |
| P9 | All reveals (9-max overflow) | Sheet (60 %) | P8 "All hands ›" |
| P10 | Session summary | Full | End session, bust |
| P11 | Hand replayer | Full | P10, Stats hands list, Session sheet |
| P12 | Hand note editor | Sheet (60 %, keyboard-aware) | P10, P11, Stats |
| P13 | Bet amount keypad | Mini (numeric) | tap the bet readout |
| P14 | Pace & speed | Mini | top-bar pace pill (long-press or tap) |
| P15 | Table options (mid-session) | Mini | top-bar overflow |
| D0 | Drills home | Tab | tab bar |
| D1 | Drill spot | Push (tab bar hidden) | D0 mode card |
| D2 | Drill feedback | Sheet (70 % / 95 %) over D1 | after answering |
| D3 | Grading range | Expander inside D2 (matrix 300 pt) | D2 |
| D4 | Rating explainer | Mini | D0 rating tile |
| D5 | Review queue (empty state) | In-place in D1 | D0 Review card when nothing due |
| D6 | Placement test | Full (paged) | D0 "Calibrate", Settings, onboarding |
| S0 | Study path | Tab | tab bar |
| S1 | Lesson reader | Push (tab bar hidden) | S0 lesson row, drill lesson link, onboarding result |
| S2 | Glossary definition | Mini (auto-height ≤ 200 pt) | tap a dotted term |
| S3 | Widget full-screen (equity calc, range explorer, breakdown) | Full | S1 "Open full screen" |
| S4 | Cheat sheet | Push (it is lesson `cheat-sheet`) with search | S0 |
| T0 | Stats overview | Tab | tab bar |
| T1 | Stat explainer | Mini | tap any stat label |
| T2 | Hands list (all recent, filter by tag) | Push | T0 "Recent hands · See all" |
| T3 | Import hands (picker → progress → result) | Full flow | T0 / T2 "Import" |
| T4 | Coaching review (leaks detail) | Push | T0 "Coaching review" card |
| X0 | Settings | Push | gear icon |
| X1 | About | Push | Settings row |
| X2 | Reset all progress | Full (typed confirmation) | Settings > Data |
| O0 | Onboarding tour (4 pages) | Full (first launch) | first run, Settings "Run again" |
| O1 | Placement intro / questions / result | Full (continues O0) | O0 page 4 "Continue" |

### 2.3 Navigation graph

```
TabBar ─┬─ Play (P0) ──▶ Table (P1, full) ──┬─ Session sheet (P2) ──▶ Replayer (P11) ──▶ Note (P12)
        │                                   ├─ Coach chip/badge ──▶ Coach note (P3) ──▶ Range (P5)
        │                                   │                    └▶ Notes list (P4) ──▶ P3
        │                                   ├─ tap seat ──▶ Read range (P6) ──▶ Peek result (in P6)
        │                                   ├─ long-press seat ──▶ Seat card (P7) ──▶ P6 / Explain
        │                                   ├─ hand over ──▶ Results overlay (P8) ──▶ All reveals (P9)
        │                                   ├─ bet readout ──▶ Keypad (P13)
        │                                   ├─ pace pill ──▶ Pace (P14)
        │                                   └─ End session ──▶ Summary (P10) ──▶ P11 / P12 / share
        │               └─ gear ──▶ Settings (X0) ──▶ About (X1) / Reset (X2) / Placement (D6) / Tour (O0)
        ├─ Drills (D0) ──▶ Spot (D1) ──▶ Feedback (D2) ──▶ Lesson (S1) | Drill 5 similar | Next
        │               └─ Calibrate ──▶ Placement (D6)
        ├─ Study (S0) ──▶ Lesson (S1) ──▶ Term (S2) / Widget full (S3) / Next lesson
        └─ Stats (T0) ──▶ Explainer (T1) / Hands (T2) ──▶ P11 / P12 / Import (T3) / Coaching (T4)
```

Rules:
- **System back** pops one level: closes the topmost sheet/mini first; on the table route it
  *leaves the table* (session stays paused; toast "Session paused — resume from Play"). No
  confirmation dialog: leaving is always safe because state is persisted.
- The table is a **modal route, not a push**, so the iOS left-edge back-swipe cannot fire while
  the user reaches for Fold.
- Sheets use two detents (peek / expanded). A sheet never opens another sheet on top; it pushes
  inside itself (P3 → P5) or replaces itself.
- Deep links (drill → lesson) push S1 on the Study tab and switch tabs, preserving the drill
  route so back returns to the feedback.

---

## 3. PLAY lobby — home / entry experience (P0)

The Play tab root doubles as the home screen. It answers three questions in one glance:
*can I keep playing, what's due today, and where was I learning?*

```
390×844                                        (safe top 47)
┌──────────────────────────────────────────────┐
│ ♠ All-In                              ⚙︎  ☾  │ 44   header (wordmark, settings, theme)
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ ● Session in progress                    │ │
│ │ 12 hands · +4.5 bb · 6-max · Step        │ │ 84   resume card (only when a session exists)
│ │                         [ Resume table ›]│ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │  ╭────────────────────────────────╮      │ │
│ │  │      ○   ○   ○                 │      │ │
│ │  │   ○   (felt preview)   ○       │      │ │ 236  play card (felt texture, seats preview
│ │  │          ▭ ▭ ▭ ▭ ▭             │      │ │      updates with the chips below)
│ │  ╰────────────────────────────────╯      │ │
│ │  Table    [Heads-up] [6-max ✓] [9-max]   │ │
│ │  Antes    [None ✓] [0.25 bb]             │ │
│ │  Pace     [Step ✓] [Auto]   Coach [on ●] │ │
│ │  ┌────────────────────────────────────┐  │ │
│ │  │           Deal me in               │  │ │ 56   primary button
│ │  └────────────────────────────────────┘  │ │
│ └──────────────────────────────────────────┘ │
│  Today                                       │
│ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│ │ ◔ 14 / 20  │ │ 🔥 3 days  │ │ 3 to review│ │ 76   today strip (goal ring · day streak · due)
│ │ drills     │ │ streak     │ │ Review ›   │ │
│ └────────────┘ └────────────┘ └────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 📖 Continue: Pot Odds, Break-even & EV   │ │ 64   next lesson card
│ │    Level 3 · 6 min · 9/31 done   ›       │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ✎ Coach's last note                      │ │
│ │ "You folded a moneymaker…"  Mistake · ›  │ │ 72   last coach note (opens the note)
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│   ▶ Play     ◎ Drills     📖 Study   ▤ Stats │ 49 + 34 safe
└──────────────────────────────────────────────┘
```

Behaviour and copy:
- **Header**: "All-In" wordmark (Bricolage 20 pt). Right: gear (Settings), moon/sun (theme quick-toggle).
- **Resume card** appears only when `session.active` and the user is off-table. Tap anywhere =
  resume. Swipe-left reveals "End session" (opens the summary).
- **Play card**: segmented controls persist (`allin.table.v1`). When seats ≠ 6 a 12 pt faint note
  appears under the chips: "Coach charts assume 6-max — verdicts at other table sizes use the
  nearest position as an approximation." "Deal me in" starts a new session *unless* one exists,
  in which case the button reads "Resume table" and a secondary text button "Start a new session"
  sits beneath it (ends the old one → summary → new).
- **Today strip**: goal ring shows drills/20 or hands/30 (whichever is closer to met); "Review ›"
  jumps straight into the Review drill mode when `dueCount > 0`, otherwise reads "Nothing due".
- **Continue lesson**: first incomplete lesson in path order.
- **Coach's last note**: most recent decision review (verdict badge + first 60 chars of layer 1).
  Tap opens P3 in read-only mode (no resume button).
- **Empty first-run state** (no sessions, no drills): the resume card, coach card and "Continue"
  collapse; a single hint card under the play card reads "New here? The 60-second tour covers
  the four modes. [Take the tour]".

---

## 4. PLAY — the table (P1)

### 4.1 Layout at 390×844, 6-max

Vertical budget (pt): safe-top 47 · top bar 44 · ticker 18 · table canvas 471 (y 109–580) ·
hero cards overlap the felt bottom · hero strip 24 · bet-size row 32 · preset row 44 ·
action buttons 56 · gaps 16 · safe-bottom 34.

```
390×844 · 6-max · hero to act, facing a raise         y
┌──────────────────────────────────────────────┐
│ (Dynamic Island / status bar)                │ 0–47
├──────────────────────────────────────────────┤
│ ‹ Leave  [12h · +4.5 bb ▾]   [✎ Coach ●3] [▶ Step ▾] │ 47–91  top bar
│  Ivey raises to 3 bb · Selbst folds          │ 91–109 ticker (tap → hand log)
│      ╭───────────────────────────────╮       │
│      │        ┌──────────────┐       │       │
│      │        │ N Negreanu UTG│  ▭▭  │       │ 120–178  seat 3 (top) plate + cards below
│      │        │ 98 bb · 31/22 │       │       │
│      │        └──────────────┘       │       │
│ ┌──────────┐                     ┌──────────┐│
│ │S Selbst MP│ ▭▭          ▭▭ │P Polk  CO ●││ 236–294  seats 4 (left-up) & 2 (right-up)
│ │ 96 bb·–/– │  Fold      3 bb │ 97 bb 24/18││          ● = dealer button on seat 2? no: on BTN
│ └──────────┘                     └──────────┘│
│      │           PRE-FLOP             │       │
│      │        ◎ Pot 4.5 bb            │       │ 300–330  street label + pot pill
│      │   ▭   ▭   ▭   ▭   ▭            │       │ 336–398  board slots 44×62 (dashed until dealt)
│ ┌──────────┐                     ┌──────────┐│
│ │H Hellmuth│ ▭▭             ▭▭ │I Ivey  BTN││ 404–462  seats 5 (left-low) & 1 (right-low)
│ │ 92 bb·12/9│  Fold     Raise 3 │100bb 22/18 D│          "Raise 3" bet pill toward pot,
│ └──────────┘                     └──────────┘│          D = dealer button, gold ring = to act
│      │     SB 0.5     BB 1 (you)     │       │ 470–500  blind chips on the felt
│      ╰───────────────╮ ╭─────────────╯       │
│                ┌────┐┌────┐                  │
│                │ Q♠ ││ Q♥ │                  │ 540–641  hero cards 72×101 (overlap felt rim)
│                │    ││    │                  │
│                └────┘└────┘                  │
│  BB · 100 bb          QQ · Pocket queens     │ 645–669  hero strip (position · stack · label)
│  [−] ───────●──────────── [+]   7.5 bb ✎     │ 677–709  size row: slider + readout (tap = keypad)
│  [Min] [ ⅓ ] [ ½ ] [ ⅔ ] [Pot] [All-in]      │ 717–761  presets (44 tall)
│ ┌──────────┐┌─────────────┐┌───────────────┐ │
│ │   Fold   ││  Call 2 bb  ││ Raise to 7.5  │ │ 769–825  actions (56 tall) — wait, exceeds
│ └──────────┘└─────────────┘└───────────────┘ │          safe area: see corrected budget ↓
└──────────────────────────────────────────────┘
```

Corrected bottom budget (must end at y = 810 = 844 − 34 safe): action buttons **750–806**,
presets **698–742**, size row **660–692**, hero strip **636–656**, hero cards **528–629**.
The felt oval is therefore x 22–368 (346 wide) × y 112–570 (458 tall); the hero cards
overlap the felt's bottom rim by ~40 pt, which is exactly how the best mobile clients anchor
"your" cards to the table edge. Board row centre at y = 355; pot pill at y = 312.

Seat plate centres (6-max): seat 3 top (195, 148); seat 2 right-upper (330, 262); seat 1
right-lower (330, 430); seat 5 left-lower (60, 430); seat 4 left-upper (60, 262); hero (195, 575
for the strip, cards above). Seats are ordered counter-clockwise from the hero exactly like the
desktop `seatPos()` so the engine's seat ids map 1:1.

Bet pills: each seat has a "bet spot" 58 pt toward the table centre from the plate centre; the
current-street bet ("3 bb") sits there with a 14 pt chip glyph. Blind posts use the same spot.

### 4.2 How 2-seat and 9-seat adapt

**Heads-up (2)** — the felt shrinks to y 132–540 and everything gets bigger:
```
│ ‹ Leave  [3h · −1.5 bb ▾]      [✎ Coach ●1] [▶ Auto ▾]│
│  Ivey posts SB 0.5                            │
│      ╭───────────────────────────────╮       │
│      │   ┌────────────────────────┐  │       │
│      │   │ I  Ivey · BTN/SB     D │  │       │ large plate 160×64, full archetype name
│      │   │ Tight-Aggressive       │  │       │
│      │   │ 100 bb · 22/18 · 14h   │  │       │
│      │   └────────────────────────┘  │       │
│      │          ▭▭   0.5 bb          │       │ opponent cards 34×48 below plate
│      │                               │       │
│      │            FLOP               │       │
│      │        ◎ Pot 2 bb             │       │
│      │    ▭    ▭    ▭    ▭    ▭      │       │ board 52×73 (bigger than 6-max)
│      │                               │       │
│      ╰───────────────╮ ╭─────────────╯       │
│                ┌────┐┌────┐                  │ hero cards 80×112
```
Position tag shows "BTN/SB" for the button and "BB" for the other seat (HU rule). The extra
vertical room is used for a permanent one-line **read strip** under the pot: "Ivey has shown
14 hands: opens 62 % on the button" (only after 8 observed hands).

**9-max** — compact seats (92×46, no HUD line, 24×34 cards) at eight rim positions:
```
│      ╭───────────────────────────────╮       │
│   ┌──────┐                     ┌──────┐      │  y 150  seats 4 (top-left) & 3 (top-right)
│   │Selbst│                     │Polk  │      │
│   │96 · MP│                    │97 · CO│     │
│ ┌──────┐  └──────┘         └──────┘  ┌──────┐│  y 232  seats 5 & 2
│ │Negre.│                             │Dwan  ││
│ │98·UTG│                             │100·BTN││
│ └──────┘      ◎ Pot 4.5 bb           └──────┘│
│ ┌──────┐   ▭   ▭   ▭   ▭   ▭          ┌──────┐│  y 355 board (40×56)
│ │Hellm.│                             │Ivey  ││  y 372  seats 6 & 1
│ │92·UTG+1│                           │100·SB││
│ └──────┘                             └──────┘│
│      ┌──────┐                   ┌──────┐     │  y 470  seats 7 & 8 (lower)
│      │Antoni│                   │Galfon│     │
│      │88·UTG+2│                 │95·HJ │     │
│      ╰──────╯───────╮ ╭─────────╰──────╯     │
│                ┌────┐┌────┐                  │  hero cards 64×90
```
Compact seats show name (10 chars), position and stack only; the HUD and last action are
revealed on the plate as a 2-second overlay when the seat acts, and always inside the seat
card (long-press). The dealer button and turn ring are unchanged. Board cards drop to 40×56.

**360×780** — global scale factor 0.92 on the table canvas (felt 316 wide), board 40×56,
hero cards 64×90, action rows keep their heights (44/56 are hard minimums) but the size row
and hero strip merge into one 32 pt row ("BB · 100 bb · 7.5 bb ✎" with the slider below the
presets). **430×932** — felt grows to 380×520, board 50×70, hero cards 80×112; nothing else
moves (extra space goes to the felt, never to the action bar).

### 4.3 Seat component

Standard seat (6-max), 104×58 plate, `ink-800` at 92 % with 1 pt `line` ring, radius 14:

```
        ┌──┐┌──┐            ← 30×42 face-down cards, overlap plate top by 12 pt
   ┌────┴──┴┴──┴────────┐
   │ (I) Ivey     [BTN] │   avatar 26 pt circle, initial, archetype colour ring
   │     100 bb   22/18 │   stack mono 13 pt gold-light · HUD mono 10 pt with colour dot
   └────────────────────┘
        ● Raise 3 bb        ← action pill (last action, this street), pops toward the pot
```

Contents and rules:
- **Avatar**: initial letter; ring colour = archetype colour (TAG blue #2f6fd0, LAG purple
  #8a5cd1, Nit green #2faa66, Station red #d23b3b). No archetype name on the plate — the HUD
  dot + ring colour is what the user learns to read; the seat card names it.
- **Name**: Inter 13 pt semibold, truncated at 8 characters with no ellipsis ("Negreanu" → "Negrean").
- **Position tag**: 10 pt caps pill (UTG/MP/CO/BTN/SB/BB; 9-max adds UTG+1, UTG+2, HJ).
- **Stack**: JetBrains Mono 13 pt, "100 bb" (one decimal only when < 10 bb: "7.5 bb").
- **HUD line**: `22/18` (VPIP/PFR) after ≥ 8 observed hands, else `–/–`; hands seen shown as
  ` · 12h` only when width allows (standard seat) — always in the seat card.
- **Last action**: a pill on the pot side of the plate: Fold (faint, plate dims to 55 % and
  cards grey), Check (muted), Call (info blue), Bet/Raise (gold, with amount), All-in (chip red).
  The pill persists for the street, then clears on the next street.
- **Dealer button**: 18 pt white disc with "D", anchored at the plate corner nearest the pot.
- **Turn indicator**: 2 pt gold ring + a thin arc that sweeps once per "think" (auto mode) or
  pulses slowly (manual mode). In manual mode the plate also shows a faint "▶" glyph so the user
  knows *this* seat moves when they tap Next action.
- **Winner**: ring turns `good` green, plate lifts 2 pt, pot chips fly in (see Motion).
- **Tap** (whole plate = 104×58 target) → P6 Read range, when the player is in the hand and the
  phase is betting. Outside those conditions tap → P7 seat card. A 12 pt eye glyph in the
  plate's top-right corner signals "tap to read".
- **Long-press** (450 ms) → P7 seat card always.
- **Compact seat** (9-max): 92×46, avatar 20 pt, name 11 pt, stack 11 pt, no HUD line.

### 4.4 Hero cards, stack and strip

- Hero cards 72×101 (radius 9), face-up always, rank in Bricolage 800 at 26 pt, suit glyph
  large bottom-right. The two cards sit side by side with a 6 pt gap, centred, overlapping the
  felt rim. Cards lift 6 pt and gain a gold glow while it's the hero's turn.
- Hero strip (20 pt, y 636–656): left "**BB** · 100 bb" (position pill + mono stack); centre/right
  the hand label in Bricolage 14 pt: "QQ · Pocket queens" (plain name from `cardsToLabel` +
  a friendly name table for pairs/broadways; otherwise just "K♠ 9♠ · suited").
- When facing a bet, the strip's right side becomes the **price line**: "To call 2 bb · need to
  win 1 in 4" (`fmtNeed`). That is layer-1 pot odds, always visible before the decision.
- Hero committed chips for the current street show at the hero bet spot (just above the cards, on
  the felt) like any other seat.

### 4.5 The ACTION BAR

Three states, always in the same 160 pt region (y 650–810):

**A. Hero to act**
```
  [−] ────────●───────────── [+]      7.5 bb ✎      ← size row (32 pt): slider, steppers, readout
  [Min]  [ ⅓ ]  [ ½ ]  [ ⅔ ]  [Pot]  [All-in]        ← presets (44 pt tall, 52–56 wide, 6 pt gaps)
  ┌────────────┐ ┌───────────────┐ ┌──────────────┐
  │    Fold    │ │   Call 2 bb   │ │ Raise to 7.5 │   ← 56 pt; widths 28 % / 34 % / 38 %
  └────────────┘ └───────────────┘ └──────────────┘
```
- **Fold**: outlined danger (red text/border on ink-800). Only appears when there is a bet to
  call; otherwise the left slot is "Check" and the middle slot is gone (two buttons: Check 45 %,
  Bet 55 %). Never require a fold confirmation — but fold is *disabled for 150 ms* after the
  action bar appears to swallow a tap intended for the previous state.
- **Check / Call**: secondary (ink-700). Label "Check" or "Call 2 bb" (amount mono). When a call
  would put the hero all-in, label "Call all-in 37 bb".
- **Bet / Raise**: primary gold. Label is *the exact commit*: "Bet 4.5" or "Raise to 7.5" (bb;
  mono amount). Reads "All-in 100" when the size equals the max.
- **Presets** (chips): `Min` (min-raise), `⅓`, `½`, `⅔`, `Pot`, `All-in`. Fractions are of
  (pot + call), added on top of the current bet — identical to the desktop `setFraction`. A chip is
  selected (gold) while the slider value equals it. Tap → selection haptic + button label updates.
  On first open the default is ⅔ (desktop default 0.66), clamped to legal bounds.
- **Slider**: track 4 pt, thumb 28 pt (hit 44), range `[minRaiseTo, maxRaiseTo]`, step 0.5 bb
  (`bb/2` chips). Drag anywhere on the row (the whole 32 pt row is the touch target, extended to
  44). Detents at the six presets give a light tick. `−`/`+` step 0.5 bb, hold to auto-repeat
  (every 90 ms after 400 ms).
- **Readout** "7.5 bb ✎": tap → P13 numeric keypad mini-sheet (custom 12-key pad: digits, ".",
  backspace, "Done"; shows legal range "min 4 · max 100"; clamps on Done). No system keyboard.
- **Drag-to-size gesture on the Raise button** (power-user, discoverable via the tour):
  press the Raise button and drag *upward* — a vertical slider materialises above the button
  (track 220 pt tall, the readout follows the thumb, presets shown as tick labels along the
  track). Releasing sets the size **without committing**; the button now shows the new amount and
  a plain tap commits. This is the "one second" path: press-drag-release-tap, all within 60 pt of
  the thumb's rest position. Dragging *sideways* > 30 pt cancels.
- Legal-action gating comes straight from `legalActions(table)`: no `canBet/canRaise` → the
  size row and presets are hidden and the buttons row is Fold/Call only (or Check).

**B. Bot to act**
```
  Manual (Step):                                   Auto:
  [✎ Explain]  ┌─────────────────────────────┐     [✎ Explain]  ┌───────────────────────────┐
               │        Next action  ›       │                  │ Ivey is thinking… ▂▃▅  ‖  │
               └─────────────────────────────┘                  └───────────────────────────┘
```
- Manual: "Next action ›" (secondary, 56 pt, 70 % width) steps one bot. **Tapping the felt**
  (anywhere on the table canvas that is not a seat/board/pot) also steps — the single most
  reachable control on the screen. A 3-time onboarding hint "Tap the table to step" fades in
  over the felt; afterwards no hint.
- Auto: the same slot shows "Ivey is thinking…" with a tiny equaliser and a **Pause** (‖) button
  at its right end (44×56). Tapping the felt in auto mode pauses (toggle). Paused state relabels
  the slot "Paused · tap to resume ▶".
- "✎ Explain" (ghost, 44×56, left) = *Explain last move*; enabled when `lastActorSeat` is a bot.
- The size row and presets are hidden in this state; the hero strip stays.

**C. Hand over**
```
  [✎ Explain]  ┌─────────────────────────────┐
               │        Next hand  ›     ◔   │      ← in Auto mode a 3 s countdown ring sits at the right
               └─────────────────────────────┘
```
- Manual: wait for the tap. Auto: auto-deals after 3 s unless the user touches the results card
  (touch = hold; the ring stops; "Next hand" becomes explicit). Setting "Auto-deal next hand" can
  turn this off.

### 4.6 Manual "step" vs auto-play on mobile

- **Control location**: top-bar right pill "▶ Step ▾" / "▶▶ Auto ▾". Tap toggles Step ↔ Auto
  (instant, haptic). Long-press (or tap the ▾) opens P14: a mini sheet with a segmented Step/Auto
  and speed chips Slow (1100 ms) · Normal (700 ms) · Fast (360 ms), plus the "Tap the table to
  step" toggle and "Auto-deal next hand" toggle. Default: Step, Normal — same as desktop.
- **What a hand in progress feels like** (Step): a quiet table; the turn ring pulses on the seat
  that will act; the ticker shows the last line; the action slot invites "Next action". Each tap
  animates exactly one action (≤ 400 ms) and returns control. The hero's own turn is
  unmistakable: the hero cards lift and glow, the action buttons slide up 8 pt into place, and a
  light haptic fires.
- **Auto**: bots act on the chosen cadence with the think-arc sweeping on the active seat; the
  user is only ever asked to act at their own turn. When the coach posts a blocking mistake, the
  loop stops (desktop `paused`), the sheet rises, and "Got it" restarts the loop — identical to
  `dismissReview → maybeAutoLoop`.
- Opening Read range (P6) pauses auto exactly as `openGuess` sets `paused: true`; closing resumes.
- App backgrounded mid-hand: auto mode flips to paused; state is persisted every action.

### 4.7 Bot action animation and timing

Per bot action (Normal speed, 700 ms budget):
1. 0–150 ms: think — the turn arc sweeps on the seat (Auto) — skipped in Step mode.
2. 150–400 ms: the action pill pops (scale 0.8→1, 200 ms, emphasized-decelerate) and, for
   bets/calls, a chip stack (3 layered 14 pt discs) slides from the plate to the bet spot
   (250 ms, standard ease), the stack number counts down (mono, 120 ms).
3. 400–450 ms: turn ring hops to the next seat.
4. Fold: cards slide 20 pt toward the centre and fade to 30 % grey (220 ms); plate dims.
5. Street change: the bet spots' chips glide to the pot (280 ms, staggered 30 ms per seat), the
   pot number ticks up, then the new board cards deal (see Motion).
Fast (360 ms) shortens each phase proportionally; Slow (1100 ms) lengthens only the think
phase. In Step mode the think phase is zero and the whole action completes in ≤ 400 ms so
rapid tapping feels responsive; a queued tap during an animation is honoured (never dropped).

### 4.8 The EV coach on mobile

**Non-blocking notes → the coach chip.** When `evaluateHero` resolves (it runs async after the
action is applied), a chip drops from under the ticker, centred over the top of the felt:

```
        ┌──────────────────────────────────────┐
        │ ✓  Nice play · Your call        ›    │   verdict icon on a coloured disc, title, chevron
        └──────────────────────────────────────┘   48 pt tall, 320 pt wide, ink-800 @ 95 %
```
- Verdict colours/labels (from `META`): Mistake (bad red, ✕), Thin spot (warn amber, i),
  Reasonable (info blue, ✓), Nice play (good green, ✓), Read (info blue, eye).
- Visible 4 s, then shrinks (200 ms) into the top-bar **Coach badge** "✎ Coach ●3" whose dot
  takes the verdict colour of the latest note and the count = notes this hand.
- Tap the chip → P3 coach note sheet at 45 % detent. Swipe up → 92 %.
- Haptics: great/ok = light; thin = medium; mistake (non-blocking, e.g. a spilled fold) = the
  notification-warning pattern.
- If the verdict arrives after the hand already ended (`handNumber` changed) it is *not* shown
  as a chip (matches desktop), but it is recorded and reachable from Stats.

**Blocking mistakes → the pause sheet.** `review.blocking` (a −EV call beyond the strictness
threshold, outside the noise band):
- The loop pauses, the felt dims to 60 %, a warning haptic fires, and P3 opens at the 62 %
  detent **without a drag-to-dismiss handle**. System back does nothing (a subtle shake).
  The only way on is the primary "Got it" button — exactly desktop's `dismissReview`.
- The hero's committed chips remain on the felt behind the sheet so the user sees what the note
  refers to. The hero cards stay visible in the 38 % of screen above the sheet? No — the sheet
  covers the bottom; instead the sheet's header repeats the situation: hero cards (XS) + board
  (XS) + "you called 2 bb into 4.5 bb".

**The coach note sheet (P3) — three visible layers**
```
┌──────────────────────────────────────────────┐
│ ━━━━                                          │  handle (absent when blocking)
│ ┌────┐  ✕ Mistake                            │  header tinted with verdict colour @ 12 %
│ │ ✕  │  EV Coach · Your call                 │
│ └────┘  [Q♠][Q♥]  on  [7♦][2♣][9♠]           │  XS cards for context
├──────────────────────────────────────────────┤
│ You paid 8 bb to win a pot of 24 bb — you    │  LAYER 1 · Inter 17 pt / 1.45, always open
│ need to win about 1 time in 4. Your hand     │
│ wins about 1 time in 5 — not enough. Over    │
│ time this call loses money; folding is       │
│ better.                                      │
│                                              │
│ Win chance vs Ivey                      21%  │  equity bar 10 pt tall, verdict colour,
│ ▓▓▓▓▓▓▓░░░░│░░░░░░░░░░░░░░░░░░░░░░░░░░       │  white marker = needed % (pot odds)
│ White line = 33% needed (pot odds ⓘ)         │  ⓘ opens S2 glossary mini for "pot odds"
│                                              │
│ ⚠ Multiway pot (3 opponents). With more…     │  only when review.multiway
│                                              │
│ ▸ Show me the math                           │  LAYER 2 · disclosure row, 48 pt tall, gold text
│ ▸ Expert detail                              │  LAYER 3 · disclosure row, muted text
│                                              │
│ Expected value                      −1.6 bb  │  EV tile (mono, red/green/muted)
│                                              │
│ ┌──────────────────┐ ┌──────────────────────┐│
│ │  👁 View range   │ │       Got it         ││  56 pt; "Close" (ghost) when non-blocking
│ └──────────────────┘ └──────────────────────┘│
└──────────────────────────────────────────────┘
```
- Layer 2 expands inline to a numbered list (steps), 15 pt, left rule in `line`. Layer 3 expands
  to a bulleted list including the `text` summary line first (desktop order), then `expert[]`.
- Expanded state is **not** remembered between notes (plain first, always). Settings offers
  "Always expand 'Show me the math'" for users who have graduated.
- "View range" pushes P5 inside the sheet (matrix 300 pt read-only, title "Ivey's assumed range",
  subtitle exactly the desktop description, footer "≈ 312 combos · 23 % of all hands"; back
  chevron returns to the note).
- Bot-read notes (`kind: "bot"`, verdict "info") use the same sheet with the eye icon, title
  "Ivey's raise", the `interpretBot` sentence as layer 1, no equity bar, and "View range".

**Reopening past notes.** Top-bar "✎ Coach ●3" → P4, a list of this hand's notes newest first:
`[badge] Your call · Mistake · "You paid 8 bb to win…"` rows (64 pt). Tap → P3 (read-only:
no pause). Notes reset on the next deal (desktop `reviewLog: []` on `deal`), and the badge
reads "✎ Coach" with no count. All decisions remain in Stats → Coaching review.

**Coach off.** The overflow menu / P15 has "EV Coach" toggle; when off the badge shows "✎ Coach
off" (muted) and no chips appear. Stats still record nothing (desktop: `coachEnabled` short-
circuits before `evaluateHero`).

### 4.9 Guess Range → Peek (P6) on a phone

Entry: tap an opponent seat during betting. The hand pauses (`openGuess`). Full-screen modal:

```
┌──────────────────────────────────────────────┐
│ ✕                Read Ivey's range      About│ 44   close · title · "About" (P7 seat card)
│ BTN · Tight-Aggressive (TAG) · Flop          │ 20   subtitle (desktop copy)
│ Optionally paint your guess, or just peek.   │ 18
├──────────────────────────────────────────────┤
│ AA  AKs AQs AJs ATs A9s A8s A7s A6s A5s A4s… │      13×13 matrix, 366 pt square:
│ AKo KK  KQs KJs …                            │      cell 27 pt, gap 1 pt, radius 3,
│ AQo KQo QQ  …                                │      label 9.5 pt semibold (mono digits)
│ …                                            │      pairs on the diagonal, suited above,
│                                              │      offsuit below (standard orientation)
│              (366 × 366)                     │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
├──────────────────────────────────────────────┤
│ ■ Pairs  ■ Suited  ■ Offsuit    38 combos · 2.9 % │ 24  legend + live combo counter
│ [Top 10%] [15%] [20%] [30%] [45%]   [↶ Undo] [Clear] │ 44  tools (horizontal scroll if needed)
│ ┌────────────────────┐ ┌────────────────────┐│
│ │       Clear        │ │    Peek & score    ││ 56  ("Peek" when nothing painted)
│ └────────────────────┘ └────────────────────┘│
└──────────────────────────────────────────────┘
```

Painting with a finger:
- **Cell size 27 pt** (below 44). Precision comes from three things: (1) **drag-paint** — the
  first cell touched decides the mode (add if it was off, remove if on; identical to
  `addModeRef`), then every cell the finger crosses gets that mode; (2) a **loupe**: while the
  finger is down, a 72 pt magnified bubble floats 56 pt above the fingertip showing the 3×3
  neighbourhood with the hovered cell outlined in gold, so the finger can occlude the grid and
  the user still sees what they're painting; (3) **tap = toggle one cell** with a 200 ms
  debounce so a sloppy tap that moves 4 pt still counts as a tap, not a drag.
- **Pinch to zoom** the matrix 1×–2.5× with two fingers; while zoomed, one-finger drags still
  paint (pan uses two fingers). Double-tap resets zoom. This is the accessibility path for
  large fingers / AX text.
- Colours: painted cells fill with the kind colour (pair `combo-pair` #b8442f, suited
  `combo-suited` #2f8f5c, offsuit `combo-offsuit` #2c3a4a-lightened) with white labels;
  unpainted are `ink-700` with faint labels. The legend under the grid names them.
- **Undo** (last stroke; up to 20) and **Clear**. **Presets**: top-X % chips from
  `topPercentRange` (10/15/20/30/45) — these *replace* the painting (undo restores).
- Haptics: a selection tick when the paint mode flips a cell (rate-limited to one per 40 ms).
- Combos counter updates live: "38 combos · 2.9 % of hands".

**Peek** (`peek(painted)`):
- With a painting: the grid switches to **compare** colouring (green = correct, amber = missed,
  red = extra — the desktop legend, plus diagonal hatching on "missed" and dots on "extra" when
  the OS "differentiate without colour" flag is on) and the score card rises from the bottom:
```
├──────────────────────────────────────────────┤
│ ■ Correct  ■ Missed  ■ Extra    Their range: 312 combos │
│ ┌──────────────────────────────────────────┐ │
│ │   64%            Coverage   71 %         │ │  accuracy in Bricolage 40 pt, grade label
│ │   SOLID          Precision  58 %         │ │  under it (Sharp read / Solid / Rough / Way off)
│ │ You caught 71 % of the hands they play   │ │  plain-English restatement of recall/precision
│ │ here; 58 % of what you painted was right.│ │
│ │ Everyone's exact cards are revealed when │ │
│ │ the hand ends.                           │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │                 Continue                 │ │  56 pt → closeGuess (resumes auto)
│ └──────────────────────────────────────────┘ │
```
- Without a painting: the grid highlights the actual range (read-only) and the card reads
  "Here's Ivey's assumed range. Paint a guess first next time for an accuracy score."
- The score is recorded (`recordGuess`) only when painted — same as desktop.
- Hole cards are *not* shown here (desktop reveals at hand end; the copy says so).

### 4.10 Explain last move

"✎ Explain" (ghost button in the bot-to-act and hand-over action bars, and in P7 seat card as
"Explain their last move") calls `explainLastBotMove`: an info-verdict note appears as a chip
("👁 Ivey's raise ›") and opens P3 on tap with the `interpretBot` line as layer 1 and "View
range" for the range the bot's decision used (`botRanges[seat]`). Disabled (40 % opacity) when
the last actor was the hero.

### 4.11 Hand log

- The **ticker** line under the top bar shows the latest log entry (12 pt muted; results in
  gold-light, deals in info blue — the desktop colour code). Tap → P2 at 92 % on its "Hand log"
  segment: a reverse-chronological list grouped by street with coach notes interleaved as
  badge rows (tap a badge row → P3). Entries: deal, actions, results (`e.kind`).
- Long-press the ticker → copies the current hand's log text (toast "Hand log copied").

### 4.12 Hand-over reveal, results overlay (P8), next hand

Sequence at `phase === "hand-over"`:
1. Showdown cards flip face-up in their seats (150 ms half-flips, seat order clockwise from the
   button, 60 ms stagger). With realistic reveals on, folded seats stay face-down.
2. Pot chips glide to the winner's plate (420 ms), the winner ring turns green, the winner's
   stack counts up. Hero win → success haptic.
3. The **results card** slides up over the lower felt (y 372–560), leaving the hero cards, the
   board and the top seats visible:

```
│      │   ▭   ▭   ▭   ▭   ▭            │       │  board stays visible
│ ┌──────────────────────────────────────────┐ │
│ │  +12.5 bb           Ivey wins with two   │ │  net (Bricolage 24, good/bad colour),
│ │  YOU WON THE POT    pair.                │ │  winner line (desktop copy)
│ ├──────────────────────────────────────────┤ │
│ │ [K♦][7♣] Polk  Folded on the flop — the   │ │  reveal rows: XS cards 22×31 + one-line
│ │          full board would have given them │ │  revealNote() sentence; folded rows greyed
│ │          a pair of kings.                 │ │
│ │ [A♠][4♠] Selbst Folded before the flop —  │ │
│ │          playable, but gave it up.        │ │  scrollable (3 rows visible); 9-max shows
│ │ [9♥][9♦] Ivey   Won with two pair.        │ │  "All 8 hands ›" → P9 sheet
│ └──────────────────────────────────────────┘ │
│                ┌────┐┌────┐                  │  hero cards remain
│  [✎ Explain]   │        Next hand  ›   ◔  │  │  action bar state C
```
- Tapping a reveal row opens that seat's P7 card with "Read their range" disabled (hand over)
  and an inline read-only matrix of the range they were assigned for their last street.
- "Next hand ›" deals (`deal()`); Auto mode's 3 s ring auto-deals unless the card is touched.
- Bust: if the hero's stack is 0 the action bar reads "Session over" and P10 opens
  automatically (desktop `deal` → `sessionEnded`).

### 4.13 Session stats access (P2)

Top-left pill "12h · +4.5 bb ▾" → P2 sheet (45 % detent):
```
│ ━━━━                                          │
│ [ This session ]  [ Hand log ]               │  segmented
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌───────────────┐ │
│ │Hands │ │ Net  │ │bb/100│ │ Read accuracy │ │  stat tiles (mono values, good/bad tone)
│ │  12  │ │+4.5  │ │ +37  │ │     64 %      │ │
│ └──────┘ └──────┘ └──────┘ └───────────────┘ │
│ Your style  22 / 15 · 12h                ⓘ  │  hero VPIP/PFR after 8 hands (tap ⓘ → T1)
│ ┌──────────────────────────────────────────┐ │
│ │ Hands this session (12)                  │ │  rows: "#12 · +3.0 bb · Replay · ✎"
│ │ #12  +3.0 bb            ▶ Replay   ✎     │ │
│ │ #11  −0.5 bb            ▶ Replay   ✎     │ │
│ └──────────────────────────────────────────┘ │
│              [ End session ]                 │  danger-ghost, 44 pt
```
bb/100 and "Your style" labels are tappable → T1 explainer mini with the desktop tooltip copy.

### 4.14 End session + summary (P10)

Full-screen modal, scrollable, decisions before money (desktop order):
```
│ ✕                Session summary             │
│ 12 hands played this session.                │
│ ┌──────────────────────────────────────────┐ │
│ │ HOW YOU PLAYED (BEFORE HOW IT PAID)      │ │  gold-tinted card
│ │ 9 coached decisions, 1 flagged as a      │ │
│ │ mistake (11 % vs your usual 18 % —       │ │
│ │ cleaner than average).                   │ │
│ │ Best: a turn raise worth +2.1 bb.        │ │
│ │ Costliest: a flop call (−1.6 bb) — it's  │ │
│ │ in your Review queue.                    │ │
│ └──────────────────────────────────────────┘ │
│ ┌────────────┐ ┌────────────┐                │
│ │ Net +4.5 bb│ │ bb/100 +37 │                │  2×2 stat tiles
│ │ Best +12.5 │ │ Worst −8.0 │                │
│ └────────────┘ └────────────┘                │
│ 3 hands reached showdown. Replay any hand    │
│ below, or export the full history.           │
│ ┌──────────────────────────────────────────┐ │
│ │ REVIEW HANDS                             │ │
│ │ #12  +3.0 bb              ✎   ▶ Replay   │ │
│ │ …                                        │ │
│ └──────────────────────────────────────────┘ │
│ [ Copy ]  [ Share hands (.txt) ]             │  share_plus system sheet
│ ┌──────────────────────────────────────────┐ │
│ │               New session                │ │  primary
│ └──────────────────────────────────────────┘ │
│                  Done                        │  ghost → back to lobby
```
Busted sessions hide ✕ and "Done" (desktop `hideClose={heroBusted}`); "New session" is the exit.

### 4.15 Table setup before a session and the empty state

Table setup is the Play-lobby play card (§3). There is no separate setup modal: the lobby *is*
the empty state. If the user opens `/table` with no session (deep link, resume after reset)
the table renders an empty felt with silhouettes and one centred card:
"Ready to play? A session deals hand after hand against a fixed table of bots. Your stack
carries over, so wins and losses stick until you end the session. [Deal me in]" — with the
same seat/ante chips beneath (desktop `PlayView` copy).

Mid-session table options (P15, from the top-bar overflow ⋯): Coach on/off, Four-colour deck,
Realistic reveals, "Leave table", "End session". Seat count and antes cannot change
mid-session (the button explains: "Ends this session first").

---

## 5. DRILLS

### 5.1 Drills home (D0)
```
│ Drills                                  ⓘ    │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │
│ │Rating  │ │Accuracy│ │Streak  │ │ Best   │  │  tiles 80×64; Rating gold; tap Rating → D4
│ │ 1120 ⓘ │ │  68 %  │ │   4    │ │   9    │  │
│ └────────┘ └────────┘ └────────┘ └────────┘  │
│ ◔ Today 14/20 drills · 3-day streak      ⓘ   │  goal line (ring 20 pt); ⓘ → daily-goal blurb
│ ┌──────────────────────────────────────────┐ │
│ │ ◎ Mixed                                  │ │  mode cards 92 pt: title, blurb (desktop
│ │ Pre-flop charts + post-flop pot-odds/    │ │  MODE_INFO text), chevron
│ │ equity. Opponent type is irrelevant —    │ │
│ │ play solid baseline poker.            ›  │ │
│ ├──────────────────────────────────────────┤ │
│ │ ⇧ Push / Fold                          › │ │
│ ├──────────────────────────────────────────┤ │
│ │ ⚡ Exploits                             › │ │
│ ├──────────────────────────────────────────┤ │
│ │ ↻ Review                     3 due     › │ │  badge "3 due" (gold) / "Nothing due" (muted)
│ └──────────────────────────────────────────┘ │
│ Calibrate my level (placement test)       ›  │  text row → D6
```
The last-used mode is remembered; the card row order is fixed.

### 5.2 The spot (D1)
```
│ ‹ Mixed                    Rating 1120 · ●●●○ │  back, mode, rating, difficulty pips
│      ╭──────────────────────────────╮        │
│      │       [UTG][MP]  folded      │        │  snapshot table 300 pt tall: compact seats
│  [CO]│  raise 2.5                   │[BTN]   │  with "In hand / Folded" and position only
│      │        ◎ Pot 4 bb            │        │  (DrillTable), board 40×56, hero cards 56×78
│  [SB]│    ▭   ▭   ▭                 │[BB you]│
│      ╰──────────────────────────────╯        │
│ Hand replay                        1 · 2 · 3 · ● │  MoveNavigator, horizontal
│ [⏮] [◀]  "CO raises to 2.5 bb"  [▶] [⏭]      │  44 pt buttons; centre text = frame text
│ ●━━━━━━━━●━━━━━━━━●━━━━━━━━◎                  │  scrubber; ◎ = decision frame (gold target)
│ Your hand: A♠ J♠    Pre-flop chart · 100bb baseline │  hand label + source pill
│ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│ │    Fold    │ │  Call 2.5  │ │ 3-bet to 8 │ │  2–3 options, 56 pt, equal widths
│ └────────────┘ └────────────┘ └────────────┘ │
```
- On entry the navigator **auto-replays** frames to the decision (400 ms per frame, chips and
  fold animations as on the table) so the user *watches* the action arrive; a tap on any nav
  control stops the auto-replay. Setting "Replay drill action automatically" (default on).
- Frames are also a horizontally scrollable chip strip when > 4 (9-max spots).
- Options come from `puzzle.options` (labels verbatim: "Fold", "Call 2.5 bb", "Raise to 8 bb",
  "Check", "Bet 4 bb", "Push all-in", "Call the shove").

### 5.3 Feedback (D2)
Answer → 250 ms: the chosen button turns green/red, accepted options green (desktop
`result.accept`), a haptic (success/warning), then D2 rises to 70 %:
```
│ ━━━━                                          │
│ ✓ Correct                          +12  ●   │  or "✕ Not optimal", rating delta mono
│ That choice costs about 1.2 bb every time — │  (only when wrong and evLossBb > 0.05)
│ a real leak.                                 │
│ Calling 2.5 to win 6.5 with 24 % equity …    │  rationale (layer 1 text from puzzle)
│ ┌──────────────────────────────────────────┐ │
│ │ Folding: 0 bb — costs nothing more.      │ │  per-option outcomes card (postflop spots)
│ │ Calling: −0.4 bb per try — your hand wins│ │
│ │ about 1 time in 4 and you need 1 in 3.   │ │
│ └──────────────────────────────────────────┘ │
│ Equity 24 % · Pot odds 33 %                  │  faint row
│ ▸ See the range it was graded against        │  expander → 300 pt read-only matrix + title
│ ┌──────────────────┐ ┌──────────────────────┐│
│ │ 📖 Pot Odds & EV │ │ ◎ Drill 5 similar    ││  lesson link (title from puzzle) · similar
│ └──────────────────┘ └──────────────────────┘│
│         2 more of this spot type coming up   │  focusLeft line
│ ┌──────────────────────────────────────────┐ │
│ │              Next puzzle  ›              │ │  sticky bottom, 56 pt
│ └──────────────────────────────────────────┘ │
```
- Swipe-left on the sheet also advances (same as Next). System back closes the sheet and keeps
  the answered state visible on D1 (options disabled, feedback re-openable via a "Show feedback"
  pill).
- "Drill 5 similar" sets `focusKind` and shows the count line above Next.

### 5.4 Rating, streak, daily goal
Tiles on D0 (§5.1) and a compact strip in D1's header (Rating · pips). Rating tile tap → D4
mini: "A self-adjusting puzzle rating (like a chess puzzle ELO)…" (desktop tooltip verbatim).
Daily goal line ⓘ → "A quiet daily goal: 20 drill answers (or 30 hands) keeps the day-streak
alive. No reminders, no guilt — just a nudge to come back tomorrow." When met, the ring fills
gold and the streak increments with a 300 ms pop; no confetti.

### 5.5 Review / "My leaks" queue
Mode "Review" serves due leak spots + due missed drills (`genFor("leaks")`). D1 shows a source
pill "Your flagged spot" and, for leaks, the *original* rationale from the coach. After a
correct answer the SRS toast reads "Beaten 1 of 3 — back in 2 days"; on the third success
"Retired — nice." Empty state (D5, in place of the table):
```
│              ┌──────┐                        │
│              │  ✓   │  (good-tinted 48 pt)   │
│              └──────┘                        │
│        Nothing due right now                 │
│ All 7 of your review spots are scheduled for │
│ later — spaced practice sticks best when you │
│ come back to it. Play or drill in the        │
│ meantime.                                    │
│      [ Play a session ]  [ Mixed drills ]    │
```
With zero cards ever: "No spots to review yet" + the desktop sentence about the coach and
missed drills.

### 5.6 Push/Fold and ICM specifics
- Snapshot shows **stack sizes in bb on every plate** in bold mono (they are the whole decision);
  the hero plate shows "12 bb · SB".
- Header pill "Push/Fold · computed Nash" or "Push/Fold · ICM bubble". The ICM pill is tappable →
  mini: "Tournament money, not chips: on the bubble, busting costs more than the chips are
  worth, so you fold hands you'd shove for chip-EV." Below the table a one-line context row:
  "9 left · 8 paid · stacks 12 / 25 / 40 bb".
- Options: "Push all-in" / "Fold" (or "Call the shove" / "Fold"). Feedback includes the
  mixed-frequency line when applicable: "Either answer is right here — the real equilibrium
  mixes." and the grading range expander titled "Nash shoving range from SB, 12 bb".

### 5.7 Placement test (D6)
Full-screen, one question per page, progress dots (8), option buttons 56 pt stacked, 350 ms
colour flash then auto-advance (desktop). Result page: level line ("You know the basics."),
"5/8 — drills are calibrated to match. Start at Pot Odds & EV…", buttons "Take me there"
(→ S1 lesson) and "Start playing" (→ lobby). Seeds the rating (900/1050/1250).

---

## 6. STUDY

### 6.1 Level path (S0)
```
│ Study                              9/31 ▓▓▓░░ │  overall progress bar in the header
│ ┌──────────────────────────────────────────┐ │
│ │ L1  Basics                        3/3 ✓  │ │  level header row (icon, title, done/total)
│ │  ✓ Hand Rankings                    4m   │ │  lesson rows 52 pt: check circle, title,
│ │  ✓ Position & the Button            5m   │ │  minutes (mono, faint)
│ │  ✓ Bankroll & Mindset               4m   │ │
│ ├──────────────────────────────────────────┤ │
│ │ L2  Pre-flop                      2/4    │ │
│ │  ✓ The 13×13 Matrix                 5m   │ │
│ │  ○ Opening Ranges by Position  ●    6m   │ │  ● = "up next" gold dot
│ │  …                                       │ │
│ ├──────────────────────────────────────────┤ │
│ │ L5  Practice                      0/6    │ │  cheat sheet, range explorer, equity calc,
│ │  ○ Quick Reference                 4m   │ │  three study drills
```
Levels are collapsible (tap header); the first incomplete level is expanded on open.

### 6.2 Lesson reader (S1)
- Typography: level label (12 pt caps, gold, tracking 0.2 em); title Bricolage 800 28 pt/1.1;
  "6 min read" faint; body Inter 17 pt/1.5 (scales with dynamic type), H2 Bricolage 20 pt,
  callout cards (gold-tinted "Key idea", amber "Beware"), tables become stacked key/value rows
  at < 400 pt width, two-column info grids stack vertically.
- Widgets are full-width cards (page margin 16 pt); complex ones (equity calculator, range
  explorer, range-vs-board breakdown) show a compact preview with "Open full screen ›" → S3.
- **Glossary terms**: dotted gold underline as on desktop. **Tap** → S2 mini-sheet (≤ 200 pt):
  term in gold-light, definition, "See all terms ›" (→ cheat sheet glossary). No long-press
  needed. VoiceOver reads "pot odds, glossary term, double-tap for definition".
- Sticky bottom bar (64 pt + safe): "[Mark complete]  [Next lesson ›]"; completion is explicit
  (desktop behaviour). After marking complete the button reads "✓ Completed".
- Deep link from drills lands here with a "‹ Back to drill" back label.

### 6.3 Quizzes
Inline card (info-tinted), "optional" pill, "You missed 2 of these before — they're up first"
line, options as 52 pt rows with A/B/C badges, tap → green/red + explanation + "Try again"
(reshuffles). Results persist (`recordQuiz`).

### 6.4 Calculators — phone layouts
- **Pot-odds calculator**: two sliders stacked (Pot before the bet · Opponent's bet) with the
  mono value right-aligned above each; three result tiles in a row (You risk · To win ·
  Getting); the break-even card (gold, Bricolage 32 pt); "Your equity estimate" slider; the EV
  verdict card (green/red border: "EV of calling −1.4 bb · Decision: Fold").
- **Bluff break-even**: two sliders; two result cards stacked (If you're bluffing 41 % / If they
  call you 29 %) with the desktop sentences.
- **Multiway equity trainer**: scenario chips in a horizontally scrolling row; hero cards + board
  row; a 1–5 opponents **stepper** (44 pt −/+ with the number) instead of a slider; big % (40 pt)
  with colour; 5-bar chart (tap a bar to select). Equities compute on scenario change with a
  shimmer on the bars while pending.
- **Free-form equity calculator** (S3 full screen): a segmented page control **You · Opponent ·
  Board**; "You" page has a Range/Hand toggle — Range shows a 366 pt paint matrix with Any two /
  Clear; Hand shows a 4-row × 13 card picker (cells 26×36, hit 44 via row height); "Opponent"
  page is the matrix; "Board" page is the card picker (0–5). A sticky footer shows
  "Range 312 vs 168 combos · Board K♠ 7♦ 2♣" and "[Calculate equity]" (56 pt). Result pushes a
  results page: equity 32 pt gold, win/tie/lose stacked bar, samples/exact line, blockers line,
  then the two range-vs-board breakdowns as collapsible cards.
- **Range explorer** (S3): preset chips (UTG ~14 % … BB defend ~55 %) horizontally scrolling,
  matrix 366 pt, footer "184 combos · 13.9 % of all hands" + the explanatory paragraph.
- **Range-vs-board breakdown**: a list of rows (category · combos · %) with a thin bar per row;
  "exact-hand mode" and blockers come from the calculator's Hand mode.
- **Hand rankings**: 10 rows, 5 cards at 26×36 each, name + note; row tap enlarges the five
  cards in a mini (44×62).

### 6.5 Cheat sheet (S4) and progress
The `cheat-sheet` lesson gets a search field (filters rows and glossary), section headers that
stick, and a "Glossary" section listing every `GLOSSARY` entry. Progress: header bar on S0, per-
level counts, gold dot for "up next", and the lobby "Continue" card.

---

## 7. STATS

### 7.1 Overview (T0)
```
│ Your progress                             ⚙︎ │
│ Decisions, not results — but we track both.  │
│ ┌────────┐ ┌────────┐ ┌────────┐            │
│ │ Hands  │ │  Net   │ │Win rate│            │  KPI tiles, horizontal scroll strip (5)
│ │  412   │ │+31 bb  │ │+7.5 ⓘ │ …          │  tap ⓘ / label → T1 explainer
│ └────────┘ └────────┘ └────────┘            │
│ ┌──────────────────────────────────────────┐ │
│ │ ▤ Cumulative winnings (bb)               │ │  fl_chart line, 180 pt tall, gradient fill,
│ │        ╱╲    ╱╲╱                         │ │  scrub to read value (haptic ticks)
│ │   ╱╲╱╱  ╲╱╲╱                             │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 👁 Range-read accuracy   64 % · 22 reads │ │  mini bars (last 30 peeks)
│ ├──────────────────────────────────────────┤ │
│ │ ◎ Hands vs each style                    │ │  4 rows: colour dot, name, net (mono),
│ │  ● Tight-Aggressive   +12 bb ▓▓▓▓▓▓░░    │ │  hands bar
│ │  ● Calling Station    +19 bb ▓▓▓▓░░░░    │ │
│ ├──────────────────────────────────────────┤ │
│ │ ✎ Coaching review                     ›  │ │  Mistakes · Thin · Great tiles + top leak
│ │  [ 6 ] [ 14 ] [ 31 ]  "Your range reads… │ │  line; tap → T4
│ ├──────────────────────────────────────────┤ │
│ │ ◎ Winnings by position                   │ │  6 rows diverging bars (BTN +42/100 …)
│ ├──────────────────────────────────────────┤ │
│ │ ▤ Style numbers                          │ │  WTSD 28 % · W$SD 52 % · AF 2.4 (each row
│ │  Went to showdown (WTSD)         28 % ⓘ │ │  tappable → T1 with blurb + healthy band)
│ ├──────────────────────────────────────────┤ │
│ │ ▶ Recent hands            Import · See all│ │  10 rows, tag chips filter row above
│ │  #412 · Today 19:02  +3.0 bb   ✎    ▶    │ │
│ ├──────────────────────────────────────────┤ │
│ │ ⚡ Practice                              │ │  heatmap: 16 weeks × 7, 16 pt cells, 3 pt
│ │  ░░▓▓░▓▓▓░░▓▓▓▓░ …                       │ │  gap, horizontally scrollable, today at right
│ │  23 active days in the last 16 weeks.    │ │  tap a cell → tooltip mini "Mar 3 · 24 reps
│ └──────────────────────────────────────────┘ │  · goal met"
```
- **T1 explainer** mini: title (gold-light), blurb, "Healthy range: 24–32 %" line — the desktop
  tooltip contents, one per stat. Every dotted label is a 44 pt row.
- Position section ends with the desktop plain-language paragraph; style numbers with the
  "small samples swing wildly" line.

### 7.2 Hand replayer (P11)
```
│ ✕            Hand #412 replay                │
│ "CO raises to 2.5 bb"                        │  frame text (desktop `description`)
│      ╭──────────────────────────────╮        │
│      │   compact table 330 pt       │        │  same renderer as drills snapshot; hero
│      │   pot · board · seats        │        │  cards 44×62, others 24×34, revealAll at end
│      ╰──────────────────────────────╯        │
│ [⏮] [◀]  ●━━━━━━━━━━●━━━━━━━━━━━━━━━  [▶] [⏭] │  scrubber + 44 pt steps; swipe left/right on
│ Pre-flop · Flop · Turn · River · Showdown    │  the table also steps; street chips jump
│ ┌──────────────────────────────────────────┐ │
│ │ ✎ Note   "review later" "bluff-catch"    │ │  note/tags summary → P12
│ └──────────────────────────────────────────┘ │
│        [ Share this hand (.txt) ]            │
```
Opens at the last frame (desktop), so the first thing seen is the outcome; ⏮ rewinds.

### 7.3 Notes, tags, bookmarks (P12)
Sheet with a 4-line text field (placeholder = desktop copy), preset tag chips (`review later`,
`bluff-catch`, `thin value`, `weird line`, `big pot`) + custom tag field ("+ custom"), Remove /
Cancel / Save. Keyboard pushes the sheet up. Tagged hands show gold chips in lists; the
Recent-hands section has a tag filter chip row (all · review later · …).

### 7.4 Hand-history import (T3) and export/share
- "Import" → system file picker (`file_picker`, `.txt`) → a progress page ("Reading 1 file…")
  → result sheet: "Imported 38 hands (2 skipped) · reviewed 21 of your calls · 3 questionable
  ones added to the Review queue. Imported hands never count toward your play stats."
  Buttons: "Open Review" · "See hands". Failure: "Couldn't find any PokerStars-style hands in
  that file (4 blocks unparseable)." with "Try another file".
- Export: session summary "Share hands (.txt)" and replayer "Share this hand" use the system
  share sheet (`share_plus`) — save to Files, AirDrop, mail, a tracker app. "Copy" copies text.
- Import also accepts a share-into-app intent ("Open in All-In" from Files/Mail) → T3 result.

### 7.5 Backup, restore, reset
Settings > Data: "Back up everything (.json)" → share sheet; "Restore from backup" → file picker
(merge, never overwrite, then a count toast); "Reset all progress" → X2 full-screen with the
"Download a backup first" button, a text field requiring `RESET`, and the danger button "Erase
everything" (disabled until typed) — identical semantics to desktop.

---

## 8. ONBOARDING

### 8.1 First-run tour (O0)
Four full-screen pages, horizontal paging (swipe or Next), each: an illustrative animation
(page 1: cards dealt to a mini table; 2: a puzzle answer turning green; 3: a lesson card with a
glowing term; 4: a coin flip with "decision" underlined), title Bricolage 24 pt, body 17 pt —
the four `TOUR` texts verbatim. Dots + "Skip" (ghost) + "Next" / "Continue" (primary). Marks
`allin.onboarded.v1`.
```
│                                    Skip      │
│            (animation, 200 pt)               │
│ Play against real-ish opponents              │
│ Four bot styles with genuinely different     │
│ tendencies. The EV Coach watches every       │
│ decision and explains — in plain English     │
│ first — whether it made money. …             │
│ ● ○ ○ ○                                      │
│ ┌──────────────────────────────────────────┐ │
│ │                  Next  ›                 │ │
│ └──────────────────────────────────────────┘ │
```
A fifth mini-page teaches the two table gestures with a live mini-table: "Tap the table to step
the action" and "Press and drag the Raise button to size a bet" (skippable).

### 8.2 Placement (O1)
Intro page: "Eight quick questions calibrate the drills to your level… No grade, no judgment,
and you can skip it." Buttons "Calibrate me" / "Skip — start playing". Then D6 flow. Result →
"Take me there" (lesson) or "Start playing" (lobby with the play card focused).

---

## 9. SETTINGS + ABOUT

Settings (X0) — grouped list, 52 pt rows, descriptions as 13 pt muted second lines:

| Group | Row | Control |
|---|---|---|
| Table & cards | Four-colour deck | toggle + 4 mini cards preview |
| | Realistic reveals | toggle |
| | Theme | segmented System · Dark · Light |
| | Reduce motion | toggle ("also honours your system setting") |
| | Haptics | toggle |
| Coach | Strictness | segmented Relaxed · Standard · Strict |
| | Simulation quality | segmented Standard · High |
| | Always expand "Show me the math" | toggle (default off) |
| Play | Default pace | segmented Step · Auto |
| | Auto speed | segmented Slow · Normal · Fast |
| | Tap the table to step | toggle (default on) |
| | Auto-deal next hand (Auto mode) | toggle (default on) |
| Drills | Replay the action automatically | toggle (default on) |
| Learning | Tour & placement | "Run again" |
| Data | Back up everything | share |
| | Restore from backup | file picker |
| | Import hand history | file picker |
| | Reset all progress | → X2 |
| About | About All-In | → X1 |

About (X1): logo, "All-In · Poker Dojo", the tagline, version pill (from `package_info_plus`),
"How to use it" four cards, "Good to know", "How the grading works" (methodology, verbatim),
"On the roadmap", "Built by Gapp" with an external link, © line. The desktop "Play online /
Download desktop" pair becomes one row "Also on desktop and web ›". The passive update check is
dropped (stores handle updates).

---

## 10. COMPONENT LIBRARY

| Component | Variants / sizes | Notes |
|---|---|---|
| **Button** | primary (gold bg, ink-900 text), secondary (ink-700), outline, ghost, danger-outline · heights 44 / 56 · icon-leading | Radius 14; label Inter 16 semibold; mono amount inside label; disabled 40 %; pressed scale 0.97 + light haptic |
| **Chip** | preset (52×44, ink-600, selected gold), filter/tag (h 32, hit 44), source pill (h 22, caps 10 pt, non-interactive), due badge | Selection tick haptic |
| **Playing card** | XS 22×31 (reveal rows, coach header) · S 30×42 (opponents 6-max) · S- 24×34 (9-max, replayer) · M 44×62 (board 6/9-max, drill hero) · M+ 52×73 (HU board) · L 56×78 (drills hero) · XL 72×101 (hero) · XL+ 80×112 (HU hero, large phones) | Face: white→#eef2f6 gradient, rank Bricolage 800 at 0.36 w, suit glyphs; back: felt gradient with gold ring; four-colour deck swaps ♦ #2f7fd6, ♣ #2fa066; radius 0.13 w |
| **Seat** | standard 104×58 · compact 92×46 · HU 160×64 · hero strip · snapshot (drill/replayer) | States: idle, to-act (gold ring + arc/pulse), folded (55 %), winner (green ring), all-in (red pill), sitting out |
| **Bet pill / chip stack** | amount pill 22 pt tall mono 11; chip stack 3 discs 14 pt | Animates plate → bet spot → pot |
| **Pot pill** | 30 pt tall, chip icon + mono 15 gold-light | Street label 10 pt caps above, tracking 0.3 em |
| **Board** | 5 slots; dashed placeholders; sizes M / M+ / 40×56 | Deal-in animation per card |
| **Range matrix** | paint (366) · read-only highlight (300, 240) · compare (366) · thumbnail (120, non-interactive) | Cell = (size − 12)/13; label ≥ 8 pt; loupe on paint; pinch-zoom on paint |
| **Loupe** | 72 pt circle, 2.4× | Shows 3×3 neighbourhood + hovered cell outline |
| **Coach chip** | 48×320, verdict tinted disc + title + chevron | Auto-collapses to badge |
| **Coach badge** | top-bar pill "✎ Coach ●3" | Dot colour = latest verdict |
| **Coach note sheet** | non-blocking (45/92 % detents) · blocking (62 %, no dismiss) · read-only (from lists) | Layers: L1 paragraph, equity bar, L2/L3 disclosure rows, EV tile, actions |
| **Verdict badge** | mistake / thin / ok / great / info · sizes 20 (row), 28 (header), 40 (drill feedback) | Icon + colour + label; never colour alone |
| **Equity bar** | 10 pt tall, verdict-coloured fill, white "needed" marker | Label row above/below |
| **Stat tile** | 80×64 (4-up), 2×2 (summary), KPI (120×84 in scroll strip) | Label 10 pt caps faint, value mono 18–24 bold, tone good/bad/gold, optional ⓘ |
| **Sheet** | detents (peek/expanded), blocking (no handle), mini (auto-height) | Grabber 36×5; scrim 55 %; keyboard-aware |
| **Segmented control** | 2–3 options, height 36 (hit 44), gold selected | Used for table size, antes, pace, theme, strictness |
| **Toggle** | 51×31 system-style, gold on | Label + description row |
| **Slider** | horizontal bet slider (detents), vertical drag-size slider, calculator sliders | Thumb 28, hit 44; value bubble |
| **Stepper** | −/+ 44 pt with mono value | Hold-to-repeat |
| **Numeric keypad** | 12 keys 3×4, each 116×48 | Clamps to legal range; "Done" |
| **Progress** | ring (20/48 pt), bar (6 pt), dots (tour, placement), pips (difficulty) | Ring fill gold when goal met |
| **Ticker** | 18 pt line, colour-coded by log kind | Tap → log |
| **Results card** | felt overlay, net + winner + reveal rows | Scroll inside; "All hands ›" |
| **Move navigator** | ⏮ ◀ text ▶ ⏭ + scrubber + street chips | Shared by drills and replayer |
| **Table renderer** | live (P1), snapshot (drill/replayer), preview (lobby) | One widget, three modes |
| **Glossary term** | dotted gold underline | Tap → definition mini |
| **Callout** | key-idea (gold), beware (amber), info (blue) | Lesson prose |
| **Toast** | 44 pt, bottom above tab bar / action bar, 2.5 s | "Session paused", "Hand log copied" |
| **Empty state** | icon 48 pt tinted, title Bricolage 20, body 15, 1–2 buttons | Review queue, no hands, no reads |
| **Heatmap** | 16 pt cells, 3 pt gap, 3 tones (ink-700 / gold 35 % / gold) | Tap → tooltip mini |
| **Line chart / mini bars / diverging bars** | fl_chart | Scrub with haptic ticks |

Colour tokens carry over from `tokens.css` unchanged (ink-900 … ink-300, text/muted/faint,
gold/dark/light, felt/dark/light, good/bad/warn/info, suit red/black, combo pair/suited/offsuit,
chip colours). Radii 6/10/16/22. Light theme = the `.light` channel overrides.

---

## 11. MOTION + HAPTICS

Easings: **standard** `cubic-bezier(0.2, 0.8, 0.2, 1)` (the existing `--ease`); **emphasized-
decelerate** `cubic-bezier(0.05, 0.7, 0.1, 1)` for entrances; **spring** (stiffness 380,
damping 30) for chips landing and the coach chip; sheets use the platform's default curve.

| Moment | What moves | Duration | Ease |
|---|---|---|---|
| Deal | 2 cards per seat from the dealer button, clockwise; each card 220 ms travel + 40 ms stagger; hero cards flip face-up last (2×150 ms) | ≈ 1.1 s total at 6-max, 1.5 s at 9-max | emphasized-decelerate |
| Blinds/antes post | chip stack plate → bet spot | 240 ms | standard |
| Bot bet/call | action pill pop (200 ms) + chip slide (250 ms) + stack tick (120 ms) | ≤ 400 ms | spring on landing |
| Fold | cards slide 20 pt in and fade to 30 % | 220 ms | standard |
| Turn moves | ring hops seat → seat | 160 ms | standard |
| Street change | bet chips → pot (280 ms, 30 ms stagger) then board cards deal-in (per card: scale 0.9→1 + fade, 180 ms, 55 ms stagger) | ≈ 700 ms | standard |
| Hero to act | cards lift 6 pt + glow; action buttons slide up 8 pt | 200 ms | emphasized-decelerate |
| Showdown flip | half-flip 150 ms × 2 per seat, 60 ms stagger | ≤ 800 ms | standard |
| Pot to winner | chip stack + number glide to winner plate, stack counts up | 420 ms | spring |
| Results card | slide up from y+40 + fade | 260 ms | emphasized-decelerate |
| Coach chip | drop from y−16 + fade + scale 0.96→1; collapse into badge (shrink toward the badge) | 240 ms / 200 ms | spring / standard |
| Coach sheet (blocking) | felt dims (200 ms) + sheet rises | 320 ms | platform |
| Range paint | cell fill 80 ms colour transition | 80 ms | linear |
| Peek score card | slide up + accuracy number counts up from 0 | 320 ms + 500 ms count | emphasized-decelerate |
| Drill answer | chosen button colour + 4 pt bounce; wrong = 2 px horizontal shake 220 ms | 250 ms | spring |
| Rating delta | "+12" floats up 12 pt and fades | 600 ms | standard |
| Goal ring met | ring completes + 300 ms pop | 300 ms | spring |
| Tab switch | crossfade 120 ms | 120 ms | linear |

Haptics (Flutter `HapticFeedback` + platform patterns; rate-limited to one event per 250 ms
except paint ticks):
- **selectionClick**: preset chip, slider detent, stepper, segmented change, range paint cell
  flip (40 ms min gap), chart scrub tick.
- **lightImpact**: any action button press (fold/check/call/raise/next), tap-to-step on felt,
  coach chip for ok/great.
- **mediumImpact**: hero's own chips land in the pot; "thin spot" chip; drill answer submitted.
- **heavyImpact**: all-in committed.
- **notification success**: hero wins a pot; drill correct; goal met; SRS card retired.
- **notification warning**: blocking mistake sheet; drill wrong; non-blocking "mistake".
- **notification error**: import failed; reset confirmed.
All haptics honour the Settings > Haptics toggle and the OS system-haptics setting.

**Reduced motion** (system flag or setting): every travel animation becomes a ≤ 150 ms
crossfade in place (chips appear at the destination, cards appear dealt, pot count snaps with a
single fade); sheets fade instead of sliding; no pulsing ring (a static 2 pt ring + "▶"
glyph); no count-up numbers; the coach chip fades in/out; auto-play cadence is unchanged so
timing stays predictable. No parallax anywhere in either mode.

---

## 12. GESTURES + REACHABILITY MAP

```
                 390 × 844 — thumb zones for a right-handed grip
┌──────────────────────────────────────────────┐
│  HARD (top 200 pt)                           │  ← only glanceable info + rare controls:
│  top bar: Leave · session pill · Coach · Pace│     all 44 pt tall, edge-anchored; each has a
│  top seat                                    │     thumb-zone alternative (below)
├──────────────────────────────────────────────┤
│  STRETCH (200–520)                           │  ← seats (tap = read range, long-press = card),
│  side seats · board · pot · coach chip       │     felt tap = step / pause, coach chip tap
├──────────────────────────────────────────────┤
│  EASY (520–810)                              │  ← hero cards, size row, presets, actions,
│  hero · size slider · presets · Fold/Call/   │     Next action / Next hand, Got it (sheet
│  Raise · Next · Explain · sheet buttons      │     footers), keypad
└──────────────────────────────────────────────┘
```

| Gesture | Where | Result |
|---|---|---|
| Tap | action buttons | fold / check / call / bet-raise / next action / next hand |
| Tap | felt (non-seat) | Step mode: next bot action · Auto: pause/resume · hero to act: nothing |
| Press + drag up | Raise button | vertical size slider; release sets, tap commits; sideways > 30 pt cancels |
| Drag | size row | slider (detents at presets) |
| Tap | bet readout | numeric keypad |
| Hold | − / + steppers | auto-repeat |
| Tap | opponent seat | Read range (P6) — or seat card outside betting |
| Long-press 450 ms | opponent seat | seat card (P7) |
| Tap | ticker | hand log sheet |
| Long-press | ticker | copy hand log |
| Tap | coach chip / badge | note sheet / notes list |
| Tap | top-left session pill | session sheet |
| Tap / long-press | pace pill | toggle Step↔Auto / pace & speed mini |
| Tap | results card | hold auto-deal (Auto mode) |
| Drag / tap | matrix | paint (first cell decides add/remove) / toggle one cell |
| Pinch / two-finger drag / double-tap | matrix | zoom / pan / reset |
| Swipe down | sheets (non-blocking) | dismiss |
| Swipe left | drill feedback sheet | next puzzle |
| Swipe left/right | replayer table | step frame |
| Scrub | trend chart | value readout |
| System back / ‹ Leave | table | leave (session paused) |
| System back | sheet / mini / modal | dismiss topmost (blocking note: shake, no dismiss) |
| Left-edge swipe | table | none (modal route) — avoids accidental exits while reaching for Fold |

Left-handed grip: no mirrored layout (poker convention keeps Fold left, Raise right), but
every top-bar control has a bottom-zone alternative: Coach notes are in the session sheet's
log; pace toggles from the overflow in P15 (bottom sheet); Leave via system back.

---

## 13. ACCESSIBILITY

- **Dynamic type**: all prose (coach notes, lessons, feedback, stats explainers, settings)
  scales fully with the system setting up to AX5. Table-critical labels (stack, position, HUD,
  bet pills, card ranks) scale from `xSmall` to `Large` then **cap** so the seat layout never
  breaks; from `xLarge` up the seat HUD line moves into the seat card and the ticker grows to
  two lines. Action button labels scale to `xxLarge` then truncate the verb ("Raise 7.5"). The
  matrix cell labels never scale (they are glyphs), but the loupe grows to 96 pt and zoom
  defaults to 1.5× when the text size is ≥ `xxLarge`.
- **Contrast** (dark): text #e9eef4 on ink-900 #0b0f14 ≈ 16:1; muted #9aa7b4 ≈ 8.3:1; faint
  #6b7888 ≈ 4.6:1 — faint is used only for ≥ 12 pt semibold or non-essential text; gold #e8c25a
  on ink-900 ≈ 10.5:1; gold-on-gold-button text ink-900 on #e8c25a ≈ 10.5:1; good/bad/warn/
  info all ≥ 4.5:1 on ink-800 for 13 pt+. Light theme tokens are validated to the same floors.
  Card faces: suit red #d83a3a on white ≈ 4.9:1; four-colour blue #2f7fd6 ≈ 4.5:1 and green
  #2fa066 ≈ 3.5:1 are used only for large glyphs (≥ 18 pt) — the rank glyph carries meaning.
- **Semantics labels** (Flutter `Semantics`): card "Queen of spades"; face-down "Face-down card";
  seat "Ivey, button, 100 big blinds, tight-aggressive, raised to 3 big blinds, to act" (HUD
  read as "plays 22 percent of hands, raises 18 percent, seen 12 hands"); pot "Pot 4 and a half
  big blinds, flop"; action buttons "Raise to 7 and a half big blinds"; preset "Two-thirds pot,
  7 and a half big blinds"; matrix cell "Ace king suited, selected" with the grid exposed as a
  13-row table (row = high rank) so VoiceOver/TalkBack can navigate by row; coach chip "Coach
  note, mistake, your call, double-tap to read"; verdict badges always carry the label.
- **Screen-reader alternatives**: drag-paint is unnecessary — cells toggle by activate; the
  vertical drag-size gesture is optional (presets + keypad exist); long-press seat card is
  reachable from P6 "About"; felt-tap step has the explicit button.
- **Colour-blindness**: four-colour deck (Settings, also offered in the tour's mini-page);
  verdicts = icon + label + colour; matrix compare mode adds hatching/dots under "differentiate
  without colour"; equity bar has the numeric % beside it; heatmap tones also differ in
  luminance; archetype identity uses initial + name in the seat card, not only the ring colour.
- **Motion**: honours system reduce-motion and the in-app toggle (§11).
- **Touch**: every control ≥ 44×44 or hit-slopped; sheets have 36×5 grabbers plus a semantic
  "Close" action; blocking sheets announce "Hand paused — coach note" on open.
- **Focus order**: on the table: hero cards → price line → action buttons → presets → seats
  (clockwise from hero) → board → pot → top bar. Sheets trap focus.

---

## 14. EDGE / EMPTY / ERROR STATES

| Situation | Behaviour |
|---|---|
| No session, Play tab | Lobby play card; table route shows the empty felt card (§4.15) |
| Session exists, user on another tab | "Session in progress" pill above the tab bar; Auto mode paused |
| App backgrounded mid-hand | State persisted after every action; on return Auto is paused with "Paused · tap to resume" |
| Process killed mid-hand | Hand restored from the persisted `GameState`; if the coach was mid-evaluation the note is dropped (never shown late) |
| Hero busts | "Session over — you busted" summary; ✕ hidden; "New session" only |
| Bot busts | Silently rebuys to the starting stack on the next deal (desktop behaviour); ticker line "Polk rebuys" |
| All-in run-out | Remaining board cards deal with 400 ms pauses per street regardless of pace; no action bar; hand-over as usual |
| Side pots | Pot pill shows "Main 40 · Side 12" stacked; pot-to-winner animates each pot separately |
| Realistic reveals on | Folded seats stay face-down at showdown and in the results card ("Folded on the flop." with no would-have line) |
| Coach evaluation slow (High quality, 9-max) | Chip shows after it resolves; the hand continues (non-blocking) — for a blocking verdict that arrives after the next bot action, the pause still fires (desktop semantics: `paused: true` at push) |
| Coach evaluation throws | Falls back to 50 % equity like desktop; the note's expert layer says "estimate unavailable — treated as a coin flip" |
| Guess with nothing painted | Button reads "Peek"; result card explains no score |
| Guess with everything painted | Allowed; precision will be low; the score card's plain line says "You painted every hand — coverage 100 %, precision 23 %" |
| Read range on a seat that just folded (race) | The modal opens read-only with "Ivey folded — here's the range they had" and no scoring |
| Explain last move with no bot action yet | Button disabled |
| Hand log empty (before first deal) | "Actions will appear here." |
| Session sheet with 0 hands | Tiles show 0 / — ; End session still available |
| Summary with 0 hands | Copy/Share disabled; "No hands were played." |
| Review queue: nothing due | D5 empty state (two variants) |
| Drill generation fails to find a focus kind | Falls back to a random puzzle (desktop loop of 60) silently |
| Equity calc: empty range / no hero cards | Calculate disabled with footer hint "Pick two cards" / "Paint a range" |
| Equity calc: card used on board and hand | Picker cell disabled (30 %) |
| Multiway trainer computing | Bars shimmer; % shows "…" |
| Import: no hands parsed | Error sheet with the desktop message + "Try another file" |
| Import: partial | Success sheet with the skipped count |
| Import: file > 5 MB | Progress with a cancel; parsed in chunks (isolate) |
| Storage full / DB error | Toast "Couldn't save — free up space"; play continues in memory; banner in Stats |
| Stats with < 8 hands | KPI tiles show values; the style/position cards show the "tracked from every new hand" placeholder |
| Heatmap with no activity | Placeholder sentence (desktop) |
| No lessons completed | Study header 0/31; the lobby "Continue" points at Hand Rankings |
| Placement skipped | Rating stays 1000; D0 shows "Calibrate my level" row until taken |
| Reset done | Returns to the lobby's first-run state; tour offered again (setting) |
| Offline | Everything works; About hides the external links' subtitles if unreachable (no update check) |
| Landscape / iPad | Phones lock to portrait. iPad runs the phone layout centred at 430 pt width in this release (see §15) |
| Low-power mode | Auto speed unchanged; decorative animations (arc sweep, glow) disabled |
| Very long bot name in another locale | Names are fixed English pro surnames; truncation rule still applies |
| Dynamic type ≥ AX3 on the table | Seat HUD moves to the seat card; ticker 2 lines; hero strip 2 lines; felt shrinks 40 pt |

---

## 15. FEATURE DISPOSITION TABLE

| Desktop feature | Disposition | How / why |
|---|---|---|
| Session vs bots, 2 / 6 / 9 seats | **Redesigned** | Lobby play card; three purpose-built portrait seat layouts (§4.1–4.2) |
| Optional ante (0.25 bb) | Kept | Lobby chip; posts animate like blinds |
| 4 archetypes with observed HUD | **Redesigned** | Ring colour + HUD line after 8 hands; full name/blurb in the seat card; HU read strip |
| Manual step-through | **Redesigned** | "Next action" button + tap-the-felt; per-action animation ≤ 400 ms |
| Auto-play, 3 speeds | Kept | Pace pill; think-arc; pause on felt tap; auto-deal countdown (new, optional) |
| Hero actions with bet sizing (½ ¾ Pot All-in, slider, numeric) | **Redesigned** | Six presets (Min ⅓ ½ ⅔ Pot All-in), detented slider, steppers, keypad, press-drag on Raise; button shows the exact commit |
| EV coach notes per decision, 4 verdicts | Kept | Chip → sheet; verdict colours/labels unchanged |
| Blocking mistakes pause the hand | Kept | Non-dismissable sheet + felt dim + "Got it" |
| 3-layer note (plain / math / expert) | Kept, made structural | Three visible tiers in every note; layer 1 never collapses |
| View assumed opponent range (13×13) | Kept | Push inside the note sheet, 300 pt read-only |
| Guess Range then Peek, accuracy/precision/recall | **Redesigned** | Full-screen paint modal with loupe, drag-paint, pinch-zoom, undo, presets; plain-English score card |
| Peek reveals hole cards | Kept as on desktop | Cards reveal at hand end (desktop moved this too); copy says so |
| Explain last bot move | Kept | Ghost button in bot-to-act / hand-over bars + seat card |
| Hand log | **Redesigned** | Ticker line + log tab in the session sheet with coach notes interleaved |
| Hand-over reveal of all cards | Kept | Seat flips + results card with `revealNote` lines; 9-max overflow sheet |
| Session summary | Kept | Full-screen modal, same order (decisions first) |
| End session | Kept | Session sheet + overflow + lobby resume-card swipe |
| Hero self-stats (VPIP/PFR) | Kept | Session sheet "Your style" row with explainer |
| Coach strictness, sim quality | Kept | Settings > Coach |
| Realistic reveals | Kept | Settings + mid-session P15 |
| Four-colour deck | Kept | Settings with preview; also offered in the tour |
| Right-rail "This session" panel | **Redesigned** | Collapsed into the top-left pill + session sheet |
| "Coach notes (n)" pill | **Redesigned** | Top-bar badge with verdict dot + notes list sheet |
| Keyboard shortcuts (F/C/R, arrows, ?, 1/2/3, Enter) | **Cut** | No hardware keyboard on phones; replaced by thumb-zone buttons, felt tap, swipe-to-next. Hardware-keyboard support may return for iPad later |
| Shortcut overlay | **Cut** | See above; the tour's gesture page replaces it |
| Sidebar tip card | **Cut** | The lobby's first-run hint card and the tour cover it; persistent tips clutter a phone |
| Dark-mode switch in sidebar | Kept | Header moon/sun + Settings theme (adds System) |
| Drills: Mixed / Push-Fold / Exploits / Review | Kept | Mode cards |
| Move navigator | **Redesigned** | Horizontal ⏮◀▶⏭ + scrubber + auto-replay on entry |
| 2–3 answer options, instant feedback, rationale, grading matrix, lesson link | Kept | Feedback sheet; matrix as an expander at 300 pt |
| Drill 5 similar | Kept | Feedback sheet button + count line |
| Elo-like rating, accuracy, streak, best | Kept | Tiles + explainer mini |
| Daily goal + day streak | Kept | Goal ring line, lobby today strip; no notifications (by design) |
| Placement test | Kept | Full-screen paged; reachable from onboarding, Drills, Settings |
| ICM bubble spots | Kept | Stack emphasis, ICM explainer pill, context row |
| Study: 5 levels / 31 lessons, progress, mark complete | Kept | Collapsible path; sticky completion bar |
| Embedded range matrices | Kept | Read-only 300–366 pt |
| Pot-odds calculator | **Redesigned** | Stacked sliders + result tiles |
| Bluff break-even calculator | **Redesigned** | Stacked; two result cards |
| Multiway equity trainer | **Redesigned** | Chip row + stepper + tappable bars |
| Free-form equity calculator | **Redesigned** | Full-screen, paged You/Opponent/Board, sticky Calculate, results page |
| Range explorer (exact-hand, range-vs-board, blockers) | **Redesigned** | Full-screen widgets; breakdown as collapsible cards |
| Hand rankings | Kept | List with enlarge-on-tap |
| Quizzes | Kept | Inline card, same logic |
| Cheat sheet | Kept + search | Sticky section headers |
| Glossary hover definitions | **Redesigned** | Tap → definition mini-sheet; "See all terms" |
| Stats: bb/100 trend | Kept | fl_chart line with scrub |
| Results vs each archetype | Kept | Rows with bars |
| Positional stats | Kept | Diverging bars + paragraph |
| Showdown stats (WTSD/W$SD/AF) with explanations | Kept | Tap → explainer mini |
| Read accuracy | Kept | Mini bars |
| Coaching review of leaks | Kept | Card + detail push |
| Practice heatmap | Kept | Horizontal scroll, 16 pt cells, tap tooltip |
| Hand replayer | **Redesigned** | Full-screen, swipe-to-step, street chips |
| Notes / bookmarks / tags | Kept | Keyboard-aware sheet; tag filter chips |
| PokerStars-style export | **Redesigned** | System share sheet (Files/AirDrop/mail) + Copy |
| Hand-history import + analyzer | **Redesigned** | File picker / share-into-app → progress → result sheet |
| Backup export / reset with typed confirmation | Kept | Settings > Data; restore added |
| Theme light/dark | Kept (+System) | |
| Reduced motion | Kept | Follows system; full spec in §11 |
| Rerun onboarding / placement | Kept | Settings > Learning |
| About / roadmap / version / methodology | Kept | About page; update-check row **cut** (app stores) |
| "Play online / Download desktop" cards | **Redesigned** | Single "Also on desktop and web" row |
| Onboarding 60-second tour | Kept + gesture page | Paged full-screen |
| Table config persisted (`allin.table.v1`) | Kept | Lobby chips |
| iPad / landscape layouts | **Deferred** | Phone layout centred at 430 pt on iPad this release; a two-column tablet layout (table + coach rail) is the obvious next step but is out of scope for "portrait phone first" |
| Hardware keyboard on tablets | **Deferred** | With the iPad layout |
| Hover tooltips everywhere else (HUD hints, stat hints, bb/100) | **Redesigned** | Every tooltip becomes a 44 pt tappable label → mini-sheet with the same copy |

---

### Appendix A — Table geometry reference (6-max, 390×844)

| Element | x (centre) | y (centre) | Size |
|---|---|---|---|
| Felt oval | 195 | 341 | 346 × 458 (radius 46 % / 50 %), rail 10 pt #241509 |
| Inner rim line | 195 | 341 | 322 × 420, white 10 % |
| Seat 3 (top) plate | 195 | 148 | 104 × 58; cards below at y 200 |
| Seat 2 (right-upper) | 330 | 262 | 104 × 58; cards above-left |
| Seat 1 (right-lower) | 330 | 430 | 104 × 58 |
| Seat 5 (left-lower) | 60 | 430 | 104 × 58 |
| Seat 4 (left-upper) | 60 | 262 | 104 × 58 |
| Bet spots | 58 pt toward centre from each plate | | pill 22 tall |
| Street label | 195 | 292 | 10 pt caps |
| Pot pill | 195 | 312 | 30 tall |
| Board | 195 | 355 | 5 × (44 × 62), 6 pt gaps → 244 wide |
| Hero bet spot | 195 | 505 | |
| Hero cards | 195 | 578 | 2 × (72 × 101), 6 pt gap; top edge y 528 |
| Hero strip | — | 646 | 20 tall |
| Size row | — | 676 | 32 tall |
| Presets | — | 720 | 44 tall |
| Actions | — | 778 | 56 tall; bottom edge y 806 |
| Coach chip | 195 | 135 (over the top rim) | 320 × 48 |

### Appendix B — Key copy (exact)

- Lobby: "Deal me in" · "Resume table" · "Start a new session" · "Coach charts assume 6-max —
  verdicts at other table sizes use the nearest position as an approximation."
- Action bar: "Fold" · "Check" · "Call 2 bb" · "Call all-in 37 bb" · "Bet 4.5" · "Raise to 7.5"
  · "All-in 100" · "Next action ›" · "Next hand ›" · "Ivey is thinking…" · "Paused · tap to
  resume" · "✎ Explain"
- Presets: "Min" "⅓" "½" "⅔" "Pot" "All-in"
- Price line: "To call 2 bb · need to win 1 in 4"
- Coach: "Mistake" "Thin spot" "Reasonable" "Nice play" "Read" · "Show me the math" / "Hide the
  math" · "Expert detail" / "Hide expert detail" · "View range" · "Got it" · "Close" ·
  "White line = 33% needed (pot odds)"
- Guess: "Read Ivey's range" · "Optionally paint your guess, or just peek to study their range."
  · "Peek & score" / "Peek" · "Clear" · "Undo" · "Sharp read" "Solid" "Rough" "Way off" ·
  "Everyone's exact cards are revealed when the hand ends." · "Continue"
- Results: "+12.5 bb" · "YOU WON THE POT" / "HAND OVER" · "Ivey wins with two pair." · "All 8
  hands ›"
- Session: "This session" · "Hand log" · "Your style" · "End session" · "Session paused —
  resume from Play"
- Drills: "Correct" / "Not optimal" · "See the range it was graded against" · "Drill 5 similar"
  · "Next puzzle ›" · "Nothing due right now" · "No spots to review yet" · "Beaten 1 of 3 —
  back in 2 days" · "Retired — nice."
- Study: "Mark complete" · "✓ Completed" · "Next lesson ›" · "Open full screen ›" · "See all
  terms ›"
- Stats: "Your progress" · "Decisions, not results — but we track both." · "Import hands" ·
  "Share hands (.txt)" · "Share this hand (.txt)" · "Back up everything (.json)" · "Reset all
  progress?" · "Erase everything"
