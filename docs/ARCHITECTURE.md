# All-In mobile — architecture

Flutter/Dart re-implementation of the desktop trainer (`../poker`, React + TypeScript +
a Rust twin). The desktop app is the behavioural reference; `docs/port/*.md` document every
subsystem precisely enough to port without reading the TypeScript, and `docs/DESIGN.md` is the
mobile UX specification. This file is the technical contract every contributor follows.

## Decisions (do not silently reverse)

- **Pure-Dart engine.** All poker math, the hand state machine, bots, drills, SRS, leaks, ICM and
  hand-history code live in `lib/engine/` with **no Flutter imports** and no I/O. They are ported
  1:1 from the desktop TypeScript and pinned by the same golden fixtures (`test/golden/*.json`,
  copied from `../poker/scripts/golden`). No Rust FFI: it would add NDK/Xcode toolchain fragility
  for no user-visible gain on a phone.
- **Charts are generated constants.** `lib/data/*.g.dart` are produced by
  `tool/convert_charts.mts` from the desktop repo's `src/data`. Never hand-edit; regenerate.
- **Offline-first, play-money only, no accounts, no network.** Everything persists on-device. The
  `INTERNET` permission is declared only in the **debug and profile** manifests (Flutter tooling
  needs it); the release manifest has none, and the app makes no HTTP calls. The only outbound
  action is `url_launcher` opening a link the user taps in About. Keep it that way — if a change
  needs the network, it needs a decision here first.
- **Same persistence schema family as desktop** (SQLite tables `user_stats`, `hand_history`,
  `range_guess`, `decisions` with `PRAGMA user_version` migrations; settings/progress as
  key-value) so a backup can round-trip between the two apps later. Mobile is at **schema v5** =
  the desktop's v4 plus the `sessions` table (`AppDatabase.desktopSchemaVersion` records which is
  which). Restore also accepts a desktop backup; the desktop cannot yet read ours.
- **Riverpod 2 without codegen** (`Notifier` / `AsyncNotifier` classes, `ProviderScope` at root).
  No `build_runner` anywhere in the project.
- **go_router** for navigation: a `StatefulShellRoute` with the bottom tabs, pushed routes for
  full-screen flows, bottom sheets for transient UI. Route names live in `lib/app/routes.dart`.
- **Heavy simulations run off the UI thread** via `compute()` (Dart isolates). The engine stays
  synchronous and pure; `lib/services/equity_service.dart` is the only place that spawns isolates.
  Bot decisions use the small synchronous sims the desktop uses (≤ 320 trials).
- **Bundled fonts** (Inter, Bricolage Grotesque, JetBrains Mono under `assets/fonts`) — the app
  must look right with no network on first launch.
- **Coach voice follows `docs/TONE.md`** everywhere: plain English first, then "show me the
  math", then "expert detail". Copy is ported verbatim from the desktop unless the mobile design
  says otherwise.
- **Portrait-first phone app.** Orientation locked to portrait (see `main.dart`).
- **One rule per shared question, one provider.** When two screens answer the same question they
  read the same provider rather than each deriving an answer. The live case is "what do I read
  next?": Home's plan card (DESIGN.md §3.2 card 3) and Study's Continue card (§6.1) both read
  `studyContinueLessonProvider`, which owns §3.2's rule in full — the placement result's suggested
  lesson while nothing is completed, the first incomplete lesson in path order after that. They
  used to derive it separately and disagreed on day one;
  `test/features/home/next_lesson_agreement_test.dart` now pins the agreement.
- **No `l10n/` layer; copy lives beside its feature.** §16.3 sketched `lib/l10n/strings.dart`; what
  shipped is one `*_copy.dart` per feature (`home_copy`, `play_copy`, `coach_copy`, `drill_copy`,
  `stats_copy`, `about_copy`, `tour_copy`, …) plus the engine's own coach and leak sentences. The
  rule the l10n file existed to enforce is kept intact and is the one that matters: **no user-facing
  sentence is assembled from fragments at a call site, and none is paraphrased**. Each copy file
  marks every constant *(desktop)* — ported verbatim — or *(mobile)* — DESIGN.md's own wording,
  quoted exactly. When a real i18n layer lands these constants move into it unchanged.
- **The hero strip's price line outranks everything beside it** (§4.4). `HeroStrip` walks a
  four-rung ladder — disc · pill · stack → disc · pill → pill → nothing — and takes the first rung
  that leaves the price line its whole measured width. §4.4 names three rungs; the fourth is the
  same rule carried to its end, because "never ellipsised and never truncated" is unconditional
  and a bare "BB" is not always narrow enough (430 pt at 1.3× text). Widths are measured against
  `DefaultTextStyle.of(context).style.merge(style)`, never the bare `AllInText` style.

## Layout

```
lib/
  main.dart                 bootstrap: orientation lock, ProviderScope, DB open, runApp
  app/                      AllInApp widget, router (go_router), shell (bottom tabs), routes.dart
  theme/                    tokens.dart (colours light/dark), typography.dart, app_theme.dart,
                            motion.dart (durations/curves + reduced-motion helpers)
  engine/                   PURE DART — see "Engine modules" below
  data/                     generated chart constants (*.g.dart)
  services/                 equity_service.dart (isolates), share_service.dart (share_plus),
                            file_service.dart (file_picker), haptics.dart, clock.dart,
                            persistence/  app_database.dart (sqflite + migrations),
                                          key_value_store.dart + one *_store.dart per JSON store,
                                          *_repository.dart, serialization.dart, backup_service.dart
  features/
    home/ play/ drills/ study/ stats/ settings/ onboarding/
      providers/            Riverpod Notifiers + state classes for the feature
      screens/              one file per routed screen (18 screens, 26 routes)
      widgets/              feature-private widgets
      content/              static content (curriculum, glossary, tour and placement copy)
      *_copy.dart           the feature's string table (see "no l10n layer" above)
  widgets/                  shared component library from DESIGN.md §10, in the §16.3 folders:
                            foundations/ shell/ table/ range/ coach/ drills/ study/ charts/
test/
  engine/                   unit tests per engine module (+ golden pins, purity, lockstep,
                            parity reviews); *_ref.dart files hold desktop-captured expectations
  golden/                   fixtures copied from the desktop repo
  services/                 sqflite via sqflite_common_ffi
  widgets/                  widget tests for shared components (+ fit tests at 360/390/430 pt)
  features/                 providers and screens, one folder per feature
  app/                      the §16.1 route table, shell chrome insets
tool/
  convert_charts.mts        desktop charts → lib/data
  release.sh                per-ABI APK build + signature + ABI verification (mirrors CI)
docs/
  ARCHITECTURE.md (this)  DESIGN.md  TONE.md  port/*.md  design/proposal-*.md
```

## Engine modules (`lib/engine/`)

| File | Ports desktop | Notes |
|---|---|---|
| `cards.dart` | `engine/cards.ts` | `Card` as 2-char string + int encoding `rank*4+suit`, deck, shuffle with injectable RNG |
| `prng.dart` | `equity.ts` (hashSeed + PRNG) | deterministic seeded generator — same algorithm so verdicts reproduce |
| `evaluator.dart` | `engine/evaluator.ts` | 5–7 card evaluator; score encoding pinned by `test/golden/evaluator.json` |
| `equity.dart` | `engine/equity.ts` | MC + exact equity: vs hand, vs range, vs random, vs field; returns equity, samples, se, exact |
| `notation.dart` | `engine/notation.ts` | hand labels, combos, matrix ordering |
| `ranges.dart` | `engine/ranges.ts` | ranked hands, top-% ranges, archetype preflop ranges (golden `charts.json`) |
| `table_state.dart` | `types/poker.ts` | immutable `TableState`, `Player`, `LegalActions`, `HandSummary` … with `copyWith` |
| `hand_engine.dart` | `game/engine.ts` | `createTable`, `startHand`, `legalActions`, `applyAction` — pure functions returning new state |
| `archetypes.dart` | `game/archetypes.ts` | four archetypes + bot names |
| `bot_brain.dart` | `game/botBrain.ts` | preflop chart policy + postflop heuristics + range narrowing |
| `coach.dart` | `store/gameStore.ts` (`evaluateHero`, `interpretBot`, `scoreGuess`) | verdicts + 3-layer text; injectable equity runner so it can be tested synchronously and run in an isolate in the app |
| `puzzles.dart` | `engine/puzzles.ts` | drill generation + grading for every mode |
| `srs.dart`, `leaks.dart`, `icm.dart` | `lib/srs.ts`, `lib/leaks.ts`, `lib/icm.ts` | scheduler, leak rules, Malmuth-Harville |
| `hand_history.dart` | `game/handHistory.ts`, `lib/hhImport.ts` | model + PokerStars-style export + import parser/analyzer |
| `format.dart` | `lib/format.ts` | `fmtBb`, `fmtTimes`, `fmtNeed`, `fmtPct`, `fmtSigned` |

Rules: no `dart:io`, no `dart:ui`, no `package:flutter` imports in `lib/engine` (enforced by
`test/engine/purity_test.dart`). Randomness always flows through an injectable `Random`/PRNG so
tests are deterministic. Money is in chips (ints); big blind = 20, stacks 2000 by default, exactly
as desktop.

## State management conventions

- One `Notifier` per feature concern (`PlaySessionNotifier`, `DrillSessionNotifier`,
  `StudyProgressNotifier`, `StatsNotifier`, `SettingsNotifier`, `GoalsNotifier`, …), each owning
  an immutable state class. Widgets `ref.watch` narrow `select`ors to avoid rebuilding the table on
  every tick.
- Engine calls are pure; notifiers orchestrate: apply action → schedule bots (timers respect the
  pace setting) → ask `EquityService` for the coach verdict off-thread → push review → persist.
- Persistence goes through repositories in `services/`; notifiers never touch sqflite directly.
- All user-facing strings live next to their feature (no i18n layer yet), coach copy in `engine/coach.dart`.

## Testing

Current state: **1424 tests in 80 `*_test.dart` files**, all green, `flutter analyze
--no-fatal-infos` clean, `dart format` clean.

- `flutter test` must pass on macOS without a device (`sqflite_common_ffi` for DB tests).
- Every engine module has a test file; the golden fixtures pin evaluator scores, ranked hands,
  top-% ranges, archetype ranges and exact-equity counts against the desktop. `purity_test.dart`
  enforces the no-Flutter rule, `lockstep_test.dart` replays a fixed bot session against a captured
  desktop transcript, and the `parity_review*` / `persistence_parity` tests pin coach verdicts,
  hand-history strings and persisted JSON shapes.
- Widget tests cover the shared component library and each screen's main states; the hero strip and
  action row also have fit tests at 360 / 390 / 430 pt across 1.0× / 1.15× / 1.3× text scale.
- `flutter analyze --no-fatal-infos`, `dart format --set-exit-if-changed lib test`, `flutter test`
  and a debug APK build are CI gates (`.github/workflows/ci.yml`).
- **Every fix ships with a regression test.** No exceptions.

## Known gaps against the spec

Tracked here so nobody re-derives them from scratch:

- **§15.5's error boundary is not built.** There is no `ErrorWidget.builder` replacement and no
  "Something went wrong — your data is safe" + Restart screen; a build error still shows Flutter's
  default. It is the only §15 row this audit found with no code behind it.
- **§15.1's silent hardware shortcuts exist on Drills only** (1/2/3, Enter/Space in
  `drills_screen.dart`). The table has no F/C/R key handling — nothing on a phone sends them, and
  the visible overlay was cut either way.
- **`about_copy.roadmap` still lists "Import your real online hand histories for coaching"**, which
  shipped (T3, `import_provider.dart`). The line is stale copy, not a missing feature.
- **§5.1's D0 height budget does not close at 360 × 780 with 1.3× text *and* a live session.** The
  session grows the tab bar by a whole label line ("Play · +4.5" wraps at 360), which leaves the
  felt — D0's only flexible band — about 200 pt. The seat column (tucked cards + a plate whose two
  lines are text-scaled, ~72 pt at 1.3×) and the street caption + pot pill (~45 pt) are together
  taller than the felt above the board, so the top seat's plate and the caption cannot both have
  their §5.1 anchor. `DrillTableMetrics.topSeatCentreY` gets the seat as high as the box allows and
  `DrillTable` clips to its box, so nothing paints over the stats strip — but the plate and the
  caption still touch in that one corner. Closing it means re-tuning §5.1's bands (or a third,
  smaller `DrillTableMetrics` tier), not a local fix. Every other size and scale is clear:
  `drills_screen_test.dart` "no seat paints over the stats strip at 1.3x text" asserts it.

## Release

Android: `tool/release.sh` builds `--split-per-abi`, verifies each APK's signing certificate
(SHA-256 `1abea51c…07eb`, the dedicated `allin-release.jks`) and its `lib/<abi>/` contents, and
names them `allin-<version>-<abi>.apk`. CI (`.github/workflows/release.yml`) does the same on a
`v*` tag and refuses to publish anything not signed with that key. Never publish a universal or
debug-signed APK. iOS builds from source (no signed distribution).

Commits are authored as the user only — no Claude attribution trailers.

## Deliberate copy changes from the desktop

Lesson, coach and About text is ported verbatim. Every intentional wording change is in this table;
there are no others, and adding one without a row here is a defect. Four rows exist because the
desktop copy describes a mouse the phone does not have; one because it describes desktop/web
platforms; three because it names a screen, a layer-3 label or a precision that does not exist on
the phone; one is the hand log, which the desktop writes in the third person and in chips.

| Where | Desktop | Mobile | Why |
|---|---|---|---|
| Lesson `position` | "(Hover the dotted terms for a definition…)" | "(Tap the dotted terms for a definition…)" | No mouse |
| Lesson `hud-reading` | "Hover a bot's HUD in the game…" | "Tap a bot's plate at the table…" | No mouse; §4.2.2 moved the 9-max HUD into P6 |
| Lesson `cheat-sheet` glossary | "Every term below is also hoverable wherever it appears in a lesson." | "Tap any dotted term wherever it appears in a lesson to see this definition." | No mouse |
| About · "How to use it" bodies | "click the eye" · "Hover any dotted term" | "tap the eye" · "Tap any dotted term" | No mouse (the only two permitted edits to those four bodies, §9) |
| About · "Good to know", tech stack, roadmap, download tiles | "(SQLite on desktop, browser storage on the web)" · a React/Tauri stack sentence · roadmap rows for desktop auto-update and PWA install · "Play online" / "Download desktop" tiles · a GitHub release check | "(everything is stored on this phone)" · "Made with Flutter and Dart." · roadmap rows for "Hand-history import from more sites" and "Share a hand as an image" · tiles cut · a "Rate All-In" row | §15.5: the platform sentences are false on a phone and the two tiles/update check are not meaningful in a store build. The honesty bullets — play-money, heuristics not a solver — are untouched |
| Read-accuracy leak line — `stats_copy.readAccuracyLeak`, and the same sentence as Home's coach note (`home_copy.coachReadLine`) | "…practise with Guess & Peek, or try the Range-Building exercise in Study." | "…tap the eye on a seat during a hand to practise, or open the Range-Building Drill in Study." | The desktop names two things no screen here is labelled: the flow is the eye on a seat ("Read {name}'s range"), and the lesson is the "Range-Building Drill" |
| Drill feedback row 3 (§5.3, §15.2) | Row label "See the range it was graded against" | Row label "**Expert detail**"; the desktop string becomes the row's first body line, "The range it was graded against:" (`DrillCopy.rangeItWasGradedAgainst`) | Layer-3 labels are identical on every three-layer surface — that is what makes the structure learnable (Principle 3) |
| `fmtNeed` / `fmtNeedTimes` (`lib/engine/format.dart`) | rounds to the nearest **half** — "you need to win about 1 time in 3.5" | rounds to the nearest **whole** — "about 1 time in 4" | TONE.md's layer-1 rule is "chances as counts", and there is no winning one time in three and a half. The half-step reads as a precision a Monte-Carlo estimate does not have and stops the sentence being a picture a beginner can hold; the whole number stays inside the word "about". `docs/port/*.md` still record the desktop's half-step form as the behaviour being ported, and the parity tests pin the mobile rule |
| Hand log — ticker (§4.2), P2 Log (§4.11), the P11 replayer's frames (§7.7) and "copy hand log" | "You raises to 58" · "You folds" · "You wins 88 (uncontested)" · "Hand #3 · blinds 10/20" | "You raise to 2.9 bb" · "You fold" · "You win 4.4 bb (uncontested)" · "Hand #3 · blinds 0.5 / 1 bb" | Below |

**The hand log deviation in full.** `lib/engine` still writes the desktop strings — they are pinned
by the parity tests and shared with the desktop — and `lib/features/play/hand_log_format.dart`
(`HandLog`) rewrites them for display only:

- the hero's verbs become second person ("You fold / check / call / bet / raise to / post SB / win"),
  because the engine's `${p.name} folds` template with a hero named "You" produces "You folds";
- bots keep the third person, and several winners take the plural ("You and Ivey win 26 bb (Pot)");
- every amount is converted to big blinds with `fmtBb` and given a " bb" unit, because every other
  surface on the phone speaks big blinds (§4.4, §4.5, §10.3). Posted stakes — the hand header's
  blinds and antes, and any "posts …" line — keep a second decimal when they need one, so the log
  says "ante 0.25 bb" like the lobby rather than `fmtBb`'s rounded "0.3";
- lines with no player and no chips (street deals, the §14 ticker overrides) pass through unchanged.

| Session summary, empty session | "No coached decisions this session — the EV Coach was off." (always) | Same sentence only when the coach really was off; with the coach on it reads "No decisions to grade yet — the EV Coach had nothing to weigh in on this session." |

The last row is a correctness fix, not a style change: DESIGN.md §4.13 pins the original string, but
it asserts a reason the user can disprove in one tap when a session ends with the coach on and no
decision yet graded.

Any further deviation from the desktop wording needs a row here.
