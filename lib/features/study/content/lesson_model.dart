/// Content model for the Study curriculum (5 levels / 31 lessons), ported from
/// the desktop `src/components/study/lessons.tsx`. Lessons are DATA: a list of
/// blocks the lesson reader renders. Keeping content out of widgets lets it be
/// tested (ids, quiz answers, glossary links) and reused (search, deep links).
///
/// Inline markup inside block strings (parsed by the reader):
///   **bold**   *italic*   `code`   {{term}}  → glossary term (key must exist in [kGlossary])
///   {{term|display text}} → glossary term shown with different text
library;

sealed class LessonBlock {
  const LessonBlock();
}

/// Section heading inside a lesson (level 2 or 3).
class HeadingBlock extends LessonBlock {
  const HeadingBlock(this.text, {this.level = 2});
  final String text;
  final int level;
}

class ParagraphBlock extends LessonBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class BulletsBlock extends LessonBlock {
  const BulletsBlock(this.items);
  final List<String> items;
}

class NumberedBlock extends LessonBlock {
  const NumberedBlock(this.items);
  final List<String> items;
}

enum CalloutKind { tip, warning, math, example, key }

/// A highlighted box ("Key idea", "Show me the math", worked example…).
class CalloutBlock extends LessonBlock {
  const CalloutBlock({required this.kind, this.title, required this.body});
  final CalloutKind kind;
  final String? title;
  final String body;
}

class TableBlock extends LessonBlock {
  const TableBlock({required this.header, required this.rows, this.caption});
  final List<String> header;
  final List<List<String>> rows;
  final String? caption;
}

/// A 13×13 range matrix illustration. Exactly one of [labels], [topPct] or
/// [chart] is set; [chart] names a chart in lib/data (e.g. 'rfi:UTG',
/// 'vsRfi:BB_vs_BTN:call').
class RangeBlock extends LessonBlock {
  const RangeBlock({
    required this.title,
    this.labels,
    this.topPct,
    this.chart,
    this.note,
  });
  final String title;
  final List<String>? labels;
  final int? topPct;
  final String? chart;
  final String? note;
}

/// Interactive widgets embedded in lessons; the reader maps each kind to a Flutter widget.
enum LessonWidgetKind {
  handRankings,
  potOddsCalculator,
  bluffCalculator,
  multiwayEquityTrainer,
  rangeExplorer,
  equityCalculator,
  rangeBoardBreakdown,
  drillPotOdds,
  drillOuts,
  drillRange,
  cheatSheet,
}

class WidgetBlock extends LessonBlock {
  const WidgetBlock(this.kind, {this.params = const {}});
  final LessonWidgetKind kind;
  final Map<String, Object> params;
}

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explanation,
  });
  final String prompt;
  final List<String> options;

  /// Index into [options].
  final int answer;
  final String explanation;
}

class QuizBlock extends LessonBlock {
  const QuizBlock(this.questions);
  final List<QuizQuestion> questions;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.minutes,
    required this.body,
  });

  /// Public contract: ids are referenced by drills (lessonId) and deep links.
  final String id;
  final String title;
  final int minutes;
  final List<LessonBlock> body;
}

class Level {
  const Level({
    required this.id,
    required this.title,
    required this.icon,
    required this.lessons,
  });
  final String id;
  final String title;

  /// Icon name from the desktop set (mapped to a Flutter icon by the UI).
  final String icon;
  final List<Lesson> lessons;
}

class GlossaryTerm {
  const GlossaryTerm({
    required this.key,
    required this.term,
    required this.definition,
  });
  final String key;
  final String term;
  final String definition;
}
