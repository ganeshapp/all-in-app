import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:allin/engine/cards.dart';
import 'package:allin/engine/evaluator.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

// (cards, category, score, name) computed with Node 23 from the desktop
// evaluator.ts.
const List<(String, int, int, String)> _pins = [
  ('Ah Kh Qh Jh Th', 8, 9306112, 'Royal Flush'),
  ('9c 8c 7c 6c 5c', 8, 8978432, 'Straight Flush, Nine high'),
  ('Ah Ad Ac As Kd', 7, 8310784, 'Four of a Kind, Aces'),
  ('Ah Ad Ac Kd Ks', 6, 7262208, 'Full House, Aces full of Kings'),
  ('Ah Jh 9h 5h 2h', 5, 6207826, 'Flush, Ace high'),
  ('9c 8d 7h 6s 5c', 4, 4784128, 'Straight, Nine high'),
  ('5h 4d 3c 2s Ah', 4, 4521984, 'Straight, Five high'),
  ('Ah Ad Ac Kd Qs', 3, 4119552, 'Three of a Kind, Aces'),
  ('Ah Ad Kc Kd Qs', 2, 3070976, 'Two Pair, Aces & Kings'),
  ('Ah Ad Kc Qd Js', 1, 2022576, 'Pair of Aces'),
  ('Ah Jd 9c 5d 3s', 0, 964947, 'Ace High'),
  ('2h 7d Ah Kh Qh Jh Th', 8, 9306112, 'Royal Flush'),
  ('As Ad Kh Kd Kc 2s 3d', 6, 7200768, 'Full House, Kings full of Aces'),
  ('6h 5d 4c 3s 2h', 4, 4587520, 'Straight, Six high'),
  ('Ah Kh Qh Jh 9h', 5, 6216889, 'Flush, Ace high'),
  ('Ah Kh Qh Th 9h', 5, 6216873, 'Flush, Ace high'),
  ('Ah Ad Kc Qd Ts', 1, 2022560, 'Pair of Aces'),
  ('Ah Ad Kc Kd Qs Qd', 2, 3070976, 'Two Pair, Aces & Kings'),
  ('Ah Ad Ac Kd Kc Ks 2d', 6, 7262208, 'Full House, Aces full of Kings'),
  ('2c 2d 2h 3c 3d 3h 4s', 6, 6496256, 'Full House, Threes full of Twos'),
  ('Ah Kd 5c 4d 3s 2h 2d', 4, 4521984, 'Straight, Five high'),
  ('7h 7d 7c 7s 2h 2d 3c', 7, 7811072, 'Four of a Kind, Sevens'),
];

EvaluatedHand _ev(String hand) => evaluateCards(hand.split(' '));

void main() {
  group('evaluator', () {
    test('pinned vectors: category, score and name match the desktop', () {
      for (final (hand, cat, score, name) in _pins) {
        final e = _ev(hand);
        expect(e.category.index, cat, reason: hand);
        expect(e.score, score, reason: hand);
        expect(e.name, name, reason: hand);
        expect(categoryOfScore(e.score), e.category);
        expect(handName(e.score), name);
      }
    });

    test('golden corpus: every entry matches category AND score exactly', () {
      final json =
          jsonDecode(File('test/golden/evaluator.json').readAsStringSync())
              as Map<String, dynamic>;
      final corpus = (json['corpus'] as List).cast<Map<String, dynamic>>();
      expect(corpus.length, 600);
      for (int i = 0; i < corpus.length; i++) {
        final entry = corpus[i];
        final cards = (entry['cards'] as List).cast<int>();
        final e = evaluateInts(cards);
        expect(e.category.index, entry['category'], reason: 'corpus $i');
        expect(e.score, entry['score'], reason: 'corpus $i');
        // Typed buffers and explicit lengths must agree with plain lists.
        final buf = Int32List(7);
        for (int k = 0; k < cards.length; k++) {
          buf[k] = cards[k];
        }
        expect(evaluateScore(buf, cards.length), e.score);
        expect(evaluateScore(Int32List.fromList(cards)), e.score);
      }
    });

    // ---- engine_test.ts assertions ----
    test('categories', () {
      expect(_ev('Ah Kh Qh Jh Th').category, HandCategory.straightFlush);
      expect(_ev('9c 8c 7c 6c 5c').category, HandCategory.straightFlush);
      expect(_ev('Ah Ad Ac As Kd').category, HandCategory.quads);
      expect(_ev('Ah Ad Ac Kd Ks').category, HandCategory.fullHouse);
      expect(_ev('Ah Jh 9h 5h 2h').category, HandCategory.flush);
      expect(_ev('9c 8d 7h 6s 5c').category, HandCategory.straight);
      expect(_ev('5h 4d 3c 2s Ah').category, HandCategory.straight);
      expect(_ev('Ah Ad Ac Kd Qs').category, HandCategory.trips);
      expect(_ev('Ah Ad Kc Kd Qs').category, HandCategory.twoPair);
      expect(_ev('Ah Ad Kc Qd Js').category, HandCategory.pair);
      expect(_ev('Ah Jd 9c 5d 3s').category, HandCategory.highCard);
    });

    test('category ordering', () {
      final sf = _ev('9c 8c 7c 6c 5c').score;
      final quads = _ev('Ah Ad Ac As Kd').score;
      final fh = _ev('Ah Ad Ac Kd Ks').score;
      final flush = _ev('Ah Jh 9h 5h 2h').score;
      final straight = _ev('9c 8d 7h 6s 5c').score;
      final trips = _ev('Ah Ad Ac Kd Qs').score;
      final twoPair = _ev('Ah Ad Kc Kd Qs').score;
      final pair = _ev('Ah Ad Kc Qd Js').score;
      final high = _ev('Ah Jd 9c 5d 3s').score;
      expect(
        sf > quads && quads > fh && fh > flush && flush > straight,
        isTrue,
      );
      expect(
        straight > trips && trips > twoPair && twoPair > pair && pair > high,
        isTrue,
      );
    });

    test('tie-breaks', () {
      expect(
        _ev('Ah Ad Kc Qd Js').score > _ev('Ah Ad Kc Qd Ts').score,
        isTrue,
        reason: 'pair kicker J > T',
      );
      expect(
        _ev('6h 5d 4c 3s 2h').score > _ev('5h 4d 3c 2s Ah').score,
        isTrue,
        reason: '6-high straight beats wheel',
      );
      expect(
        _ev('Ah Kh Qh Jh 9h').score > _ev('Ah Kh Qh Th 9h').score,
        isTrue,
        reason: 'flush 2nd kicker',
      );
    });

    test('7-card best selection', () {
      expect(
        evaluateInts(
          ['2h', '7d', 'Ah', 'Kh', 'Qh', 'Jh', 'Th'].map(cardToInt).toList(),
        ).category,
        HandCategory.straightFlush,
      );
      expect(
        evaluateInts(
          ['As', 'Ad', 'Kh', 'Kd', 'Kc', '2s', '3d'].map(cardToInt).toList(),
        ).category,
        HandCategory.fullHouse,
      );
    });

    test('score encoding details', () {
      expect(kCat, 1048576);
      // Royal: 8 * 16^5 + 14 * 16^4.
      expect(_ev('Ah Kh Qh Jh Th').score, 8 * kCat + 14 * 65536);
      // Wheel straight flush packs 5, not 14.
      expect(_ev('5h 4h 3h 2h Ah').score, 8 * kCat + 5 * 65536);
      expect(_ev('5h 4h 3h 2h Ah').name, 'Straight Flush, Five high');
      // Two pair with three pairs: kicker is the third pair's rank.
      expect(
        _ev('Ah Ad Kc Kd Qs Qd 2c').score,
        2 * kCat + (14 << 16) + (13 << 12) + (12 << 8),
      );
      // Trips with a lower pair on board is a full house.
      expect(
        _ev('Kh Kd Kc 2s 2d 9c 8d').name,
        'Full House, Kings full of Twos',
      );
      // Full house with two trips uses the higher trips as the pair.
      expect(
        _ev('Kh Kd Kc 2s 2d 2c 8d').name,
        'Full House, Kings full of Twos',
      );
      // Flush beats straight even when both present.
      expect(_ev('Ah Kh Qh Jh 9c Th 2h').name, 'Royal Flush');
      expect(_ev('Ah Kh Qh Jh 9c Tc 2h').name, 'Flush, Ace high');
    });

    test('every name template appears verbatim', () {
      expect(_ev('Ah Kh Qh Jh Th').name, 'Royal Flush');
      expect(_ev('9c 8c 7c 6c 5c').name, 'Straight Flush, Nine high');
      expect(_ev('Ah Ad Ac As Kd').name, 'Four of a Kind, Aces');
      expect(_ev('Ah Ad Ac Kd Ks').name, 'Full House, Aces full of Kings');
      expect(_ev('Ah Jh 9h 5h 2h').name, 'Flush, Ace high');
      expect(_ev('5h 4d 3c 2s Ah').name, 'Straight, Five high');
      expect(_ev('6h 5d 4c 3s 2h').name, 'Straight, Six high');
      expect(_ev('Ah Ad Ac Kd Qs').name, 'Three of a Kind, Aces');
      expect(_ev('Ah Ad Kc Kd Qs').name, 'Two Pair, Aces & Kings');
      expect(_ev('Ah Ad Kc Qd Js').name, 'Pair of Aces');
      expect(_ev('Ah Jd 9c 5d 3s').name, 'Ace High');
      expect(_ev('2h 3d 4c 5d 7s').name, 'Seven High');
      expect(_ev('6h 6d 4c 5d 7s').name, 'Pair of Sixes');
      expect(_ev('3h 3d 3c 5d 7s').name, 'Three of a Kind, Threes');
      expect(_ev('Th Td 5c 5d 7s').name, 'Two Pair, Tens & Fives');
    });

    test('compareHands', () {
      final a = _ev('Ah Ad Kc Qd Js');
      final b = _ev('Ah Ad Kc Qd Ts');
      expect(compareHands(a, b) > 0, isTrue);
      expect(compareHands(b, a) < 0, isTrue);
      expect(compareHands(a, _ev('Ac As Kd Qc Jd')), 0);
      expect(compareHands(a, b), a.score - b.score);
    });

    test('scores are unique per distinct 5-card strength class', () {
      // Every score must decode back to the same category it was built with.
      for (int i = 0; i < 52; i++) {
        for (int j = i + 1; j < 52; j++) {
          for (int k = j + 1; k < 52; k += 7) {
            for (int l = k + 1; l < 52; l += 11) {
              for (int m = l + 1; m < 52; m += 13) {
                final s = evaluateScore([i, j, k, l, m]);
                expect(s ~/ kCat, inInclusiveRange(0, 8));
                expect(s, lessThanOrEqualTo(9306112));
              }
            }
          }
        }
      }
    });

    test('does not crash on fewer than five cards', () {
      expect(evaluateInts([0, 1, 2, 3]).category, HandCategory.quads);
      expect(
        evaluateInts([cardToInt('Ah'), cardToInt('Ad')]).name,
        'Pair of Aces',
      );
      expect(evaluateInts(<int>[]).score, 0);
    });

    test('performance: 4000-trial hand-vs-range sim under 400 ms', () {
      // AKs vs {QQ+, AKs, AKo} on a random 5-card runout, seeded so the
      // workload is fixed. Mirrors the shape of equityVsRange.
      final hero = [cardToInt('As'), cardToInt('Ks')];
      final combos = <List<int>>[];
      for (final label in ['AA', 'KK', 'QQ', 'AKs', 'AKo']) {
        for (final (a, b) in labelToCombos(label)) {
          final ia = cardToInt(a);
          final ib = cardToInt(b);
          if (ia == hero[0] ||
              ia == hero[1] ||
              ib == hero[0] ||
              ib == hero[1]) {
            continue;
          }
          combos.add([ia, ib]);
        }
      }
      final rng = Mulberry32(hashSeed('AsKs|'));
      final deck = Int32List(52);
      final heroBuf = Int32List(7);
      final villBuf = Int32List(7);
      heroBuf[0] = hero[0];
      heroBuf[1] = hero[1];
      int win = 0, tie = 0, lose = 0;
      final sw = Stopwatch()..start();
      for (int t = 0; t < 4000; t++) {
        final combo = combos[rng.nextInt(combos.length)];
        villBuf[0] = combo[0];
        villBuf[1] = combo[1];
        int n = 0;
        for (int c = 0; c < 52; c++) {
          if (c == hero[0] || c == hero[1] || c == combo[0] || c == combo[1]) {
            continue;
          }
          deck[n++] = c;
        }
        for (int i = 0; i < 5; i++) {
          final j = i + rng.nextInt(n - i);
          final tmp = deck[i];
          deck[i] = deck[j];
          deck[j] = tmp;
          heroBuf[2 + i] = deck[i];
          villBuf[2 + i] = deck[i];
        }
        final hs = evaluateScore(heroBuf);
        final vs = evaluateScore(villBuf);
        if (hs > vs) {
          win++;
        } else if (hs < vs) {
          lose++;
        } else {
          tie++;
        }
      }
      sw.stop();
      expect(win + tie + lose, 4000);
      // AKs vs a premium range is roughly 40–50 % equity — sanity only.
      final eq = (win + tie / 2) / 4000;
      expect(eq, inInclusiveRange(0.35, 0.55));
      expect(
        sw.elapsedMilliseconds,
        lessThan(400),
        reason: 'sim took ${sw.elapsedMilliseconds} ms',
      );
    });
  });
}
