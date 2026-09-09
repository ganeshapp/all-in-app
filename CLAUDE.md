# All-In mobile (Flutter) — working notes for contributors

The phone edition of the desktop trainer at `../poker`. Flutter, Dart, offline, play-money.

## State

Feature-complete against `docs/DESIGN.md`. **1424 tests in 80 `*_test.dart` files pass**,
`flutter analyze --no-fatal-infos` is clean, `dart format lib test` is clean, and the app runs on a
booted Android emulator. Five tabs (Home · Play · Drills · Study · Stats), 18 screens, 26 routes;
31 lessons, 6 study tools, 4 drill modes, 25 glossary terms, 35 quiz questions.

The one known gap is DESIGN.md §15.5's error boundary — see "Known gaps against the spec" in
`docs/ARCHITECTURE.md`, which also lists the two smaller ones.

## Read before changing anything

- `docs/ARCHITECTURE.md` — the technical contract: decisions that must not be silently reversed,
  the engine module map, the copy-change table, release rules, known gaps.
- `docs/DESIGN.md` — the mobile UX spec. §15 is the feature disposition table (kept / redesigned /
  cut and why); §16 is routes, folders, tokens and definition of done.
- `docs/TONE.md` — how the coach talks. Every explanation is three layers: plain English →
  "Show me the math" → "Expert detail".
- `docs/port/*.md` — the desktop behaviour being ported, precise enough that you should not need
  the TypeScript. The desktop source is at `../poker` when a doc is unclear.

## Rules

- **`lib/engine/` is pure Dart**: no `package:flutter`, `dart:io` or `dart:ui` imports
  (`test/engine/purity_test.dart` enforces it), no I/O, injectable randomness everywhere, a test
  file per module. The golden fixtures in `test/golden/` are copied from the desktop and must keep
  passing. Money is in chips (ints); big blind 20, stacks 2000.
- **Riverpod 2 without codegen; go_router; sqflite. No `build_runner` anywhere.**
- **Charts under `lib/data/*.g.dart` are generated** by `tool/convert_charts.mts` from `../poker/src/data`.
  Never hand-edit; regenerate and commit the golden diff.
- **Theme tokens are non-negotiable** (DESIGN.md §16.5): colours only via `context.colors.*` /
  `AllInColors` — no literal hex in features; text via `AllInText` (`.mono` for every changing
  number); durations via `AllInMotion.of(context, …)`; radii/spacing from `AllInRadius` /
  `AllInSpace`. Gold is the accent, never a verdict colour.
- **Every interactive target is ≥ 44 pt.**
- **Copy is never paraphrased and never assembled from fragments at a call site.** It lives in the
  feature's `*_copy.dart` (or `lib/engine/coach.dart` / `leaks.dart` for coach sentences), marked
  *(desktop)* = verbatim or *(mobile)* = DESIGN.md's own wording quoted exactly. **Any wording that
  differs from the desktop needs a row in the copy-change table in `docs/ARCHITECTURE.md`.**
- **A feature never imports another feature's widgets.** If two features need it, it belongs in
  `lib/widgets/`. If a widget's name appears in DESIGN.md §10, it lives in `lib/widgets`.
- **Add a regression test with every fix.**
- **Run `dart format lib test`, `flutter analyze --no-fatal-infos`, `flutter test` before finishing
  any change.** All three are CI gates.

## Release

- Android ships **per-ABI signed APKs only** (`tool/release.sh`, mirrored by
  `.github/workflows/release.yml` on a `v*` tag). Both verify the signing certificate against
  `allin-release.jks` and refuse a debug-signed or wrong-ABI APK. Never publish a universal APK.
- Commit as the repository owner. **Never add `Co-Authored-By` trailers.**
