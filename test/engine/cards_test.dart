import 'package:allin/engine/cards.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _deckRef = [
  '2c', '2d', '2h', '2s', '3c', '3d', '3h', '3s', '4c', '4d', '4h', '4s', //
  '5c', '5d', '5h', '5s', '6c', '6d', '6h', '6s', '7c', '7d', '7h', '7s', //
  '8c', '8d', '8h', '8s', '9c', '9d', '9h', '9s', 'Tc', 'Td', 'Th', 'Ts', //
  'Jc', 'Jd', 'Jh', 'Js', 'Qc', 'Qd', 'Qh', 'Qs', 'Kc', 'Kd', 'Kh', 'Ks', //
  'Ac', 'Ad', 'Ah', 'As',
];

void main() {
  group('card <-> int encoding', () {
    test('pinned values', () {
      expect(cardToInt('2c'), 0);
      expect(cardToInt('2d'), 1);
      expect(cardToInt('2h'), 2);
      expect(cardToInt('2s'), 3);
      expect(cardToInt('Ac'), 48);
      expect(cardToInt('As'), 51);
      expect(cardToInt('Td'), 33);
      expect(cardToInt('Th'), 34);
      expect(cardToInt('Kd'), 45);
      expect(cardToInt('Kh'), 46);
      expect(intToCard(0), '2c');
      expect(intToCard(51), 'As');
      expect(intToCard(33), 'Td');
    });

    test('round-trips all 52 cards', () {
      for (int i = 0; i < 52; i++) {
        final c = intToCard(i);
        expect(cardToInt(c), i);
        expect(rankOf(i), (i >> 2) + 2);
        expect(suitOf(i), i & 3);
        expect(cardRank(c), kRanks[i >> 2]);
        expect(cardSuit(c), kSuits[i & 3]);
      }
      expect(rankOf(cardToInt('Ah')), 14);
      expect(rankOf(cardToInt('2h')), 2);
      expect(suitOf(cardToInt('Ah')), 2);
    });
  });

  group('deck', () {
    test('makeDeck order matches ints', () {
      final d = makeDeck();
      expect(d, _deckRef);
      for (int i = 0; i < 52; i++) {
        expect(cardToInt(d[i]), i);
      }
    });

    test('makeDeckInts is 0..51', () {
      expect(makeDeckInts(), List<int>.generate(52, (i) => i));
    });
  });

  group('shuffle', () {
    test('is an in-place permutation returning the same list', () {
      final d = makeDeck();
      final r = shuffle(d, rng: Mulberry32(1));
      expect(identical(r, d), isTrue);
      expect(d.length, 52);
      expect(d.toSet(), _deckRef.toSet());
      expect(d, isNot(_deckRef));
    });

    test('is deterministic under a seeded rng and matches the TS idiom', () {
      final a = shuffle(makeDeckInts(), rng: Mulberry32(0xa11a));
      final b = shuffle(makeDeckInts(), rng: Mulberry32(0xa11a));
      expect(a, b);
      // Same as golden_gen.ts: j = (rand() * (k + 1)) | 0 with mulberry32(0xa11a).
      final rand = Mulberry32(0xa11a);
      final deck = List<int>.generate(52, (k) => k);
      for (int k = 51; k > 0; k--) {
        final j = (rand.next() * (k + 1)).toInt();
        final t = deck[k];
        deck[k] = deck[j];
        deck[j] = t;
      }
      expect(a, deck);
      // First corpus deal from test/golden/evaluator.json.
      expect(a.sublist(0, 5), [18, 16, 9, 27, 1]);
    });

    test('works with the default rng and on short lists', () {
      expect(shuffle(<int>[]), isEmpty);
      expect(shuffle([7]), [7]);
      final d = shuffle(makeDeckInts());
      expect(d.toSet().length, 52);
    });
  });

  group('display helpers', () {
    test('suit symbols and colours', () {
      expect(kSuitSymbol['s'], '♠');
      expect(kSuitSymbol['h'], '♥');
      expect(kSuitSymbol['d'], '♦');
      expect(kSuitSymbol['c'], '♣');
      expect(isRedSuit('h'), isTrue);
      expect(isRedSuit('d'), isTrue);
      expect(isRedSuit('s'), isFalse);
      expect(isRedSuit('c'), isFalse);
    });
  });
}
