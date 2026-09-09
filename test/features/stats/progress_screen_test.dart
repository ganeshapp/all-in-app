/// T0 · Progress (DESIGN.md §7.1–§7.4, §7.11, §14).
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/screens/progress_screen.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'stats_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

DecisionRecord _decision(String verdict, String action, int i) =>
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

Future<StatsFixture> _seeded() async {
  final fixture = StatsFixture();
  await fixture.addHand(sixMaxHand(), netBb: 13, position: Position.btn);
  await fixture.addGuess(
    const GuessRecord(
      accuracy: 0.64,
      archetype: Archetype.nit,
      street: 'flop',
      ts: 1700000000000,
    ),
  );
  for (var i = 0; i < 4; i++) {
    await fixture.addDecision(_decision('mistake', 'fold', i));
  }
  for (var i = 4; i < 6; i++) {
    await fixture.addDecision(_decision('thin', 'call', i));
  }
  for (var i = 6; i < 8; i++) {
    await fixture.addDecision(_decision('great', 'raise', i));
  }
  return fixture;
}

void main() {
  testWidgets('first run shows every card\'s verbatim empty line', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    expect(find.text(StatsCopy.title), findsOneWidget);
    expect(find.text(StatsCopy.subtitle), findsOneWidget);
    expect(find.text(StatsCopy.chartEmpty), findsOneWidget);
    expect(find.text(StatsCopy.coachingReviewEmpty), findsOneWidget);
    expect(find.text(StatsCopy.handsEmpty), findsOneWidget);

    // KPI zeros and the "—" read accuracy (§7.2).
    expect(find.text('0'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(find.text(StatsCopy.kpiReadsSub(0)), findsOneWidget);

    // Cards further down the page.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(StatsCopy.positionsEmpty),
      300,
      scrollable: list,
    );
    expect(find.text(StatsCopy.positionsEmpty), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(StatsCopy.readsEmpty),
      300,
      scrollable: list,
    );
    expect(find.text(StatsCopy.readsEmpty), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(StatsCopy.practiceEmpty),
      300,
      scrollable: list,
    );
    expect(find.text(StatsCopy.practiceEmpty), findsOneWidget);
  });

  testWidgets('a played hand fills the KPIs, the review and the row', (
    tester,
  ) async {
    final fixture = await _seeded();
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    expect(find.text('1'), findsWidgets); // hands played
    expect(find.text('+13.0 bb'), findsOneWidget); // net
    expect(find.text(StatsCopy.kpiReadsSub(1)), findsOneWidget);

    // Coaching review: 4 mistakes, 2 thin, 2 great, and the fold leak.
    expect(find.text(StatsCopy.verdictMistakes.toUpperCase()), findsOneWidget);
    expect(find.text(kLeakFoldTooOften), findsOneWidget);
    expect(find.text(StatsCopy.recentNegativeEv), findsOneWidget);
    expect(
      find.text(
        StatsCopy.decisionNumbers(equity: 0.17, potOdds: 0.25, evBb: -2),
      ),
      findsWidgets,
    );

    // The recent hand row, further down the page.
    await tester.scrollUntilVisible(
      find.textContaining('Hand #7'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Hand #7'), findsOneWidget);
  });

  testWidgets('the win-rate ⓘ opens T1 with the verbatim body', (tester) async {
    final fixture = await _seeded();
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    await tester.tap(find.bySemanticsLabel('About win rate'));
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.winRateTitle), findsOneWidget);
    expect(find.text(StatsCopy.winRateBody), findsOneWidget);
    // §7.2: both disclosure rows render, always.
    expect(find.text(CoachCopy.showMath), findsOneWidget);
    expect(find.text(CoachCopy.expertDetail), findsOneWidget);
  });

  testWidgets('X2 needs the word typed before it will erase anything', (
    tester,
  ) async {
    final fixture = await _seeded();
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    final reset = find.text(StatsCopy.resetRow);
    await tester.scrollUntilVisible(
      reset,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.resetTitle), findsOneWidget);
    expect(find.text(StatsCopy.resetBody), findsOneWidget);
    expect(find.text(StatsCopy.resetBackupFirst), findsOneWidget);

    final erase = find.widgetWithText(TextButton, StatsCopy.resetConfirm);
    expect(tester.widget<TextButton>(erase).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'reset');
    await tester.pump();
    expect(tester.widget<TextButton>(erase).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'RESET');
    await tester.pump();
    expect(tester.widget<TextButton>(erase).onPressed, isNotNull);

    await tester.tap(find.text(StatsCopy.resetCancel));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.resetTitle), findsNothing);
  });

  testWidgets('a dotted style label opens T1 with its healthy band', (
    tester,
  ) async {
    final fixture = await _seeded();
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    final label = find.text(StatsCopy.wtsdLabel);
    await tester.scrollUntilVisible(
      label,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    await tester.tap(label);
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.wtsdBlurb), findsOneWidget);
    await tester.tap(find.text(CoachCopy.showMath));
    await tester.pumpAndSettle();
    expect(
      find.text(StatsCopy.healthyRange(StatsCopy.wtsdBand)),
      findsOneWidget,
    );
  });

  group('renders at every supported width, theme and text scale (§13)', () {
    for (final size in const [Size(360, 780), Size(390, 844), Size(430, 932)]) {
      for (final dark in const [true, false]) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets('${size.width.toInt()} dark=$dark scale=$scale', (
            tester,
          ) async {
            final fixture = await _seeded();
            await pumpStats(
              tester,
              const ProgressScreen(),
              fixture: fixture,
              size: size,
              dark: dark,
              textScale: scale,
            );
            await _settle(tester);
            expect(tester.takeException(), isNull);
            expect(find.text(StatsCopy.title), findsOneWidget);
          });
        }
      }
    }
  });
}
