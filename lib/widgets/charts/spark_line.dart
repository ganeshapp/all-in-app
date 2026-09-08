/// `SparkLine` — the smallest chart primitive (DESIGN.md §10.1, §7.3): a bare
/// polyline with no axes, used for the drill rating trend and any inline
/// "where is this going?" glance.
///
/// It renders at any length: empty draws the baseline alone, one value draws a
/// dot, hundreds are decimated by the painter's stroke rather than by dropping
/// points. Shape carries the meaning, so it stays readable in both themes and
/// without colour (§13).
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class SparkLine extends StatelessWidget {
  const SparkLine({
    super.key,
    required this.values,
    this.height = 32,
    this.color,
    this.strokeWidth = 1.5,
    this.filled = false,
    this.semanticLabel,
  });

  final List<double> values;
  final double height;

  /// Defaults to `gold` — a trend line is the accent, not a verdict (§16.5).
  final Color? color;

  final double strokeWidth;

  /// Fills the area under the line at 18 % of [color].
  final bool filled;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final line = color ?? c.gold;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparkLinePainter(
              values: values,
              color: line,
              trackColor: c.line,
              strokeWidth: strokeWidth,
              filled: filled,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkLinePainter extends CustomPainter {
  _SparkLinePainter({
    required this.values,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.filled,
  });

  final List<double> values;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (values.isEmpty) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        Paint()
          ..color = trackColor
          ..strokeWidth = 1,
      );
      return;
    }

    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    if (values.length == 1) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        strokeWidth + 0.5,
        Paint()..color = color,
      );
      return;
    }

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;
    final inset = strokeWidth;
    final usable = size.height - inset * 2;

    double xOf(int i) => i / (values.length - 1) * size.width;
    double yOf(double v) => inset + (1 - (v - min) / span) * usable;

    final path = Path()..moveTo(xOf(0), yOf(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xOf(i), yOf(values[i]));
    }

    if (filled) {
      final area =
          Path.from(path)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.18));
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_SparkLinePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled ||
      !identical(old.values, values);
}
