/// The Study curriculum: 5 levels / 31 lessons, ported from the desktop
/// `src/components/study/lessons.tsx` (`LEVELS`, `ALL_LESSON_IDS`) plus the
/// lesson-lookup helpers `StudyView.tsx` derives from them.
///
/// Lesson ids are a public contract — drills deep-link by `lessonId`, the
/// onboarding placement picks `hand-rankings` / `pot-odds` / `threebet-pots`,
/// and progress is persisted by id. Never rename them.
library;

import 'lesson_model.dart';
import 'level1_basics.dart';
import 'level2_preflop.dart';
import 'level3_postflop.dart';
import 'level4_advanced.dart';
import 'level5_practice.dart';

/// All levels in curriculum order (desktop `LEVELS`).
const List<Level> kLevels = [
  kLevel1,
  kLevel2Preflop,
  kLevel3Postflop,
  kLevel4Advanced,
  kLevel5Practice,
];

/// Desktop `Level.blurb`, keyed by level id. Not rendered anywhere on desktop
/// (kept for parity); the mobile level list may use them as subtitles.
const Map<String, String> kLevelBlurbs = {
  'basics': 'Rules, rankings, position and bankroll.',
  'preflop': 'The 13×13 matrix and opening ranges.',
  'postflop': 'Board texture, pot odds and c-betting.',
  'advanced': 'Combinatorics, blockers and exploits.',
  'practice': 'Hands-on drills and a range explorer.',
};

/// The desktop icon names a [Level.icon] may take (`IconName` subset used by
/// the curriculum). The UI maps each to a Flutter icon.
const Set<String> kLevelIconNames = {'book', 'cards', 'target', 'bolt'};

final List<Lesson> _allLessons = List.unmodifiable([
  for (final level in kLevels) ...level.lessons,
]);

final List<String> _allLessonIds = List.unmodifiable([
  for (final lesson in _allLessons) lesson.id,
]);

/// Every lesson in reading order.
List<Lesson> get kAllLessons => _allLessons;

/// Flat ordering of lesson ids (desktop `ALL_LESSON_IDS`): drives "Next
/// lesson", the `n/31` progress fraction and deep-link validation. Length 31.
List<String> get kAllLessonIds => _allLessonIds;

/// The lesson the Study tab opens on (`LEVELS[0].lessons[0].id`).
String get kFirstLessonId => kLevels.first.lessons.first.id;

/// The lesson with [id], or null when unknown.
Lesson? lessonById(String id) {
  for (final lesson in _allLessons) {
    if (lesson.id == id) return lesson;
  }
  return null;
}

/// The level with [id], or null when unknown.
Level? levelById(String id) {
  for (final level in kLevels) {
    if (level.id == id) return level;
  }
  return null;
}

/// The level containing lesson [lessonId], or null when unknown.
Level? levelForLesson(String lessonId) {
  for (final level in kLevels) {
    for (final lesson in level.lessons) {
      if (lesson.id == lessonId) return level;
    }
  }
  return null;
}

/// Position of [lessonId] in [kAllLessonIds], or -1 when unknown.
int lessonIndex(String lessonId) => _allLessonIds.indexOf(lessonId);

/// The id that follows [lessonId] in reading order; null after the last
/// lesson or for an unknown id (desktop `ALL_LESSON_IDS[idx + 1]`).
String? nextLessonId(String lessonId) {
  final idx = lessonIndex(lessonId);
  if (idx < 0 || idx + 1 >= _allLessonIds.length) return null;
  return _allLessonIds[idx + 1];
}

/// The lesson and its level for [lessonId], falling back to the first
/// lesson of the first level when the id is unknown — the same fallback
/// `StudyView` applies to a stale `activeId`.
({Lesson lesson, Level level}) resolveLesson(String lessonId) {
  for (final level in kLevels) {
    for (final lesson in level.lessons) {
      if (lesson.id == lessonId) return (lesson: lesson, level: level);
    }
  }
  return (lesson: kLevels.first.lessons.first, level: kLevels.first);
}
