/// `TurnRing` — the 2 pt gold "this seat is to act" ring (DESIGN.md §10.3,
/// behaviour §4.3).
///
/// Manual pace breathes slowly (1.6 s) and carries a faint `▶` meaning "this
/// seat moves on Next action"; Auto pace sweeps a thin arc once per think.
/// Reduced motion leaves a static ring (§11).
library;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';

enum TurnRingMode {
  /// Manual pace: 1.6 s breathing pulse.
  breathing,

  /// Auto pace: a thin arc sweeps once per think.
  arc,

  /// Winner / reduced motion / any non-animated ring.
  still,

  /// No ring at all.
  none,
}

class TurnRing extends StatefulWidget {
  const TurnRing({
    super.key,
    required this.mode,
    required this.child,
    this.borderRadius = 14,
    this.color,
    this.showStepGlyph = false,
    this.reducedMotion = false,
  });

  final TurnRingMode mode;
  final Widget child;

  /// Matches the plate's radius so the ring hugs it.
  final double borderRadius;

  /// Defaults to gold; the winner ring passes `good` (§4.3).
  final Color? color;

  /// The faint `▶` inside the ring, Manual pace only (§4.3).
  final bool showStepGlyph;
  final bool reducedMotion;

  static const Duration breathePeriod = Duration(milliseconds: 1600);
  static const Duration arcPeriod = Duration(milliseconds: 1100);

  @override
  State<TurnRing> createState() => _TurnRingState();
}

class _TurnRingState extends State<TurnRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TurnRing.breathePeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TurnRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduced =
        widget.reducedMotion ||
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    final animate =
        !reduced &&
        (widget.mode == TurnRingMode.breathing ||
            widget.mode == TurnRingMode.arc);
    _controller.duration =
        widget.mode == TurnRingMode.arc
            ? TurnRing.arcPeriod
            : TurnRing.breathePeriod;
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == TurnRingMode.none) return widget.child;

    final c = context.colors;
    final ringColor = widget.color ?? c.gold;
    final reduced =
        widget.reducedMotion ||
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    final mode =
        reduced && widget.mode != TurnRingMode.still
            ? TurnRingMode.still
            : widget.mode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder:
                  (context, _) => CustomPaint(
                    painter: _TurnRingPainter(
                      mode: mode,
                      t: _controller.value,
                      color: ringColor,
                      radius: widget.borderRadius,
                    ),
                  ),
            ),
          ),
        ),
        if (widget.showStepGlyph)
          Positioned(
            top: 2,
            right: 4,
            // An `Icon`, not the literal U+25B6: that codepoint defaults to
            // emoji presentation, so Android drew this "step" hint as a
            // bright orange NotoColorEmoji square on the felt.
            child: IgnorePointer(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 10,
                color: ringColor.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

class _TurnRingPainter extends CustomPainter {
  const _TurnRingPainter({
    required this.mode,
    required this.t,
    required this.color,
    required this.radius,
  });

  final TurnRingMode mode;
  final double t;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );

    switch (mode) {
      case TurnRingMode.breathing:
        // A gold halo expands to 13 pt and fades, once per period (§4.3).
        final grow = 13 * t;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, size.width - 2, size.height - 2).inflate(grow),
            Radius.circular(radius + grow),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - t) * 0.45),
        );
      case TurnRingMode.arc:
        final path = Path()..addRRect(rrect);
        final metrics = path.computeMetrics().toList();
        if (metrics.isEmpty) return;
        final metric = metrics.first;
        final len = metric.length;
        final start = (t * len) % len;
        final sweep = len * 0.18;
        final extracted =
            start + sweep <= len
                ? metric.extractPath(start, start + sweep)
                : (Path()
                  ..addPath(metric.extractPath(start, len), Offset.zero)
                  ..addPath(
                    metric.extractPath(0, start + sweep - len),
                    Offset.zero,
                  ));
        canvas.drawPath(
          extracted,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: 0.9),
        );
      case TurnRingMode.still:
      case TurnRingMode.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_TurnRingPainter old) =>
      old.t != t || old.mode != mode || old.color != color;
}

/// Shared with §11's motion table: the ring never animates under reduced
/// motion, so callers can ask for the effective mode without duplicating
/// the check.
TurnRingMode effectiveTurnRingMode(
  BuildContext context,
  TurnRingMode mode, {
  required bool reducedMotion,
}) {
  final zero =
      AllInMotion.of(context, AllInMotion.base, reduced: reducedMotion) ==
      Duration.zero;
  if (!zero) return mode;
  return switch (mode) {
    TurnRingMode.none => TurnRingMode.none,
    _ => TurnRingMode.still,
  };
}
