/// `CoachNotesList` — P4, "Coach notes · Hand #12" (DESIGN.md §10.5, §4.8).
///
/// 64 pt rows: verdict disc 24 · label · "{title} · {street}", then the first
/// line of layer 1 in muted text, ellipsised. Newest first. Tapping a row is
/// the host sheet's job — it replaces itself with P3.
library;

import 'package:flutter/material.dart';

import '../../engine/coach.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'coach_note_view.dart';
import 'verdict_badge.dart';

class CoachNotesList extends StatelessWidget {
  const CoachNotesList({
    super.key,
    required this.reviews,
    this.title,
    this.onTapNote,
    this.newestFirst = true,
    this.emptyText = 'Actions will appear here.',
  });

  /// The hand's `reviewLog`, in the order the engine produced it.
  final List<CoachReview> reviews;

  /// "Coach notes · Hand #12".
  final String? title;

  final ValueChanged<CoachReview>? onTapNote;

  /// §4.8 lists the notes newest first; the log arrives chronologically.
  final bool newestFirst;

  final String emptyText;

  static const double rowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ordered =
        newestFirst ? reviews.reversed.toList(growable: false) : reviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
          ),
          const SizedBox(height: AllInSpace.sm),
        ],
        if (ordered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AllInSpace.md),
            child: Text(
              emptyText,
              style: AllInText.body(15, color: c.textMuted),
            ),
          )
        else
          for (final review in ordered)
            _NoteRow(
              review: review,
              onTap: onTapNote == null ? null : () => onTapNote!(review),
            ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.review, this.onTap});

  final CoachReview review;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final read = review.kind == ReviewKind.bot;
    final tone = VerdictBadge.colorOf(review.verdict, c);
    final label = VerdictBadge.labelOf(review.verdict, read: read);
    final street = CoachNoteView.streetLabel(review.board);
    final first = CoachNoteView.firstClause(review.plain ?? review.text);

    return Semantics(
      button: onTap != null,
      label: '$label, ${review.title}, $street. $first',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CoachNotesList.rowHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AllInSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: VerdictBadge(
                      verdict: review.verdict,
                      size: VerdictBadge.small,
                      read: read,
                    ),
                  ),
                  const SizedBox(width: AllInSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              label,
                              style: AllInText.body(
                                15,
                                weight: FontWeight.w600,
                                color: tone,
                              ),
                            ),
                            const SizedBox(width: AllInSpace.sm),
                            Expanded(
                              child: Text(
                                '${review.title} · $street',
                                style: AllInText.body(15, color: c.text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '"$first"',
                          style: AllInText.body(13, color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 20, color: c.textFaint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
