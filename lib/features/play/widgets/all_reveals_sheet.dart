/// P9 · All reveals — the 9-max overflow of the results card (DESIGN.md §4.12,
/// §2.2 "sheet L").
///
/// The card on the felt shows the first rows and an "All 8 hands ›" row; this
/// sheet is the same list with nothing hidden. Tapping a row returns that
/// seat, so the caller can open P6 for it exactly as a card row would.
///
/// `AllInSheet` already wraps its child in a scroll view, so the body is a
/// `Column` — never a `ListView` (unbounded height inside a sheet).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AllRevealsSheet extends StatelessWidget {
  const AllRevealsSheet({
    super.key,
    required this.rows,
    this.fourColorDeck = false,
    this.onRow,
  });

  /// The same rows the card renders, in seat order.
  final List<RevealRow> rows;
  final bool fourColorDeck;
  final ValueChanged<int>? onRow;

  /// Sheet L (§2.2). Returns the tapped seat, or null.
  static Future<int?> show(
    BuildContext context, {
    required List<RevealRow> rows,
    bool fourColorDeck = false,
    bool reducedMotion = false,
  }) => AllInSheet.show<int>(
    context,
    detent: AllInSheetDetent.l,
    reducedMotion: reducedMotion,
    maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
    builder:
        (sheetContext) => AllRevealsSheet(
          rows: rows,
          fourColorDeck: fourColorDeck,
          onRow: (seat) => Navigator.of(sheetContext).pop(seat),
        ),
  );

  static const String title = 'Everyone’s cards';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AllInSpace.md),
              child: Text(
                'Nobody else was dealt in.',
                style: AllInText.body(13, color: c.textMuted),
              ),
            ),
          for (final row in rows) ...[
            Divider(height: 1, thickness: 1, color: c.line),
            AllRevealTile(
              row: row,
              fourColorDeck: fourColorDeck,
              onTap: onRow == null ? null : () => onRow!(row.playerId),
            ),
          ],
        ],
      ),
    );
  }
}

/// One reveal row outside the card: XS cards · name · the verbatim
/// `revealNote()`. The card's own row is private to `ResultsCard` (§10.3), so
/// this is the sheet's copy of the same anatomy at a comfortable 56 pt.
class AllRevealTile extends StatelessWidget {
  const AllRevealTile({
    super.key,
    required this.row,
    this.fourColorDeck = false,
    this.onTap,
  });

  final RevealRow row;
  final bool fourColorDeck;
  final VoidCallback? onTap;

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
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AllInSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(width: AllInSpace.sm),
                  SizedBox(
                    width: 64,
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
                  const SizedBox(width: AllInSpace.xs),
                  Expanded(
                    child: Text(
                      row.note,
                      style: AllInText.body(13, color: c.textMuted),
                    ),
                  ),
                  if (onTap != null)
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
