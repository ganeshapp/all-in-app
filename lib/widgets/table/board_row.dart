/// `BoardRow` — the five community-card slots with dashed placeholders and the
/// deal-in animation (DESIGN.md §10.3; sizes §4.2 / §4.2.2 / §4.2.3, motion
/// §11 "street closes … board deals").
library;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'playing_card_view.dart';

class BoardRow extends StatelessWidget {
  const BoardRow({
    super.key,
    required this.cards,
    required this.size,
    this.gap = 6,
    this.fourColorDeck = false,
    this.reducedMotion = false,
  });

  /// 0–5 community cards, in dealt order.
  final List<String> cards;

  /// Card *width*; height follows §10.3 (`width × 1.4`).
  final double size;

  /// 6 at 390 (6-max), 3 at 9-max — §4.2 / §4.2.2.
  final double gap;
  final bool fourColorDeck;
  final bool reducedMotion;

  static const int slots = 5;

  /// Total width of the row for a given card width and gap.
  static double widthFor(double size, double gap) =>
      slots * size + (slots - 1) * gap;

  @override
  Widget build(BuildContext context) {
    final height = PlayingCardView.heightFor(size);
    return Semantics(
      label: cards.isEmpty ? 'No board cards yet' : 'Board',
      child: SizedBox(
        width: widthFor(size, gap),
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < slots; i++) ...[
              if (i > 0) SizedBox(width: gap),
              if (i < cards.length)
                _DealIn(
                  key: ValueKey('board-$i-${cards[i]}'),
                  slot: i,
                  reducedMotion: reducedMotion,
                  child: PlayingCardView(
                    card: cards[i],
                    width: size,
                    fourColorDeck: fourColorDeck,
                  ),
                )
              else
                _EmptySlot(width: size, height: height),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DashedSlotPainter(
          radius: PlayingCardView.radiusFor(width),
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.12),
          fill: AllInColors.dark.shadowColor.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

class _DashedSlotPainter extends CustomPainter {
  const _DashedSlotPainter({
    required this.radius,
    required this.color,
    required this.fill,
  });

  final double radius;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + 3).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), stroke);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter old) =>
      old.radius != radius || old.color != color || old.fill != fill;
}

/// Fade + rise + slight scale, staggered 60 ms by slot index (§11).
class _DealIn extends StatefulWidget {
  const _DealIn({
    super.key,
    required this.slot,
    required this.child,
    required this.reducedMotion,
  });

  final int slot;
  final Widget child;
  final bool reducedMotion;

  @override
  State<_DealIn> createState() => _DealInState();
}

class _DealInState extends State<_DealIn> with SingleTickerProviderStateMixin {
  static const Duration _deal = AllInMotion.deal;
  static const Duration _stagger = Duration(milliseconds: 60);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _deal + _stagger * widget.slot,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _controller.duration!.inMilliseconds == 0
          ? 0
          : (_stagger.inMilliseconds * widget.slot) /
              _controller.duration!.inMilliseconds,
      1,
      curve: AllInMotion.ease,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        AllInMotion.of(context, _deal, reduced: widget.reducedMotion) ==
        Duration.zero;
    if (reduced) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder:
          (context, child) => Opacity(
            opacity: _t.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _t.value) * -8),
              child: Transform.scale(
                scale: 0.94 + 0.06 * _t.value,
                child: child,
              ),
            ),
          ),
    );
  }
}
