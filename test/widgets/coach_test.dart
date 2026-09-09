/// Widget tests for the §10.5 coach anatomy and the §10.1 chart primitives.
///
/// The contract the rest of the app builds on: layer 1 is the first thing on
/// screen, **both** disclosure rows are always there (even with nothing behind
/// them), expanding shows the steps and the expert bullets, and every chart
/// survives empty / one-point / 500-point data at 360, 390 and 430 pt in both
/// themes without an overflow.
library;

import 'dart:math' as math;

import 'package:allin/engine/coach.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/charts/diverging_bar.dart';
import 'package:allin/widgets/charts/heatmap_grid.dart';
import 'package:allin/widgets/charts/line_chart.dart';
import 'package:allin/widgets/charts/mini_bars.dart';
import 'package:allin/widgets/charts/spark_line.dart';
import 'package:allin/widgets/coach/coach_note_view.dart';
import 'package:allin/widgets/coach/coach_notes_list.dart';
import 'package:allin/widgets/coach/equity_bar.dart';
import 'package:allin/widgets/coach/explainer_sheet.dart';
import 'package:allin/widgets/coach/verdict_badge.dart';
import 'package:allin/services/persistence/goals_store.dart' show HeatmapCell;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _phone390 = Size(390, 844);

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> pumpCoach(
  WidgetTester tester,
  Widget child, {
  bool dark = true,
  double textScale = 1.0,
  Size size = _phone390,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AllInAppTheme.dark() : AllInAppTheme.light(),
      home: Builder(
        builder:
            (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CoachReview review({
  Verdict verdict = Verdict.mistake,
  ReviewKind kind = ReviewKind.decision,
  String? plain = 'You paid 8 bb to win a pot of 24 bb.',
  String text = 'Call is −2.0 bb against the assumed range.',
  List<String>? steps,
  List<String>? expert,
  double? equity,
  double? potOdds,
  double? evChips,
  bool multiway = false,
  int opponents = 1,
  List<String> board = const ['7d', '2c', '9s', 'Kd', '3c'],
}) => CoachReview(
  id: 1,
  kind: kind,
  blocking: verdict == Verdict.mistake,
  verdict: verdict,
  title: 'Your call',
  plain: plain,
  text: text,
  steps: steps,
  expert: expert,
  equity: equity,
  potOdds: potOdds,
  evChips: evChips,
  multiway: multiway,
  opponents: opponents,
  villainName: 'Ivey',
  board: board,
);

void main() {
  group('CoachNoteView', () {
    for (final verdict in Verdict.values) {
      testWidgets('$verdict renders layer 1 first and both rows', (
        tester,
      ) async {
        await pumpCoach(
          tester,
          CoachNoteView(
            review: review(
              verdict: verdict,
              kind:
                  verdict == Verdict.info
                      ? ReviewKind.bot
                      : ReviewKind.decision,
            ),
          ),
        );

        expect(
          find.text('You paid 8 bb to win a pot of 24 bb.'),
          findsOneWidget,
        );
        expect(find.text(CoachCopy.showMath), findsOneWidget);
        expect(find.text(CoachCopy.expertDetail), findsOneWidget);

        // Layer 1 sits above both disclosure rows.
        final plainY =
            tester
                .getTopLeft(find.text('You paid 8 bb to win a pot of 24 bb.'))
                .dy;
        final mathY = tester.getTopLeft(find.text(CoachCopy.showMath)).dy;
        final expertY = tester.getTopLeft(find.text(CoachCopy.expertDetail)).dy;
        expect(plainY, lessThan(mathY));
        expect(mathY, lessThan(expertY));

        // The verdict word is printed, never colour alone (§13).
        final read = verdict == Verdict.info;
        expect(
          find.text(VerdictBadge.labelOf(verdict, read: read)),
          findsOneWidget,
        );
      });
    }

    testWidgets('empty steps / expert open to the written placeholders', (
      tester,
    ) async {
      await pumpCoach(tester, CoachNoteView(review: review()));

      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pumpAndSettle();
      expect(find.text(CoachCopy.noMathVerdict), findsOneWidget);
      expect(find.text(CoachCopy.hideMath), findsOneWidget);

      await tester.tap(find.text(CoachCopy.expertDetail));
      await tester.pumpAndSettle();
      // `plain` exists, so layer 3 holds the layer-2 line rather than the
      // "Nothing extra here." placeholder.
      expect(find.text(CoachCopy.nothingExtra), findsNothing);
      expect(
        find.text('Call is −2.0 bb against the assumed range.'),
        findsOneWidget,
      );
    });

    testWidgets('a bot read gets the read placeholder', (tester) async {
      await pumpCoach(
        tester,
        CoachNoteView(
          review: review(
            kind: ReviewKind.bot,
            verdict: Verdict.info,
            plain: null,
            text: 'Ivey raises from the button a lot.',
          ),
        ),
      );
      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pumpAndSettle();
      expect(find.text(CoachCopy.noMathRead), findsOneWidget);

      await tester.tap(find.text(CoachCopy.expertDetail));
      await tester.pumpAndSettle();
      expect(find.text(CoachCopy.nothingExtra), findsOneWidget);
    });

    testWidgets('expanding shows the steps and the expert lines', (
      tester,
    ) async {
      await pumpCoach(
        tester,
        CoachNoteView(
          review: review(
            steps: const ['Pot 24 + call 8 = 32', '17 % × 32 − 8 ≈ −2.6 bb'],
            expert: const ['Range: 22+, A2s+, KTo+'],
          ),
        ),
      );

      expect(find.text('Pot 24 + call 8 = 32'), findsNothing);
      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pumpAndSettle();
      expect(find.text('Pot 24 + call 8 = 32'), findsOneWidget);
      expect(find.text('17 % × 32 − 8 ≈ −2.6 bb'), findsOneWidget);

      await tester.tap(find.text(CoachCopy.expertDetail));
      await tester.pumpAndSettle();
      expect(find.text('Range: 22+, A2s+, KTo+'), findsOneWidget);
    });

    testWidgets('equity bar, multiway callout and EV tile', (tester) async {
      await pumpCoach(
        tester,
        CoachNoteView(
          review: review(
            equity: 0.17,
            potOdds: 0.25,
            evChips: -40,
            multiway: true,
            opponents: 3,
          ),
        ),
      );

      expect(find.text('Win chance vs Ivey'), findsOneWidget);
      expect(find.text('17 %'), findsOneWidget);
      expect(find.text('White line = 25 % needed (pot odds)'), findsOneWidget);
      expect(find.text(CoachCopy.multiway(3)), findsOneWidget);
      expect(find.text(CoachCopy.expectedValue), findsOneWidget);
      // evChips / bigBlind = −40 / 20.
      expect(find.text('-2.0 bb'), findsOneWidget);
    });

    testWidgets('blocking shows "Got it", non-blocking shows "Close"', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpCoach(
        tester,
        CoachNoteView(
          review: review(),
          blocking: true,
          onDismiss: () => dismissed++,
        ),
      );
      expect(find.text(CoachCopy.gotIt), findsOneWidget);
      await tester.tap(find.text(CoachCopy.gotIt));
      expect(dismissed, 1);

      await pumpCoach(
        tester,
        CoachNoteView(review: review(), onDismiss: () {}),
      );
      expect(find.text(CoachCopy.close), findsOneWidget);
    });

    testWidgets('alwaysExpandMath opens layer 2 but never layer 3', (
      tester,
    ) async {
      await pumpCoach(
        tester,
        CoachNoteView(
          review: review(
            steps: const ['Pot 24 + call 8 = 32'],
            expert: const ['Range: 22+'],
          ),
          alwaysExpandMath: true,
        ),
      );
      expect(find.text('Pot 24 + call 8 = 32'), findsOneWidget);
      expect(find.text('Range: 22+'), findsNothing);
    });

    testWidgets('.drill() renders the verdict, delta and outcomes', (
      tester,
    ) async {
      await pumpCoach(
        tester,
        const CoachNoteView.drill(
          correct: false,
          verdictLabel: 'Not optimal',
          ratingDelta: -6,
          evLossLine: 'That choice costs about 1.2 bb every time.',
          rationale: "You're getting 3:1 and this hand wins about 1 time in 3.",
          outcomes: ['Folding: 0 bb — costs nothing more.'],
        ),
      );
      expect(find.text('Not optimal'), findsOneWidget);
      expect(find.text('-6'), findsOneWidget);
      expect(find.text('Folding: 0 bb — costs nothing more.'), findsOneWidget);
      expect(find.text(CoachCopy.showMath), findsOneWidget);
      expect(find.text(CoachCopy.expertDetail), findsOneWidget);

      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pumpAndSettle();
      expect(find.text(CoachCopy.noMathChartSpot), findsOneWidget);
    });

    testWidgets('.peek() leads with the grade word, never the percentage', (
      tester,
    ) async {
      await pumpCoach(
        tester,
        const CoachNoteView.peek(
          grade: PeekGrade.solid,
          plainLines: ['You caught about 7 in 10 of the hands they play here.'],
          mathLines: ['Score: 64 %'],
        ),
      );
      expect(find.text('Solid'), findsOneWidget);
      expect(find.text('Score: 64 %'), findsNothing);

      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pumpAndSettle();
      expect(find.text('Score: 64 %'), findsOneWidget);
    });

    test('PeekGrade thresholds match desktop', () {
      expect(PeekGrade.forScore(0.81), PeekGrade.sharp);
      expect(PeekGrade.forScore(0.6), PeekGrade.solid);
      expect(PeekGrade.forScore(0.4), PeekGrade.rough);
      expect(PeekGrade.forScore(0.39), PeekGrade.wayOff);
    });

    test('streetLabel and firstClause', () {
      expect(CoachNoteView.streetLabel(const []), 'Pre-flop');
      expect(CoachNoteView.streetLabel(const ['a', 'b', 'c']), 'Flop');
      expect(CoachNoteView.streetLabel(const ['a', 'b', 'c', 'd']), 'Turn');
      expect(
        CoachNoteView.streetLabel(const ['a', 'b', 'c', 'd', 'e']),
        'River',
      );
      expect(
        CoachNoteView.firstClause('Betting with the goods — on a wet board.'),
        'Betting with the goods',
      );
    });

    testWidgets('renders in both themes at 1.3× text without overflow', (
      tester,
    ) async {
      for (final dark in const [true, false]) {
        for (final size in const [
          Size(360, 780),
          Size(390, 844),
          Size(430, 932),
        ]) {
          await pumpCoach(
            tester,
            CoachNoteView(
              review: review(
                equity: 0.17,
                potOdds: 0.25,
                evChips: -40,
                multiway: true,
                opponents: 3,
                steps: const ['Pot 24 + call 8 = 32'],
                expert: const ['Range: 22+'],
              ),
              heroCards: const ['Qs', 'Qh'],
              situation: 'you called 8 bb into 24 bb',
              onDismiss: () {},
            ),
            dark: dark,
            textScale: 1.3,
            size: size,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('CoachNotesList', () {
    testWidgets('lists newest first and reports taps', (tester) async {
      CoachReview? tapped;
      await pumpCoach(
        tester,
        CoachNotesList(
          title: 'Coach notes · Hand #12',
          reviews: [
            review(verdict: Verdict.great, plain: 'Betting with the goods.'),
            review(verdict: Verdict.mistake, plain: 'You paid too much.'),
          ],
          onTapNote: (r) => tapped = r,
        ),
      );

      expect(find.text('Coach notes · Hand #12'), findsOneWidget);
      final firstY = tester.getTopLeft(find.text('"You paid too much"')).dy;
      final secondY =
          tester.getTopLeft(find.text('"Betting with the goods"')).dy;
      expect(firstY, lessThan(secondY));

      await tester.tap(find.text('"You paid too much"'));
      expect(tapped?.verdict, Verdict.mistake);
    });

    testWidgets('empty state', (tester) async {
      await pumpCoach(tester, const CoachNotesList(reviews: []));
      expect(find.text('Actions will appear here.'), findsOneWidget);
    });
  });

  group('ExplainerSheet', () {
    testWidgets('always renders both rows and opens to placeholders', (
      tester,
    ) async {
      await pumpCoach(
        tester,
        const ExplainerSheet(
          title: 'Win rate',
          body: 'Big blinds won per 100 hands.',
        ),
      );
      expect(find.text('Big blinds won per 100 hands.'), findsOneWidget);

      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pumpAndSettle();
      expect(find.text(CoachCopy.noMathDefinition), findsOneWidget);

      await tester.tap(find.text(CoachCopy.expertDetail));
      await tester.pumpAndSettle();
      expect(find.text(CoachCopy.nothingExtra), findsOneWidget);
    });
  });

  group('EquityBar', () {
    testWidgets('hides the marker and caption without pot odds', (
      tester,
    ) async {
      await pumpCoach(tester, const EquityBar(equity: 0.5));
      expect(find.text('Win chance'), findsOneWidget);
      expect(find.text('50 %'), findsOneWidget);
      expect(find.textContaining('White line'), findsNothing);
    });

    // The caption reads "White line = 21 % needed", and in Light the unfilled
    // track is #D2DAE4 — a pure white line on it is 1.4:1, i.e. gone. The
    // line keeps its colour; the always-dark edge beside it is what carries
    // the contrast.
    for (final dark in const [true, false]) {
      testWidgets('the needed marker stays visible on the track, '
          '${dark ? 'dark' : 'light'}', (tester) async {
        await pumpCoach(
          tester,
          // Pot odds well past the equity, so the marker sits on the bare
          // track rather than on the verdict fill.
          const EquityBar(equity: 0.12, potOdds: 0.8, villainName: 'Ivey'),
          dark: dark,
        );
        expect(find.textContaining('White line'), findsOneWidget);

        final colors = dark ? AllInColors.dark : AllInColors.light;
        final marker = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color != null &&
              w.constraints?.maxWidth == EquityBar.markerWidth,
        );
        expect(marker, findsOneWidget, reason: 'no marker edge');
        final edge = Color.alphaBlend(
          tester.widget<Container>(marker).color!,
          colors.ink600,
        );
        // White carries the contrast in Dark, the edge carries it in Light —
        // one of them has to, whichever theme this is.
        expect(
          math.max(
            _contrast(edge, colors.ink600),
            _contrast(AllInColors.cardFaceTop, colors.ink600),
          ),
          greaterThanOrEqualTo(3.0),
          reason: 'the needed marker disappears into the track',
        );
      });
    }
  });

  group('charts', () {
    final datasets = <String, List<double>>{
      'empty': const [],
      'single': const [4.5],
      'two': const [0, -3.5],
      'large': List<double>.generate(500, (i) => (i % 37) - 18.0),
    };

    for (final entry in datasets.entries) {
      for (final size in const [
        Size(360, 780),
        Size(390, 844),
        Size(430, 932),
      ]) {
        for (final dark in const [true, false]) {
          testWidgets('render ${entry.key} at ${size.width.toInt()} '
              '${dark ? 'dark' : 'light'}', (tester) async {
            await pumpCoach(
              tester,
              Column(
                children: [
                  LineChart(values: entry.value),
                  const SizedBox(height: 8),
                  MiniBars(
                    values: entry.value
                        .map((v) => (v.abs() % 20) / 20)
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  SparkLine(values: entry.value),
                  const SizedBox(height: 8),
                  DivergingBar(value: -3.5, max: 12),
                  const SizedBox(height: 8),
                  HeatmapGrid(
                    cells: [
                      for (var i = 0; i < entry.value.length && i < 112; i++)
                        HeatmapCell(
                          key: '2026-09-${(i % 28) + 1}',
                          count: i % 40,
                          met: i % 7 == 0,
                        ),
                    ],
                  ),
                ],
              ),
              dark: dark,
              size: size,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('LineChart shows the verbatim empty line under two values', (
      tester,
    ) async {
      await pumpCoach(tester, const LineChart(values: [1]));
      expect(find.text('Play a few hands to see your trend.'), findsOneWidget);
    });

    testWidgets('MiniBars shows the verbatim empty line', (tester) async {
      await pumpCoach(tester, const MiniBars(values: []));
      expect(find.text('No reads logged yet.'), findsOneWidget);
    });

    testWidgets('a plain tap on a chart does nothing (§7.3, §7.11)', (
      tester,
    ) async {
      var scrubs = 0;
      var inspects = 0;
      HeatmapCell? tappedCell;
      await pumpCoach(
        tester,
        Column(
          children: [
            LineChart(values: const [0, 1, 2, 3], onScrub: (_) => scrubs++),
            MiniBars(
              values: const [0.1, 0.5, 0.9],
              onInspect: (_) => inspects++,
            ),
            HeatmapGrid(
              cells: const [
                HeatmapCell(key: '2026-09-01', count: 4, met: false),
              ],
              onTapCell: (cell) => tappedCell = cell,
            ),
          ],
        ),
      );

      await tester.tap(find.byType(LineChart));
      await tester.tap(find.byType(MiniBars));
      await tester.tap(find.byType(HeatmapGrid));
      await tester.pumpAndSettle();
      expect(scrubs, 0);
      expect(inspects, 0);
      expect(tappedCell, isNull);
    });

    testWidgets('holding then dragging the chart scrubs it', (tester) async {
      final seen = <int?>[];
      await pumpCoach(
        tester,
        LineChart(values: const [0, 2, 4, 6, 8], onScrub: seen.add),
      );

      final chart = tester.getCenter(find.byType(LineChart));
      final gesture = await tester.startGesture(
        Offset(chart.dx - 100, chart.dy),
      );
      await tester.pump(const Duration(milliseconds: 260));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(seen, isNotEmpty);
      expect(seen.first, isNotNull);
      expect(seen.last, isNull);
    });

    test('HeatmapGrid.activeDays counts days with any activity', () {
      expect(
        HeatmapGrid.activeDays(const [
          HeatmapCell(key: 'a', count: 0, met: false),
          HeatmapCell(key: 'b', count: 3, met: false),
          HeatmapCell(key: 'c', count: 24, met: true),
        ]),
        2,
      );
    });
  });
}
