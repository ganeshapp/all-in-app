/// Spaced-repetition scheduling (SM-2 family, tuned small) — ported 1:1 from
/// the desktop `src/lib/srs.ts`.
///
/// A card graduates only after [kRetireReps] consecutive correct answers on a
/// SPACED schedule (1d → 3d → ~1w) — answering once right after a miss no
/// longer deletes anything. A miss resets the ladder and brings the card back
/// within minutes.
///
/// [SrsState.wins] is the desktop's `reps` (consecutive correct spaced
/// reviews).
library;

import 'dart:math' as math;

import 'format.dart' show jsRound;
import 'types.dart';

/// Consecutive spaced successes needed before a card retires.
const int kRetireReps = 3;

const int _minuteMs = 60000;
const int _dayMs = 86400000;

/// A brand-new card: due immediately, default ease 2.3.
SrsState newSrs(int now) =>
    SrsState(due: now, intervalDays: 0, ease: 2.3, wins: 0, lapses: 0);

/// Apply one review. Same arithmetic order as the TypeScript so the
/// accumulated `ease` bits match persisted desktop data.
SrsState reviewSrs(SrsState s, bool correct, int now) {
  if (!correct) {
    return SrsState(
      due: now + 10 * _minuteMs, // back in ~10 minutes
      intervalDays: 0,
      ease: math.max(1.3, s.ease - 0.2),
      wins: 0,
      lapses: s.lapses + 1,
    );
  }
  final double intervalDays =
      s.wins == 0
          ? 1
          : s.wins == 1
          ? 3
          : math.max(4, jsRound(s.intervalDays * s.ease));
  return SrsState(
    due: now + (intervalDays * _dayMs).toInt(),
    intervalDays: intervalDays,
    ease: math.min(3, s.ease + 0.05),
    wins: s.wins + 1,
    lapses: s.lapses,
  );
}

/// Missing state counts as due.
bool isDue(SrsState? s, int now) => s == null || s.due <= now;

/// Graduated = beaten [kRetireReps] times on the spaced ladder.
bool isGraduated(SrsState s) => s.wins >= kRetireReps;
