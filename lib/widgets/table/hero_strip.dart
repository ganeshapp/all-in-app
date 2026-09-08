/// `HeroStrip` — the 28 pt line under the hero's cards: position pill · stack
/// on the left, the price line or the hand label on the right (DESIGN.md
/// §10.3; rules §4.4, width table §4.4, gesture §4.12/§11).
///
/// The price line is never ellipsised and never truncated: when even the short
/// form will not fit, the strip drops its **left** segment to the bare position
/// pill instead (§4.4).
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

class _HeroStripState extends State<HeroStrip> {
  double _drag = 0;
  bool _fired = false;

  void _crossed() {
    if (_fired) return;
    _fired = true;
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onSwipeUp?.call();
  }

  double _measure(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

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
        final box = constraints.maxWidth;
        final rightWidth = _measure(rightText, rightStyle, scaler);
        final fullLeft = _measure(
          '$pos · $stackText',
          AllInText.body(15, weight: FontWeight.w600, color: c.text),
          scaler,
        );
        final discWidth = widget.isButton ? 22.0 : 0.0;
        // The price line is never truncated: the left segment gives way first.
        final compactLeft = fullLeft + discWidth + 12 + rightWidth > box;

        final left = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isButton) ...[
              const DealerDisc(size: 16),
              const SizedBox(width: 6),
            ],
            PositionPill(label: pos),
            if (!compactLeft) ...[
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapLeft,
                child: Semantics(
                  button: widget.onTapLeft != null,
                  label: '$pos, $stackText',
                  child: ExcludeSemantics(child: left),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    rightText,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
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
