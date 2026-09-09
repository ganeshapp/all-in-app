/// S0 · Study root (DESIGN.md §6.1, §14 "all 31 complete").
library;

import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/widgets/study_path.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/study_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

KeyValueStore _storeWith(List<String> completed) {
  final store = KeyValueStore.memory();
  store.setJson(StudyProgress.storageKey, completed);
  return store;
}

void main() {
  group('renders', () {
    for (final size in kStudySizes) {
      for (final dark in <bool>[true, false]) {
        testWidgets('at ${size.width.toInt()} pt, ${dark ? 'dark' : 'light'}', (
          tester,
        ) async {
          await pumpStudyApp(tester, size: size, dark: dark);
          expect(find.text('Study'), findsOneWidget);
          expect(find.text('Your progress'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('at 1.3x text scale', (tester) async {
      await pumpStudyApp(tester, size: const Size(360, 780), textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.byType(ToolsGrid), findsOneWidget);
    });

    testWidgets('reflows the tools to one column above 1.5x', (tester) async {
      expect(ToolsGrid.singleColumn(1.6), isTrue);
      expect(ToolsGrid.singleColumn(1.3), isFalse);
      // The tile is solved from the text scale now that it carries a gloss
      // line under the label; it grows with the user's text, never shrinks.
      expect(ToolsGrid.tileHeight(1.0), greaterThan(56));
      expect(ToolsGrid.tileHeight(1.4), greaterThan(ToolsGrid.tileHeight(1.0)));
      await pumpStudyApp(tester, size: const Size(360, 780), textScale: 1.6);
      expect(tester.takeException(), isNull);
    });

    // A tool nobody can name is a tool nobody opens: the six tiles say what
    // they do, and the gloss has to survive the narrowest tile at the largest
    // two-column text scale.
    for (final size in <Size>[Size(360, 780), Size(390, 844), Size(430, 932)]) {
      for (final scale in <double>[1.0, 1.3]) {
        testWidgets('every tool names what it does at ${size.width.toInt()}, '
            '${scale}x text', (tester) async {
          await pumpStudyApp(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          for (final tool in kStudyTools) {
            expect(
              find.text(tool.subtitle),
              findsOneWidget,
              reason: '${tool.id} has no gloss on screen',
            );
            final text = tester.widget<Text>(find.text(tool.subtitle));
            final box = tester.renderObject<RenderBox>(
              find.text(tool.subtitle),
            );
            expect(text.maxLines, 2);
            // Two lines of gloss have to fit inside the tile the grid
            // reserved for them.
            expect(
              box.size.height,
              lessThanOrEqualTo(ToolsGrid.tileHeight(scale)),
            );
          }
        });
      }
    }
  });

  group('progress header and Continue card', () {
    testWidgets('first run: 0/31 and the first lesson', (tester) async {
      await pumpStudyApp(tester);
      expect(find.text('0/31'), findsOneWidget);
      expect(find.text('Continue: Hand Rankings'), findsOneWidget);
      expect(find.text('Basics · 4 min read'), findsOneWidget);
    });

    testWidgets('skips completed lessons in path order', (tester) async {
      await pumpStudyApp(
        tester,
        overrides: studyOverrides(
          store: _storeWith(<String>['hand-rankings', 'position']),
        ),
      );
      expect(find.text('2/31'), findsOneWidget);
      expect(find.text('Continue: Bankroll & Mindset'), findsOneWidget);
    });

    testWidgets('§14 course complete', (tester) async {
      await pumpStudyApp(
        tester,
        overrides: studyOverrides(store: _storeWith(kAllLessonIds)),
      );
      expect(find.text('31/31'), findsOneWidget);
      expect(find.text(ContinueCard.completeTitle), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the Continue card opens the reader', (tester) async {
      await pumpStudyApp(tester);
      await tester.tap(find.text('Continue: Hand Rankings'));
      await tester.pumpAndSettle();
      expect(find.text('4 min read'), findsOneWidget);
      expect(find.text('BASICS'), findsOneWidget);
    });

    testWidgets('a lesson row opens that lesson', (tester) async {
      await pumpStudyApp(tester);
      await tester.tap(find.text('Bankroll & Mindset'));
      await tester.pumpAndSettle();
      expect(find.text('BASICS'), findsOneWidget);
      expect(find.text('4 min read'), findsOneWidget);
    });

    testWidgets('a tool tile opens its tool screen', (tester) async {
      await pumpStudyApp(tester);
      await tester.tap(find.text('Pot odds'));
      await tester.pumpAndSettle();
      expect(find.text('Pot odds'), findsOneWidget);
      expect(find.text('Open lesson ›'), findsOneWidget);
    });

    testWidgets('the pinned row opens the quick reference', (tester) async {
      await pumpStudyApp(tester);
      await tester.tap(find.text(QuickReferenceRow.label));
      await tester.pumpAndSettle();
      expect(find.text('Quick reference'), findsOneWidget);
      expect(find.text('Search terms and numbers'), findsOneWidget);
    });
  });

  group('level path', () {
    testWidgets('shows five sticky level headers and the level counts', (
      tester,
    ) async {
      await pumpStudyApp(
        tester,
        overrides: studyOverrides(
          store: _storeWith(<String>['hand-rankings', 'position']),
        ),
      );
      expect(find.byType(LevelHeader), findsWidgets);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Hand Rankings'), findsOneWidget);
      expect(find.text('4m'), findsWidgets);
    });

    testWidgets('the store round-trips through the notifier', (tester) async {
      final store = KeyValueStore.memory();
      await pumpStudyApp(tester, overrides: studyOverrides(store: store));
      expect(StudyProgressStore(store).load().completed, isEmpty);
      await tester.tap(find.text('Continue: Hand Rankings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mark complete'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();
      expect(StudyProgressStore(store).load().completed, <String>[
        'hand-rankings',
      ]);
    });
  });
}
