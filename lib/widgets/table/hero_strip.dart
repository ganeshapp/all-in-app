/// `HeroStrip` — the 28 pt line under the hero's cards: position pill · stack
/// on the left, the price line or the hand label on the right (DESIGN.md
/// §10.3; rules §4.4, width table §4.4, gesture §4.12/§11).
///
/// The price line is never ellipsised and never truncated: when even the short
/// form will not fit, the strip drops its **left** segment to the bare position
/// pill instead (§4.4).
///
/// That is a *ladder*, not a single step, and [_HeroStripState._leftBudget]
/// walks all of it — full (disc · pill · stack) → disc · pill → pill → nothing —
/// stopping at the first rung that leaves the price line its whole measured
/// width. §4.4 names the third rung ("the bare position pill") because that is
/// where its own worst example lands; the fourth exists because the promise is
/// unconditional and the third is not always enough. At 430 pt and 1.3× text,
/// `"To call 98.8 bb · need 1 in 1.5"` is ~1 pt wider than the strip minus a
/// bare "BB", and the price is the one number the decision depends on.
///
/// The rungs are measured against what is actually painted — the pill's
/// padding, the mono stack, the dealer disc — rather than against a single
/// `"BB · 100 bb"` string in body type, which is what the earlier estimate did
/// and why the line still overflowed at 360/1.15×, 390/1.0× and 430/1.15×.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/format.dart';
import '../../engine/types.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'seat_plate.dart' show DealerDisc, PositionPill, positionLabel;

class HeroStrip extends StatefulWidget {
  const HeroStrip({
    super.key,
    required this.position,
    required this.stack,
    this.bigBlind = 20,
    this.seats = 6,
    this.isButton = false,
    this.priceLine,
    this.handLabel,
    this.allIn = false,
    this.onTapLeft,
    this.onSwipeUp,
    this.enableHaptics = true,
  });

  final Position position;

  /// Chips.
  final int stack;
  final int bigBlind;

  /// 2 renders the "BTN/SB" display mapping (§4.2.1).
  final int seats;

  /// Dealer disc left of the position pill when the hero has the button.
  final bool isButton;

  /// The price line, already in its long or short form — see
  /// [HeroStrip.priceLineFor] and [HeroStrip.useShortForm].
  final String? priceLine;

  /// Shown when there is no price: "QQ · pocket queens", or the made hand at
  /// hand-over.
  final String? handLabel;

  /// Replaces the right side with "ALL-IN" in `chipRed` (§4.4).
  final bool allIn;

  /// Tapping the left segment opens T1 after 8 hands (§4.4).
  final VoidCallback? onTapLeft;

  /// Swipe up → P2 Session sheet; threshold 48 pt or 420 pt/s (§11).
  final VoidCallback? onSwipeUp;
  final bool enableHaptics;

  static const double height = 28;
  static const double swipeThreshold = 48;
  static const double swipeVelocity = 420;

  /// "To call 2 bb · need to win 1 in 4" / "To call 2 bb · need 1 in 4".
  /// [potOdds] is the break-even share of the final pot the call buys.
  static String priceLineFor({
    required num toCall,
    required int bigBlind,
    required double potOdds,
    required bool short,
  }) {
    final amount = '${fmtBb(toCall, bigBlind)} bb';
    if (potOdds <= 0) return 'To call $amount';
    // Same rounding as fmtNeed: nearest half.
    final rounded = jsRound(1 / potOdds * 2) / 2;
    final times =
        rounded == rounded.truncateToDouble()
            ? jsIntString(rounded)
            : jsToFixed(rounded, 1);
    return short
        ? 'To call $amount · need 1 in $times'
        : 'To call $amount · need to win 1 in $times';
  }

  /// §4.4's width table plus its two overrides: heads-up and textScaler > 1.15
  /// always take the short form, and so does anything under 390 pt.
  static bool useShortForm({
    required double width,
    required int seats,
    required TextScaler textScaler,
  }) => seats == 2 || width < 390 || textScaler.scale(15) > 15 * 1.15;

  @override
  State<HeroStrip> createState() => _HeroStripState();
}

/// The rungs of §4.4's ladder, widest first. The strip takes the first one
/// that leaves the price line its whole measured width.
enum _LeftSegment {
  /// Dealer disc (when the hero has the button) · position pill · stack.
  full,

  /// Disc · pill — the stack is the first thing to go.
  discAndPill,

  /// §4.4's named fallback: "the bare position pill".
  pill,

  /// Nothing. Only a *protected* right side (the price line, "ALL-IN") gets
  /// here, and only when the pill alone still would not fit.
  none;

  bool get showsDisc => this == full || this == discAndPill;
  bool get showsStack => this == full;
  bool get showsPill => this != none;
}

class _HeroStripState extends State<HeroStrip> {
  double _drag = 0;
  bool _fired = false;

  /// The widest rung whose left segment plus the 12 pt gap still leaves
  /// [rightWidth] intact, never going below [floor].
  ///
  /// When nothing fits — a box narrower than the price line itself, which the
  /// table's own layout never produces — it keeps [_LeftSegment.pill]: the
  /// right side is going to overflow either way, and dropping the position
  /// would buy nothing.
  static _LeftSegment _leftSegment({
    required double box,
    required double rightWidth,
    required double discWidth,
    required double pillWidth,
    required double stackWidth,
    required _LeftSegment floor,
  }) {
    double widthOf(_LeftSegment segment) => switch (segment) {
      _LeftSegment.full => discWidth + pillWidth + stackWidth,
      _LeftSegment.discAndPill => discWidth + pillWidth,
      _LeftSegment.pill => pillWidth,
      _LeftSegment.none => 0,
    };

    for (final segment in _LeftSegment.values) {
      if (segment.index > floor.index) break;
      final gap = segment == _LeftSegment.none ? 0 : 12;
      if (widthOf(segment) + gap + rightWidth <= box + 0.01) return segment;
    }
    return _LeftSegment.pill;
  }

  void _crossed() {
    if (_fired) return;
    _fired = true;
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onSwipeUp?.call();
  }

  /// The width [text] will actually paint at.
  ///
  /// [ambient] is `DefaultTextStyle.of(context).style` and merging it in is not
  /// optional: `Text` merges it (every `AllInText` style has `inherit: true`),
  /// and Material's `bodyMedium` carries a `letterSpacing` of 0.25 that
  /// `AllInText.body` does not name. Measuring the bare style under-counted the
  /// price line by a quarter point per character — 8 pt on the long form — and
  /// that was exactly the margin by which it overflowed.
  double _measure(
    String text,
    TextStyle style,
    TextScaler scaler, {
    required TextStyle ambient,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: ambient.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.maxIntrinsicWidth;
  }

  /// `PositionPill`'s painted width: 5 pt of padding either side of an 11 pt
  /// semibold label carrying 0.4 of letter spacing.
  double _pillWidth(
    String label,
    Color color,
    TextScaler scaler, {
    required TextStyle ambient,
  }) =>
      _measure(
        label,
        AllInText.body(
          11,
          weight: FontWeight.w600,
          color: color,
          height: 1.1,
        ).copyWith(letterSpacing: 0.4),
        scaler,
        ambient: ambient,
      ) +
      10;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scaler = MediaQuery.textScalerOf(context);
    final pos = positionLabel(widget.position, widget.seats);
    final stackText = '${fmtBb(widget.stack, widget.bigBlind)} bb';

    final rightText =
        widget.allIn ? 'ALL-IN' : (widget.priceLine ?? widget.handLabel ?? '');
    final rightStyle =
        widget.allIn
            ? AllInText.body(
              15,
              weight: FontWeight.w700,
              color: AllInColors.chipRed,
            )
            : (widget.priceLine != null
                ? AllInText.body(15, color: c.text)
                : AllInText.body(15, color: c.textMuted));

    return LayoutBuilder(
      builder: (context, constraints) {
        final ambient = DefaultTextStyle.of(context).style;
        final box = constraints.maxWidth;
        final rightWidth = _measure(
          rightText,
          rightStyle,
          scaler,
          ambient: ambient,
        );
        final discWidth = widget.isButton ? 22.0 : 0.0;
        final pillWidth = _pillWidth(
          pos,
          c.textMuted,
          scaler,
          ambient: ambient,
        );
        final stackWidth =
            6 +
            _measure(
              stackText,
              AllInText.mono(15, color: c.goldLight),
              scaler,
              ambient: ambient,
            );

        // §4.4's ladder. The price line (and "ALL-IN") is protected and may
        // take the whole strip; a hand label is not, and stops at the pill so
        // the hero always knows which seat is being described.
        final protect = widget.priceLine != null || widget.allIn;
        final segment = _leftSegment(
          box: box,
          rightWidth: rightWidth,
          discWidth: discWidth,
          pillWidth: pillWidth,
          stackWidth: stackWidth,
          floor: protect ? _LeftSegment.none : _LeftSegment.discAndPill,
        );

        final left = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isButton && segment.showsDisc) ...[
              const DealerDisc(size: 16),
              const SizedBox(width: 6),
            ],
            PositionPill(label: pos),
            if (segment.showsStack) ...[
              const SizedBox(width: 6),
              Text(
                stackText,
                maxLines: 1,
                style: AllInText.mono(15, color: c.goldLight),
              ),
            ],
          ],
        );

        final row = SizedBox(
          height: HeroStrip.height * scaler.scale(15) / 15,
          child: Row(
            children: [
              // The left segment keeps its screen-reader line even when it
              // has given up every pixel: the position and the stack are
              // still true, they are just not worth a truncated price line.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: segment.showsPill ? widget.onTapLeft : null,
                child: Semantics(
                  button: segment.showsPill && widget.onTapLeft != null,
                  label: '$pos, $stackText',
                  child: ExcludeSemantics(
                    child: segment.showsPill ? left : const SizedBox.shrink(),
                  ),
                ),
              ),
              if (segment.showsPill) const SizedBox(width: 12),
              // `Expanded`, not `Spacer` + `Flexible`: two flex children would
              // split the free space in half and push the right text off the
              // edge of the strip.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    rightText,
                    maxLines: 1,
                    softWrap: false,
                    // The price line is never ellipsised (§4.4); the hand
                    // label may be, so it can never spill off-screen.
                    overflow:
                        widget.priceLine != null || widget.allIn
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: rightStyle,
                  ),
                ),
              ),
            ],
          ),
        );

        if (widget.onSwipeUp == null) return row;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) {
            _drag = 0;
            _fired = false;
          },
          onVerticalDragUpdate: (d) {
            _drag -= d.delta.dy;
            if (_drag >= HeroStrip.swipeThreshold) _crossed();
          },
          onVerticalDragEnd: (d) {
            if (-d.velocity.pixelsPerSecond.dy >= HeroStrip.swipeVelocity) {
              _crossed();
            }
            _drag = 0;
          },
          child: row,
        );
      },
    );
  }
}
