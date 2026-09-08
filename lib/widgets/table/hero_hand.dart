/// `HeroHand` — the hero's two cards with the turn lift and gold glow
/// (DESIGN.md §10.3; behaviour §4.4, motion §11 "Hero's turn").
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';
import 'playing_card_view.dart';

class HeroHand extends StatefulWidget {
  const HeroHand({
    super.key,
    required this.cards,
    required this.size,
    this.active = false,
    this.folded = false,
    this.gap = 6,
    this.fourColorDeck = false,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  /// The hero's hole cards; empty between hands.
  final List<String> cards;

  /// Card width — 72 at 390, 64 at 360, 80 at 430 (§4.2.3).
  final double size;

  /// The hero is to act: lift 6 pt, gold glow, one light haptic (§4.4).
  final bool active;

  /// After a hero fold the cards slide 20 pt down and dim to 30 % (§4.5).
  final bool folded;
  final double gap;
  final bool fourColorDeck;
  final bool enableHaptics;
  final bool reducedMotion;

  static const double lift = 6;
  static const double foldDrop = 20;

  @override
  State<HeroHand> createState() => _HeroHandState();
}

class _HeroHandState extends State<HeroHand> {
  @override
  void didUpdateWidget(HeroHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    // §11: one light haptic when the hero's turn arrives.
    if (widget.active && !oldWidget.active && widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = AllInMotion.of(
      context,
      const Duration(milliseconds: 200),
      reduced: widget.reducedMotion,
    );
    final offset =
        widget.folded
            ? HeroHand.foldDrop
            : (widget.active ? -HeroHand.lift : 0.0);

    return AnimatedSlide(
      offset: Offset(0, offset / PlayingCardView.heightFor(widget.size)),
      duration: duration,
      curve: AllInMotion.ease,
      child: AnimatedOpacity(
        opacity: widget.folded ? 0.30 : 1,
        duration: duration,
        curve: AllInMotion.ease,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) SizedBox(width: widget.gap),
              PlayingCardView(
                card: i < widget.cards.length ? widget.cards[i] : null,
                width: widget.size,
                faceDown: i >= widget.cards.length,
                glow: widget.active && !widget.folded,
                fourColorDeck: widget.fourColorDeck,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
