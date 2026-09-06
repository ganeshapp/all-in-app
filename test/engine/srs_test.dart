// Port of the desktop scripts/srs_test.ts (13 assertions) plus the pinned
// ladder from docs/port/drill-ux-srs-leaks.md §2.4 (values recomputed by
// running srs.ts under Node 23). `wins` is the desktop's `reps`.
import 'package:allin/engine/srs.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

const day = 86400000;
const t0 = 1750000000000;

void main() {
  final fresh = newSrs(t0);
  final r1 = reviewSrs(fresh, true, t0);
  final r2 = reviewSrs(r1, true, t0 + day);
  final r3 = reviewSrs(r2, true, t0 + 4 * day);
  final miss = reviewSrs(r2, false, t0 + 4 * day);
  final recover = reviewSrs(miss, true, t0 + 5 * day);
  final r4 = reviewSrs(r3, true, t0 + 11 * day);

  test('new cards are due immediately and not graduated', () {
    expect(isDue(fresh, t0), isTrue);
    expect(isGraduated(fresh), isFalse);
    expect(isDue(null, t0), isTrue, reason: 'missing state counts as due');
  });

  test('correct ladder: 1d -> 3d -> ~1w, graduating at RETIRE_REPS', () {
    expect(kRetireReps, 3);
    expect(r1.intervalDays, 1);
    expect(r1.due, t0 + day);
    expect(isDue(r1, t0 + day ~/ 2), isFalse);
    expect(isDue(r1, t0 + day), isTrue);
    expect(r2.intervalDays, 3);
    expect(r3.intervalDays, greaterThanOrEqualTo(4));
    expect(r3.wins, kRetireReps);
    expect(isGraduated(r3), isTrue);
  });

  test('a miss resets the ladder and returns quickly', () {
    expect(miss.wins, 0);
    expect(miss.lapses, 1);
    expect(miss.due - (t0 + 4 * day), lessThanOrEqualTo(15 * 60000));
    expect(miss.ease, lessThan(r2.ease));
    expect(recover.intervalDays, 1);
    expect(
      isGraduated(recover),
      isFalse,
      reason: 'one correct answer never retires a card',
    );
  });

  test('ease is clamped', () {
    var s = newSrs(t0);
    for (var i = 0; i < 20; i++) {
      s = reviewSrs(s, false, t0);
    }
    expect(s.ease, greaterThanOrEqualTo(1.3));
    expect(s.ease, 1.3);
    expect(s.lapses, 20);
    var g = newSrs(t0);
    for (var i = 0; i < 20; i++) {
      g = reviewSrs(g, true, t0).copyWith(wins: 1);
    }
    expect(g.ease, lessThanOrEqualTo(3));
    expect(g.ease, 3);
    expect(g.intervalDays, 3);
    expect(g.due, 1750259200000);
  });

  test('pinned ladder bits match the TypeScript', () {
    void check(
      SrsState s,
      int due,
      double interval,
      double ease,
      int wins,
      int lapses,
    ) {
      expect(s.due, due);
      expect(s.intervalDays, interval);
      expect(s.ease, ease);
      expect(s.wins, wins);
      expect(s.lapses, lapses);
    }

    check(fresh, 1750000000000, 0, 2.3, 0, 0);
    check(r1, 1750086400000, 1, 2.3499999999999996, 1, 0);
    check(r2, 1750345600000, 3, 2.3999999999999995, 2, 0);
    check(r3, 1750950400000, 7, 2.4499999999999993, 3, 0);
    check(miss, 1750346200000, 0, 2.1999999999999993, 0, 1);
    check(recover, 1750518400000, 1, 2.249999999999999, 1, 1);
    check(r4, 1752419200000, 17, 2.499999999999999, 4, 0);
  });

  test('desktop-persisted ease values round-trip through SrsState json', () {
    final j = {
      'due': 1750086400000,
      'intervalDays': 1,
      'ease': 2.35,
      'wins': 1,
      'lapses': 0,
    };
    final s = SrsState.fromJson(j);
    expect(reviewSrs(s, true, 1750086400000).intervalDays, 3);
  });
}
