import 'package:allin/engine/format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'format_ref.dart';

void main() {
  group('jsRound', () {
    test('matches Math.round tie-breaking', () {
      expect(jsRound(2.5), 3);
      expect(jsRound(-2.5), -2);
      expect(jsRound(-0.4).isNegative, isTrue); // -0
      expect(jsRound(-0.4), 0);
      expect(jsRound(0.49999999999999994), 0);
      expect(jsRound(1.5), 2);
      expect(jsRound(-1.5), -1);
      expect(jsRound(double.nan).isNaN, isTrue);
      expect(jsRound(double.infinity), double.infinity);
    });
  });

  group('jsToFixed', () {
    test('never prints negative zero', () {
      expect(jsToFixed(-0.0, 1), '0.0');
      expect(jsToFixed(-0.04, 1), '-0.0');
      expect(jsToFixed(12.5, 0), '13');
      expect(jsToFixed(0.125, 2), '0.13');
      expect(jsToFixed(1.005, 2), '1.00');
    });
  });

  group('fmtBb', () {
    test('pinned against the TypeScript (${kFmtBbRef.length} cases)', () {
      for (final (chips, bb, want) in kFmtBbRef) {
        expect(fmtBb(chips, bb), want, reason: 'fmtBb($chips, $bb)');
      }
    });
    test('documented examples', () {
      expect(fmtBb(30, 20), '1.5');
      expect(fmtBb(40, 20), '2');
      expect(fmtBb(2000, 20), '100');
      expect(fmtBb(-1, 20), '0'); // Math.round(-0.5) → -0 → "0"
    });
  });

  group('fmtChips', () {
    test('pinned against the TypeScript (${kFmtChipsRef.length} cases)', () {
      for (final (n, want) in kFmtChipsRef) {
        expect(fmtChips(n), want, reason: 'fmtChips($n)');
      }
    });
    test('groups thousands like en-US toLocaleString', () {
      expect(fmtChips(2000), '2,000');
      expect(fmtChips(1234567), '1,234,567');
      expect(fmtChips(-1234), '-1,234');
      expect(fmtChips(-0.4), '-0'); // JS keeps the sign of -0 here
    });
  });

  group('fmtSigned', () {
    test('pinned against the TypeScript (${kFmtSignedRef.length} cases)', () {
      for (final (n, digits, want) in kFmtSignedRef) {
        final got = digits == null ? fmtSigned(n) : fmtSigned(n, digits);
        expect(got, want, reason: 'fmtSigned($n, $digits)');
      }
    });
    test('negative values that round to zero print as +0.0', () {
      expect(fmtSigned(-0.04), '+0.0');
      expect(fmtSigned(-0.05), '+0.0');
      expect(fmtSigned(-0.06), '-0.1');
      expect(fmtSigned(1.25), '+1.3');
      expect(fmtSigned(-1.25), '-1.2');
    });
  });

  group('fmtPct', () {
    test('pinned against the TypeScript (${kFmtPctRef.length} cases)', () {
      for (final (frac, digits, want) in kFmtPctRef) {
        final got = digits == null ? fmtPct(frac) : fmtPct(frac, digits);
        expect(got, want, reason: 'fmtPct($frac, $digits)');
      }
    });
    test('documented examples', () {
      expect(fmtPct(0.334), '33%');
      expect(fmtPct(0.334, 1), '33.4%');
      expect(fmtPct(0.125), '13%');
      expect(fmtPct(1 / 3, 1), '33.3%');
    });
  });

  group('fmtTimes', () {
    test('pinned against the TypeScript (${kFmtTimesRef.length} cases)', () {
      for (final (p, want) in kFmtTimesRef) {
        expect(fmtTimes(p), want, reason: 'fmtTimes($p)');
      }
    });
    test('TONE.md phrasing', () {
      expect(fmtTimes(0.25), 'about 1 time in 4');
      expect(fmtTimes(0.7), 'about 7 times in 10');
      expect(fmtTimes(0.95), 'almost every time');
      expect(fmtTimes(0.02), 'almost never');
      expect(fmtTimes(0.45), 'about 5 times in 10');
      expect(fmtTimes(0.0401), 'about 1 time in 25');
    });
  });

  group('fmtNeed', () {
    test('pinned against the TypeScript (${kFmtNeedRef.length} cases)', () {
      for (final (p, want) in kFmtNeedRef) {
        expect(fmtNeed(p), want, reason: 'fmtNeed($p)');
      }
    });
    test('documented examples', () {
      expect(fmtNeed(0), 'any win rate');
      expect(fmtNeed(0.25), 'about 1 time in 4');
      expect(fmtNeed(0.3), 'about 1 time in 3.5');
      expect(fmtNeed(1 / 3), 'about 1 time in 3');
    });
  });
}
