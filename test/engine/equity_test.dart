import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:allin/engine/cards.dart';
import 'package:allin/engine/equity.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/prng.dart';
import 'package:flutter_test/flutter_test.dart';

// Every pinned number below was computed with Node 23 running the desktop
// `src/engine/equity.ts` directly (`node --experimental-transform-types`),
// so seeded Monte-Carlo runs must reproduce the TypeScript exactly.

List<int> _ci(List<String> cards) => cards.map(cardToInt).toList();

List<IntCombo> _combos(List<String> labels) => [
  for (final l in labels)
    for (final c in labelToCombos(l)) comboToInts(c),
];

IntCombo _hand(String a, String b) => comboToInts((a, b));

void _expectCounts(
  EquityResult r,
  int win,
  int tie,
  int lose, {
  bool exact = false,
}) {
  expect(r.win, win);
  expect(r.tie, tie);
  expect(r.lose, lose);
  expect(r.samples, win + tie + lose);
  expect(r.exact, exact);
  if (exact) expect(r.se, 0);
}

void main() {
  final aa = _hand('Ah', 'Ad');
  final aks = _hand('As', 'Ks');
  final kk = _hand('Kh', 'Kd');
  final akhh = _hand('Ah', 'Kh');
  final qq = _combos(['QQ']);

  group('comboToInts / EquityResult', () {
    test('comboToInts maps both cards', () {
      expect(comboToInts(('As', 'Ks')), [51, 47]);
      expect(comboToInts(('2c', '2d')), [0, 1]);
    });

    test('empty result matches the desktop literal', () {
      expect(EquityResult.empty.toJson(), {
        'equity': 0.5,
        'win': 0,
        'tie': 0,
        'lose': 0,
        'samples': 0,
        'se': 0.0,
        'exact': false,
      });
      expect(
        EquityResult.fromJson(EquityResult.empty.toJson()),
        EquityResult.empty,
      );
    });
  });

  group('exact enumeration (parity_test.ts EQ_CASES, TS counts)', () {
    // River vs random: C(45,2) = 990 villain combos.
    test('AhKh on AdKc7s2d9h vs random', () {
      final r = equityVsRandom(
        akhh,
        _ci(['Ad', 'Kc', '7s', '2d', '9h']),
        iters: 10,
      );
      _expectCounts(r, 975, 4, 11, exact: true);
      expect(r.samples, 990);
      expect(r.equity, 0.9868686868686869);
      expect(r.equity > 0.85, isTrue);
    });

    test('7h2c on a royal-flush board: board plays, everyone ties', () {
      final r = equityVsRandom(
        _hand('7h', '2c'),
        _ci(['As', 'Ks', 'Qs', 'Js', 'Ts']),
        iters: 10,
      );
      _expectCounts(r, 0, 990, 0, exact: true);
      expect(r.equity, 0.5);
    });

    test('9c9d on 9h9s2c3d4h: quads win everything', () {
      final r = equityVsRandom(
        _hand('9c', '9d'),
        _ci(['9h', '9s', '2c', '3d', '4h']),
        iters: 10,
      );
      _expectCounts(r, 990, 0, 0, exact: true);
      expect(r.equity, 1.0);
    });

    // River vs ranges (blockers + suited/offsuit/pair label expansion).
    test('AhAd on KcQdJs3d2h vs AKs,AKo,TT,T9s', () {
      final r = equityVsRange(
        aa,
        _ci(['Kc', 'Qd', 'Js', '3d', '2h']),
        _combos(['AKs', 'AKo', 'TT', 'T9s']),
        iters: 10,
      );
      _expectCounts(r, 12, 0, 4, exact: true);
      expect(r.equity, 0.75);
    });

    test('QsJd on Th9c2d8sKd vs QQ,JJ,TT,AKo,AQs', () {
      final r = equityVsRange(
        _hand('Qs', 'Jd'),
        _ci(['Th', '9c', '2d', '8s', 'Kd']),
        _combos(['QQ', 'JJ', 'TT', 'AKo', 'AQs']),
        iters: 10,
      );
      _expectCounts(r, 21, 0, 0, exact: true);
      expect(r.equity, 1.0);
    });

    test('2c2d on AcKcQcJc9c vs A2s,KQo,55', () {
      final r = equityVsRange(
        _hand('2c', '2d'),
        _ci(['Ac', 'Kc', 'Qc', 'Jc', '9c']),
        _combos(['A2s', 'KQo', '55']),
        iters: 10,
      );
      _expectCounts(r, 0, 14, 0, exact: true);
      expect(r.equity, 0.5);
    });

    // Turn vs ranges (exact: combos × 44 rivers).
    test('AhKh on AdKc7s2d vs QQ,JJ,AKo', () {
      final r = equityVsRange(
        akhh,
        _ci(['Ad', 'Kc', '7s', '2d']),
        _combos(['QQ', 'JJ', 'AKo']),
        iters: 10,
      );
      _expectCounts(r, 504, 132, 24, exact: true);
      expect(r.equity, 0.8636363636363636);
    });

    test('8h7h on 6h5cKd2s vs AA,KK,AKs,66', () {
      final r = equityVsRange(
        _hand('8h', '7h'),
        _ci(['6h', '5c', 'Kd', '2s']),
        _combos(['AA', 'KK', 'AKs', '66']),
        iters: 10,
      );
      _expectCounts(r, 120, 0, 540, exact: true);
      expect(r.equity, 0.18181818181818182);
    });

    test('AsQs on Qc7d3hAs vs 77,A7s,KQs,JTs (hero card on board)', () {
      final r = equityVsRange(
        _hand('As', 'Qs'),
        _ci(['Qc', '7d', '3h', 'As']),
        _combos(['77', 'A7s', 'KQs', 'JTs']),
        iters: 10,
      );
      _expectCounts(r, 355, 0, 140, exact: true);
      expect(r.equity, 0.7171717171717171);
    });

    test('TdTs on 9c8c2h7c vs A9s,JTo,65s,QQ', () {
      final r = equityVsRange(
        _hand('Td', 'Ts'),
        _ci(['9c', '8c', '2h', '7c']),
        _combos(['A9s', 'JTo', '65s', 'QQ']),
        iters: 10,
      );
      _expectCounts(r, 189, 15, 632, exact: true);
      expect(r.equity, 0.23504784688995214);
    });

    test('turn vs QQ enumerates 6 combos x 44 rivers (engine_test.ts)', () {
      final t = equityVsRange(
        akhh,
        _ci(['Ad', 'Kc', '7s', '2d']),
        qq,
        iters: 10,
      );
      expect(t.exact, isTrue);
      expect(t.samples, 6 * 44);
      expect(t.equity > 0.9, isTrue);
    });
  });

  group('equityVsRange (Monte-Carlo, seeded = TS bit-for-bit)', () {
    test('AKs vs QQ 2000 seed 42', () {
      final r = equityVsRange(aks, [], qq, iters: 2000, seed: 42);
      _expectCounts(r, 948, 12, 1040);
      expect(r.equity, 0.477);
      expect(r.se, 0.011168504823833851);
    });

    test('AKs vs QQ 2000 seed 43 / seed 5', () {
      final r43 = equityVsRange(aks, [], qq, iters: 2000, seed: 43);
      _expectCounts(r43, 907, 10, 1083);
      expect(r43.equity, 0.456);
      final r5 = equityVsRange(aks, [], qq, iters: 2000, seed: 5);
      _expectCounts(r5, 953, 9, 1038);
      expect(r5.equity, 0.47875);
      // MC results report their uncertainty.
      expect(r5.exact, isFalse);
      expect(r5.se > 0 && r5.se < 0.02, isTrue);
    });

    test('same seed => identical; different seed => different', () {
      final s1 = equityVsRange(aks, [], qq, iters: 2000, seed: 42);
      final s2 = equityVsRange(aks, [], qq, iters: 2000, seed: 42);
      expect(s1, s2);
      final sDiff = equityVsRange(aks, [], qq, iters: 2000, seed: 43);
      expect(sDiff == s1, isFalse);
    });

    test('flop, hashSeed-derived seed (coach call shape)', () {
      final r = equityVsRange(
        aks,
        _ci(['Kh', '7d', '2c']),
        _combos(['QQ', 'AKo', 'AKs', '77']),
        iters: 500,
        seed: hashSeed('AsKs|Kh7d2c'),
      );
      _expectCounts(r, 190, 180, 130);
      expect(r.equity, 0.56);
      expect(r.se, 0.02219909908081857);
    });

    test('KK vs AA range 1000 seed 1', () {
      final r = equityVsRange(kk, [], _combos(['AA']), iters: 1000, seed: 1);
      _expectCounts(r, 166, 3, 831);
      expect(r.equity, 0.1675);
    });

    test('engine_test.ts sanity at 8000 iters (pinned by seed)', () {
      final r1 = equityVsRange(aks, [], qq, iters: 8000, seed: 102);
      _expectCounts(r1, 3754, 37, 4209);
      expect(r1.equity, closeTo(0.46, 0.04));
      final r2 = equityVsRange(kk, [], _combos(['AA']), iters: 8000, seed: 103);
      _expectCounts(r2, 1441, 46, 6513);
      expect(r2.equity, closeTo(0.18, 0.04));
    });

    test('dead cards: combos sharing a card with hero are dropped', () {
      // Hero AhAd vs "AA": only AcAs survives.
      final r = equityVsRange(aa, [], _combos(['AA']), iters: 100, seed: 1);
      _expectCounts(r, 4, 96, 0);
      expect(r.equity, 0.52);
    });

    test('dead cards: combos sharing a card with the board are dropped', () {
      final r = equityVsRange(
        kk,
        _ci(['Ah', '7c', '2d']),
        _combos(['AKs']),
        iters: 300,
        seed: 9,
      );
      _expectCounts(r, 6, 0, 294);
      expect(r.equity, 0.02);
    });

    test('empty / fully blocked range => empty result, even on the river', () {
      expect(
        equityVsRange(aa, [], [], iters: 100, seed: 1),
        EquityResult.empty,
      );
      expect(
        equityVsRange(
          aa,
          _ci(['Ac', 'As', '2c', '3d', '4h']),
          _combos(['AA']),
          iters: 100,
          seed: 1,
        ),
        EquityResult.empty,
      );
    });

    test('iters 0 => empty result', () {
      expect(equityVsRange(aks, [], qq, iters: 0, seed: 1), EquityResult.empty);
    });

    test('unseeded path draws from the injected rng', () {
      final viaRng = equityVsRange(
        aks,
        [],
        qq,
        iters: 500,
        rng: Mulberry32(42),
      );
      final viaSeed = equityVsRange(aks, [], qq, iters: 500, seed: 42);
      expect(viaRng, viaSeed);
      // Default Random() still produces a sane estimate.
      final r = equityVsRange(aks, [], qq, iters: 3000);
      expect(r.samples, 3000);
      expect(r.equity, closeTo(0.46, 0.06));
    });
  });

  group('equityVsRandom', () {
    test('AA on Ks7d2c 2000 seed 7', () {
      final r = equityVsRandom(
        aa,
        _ci(['Ks', '7d', '2c']),
        iters: 2000,
        seed: 7,
      );
      _expectCounts(r, 1783, 1, 216);
      expect(r.equity, 0.89175);
      expect(r.se, 0.006947371355412058);
      expect(
        r,
        equityVsRandom(aa, _ci(['Ks', '7d', '2c']), iters: 2000, seed: 7),
      );
    });

    test('AA preflop 1000 seed 123', () {
      final r = equityVsRandom(aa, [], iters: 1000, seed: 123);
      _expectCounts(r, 851, 8, 141);
      expect(r.equity, 0.855);
    });

    test('AA vs random ~85% at 6000 iters (engine_test.ts, pinned)', () {
      final r = equityVsRandom(aa, [], iters: 6000, seed: 101);
      _expectCounts(r, 5056, 31, 913);
      expect(r.equity, closeTo(0.85, 0.03));
    });

    test('river is exact; iters ignored', () {
      final r = equityVsRandom(
        _hand('7h', '2c'),
        _ci(['As', 'Ks', 'Qs', 'Js', 'Ts']),
        iters: 10,
      );
      _expectCounts(r, 0, 990, 0, exact: true);
    });

    test('iters 0 => empty result', () {
      expect(equityVsRandom(aks, [], iters: 0, seed: 1), EquityResult.empty);
    });
  });

  group('equityVsField (multiway)', () {
    test('AA vs 3 opponents 1000 seed 11', () {
      final r = equityVsField(aa, [], 3, iters: 1000, seed: 11);
      _expectCounts(r, 646, 7, 347);
      expect(r.equity, closeTo(0.6485, 1e-12));
      expect(r.se, closeTo(0.015097938601014379, 1e-15));
    });

    test('AhKh on AdKc7s vs 2 opponents 800 seed 3', () {
      final r = equityVsField(
        akhh,
        _ci(['Ad', 'Kc', '7s']),
        2,
        iters: 800,
        seed: 3,
      );
      _expectCounts(r, 726, 7, 67);
      expect(r.equity, closeTo(0.911875, 1e-12));
    });

    test('opponent count clamps to 1..8', () {
      final one = equityVsField(aa, [], 1, iters: 500, seed: 2);
      _expectCounts(one, 419, 3, 78);
      expect(one.equity, closeTo(0.841, 1e-12));
      expect(equityVsField(aa, [], 0, iters: 500, seed: 2), one);
      expect(equityVsField(aa, [], -3, iters: 500, seed: 2), one);
      final eight = equityVsField(aa, [], 8, iters: 300, seed: 4);
      _expectCounts(eight, 91, 1, 208);
      expect(eight.equity, closeTo(0.305, 1e-12));
      expect(equityVsField(aa, [], 12, iters: 300, seed: 4), eight);
    });

    test('2 opponents 300 seed 4 (split-pot share)', () {
      final r = equityVsField(aa, [], 2, iters: 300, seed: 4);
      _expectCounts(r, 217, 1, 82);
      expect(r.equity, closeTo(0.7244444444444444, 1e-12));
    });

    test('river board is still sampled (never exact)', () {
      final r = equityVsField(
        akhh,
        _ci(['Ad', 'Kc', '7s', '2d', '9h']),
        2,
        iters: 300,
        seed: 4,
      );
      _expectCounts(r, 290, 5, 5);
      expect(r.equity, closeTo(0.975, 1e-12));
      expect(r.exact, isFalse);
    });

    test('multiway_test.ts: AA decays with more opponents (pinned)', () {
      final a1 = equityVsField(aa, [], 1, iters: 8000, seed: 201);
      final a2 = equityVsField(aa, [], 2, iters: 8000, seed: 202);
      final a4 = equityVsField(aa, [], 4, iters: 8000, seed: 203);
      _expectCounts(a1, 6800, 50, 1150);
      _expectCounts(a2, 5823, 47, 2130);
      _expectCounts(a4, 4416, 54, 3530);
      expect(a1.equity, closeTo(0.853125, 1e-12));
      expect(a2.equity, closeTo(0.7303541666666664, 1e-12));
      expect(a4.equity, closeTo(0.5546624999999998, 1e-12));
      expect((a1.equity - 0.85).abs() < 0.03, isTrue, reason: 'AA vs 1 ≈ 85%');
      expect(
        a1.equity > a2.equity && a2.equity > a4.equity,
        isTrue,
        reason: 'AA equity decreases as opponents increase',
      );
      expect(a1.equity <= 1 && a4.equity >= 0, isTrue);
    });

    test('multiway_test.ts: top two pair decays multiway (pinned)', () {
      final b = _ci(['Ad', 'Kc', '7s']);
      final t1 = equityVsField(akhh, b, 1, iters: 8000, seed: 204);
      final t3 = equityVsField(akhh, b, 3, iters: 8000, seed: 205);
      _expectCounts(t1, 7554, 39, 407);
      _expectCounts(t3, 6769, 102, 1129);
      expect(t1.equity, closeTo(0.9466875, 1e-12));
      expect(t3.equity, closeTo(0.8524791666666668, 1e-12));
      expect(t1.equity > t3.equity, isTrue);
      expect(t1.equity > 0.8, isTrue);
    });

    test('iters 0 => empty result', () {
      expect(equityVsField(aks, [], 2, iters: 0, seed: 1), EquityResult.empty);
    });
  });

  group('equityRangeVsRange', () {
    test('AKs vs QQ 1000 seed 42', () {
      final r = equityRangeVsRange(
        _combos(['AKs']),
        [],
        qq,
        iters: 1000,
        seed: 42,
      );
      _expectCounts(r, 464, 5, 531);
      expect(r.equity, 0.4665);
      expect(r.se, 0.015775859723007175);
    });

    test('clashing combos are re-drawn up to 8 times then skipped', () {
      final r = equityRangeVsRange(
        _combos(['AA']),
        [],
        _combos(['AA']),
        iters: 500,
        seed: 1,
      );
      _expectCounts(r, 6, 395, 10);
      expect(r.samples, 411); // 89 trials dropped
      expect(r.equity, 0.4951338199513382);
      final s = equityRangeVsRange(
        _combos(['AKs']),
        [],
        _combos(['AKs']),
        iters: 500,
        seed: 1,
      );
      _expectCounts(s, 32, 431, 37);
      expect(s.equity, 0.495);
    });

    test('flop: TT+ vs AK 600 seed 77 (board-blocked combos dropped)', () {
      final r = equityRangeVsRange(
        _combos(['TT', 'JJ', 'QQ', 'KK', 'AA']),
        _ci(['Ks', '7d', '2c']),
        _combos(['AKs', 'AKo']),
        iters: 600,
        seed: 77,
      );
      _expectCounts(r, 216, 0, 379);
      expect(r.equity, 0.3630252100840336);
    });

    test('river: never exact; all-lose se uses the 1e-9 variance floor', () {
      final r = equityRangeVsRange(
        _combos(['TT', 'JJ']),
        _ci(['Ks', '7d', '2c', '2h', '3s']),
        _combos(['AKs', 'AKo']),
        iters: 200,
        seed: 8,
      );
      _expectCounts(r, 0, 0, 200);
      expect(r.equity, 0.0);
      expect(r.se, 0.00000223606797749979);
    });

    test('a range fully blocked by the board => empty result', () {
      expect(
        equityRangeVsRange(
          _combos(['AA']),
          _ci(['Ah', 'Ad', 'Ac', 'As', '2c']),
          _combos(['KK']),
          iters: 200,
          seed: 8,
        ),
        EquityResult.empty,
      );
      expect(
        equityRangeVsRange(
          _combos(['AA']),
          [],
          _combos(['KK']),
          iters: 0,
          seed: 1,
        ),
        EquityResult.empty,
      );
    });

    test('multiway_test.ts: AA vs any-two and AKs vs QQ (pinned)', () {
      final all = _combos(allLabels());
      expect(all.length, kTotalCombos);
      final aaVsField = equityRangeVsRange(
        _combos(['AA']),
        [],
        all,
        iters: 8000,
        seed: 206,
      );
      _expectCounts(aaVsField, 6834, 49, 1117);
      expect(aaVsField.equity, 0.8573125);
      expect((aaVsField.equity - 0.85).abs() < 0.03, isTrue);
      final aksVsQQ = equityRangeVsRange(
        _combos(['AKs']),
        [],
        qq,
        iters: 8000,
        seed: 207,
      );
      _expectCounts(aksVsQQ, 3747, 30, 4223);
      expect(aksVsQQ.equity, 0.47025);
      expect((aksVsQQ.equity - 0.46).abs() < 0.04, isTrue);
    });
  });

  group('card-level conveniences (engineClient.ts)', () {
    test('expandRange drops combos blocked by hero or board', () {
      final combos = expandRange(['AA', 'AKs'], ('Ah', 'Kd'), ['As', '7c']);
      // AA: only AcAd survives; AKs: AcKc and AhKh/AsKs blocked -> AcKc only.
      expect(combos, [comboToInts(('Ac', 'Ad')), comboToInts(('Ac', 'Kc'))]);
    });

    test('equityVsRangeCards == equityVsRange over the expanded range', () {
      final hero = ('As', 'Ks');
      final board = ['Kh', '7d', '2c'];
      final range = ['QQ', 'AKo', 'AKs', '77'];
      final a = equityVsRangeCards(
        hero,
        board,
        range,
        iters: 500,
        seed: hashSeed('AsKs|Kh7d2c'),
      );
      final b = equityVsRange(
        comboToInts(hero),
        _ci(board),
        expandRange(range, hero, board),
        iters: 500,
        seed: hashSeed('AsKs|Kh7d2c'),
      );
      expect(a, b);
      _expectCounts(a, 190, 180, 130);
    });

    test('equityVsRandomCards / equityVsFieldCards delegate', () {
      expect(
        equityVsRandomCards(
          ('Ah', 'Ad'),
          ['Ks', '7d', '2c'],
          iters: 2000,
          seed: 7,
        ),
        equityVsRandom(aa, _ci(['Ks', '7d', '2c']), iters: 2000, seed: 7),
      );
      expect(
        equityVsFieldCards(
          ('Ah', 'Kh'),
          ['Ad', 'Kc', '7s'],
          2,
          iters: 800,
          seed: 3,
        ),
        equityVsField(akhh, _ci(['Ad', 'Kc', '7s']), 2, iters: 800, seed: 3),
      );
    });
  });

  group('golden equity_matrix.json', () {
    // Generated by the desktop's Rust `poker-core/examples/equity_matrix.rs`
    // (StdRng/ChaCha, 40k disjoint-combo boards per unordered pair,
    // SE ≈ 0.25%, complement filled by symmetry, 4-decimal output). That
    // RNG stream is not reproducible from Dart, so the structure is pinned
    // exactly and sampled cells are checked with our own 40k-trial sampler
    // within 0.015 (≈ 4σ of the two estimators combined; seeded, so stable).
    final json =
        jsonDecode(File('test/golden/equity_matrix.json').readAsStringSync())
            as Map<String, dynamic>;
    final labels = (json['labels'] as List).cast<String>();
    final matrix =
        (json['equity'] as List)
            .map(
              (row) => (row as List).map((e) => (e as num).toDouble()).toList(),
            )
            .toList();

    test('labels are the 169 hands in Rust generation order', () {
      const ranks = 'AKQJT98765432';
      final expected = <String>[];
      for (int i = 0; i < 13; i++) {
        for (int j = i; j < 13; j++) {
          if (i == j) {
            expected.add('${ranks[i]}${ranks[j]}');
          } else {
            expected.add('${ranks[i]}${ranks[j]}s');
            expected.add('${ranks[i]}${ranks[j]}o');
          }
        }
      }
      expect(labels, expected);
      expect(labels.toSet(), allLabels().toSet());
    });

    test('169x169, diagonal 0.5, symmetric to 4 decimals', () {
      expect(matrix.length, 169);
      for (int i = 0; i < 169; i++) {
        expect(matrix[i].length, 169);
        expect(matrix[i][i], 0.5);
        for (int j = i + 1; j < 169; j++) {
          expect(
            matrix[i][j] + matrix[j][i],
            closeTo(1.0, 1.5e-4),
            reason: '${labels[i]} vs ${labels[j]}',
          );
          expect(matrix[i][j] >= 0 && matrix[i][j] <= 1, isTrue);
        }
      }
    });

    test('sampled cells agree with equityRangeVsRange within 0.015', () {
      const cases = <(String, String, double)>[
        ('AA', 'KK', 0.8188),
        ('AKs', 'QQ', 0.4597),
        ('72o', 'AA', 0.1203),
        ('JTs', '22', 0.5341),
        ('A5s', 'KQo', 0.6025),
        ('76s', '99', 0.1995),
      ];
      for (final (a, b, golden) in cases) {
        expect(matrix[labels.indexOf(a)][labels.indexOf(b)], golden);
        final r = equityRangeVsRange(
          _combos([a]),
          [],
          _combos([b]),
          iters: 40000,
          seed: hashSeed('$a|$b'),
        );
        expect(r.samples, 40000);
        expect(r.equity, closeTo(golden, 0.015), reason: '$a vs $b');
      }
    });
  });

  group('performance', () {
    test('4000-trial hand-vs-range flop sim finishes under 400 ms', () {
      const wide = [
        'AA', 'KK', 'QQ', 'JJ', 'TT', '99', '88', '77', 'AKs', 'AKo', 'AQs', //
        'AQo', 'AJs', 'AJo', 'ATs', 'KQs', 'KQo', 'KJs', 'KTs', 'QJs', 'QTs',
        'JTs', 'T9s', '98s', '87s', '76s', '65s', 'A5s', 'A4s', 'A3s',
      ];
      final range = _combos(wide);
      final board = _ci(['Kh', '7d', '2c']);
      // Warm up the JIT once, then time.
      equityVsRange(aks, board, range, iters: 200, seed: 303);
      final sw = Stopwatch()..start();
      final r = equityVsRange(aks, board, range, iters: 4000, seed: 303);
      sw.stop();
      _expectCounts(r, 3257, 186, 557);
      expect(r.equity, 0.8375);
      expect(
        sw.elapsedMilliseconds,
        lessThan(400),
        reason: 'took ${sw.elapsedMilliseconds} ms',
      );
    });
  });

  test('Random is accepted anywhere a seed is (Mulberry32 implements it)', () {
    final Random rng = Mulberry32(7);
    final r = equityVsRandom(
      aa,
      _ci(['Ks', '7d', '2c']),
      iters: 2000,
      rng: rng,
    );
    _expectCounts(r, 1783, 1, 216);
  });
}
