/// `MiniBars` — the range-read accuracy strip (DESIGN.md §10.1, §7.3): the last
/// 30 Peek scores as bars whose height is `max(3, v × 100) %` of the band and
/// whose opacity is `0.55 + v × 0.45`, in `info`.
///
/// **A bar is never a tap target** (§7.3, §12). The whole strip is one 44 pt
/// gesture band; a 200 ms hold claims the pointer from the page scroll and a
/// mono label follows the finger, with the bar under it at full opacity and the
/// rest dimmed to 40 %. Lifting clears the label after 1.5 s. A plain tap does
/// nothing. The same values are rows in Stats → All hands, so nothing here is
/// drag-only.
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class MiniBars extends StatefulWidget {
  const MiniBars({
    super.key,
    required this.values,
    this.barHeight = 32,
    this.bandHeight = 44,
    this.gap = 2,
    this.color,
    this.labelBuilder,
    this.onInspect,
    this.emptyText = 'No reads logged yet.',
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  });

  /// 0–1 scores, oldest first (the caller takes the last 30).
  final List<double> values;

  final double barHeight;

  /// The gesture band; ≥ 44 so the strip clears the §12 floor.
  final double bandHeight;

  final double gap;

  /// Defaults to `info`.
  final Color? color;

  /// "Read 14 · 71 % · Ivey, flop, 3 days ago".
  final String Function(int index, double value)? labelBuilder;

  /// Index under the finger, or null when the inspection ends.
  final ValueChanged<int?>? onInspect;

  /// §7.3's verbatim empty line.
  final String emptyText;

  final bool enableHaptics;

  /// Accepted for API symmetry with the other charts; nothing here
  /// animates, so the strip is identical either way (§11).
  final bool reducedMotion;
  final String? semanticLabel;

  static const Duration holdToInspect = Duration(milliseconds: 200);
  static const Duration labelLinger = Duration(milliseconds: 1500);

  @override
  State<MiniBars> createState() => _MiniBarsState();
}

class _MiniBarsState extends State<MiniBars> {
  int? _index;
  String? _label;
  Timer? _clear;
  double _width = 0;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  int _indexAt(double dx) {
    final n = widget.values.length;
    if (n == 0 || _width <= 0) return 0;
    final slot = _width / n;
    return (dx / slot).floor().clamp(0, n - 1);
  }

  void _inspect(double dx) {
    final next = _indexAt(dx);
    if (next == _index) return;
    _clear?.cancel();
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    setState(() {
      _index = next;
      _label = _labelFor(next);
    });
    widget.onInspect?.call(next);
  }

  void _end() {
    if (_index == null) return;
    widget.onInspect?.call(null);
    setState(() => _index = null);
    _clear?.cancel();
    _clear = Timer(MiniBars.labelLinger, () {
      if (mounted) setState(() => _label = null);
    });
  }

  String _labelFor(int index) {
    final value = widget.values[index];
    return widget.labelBuilder?.call(index, value) ??
        'Read ${index + 1} · ${(value * 100).round()} %';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = widget.color ?? c.info;

    if (widget.values.isEmpty) {
      return SizedBox(
        height: widget.bandHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.emptyText,
            style: AllInText.body(14, color: c.textMuted),
          ),
        ),
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? _summary(),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              child:
                  _label == null
                      ? const SizedBox.shrink()
                      : Text(
                        _label!,
                        style: AllInText.mono(12, color: c.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
            ),
            RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: MiniBars.holdToInspect,
                        debugOwner: this,
                      ),
                      (recognizer) {
                        recognizer.onLongPressStart =
                            (d) => _inspect(d.localPosition.dx);
                        recognizer.onLongPressMoveUpdate =
                            (d) => _inspect(d.localPosition.dx);
                        recognizer.onLongPressEnd = (_) => _end();
                        recognizer.onLongPressCancel = _end;
                      },
                    ),
              },
              child: SizedBox(
                height: widget.bandHeight,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _width = constraints.maxWidth;
                    return CustomPaint(
                      painter: _MiniBarsPainter(
                        values: widget.values,
                        color: tone,
                        gap: widget.gap,
                        barHeight: widget.barHeight,
                        index: _index,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summary() {
    final mean = widget.values.reduce((a, b) => a + b) / widget.values.length;
    return 'Range-read accuracy, last ${widget.values.length} reads, '
        'average ${(mean * 100).round()} percent';
  }
}

class _MiniBarsPainter extends CustomPainter {
  _MiniBarsPainter({
    required this.values,
    required this.color,
    required this.gap,
    required this.barHeight,
    required this.index,
  });

  final List<double> values;
  final Color color;
  final double gap;
  final double barHeight;
  final int? index;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0) return;
    final slot = size.width / values.length;
    // With more bars than pixels the gap is dropped rather than inverted.
    final width = slot > gap * 2 ? slot - gap : slot;
    final height = barHeight > size.height ? size.height : barHeight;
    final bottom = size.height - (size.height - height) / 2;

    for (var i = 0; i < values.length; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final fraction = v * 100 < 3 ? 0.03 : v;
      final barTop = bottom - fraction * height;
      final dimmed = index != null && index != i;
      final opacity =
          index == i ? 1.0 : (0.55 + v * 0.45) * (dimmed ? 0.4 : 1.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(i * slot, barTop, i * slot + width, bottom),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_MiniBarsPainter old) =>
      old.index != index ||
      old.color != color ||
      old.barHeight != barHeight ||
      !identical(old.values, values);
}
