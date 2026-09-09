/// S4 · Quick reference + glossary (DESIGN.md §6.7) — the five reference
/// sections, the searchable glossary, and the `?term=` deep link (a query,
/// never a fragment).
library;

import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/glossary.dart';
import 'package:allin/features/study/screens/quick_reference_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('renders', () {
    for (final size in kStudySizes) {
      testWidgets('at ${size.width.toInt()} pt', (tester) async {
        await pumpStudyApp(
          tester,
          location: AllInRoutes.glossaryPath(),
          size: size,
        );
        expect(find.text('Quick reference'), findsOneWidget);
        expect(find.text('Equity from outs (2 / 4 rule)'), findsOneWidget);
        expect(find.text('≈ 36% / 18%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at 1.3x text scale', (tester) async {
      await pumpStudyApp(
        tester,
        location: AllInRoutes.glossaryPath(),
        size: const Size(360, 780),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the glossary section carries the caption', (tester) async {
      await pumpStudyApp(tester, location: AllInRoutes.glossaryPath());
      expect(find.text('Glossary'), findsOneWidget);
      expect(find.text(kQuickReferenceCaption), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters both halves and drops the section headings', (
      tester,
    ) async {
      await pumpStudyApp(tester, location: AllInRoutes.glossaryPath());
      await tester.enterText(find.byType(TextField), 'blocker');
      await tester.pump();
      expect(
        find.textContaining('removes combos from the opponent'),
        findsOneWidget,
      );
      expect(find.text('Equity from outs (2 / 4 rule)'), findsNothing);
      expect(find.text('Glossary'), findsNothing);
    });

    testWidgets('matches the reference numbers too', (tester) async {
      await pumpStudyApp(tester, location: AllInRoutes.glossaryPath());
      await tester.enterText(find.byType(TextField), 'Gutshot');
      await tester.pump();
      expect(find.text('≈ 16% / 8%'), findsOneWidget);
    });

    testWidgets('says so when nothing matches, and clears', (tester) async {
      await pumpStudyApp(tester, location: AllInRoutes.glossaryPath());
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('Nothing matches “zzzz”.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.text('Equity from outs (2 / 4 rule)'), findsOneWidget);
    });
  });

  group('?term= deep link', () {
    testWidgets('scrolls a term into view and flashes it', (tester) async {
      await pumpStudyApp(
        tester,
        location: AllInRoutes.glossaryPath(term: 'blocker'),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      // The row really was revealed, not just built off-screen.
      expect(
        find.textContaining('removes combos from the opponent'),
        findsOneWidget,
      );
      final box = tester.getRect(
        find.textContaining('removes combos from the opponent'),
      );
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(844));
      // Let the 600 ms gold flash finish.
      await tester.pump(kTermFlashDuration);
      await tester.pump();
    });

    testWidgets('an unknown term opens at the top, never an error', (
      tester,
    ) async {
      await pumpStudyApp(
        tester,
        location: AllInRoutes.glossaryPath(term: 'not-a-term'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Equity from outs (2 / 4 rule)'), findsOneWidget);
    });

    test('the path is a query parameter, not a fragment', () {
      expect(
        AllInRoutes.glossaryPath(term: 'potOdds'),
        '/study/glossary?term=potOdds',
      );
    });
  });

  test('every glossary key is unique and non-empty', () {
    final keys = kGlossary.map((t) => t.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
    expect(keys.any((k) => k.isEmpty), isFalse);
    expect(kGlossary, hasLength(25));
  });
}
