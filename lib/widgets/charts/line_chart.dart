/// `LineChart` — cumulative winnings (DESIGN.md §10.1, §7.3): 170 pt tall, area
/// gradient, dashed zero line, last-point dot, min/max labels.
///
/// **Scrub**: a `LongPressGestureRecognizer` with a 200 ms deadline sits in the
/// gesture arena. Before it wins, a vertical drag scrolls the enclosing page
/// exactly as anywhere else; once it wins it holds the pointer until it lifts,
/// so the page cannot slide out from under a scrubbing thumb (§7.3, §12). A
/// plain tap or a flick does nothing at all. `selectionClick` fires on entering
/// the scrub and again on every data point crossed.
///
/// Fewer than two values renders the verbatim empty line instead of a chart.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/format.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.values,
    this.height = 170,
    this.color,
    this.labelBuilder,
    this.onScrub,
    this.emptyText = 'Play a few hands to see your trend.',
    this.showZeroLine = true,
    this.showExtremes = true,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  });

  /// Cumulative big blinds, oldest first.
  final List<double> values;

  final double height;

  /// Defaults to `gold`.
  final Color? color;

  /// The floating label's text — "Hand 212 · +31.5 bb" by default.
  final String Function(int index, double value)? labelBuilder;

  /// Index under the finger, or null when the scrub ends.
  final ValueChanged<int?>? onScrub;

  /// §7.3's verbatim empty line (fewer than two values).
  final String emptyText;

  final bool showZeroLine;
  final bool showExtremes;
  final bool enableHaptics;

  /// No draw-in animation (§7.3).
  final bool reducedMotion;

  final String? semanticLabel;

  static const Duration holdToScrub = Duration(milliseconds: 200);

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: AllInMotion.slide,
  );
  bool _started = false;
  int? _index;
  double _plotWidth = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _draw.duration = AllInMotion.of(
      context,
      AllInMotion.slide,
      reduced: widget.reducedMotion,
    );
    if (!_started) {
      _started = true;
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  int _indexAt(double dx) {
    final n = widget.values.length;
    if (n < 2 || _plotWidth <= 0) return 0;
    final t = (dx / _plotWidth).clamp(0.0, 1.0);
    return (t * (n - 1)).round().clamp(0, n - 1);
  }

  void _setIndex(int? next) {
    if (_index == next) return;
    if (next != null && widget.enableHaptics) HapticFeedback.selectionClick();
    setState(() => _index = next);
    widget.onScrub?.call(next);
  }

  String _label(int index) {
    final value = widget.values[index];
    return widget.labelBuilder?.call(index, value) ??
        'Hand ${index + 1} · ${fmtSigned(value)} bb';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = widget.color ?? c.gold;

    if (widget.values.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            widget.emptyText,
            textAlign: TextAlign.center,
            style: AllInText.body(14, color: c.textMuted),
          ),
        ),
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? _summary(),
      child: ExcludeSemantics(
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
              LongPressGestureRecognizer
            >(
              () => LongPressGestureRecognizer(
                duration: LineChart.holdToScrub,
                debugOwner: this,
              ),
              (recognizer) {
                recognizer.onLongPressStart =
                    (d) => _setIndex(_indexAt(d.localPosition.dx));
                recognizer.onLongPressMoveUpdate =
                    (d) => _setIndex(_indexAt(d.localPosition.dx));
                recognizer.onLongPressEnd = (_) => _setIndex(null);
                recognizer.onLongPressCancel = () => _setIndex(null);
              },
            ),
          },
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _plotWidth = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _draw,
                  builder:
                      (context, _) => CustomPaint(
                        painter: _LineChartPainter(
                          values: widget.values,
                          progress:
                              _draw.duration == Duration.zero ? 1 : _draw.value,
                          color: tone,
                          zeroColor: c.line,
                          textColor: c.textFaint,
                          crosshairColor: c.text,
                          labelBackground: c.ink700,
                          labelBorder: c.lineStrong,
                          index: _index,
                          label: _index == null ? null : _label(_index!),
                          showZeroLine: widget.showZeroLine,
                          showExtremes: widget.showExtremes,
                          textDirection: Directionality.of(context),
                        ),
                      ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _summary() {
    final last = widget.values.last;
    return 'Cumulative winnings, ${widget.values.length} hands, '
        'now ${fmtSigned(last)} big blinds';
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.zeroColor,
    required this.textColor,
    required this.crosshairColor,
    required this.labelBackground,
    required this.labelBorder,
    required this.index,
    required this.label,
    required this.showZeroLine,
    required this.showExtremes,
    required this.textDirection,
  });

  final List<double> values;
  final double progress;
  final Color color;
  final Color zeroColor;
  final Color textColor;
  final Color crosshairColor;
  final Color labelBackground;
  final Color labelBorder;
  final int? index;
  final String? label;
  final bool showZeroLine;
  final bool showExtremes;
  final TextDirection textDirection;

  static const double _inset = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || values.length < 2) return;

    var min = 0.0;
    var max = 0.0;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    if ((max - min).abs() < 1e-9) {
      min -= 1;
      max += 1;
    }
    final usable = size.height - _inset * 2;
    double xOf(int i) => i / (values.length - 1) * size.width;
    double yOf(double v) => _inset + (1 - (v - min) / (max - min)) * usable;

    // Dashed zero line.
    if (showZeroLine && min <= 0 && max >= 0) {
      final y = yOf(0);
      final paint =
          Paint()
            ..color = zeroColor
            ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
      }
    }

    final shown = (values.length * progress).ceil().clamp(2, values.length);
    final path = Path()..moveTo(xOf(0), yOf(values.first));
    for (var i = 1; i < shown; i++) {
      path.lineTo(xOf(i), yOf(values[i]));
    }

    // Area gradient under the line.
    final area =
        Path.from(path)
          ..lineTo(xOf(shown - 1), size.height)
          ..lineTo(xOf(0), size.height)
          ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Last-point dot.
    canvas.drawCircle(
      Offset(xOf(shown - 1), yOf(values[shown - 1])),
      3,
      Paint()..color = color,
    );

    if (showExtremes) {
      _text(canvas, fmtSigned(max), const Offset(0, 0), textColor);
      _text(canvas, fmtSigned(min), Offset(0, size.height - 12), textColor);
    }

    final i = index;
    if (i != null && i >= 0 && i < values.length) {
      final x = xOf(i);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = crosshairColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, yOf(values[i])), 4, Paint()..color = color);
      if (label != null) _floatingLabel(canvas, size, x, label!);
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: AllInText.mono(10, color: color)),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, at);
  }

  void _floatingLabel(Canvas canvas, Size size, double x, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AllInText.mono(12, color: crosshairColor),
      ),
      textDirection: textDirection,
    )..layout();
    const padding = 8.0;
    final width = painter.width + padding * 2;
    final height = painter.height + padding;
    final left = (x - width / 2).clamp(
      0.0,
      (size.width - width).clamp(0.0, size.width),
    );
    final rect = Rect.fromLTWH(left, 0, width, height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(AllInRadius.sm),
    );
    canvas
      ..drawRRect(rrect, Paint()..color = labelBackground)
      ..drawRRect(
        rrect,
        Paint()
          ..color = labelBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    painter.paint(canvas, Offset(left + padding, padding / 2));
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.progress != progress ||
      old.index != index ||
      old.label != label ||
      old.color != color ||
      !identical(old.values, values);
}
