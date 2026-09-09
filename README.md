# All-In · Poker Dojo — for phones

A clean, offline-first Texas Hold'em **trainer** that fits in one hand. Learn from the rules up to
solid, EV-aware play by actually doing the math with you — a sandbox vs. bots, chess-style drills
graded by real charts and computed Nash tables, a 31-lesson course, an inline Expected-Value coach,
and honest stats. No account, no ads, no network.

This is the phone edition of [All-In](https://github.com/ganeshapp/poker) (desktop + web). Same
poker, same coach, same honesty — a different app.

Built by [Gapp](https://www.gapp.in).

---

## Who it's for

Someone who wants to get better at Hold'em in the five minutes they actually have: on a train, in a
queue, before bed. Beginners get a course and a coach that explains itself in plain English before it
shows any math. Improving players get drills, a Nash push/fold trainer, a leak queue and bb/100.
Nobody gets a leaderboard, a nudge notification, or a real-money button.

## Not a port — a re-imagined phone app

The desktop app is a sidebar plus a wide two-pane workspace. None of that survives a 390 pt screen,
so the mobile app was designed from its own spec ([`docs/DESIGN.md`](docs/DESIGN.md)) and only the
*behaviour* was ported. What changed:

| Desktop | Phone |
|---|---|
| Left sidebar with 5 views | 5-tab bar; **Home ("Today")** is a new tab the desktop has no equivalent of — one screen that says what to do next |
| Wide felt with a HUD on every seat | Three purpose-built felt layouts (heads-up / 6-max / 9-max). At 9-max the VPIP/PFR numbers move off the plate into the player sheet — a 9 pt HUD line is below the legibility floor |
| Bet-size buttons + slider + a numeric field | A sizing rail with seven detents (Min · ⅓ · ½ · ⅔ · ¾ · Pot · All-in), drag with magnets, and a bet keypad sheet. The system keyboard never opens at the table |
| Hover for tooltips, glossary and HUD | Tap: dotted terms open a popover, seats open a sheet, stats open explainer sheets |
| Guess/peek a range on a 13×13 grid with a mouse | A full-screen finger-paint range painter with a loupe, rank headers, presets and undo |
| Move navigator with four buttons | A frame scrubber, swipe on the table, long-press for the frame list |
| Study is a two-pane list + reader | List → reader; the six calculators also get their own full-screen tool routes |
| Session lives in memory until you close the tab | The session is snapshotted after every action, so an interrupted hand survives a phone call, a task-switch, or the app being killed |
| Pace/speed/coach reset every run | Remembered across sessions |
| Keyboard shortcuts, shortcut overlay | Cut on Play. Drills still answer to 1/2/3 and Enter/Space if a hardware keyboard is attached, silently |

Everything is portrait-first — the orientation is locked in `main.dart` — and anything wider than
600 pt gets the phone layout centred in a 430 pt column rather than a stretched one.

## What's in it

Five tabs, 18 screens, 26 routes.

### Home — "Today"

The screen the app opens on, and the only place that answers "what should I do right now?".

- **Today ring** — a quiet daily goal: 20 drill answers *or* 30 hands. Either fills it; the day
  streak never counts down and is never coloured red.
- **Next up** — up to five plan cards, ranked: clear your review queue · resume a paused table ·
  continue the next lesson · a set of 10 spots in your weakest drill kind · play 20 hands with your
  saved table options. The top card carries the button; each carries a time estimate.
- **Coach's note** — one sentence about *your* play, drawn from your leak rules, your range-read
  accuracy, or yesterday's costliest decision, with "Show me why ›" opening the same three-layer
  explanation the table coach uses.
- **Last session** and a **five-week practice heatmap** that opens Stats.

The "continue lesson" card and Study's Continue card read the same provider, so they can never
disagree about which lesson is next.

### Play

- **Sessions vs. four bot archetypes** (TAG / LAG / Nit / Calling Station) at **heads-up, 6-max or
  9-max**, with optional **0.25 bb antes**, 100 bb stacks and 0.5/1 bb blinds. Manual step-through
  (tap the felt, "Next action", hold to fast-forward) or auto-play at three speeds, plus a
  skip-to-my-turn control.
- **Fold / Check-Call / Bet-Raise** with exact-commit labels ("Call 6 bb", not "Call"), a 150 ms tap
  guard when the row appears so a stray tap can't fold for you, and no confirm step; the sizing rail
  and keypad above.
- **Inline EV Coach.** Every hero decision runs a Monte-Carlo equity simulation against the villain's
  perceived range — or, multiway, against the whole field — off the UI thread in an isolate. The
  verdict appears as a chip on the felt, expands to a badge, and opens a sheet with the three layers
  the whole app uses: **plain English → "Show me the math" → "Expert detail"**, plus the assumed
  range on a 13×13 matrix. Clear −EV mistakes pause the hand with a non-dismissable sheet.
- **Read their range.** Tap the eye on a seat to paint what you think they hold, then peek: you get
  accuracy, precision and recall as plain sentences ("you caught…", "you painted…") next to the real
  range.
- **Explain their last move** for any bot action, and a player sheet with the archetype, the observed
  VPIP/PFR after 8 hands, and the 9-max position caveat.
- **Hand log** — a live ticker on the felt and a full log in the session sheet with coach notes
  interleaved, plus copy-to-clipboard. Written in second person and in big blinds (see below).
- **Hand-over reveals** on the felt with the board still visible, optional realistic reveals, and a
  learn-by-reveal heuristic that collapses the results card if you're spamming "Next hand".
- **Session tiles** (hands, net bb, bb/100, read accuracy, your style) and an **end-of-session
  summary** that leads with decision quality, not money, and shares as a PokerStars-style history.
- **Resume.** Leaving the table pauses it; Home, the lobby and a session pill all bring it back, and
  a cold start after a kill lands you back on the felt.

### Drills

Chess-puzzle practice: a spot is replayed to the decision point, you answer, you get graded.

- **Four modes** — **Mixed** (cash spots), **Push / Fold**, **Exploits**, **Review**.
- Mixed quietly contains five kinds of spot: pre-flop chart spots (opens and facing a raise),
  post-flop fundamentals (bet *and* check-back), 3-bet pots, check-raises, and river-as-aggressor.
  They are not separate chips — the point is not knowing which is coming — but a **source pill** names
  what graded you ("Pre-flop chart · 100bb baseline", "Post-flop heuristic · fundamentals",
  "Push/Fold · computed Nash", "Push/Fold · ICM bubble", "Exploit · vs a known type", "Your flagged
  spot").
- **Frame scrubber** to replay the action, an answer row of 2–3 exact-label options
  (`Fold` / `Call 6 bb` / `Check-raise to 16 bb` …), and a feedback panel with the verdict, the
  EV-loss in bb, a plain rationale, the outcomes box, the equity/pot-odds line as layer 2, the
  grading range under **Expert detail**, a link to the lesson that covers it, "Drill 5 similar" and
  "Next puzzle".
- **Self-adjusting rating** with a 30-day sparkline, accuracy, streak, best, Today and day streak.
- **Review queue** — coach-flagged decisions and missed drills come back on a spaced schedule; beat a
  spot three times over days and it retires. The tab badge shows what's due.
- **Push/Fold** adds a stacks strip and, on a third of reps, an **ICM bubble** banner.
- **Placement test** — 8 questions, one per screen, which picks your first lesson.
- An **optional counter** when you arrive from Home's quick-set card. Drills never force a stop.

### Study

- **31 lessons across 5 levels**, ported from the desktop course: *Basics* (hand rankings, position,
  bankroll) · *Pre-flop* (the 13×13 matrix, opening ranges, 3-betting, reading a HUD) · *Post-flop*
  (board texture, counting outs, estimating equity, pot odds, implied odds, bet sizing, c-betting,
  MDF, check-raising) · *Advanced* (combinatorics, hand-reading, exploits, multiway, SPR, 3-bet pots,
  equity realization, turn and river play, synthesis) · *Practice* (cheat sheet, range explorer,
  equity calculator, three mini-drills).
- **Interactive widgets inside the lessons**: hand rankings, pot-odds and bluff calculators, a
  multiway-equity trainer, a range explorer, a free-form equity calculator (any range vs. any range
  on any board), a range/board breakdown, three mini-drills and the cheat sheet.
- **Six tool screens** with their own routes, so a calculator you use often is one deep link away:
  Range explorer · Equity calc · Pot odds · Bluff calc · Multiway · Hand rankings.
- **35 optional quiz questions**, per-question results remembered.
- **Quick reference** — searchable cheat sheet plus a **25-term glossary**; every dotted term in a
  lesson taps through to its definition.
- Progress is `n/31`; "Mark complete" and "Next lesson" work as on desktop.

### Stats — "Your progress"

- **KPI grid** (hands, bb/100, net, mistakes), a cumulative bb chart you scrub instead of hover, a
  **coaching review** of your leaks, results **vs. each archetype**, **positional** breakdown, your
  style numbers, **range-read accuracy** and the practice heatmap. The ⓘ on a card or a dotted stat
  label opens an explainer sheet with the same three layers the coach uses.
- **All hands** with filters (all / played / imported) and tag chips, **notes and tags** per hand
  (the `review later` tag *is* the bookmark — there is no separate flag), and swipe actions.
- **Hand replayer** — step any hand with a scrubber or swipes, with the coach notes that were
  recorded at the time.
- **Hand-history import (.txt)** — pick a PokerStars-format file and it is parsed, persisted and
  analysed off the UI thread with a real progress count ("Reviewing your calls… 12 of 40"). It can be
  cancelled, or backgrounded while it finishes. Imported hands feed the same coaching review.
- **Export** a hand or a session as a PokerStars-style history, and **back up everything** as JSON
  through the system share sheet.

### Settings & About

Theme (light/dark), reduce motion, haptics, four-colour deck with a live preview, realistic reveals,
coach strictness, simulation quality, "always expand Show me the math", pace/speed, EV coach on/off,
auto-deal, rerun the tour and placement, **back up / restore / import / reset** (reset needs a typed
confirmation), and the About page with the same honesty notes as the desktop.

**Restore from a backup is new here** — the desktop can export its data but not import it back.

### Deliberately not in v1

Left-handed mirror layout · a confirm tap on all-in · pinch-zoom on the range matrix · forced sets of
10 with summary cards · a heads-up "read strip" (it needs per-position stats the engine doesn't
track) · share-into-app import intents · push notifications and streak reminders · card sounds
(haptics carry the feedback) · dedicated landscape and tablet layouts (a tablet gets the centred
phone column instead) · sitting-out/rebuy UI (bots auto-rebuy to 100 bb). The reasoning for each is
in [`docs/DESIGN.md`](docs/DESIGN.md) §15.6.

Also cut from the desktop because they don't mean anything on a phone: the keyboard-shortcut card and
overlay, the GitHub release check (the store handles updates; About has a "Rate All-In" row instead),
the "Play online" / "Download desktop" tiles, and the sidebar theme toggle.

**Known gap:** §15.5's error boundary — a friendly "Something went wrong — your data is safe" screen
replacing Flutter's red error widget — is specified but not implemented yet.

## Notes & honesty

- **Offline-first, and literally offline.** Everything is on your phone: SQLite for hands, stats,
  reads and decisions; key-value storage for settings and progress. The release APK does not declare
  the `INTERNET` permission. There are no accounts, no sync, no analytics. The only outbound action is
  opening a link you tap in About.
- **Pre-flop ranges and drills are chart-derived.** The 100 bb 6-max charts are self-authored
  consensus baselines with mixed frequencies where real strategies mix — not direct solver output.
- **Post-flop coaching is pot-odds + Monte-Carlo equity heuristics, not a solver.** It compares the
  price the pot is offering with how often your hand wins against the opponent's likely range,
  estimated by dealing thousands of runouts. That catches clear mistakes well and can't see
  everything a solver sees; treat close verdicts as guidance.
- **Push/fold is real Nash** — tables computed for chip-EV, no antes, one caller at a time, with
  mixed-frequency hands accepting either answer. ICM bubble spots use Malmuth-Harville.
- **It's a play-money trainer.** No real money, ever. Variance is real, so judge yourself on decision
  quality (the coach), not short-term results.
- **Coach charts assume 6-max.** Play at 2 or 9 seats and the lobby says so.

## How it's built

- **The engine is pure Dart, ported 1:1 from the desktop TypeScript** — evaluator, equity (Monte
  Carlo and exact), notation, ranges, the hand state machine, bots, drills, SRS, leaks, ICM, hand
  histories. No Flutter, `dart:io` or `dart:ui` imports (a test enforces it), injectable randomness
  everywhere, and the **same golden fixtures as the desktop** (`test/golden/*.json`, copied from
  `../poker/scripts/golden`) pinning evaluator scores, chart snapshots and exact-equity counts. No
  Rust FFI: the NDK/Xcode toolchain cost buys nothing a phone can feel.
- **Riverpod 2 without codegen**, **go_router** (a `StatefulShellRoute` for the tabs, root-level
  modals for the table and full-screen flows, sheets that aren't routes), **sqflite**. **No
  `build_runner` anywhere** in the project.
- **Heavy simulations run off the UI thread** in isolates via `compute()`; the engine itself stays
  synchronous and pure.
- **The persistence schema is the desktop's** (v4: `user_stats`, `hand_history`, `range_guess`,
  `decisions` with `PRAGMA user_version` migrations) plus a v5 `sessions` table, so backups can
  round-trip between the two apps.
- Fonts (Inter, Bricolage Grotesque, JetBrains Mono) are bundled — the app looks right with no
  network on first launch.

Full detail in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); the mobile UX spec is
[`docs/DESIGN.md`](docs/DESIGN.md), the coach's voice is [`docs/TONE.md`](docs/TONE.md), and
[`docs/port/*.md`](docs/port) document the desktop behaviour precisely enough to port without reading
the TypeScript.

## Quick start (development)

Prerequisites: **Flutter 3.29+** (Dart 3.7+), and the Android or iOS toolchain for the platform you
want to run on.

```bash
flutter pub get

flutter run        # a connected phone or a booted emulator
flutter test
flutter analyze --no-fatal-infos
dart format lib test
```

## Testing

```bash
flutter test
```

**1424 tests** across 80 test files, all runnable on a Mac with no device attached
(`sqflite_common_ffi` backs the database tests):

| Area | What it covers |
|---|---|
| `test/engine/` | every engine module, plus golden pins, purity, a lockstep sim against the desktop, and parity reviews for the coach, hand histories, drills and persisted JSON |
| `test/services/` | sqflite schema + migrations, repositories, backup/restore, the equity isolate |
| `test/widgets/` | the shared component library, and fit tests for the hero strip and action row at 360/390/430 pt and 1.3× text |
| `test/features/` | providers and screens for all seven features |
| `test/app/` | the §16.1 route table and the shell's chrome insets |

CI (`.github/workflows/ci.yml`) runs `dart format --set-exit-if-changed`, `flutter analyze
--no-fatal-infos`, `flutter test` and a debug APK build on every push to `main` and every PR.

The chart constants under `lib/data/*.g.dart` are generated from the desktop repo's `src/data` by
`tool/convert_charts.mts` — never hand-edit them. If you change a chart or the evaluator's scoring
*deliberately*, regenerate and commit the golden diff.

## Building & releasing

Android ships as **per-ABI signed APKs** — never a lone universal APK, and never a debug-signed one.

```bash
tool/release.sh    # needs android/key.properties pointing at allin-release.jks
```

The script builds `--split-per-abi`, then for each of `arm64-v8a`, `armeabi-v7a` and `x86_64`
verifies the APK's signing certificate against the All-In release keystore's SHA-256, refuses
anything debug-signed, checks the APK really contains `lib/<abi>/libflutter.so`, and writes
`build/release/allin-<version>-<abi>.apk`.

`.github/workflows/release.yml` does exactly the same on a `v*` tag — installing the keystore from
repo secrets, running analyze and the full test suite first, applying both verifications, and
attaching the three APKs to a GitHub Release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

An APK signed with any other key cannot update an installed All-In; it forces an uninstall that
destroys the user's local data. That is why the verification is a hard failure in both places.

iOS builds from source; there is no signed distribution yet.

## Project structure

```
lib/
  main.dart      portrait lock, storage opened before the first frame, ProviderScope
  app/           MaterialApp.router, the go_router table, the tab shell, route names
  theme/         colour tokens (light/dark), typography, motion durations/curves
  engine/        PURE DART: cards, prng, evaluator, equity, notation, ranges, hand engine,
                 archetypes, bot brain, coach, puzzles, srs, leaks, icm, hand history, format
  data/          generated chart constants (*.g.dart)
  services/      sqflite + migrations, key-value stores, equity isolates, share, files, haptics
  widgets/       the shared component library: foundations, table, range, coach, drills,
                 study, charts, shell
  features/      home · play · drills · study · stats · settings · onboarding
                 (each: providers/ screens/ widgets/ content/ — a feature never imports
                  another feature's widgets)
test/            engine · services · widgets · features · app · golden fixtures
tool/            convert_charts.mts, release.sh
docs/            ARCHITECTURE.md · DESIGN.md · TONE.md · port/*.md · design/proposal-*.md
```

## Roadmap

Nothing here is committed; it's a public to-do. All-In is, and will remain, **offline-first and
play-money only**.

| Idea | Why |
|---|---|
| The §15.5 error boundary | Specified, not built — the last gap against the design |
| Configurable table — stack depths, straddles, ante variants | The lobby already carries seats and a 0.25 bb ante; depth is the missing axis |
| Hand-history import from more sites | Only the PokerStars format parses today |
| Share a hand as an image | The replayer already draws the felt |
| Ante-aware push/fold tables | The bundled Nash tables are no-ante |
| Adaptive bots and difficulty levels | The archetypes are fixed policies |
| Landscape / tablet layouts | Portrait-first was a v1 decision, not a permanent one |

## Credits

Designed and built by **Gapp** — https://www.gapp.in. © Gapp.
