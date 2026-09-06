# All-In mobile (Flutter) — working notes for AI contributors

- Read `docs/ARCHITECTURE.md` (technical contract), `docs/DESIGN.md` (mobile UX spec) and
  `docs/TONE.md` (how the coach talks) before changing anything. `docs/port/*.md` describe the
  desktop behaviour being ported; the desktop source is at `../poker` if a doc is unclear.
- `lib/engine/` is pure Dart: no Flutter/dart:io/dart:ui imports, injectable randomness, tests for
  every module, golden fixtures in `test/golden/` must keep passing.
- Riverpod without codegen; go_router; sqflite; no build_runner.
- Run `dart format lib test`, `flutter analyze`, `flutter test` before finishing any change.
- Charts under `lib/data/*.g.dart` are generated — regenerate with `tool/convert_charts.mts`.
- Commit as the repository owner; never add `Co-Authored-By` trailers.
- Android releases: per-ABI APKs signed with `allin-release.jks` only (see `tool/release.sh`).
