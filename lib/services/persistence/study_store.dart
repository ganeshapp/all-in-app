/// Study progress and quiz results (docs/port/persistence-stats-settings.md
/// §6.5; DESIGN.md §6 Study).
///
/// Two keys — `allin.study.v1` (array of completed lesson ids) and
/// `allin.quiz.v1` (`{ "<qKey>": {correct, wrong, lastCorrect, ts} }`) — whose
/// shapes and key derivation already live in the ported curriculum's
/// [StudyProgress]. This store is only the storage adapter for it, so the
/// quiz key stays `String(hashSeed(prompt))` and desktop data keeps working.
library;

import '../../features/study/content/study_progress.dart';
import 'key_value_store.dart';

export '../../features/study/content/study_progress.dart'
    show QuizStat, StudyProgress;

class StudyProgressStore {
  StudyProgressStore(this._store);

  /// Storage key for the completed-lesson list.
  static const String completedKey = StudyProgress.storageKey;

  /// Storage key for the quiz results map.
  static const String quizKey = StudyProgress.quizStorageKey;

  final KeyValueStore _store;

  StudyProgress load() => StudyProgress.fromJson(
    _store.getJson(completedKey),
    _store.getJson(quizKey),
  );

  /// Writes both keys (the desktop writes each one as it changes; writing
  /// both is idempotent and keeps the caller from having to know which
  /// mutation touched which key).
  Future<bool> save(StudyProgress progress) async {
    final a = await _store.setJson(completedKey, progress.toJson());
    final b = await _store.setJson(quizKey, progress.quizResultsToJson());
    return a && b;
  }

  Future<StudyProgress> complete(String lessonId) =>
      _mutate((p) => p.complete(lessonId));

  Future<StudyProgress> toggle(String lessonId) =>
      _mutate((p) => p.toggle(lessonId));

  /// Records one answer. [qKey] is [StudyProgress.quizKey] of the prompt.
  Future<StudyProgress> recordQuiz(String qKey, bool correct, {int? nowMs}) =>
      _mutate((p) => p.recordQuiz(qKey, correct, nowMs: nowMs));

  Future<StudyProgress> _mutate(
    StudyProgress Function(StudyProgress) change,
  ) async {
    final next = change(load());
    await save(next);
    return next;
  }
}
