/// The in-lesson quiz (DESIGN.md §6.4; docs/port/study-curriculum.md §4):
/// verbatim copy, scoring, persistence under `allin.quiz.v1`, missed-first
/// ordering and "Try again".
library;

import 'dart:math' as math;

import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/features/study/widgets/quiz_card.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/study_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const QuizQuestion _q1 = QuizQuestion(
  prompt: 'Alpha question?',
  options: <String>['Alpha wrong', 'Alpha right'],
  answer: 1,
  explanation: 'Because alpha.',
);

const QuizQuestion _q2 = QuizQuestion(
  prompt: 'Beta question?',
  options: <String>['Beta right', 'Beta wrong'],
  answer: 0,
  explanation: 'Because beta.',
);

/// A fixed permutation so option order is stable across runs.
math.Random _fixed() => math.Random(7);

void main() {
  testWidgets('renders the verbatim header copy', (tester) async {
    await pumpStudyWidget(
      tester,
      SingleChildScrollView(
        child: QuizCard(questions: const <QuizQuestion>[_q1], random: _fixed()),
      ),
    );
    expect(find.text(kQuizTitle), findsOneWidget);
    expect(find.text(kQuizOptionalPill.toUpperCase()), findsOneWidget);
    expect(find.textContaining(kQuizSubline), findsOneWidget);
    expect(find.text('1. Alpha question?'), findsOneWidget);
  });

  testWidgets('a correct pick shows "Correct." and records it', (tester) async {
    final store = KeyValueStore.memory();
    await pumpStudyWidget(
      tester,
      SingleChildScrollView(
        child: QuizCard(questions: const <QuizQuestion>[_q1], random: _fixed()),
      ),
      overrides: studyOverrides(store: store),
    );
    await tester.tap(find.text('Alpha right'));
    await tester.pump();
    expect(find.textContaining('Correct.'), findsOneWidget);
    expect(find.textContaining('Because alpha.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    final stat =
        StudyProgressStore(store).load().quizResults[StudyProgress.quizKey(
          _q1.prompt,
        )];
    expect(stat, isNotNull);
    expect(stat!.correct, 1);
    expect(stat.wrong, 0);
    expect(stat.lastCorrect, isTrue);
  });

  testWidgets('a wrong pick shows "Not quite." and "Try again"', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await pumpStudyWidget(
      tester,
      SingleChildScrollView(
        child: QuizCard(questions: const <QuizQuestion>[_q1], random: _fixed()),
      ),
      overrides: studyOverrides(store: store),
    );
    await tester.tap(find.text('Alpha wrong'));
    await tester.pump();
    expect(find.textContaining('Not quite.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    final key = StudyProgress.quizKey(_q1.prompt);
    expect(StudyProgressStore(store).load().quizResults[key]!.wrong, 1);
    expect(
      StudyProgressStore(store).load().quizResults[key]!.lastCorrect,
      isFalse,
    );

    // Try again re-enables the options; the wrong attempt stays recorded.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Try again'), findsNothing);
    expect(find.textContaining('Not quite.'), findsNothing);

    await tester.tap(find.text('Alpha right'));
    await tester.pump();
    expect(find.textContaining('Correct.'), findsOneWidget);
    final after = StudyProgressStore(store).load().quizResults[key]!;
    expect(after.wrong, 1);
    expect(after.correct, 1);
    expect(after.lastCorrect, isTrue);
  });

  testWidgets('missed questions come first and are announced', (tester) async {
    final store = KeyValueStore.memory();
    // Beta was answered wrong last time.
    store.setJson(StudyProgress.quizStorageKey, <String, Object>{
      StudyProgress.quizKey(_q2.prompt): const QuizStat(wrong: 1).toJson(),
    });

    await pumpStudyWidget(
      tester,
      SingleChildScrollView(
        child: QuizCard(
          questions: const <QuizQuestion>[_q1, _q2],
          random: _fixed(),
        ),
      ),
      overrides: studyOverrides(store: store),
    );
    expect(find.text('1. Beta question?'), findsOneWidget);
    expect(find.text('2. Alpha question?'), findsOneWidget);
    expect(find.textContaining(quizMissedLine(1)), findsOneWidget);
  });

  testWidgets('the quiz never gates completion', (tester) async {
    final store = KeyValueStore.memory();
    await pumpStudyWidget(
      tester,
      SingleChildScrollView(
        child: QuizCard(questions: const <QuizQuestion>[_q1], random: _fixed()),
      ),
      overrides: studyOverrides(store: store),
    );
    await tester.tap(find.text('Alpha wrong'));
    await tester.pump();
    expect(StudyProgressStore(store).load().completed, isEmpty);
  });
}
