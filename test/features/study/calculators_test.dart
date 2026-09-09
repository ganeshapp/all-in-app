/// The §6.5 embedded widgets: the desktop's numbers for pinned inputs
/// (docs/port/study-curriculum.md §12, §16) and the mobile layouts around
/// them.
library;

import 'dart:math' as math;

import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/features/study/widgets/bluff_calculator.dart';
import 'package:allin/features/study/widgets/hand_rankings_list.dart';
import 'package:allin/features/study/widgets/mini_drills.dart';
import 'package:allin/features/study/widgets/multiway_trainer.dart';
import 'package:allin/features/study/widgets/pot_odds_calculator.dart';
import 'package:allin/features/study/widgets/range_explorer.dart';
import 'package:allin/features/study/widgets/study_controls.dart';
import 'package:allin/engine/cards.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('PotOddsCalculator (§12.2)', () {
    test('the pinned arithmetic', () {
      const m = PotOddsMath(pot: 10, bet: 6.5, eq: 50);
      expect(m.toWin, 16.5);
      expect(m.finalPot, 23.0);
      expect(m.breakEven, closeTo(0.2826, 0.0001));
      expect(m.ratio, closeTo(2.538, 0.001));
      expect(m.ev, closeTo(5.0, 0.0001));
      expect(m.call, isTrue);
      expect(m.decision, 'Call');
    });

    test('an EV of exactly zero reads Fold (the 0.02 bb epsilon)', () {
      // 25% equity on a half-pot bet is the break-even point exactly.
      const m = PotOddsMath(pot: 10, bet: 5, eq: 25);
      expect(m.ev, closeTo(0, 1e-9));
      expect(m.decision, 'Fold');
    });

    testWidgets('shows the desktop numbers at its default inputs', (
      tester,
    ) async {
      await pumpStudyWidget(
        tester,
        const SingleChildScrollView(child: PotOddsCalculator()),
      );
      expect(find.text('Pot before the bet'), findsOneWidget);
      expect(find.text("Opponent's bet"), findsOneWidget);
      expect(find.text('10 bb'), findsOneWidget);
      expect(find.text('6.5 bb'), findsWidgets);
      expect(find.text('16.5 bb'), findsOneWidget);
      expect(find.text('2.5 : 1'), findsOneWidget);
      expect(find.text('28%'), findsOneWidget);
      expect(find.text('+5.0 bb'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(
        find.text(
          '= your call (6.5) ÷ final pot (23.0). Call when your equity beats '
          'this.',
        ),
        findsOneWidget,
      );
    });

    for (final size in kStudySizes) {
      testWidgets('fits at ${size.width.toInt()} pt and 1.3x', (tester) async {
        await pumpStudyWidget(
          tester,
          const SingleChildScrollView(child: PotOddsCalculator()),
          size: size,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BluffCalculator (§12.3)', () {
    test('the pinned arithmetic', () {
      const m = BluffMath(pot: 10, bet: 7);
      expect(m.foldNeeded, closeTo(7 / 17, 1e-9));
      expect(m.callerNeeds, closeTo(7 / 24, 1e-9));
      expect(m.betAsPot, closeTo(0.7, 1e-9));
    });

    testWidgets('shows both boxes with their verbatim captions', (
      tester,
    ) async {
      await pumpStudyWidget(
        tester,
        const SingleChildScrollView(child: BluffCalculator()),
      );
      expect(find.text('7 bb (70% pot)'), findsOneWidget);
      expect(find.text('41%'), findsOneWidget);
      expect(find.text('29%'), findsOneWidget);
      expect(
        find.text(
          'they must fold at least this often for the bluff to make money',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'they only need to win this often for their call to make money',
        ),
        findsOneWidget,
      );
    });
  });

  group('HandRankingsList (§12.1)', () {
    testWidgets('ten rows, strongest first', (tester) async {
      await pumpStudyWidget(
        tester,
        const SingleChildScrollView(child: HandRankingsList(available: 358)),
      );
      expect(kHandRankings, hasLength(10));
      expect(kHandRankings.first.name, 'Royal Flush');
      expect(kHandRankings.last.name, 'High Card');
      expect(find.text('Royal Flush'), findsOneWidget);
      expect(find.text('Nothing — highest card plays'), findsOneWidget);
    });
  });

  group('MultiwayTrainer (§12.4)', () {
    testWidgets('runs five sims and lands on a number', (tester) async {
      await pumpStudyWidget(
        tester,
        const SingleChildScrollView(child: MultiwayTrainer(available: 358)),
      );
      expect(find.text('Two pair (top two)'), findsOneWidget);
      expect(find.text('Pocket Aces (pre-flop)'), findsOneWidget);
      expect(find.text(kMultiwayFooter), findsOneWidget);
      // Five 1 200-trial runs through the in-process service.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('EQUITY VS 2'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('RangeExplorer (§12.5)', () {
    testWidgets('opens on the UTG preset and counts its combos', (
      tester,
    ) async {
      await pumpStudyWidget(
        tester,
        const SingleChildScrollView(child: RangeExplorer(available: 358)),
      );
      // The preset row scrolls horizontally, so only the first chips are
      // built; the full list is asserted below.
      expect(find.text('UTG ~14%'), findsOneWidget);
      expect(find.text('MP ~19%'), findsOneWidget);
      expect(find.text(kRangeExplorerNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('the presets are the desktop five', () {
      expect(kExplorerPresets.map((p) => p.pct).toList(), <int>[
        14,
        19,
        27,
        45,
        55,
      ]);
    });
  });

  group('scroll gutters (§6.5)', () {
    test('an embedded matrix always reserves a real gutter', () {
      for (final width in <double>[328, 358, 398]) {
        final gutter = ScrollSafeRangeMatrix.gutterFor(width);
        expect(gutter, greaterThanOrEqualTo(16));
        expect(ScrollSafeRangeMatrix.boxFor(width), width - 2 * gutter);
      }
      expect(ScrollSafeRangeMatrix.gutterFor(358), 24);
    });
  });

  group('study mini-drills (§16)', () {
    test('pot-odds spots are internally consistent', () {
      final rng = math.Random(11);
      for (var i = 0; i < 200; i++) {
        final spot = makePotSpot(rng);
        expect(spot.pot, inInclusiveRange(4, 40));
        expect(
          spot.correct,
          (spot.bet / (spot.pot + 2 * spot.bet) * 100).round(),
        );
        expect(spot.options, contains(spot.correct));
        expect(spot.options, hasLength(4));
        expect(spot.options.toSet(), hasLength(4));
      }
    });

    test('outs spots follow the 2/4 rule', () {
      final rng = math.Random(3);
      for (var i = 0; i < 200; i++) {
        final spot = makeOutsSpot(rng);
        expect(spot.mult, anyOf(2, 4));
        expect(spot.correct, math.min(95, spot.draw.outs * spot.mult));
        expect(spot.options, contains(spot.correct));
        expect(spot.options, hasLength(4));
      }
    });

    test('the seven draws are the desktop list', () {
      expect(kOutsDraws.map((d) => d.outs).toList(), <int>[
        9,
        8,
        4,
        6,
        12,
        2,
        15,
      ]);
    });

    test('scoreRange is combo-weighted F1', () {
      final target = kRangeTargets.first.labels;
      expect(target, isNotEmpty);
      expect(scoreRange(target, target), closeTo(1.0, 1e-9));
      expect(scoreRange(<HandLabel>{}, target), 0.0);
      final half = target.take(target.length ~/ 2).toSet();
      expect(scoreRange(half, target), lessThan(1.0));
      expect(scoreRange(half, target), greaterThan(0.0));
      expect(kRangePassThreshold, 0.7);
    });

    testWidgets('the pot-odds drill scores an answer', (tester) async {
      final rng = math.Random(5);
      final spot = makePotSpot(math.Random(5));
      await pumpStudyWidget(
        tester,
        SingleChildScrollView(child: PotOddsDrill(random: rng)),
      );
      expect(find.text('Pot-odds drill'), findsOneWidget);
      expect(find.text('Score 0/0'), findsOneWidget);
      await tester.tap(find.text('${spot.correct}%'));
      await tester.pump();
      expect(find.text('Score 1/1'), findsOneWidget);
      expect(find.textContaining('Correct.'), findsOneWidget);
      expect(find.textContaining(spot.explanation), findsOneWidget);
    });

    testWidgets('the range drill grades against the standard', (tester) async {
      await pumpStudyWidget(
        tester,
        SingleChildScrollView(
          child: RangeBuildDrill(available: 358, random: math.Random(2)),
        ),
      );
      expect(find.text('Range-building drill'), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);
      expect(find.text('Nothing painted yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('range/board breakdown (§12.7)', () {
    test('drawFlags spots a four-flush that uses a hole card', () {
      final flags = drawFlags((
        'Ah',
        'Kh',
      ), <Card>['Qh', '7h', '2s'].map(cardToInt).toList());
      expect(flags.flushDraw, isTrue);
    });

    test('breakdownRange counts every unblocked combo', () {
      final range = <HandLabel>{'AA', 'AKs'};
      final b = breakdownRange(range, const <Card>['Ah', 'Kd', '7c']);
      // AA loses the ace of hearts (3 combos left), AKs loses A♥K♥ and A♦K♦.
      expect(b.total, comboCount('AA') - 3 + comboCount('AKs') - 2);
    });
  });
}
