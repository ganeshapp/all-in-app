# All-In · Poker Dojo — Mobile UX Proposal (angle: table fidelity first)

Target: Flutter, iOS + Android phones, portrait-first. Reference frame **390×844 pt** (iPhone 15/16);
must hold at **360×780** (small Android) and scale to **430×932** (large phones). Dark theme
primary, light parity. Brand: green felt + gold accent. Fonts: Bricolage Grotesque (display),
Inter (body), JetBrains Mono (numbers). All sizes are pt (logical pixels). Every tappable target
is ≥ 44×44 pt, or carries hit-slop that brings it to 44.

Sources read: `README.md`, `TONE.md`, `Notes.md`, `src/views/*.tsx`, `SideRail.tsx`,
`ActionBar.tsx`, `EVCoachPanel.tsx`, `GuessModal.tsx`, `RangeMatrix.tsx`, `drills/*.tsx`,
`study/lessons.tsx` + widgets (skimmed), `StatsView.tsx`, `OnboardingModal.tsx`,
`gameStore.ts`, `Seat.tsx` / `PokerTable.tsx` / `HUD.tsx` / `PlayingCard.tsx`,
`ResultOverlay.tsx`, `SessionSummaryModal.tsx`, `HandReplayModal.tsx`, `SettingsView.tsx`,
`AboutView.tsx`, `tokens.css`, and `poker-zapp/docs/port/*.md`.

The thesis of this proposal: **the table is where the learning happens**, so the table must feel
as good as PokerStars / GGPoker mobile first — readable seats at 2/6/9, big hero cards, honest
chip and card motion, a bet-size control you operate with a thumb in one second — and the coach
is layered over that table without ever hiding the hero's cards or the action bar.

---

## 1. Design principles

1. **The table is the classroom.** Every pixel of the Play screen serves reading the table:
   seats, stacks, bets, board, pot, whose turn. The coach is layered *on top* (chip → sheet),
   never beside it, and never covers the hero's cards or the action bar.
2. **The loop lives under the thumb.** Fold / Check-Call / Bet-Raise, "Next action", "Next hand"
   and "Got it" all sit in the bottom 160 pt. Nothing done every few seconds is above y = 620.
3. **One second to size a bet.** Six preset chips, a detented slider, a typed value, and a
   press-and-drag on the Raise button. The primary button always shows the exact commit
   ("Raise to 7.5"). No modal, no confirm dialog, no system keyboard.
4. **Plain English first, math on demand.** Every coach surface renders TONE.md's three layers
   as three visible tiers: layer 1 always open; "Show me the math" and "Expert detail" as
   disclosure rows. Layer 1 never collapses; layer 3 never auto-expands.
5. **Interrupt only for money.** Only a *blocking* mistake stops the hand (a sheet you must
   acknowledge). Everything else is a 4-second chip that shrinks into a badge you can reopen.
6. **Reads are earned, not given.** HUD numbers appear after 8 observed hands; Guess Range
   always offers painting *before* peeking; hole cards are revealed only at hand end.
7. **Portrait-native, not shrunken.** Three purpose-built seat layouts (2 / 6 / 9), a compact
   seat for 9-max, and card sizes chosen per slot. No pinch-zooming a desktop table.
8. **Quiet consistency.** No push notifications, no streak guilt. The daily goal is a small
   ring; the streak is a number that never nags.

---

## 2. Information architecture

### 2.1 Root tabs (bottom tab bar, 49 pt + bottom safe area)

| Tab | Root screen | Notes |
|---|---|---|
| **Play** | Lobby (home / entry) | Table setup, resume-session card, today strip. The *table itself* is a full-screen route pushed from here with the tab bar hidden. |
| **Drills** | Drills home | Rating tiles, daily-goal ring, mode cards, Review due count. |
| **Study** | Level path | 5 levels / 31 lessons with progress. |
| **Stats** | Progress overview | KPIs, trend, breakdowns, hands, heatmap, import / export. |

Settings and About are not tabs: a gear icon in the Play-lobby and Stats headers opens Settings
(push); About is a row inside Settings. Four tabs keep each ≥ 88 pt wide at 390 (thumb-sized)
and give the table a full-screen canvas.

A **"Session in progress"** pill (56 pt, sits above the tab bar) appears on every tab while a
session is paused off-table: `● 12 hands · +4.5 bb   Resume ›`. Tap = resume the table.

### 2.2 Presentation types — when to use which

| Type | Used for | Dismissal |
|---|---|---|
| **Push** | Content you read and come back from (lesson, hands list, settings) | back chevron, system back, iOS edge-swipe |
| **Sheet** (detents 45 % / 92 %) | Context that belongs to what's beneath it (coach note, session stats, drill feedback) | drag down, scrim tap, system back |
| **Mini** (auto-height ≤ 40 %) | One decision or one definition (keypad, pace, glossary term, stat explainer, seat card) | drag down, scrim tap, system back |
| **Full** (full-screen modal) | Focused tasks that need the whole screen or must not be left accidentally (table, Guess Range, summary, replayer, placement, onboarding, reset) | explicit ✕ / Done, system back |
| **Overlay** | In-place on the felt (results card, coach chip, hints) | automatic or tap |

Rules: a sheet never opens another sheet on top — it pushes inside itself (coach note → range
viewer) or replaces itself. Blocking coach notes are the one sheet without drag-to-dismiss.

### 2.3 Screen inventory

| # | Screen | Type | Reached from |
|---|---|---|---|
| P0 | Play lobby (home) | Tab | tab bar |
| P1 | Table (session) | Full (route `/table`) | P0 "Deal me in", Resume pill |
| P2 | Session sheet (This session · Hand log · End) | Sheet 45 / 92 % | P1 top-left pill, P1 ticker |
| P3 | Coach note | Sheet 45 / 92 % (**blocking: 62 %, no swipe-dismiss**) | coach chip, badge, notes list, lobby card |
| P4 | Coach notes list (this hand) | Sheet 45 % | P1 top-bar Coach badge |
| P5 | Assumed range viewer (read-only matrix) | Push-within-sheet (P3) | P3 "View range" |
| P6 | Read range (Guess → Peek) | Full | tap an opponent seat during betting |
| P7 | Seat card (about this player) | Mini | long-press seat, P6 "About", results row |
| P8 | Hand results | Overlay on the felt | automatic at hand-over |
| P9 | All reveals (9-max overflow) | Sheet 60 % | P8 "All 8 hands ›" |
| P10 | Session summary | Full | End session, bust |
| P11 | Hand replayer | Full | P10, Stats hands list, P2 |
| P12 | Hand note editor | Sheet 60 %, keyboard-aware | P10, P11, Stats |
| P13 | Bet amount keypad | Mini | tap the bet readout |
| P14 | Pace & speed | Mini | long-press pace pill / ▾ |
| P15 | Table options (mid-session) | Mini | top-bar overflow ⋯ |
| D0 | Drills home | Tab | tab bar |
| D1 | Drill spot | Push (tab bar hidden) | D0 mode card |
| D2 | Drill feedback | Sheet 70 / 95 % over D1 | after answering |
| D3 | Grading range | Expander inside D2 (300 pt matrix) | D2 |
| D4 | Rating / goal explainer | Mini | D0 tiles |
| D5 | Review queue empty state | In-place in D1 | D0 Review when nothing due |
| D6 | Placement test | Full (paged) | D0 "Calibrate", Settings, onboarding |
| S0 | Study path | Tab | tab bar |
| S1 | Lesson reader | Push (tab bar hidden) | S0 row, drill lesson link, placement result, lobby |
| S2 | Glossary definition | Mini ≤ 200 pt | tap a dotted term |
| S3 | Widget full-screen (equity calc, range explorer, breakdown) | Full | S1 "Open full screen" |
| S4 | Cheat sheet (lesson `cheat-sheet` + search) | Push | S0 |
| T0 | Stats overview | Tab | tab bar |
| T1 | Stat explainer | Mini | tap any dotted stat label |
| T2 | Hands list (recent, tag filter) | Push | T0 "See all" |
| T3 | Import hands (picker → progress → result) | Full flow | T0 / T2 "Import", share-into-app |
| T4 | Coaching review (leaks detail) | Push | T0 card |
| X0 | Settings | Push | gear icon |
| X1 | About | Push | Settings row |
| X2 | Reset all progress | Full (typed confirmation) | Settings > Data |
| O0 | Onboarding tour (4 pages + gesture page) | Full (first launch) | first run, Settings "Run again" |
| O1 | Placement intro / questions / result | Full (continues O0) | O0 last page "Continue" |

### 2.4 Navigation graph

```
TabBar ─┬─ Play (P0) ──▶ Table (P1, full) ──┬─ session pill / ticker ──▶ Session sheet (P2) ──▶ Replayer (P11) ──▶ Note (P12)
        │                                   ├─ coach chip / badge ──▶ Coach note (P3) ──▶ Range (P5)
        │                                   │                     └▶ Notes list (P4) ──▶ P3
        │                                   ├─ tap seat ──▶ Read range (P6) ──▶ score (in P6) ──▶ About (P7)
        │                                   ├─ long-press seat ──▶ Seat card (P7) ──▶ P6 / Explain
        │                                   ├─ hand over ──▶ Results overlay (P8) ──▶ All reveals (P9) / P7
        │                                   ├─ bet readout ──▶ Keypad (P13)
        │                                   ├─ pace pill ──▶ Pace (P14) · overflow ──▶ Options (P15)
        │                                   └─ End session ──▶ Summary (P10) ──▶ P11 / P12 / share
        │               └─ gear ──▶ Settings (X0) ──▶ About (X1) / Reset (X2) / Placement (D6) / Tour (O0)
        ├─ Drills (D0) ──▶ Spot (D1) ──▶ Feedback (D2) ──▶ Lesson (S1) | Drill 5 similar | Next
        │               └─ Calibrate ──▶ Placement (D6)
        ├─ Study (S0) ──▶ Lesson (S1) ──▶ Term (S2) / Widget full (S3) / Next lesson
        └─ Stats (T0) ──▶ Explainer (T1) / Hands (T2) ──▶ P11 / P12 / Import (T3) / Coaching (T4)
```

Rules:
- **System back** pops one level: the topmost mini/sheet first; on the table route it *leaves
  the table* (session persists, paused; toast "Session paused — resume from Play"). No
  confirmation dialog: leaving is always safe because state is persisted after every action.
- The table is a **modal route, not a push**, so the iOS left-edge back-swipe cannot fire while
  a thumb reaches for Fold.
- Deep links (drill feedback → lesson) push S1 on the Study tab and switch tabs, preserving the
  drill route so back returns to the feedback sheet.
- Everything is offline; there are no loading screens, only computation shimmers (equity).

---

## 3. HOME — the Play lobby (P0)

The Play tab root doubles as the home screen. It answers three questions in one glance:
*can I keep playing, what's due today, where was I learning?*

```
390×844                                        (safe top 47)
┌──────────────────────────────────────────────┐
│ ♠ All-In                              ⚙︎  ☾  │ 44   header: wordmark · Settings · theme
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ ● Session in progress                    │ │
│ │ 12 hands · +4.5 bb · 6-max · Step        │ │ 84   resume card (only while a session exists)
│ │                         [ Resume table ›]│ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │  ╭────────────────────────────────╮      │ │
│ │  │      ○   ○   ○                 │      │ │
│ │  │   ○   (felt preview)   ○       │      │ │ 236  play card: live felt preview that
│ │  │          ▭ ▭ ▭ ▭ ▭             │      │ │      re-seats itself as the chips change
│ │  ╰────────────────────────────────╯      │ │
│ │  Table    [Heads-up] [6-max ✓] [9-max]   │ │      segmented, 36 pt (hit 44)
│ │  Antes    [None ✓] [0.25 bb]             │ │
│ │  Pace     [Step ✓] [Auto]   Coach [on ●] │ │
│ │  ┌────────────────────────────────────┐  │ │
│ │  │           Deal me in               │  │ │ 56   primary
│ │  └────────────────────────────────────┘  │ │
│ └──────────────────────────────────────────┘ │
│  Today                                       │
│ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│ │ ◔ 14 / 20  │ │ ⚡ 3 days  │ │ 3 to review│ │ 76   goal ring · day streak · Review due
│ │ drills     │ │ streak     │ │ Review ›   │ │
│ └────────────┘ └────────────┘ └────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 📖 Continue: Pot Odds, Break-even & EV   │ │ 64   next incomplete lesson
│ │    Level 3 · 6 min · 9/31 done         › │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ✎ Coach's last note          Mistake  ›  │ │ 72   most recent decision review
│ │ "You paid 8 bb to win a pot of 24 bb…"   │ │
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│   ▶ Play     ◎ Drills     📖 Study   ▤ Stats │ 49 + 34 safe
└──────────────────────────────────────────────┘
```

Behaviour and copy:
- **Header**: "All-In" wordmark (Bricolage 20). Right: gear → Settings; moon/sun = theme quick-toggle.
- **Resume card** shows only when `session.active` and the user is off-table. Tap anywhere =
  resume. Swipe-left reveals "End session" (→ P10 summary).
- **Play card**: the segmented choices persist (`allin.table.v1`). When seats ≠ 6 a 12 pt faint
  note appears under the chips: "Coach charts assume 6-max — verdicts at other table sizes use
  the nearest position as an approximation." "Deal me in" starts a new session; if one exists
  the button reads "Resume table" with a secondary text button "Start a new session" beneath it
  (ends the old one → summary → deals).
- **Today strip**: the ring shows drills/20 or hands/30 (whichever is closer to met). "Review ›"
  opens Drills in Review mode when `dueCount > 0`; otherwise the tile reads "Nothing due".
- **Continue lesson**: the first incomplete lesson in path order.
- **Coach's last note**: latest decision review (verdict badge + first 60 chars of layer 1).
  Tap → P3 in read-only mode.
- **First-run empty state** (no sessions, no drills): resume, coach and continue cards collapse
  to a single hint card under the play card — "New here? The 60-second tour covers the four
  modes. [Take the tour]".

---

## 4. PLAY — the table (P1)

### 4.1 Layout at 390×844, 6-max

Vertical budget (pt), top to bottom: status 47 · top bar 44 · ticker 18 · felt canvas
(y 114–566) · hero cards overlap the felt's bottom rim · hero strip 20 · size row 32 ·
presets 44 · action buttons 56 · gaps 8/8/10 · bottom safe 34. Action buttons end at y 806.

```
390×844 · 6-max · hero (BB, Q♠Q♥) to act, facing Ivey's raise to 3          y
┌──────────────────────────────────────────────┐
│ (status bar / Dynamic Island)                │ 0–47
├──────────────────────────────────────────────┤
│ ‹ Leave  [12h · +4.5 bb ▾]  [✎ Coach ●3] [▶ Step ▾] ⋯ │ 47–91  top bar (44)
│  Ivey raises to 3 bb · Selbst folds          │ 91–109 ticker (tap → hand log)
│      ╭────────────┬──┬──┬───────────╮        │ 114 felt top rim
│      │            ┌──┴──┴───────┐   │        │ 115 top seat cards peek above the plate
│      │            │(N) Negreanu UTG│  │        │ 139–197 seat 3 plate 104×58
│      │            │ 98 bb   31/22  │  │        │
│      │            └────────────────┘  │        │
│      │                 ● 3 bb          │        │ 221–243 seat 3 bet pill (bet spot)
│ ┌──┬──┬─────────┐                ┌──┬──┬──────────┐│
│ │(S) Selbst  MP │                │(P) Polk   CO  ││ 239–297 seats 4 (left) & 2 (right)
│ │ 96 bb   –/–   │  Fold          │ 97 bb  24/18  ││          cards peek above each plate
│ └───────────────┘                └───────────────┘│
│      │           PRE-FLOP     ● 3 bb   │        │ 268 street label · 284–306 bet pills
│      │        ◎ Pot 4.5 bb             │        │ 281–311 pot pill
│      │    ▭    ▭    ▭    ▭    ▭        │        │ 321–383 board slots 44×62 (dashed)
│ ┌──┬──┬─────────┐                ┌──┬──┬──────────┐│
│ │(H) Hellmuth UTG│                │(I) Ivey  BTN D││ 407–465 seats 5 (left) & 1 (right)
│ │ 92 bb   12/9  │                │100 bb  22/18  ││          D = dealer button; gold ring
│ └───────────────┘   0.5 bb       └───────────────┘│          = to act (here: none, hero acts)
│      │        ◎ 1 bb (you)              │        │ 467–489 hero bet pill (BB post)
│      ╰──────────────╮   ╭──────────────╯        │ 566 felt bottom rim
│                 ┌─────┐┌─────┐                 │
│                 │ Q♠  ││ Q♥  │                 │ 520–621 hero cards 72×101 (lifted, glowing)
│                 │     ││     │                 │
│                 └─────┘└─────┘                 │
│  BB · 100 bb          To call 2 bb · need 1 in 4 │ 628–648 hero strip (position · stack · price)
│  [−] ────────●────────────── [+]   7.5 bb ✎    │ 656–688 size row: slider, steppers, readout
│  [Min]  [ ⅓ ]  [ ½ ]  [ ⅔ ]  [Pot]  [All-in]   │ 696–740 presets (44 tall)
│ ┌──────────┐ ┌─────────────┐ ┌───────────────┐ │
│ │   Fold   │ │  Call 2 bb  │ │ Raise to 7.5  │ │ 750–806 actions (56 tall)
│ └──────────┘ └─────────────┘ └───────────────┘ │
│                (home indicator)                │ 810–844 safe
└──────────────────────────────────────────────┘
```

Geometry (centres): felt oval x 22–368 × y 114–566 (346×452, radius 46 % / 50 %, 10 pt rail
`#241509`, inner rim line at 92 %). Seat plates 104×58: seat 3 (top) at (195, 168); seat 2 at
(330, 268); seat 1 at (330, 436); seat 5 at (60, 436); seat 4 at (60, 268). Side plates straddle
the rail — exactly how mobile clients gain width. Street label (195, 268); pot pill (195, 296);
board (195, 352); hero bet spot (195, 478); hero cards top edge y 520.

Seat order is counter-clockwise from the hero, identical to the desktop `seatPos()` so engine
seat ids map 1:1 (seat 1 right-lower, 2 right-upper, 3 top, 4 left-upper, 5 left-lower).

**Bet spots**: 58 pt from each plate centre toward the table centre; the current-street bet
pill (22 pt tall, mono 11, chip glyph) sits there. Blind and ante posts use the same spot.
Opponent hole cards (30×42, face-down) peek 24 pt above the plate's top edge, tucked behind it —
they never need their own slot, and a fold slides them down behind the plate.

### 4.2 How 2-seat and 9-seat adapt

**Heads-up (2)** — the felt shrinks to y 132–540 and everything grows:

```
│ ‹ Leave  [3h · −1.5 bb ▾]      [✎ Coach ●1] [▶▶ Auto ▾] ⋯ │
│  Ivey posts SB 0.5                            │
│      ╭───────────────────────────────╮       │
│      │   ┌────────────────────────┐  │       │
│      │   │ (I) Ivey · BTN/SB    D │  │       │ plate 160×64 with archetype name
│      │   │ Tight-Aggressive       │  │       │
│      │   │ 100 bb · 22/18 · 14h   │  │       │
│      │   └────────────────────────┘  │       │
│      │          ▭▭   ● 0.5 bb        │       │ opponent cards 34×48 + bet spot
│      │  Ivey has shown 14 hands:     │       │ read strip (after 8 observed hands)
│      │  opens 62 % on the button.    │       │
│      │            FLOP               │       │
│      │        ◎ Pot 2 bb             │       │
│      │    ▭    ▭    ▭    ▭    ▭      │       │ board 52×73
│      ╰───────────────╮ ╭─────────────╯       │
│                ┌─────┐┌─────┐                │ hero cards 80×112
```
Position tags follow the HU rule: "BTN/SB" for the button, "BB" for the other seat.

**9-max** — compact seats (84×46, no HUD line, cards 24×34) at eight rim positions, board 40×56:

```
│      ╭───────────────────────────────╮       │
│   ┌──────┐                     ┌──────┐      │ y 150  seats 5 (top-left) & 4 (top-right)
│   │Negre.│                     │Selbst│      │
│   │98·UTG│                     │96·MP │      │
│ ┌──────┐└──────┘         └──────┘┌──────┐    │ y 240  seats 6 & 3
│ │Hellm.│                        │Polk  │     │
│ │92·UTG+1│                      │97·CO │     │
│ └──────┘      ◎ Pot 4.5 bb       └──────┘    │ y 236  pot pill
│ ┌──────┐   ▭   ▭   ▭   ▭   ▭     ┌──────┐    │ y 290  board (40×56), 85–305 wide
│ │Anton.│                        │Dwan D│     │ y 340  seats 7 & 2
│ │88·UTG+2│                      │100·BTN│    │
│ └──────┘                        └──────┘     │
│   ┌──────┐                     ┌──────┐      │ y 430  seats 8 & 1
│   │Galfo.│                     │Ivey  │      │
│   │95·HJ │                     │100·SB│      │
│   ╰──────╯───────╮ ╭───────────╰──────╯      │
│                ┌────┐┌────┐                  │ hero cards 64×90
```
Compact seats show name (6 chars), position and stack. The HUD line and last action appear on
the plate as a 2-second overlay when the seat acts, and always inside the seat card
(long-press). Dealer button, turn ring and bet spots are unchanged.

**360×780** — the table canvas scales by 0.92 (felt 316 wide), board 40×56, hero cards 64×90.
Action rows keep their heights (44 / 56 are hard minimums); the hero strip and size row merge
into one 32 pt row ("BB · 100 bb · 7.5 bb ✎", slider inline). **430×932** — felt 380×520,
board 50×70, hero cards 80×112; extra height goes to the felt, never to the action bar.

### 4.3 Seat component

Standard seat (6-max): plate 104×58, `ink-800` @ 92 % with a 1 pt `line` ring, radius 14.

```
        ┌──┐┌──┐            ← 30×42 face-down cards, peeking 24 pt above the plate
   ┌────┴──┴┴──┴────────┐
   │ (I) Ivey     [BTN] │   avatar 26 pt circle with initial; ring = archetype colour
   │     100 bb   22/18 │   stack mono 13 gold-light · HUD mono 10 with colour dot
   └────────────────────┘ D ← dealer button 18 pt, plate corner nearest the pot
        ● Raise 3 bb        ← action pill on the pot side (last action this street)
```

- **Avatar**: initial; ring colour = archetype (TAG `#2f6fd0`, LAG `#8a5cd1`, Nit `#2faa66`,
  Station `#d23b3b`). The archetype *name* is never on the plate — the user learns to read the
  HUD; the seat card names it.
- **Name**: Inter 13 semibold, truncated to 8 characters without ellipsis.
- **Position tag**: 10 pt caps pill (UTG/MP/CO/BTN/SB/BB; 9-max adds UTG+1, UTG+2, HJ).
- **Stack**: JetBrains Mono 13, "100 bb" (one decimal only under 10 bb: "7.5 bb").
- **HUD line**: `22/18` (VPIP/PFR) after ≥ 8 observed hands, else `–/–`; ` · 12h` when width
  allows. Tapping the HUD text (hit 44) opens the seat card with the desktop HUD tooltip copy.
- **Last action**: pill on the pot side — Fold (faint; plate dims to 55 %, cards grey and slide
  behind the plate), Check (muted), Call (info blue), Bet/Raise (gold with amount), All-in
  (chip red). Persists for the street.
- **Turn indicator**: 2 pt gold ring; in Auto mode a thin arc sweeps once per think; in Step
  mode the ring pulses slowly and a faint "▶" glyph shows *this* seat moves on "Next action".
- **Winner**: ring turns `good` green, plate lifts 2 pt, pot chips fly in.
- **Tap** (whole plate) → P6 Read range when the player is in the hand and the phase is
  betting (a 12 pt eye glyph in the plate's corner signals it, replacing the desktop's floating
  eye button). Otherwise tap → P7 seat card.
- **Long-press** (450 ms) → P7 seat card always.
- **Compact seat** (9-max): 84×46, avatar 20, name 11, stack 11, no HUD line.
- **Hero seat** has no plate on the felt: the hero strip under the cards carries it (§4.4).

### 4.4 Hero cards, stack and strip

- Hero cards 72×101 (radius 9), always face-up, rank in Bricolage 800 at 26 pt, large suit
  glyph bottom-right. 6 pt gap, centred, overlapping the felt rim by 46 pt — "your" cards are
  anchored to the table edge like the best mobile clients. While it is the hero's turn the
  cards lift 6 pt and gain the gold glow (`--glow-gold`).
- Hero strip (20 pt, y 628–648): left "**BB** · 100 bb" (position pill + mono stack); right, the
  hand label in Bricolage 14: "QQ · Pocket queens" (`cardsToLabel` + a friendly-name table for
  pairs/broadways; else "K♠ 9♠ · suited").
- Facing a bet, the right side becomes the **price line**: "To call 2 bb · need to win 1 in 4"
  (`fmtNeed`). That is layer-1 pot odds, visible before every decision.
- Hero committed chips for the street sit at the hero bet spot on the felt, like any seat.
- All-in hero: the strip reads "ALL-IN" in chip red and the cards keep their glow until showdown.

### 4.5 The ACTION BAR

Three states, always in the same 160 pt region (y 650–810), so the thumb never hunts.

**A. Hero to act**
```
  [−] ────────●───────────── [+]      7.5 bb ✎      ← size row (32): slider · steppers · readout
  [Min]  [ ⅓ ]  [ ½ ]  [ ⅔ ]  [Pot]  [All-in]        ← presets (44 tall, 54 wide, 6 gaps)
  ┌────────────┐ ┌───────────────┐ ┌──────────────┐
  │    Fold    │ │   Call 2 bb   │ │ Raise to 7.5 │   ← 56 tall; widths 28 % / 34 % / 38 %
  └────────────┘ └───────────────┘ └──────────────┘
```
- **Fold**: outlined danger (red text/border on ink-800), left. Appears only when there is a
  bet to call; otherwise the row is **Check** (45 %) + **Bet** (55 %). No fold confirmation, but
  Fold ignores taps for the first 150 ms after the row appears (swallows a tap meant for the
  previous state).
- **Check / Call**: secondary (ink-700). "Check" or "Call 2 bb" (mono amount); "Call all-in 37 bb"
  when a call commits the stack.
- **Bet / Raise**: primary gold. The label is *the exact commit*: "Bet 4.5" or "Raise to 7.5"
  (bb, mono amount); "All-in 100" when the size equals the maximum.
- **Presets**: `Min` (min-raise), `⅓`, `½`, `⅔`, `Pot`, `All-in`. Fractions are of (pot + call)
  added on top of the current bet — the desktop `setFraction`. Selected chip is gold while the
  slider equals it. Default on open: ⅔ (desktop 0.66), clamped to legal bounds. ¾ is a slider
  detent rather than a chip (six chips is the most that fit a 390 width at 44 pt).
- **Slider**: 4 pt track, 28 pt thumb (hit 44), range `[minRaiseTo, maxRaiseTo]`, step 0.5 bb.
  The whole 32 pt row (extended to 44) is the drag target. Detents at Min ⅓ ½ ⅔ ¾ Pot All-in
  give a selection tick. `−`/`+` step 0.5 bb; hold to auto-repeat (every 90 ms after 400 ms).
- **Readout** "7.5 bb ✎": tap → P13 numeric keypad (below). No system keyboard on the table.
- **Press-and-drag on the Raise button** (the "one second" path, taught in the tour): press
  the Raise button and drag *up* — a vertical track (220 pt) rises from the button; the readout
  follows the thumb; presets appear as tick labels along the track. Release **sets** the size
  (button label updates); a plain tap then **commits**. Drag sideways > 30 pt cancels. Press,
  drag, release, tap — all within 60 pt of the thumb's rest position.
- Legal-action gating comes straight from `legalActions(table)`: no `canBet/canRaise` → size
  row and presets hide and the row is Fold / Call (or Check) only.

**P13 — bet keypad (mini, 300 pt tall)**
```
│ ━━━━                                          │
│  Raise to            7.5  bb                  │  live value, mono 28; range under it
│  min 4 · max 100                              │
│  ┌────┐ ┌────┐ ┌────┐                         │
│  │ 1  │ │ 2  │ │ 3  │    keys 116×48          │
│  │ 4  │ │ 5  │ │ 6  │                         │
│  │ 7  │ │ 8  │ │ 9  │                         │
│  │ .  │ │ 0  │ │ ⌫  │                         │
│  └────┘ └────┘ └────┘                         │
│  ┌──────────────────────────────────────────┐ │
│  │              Done · Raise to 7.5         │ │  clamps to the legal range on Done
│  └──────────────────────────────────────────┘ │
```

**B. Bot to act**
```
  Step (manual):                                   Auto:
  [✎ Explain]  ┌────────────────────────────┐      [✎ Explain]  ┌───────────────────────────┐
               │        Next action  ›      │                   │ Ivey is thinking… ▂▃▅  ‖  │
               └────────────────────────────┘                   └───────────────────────────┘
```
- Step: "Next action ›" (secondary, 56 pt, 70 % width) steps one bot. **Tapping the felt**
  (anywhere on the canvas that is not a seat, board or pot) also steps — the most reachable
  control on the screen. A hint "Tap the table to step" fades over the felt the first 3 times.
- Auto: the slot reads "Ivey is thinking…" with a tiny equaliser and a **Pause** (‖, 44×56) at
  its right. Tapping the felt in Auto pauses/resumes; paused label: "Paused · tap to resume ▶".
- "✎ Explain" (ghost, 44×56, left) = *Explain last move*; enabled when `lastActorSeat` is a bot.
- Size row and presets are hidden; the hero strip stays.

**C. Hand over**
```
  [✎ Explain]  ┌────────────────────────────┐
               │        Next hand  ›     ◔  │      ← Auto: a 3 s countdown ring at the right
               └────────────────────────────┘
```
- Step: waits for the tap. Auto: auto-deals after 3 s unless the user touches the results
  card (touch = hold; ring stops; "Next hand" becomes explicit). Setting "Auto-deal next hand".

### 4.6 Manual "step" vs auto-play on mobile

- **Control location**: top-bar pill "▶ Step ▾" / "▶▶ Auto ▾". Tap toggles Step ↔ Auto
  (instant, haptic). Long-press or the ▾ opens **P14**:

```
│ ━━━━                                          │
│  Pace              [ Step ]  [ Auto ]         │  segmented 36 (hit 44)
│  Step through each player's action yourself.  │  desktop helper copy per mode
│  Speed             [Slow] [Normal ✓] [Fast]   │  1100 / 700 / 360 ms (Auto only)
│  Tap the table to step                  [on ●]│
│  Auto-deal next hand                    [on ●]│
```
  Default: Step, Normal — the desktop defaults.
- **A hand in progress (Step)**: a quiet table; the turn ring pulses on the seat that will act;
  the ticker shows the last line; the action slot invites "Next action". Each tap animates
  exactly one action (≤ 400 ms) and returns control. The hero's own turn is unmistakable: cards
  lift and glow, the action buttons slide up 8 pt into place, a light haptic fires.
- **Auto**: bots act on the chosen cadence with the think-arc sweeping on the active seat; the
  user is only interrupted at their own turn. A blocking coach note stops the loop (desktop
  `paused`), the sheet rises, and "Got it" restarts it — identical to `dismissReview →
  maybeAutoLoop`.
- Opening Read range pauses Auto exactly as `openGuess` sets `paused: true`; closing resumes.
- App backgrounded mid-hand: Auto flips to paused; state is persisted after every action.

### 4.7 Bot action animation and timing

Per bot action at Normal speed (700 ms cadence):
1. 0–150 ms: think — the arc sweeps on the seat (Auto only; zero in Step).
2. 150–400 ms: the action pill pops (scale 0.8→1, 200 ms, emphasized-decelerate); for bets and
   calls a chip stack (three layered 14 pt discs) slides plate → bet spot (250 ms) while the
   stack number counts down (120 ms).
3. 400–450 ms: the turn ring hops to the next seat.
4. Fold: cards slide 20 pt down behind the plate and fade to 30 % (220 ms); plate dims.
5. Street change: bet-spot chips glide to the pot (280 ms, 30 ms stagger per seat), the pot
   number ticks up, then the new board cards deal in (§11).

Fast (360 ms) shortens every phase proportionally; Slow (1100 ms) lengthens only the think
phase. In Step mode the whole action completes in ≤ 400 ms so rapid tapping feels responsive;
a tap during an animation is queued, never dropped.

### 4.8 The EV coach on mobile

**Non-blocking notes → the coach chip.** When `evaluateHero` resolves (it runs after the
action is applied), a chip drops from beneath the ticker, centred over the top rim of the felt
(y 95–143, 320×48, `ink-800` @ 95 %):

```
        ┌──────────────────────────────────────┐
        │ ✓  Nice play · Your call        ›    │   verdict icon on a coloured disc · title · chevron
        └──────────────────────────────────────┘
```
- Verdicts from `META`: **Mistake** (bad red, ✕) · **Thin spot** (warn amber, i) · **Reasonable**
  (info blue, ✓) · **Nice play** (good green, ✓) · **Read** (info blue, eye).
- Visible 4 s, then shrinks (200 ms) into the top-bar **Coach badge** "✎ Coach ●3": dot =
  latest verdict colour, count = notes this hand.
- Tap the chip → P3 at the 45 % detent; swipe up → 92 %.
- Haptics: great/ok = light; thin = medium; non-blocking mistake = notification-warning.
- A verdict that arrives after the hand ended (`handNumber` changed) is *not* shown as a chip
  (desktop rule) but is recorded and reachable from Stats.

**Blocking mistakes → the pause sheet.** `review.blocking` (a −EV call beyond the strictness
threshold, outside the noise band): the loop pauses, the felt dims to 60 %, a warning haptic
fires, and P3 opens at the 62 % detent **without a grabber**. System back gives a subtle shake.
The only way on is "Got it" — desktop `dismissReview`. The sheet header repeats the situation
(hero cards XS + board XS + "you called 2 bb into 4.5 bb") because the felt behind is dimmed.

**P3 — the coach note sheet, three visible layers**
```
┌──────────────────────────────────────────────┐
│ ━━━━                                          │  grabber (absent when blocking)
│ ┌────┐  ✕ Mistake                            │  header tinted verdict colour @ 12 %
│ │ ✕  │  EV Coach · Your call                 │
│ └────┘  [Q♠][Q♥]  on  [7♦][2♣][9♠]           │  XS cards for context
├──────────────────────────────────────────────┤
│ You paid 8 bb to win a pot of 24 bb — you    │  LAYER 1 · Inter 17 / 1.45 · always open
│ need to win about 1 time in 4. Your hand     │
│ wins about 1 time in 5 — not enough. Over    │
│ time this call loses money; folding is       │
│ better.                                      │
│                                              │
│ Win chance vs Ivey                      21 % │  equity bar 10 pt, verdict colour,
│ ▓▓▓▓▓▓▓░░░░│░░░░░░░░░░░░░░░░░░░░░░░░░░       │  white marker = needed % (pot odds)
│ White line = 33 % needed (pot odds ⓘ)        │  ⓘ → S2 glossary mini "pot odds"
│                                              │
│ ⚠ Multiway pot (3 opponents). With more…     │  only when review.multiway
│                                              │
│ ▸ Show me the math                           │  LAYER 2 · disclosure row 48 pt, gold
│ ▸ Expert detail                              │  LAYER 3 · disclosure row 48 pt, muted
│                                              │
│ Expected value                      −1.6 bb  │  EV tile (mono; red / green / muted)
│                                              │
│ ┌──────────────────┐ ┌──────────────────────┐│
│ │  👁 View range   │ │       Got it         ││  56; "Close" (ghost) when non-blocking
│ └──────────────────┘ └──────────────────────┘│
└──────────────────────────────────────────────┘
```
- Layer 2 expands inline to the numbered `steps` (15 pt, left rule in `line`). Layer 3 expands
  to a bulleted list: the `text` summary first (desktop order), then `expert[]`.
- Expanded state is **not** remembered between notes (plain first, always). Settings offers
  "Always expand 'Show me the math'" for graduates.
- "View range" pushes P5 inside the sheet: 300 pt read-only matrix, title "Ivey's assumed
  range", the desktop description as subtitle, footer "≈ 312 combos · 23 % of all hands", back
  chevron returns to the note.
- Bot-read notes (`kind: "bot"`, verdict `info`) use the same sheet: eye icon, title "Ivey's
  raise", `interpretBot` sentence as layer 1, no equity bar, "View range".

**Reopening past notes (P4).** Top-bar "✎ Coach ●3" → a list of this hand's notes, newest
first, 64 pt rows: `[badge] Your call · Mistake · "You paid 8 bb to win…"`. Tap → P3 read-only
(no pause). Notes reset on the next deal (desktop `reviewLog: []`), the badge returns to
"✎ Coach". Every decision remains in Stats → Coaching review.

**Coach off.** P15 has the "EV Coach" toggle. Off: badge reads "✎ Coach off" (muted), no chips,
nothing recorded (desktop `coachEnabled` short-circuits before `evaluateHero`).

### 4.9 Guess Range → Peek (P6) on a phone

Entry: tap an opponent seat during betting. The hand pauses (`openGuess`). Full-screen modal:

```
┌──────────────────────────────────────────────┐
│ ✕                Read Ivey's range      About│ 44   close · title · About → P7
│ BTN · Tight-Aggressive (TAG) · Flop          │ 20   desktop subtitle
│ Optionally paint your guess, or just peek.   │ 18
├──────────────────────────────────────────────┤
│ AA  AKs AQs AJs ATs A9s A8s A7s A6s A5s A4s… │      13×13 matrix, 366 pt square:
│ AKo KK  KQs KJs …                            │      cell 27, gap 1, radius 3
│ AQo KQo QQ  …                                │      label 9.5 semibold (mono digits)
│ …                       ╭───────╮            │      pairs diagonal, suited above,
│                         │ loupe │ ← 72 pt    │      offsuit below (standard orientation)
│                         ╰───┬───╯            │
│              (366 × 366)    ● finger         │
│                                              │
│                                              │
├──────────────────────────────────────────────┤
│ ■ Pairs ■ Suited ■ Offsuit   38 combos · 2.9 % │ 24  legend + live combo counter
│ [Top 10%] [15%] [20%] [30%] [45%]  [↶ Undo]   │ 44  presets (scrolling row) · Undo
│ ┌────────────────────┐ ┌────────────────────┐│
│ │       Clear        │ │    Peek & score    ││ 56  "Peek" when nothing is painted
│ └────────────────────┘ └────────────────────┘│
└──────────────────────────────────────────────┘
```

Painting with a finger — a 27 pt cell is below 44, so precision comes from three things:
1. **Drag-paint**: the first cell touched decides the mode (add if it was off, remove if on —
   the desktop `addModeRef`); every cell the finger crosses gets that mode. Cell fills animate
   80 ms. A selection tick fires per flipped cell (min 40 ms apart).
2. **Loupe**: while the finger is down, a 72 pt magnified bubble floats 56 pt above the
   fingertip showing the 3×3 neighbourhood with the cell under the finger outlined in gold —
   the finger can occlude the grid and the user still sees exactly what they paint.
3. **Tap = toggle one cell**: a touch that moves < 4 pt within 200 ms is a tap, not a drag.

Also: **pinch to zoom** 1×–2.5× (one finger still paints; two fingers pan); double-tap resets.
This is the large-finger / AX-text path. Colours: painted cells use the kind colour (pair
`combo-pair`, suited `combo-suited`, offsuit `combo-offsuit`) with white labels; unpainted
`ink-700` with faint labels. **Undo** (last stroke, 20 deep) and **Clear**. **Presets** from
`topPercentRange` (10/15/20/30/45 %) replace the painting (undo restores). The counter reads
"38 combos · 2.9 % of hands".

**Peek** (`peek(painted)`):
- With a painting, the grid switches to **compare** colouring (green = correct, amber = missed,
  red = extra — the desktop legend; hatching on missed and dots on extra when the OS
  "differentiate without colour" flag is on) and the score card rises from the bottom:

```
├──────────────────────────────────────────────┤
│ ■ Correct ■ Missed ■ Extra   Their range: 312 combos │
│ ┌──────────────────────────────────────────┐ │
│ │   64 %           Coverage   71 %         │ │  accuracy Bricolage 40 + grade label
│ │   SOLID          Precision  58 %         │ │  Sharp read ≥ 80 · Solid ≥ 60 · Rough ≥ 40 · Way off
│ │ You caught 71 % of the hands they play   │ │  plain-English restatement of recall / precision
│ │ here; 58 % of what you painted was right.│ │
│ │ Everyone's exact cards are revealed when │ │
│ │ the hand ends.                           │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │                 Continue                 │ │  56 → closeGuess (resumes Auto)
│ └──────────────────────────────────────────┘ │
```
- Without a painting: the grid highlights the actual range read-only and the card reads
  "Here's Ivey's assumed range. Paint a guess first next time for an accuracy score."
- Recorded (`recordGuess`) only when painted — desktop rule. Hole cards are not shown here; at
  hand end the results card marks the read seat with "Your read: 64 %" and tapping it reopens
  the compare grid with the cell of their actual hand ringed in gold.

### 4.10 Explain last move

"✎ Explain" (ghost button in the bot-to-act and hand-over bars; also "Explain their last move"
in P7) calls `explainLastBotMove`: an info-verdict chip ("👁 Ivey's raise ›") drops in and
opens P3 with the `interpretBot` line as layer 1 and "View range" for the range the bot used
(`botRanges[seat]`). Disabled at 40 % when the last actor was the hero.

### 4.11 Hand log

- The **ticker** under the top bar shows the latest log entry (12 pt; results in gold-light,
  deals in info blue, actions muted, info faint — the desktop colour code). Tap → P2 at 92 % on
  its "Hand log" segment: reverse-chronological, grouped by street, coach notes interleaved as
  badge rows (tap → P3). Entries are the engine's `log` (`deal` / `action` / `result` / `info`).
- Long-press the ticker → copies the hand's log text (toast "Hand log copied").

### 4.12 Hand-over reveal, results overlay (P8), next hand

At `phase === "hand-over"`:
1. Showdown cards flip face-up in their seats (two 150 ms half-flips, clockwise from the
   button, 60 ms stagger). With Realistic reveals on, folded seats stay face-down.
2. Pot chips glide to the winner's plate (420 ms); the ring turns green; the stack counts up.
   Hero win → success haptic.
3. The **results card** slides up over the lower felt (y 372–560), leaving the board, the top
   seats and the hero cards visible:

```
│      │    ▭    ▭    ▭    ▭    ▭        │        │  board stays visible
│ ┌──────────────────────────────────────────┐ │
│ │  +12.5 bb           Ivey wins with two   │ │  net (Bricolage 24, good/bad colour) ·
│ │  YOU WON THE POT    pair.                │ │  winner line (desktop copy)
│ ├──────────────────────────────────────────┤ │
│ │ [K♦][7♣] Polk  Folded on the flop — the   │ │  reveal rows: XS cards 22×31 + the one-line
│ │          full board would have given them │ │  revealNote(); folded rows greyed
│ │          a pair of kings.                 │ │
│ │ [A♠][4♠] Selbst Folded before the flop —  │ │
│ │          playable, but gave it up.        │ │  3 rows visible, scrolls; 9-max shows
│ │ [9♥][9♦] Ivey   Won with two pair. · Your read 64 % │  "All 8 hands ›" → P9
│ └──────────────────────────────────────────┘ │
│                 ┌─────┐┌─────┐                 │  hero cards remain
│  [✎ Explain]    │       Next hand  ›   ◔    │  │  action bar state C
```
- Tapping a reveal row opens that seat's P7 with "Read their range" disabled and an inline
  read-only matrix of the range they were assigned for their last street.
- "Next hand ›" → `deal()`; Auto's 3 s ring auto-deals unless the card is touched.
- Bust: hero stack 0 → the bar reads "Session over" and P10 opens (desktop `deal` →
  `sessionEnded`).

### 4.13 Session stats access (P2)

Top-left pill "12h · +4.5 bb ▾" → P2 at 45 %:
```
│ ━━━━                                          │
│ [ This session ]  [ Hand log ]               │  segmented
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌───────────────┐ │
│ │Hands │ │ Net  │ │bb/100│ │ Read accuracy │ │  stat tiles (mono, good/bad tone)
│ │  12  │ │+4.5  │ │ +37  │ │     64 %      │ │
│ └──────┘ └──────┘ └──────┘ └───────────────┘ │
│ Your style  22 / 15 · 12h                ⓘ  │  hero VPIP/PFR after 8 hands; ⓘ → T1
│ ┌──────────────────────────────────────────┐ │
│ │ Hands this session (12)                  │ │
│ │ #12  +3.0 bb            ▶ Replay   ✎     │ │  rows 52 pt
│ │ #11  −0.5 bb            ▶ Replay   ✎     │ │
│ └──────────────────────────────────────────┘ │
│              [ End session ]                 │  danger-ghost, 44
```
"bb/100" and "Your style" are tappable → T1 explainer minis with the desktop tooltip copy.

### 4.14 End session + summary (P10)

Full-screen modal, decisions before money (desktop order):
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
│ │ Net +4.5 bb│ │ bb/100 +37 │                │  2×2 tiles: Net · bb/100 ·
│ │ Best +12.5 │ │ Worst −8.0 │                │  Biggest win · Biggest loss
│ └────────────┘ └────────────┘                │
│ 3 hands reached showdown. Replay any hand    │
│ below, or export the full history.           │
│ ┌──────────────────────────────────────────┐ │
│ │ REVIEW HANDS                             │ │
│ │ #12  +3.0 bb              ✎   ▶ Replay   │ │
│ └──────────────────────────────────────────┘ │
│ [ Copy ]  [ Share hands (.txt) ]             │  system share sheet
│ ┌──────────────────────────────────────────┐ │
│ │               New session                │ │  primary
│ └──────────────────────────────────────────┘ │
│                  Done                        │  ghost → lobby
```
Busted sessions hide ✕ and "Done" (desktop `hideClose={heroBusted}`); title "Session over —
you busted"; "New session" is the exit.

### 4.15 Table setup and the empty state

Setup is the lobby play card (§3): there is no separate setup modal — the lobby *is* the empty
state. If `/table` opens with no session (deep link, resume after reset) it renders an empty
felt with seat silhouettes and one centred card: "Ready to play? A session deals hand after
hand against a fixed table of bots. Your stack carries over, so wins and losses stick until
you end the session. [Deal me in]" with the seat/ante chips beneath (desktop `PlayView` copy).

**P15 — table options** (top-bar ⋯, mini): EV Coach toggle · Four-colour deck · Realistic
reveals · "Leave table" · "End session". Seats and antes cannot change mid-session (row reads
"Ends this session first").

### 4.16 Seat card (P7)

```
│ ━━━━                                          │
│ (I) Ivey                 BTN · 100 bb · 22/18 │
│ Tight-Aggressive (TAG)                        │  archetype name + colour dot
│ Plays few hands and plays them hard…          │  archetype blurb (desktop tooltip)
│ Observed over 14 hands this session — VPIP =  │  HUD explanation (desktop copy; the
│ how often they put money in pre-flop, PFR =   │  "stats appear after 8 hands" variant
│ how often they raise…                         │  before the sample is reached)
│ [ 👁 Read their range ]  [ ✎ Explain last move ]│  44 pt; disabled states per §14
```

---
