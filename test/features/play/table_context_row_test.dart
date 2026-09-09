/// The 48 pt context row (DESIGN.md §4.5), and in particular `⏭`.
///
/// "Skip to my turn" is the most valuable control of an Auto-pace grind, and
/// it used to be a bare 22 pt `textMuted` glyph at the right edge of an ink900
/// row: invisible against the background and unlabelled, so nothing told a
/// returning user it existed. It now gets the gold treatment and the verb.
///
/// The rows here leave "Explain last move" out on purpose: the test font gives
/// every glyph a full em, so that one label measures ~2.5× its shipped width
/// and no phone-width row containing it can be laid out truthfully.
library;

import 'package:allin/features/play/widgets/table_context_row.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = phone390,
  double textScale = 1.0,
  bool dark = true,
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
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: child,
                ),
              ),
            ),
      ),
    ),
  );
}

void main() {
  group('⏭ (§4.5 C/D)', () {
    testWidgets('reads as a control: gold, labelled, ≥ 44 pt', (tester) async {
      var skips = 0;
      await _pump(
        tester,
        TableContextRow(
          mode: ContextRowMode.waiting,
          thinkingName: 'Ivey',
          showSkip: true,
          onSkip: () => skips++,
          reducedMotion: true,
        ),
      );

      expect(find.text(TableContextRow.skipLabel), findsOneWidget);

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.skip_next_rounded).first,
      );
      expect(icon.color, AllInColors.dark.gold);

      final label = tester.widget<Text>(find.text(TableContextRow.skipLabel));
      expect(label.style?.color, AllInColors.dark.gold);

      final box = tester.getRect(find.byIcon(Icons.skip_next_rounded).first);
      final tapTarget = tester.getRect(
        find.ancestor(
          of: find.text(TableContextRow.skipLabel),
          matching: find.byType(InkWell),
        ),
      );
      expect(tapTarget.height, greaterThanOrEqualTo(44));
      expect(tapTarget.width, greaterThanOrEqualTo(44));
      expect(box.width, greaterThan(0));

      await tester.tap(find.text(TableContextRow.skipLabel));
      await tester.pump();
      expect(skips, 1);
    });

    testWidgets('the screen reader still hears the whole sentence', (
      tester,
    ) async {
      await _pump(
        tester,
        TableContextRow(
          mode: ContextRowMode.waiting,
          thinkingName: 'Ivey',
          showSkip: true,
          onSkip: () {},
          reducedMotion: true,
        ),
      );
      expect(find.bySemanticsLabel('Skip to my turn'), findsOneWidget);
    });

    test('the label is dropped at 1.3×, exactly like §4.2.4', () {
      expect(TableContextRow.dropsSkipLabel(TextScaler.noScaling), isFalse);
      expect(
        TableContextRow.dropsSkipLabel(const TextScaler.linear(1.15)),
        isFalse,
      );
      expect(
        TableContextRow.dropsSkipLabel(const TextScaler.linear(1.3)),
        isTrue,
      );
    });

    for (final size in const [phone360, phone390, phone430]) {
      testWidgets('at 1.3× the glyph carries it alone at '
          '${size.width.toInt()}', (tester) async {
        await _pump(
          tester,
          TableContextRow(
            mode: ContextRowMode.waiting,
            thinkingName: 'Negreanu',
            showSkip: true,
            onSkip: () {},
            reducedMotion: true,
          ),
          size: size,
          textScale: 1.3,
        );
        expect(find.text(TableContextRow.skipLabel), findsNothing);
        expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
        expect(find.bySemanticsLabel('Skip to my turn'), findsOneWidget);
      });
    }
  });
}
