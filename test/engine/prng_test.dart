import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/prng.dart';
import 'package:flutter_test/flutter_test.dart';

// Reference outputs computed with Node 23 from the desktop TypeScript
// (`mulberry32` / `hashSeed` in src/engine/equity.ts).
const Map<int, List<double>> _prngRef = {
  0: [
    0.26642920868471265,
    0.0003297457005828619,
    0.2232720274478197,
    0.1462021479383111,
    0.46732782293111086,
    0.5450490827206522,
    0.6152513844426721,
    0.6489853798411787,
  ],
  1: [
    0.6270739405881613,
    0.002735721180215478,
    0.5274470399599522,
    0.9810509674716741,
    0.9683778982143849,
    0.281103502959013,
    0.6128388606011868,
    0.7207431411370635,
  ],
  42: [
    0.6011037519201636,
    0.44829055899754167,
    0.8524657934904099,
    0.6697340414393693,
    0.17481389874592423,
    0.5265925421845168,
    0.2732279943302274,
    0.6247446539346129,
  ],
  0xa11a: [
    0.4725986956618726,
    0.04830061923712492,
    0.6855211523361504,
    0.1371903265826404,
    0.4850823583547026,
    0.8559760458301753,
    0.1144803399220109,
    0.47249475098215044,
  ],
  123456789: [
    0.2577907438389957,
    0.9707721115555614,
    0.7853280142880976,
    0.20616457983851433,
    0.30307188746519387,
    0.7470660470426083,
    0.7787336520850658,
    0.2845096290111542,
  ],
  2906473402: [
    0.3818417105358094,
    0.10900921770371497,
    0.24382608523592353,
    0.5372653310187161,
    0.7357023046351969,
    0.8720021683257073,
    0.8629971598275006,
    0.24675471032969654,
  ],
  0xffffffff: [
    0.8964226141106337,
    0.189478256739676,
    0.7156526781618595,
    0.9440599093213677,
    0.8452364315744489,
    0.5391399988438934,
    0.6804977387655526,
    0.4755720964167267,
  ],
};

const Map<String, int> _hashRef = {
  '': 2166136261,
  'a': 3826002220,
  'abc': 440920331,
  'hello': 1335831723,
  'AsKs|Kh7d2c': 2906473402,
  '1|flop|call|AhKh|Ks7d2c': 1366682787,
  'QQ|': 1506056881,
  'imp|0|flop|10': 1531391887,
  '♠♥': 3058318638,
  'AA|Kh7d2c': 1812170046,
  '12|river|raise|AsAd|Kh7d2c9s3h': 893492319,
};

void main() {
  group('Mulberry32', () {
    test(
      'reproduces the TypeScript sequence bit-for-bit (56 pinned values)',
      () {
        _prngRef.forEach((seed, expected) {
          final g = Mulberry32(seed);
          for (int i = 0; i < expected.length; i++) {
            expect(g.next(), expected[i], reason: 'seed=$seed call #$i');
          }
        });
      },
    );

    test('mulberry32() closure and nextDouble() are the same generator', () {
      final f = mulberry32(42);
      final g = Mulberry32(42);
      for (int i = 0; i < 20; i++) {
        final v = f();
        expect(v, g.nextDouble());
        if (i < 8) expect(v, _prngRef[42]![i]);
      }
    });

    test('seed is masked to 32 bits like JS >>> 0', () {
      final a = Mulberry32(0x1_0000_002A); // 2^32 + 42
      final b = Mulberry32(42);
      expect(a.state, 42);
      for (int i = 0; i < 5; i++) {
        expect(a.next(), b.next());
      }
      final c = Mulberry32(-1);
      final d = Mulberry32(0xffffffff);
      for (int i = 0; i < 5; i++) {
        expect(c.next(), d.next());
      }
    });

    test('nextInt is floor(next() * max) — the JS (rand()*n)|0 idiom', () {
      final a = Mulberry32(7);
      final b = Mulberry32(7);
      for (int i = 0; i < 200; i++) {
        final max = 1 + (i % 52);
        final expected = (b.next() * max).toInt();
        final got = a.nextInt(max);
        expect(got, expected);
        expect(got, inInclusiveRange(0, max - 1));
      }
      expect(() => a.nextInt(0), throwsRangeError);
    });

    test('outputs stay within [0, 1) over many draws', () {
      final g = Mulberry32(0xdeadbeef);
      for (int i = 0; i < 100000; i++) {
        final v = g.next();
        expect(v >= 0 && v < 1, isTrue);
      }
    });

    test('reproduces the golden evaluator corpus deals (30k+ draws)', () {
      // scripts/golden_gen.ts: rand = mulberry32(0xa11a); 600 Fisher–Yates
      // shuffles of [0..51] with j = (rand() * (k + 1)) | 0, then the first
      // 5 + (i % 3) cards. Every card list must match exactly.
      final json =
          jsonDecode(File('test/golden/evaluator.json').readAsStringSync())
              as Map<String, dynamic>;
      final corpus = (json['corpus'] as List).cast<Map<String, dynamic>>();
      expect(corpus.length, 600);
      final rand = Mulberry32(0xa11a);
      for (int i = 0; i < 600; i++) {
        final deck = List<int>.generate(52, (k) => k);
        for (int k = deck.length - 1; k > 0; k--) {
          final j = (rand.next() * (k + 1)).toInt();
          final t = deck[k];
          deck[k] = deck[j];
          deck[j] = t;
        }
        final cards = deck.sublist(0, 5 + (i % 3));
        expect(
          cards,
          (corpus[i]['cards'] as List).cast<int>(),
          reason: 'corpus entry $i',
        );
      }
    });
  });

  group('hashSeed', () {
    test('matches the TypeScript FNV-1a values', () {
      _hashRef.forEach((s, expected) {
        expect(hashSeed(s), expected, reason: 'hashSeed("$s")');
      });
    });

    test('is always an unsigned 32-bit value', () {
      for (final s in ['x', 'yy', 'zzz', '😀', '1|flop|call|AhKh|Ks7d2c']) {
        final h = hashSeed(s);
        expect(h, inInclusiveRange(0, 0xffffffff));
      }
    });

    test('hashSeed seeds Mulberry32 the same way as the desktop', () {
      // hashSeed("AsKs|Kh7d2c") == 2906473402; the pinned sequence for that
      // seed is the same one the desktop coach would sample from.
      final g = Mulberry32(hashSeed('AsKs|Kh7d2c'));
      for (int i = 0; i < 8; i++) {
        expect(g.next(), _prngRef[2906473402]![i]);
      }
    });
  });
}
