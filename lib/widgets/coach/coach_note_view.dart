/// `CoachNoteView` — the three-layer coach anatomy (DESIGN.md §10.5, §4.8).
///
/// One widget, three variants, one order everywhere (TONE.md's layers):
///
/// 1. header (verdict disc · label · "EV Coach · Your call · River" · optional
///    XS cards + the one-line situation),
/// 2. **layer 1** — the plain-English paragraph, always open, verbatim
///    `review.plain ?? review.text`,
/// 3. the optional [EquityBar] and the amber multiway callout,
/// 4. **two `DisclosureRow`s, always rendered** — "Show me the math" (gold) and
///    "Expert detail" (muted). When there is nothing behind them they open to a
///    written line, never to blank space (§4.8, §7.2, §14),
/// 5. the EV tile, then the button row.
///
/// Variants: the default constructor is P3 / H1 (`readOnly` for the P4 → P3
/// replacement and the replayer), [CoachNoteView.drill] is D1's feedback body
/// (§5.3) and [CoachNoteView.peek] is P7's score card (§4.9).
///
/// Pure presentation: it takes a `CoachReview` plus callbacks. The XS cards are
/// drawn through [cardBuilder] so this file never depends on
/// `lib/widgets/table/playing_card_view.dart`; "View range" is [onViewRange],
/// because P5 is pushed by the sheet that hosts this view.
library;

import 'package:flutter/material.dart';

import '../../engine/cards.dart' show kSuitSymbol;
import '../../engine/coach.dart';
import '../../engine/format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/all_in_button.dart';
import '../foundations/disclosure_row.dart';
import 'equity_bar.dart';
import 'verdict_badge.dart';

/// Draws one card at [width] pt — `(ctx, card, width) => PlayingCardView(...)`.
typedef CoachCardBuilder =
    Widget Function(BuildContext context, String card, double width);

enum CoachNoteVariant { note, drill, peek }

/// P7's grade word (§4.9). Gold is not a verdict colour (§16.5) but it *is*
/// the "Solid" grade colour the spec asks for, so grades have their own scale.
enum PeekGrade {
  sharp('Sharp read'),
  solid('Solid'),
  rough('Rough'),
  wayOff('Way off');

  const PeekGrade(this.label);

  final String label;

  /// Desktop thresholds: ≥ .8 · ≥ .6 · ≥ .4 · else.
  static PeekGrade forScore(double score) =>
      score >= 0.8
          ? PeekGrade.sharp
          : score >= 0.6
          ? PeekGrade.solid
          : score >= 0.4
          ? PeekGrade.rough
          : PeekGrade.wayOff;

  Color color(AllInColors c) => switch (this) {
    PeekGrade.sharp => c.good,
    PeekGrade.solid => c.gold,
    PeekGrade.rough => c.warn,
    PeekGrade.wayOff => c.bad,
  };
}

/// The verbatim strings the three-layer surfaces share, in one place so the
/// user meets one vocabulary everywhere (§7.2). Moves to `l10n/strings.dart`
/// when that table lands (§16.7).
abstract final class CoachCopy {
  static const String showMath = 'Show me the math';
  static const String hideMath = 'Hide the math';
  static const String expertDetail = 'Expert detail';
  static const String hideExpert = 'Hide expert detail';

  /// §4.8 — a coach verdict with no steps.
  static const String noMathVerdict =
      'No math for this one — the verdict is a rule of thumb, not a '
      'calculation.';

  /// §7.2 — an explainer with nothing to derive.
  static const String noMathDefinition =
      "No math for this one — it's a definition, not a calculation.";

  /// §5.3 — a drill spot graded from a chart.
  static const String noMathChartSpot =
      "No math for this one — it's a chart spot.";

  /// §4.8 — a bot read.
  static const String noMathRead =
      'No math for a read — this is an interpretation of their style.';

  static const String nothingExtra = 'Nothing extra here.';

  static const String gotIt = 'Got it';
  static const String close = 'Close';
  static const String viewRange = 'View range';
  static const String expectedValue = 'Expected value';

  /// §4.8's multiway callout (port §9 body step 3), `{n}` = opponents.
  static String multiway(int opponents) =>
      'Multiway pot ($opponents opponents). With more players someone hits '
      'the board more often, so you need a stronger hand to continue. The '
      'numbers here are a rough estimate against random hands — treat close '
      'verdicts loosely.';
}

class CoachNoteView extends StatelessWidget {
  /// P3 / H1: the note as the engine produced it.
  const CoachNoteView({
    super.key,
    required CoachReview this.review,
    this.bigBlind = 20,
    this.blocking = false,
    this.readOnly = false,
    this.heroCards = const <String>[],
    this.situation,
    this.cardBuilder,
    this.alwaysExpandMath = false,
    this.onViewRange,
    this.onDismiss,
    this.dismissLabel,
    this.onOpenGlossary,
    this.onDisclosureToggle,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = CoachNoteVariant.note,
       correct = null,
       verdictLabel = null,
       ratingDelta = null,
       evLossLine = null,
       rationale = null,
       outcomes = const <String>[],
       mathLines = const <String>[],
       expertLines = const <String>[],
       expertChild = null,
       actions = null,
       footerCaption = null,
       grade = null,
       gradeLabel = null,
       plainLines = const <String>[];

  /// D1's feedback body (§5.3): verdict header with the rating delta, the
  /// EV-loss line, the rationale, the per-option outcomes box, then the same
  /// two rows — layer 3 holds `gradeRangeTitle` + the compare matrix.
  const CoachNoteView.drill({
    super.key,
    required bool this.correct,
    required String this.verdictLabel,
    required String this.rationale,
    this.ratingDelta,
    this.evLossLine,
    this.outcomes = const <String>[],
    this.mathLines = const <String>[],
    this.expertLines = const <String>[],
    this.expertChild,
    this.actions,
    this.footerCaption,
    this.alwaysExpandMath = false,
    this.onDisclosureToggle,
    this.onOpenGlossary,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = CoachNoteVariant.drill,
       review = null,
       bigBlind = 20,
       blocking = false,
       readOnly = false,
       heroCards = const <String>[],
       situation = null,
       cardBuilder = null,
       onViewRange = null,
       onDismiss = null,
       dismissLabel = null,
       grade = null,
       gradeLabel = null,
       plainLines = const <String>[];

  /// P7's score card (§4.9): the grade word is layer 1's headline — the
  /// percentage lives one row down, never here.
  const CoachNoteView.peek({
    super.key,
    required PeekGrade this.grade,
    required this.plainLines,
    this.gradeLabel,
    this.mathLines = const <String>[],
    this.expertLines = const <String>[],
    this.actions,
    this.footerCaption,
    this.alwaysExpandMath = false,
    this.onDisclosureToggle,
    this.onOpenGlossary,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = CoachNoteVariant.peek,
       review = null,
       bigBlind = 20,
       blocking = false,
       readOnly = false,
       heroCards = const <String>[],
       situation = null,
       cardBuilder = null,
       onViewRange = null,
       onDismiss = null,
       dismissLabel = null,
       correct = null,
       verdictLabel = null,
       ratingDelta = null,
       evLossLine = null,
       rationale = null,
       outcomes = const <String>[],
       expertChild = null;

  final CoachNoteVariant variant;

  // ---------------------------------------------------------------- note
  /// The engine's note. Non-null for [CoachNoteVariant.note].
  final CoachReview? review;

  /// Chips per big blind — the EV tile prints `evChips / bigBlind`.
  final double bigBlind;

  /// A blocking mistake (§4.8): the dismiss button reads "Got it" and is
  /// primary; the hosting sheet drops its grabber and scrim dismissal.
  final bool blocking;

  /// P4 → P3 and the replayer: nothing is dismissed, nothing is paused.
  final bool readOnly;

  /// Hero's two cards for the header's XS row; the board comes from [review].
  final List<String> heroCards;

  /// "you called 8 bb into 24 bb".
  final String? situation;

  /// Draws the 22 pt header cards. Text glyphs are used when null.
  final CoachCardBuilder? cardBuilder;

  final VoidCallback? onViewRange;
  final VoidCallback? onDismiss;
  final String? dismissLabel;

  // --------------------------------------------------------------- drill
  final bool? correct;
  final String? verdictLabel;
  final int? ratingDelta;
  final String? evLossLine;
  final String? rationale;
  final List<String> outcomes;

  /// Layer 3 body for the drill panel — `gradeRangeTitle`, the read-only
  /// compare matrix and the caption are built by the caller.
  final Widget? expertChild;

  /// The secondary button row (lesson link · "Drill 5 similar"). The pinned
  /// "Next puzzle" button belongs to `FeedbackPanel`, not to this widget.
  final Widget? actions;

  /// "4 more of this spot type coming up".
  final String? footerCaption;

  // ---------------------------------------------------------------- peek
  final PeekGrade? grade;

  /// Overrides [PeekGrade.label] when a caller has its own verbatim word.
  final String? gradeLabel;

  /// Layer 1's plain-English lines ("You caught about 7 in 10…").
  final List<String> plainLines;

  // -------------------------------------------------------------- shared
  /// Layer 2 lines. For [CoachNoteVariant.note] the engine's `steps` are used
  /// instead and this list is ignored.
  final List<String> mathLines;

  /// Layer 3 lines, rendered as bullets.
  final List<String> expertLines;

  /// Settings → Coach → "Always expand 'Show me the math'" (§4.8). Layer 3
  /// never auto-expands.
  final bool alwaysExpandMath;

  /// Fired whenever a disclosure row opens or closes — the sheet grows to L.
  final ValueChanged<bool>? onDisclosureToggle;

  final void Function(String termId)? onOpenGlossary;
  final bool enableHaptics;
  final bool reducedMotion;

  /// "Pre-flop" / "Flop" / "Turn" / "River" from a board length.
  static String streetLabel(List<String> board) => switch (board.length) {
    0 => 'Pre-flop',
    3 => 'Flop',
    4 => 'Turn',
    _ => 'River',
  };

  /// "Q♠ Q♥" — the text fallback when no [cardBuilder] is supplied.
  static String cardsText(List<String> cards) => cards
      .map((c) => c.length < 2 ? c : '${c[0]}${kSuitSymbol[c[1]] ?? c[1]}')
      .join(' ');

  /// The §4.8 chip clause: the first sentence of layer 1, ellipsised by the
  /// caller's `Text` widget rather than here.
  static String firstClause(String text) {
    var cut = text.length;
    for (final marker in const [' — ', '; ', '. ']) {
      final at = text.indexOf(marker);
      if (at > 0 && at < cut) cut = at;
    }
    var clause = text.substring(0, cut).trim();
    while (clause.endsWith('.') || clause.endsWith(';')) {
      clause = clause.substring(0, clause.length - 1).trimRight();
    }
    return clause;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._header(context, c),
        ..._layerOne(context, c),
        ..._middle(context, c),
        const SizedBox(height: AllInSpace.sm),
        _mathRow(context),
        _expertRow(context),
        ..._footer(context, c),
      ],
    );
  }

  // -------------------------------------------------------------- header

  List<Widget> _header(BuildContext context, AllInColors c) {
    switch (variant) {
      case CoachNoteVariant.note:
        final r = review!;
        final read = r.kind == ReviewKind.bot;
        final tone = VerdictBadge.colorOf(r.verdict, c);
        final line2 =
            '${read ? 'Bot read' : 'EV Coach'} · ${r.title} · '
            '${streetLabel(r.board)}';
        return [
          Container(
            padding: const EdgeInsets.all(AllInSpace.md),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VerdictBadge(
                  verdict: r.verdict,
                  size: VerdictBadge.large,
                  read: read,
                ),
                const SizedBox(width: AllInSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        VerdictBadge.labelOf(r.verdict, read: read),
                        style: AllInText.body(
                          17,
                          weight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line2,
                        style: AllInText.body(13, color: c.textMuted),
                      ),
                      ..._headerCards(context, c, r.board),
                      if (situation != null && situation!.isNotEmpty) ...[
                        const SizedBox(height: AllInSpace.xs),
                        Text(
                          situation!,
                          style: AllInText.body(13, color: c.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.md),
        ];
      case CoachNoteVariant.drill:
        final isCorrect = correct ?? false;
        final tone = isCorrect ? c.good : c.bad;
        final delta = ratingDelta;
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              VerdictBadge(
                verdict: isCorrect ? Verdict.great : Verdict.mistake,
                size: VerdictBadge.medium,
              ),
              const SizedBox(width: AllInSpace.md),
              Expanded(
                child: Text(
                  verdictLabel ?? '',
                  style: AllInText.body(
                    17,
                    weight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
              if (delta != null)
                Text(
                  delta >= 0 ? '+$delta' : '$delta',
                  style: AllInText.mono(15, color: delta >= 0 ? c.good : c.bad),
                ),
            ],
          ),
          if (evLossLine != null && evLossLine!.isNotEmpty) ...[
            const SizedBox(height: AllInSpace.sm),
            Text(evLossLine!, style: AllInText.body(15, color: c.bad)),
          ],
          const SizedBox(height: AllInSpace.md),
          Container(height: 1, color: c.line),
          const SizedBox(height: AllInSpace.md),
        ];
      case CoachNoteVariant.peek:
        return const [];
    }
  }

  List<Widget> _headerCards(
    BuildContext context,
    AllInColors c,
    List<String> board,
  ) {
    if (heroCards.isEmpty && board.isEmpty) return const [];
    if (cardBuilder == null) {
      final hero = cardsText(heroCards);
      final rest = cardsText(board);
      final text =
          hero.isEmpty
              ? rest
              : rest.isEmpty
              ? hero
              : '$hero  on  $rest';
      return [
        const SizedBox(height: AllInSpace.sm),
        Text(text, style: AllInText.mono(13, color: c.text)),
      ];
    }
    final build = cardBuilder!;
    return [
      const SizedBox(height: AllInSpace.sm),
      Wrap(
        spacing: 3,
        runSpacing: AllInSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final card in heroCards) build(context, card, 22),
          if (heroCards.isNotEmpty && board.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.xs),
              child: Text('on', style: AllInText.body(12, color: c.textMuted)),
            ),
          for (final card in board) build(context, card, 22),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------- layer 1

  List<Widget> _layerOne(BuildContext context, AllInColors c) {
    switch (variant) {
      case CoachNoteVariant.note:
        final r = review!;
        return [
          Text(
            r.plain ?? r.text,
            style: AllInText.body(17, color: c.text, height: 1.45),
          ),
        ];
      case CoachNoteVariant.drill:
        return [
          Text(
            rationale ?? '',
            style: AllInText.body(17, color: c.text, height: 1.45),
          ),
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
        ];
      case CoachNoteVariant.peek:
        final g = grade!;
        return [
          Text(
            gradeLabel ?? g.label,
            style: AllInText.display(34, color: g.color(c)),
          ),
          const SizedBox(height: AllInSpace.sm),
          for (final line in plainLines)
            Padding(
              padding: const EdgeInsets.only(bottom: AllInSpace.sm),
              child: Text(
                line,
                style: AllInText.body(15, color: c.text, height: 1.45),
              ),
            ),
        ];
    }
  }

  // ------------------------------------------- equity bar + multiway callout

  List<Widget> _middle(BuildContext context, AllInColors c) {
    if (variant != CoachNoteVariant.note) return const [];
    final r = review!;
    final widgets = <Widget>[];
    if (r.equity != null) {
      widgets
        ..add(const SizedBox(height: AllInSpace.lg))
        ..add(
          EquityBar(
            equity: r.equity!,
            potOdds: r.potOdds,
            villainName: r.villainName,
            color: VerdictBadge.colorOf(r.verdict, c),
            onOpenGlossary: onOpenGlossary,
            reducedMotion: reducedMotion,
          ),
        );
    }
    if (r.multiway == true) {
      widgets
        ..add(const SizedBox(height: AllInSpace.md))
        ..add(
          Container(
            padding: const EdgeInsets.all(AllInSpace.md),
            decoration: BoxDecoration(
              color: c.warn.withValues(alpha: 0.10),
              border: Border.all(color: c.warn.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: c.warn),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    CoachCopy.multiway(r.opponents ?? 0),
                    style: AllInText.body(14, color: c.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
    }
    return widgets;
  }

  // ------------------------------------------------------ layers 2 and 3

  /// Both rows are keyed on the note so disclosure state is never remembered
  /// between notes (§4.8) — plain English first, always.
  String get _noteKey => switch (variant) {
    CoachNoteVariant.note => 'note-${review!.id}',
    CoachNoteVariant.drill => 'drill-${rationale.hashCode}',
    CoachNoteVariant.peek => 'peek-${grade!.name}',
  };

  Widget _mathRow(BuildContext context) {
    final lines = _mathLines();
    final placeholder = _mathPlaceholder();
    return DisclosureRow(
      key: ValueKey('math-$_noteKey'),
      label: CoachCopy.showMath,
      expandedLabel: CoachCopy.hideMath,
      initiallyExpanded: alwaysExpandMath,
      onToggle: onDisclosureToggle,
      enableHaptics: enableHaptics,
      reducedMotion: reducedMotion,
      child:
          lines.isEmpty
              ? _Placeholder(placeholder)
              : _NumberedSteps(steps: lines),
    );
  }

  Widget _expertRow(BuildContext context) {
    final lines = _expertLines();
    final extra = expertChild;
    return DisclosureRow(
      key: ValueKey('expert-$_noteKey'),
      label: CoachCopy.expertDetail,
      expandedLabel: CoachCopy.hideExpert,
      tone: DisclosureTone.muted,
      onToggle: onDisclosureToggle,
      enableHaptics: enableHaptics,
      reducedMotion: reducedMotion,
      child:
          lines.isEmpty && extra == null
              ? _Placeholder(CoachCopy.nothingExtra)
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lines.isNotEmpty) _Bullets(lines: lines),
                  if (extra != null) ...[
                    if (lines.isNotEmpty) const SizedBox(height: AllInSpace.md),
                    extra,
                  ],
                ],
              ),
    );
  }

  List<String> _mathLines() {
    if (variant != CoachNoteVariant.note) return mathLines;
    return review!.steps ?? const <String>[];
  }

  String _mathPlaceholder() => switch (variant) {
    CoachNoteVariant.note =>
      review!.kind == ReviewKind.bot
          ? CoachCopy.noMathRead
          : CoachCopy.noMathVerdict,
    CoachNoteVariant.drill => CoachCopy.noMathChartSpot,
    CoachNoteVariant.peek => CoachCopy.noMathDefinition,
  };

  List<String> _expertLines() {
    if (variant != CoachNoteVariant.note) return expertLines;
    final r = review!;
    return [
      // Desktop order: the layer-2 line moves here when `plain` exists.
      if (r.plain != null && r.text.isNotEmpty) r.text,
      ...?r.expert,
    ];
  }

  // -------------------------------------------------- EV tile + buttons

  List<Widget> _footer(BuildContext context, AllInColors c) {
    final widgets = <Widget>[];
    if (variant == CoachNoteVariant.note && review!.evChips != null) {
      final bb = bigBlind == 0 ? 1.0 : bigBlind;
      final ev = review!.evChips! / bb;
      final tone =
          ev < -0.05
              ? c.bad
              : ev > 0.05
              ? c.good
              : c.textMuted;
      widgets
        ..add(const SizedBox(height: AllInSpace.sm))
        ..add(
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.md,
              vertical: AllInSpace.sm,
            ),
            decoration: BoxDecoration(
              color: c.ink700,
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    CoachCopy.expectedValue,
                    style: AllInText.body(14, color: c.textMuted),
                  ),
                ),
                Text(
                  '${fmtSigned(ev)} bb',
                  style: AllInText.mono(15, color: tone),
                ),
              ],
            ),
          ),
        );
    }

    if (footerCaption != null && footerCaption!.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: AllInSpace.md))
        ..add(
          Text(footerCaption!, style: AllInText.body(13, color: c.textFaint)),
        );
    }

    final buttons = _buttons(context);
    if (buttons != null) {
      widgets
        ..add(const SizedBox(height: AllInSpace.md))
        ..add(buttons);
    }
    return widgets;
  }

  Widget? _buttons(BuildContext context) {
    if (variant != CoachNoteVariant.note) return actions;
    final showRange =
        onViewRange != null && (review!.villainRange?.isNotEmpty ?? false);
    final showDismiss = onDismiss != null;
    if (!showRange && !showDismiss) return null;
    return Row(
      children: [
        if (showRange)
          Expanded(
            child: AllInButton.secondary(
              label: CoachCopy.viewRange,
              leading: Icons.visibility_outlined,
              onPressed: onViewRange,
              expand: true,
              enableHaptics: enableHaptics,
              reducedMotion: reducedMotion,
            ),
          ),
        if (showRange && showDismiss) const SizedBox(width: AllInSpace.md),
        if (showDismiss)
          Expanded(
            child:
                blocking
                    ? AllInButton.primary(
                      label: dismissLabel ?? CoachCopy.gotIt,
                      onPressed: onDismiss,
                      expand: true,
                      enableHaptics: enableHaptics,
                      reducedMotion: reducedMotion,
                    )
                    : AllInButton.ghost(
                      label: dismissLabel ?? CoachCopy.close,
                      onPressed: onDismiss,
                      expand: true,
                      enableHaptics: enableHaptics,
                      reducedMotion: reducedMotion,
                    ),
          ),
      ],
    );
  }
}

/// Layer 2's numbered derivation: mono numbers, 2 pt left rule in `line`.
class _NumberedSteps extends StatelessWidget {
  const _NumberedSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(left: AllInSpace.md),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.line, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == steps.length - 1 ? 0 : AllInSpace.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: AllInText.mono(13, color: c.textFaint),
                  ),
                  const SizedBox(width: AllInSpace.sm),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: AllInText.body(15, color: c.text, height: 1.4),
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

/// Layer 3's bullet list.
class _Bullets extends StatelessWidget {
  const _Bullets({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == lines.length - 1 ? 0 : AllInSpace.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: AllInText.body(15, color: c.textFaint)),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    lines[i],
                    style: AllInText.body(15, color: c.textMuted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The written line a disclosure row opens to when there is nothing behind it
/// (§14 — never blank space).
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AllInText.body(15, color: context.colors.textMuted, height: 1.4),
  );
}
