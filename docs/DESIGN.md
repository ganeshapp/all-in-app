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
| Play | `cards` | **Lobby** (§4.1) | Table setup + resume. A live session puts the Resume card at the top of the lobby; **the tab never auto-redirects to the table** (§2.1.1). |
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

**Compact-height rule.** At 360×780 the bar (80) + gesture inset (24) + pill (56 + 8 gap) eat
**168 pt — 21 %** of every tab. So the pill is height-gated: it renders only when
`screenH ≥ 800` **and** `textScaler ≤ 1.15`. Below that the **Play tab item carries the
session** instead — its label becomes `"Play · +4.5"` (mono net, good/bad coloured) with a 6 pt
gold dot on the icon; tapping Play opens the lobby with the Resume card focused and ringed gold
for 2 s. Home's Resume plan card (§3.2 card 2) is the other one-tap way back, so a session is
never more than one tap away on any screen size. There is no 44-pt pill variant: a 44-pt row is
below the §1 "pressed every few seconds" floor for the fastest path back to money — either the
full 56 or nothing.

#### 2.1.1 The Play tab never redirects

`GoRouter` does **not** redirect `/play` → `/table`. A redirect keyed on `hasSession` makes the
lobby's Resume card, the "Start a new table over a paused one" dialog (§4.1) and Recent sessions
unreachable for exactly as long as a session exists, and bounces the user back onto the felt the
instant they leave it with `‹`. Rules:

- Tapping the Play tab always shows **P0**, with the Resume card first while a snapshot exists.
- After leaving the table with `‹` / system back, the Play tab shows the lobby. Ways back in:
  the Resume card, the Play-tab session dot, the Session pill, Home's Resume plan card.
- **Cold start only**: if the app was killed while `/table` was the active location, the router
  sets `initialLocation = '/table'` **once** (flag `allin.hints.v1.resumeOnLaunch`, cleared on
  the first frame). Every later navigation follows the rules above.

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
| P6 | Player sheet (archetype, HUD explained, actions) | sheet **M** (its content is ≈ 380 pt, taller than the S cap of 40 % — §4.3) | P1 plate tap, P8 reveal row |
| P7 | Read range: Guess → Peek | full-screen modal | P1 seat eye, plate long-press, P6 "Read their range" |
| P8 | Results overlay | in-place overlay on the lower felt | auto at hand-over |
| P9 | All reveals (9-max overflow) | sheet L | P8 "All 8 hands ›" |
| P10 | Session summary | full-screen modal over the table (`/table/summary`); **read-only** copies are branch pushes (`/home/session/:id`, `/play/session/:id`, `/stats/session/:id`) | P2 "End session", bust, Resume pill swipe; read-only from H0, P0 Recent, T0 |
| P11 | Hand replayer | push (tab bar hidden); **two routes** — `/stats/hand/:startedAt` in the Stats branch and `/table/hand/:startedAt` inside the table modal (§16.1) | P10 row, T2 row, T0 recent hand, P2 Log hand row |
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
| S1 | Lesson reader | **two routes**: `/study/lesson/:id` (branch push, tab bar hidden) and root-level `/lesson/:id` (`fullscreenDialog`, "Done" instead of `‹`) — §16.1 | S0 row + H0 continue card use the push; D1's lesson button uses the modal; the placement result uses the push (§5.8) |
| S2 | Term popover | anchored popover | any dotted term |
| S3 | Tool screens: Range explorer · Equity calculator · Pot-odds calculator · Bluff calculator · Multiway trainer · Hand rankings | push | S0 Tools row, lesson "Open full screen" |
| S4 | Quick reference + Glossary (searchable) | push | S0 pinned row, S2 "Open glossary" |
| S5 | Card keypad | sheet M | S3 equity calculator slots |
| S6 | Range editor (paint a range full-screen) | full-screen modal | S3 equity calculator "Edit" |
| T0 | Progress | tab root | tab |
| T1 | Stat explainer | sheet S | any ⓘ tile / dotted label |
| T2 | All hands (filter by tag / source) | push | T0 "All hands ›" |
| T3 | Import hands (picker → progress → result) | system picker + sheet **S** (progress and result alike, §7.8) | T0/T2 "Import", X0 Data |
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
│                             ├─ push  Session summary (P10 read-only) at /home/session/:id
│                             │        ── push Replayer (P11) at /home/session/:id/hand/:startedAt
│                             └─ sheet Coach's note (H1) · sheet Goal explainer (H2)
├─ Play / Lobby (P0) ─────────┬─ modal TABLE (P1)  [tab bar hidden; root-level /table]
│                             │    ├─ sheet  Session (P2: Log · Session · Options)
│                             │    ├─ sheet  Coach note (P3) ── in-sheet push Assumed range (P5)
│                             │    ├─ sheet  Coach notes list (P4) ── P3
│                             │    ├─ sheet  Player (P6)
│                             │    ├─ modal  READ RANGE (P7: paint → peek, same route)
│                             │    ├─ overlay Results (P8) ── sheet All reveals (P9) · sheet Player (P6)
│                             │    ├─ sheet  Bet keypad (P13)
│                             │    ├─ sheet  Explainer (T1) for any ⓘ
│                             │    ├─ push   Replayer (P11) at /table/hand/:startedAt  (from P2 Log)
│                             │    └─ modal  SESSION SUMMARY (P10) at /table/summary
│                             │             ── push Replayer (P11) at /table/summary/hand/:startedAt
│                             │             ── sheet Note (P12) · system Share
│                             └─ push  Session summary (P10 read-only) at /play/session/:id
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
Lesson reader as a modal (/lesson/:id) is root-level and can be presented over Drills or the
placement result without leaving the branch it was opened from.
```

**Why the extra routes.** P10 and P11 are reachable from three places that live on different
branches, and the table is a *root-level* modal. Pushing `/stats/hand/:startedAt` from inside
the table modal would dismiss the table and switch tabs; pushing `/play/session/:id` from Home
would switch tabs mid-gesture. So each host owns its own copy of the sub-route (same screen
widget, same provider, different `parentNavigatorKey`). §16.1 lists them all.

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
| Session summary (P10) | Equals ✕ (returns to the table; session continues). Busted: back does nothing (only "New session" continues — a *blocked-back* response). |
| Drill feedback panel (D1) | Collapses to the compact detent; never dismisses the verdict. |
| Drills root with an unanswered spot | Normal tab behaviour (nothing is lost). |
| Lesson reader from a drill | Returns to the same answered spot with the panel still up. |
| Range editor (S6) | Equals "Done" (keeps edits). |
| Placement (D5) / Onboarding (O0) | Previous page; on the first page it does nothing (a *blocked-back* response); ✕ is the only exit. |
| Replayer (P11) | Pops to where it came from. |
| Reset dialog (X2) | Cancel. |

**Blocked back** (P10-busted page 1, O0/D5 page 1): a 120 ms 4 pt horizontal shake of the page
content + `selectionClick`. **Under reduced motion the shake is dropped entirely** — the haptic
alone is the response, and if Settings → Haptics is also off nothing happens (the screen is
already telling the user what the only exit is). Motion is never the sole channel for a refusal.

### 2.6 Internal deep links (go_router paths, §16.1)

| Deep link | Goes to | Used by |
|---|---|---|
| `/lesson/:id` | S1 as a root-level full-screen modal ("Done") | drill feedback (D1) |
| `/study/lesson/:id` | S1 as a Study-branch push | Home continue card, coach's note, placement result |
| `/drills?mode=leaks` | D0 in Review mode | Home review card, Stats coaching review |
| `/stats/hand/:startedAt` | P11 in the Stats branch | T0 / T2 / P10-read-only rows |
| `/table/hand/:startedAt` | P11 inside the table modal | P2 Log rows, P10-over-table rows |
| `/study/glossary?term=:id` | S4 scrolled to and flashing that term | S2 "Open glossary" |
| `/stats/settings?section=data` | X0 scrolled to and flashing the DATA group | import result, backup toasts |

`/settings` and `/settings/data` are accepted as legacy aliases and **redirect** to
`/stats/settings` and `/stats/settings?section=data` (§16.1). There is no URL-fragment route:
`go_router` matches paths and queries, never `#fragments`. No external URL scheme in v1.

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
whole (whole card = one 72 pt target).

**Home scrolls at every supported width** — 390 included. The wireframe above sums to ≈ 963 pt
below the safe inset (title 44 + streak 20 + goal 84 + eyebrow 28 + primary 96 + three cards
3 × 72 + coach 96 + eyebrow 28 + last-session 64 + eyebrow 28 + heatmap 102 + caption 18, plus
8–12 pt gaps), against a viewport of 844 − 59 − 80 (tab bar) − 34 (inset) = **671 pt** at
390×844 and 780 − 32 − 80 − 24 = **644 pt** at 360×780. What matters is not that it fits — it
never does — but that the **goal card and the primary plan card are always above the fold**:
they end at y ≈ 343 at 390 and y ≈ 316 at 360, roughly half a screen.

Bottom content padding of the scroll view = `tabBarHeight + (pillVisible ? 64 : 0) + 16`, so the
heatmap caption always clears both the bar and the Session pill: 80 + 64 + 16 = **160** at
390×844 with a session, 80 + 0 + 16 = **96** at 360×780 (no pill there — §2.1).

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

### 4.8 The EV Coach on the table: chip → badge → sheet (P3, P4, P5)

**Where the coach lives.** Three surfaces, one voice, one anatomy (`CoachNoteView`, §10.5):

| Surface | What | When |
|---|---|---|
| **Coach chip** (`CoachChip`) | 300×40 pill in the felt's chip zone (fraction (0.50, 0.79) → y 479–519 at 390), 90 pt above the hero cards and inside the thumb arc | every non-blocking verdict |
| **Coach badge** `[◉ 3]` | top-bar 44×44; count = notes this hand; dot = latest verdict colour | whenever `reviewLog` is non-empty |
| **Coach sheet** (P3) | bottom sheet M (55 %) → L (capped so the bottom 120 pt stay visible, §2.4) | tap chip / badge row; auto for blocking |

The chip sits **on the felt, under the board and above the hero's cards** — not in the top bar —
so a thumb resting on the action row reaches it without a second hand, and it never covers a
seat, the board, the pot or the action row. When the chip zone would collide with a bet pill
(HU layout, 9-max hero bet spot), bet pills are drawn beneath it; the chip has priority for 4 s.

**Non-blocking notes → chip.** When `evaluateHero` resolves (after the action is applied, never
blocking the UI), the chip springs in (scale 0.9→1, 260 ms `AllInMotion.ease`, light haptic):

```
        ┌──────────────────────────────────────┐
        │ ✓  Nice play · Betting with the go… ›│  verdict disc 24 · label · first clause of layer 1 · chevron
        └──────────────────────────────────────┘
```

- Verdict `META` labels *(desktop)*: **Mistake** (`bad`, ✕) · **Thin spot** (`warn`, i) ·
  **Reasonable** (`info`, ✓) · **Nice play** (`good`, ✓) · **Read** (`info`, eye).
- Content = label + " · " + the first clause of `plain ?? text` (cut at the first " — ", ";" or
  full stop, ellipsised at one line) so a beginner learns something without tapping.
- Lifetime: 4 s at Manual/Normal/Fast; 8 s at Slow; non-blocking **mistakes** (fold / check /
  bet verdicts) stay 8 s regardless. Then it shrinks into the badge (200 ms, path to the top
  bar; reduced motion: crossfade). Chips never stack — a newer note replaces the older with a
  crossfade and the badge count increments.
- Tap chip → P3 at M. Swipe the chip up → P3 at L. Swipe the chip down → dismiss to badge.
- Haptics: Nice play / Reasonable = light; Thin spot = medium; non-blocking Mistake =
  `notification.warning`.
- A verdict that resolves after `handNumber` changed is not shown as a chip *(desktop)*; it
  is still recorded (Stats, hand record).

**Blocking mistakes → the sheet opens itself.** `review.blocking` (a −EV call beyond the
strictness threshold, outside the noise band): the loop pauses (`paused = true`), the felt dims
to 60 %, a `notification.warning` haptic fires once, the action zone dims to 40 % (State F),
and P3 opens at **M with no grabber**. Scrim tap does nothing; swipe-down does nothing; system
back **equals "Got it"** (§2.5 — acknowledgement is the only way on, and back is an
acknowledgement, never an escape). "Got it" → `dismissReview()` → `maybeAutoLoop()`.

**P3 — Coach note sheet** (blocking example; a non-blocking note is identical with a grabber and
"Close" (ghost) instead of "Got it"):

```
┌──────────────────────────────────────────┐
│               (no grabber when blocking) │
│ ┌──────────────────────────────────────┐ │
│ │ ⊗  Mistake                           │ │ header tinted bad @ 12 %; disc 32 with ✕
│ │    EV Coach · Your call · River      │ │ line 2: "EV Coach" | "Bot read" · title · street
│ │    [Q♠][Q♥]  on  [7♦][2♣][9♠][K♦][3♣]│ │ XS cards 22×31: context, because the felt is dimmed
│ │    you called 8 bb into 24 bb        │ │ (new) one-line situation
│ └──────────────────────────────────────┘ │
│ You paid 8 bb to win a pot of 24 bb —    │ LAYER 1 · Inter 17/1.45 · always open · verbatim
│ you need to win about 1 time in 4. Your  │ `plain ?? text`
│ hand wins about 1 time in 6 — not        │
│ enough. Over time this call loses money; │
│ folding is better.                       │
│                                          │
│ Win chance vs Ivey ⓘ              17 %  │ equity row (only when equity != null)
│ ▓▓▓▓▓▓▓░░░░░░░░░░░│░░░░░░░░░░░░░░░░░░    │ bar 10 pt, verdict colour; white 2 pt marker = needed
│ White line = 25 % needed (pot odds ⓘ)    │ ⓘ → S2 term popover ("Win chance (equity)" / "Pot odds")
│                                          │
│ ⚠ Multiway pot (3 opponents). With more… │ amber callout, only when review.multiway (verbatim)
│                                          │
│ ▸ Show me the math                       │ LAYER 2 · disclosure row 48, gold label
│ ▸ Expert detail                          │ LAYER 3 · disclosure row 48, muted label
│                                          │
│ Expected value              −2.0 bb      │ EV tile: bad < −0.05 · good > +0.05 · muted between
│ ┌───────────────┐ ┌────────────────────┐ │
│ │ 👁 View range │ │      Got it        │ │ 48; View range only when villainRange non-empty
│ └───────────────┘ └────────────────────┘ │
└──────────────────────────────────────────┘
```

- **The two disclosure rows are always rendered.** When `steps` is empty the row reads
  "Show me the math" and opens to "No math for this one — the verdict is a rule of thumb, not a calculation."
  *(new)*; when `expert` is empty and there is no `plain`, "Expert detail" opens to "Nothing
  extra here." *(new)*. Labels toggle to "Hide the math" / "Hide expert detail" *(desktop)*.
- Layer 2 expands inline to the numbered `steps` (Inter 15, mono numbers, 2 pt left rule in
  `line`). Layer 3 expands to bullets: `review.text` first (only when `plain` exists — the
  layer-2 line moves here, desktop order), then each `expert` string.
- Opening either disclosure grows the sheet to L. **Disclosure state is not remembered between
  notes** (plain first, always). Settings → Coach → "Always expand 'Show me the math'" (default
  off) opens layer 2 on every note for graduates; layer 3 never auto-expands.
- The ⓘ popovers use the verbatim tooltip bodies: **Win chance (equity)** — "how often your
  hand ends up best if the rest of the cards were dealt out with nobody folding." · **Pot
  odds** — "the share of the final pot your call pays for. Win more often than this and the
  call makes money."
- **View range** pushes **P5** inside the sheet (slide-left 250 ms): title "Ivey's assumed
  range", subtitle *(desktop)* "This is the range the coach used for its equity estimate, based
  on archetype, position and action so far.", a read-only `RangeMatrix` (346 pt at 390; cells
  24), `RangeLegend(kind)`, footer mono "≈ 312 combos · 23 % of all hands", back chevron
  returns to the note. The sheet stays at L while P5 is shown.
- Bot-read notes (`kind == "bot"`, verdict `info`): eye disc, line 2 "Bot read · Ivey's raise",
  the `interpretBot` sentence as layer 1, no equity bar, layer 2 = "No math for a read — this
  is an interpretation of their style." *(new)*, layer 3 = the archetype blurb, "View range"
  shows `botRanges[seat]`.
- Coach copy is never paraphrased; every string is `review.plain`, `review.text`,
  `review.steps[]`, `review.expert[]` from the engine.

**P4 — Coach notes list (this hand).** Tap the badge → sheet M:

```
┌──────────────────────────────────────────┐
│               ▬▬▬                        │
│ Coach notes · Hand #12                   │ Inter 17 semibold
│ ⊗ Mistake     Your call · River          │ rows 64: disc 24 · label · title · street
│   "You paid 8 bb to win a pot of 24…"    │ first line of layer 1, muted, ellipsised
│ ✓ Nice play   Your bet · Flop            │
│   "Betting with the goods on a wet…"     │
│ 👁 Read       Ivey's raise · Pre-flop     │
│   "Ivey raises from the button a lot…"   │
└──────────────────────────────────────────┘
```
Newest first. Tap a row → the sheet **replaces itself** with P3 (read-only, no pause; back
chevron returns to the list). Notes reset on the next deal (`reviewLog: []`) and the badge
disappears. Every decision remains in Stats → Coaching review, and mobile **persists each
hand's notes with the hand record** (`hand_json.coachNotes[]`, §16.4) so the replayer (§7.7)
can replay the coaching at the frame where it happened.

**Coach off.** No badge, no chips, nothing recorded (`coachEnabled` short-circuits before
`evaluateHero`). The toggle lives in P2 Options and the lobby. The hero strip's price line
stays on regardless — it is not coaching, it is the table.

### 4.9 Read range: Guess → Peek (P7)

Entry: seat eye (one tap), plate long-press, P6 "Read their range". Available for any bot with
cards while `phase == betting`, on any street, not only the hero's turn. Opening calls
`openGuess(id)` → `paused = true` (Auto stops); closing calls `closeGuess()` → resumes.
Full-screen modal (the matrix needs the full width); tab bar hidden.

```
┌──────────────────────────────────────────┐
│ ✕       Read Ivey's range         Peek   │ 59–103 top bar; ✕ 44; Peek = text button 44 (primary colour)
│ BTN · Tight-Aggressive (TAG) · Flop      │ Inter 13 muted (desktop subtitle line 1)
│ Optionally paint your guess, or just     │ desktop subtitle line 2
│ peek to study their range.               │
│    A  K  Q  J  T  9  8  7  6  5  4  3  2 │ 155–175 column header (tap = toggle column; long-press = "this and better")
│ A ▓▓ ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ 179–541 matrix 362×362 at 390 (cells 26 + gap 2)
│ K ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ row header 20 pt wide (tap = toggle row; long-press = 99+ etc.)
│ Q ▓▓ ▓▓ ▓▓ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ pairs diagonal = comboPair · suited (upper-right) = comboSuited
│ J ▓▓ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ offsuit (lower-left) = comboOffsuit · unpainted = ink700 + faint label
│ T ░░ ░░ ░░ ░░ ▓▓ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ │ label 9.5 semibold (mono digits): "AKs", "T9o", "77"
│ …                    ╭──────╮            │ loupe 56×56, 48 pt above the fingertip while pressed
│                      │ K♠Q♠ │            │ (3×3 neighbourhood, target cell outlined gold)
│                      ╰──┬───╯            │
│ 2 ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ░░ ▓▓ │
│ ■ Pairs ■ Suited ■ Offsuit  148 combos · 11 % │ 549–573 legend + live counter (mono gold-light)
│ [Top 10 %][15 %][25 %][40 %][55 %][UTG][MP][CO][BTN][BB] │ 581–617 preset chips 36 tall, h-scroll, hit 44
│ ┌────────┐ ┌────────┐ ┌────────────────┐ │
│ │ ↶ Undo │ │ Clear  │ │  Peek & score  │ │ 629–685 buttons 56; "Peek" when nothing is painted
│ └────────┘ └────────┘ └────────────────┘ │
│ Guessing is optional — peek any time.    │ 693–711 desktop hint, faint 12
└──────────────────────────────────────────┘ + 34 inset
```

**Finger-painting spec (`RangeMatrix.editable`)** — cells are 26 pt (25 at 360, 29 at 430),
deliberately below 44: the matrix is one paint surface, not 169 buttons. Precision comes from
five mechanisms:

1. **Touch-down decides the stroke mode**: the first cell touched is toggled immediately; if it
   was empty the stroke is *add*, otherwise *remove* (desktop `addModeRef`). The stroke keeps
   that mode until the finger lifts.
2. **Drag** paints every cell the finger crosses in that mode. Pointer samples are
   **interpolated along the segment** between consecutive events (Bresenham over cell indices)
   so a fast diagonal swipe never skips a cell. Cell fill animates 80 ms. `selectionClick`
   haptic per newly painted cell, throttled to ≥ 30 ms.
3. **Loupe**: while pressed, a 56 pt bubble floats 48 pt above the fingertip showing the 3×3
   neighbourhood with the cell under the finger outlined in gold and its label in Bricolage 13.
   Still shown under reduced motion (it is not motion). Hidden when a hardware
   pointer (mouse/stylus hover) is detected.
4. **Tap** = a touch that moves < 4 pt and lifts within 200 ms → toggles that one cell only.
5. **Header selectors**: tap a column header → toggle the whole column; tap a row header →
   toggle the whole row (mode = the majority state inverted); tap the "A" corner → toggle all
   pairs; **long-press** a row header → "this and better" (long-press "9" → 99+; on the suited
   header row → A9s+ style "and better" along that row). Header hit boxes are 44 tall / 26 wide
   + slop to 44.

- **Undo** reverts the last stroke (20 deep; a preset or Clear counts as one stroke). **Clear**
  empties with a 3 s "Undo clear" snackbar. Presets replace the current paint: Top 10 / 15 /
  25 / 40 / 55 % (`topPercentRange`) and the position opens from the 100 bb chart (UTG · MP ·
  CO · BTN · BB defend = `chartToSet`), labelled by position only.
- Counter: `"{combos} combos · {fmtPct(combos/1326)}"`; at 0: "Nothing painted yet".
- No pinch-zoom (it conflicts with paint and needs a custom recogniser); OS zoom and the
  §13 semantics cover large-text users. The grid never scrolls; at 780 pt tall the legend and
  the preset row merge into one 36 pt line and buttons are 48.
- **Compare mode** colours *(desktop legend)*: `good` = correct, `warn` = missed, `bad` =
  extra; with the OS "differentiate without colour" flag, missed cells get diagonal hatching
  and extra cells a centre dot.

**Peek → reveal** (`peek(painted)`; same route, content crossfades 200 ms; medium haptic; a
"Sharp read" gets `notification.success`):

```
┌──────────────────────────────────────────┐
│ ✕       Ivey's range revealed            │
│ BTN · Tight-Aggressive (TAG) · Flop      │
│    (13×13 compare matrix, read-only)     │ green correct · amber missed · red extra
│ ■ Correct ■ Missed ■ Extra  Their range: 312 combos │ legend switches to compare mode
│ ┌──────────────────────────────────────┐ │
│ │  64 %   SOLID                        │ │ Bricolage 40 + grade label, both in the grade colour
│ │  You caught about 7 in 10 of the     │ │ plain-English recall / precision (new, layer 1)
│ │  hands they play here, and about 6   │ │
│ │  in 10 of what you painted was right.│ │
│ │  Coverage (recall): 71 %             │ │ desktop lines, mono, muted (layer 2 of this card)
│ │  Precision: 58 %                     │ │
│ └──────────────────────────────────────┘ │
│ Everyone's exact cards are revealed when │ desktop
│ the hand ends.                           │
│ ┌──────────────────────────────────────┐ │
│ │               Continue               │ │ 56 primary → closeGuess() → resumes
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

- Grades *(desktop)*: ≥ 0.8 "Sharp read" (`good`) · ≥ 0.6 "Solid" (`gold`) · ≥ 0.4 "Rough"
  (`warn`) · else "Way off" (`bad`). Recorded (`recordGuess`) only when something was painted.
- Nothing painted: the matrix highlights the actual range read-only and the card reads
  *(desktop)* "Here's Ivey's assumed range. Paint a guess first next time for an accuracy
  score."
- ✕ / system back before Peek → `closeGuess()` without scoring (no "discard?" dialog — desktop
  parity; the paint is cheap). After Peek → equals Continue.
- At hand-over the results overlay marks the read seat "Your read 64 %"; tapping reopens the
  compare grid read-only with the cell of their actual hand ringed in gold (§4.12).

### 4.10 Explain last move

Available whenever `canExplain` (last actor is a bot): the ghost "◉ Explain last move" in
States C/D/E, "Explain their last move" in P6, and **tapping a bot's action pill** (hit box 44
tall × pill + 8) when that seat was the last actor. Calls `explainLastBotMove()`: an info chip
"👁 Ivey's raise ›" appears and P3 opens at M with the `interpretBot` sentence as layer 1 and
"View range" for `botRanges[seat]`. The store keeps the last action's label so the title never
degrades to "Ivey's move" after a street closes (fixes the desktop quirk). It pauses Auto only
while the sheet is open. Disabled at 40 % (no-op, no caption) when the last actor was the hero.

`interpretBot` copy is verbatim from the engine (`docs/port/play-loop-and-coach.md` §5).

### 4.11 Session sheet (P2): Log · Session · Options

Opened by: the top-bar title, the ticker (opens on Log), the pace pill long-press (opens on
Options), swipe-up on the hero strip. Sheet M; the segment is remembered for the session.

```
┌──────────────────────────────────────────┐
│               ▬▬▬                        │
│ ┌────────┬──────────┬──────────┐         │ segmented 36 (hit 44)
│ │  Log ● │ Session  │ Options  │         │
│ └────────┴──────────┴──────────┘         │
│ HAND #12                                 │ eyebrow
│  Ivey raises to 2.5 bb                   │ action rows 32: kind colours (result gold-light,
│  Dwan folds                              │ deal info, action muted, info faint); hero lines
│  You call 2.5 bb                         │ in `text`; newest at the bottom, auto-scrolls
│  ⊗ Mistake · Your call ›                 │ coach notes interleaved as badge rows → P3
│  Flop: 7♠ 8♦ K♣                          │
│  Ivey bets 2 bb                          │
│ ▸ Hand #11 (+4 bb)                       │ previous hands collapsed (this session), 44 rows
│ ▸ Hand #10 (−1 bb)                       │ tap → expand; "▷ Replay" at the row end → P11
└──────────────────────────────────────────┘
```

- **Log**: the engine `log` for the current hand; empty state "Actions will appear here."
  *(desktop)*. Long-press any hand's header → "Hand log copied" toast.
- **Session**: stat tiles (`StatTile`, mono) Hands `12` · Net `+4.5 bb` (good/bad) · bb/100
  `+37` · Read accuracy `64 %` (or "—") · Your style `24/19 · 12h` (after 8 hands; "—" before).
  Each tile tap → T1 explainer with the verbatim tooltip (bb/100: "Big blinds won per 100 hands
  — the standard poker win-rate, independent of stake. +5 is strong; pros live roughly between
  −5 and +10. Small samples swing wildly." · Your VPIP / PFR: "How often YOU voluntarily put
  money in pre-flop, and how often you raise. Most winning 6-max players sit around 22–28 VPIP
  and 16–22 PFR. Much higher = too loose; a big gap between the numbers = too passive."). Below:
  "Hands this session (12)" rows 52 (`#12 · +3.0 bb · ▷ Replay · ✎`). Bottom: **"End session"**
  (danger ghost 48).
- **Options**: see §4.6 (Pace, Speed, EV Coach, Auto-deal next hand, Realistic reveals,
  Four-colour deck, the read-only Seats/Antes rows, End session).

### 4.12 Hand-over: reveal, results overlay (P8), next hand

At `phase == hand-over` (all steps skippable by tapping Next hand):

1. **Reveal**: showdown cards flip face-up in their seats (two 150 ms half-flips, seat order from
   the button, 60 ms stagger). Unless "Realistic reveals" is on, folded seats flip too, dimmed
   45 % + greyscale (`isHero || (revealed && !(realisticReveal && hasFolded))`).
2. **Pot to winner**: chips glide to the winner's plate (420 ms); ring turns `good`; stack counts
   up; "+6.5 bb" floats up 24 pt from the plate. Side pots animate one after another, each
   labelled "Main pot" / "Side pot 2" for 600 ms. Hero win → `notification.success` haptic.
3. **Results overlay** (`ResultsCard`) slides up over the **lower felt only** (y 372–560 at 390:
   below the board, above the felt's bottom rim), so the board, the top seats and the hero cards
   stay visible; the seats it covers (s1/s5 at 6-max) are exactly the ones whose cards are also
   listed in the card:

```
│      │     ▭    ▭    ▭    ▭    ▭         │  │ board stays visible
│ ┌──────────────────────────────────────────┐ │ 372
│ │  +12.5 bb            Ivey wins with two  │ │ net: Bricolage 24 in good / bad / muted
│ │  YOU WON THE POT     pair.               │ │ caption "You won the pot" | "Hand over" (desktop)
│ ├──────────────────────────────────────────┤ │ sentence: "{names} wins with {hand}." | "{names} takes it down."
│ │ [K♦][7♣] Polk   Folded on the flop — the  │ │ reveal rows 44+: XS cards 22×31 (folded: 45 %
│ │          full board would have given them │ │ + grey) · name · revealNote() verbatim
│ │          a pair of kings.                 │ │
│ │ [A♠][4♠] Selbst Folded before the flop —  │ │
│ │          playable, but gave it up.        │ │ 3 rows visible; the list scrolls inside the card
│ │ [9♥][9♦] Ivey   Won with two pair. · Your read 64 % › │ read seat: link → compare grid (§4.9)
│ └──────────────────────────────────────────┘ │ 560
│                 ┌─────┐┌─────┐                 │ hero cards remain; hero strip shows the made hand
│  [◉ Explain last move]                 ◔ 3 s │ context row (State E)
│  ┌────────────────────────────────────────┐   │
│  │               Next hand  ›             │   │ action row
```

- 9-max: three rows + "All 8 hands ›" → **P9** (sheet L with every reveal row).
- Realistic reveals on: folded rows show face-down XS cards and only "Folded on the turn."
- Tap a reveal row → P6 for that seat with "Read their range" disabled ("Hand over — reads
  reopen on the next deal") and an inline read-only matrix of the range assigned for their last
  street; "Explain their last move" enabled when applicable.
- **Learn-by-reveal**: the card opens automatically at every hand-over (it is the desktop
  overlay). If the user taps Next hand within 1 s on three consecutive hands, the card collapses
  to a one-line strip ("+12.5 bb · You won the pot · See everyone's cards ›") on subsequent
  hands until they open it twice in a row again. Nothing is ever hidden; only the default
  height adapts.
- "Next hand" → `deal()`. With **Auto-deal next hand** on (default off) and Auto pace, a 3 s ring
  counts down in the context row; **touching the results card cancels the countdown** and the
  button becomes explicit. Under reduced motion the ring is a static "3 s" caption that counts.
- Bust (hero stack 0 at deal): the bar reads "Session over" and P10 opens (title "Session over
  — you busted", no ✕, only "New session").

### 4.13 Session stats, end session, summary (P10), share

End session: P2 Session → "End session"; the Session pill swipe-left → "End session"; the
lobby's Resume card overflow. Busting opens the summary automatically. `endSession()` shows
P10; **closing P10 with ✕ returns to the table and the session continues** *(desktop)*; only
"New session" rebuilds the table, and "Done" returns to the lobby with the session ended.

```
┌──────────────────────────────────────────┐
│ ✕            Session summary             │ 59–103 (✕ hidden when busted)
│ 41 hands played this session.            │ "{n} hand{s} played this session."
│ ┌──────────────────────────────────────┐ │
│ │ HOW YOU PLAYED (BEFORE HOW IT PAID)  │ │ gold-tinted card, eyebrow verbatim
│ │ 18 coached decisions, 2 flagged as   │ │ "{n} coached decision{s}, {m} flagged as mistakes
│ │ mistakes (11 % vs your usual 14 % —  │ │  ({rate}% vs your usual {life}% — cleaner than
│ │ cleaner than average).               │ │  average | — a rougher one)."
│ │ Best: a turn raise worth +3.2 bb.    │ │ "Best: a {street} {action} worth {ev} bb."
│ │ Costliest: a river call (−3.1 bb) —  │ │ "Costliest: a {street} {action} ({ev} bb) — it's
│ │ it's in your Review queue.        ›  │ │  in your Review queue." → tap: Drills Review mode
│ └──────────────────────────────────────┘ │
│ ┌──────────┬──────────┐                  │
│ │ Net      │ bb / 100 │                  │ 2×2 StatTiles: Net (good/bad) · bb / 100 ·
│ │ +12.5 bb │ +30.5    │                  │ Biggest win (good) · Biggest loss (bad)
│ ├──────────┼──────────┤                  │
│ │ Biggest  │ Biggest  │                  │
│ │ win +18  │ loss −9.5│                  │
│ └──────────┴──────────┘                  │
│ 6 hands reached showdown. Replay any     │ verbatim
│ hand below, or export the full history   │
│ for a poker tracker.                     │
│ REVIEW HANDS                             │
│  Hand #41   +6.0 bb          ▷ Replay  ✎ │ rows 52; ✎ gold when a note exists → P12
│  Hand #40   −1.0 bb          ▷ Replay  ✎ │ swipe-left → "Note" action; tap row → P11
│  …                                       │
│ ┌────────────┐ ┌───────────────────────┐ │
│ │ ⇪ Share    │ │     New session       │ │ 56; Share = system share sheet
│ └────────────┘ └───────────────────────┘ │
│                  Done                    │ ghost 44 → lobby (hidden when busted)
└──────────────────────────────────────────┘
```

- "Share" replaces the desktop's Copy + Export: the system share sheet carries the
  PokerStars-style text as both a text item and an attached
  `all-in-session-{startedAt ISO, first 19 chars, ":"/"T" → "-"}.txt`; Copy is one of its
  targets. Disabled when 0 hands. Toast after a share that completes: none (the OS confirms);
  after "Copy": "Hand history copied to clipboard." *(desktop)*.
- The verdict card and the money tiles never share a colour scale (principle 8).
- Read-only P10 (from Home / Lobby recent sessions / T0): same layout, no "New session", "Done"
  only; header "Session · Today 18:10 · 6-max".

### 4.14 Session persistence and leaving the table

- **Snapshot contract** *(mobile addition)*: the session snapshot (table options, stacks,
  archetypes + dials, session counters, hand history, HUD counters, play settings, `reviewLog`)
  is written at **every hand boundary** and after **every hero action**. Leaving mid-hand keeps
  the mid-hand snapshot; resuming restores the exact table state (street, board, pot, `toAct`)
  with a 2 s caption "Resumed — Hand #13, flop" *(new)* under the top bar. If the mid-hand
  snapshot cannot be restored (schema mismatch after an update), the hand is **abandoned**: not
  counted, stacks restored to the hand's start, a fresh hand deals, and the caption reads
  "Resumed — that hand couldn't be restored, dealing a fresh one" *(new)*.
- **Leaving** (`‹`, system back): no dialog. The session pauses, the route pops, a toast
  "Session paused — resume from Home or Play" *(new)* shows once per session. The table is a
  **modal route** so the iOS edge-swipe never fires under a thumb reaching for Fold.
- **P14 "Leave table?"** exists only for the case where the snapshot write failed (storage
  full): "Your session can't be saved right now. Leave anyway? This hand will be lost." — Cancel
  · Leave *(new)*.
- **Backgrounding**: the loop pauses immediately; state is already persisted. On return: the
  same screen, ticker "Paused — tap to continue"; the first tap re-enables the loop after 700 ms.
- **Start a new table over a paused one**: dialog from the lobby (§4.1).

### 4.15 Table empty states and first-table coach marks (O1)

- **No session on the table route** (deep link / after reset): seat silhouettes on the felt and
  a centred card *(desktop)* "Ready to play?" + "A session deals hand after hand against a fixed
  table of bots. Your stack carries over, so wins and losses stick until you end the session."
  + "Deal me in" (uses saved options).
- **Between hands**: the board shows dashed slots and the pot pill "0 bb" for ≤ 300 ms.
- **O1 coach marks** (first three hands of the user's life only, never again, dismiss on any
  tap; each is a 36 pt caption with a 6 pt gold pointer, Inter 14 on `ink800` @ 95 %):
  1. Under the action row in State C: "Tap the table or Next action to step" *(new)*.
  2. Next to the first eye glyph that appears: "Tap the eye to read their range" *(new)*.
  3. Above the hero strip on the first hero turn: "Swipe up here for the hand log and your
     session" *(new)*.
  HU adds "You're the button — you act first pre-flop, last after it" *(new)* in the ticker for
  the first three HU hands (§4.2.1).

---

## 5. DRILLS

Chess-puzzle rhythm: see the spot, scrub the story if you need it, answer with one tap, read
the verdict, next. One spot per screen; the answer row is always under the thumb; feedback rises
from the bottom without hiding the table. Drills are a **tab root** (not a focus mode): a spot
is stateless until answered, so leaving costs nothing.

### 5.1 Drills root (D0)

```
┌──────────────────────────────────────────┐
│ Drills                             [ⓘ]   │ 59–103 title; ⓘ → D4 (current mode blurb)
│ ⟨ Mixed ● ⟩⟨ Push / Fold ⟩⟨ Exploits ⟩⟨ Review 3 ⟩│ 103–147 mode chips 36 (hit 44), h-scroll; count pill on Review
│ Rating 1084 · 71 % · streak 4 · best 9   │ 147–179 stats strip 32, mono; each stat a 44-tall target → D3
│ ◔ 14/20 today      Day streak 6          │ 179–203 second line (hidden in Review mode)
│   ╭──────────────────────────────────╮   │ 207–507 drill table 300 (DrillTable: fixed 6 anchors)
│   │ ┌────┐   ┌────┐   ┌────┐         │   │ plates 72×36: position bold + "Folded" (faint) /
│   │ │ MP │   │UTG │   │ CO ▯▯│        │   │ "In hand" (info); a seat with cards = in hand
│   │ │Fold│   │Fold│   │In hd │        │   │ folded seats 25 % opacity + greyscale
│   │ └────┘   └────┘   └────┘         │   │
│   │            FLOP · 7.5 bb         │   │ street caption + pot pill (frame values)
│   │        ┌──┐ ┌──┐ ┌──┐            │   │ board 44×62 (frame board)
│   │        │A♠│ │7♦│ │2♣│            │   │
│   │ ┌────┐            ┌────┐         │   │
│   │ │ SB │            │ BB │         │   │
│   │ │Fold│            │Fold│         │   │
│   │ └────┘  ┌──┐┌──┐  └────┘         │   │ hero cards 48×67 face-up; plate ringed gold, "You"
│   │         │K♥││Q♥│  You · BTN      │   │
│   ╰──────────────────────────────────╯   │
│ ‹‹  ‹   ● 5 / 6  CO bets 5 bb     ›  ›› │ 515–559 move navigator 44 (§5.2)
│ Your hand  KQs      Post-flop heuristic · fundamentals │ 563–583 hand label (gold Bricolage 17) + source pill
│ ┌──────────┐┌──────────┐┌──────────────┐ │ 591–647 answer row 56 (2 or 3 options)
│ │   Fold   ││  Call 5  ││ Raise to 16  │ │ 28 / 34 / 38 % like the table; 2 options = 50/50
│ └──────────┘└──────────┘└──────────────┘ │
│ ┌────┬────┬────┬────┬────┐               │ tab bar
└──────────────────────────────────────────┘
```

- **Mode chips** carry the verbatim labels `Mixed` · `Push / Fold` · `Exploits` · `Review`;
  Review shows the count pill when `dueCount > 0` (the same number badges the tab). Tap →
  `setMode(m)`; the spot crossfades 200 ms. Long-press a chip / tap ⓘ → **D4** (sheet S) with the
  verbatim blurb *(desktop `MODE_INFO`)*.
- **Stats strip** (hidden entirely in Review mode; replaced by "Review · 3 due · 7 scheduled"
  *(new)*): "Rating {rating}" (gold), "{acc} %", "streak {n}", "best {n}". Second line: Today
  ring 20 pt + "{min(today,20)}/20 today" (gold when met) · "Day streak {n}" only when > 0. Tap
  Rating → D3 with the verbatim tooltip "A self-adjusting puzzle rating (like a chess puzzle
  ELO). Right answers raise it, wrong ones lower it, weighted by difficulty." + a 30-day rating
  sparkline *(new, from `drill_answers`)*; tap Today → the verbatim daily-goal tooltip (§3.3).
- **Drill table**: the fixed anchors hero (0.50, 0.85), then clockwise from lower-right
  (0.89, 0.60) · (0.89, 0.18) · (0.50, 0.07) · (0.11, 0.18) · (0.11, 0.60) *(desktop)*. Plates
  are not tappable (no archetype to inspect). Exploit spots colour the named seat's ring with
  the archetype colour and show its HUD numbers (§5.7).
- **Answer row**: labels verbatim from `option.label` ("Fold", "Call 2.5 bb", "Raise to 7.5
  bb", "Shove 12 bb", "Check", "Bet"). Fold leftmost, the aggressive action rightmost, same
  colours as the table (§4.5). No keycaps; hardware keyboards still map 1/2/3 and Enter.
- **Source pill** *(desktop, verbatim)*: "Pre-flop chart · 100bb baseline" · "Post-flop
  heuristic · fundamentals" · "Push/Fold · computed Nash" · "Push/Fold · ICM bubble" · "Exploit ·
  vs a known type" · "Your flagged spot". Tap → sheet S with the matching paragraph from About's
  "How the grading works".
- **Bounded sets** *(mobile addition, optional)*: when D0 is opened from a Home "quick set"
  card, a set counter "3 of 10" sits at the right of the hand-label line. After the 10th answer
  the feedback panel's header adds a one-line strip "Set done — 8 of 10 · rating +24" with
  "Keep going" as the Next button's label; the endless loop is otherwise unchanged. There is
  no set-summary card and no forced stop.
- **360×780**: table 264 pt; the stats strip and the Today line merge into one 32 pt line
  ("Rating 1084 · 71 % · 4/9 · ◔ 14/20"); everything else keeps its height.

### 5.2 Move navigator (D0 scrubber, D2 frame list)

The desktop frame list becomes a **scrubber row** (`FrameScrubber`, 44 tall): `‹‹` first ·
`‹` previous · centre pill "● 5 / 6 · CO bets 5 bb" (mono index, frame text ellipsised) · `›`
next · `››` Decision. Buttons 44×44; disabled at the ends (40 %). The table above re-renders
that frame's board, pot and folded seats.

- **Swipe left / right anywhere on the drill table** = next / previous frame (horizontal drag,
  40 pt threshold, `selectionClick` per frame) — the one-thumb way to watch the hand.
- **Long-press the centre pill** → **D2** frame list (sheet M): rows 44 = mono index + text;
  the last row bold with a target icon (the decision point); the current row gold-tinted; tap
  → `setNav(i)`.
- The spot opens **on the decision frame** (`navIndex = last`) *(desktop)*; a 1.2 s hint
  "◂ swipe to replay the action" *(new)* shows over the table the first five times only.
- Answering snaps to the decision frame. Scrubbing after answering is allowed; the feedback
  panel drops to compact while a finger is on the table and returns when it lifts.

### 5.3 Answering and the feedback panel (D1)

Tap an option → `answer(action)`; press-scale 0.97; medium haptic; all options lock; accepted
option(s) turn `good`, a wrong pick turns `bad`, the rest dim *(desktop)*. Then **D1** slides up
from behind the answer row (280 ms spring; reduced motion: appears):

```
┌──────────────────────────────────────────┐
│   (table visible, dimmed 20 %)           │
│ ┌──────────────────────────────────────┐ │ panel top at y ≈ 300 (compact) / 92 % (expanded)
│ │ ⊗  Not optimal                  −6   │ │ header: badge 28 (bad ✕ / good ✓) · verdict · rating delta (mono)
│ │ That choice costs about 1.2 bb every │ │ EV-loss line, bad colour (only wrong & > 0.05 bb):
│ │ time — a real leak.                  │ │ "…— a small leak | a real leak | a blunder-sized leak."
│ │──────────────────────────────────────│ │
│ │ You're getting 3:1 and this hand     │ │ LAYER 1 · rationale (verbatim)
│ │ wins about 1 time in 3 — the call    │ │
│ │ makes money.                         │ │
│ │ Folding: 0 bb — costs nothing more.  │ │ per-option outcomes box (only when equity, potOdds,
│ │ Calling: +2.6 bb per try — your hand │ │ toCall > 0 exist), verbatim templates
│ │ wins about 1 time in 3 and you need  │ │
│ │ about 1 time in 4.                   │ │
│ │ ▸ Show me the math                   │ │ LAYER 2 · "Equity: 33% · Pot odds: 25%" + steps (new)
│ │ ▸ See the range it was graded against│ │ LAYER 3 · read-only matrix 260 + gradeRangeTitle
│ │ ┌───────────────┐ ┌────────────────┐ │ │
│ │ │ 📖 Pot Odds… │ │ ◎ Drill 5 similar│ │ │ secondary row 48: lessonTitle ?? "Read the lesson" ·
│ │ └───────────────┘ └────────────────┘ │ │ "Drill 5 similar" (practice, non-leak only)
│ │ 4 more of this spot type coming up   │ │ faint caption when focusLeft > 0 (verbatim)
│ │ ┌──────────────────────────────────┐ │ │
│ │ │          Next puzzle           › │ │ │ primary 56, pinned at the panel's bottom
│ │ └──────────────────────────────────┘ │ │
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

- **Detents**: compact (header + EV line + rationale + Next; ≈ 300–360 pt) and expanded (92 %).
  Opens compact; opening a disclosure expands. **Dragging down past compact does not dismiss**
  and the scrim is inert — the verdict stays until Next (desktop parity). System back →
  compact (§2.5).
- **Three layers, always**: layer 1 = verdict + EV-loss line + rationale (+ the outcomes box);
  "Show me the math" = the "Equity: 33%" / "Pot odds: 25%" line *(desktop)* plus the EV
  arithmetic as steps *(new)*: "Pot 24 + call 8 = 32 · 33 % × 32 − 8 ≈ +2.6 bb"; when neither
  value exists the row opens to "No math for this one — it's a chart spot." *(new)*. Row 3 =
  "See the range it was graded against" / "Hide the range" *(desktop)*, or "Expert detail:
  no range for this spot" *(new)* for leak puzzles without `gradeRange`.
- **Rating delta** "+12" / "−6" in the header (practice modes only), then after 600 ms flies to
  the stats strip whose Rating rolls to the new value (200 ms). Review mode: no delta.
- **Lesson link** → S1 as a **full-screen modal over Drills** ("Done" returns to the same
  answered spot with the panel still up).
- **Next puzzle** → `next()`; also reachable by **overscrolling the expanded panel** (a small
  "release for next" hint at 60 pt of overscroll) for one-thumb chains.
- Streak: a correct answer pulses the streak number once; a wrong one resets it with a 200 ms
  shake. `notification.success` on correct, `notification.warning` on wrong. No sounds.

### 5.4 Rating, accuracy, streak, daily goal — display rules

| Element | Where | Copy / behaviour |
|---|---|---|
| Rating | stats strip (gold mono) | "Rating {int}"; tap → D3 |
| Accuracy | stats strip | "{round(correct/solved×100)} %"; "0 %" when nothing solved |
| Streak / Best | stats strip | "streak {n} · best {n}" |
| Today | second line | ring + "{min(today,20)}/20 today"; gold when met; tap → D3 goal copy |
| Day streak | second line | "Day streak {n}"; hidden at 0; never counts down |
| Tab badge | Drills tab | Review due count |

### 5.5 Review / "My leaks" queue

Review serves a uniform random pick from due leak spots and due missed drills. Presentation is
the standard spot with three differences:

1. Source pill "Your flagged spot" for leak puzzles; frames verbatim ("Pre-flop." / "Flop: Ah
   7d 2c" / "Action on you in the CO facing 2.0 bb. What's the play?").
2. The feedback header adds a **schedule line** *(new)*: "Back in 10 minutes" (wrong) · "Next
   in 1 day · 1 of 3" · "Next in 3 days · 2 of 3" · "Retired — beaten 3 times" (correct,
   graduated).
3. Feedback for the last due card **stays visible until Next** (fixes the desktop
   vanishing-feedback quirk); Next then shows the empty state.

Empty state (centred, 48 pt `good` check badge):

```
┌──────────────────────────────────────────┐
│ Drills                             [ⓘ]   │
│ ⟨ Mixed ⟩⟨ Push / Fold ⟩⟨ Exploits ⟩⟨ Review ● ⟩│
│                                          │
│                  ✓                       │
│         Nothing due right now            │ or "No spots to review yet" (totalCards == 0)
│  All 7 of your review spots are          │ verbatim bodies (desktop §8.2)
│  scheduled for later — spaced practice   │
│  sticks best when you come back to it.   │
│  Play or drill in the meantime.          │
│  Next due: tomorrow 09:14                │ (new) earliest srs.due, local time; hidden when none
│ ┌────────────────┐ ┌───────────────────┐ │
│ │ ▶ Play a session│ │ ◎ Drill Mixed     │ │ 48 secondary
│ └────────────────┘ └───────────────────┘ │
└──────────────────────────────────────────┘
```

### 5.6 Push/Fold and ICM specifics

Push/fold spots have exactly two options → two 56 pt buttons ("Fold" · "Shove 12 bb" /
"Call 11 bb"). A **stacks strip** (28 pt, mono 12) sits between the table and the navigator with
the verbatim frame text ("Stacks 12 bb · Blinds 0.5/1 · Nash chip-EV, no antes").

```
│   ╭──────────────────────────────────╮   │
│   │  UTG Fold   MP Fold   CO Fold    │   │
│   │        (BTN) ▯▯  In hand         │   │
│   │        PRE-FLOP · 1.5 bb         │   │
│   │  SB  You ◆ 12 bb      BB ▯▯ In hand │ │ live stacks as plate captions
│   ╰──────────────────────────────────╯   │
│ ┌ BUBBLE · 4 left, 3 paid · 50 / 30 / 20 ┐│ ICM banner (gold outline, 36) + scenario name
│ │ Chip leader in the BB                  ││
│ └────────────────────────────────────────┘│
│ Stacks 12 bb · Blinds 0.5/1 · Nash chip-EV, no antes │ stacks strip
│ ‹‹  ‹  ● 3 / 3 Folded to you in the SB with 12 bb. Shove or fold?  ›  ›› │
│ Your hand  A5s            Push/Fold · computed Nash │
│ ┌───────────────────┐┌───────────────────┐ │
│ │       Fold        ││    Shove 12 bb    │ │
│ └───────────────────┘└───────────────────┘ │
```

ICM bubble spots (`icm: true`, a third of push/fold reps) add the banner; the four live stacks
label the SB/BB/other plates ("45 bb", "15 bb"); CO/BTN plates read "In hand" *(desktop)*. The
feedback's layer 1 includes the verbatim `icmNote`; the grading-range row is titled "ICM SB
shoving range — Chip leader in the BB". Mixed-frequency hands (0.2 < freq < 0.8) accept either
answer with the verbatim "Either answer is fine here — this hand is a mix in the equilibrium."

### 5.7 Exploits mode

Exploit spots name the opponent type in the frame text ("The button is a Calling Station…").
The drill table rings that seat's plate in the archetype colour and shows its HUD numbers
("46/7"), so the HUD-reading skill from Play carries over. Layer 2 shows both numbers the
desktop shows (balanced vs exploitative) as two mono lines.

### 5.8 Placement test (D5)

Full-screen modal, no tab bar, from Onboarding (O0 page 5) and Settings → "Run again". Eight
questions, one per screen, auto-advance:

```
┌──────────────────────────────────────────┐
│ ✕                          ▰▰▰▱▱▱▱▱     │ 8-segment progress (3 of 8 done)
│ QUESTION 4 OF 8                          │ eyebrow (verbatim "Question 4 of 8")
│                                          │
│ A flush draw on the flop (9 outs, two    │ Bricolage 22
│ cards to come) has roughly what chance   │
│ of hitting?                              │
│ ┌────────────────────────────────────┐   │
│ │ About 18%                          │   │ options 56, full width, shuffled (Fisher–Yates once)
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ About 36%                          │   │ tapped → good/bad tint 350 ms, then advance
│ └────────────────────────────────────┘   │
│ ┌────────────────────────────────────┐   │
│ │ About 9%                           │   │
│ └────────────────────────────────────┘   │
│ No grade, no judgment — you can stop     │ faint footer (new)
│ any time.                                │
└──────────────────────────────────────────┘
```

Questions, options and shuffling are the desktop's (`design-brand-onboarding.md` §12.5).
Intro page *(verbatim)*: "Eight quick questions calibrate the drills to your level — harder
spots if you're experienced, clearer ones if you're new. No grade, no judgment, and you can
skip it." — "Skip — start playing" (ghost) · "Calibrate me" (primary). Result page: gold card
with the headline ("Starting fresh — perfect." / "You know the basics." / "Solid foundations.")
and "{score}/8 — drills are calibrated to match. {advice}"; buttons "Take me there" (secondary →
`hand-rankings` / `pot-odds` / `threebet-pots`) and "Start playing" (primary → Home). Seeding ≤
2 → 900, ≤ 5 → 1050, else 1250 (`seedRating`, keeps solved/correct/streak/best). ✕ mid-quiz →
`markOnboarded()`, rating untouched. System back = previous question; on Q1 a subtle shake.

---

## 6. STUDY

The desktop's two-pane course becomes list → reader. Lesson ids are a public contract
(`docs/port/study-curriculum.md` §1.2); mobile changes nothing about content, order, minutes or
completion rules. Completion is explicit ("Mark complete"); "Next lesson" never completes.

### 6.1 Study root (S0)

```
┌──────────────────────────────────────────┐
│ Study                                    │ 59–103
│ Your progress                    7/31    │ label + mono; ProgressBar 4 pt gold under it
│ ━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░░░░░░░░░   │
│ ┌──────────────────────────────────────┐ │
│ │ ▤ Continue: Pot Odds, Break-even & EV│ │ Continue card 72 (first incomplete in path order)
│ │ Level 3 · 6 min read                 │ │ → S1
│ └──────────────────────────────────────┘ │
│ TOOLS                                    │ eyebrow
│ [Range explorer][Equity calc][Pot odds]  │ 2×3 grid of 44-tall tool tiles (icon + label) → S3
│ [Bluff calc][Multiway][Hand rankings]    │
│ ▤ Quick reference & glossary          ›  │ pinned row 56 → S4
│ L1  Basics                         3/3   │ level header 48: icon tile 28 gold-tinted · "L1" faint · title · mono count
│  ● Hand Rankings                    4m   │ lesson rows 52: 16 pt circle (good + check when done,
│  ● Position & the Button            5m   │ outline otherwise) · title (1 line, ellipsis) · faint mono minutes
│  ● Bankroll & Mindset               4m   │
│ L2  Pre-flop                       2/4   │
│  ● The 13×13 Matrix                 5m   │
│  ● Opening Ranges by Position       6m   │
│  ○ 3-Betting                        5m   │
│  ○ Reading the HUD: VPIP & PFR      5m   │
│ L3  Post-flop                      2/9   │ level headers are sticky while their lessons scroll
│  …                                       │
│ ┌────┬────┬────┬────┬────┐               │
└──────────────────────────────────────────┘
```

- Levels are always expanded (31 rows scroll; no accordion — one less tap and the sticky
  header keeps orientation). The active/last-read lesson row is gold-tinted 15 %.
- Progress "7/31" and `pct` from `studyStore.completed` *(desktop)*.
- Tools (S3) and Quick reference (S4) are pushes; the same widgets also appear inside their
  lessons (Level 5) — the tool screens are the lessons' widgets given the full screen with the
  lesson's lead paragraph as an intro.

### 6.2 Lesson reader (S1)

Push, tab bar hidden. Body blocks are the desktop prose blocks (Lead, P, H, UL, Callout, Row
grids, cards, widgets) rendered at Inter 16/1.55, headings Bricolage 22, content width 358.

```
┌──────────────────────────────────────────┐
│ ‹   POST-FLOP                 7/31  ⋯    │ 59–103 back · eyebrow (level, gold @80 %) · progress · ⋯ (Mark complete / Glossary)
│ Pot Odds, Break-even & EV                │ Bricolage 28
│ 6 min read                               │ faint 13
│ ┌──────────────────────────────────────┐ │
│ │ Lead paragraph (Inter 17 medium)…    │ │
│ └──────────────────────────────────────┘ │
│ Body paragraph with a dotted term like   │ dotted gold underline = S2 popover on tap
│ pot odds and equity …                    │
│ ┌──────────────────────────────────────┐ │
│ │ (PotOddsCalculator widget, full      │ │ widgets render inline at full width; the range
│ │  width)                              │ │ matrices render at 346 (§6.5)
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ ◎ Practice            optional       │ │ Quiz card (§6.4)
│ │ …                                    │ │
│ └──────────────────────────────────────┘ │
│ ─────────────────────────────────────── │ footer (top border, 32 pt above)
│ ┌───────────────────┐ ┌────────────────┐│
│ │   Mark complete   │ │  Next lesson › ││ 48: primary (or disabled "✓ Completed") · outline
│ └───────────────────┘ └────────────────┘│
└──────────────────────────────────────────┘
```

- Widget state resets per visit (React key parity): sliders, painted ranges and quiz picks
  are not persisted; quiz *results* are (`allin.quiz.v1`).
- Scroll position resets to top on lesson change. A thin gold read-progress line (2 pt) runs
  under the top bar as the user scrolls.
- "Next lesson" → replaces the route (no stack growth). Last lesson: the button is absent.
- Opened from a drill (D1) or the placement result: presented as a **full-screen modal** with
  "Done" instead of `‹`; Done returns to the exact prior state.
- Long-press any paragraph → "Copy" only (no share; keeps the reader quiet).

### 6.3 Term popover (S2)

Every `Term` (dotted gold underline, underline offset 2) is a 44-tall tap target (line-height
slop). Tap → anchored popover ≤ 280×180: term in Bricolage 15 gold-light, definition Inter 14,
and a "Open glossary ›" text button (→ S4 scrolled to the term). Tap outside / scroll / back
closes. The same popover is used by every ⓘ on the coach sheet and the Stats explainers when
the content is one definition (`GLOSSARY` is the single source of truth).

### 6.4 Quiz (in-lesson)

Card: radius 16, `info` @ 25 % border, `info` @ 6 % fill, 16 pt padding. Header: target icon
16 + "Practice" + pill "optional". Sub-line *(desktop)* "Test yourself — this doesn't affect
lesson completion." (+ warn-coloured "You missed {n} of these before — they're up first." when
applicable). Questions in display order: "{i}. {q}"; option buttons 48 tall (letter badge
20×20 A/B/C by display position, text left-aligned); after answering the correct option gets
the `good` style + check badge, a wrong pick the `bad` style + ✕, others neutral, all disabled;
feedback line "Correct. " (good) / "Not quite. " (warn) + `explain`; "Try again" gold text
button when wrong. Shuffling and ordering per `study-curriculum.md` §4.2–4.3.

### 6.5 Embedded widgets — mobile rendering rules

All widgets keep the desktop state, math, pins and copy (`study-curriculum.md` §12); only the
layout changes. Shared rules: sliders are `AllInSlider` (44-tall hit band, 16 pt gold thumb,
haptic tick per step); Fields are label-left / mono value-right over the slider; Result tiles
are `StatTile`; every big number is mono or Bricolage; every card is full content width.

| Widget | Mobile layout |
|---|---|
| **HandRankings** | Ten rows 64 tall: rank circle 28 · name Inter 15 semibold · five cards 32×45 · example line faint. |
| **PotOddsCalculator** | Fields stacked (Pot before the bet 1–60 · Opponent's bet 0.5–60); Result tiles in one 3-column row (You risk · To win · Getting); gold box "Break-even equity" (Bricolage 32) + formula line; Field "Your equity estimate" 0–100; verdict box two columns (EV of calling · Decision "Call"/"Fold"). |
| **BluffCalculator** | Fields stacked (Pot · Your bet "{bet} bb ({pct} pot)" 0.5–90); two result boxes stacked: gold "If you're bluffing" · plain "If they call you", each with its verbatim caption. |
| **MultiwayEquityTrainer** | Scenario chips in a wrapping row (36 tall, hit 44); hero cards 40 + "on" + board 36; Field "Opponents" 1–5; big number Bricolage 36 (good ≥ 0.6, gold ≥ 0.4, bad) + caption "equity vs {n}"; the five-column bar chart (columns are 44-wide tap targets; tap sets `opp`); footer paragraph verbatim. Bars show a shimmer until all five results arrive. |
| **RangeExplorer** | Preset chips row (h-scroll, 36/44: "UTG ~14%" … "BB defend ~55%", "Clear"); editable `RangeMatrix` 346 (§4.9 paint spec, loupe on); legend + "{combos} combos · {pct} of all hands"; paragraph verbatim. |
| **EquityCalculator** | Stacked, not side-by-side: segmented "Range / Hand"; **Your range** matrix 346 (or hand-mode card picker); **Opponent's range** matrix 346; legend; **Board (n/5)** with the 52-card grid as **S5 Card keypad** (sheet M) opened by tapping the board slots; footer summary + "Calculate equity" (56, primary; "Calculating…" busy); result panel (equity, stacked bar, Win/Tie/Lose, samples/exact, blockers line); breakdown cards. Tapping either matrix's "Edit" opens **S6 Range editor** (full-screen, the §4.9 painter with Done). |
| **RangeBoardBreakdown** | One card per range: title, made-hand rows (label · combos · pct bar), draws row, blockers line — as desktop, single column. |
| **Study mini-drills** (Pot-odds · Outs → equity · Range-building) | Shell card: title · mono "Score {r}/{t}"; prompt Inter 16; option grid 2×2 (48 tall, mono values); "Correct. " / "Not quite. " explain line; footer button "New spot" / "Check" / "New drill" (48). Range-building uses the editable matrix 346 and compare colouring + "{pct} match". |

**S5 Card keypad** (sheet M, 420 tall): four suit rows × 13 rank keys (26×36, hit 44 via row
height 44), rank "T" shown as "10", suit-coloured glyphs; used cards (board/hero) disabled at
30 %; a header "Board · 2/5" with the picked cards as XS cards and a "Clear" text button;
"Done" (48). Tapping a key toggles; the sheet stays open until Done (multi-pick).

**S6 Range editor** (full-screen modal): the §4.9 painter (headers, loupe, undo, presets
incl. "Any two" and "Clear") with title "Your range" / "Opponent's range" and "Done" (system
back = Done, keeps edits).

### 6.6 Tool screens (S3)

Each tool is a push with the lesson lead as intro and the widget at full width: **Range
explorer** (`range-explorer` lead), **Equity calculator** (`equity-calculator` lead), **Pot-odds
calculator** (lead from `pot-odds`: the widget's own intro sentence), **Bluff calculator**,
**Multiway trainer**, **Hand rankings**. Title bar: `‹` · title · "Open lesson ›" text button.

### 6.7 Quick reference + Glossary (S4)

Push. A search field (44, "Search terms and numbers") filters both. Sections are the
`cheat-sheet` lesson's five headings rendered as `Row(k, v)` cards (k Inter 14 · v mono 13
gold-light) in one column, then **Glossary** as one row per entry (term Inter 15 semibold ·
definition Inter 14 muted), in glossary order. Caption *(desktop, adapted)*: "Every term below
is also tappable wherever it appears in a lesson." Deep link `/study/glossary#potOdds` scrolls
to and flashes a term (from S2 "Open glossary").

---

## 7. STATS — "Progress" (T0)

Every desktop card survives; the order is re-cut for a phone: the three questions a learner
asks first ("am I improving?", "what's my leak?", "which hand was that?") come first. Every
number keeps its desktop derivation (`persistence-stats-settings.md` §7) and every dotted label
or ⓘ opens **T1** with the verbatim tooltip. Charts are scrubbable; nothing depends on hover.

### 7.1 Wireframe (390×844; scrolls)

```
┌──────────────────────────────────────────┐
│ Your progress                       [⚙]  │ 59–103 title (desktop h1); gear → X0
│ Decisions, not results — but we track    │ desktop subtitle, muted 14
│ both.                                    │
│ ┌────────┬────────┬────────┬────────┬────┐│ KPI row (h-scroll if needed): 5 StatTiles 72 tall
│ │ Hands  │ Net    │Win rate│Showdown│Read││ label eyebrow · value mono 20 · sub faint
│ │ 412    │+38.5 bb│ +9.3 ⓘ │ 52 %   │64 %││ Net/Win rate good/bad by sign
│ │        │        │bb/100  │ won    │19 rd││
│ └────────┴────────┴────────┴────────┴────┘│
│ CUMULATIVE WINNINGS (bb)                 │ card: LineChart 170 tall, scrub → T4 value sheet
│ ┌──────────────────────────────────────┐ │ (touch-and-hold shows a crosshair + "Hand 212 · +31.5 bb"
│ │      ╱╲    ╱╲╱╲                      │ │  in a floating label instead of a sheet)
│ │ ╱╲╱╲╱  ╲╱╲╱     ╲╱╲                  │ │
│ │ - - - - - - - - - - - - - - - - -    │ │ dashed zero line
│ └──────────────────────────────────────┘ │
│ COACHING REVIEW                          │ card
│ ┌──────────┬──────────┬──────────┐       │ three verdict boxes: Mistakes (bad) · Thin spots (warn)
│ │ 14       │ 22       │ 31       │       │ · Great plays (good); mono 22 + eyebrow
│ │ MISTAKES │THIN SPOTS│GREAT PLAYS│      │
│ └──────────┴──────────┴──────────┘       │
│ ⚡ You fold too often when you're getting│ leak sentences (verbatim), bolt icon; tap → H1-style
│    the right price — look for more +EV   │ three-layer sheet (§3.4)
│    calls.                                │
│ Recent −EV decisions                     │ rows 44: "River call vs Nit" · mono bad "17% eq · 25% needed · −2.0 bb"
│  River call vs Nit   17% eq · 25% needed · −2.0 bb │ tap → the hand's replayer at that frame (when the hand is stored)
│ [ Review these spots › ]                 │ secondary 44 → Drills Review (only when dueCount > 0)
│ RECENT HANDS                  [⇩ Import] │ card header + Import button (44) → T3
│ ⟨ all ⟩⟨ review later ⟩⟨ big pot ⟩       │ tag chips 36 (only when tags exist)
│  Hand #41 · Today 18:10       +6.0 bb ✎ │ rows 56 (two lines when a note exists: tag chips + note text)
│  Hand #40 · Today 18:09       −1.0 bb ✎ │ "imported" badge when h.imported
│  All hands ›                             │ → T2
│ HANDS VS EACH STYLE                      │ card: 4 rows (dot · name · signed net · bar tinted by archetype)
│ WINNINGS BY POSITION                     │ card: 6 diverging rows + footnote (verbatim)
│ STYLE NUMBERS                            │ card: WTSD · W$SD · AF rows (dotted labels → T1) + footnote
│ RANGE-READ ACCURACY                      │ card: MiniBars (last 30) + caption "Last 30 Peek scores."
│ PRACTICE                                 │ card: 16-week heatmap, 7 rows column-major, cells 11 + 3 gap
│ ▢▢▣▣▢▣▣ … (16 columns)                   │ tap a cell → tooltip strip "2026-09-03: 24 reps · goal met"
│ 41 active days in the last 16 weeks. …   │ caption verbatim
│ DATA                                     │ card: "Back up (.json)" · "Import hands (.txt)" · "Reset all progress" → X0 Data rows
│ ┌────┬────┬────┬────┬────┐               │
└──────────────────────────────────────────┘
```

### 7.2 KPIs and explainers (T1)

Tiles *(desktop)*: `Hands` · `Net` (`{fmtSigned(netBb)} bb`) · `Win rate` (`fmtSigned(bb100)`,
sub "bb/100 (lifetime)", ⓘ) · `Showdown` (`fmtPct(sdWin)`, sub "won") · `Read acc.`
(`fmtPct(avgAcc)` or "—", sub "{n} reads"). T1 (sheet S) = title + verbatim body; Win rate:
"Big blinds won per 100 hands — the standard, stake-independent win-rate. Roughly: +5 is a
strong winner; expect wild swings under a few thousand hands." Every T1 also renders the two
empty disclosure rows only when there is math behind the stat (Style numbers get "Healthy
range: 24–32%" as the layer-2 content).

### 7.3 Charts

- **Cumulative winnings**: desktop algorithm (`LineChart`), 170 tall, area gradient, dashed
  zero line, last-point dot, min/max labels. Fewer than 2 values → "Play a few hands to see your
  trend." *(desktop)*. **Scrub**: touch-and-hold (200 ms) then drag shows a vertical crosshair
  and a floating mono label "Hand 212 · +31.5 bb" (T4 as an in-chart label; no sheet). Reduced
  motion: no draw-in animation.
- **Range-read accuracy**: `MiniBars` of the last 30 guesses (bar height `max(3, v×100)%`,
  `info`, opacity `0.55 + v×0.45`); tap a bar → its value in a 1.5 s label. Empty: "No reads
  logged yet." *(desktop)*.

### 7.4 Hands vs each style · Winnings by position · Style numbers · Coaching review

Verbatim copy and derivations from `persistence-stats-settings.md` §7.5–7.8. Mobile
specifics: position rows are 44 tall with the diverging bar 8 pt; the three style rows'
dotted labels open T1 with title = label, body = blurb, footer "Healthy range: {band}";
Coaching review's empty state is the verbatim "Play with the EV Coach on and your reviewed
decisions, leaks and mistakes will appear here."; each leak sentence is tappable → the
three-layer sheet of §3.4 (H1) so the numbers behind the sentence are one tap away.

### 7.5 Recent hands (T0) and All hands (T2)

- T0 shows the 5 most recent; **T2** (push) lists `loadRecentHands(100)` with the tag chip
  filter, a "Played / Imported / All" segmented control *(new)*, and rows 56: "Hand #41 ·
  {toLocaleString}" · signed net · ✎ (gold when a note exists). Tap row → **P11** replayer;
  tap ✎ → **P12** note editor; swipe-left → "Note" · "Export" (share this hand's text).
- Empty states *(desktop)*: "Finished hands appear here and stay replayable after a restart."
  / with a filter "No hands carry that tag among the recent ones."

### 7.6 Hand note editor (P12)

Sheet M, keyboard-aware (rises with the keyboard; the Save row stays above it). Title "Note on
hand #41" · description local date-time · textarea (4 rows) with the verbatim placeholder
"What happened, and what's the lesson? (e.g. 'called the river with a bluff-catcher vs a Nit —
their range had no bluffs')" · "Tags" chips (`review later` · `bluff-catch` · `thin value` ·
`weird line` · `big pot` + custom tags on this note; 36 tall, hit 44) · custom field "+ custom,
Enter" (lower-cased on submit) · left "Remove note" (danger ghost, only when a note exists) ·
right "Cancel" · "Save" (disabled when text and tags are both empty). Key = `startedAt`.

### 7.7 Hand replayer (P11)

Push (tab bar hidden) from P10 rows, T0/T2 rows, P2 Log, and Coaching review rows. Uses
`buildReplayFrames(hand)` verbatim (`play-loop-and-coach.md` §21); opens on the **last frame**.

```
┌──────────────────────────────────────────┐
│ ‹   Hand #41 replay                 ✎ ⇪  │ 59–103 back · title · note · share (this hand's text)
│ Dwan raises to 3 bb                      │ 103–127 frame text (Inter 15), crossfades per frame
│   ╭──────────────────────────────────╮   │ 131–491 felt 360: the same table renderer in replay
│   │        (6 / 2 / 9 seats)         │   │ mode — seats at the live anchors, plates position +
│   │      PRE-FLOP · 3.5 bb           │   │ "{stack} bb" at hand start, folded 25 %, hole cards
│   │     ▭   ▭   ▭   ▭   ▭            │   │ when holes[seat] exists && (isHero || revealAll)
│   │  ┌──┐┌──┐  You · BTN             │   │
│   ╰──────────────────────────────────╯   │
│ ⊗ Mistake · Your call · "You paid 8 bb…" ›│ 499–547 coach note strip for THIS frame (when the
│                                          │ hand record carries coachNotes; tap → P3 read-only)
│ ‹‹  ‹   ● 4 / 14                  ›  ›› │ 555–599 scrubber (FrameScrubber): first · prev · pill · next · last
│ ○──────●──────────────────────────────○  │ 607–651 timeline slider 44 (0..last), haptic tick per frame
│                 ▬▬▬▬▬▬                   │
└──────────────────────────────────────────┘
```

- Swipe left/right on the felt = next/previous frame (as the drill navigator). Long-press the
  pill → the full frame list (D2 pattern).
- The **coach note strip** is the mobile addition (notes persisted per hand, §4.8): a note whose
  `street`/`action` match the frame's last action appears under the felt; frames without a
  note show the strip empty (fixed 48 pt so the scrubber never jumps).
- Imported hands: no coach notes; the title carries an "imported" badge; stacks in the site's
  units as written.

### 7.8 Import hands (T3)

Entry: T0 "Import" · T2 header · X0 Data → "Import hands (.txt)". Flow:

1. **System file picker** (`.txt`, `text/plain`). Cancel → nothing.
2. **Progress sheet** (S, non-dismissable while parsing): "Reading hands…" with a determinate
   bar per parsed hand and "Reviewing your calls… 12 of 40" during `analyzeImported` (the
   2 500-sample equity runs happen in an isolate; the sheet can be dismissed to the background
   — a toast appears when done).
3. **Result sheet** (S): the verbatim summary "Imported {n} hand{s}{ (k skipped)} · reviewed
   {r} of your calls · {m questionable one{s} added to the Review queue | no clear mistakes
   found}. Imported hands never count toward your play stats." + buttons "See hands" (→ T2
   filtered to Imported) · "Review now" (only when m > 0 → Drills Review) · "Done".
4. Failure (no hands parsed): "Couldn't find any hands in that file. All-In reads
   PokerStars-style text histories — export a session to see the format." *(new)* with
   "Export a sample" (shares the format) · "OK".

Imported hands are stored with `source = 'import'`, never touch `user_stats`, and appear in T2
with the badge. No "share into app" intent in v1 (§15).

### 7.9 Export / share

- **Session**: P10 "Share" (§4.13). **Single hand**: P11 `⇪` and the T2 swipe action share
  `formatSession([hand])`.
- **Backup**: X0 Data → "Back up all data (.json)" → `exportBackup()` → share sheet with
  `allin-backup-{YYYY-MM-DD}.json` (Save to Files / Drive / AirDrop…). Caption under the row:
  "A safety copy of your stats, decisions, reads and hands. Restore it from this screen on a
  new phone." *(new)*.
- **Restore** *(mobile addition; the desktop has no import of backups)*: X0 Data → "Restore
  from backup…" → picker (`.json`) → **X3** dialog "Restore this backup? Your current stats,
  decisions, reads and hands will be replaced by the backup from {exportedAt date} ({hands}
  hands)." — Cancel · Restore. Notes, leaks, review cards, goals, study and settings are
  untouched (mirrors what `resetStats` leaves alone).

### 7.10 Reset all progress (X2)

Dialog with a typed confirmation: title "Reset all progress?" · description "This permanently
deletes your lifetime stats, decisions, reads, and saved hands." · full-width secondary
"Download a backup first" (→ the backup share; the returned message shown beneath in faint) ·
label "Type RESET to confirm:" + a text field (autocorrect off, capitals on) · ghost "Cancel" ·
danger "Erase everything" enabled only when the field is exactly `RESET`. Reset does not clear
notes, leaks, review cards, goals, study or settings *(desktop)*. After reset: toast "Progress
erased", T0 shows all empty states, the table route shows State G.

### 7.11 Practice heatmap

16 weeks × 7, column-major, oldest left, today the last cell of the last column; cells 11 +
3 gap (the grid is 221 wide, centred); colours `gold` (met) · gold @ 35 % over `ink600` (active)
· `ink700` (none). Tap a cell → a 1.5 s label "{key}: {count} reps{ · goal met}". Captions
verbatim (§7.10 of the port doc). The Home mini-heatmap (§3.5) is the last 5 columns of this
grid.

---

## 8. ONBOARDING

Gate: `allin.onboarded.v1 == "1"` (true if storage throws — never nag). First launch mounts
**O0** as a full-screen modal over the tab scaffold; any close path (`Skip`, ✕, "Start
playing", "Take me there") calls `markOnboarded()`. Settings → "Run again" clears the flag and
presents O0 immediately (no app reload).

### 8.1 Tour (O0, pages 1–4)

```
┌──────────────────────────────────────────┐
│ ✕                              Skip      │ 59–103: ✕ 44 · "Skip" text button 44
│                                          │
│              ┌────────┐                  │ icon tile 72, gold @ 15 %, icon 32 gold
│              │   ▶    │                  │
│              └────────┘                  │
│   Play against real-ish opponents        │ Bricolage 26, centred
│   Four bot styles with genuinely         │ Inter 16/1.5 muted, centred, max 326 wide
│   different tendencies. The EV Coach     │ (verbatim page bodies, design-brand-onboarding §12.3)
│   watches every decision and explains —  │
│   in plain English first — whether it    │
│   made money. At the end of each hand,   │
│   everyone's cards are revealed, folds   │
│   included: that's how you build         │
│   intuition.                             │
│                                          │
│              ● ○ ○ ○                     │ page dots (gold = current and past)
│ ┌──────────────────────────────────────┐ │
│ │               Next  ›                │ │ 56 primary; page 4 reads "Continue"
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

- Title "Welcome to All-In" and the descriptor "A 60-second tour · {n} of 4" live in the
  navigation title (Inter 13 muted under the ✕ row).
- Pages: `play` "Play against real-ish opponents" · `target` "Drill like chess puzzles" ·
  `book` "Study when you want the why" · `coach` "Judge decisions, not results" — bodies
  verbatim. Horizontal paging (swipe) and the Next button both advance; system back = previous
  page; on page 1 a subtle shake.
- Page 4's illustration is a live, non-interactive 3-layer coach note (a real `CoachNoteView`
  with the TONE.md example) so the structure is seen before it is met.

### 8.2 Placement intro and test (O0 page 5 → D5)

Page 5 title "Optional placement"; paragraph verbatim (§5.8); buttons "Skip — start playing"
(ghost 48) · "Calibrate me" (primary 56 → D5 in place, same modal). Result page as §5.8; "Start
playing" → Home in its first-run state (§3.6); "Take me there" → Study → S1 of the advised
lesson (Home is behind it).

### 8.3 First-table coach marks (O1)

Three one-time captions on the first three hands (§4.15). Never repeated; "Run again" resets
them together with the tour.

---

## 9. SETTINGS (X0) + ABOUT (X1)

Push from the gear on Home and Progress. Grouped list, rows 56+ (title Inter 16 · description
Inter 13 muted, 2–3 lines · control right). Subtitle under the title *(desktop)*: "Everything
is saved on this device."

```
┌──────────────────────────────────────────┐
│ ‹   Settings                             │
│ Everything is saved on this device.      │
│ TABLE & CARDS                            │
│  Four-colour deck   [A♠][A♥][A♦][A♣] (●) │ switch; preview cards 26 wide update live
│   ♠ black · ♥ red · ♦ blue · ♣ green.    │ description verbatim
│   Makes suits unmistakable at a glance — │
│   recommended, and essential if you have │
│   trouble telling red suits apart.       │
│  Realistic reveals                  ( )  │ switch; description verbatim
│  Theme            [ Dark ● ][ Light ]    │ segmented (calls set(v), not toggle)
│   Light or dark. ("System" is not offered — the theme is explicit, desktop parity.)
│  Reduce motion                      ( )  │ switch; "Disables animations and transitions. Also honors your system's reduced-motion preference automatically."
│  Haptics                            (●)  │ (new) switch, default on
│ COACH                                    │
│  Strictness  [Relaxed][Standard ●][Strict]│ segmented; description verbatim
│  Simulation quality [Standard ●][High]   │ segmented; description verbatim
│  Always expand "Show me the math"   ( )  │ (new) switch, default off
│ PLAY                                     │
│  Pace / speed / EV Coach / Auto-deal     │ the remembered play settings (§4.1); same controls as P2 Options
│ LEARNING                                 │
│  Tour & placement          [ Run again ] │ description verbatim ("Re-run the first-launch tour and the placement quiz (recalibrates your drill rating).")
│ DATA                                     │
│  Back up all data (.json)             ›  │ → share
│  Restore from backup…                 ›  │ → picker → X3
│  Import hands (.txt)                  ›  │ → T3
│  Reset all progress                   ›  │ danger text → X2
│ ABOUT                                    │
│  About All-In · Version 1.2.0         ›  │ → X1
│ ┌────┬────┬────┬────┬────┐               │
└──────────────────────────────────────────┘
```

- Persisted as `AppSettings` (`fourColorDeck`, `reducedMotion`, `coachStrictness`,
  `simQuality`, `realisticReveal`) + mobile additions `haptics`, `alwaysExpandMath`, and the
  play settings (`paceMode`, `speedMs`, `coachEnabled`, `autoDeal`).
- The desktop "Keyboard" card is dropped (no shortcuts on a phone; hardware keyboards are
  handled silently — §15). Theme quick-toggle in the sidebar → dropped; the Theme row is enough.
- Changing Four-colour deck or Theme applies instantly everywhere (including a paused table).

**X1 About** (push): hero card (logo 64, "All-In · Poker Dojo", the verbatim description
paragraph, version pill "Version {x.y.z}"); "How to use it" four cards (verbatim, with "click
the eye" → "tap the eye" and "Hover any dotted term" → "Tap any dotted term" — the only two
permitted edits); "Good to know" bullets (verbatim; "SQLite on desktop, browser storage on the
web" → "everything is stored on this phone"); "How the grading works" (verbatim); "On the
roadmap" (verbatim list; the desktop auto-update and PWA rows are dropped, replaced by
"Hand-history import from more sites" and "Share a hand as an image" *(new)*); "Built by"
(Gapp · www.gapp.in · "Designed and built by Gapp. Made with Flutter and Dart. Thanks for
playing — feedback is always welcome."); footer "All-In · Poker Dojo — © Gapp". The passive
GitHub release check is dropped (store channel); a "Rate All-In" row *(new)* opens the store
listing. External links open in the system browser (`url_launcher`, external mode).

---

## 10. COMPONENT LIBRARY (`lib/widgets/`)

Every feature reuses these; none re-implements a card, a pill or a matrix. Names are the Dart
class names. Variants are constructor parameters or named constructors.

### 10.1 Foundations

| Widget | Purpose | Variants / props |
|---|---|---|
| `AllInScaffold` | Page scaffold with safe areas, large title (Bricolage 28), optional gear/trailing actions | `title`, `subtitle`, `actions`, `body`, `bottom` (pinned slot above the tab bar / inset) |
| `AllInButton` | The only button | `.primary` (gold fill, ink900 text) · `.secondary` (ink600) · `.outline` (1 pt lineStrong) · `.ghost` (text only) · `.danger` (ink700 fill, bad text/border) · sizes `md` 48, `lg` 56, `sm` 36 (hit 44) · `leading`/`trailing` icon · `busy` |
| `AllInSegmented` | 2–4 way segmented control | `labels`, `value`, `onChanged`, 36 tall (hit 44) |
| `AllInSwitch` | Adaptive switch (Cupertino / M3), gold on | — |
| `AllInSlider` | Single-thumb slider, gold fill, 16 pt thumb, 44 hit band, haptic per step | `min`, `max`, `step`, `detents` |
| `AllInCard` | Surface card | `.plain` (ink800, line border, radius lg) · `.glass` (ink800 @ 92 %) · `.gold` (gold @ 6 % fill, gold @ 25 % border) · `.info` (info tint) |
| `Eyebrow` | Small caps label (`AllInText.eyebrow`) | `color` |
| `StatTile` | Label + mono value (+ sub) | `tone` (neutral/good/bad/gold), `onInfo` (→ explainer), sizes 72 / 96 |
| `DisclosureRow` | 48 pt row "▸ Show me the math" that expands inline; rotates chevron | `label`, `expandedLabel`, `child`, `tone` (gold/muted), `alwaysRendered: true` |
| `TermText` | Inline text with dotted-underline glossary terms → `TermPopover` | `text`, `terms` |
| `TermPopover` | Anchored ≤ 280×180 definition | `termId` |
| `AllInSheet` | Bottom sheet wrapper: grabber, detents S/M/L, table cap, `dismissible`, `blocking` | `detent`, `child`, `onClose` |
| `AllInDialog` | Adaptive alert (Cupertino / M3) | `title`, `body`, `actions`, `.typed(confirmWord)` |
| `AllInToast` | 44 pt pill at the top of the content area, 2.5 s | `text` |
| `ProgressBarThin` | 4/8 pt gold bar | `value`, `max`, `height` |
| `HeatmapGrid` | 7-row column-major heatmap | `weeks`, `cells`, `cellSize`, `onTapCell` |
| `SparkLine` / `LineChart` / `MiniBars` / `DivergingBar` | Chart primitives (CustomPainter) | per §7 |

### 10.2 Navigation & shell

| Widget | Purpose |
|---|---|
| `TabScaffold` | `StatefulShellRoute` host: 5 tabs, M3 `NavigationBar` / Cupertino-sized bar, badge on Drills, hides on listed routes |
| `SessionPill` | 56 pt "● 12 hands · +4.5 bb · Resume ›" above the tab bar; swipe-left → End session |
| `PlanCard` | Home plan card (`primary: bool`, icon, title, subtitle, estimate, `button`) |
| `CoachCard` | Home coach's note card with "Show me why ›" |
| `GoalCard` | Bar + "8 of 20" + caption |

### 10.3 Table & cards

| Widget | Purpose | Props |
|---|---|---|
| `PlayingCardView` | Card face/back; four-colour aware; sizes XS 22×31 · S 30×42 · M 44×62 · L 52×73 · XL 72×101 · XXL 80×112 | `card`, `size`, `faceDown`, `dimmed`, `glow` |
| `FeltCanvas` | The felt shape (rail, gradient, hairline) + anchor system in fractions | `layout` (hu/six/nine), `child` builder with `anchor(fx, fy)` |
| `SeatPlate` | Opponent plate (standard 104×58 / compact 84×50 / HU 160×64) with avatar ring, name, position pill, stack, HUD, eye glyph, turn ring, dealer disc, tucked cards | `player`, `variant`, `state` (idle/toAct/folded/allIn/winner), `showEye`, `onTap`, `onEye`, `onLongPress` |
| `BetPill` | 22 pt chip-glyph + mono amount at a bet spot; also renders action pills (Raise/Call/Check/Fold colours) | `kind`, `amount` |
| `PotPill` | "PRE-FLOP · Pot 4.5 bb" (street eyebrow + mono) | `street`, `pot` |
| `BoardRow` | Five slots (dashed placeholders) with deal-in animation | `cards`, `size` |
| `HeroHand` | Two hero cards with lift/glow | `cards`, `size`, `active` |
| `HeroStrip` | Position pill · stack · price line / hand label | `position`, `stack`, `priceLine`, `handLabel` |
| `SizingRail` | 48 pt band, seven detents, knob, readout, magnet ticks | `min`, `max`, `detents`, `value`, `onChanged` |
| `ActionRow` | The 56 pt row in States A–G | `state`, callbacks |
| `CoachChip` | 300×40 verdict chip | `verdict`, `title`, `clause`, `onTap` |
| `CoachBadge` | Top-bar `[◉ 3]` | `count`, `verdict` |
| `Ticker` | 18 pt last-log line with kind colours | `entry` |
| `ResultsCard` | Lower-felt results overlay with reveal rows | `summary`, `rows`, `onRow`, `onReadSeat` |
| `TurnRing` | 2 pt gold ring with breathing / arc modes | `mode` |
| `ChipStack` | 3-disc chip stack used by bet/pot animations | `amount`, `color` |

### 10.4 Range

| Widget | Purpose | Props |
|---|---|---|
| `RangeMatrix` | The 13×13 grid (CustomPainter + gesture arena) | `.readOnly(highlight)` · `.editable(value, onChanged, undoController)` · `.compare(painted, actual)` · `size` (346 / 260 / 300) · `showHeaders` · `loupe` · `hatchWhenNoColour` |
| `RangeLegend` | Pairs/Suited/Offsuit or Correct/Missed/Extra | `mode` |
| `RangePresetRow` | h-scroll chips (Top n %, position opens, Any two, Clear) | `presets`, `onPick` |
| `ComboCounter` | "148 combos · 11 % of hands" | `combos` |
| `RangeMatrixLoupe` | 56 pt magnifier bubble | internal |

### 10.5 Coach

| Widget | Purpose |
|---|---|
| `CoachNoteView` | The three-layer anatomy: header (verdict disc, label, kind · title · street, optional XS cards + situation line), layer 1 paragraph, optional equity bar, optional multiway callout, `DisclosureRow` × 2 (always rendered), EV tile, button row. Used by P3, H1, D1 (as `.drill()` variant with the verdict header and outcomes box), T0 leak sentences, peek result card (`.peek()`) |
| `VerdictBadge` | 24/28/32 disc with ✕ / i / ✓ / eye in verdict colour |
| `EquityBar` | 10 pt bar + needed marker + caption |
| `CoachNotesList` | P4 rows |

### 10.6 Drills

| Widget | Purpose |
|---|---|
| `DrillTable` | Fixed 6-anchor felt with position plates, frame board/pot, hero cards |
| `FrameScrubber` | `‹‹ ‹ ● 5/6 · text › ››` row; long-press → frame list |
| `AnswerRow` | 2–3 option buttons with post-answer colouring |
| `FeedbackPanel` | Two-detent panel (compact/expanded), inert scrim, Next pinned |
| `ModeChips` | Mixed · Push / Fold · Exploits · Review (count) |
| `StatsStrip` | Rating · accuracy · streak · best (+ Today line) |
| `StacksStrip`, `IcmBanner` | Push/fold extras |

### 10.7 Study & stats

`LessonList`, `LessonReader` (block renderer), `QuizCard`, `PotOddsCalculator`,
`BluffCalculator`, `MultiwayTrainer`, `RangeExplorer`, `EquityCalculator`, `CardKeypadSheet`
(S5), `RangeEditorScreen` (S6), `HandRankingsList`, `RangeBoardBreakdownCard`,
`StudyMiniDrill` (three variants), `KpiRow`, `CoachingReviewCard`, `HandRow`, `TagChips`,
`HandNoteEditorSheet` (P12), `ReplayerScreen` (P11), `ImportFlow` (T3), `ResetDialog` (X2).

---

## 11. MOTION + HAPTICS

Curves: `AllInMotion.ease` (0.2, 0.8, 0.2, 1) for UI; `easeOut` for exits. Durations are the
`AllInMotion` tokens unless listed. **Reduced motion** (setting or OS): every duration → 0 via
`AllInMotion.of(context, d, reduced:)`; cards/chips appear in place; rings are static; numbers
snap; sheets still slide (system-driven) but without spring overshoot; the deal countdown is a
static caption.

| Event | Motion | Duration | Haptic |
|---|---|---|---|
| Sheet open / close | slide + 40 % scrim fade | 250 / 200 | — |
| Full-screen modal | slide up (iOS) / fade-through (Android) | platform | — |
| Push | platform | platform | — |
| Button press | scale 0.97 | 120 | medium on commit (Fold/Call/Raise/Next/Got it/answers); light on toggles |
| Deal: hero cards | slide from pot centre + flip | 280, stagger 60 | light when the 2nd card lands |
| Deal: opponent backs | pop in around the ring | 200, stagger 40 | — |
| Bot think (Auto) | HUD → dots shimmer; arc sweeps | 0–150 | — |
| Action pill pop | scale 0.8→1 | 200 | light (raise only, Auto) |
| Chips plate → bet spot | slide + stack count-down | 250 / 120 | — |
| Turn ring hop | crossfade | 120 | — |
| Fold | cards slide 20 pt behind plate, fade 30 % | 220 | — |
| Street closes | pills + chips to pot (stagger 30/seat) → pot rolls → board deals | 280 → 200 → 340 each, stagger 60 | — |
| Hero's turn | cards lift 6 + glow; action buttons slide up 8 | 200 | light (once) |
| Coach chip in / to badge | spring scale 0.9→1 / shrink-to-badge | 260 / 200 | light (great/ok), medium (thin), warning (mistake) |
| Blocking sheet | felt dims 60 %, sheet slides | 250 | notification.warning |
| Sizing rail | knob follows finger; magnet ±6 pt | 0 | selectionClick per detent |
| Range paint | cell fill | 80 | selectionClick per cell (≥ 30 ms apart) |
| Peek reveal | crossfade | 200 | medium; success when "Sharp read" |
| Showdown flips | two half-flips, stagger 60 | 150 + 150 | — |
| Pot to winner | slide + stack count-up; "+6.5 bb" float | 420 / 300 | success on hero win |
| Results card | slide up over the lower felt | 240 | — |
| Drill answer | option tints | 120 | medium |
| Feedback panel | spring up | 280 | success (correct) / warning (wrong) |
| Rating delta → strip | fly + roll | 600 + 200 | — |
| Frame scrub | table crossfade | 150 | selectionClick per frame |
| Toast | slide down / up | 200 | — |
| Goal met | bar completes (no confetti) | 300 | light |

Haptics use `HapticFeedback` (`lightImpact`, `mediumImpact`, `selectionClick`) and the platform
notification patterns via a small `Haptics` service; all gated by Settings → Haptics.

---

## 12. GESTURES + REACHABILITY

**Thumb zones at 390×844** (right-handed grip; mirrored for left): *easy* y ≥ 560 and x ≤ 300;
*stretch* y 380–560; *far* y < 380. Rule: anything used every few seconds is *easy*; once a
minute is *stretch*; rarer is anywhere.

| Gesture | Where | Result |
|---|---|---|
| Tap | everywhere | the visible affordance |
| Tap the felt (not a seat/board/pot/pill/chip) | Table, Manual | one bot action; Auto: pause/resume |
| Long-press "Next action" | Table | hold to fast-forward at Fast until hero's turn / hand-over |
| Tap ⏭ | Table, Auto | skip to my turn |
| Drag on the sizing rail | Table, State A | set the raise size; release never commits |
| Tap rail label / tick | Table | jump to the detent |
| Tap the Raise amount / long-press Raise | Table | P13 keypad |
| Tap seat eye · long-press plate | Table | P7 Read range |
| Tap plate | Table | P6 Player sheet |
| Tap action pill | Table | Explain last move |
| Tap chip · swipe chip up / down | Table | P3 M · P3 L · dismiss to badge |
| Tap title · ticker · long-press ticker | Table | P2 Session · P2 Log · copy log |
| Swipe up on the hero strip | Table | P2 |
| Touch the results card | Table, hand-over | cancels auto-deal countdown |
| Swipe left / right on the drill table or the replayer felt | Drills, Replayer | previous / next frame |
| Long-press the frame pill | Drills, Replayer | frame list |
| Overscroll the expanded feedback panel | Drills | next puzzle |
| Drag-paint · header tap · header long-press | Range matrix | paint · row/column · "this and better" |
| Swipe-left on a row | Summary / hands lists / Session pill | Note · Export · End session |
| Touch-and-hold + drag on the chart | Stats | scrub crosshair |
| Re-tap active tab | Tab bar | scroll to top |
| System back / edge swipe | everywhere | §2.5 |

Never used: pinch-zoom on the matrix, shake, 3D/haptic touch menus, double-tap on cards,
horizontal swipes between tabs (conflicts with the drill scrubber and back-swipe).

Hit targets: every control ≥ 44×44 (visual ≥ 36 with slop). The two paint surfaces (§4.9 matrix
cells, S6) are exempt and compensated by drag-paint, loupe and header selectors. Hit-slop is
never allowed to overlap a neighbouring control's box; gaps of 8 pt between 44-pt controls.

**Left-handed use**: the action row and rail are symmetric enough (Fold left / Raise right is a
convention worth keeping for muscle memory across devices); no mirror setting in v1 (§15).

---

## 13. ACCESSIBILITY

- **Dynamic type**: all text uses `MediaQuery.textScaler`. Table caps (§4.2.4): felt text ≤
  1.15×, action zone ≤ 1.3× with the felt shrinking to compensate (min 400 pt at 390 wide);
  above 1.3× action labels drop amounts into the hero strip. Sheets, lists, lessons and stats
  scale without limit (rows grow; nothing truncates below 1.5×, ellipsis beyond). Card ranks are
  fixed-size (they are graphics).
- **Colour**: verdict colours always pair with an icon (✕ / i / ✓ / eye) and a word; money
  sign is always printed (+/−); the matrix compare mode adds hatching/dots under
  "differentiate without colour"; the four-colour deck is offered in onboarding page 1's
  footer ("Trouble telling suits apart? Turn on the four-colour deck in Settings." *(new)*).
  Contrast ≥ 4.5:1 for text on all surfaces in both themes (tokens are chosen for this; gold on
  ink900 = 9.8:1; textMuted on ink800 = 5.6:1).
- **Screen readers** (VoiceOver / TalkBack): semantic labels on every control ("Fold", "Call
  2 big blinds", "Raise to 7.5 big blinds", "Next action"); the felt exposes a summary node
  ("Pre-flop, pot 4.5 big blinds, Ivey to act, you are big blind with queen of spades, queen of
  hearts") updated on each action; seats are nodes ("Ivey, button, 100 big blinds, VPIP 22 PFR
  18, raised to 3") with actions "Read range" and "About player". The matrix exposes 13 row
  nodes with 13 cell children ("Ace King suited, painted") and custom actions "Toggle row",
  "Toggle column"; the loupe is hidden. The sizing rail is an adjustable node (increment /
  decrement by 0.5 bb) with the value announced. The coach note reads layer 1 first, then the
  two disclosure buttons. Live regions: the ticker (polite), the coach chip (assertive for
  mistakes), the feedback verdict (assertive).
- **Reduced motion**: §11. **Reduce transparency**: glass surfaces become opaque `ink800`.
- **Hardware keyboard** (iPad-style keyboards on phones, accessibility switches): F / C / R,
  →, Enter, 1/2/3 and Space map to the desktop actions silently; no overlay lists them.
- **Focus order** follows visual order; the blocking sheet traps focus until "Got it".
- **Timeouts**: none that matter — the only timers are the coach chip (reopenable from the
  badge) and the optional auto-deal ring (off by default, cancellable by touch).
- **Language**: English only in v1; all strings live in one ARB-ready table (§16.5) so the
  verbatim coach copy is never split across widgets.

---

## 14. EDGE / EMPTY / ERROR STATES

| Where | State | What the user sees |
|---|---|---|
| Home | first run | §3.6 |
| Home | goal met | "Goal met — anything else is a bonus" |
| Home | no session, no lessons started, no drills | three cards (lesson, quick set, play) + no-data coach line |
| Lobby | never played | dashed preview + "Your first table…" caption; no Recent |
| Lobby | snapshot exists | Resume card; "Deal me in" asks the §4.1 dialog |
| Table | no session (deep link) | State G "Ready to play?" |
| Table | resumed mid-hand | "Resumed — Hand #13, flop" caption |
| Table | mid-hand snapshot unreadable | fresh hand + "that hand couldn't be restored" caption |
| Table | snapshot write fails | P14 dialog on leave; a persistent 18 pt ticker "Can't save — free some space" *(new)* |
| Table | bot at 0 bb | rebuilt to 100 bb at the next deal with the "rebought" caption |
| Table | hero busted | P10 "Session over — you busted", no ✕ |
| Table | coach evaluating slowly (High sim quality, 9-max) | the chip zone shows a 3-dot shimmer for ≤ 1.5 s; the hand continues; a verdict arriving after the hand ended is recorded, not shown |
| Table | coach off | no badge/chips; price line still on |
| Table | Auto + any sheet / P7 / blocking note | loop paused (`paused || guess.open`) |
| Table | backgrounded | paused; "Paused — tap to continue" |
| Table | 9-max at 360 wide | mid-side bet pills move below plates; names 6 chars |
| Read range | nothing painted → Peek | actual range + "Paint a guess first next time…" |
| Read range | hand ends while open (cannot happen: the hand is paused) | — |
| Coach note | no steps / no expert | disclosure rows open to the "No math…" / "Nothing extra" lines |
| Hand log | first hand, no action | "Actions will appear here." |
| Drills | Review, nothing due | §5.5 empty state with "Next due" |
| Drills | Review, no cards ever | "No spots to review yet" + the verbatim body |
| Drills | last due card answered | feedback stays until Next |
| Drills | lesson opened from feedback | modal S1; Done returns to the same answered spot |
| Study | all 31 complete | Continue card → "Course complete — revisit any lesson" *(new)*; bar full gold |
| Study | equity calc: empty ranges | "Calculate equity" disabled; footer "0 vs 0 combos" |
| Study | equity calc: hero card also on board | prevented on the hero side; board side guards too *(port fix)* |
| Study | multiway trainer computing | bars shimmer; number "—" |
| Stats | no hands | KPI zeros/"—"; chart "Play a few hands to see your trend."; each card's verbatim empty text |
| Stats | no reads | "No reads logged yet." |
| Stats | no coached decisions | "Play with the EV Coach on and your reviewed decisions…" |
| Stats | no position data | "Position is tracked from every new hand you play." |
| Stats | pre-v3 records (no sawFlop) | excluded from WTSD silently (desktop) |
| Stats | tag filter with no matches | "No hands carry that tag among the recent ones." |
| Import | no hands parsed | §7.8 failure copy |
| Import | partial parse | "(k skipped)" in the summary |
| Import | huge file (> 5 000 hands) | progress sheet with cancel; imports in batches of 200 |
| Backup restore | wrong file / corrupt | "That file isn't an All-In backup." *(new)* |
| Reset | typed wrong | "Erase everything" stays disabled; no error text |
| Storage | quota / DB error | fallback per `persistence-stats-settings.md` §2.1; a one-time toast "Some data couldn't be saved" *(new)* |
| Any sheet | keyboard up (note editor, custom tag) | sheet rises; Save stays visible |
| Any list | > 1 000 rows | paginated 100 at a time ("Load more") |
| Rotation | landscape | not supported: the app locks portrait (manifest / Info.plist) |
| Tablet | > 600 pt wide | phone layout centred in a 430-wide column (v1; tablet layout is roadmap) |

---

## 15. FEATURE DISPOSITION TABLE

Every desktop feature → **Kept** (as is) · **Redesigned** (how) · **Cut** (why). "Deviation"
rows are places where this spec deliberately departs from `docs/port/*.md`.

### 15.1 Play

| Desktop feature | Disposition | Mobile form |
|---|---|---|
| Session vs bots, 2 / 6 / 9 seats, optional ante | Kept | Lobby segmented controls (§4.1); three purpose-built felt layouts (§4.2) |
| Four archetypes with observed HUD (VPIP/PFR after 8 hands) | Kept | HUD on every plate incl. 9-max compact; archetype name only in P6 |
| Manual step-through (→ key / Next action) | Redesigned | "Next action" + tap-the-felt + hold-to-fast-forward (§4.5 C) |
| Auto-play, 3 speeds | Kept | Pace pill + Options; ⏭ skip-to-my-turn added (§4.5 D) |
| Hero actions Fold / Check-Call / Bet-Raise | Kept | Action row, exact-commit labels, 150 ms Fold guard, no confirm steps |
| Bet sizing: ½ ¾ Pot All-in + slider + numeric field | Redesigned | Sizing rail with Min ⅓ ½ ⅔ ¾ Pot All-in detents + drag + keypad sheet (§4.5); no system keyboard |
| EV coach notes per decision, verdict palette | Kept | Chip (on the felt) → badge → sheet (§4.8) |
| Blocking mistakes pause the hand | Kept | Non-dismissable sheet; back = Got it |
| 3-layer coach note (plain / math / expert) | Kept, stronger | Rows always rendered; "no math" placeholders; per-note collapse (deviation from desktop's session-sticky toggles) + "Always expand" setting |
| View assumed range (13×13) | Kept | P5 inside the sheet |
| Guess Range → Peek (paint, accuracy/precision/recall, actual range) | Redesigned | Full-screen painter with finger-paint spec, loupe, headers, undo, presets; plain-English score card (§4.9) |
| Eye button on seats | Kept | Eye glyph with 44 pt hit box; one tap → P7 |
| Explain last bot move | Kept | Ghost button + P6 + tap the action pill (§4.10) |
| Hand log | Redesigned | Ticker + P2 Log with coach notes interleaved |
| Hand-over reveal + revealNote lines | Kept | Results overlay on the lower felt, board stays visible (§4.12) |
| Realistic-reveal option | Kept | Settings + P2 Options |
| Session stats (hands, net, bb/100, read accuracy, Your style) | Kept | P2 Session tiles + top-bar title |
| End session + summary (decisions before money) | Kept | P10; Copy + Export → Share (§4.13) |
| Session in memory only | Deviation | Snapshot after every action/hand; resume from Home/Play/pill (§4.14) |
| Pace / speed / coach not persisted | Deviation | Remembered across sessions |
| Coach strictness + sim quality | Kept | Settings → Coach |
| Four-colour deck | Kept | Settings, live preview |
| "Coach charts assume 6-max" note | Kept | Lobby, when seats ≠ 6 |
| 9-max position labels (6-label approximation) | Kept | Plates show them as-is; P6 adds "(approximate…)"; no UTG+1/HJ |
| Keyboard shortcuts F/C/R/→/Enter/Space/? | Cut (visible) / Kept (silent) | No shortcut overlay; hardware keys still work |
| Start-session overlay copy | Kept | Lobby first visit + State G |

### 15.2 Drills

| Desktop feature | Disposition | Mobile form |
|---|---|---|
| Modes Mixed / Push-Fold / Exploits / Review | Kept | Mode chips with blurbs in D4 |
| Move navigator (frame list + 4 buttons) | Redesigned | Scrubber row + swipe on the table + long-press frame list (§5.2) |
| 2–3 answer options with keycaps | Redesigned | Answer row; no keycaps; keys still work |
| Feedback: verdict, EV-loss, rationale, outcomes box, Equity/Pot odds line, grading range, lesson link, Drill 5 similar, Next | Kept | Feedback panel with the 3-layer anatomy; equity line becomes layer 2 with steps |
| Elo rating, accuracy, streak, best, Today, Day streak | Kept | Stats strip; rating sparkline added |
| Daily goal + quiet streak | Kept | Home goal card, Drills Today line, heatmap |
| Review queue (SRS), due counts, retire after 3 | Kept | Tab badge, schedule line, "Next due" |
| Last-due-card feedback vanishing | Fixed | Stays until Next |
| Push/Fold Nash, ICM bubble banner | Kept | Stacks strip + ICM banner (§5.6) |
| Exploits vs known archetype | Kept | Seat ring colour + HUD numbers |
| Placement test (8 Q) | Kept | D5 one-question-per-screen |
| Endless drill loop | Kept | Optional 10-set counter only from Home's quick set; never forced |

### 15.3 Study

| Desktop feature | Disposition | Mobile form |
|---|---|---|
| 5 levels / 31 lessons, progress, Mark complete, Next lesson | Kept | S0 list + S1 reader |
| Range matrices in lessons | Kept | 346 pt editable/readonly matrices |
| Pot-odds, bluff, multiway, equity calculators, range explorer, hand rankings | Kept | Inline + Tool screens (§6.5–6.6) |
| Equity calculator side-by-side ranges + 52-card grids | Redesigned | Stacked; card keypad sheet; range editor modal |
| Quizzes | Kept | Quiz card |
| Cheat sheet | Kept | Quick reference (searchable) |
| Hover glossary | Redesigned | Tap → term popover; glossary screen |
| Study mini-drills | Kept | Shell card |
| Two-pane layout | Cut | Phone is list → reader |

### 15.4 Stats

| Desktop feature | Disposition | Mobile form |
|---|---|---|
| KPI row, cumulative chart, read accuracy, vs archetype, positional, style numbers, coaching review, recent hands, heatmap | Kept | Re-ordered cards; scrub instead of hover (§7) |
| Hand replayer | Kept, extended | P11 with swipe, slider, and the persisted coach-note strip |
| Notes / bookmarks / tags | Kept | P12 sheet; tag chips; swipe actions |
| Hand-history export (.txt) | Kept | Share sheet |
| Hand-history import (.txt) + analyzer | Kept | T3 flow with progress + verbatim summary |
| Backup (.json) | Kept | Share sheet |
| Restore backup | Added | X3 (desktop cannot import its own backup) |
| Reset with typed confirmation | Kept | X2 |
| Tooltips on stats | Redesigned | T1 explainer sheets / popovers |

### 15.5 Settings / About / Onboarding / Shell

| Desktop feature | Disposition | Mobile form |
|---|---|---|
| Theme (dark/light) | Kept | Settings segmented; sidebar toggle cut |
| Reduced motion | Kept | Setting + OS |
| Four-colour deck, realistic reveals, strictness, sim quality | Kept | Settings |
| Rerun onboarding/placement | Kept | "Run again" |
| Keyboard card + shortcut overlay | Cut | No keyboard on a phone |
| About copy, roadmap, version | Kept | X1, with the two permitted edits and a mobile roadmap list |
| GitHub release check | Cut | Store channel; "Rate All-In" row |
| "Play online" / "Download desktop" tiles | Cut | Not meaningful on the phone build |
| Sidebar tip card | Redesigned | Folded into Home's Coach card |
| First-run tour + placement | Kept | O0 pages + D5 |
| Left sidebar nav | Redesigned | 5-tab bar |
| Error boundary | Kept | Flutter `ErrorWidget` replacement with "Something went wrong — your data is safe" + Restart *(new)* |

### 15.6 Considered and not built (v1)

| Idea | Why not |
|---|---|
| Left-handed layout mirror | Adds scope without evidence; Fold-left/Raise-right muscle memory is cross-device |
| Confirm all-in second tap | Friction in shove-heavy spots; the exact-commit label + 150 ms guard suffice |
| Pinch-zoom on the matrix | Gesture-arena conflict with paint; OS zoom + loupe + headers cover it |
| Sets of 10 with summary cards | Grinders chain 100; the optional counter keeps the habit idea without a stop |
| HU "read strip" (opens 62 % on the button) | Needs per-position stats the engine does not track |
| Share-into-app import intent | Platform intents + file association; roadmap |
| Push notifications / streak reminders | Principle 4 |
| Card sounds | Deferred; haptics carry the feedback |
| Landscape / tablet layouts | Portrait-first; tablet is a centred phone column |
| Sitting-out / rebuy UI | Bots auto-rebuild to 100 bb (engine); a one-hand caption suffices |

---

## 16. IMPLEMENTATION NOTES FOR ENGINEERS

### 16.1 go_router routes (names = screen IDs; paths are stable deep-link targets)

```
StatefulShellRoute.indexedStack (TabScaffold)
  branch home    /home                         H0  TodayScreen
    /home/coach-note                            H1  sheet (showModalBottomSheet via AllInSheet)
    /home/goal                                  H2  sheet
  branch play    /play                         P0  LobbyScreen
    /play/session/:id                           P10 SessionSummaryScreen (read-only when ended)
  branch drills  /drills?mode=mixed|pushfold|exploit|leaks&set=10   D0 DrillsScreen
    (D1 panel, D2/D3/D4 sheets are widgets inside D0, not routes)
  branch study   /study                        S0  StudyScreen
    /study/lesson/:id                           S1  LessonReaderScreen (push)
    /study/tools/:tool                          S3  ToolScreen (range-explorer | equity | pot-odds | bluff | multiway | rankings)
    /study/glossary#:termId                     S4  QuickReferenceScreen
  branch stats   /stats                        T0  ProgressScreen
    /stats/hands?filter=all|played|imported&tag=  T2  AllHandsScreen
    /stats/hand/:startedAt                      P11 ReplayerScreen (push, tab bar hidden)
    /stats/settings                             X0  SettingsScreen (push)  — also /home/settings
    /stats/settings/about                       X1  AboutScreen
Top-level (outside the shell, `parentNavigatorKey: rootKey`, fullscreenDialog: true):
  /table                                        P1  TableScreen (modal route; no edge-swipe)
  /table/read/:seat                             P7  ReadRangeScreen (modal over P1)
  /table/summary                                P10 SessionSummaryScreen (modal over P1)
  /placement                                    D5  PlacementScreen
  /onboarding                                   O0  OnboardingScreen
  /study/range-editor                           S6  RangeEditorScreen (modal; returns the set via `pop(result)`)
```

Sheets (P2 P3 P4 P6 P9 P12 P13 T1 T3 T4 D2 D3 D4 H1 H2 S5) are **not routes**: open them with
`AllInSheet.show(context, …)` so they belong to the presenting route and system back pops
them first. P5 is a nested `Navigator` inside P3's sheet. P8 is table state (an overlay widget),
never a route. Dialogs (P14, X2, X3, the new-table dialog) use `AllInDialog.show`.

`GoRouter` config: `Play` tab's `redirect` → `/table` when `sessionProvider.hasSession`. The
shell hides the `NavigationBar` when the current location matches `/table*`, `/placement`,
`/onboarding`, `/study/lesson/*`, `/study/range-editor`, `/stats/hand/*`. Android predictive
back is enabled (`android:enableOnBackInvokedCallback`); `PopScope` on P1 (persist + pop), P3
blocking (`canPop: false` + `onPopInvokedWithResult → dismissReview`), D1 (collapse), P7
(closeGuess), S6 (Done), D5/O0 (previous page or shake).

### 16.2 Presentation cheat-sheet

| Kind | Implementation |
|---|---|
| Tab root | branch of the `StatefulShellRoute` |
| Push | `GoRoute` in the branch; platform transitions (`CupertinoPage` on iOS, `MaterialPage` with fade-through on Android) |
| Full-screen modal | root-level `GoRoute` with `fullscreenDialog: true`; iOS: slide-up; Android: fade-through; no edge-swipe |
| Sheet | `AllInSheet.show` → `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with a `DraggableScrollableSheet` and snap sizes S/M/L; table-parented sheets pass `maxHeightFraction: (screenH - 120 - inset) / screenH` |
| Panel (D1) | `AnimatedPositioned` inside D0's `Stack`; own drag handle; no barrier |
| Overlay | `Stack` layer inside `FeltCanvas` (chip, results card, captions, coach marks) |
| Popover | `OverlayPortal` anchored with `CompositedTransformFollower` |
| Dialog | `showAdaptiveDialog` |
| Toast | `Overlay` entry via `AllInToast.show` |

### 16.3 Feature folders

```
lib/
  app/            app.dart (MaterialApp.router, theme, textScaler caps), router.dart (routes above), shell/tab_scaffold.dart
  theme/          tokens.dart, typography.dart, motion.dart (existing) + theme_data.dart (ThemeData from tokens)
  engine/         pure Dart (existing)
  data/           generated charts (existing)
  services/       persistence/ (sqflite schema v4 + json stores), haptics.dart, share.dart, files.dart, clock.dart
  widgets/        §10 components, one file per widget, exported by widgets.dart
  features/
    home/         providers/ (plan_provider, coach_note_provider, goal_provider) · screens/ (today_screen) · widgets/ (plan_card, coach_card, goal_card, mini_heatmap)
    play/         providers/ (session_provider [game loop + snapshot], coach_provider, guess_provider, pace_provider, table_layout_provider)
                  screens/ (lobby_screen, table_screen, read_range_screen, session_summary_screen)
                  widgets/ (felt/*, seat_plate, hero_strip, sizing_rail, action_row, coach_chip, results_card, session_sheet, coach_note_sheet, player_sheet, bet_keypad_sheet, ticker, coach_marks)
    drills/       providers/ (drill_provider, review_provider, leak_provider, srs) · screens/ (drills_screen, placement_screen) · widgets/ (drill_table, frame_scrubber, answer_row, feedback_panel, mode_chips, stats_strip, stacks_strip, icm_banner)
    study/        content/ (existing) · providers/ (study_progress_provider, quiz_provider) · screens/ (study_screen, lesson_reader_screen, tool_screen, quick_reference_screen, range_editor_screen) · widgets/ (lesson_blocks, quiz_card, calculators/*, range_explorer, equity_calculator, card_keypad_sheet, mini_drills/*)
    stats/        providers/ (stats_provider, notes_provider, hands_provider, import_provider) · screens/ (progress_screen, all_hands_screen, replayer_screen) · widgets/ (kpi_row, charts/*, coaching_review_card, hand_row, note_editor_sheet, import_flow, heatmap_card)
    settings/     providers/ (settings_provider, theme_provider) · screens/ (settings_screen, about_screen) · widgets/ (setting_rows, reset_dialog, restore_dialog)
    onboarding/   providers/ (onboarding_provider) · screens/ (onboarding_screen) · widgets/ (tour_page)
  l10n/           strings.dart (all user-facing strings, keyed; verbatim desktop copy marked)
```

Rules: a feature imports `widgets/`, `engine/`, `services/`, `theme/` and its own folder; never
another feature's widgets (shared things move to `lib/widgets`). Providers are Riverpod
without codegen (`NotifierProvider`, `AsyncNotifierProvider`); the game loop lives in
`SessionNotifier` and exposes `TableState` + `PlaySettings`; the UI never mutates engine
objects. go_router only; no `Navigator.push` outside `AllInSheet`/`AllInDialog`.

### 16.4 Persistence additions (beyond the desktop shapes, which are kept for import parity)

| Store | Key / table | Shape |
|---|---|---|
| Session snapshot | `allin.session.v1` | `{ options, table: TableState json, players, session, playSettings, reviewLog, savedAt }`; written after every hero action and hand boundary; cleared on New session / End |
| Play settings | inside `allin.settings.v1` | `paceMode`, `speedMs`, `coachEnabled`, `autoDeal`, `haptics`, `alwaysExpandMath` |
| Ended sessions | table `sessions` | `startedAt, endedAt, seats, ante, hands, netBb, bb100, mistakes, summaryJson` (last 10 shown in the lobby) |
| Coach notes per hand | `hand_json.coachNotes[]` | `{ street, action, verdict, title, plain, text, steps, expert, equity, potOdds, evBb, villainName, villainRange }` |
| Drill answers ring | `allin.drill_answers.v1` | last 200 `{ ts, mode, kind, correct, ratingAfter }` (weakest-mode quick set, rating sparkline) |
| Coach-mark / hint counters | `allin.hints.v1` | `{ firstHands, swipeHint, revealCollapse }` |
| Quiz results | `allin.quiz.v1` | as desktop |

SQLite via `sqflite`, schema v4 as desktop plus the `sessions` table (v5 migration on
mobile); JSON stores via `shared_preferences`. Backup/restore round-trips the desktop JSON.

### 16.5 Theme token usage (non-negotiable)

- Colours only through `context.colors.*` and the `AllInColors` statics; no literal hex in
  features. Felt: `felt/feltLight/feltDark`, rail `rail/railLight`; cards `cardFace*/cardBack*`.
- Verdicts: `bad` mistake · `warn` thin · `info` reasonable/read · `good` great. Money: `good`/
  `bad` by sign, `textMuted` at 0. Gold is the accent, the primary button, the active tab, the
  selected detent, the coach's identity — never a verdict colour.
- Text: `AllInText.display` for titles, card ranks, big numbers; `.body` for prose; `.mono` for
  every changing number (stacks, pots, bb, %, ratings, timers, counts); `.eyebrow` for section
  labels. Never mix a mono number into a body run without `.mono`.
- Radii `AllInRadius.md` (10) chips/pills, `.lg` (16) cards/sheets, `.xl` (22) plan cards,
  `.pill` for pills. Spacing on the `AllInSpace` scale; the 16 pt page margin is `lg`.
- Motion through `AllInMotion.of(context, d, reduced: settings.reducedMotion)`.

### 16.6 Shared vs platform-specific

Shared (one implementation): everything in `lib/widgets`, the felt, cards, matrix, coach
note, typography, colours, sheets' content, all copy. Platform-specific (thin adapters):
`NavigationBar` vs Cupertino-sized bar, page transitions, `showAdaptiveDialog`, switch style,
haptic patterns, share sheet, file picker, predictive back vs edge-swipe (both routed through
`PopScope`). No screen may branch on platform outside these adapters.

### 16.7 Definition of done per feature

A feature is done when: every screen ID in its rows of §2.2 exists at the path in §16.1; every
verbatim string is sourced from `l10n/strings.dart`; every ≥ 44 pt target is verified with the
Flutter inspector's touch-target overlay; the 390×844, 360×780 and 430×932 golden tests pass in
both themes; reduced motion and 1.3× text scale screenshots are attached; and the §14 states
for that feature render without a debugger.

