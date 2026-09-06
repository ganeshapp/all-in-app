/// Deterministic randomness — ported from the desktop `src/engine/equity.ts`
/// (`mulberry32` + `hashSeed`).
///
/// Both functions must reproduce the JavaScript bit-for-bit so that coach
/// verdicts, bot range narrowing and hand-history import all land on the same
/// sampled outcomes as the desktop app. All arithmetic is modulo 2^32: Dart
/// ints are 64-bit and wrap, so every product / sum / xor is masked with
/// [_mask32] and `>>` is only applied to masked, non-negative values
/// (which makes it equivalent to JS `>>>`).
library;

import 'dart:math';

const int _mask32 = 0xFFFFFFFF;

/// JS `Math.imul`: low 32 bits of the product, as an unsigned value.
int _imul(int a, int b) => ((a & _mask32) * (b & _mask32)) & _mask32;

/// The desktop PRNG (`mulberry32`). Implements [Random] so it can be dropped
/// anywhere the engine takes an injectable RNG.
///
/// `next()` returns the same double sequence as the TypeScript closure for
/// the same 32-bit seed. [nextInt] is `floor(next() * max)` — exactly the
/// `(rand() * n) | 0` / `Math.floor(Math.random() * n)` idiom the desktop
/// code uses, so shuffles and index picks driven by a [Mulberry32] reproduce
/// the TypeScript ones too.
class Mulberry32 implements Random {
  Mulberry32(int seed) : _a = seed & _mask32;

  int _a;

  /// Current 32-bit state (unsigned). Exposed for tests/debugging only.
  int get state => _a;

  /// Next double in `[0, 1)` — identical to calling the TS closure.
  double next() {
    _a = (_a + 0x6D2B79F5) & _mask32;
    int t = _a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _mask32)) & _mask32;
    return ((t ^ (t >> 14)) & _mask32) / 4294967296;
  }

  @override
  double nextDouble() => next();

  @override
  int nextInt(int max) {
    if (max <= 0) {
      throw RangeError.range(max, 1, null, 'max', 'max must be positive');
    }
    return (next() * max).toInt();
  }

  @override
  bool nextBool() => next() < 0.5;
}

/// FNV-1a hash of a string → 32-bit unsigned seed (desktop `hashSeed`).
/// Iterates UTF-16 code units like JS `charCodeAt`.
int hashSeed(String s) {
  int h = 0x811C9DC5;
  for (int i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & _mask32;
    h = _imul(h, 0x01000193);
  }
  return h & _mask32;
}

/// Desktop `mulberry32(seed)`: a closure returning doubles in `[0, 1)`.
double Function() mulberry32(int seed) {
  final g = Mulberry32(seed);
  return g.next;
}
