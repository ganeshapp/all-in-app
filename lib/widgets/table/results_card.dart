/// `ResultsCard` — the hand-over overlay over the lower felt (DESIGN.md §10.3;
/// anatomy, coach row and collapse rules §4.12).
///
/// The card's band never moves: the 44 pt coach row comes out of the scrolling
/// reveal list, not out of the card's height, and the collapse hides the
/// reveals, never the verdict.
library;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'coach_chip.dart';
import 'playing_card_view.dart';

/// The card's header: the hero's net, the caption and the result sentence.
class ResultsSummary {
  const ResultsSummary({
    required this.netBb,
    required this.caption,
    required this.sentence,
  });

  /// The hero's net for the hand, in big blinds.
  final double netBb;

  /// "You won the pot" | "Hand over" *(desktop)*.
  final String caption;

  /// "{names} wins with {hand}." | "{names} takes it down."
  final String sentence;
}

/// One reveal row: XS cards, the seat's name and the verbatim `revealNote()`.
class RevealRow {
  const RevealRow({
    required this.playerId,
    required this.name,
    required this.cards,
    required this.note,
    this.faceDown = false,
    this.folded = false,
    this.readLabel,
  });

  final int playerId;
  final String name;
  final List<String> cards;

  /// `revealNote()`, verbatim.
  final String note;

  /// Realistic reveals: a folded seat keeps its cards face-down (§4.12).
  final bool faceDown;
  final bool folded;

  /// "Your read 64 %" — the link into the compare grid (§4.9).
  final String? readLabel;
}

class ResultsCard extends StatelessWidget {
  const ResultsCard({
    super.key,
    required this.summary,
    required this.rows,
    this.onRow,
    this.onReadSeat,
    this.coach,
    this.onCoachTap,
    this.collapsed = false,
    this.onExpand,
    this.moreLabel,
    this.onMore,
    this.onTouch,
    this.fourColorDeck = false,
    this.reducedMotion = false,
  });

  final ResultsSummary summary;
  final List<RevealRow> rows;

  /// Tap a reveal row → P6 for that seat.
  final ValueChanged<int>? onRow;

  /// Tap the read link → the compare grid (§4.9).
  final ValueChanged<int>? onReadSeat;

  /// The verdict for this hand's last hero action, if one exists and has not
  /// been acknowledged (§4.12).
  final CoachChipContent? coach;
  final VoidCallback? onCoachTap;

  /// The one-line strip form after three quick "Next hand" taps (§4.12).
  final bool collapsed;
  final VoidCallback? onExpand;

  /// "All 8 hands ›" at 9-max → P9.
  final String? moreLabel;
  final VoidCallback? onMore;

  /// Touching the card cancels the auto-deal countdown (§4.12).
  final VoidCallback? onTouch;
  final bool fourColorDeck;
  final bool reducedMotion;

  static const double coachRowHeight = 44;
  static const double collapsedHeight = 44;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.ink800.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AllInRadius.lg),
        border: Border.all(color: c.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AllInColors.dark.shadowColor.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (coach != null) ...[
            _CoachRow(content: coach!, onTap: onCoachTap),
            Divider(height: 1, thickness: 1, color: c.line),
          ],
          if (collapsed)
            _CollapsedStrip(summary: summary, onTap: onExpand)
          else ...[
            _Header(summary: summary),
            Divider(height: 1, thickness: 1, color: c.line),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: rows.length + (moreLabel == null ? 0 : 1),
                separatorBuilder:
                    (context, _) =>
                        Divider(height: 1, thickness: 1, color: c.line),
                itemBuilder: (context, index) {
                  if (index >= rows.length) {
                    return _MoreRow(label: moreLabel!, onTap: onMore);
                  }
                  final row = rows[index];
                  return _RevealRowView(
                    row: row,
                    fourColorDeck: fourColorDeck,
                    onTap: onRow == null ? null : () => onRow!(row.playerId),
                    onRead:
                        onReadSeat == null || row.readLabel == null
                            ? null
                            : () => onReadSeat!(row.playerId),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );

    final animated = AnimatedSize(
      duration: AllInMotion.of(
        context,
        const Duration(milliseconds: 200),
        reduced: reducedMotion,
      ),
      curve: AllInMotion.ease,
      alignment: Alignment.topCenter,
      child: card,
    );

    if (onTouch == null) return animated;
    return Listener(onPointerDown: (_) => onTouch!(), child: animated);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final ResultsSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final net = summary.netBb;
    final tone =
        net > 0
            ? c.good
            : net < 0
            ? c.bad
            : c.textMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.md,
        AllInSpace.md,
        AllInSpace.md,
        AllInSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${fmtSigned(net)} bb',
                style: AllInText.display(24, color: tone, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                summary.caption.toUpperCase(),
                style: AllInText.eyebrow(c.textMuted),
              ),
            ],
          ),
          const SizedBox(width: AllInSpace.md),
          Expanded(
            child: Text(
              summary.sentence,
              style: AllInText.body(14, color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedStrip extends StatelessWidget {
  const _CollapsedStrip({required this.summary, this.onTap});

  final ResultsSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final net = summary.netBb;
    final tone =
        net > 0
            ? c.good
            : net < 0
            ? c.bad
            : c.textMuted;

    return Semantics(
      button: true,
      label:
          '${fmtSigned(net)} big blinds, ${summary.caption}, '
          "see everyone's cards",
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: ResultsCard.collapsedHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
              child: Row(
                children: [
                  Text(
                    '${fmtSigned(net)} bb',
                    style: AllInText.mono(15, color: tone),
                  ),
                  const SizedBox(width: AllInSpace.sm),
                  Expanded(
                    child: Text(
                      '· ${summary.caption} · See everyone’s cards',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.body(13, color: c.textMuted),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: c.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({required this.content, this.onTap});

  final CoachChipContent content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = CoachChip.verdictColor(context, content.verdict);
    final label = CoachChip.verdictLabel(content.verdict);
    final clause = content.clause ?? content.title ?? '';

    return Semantics(
      button: true,
      liveRegion: true,
      label: [label, if (clause.isNotEmpty) clause].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: ResultsCard.coachRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
            color: tone.withValues(alpha: 0.10),
            child: Row(
              children: [
                VerdictDisc(verdict: content.verdict, size: 24),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    clause.isEmpty ? label : '$label · $clause',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(13, color: c.text),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealRowView extends StatelessWidget {
  const _RevealRowView({
    required this.row,
    required this.fourColorDeck,
    this.onTap,
    this.onRead,
  });

  final RevealRow row;
  final bool fourColorDeck;
  final VoidCallback? onTap;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: onTap != null,
      label: '${row.name}, ${row.note}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AllInSpace.md,
                vertical: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        PlayingCardView(
                          card: i < row.cards.length ? row.cards[i] : null,
                          width: PlayingCardView.xs,
                          faceDown: row.faceDown || i >= row.cards.length,
                          dimmed: row.folded,
                          greyscale: row.folded && !row.faceDown,
                          fourColorDeck: fourColorDeck,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: AllInSpace.sm),
                  SizedBox(
                    width: 56,
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.body(
                        13,
                        weight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.note,
                          style: AllInText.body(13, color: c.textMuted),
                        ),
                        if (row.readLabel != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onRead,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    row.readLabel!,
                                    style: AllInText.body(
                                      12,
                                      weight: FontWeight.w600,
                                      color: c.gold,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 14,
                                    color: c.gold,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
              child: Row(
                children: [
                  Text(
                    label,
                    style: AllInText.body(
                      13,
                      weight: FontWeight.w600,
                      color: c.gold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.gold),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
