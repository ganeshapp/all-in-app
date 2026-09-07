/// Barrel for the pure-Dart poker engine (see docs/ARCHITECTURE.md).
///
/// Everything under `lib/engine/` is free of Flutter / dart:io / dart:ui and
/// is pinned by `test/engine/*_test.dart` plus the golden fixtures.
library;

export 'archetypes.dart';
export 'bot_brain.dart';
export 'cards.dart';
export 'coach.dart';
export 'equity.dart';
export 'evaluator.dart';
export 'format.dart';
export 'hand_engine.dart';
export 'hand_history.dart';
export 'hh_import.dart';
export 'icm.dart';
export 'leaks.dart';
export 'notation.dart';
export 'prng.dart';
export 'puzzles.dart';
export 'ranges.dart';
export 'srs.dart';
export 'types.dart';
