/// Spot generation, off the UI thread.
///
/// The engine's generators are pure but **not** cheap: `_genPostflopBet`,
/// `_genThreeBetPot` and friends each run a 3 000-trial Monte-Carlo
/// simulation, `strengthSlice` runs 80 trials per label over 169 labels, and
/// `adaptivePuzzle` rejection-samples up to 25 whole puzzles. That is tens to
/// hundreds of milliseconds — far past the ~2 ms the UI thread may spend
/// (ARCHITECTURE.md, DESIGN.md §11: the mode crossfade and the panel spring
/// must not drop frames).
///
/// So every draw crosses an isolate through `compute`, carrying the puzzle
/// back as its own desktop-compatible JSON ([Puzzle.toJson]). Tests swap in
/// [InProcessDrillGenerator], which runs the same pure function on the
/// current isolate with a seeded [Mulberry32] so a spot is reproducible.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine.dart';

/// Which engine entry point a request runs.
enum DrillGenKind {
  /// `generatePuzzle()` — the launch spot, and the focus fallback (§6.2).
  mixed,

  /// `adaptivePuzzle(rating)` — Mixed with no focus (§6.4).
  adaptive,

  /// `generatePuzzleOfKind(kind)` — "Drill 5 similar" (§6.8).
  ofKind,

  /// `generatePushFold()` (a third of which are ICM bubbles).
  pushfold,

  /// `generateExploit()`.
  exploit,
}

/// One draw. Primitives only, so it crosses an isolate boundary as-is.
@immutable
class DrillGenRequest {
  const DrillGenRequest({
    required this.kind,
    this.rating = kDefaultRating,
    this.focusKind,
    this.seed,
  });

  final DrillGenKind kind;

  /// Only read by [DrillGenKind.adaptive].
  final int rating;

  /// `PuzzleKind.label`; only read by [DrillGenKind.ofKind].
  final String? focusKind;

  /// Seeds a [Mulberry32] instead of `Random()` — tests and goldens.
  final int? seed;

  DrillGenRequest withSeed(int? seed) => DrillGenRequest(
    kind: kind,
    rating: rating,
    focusKind: focusKind,
    seed: seed,
  );
}

/// The pure draw. Public so the isolate entry point can reach it.
Puzzle generateDrillSpot(DrillGenRequest request, Random rng) => switch (request
    .kind) {
  DrillGenKind.mixed => generatePuzzle(rng: rng),
  DrillGenKind.adaptive => adaptivePuzzle(request.rating, rng: rng),
  DrillGenKind.ofKind => generatePuzzleOfKind(
    PuzzleKind.fromLabel(request.focusKind ?? PuzzleKind.rfi.label),
    rng: rng,
  ),
  DrillGenKind.pushfold => generatePushFold(rng: rng),
  DrillGenKind.exploit => generateExploit(rng: rng),
};

/// `compute` entry point — top-level by necessity.
Map<String, Object?> runDrillGen(DrillGenRequest request) {
  final rng = request.seed == null ? Random() : Mulberry32(request.seed!);
  return generateDrillSpot(request, rng).toJson();
}

/// Draws spots on a background isolate.
class DrillGenerator {
  const DrillGenerator();

  Future<Puzzle> generate(DrillGenRequest request) async =>
      Puzzle.fromJson(await compute(runDrillGen, request));
}

/// The same generator on the current isolate — tests, and any host where
/// spawning an isolate is not available.
class InProcessDrillGenerator extends DrillGenerator {
  InProcessDrillGenerator({int? seed})
    : _rng = seed == null ? Random() : Mulberry32(seed);

  final Random _rng;

  @override
  Future<Puzzle> generate(DrillGenRequest request) async =>
      generateDrillSpot(request, _rng);
}

final drillGeneratorProvider = Provider<DrillGenerator>(
  (ref) => const DrillGenerator(),
);
