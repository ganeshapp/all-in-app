/// Structural tests for the ported Study curriculum data
/// (`lib/features/study/content/`).
///
/// The desktop `src/components/study/lessons.tsx` is the source of truth: the
/// lesson id order below is `ALL_LESSON_IDS` extracted from it verbatim, and
/// the titles/minutes table mirrors `LEVELS`. Ids are a public contract (drills
/// deep-link by `lessonId`, progress is persisted by id), so any accidental
/// rename, reorder or dropped lesson fails here.
library;

import 'package:allin/data/preflop_charts.g.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/content/glossary.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Desktop `ALL_LESSON_IDS` (lessons.tsx), in order.
const List<String> kDesktopLessonIds = [
  'hand-rankings',
  'position',
  'bankroll',
  'matrix',
  'opening-ranges',
  'three-betting',
  'hud-reading',
  'board-texture',
  'counting-outs',
  'estimating-equity',
  'pot-odds',
  'implied-odds',
  'bet-sizing',
  'cbetting',
  'mdf',
  'check-raising',
  'combinatorics',
  'hand-reading',
  'exploits',
  'multiway',
  'spr',
  'threebet-pots',
  'equity-realization',
  'turn-river',
  'synthesis',
  'cheat-sheet',
  'range-explorer',
  'equity-calculator',
  'drill-potodds',
  'drill-outs',
  'drill-range',
];

/// Desktop `Level` ids/titles/icons, in order.
const List<(String, String, String)> kDesktopLevels = [
  ('basics', 'Basics', 'book'),
  ('preflop', 'Pre-flop', 'cards'),
  ('postflop', 'Post-flop', 'target'),
  ('advanced', 'Advanced', 'bolt'),
  ('practice', 'Practice', 'target'),
];

/// Desktop `Lesson.title` / `Lesson.minutes`, keyed by lesson id.
const Map<String, (String, int)> kDesktopLessonMeta = {
  'hand-rankings': ('Hand Rankings', 4),
  'position': ('Position & the Button', 5),
  'bankroll': ('Bankroll & Mindset', 4),
  'matrix': ('The 13×13 Matrix', 5),
  'opening-ranges': ('Opening Ranges by Position', 6),
  'three-betting': ('3-Betting', 5),
  'hud-reading': ('Reading the HUD: VPIP & PFR', 5),
  'board-texture': ('Reading Board Texture', 5),
  'counting-outs': ('Counting Outs & the 2/4 Rule', 5),
  'estimating-equity': ('Estimating Equity', 5),
  'pot-odds': ('Pot Odds, Break-even & EV', 6),
  'implied-odds': ('Implied & Reverse-Implied Odds', 5),
  'bet-sizing': ('Bet Sizing', 6),
  'cbetting': ('Continuation Betting', 4),
  'mdf': ('Minimum Defense Frequency', 5),
  'check-raising': ('Check-Raising', 5),
  'combinatorics': ('Combinatorics & Blockers', 6),
  'hand-reading': ('Hand Reading: Narrowing a Range', 7),
  'exploits': ('Exploiting the Archetypes', 6),
  'multiway': ('Playing Multiway', 6),
  'spr': ('SPR & Commitment', 5),
  'threebet-pots': ('Playing 3-Bet Pots', 6),
  'equity-realization': ('Equity Realization', 5),
  'turn-river': ('Turn & River Play', 6),
  'synthesis': ('Putting It Together', 3),
  'cheat-sheet': ('Quick Reference', 4),
  'range-explorer': ('Range Explorer', 5),
  'equity-calculator': ('Equity Calculator', 5),
  'drill-potodds': ('Pot-Odds Drill', 5),
  'drill-outs': ('Outs → Equity Drill', 5),
  'drill-range': ('Range-Building Drill', 6),
};

/// Every user-visible string a block carries (used for markup checks).
List<String> blockStrings(LessonBlock b) => switch (b) {
  HeadingBlock(:final text) => [text],
  ParagraphBlock(:final text) => [text],
  BulletsBlock(:final items) => items,
  NumberedBlock(:final items) => items,
  CalloutBlock(:final title, :final body) => [if (title != null) title, body],
  TableBlock(:final header, :final rows, :final caption) => [
    ...header,
    for (final r in rows) ...r,
    if (caption != null) caption,
  ],
  RangeBlock(:final title, :final labels, :final note) => [
    title,
    ...?labels,
    if (note != null) note,
  ],
  WidgetBlock() => const [],
  QuizBlock(:final questions) => [
    for (final q in questions) ...[q.prompt, ...q.options, q.explanation],
  ],
};

/// `{{key}}` / `{{key|display text}}` glossary references.
final RegExp _termRe = RegExp(r'\{\{([^}|]+)(?:\|([^}]*))?\}\}');

void main() {
  group('curriculum shape', () {
    test('has exactly 5 levels and 31 lessons', () {
      expect(kLevels, hasLength(5));
      expect(kAllLessons, hasLength(31));
      expect(kAllLessonIds, hasLength(31));
    });

    test('level ids, titles and icons match the desktop LEVELS', () {
      expect(
        kLevels.map((l) => (l.id, l.title, l.icon)).toList(),
        kDesktopLevels,
      );
      for (final level in kLevels) {
        expect(kLevelIconNames, contains(level.icon));
        expect(kLevelBlurbs, contains(level.id));
        expect(kLevelBlurbs[level.id], isNotEmpty);
        expect(level.lessons, isNotEmpty);
      }
    });

    test('lesson id order equals the desktop ALL_LESSON_IDS', () {
      expect(kAllLessonIds, kDesktopLessonIds);
    });

    test('lesson ids are unique', () {
      expect(kAllLessonIds.toSet(), hasLength(kAllLessonIds.length));
    });

    test('every lesson has the desktop title/minutes and a non-empty body', () {
      for (final lesson in kAllLessons) {
        final meta = kDesktopLessonMeta[lesson.id];
        expect(meta, isNotNull, reason: 'unknown lesson ${lesson.id}');
        expect(lesson.title, meta!.$1, reason: lesson.id);
        expect(lesson.minutes, meta.$2, reason: lesson.id);
        expect(lesson.minutes, greaterThan(0), reason: lesson.id);
        expect(lesson.body, isNotEmpty, reason: lesson.id);
      }
    });

    test('every lesson opens with the desktop Lead paragraph', () {
      for (final lesson in kAllLessons) {
        expect(
          lesson.body.first,
          isA<ParagraphBlock>(),
          reason: '${lesson.id}: first block should be the Lead paragraph',
        );
      }
    });

    test('no block carries an empty string', () {
      for (final lesson in kAllLessons) {
        for (final block in lesson.body) {
          // Stat-row tables deliberately use an all-empty header, which the
          // reader skips; every other string must carry content.
          final strings =
              block is TableBlock
                  ? [
                    for (final r in block.rows) ...r,
                    if (block.caption != null) block.caption!,
                  ]
                  : blockStrings(block);
          for (final s in strings) {
            expect(
              s.trim(),
              isNotEmpty,
              reason: '${lesson.id}: empty string in ${block.runtimeType}',
            );
          }
        }
      }
    });
  });

  group('quizzes', () {
    test('answers index into options and explanations are non-empty', () {
      var questions = 0;
      for (final lesson in kAllLessons) {
        for (final block in lesson.body.whereType<QuizBlock>()) {
          expect(block.questions, isNotEmpty, reason: lesson.id);
          for (final q in block.questions) {
            questions++;
            final where = '${lesson.id}: "${q.prompt}"';
            expect(q.prompt.trim(), isNotEmpty, reason: where);
            expect(
              q.options.length,
              greaterThanOrEqualTo(2),
              reason: '$where needs at least two options',
            );
            expect(q.answer, greaterThanOrEqualTo(0), reason: where);
            expect(q.answer, lessThan(q.options.length), reason: where);
            expect(q.explanation.trim(), isNotEmpty, reason: where);
            expect(
              q.options.map((o) => o.trim()).toSet(),
              hasLength(q.options.length),
              reason: '$where has duplicate options',
            );
          }
        }
      }
      // The desktop lessons.tsx ships 34 quiz questions across 13 lessons.
      expect(questions, 34);
    });
  });

  group('inline markup', () {
    test('every {{term}} key exists in kGlossary', () {
      final used = <String>{};
      for (final lesson in kAllLessons) {
        for (final block in lesson.body) {
          for (final s in blockStrings(block)) {
            for (final m in _termRe.allMatches(s)) {
              final key = m.group(1)!;
              used.add(key);
              expect(
                glossaryTerm(key),
                isNotNull,
                reason: '${lesson.id}: unknown glossary key "$key"',
              );
              final display = m.group(2);
              if (display != null) {
                expect(
                  display.trim(),
                  isNotEmpty,
                  reason: '${lesson.id}: empty display text for "$key"',
                );
              }
            }
          }
        }
      }
      expect(used, isNotEmpty);
    });

    test('glossary keys and terms are unique and non-empty', () {
      expect(kGlossary, hasLength(25));
      expect(kGlossary.map((t) => t.key).toSet(), hasLength(kGlossary.length));
      for (final t in kGlossary) {
        expect(t.key.trim(), isNotEmpty);
        expect(t.term.trim(), isNotEmpty);
        expect(t.definition.trim(), isNotEmpty);
        expect(glossaryTerm(t.key), same(t));
      }
      expect(glossaryTerm('not-a-term'), isNull);
    });
  });

  group('blocks', () {
    test('every RangeBlock has exactly one of labels/topPct/chart', () {
      var ranges = 0;
      for (final lesson in kAllLessons) {
        for (final block in lesson.body.whereType<RangeBlock>()) {
          ranges++;
          final set =
              [
                block.labels != null,
                block.topPct != null,
                block.chart != null,
              ].where((x) => x).length;
          expect(
            set,
            1,
            reason:
                '${lesson.id}: RangeBlock "${block.title}" must set exactly '
                'one of labels/topPct/chart',
          );
          expect(block.title.trim(), isNotEmpty, reason: lesson.id);
          if (block.topPct != null) {
            expect(block.topPct, inInclusiveRange(1, 100), reason: lesson.id);
          }
          if (block.labels != null) {
            expect(block.labels, isNotEmpty, reason: lesson.id);
          }
        }
      }
      // matrix (1) + opening-ranges (2) + three-betting (1) + hand-reading (3).
      expect(ranges, 7);
    });

    test('every RangeBlock chart reference resolves to a real chart', () {
      for (final lesson in kAllLessons) {
        for (final block in lesson.body.whereType<RangeBlock>()) {
          final chart = block.chart;
          if (chart == null) continue;
          final parts = chart.split(':');
          final where = '${lesson.id}: chart "$chart"';
          switch (parts.first) {
            case 'rfi':
              expect(parts, hasLength(2), reason: where);
              expect(kRfi100[parts[1]], isNotNull, reason: where);
              expect(kRfi100[parts[1]], isNotEmpty, reason: where);
            case 'vsRfi':
              expect(parts, hasLength(3), reason: where);
              expect(kVsRfi100[parts[1]]?[parts[2]], isNotNull, reason: where);
              expect(kVsRfi100[parts[1]]?[parts[2]], isNotEmpty, reason: where);
            default:
              fail('$where has an unknown chart family "${parts.first}"');
          }
        }
      }
    });

    test('table rows all have the header width', () {
      for (final lesson in kAllLessons) {
        for (final block in lesson.body.whereType<TableBlock>()) {
          expect(block.header, isNotEmpty, reason: lesson.id);
          expect(block.rows, isNotEmpty, reason: lesson.id);
          for (final row in block.rows) {
            expect(
              row,
              hasLength(block.header.length),
              reason: '${lesson.id}: ragged table row $row',
            );
          }
        }
      }
    });

    test('interactive lessons embed their desktop widget', () {
      const expected = {
        'hand-rankings': LessonWidgetKind.handRankings,
        'pot-odds': LessonWidgetKind.potOddsCalculator,
        'bet-sizing': LessonWidgetKind.bluffCalculator,
        'multiway': LessonWidgetKind.multiwayEquityTrainer,
        'range-explorer': LessonWidgetKind.rangeExplorer,
        'equity-calculator': LessonWidgetKind.equityCalculator,
        'drill-potodds': LessonWidgetKind.drillPotOdds,
        'drill-outs': LessonWidgetKind.drillOuts,
        'drill-range': LessonWidgetKind.drillRange,
      };
      expected.forEach((id, kind) {
        final lesson = lessonById(id);
        expect(lesson, isNotNull, reason: id);
        expect(
          lesson!.body.whereType<WidgetBlock>().map((w) => w.kind),
          contains(kind),
          reason: id,
        );
      });
    });
  });

  group('lookup helpers', () {
    test('lessonById finds every lesson and rejects unknown ids', () {
      for (final id in kAllLessonIds) {
        expect(lessonById(id)?.id, id);
      }
      expect(lessonById('nope'), isNull);
      expect(lessonById(''), isNull);
    });

    test('levelById / levelForLesson / lessonIndex agree', () {
      for (final level in kLevels) {
        expect(levelById(level.id), same(level));
        for (final lesson in level.lessons) {
          expect(levelForLesson(lesson.id), same(level));
        }
      }
      expect(levelById('nope'), isNull);
      expect(levelForLesson('nope'), isNull);
      for (var i = 0; i < kAllLessonIds.length; i++) {
        expect(lessonIndex(kAllLessonIds[i]), i);
      }
      expect(lessonIndex('nope'), -1);
    });

    test('nextLessonId walks the flat order and stops at the end', () {
      for (var i = 0; i < kAllLessonIds.length - 1; i++) {
        expect(nextLessonId(kAllLessonIds[i]), kAllLessonIds[i + 1]);
      }
      expect(nextLessonId(kAllLessonIds.last), isNull);
      expect(nextLessonId('nope'), isNull);
    });

    test('kFirstLessonId and resolveLesson fall back to the first lesson', () {
      expect(kFirstLessonId, 'hand-rankings');
      final resolved = resolveLesson('mdf');
      expect(resolved.lesson.id, 'mdf');
      expect(resolved.level.id, 'postflop');
      final fallback = resolveLesson('nope');
      expect(fallback.lesson.id, kFirstLessonId);
      expect(fallback.level.id, kLevels.first.id);
    });
  });
}
