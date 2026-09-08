/// Widget + unit tests for the §10.4 range components.
///
/// They pin the §4.9 arithmetic (the grid fits its box at 360 / 390 / 430), the
/// cell↔label mapping against the engine's `labelAt`, the finger-painting
/// contract (touch-down mode, interpolated drag, header selectors, undo) and
/// the compare-mode colouring.
library;

import 'package:allin/engine/notation.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpRange(
  WidgetTester tester,
  Widget child, {
  bool dark = true,
  double textScale = 1.0,
  Size size = const Size(390, 844),
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
                body: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
      ),
    ),
  );
}

/// Top-left of the *grid* — the widget centres it inside the box it was given.
Offset gridOrigin(WidgetTester tester, RangeMatrixGeometry geo) {
  final box = tester.getRect(find.byType(RangeMatrix));
  return Offset(box.left + (box.width - geo.gridWidth) / 2, box.top);
}

void main() {
  group('§4.9 arithmetic', () {
    test('cell = floor((W − H − 12g) / 13) and the grid fits its box', () {
      final cases = <List<double>>[
        // width, header, gap, expected cell
        <double>[352, 20, 1, 24], // P7 painter @ 360
        <double>[382, 20, 2, 26], // P7 painter @ 390
        // §4.9's table prints 29 here (grid 423), which fails its own
        // `grid ≤ W` assert; the formula is normative, so 28 it is.
        <double>[422, 22, 2, 28], // P7 painter @ 430
        <double>[326, 18, 1, 22], // P5 / lessons / explorer (table says 23)
        <double>[300, 16, 1, 20], // P8 reveal row (table says 21)
      ];
      for (final c in cases) {
        final geo = RangeMatrixGeometry.solve(
          width: c[0],
          headerWidth: c[1],
          gap: c[2],
        );
        expect(geo.cell, c[3], reason: 'box ${c[0]}');
        expect(geo.gridWidth, lessThanOrEqualTo(c[0]));
      }
    });

    test('grid widths follow the formula (see the deviation note)', () {
      expect(
        RangeMatrixGeometry.solve(
          width: 352,
          headerWidth: 20,
          gap: 1,
        ).gridWidth,
        344,
      );
      expect(
        RangeMatrixGeometry.solve(
          width: 382,
          headerWidth: 20,
          gap: 2,
        ).gridWidth,
        382,
      );
      expect(
        RangeMatrixGeometry.solve(
          width: 326,
          headerWidth: 18,
          gap: 1,
        ).gridWidth,
        316,
      );
      expect(
        RangeMatrixGeometry.solve(
          width: 300,
          headerWidth: 16,
          gap: 1,
        ).gridWidth,
        288,
      );
    });

    test('hairline buys a point at 360 and text > 1.3× forces it', () {
      final hair = RangeMatrixGeometry.solve(
        width: 352,
        headerWidth: 20,
        gap: 1,
        hairline: true,
      );
      expect(hair.gap, 0);
      expect(hair.cell, 25);
      expect(hair.gridWidth, lessThanOrEqualTo(352));

      final big = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
        textScale: 1.4,
      );
      expect(big.hairline, isTrue);
      expect(big.gridWidth, lessThanOrEqualTo(382));
    });

    test('the in-cell label is omitted below cell 20', () {
      expect(
        RangeMatrixGeometry.solve(
          width: 382,
          headerWidth: 20,
          gap: 2,
        ).labelSize,
        closeTo(10.4, 0.001), // min(11, 26 × 0.40)
      );
      expect(
        RangeMatrixGeometry.solve(
          width: 452,
          headerWidth: 22,
          gap: 2,
        ).labelSize,
        11, // capped
      );
      expect(
        RangeMatrixGeometry.solve(
          width: 264,
          headerWidth: 18,
          gap: 1,
        ).labelSize,
        0,
      );
    });

    test('every cell centre maps to the engine label for that row/col', () {
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      for (var r = 0; r < 13; r++) {
        for (var c = 0; c < 13; c++) {
          final hit = geo.cellAt(geo.rectFor(r, c).center);
          expect(hit, isNotNull);
          expect(hit!.row, r);
          expect(hit.col, c);
          expect(hit.label, labelAt(r, c));
        }
      }
      expect(geo.cellAt(const Offset(2, 2)), isNull); // the header corner
      expect(geo.cellAt(Offset(geo.gridWidth + 10, 40)), isNull);
    });
  });

  group('cell state', () {
    test('compare mode splits correct / missed / extra', () {
      RangeCellState state(String label) => RangeMatrix.stateFor(
        mode: RangeMatrixMode.compare,
        label: label,
        painted: <HandLabel>{'AA', 'KK', 'QQ'},
        actual: <HandLabel>{'AA', 'KK', 'JJ'},
      );
      expect(state('AA'), RangeCellState.correct);
      expect(state('KK'), RangeCellState.correct);
      expect(state('QQ'), RangeCellState.extra);
      expect(state('JJ'), RangeCellState.missed);
      expect(state('72o'), RangeCellState.off);
    });

    test('compare colours are good / warn / bad', () {
      const c = AllInColors.dark;
      expect(
        RangeMatrix.fillColor(c, RangeCellState.correct, ComboKind.pair),
        c.good,
      );
      expect(
        RangeMatrix.fillColor(c, RangeCellState.missed, ComboKind.pair),
        c.warn,
      );
      expect(
        RangeMatrix.fillColor(c, RangeCellState.extra, ComboKind.pair),
        c.bad,
      );
      expect(
        RangeMatrix.fillColor(c, RangeCellState.off, ComboKind.pair),
        c.ink700,
      );
    });

    test('kind colours come from the tokens', () {
      const c = AllInColors.dark;
      expect(
        RangeMatrix.fillColor(c, RangeCellState.painted, ComboKind.pair),
        AllInColors.comboPair,
      );
      expect(
        RangeMatrix.fillColor(c, RangeCellState.painted, ComboKind.suited),
        AllInColors.comboSuited,
      );
      expect(
        RangeMatrix.fillColor(c, RangeCellState.highlighted, ComboKind.offsuit),
        c.comboOffsuit,
      );
    });
  });

  group('UndoController', () {
    test('records strokes and restores the last one, 20 deep', () {
      final undo = UndoController();
      expect(undo.canUndo, isFalse);
      for (var i = 0; i < 25; i++) {
        undo.record(<HandLabel>{'AA'});
      }
      expect(undo.length, 20);
      undo.record(<HandLabel>{'AA', 'KK'});
      expect(undo.undo(), <HandLabel>{'AA', 'KK'});
      expect(undo.length, 19);
      undo.clear();
      expect(undo.canUndo, isFalse);
      expect(undo.undo(), isNull);
    });
  });

  group('painting', () {
    testWidgets('a drag across a row paints exactly that row', (tester) async {
      var value = <HandLabel>{};
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );

      final origin = gridOrigin(tester, geo);
      Offset at(int r, int c) => origin + geo.rectFor(r, c).center;

      final gesture = await tester.startGesture(at(4, 0));
      await tester.pump();
      for (var c = 1; c < 13; c++) {
        await gesture.moveTo(at(4, c));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final expected = <HandLabel>{for (var c = 0; c < 13; c++) labelAt(4, c)};
      expect(value, expected);
      expect(value.length, 13);
    });

    testWidgets('a fast diagonal never skips a cell', (tester) async {
      var value = <HandLabel>{};
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      final gesture = await tester.startGesture(
        origin + geo.rectFor(0, 0).center,
      );
      await tester.pump();
      // One giant jump from AA to 22 — the diagonal must be filled in.
      await gesture.moveTo(origin + geo.rectFor(12, 12).center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      for (var i = 0; i < 13; i++) {
        expect(value, contains(labelAt(i, i)), reason: 'pair $i');
      }
    });

    testWidgets('touch-down on a painted cell erases for the whole stroke', (
      tester,
    ) async {
      var value = <HandLabel>{for (var c = 0; c < 13; c++) labelAt(2, c)};
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      final gesture = await tester.startGesture(
        origin + geo.rectFor(2, 0).center,
      );
      await tester.pump();
      for (var c = 1; c < 5; c++) {
        await gesture.moveTo(origin + geo.rectFor(2, c).center);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(value.length, 8);
      expect(value.contains(labelAt(2, 0)), isFalse);
      expect(value.contains(labelAt(2, 5)), isTrue);
    });

    testWidgets('undo restores the set from before the stroke', (tester) async {
      var value = <HandLabel>{};
      final undo = UndoController();
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                undoController: undo,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      await tester.tapAt(origin + geo.rectFor(0, 0).center);
      await tester.pumpAndSettle();
      expect(value, <HandLabel>{'AA'});
      expect(undo.canUndo, isTrue);
      expect(undo.undo(), isEmpty);
      expect(undo.canUndo, isFalse);
    });

    testWidgets('a header tap toggles the whole row / column, once', (
      tester,
    ) async {
      var value = <HandLabel>{};
      final undo = UndoController();
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                undoController: undo,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      await tester.tapAt(origin + geo.columnHeaderRect(3).center);
      await tester.pumpAndSettle();
      expect(value, <HandLabel>{for (var r = 0; r < 13; r++) labelAt(r, 3)});
      expect(undo.length, 1);

      await tester.tapAt(origin + geo.rowHeaderRect(0).center);
      await tester.pumpAndSettle();
      expect(value.length, 13 + 12); // the row, minus the shared cell
      expect(undo.length, 2);

      // Tapping the same column again clears it (majority inverted).
      await tester.tapAt(origin + geo.columnHeaderRect(3).center);
      await tester.pumpAndSettle();
      expect(value.contains(labelAt(5, 3)), isFalse);
    });

    testWidgets('long-pressing a row header paints "this and better"', (
      tester,
    ) async {
      var value = <HandLabel>{};
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      // Row 5 = the rank "9" → 99+.
      await tester.longPressAt(origin + geo.rowHeaderRect(5).center);
      await tester.pumpAndSettle();
      expect(value, <HandLabel>{'AA', 'KK', 'QQ', 'JJ', 'TT', '99'});
    });

    testWidgets('the header slop never steals a cell touch (§12)', (
      tester,
    ) async {
      var value = <HandLabel>{};
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      // 2 pt inside the first cell row — well inside the column header's
      // 44 pt slop, which must lose to the grid's own paint surface.
      await tester.tapAt(
        origin + Offset(geo.rectFor(0, 6).center.dx, geo.headerHeight + 2),
      );
      await tester.pumpAndSettle();
      expect(value, <HandLabel>{labelAt(0, 6)});
    });

    testWidgets('the loupe follows the finger and leaves on lift', (
      tester,
    ) async {
      var value = <HandLabel>{};
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => RangeMatrix.editable(
                value: value,
                width: 382,
                gap: 2,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      expect(find.byType(RangeMatrixLoupe), findsNothing);
      final gesture = await tester.startGesture(
        origin + geo.rectFor(6, 6).center,
      );
      await tester.pump();
      expect(find.byType(RangeMatrixLoupe), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(RangeMatrixLoupe), findsNothing);
    });

    testWidgets('an editable matrix publishes a gesture-exclusion rect', (
      tester,
    ) async {
      final rects = <Rect?>[];
      RangeMatrix.exclusionReporter = rects.add;
      addTearDown(() => RangeMatrix.exclusionReporter = null);

      await pumpRange(
        tester,
        RangeMatrix.editable(
          value: const <HandLabel>{},
          width: 382,
          gap: 2,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(rects.whereType<Rect>(), isNotEmpty);
      expect(rects.whereType<Rect>().last.width, 382);

      rects.clear();
      await pumpRange(tester, const RangeMatrix.readOnly(width: 382, gap: 2));
      await tester.pumpAndSettle();
      expect(rects.whereType<Rect>(), isEmpty);
    });

    testWidgets('a read-only matrix ignores drags', (tester) async {
      final geo = RangeMatrixGeometry.solve(
        width: 382,
        headerWidth: 20,
        gap: 2,
      );
      await pumpRange(
        tester,
        const RangeMatrix.readOnly(
          highlight: <HandLabel>{'AA'},
          width: 382,
          gap: 2,
        ),
      );
      final origin = gridOrigin(tester, geo);
      await tester.dragFrom(
        origin + geo.rectFor(0, 0).center,
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    for (final size in <Size>[
      const Size(360, 780),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      for (final dark in <bool>[true, false]) {
        for (final scale in <double>[1.0, 1.3]) {
          testWidgets('painter fits ${size.width.toInt()} '
              '${dark ? 'dark' : 'light'} @${scale}x', (tester) async {
            final box = size.width - 8;
            await pumpRange(
              tester,
              RangeMatrix.editable(
                value: const <HandLabel>{'AA', 'AKs', 'AKo'},
                width: box,
                gap: size.width <= 360 ? 1 : 2,
                headerWidth: size.width >= 430 ? 22 : 20,
                onChanged: (_) {},
              ),
              dark: dark,
              textScale: scale,
              size: size,
            );
            expect(tester.takeException(), isNull);
            final rendered = tester.getSize(find.byType(RangeMatrix));
            expect(rendered.width, lessThanOrEqualTo(box));
            expect(rendered.height, lessThanOrEqualTo(size.height));
          });
        }
      }
    }

    testWidgets('an embedded matrix keeps painting while the page scrolls', (
      tester,
    ) async {
      var value = <HandLabel>{};
      final geo = RangeMatrixGeometry.solve(
        width: 326,
        headerWidth: 18,
        gap: 1,
      );
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpRange(
        tester,
        SizedBox(
          width: 390,
          height: 600,
          child: ListView(
            controller: controller,
            children: <Widget>[
              const SizedBox(height: 400),
              Center(
                child: StatefulBuilder(
                  builder:
                      (context, setState) => RangeMatrix.editable(
                        value: value,
                        width: 326,
                        headerWidth: 18,
                        onChanged: (next) => setState(() => value = next),
                      ),
                ),
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      );
      final origin = gridOrigin(tester, geo);
      final gesture = await tester.startGesture(
        origin + geo.rectFor(0, 0).center,
      );
      await tester.pump();
      await gesture.moveTo(origin + geo.rectFor(4, 0).center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.offset, 0, reason: 'the grid claimed the drag (§6.5)');
      expect(value.length, 5);
    });
  });

  group('legend, presets and counter', () {
    testWidgets('legend renders both modes', (tester) async {
      await pumpRange(
        tester,
        const Column(
          children: <Widget>[
            RangeLegend(),
            RangeLegend(mode: RangeLegendMode.compare, hatchWhenNoColour: true),
          ],
        ),
      );
      expect(find.text('Pairs'), findsOneWidget);
      expect(find.text('Suited'), findsOneWidget);
      expect(find.text('Offsuit'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Extra'), findsOneWidget);
    });

    test('the default presets are the §4.9 list', () {
      final presets = RangePresetRow.defaults();
      expect(presets.map((p) => p.label).toList(), <String>[
        'Top 10 %',
        '15 %',
        '25 %',
        '40 %',
        '55 %',
        'UTG',
        'MP',
        'CO',
        'BTN',
        'BB',
        'Any two',
        'Clear',
      ]);
      expect(presets.first.labels, contains('AA'));
      expect(presets.firstWhere((p) => p.id == 'clear').labels, isEmpty);
      expect(presets.firstWhere((p) => p.id == 'any-two').labels.length, 169);
      final utg = presets.firstWhere((p) => p.id == 'open-UTG').labels;
      expect(utg, contains('AA'));
      expect(utg, isNot(contains('72o')));
      expect(
        combosInSet(presets.firstWhere((p) => p.id == 'defend-BB').labels),
        greaterThan(combosInSet(utg)),
      );
    });

    testWidgets('preset chips are 44 pt tall and report their pick', (
      tester,
    ) async {
      RangePreset? picked;
      await pumpRange(
        tester,
        RangePresetRow(
          presets: RangePresetRow.defaults(),
          onPick: (p) => picked = p,
        ),
      );
      final chip = find.text('Top 10 %');
      expect(chip, findsOneWidget);
      expect(
        tester.getSize(find.byType(RangePresetRow)).height,
        RangePresetRow.hitHeight,
      );
      await tester.tap(chip);
      await tester.pump();
      expect(picked?.id, 'top-10');
    });

    testWidgets('the counter reads combos, percent and the empty state', (
      tester,
    ) async {
      await pumpRange(
        tester,
        const Column(
          children: <Widget>[
            ComboCounter(combos: 148),
            ComboCounter(combos: 0),
          ],
        ),
      );
      expect(find.text('148 combos · 11% of hands'), findsOneWidget);
      expect(find.text('Nothing painted yet'), findsOneWidget);
    });
  });
}
