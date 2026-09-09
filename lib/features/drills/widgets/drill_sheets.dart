/// The four sheets D0 presents (DESIGN.md §2.2): **D2** the frame list,
/// **D3** the stat explainers, **D4** the mode blurb, and the source-pill
/// sheet of §5.1. None of them is a route — they belong to D0 so system back
/// pops them first (§16.1).
///
/// D3, D4 and the source pill are all one widget, `ExplainerSheet` (§10.5):
/// title · verbatim body · the same two disclosure rows in the same two
/// places. Only D2 is bespoke, because it is a list of frames.
library;

import 'package:flutter/material.dart';

import '../../../engine/engine.dart';
import '../../../services/persistence.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../content/drill_copy.dart';

/* ------------------------------------------------------------ D2 · frames */

/// The frame list behind a long-press on the scrubber pill (§5.2).
class DrillFrameListSheet extends StatelessWidget {
  const DrillFrameListSheet({
    super.key,
    required this.frames,
    required this.index,
    required this.onPick,
  });

  final List<DrillFrame> frames;
  final int index;
  final ValueChanged<int> onPick;

  static Future<void> show(
    BuildContext context, {
    required List<DrillFrame> frames,
    required int index,
    required ValueChanged<int> onPick,
    bool reducedMotion = false,
  }) => AllInSheet.show<void>(
    context,
    reducedMotion: reducedMotion,
    child: DrillFrameListSheet(frames: frames, index: index, onPick: onPick),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Eyebrow(DrillCopy.handReplay),
        const SizedBox(height: AllInSpace.sm),
        for (var i = 0; i < frames.length; i++)
          _FrameRow(
            index: i,
            text: frames[i].text,
            current: i == index,
            decision: i == frames.length - 1,
            onTap: () {
              onPick(i);
              Navigator.of(context).maybePop();
            },
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
        Container(height: 0, color: c.line),
      ],
    );
  }
}

class _FrameRow extends StatelessWidget {
  const _FrameRow({
    required this.index,
    required this.text,
    required this.current,
    required this.decision,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool current;
  final bool decision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: current,
      label:
          '${index + 1}. $text'
          '${decision ? '. ${DrillCopy.decisionPoint}' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.sm,
              vertical: AllInSpace.sm,
            ),
            decoration: BoxDecoration(
              color:
                  current ? c.gold.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${index + 1}',
                    style: AllInText.mono(
                      12,
                      color: current ? c.gold : c.textFaint,
                    ),
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    text,
                    style: AllInText.body(
                      15,
                      weight: decision ? FontWeight.w700 : FontWeight.w400,
                      color: current ? c.text : c.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
                if (decision) ...[
                  const SizedBox(width: AllInSpace.sm),
                  Icon(Icons.my_location_rounded, size: 16, color: c.gold),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------- D3 · stat sheets */

/// Which stat was tapped — mirrors `StatsStrip`'s [DrillStat].
Future<void> showDrillStatSheet(
  BuildContext context, {
  required DrillStat stat,
  required List<DrillAnswer> answers,
  required int nowMs,
  bool reducedMotion = false,
}) {
  final (
    String title,
    String body,
    String? math,
    String? expert,
  ) = switch (stat) {
    DrillStat.rating => (
      DrillCopy.ratingTitle,
      DrillCopy.ratingTooltip,
      DrillCopy.ratingMath,
      DrillCopy.ratingExpert,
    ),
    DrillStat.accuracy => (
      DrillCopy.accuracyTitle,
      DrillCopy.accuracyTooltip,
      DrillCopy.accuracyMath,
      null,
    ),
    DrillStat.streak || DrillStat.best => (
      DrillCopy.streakTitle,
      DrillCopy.streakTooltip,
      null,
      null,
    ),
    DrillStat.today || DrillStat.dayStreak => (
      DrillCopy.todayTitle,
      DrillCopy.todayTooltip,
      DrillCopy.todayMath,
      null,
    ),
  };

  final spark =
      stat == DrillStat.rating
          ? _RatingSparkline(answers: answers, nowMs: nowMs)
          : null;

  return AllInSheet.show<void>(
    context,
    detent: AllInSheetDetent.s,
    reducedMotion: reducedMotion,
    child: ExplainerSheet(
      title: title,
      body: body,
      math: math,
      expert: expert,
      reducedMotion: reducedMotion,
      footer: spark,
    ),
  );
}

/// The 30-day rating trend of §5.1, read from `allin.drill_answers.v1`.
class _RatingSparkline extends StatelessWidget {
  const _RatingSparkline({required this.answers, required this.nowMs});

  final List<DrillAnswer> answers;
  final int nowMs;

  static const int _windowMs = 30 * 86400000;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = [
      for (final a in answers)
        if (a.ts >= nowMs - _windowMs) a.ratingAfter,
    ];
    if (values.length < 2) {
      return Text(
        DrillCopy.ratingNoTrend,
        style: AllInText.body(13, color: c.textFaint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Eyebrow(DrillCopy.ratingTrend),
        const SizedBox(height: AllInSpace.sm),
        SparkLine(
          values: values,
          filled: true,
          semanticLabel: DrillCopy.ratingTrendSemantics(
            values.first.round(),
            values.last.round(),
          ),
        ),
      ],
    );
  }
}

/* -------------------------------------- D4 · mode blurb, and the source pill */

/// D4 — the current mode's verbatim blurb.
Future<void> showDrillModeSheet(
  BuildContext context, {
  required DrillMode mode,
  bool reducedMotion = false,
}) => AllInSheet.show<void>(
  context,
  detent: AllInSheetDetent.s,
  reducedMotion: reducedMotion,
  child: ExplainerSheet(
    title: mode.label,
    body: mode.blurb,
    reducedMotion: reducedMotion,
  ),
);

/// The source pill → About's matching "How the grading works" paragraph.
Future<void> showDrillSourceSheet(
  BuildContext context, {
  required Puzzle puzzle,
  bool reducedMotion = false,
}) => AllInSheet.show<void>(
  context,
  detent: AllInSheetDetent.s,
  reducedMotion: reducedMotion,
  child: ExplainerSheet(
    title: DrillCopy.sourceLabel(puzzle),
    body: DrillCopy.sourceExplainer(puzzle),
    reducedMotion: reducedMotion,
  ),
);
