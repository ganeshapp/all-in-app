/// S0's parts (DESIGN.md §6.1): the progress header, the Continue card, the
/// two-column tools grid, the pinned Quick-reference row, and the sticky level
/// header with its 52 pt lesson rows.
///
/// The tools grid is the one piece with real layout arithmetic in it: two
/// columns whose tile is solved from the text scale, and a single column above
/// 1.5× — because a tool whose name is truncated is a tool nobody opens
/// (§6.1).
///
/// **Deviation from §6.1's "icon 20 + label Inter 15 on ONE line", 56 tall.**
/// Six labels alone ("Bluff calc", "Multiway", "Range explorer") tell a
/// first-week player nothing about what the six screens behind them do, and
/// nothing else on S0 explains them — the reader has to open all six to find
/// the one they wanted. Each tile now carries a one-sentence gloss under its
/// label and the tile is sized for it. §6.1's *rationale* is untouched: its
/// whole argument is that two columns exist so the **label** never truncates,
/// and the label still owns its own line at every width and scale.
library;

import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// One tile of the §6.1 TOOLS grid.
class StudyTool {
  const StudyTool({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
    required this.lessonId,
    required this.kind,
  });

  /// The `:tool` path segment (`range-explorer`, `equity`, …).
  final String id;
  final String label;

  /// One plain-English line saying what the tool answers (TONE.md): no term
  /// here is one the tool itself is supposed to teach.
  final String subtitle;
  final IconData icon;

  /// The lesson S3 borrows its intro paragraph from, and the target of the
  /// tool screen's "Open lesson ›".
  final String lessonId;

  /// The widget S3 renders at full width — the same one the lesson embeds.
  final LessonWidgetKind kind;
}

/// The six tools, in wireframe order (§6.1, §6.6).
const List<StudyTool> kStudyTools = <StudyTool>[
  StudyTool(
    id: 'range-explorer',
    label: 'Range explorer',
    subtitle: 'See every hand a range holds',
    icon: Icons.grid_view_rounded,
    lessonId: 'range-explorer',
    kind: LessonWidgetKind.rangeExplorer,
  ),
  StudyTool(
    id: 'equity',
    label: 'Equity calc',
    subtitle: 'How often one hand beats another',
    icon: Icons.pie_chart_outline_rounded,
    lessonId: 'equity-calculator',
    kind: LessonWidgetKind.equityCalculator,
  ),
  StudyTool(
    id: 'pot-odds',
    label: 'Pot odds',
    subtitle: 'Is this call worth the price?',
    icon: Icons.percent_rounded,
    lessonId: 'pot-odds',
    kind: LessonWidgetKind.potOddsCalculator,
  ),
  StudyTool(
    id: 'bluff',
    label: 'Bluff calc',
    subtitle: 'How often a bluff has to work',
    icon: Icons.auto_awesome_rounded,
    lessonId: 'bet-sizing',
    kind: LessonWidgetKind.bluffCalculator,
  ),
  StudyTool(
    id: 'multiway',
    label: 'Multiway',
    subtitle: 'Your chances against 3 or more',
    icon: Icons.groups_rounded,
    lessonId: 'multiway',
    kind: LessonWidgetKind.multiwayEquityTrainer,
  ),
  StudyTool(
    id: 'rankings',
    label: 'Hand rankings',
    subtitle: 'What beats what',
    icon: Icons.style_rounded,
    lessonId: 'hand-rankings',
    kind: LessonWidgetKind.handRankings,
  ),
];

/// The tool with [id], or null.
StudyTool? studyToolById(String id) {
  for (final tool in kStudyTools) {
    if (tool.id == id) return tool;
  }
  return null;
}

/// "Your progress · 7/31" over a 4 pt gold bar (§6.1).
class StudyProgressHeader extends StatelessWidget {
  const StudyProgressHeader({
    super.key,
    required this.completed,
    required this.total,
    this.reducedMotion = false,
  });

  final int completed;
  final int total;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Your progress',
                style: AllInText.body(14, color: c.textMuted),
              ),
            ),
            Text(
              '$completed/$total',
              style: AllInText.mono(14, weight: FontWeight.w600, color: c.text),
            ),
          ],
        ),
        const SizedBox(height: AllInSpace.sm),
        ProgressBarThin(
          value: total == 0 ? 0 : completed / total,
          semanticLabel: '$completed of $total lessons complete',
          reducedMotion: reducedMotion,
        ),
      ],
    );
  }
}

/// The 72 pt "Continue" card, or the §14 course-complete state.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.lesson,
    required this.levelTitle,
    required this.onTap,
  });

  /// Null when every lesson is complete.
  final Lesson? lesson;
  final String? levelTitle;
  final VoidCallback onTap;

  /// §14: "Study | all 31 complete".
  static const String completeTitle = 'Course complete — revisit any lesson';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = lesson;
    return AllInCard(
      variant: AllInCardVariant.gold,
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.lg,
        vertical: AllInSpace.md,
      ),
      onTap: onTap,
      semanticLabel:
          l == null
              ? completeTitle
              : 'Continue: ${l.title}. $levelTitle, ${l.minutes} minute read',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Icon(Icons.menu_book_rounded, size: 20, color: c.gold),
            const SizedBox(width: AllInSpace.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l == null ? completeTitle : 'Continue: ${l.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(
                      15,
                      weight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l == null
                        ? 'Every lesson is done — open any of them again.'
                        : '${levelTitle ?? ''} · ${l.minutes} min read',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(12.5, color: c.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

/// The TOOLS grid (§6.1). Two columns of [tileHeight] tiles; one column above
/// 1.5× text scale.
class ToolsGrid extends StatelessWidget {
  const ToolsGrid({super.key, required this.onOpen, this.tools = kStudyTools});

  final ValueChanged<StudyTool> onOpen;
  final List<StudyTool> tools;

  /// The tile height for [textScale]: 8 pt of padding top and bottom, the
  /// label's line, and room for the gloss to take two lines — which it does at
  /// 360, where a tile is 160 pt wide (§6.1).
  ///
  /// Every tile in a run is given the same height, so the grid keeps its
  /// rhythm whether a gloss wrapped or not.
  static double tileHeight(double textScale) =>
      16 + labelLine * textScale + 2 + 2 * glossLine * textScale;

  /// Inter 15 and Inter 12 at their rendered line heights.
  static const double labelLine = 19;
  static const double glossLine = 15.5;

  /// Whether the grid reflows to a single column (§6.1).
  static bool singleColumn(double textScale) => textScale > 1.5;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final one = singleColumn(scale);
    final height = tileHeight(scale);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = one ? 1 : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * AllInSpace.sm) / columns;
        return Wrap(
          spacing: AllInSpace.sm,
          runSpacing: AllInSpace.sm,
          children: <Widget>[
            for (final tool in tools)
              SizedBox(
                width: width,
                height: height,
                child: _ToolTile(tool: tool, onTap: () => onOpen(tool)),
              ),
          ],
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});

  final StudyTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '${tool.label}. ${tool.subtitle}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
          decoration: BoxDecoration(
            color: c.ink850,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(AllInRadius.md),
          ),
          child: Row(
            children: <Widget>[
              Icon(tool.icon, size: 20, color: c.gold),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tool.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.body(15, color: c.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.body(
                        12,
                        color: c.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pinned "Quick reference & glossary ›" row (56 pt, §6.1).
class QuickReferenceRow extends StatelessWidget {
  const QuickReferenceRow({super.key, required this.onTap});

  final VoidCallback onTap;

  static const String label = 'Quick reference & glossary';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AllInSpace.md,
            vertical: AllInSpace.sm,
          ),
          decoration: BoxDecoration(
            color: c.ink850,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(AllInRadius.md),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.menu_book_rounded, size: 20, color: c.gold),
              const SizedBox(width: AllInSpace.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.body(15, color: c.text),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 48 pt level header — sticky while its lessons scroll (§6.1).
class LevelHeader extends StatelessWidget {
  const LevelHeader({
    super.key,
    required this.level,
    required this.index,
    required this.done,
  });

  final Level level;

  /// 0-based; rendered as "L{index + 1}".
  final int index;
  final int done;

  /// Desktop icon name → Flutter icon (`kLevelIconNames`).
  static IconData iconFor(String name) => switch (name) {
    'cards' => Icons.style_rounded,
    'target' => Icons.adjust_rounded,
    'bolt' => Icons.bolt_rounded,
    _ => Icons.menu_book_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      color: c.ink900,
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AllInRadius.sm),
            ),
            child: Icon(iconFor(level.icon), size: 16, color: c.gold),
          ),
          const SizedBox(width: AllInSpace.sm),
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'L${index + 1} ',
                      style: AllInText.body(
                        15,
                        weight: FontWeight.w700,
                        color: c.textFaint,
                      ),
                    ),
                    TextSpan(
                      text: level.title,
                      style: AllInText.body(
                        15,
                        weight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(
            '$done/${level.lessons.length}',
            style: AllInText.mono(13, color: c.textFaint),
          ),
        ],
      ),
    );
  }
}

/// A 52 pt lesson row (§6.1).
class LessonRow extends StatelessWidget {
  const LessonRow({
    super.key,
    required this.lesson,
    required this.done,
    required this.active,
    required this.onTap,
    this.reducedMotion = false,
  });

  final Lesson lesson;
  final bool done;

  /// The active / last-read lesson row is gold-tinted 15 % (§6.1).
  final bool active;
  final VoidCallback onTap;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label:
          '${lesson.title}. ${lesson.minutes} minute read. '
          '${done ? 'Completed' : 'Not started'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AllInMotion.of(
            context,
            AllInMotion.fast,
            reduced: reducedMotion,
          ),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AllInSpace.sm,
            vertical: AllInSpace.sm,
          ),
          decoration: BoxDecoration(
            color: active ? c.gold.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(AllInRadius.sm),
            border: Border(left: BorderSide(color: c.line)),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: AllInSpace.sm),
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? c.good : null,
                  shape: BoxShape.circle,
                  border: done ? null : Border.all(color: c.ink400, width: 1.5),
                ),
                child:
                    done
                        ? Icon(Icons.check_rounded, size: 11, color: c.ink900)
                        : null,
              ),
              const SizedBox(width: AllInSpace.md),
              Expanded(
                child: Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.body(
                    15,
                    color: active || done ? c.text : c.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Text(
                '${lesson.minutes}m',
                style: AllInText.mono(12.5, color: c.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The level a lesson belongs to, plus its 1-based index — S0 and S1 both
/// need it and neither should scan `kLevels` inline.
({Level level, int index})? levelWithIndex(String lessonId) {
  for (var i = 0; i < kLevels.length; i++) {
    for (final lesson in kLevels[i].lessons) {
      if (lesson.id == lessonId) return (level: kLevels[i], index: i);
    }
  }
  return null;
}
