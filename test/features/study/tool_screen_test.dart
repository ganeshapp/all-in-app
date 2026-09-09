/// S3 · Tool screens (DESIGN.md §6.6) — each tool is its lesson's widget at
/// full width, with the lesson's lead as the intro.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/screens/tool_screen.dart';
import 'package:allin/features/study/widgets/study_path.dart';
import 'package:allin/features/study/widgets/study_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Everything a reader can actually see, `Text` and `RichText` alike.
String _visibleText(WidgetTester tester) {
  final buf = StringBuffer();
  for (final w in tester.allWidgets) {
    if (w is Text) buf.write(w.data ?? '');
    if (w is RichText) buf.write(w.text.toPlainText());
  }
  return buf.toString();
}

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
      // The lead is lesson prose and goes through the lesson's own renderer.
      final lead = tester.widget<LessonRichText>(
        find.byType(LessonRichText).first,
      );
      expect(lead.text, ToolScreen.leadOf(tool.lessonId));
      // A plain `Text` printed the paragraph's own markup: "**equity**" with
      // the asterisks showing.
      expect(_visibleText(tester), isNot(contains('**')));
      expect(_visibleText(tester), isNot(contains('{{')));
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

  // The title shares its row with the back chevron and "Open lesson ›". At
  // 360 pt × 1.3× even "Equity calc" overran that slot and read "Equity c…";
  // the tool's own name is the one thing S3's header has to say.
  testWidgets('no tool name is truncated at 360 pt, 1.3x text', (tester) async {
    for (final tool in kStudyTools) {
      await pumpStudyApp(
        tester,
        location: AllInRoutes.toolPath(tool.id),
        size: const Size(360, 780),
        textScale: 1.3,
      );
      final title = find.text(tool.label);
      expect(title, findsWidgets, reason: '${tool.id} has no header title');
      for (final element in title.evaluate()) {
        expect(
          (element.renderObject! as RenderParagraph).didExceedMaxLines,
          isFalse,
          reason: '${tool.id} is truncated in its header',
        );
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
