/// `RangeLegend` — the swatch row under a `RangeMatrix` (DESIGN.md §10.4).
///
/// Two modes: the painter's Pairs / Suited / Offsuit (§4.9) and the peek /
/// grading Correct / Missed / Extra (§4.9 "Compare mode colours"). When the OS
/// asks to differentiate without colour the swatches carry the same hatching
/// and dots the grid does (§13).
library;

import 'package:flutter/material.dart';

import '../../engine/notation.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'range_matrix.dart';

enum RangeLegendMode { kind, compare }

class RangeLegend extends StatelessWidget {
  const RangeLegend({
    super.key,
    this.mode = RangeLegendMode.kind,
    this.hatchWhenNoColour = false,
    this.trailing,
  });

  final RangeLegendMode mode;
  final bool hatchWhenNoColour;

  /// Optional right-hand text — the live counter on P7, "Their range: 312
  /// combos" on the reveal (§4.9).
  final Widget? trailing;

  static const double swatch = 12;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hatch = hatchWhenNoColour || MediaQuery.highContrastOf(context);
    final items = <_LegendItem>[
      if (mode == RangeLegendMode.kind) ...<_LegendItem>[
        _LegendItem(
          'Pairs',
          RangeMatrix.kindColor(c, ComboKind.pair),
          RangeCellState.painted,
          ComboKind.pair,
        ),
        _LegendItem(
          'Suited',
          RangeMatrix.kindColor(c, ComboKind.suited),
          RangeCellState.painted,
          ComboKind.suited,
        ),
        _LegendItem(
          'Offsuit',
          RangeMatrix.kindColor(c, ComboKind.offsuit),
          RangeCellState.painted,
          ComboKind.offsuit,
        ),
      ] else ...<_LegendItem>[
        _LegendItem('Correct', c.good, RangeCellState.correct, ComboKind.pair),
        _LegendItem('Missed', c.warn, RangeCellState.missed, ComboKind.pair),
        _LegendItem('Extra', c.bad, RangeCellState.extra, ComboKind.pair),
      ],
    ];

    return Semantics(
      container: true,
      child: Row(
        children: <Widget>[
          for (final item in items) ...<Widget>[
            _Swatch(item: item, hatch: hatch),
            const SizedBox(width: AllInSpace.xs + 2),
            Text(item.label, style: AllInText.body(11.5, color: c.textMuted)),
            const SizedBox(width: AllInSpace.md),
          ],
          if (trailing != null) Expanded(child: trailing!),
        ],
      ),
    );
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color, this.state, this.kind);
  final String label;
  final Color color;
  final RangeCellState state;
  final ComboKind kind;
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.item, required this.hatch});

  final _LegendItem item;
  final bool hatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: RangeLegend.swatch,
      height: RangeLegend.swatch,
      child: CustomPaint(
        painter: _SwatchPainter(
          fill: item.color,
          ink: RangeMatrix.labelColor(c, item.state, item.color),
          hatched:
              hatch &&
              (item.state == RangeCellState.missed ||
                  (item.state == RangeCellState.painted &&
                      item.kind == ComboKind.suited)),
          dotted:
              hatch &&
              (item.state == RangeCellState.extra ||
                  (item.state == RangeCellState.painted &&
                      item.kind == ComboKind.offsuit)),
        ),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.fill,
    required this.ink,
    required this.hatched,
    required this.dotted,
  });

  final Color fill;
  final Color ink;
  final bool hatched;
  final bool dotted;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = fill,
    );
    if (!hatched && !dotted) return;
    final paint =
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..strokeWidth = 1;
    if (hatched) {
      canvas.save();
      canvas.clipRect(rect);
      for (var x = -size.height; x < size.width; x += 4) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
      }
      canvas.restore();
    } else {
      canvas.drawCircle(rect.center, 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.fill != fill ||
      old.ink != ink ||
      old.hatched != hatched ||
      old.dotted != dotted;
}
