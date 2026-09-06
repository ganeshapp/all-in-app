/// Study progress — a pure-Dart port of the desktop `src/store/studyStore.ts`
/// (Zustand store persisted in `localStorage`). No Flutter or Riverpod here:
/// a `StudyProgressNotifier` wraps this value class and a preferences service
/// persists the two JSON blobs under the same keys as the desktop.
///
/// Two independent persisted records:
///
/// | Key               | Value                                                     |
/// |-------------------|-----------------------------------------------------------|
/// | `allin.study.v1`  | JSON array of completed lesson ids, in completion order   |
/// | `allin.quiz.v1`   | JSON object `{ "<qKey>": {correct, wrong, lastCorrect, ts} }` |
///
/// Quiz keys are `hashSeed(question.prompt)` rendered as a decimal string
/// (see [StudyProgress.quizKey]); editing a question's wording orphans its
/// stored stats, exactly as on desktop.
library;

import 'dart:convert';

import 'package:collection/collection.dart';

import '../../../engine/prng.dart';
import 'curriculum.dart';
import 'lesson_model.dart';

/// Per-question quiz results (desktop `QuizStat`).
class QuizStat {
  const QuizStat({
    this.correct = 0,
    this.wrong = 0,
    this.lastCorrect = false,
    this.ts = 0,
  });

  /// Tolerant decode: missing or malformed fields fall back to the defaults.
  factory QuizStat.fromJson(Object? json) {
    if (json is! Map) return const QuizStat();
    return QuizStat(
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      lastCorrect: json['lastCorrect'] == true,
      ts: (json['ts'] as num?)?.toInt() ?? 0,
    );
  }

  /// Cumulative correct answers for this question.
  final int correct;

  /// Cumulative wrong answers.
  final int wrong;

  /// Outcome of the most recent answer.
  final bool lastCorrect;

  /// Unix epoch milliseconds of the most recent answer (0 = never answered).
  final int ts;

  Map<String, Object> toJson() => {
    'correct': correct,
    'wrong': wrong,
    'lastCorrect': lastCorrect,
    'ts': ts,
  };

  @override
  bool operator ==(Object other) =>
      other is QuizStat &&
      other.correct == correct &&
      other.wrong == wrong &&
      other.lastCorrect == lastCorrect &&
      other.ts == ts;

  @override
  int get hashCode => Object.hash(correct, wrong, lastCorrect, ts);

  @override
  String toString() =>
      'QuizStat(correct: $correct, wrong: $wrong, lastCorrect: $lastCorrect, ts: $ts)';
}

/// Immutable study progress. Mutators ([complete], [toggle], [recordQuiz])
/// return a new instance so the class can be used directly as notifier state.
class StudyProgress {
  const StudyProgress({this.completed = const [], this.quizResults = const {}});

  /// Decode the two persisted values (already parsed JSON). Anything that is
  /// not the expected shape falls back to empty, like the desktop `load()`.
  factory StudyProgress.fromJson(Object? completedJson, [Object? quizJson]) {
    final completed = <String>[
      if (completedJson is List)
        for (final id in completedJson)
          if (id is String) id,
    ];
    final quiz = <String, QuizStat>{
      if (quizJson is Map)
        for (final e in quizJson.entries)
          if (e.key is String) e.key as String: QuizStat.fromJson(e.value),
    };
    return StudyProgress(
      completed: List.unmodifiable(completed),
      quizResults: Map.unmodifiable(quiz),
    );
  }

  /// Decode the raw strings stored under [storageKey] / [quizStorageKey].
  /// Null, empty or unparsable input yields the defaults (`[]` / `{}`) —
  /// the desktop swallows parse errors the same way.
  factory StudyProgress.decode({String? completed, String? quiz}) {
    Object? parse(String? s, String fallback) {
      try {
        return jsonDecode(s == null || s.isEmpty ? fallback : s);
      } on FormatException {
        return jsonDecode(fallback);
      }
    }

    return StudyProgress.fromJson(parse(completed, '[]'), parse(quiz, '{}'));
  }

  /// Storage key for the completed-lesson list (desktop `allin.study.v1`).
  static const String storageKey = 'allin.study.v1';

  /// Storage key for the quiz results map (desktop `allin.quiz.v1`).
  static const String quizStorageKey = 'allin.quiz.v1';

  /// Completed lesson ids in insertion order. Never pruned by the UI: stale
  /// ids (renamed lessons) are harmless and simply inflate [completedCount],
  /// as on desktop.
  final List<String> completed;

  /// Per-question results keyed by [quizKey].
  final Map<String, QuizStat> quizResults;

  /// The persisted key for a quiz question: `String(hashSeed(q))`.
  static String quizKey(String prompt) => hashSeed(prompt).toString();

  bool isComplete(String lessonId) => completed.contains(lessonId);

  int get completedCount => completed.length;

  /// Number of lessons in the curriculum (31).
  int get total => kAllLessonIds.length;

  /// Desktop `pct = completed.length / ALL_LESSON_IDS.length * 100`. Not
  /// clamped here (the progress bar clamps to 0–100 when drawing).
  double get percent => completedCount / total * 100;

  /// How many of [level]'s lessons are complete (the `lvDone/n` counter).
  int completedInLevel(Level level) =>
      level.lessons.where((l) => completed.contains(l.id)).length;

  /// Idempotent: returns `this` when [lessonId] is already complete.
  StudyProgress complete(String lessonId) {
    if (completed.contains(lessonId)) return this;
    return StudyProgress(
      completed: List.unmodifiable([...completed, lessonId]),
      quizResults: quizResults,
    );
  }

  /// Remove [lessonId] if present, otherwise append it. Exists on desktop for
  /// future use; no UI calls it today.
  StudyProgress toggle(String lessonId) {
    final next =
        completed.contains(lessonId)
            ? completed.where((x) => x != lessonId).toList()
            : [...completed, lessonId];
    return StudyProgress(
      completed: List.unmodifiable(next),
      quizResults: quizResults,
    );
  }

  /// Record one answer to the question keyed by [qKey]. [nowMs] defaults to
  /// the wall clock (desktop `Date.now()`); inject it in tests.
  StudyProgress recordQuiz(String qKey, bool correct, {int? nowMs}) {
    final prev = quizResults[qKey] ?? const QuizStat();
    final stat = QuizStat(
      correct: prev.correct + (correct ? 1 : 0),
      wrong: prev.wrong + (correct ? 0 : 1),
      lastCorrect: correct,
      ts: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    return StudyProgress(
      completed: completed,
      quizResults: Map.unmodifiable({...quizResults, qKey: stat}),
    );
  }

  /// True when the question was answered before and the last attempt was
  /// wrong — such questions are surfaced first by the quiz widget.
  bool wasMissed(String qKey) {
    final s = quizResults[qKey];
    return s != null && !s.lastCorrect;
  }

  /// The value persisted under [storageKey]: a JSON array of lesson ids.
  List<String> toJson() => List.of(completed);

  /// The value persisted under [quizStorageKey].
  Map<String, Object> quizResultsToJson() => {
    for (final e in quizResults.entries) e.key: e.value.toJson(),
  };

  /// [toJson] as the string stored under [storageKey].
  String encodeCompleted() => jsonEncode(toJson());

  /// [quizResultsToJson] as the string stored under [quizStorageKey].
  String encodeQuizResults() => jsonEncode(quizResultsToJson());

  static const _listEq = ListEquality<String>();
  static const _mapEq = MapEquality<String, QuizStat>();

  @override
  bool operator ==(Object other) =>
      other is StudyProgress &&
      _listEq.equals(other.completed, completed) &&
      _mapEq.equals(other.quizResults, quizResults);

  @override
  int get hashCode =>
      Object.hash(_listEq.hash(completed), _mapEq.hash(quizResults));

  @override
  String toString() =>
      'StudyProgress(completed: $completed, quizResults: ${quizResults.length} keys)';
}
