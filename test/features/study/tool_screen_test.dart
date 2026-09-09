/// S3 · Tool screens (DESIGN.md §6.6) — each tool is its lesson's widget at
/// full width, with the lesson's lead as the intro.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/screens/tool_screen.dart';
import 'package:allin/features/study/widgets/study_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('every tool points at a real lesson', () {
    for (final tool in kStudyTools) {
      expect(
        lessonById(tool.lessonId),
        isNotNull,
        reason: '${tool.id} → ${tool.lessonId}',
      );
      expect(ToolScreen.leadOf(tool.lessonId), isNotNull);
    }
  });

  for (final tool in kStudyTools) {
    testWidgets('${tool.id} renders with its lead', (tester) async {
      await pumpStudyApp(tester, location: AllInRoutes.toolPath(tool.id));
      expect(find.text(tool.label), findsOneWidget);
      expect(find.text('Open lesson ›'), findsOneWidget);
      expect(find.text(ToolScreen.leadOf(tool.lessonId)!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders at 360 and 430 without overflow', (tester) async {
    for (final size in <Size>[const Size(360, 780), const Size(430, 932)]) {
      for (final tool in kStudyTools) {
        await pumpStudyApp(
          tester,
          location: AllInRoutes.toolPath(tool.id),
          size: size,
        );
        expect(tester.takeException(), isNull, reason: '${tool.id} @$size');
      }
    }
  });

  testWidgets('"Open lesson ›" pushes the reader', (tester) async {
    await pumpStudyApp(tester, location: AllInRoutes.toolPath('pot-odds'));
    await tester.tap(find.text('Open lesson ›'));
    await tester.pumpAndSettle();
    expect(find.text('Pot Odds, Break-even & EV'), findsOneWidget);
    expect(find.text('6 min read'), findsOneWidget);
  });

  testWidgets('an unknown tool offers the six real ones', (tester) async {
    await pumpStudyApp(tester, location: AllInRoutes.toolPath('nope'));
    expect(find.text('Tools'), findsOneWidget);
    expect(
      find.text(
        "That tool isn't in this version — here are the ones that are.",
      ),
      findsOneWidget,
    );
    expect(find.byType(ToolsGrid), findsOneWidget);
    await tester.tap(find.text('Bluff calc'));
    await tester.pumpAndSettle();
    expect(find.text('Bluff calc'), findsOneWidget);
    expect(find.text('Open lesson ›'), findsOneWidget);
  });
}
