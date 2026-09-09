/// The lesson block renderer (DESIGN.md §6.2, §6.5; docs/port/
/// study-curriculum.md §6) — one widget per [LessonBlock] variant, at mobile
/// typography, with every `{{term}}` resolved to a dotted-gold S2 popover.
///
/// Two rules this file exists to keep:
///
/// * **Every variant renders.** `HeadingBlock`, `ParagraphBlock`,
///   `BulletsBlock`, `NumberedBlock`, `CalloutBlock` (all five kinds),
///   `TableBlock`, `RangeBlock`, `WidgetBlock` (all eleven kinds) and
///   `QuizBlock` have a case; the `switch` is exhaustive over the sealed
///   class, so a new block type is a compile error rather than a blank space.
/// * **Nothing is a desktop table.** A three-column table at 360 pt is
///   unreadable, so tables become card grids: a key/value table (the desktop's
///   `Row(k, v)`, recognised by an all-empty header) is a stack of label-left /
///   mono-value-right rows, and a headed table is one card per row with the
///   header cells as the field labels (§6.2).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/data/preflop_charts.g.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bluff_calculator.dart';
import 'equity_calculator.dart';
import 'hand_rankings_list.dart';
import 'mini_drills.dart';
import 'multiway_trainer.dart';
import 'pot_odds_calculator.dart';
import 'quiz_card.dart';
import 'range_board_breakdown_card.dart';
import 'range_explorer.dart';
import 'study_controls.dart';
import 'study_text.dart';

/// Vertical gap between two lesson blocks (desktop `space-y-4`).
const double kLessonBlockGap = AllInSpace.lg;

/// The five callout kinds' identity: icon, tone and the title used when the
/// block leaves [CalloutBlock.title] null.
({IconData icon, Color Function(AllInColors) tone, String title}) calloutStyle(
  CalloutKind kind,
) => switch (kind) {
  CalloutKind.key => (
    icon: Icons.bolt_rounded,
    tone: (AllInColors c) => c.gold,
    title: 'Key idea',
  ),
  CalloutKind.tip => (
    icon: Icons.lightbulb_outline_rounded,
    tone: (AllInColors c) => c.info,
    title: 'Tip',
  ),
  CalloutKind.warning => (
    icon: Icons.warning_amber_rounded,
    tone: (AllInColors c) => c.warn,
    title: 'Watch out',
  ),
  CalloutKind.math => (
    icon: Icons.functions_rounded,
    tone: (AllInColors c) => c.gold,
    title: 'Show me the math',
  ),
  CalloutKind.example => (
    icon: Icons.menu_book_outlined,
    tone: (AllInColors c) => c.info,
    title: 'Worked example',
  ),
};

/// The hands a [RangeBlock] highlights.
///
/// `chart` names a generated chart — `rfi:<POS>` or
/// `vsRfi:<SPOT>:<call|threebet>`; `topPct` is `topPercentRange(pct)`;
/// `labels` is a literal set. An unknown chart id yields the empty set, which
/// draws an empty (but perfectly legible) grid rather than throwing inside a
/// lesson.
Set<HandLabel> rangeBlockLabels(RangeBlock block) {
  final labels = block.labels;
  if (labels != null) return labels.toSet();
  final pct = block.topPct;
  if (pct != null) return topPercentRange(pct);
  final chart = block.chart;
  if (chart == null) return <HandLabel>{};
  final parts = chart.split(':');
  if (parts.length == 2 && parts[0] == 'rfi') {
    final table = kRfi100[parts[1]];
    return table == null ? <HandLabel>{} : chartToSet(table);
  }
  if (parts.length == 3 && parts[0] == 'vsRfi') {
    final table = kVsRfi100[parts[1]]?[parts[2]];
    return table == null ? <HandLabel>{} : chartToSet(table);
  }
  return <HandLabel>{};
}

/// One block of a lesson body.
class LessonBlockView extends ConsumerWidget {
  const LessonBlockView({
    super.key,
    required this.block,
    required this.contentWidth,
    this.isLead = false,
    this.onOpenGlossary,
    this.quizSeed = 0,
  });

  final LessonBlock block;

  /// The width the page gives this block (page width − 2 × 16 pt margin).
  final double contentWidth;

  /// True for the first paragraph of a lesson — the desktop `Lead`.
  final bool isLead;

  final void Function(String termId)? onOpenGlossary;

  /// Changes when the reader wants a fresh quiz (a new lesson visit).
  final int quizSeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = ref.watch(reducedMotionProvider);
    return switch (block) {
      HeadingBlock(:final text, :final level) => _Heading(
        text: text,
        level: level,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      ParagraphBlock(:final text) => _Paragraph(
        text: text,
        lead: isLead,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      BulletsBlock(:final items) => _ListBlock(
        items: items,
        numbered: false,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      NumberedBlock(:final items) => _ListBlock(
        items: items,
        numbered: true,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      CalloutBlock(:final kind, :final title, :final body) => _Callout(
        kind: kind,
        title: title,
        body: body,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      TableBlock() => _Table(
        block: block as TableBlock,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      RangeBlock() => _Range(
        block: block as RangeBlock,
        contentWidth: contentWidth,
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reduced,
      ),
      WidgetBlock(:final kind, :final params) => LessonWidgetView(
        kind: kind,
        params: params,
        contentWidth: contentWidth,
      ),
      QuizBlock(:final questions) => QuizCard(
        key: ValueKey<int>(quizSeed),
        questions: questions,
        onOpenGlossary: onOpenGlossary,
      ),
    };
  }
}

/* ------------------------------------------------------------------- prose */

class _Heading extends StatelessWidget {
  const _Heading({
    required this.text,
    required this.level,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final String text;
  final int level;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      header: true,
      child: LessonRichText(
        text,
        style: AllInText.display(
          level >= 3 ? 18 : 22,
          color: c.text,
          height: 1.25,
        ),
        onOpenGlossary: onOpenGlossary,
        reducedMotion: reducedMotion,
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({
    required this.text,
    required this.lead,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final String text;
  final bool lead;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  /// The plain text a long-press copies — markup stripped, terms shown.
  static String plainText(String source) => source
      .replaceAllMapped(
        RegExp(r'\{\{([^}|]+)(?:\|([^}]*))?\}\}'),
        (m) => m.group(2) ?? m.group(1) ?? '',
      )
      .replaceAll('**', '')
      .replaceAll('`', '');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = LessonRichText(
      text,
      style:
          lead
              ? AllInText.body(
                17,
                weight: FontWeight.w500,
                color: c.text,
                height: 1.5,
              )
              : AllInText.body(16, color: c.textMuted, height: 1.55),
      onOpenGlossary: onOpenGlossary,
      reducedMotion: reducedMotion,
    );
    // §6.2: "Long-press any paragraph → Copy only (no share; keeps the reader
    // quiet)." One gesture, one outcome, a toast to confirm it happened.
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: plainText(text)));
        if (!context.mounted) return;
        HapticFeedback.selectionClick();
        AllInToast.show(
          context,
          'Copied',
          icon: Icons.copy_rounded,
          reducedMotion: reducedMotion,
        );
      },
      child: body,
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.items,
    required this.numbered,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final List<String> items;
  final bool numbered;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == items.length - 1 ? 0 : AllInSpace.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child:
                      numbered
                          ? Text(
                            '${i + 1}.',
                            style: AllInText.mono(13, color: c.gold),
                          )
                          : Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: c.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                ),
                Expanded(
                  child: LessonRichText(
                    items[i],
                    style: AllInText.body(16, color: c.textMuted, height: 1.55),
                    onOpenGlossary: onOpenGlossary,
                    reducedMotion: reducedMotion,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.kind,
    required this.title,
    required this.body,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final CalloutKind kind;
  final String? title;
  final String body;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = calloutStyle(kind);
    final tone = style.tone(c);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AllInSpace.lg),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(AllInRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(style.icon, size: 15, color: tone),
              const SizedBox(width: AllInSpace.xs),
              Expanded(
                child: Text(
                  title ?? style.title,
                  style: AllInText.body(
                    13,
                    weight: FontWeight.w600,
                    color: kind == CalloutKind.warning ? c.warn : c.goldLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.xs),
          LessonRichText(
            body,
            style: AllInText.body(14, color: c.textMuted, height: 1.55),
            onOpenGlossary: onOpenGlossary,
            reducedMotion: reducedMotion,
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ tables */

class _Table extends StatelessWidget {
  const _Table({
    required this.block,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final TableBlock block;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  /// The desktop's `Row(k, v)` stat rows: two columns and no header text.
  bool get isKeyValue =>
      block.header.length == 2 && block.header.every((h) => h.trim().isEmpty);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isKeyValue)
          for (final row in block.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AllInSpace.sm),
              child: StatRowCard(
                label: row.isEmpty ? '' : row[0],
                value: row.length > 1 ? row[1] : '',
                onOpenGlossary: onOpenGlossary,
                reducedMotion: reducedMotion,
              ),
            )
        else
          for (final row in block.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AllInSpace.sm),
              child: _RecordCard(
                header: block.header,
                row: row,
                onOpenGlossary: onOpenGlossary,
                reducedMotion: reducedMotion,
              ),
            ),
        if (block.caption != null)
          Padding(
            padding: const EdgeInsets.only(top: AllInSpace.xs),
            child: Text(
              block.caption!,
              style: AllInText.body(12.5, color: c.textFaint, height: 1.4),
            ),
          ),
      ],
    );
  }
}

/// Label left (Inter 13), mono gold-light value right — the desktop stat row.
class StatRowCard extends StatelessWidget {
  const StatRowCard({
    super.key,
    required this.label,
    required this.value,
    this.onOpenGlossary,
    this.reducedMotion = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  /// Gold wash used by S4's `?term=` flash.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.md,
        vertical: AllInSpace.sm,
      ),
      decoration: BoxDecoration(
        color: highlight ? c.gold.withValues(alpha: 0.15) : c.ink850,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AllInRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: LessonRichText(
              label,
              style: AllInText.body(13, color: c.text, height: 1.4),
              onOpenGlossary: onOpenGlossary,
              reducedMotion: reducedMotion,
            ),
          ),
          const SizedBox(width: AllInSpace.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AllInText.mono(12.5, color: c.goldLight),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of a headed table, as a card: the first cell is the row's title and
/// every other cell is a labelled field. This is what keeps a three-column
/// table readable at 360 pt (§6.2).
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.header,
    required this.row,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final List<String> header;
  final List<String> row;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard.plain(
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.md,
        vertical: AllInSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (row.isNotEmpty)
            LessonRichText(
              row[0],
              style: AllInText.body(
                15,
                weight: FontWeight.w600,
                color: c.text,
                height: 1.35,
              ),
              onOpenGlossary: onOpenGlossary,
              reducedMotion: reducedMotion,
            ),
          for (var i = 1; i < row.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AllInSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (i < header.length && header[i].trim().isNotEmpty) ...[
                    SizedBox(
                      width: 78,
                      child: Text(
                        header[i],
                        style: AllInText.eyebrow(c.textFaint),
                      ),
                    ),
                    const SizedBox(width: AllInSpace.xs),
                  ],
                  Expanded(
                    child: LessonRichText(
                      row[i],
                      style: AllInText.body(
                        13.5,
                        color: c.textMuted,
                        height: 1.45,
                      ),
                      onOpenGlossary: onOpenGlossary,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------- range block */

class _Range extends StatelessWidget {
  const _Range({
    required this.block,
    required this.contentWidth,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final RangeBlock block;
  final double contentWidth;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = rangeBlockLabels(block);
    return StudyWidgetCard.wide(
      child: Column(
        children: <Widget>[
          StudyPad(
            child: Text(
              block.title,
              textAlign: TextAlign.center,
              style: AllInText.body(13, weight: FontWeight.w600, color: c.text),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          ScrollSafeRangeMatrix.readOnly(
            available: contentWidth,
            highlight: labels,
            reducedMotion: reducedMotion,
            semanticLabel: '${block.title}. ${labels.length} hand groups',
          ),
          const SizedBox(height: AllInSpace.sm),
          const StudyPad(child: StudyLegend()),
          if (block.note != null) ...<Widget>[
            const SizedBox(height: AllInSpace.sm),
            StudyPad(
              child: LessonRichText(
                block.note!,
                textAlign: TextAlign.center,
                style: AllInText.body(12.5, color: c.textFaint, height: 1.45),
                onOpenGlossary: onOpenGlossary,
                reducedMotion: reducedMotion,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------- widget dispatch */

/// Maps a [LessonWidgetKind] to its widget. Used inline by the reader and
/// full-screen by S3, which is why it takes the width rather than measuring.
class LessonWidgetView extends ConsumerWidget {
  const LessonWidgetView({
    super.key,
    required this.kind,
    required this.contentWidth,
    this.params = const <String, Object>{},
  });

  final LessonWidgetKind kind;
  final double contentWidth;
  final Map<String, Object> params;

  /// The matrix box a widget card gets: the full content width, because
  /// [StudyWidgetCard.wide] keeps its horizontal padding out of the way.
  double get _matrixBox => contentWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    switch (kind) {
      case LessonWidgetKind.handRankings:
        return HandRankingsList(
          available: contentWidth,
          fourColorDeck: settings.fourColorDeck,
        );
      case LessonWidgetKind.potOddsCalculator:
        return PotOddsCalculator(enableHaptics: settings.haptics);
      case LessonWidgetKind.bluffCalculator:
        return BluffCalculator(enableHaptics: settings.haptics);
      case LessonWidgetKind.multiwayEquityTrainer:
        return MultiwayTrainer(available: _matrixBox);
      case LessonWidgetKind.rangeExplorer:
        return RangeExplorer(available: _matrixBox);
      case LessonWidgetKind.equityCalculator:
        return EquityCalculator(available: _matrixBox);
      case LessonWidgetKind.rangeBoardBreakdown:
        return _breakdown();
      case LessonWidgetKind.drillPotOdds:
        return const PotOddsDrill();
      case LessonWidgetKind.drillOuts:
        return const OutsDrill();
      case LessonWidgetKind.drillRange:
        return RangeBuildDrill(available: _matrixBox);
      case LessonWidgetKind.cheatSheet:
        return const _QuickReferenceLink();
    }
  }

  /// `rangeBoardBreakdown` takes its range and board from [params]:
  /// `topPct` (int) or `labels` (space-separated), `board` (space-separated
  /// cards) and an optional `title`. The defaults are a button-opening range
  /// on a dry ace-high flop — the example the Hand-reading lesson uses.
  Widget _breakdown() {
    final labels = params['labels'];
    final topPct = params['topPct'];
    final range =
        labels is String
            ? labels.split(' ').where((s) => s.isNotEmpty).toSet()
            : topPercentRange(topPct is int ? topPct : 45);
    final board = params['board'];
    final cards =
        board is String
            ? board.split(' ').where((s) => s.isNotEmpty).toList()
            : const <Card>['Ah', 'Kd', '7c'];
    final title = params['title'];
    return RangeBoardBreakdownCard(
      title: title is String ? title : 'This range on this board',
      range: range,
      board: cards,
    );
  }
}

/// The `cheatSheet` widget kind: the quick reference is a whole screen (S4),
/// so inside a lesson it is a working link to it rather than a second copy.
class _QuickReferenceLink extends StatelessWidget {
  const _QuickReferenceLink();

  @override
  Widget build(BuildContext context) {
    return AllInCard.plain(
      onTap: () => context.push(AllInRoutes.glossaryPath()),
      child: Row(
        children: <Widget>[
          Icon(Icons.menu_book_rounded, size: 20, color: context.colors.gold),
          const SizedBox(width: AllInSpace.md),
          Expanded(
            child: Text(
              'Quick reference & glossary',
              style: AllInText.body(
                15,
                weight: FontWeight.w600,
                color: context.colors.text,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.colors.textFaint,
          ),
        ],
      ),
    );
  }
}
