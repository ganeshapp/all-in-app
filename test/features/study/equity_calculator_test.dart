/// The equity calculator (DESIGN.md §6.5, §14) and the two surfaces it owns:
/// the S5 card keypad and the S6 range editor.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/features/study/widgets/card_keypad_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The board strip's tap target (the S5 opener).
final Finder boardSlots = find.byWidgetPredicate(
  (w) => w is Semantics && (w.properties.label ?? '').startsWith('Board, '),
);

/// Taps [finder] after scrolling it into the viewport — the calculator is
/// taller than any phone.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('§14 empty ranges: the button is disabled and says 0 vs 0', (
    tester,
  ) async {
    await pumpStudyApp(
      tester,
      location: AllInRoutes.toolPath('equity'),
      size: const Size(430, 932),
    );
    expect(find.text('0 vs 0 combos'), findsOneWidget);
    expect(find.text('Calculate equity'), findsOneWidget);
    expect(find.text('Board (0/5)'), findsOneWidget);

    // Tapping the disabled button does nothing at all.
    await tapVisible(tester, find.text('Calculate equity'));
    expect(find.text('Win'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Any two" fills a range and the footer counts it', (
    tester,
  ) async {
    await pumpStudyApp(
      tester,
      location: AllInRoutes.toolPath('equity'),
      size: const Size(430, 932),
    );
    await tapVisible(tester, find.text('Any two').first);
    expect(find.text('$kTotalCombos vs 0 combos'), findsOneWidget);
  });

  testWidgets('the S5 keypad picks board cards', (tester) async {
    await pumpStudyApp(
      tester,
      location: AllInRoutes.toolPath('equity'),
      size: const Size(430, 932),
    );
    await tester.ensureVisible(boardSlots);
    await tester.pump();
    await tester.tap(boardSlots);
    await tester.pumpAndSettle();
    expect(find.byType(CardKeypadSheet), findsOneWidget);
    expect(find.text('Board · 0/5'), findsOneWidget);

    // "A♠" and "K♠" — the rank keys carry the suit glyph.
    await tester.tap(find.text('A♠'));
    await tester.pump();
    await tester.tap(find.text('K♠'));
    await tester.pump();
    expect(find.text('Board · 2/5'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Board (2/5)'), findsOneWidget);
    expect(find.text('Clear board'), findsOneWidget);

    await tapVisible(tester, find.text('Clear board'));
    expect(find.text('Board (0/5)'), findsOneWidget);
  });

  testWidgets('"Edit" opens S6 and Done brings the painted range back', (
    tester,
  ) async {
    await pumpStudyApp(
      tester,
      location: AllInRoutes.toolPath('equity'),
      size: const Size(430, 932),
    );
    await tester.ensureVisible(find.text('Edit').first);
    await tester.pump();
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('Your range'), findsWidgets);

    await tester.tap(find.text('Top 10 %'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Back on the calculator with a non-empty hero range.
    expect(find.text('Board (0/5)'), findsOneWidget);
    expect(find.text('0 vs 0 combos'), findsNothing);
  });

  testWidgets('a full run reports win / tie / lose', (tester) async {
    await pumpStudyApp(
      tester,
      location: AllInRoutes.toolPath('equity'),
      size: const Size(430, 932),
    );
    final anyTwo = find.text('Any two');
    await tapVisible(tester, anyTwo.at(0));
    await tapVisible(tester, anyTwo.at(1));
    expect(find.text('$kTotalCombos vs $kTotalCombos combos'), findsOneWidget);

    await tester.ensureVisible(find.text('Calculate equity'));
    await tester.pump();
    await tester.tap(find.text('Calculate equity'));
    // The in-process service runs 5 000 trials off the build phase.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Your equity'), findsOneWidget);
    expect(find.textContaining('Win '), findsOneWidget);
    expect(find.textContaining('Tie '), findsOneWidget);
    expect(find.textContaining('Lose '), findsOneWidget);
    expect(find.textContaining('trials'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
