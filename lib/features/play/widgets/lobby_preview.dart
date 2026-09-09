/// The 140 pt felt preview at the top of the P0 setup card (DESIGN.md §4.1):
/// "live re-seats itself as Table changes; ante chips appear with Antes".
///
/// It reuses `FeltCanvas`'s anchors so the preview is the same table the user
/// is about to sit at, only smaller: seat discs instead of plates, five board
/// slots (dashed on the very first visit) and one ante chip per seat while
/// antes are on.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

class LobbyFeltPreview extends StatelessWidget {
  const LobbyFeltPreview({
    super.key,
    required this.seats,
    required this.ante,
    this.dashedBoard = false,
    this.height = 140,
  });

  final int seats;

  /// Chips per player, per hand. > 0 draws the ante chips.
  final int ante;

  /// §4.1's empty state: "the preview shows dashed board slots".
  final bool dashedBoard;

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final layout = FeltLayout.fromSeats(seats);

    return SizedBox(
      height: height,
      child: Semantics(
        label:
            '$seats-seat table preview'
            '${ante > 0 ? ', antes on' : ''}',
        child: ExcludeSemantics(
          child: FeltCanvas(
            layout: layout,
            railWidth: 5,
            builder: (context, felt) {
              final scale = (felt.size.width / 346).clamp(0.35, 1.0);
              final dot = (10 * scale + 6).clamp(7.0, 14.0);
              return [
                // Hero disc: seat 0 has no plate anchor, so it is drawn at the
                // bottom centre where the hero's cards live on the table.
                felt.at(
                  0.50,
                  0.86,
                  child: _Disc(size: dot, color: c.gold, filled: true),
                ),
                for (final seat in felt.plateSeats)
                  felt.place(
                    felt.seatAnchor(seat),
                    child: _Disc(
                      size: dot,
                      color: c.text.withValues(alpha: 0.72),
                    ),
                  ),
                if (ante > 0)
                  for (final seat in felt.plateSeats)
                    felt.place(
                      felt.betAnchor(seat),
                      child: _AnteChip(size: (dot * 0.55).clamp(4.0, 8.0)),
                    ),
                if (ante > 0)
                  felt.at(
                    0.50,
                    0.74,
                    child: _AnteChip(size: (dot * 0.55).clamp(4.0, 8.0)),
                  ),
                felt.place(
                  felt.boardAnchor,
                  child: _BoardSlots(
                    dashed: dashedBoard,
                    width: (felt.size.width * 0.085).clamp(12.0, 30.0),
                  ),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color, this.filled = false});

  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : Colors.transparent,
      border: Border.all(color: color, width: 1.5),
    ),
  );
}

class _AnteChip extends StatelessWidget {
  const _AnteChip({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AllInColors.chipBlue,
    ),
  );
}

class _BoardSlots extends StatelessWidget {
  const _BoardSlots({required this.dashed, required this.width});

  final bool dashed;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final height = width * 1.4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 3),
            child: CustomPaint(
              size: Size(width, height),
              painter: _SlotPainter(
                color: c.text.withValues(alpha: dashed ? 0.45 : 0.22),
                dashed: dashed,
                radius: width * 0.18,
              ),
            ),
          ),
      ],
    );
  }
}

class _SlotPainter extends CustomPainter {
  const _SlotPainter({
    required this.color,
    required this.dashed,
    required this.radius,
  });

  final Color color;
  final bool dashed;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color;
    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    // A 3-on / 3-off dash walked around the rounded rectangle.
    final metrics = (Path()..addRRect(rrect)).computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 3).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 3;
      }
    }
  }

  @override
  bool shouldRepaint(_SlotPainter old) =>
      old.color != color || old.dashed != dashed || old.radius != radius;
}
