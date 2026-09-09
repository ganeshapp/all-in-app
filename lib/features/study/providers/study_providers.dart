/// Riverpod layer for the Study tab (DESIGN.md §6, docs/port/study-curriculum
/// §3): the persisted [StudyProgress] over [StudyProgressStore], the derived
/// "Continue" lesson, the equity service the §6.5 calculators run on and the
/// haptics instance every study control uses.
///
/// The engine and the curriculum stay pure: nothing here mutates a [Lesson],
/// and every mutation returns a fresh [StudyProgress].
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence/study_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drills/providers/drill_provider.dart'
    show drillScoreboardProvider;

/// Storage adapter for `allin.study.v1` / `allin.quiz.v1`.
final studyProgressStoreProvider = Provider<StudyProgressStore>(
  (ref) => StudyProgressStore(ref.watch(keyValueStoreProvider)),
);

/// Completed lesson ids + per-question quiz stats. Writes are fire-and-forget
/// (the desktop swallows save errors too, §3), so the UI never waits on disk.
class StudyProgressNotifier extends Notifier<StudyProgress> {
  @override
  StudyProgress build() => ref.read(studyProgressStoreProvider).load();

  StudyProgressStore get _store => ref.read(studyProgressStoreProvider);

  /// Idempotent "Mark complete" (§6.2). Returns immediately; the write lands
  /// after.
  Future<void> complete(String lessonId) => _apply(state.complete(lessonId));

  /// Present on desktop for future use; no UI calls it (§3).
  Future<void> toggle(String lessonId) => _apply(state.toggle(lessonId));

  /// One quiz answer. [qKey] is [StudyProgress.quizKey] of the prompt.
  Future<void> recordQuiz(String qKey, bool correct, {int? nowMs}) =>
      _apply(state.recordQuiz(qKey, correct, nowMs: nowMs));

  Future<void> _apply(StudyProgress next) async {
    if (next == state) return;
    state = next;
    await _store.save(next);
  }
}

final studyProgressProvider =
    NotifierProvider<StudyProgressNotifier, StudyProgress>(
      StudyProgressNotifier.new,
    );

/// "{n}/31" for the S0 header and the S1 top bar.
final studyCompletedCountProvider = Provider<int>(
  (ref) => ref.watch(studyProgressProvider.select((p) => p.completed.length)),
);

/// The lesson the placement test suggested, recovered from the rating it
/// seeded (the bands of `PlacementResult.forScore`: 900 · 1050 · 1250). The
/// suggestion itself is not persisted, and re-deriving it here is cheaper than
/// a new store — on any other rating this returns null.
String? placementLessonForRating(double rating) => switch (rating) {
  900 => 'hand-rankings',
  1050 => 'pot-odds',
  1250 => 'threebet-pots',
  _ => null,
};

/// **The one "what do I read next?" rule.** Home's "Next up" card (§3.2 card 3)
/// and Study's Continue card (§6.1) both read this provider, so the two can
/// never name different lessons — they used to, because Home applied §3.2's
/// placement clause and Study only ever took the first incomplete lesson.
///
/// §3.2 is the rule of record and it is what both screens now follow: the
/// placement result's suggestion while nothing has been completed yet ("on the
/// first day"), otherwise **the first incomplete lesson in path order**. §6.1's
/// wireframe caption says only "first incomplete in path order"; it describes
/// the ordinary case and says nothing about placement, so it is not in
/// conflict — and a learner who has just been told "start with 3-Betting"
/// should find that lesson under Continue on both screens.
///
/// Null when the whole course is done (§14: "Course complete — revisit any
/// lesson").
final studyContinueLessonProvider = Provider<Lesson?>((ref) {
  final completed = ref.watch(
    studyProgressProvider.select((p) => p.completed.toSet()),
  );

  if (completed.isEmpty) {
    final rating = ref.watch(drillScoreboardProvider.select((s) => s.rating));
    final suggested = placementLessonForRating(rating);
    if (suggested != null) {
      final lesson = lessonById(suggested);
      if (lesson != null) return lesson;
    }
  }

  for (final lesson in kAllLessons) {
    if (!completed.contains(lesson.id)) return lesson;
  }
  return null;
});

/// The lesson S0 tints gold — the one being read, or the last one opened
/// (§6.1). Session-lived on purpose: it is a "where was I" affordance, not
/// progress, and the persisted "where was I" is the Continue card.
class StudyLastReadNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String lessonId) => state = lessonId;
}

final studyLastReadProvider = NotifierProvider<StudyLastReadNotifier, String?>(
  StudyLastReadNotifier.new,
);

/// The isolate-backed equity service behind the §6.5 calculators. Study owns
/// its own instance so a lesson calculation never cancels a coach verdict;
/// hoist it to `app_providers.dart` when Play needs one too.
final studyEquityServiceProvider = Provider<EquityService>((ref) {
  final service = EquityService();
  ref.onDispose(service.dispose);
  return service;
});

/// Haptics gated by Settings → Haptics (§9, §11).
final studyHapticsProvider = Provider<Haptics>((ref) {
  final haptics = Haptics(enabled: ref.watch(hapticsEnabledProvider));
  return haptics;
});

/// The title S6 opens with ("Your range" / "Opponent's range", §6.5). The
/// router builds `RangeEditorScreen` from `state.extra` alone, so the pusher
/// parks the title here first. See the note in the feature report: once
/// `router.dart` forwards a title this provider can go.
class RangeEditorTitleNotifier extends Notifier<String> {
  @override
  String build() => 'Your range';

  void set(String title) => state = title;
}

final rangeEditorTitleProvider =
    NotifierProvider<RangeEditorTitleNotifier, String>(
      RangeEditorTitleNotifier.new,
    );
