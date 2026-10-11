/// Counting outs (`lib/engine/outs.dart`) — a 1:1 port of the desktop's
/// `src/engine/outs.ts`, pinned to the counts every poker book gives, because
/// a coach that disagrees with the 2/4 rule lesson in its own Study tab is
/// worse than one that says nothing.
library;

import 'package:allin/engine/cards.dart';
import 'package:allin/engine/equity.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/outs.dart';
import 'package:flutter_test/flutter_test.dart';

List<IntCombo> _range(List<String> labels) => [
  for (final l in labels) ...labelToCombos(l).map(comboToInts),
];

List<int> _board(List<String> cards) => [for (final c in cards) cardToInt(c)];

void main() {
  final range = _range([
    '77',
    '88',
    '99',
    'TT',
    'JJ',
    'QQ',
    'KK',
    'AA',
    'AJs',
    'ATs',
    'KQs',
    'QJs',
    'JTs',
    'T9s',
    '98s',
    '87s',
    '76s',
    '65s',
    '54s',
    'AQo',
    'AJo',
    'KQo',
  ]);

  group('the textbook counts', () {
    test('a bare flush draw is nine outs, named as nine hearts', () {
      final r = countOuts(
        comboToInts(('7h', '6h')),
        _board(['Ah', '9s', '2h']),
        [range],
      );
      expect(r.count, 9);
      expect(r.groups.first.cardsLabel, 'nine hearts');
      expect(r.groups.first.makes, 'a flush');
    });

    test('a flush draw with two cards above the board is fifteen', () {
      final r = countOuts(
        comboToInts(('Ah', 'Kh')),
        _board(['9h', '5s', '2h']),
        [range],
      );
      expect(r.count, 15);
    });

    test('an open-ended straight draw is eight outs', () {
      final r = countOuts(
        comboToInts(('9s', '8s')),
        _board(['7h', '6d', '2c']),
        [range],
      );
      expect(r.count, 8);
    });

    test('a made set is ahead, so it is not counted as drawing', () {
      final r = countOuts(
        comboToInts(('7s', '7d')),
        _board(['7h', 'Kd', '2c']),
        [range],
      );
      expect(r.ahead, isTrue);
      expect(r.count, 0);
      expect(describeOuts(r), isEmpty);
    });
  });

  // The hand that cost 100 bb. The coach graded calling here as a "thin spot"
  // because it measured against random cards; against the hands that actually
  // keep betting it is four outs to the small end of a straight.
  group('queen-high with a gutshot on 6h 5s 4h', () {
    final r = countOuts(comboToInts(('Qs', '2d')), _board(['6h', '5s', '4h']), [
      range,
      range,
    ]);

    test('is four outs, not seven', () => expect(r.count, 4));

    test('names the cards', () {
      expect(r.groups.first.cardsLabel, 'the four 3s');
      expect(describeOuts(r), contains('the four 3s'));
    });

    test('warns that it is the small end of the straight', () {
      expect(r.groups.first.caution, isNotNull);
      expect(describeOuts(r), contains('low end'));
    });

    test('and that it does not always hold up when it lands', () {
      expect(r.holdUp, isNotNull);
      expect(r.holdUp! < 0.9, isTrue);
    });

    test('is behind almost every hand right now', () {
      expect(r.share < 0.2, isTrue);
      expect(r.ahead, isFalse);
    });
  });

  group('the 2/4 rule the Study tab teaches', () {
    test('nine outs is 18% on one card and 36% by the river', () {
      expect((ruleOfTwoFour(9, 1) * 100).round(), 18);
      expect((ruleOfTwoFour(9, 2) * 100).round(), 36);
    });

    test('four outs is 8% on one card', () {
      expect((ruleOfTwoFour(4, 1) * 100).round(), 8);
    });
  });
}
