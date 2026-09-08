/// `DivergingBar` — the 8 pt bar in Stats' "Winnings by position" rows and any
/// signed-money row (DESIGN.md §10.1, §7.4).
///
/// The **direction** carries the sign (right = won, left = lost), so the row
/// reads without colour (§13); the caller always prints the signed number
/// beside it. `good` / `bad` by sign, `textMuted` at zero (§16.5).
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class DivergingBar extends StatelessWidget {
  const DivergingBar({
    super.key,
    required this.value,
    required this.max,
    this.height = 8,
    this.positiveColor,
    this.negativeColor,
    this.trackColor,
    this.color,
    this.showCentreLine = true,
    this.semanticLabel,
  });

  /// Signed magnitude in the caller's own unit (bb, chips…).
  final double value;

  /// The largest absolute value in the group — the full half-width.
  final double max;

  final double height;
  final Color? positiveColor;
  final Color? negativeColor;
  final Color? trackColor;

  /// Overrides both sign colours — the archetype-tinted "hands vs each style"
  /// rows pass their own tint here.
  final Color? color;

  final bool showCentreLine;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone =
        color ??
        (value > 0
            ? (positiveColor ?? c.good)
            : value < 0
            ? (negativeColor ?? c.bad)
            : c.textMuted);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _DivergingBarPainter(
              value: value,
              max: max,
              color: tone,
              trackColor: trackColor ?? c.ink700,
              centreColor: c.lineStrong,
              showCentreLine: showCentreLine,
            ),
          ),
        ),
      ),
    );
  }
}

class _DivergingBarPainter extends CustomPainter {
  _DivergingBarPainter({
    required this.value,
    required this.max,
    required this.color,
    required this.trackColor,
    required this.centreColor,
    required this.showCentreLine,
  });

  final double value;
  final double max;
  final Color color;
  final Color trackColor;
  final Color centreColor;
  final bool showCentreLine;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = trackColor,
    );

    final centre = size.width / 2;
    final span = max.abs() < 1e-9 ? 1.0 : max.abs();
    final fraction = (value / span).clamp(-1.0, 1.0);
    final extent = fraction.abs() * centre;
    if (extent > 0.5) {
      final rect =
          fraction >= 0
              ? Rect.fromLTRB(centre, 0, centre + extent, size.height)
              : Rect.fromLTRB(centre - extent, 0, centre, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color,
      );
    }

    if (showCentreLine) {
      canvas.drawLine(
        Offset(centre, 0),
        Offset(centre, size.height),
        Paint()
          ..color = centreColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_DivergingBarPainter old) =>
      old.value != value ||
      old.max != max ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.showCentreLine != showCentreLine;
}
