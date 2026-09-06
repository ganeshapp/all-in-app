import 'package:allin/engine/notation.dart';
import 'package:flutter_test/flutter_test.dart';

// allLabels() order pinned from the desktop TypeScript (Node 23).
const List<String> _labelsRef = [
  'AA',
  'AKs',
  'AQs',
  'AJs',
  'ATs',
  'A9s',
  'A8s',
  'A7s',
  'A6s',
  'A5s',
  'A4s',
  'A3s',
  'A2s', //
  'AKo',
  'KK',
  'KQs',
  'KJs',
  'KTs',
  'K9s',
  'K8s',
  'K7s',
  'K6s',
  'K5s',
  'K4s',
  'K3s',
  'K2s', //
  'AQo',
  'KQo',
  'QQ',
  'QJs',
  'QTs',
  'Q9s',
  'Q8s',
  'Q7s',
  'Q6s',
  'Q5s',
  'Q4s',
  'Q3s',
  'Q2s', //
  'AJo',
  'KJo',
  'QJo',
  'JJ',
  'JTs',
  'J9s',
  'J8s',
  'J7s',
  'J6s',
  'J5s',
  'J4s',
  'J3s',
  'J2s', //
  'ATo',
  'KTo',
  'QTo',
  'JTo',
  'TT',
  'T9s',
  'T8s',
  'T7s',
  'T6s',
  'T5s',
  'T4s',
  'T3s',
  'T2s', //
  'A9o',
  'K9o',
  'Q9o',
  'J9o',
  'T9o',
  '99',
  '98s',
  '97s',
  '96s',
  '95s',
  '94s',
  '93s',
  '92s', //
  'A8o',
  'K8o',
  'Q8o',
  'J8o',
  'T8o',
  '98o',
  '88',
  '87s',
  '86s',
  '85s',
  '84s',
  '83s',
  '82s', //
  'A7o',
  'K7o',
  'Q7o',
  'J7o',
  'T7o',
  '97o',
  '87o',
  '77',
  '76s',
  '75s',
  '74s',
  '73s',
  '72s', //
  'A6o',
  'K6o',
  'Q6o',
  'J6o',
  'T6o',
  '96o',
  '86o',
  '76o',
  '66',
  '65s',
  '64s',
  '63s',
  '62s', //
  'A5o',
  'K5o',
  'Q5o',
  'J5o',
  'T5o',
  '95o',
  '85o',
  '75o',
  '65o',
  '55',
  '54s',
  '53s',
  '52s', //
  'A4o',
  'K4o',
  'Q4o',
  'J4o',
  'T4o',
  '94o',
  '84o',
  '74o',
  '64o',
  '54o',
  '44',
  '43s',
  '42s', //
  'A3o',
  'K3o',
  'Q3o',
  'J3o',
  'T3o',
  '93o',
  '83o',
  '73o',
  '63o',
  '53o',
  '43o',
  '33',
  '32s', //
  'A2o',
  'K2o',
  'Q2o',
  'J2o',
  'T2o',
  '92o',
  '82o',
  '72o',
  '62o',
  '52o',
  '42o',
  '32o',
  '22',
];

void main() {
  test('labelAt / grid convention', () {
    expect(labelAt(0, 0), 'AA');
    expect(labelAt(0, 1), 'AKs');
    expect(labelAt(1, 0), 'AKo');
    expect(labelAt(12, 12), '22');
    expect(labelAt(12, 0), 'A2o');
    expect(labelAt(0, 12), 'A2s');
    expect(labelAt(5, 7), '97s');
    expect(labelAt(7, 5), '97o');
  });

  test('allLabels() is 169 labels in the pinned row-major order', () {
    final labels = allLabels();
    expect(labels.length, 169);
    expect(labels, _labelsRef);
    expect(labels.toSet().length, 169);
  });

  test('kindOf / comboCount / combosInSet / TOTAL_COMBOS', () {
    expect(kindOf('AA'), ComboKind.pair);
    expect(kindOf('AKs'), ComboKind.suited);
    expect(kindOf('AKo'), ComboKind.offsuit);
    expect(comboCount('AA'), 6);
    expect(comboCount('AKs'), 4);
    expect(comboCount('AKo'), 12);
    expect(kTotalCombos, 1326);
    expect(combosInSet(allLabels()), kTotalCombos);
    expect(combosInSet(const ['AA', 'AKs', 'AKo']), 22);
    expect(combosInSet(const <String>[]), 0);
  });

  test('labelToCombos pinned order (desktop)', () {
    expect(labelToCombos('AA'), const [
      ('Ac', 'Ad'),
      ('Ac', 'Ah'),
      ('Ac', 'As'),
      ('Ad', 'Ah'),
      ('Ad', 'As'),
      ('Ah', 'As'),
    ]);
    expect(labelToCombos('22'), const [
      ('2c', '2d'),
      ('2c', '2h'),
      ('2c', '2s'),
      ('2d', '2h'),
      ('2d', '2s'),
      ('2h', '2s'),
    ]);
    expect(labelToCombos('AKs'), const [
      ('Ac', 'Kc'),
      ('Ad', 'Kd'),
      ('Ah', 'Kh'),
      ('As', 'Ks'),
    ]);
    expect(labelToCombos('T9s'), const [
      ('Tc', '9c'),
      ('Td', '9d'),
      ('Th', '9h'),
      ('Ts', '9s'),
    ]);
    expect(labelToCombos('AKo'), const [
      ('Ac', 'Kd'),
      ('Ac', 'Kh'),
      ('Ac', 'Ks'),
      ('Ad', 'Kc'),
      ('Ad', 'Kh'),
      ('Ad', 'Ks'),
      ('Ah', 'Kc'),
      ('Ah', 'Kd'),
      ('Ah', 'Ks'),
      ('As', 'Kc'),
      ('As', 'Kd'),
      ('As', 'Kh'),
    ]);
    expect(labelToCombos('72o'), const [
      ('7c', '2d'),
      ('7c', '2h'),
      ('7c', '2s'),
      ('7d', '2c'),
      ('7d', '2h'),
      ('7d', '2s'),
      ('7h', '2c'),
      ('7h', '2d'),
      ('7h', '2s'),
      ('7s', '2c'),
      ('7s', '2d'),
      ('7s', '2h'),
    ]);
  });

  test('every label expands to comboCount combos, all 1326 distinct', () {
    final seen = <String>{};
    for (final l in allLabels()) {
      final combos = labelToCombos(l);
      expect(combos.length, comboCount(l), reason: l);
      for (final (a, b) in combos) {
        expect(a, isNot(b));
        expect(cardsToLabel(a, b), l);
        expect(seen.add('$a$b'), isTrue, reason: '$a$b duplicated');
      }
    }
    expect(seen.length, 1326);
  });

  test('cardsToLabel', () {
    expect(cardsToLabel('As', 'Kd'), 'AKo');
    expect(cardsToLabel('Kd', 'As'), 'AKo');
    expect(cardsToLabel('As', 'Ks'), 'AKs');
    expect(cardsToLabel('Ts', 'Td'), 'TT');
    expect(cardsToLabel('2c', '7d'), '72o');
    expect(cardsToLabel('7d', '2c'), '72o');
    expect(cardsToLabel('Jh', 'Qh'), 'QJs');
  });

  test('prettyLabel is identity', () {
    expect(prettyLabel('AKs'), 'AKs');
    expect(prettyLabel('AA'), 'AA');
  });
}
