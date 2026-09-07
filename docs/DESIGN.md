# All-In · Poker Dojo — Mobile design specification (single source of truth)

Status: **FINAL**. Supersedes `docs/design/proposal-{native,table,habit}.md`. Engineers build from
this file; the proposals are history. Where this file is silent, `docs/port/*.md` (desktop
behaviour) and `docs/TONE.md` (coach voice) apply. Where this file and a port doc disagree, this
file wins and the deviation is listed in §15.

Target: Flutter, iOS + Android phones, portrait only. Design canvas **390×844 pt** (iPhone 15/16
class: status/Dynamic Island inset **59**, home indicator inset **34**). Must also hold at
**360×780** (compact Android: status 32, gesture inset 24) and stretch to **430×932**. Dark
theme is primary; light theme has full parity. Brand: green felt + gold. Fonts: Bricolage
Grotesque (display: headings, card ranks, big numbers), Inter (body), JetBrains Mono (every number
that changes; tabular figures). Tokens: `lib/theme/tokens.dart` (`AllInColors`, `AllInRadius`,
`AllInSpace`), `typography.dart` (`AllInText.display/body/mono/eyebrow`), `motion.dart`
(`AllInMotion`). All sizes below are pt. **Every tappable target is ≥ 44×44 pt** (visual size may
be smaller; hit-slop makes up the difference) except the two paint surfaces called out in §4.9
and §6.5, which are handled by drag-paint, loupe and header selectors.

Copy in double quotes is exact. Copy marked *(desktop)* is verbatim from the desktop app and must
not be paraphrased (TONE.md). Copy marked *(new)* is new to mobile.

Contents: 1 Principles · 2 Information architecture · 3 Home · 4 Play · 5 Drills · 6 Study ·
7 Stats · 8 Onboarding · 9 Settings + About · 10 Component library · 11 Motion + haptics ·
12 Gestures + reachability · 13 Accessibility · 14 Edge / empty / error states · 15 Feature
disposition table · 16 Implementation notes for engineers.

---

## 1. Design principles

1. **The next decision is always under the thumb.** Fold / Check-Call / Raise, "Next action",
   "Next hand", "Got it", drill answers and "Next puzzle" live in the bottom 160 pt of the screen,
   in the same slots every time. Anything pressed every few seconds is ≥ 56 pt tall. Nothing used
   more than once a minute lives above the screen's midline. The action row never moves: Fold is
   always leftmost, the aggressive action always rightmost.

2. **The table is the classroom; everything else is a layer on it.** The table is a full-screen
   route with no tab bar. Coach notes, player reads, the hand log, session stats and pace arrive
   as bottom sheets that never cover the action row (max detent leaves the bottom 120 pt clear —
   §2.4). Drills follow the same rule: the spot stays visible under the feedback panel. Results
   render in place on the lower felt so the board and the hero's cards never disappear.

3. **Three layers, always visible as three layers.** Every coach note, drill rationale, peek
   note, session debrief and stat explanation renders as: plain-English paragraph (always open) →
   "Show me the math" disclosure row → "Expert detail" disclosure row. The two rows are always
   present, even when there is nothing behind them ("No math for a read — this is an
   interpretation of their style"), so the structure teaches itself. Layer 1 uses counts ("about 1
   time in 4"), never percentages (`fmtTimes` / `fmtNeed`).

4. **Interrupt only for money.** Non-blocking verdicts are a chip that folds itself into a badge;
   only a blocking mistake stops the hand and demands "Got it". No toasts for praise, no confetti,
   no streak nagging, no push notifications, no red dots for missed days. The app judges the
   decision, never the person, and never comments on time spent.

5. **Reads are earned, not given.** HUD numbers appear after 8 observed hands; the archetype name
   is never on the plate; Guess Range always offers painting before peeking; hole cards are
   revealed only at hand end.

6. **Touch replaces hover, never removes it.** Every desktop hover (HUD tooltip, glossary term,
   stat hint, eye-to-guess, chart tooltip) has a ≥ 44 pt tap target (player sheet, term popover,
   explainer sheet, seat eye, chart scrub). Long-press is only ever a shortcut for something that
   also has a visible tap path.

7. **Five minutes, well spent.** Home is a plan, not a menu: one primary suggestion with a time
   estimate, built from live state. Every loop has a natural stopping point one tap away and
   "keep going" one tap away; nothing is forced to stop.

8. **Verdicts and results never share a colour scale in the same row.** EV verdicts use the
   verdict palette (bad/warn/info/good); money uses signed mono numbers in good/bad. The debrief
   leads with "How you played (before how it paid)".

9. **Platform-honest, brand-consistent.** Material 3 `NavigationBar`, modal bottom sheets and
   predictive back on Android; Cupertino tab bar sizing, sheet grabbers, edge-swipe back and the
   iOS haptic vocabulary on iOS. The felt, cards, matrix, coach note, typography and colours are
   identical on both. What is shared vs platform-specific is listed in §16.6.

---

## 2. Information architecture

### 2.1 Root tabs (bottom navigation, 5 items)

| Tab | Icon | Root screen | Notes |
|---|---|---|---|
| Home | `sun`/chip | **Today** (§3) | The plan. Gear (top-right) → Settings. |
| Play | `cards` | **Lobby** (§4.1) | Table setup + resume. If a session is live, the tab opens the **Table** route directly (lobby skipped). |
| Drills | `target` | **Drills** (§5) | Mode chips + current spot. Tab badge = Review due count. |
| Study | `book` | **Study** (§6) | Continue card, 5 levels / 31 lessons, Tools, Quick reference. |
| Stats | `stats` | **Progress** (§7) | KPIs, charts, coaching review, hands, heatmap. Gear → Settings. |

Tab bar: Material 3 `NavigationBar` (80 pt incl. labels) on Android; 49 pt + 34 home-indicator on
iOS. Active = gold icon + label; inactive = `textMuted`. Labels always visible. Re-tapping the
active tab scrolls its root to top. The bar is hidden on: Table, Guess Range, Range editor, Hand
replayer, Session summary, Placement test, Onboarding, Lesson reader (reader hides it to gain
height; back restores it).

**Session-in-progress pill** (§10.2 `SessionPill`): 56 pt, sits 8 pt above the tab bar on every
tab while a session exists and the user is off-table: `● 12 hands · +4.5 bb      Resume ›`.
Tap → Table. Swipe left → "End session" (→ Session summary). A session can never be lost.

### 2.2 Screen inventory (stable IDs; use these names in tickets and route names)

| ID | Screen | Type | Opened from |
|---|---|---|---|
| H0 | Today | tab root | tab |
| H1 | Coach's note detail | sheet M | H0 coach card "Show me why ›" |
| H2 | Goal explainer | sheet S | H0 goal ring, D0 Today stat |
| P0 | Play lobby (setup / resume / recent sessions / empty) | tab root | tab |
| P1 | Table | full-screen modal route | P0 "Deal me in", Resume pill, H0 plan card |
| P2 | Session sheet (Log · Session · Options) | sheet M/L | P1 title tap, ticker tap, hero-strip swipe-up |
| P3 | Coach note | sheet M→L (blocking: M, no grabber, no scrim dismiss) | auto, coach chip, P4 row, H0 card (read-only) |
| P4 | Coach notes list (this hand) | sheet M | P1 top-bar Coach badge |
| P5 | Assumed range viewer (read-only 13×13) | push inside P3 | P3 "View range" |
| P6 | Player sheet (archetype, HUD explained, actions) | sheet S/M | P1 plate tap, P8 reveal row |
| P7 | Read range: Guess → Peek | full-screen modal | P1 seat eye, plate long-press, P6 "Read their range" |
| P8 | Results overlay | in-place overlay on the lower felt | auto at hand-over |
| P9 | All reveals (9-max overflow) | sheet L | P8 "All 8 hands ›" |
| P10 | Session summary | full-screen modal | P2 "End session", bust, Resume pill swipe |
| P11 | Hand replayer | push (tab bar hidden) | P10 row, T2 row, T0 recent hand, P2 Log hand row |
| P12 | Hand note editor | sheet M (keyboard-aware) | P10, P11, T0/T2 note button |
| P13 | Bet keypad | sheet S (auto-height) | P1 Raise label long-press / amount tap |
| P14 | Leave table? | dialog | only when leaving mid-hand with an unsaved snapshot failure (§4.14) |
| D0 | Drills (mode chips + spot) | tab root | tab, H0 plan cards |
| D1 | Feedback panel | bottom panel, 2 detents, never scrim-dismissed | after answering |
| D2 | Frame list | sheet M | long-press the scrubber pill |
| D3 | Stat explainer (Rating / Today / Accuracy) | sheet S | D0 stats strip |
| D4 | Mode blurb | sheet S | D0 chip long-press, D0 ⓘ |
| D5 | Placement test | full-screen modal | Onboarding, Settings "Run again" |
| S0 | Study | tab root | tab |
| S1 | Lesson reader | push (tab bar hidden) | S0 row, D1 lesson button (as modal over Drills), H0 continue card, placement result |
| S2 | Term popover | anchored popover | any dotted term |
| S3 | Tool screens: Range explorer · Equity calculator · Pot-odds calculator · Bluff calculator · Multiway trainer · Hand rankings | push | S0 Tools row, lesson "Open full screen" |
| S4 | Quick reference + Glossary (searchable) | push | S0 pinned row, S2 "Open glossary" |
| S5 | Card keypad | sheet M | S3 equity calculator slots |
| S6 | Range editor (paint a range full-screen) | full-screen modal | S3 equity calculator "Edit" |
| T0 | Progress | tab root | tab |
| T1 | Stat explainer | sheet S | any ⓘ tile / dotted label |
| T2 | All hands (filter by tag / source) | push | T0 "All hands ›" |
| T3 | Import hands (picker → progress → result) | system picker + sheet M | T0/T2 "Import", X0 Data |
| T4 | Chart value | sheet S | scrub on the cumulative chart |
| X0 | Settings | push | gear on H0 / T0 |
| X1 | About | push | X0 row |
| X2 | Reset all progress | dialog with typed confirmation | X0 Data |
| X3 | Restore backup? | dialog | X0 Data after picking a `.json` |
| O0 | Onboarding tour (4 pages) → placement intro | full-screen modal | first run, X0 "Run again" |
| O1 | First-table coach marks (3 captions) | overlay captions on P1 | first three hands ever |

### 2.3 Navigation graph

```
TabScaffold (StatefulShellRoute)
├─ Home / Today (H0) ─────────┬─ push  Settings (X0) ── push About (X1)
│                             ├─ modal TABLE (P1)                (Resume / Play 20 hands)
│                             ├─ tab-jump Drills (D0, mode=leaks | mixed …)
│                             ├─ tab-jump Study → push Lesson (S1)
│                             ├─ push  Session summary (P10, read-only, last session)
│                             └─ sheet Coach's note (H1) · sheet Goal explainer (H2)
├─ Play / Lobby (P0) ─────────┬─ modal TABLE (P1)  [tab bar hidden]
│                             │    ├─ sheet  Session (P2: Log · Session · Options)
│                             │    ├─ sheet  Coach note (P3) ── in-sheet push Assumed range (P5)
│                             │    ├─ sheet  Coach notes list (P4) ── P3
│                             │    ├─ sheet  Player (P6)
│                             │    ├─ modal  READ RANGE (P7: paint → peek, same route)
│                             │    ├─ overlay Results (P8) ── sheet All reveals (P9) · sheet Player (P6)
│                             │    ├─ sheet  Bet keypad (P13)
│                             │    ├─ sheet  Explainer (T1) for any ⓘ
│                             │    └─ modal  SESSION SUMMARY (P10) ── push Replayer (P11) ── sheet Note (P12) · system Share
│                             └─ push  Session summary (P10) of a past session (read-only)
├─ Drills (D0) ───────────────┬─ panel Feedback (D1) ── modal Lesson reader (S1, "Done" returns)
│                             ├─ sheet Frame list (D2) · sheet Explainer (D3) · sheet Mode blurb (D4)
│                             └─ modal PLACEMENT (D5)
├─ Study (S0) ────────────────┬─ push Lesson reader (S1) ── popover Term (S2) ── push Glossary (S4)
│                             │                            ── sheet Card keypad (S5) ── modal RANGE EDITOR (S6)
│                             ├─ push Tools (S3 ×6)
│                             └─ push Quick reference / Glossary (S4)
└─ Stats (T0) ────────────────┬─ sheet Explainer (T1) · sheet Chart value (T4)
                              ├─ push Replayer (P11) ── sheet Note (P12)
                              ├─ push All hands (T2) ── P11 / P12 / Import (T3)
                              ├─ system File picker → sheet Import result (T3)
                              └─ push Settings (X0) ── dialog Reset (X2) · dialog Restore (X3) · system Share
Onboarding (O0 → D5), first run only, full-screen modal over everything.
```

### 2.4 Presentation types — the rule for choosing

| Type | Behaviour | Use when |
|---|---|---|
| **Tab root** | Tab bar visible, scrolls | Browsing / choosing |
| **Push** | Slides from the right; back chevron, system back, iOS edge-swipe, Android predictive back | Reading one item (lesson, replayer, settings, hands list, tools) |
| **Sheet** | Bottom sheet, grabber, scrim 40 %; detents **S** (auto-height ≤ 40 %), **M** (55 %), **L** (92 %); swipe-down / scrim tap / system back closes | Context stays useful underneath (coach note over the table, definitions, keypads, session stats). **On the Table route the L detent is capped so the bottom 120 pt (context row + action row + inset) stay visible and interactive.** |
| **Full-screen modal** | Covers the tab bar; explicit ✕ / Done / Leave; system back = the screen's stated back action | Anything with a live state machine or that needs the full width: the table, Read range, Range editor, Session summary, Placement, Onboarding |
| **Panel** | Like a sheet but cannot be dismissed by scrim or swipe; only its own primary button advances | Drill feedback (the verdict never vanishes) |
| **Overlay** | In place on the felt; automatic or tap | Results card, coach chip, hints, coach marks |
| **Popover** | Anchored card ≤ 280×180; tap outside closes | One-line definitions (glossary term) |
| **Dialog** | Adaptive alert (Cupertino / M3) | Destructive or irreversible: erase data, restore backup, start a new session over a paused one |
| **Toast** | 44 pt pill at the top of the content area, 2.5 s | Confirmations only ("Hand history copied") |

Rules: a sheet never opens another sheet on top — it pushes inside itself (coach note → range
viewer) or replaces itself (notes list → note). A sheet opened from a full-screen modal belongs
to that modal. Everything is offline; there are no loading screens, only computation shimmers.

### 2.5 System back / back gesture mapping (exhaustive)

| Where | System back does |
|---|---|
| Any sheet / popover / toast | Closes it (blocking coach sheet: equals "Got it" — it is the acknowledgement) |
| Table (P1) | Leaves the table **without a dialog**; the session is persisted after every action (§4.14) and paused; a toast "Session paused — resume from Home or Play" *(new)*. The table is a **modal route, not a push**, so the iOS left-edge swipe cannot fire while a thumb reaches for Fold. |
| Read range (P7) before Peek | Closes without scoring; a painted guess asks nothing (desktop parity: closing = `closeGuess`). |
| Read range (P7) after Peek | Equals "Continue". |
| Results overlay (P8) | Not dismissable by back (it is felt state); back leaves the table as above. |
| Session summary (P10) | Equals ✕ (returns to the table; session continues). Busted: back does nothing (only "New session" continues — a subtle shake). |
| Drill feedback panel (D1) | Collapses to the compact detent; never dismisses the verdict. |
| Drills root with an unanswered spot | Normal tab behaviour (nothing is lost). |
| Lesson reader from a drill | Returns to the same answered spot with the panel still up. |
| Range editor (S6) | Equals "Done" (keeps edits). |
| Placement (D5) / Onboarding (O0) | Previous page; on the first page it does nothing (a subtle shake); ✕ is the only exit. |
| Replayer (P11) | Pops to where it came from. |
| Reset dialog (X2) | Cancel. |

### 2.6 Internal deep links (go_router paths, §16.1)

`/study/lesson/:id` (drill feedback, placement result, coach's note), `/drills?mode=leaks`
(Home review card, Stats coaching review), `/stats/hand/:startedAt` (summary rows), `/settings/data`
(import result). No external URL scheme in v1.

---

## 3. HOME — "Today"

Purpose: answer "what should I do in the next five minutes?" with one primary suggestion and at
most three alternates, show the daily goal as something being filled, and let the coach say one
useful sentence. Home never shows table options (that is the Play lobby's job); its play card
launches with the saved options.

### 3.1 Wireframe (390×844)

```
┌──────────────────────────────────────────┐ 0–59 safe
│ Good evening                        [⚙]  │ 59–103  title (Bricolage 28) · gear 44×44
│ Wednesday · 4 days in a row              │ 103–123 Inter 13 muted; streak part hidden at 0
│ ┌──────────────────────────────────────┐ │
│ │ Today                                │ │ Goal card 84: label · bar 8 pt gold ·
│ │ ████████████░░░░░░░░░░░░   8 of 20   │ │ mono 15 count · caption 13 muted
│ │ drills · or 30 hands — either counts │ │ tap → H2 explainer
│ └──────────────────────────────────────┘ │
│ NEXT UP                                  │ eyebrow
│ ┌──────────────────────────────────────┐ │
│ │ ◔ Clear your review           ~2 min │ │ PRIMARY plan card 96: gold 1.5 pt border
│ │ 5 spots due · 2 are coach-flagged    │ │ whole card tappable +
│ │ calls              [ Start review ]  │ │ explicit 44 pt button for first-day users
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ ▶ Resume your table           ~6 min │ │ plan card 72
│ │ 12 hands, +4.5 bb · Coach on         │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ ▤ Continue: Pot Odds, Break-even & EV│ │ plan card 72
│ │ Level 3 · 6 min read · 7/31 done     │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ ◎ A set of 10 mixed spots     ~4 min │ │ plan card 72
│ │ Rating 1,082 · 71 % accuracy         │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ (C) Coach                            │ │ Coach card ≥ 96
│ │ "You fold too often when you're      │ │ verbatim leak line
│ │  getting the right price — look for  │ │
│ │  more +EV calls."     Show me why ›  │ │ → H1 (three layers)
│ └──────────────────────────────────────┘ │
│ LAST SESSION                             │
│ ┌──────────────────────────────────────┐ │
│ │ +12.5 bb · 41 hands · 2 mistakes   › │ │ 64 → P10 read-only
│ │ Costliest: a river call (−3.1 bb)    │ │
│ └──────────────────────────────────────┘ │
│ PRACTICE  ▢▢▢▣▣ ▣▢▢▣▣ ▣▣▣▢▣ ▣▣■■■  5 wk │ mini heatmap (5 weeks × 7, 12 pt cells) → Stats
│ ┌────┬────┬────┬────┬────┐               │ tab bar (Session pill above it when off-table)
└──────────────────────────────────────────┘
```

Card anatomy (`PlanCard`, §10.4): 16 pt padding, radius `AllInRadius.lg`, icon 20 pt in a 32 pt
gold-tinted square, title Inter 17 semibold, subtitle Inter 14 muted, time estimate mono 13
right-aligned. The primary card carries a 44 pt gold button; every other card is tappable as a
whole (whole card = one 72 pt target). At 360×780 the screen scrolls; the primary card is always
above the fold (goal card 84 + primary 96 end at y ≈ 340).

### 3.2 Plan logic (deterministic; at most four cards; the first is styled primary)

Built from live state in this priority order:

1. **Review due** — if `dueCount > 0` (due leak spots + due missed drills, §5.5). Estimate = 20 s
   per due spot rounded up to the minute (`"~2 min"`). Subtitle: `"{n} spots due"` + `" · {k} are
   coach-flagged calls"` when `k > 0` (k = due leak spots whose `best == fold`) *(new)*. Button
   "Start review" → Drills in Review mode.
2. **Resume session** — if a session snapshot exists with `hands > 0`. Title "Resume your table";
   subtitle `"{hands} hands, {fmtSigned(net)} bb · Coach {on|off}"`. Estimate assumes 20 more
   hands at ~18 s per hand ("~6 min"). Tap → P1.
3. **Continue lesson** — the first incomplete lesson in path order, or on the first day the
   placement result's suggested lesson. Title `"Continue: {title}"`; subtitle
   `"Level {n} · {minutes} min read · {done}/31 done"`. Tap → S1.
4. **Quick set** — "A set of 10 {mode} spots" in the mode with the weakest accuracy over the last
   20 answers in that mode (needs ≥ 5 answers in the mode; otherwise Mixed). Mobile records
   per-mode answer history (`drill_answers` ring of 200, §16.4) — a deliberate addition to the
   desktop drill store. Subtitle `"Rating {rating} · {acc} % accuracy"`. Estimate "~4 min". Tap →
   D0 with the set counter armed (§5.4).
5. **Play 20 hands** — when no snapshot exists. Title "Play 20 hands · 6-max" (saved options);
   subtitle "Coach on · Manual pace" (saved play settings). Estimate "~6 min". Tap → new session.

Cards 2 and 5 are mutually exclusive. If the daily goal is met, the line **"Goal met — anything
else is a bonus"** *(new)* (Inter 14, good colour, no icon, no animation) sits above the list;
nothing is hidden.

### 3.3 Goal card

Bar fill = `max(drills/20, hands/30)` clamped to 1, gold; label = whichever is closer to
completion: `"{drills} of 20"` + caption "drills · or 30 hands — either counts" *(new)*, or
`"{hands} of 30"` + caption "hands · or 20 drills — either counts". At 100 % the bar is fully
gold and the count reads "20 of 20" (no celebration). Tap → H2: sheet S with the verbatim
Today tooltip *(desktop)*: "A quiet daily goal: 20 drill answers (or 30 hands) keeps the
day-streak alive. No reminders, no guilt — just a nudge to come back tomorrow."

Streak line: `"{weekday} · {n} days in a row"`; the streak fragment is omitted when `streak() == 0`.
It never counts down and is never coloured.

### 3.4 Coach's note (card) and detail (H1)

One sentence chosen in priority order (all *(desktop)* unless marked):
1. A leak line from `leaksFromDecisions` (first of: "You fold too often when you're getting the
   right price — look for more +EV calls." / "You call too wide for the pot odds — fold your
   weakest hands more." / "No clear −EV mistakes flagged — solid discipline. Keep refining the
   thin spots.").
2. The read-accuracy line: "Your range reads are often off — drill Guess & Peek and the
   Range-Building exercise." (guesses ≥ 5 and mean accuracy < 0.5).
3. Yesterday's debrief line: `"Costliest: a {street} {action} ({fmtSigned(evBb)} bb) — it's in
   your Review queue."`.
4. No data: "Play a session with the EV Coach on and I'll start noticing patterns." *(new)*.

"Show me why ›" → **H1** (sheet M) rendered with `CoachNoteView` (§10.5): layer 1 = the same
sentence; "Show me the math" = the numbers behind it, e.g. `"{foldMistakes} of your last {n}
coached decisions were folds the coach flagged — {pct} %."` *(new)*; "Expert detail" = the rule
(`"Flagged when ≥ 3 fold mistakes and > 12 % of coached decisions."` *(new)*); a secondary
button to the relevant lesson (`pot-odds` for the two leak lines, `drill-range` for reads) and,
when due, "Review these spots ›".

### 3.5 Other rows

- **Last session** (only when a session has ended): `"{fmtSigned(net)} bb · {hands} hands · {m}
  mistakes"` + costliest line; tap → P10 read-only.
- **Practice** mini heatmap: last 5 weeks (35 cells, 12 pt, 3 pt gap; gold = goal met; gold @35 %
  = active; `ink700` = none), caption `"{active} active days"`. Tap → Stats (scrolls to the full
  16-week heatmap). Hidden until the first active day.
- Greeting: "Good morning" (05–12), "Good afternoon" (12–18), "Good evening" (otherwise). The
  first run after onboarding replaces the streak line with "Start with a session — the coach
  explains as you go." *(new)*.
- No pull-to-refresh (everything is local and live).

### 3.6 States

- **First run (no data):** goal bar at 0 with the caption; cards: Continue lesson (placement
  suggestion or `hand-rankings`), Quick set (Mixed), Play 20 hands; coach card shows the no-data
  line; heatmap and Last session hidden.
- **Goal met:** §3.2.
- **Session paused:** card 2 present and the Session pill above the tab bar.

---

## 4. PLAY

### 4.1 Lobby (P0) — table setup, resume, recent sessions, empty state

```
┌──────────────────────────────────────────┐
│ Play                                     │ 59–103 title
│ Six seats, four kinds of opponent, one   │ Inter 14 muted (new)
│ coach.                                   │
│ ┌──────────────────────────────────────┐ │
│ │ ● Session in progress                │ │ Resume card 96 (only while a snapshot exists)
│ │ 6-max · 12 hands · +4.5 bb · 8 min ago│ │
│ │                          [ Resume › ]│ │ 44 gold; whole card tappable
│ └──────────────────────────────────────┘ │
│ NEW TABLE                                │
│ ┌──────────────────────────────────────┐ │
│ │      ╭──────────────────────╮        │ │ felt preview 140 pt: live re-seats itself
│ │      │  ○   ○   ○  ·  ○  ○  │        │ │ as Table changes; ante chips appear with Antes
│ │      ╰──────────────────────╯        │ │
│ │ Table   [ Heads-up ][ 6-max ● ][ 9-max ]│ │ segmented 44 (desktop labels)
│ │ Antes   [ None ● ][ 0.25 bb ]        │ │ segmented 44
│ │ ⓘ Coach charts assume 6-max —        │ │ 12 pt faint, only when seats ≠ 6 (desktop)
│ │   verdicts at other table sizes use  │ │
│ │   the nearest position as an         │ │
│ │   approximation.                     │ │
│ │ Pace    [ Manual ● ][ Auto ]  Normal ▾│ │ speed menu only when Auto
│ │ EV Coach  Grades every decision  (● )│ │ toggle
│ │ Stacks  100 bb each · blinds 0.5 / 1 │ │ static caption
│ │ ┌──────────────────────────────────┐ │ │
│ │ │           Deal me in             │ │ │ primary 56
│ │ └──────────────────────────────────┘ │ │
│ └──────────────────────────────────────┘ │
│ RECENT SESSIONS                          │
│ Today 18:10   6-max · 31 hands  +12.5 bb ›│ rows 56 → P10 read-only
│ Yesterday     9-max · 18 hands   −3.0 bb ›│
│ ┌────┬────┬────┬────┬────┐               │
└──────────────────────────────────────────┘
```

- Seats / antes persist as `TableOptions` (2/6/9, 0/5 chips; `allin.table.v1`). Pace, speed and
  EV Coach are the desktop's non-persisted play settings; **on mobile they are remembered**
  (deviation: re-choosing pace every session is friction on a phone). Realistic reveals and the
  four-colour deck live in Settings and in P2 Options.
- A paragraph under NEW TABLE on the very first visit only *(desktop start-overlay copy)*: "A
  session deals hand after hand against a fixed table of bots. Your stack carries over, so wins
  and losses stick until you end the session."
- "Deal me in" → `newSession(opts)` → P1. Archetypes are assigned randomly per seat; the lobby
  never shows them.
- Resume card + Deal me in both present: tapping Deal me in asks (dialog) "Start a new table?
  Your paused session (12 hands) will be summarised and closed." — [Keep paused one] [New table]
  *(new)*. "New table" shows P10 for the old session first, then deals.
- Recent sessions: last 10 ended sessions (`sessions` table, §16.4), row = relative day/time,
  `"{seats-label} · {hands} hands"`, signed net. Tap → P10 read-only.
- **Empty state** (never played): the preview shows dashed board slots and the caption "Your first
  table. The coach explains every decision in plain English." *(new)* under it; no Recent section.

### 4.2 Table (P1) — 6-max portrait wireframe at 390×844 (hero BB with Q♠Q♥ to act, facing a raise to 3)

Vertical budget, top to bottom. These bands are **fixed**: the context row and the action row
never change height between states, so the felt never jumps.

```
y    0– 59   status / Dynamic Island (safe inset)
y   59–103   top bar 44          ‹  ·  "Hand #12 · +4.5 bb"  ·  [◉ 3]  ·  [▶ Step]
y  103–121   ticker 18           last log line (Inter 13 muted; results gold-light, deals info)
y  121–600   FELT canvas 479     x 22–368 (346 wide) · rail 10 pt · 5 seats · pot · board · chip zone
y  556–657   hero cards 72×101   anchored over the felt's bottom rim (overlap 44)
y  666–694   hero strip 28       "BB · 100 bb"        "To call 2 bb · need to win 1 in 4"
y  698–746   context row 48      sizing rail | pace strip | explain + caption | countdown
y  754–810   action row 56       Fold · Call 2 · Raise to 7.5   (8 pt gaps, 16 pt margins)
y  810–844   home indicator
```

```
┌──────────────────────────────────────────────┐
│ ‹   Hand #12 · +4.5 bb          [◉ 3] [▶ Step]│ 59–103
│  Negreanu raises to 3 bb                     │ 103–121 ticker (tap → P2 Log; long-press = copy)
│      ╭───────────────┬──┬──┬──────────────╮  │ 121 felt top rim
│      │            ┌──┴──┴──┴─┐            │  │ 125 top seat's cards peek 24 pt above the plate
│      │            │(N) Negre. UTG│           │  │ 149–207 seat 3 plate 104×58, centre (195,178)
│      │            │ 98 bb  31/22 │ 👁         │  │        eye glyph at the plate's outer corner
│      │            └──────────────┘           │  │
│      │                ● 3 bb                 │  │ 236 seat-3 bet spot (pill 22 tall)
│ ┌──┬──┬──────────┐                ┌──┬──┬──────────┐│
│ │(S) Selbst  MP │                │(P) Polk   CO ││ 243–301 seats 4 (left) & 2 (right), centres
│ │ 96 bb   –/–   │   Fold         │ 97 bb  24/18 ││ (60,272) / (330,272): plates straddle the rail
│ └───────────────┘                └───────────────┘│
│      │        PRE-FLOP · Pot 4.5 bb        │  │ 256–280 pot pill (≤ 130 wide, centre y 268)
│      │     ▭    ▭    ▭    ▭    ▭           │  │ 306–368 board slots 44×62, x 73–317 (6 gaps)
│ ┌──┬──┬──────────┐                ┌──┬──┬──────────┐│
│ │(H) Hellmuth UTG│   ● 1 bb (you)  │(I) Ivey  BTN D││ 401–459 seats 5 (left) & 1 (right),
│ │ 92 bb   12/9  │                │100 bb  22/18  ││ centres (60,430) / (330,430); D = dealer disc
│ └───────────────┘                └───────────────┘│
│      │ ┌──────────────────────────────────┐ │  │ 479–519 COACH CHIP zone (300×40, x 45–345)
│      │ │ ✓ Nice play · Betting with the…  ›│ │  │        (empty felt when no chip)
│      │ └──────────────────────────────────┘ │  │
│      ╰──────────────╮   ╭─────────────────╯  │ 600 felt bottom rim
│                 ┌─────┐┌─────┐                 │
│                 │ Q♠  ││ Q♥  │                 │ 556–657 hero cards (lift 6 + gold glow on turn)
│                 └─────┘└─────┘                 │
│  BB · 100 bb          To call 2 bb · need 1 in 4│ 666–694 hero strip
│  Min   ⅓    ½    ⅔    ¾   Pot   All-in         │ 698–746 sizing rail (labels 11, rail 6, knob 28)
│  ○────○────○────●────○────○────────○           │
│ ┌──────────┐ ┌─────────────┐ ┌───────────────┐ │
│ │   Fold   │ │  Call 2 bb  │ │ Raise to 7.5  │ │ 754–810 action row
│ └──────────┘ └─────────────┘ └───────────────┘ │
│                 ▬▬▬▬▬▬                         │ 810–844
└──────────────────────────────────────────────┘
```

**Felt geometry.** The felt is a rounded rectangle x 22–368, y 121–600 (346×479), corner radius
150 (reads as an oval), 10 pt rail `AllInColors.rail` with a 1 pt `railLight` highlight, felt
fill radial `feltLight` → `felt` → `feltDark`, inner hairline at 92 % of the shape. All seat and
prop anchors are **fractions of the felt canvas** so the same table scales to 360 and 430:

| Anchor (6-max) | fraction (x, y) | @390 screen (x, y) |
|---|---|---|
| seat 3 (top) | (0.50, 0.12) | (195, 178) |
| seat 2 (upper right) / seat 4 (upper left) | (0.89, 0.315) / (0.11, 0.315) | (330, 272) / (60, 272) |
| seat 1 (lower right) / seat 5 (lower left) | (0.89, 0.645) / (0.11, 0.645) | (330, 430) / (60, 430) |
| pot pill centre | (0.50, 0.307) | (195, 268) |
| board centre | (0.50, 0.45) | (195, 337) |
| hero bet spot | (0.50, 0.60) | (195, 408) |
| coach chip centre | (0.50, 0.79) | (195, 499) |
| table centre (bet-spot vector origin) | (0.50, 0.44) | (195, 332) |

**Seat order** is counter-clockwise from the hero exactly as the desktop `seatPos()` and the
engine: seat 1 lower-right, 2 upper-right, 3 top, 4 upper-left, 5 lower-left. Engine seat ids map
1:1; the dealer button therefore travels the same way as on desktop, in the replayer and in hand
histories. (No mirroring.)

**Bet spots**: each seat's bet pill (§10.3 `BetPill`, 22 tall, mono 11, chip glyph) sits 58 pt
from the plate centre along the line to the table centre; blinds and antes post there. The hero's
bet pill sits at the hero bet spot. Computed positions never collide with the pot pill or board at
any supported width (checked: seat 2 → (277, 295); seat 1 → (283, 395)).

**Opponent hole cards** (30×42 face-down) peek 24 pt above the plate's top edge, tucked behind
it; a fold slides them 20 pt down behind the plate — no separate card slot exists per seat.

**Top bar** (44): `‹` (44×44, leaves the table; §2.5) · centre title "Hand #12 · +4.5 bb"
(Inter 15 semibold + mono; tap → P2 Session segment; the net is good/bad coloured) · Coach badge
`[◉ 3]` (44×44; count = notes this hand; dot = latest verdict colour; hidden when coach off) ·
Pace pill `[▶ Step]` / `[▶▶ Auto]` (64×36 in a 44 hit box; tap toggles; long-press → P2 Options).
At 360 wide the title truncates to "#12 · +4.5"; nothing else changes.

**Ticker** (18): the newest engine `log` line; colour by kind (result gold-light, deal info,
action muted, info faint). Tap → P2 Log at L. Long-press → copies the hand's log ("Hand log
copied" toast). In Auto pace every line passes through the ticker so a user looking up from the
action row can catch up. Empty at the very first deal: "Actions will appear here." *(desktop)*.

### 4.2.1 Heads-up (2 seats)

The felt keeps its frame; everything grows because there is one opponent:

```
│ ‹   Hand #4 · −1.5 bb           [◉ 1] [▶ Step]│
│  Dwan posts SB 0.5                            │ ticker; first 3 HU hands instead show
│      ╭───────────────────────────────╮       │ "You're the button — you act first pre-flop,
│      │      ┌────────────────────┐   │       │  last after it" (new)
│      │      │(D) Dwan · BB    –/–│   │       │ plate 160×64 at (0.50, 0.145) → (195,190)
│      │      │ 98.5 bb · 4h       │   │       │ HU shows the archetype name spelled out ONLY in P6
│      │      └────────────────────┘   │       │ cards 34×48 tucked behind the plate
│      │             ● 1 bb            │       │ bet spot (0.50, 0.27)
│      │        FLOP · Pot 6.5 bb      │       │ pot pill (0.50, 0.37)
│      │    ┌───┐ ┌───┐ ┌───┐ ▭   ▭    │       │ board 52×73 at (0.50, 0.52)
│      │    │A♠ │ │7♦ │ │2♣ │          │       │
│      │             ● 2 bb (you)      │       │ hero bet spot (0.50, 0.67)
│      │   [coach chip zone]           │       │ (0.50, 0.79)
│      ╰───────────────╮ ╭─────────────╯       │
│                ┌──────┐┌──────┐              │ hero cards 80×112 (top y 545)
│  BTN/SB · 98.5 bb        To call 2 bb · need 1 in 4 │
```
Position tags follow the HU rule: "BTN/SB" for the button, "BB" for the other seat. The dealer
disc alternates between the two plates.

### 4.2.2 9-max (8 opponents)

Compact plates 84×50 keep the HUD (reads matter most at 9-max): row 1 avatar 20 + name (5 chars)
+ position; row 2 stack mono 11 + HUD mono 9 (`22/18·14h`). Cards 24×34 tucked. Board 40×56
(five = 220 wide, x 85–305). Anchors (fractions): s5 (0.28, 0.10) · s4 (0.72, 0.10) · s6 (0.11,
0.28) · s3 (0.89, 0.28) · s7 (0.11, 0.47) · s2 (0.89, 0.47) · s8 (0.11, 0.665) · s1 (0.89,
0.665) · pot pill (0.50, 0.33) · board (0.50, 0.45) · hero bet spot (0.50, 0.60) · chip
(0.50, 0.79). Side bet spots are 52 pt toward the centre; at 360 wide the mid-side bet pills
(s7/s2) move 16 pt below their plate instead so they never touch the board.

```
│      ╭───────────────────────────────╮       │
│   ┌──────┐                     ┌──────┐      │ s5 (top-left) · s4 (top-right), y ≈ 169
│   │Anton.│UTG                  │Dwan  │UTG   │
│   │88·12/9│                    │100·34/27│    │
│ ┌──────┐└──────┘         └──────┘┌──────┐    │
│ │Galfo.│MP                     │Selbst│MP   │ s6 · s3, y ≈ 255
│ │95·22/18│    PRE-FLOP · 2.5   │96·–/–│     │ pot pill y ≈ 279
│ └──────┘ ▭   ▭   ▭   ▭   ▭     └──────┘    │ board y 309–365
│ ┌──────┐                        ┌──────┐    │
│ │Chidw.│CO                     │Polk  │CO   │ s7 · s2, y ≈ 346
│ └──────┘                        └──────┘    │
│ ┌──────┐         ● 1 bb (you)   ┌──────┐    │
│ │Bruns.│BTN D                  │Ivey  │SB   │ s8 · s1, y ≈ 439
│ └──────┘                        └──────┘    │
│      │        [coach chip zone]        │     │
│      ╰──────────────╮ ╭───────────────╯      │
│                ┌────┐┌────┐                  │ hero cards 64×90
```
Position labels on 9-max are the engine's 6-label approximation (`BTN SB BB UTG UTG MP MP CO
CO`): two seats may share a label and the plate shows it as-is. The player sheet adds
"(approximate — 9-max uses 6-max labels)" *(new)* after the position, and the lobby shows the
verbatim "Coach charts assume 6-max…" note. Never invent UTG+1 / HJ.

### 4.2.3 360×780 and 430×932

**360×780** (status 32, gesture inset 24). Bands: top bar 32–76 · ticker 76–94 · felt 94–560
(316×466; canvas scale 0.913, anchors unchanged as fractions) · hero cards 64×90 (top 520,
overlap 40) · hero strip 612–640 · context row 644–692 · action row 700–756 · inset. Plates
96×54 (6-max), 78×46 (9-max, HUD 9 pt kept), HU plate 148×60; board 40×56; names truncate at 6
characters without ellipsis. Bottom row heights are hard minimums and never shrink. The sizing
rail keeps all seven ticks (spacing 45 pt, labels 10 pt).

**430×932**: felt 380×548 (extra height goes to the felt only), board 50×70, hero cards 80×112,
plates 112×60. The action zone keeps its 390 heights; margins grow to 20.

### 4.2.4 Dynamic type on the table

The felt's text (plate name/stack/HUD, pot, ticker) scales with the system text size up to
**1.15×** and then stops; the hero strip, context row and action row scale up to **1.3×** and
grow in height (the felt shrinks to compensate, never below 400 pt at 390 wide). Above 1.3× the
action labels drop their amounts into the hero strip ("Call" + strip line "To call 2 bb").

### 4.3 Seat component (`SeatPlate`, §10.3)

```
        ┌──┐┌──┐            ← 30×42 face-down cards, peeking 24 pt above the plate, tucked behind it
   ┌────┴──┴┴──┴────────┐
   │ (I) Ivey     [BTN] │👁  avatar 26 (initial; ring = archetype colour) · name Inter 13 semibold
   │     100 bb   22/18 │   stack mono 13 gold-light · HUD mono 10 with a colour dot
   └────────────────────┘ D  dealer disc 18, on the plate corner nearest the pot
        ● Raise 3 bb        ← action pill at the bet spot (last action this street)
```

- **Plate**: 104×58, radius 14, `ink800` @ 92 %, 1 pt `line` ring. Name truncated to 8
  characters without ellipsis. Position tag: 10 pt caps pill (UTG / MP / CO / BTN / SB / BB;
  HU: BTN/SB, BB). Stack: mono 13 `"100 bb"` (`fmtBb`: one decimal only when needed).
- **Avatar ring colour = archetype** (TAG `#2f6fd0`, LAG `#8a5cd1`, Nit `#2faa66`, Station
  `#d23b3b`). The archetype *name* is never on the plate.
- **HUD line**: `22/18` (VPIP/PFR) after ≥ 8 observed hands, else `–/–`; `· 12h` when width
  allows. In Auto pace the HUD line is replaced by a three-dot "thinking" shimmer while the bot's
  delay runs; `thinking` is cleared whenever the loop exits for any reason.
- **Eye glyph** `👁` (12 pt, gold @ 70 %) at the plate's outer top corner, visible while
  `phase == betting && !hasFolded && hole != null`; its invisible hit box is 44×44 (the corner
  quadrant of the plate plus 12 pt of felt outside it). **Tap → P7 Read range** (one tap for
  experts). Hidden on folded seats and at hand-over.
- **Tap the plate** (anywhere except the eye) → **P6 Player sheet** (the gentle default: a curious
  first-week tap never lands in a 13×13 matrix).
- **Long-press the plate** (500 ms, medium haptic) → P7 directly (shortcut).
- **Tap the action pill** (hit box 44 tall, full pill width + 8 pt) → Explain last move (§4.10)
  when that seat was the last actor; otherwise no-op.
- **Turn indicator**: 2 pt gold ring; Manual: slow 1.6 s breathing pulse + a faint `▶` glyph
  inside the ring meaning "this seat moves on Next action"; Auto: a thin arc sweeps once per
  think. Exactly one seat carries it while `phase == betting`. Static ring under reduced motion.
- **Folded**: cards slide 20 pt down behind the plate and fade to 30 %; plate dims to 55 %;
  pill "Fold" faint. **All-in**: red "ALL-IN" pill replaces the stack. **Winner**: ring turns
  `good`, plate lifts 2 pt, chips fly in, `"+6.5 bb"` floats up 24 pt and fades.
- **Action pill colours** *(desktop)*: Raise/Bet gold, All-in `chipRed`, Call `info`, Check
  muted, Fold faint. Pills persist until the street closes, then glide into the pot with the
  chips.
- **Compact seat** (9-max): 84×50 — see §4.2.2. **Hero seat** has no plate on the felt: the hero
  strip carries it (§4.4).
- Sitting out / busting bots do not exist (bots always play; a bot at 0 bb is rebuilt to 100 bb
  at the next deal exactly as the desktop `deal()` does — the plate shows "100 bb" again with a
  one-hand "rebought" caption *(new)* in place of the HUD line).

**P6 — Player sheet** (S detent, ≈ 380 pt):

```
┌──────────────────────────────────────────┐
│               ▬▬▬                        │
│ (I) Ivey · BTN · Tight-Aggressive (TAG)  │ Inter 17 semibold; archetype name + colour dot
│ Plays few hands but bets and raises      │ archetype blurb (desktop, verbatim)
│ them hard. The textbook winner.          │
│ ┌──────────────┬───────────────────────┐ │
│ │ VPIP 22 %    │ PFR 18 %   · 14 hands │ │ StatTiles (mono); "–" under 8 hands
│ └──────────────┴───────────────────────┘ │
│ Observed over 14 hands this session —    │ HUD tooltip text (desktop, verbatim)
│ VPIP = how often they put money in       │
│ pre-flop, PFR = how often they raise.    │
│ Each player's exact numbers vary, so     │
│ watch them settle.                       │
│ ┌────────────────────────────────────┐   │
│ │ 👁  Read their range               │   │ primary 48 → P7 (only while in hand & betting)
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ ◉  Explain their last move         │   │ secondary 48 (only if they acted last)
│ └────────────────────────────────────┘   │
└──────────────────────────────────────────┘
```
Under 8 hands the paragraph is "Stats appear after 8 observed hands (3 so far) — reads are earned,
not given." *(desktop)*. The archetype name is shown here from hand 1 (desktop tooltip parity;
Exploits drills must connect to play). Disabled buttons read at 40 % with the reason in a caption
("Hand over — reads reopen on the next deal" *(new)*).

### 4.4 Hero: cards, strip, turn state

- **Hero cards** 72×101 (radius 9), always face-up, rank Bricolage 800 at 26 pt top-left, large
  suit glyph bottom-right at 92 % of the face; 6 pt gap, centred, overlapping the felt rim by 44
  so "your" cards are anchored to the table edge. On the hero's turn the cards lift 6 pt and gain
  the gold glow; a light haptic fires once. Four-colour deck applies (♦ `suitBlue`, ♣
  `suitGreen`). Tap a card: nothing (no fan gimmicks).
- **Hero strip** (28 pt, y 666–694, Inter 15 / mono 15): left `"BB · 100 bb"` (position pill
  + stack; dealer disc appears left of it when hero is BTN); right, the **price line** when facing
  a bet: `"To call 2 bb · need to win 1 in 4"` (`fmtBb`, `fmtNeed`) — layer-1 pot odds visible
  before every decision; the percentage form lives in the coach note's layer 2. Otherwise the
  right side shows the hand label `"QQ · pocket queens"` (`cardsToLabel` + friendly names for
  pairs and broadways, else `"K♠ 9♠ · suited"`). At hand-over it shows the made hand ("Two pair,
  queens and sevens").
- After 8 hands, tapping the left part of the strip opens T1 with the "Your VPIP / PFR" copy
  *(desktop)* and the hero's `"24/19 · 12h"`; the numbers themselves live in P2 Session (not on
  the strip — width is spent on the price line).
- **Swipe up** on the hero strip → P2 (secondary gesture; the first-hands caption mentions it).
- All-in hero: strip reads "ALL-IN" in `chipRed`; cards keep the glow until showdown.

### 4.5 Action zone — context row (48) + action row (56)

The two rows keep their heights in every state; only their contents change. Margins 16, gaps 8.
Labels Inter 17 semibold; amounts mono. Every button acknowledges with a 120 ms press-scale to
0.97 and a medium haptic on commit.

**State A — hero to act, can bet/raise** (`heroToAct && (canBet || canRaise)`):

```
│  Min   ⅓    ½    ⅔    ¾   Pot   All-in        │ context row = SIZING RAIL (48)
│  ○────○────○────●────○────○────────○          │
│ ┌──────────┐ ┌─────────────┐ ┌───────────────┐│ action row
│ │   Fold   │ │  Call 2 bb  │ │ Raise to 7.5  ││ widths 28 % / 34 % / 38 %
│ └──────────┘ └─────────────┘ └───────────────┘│
```

- **Fold** (28 %): `ink700` fill, `bad` text, 1 pt `bad` @ 40 % border. Present only when there
  is a bet to call. **Fold ignores taps for the first 150 ms after the row appears** (swallows a
  tap meant for the previous state).
- **Check / Call** (34 %): `ink600` fill. "Check" · "Call 2 bb" · "Call all-in 37 bb" when the
  call commits the stack. When nothing is to call the row is **Check (45 %) + Bet (55 %)**.
- **Bet / Raise** (38 %): gold fill, `ink900` text. The label is always **the exact commit**:
  "Bet 4.5" / "Raise to 7.5" / "All-in 100" (when the size equals the maximum; label turns
  `chipRed` on gold). Tapping commits immediately — no confirm step, ever. After the label
  changes to "All-in …" the button ignores taps for 150 ms (same guard as Fold).
- Gating comes straight from `legalActions()`: no `canBet/canRaise` → the rail hides (context
  row shows the price line's percentage twin: "Calling 2 bb into 4.5 bb" muted) and the row is
  Fold / Call (or Check) only. Facing an all-in the Call button grows to fill and the context row
  reads `"All-in call — 45 bb to win 120 bb"` *(new)*.

**Sizing rail** (`SizingRail`, §10.3) — the whole 48 pt band is the drag target:

- Seven **detents**, evenly spaced across the rail regardless of value: `Min · ⅓ · ½ · ⅔ · ¾ ·
  Pot · All-in`. Values: Min = `minRaiseTo`; fractions = `add = round((pot + toCall) × f)`,
  `raiseTo = clamp(currentBet > 0 ? currentBet + add : add)` (the desktop `setFraction`, ½ ¾ Pot
  unchanged; ⅓ and ⅔ added); All-in = `maxRaiseTo`. Detents whose clamped value equals their left
  neighbour's collapse into it (label hidden, tick merged) so labels never overlap.
- Between two detents the knob interpolates linearly in bb, quantised to `max(1, bb/2)` chips
  (0.5 bb). Dragging anywhere on the band moves the knob to the finger; the knob magnetises to a
  detent within ±6 pt with a `selectionClick` haptic per detent crossed. **Tap** a label or tick to
  jump. **Release never commits** — only the Raise button commits.
- Default on open: ⅔ (desktop 0.66 rule), recomputed whenever `toAct / street / currentBet /
  phase / handNumber` change. The selected detent's label is gold; a custom value shows no gold
  label and a small readout `"7.5 bb"` above the knob while dragging (mono 12).
- While dragging, the price line becomes the opponent's price: `"If they call they need to win
  about 1 in 3"` *(new)*, then reverts on release.
- **Tap the Raise amount** (the mono part of the button, hit box = the button's right 60 %) or
  **long-press the Raise button** (500 ms) → **P13 Bet keypad** (sheet S, 300 tall): mono 28
  display "7.5 bb", caption "min 4 · max 100", ±0.5 steppers (44), keypad 1–9 · . · 0 · ⌫ (keys
  116×48), the same seven detent chips, and "Set · Raise to 7.5" (56). Set clamps to
  `[minRaiseTo, maxRaiseTo]` and returns with the value selected — still not committed. No system
  keyboard on the table.
- A held finger on the rail after 600 ms without movement shows the readout only; nothing fires.

**State B — hero to act, cannot raise**: Raise removed, Call/Check fills the remaining width;
context row as above.

**State C — bot to act, Manual pace**:

```
│ [◉ Explain last move]        Tap the table or Next action to step │ context row: ghost 44 + caption
│ ┌────────────────────────────────────────────┐ │
│ │              Next action  ›                │ │ action row: secondary 56, full width
│ └────────────────────────────────────────────┘ │
```
- Tap = `stepBot()` — exactly one bot action, animated in ≤ 400 ms; taps during an animation are
  queued, never dropped. **Tap anywhere on the felt** that is not a seat, the board, the pot, the
  chip or a pill also steps (the biggest target on screen). A resting finger does nothing:
  holding the felt has no auto-repeat.
- **Hold "Next action"** (long-press 500 ms) = hold to fast-forward: bots act at the Fast delay
  (360 ms) while held, stopping at the hero's turn or hand-over (medium haptic at the stop).
- The caption "Tap the table or Next action to step" *(new)* shows for the first three hands of
  the user's life, then never again (O1 coach mark 1).
- "◉ Explain last move" (ghost, 44 tall) is present whenever `canExplain` (last actor is a bot).

**State D — bot to act, Auto pace**:

```
│ ◌ Ivey is thinking…        [◉ Explain]  [ ⏭ ] │ context row: spinner 16 + name; ghost; skip 44×44
│ ┌────────────────────────────────────────────┐ │
│ │            Pause · tap the table           │ │ action row: secondary 56 ("Paused · tap to resume ▶" when paused)
│ └────────────────────────────────────────────┘ │
```
- `⏭` = **skip to my turn**: runs the remaining bot actions at 120 ms cadence without changing
  any state ordering, stopping at the hero's turn or hand-over.
- Tapping the felt in Auto pauses/resumes (same as the button). Pause sets the desktop `paused`
  flag; the pace setting stays Auto.
- Auto never runs while any sheet, P7, or a blocking note is open (`paused || guess.open`).

**State E — hand over**:

```
│ [◉ Explain last move]                   ◔ 3 s │ context row: ghost; countdown ring only with Auto-deal on
│ ┌────────────────────────────────────────────┐ │
│ │               Next hand  ›                 │ │ action row: primary 56 (gold)
│ └────────────────────────────────────────────┘ │
```
- "Next hand" → `deal()`. Setting "Auto-deal next hand" (default **off**, desktop parity): in
  Auto pace a 3 s ring counts down; **touching the results card cancels the countdown** (the user
  is reading) and "Next hand" becomes explicit.

**State F — paused** (blocking note up, P7 open, app backgrounded): the action zone dims to 40 %
and ignores taps; the reason is on screen (the sheet, or the ticker "Paused — tap to continue"
*(new)*).

**State G — no session** (deep link / after reset): the felt shows seat silhouettes and a centred
card "Ready to play?" *(desktop)* with the start-overlay paragraph and "Deal me in" → uses saved
options.

### 4.6 Manual "Step" vs Auto pace

- Control: top-bar pace pill "▶ Step" / "▶▶ Auto" — tap toggles (instant, light haptic);
  long-press → P2 Options. Defaults: Step, Normal — the desktop defaults. Remembered across
  sessions (§4.1).
- P2 Options rows: Pace segmented `Step` / `Auto` with the verbatim helper copy *(desktop)*
  "Step through each player's action yourself." (the "→ key" clause is dropped) / "Bots act
  automatically at the chosen speed."; Speed `Slow` / `Normal` / `Fast` (1100 / 700 / 360 ms,
  Auto only); switches: EV Coach · Auto-deal next hand · Realistic reveals · Four-colour deck;
  rows "Seats — 6-max" and "Antes — none" read "Ends this session first" *(new)* and are not
  editable mid-session; "End session" (danger ghost 48) at the bottom.
- Switching Step ↔ Auto mid-hand takes effect at the next tick (`setSettings`).
- A hand in Step: a quiet table; the turn ring breathes on the seat that will act; the ticker
  shows the last line; the action row invites "Next action". The hero's turn is unmistakable:
  cards lift and glow, the action row's buttons slide up 8 pt into place, a light haptic fires.
- Backgrounding mid-hand: Auto flips to paused; on return the same screen shows with the ticker
  "Paused — tap to continue"; the loop resumes 700 ms after the first tap so the user can
  re-orient.

### 4.7 Bot action animation and timing

Per bot action at Normal (700 ms cadence):

| phase | ms | what moves |
|---|---|---|
| think (Auto only) | 0–150 | HUD line → three-dot shimmer; turn ring arc sweeps |
| act | 150–400 | action pill pops at the bet spot (scale 0.8→1, 200 ms, `AllInMotion.ease`); bet/call: a 3-disc chip stack slides plate → bet spot (250 ms) while the stack number counts down (120 ms) |
| pass | 400–450 | turn ring hops to the next seat (120 ms crossfade) |
| fold | 220 | cards slide 20 pt down behind the plate, fade to 30 %; plate dims |
| street closes | ≈ 500 | bet pills + chips glide to the pot (280 ms, 30 ms stagger per seat), pot number rolls (200 ms), new board cards deal in (`AllInMotion.deal` 340 ms each, 60 ms stagger) |

Fast (360) shortens every phase proportionally; Slow (1100) lengthens only the think phase. In
Step the whole action completes in ≤ 400 ms so rapid tapping feels responsive; the queue drains
in order. Deal: hero cards slide from the pot centre and flip (280 ms, 60 ms stagger); opponents'
backs pop in around the ring (40 ms stagger); blinds' pills appear; "PRE-FLOP" fades into the pot
pill; light haptic when the hero's second card lands. Hero acts: same as a bot act with no think
phase, medium haptic. Reduced motion: every duration → 0, chips and cards appear in place, the
ring is static, the pot number snaps.

