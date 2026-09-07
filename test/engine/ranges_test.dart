import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/archetypes.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

// chenScore(label) for all 169 labels, computed from the desktop TypeScript
// (Node 23, `chenScore` in src/engine/ranges.ts).
const Map<String, double> _chenRef = {
  '22': 5, '33': 5, '44': 5, '55': 5, '66': 6, '77': 7, '88': 8, '99': 9,
  'AA': 20, 'AKs': 12, 'AQs': 11, 'AJs': 10, 'ATs': 8, 'A9s': 7, 'A8s': 7,
  'A7s': 7, 'A6s': 7, 'A5s': 7, 'A4s': 7, 'A3s': 7, 'A2s': 7, 'AKo': 10,
  'KK': 16, 'KQs': 10, 'KJs': 9, 'KTs': 8, 'K9s': 6, 'K8s': 5, 'K7s': 5,
  'K6s': 5, 'K5s': 5, 'K4s': 5, 'K3s': 5, 'K2s': 5, 'AQo': 9, 'KQo': 8,
  'QQ': 14, 'QJs': 9, 'QTs': 8, 'Q9s': 7, 'Q8s': 5, 'Q7s': 4, 'Q6s': 4,
  'Q5s': 4, 'Q4s': 4, 'Q3s': 4, 'Q2s': 4, 'AJo': 8, 'KJo': 7, 'QJo': 7,
  'JJ': 12, 'JTs': 9, 'J9s': 8, 'J8s': 6, 'J7s': 4, 'J6s': 3, 'J5s': 3,
  'J4s': 3, 'J3s': 3, 'J2s': 3, 'ATo': 6, 'KTo': 6, 'QTo': 6, 'JTo': 7,
  'TT': 10, 'T9s': 8, 'T8s': 7, 'T7s': 5, 'T6s': 3, 'T5s': 2, 'T4s': 2,
  'T3s': 2, 'T2s': 2, 'A9o': 5, 'K9o': 4, 'Q9o': 5, 'J9o': 6, 'T9o': 6,
  '98s': 7.5, '97s': 6.5, '96s': 4.5, '95s': 2.5, '94s': 1.5, '93s': 1.5,
  '92s': 1.5, 'A8o': 5, 'K8o': 3, 'Q8o': 3, 'J8o': 4, 'T8o': 5, '98o': 5.5,
  '87s': 7, '86s': 6, '85s': 4, '84s': 2, '83s': 1, '82s': 1, 'A7o': 5,
  'K7o': 3, 'Q7o': 2, 'J7o': 2, 'T7o': 3, '97o': 4.5, '87o': 5, '76s': 6.5,
  '75s': 5.5, '74s': 3.5, '73s': 1.5, '72s': 0.5, 'A6o': 5, 'K6o': 3,
  'Q6o': 2, 'J6o': 1, 'T6o': 1, '96o': 2.5, '86o': 4, '76o': 4.5, '65s': 6,
  '64s': 5, '63s': 3, '62s': 1, 'A5o': 5, 'K5o': 3, 'Q5o': 2, 'J5o': 1,
  'T5o': 0, '95o': 0.5, '85o': 2, '75o': 3.5, '65o': 4, '54s': 5.5,
  '53s': 4.5, '52s': 2.5, 'A4o': 5, 'K4o': 3, 'Q4o': 2, 'J4o': 1, 'T4o': 0,
  '94o': -0.5, '84o': 0, '74o': 1.5, '64o': 3, '54o': 3.5, '43s': 5,
  '42s': 4, 'A3o': 5, 'K3o': 3, 'Q3o': 2, 'J3o': 1, 'T3o': 0, '93o': -0.5,
  '83o': -1, '73o': -0.5, '63o': 1, '53o': 2.5, '43o': 3, '32s': 4.5,
  'A2o': 5, 'K2o': 3, 'Q2o': 2, 'J2o': 1, 'T2o': 0, '92o': -0.5, '82o': -1,
  '72o': -1.5, '62o': -1, '52o': 0.5, '42o': 2, '32o': 2.5, //
};

// JS `[...set].sort()` — default UTF-16 code-unit order, which is what Dart's
// String.compareTo does too.
List<String> _sorted(Iterable<String> it) => it.toList()..sort();

Map<String, dynamic> _loadCharts() {
  final f = File('test/golden/charts.json');
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('chenScore', () {
    test('matches the desktop for all 169 labels', () {
      expect(_chenRef.length, 169);
      for (final l in allLabels()) {
        expect(chenScore(l), _chenRef[l], reason: l);
      }
    });

    test('spot pins from docs/port/math-engine.md', () {
      expect(chenScore('AA'), 20);
      expect(chenScore('22'), 5);
      expect(chenScore('AKs'), 12);
      expect(chenScore('AKo'), 10);
      expect(chenScore('98s'), 7.5);
      expect(chenScore('72o'), -1.5);
      expect(chenScore('T2o'), 0);
    });
  });

  group('rankedHands', () {
    test('order matches charts.json ranked EXACTLY', () {
      final golden = (_loadCharts()['ranked'] as List).cast<String>();
      final ranked = rankedHands();
      expect(ranked.length, 169);
      expect(ranked.map((h) => h.label).toList(), golden);
      for (final h in ranked) {
        expect(h.score, _chenRef[h.label]);
        expect(h.combos, comboCount(h.label));
      }
    });

    test('is cached and unmodifiable', () {
      expect(identical(rankedHands(), rankedHands()), isTrue);
      expect(() => rankedHands().add(rankedHands().first), throwsA(anything));
    });
  });

  group('strengthRankMap', () {
    test('1-based ranks', () {
      final m = strengthRankMap();
      expect(m.length, 169);
      expect(m['AA'], 1);
      expect(m['AKo'], 10);
      expect(m['72o'], 169);
    });
  });

  group('topPercentRange', () {
    test('every integer pct 1..100 matches charts.json topPct EXACTLY', () {
      final golden = _loadCharts()['topPct'] as Map<String, dynamic>;
      expect(golden.length, 100);
      for (int p = 1; p <= 100; p++) {
        final want = (golden['$p'] as List).cast<String>();
        expect(_sorted(topPercentRange(p)), want, reason: 'pct=$p');
      }
    });

    test('insertion order is strength order and clamps', () {
      expect(topPercentRange(10).toList(), [
        'AA', 'KK', 'QQ', 'JJ', 'AKs', 'AQs', 'TT', 'AJs', 'KQs', 'AKo', '99',
        'KJs', 'QJs', 'JTs', 'AQo', '88', 'ATs', 'KTs', 'QTs', 'J9s', 'T9s',
        'AJo', 'KQo', //
      ]);
      expect(topPercentRange(1), {'AA', 'KK', 'QQ'});
      expect(topPercentRange(2), {'AA', 'KK', 'QQ', 'JJ', 'AKs'});
      expect(topPercentRange(0.5).length, 2);
      expect(topPercentRange(0), isEmpty);
      expect(topPercentRange(-5), isEmpty);
      expect(topPercentRange(100).length, 169);
      expect(topPercentRange(150).length, 169);
    });

    test('label / combo counts pinned in the port doc', () {
      const pcts = [
        2, 3, 4, 6, 8, 10, 12, 15, 18, 20, 22, 25, 27, 30, 35, 40, 45, 50, //
        55, 60, 70, 80, 90,
      ];
      const counts = [
        5, 8, 10, 15, 20, 23, 28, 37, 42, 47, 49, 54, 58, 67, 74, 80, 91, //
        100, 110, 115, 131, 147, 158,
      ];
      for (int i = 0; i < pcts.length; i++) {
        expect(
          topPercentRange(pcts[i]).length,
          counts[i],
          reason: '${pcts[i]}',
        );
      }
      expect(combosInSet(topPercentRange(5)), 68);
      expect(combosInSet(topPercentRange(14)), 188);
      expect(combosInSet(topPercentRange(55)), 738);
      expect(combosInSet(topPercentRange(90)), 1194);
    });
  });

  test('positionMultiplier', () {
    expect(positionMultiplier(Position.utg), 0.5);
    expect(positionMultiplier(Position.mp), 0.68);
    expect(positionMultiplier(Position.co), 0.9);
    expect(positionMultiplier(Position.btn), 1.25);
    expect(positionMultiplier(Position.sb), 0.85);
    expect(positionMultiplier(Position.bb), 1.0);
  });

  group('buildPreflopRanges', () {
    test(
      'all 24 archetype:position play/raise sets match charts.json EXACTLY',
      () {
        final golden = _loadCharts()['bots'] as Map<String, dynamic>;
        expect(golden.length, 24);
        int checked = 0;
        for (final a in Archetype.values) {
          final cfg = kArchetypes[a]!;
          for (final pos in Position.values) {
            final key = '${a.label}:${pos.label}';
            final want = golden[key] as Map<String, dynamic>;
            final r = buildPreflopRanges(cfg.vpip, cfg.pfr, pos);
            expect(
              _sorted(r.play),
              (want['play'] as List).cast<String>(),
              reason: '$key play',
            );
            expect(
              _sorted(r.raise),
              (want['raise'] as List).cast<String>(),
              reason: '$key raise',
            );
            expect(r.play.containsAll(r.raise), isTrue, reason: key);
            checked++;
          }
        }
        expect(checked, 24);
      },
    );

    test('pinned sizes (float products are not rounded)', () {
      final tagSb = buildPreflopRanges(22, 18, Position.sb);
      expect(tagSb.play.length, 44);
      expect(tagSb.raise.length, 37);
      final nitUtg = buildPreflopRanges(12, 9, Position.utg);
      expect(
        _sorted(nitUtg.play).join(','),
        '99,AA,AJs,AKo,AKs,AQo,AQs,JJ,JTs,KJs,KK,KQs,QJs,QQ,TT',
      );
      expect(
        _sorted(nitUtg.raise).join(','),
        '99,AA,AJs,AKo,AKs,AQs,JJ,KK,KQs,QQ,TT',
      );
      // Floors: playPct >= 4, raisePct >= 2.
      final tiny = buildPreflopRanges(0, 0, Position.utg);
      expect(tiny.play, topPercentRange(4));
      expect(tiny.raise, topPercentRange(2));
      // Ceilings: playPct <= 90, raisePct <= playPct.
      final huge = buildPreflopRanges(100, 100, Position.btn);
      expect(huge.play, topPercentRange(90));
      expect(huge.raise, topPercentRange(90));
    });
  });

  group('chart helpers', () {
    const chart = {'AA': 1, 'AKs': 0.5, '72o': 0.25, 'KK': 0.49};

    test('chartToSet keeps labels with frequency >= min (default 0.5)', () {
      expect(chartToSet(chart).toList(), ['AA', 'AKs']);
      expect(chartToSet(chart, 0.2).toList(), ['AA', 'AKs', '72o', 'KK']);
      expect(chartToSet(const {}), isEmpty);
    });

    test('chartWidth is combo-weighted over 1326', () {
      expect(
        chartWidth(const {'AA': 1, 'AKs': 0.5, '72o': 0.25}),
        0.008295625942684766,
      );
      expect(chartWidth(const {}), 0);
      final all = {for (final l in allLabels()) l: 1};
      expect(chartWidth(all), 1.0);
    });
  });

  test('kStudyRanges copy is verbatim', () {
    expect(kStudyRanges.length, 4);
    expect(kStudyRanges[0].title, 'UTG Open (~14%)');
    expect(kStudyRanges[0].pct, 14);
    expect(
      kStudyRanges[0].note,
      'Tightest opening range — premium pairs, big broadways, AK–AQ.',
    );
    expect(kStudyRanges[1].title, 'CO Open (~27%)');
    expect(kStudyRanges[1].pct, 27);
    expect(
      kStudyRanges[1].note,
      'Widen with suited connectors and more broadways.',
    );
    expect(kStudyRanges[2].title, 'BTN Open (~45%)');
    expect(kStudyRanges[2].pct, 45);
    expect(
      kStudyRanges[2].note,
      'Steal wide — any pair, most suited hands, many offsuit broadways.',
    );
    expect(kStudyRanges[3].title, 'BB Defend (~55%)');
    expect(kStudyRanges[3].pct, 55);
    expect(
      kStudyRanges[3].note,
      'Closing the action with a price; defend wide vs a single raise.',
    );
    for (final s in kStudyRanges) {
      expect(topPercentRange(s.pct), isNotEmpty);
    }
  });
}
