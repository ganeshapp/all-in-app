/// D1's content — the two halves `FeedbackPanel` pins and scrolls
/// (DESIGN.md §5.3, §5.5, §5.6, §5.7).
///
/// The panel's contract (§10.6) splits the note in two: `header` is **pinned**
/// (verdict badge, verdict word, rating delta, EV-loss line, schedule line)
/// and `body` **scrolls** (rationale, outcomes box, the two disclosure rows,
/// the secondary button row). `CoachNoteView.drill` renders both halves in one
/// column, so it cannot be handed to either slot without duplicating the
/// header — see the feature report. What is reused instead is every piece it
/// is made of: `VerdictBadge`, `DisclosureRow` with the **same two labels in
/// the same two places** (Principle 3), and `RangeMatrix.readOnly` inside
/// layer 3.
library;

import 'package:flutter/material.dart';

import '../../../engine/engine.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../content/drill_copy.dart';
import '../content/drill_rationale.dart';

/// The width §10.4 gives the D1 grading matrix.
const double kDrillGradeMatrixWidth = 326;

/* --------------------------------------------------------------- header */

class DrillFeedbackHeader extends StatelessWidget {
  const DrillFeedbackHeader({
    super.key,
    required this.correct,
    this.ratingDelta,
    this.evLossLine,
    this.scheduleLine,
    this.setDoneLine,
  });

  final bool correct;

  /// Practice modes only; null in Review (§5.3 "Review mode: no delta").
  final int? ratingDelta;

  /// Only when wrong and the loss is worth naming (> 0.05 bb).
  final String? evLossLine;

  /// §5.5's "Next in 3 days · 2 of 3" / "Retired — beaten 3 times".
  final String? scheduleLine;

  /// §5.1's bounded-set strip.
  final String? setDoneLine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = correct ? c.good : c.bad;
    final delta = ratingDelta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: _semantics(),
          child: ExcludeSemantics(
            child: Row(
              children: [
                VerdictBadge(
                  verdict: correct ? Verdict.great : Verdict.mistake,
                  size: VerdictBadge.medium,
                ),
                const SizedBox(width: AllInSpace.md),
                Expanded(
                  child: Text(
                    correct ? DrillCopy.correct : DrillCopy.notOptimal,
                    style: AllInText.body(
                      17,
                      weight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                ),
                // A bare signed integer in the corner said nothing about what
                // it counted; §5.4 calls this the *rating* change, so the row
                // says so (the full explainer stays behind the stats sheet's
                // `DrillCopy.ratingTooltip`).
                if (delta != null && delta != 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        fmtSigned(delta, 0),
                        style: AllInText.mono(
                          15,
                          color: delta > 0 ? c.good : c.bad,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DrillCopy.ratingUnit,
                        style: AllInText.body(12, color: c.textFaint),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (evLossLine != null) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(
            evLossLine!,
            style: AllInText.body(15, color: c.bad, height: 1.35),
          ),
        ],
        if (scheduleLine != null) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(scheduleLine!, style: AllInText.mono(12, color: c.textMuted)),
        ],
        if (setDoneLine != null) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(setDoneLine!, style: AllInText.mono(12, color: c.gold)),
        ],
      ],
    );
  }

  String _semantics() => [
    correct ? DrillCopy.correct : DrillCopy.notOptimal,
    if (ratingDelta != null && ratingDelta != 0)
      'rating ${fmtSigned(ratingDelta!, 0)}',
    if (evLossLine != null) evLossLine!,
    if (scheduleLine != null) scheduleLine!,
    if (setDoneLine != null) setDoneLine!,
  ].join('. ');
}

/* ----------------------------------------------------------------- body */

class DrillFeedbackBody extends StatelessWidget {
  const DrillFeedbackBody({
    super.key,
    required this.puzzle,
    required this.rationale,
    this.actions,
    this.footerCaption,
    this.alwaysExpandMath = false,
    this.onDisclosureToggle,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final Puzzle puzzle;

  /// `GradeResult.rationale` — verbatim from the engine. It is *not* rendered
  /// as layer 1: [DrillRationale.plain] re-writes the verdict in the coach's
  /// voice from the puzzle's structured fields, and this expert wording moves
  /// to the top of "Show me the math" (§5.3 layer 2, TONE.md).
  final String rationale;

  /// The 48 pt secondary row (lesson link · "Drill 5 similar").
  final Widget? actions;

  /// "4 more of this spot type coming up".
  final String? footerCaption;

  final bool alwaysExpandMath;

  /// Opening a disclosure expands the panel (§5.3).
  final ValueChanged<bool>? onDisclosureToggle;

  final bool enableHaptics;
  final bool reducedMotion;

  /// §5.3's per-option outcomes box — only when the spot has a real price.
  static List<String> outcomesFor(Puzzle p) {
    final equity = p.equity;
    final odds = p.potOdds;
    if (equity == null || odds == null || p.toCall <= 0) return const [];
    return [
      DrillCopy.folding,
      DrillCopy.calling(equity, p.pot, p.toCall, odds),
    ];
  }

  /// Layer 2 (§5.3, §5.7): the desktop's Equity / Pot-odds line, the EV
  /// arithmetic as steps, and — for exploits — the balanced number beside the
  /// exploitative one.
  static List<String> mathLinesFor(Puzzle p) {
    final lines = <String>[];
    // Layer 2 leads with the engine's own sentence whenever layer 1 replaced
    // it: the expert wording is kept in full, one disclosure away.
    if (DrillRationale.plain(p) != null) lines.add(p.rationale);
    final equity = p.equity;
    final odds = p.potOdds;
    if (p.kind == PuzzleKind.exploit && equity != null) {
      final balanced = DrillCopy.balancedPctOf(p.rationale);
      if (balanced != null) lines.add(DrillCopy.balancedLine(balanced));
      lines.add(DrillCopy.exploitLine((equity * 100).round()));
    }
    if (equity != null) lines.add(DrillCopy.equityLine(equity));
    if (odds != null) lines.add(DrillCopy.potOddsLine(odds));
    if (equity != null && p.toCall > 0) {
      lines.add(DrillCopy.mathSteps(equity, p.pot, p.toCall));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final outcomes = outcomesFor(puzzle);
    final math = mathLinesFor(puzzle);
    final mixed = puzzle.accept.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DrillRationale.plain(puzzle) ?? rationale,
          style: AllInText.body(17, color: c.text, height: 1.45),
        ),
        if (mixed) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(
            DrillCopy.mixedFrequency,
            style: AllInText.body(15, color: c.textMuted, height: 1.4),
          ),
        ],
        if (outcomes.isNotEmpty) ...[
          const SizedBox(height: AllInSpace.md),
          Container(
            padding: const EdgeInsets.all(AllInSpace.md),
            decoration: BoxDecoration(
              color: c.ink700,
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in outcomes)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: line == outcomes.last ? 0 : AllInSpace.sm,
                    ),
                    child: Text(
                      line,
                      style: AllInText.body(15, color: c.text, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AllInSpace.sm),
        DisclosureRow(
          key: ValueKey('drill-math-${puzzle.hashCode}'),
          label: CoachCopy.showMath,
          expandedLabel: CoachCopy.hideMath,
          initiallyExpanded: alwaysExpandMath,
          onToggle: onDisclosureToggle,
          enableHaptics: enableHaptics,
          reducedMotion: reducedMotion,
          child:
              math.isEmpty
                  ? Text(
                    CoachCopy.noMathChartSpot,
                    style: AllInText.body(15, color: c.textMuted, height: 1.45),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final line in math)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AllInSpace.xs),
                          child: Text(
                            line,
                            style: AllInText.mono(13, color: c.textMuted),
                          ),
                        ),
                    ],
                  ),
        ),
        DisclosureRow(
          key: ValueKey('drill-expert-${puzzle.hashCode}'),
          label: CoachCopy.expertDetail,
          expandedLabel: CoachCopy.hideExpert,
          tone: DisclosureTone.muted,
          onToggle: onDisclosureToggle,
          enableHaptics: enableHaptics,
          reducedMotion: reducedMotion,
          child: DrillGradeRange(puzzle: puzzle),
        ),
        if (actions != null) ...[
          const SizedBox(height: AllInSpace.md),
          actions!,
        ],
        if (footerCaption != null) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(
            footerCaption!,
            textAlign: TextAlign.center,
            style: AllInText.body(12, color: c.textFaint),
          ),
        ],
      ],
    );
  }
}

/* ---------------------------------------------------- layer 3's contents */

/// Layer 3's body: the desktop's own label as the first line, the range title
/// and the read-only matrix. Leak spots keep the row and say why it is empty
/// (§5.3, §15.2).
class DrillGradeRange extends StatelessWidget {
  const DrillGradeRange({super.key, required this.puzzle});

  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final range = puzzle.gradeRange;
    if (range == null || range.isEmpty) {
      return Text(
        DrillCopy.noRangeForLeak,
        style: AllInText.body(15, color: c.textMuted, height: 1.45),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DrillCopy.rangeItWasGradedAgainst,
          style: AllInText.body(15, color: c.textMuted, height: 1.45),
        ),
        if (puzzle.gradeRangeTitle != null) ...[
          const SizedBox(height: AllInSpace.xs),
          Text(
            puzzle.gradeRangeTitle!,
            style: AllInText.body(13, weight: FontWeight.w600, color: c.text),
          ),
        ],
        const SizedBox(height: AllInSpace.sm),
        LayoutBuilder(
          builder:
              (context, constraints) => RangeMatrix.readOnly(
                highlight: range.toSet(),
                width:
                    constraints.maxWidth.isFinite &&
                            constraints.maxWidth < kDrillGradeMatrixWidth
                        ? constraints.maxWidth
                        : kDrillGradeMatrixWidth,
                headerWidth: 18,
                semanticLabel:
                    puzzle.gradeRangeTitle ?? DrillCopy.rangeItWasGradedAgainst,
              ),
        ),
        const SizedBox(height: AllInSpace.sm),
        const RangeLegend(),
      ],
    );
  }
}
