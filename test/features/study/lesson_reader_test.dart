/// S1 · Lesson reader (DESIGN.md §6.2, §6.4, §14).
///
/// The headline test is the boring one: **every one of the 31 lessons renders,
/// at every supported width, in both themes, and again at 1.3× text** — an
/// overflow anywhere in the curriculum fails the suite. The rest pin the
/// behaviours the spec is explicit about: explicit completion, "Next lesson"
/// navigating without completing, and an unknown id landing on Study.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/content/glossary.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/features/study/screens/lesson_reader_screen.dart';
import 'package:allin/features/study/widgets/study_chrome.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/study_store.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('every lesson renders', () {
    for (final size in kStudySizes) {
      testWidgets('at ${size.width.toInt()} pt', (tester) async {
        for (final lesson in kAllLessons) {
          await pumpStudyApp(
            tester,
            location: AllInRoutes.lessonPath(lesson.id),
            size: size,
          );
          expect(
            find.text(lesson.title),
            findsOneWidget,
            reason: 'title of ${lesson.id}',
          );
          // Scroll the whole body: an overflow below the fold still throws.
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -4000),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: lesson.id);
        }
      });
    }

    testWidgets('at 1.3x text scale', (tester) async {
      for (final lesson in kAllLessons) {
        await pumpStudyApp(
          tester,
          location: AllInRoutes.lessonPath(lesson.id),
          size: const Size(360, 780),
          textScale: 1.3,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: lesson.id);
      }
    });

    testWidgets('in the light theme', (tester) async {
      for (final lesson in kAllLessons) {
        await pumpStudyApp(
          tester,
          location: AllInRoutes.lessonPath(lesson.id),
          dark: false,
        );
        expect(tester.takeException(), isNull, reason: lesson.id);
      }
    });
  });

  group('header and footer', () {
    testWidgets('shows the level eyebrow, progress and minutes', (
      tester,
    ) async {
      await pumpStudyApp(tester, location: AllInRoutes.lessonPath('pot-odds'));
      expect(find.text('POST-FLOP'), findsOneWidget);
      expect(find.text('0/31'), findsOneWidget);
      expect(find.text('6 min read'), findsOneWidget);
    });

    testWidgets('Mark complete persists and becomes "Completed"', (
      tester,
    ) async {
      final store = KeyValueStore.memory();
      await pumpStudyApp(
        tester,
        location: AllInRoutes.lessonPath('hand-rankings'),
        overrides: studyOverrides(store: store),
      );
      await tester.scrollUntilVisible(
        find.text('Mark complete'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mark complete'));
      await tester.pump();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Mark complete'), findsNothing);
      expect(StudyProgressStore(store).load().completed, <String>[
        'hand-rankings',
      ]);
    });

    testWidgets('"Next lesson" navigates and completes nothing', (
      tester,
    ) async {
      final store = KeyValueStore.memory();
      final router = await pumpStudyApp(
        tester,
        location: AllInRoutes.studyPath,
        overrides: studyOverrides(store: store),
      );
      await tester.tap(find.text('Continue: Hand Rankings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Next lesson'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Next lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Position & the Button'), findsOneWidget);
      expect(find.text('Hand Rankings'), findsNothing);
      // No stack growth: one pop lands back on the course, not on the
      // previous lesson (§6.2).
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Your progress'), findsOneWidget);
      expect(StudyProgressStore(store).load().completed, isEmpty);
    });

    testWidgets('the last lesson has no "Next lesson"', (tester) async {
      await pumpStudyApp(
        tester,
        location: AllInRoutes.lessonPath(kAllLessonIds.last),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pump();
      expect(find.text('Next lesson'), findsNothing);
      expect(find.text('Mark complete'), findsOneWidget);
    });
  });

  group('presentation', () {
    testWidgets('the push host shows a chevron', (tester) async {
      await pumpStudyApp(tester, location: AllInRoutes.lessonPath('position'));
      expect(find.byType(StudyBackChevron), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('the modal host shows "Done"', (tester) async {
      await pumpStudyApp(
        tester,
        location: AllInRoutes.lessonModalPath('position'),
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(StudyBackChevron), findsNothing);
    });
  });

  group('§14 unknown lesson id', () {
    testWidgets('lands on Study with the toast, never a 404', (tester) async {
      final router = await pumpStudyApp(
        tester,
        location: AllInRoutes.lessonPath('no-such-lesson'),
      );
      await tester.pump();
      await tester.pump();
      expect(locationOf(router), AllInRoutes.studyPath);
      expect(find.text(kUnknownLessonToast), findsOneWidget);
      AllInToast.dismiss();
      await tester.pump();
    });
  });

  group('{{term}} markup', () {
    test('every term used in a lesson exists in the glossary', () {
      final known = <String>{for (final t in kGlossary) t.key};
      final pattern = RegExp(r'\{\{([^}|]+)(?:\|([^}]*))?\}\}');
      final missing = <String>{};
      var used = 0;

      void scan(String text) {
        for (final m in pattern.allMatches(text)) {
          used++;
          final id = m.group(1)!;
          if (!known.contains(id)) missing.add(id);
        }
      }

      for (final lesson in kAllLessons) {
        for (final block in lesson.body) {
          switch (block) {
            case ParagraphBlock(:final text):
              scan(text);
            case HeadingBlock(:final text):
              scan(text);
            case BulletsBlock(:final items):
            case NumberedBlock(:final items):
              items.forEach(scan);
            case CalloutBlock(:final body):
              scan(body);
            case TableBlock(:final rows):
              for (final row in rows) {
                row.forEach(scan);
              }
            case RangeBlock(:final title, :final note):
              scan(title);
              if (note != null) scan(note);
            case QuizBlock(:final questions):
              for (final q in questions) {
                scan(q.prompt);
                q.options.forEach(scan);
                scan(q.explanation);
              }
            case WidgetBlock():
              break;
          }
        }
      }

      expect(missing, isEmpty);
      expect(used, greaterThan(0));
    });

    testWidgets('a term renders as a tappable popover', (tester) async {
      await pumpStudyApp(tester, location: AllInRoutes.lessonPath('position'));
      // The Position lesson's seat cards use {{UTG}}…{{BB}}.
      expect(find.textContaining('{{'), findsNothing);
      expect(find.byType(TermText), findsWidgets);
    });
  });
}
