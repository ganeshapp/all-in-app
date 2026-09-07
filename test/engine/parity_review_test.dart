/// Adversarial parity review pins for cards / prng / notation / evaluator /
/// equity / ranges.
///
/// Every expected value here was computed by running the desktop TypeScript
/// (`src/engine/*.ts`) under Node (`node --experimental-transform-types`) on
/// the same inputs, as part of a 3000-hand evaluator fuzz + 180 seeded
/// Monte-Carlo / exact-enumeration cases + all-pairs notation / ranges
/// checks. The fuzz found no discrepancy; the cases below are the ones that
/// exercise paths the module tests did not pin explicitly (two trips, three
/// pairs, quads + trips, wheel straight flush, board-blocked combos left in
/// the input range, opponent-count clamping at both ends, the all-lose
/// standard-error floor, and a range sampled against itself).
library;

import 'package:allin/engine/equity.dart';
import 'package:allin/engine/evaluator.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectResult(
  EquityResult r, {
  required double equity,
  required int win,
  required int tie,
  required int lose,
  required double se,
  required bool exact,
}) {
  expect(r.win, win);
  expect(r.tie, tie);
  expect(r.lose, lose);
  expect(r.samples, win + tie + lose);
  expect(r.equity, equity);
  expect(r.se, se);
  expect(r.exact, exact);
}

void main() {
  group('evaluator edge hands (TS-pinned score, category and name)', () {
    const cases = <(List<int>, int, int, String)>[
      // two trips -> full house of the higher trips
      (
        [50, 49, 48, 46, 45, 44, 3],
        7262208,
        6,
        'Full House, Aces full of Kings',
      ),
      // three pairs -> top two, third pair rank is the kicker
      ([50, 49, 46, 45, 42, 41, 39], 3070976, 2, 'Two Pair, Aces & Kings'),
      // quads + trips -> trips rank is the kicker
      ([50, 49, 48, 51, 46, 45, 44], 8310784, 7, 'Four of a Kind, Aces'),
      ([50, 49, 48, 51, 46, 45, 0], 8310784, 7, 'Four of a Kind, Aces'),
      // A-7 hearts: seven-high straight flush (not the wheel)
      ([50, 2, 6, 10, 14, 18, 22], 8847360, 8, 'Straight Flush, Seven high'),
      // wheel straight flush with a pair of kings on the side
      ([2, 6, 10, 14, 50, 45, 44], 8716288, 8, 'Straight Flush, Five high'),
      // 6-card flush + straight: flush wins, top five flush cards packed
      ([30, 26, 22, 18, 12, 50, 46], 6216071, 5, 'Flush, Ace high'),
      ([2, 1, 0, 6, 5, 4, 11], 6496256, 6, 'Full House, Threes full of Twos'),
      ([34, 38, 42, 46, 50, 30, 26], 9306112, 8, 'Royal Flush'),
      // 7-card straight: highest window
      ([0, 5, 10, 15, 16, 21, 26], 4718592, 4, 'Straight, Eight high'),
      // wheel with trips of fives
      ([48, 1, 6, 11, 12, 13, 14], 4521984, 4, 'Straight, Five high'),
      ([48, 49, 2, 3, 4, 5, 10], 3027968, 2, 'Two Pair, Aces & Threes'),
      ([48, 45, 42, 39, 28, 25, 22], 974009, 0, 'Ace High'),
      ([48, 49, 46, 43, 36, 29, 22], 2022576, 1, 'Pair of Aces'),
      ([0, 1, 6, 11, 12, 21, 30], 1218384, 1, 'Pair of Twos'),
      // royal flush beats the trips of aces it sits next to
      ([50, 46, 42, 38, 34, 49, 48], 9306112, 8, 'Royal Flush'),
      // straight flush (6 high) beats the trips of sixes
      ([2, 6, 10, 14, 18, 17, 16], 8781824, 8, 'Straight Flush, Six high'),
      // flush beats trips of aces
      ([50, 46, 42, 38, 30, 49, 48], 6216889, 5, 'Flush, Ace high'),
    ];
    for (final (cards, score, cat, name) in cases) {
      test('$cards -> $name', () {
        final e = evaluateInts(cards);
        expect(e.score, score);
        expect(e.category, HandCategory.values[cat]);
        expect(e.name, name);
        expect(evaluateScore(cards), score);
      });
    }
  });

  group('equityVsRange with board-blocked combos left in the input', () {
    test(
      'flop, 16 combos incl. [47,19] (19 is on the board), seed 577593827',
      () {
        final r = equityVsRange(
          [43, 48],
          [25, 19, 4],
          [
            [12, 1],
            [12, 2],
            [12, 3],
            [13, 0],
            [13, 2],
            [13, 3],
            [14, 0],
            [14, 1],
            [14, 3],
            [15, 0],
            [15, 1],
            [15, 2],
            [44, 16],
            [45, 17],
            [46, 18],
            [47, 19],
          ],
          iters: 221,
          seed: 577593827,
        );
        _expectResult(
          r,
          equity: 0.5746606334841629,
          win: 127,
          tie: 0,
          lose: 94,
          se: 0.0332565639972595,
          exact: false,
        );
      },
    );

    test('flop, 46 combos incl. hero/board clashes, seed 790946159', () {
      final r = equityVsRange(
        [27, 11],
        [23, 16, 42],
        [
          [36, 21],
          [36, 22],
          [36, 23],
          [37, 20],
          [37, 22],
          [37, 23],
          [38, 20],
          [38, 21],
          [38, 23],
          [39, 20],
          [39, 21],
          [39, 22],
          [44, 24],
          [45, 25],
          [46, 26],
          [47, 27],
          [48, 16],
          [49, 17],
          [50, 18],
          [51, 19],
          [48, 49],
          [48, 50],
          [48, 51],
          [49, 50],
          [49, 51],
          [50, 51],
          [36, 4],
          [37, 5],
          [38, 6],
          [39, 7],
          [28, 1],
          [28, 2],
          [28, 3],
          [29, 0],
          [29, 2],
          [29, 3],
          [30, 0],
          [30, 1],
          [30, 3],
          [31, 0],
          [31, 1],
          [31, 2],
          [32, 8],
          [33, 9],
          [34, 10],
          [35, 11],
        ],
        iters: 323,
        seed: 790946159,
      );
      _expectResult(
        r,
        equity: 0.34520123839009287,
        win: 111,
        tie: 1,
        lose: 211,
        se: 0.026453846917429066,
        exact: false,
      );
    });
  });

  group('equityVsField clamping and se floor (TS-pinned)', () {
    test('0 opponents clamps to 1', () {
      final r = equityVsField(
        [8, 37],
        [45, 26, 33],
        0,
        iters: 276,
        seed: 634285042,
      );
      _expectResult(
        r,
        equity: 0.3894927536231884,
        win: 100,
        tie: 15,
        lose: 161,
        se: 0.02935219349000498,
        exact: false,
      );
      expect(
        r,
        equityVsField([8, 37], [45, 26, 33], 1, iters: 276, seed: 634285042),
      );
    });

    test('10 opponents clamps to 8 (preflop, 16 opponent cards drawn)', () {
      final r = equityVsField([16, 27], [], 10, iters: 287, seed: 413348075);
      _expectResult(
        r,
        equity: 0.09610917537746806,
        win: 22,
        tie: 13,
        lose: 252,
        se: 0.017398005591347375,
        exact: false,
      );
      expect(r, equityVsField([16, 27], [], 8, iters: 287, seed: 413348075));
    });

    test('river, every trial lost: equity 0, se = sqrt(1e-9 / n)', () {
      final r = equityVsField(
        [2, 13],
        [11, 26, 28, 50, 22],
        9,
        iters: 290,
        seed: 654676017,
      );
      _expectResult(
        r,
        equity: 0,
        win: 0,
        tie: 0,
        lose: 290,
        se: 1.8569533817705187e-06,
        exact: false,
      );
    });
  });

  test(
    'equityRangeVsRange: a range against itself on the turn (TS-pinned)',
    () {
      const range = <List<int>>[
        [44, 28],
        [45, 29],
        [46, 30],
        [47, 31],
        [40, 16],
        [41, 17],
        [42, 18],
        [43, 19],
        [40, 20],
        [41, 21],
        [42, 22],
        [43, 23],
        [36, 24],
        [37, 25],
        [38, 26],
        [39, 27],
      ];
      final r = equityRangeVsRange(
        range,
        [45, 1, 51, 23],
        range,
        iters: 323,
        seed: 27662204,
      );
      _expectResult(
        r,
        equity: 0.4953560371517028,
        win: 132,
        tie: 56,
        lose: 135,
        se: 0.0278195441917611,
        exact: false,
      );
    },
  );
}
