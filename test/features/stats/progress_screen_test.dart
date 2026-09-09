/// T0 · Progress (DESIGN.md §7.1–§7.4, §7.11, §14).
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/screens/progress_screen.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/tokens.dart';
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

/// The colour of the money in a coaching-review row.
Color? _rowMoneyColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

/// The colour of a `StatTile`'s big mono value, found by its label.
Color? _tileValueColour(WidgetTester tester, String label) {
  final tile = find.ancestor(
    of: find.text(label.toUpperCase()),
    matching: find.byType(StatTile),
  );
  final value = tester.widget<StatTile>(tile.first).value;
  return tester
      .widget<Text>(find.descendant(of: tile.first, matching: find.text(value)))
      .style
      ?.color;
}

/// The colour of a coaching-review verdict count, found by its eyebrow.
Color? _verdictColour(WidgetTester tester, String label) {
  final box =
      find
          .ancestor(
            of: find.text(label.toUpperCase()),
            matching: find.byType(Column),
          )
          .first;
  return tester
      .widget<Text>(find.descendant(of: box, matching: find.byType(Text)).first)
      .style
      ?.color;
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

    // KPI zeros and the "—" read accuracy (§7.2).
    expect(find.text('0'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(find.text(StatsCopy.kpiReadsSub(0)), findsOneWidget);

    // Cards further down the page. The glossed "EV Coach" empty line is a
    // line taller, so the hands card now starts just below the fold too.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(StatsCopy.handsEmpty),
      300,
      scrollable: list,
    );
    expect(find.text(StatsCopy.handsEmpty), findsOneWidget);

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
    // The facts read as counts (TONE.md) and the money is its own span, so a
    // positive amount can be coloured on the money scale rather than in red.
    expect(
      find.text(StatsCopy.decisionNumbers(equity: 0.17, potOdds: 0.25)),
      findsWidgets,
    );
    expect(
      StatsCopy.decisionNumbers(equity: 0.17, potOdds: 0.25),
      'needed about 1 time in 4 · won about 1 time in 6',
    );
    expect(find.text(StatsCopy.decisionAmount(-2)), findsWidgets);

    // The recent hand row, further down the page.
    await tester.scrollUntilVisible(
      find.textContaining('Hand #7'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Hand #7'), findsOneWidget);
  });

  testWidgets('a decision row colours only the money, on the money scale', (
    tester,
  ) async {
    // Principle 8 / §13: verdicts and results never share a colour scale in
    // one row. The whole trailing string used to be painted `c.bad`, so a
    // *gain* ("+4.5 bb") was printed in the loss red.
    final fixture = await _seeded();
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    final colours = AllInColors.dark;
    final facts = StatsCopy.decisionNumbers(equity: 0.17, potOdds: 0.25);
    expect(_rowMoneyColour(tester, facts), colours.textMuted);
    expect(_rowMoneyColour(tester, StatsCopy.decisionAmount(-2)), colours.bad);
  });

  testWidgets('a zero is never painted as a win, a loss or a verdict', (
    tester,
  ) async {
    // §13 / principle 8: "+0.0 bb" in the win green and "0 GREAT PLAYS" in it
    // drew the eye to nothing having happened. Zero is a neutral fact.
    final fixture = StatsFixture();
    await fixture.addHand(sixMaxHand(), netBb: 0, position: Position.btn);
    for (var i = 0; i < 4; i++) {
      await fixture.addDecision(_decision('mistake', 'fold', i));
    }
    await pumpStats(tester, const ProgressScreen(), fixture: fixture);
    await _settle(tester);

    final colours = AllInColors.dark;
    // The NET tile and the win-rate tile both read zero here.
    expect(_tileValueColour(tester, StatsCopy.kpiNet), colours.textMuted);
    expect(_tileValueColour(tester, StatsCopy.kpiWinRate), colours.textMuted);

    // Only the verdict that actually happened keeps its colour.
    expect(_verdictColour(tester, StatsCopy.verdictMistakes), colours.bad);
    expect(
      _verdictColour(tester, StatsCopy.verdictThinSpots),
      colours.textMuted,
    );
    expect(
      _verdictColour(tester, StatsCopy.verdictGreatPlays),
      colours.textMuted,
    );
  });

  test('the money helper makes zero neutral in both directions', () {
    final colours = AllInColors.dark;
    expect(colours.money(4.5), colours.good);
    expect(colours.money(-0.4), colours.bad);
    expect(colours.money(0), colours.textMuted);
    expect(colours.countTone(0, colours.good), colours.textMuted);
    expect(colours.countTone(2, colours.good), colours.good);
    expect(StatTone.money(1), StatTone.good);
    expect(StatTone.money(-1), StatTone.bad);
    expect(StatTone.money(0), StatTone.muted);
  });

  test('the coaching-review copy has no unglossed shorthand', () {
    // "−EV", "eq" and the raw archetype codes are never explained on T0.
    expect(StatsCopy.recentNegativeEv, isNot(contains('EV')));
    expect(
      StatsCopy.decisionNumbers(equity: 0.25, potOdds: 0.33),
      isNot(contains('eq')),
    );
    expect(
      StatsCopy.decisionNumbers(equity: 0.25, potOdds: 0.33),
      isNot(contains('%')),
    );
    expect(
      StatsCopy.decisionRow(street: 'flop', action: 'fold', archetype: 'TAG'),
      'Flop fold vs Tight-Aggressive',
    );
    expect(
      StatsCopy.decisionRow(
        street: 'river',
        action: 'call',
        archetype: 'Station',
      ),
      'River call vs Calling Station',
    );
  });

  test('the read-accuracy explainer states the formula the engine uses', () {
    // §4.9's prose says the arithmetic mean; `coach.dart` scores the harmonic
    // mean. TONE.md's honesty rule makes the code the authority, and a spec
    // cross-reference means nothing to a user.
    expect(StatsCopy.readAccuracyExpert, isNot(contains('§')));
    expect(StatsCopy.readAccuracyExpert, isNot(contains('/ 2')));
    expect(StatsCopy.readAccuracyExpert, contains('2 × coverage × precision'));
  });

  test('the read-accuracy nudge points at labels the app actually shows', () {
    expect(StatsCopy.readAccuracyLeak, isNot(contains('Guess & Peek')));
    expect(StatsCopy.readAccuracyLeak, contains('Range-Building Drill'));
    expect(StatsCopy.readAccuracyLeak, contains('eye on a seat'));
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
