/// `FeltCanvas` — the table felt (rail, gradient, hairline) plus the fractional
/// anchor system every prop on the table is positioned with (DESIGN.md §10.3,
/// geometry §4.2 / §4.2.1 / §4.2.2).
///
/// Anchors are fractions of the canvas, never absolute offsets, so the same
/// table scales from 360 to 430 without a second layout (§4.2, "bet spots are
/// anchors, not an offset").
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Which anchor table applies. Seat counts 2 / 6 / 9 (§4.2, §4.2.1, §4.2.2).
enum FeltLayout {
  hu(2),
  six(6),
  nine(9);

  const FeltLayout(this.seats);
  final int seats;

  static FeltLayout fromSeats(int seats) => switch (seats) {
    2 => FeltLayout.hu,
    9 => FeltLayout.nine,
    _ => FeltLayout.six,
  };
}

/// The measured felt plus every anchor in §4.2's tables.
class FeltGeometry {
  const FeltGeometry({
    required this.size,
    required this.layout,
    required this.railWidth,
  });

  final Size size;
  final FeltLayout layout;
  final double railWidth;

  /// Pixel position of a fractional anchor.
  Offset anchor(double fx, double fy) =>
      Offset(size.width * fx, size.height * fy);

  /// Seat-plate centre. Seat 0 is the hero, who has no plate (§4.3) — asking
  /// for it is a programming error.
  Offset seatAnchor(int seat) {
    final a = _seatFractions[layout]![seat];
    assert(a != null, 'seat $seat has no plate anchor in $layout');
    return anchor(a!.dx, a.dy);
  }

  /// Bet-slot centre; seat 0 is the hero's own bet spot.
  Offset betAnchor(int seat) {
    final a = _betFractions[layout]![seat];
    assert(a != null, 'seat $seat has no bet anchor in $layout');
    return anchor(a!.dx, a.dy);
  }

  Offset get potAnchor {
    final a = _potFraction[layout]!;
    return anchor(a.dx, a.dy);
  }

  Offset get boardAnchor {
    final a = _boardFraction[layout]!;
    return anchor(a.dx, a.dy);
  }

  /// The coach chip zone — one anchor at (0.50, 0.79) in every layout (§4.8).
  Offset get chipAnchor => anchor(0.50, 0.79);

  /// Seat ids that carry a plate in this layout (hero excluded).
  Iterable<int> get plateSeats => _seatFractions[layout]!.keys;

  /// Places [child] with its [alignment] point sitting on the fraction.
  Widget at(
    double fx,
    double fy, {
    required Widget child,
    Alignment alignment = Alignment.center,
  }) => place(anchor(fx, fy), child: child, alignment: alignment);

  /// Places [child] with its [alignment] point sitting on [point].
  Widget place(
    Offset point, {
    required Widget child,
    Alignment alignment = Alignment.center,
  }) => Positioned(
    left: point.dx,
    top: point.dy,
    child: FractionalTranslation(
      translation: Offset(-(alignment.x + 1) / 2, -(alignment.y + 1) / 2),
      child: child,
    ),
  );

  /// The lowest seat centre whose tucked cards still clear the rail:
  /// `cardTop = seatCentreY − plateHeight/2 − peek` must be ≥ [railWidth]
  /// (§4.2's invariant).
  double railClearedCentreY({
    required double plateHeight,
    required double peek,
  }) => railWidth + peek + plateHeight / 2;

  /// [seatAnchor], nudged down when the felt is too short for the seat's
  /// plate to clear the rail.
  ///
  /// The felt is the table's one flexible band: it absorbs whatever the fixed
  /// rows leave. At 360 × 780 with the system insets and 1.3× text it came out
  /// 435.3 pt tall, and the top seat's anchor (0.14) put its cards 9.94 pt
  /// down — 0.06 inside the 10 pt rail. Asserting on the raw fraction turned
  /// that sixteenth of a pixel into a red error box over the whole table, so
  /// the geometry now *satisfies* the invariant instead of only checking it.
  Offset seatAnchorClearingRail({
    required int seat,
    required double plateHeight,
    required double peek,
  }) {
    final a = seatAnchor(seat);
    final floor = railClearedCentreY(plateHeight: plateHeight, peek: peek);
    return a.dy >= floor ? a : Offset(a.dx, floor);
  }

  /// How far [seatAnchorClearingRail] had to move [seat], in points.
  double railClearanceDeficit({
    required int seat,
    required double plateHeight,
    required double peek,
  }) => math.max(
    0.0,
    railClearedCentreY(plateHeight: plateHeight, peek: peek) -
        seatAnchor(seat).dy,
  );

  /// §4.2's invariant, as a debug check. A sub-point deficit is the flexible
  /// felt rounding against a fixed anchor and [seatAnchorClearingRail] absorbs
  /// it; anything past [railClearanceTolerance] is a real layout bug.
  bool debugCardsClearRail({
    required int seat,
    required double plateHeight,
    required double peek,
  }) {
    final deficit = railClearanceDeficit(
      seat: seat,
      plateHeight: plateHeight,
      peek: peek,
    );
    assert(
      deficit <= railClearanceTolerance,
      'seat $seat hole cards start ${deficit.toStringAsFixed(1)} pt inside '
      'the $railWidth pt rail of a ${size.width}×${size.height} felt — more '
      'than the $railClearanceTolerance pt the anchor may be nudged',
    );
    return deficit <= railClearanceTolerance;
  }

  /// How far a seat may be nudged down before the felt is simply too short.
  static const double railClearanceTolerance = 12;

  // ---- §4.2 / §4.2.1 / §4.2.2 anchor tables (fractions of the canvas) ----

  static const Map<FeltLayout, Map<int, Offset>> _seatFractions = {
    FeltLayout.hu: {1: Offset(0.50, 0.145)},
    FeltLayout.six: {
      1: Offset(0.89, 0.675),
      2: Offset(0.89, 0.315),
      3: Offset(0.50, 0.14),
      4: Offset(0.11, 0.315),
      5: Offset(0.11, 0.675),
    },
    FeltLayout.nine: {
      1: Offset(0.89, 0.665),
      2: Offset(0.89, 0.47),
      3: Offset(0.89, 0.28),
      4: Offset(0.72, 0.115),
      5: Offset(0.28, 0.115),
      6: Offset(0.11, 0.28),
      7: Offset(0.11, 0.47),
      8: Offset(0.11, 0.665),
    },
  };

  static const Map<FeltLayout, Map<int, Offset>> _betFractions = {
    FeltLayout.hu: {0: Offset(0.50, 0.67), 1: Offset(0.50, 0.27)},
    FeltLayout.six: {
      0: Offset(0.50, 0.60),
      1: Offset(0.645, 0.575),
      2: Offset(0.645, 0.368),
      3: Offset(0.50, 0.24),
      4: Offset(0.355, 0.368),
      5: Offset(0.355, 0.575),
    },
    FeltLayout.nine: {
      0: Offset(0.50, 0.60),
      1: Offset(0.70, 0.60),
      2: Offset(0.89, 0.565),
      3: Offset(0.89, 0.375),
      4: Offset(0.72, 0.21),
      5: Offset(0.28, 0.21),
      6: Offset(0.11, 0.375),
      7: Offset(0.11, 0.565),
      8: Offset(0.30, 0.60),
    },
  };

  static const Map<FeltLayout, Offset> _potFraction = {
    FeltLayout.hu: Offset(0.50, 0.37),
    FeltLayout.six: Offset(0.50, 0.305),
    FeltLayout.nine: Offset(0.50, 0.33),
  };

  static const Map<FeltLayout, Offset> _boardFraction = {
    FeltLayout.hu: Offset(0.50, 0.52),
    FeltLayout.six: Offset(0.50, 0.47),
    FeltLayout.nine: Offset(0.50, 0.45),
  };
}

typedef FeltBuilder =
    List<Widget> Function(BuildContext context, FeltGeometry felt);

/// The felt shape plus an anchored [Stack] of props.
class FeltCanvas extends StatelessWidget {
  const FeltCanvas({
    super.key,
    this.layout = FeltLayout.six,
    required this.builder,
    this.railWidth = 10,
    this.onTapBackground,
    this.semanticSummary,
  });

  final FeltLayout layout;

  /// Props, positioned with `felt.at(fx, fy, child: …)`.
  final FeltBuilder builder;

  /// Rail thickness; 10 pt at every supported width (§4.2).
  final double railWidth;

  /// "Tap the felt" — one bot action in Manual, pause/resume in Auto (§4.5 C/D).
  /// Props on top of the felt receive their own taps first.
  final VoidCallback? onTapBackground;

  /// §13 live summary node ("Pre-flop, pot 4.5 big blinds, Ivey to act, …").
  final String? semanticSummary;

  /// Corner radius reads as an oval: 150 pt on a 346 pt-wide felt (§4.2).
  static double radiusFor(Size size) =>
      math.min(size.width * (150 / 346), math.min(size.width, size.height) / 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final felt = FeltGeometry(
          size: size,
          layout: layout,
          railWidth: railWidth,
        );

        Widget surface = CustomPaint(
          size: size,
          painter: _FeltPainter(railWidth: railWidth),
        );
        if (onTapBackground != null) {
          surface = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapBackground,
            child: surface,
          );
        }

        // The felt is a fixed dark material in both themes, so its props read
        // against dark green rather than against the page (see [FeltTheme]).
        final stack = FeltTheme(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: surface),
              ...builder(context, felt),
            ],
          ),
        );

        return SizedBox(
          width: size.width,
          height: size.height,
          child:
              semanticSummary == null
                  ? stack
                  : Semantics(
                    container: true,
                    liveRegion: true,
                    label: semanticSummary,
                    child: stack,
                  ),
        );
      },
    );
  }
}

class _FeltPainter extends CustomPainter {
  const _FeltPainter({required this.railWidth});

  final double railWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = FeltCanvas.radiusFor(size);
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // Rail: wood fill plus a 1 pt highlight along its outer edge.
    canvas.drawRRect(outer, Paint()..color = AllInColors.rail);
    canvas.drawRRect(
      outer.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AllInColors.railLight,
    );

    // Felt: radial feltLight → felt → feltDark.
    final innerRect = Rect.fromLTWH(
      railWidth,
      railWidth,
      math.max(0, size.width - railWidth * 2),
      math.max(0, size.height - railWidth * 2),
    );
    final inner = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(math.max(0, radius - railWidth)),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.85,
          colors: [
            AllInColors.feltLight,
            AllInColors.felt,
            AllInColors.feltDark,
          ],
          stops: [0, 0.55, 1],
        ).createShader(innerRect),
    );

    // Inner hairline at 92 % of the felt shape.
    final hair = Rect.fromCenter(
      center: innerRect.center,
      width: innerRect.width * 0.92,
      height: innerRect.height * 0.92,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        hair,
        Radius.circular(math.max(0, (radius - railWidth) * 0.92)),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(_FeltPainter oldDelegate) =>
      oldDelegate.railWidth != railWidth;
}
