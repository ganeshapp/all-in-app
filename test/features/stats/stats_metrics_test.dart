/// Every Progress number, computed from one fixture snapshot and compared
/// against values worked out by hand from
/// `docs/port/persistence-stats-settings.md` §7.1–§7.8.
///
/// The fixture is deliberately asymmetric: the lifetime counters are larger
/// than the stored window (so `chartBase` has to carry the difference), one
/// hand is multiway (so the archetype split has to divide it), and one record
/// has no `sawFlop` (so WTSD has to exclude it).
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/providers/stats_metrics.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

HandRecord _hand({
  required int n,
  required double netBb,
  required bool showdown,
  required bool won,
  required List<Archetype> archetypes,
  required Position position,
  bool? sawFlop,
}) => HandRecord(
  n: n,
  netBb: netBb,
  potBb: 6,
  showdown: showdown,
  won: won,
  archetypes: archetypes,
  position: position,
  sawFlop: sawFlop,
  ts: 1700000000000 + n,
);

DecisionRecord _decision(String verdict, String action, [int i = 0]) =>
    DecisionRecord(
      verdict: verdict,
      action: action,
      equity: 0.17,
      potOdds: 0.25,
      evBb: -2,
      street: 'river',
      villainArchetype: 'Nit',
      position: 'BB',
      ts: 1700000000000 + i,
    );

/// handsPlayed 8 / netChips 200 (bb 20 → net 10 bb) with a 5-hand window
/// summing to 5 bb, so `chartBase` is 5.
final StatsSnapshot fixture = StatsSnapshot(
  handsPlayed: 8,
  netChips: 200,
  bigBlind: 20,
  history: [
    _hand(
      n: 1,
      netBb: 2,
      showdown: true,
      won: true,
      archetypes: [Archetype.tag],
      position: Position.btn,
      sawFlop: true,
    ),
    _hand(
      n: 2,
      netBb: -1,
      showdown: false,
      won: false,
      archetypes: [Archetype.lag],
      position: Position.bb,
      sawFlop: true,
    ),
    _hand(
      n: 3,
      netBb: 3,
      showdown: true,
      won: true,
      archetypes: [Archetype.tag, Archetype.nit],
      position: Position.btn,
      sawFlop: true,
    ),
    _hand(
      n: 4,
      netBb: -0.5,
      showdown: false,
      won: false,
      archetypes: [Archetype.station],
      position: Position.sb,
      sawFlop: true,
    ),
    _hand(
      n: 5,
      netBb: 1.5,
      showdown: true,
      won: false,
      archetypes: [Archetype.tag],
      position: Position.co,
      // pre-v3 record: excluded from WTSD, silently (§14).
      sawFlop: null,
    ),
  ],
  guesses: [
    for (final (i, a) in <double>[0.2, 0.3, 0.4, 0.5, 0.6, 0.4].indexed)
      GuessRecord(
        accuracy: a,
        archetype: Archetype.nit,
        street: 'flop',
        ts: 1700000000000 + i,
      ),
  ],
  decisions: [
    _decision('mistake', 'fold', 1),
    _decision('mistake', 'fold', 2),
    _decision('mistake', 'fold', 3),
    _decision('mistake', 'fold', 4),
    _decision('thin', 'call', 5),
    _decision('thin', 'call', 6),
    _decision('great', 'raise', 7),
    _decision('great', 'raise', 8),
    _decision('info', 'bet', 9),
  ],
);

void main() {
  final m = computeStatsMetrics(fixture);

  group('KPIs (§7.1, §7.2)', () {
    test('net and win rate come from the lifetime counters', () {
      expect(m.netBb, 10);
      expect(m.bb100, 125); // 10 bb / 8 hands × 100
      expect(m.handsPlayed, 8);
    });

    test('showdown counts only hands that reached one', () {
      expect(m.showdownHands, 3);
      expect(m.showdownWon, 2);
      expect(m.sdWin, closeTo(2 / 3, 1e-12));
    });

    test('read accuracy is the mean of every guess', () {
      expect(m.avgAcc, closeTo(0.4, 1e-12));
      expect(m.readScores.length, 6);
    });

    test('won / lost split feeds the Net explainer', () {
      expect(m.wonBb, closeTo(6.5, 1e-12));
      expect(m.lostBb, closeTo(1.5, 1e-12));
    });
  });

  group('cumulative chart (§7.3)', () {
    test('chartBase closes the gap between window and lifetime', () {
      expect(m.chartBase, closeTo(5, 1e-12));
    });

    test('one point per stored hand, ending on the lifetime net', () {
      expect(m.cumulative, hasLength(5));
      expect(m.cumulative, [7.0, 6.0, 9.0, 8.5, 10.0]);
      expect(m.cumulative.last, closeTo(m.netBb, 1e-12));
    });

    test('trend windows stay absent until they are full', () {
      expect(m.bb100Over(100), isNull);
      expect(m.trendWindows, isEmpty);
      expect(m.bb100Over(5), closeTo(100, 1e-12)); // 5 bb over 5 hands
    });
  });

  group('hands vs each style (§7.5)', () {
    test('a multiway hand splits its result between the styles', () {
      final byStyle = {for (final a in m.archetypes) a.archetype: a};
      expect(byStyle[Archetype.tag]!.hands, 3);
      expect(byStyle[Archetype.tag]!.net, closeTo(5, 1e-12)); // 2 + 1.5 + 1.5
      expect(byStyle[Archetype.nit]!.net, closeTo(1.5, 1e-12));
      expect(byStyle[Archetype.lag]!.net, closeTo(-1, 1e-12));
      expect(byStyle[Archetype.station]!.net, closeTo(-0.5, 1e-12));
    });

    test('the four nets sum to the true total', () {
      final total = m.archetypes.fold<double>(0, (a, s) => a + s.net);
      expect(total, closeTo(5, 1e-12));
    });

    test('the bar denominator is the largest sample', () {
      expect(m.maxArchetypeHands, 3);
    });
  });

  group('winnings by position (§7.7)', () {
    test('rate is bb/100 from that seat', () {
      final byPos = {for (final p in m.positions) p.position: p};
      expect(byPos[Position.btn]!.hands, 2);
      expect(byPos[Position.btn]!.rate, closeTo(250, 1e-12));
      expect(byPos[Position.bb]!.rate, closeTo(-100, 1e-12));
      expect(byPos[Position.sb]!.rate, closeTo(-50, 1e-12));
      expect(byPos[Position.co]!.rate, closeTo(150, 1e-12));
      expect(byPos[Position.utg]!.hands, 0);
      expect(byPos[Position.utg]!.rate, 0);
    });

    test('tracked total and bar scale', () {
      expect(m.trackedPositions, 5);
      expect(m.maxPositionRate, closeTo(250, 1e-12));
    });

    test('rows keep the desktop order', () {
      expect(m.positions.map((p) => p.position).toList(), kPositionOrder);
    });
  });

  group('style numbers (§7.8)', () {
    test('WTSD excludes the record without sawFlop', () {
      expect(m.flopsSeen, 4);
      expect(m.showdownsFromFlops, 2);
      expect(m.wtsd, closeTo(0.5, 1e-12));
    });

    test(r'W$SD is the showdown win rate', () {
      expect(m.wsd, closeTo(2 / 3, 1e-12));
    });

    test('AF is bets + raises over calls, across coached decisions', () {
      expect(m.aggressiveActions, 3); // two raises and the info bet
      expect(m.callActions, 2);
      expect(m.af, closeTo(1.5, 1e-12));
    });
  });

  group('coaching review (§7.6, §8)', () {
    test('info decisions are excluded from the totals', () {
      expect(m.leak.total, 8);
      expect(m.leak.mistakes, 4);
      expect(m.leak.thin, 2);
      expect(m.leak.great, 2);
      expect(m.leak.foldMistakes, 4);
      expect(m.leak.callMistakes, 0);
    });

    test('the fold leak fires and the read leak is appended', () {
      expect(m.allLeaks, [kLeakFoldTooOften, StatsCopy.readAccuracyLeak]);
    });

    test('recent mistakes are the last five, newest first', () {
      expect(m.recentMistakes, hasLength(4));
      expect(m.recentMistakes.first.ts, 1700000000004);
      expect(m.recentMistakes.last.ts, 1700000000001);
    });
  });

  group('empty snapshot (§14 "Stats · no hands")', () {
    final empty = computeStatsMetrics(StatsSnapshot.empty);

    test('every number is a zero or a dash, and nothing throws', () {
      expect(empty.isEmpty, isTrue);
      expect(empty.netBb, 0);
      expect(empty.bb100, 0);
      expect(empty.sdWin, 0);
      expect(empty.avgAcc, 0);
      expect(empty.cumulative, isEmpty);
      expect(empty.wtsd, isNull);
      expect(empty.wsd, isNull);
      expect(empty.af, isNull);
      expect(empty.allLeaks, isEmpty);
      expect(empty.trackedPositions, 0);
      expect(empty.maxArchetypeHands, 1);
      expect(empty.maxPositionRate, 1);
    });
  });
}
