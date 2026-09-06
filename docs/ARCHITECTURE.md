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
