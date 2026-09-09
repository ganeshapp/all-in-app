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
- **Offline-first, play-money only, no accounts, no network.** Everything persists on-device.
- **Same persistence schema family as desktop** (SQLite tables `user_stats`, `hand_history`,
  `range_guess`, `decisions` with `PRAGMA user_version` migrations; settings/progress as
  key-value) so a backup can round-trip between the two apps later.
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
  used to derive it separately and disagreed on day one.
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
  services/                 database.dart (sqflite + migrations), preferences.dart,
                            equity_service.dart (isolates), export_service.dart (share_plus),
                            import_service.dart (file_picker + hh parser), haptics.dart
  features/
    home/ play/ drills/ study/ stats/ settings/ onboarding/
      providers/            Riverpod Notifiers + state classes for the feature
      screens/              one file per routed screen
      widgets/              feature-private widgets
  widgets/                  shared component library from DESIGN.md §10 (PlayingCard,
                            RangeMatrix, CoachNote, VerdictBadge, StatTile, AppSheet, Segmented,
                            PrimaryButton, Chip, ProgressRing, SeatBadge, ...)
test/
  engine/                   unit tests per engine module (+ golden pins)
  golden/                   fixtures copied from the desktop repo
  services/                 sqflite via sqflite_common_ffi
  widgets/                  widget tests for shared components and key screens
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

- `flutter test` must pass on macOS without a device (`sqflite_common_ffi` for DB tests).
- Every engine module has a test file; the golden fixtures pin evaluator scores, ranked hands,
  top-% ranges, archetype ranges and exact-equity counts against the desktop.
- Widget tests cover the shared component library and each screen's main states.
- `flutter analyze` clean and `dart format` clean are CI gates.

## Release

Android: `tool/release.sh` builds `--split-per-abi`, verifies each APK's signing certificate
(SHA-256 `1abea51c…07eb`, the dedicated `allin-release.jks`) and its `lib/<abi>/` contents, and
names them `allin-<version>-<abi>.apk`. CI (`.github/workflows/release.yml`) does the same on a
`v*` tag and refuses to publish anything not signed with that key. Never publish a universal or
debug-signed APK. iOS builds from source (no signed distribution).

Commits are authored as the user only — no Claude attribution trailers.

## Deliberate copy changes from the desktop

Lesson and coach text is ported verbatim, with four exceptions: three where the desktop copy
describes a mouse the phone does not have, and the hand log, which the desktop writes in the third
person and in chips. These are the only intentional wording changes:

| Where | Desktop | Mobile |
|---|---|---|
| Lesson `position` | "(Hover the dotted terms for a definition…)" | "(Tap the dotted terms for a definition…)" |
| Lesson `hud-reading` | "Hover a bot's HUD in the game…" | "Tap a bot's plate at the table…" |
| Lesson `cheat-sheet` glossary | "Every term below is also hoverable wherever it appears in a lesson." | "Tap any dotted term wherever it appears in a lesson to see this definition." |
| Hand log — ticker (§4.2), P2 Log (§4.11) and "copy hand log" | "You raises to 58" · "You folds" · "You wins 88 (uncontested)" · "Hand #3 · blinds 10/20" | "You raise to 2.9 bb" · "You fold" · "You win 4.4 bb (uncontested)" · "Hand #3 · blinds 0.5 / 1 bb" |

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

Any further deviation from the desktop wording needs a row here.
