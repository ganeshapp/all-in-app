/// `RangeMatrixLoupe` — the magnifier bubble that floats above the fingertip
/// while a range is being painted (DESIGN.md §10.4; behaviour in §4.9
/// mechanism 3 and §6.5 "the loupe in a scroll view").
///
/// It is a dumb renderer: `RangeMatrix` owns the finger tracking and hands it a
/// 3×3 neighbourhood plus a colour resolver. Shown under reduced motion too —
/// it is magnification, not motion.
library;

import 'package:flutter/material.dart';

import '../../engine/notation.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class RangeMatrixLoupe extends StatelessWidget {
  const RangeMatrixLoupe({
    super.key,
    required this.row,
    required this.col,
    required this.fillFor,
    this.size = 56,
    this.label,
  });

  /// The cell under the finger (0..12 each; the 3×3 window is centred on it and
  /// clamped to the grid).
  final int row;
  final int col;

  /// Fill colour for a neighbour cell, as the matrix would paint it.
  final Color Function(int row, int col) fillFor;

  /// Width of the bubble; the label line adds [labelHeight] below it.
  final double size;

  /// Defaults to `labelAt(row, col)`.
  final String? label;

  static const double labelHeight = 20;
  static const double _pad = 4;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // −2 for the container's 1 pt border on each side.
    final cell = (size - _pad * 2 - _gap * 2 - 2) / 3;
    final text = label ?? labelAt(row, col);
    final startRow = row.clamp(1, 11) - 1;
    final startCol = col.clamp(1, 11) - 1;

    return ExcludeSemantics(
      child: Container(
        width: size,
        decoration: BoxDecoration(
          color: c.ink800,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          border: Border.all(color: c.lineStrong),
          boxShadow: [
            BoxShadow(
              color: c.shadowColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(_pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < 3; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var k = 0; k < 3; k++) ...[
                    if (k > 0) const SizedBox(width: _gap),
                    _MiniCell(
                      size: cell,
                      color: fillFor(startRow + r, startCol + k),
                      ringed:
                          startRow + r == row.clamp(0, 12) &&
                          startCol + k == col.clamp(0, 12),
                      ringColor: c.gold,
                    ),
                  ],
                ],
              ),
            ],
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Text(
                  text,
                  maxLines: 1,
                  style: AllInText.display(13, color: c.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCell extends StatelessWidget {
  const _MiniCell({
    required this.size,
    required this.color,
    required this.ringed,
    required this.ringColor,
  });

  final double size;
  final Color color;
  final bool ringed;
  final Color ringColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
      border: ringed ? Border.all(color: ringColor, width: 1.5) : null,
    ),
  );
}
