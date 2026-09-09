/// `SeatPlate` — an opponent's seat on the felt: tucked hole cards, the plate
/// (avatar ring, name, position pill, stack, HUD line), the eye glyph, the turn
/// ring and the dealer disc (DESIGN.md §10.3; behaviour §4.3, sizes §4.2 /
/// §4.2.1 / §4.2.2 / §4.2.3).
///
/// One `GestureDetector` owns the whole plate and splits itself by local
/// position: inside the 44×44 eye rect a tap opens P7, everywhere else P6
/// (§4.3 — "one control with two zones, not two overlapping controls").
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/format.dart';
import '../../engine/types.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'playing_card_view.dart';
import 'turn_ring.dart';

/// The one shared display mapping: heads-up shows "BTN/SB" for the button and
/// "BB" for the other seat. It is **never** written to storage (§4.2.1).
String positionLabel(Position position, int seats) =>
    (seats == 2 && position == Position.btn) ? 'BTN/SB' : position.label;

/// Archetype ring colours (§4.3; hexes from `engine/archetypes.dart`).
Color archetypeColor(Archetype? archetype) => switch (archetype) {
  Archetype.tag => AllInColors.suitBlue,
  Archetype.lag => AllInColors.chipPurple,
  Archetype.nit => AllInColors.suitGreen,
  Archetype.station => AllInColors.chipRed,
  null => AllInColors.dark.ink300,
};

/// 104×58 standard · 84×50 compact (9-max) · 160×64 heads-up (§10.3).
enum SeatPlateVariant { standard, compact, hu }

enum SeatPlateState { idle, toAct, folded, allIn, winner }

class SeatPlate extends StatelessWidget {
  const SeatPlate({
    super.key,
    required this.player,
    this.variant = SeatPlateVariant.standard,
    this.state = SeatPlateState.idle,
    this.bigBlind = 20,
    this.seats = 6,
    this.showEye = false,
    this.isButton = false,
    this.showHole = false,
    this.thinking = false,
    this.rebought = false,
    this.turnMode = TurnRingMode.breathing,
    this.plateSize,
    this.holeCardWidth,
    this.cardPeek,
    this.nameLimit,
    this.mirrored = false,
    this.dealerAlignment,
    this.fourColorDeck = false,
    this.realisticReveal = false,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.onTap,
    this.onEye,
    this.onLongPress,
  });

  final Player player;
  final SeatPlateVariant variant;
  final SeatPlateState state;
  final int bigBlind;

  /// Table size — only used for the "BTN/SB" display mapping (§4.2.1).
  final int seats;

  /// The eye is visible while `phase == betting && !hasFolded && hole != null`
  /// (§4.3). When false the whole plate opens P6.
  final bool showEye;
  final bool isButton;

  /// `isHero || (revealed && !(realisticReveal && hasFolded))` — §6.5 of the
  /// port spec. When false the tucked cards render face-down.
  final bool showHole;

  /// Auto pace: the HUD line becomes a three-dot shimmer while the bot's delay
  /// runs; reduced motion replaces it with the static word "thinking" (§11).
  final bool thinking;

  /// A bot rebuilt to 100 bb shows "rebought" in place of the HUD for one hand.
  final bool rebought;
  final TurnRingMode turnMode;

  /// Overrides the variant default (360 / 430 sizes, §4.2.3).
  final Size? plateSize;
  final double? holeCardWidth;
  final double? cardPeek;
  final int? nameLimit;

  /// True for seats on the left half of the felt: the eye moves to the top-left
  /// corner and the dealer disc to the inner (right) one.
  final bool mirrored;

  /// Overrides the derived dealer-disc corner.
  final Alignment? dealerAlignment;
  final bool fourColorDeck;
  final bool realisticReveal;
  final bool enableHaptics;
  final bool reducedMotion;

  /// Tap outside the eye rect → P6 Player sheet.
  final VoidCallback? onTap;

  /// Tap inside the eye rect → P7 Read range.
  final VoidCallback? onEye;

  /// Long-press (500 ms, medium haptic) → P7 directly.
  final VoidCallback? onLongPress;

  /// "Reads are earned": HUD numbers appear only after 8 observed hands.
  static const int minSample = 8;

  /// The eye's hit rect is 44×44 anchored to the plate's outer top corner.
  static const double eyeHit = 44;

  /// §4.3 also grants 12 pt of felt beyond the plate's two outer edges; the
  /// caller owns that slop because it lives outside this widget's box.
  static const double eyeFeltSlop = 12;

  static Size defaultPlateSize(SeatPlateVariant variant) => switch (variant) {
    SeatPlateVariant.standard => const Size(104, 58),
    SeatPlateVariant.compact => const Size(84, 50),
    SeatPlateVariant.hu => const Size(160, 64),
  };

  static double defaultHoleCardWidth(SeatPlateVariant variant) =>
      switch (variant) {
        SeatPlateVariant.standard => 30,
        SeatPlateVariant.compact => 24,
        SeatPlateVariant.hu => 34,
      };

  /// 24 pt on the standard and heads-up plates, 14 pt at 9-max (§4.2.2).
  static double defaultPeek(SeatPlateVariant variant) =>
      variant == SeatPlateVariant.compact ? 14 : 24;

  static double _radius(SeatPlateVariant variant) => switch (variant) {
    SeatPlateVariant.standard => 14,
    SeatPlateVariant.compact => 12,
    SeatPlateVariant.hu => 16,
  };

  static double _avatar(SeatPlateVariant variant) => switch (variant) {
    SeatPlateVariant.standard => 26,
    SeatPlateVariant.compact => 20,
    SeatPlateVariant.hu => 30,
  };

  static int _nameLimit(SeatPlateVariant variant) => switch (variant) {
    SeatPlateVariant.standard => 8,
    SeatPlateVariant.compact => 5,
    SeatPlateVariant.hu => 12,
  };

  /// "22/18" once the sample is earned, "–/–" before it (§4.3).
  static String hudNumbers(Player player) {
    final n = player.handsSeen;
    if (n < minSample) return '–/–';
    final vpip = jsRound(player.vpipCount / n * 100);
    final pfr = jsRound(player.pfrCount / n * 100);
    return '${jsIntString(vpip)}/${jsIntString(pfr)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = plateSize ?? defaultPlateSize(variant);
    final cardWidth = holeCardWidth ?? defaultHoleCardWidth(variant);
    final peek = cardPeek ?? defaultPeek(variant);
    final radius = _radius(variant);
    final folded = state == SeatPlateState.folded;
    final duration = AllInMotion.of(
      context,
      const Duration(milliseconds: 220),
      reduced: reducedMotion,
    );

    final ringMode = effectiveTurnRingMode(
      context,
      state == SeatPlateState.toAct
          ? turnMode
          : (state == SeatPlateState.winner
              ? TurnRingMode.still
              : TurnRingMode.none),
      reducedMotion: reducedMotion,
    );

    final plate = TurnRing(
      mode: ringMode,
      borderRadius: radius,
      color: state == SeatPlateState.winner ? c.good : c.gold,
      showStepGlyph:
          state == SeatPlateState.toAct && turnMode == TurnRingMode.breathing,
      reducedMotion: reducedMotion,
      // §4.3's "folded dims to 55 %" dims the plate's *contents*, not the
      // plate. Fading the whole widget took its `ink800 @ 92 %` background
      // down to ~51 % opaque, so the felt's radial highlight, inner hairline
      // and seat ring read straight through: the plate stopped being an
      // object and became a smudge. (The tucked cards keep their own 0.30.)
      child: Container(
        width: size.width,
        height: size.height,
        padding: EdgeInsets.symmetric(
          horizontal: variant == SeatPlateVariant.compact ? 6 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: c.ink800.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: c.line, width: 1),
        ),
        child: AnimatedOpacity(
          opacity: folded ? 0.55 : 1,
          duration: duration,
          child: MediaQuery.withClampedTextScaling(
            // §4.2.4: felt text stops scaling at 1.15×.
            maxScaleFactor: 1.15,
            child: _PlateBody(
              player: player,
              variant: variant,
              state: state,
              bigBlind: bigBlind,
              seats: seats,
              thinking: thinking,
              rebought: rebought,
              avatar: _avatar(variant),
              nameLimit: nameLimit ?? _nameLimit(variant),
              reducedMotion: reducedMotion,
            ),
          ),
        ),
      ),
    );

    final hole = player.hole;
    final eyeVisible = showEye && !folded && hole != null && onEye != null;

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        if (hole != null)
          AnimatedPositioned(
            duration: duration,
            curve: AllInMotion.ease,
            left: 0,
            right: 0,
            top: -peek + (folded ? 20 : 0),
            child: AnimatedOpacity(
              opacity: folded ? 0.30 : 1,
              duration: duration,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < hole.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    PlayingCardView(
                      card: showHole ? hole[i] : null,
                      width: cardWidth,
                      faceDown: !showHole,
                      dimmed: folded,
                      greyscale: folded && showHole,
                      fourColorDeck: fourColorDeck,
                    ),
                  ],
                ],
              ),
            ),
          ),
        AnimatedSlide(
          offset: Offset(
            0,
            state == SeatPlateState.winner ? -2 / size.height : 0,
          ),
          duration: duration,
          curve: AllInMotion.ease,
          child: plate,
        ),
        if (eyeVisible)
          Positioned(
            top: 3,
            left: mirrored ? 4 : null,
            right: mirrored ? null : 4,
            child: IgnorePointer(
              child: Text(
                '👁',
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  color: c.gold.withValues(alpha: 0.70),
                ),
              ),
            ),
          ),
        if (isButton)
          Positioned(
            bottom: -4,
            left: (dealerAlignment ?? _dealerCorner).x < 0 ? -4 : null,
            right: (dealerAlignment ?? _dealerCorner).x < 0 ? null : -4,
            child: const DealerDisc(size: 18),
          ),
      ],
    );

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Semantics(
        container: true,
        label: _semanticLabel(),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp:
                (onTap == null && onEye == null)
                    ? null
                    : (details) {
                      final inEye =
                          eyeVisible &&
                          _eyeRect(size).contains(details.localPosition);
                      if (inEye) {
                        onEye!.call();
                      } else {
                        onTap?.call();
                      }
                    },
            onLongPress:
                onLongPress == null
                    ? null
                    : () {
                      if (enableHaptics) HapticFeedback.mediumImpact();
                      onLongPress!.call();
                    },
            child: stack,
          ),
        ),
      ),
    );
  }

  Alignment get _dealerCorner =>
      mirrored ? Alignment.bottomRight : Alignment.bottomLeft;

  /// 44×44 in the plate's outer top corner; empty when the eye is hidden.
  Rect _eyeRect(Size size) =>
      mirrored
          ? Rect.fromLTWH(0, 0, eyeHit, eyeHit)
          : Rect.fromLTWH(size.width - eyeHit, 0, eyeHit, eyeHit);

  String _semanticLabel() {
    final parts = <String>[
      player.name,
      positionLabel(player.position, seats),
      '${fmtBb(player.stack, bigBlind)} big blinds',
    ];
    if (player.handsSeen >= minSample) {
      final n = player.handsSeen;
      parts.add(
        'VPIP ${jsIntString(jsRound(player.vpipCount / n * 100))} '
        'PFR ${jsIntString(jsRound(player.pfrCount / n * 100))}',
      );
    }
    final last = player.lastAction;
    if (last != null) parts.add(last.label);
    if (state == SeatPlateState.allIn) parts.add('all in');
    if (state == SeatPlateState.folded) parts.add('folded');
    return parts.join(', ');
  }
}

class _PlateBody extends StatelessWidget {
  const _PlateBody({
    required this.player,
    required this.variant,
    required this.state,
    required this.bigBlind,
    required this.seats,
    required this.thinking,
    required this.rebought,
    required this.avatar,
    required this.nameLimit,
    required this.reducedMotion,
  });

  final Player player;
  final SeatPlateVariant variant;
  final SeatPlateState state;
  final int bigBlind;
  final int seats;
  final bool thinking;
  final bool rebought;
  final double avatar;
  final int nameLimit;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = variant == SeatPlateVariant.compact;
    final ring = archetypeColor(player.archetype);
    final name =
        player.name.length > nameLimit
            ? player.name.substring(0, nameLimit)
            : player.name;

    final stackLine =
        state == SeatPlateState.allIn
            ? _AllInPill(compact: compact)
            : Text(
              '${fmtBb(player.stack, bigBlind)} bb',
              maxLines: 1,
              style: AllInText.mono(
                compact ? 12 : 13,
                color: c.goldLight.withValues(alpha: 0.90),
              ),
            );

    final Widget hudLine;
    if (rebought) {
      hudLine = Text(
        'rebought',
        maxLines: 1,
        style: AllInText.body(10, color: c.textFaint),
      );
    } else if (thinking) {
      hudLine = _Thinking(reducedMotion: reducedMotion);
    } else if (compact) {
      // §4.2.2: no VPIP/PFR on the 9-max plate — sample size only.
      hudLine = Text(
        '· ${player.handsSeen}h',
        maxLines: 1,
        style: AllInText.mono(11, color: c.textFaint),
      );
    } else {
      hudLine = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
          ),
          const SizedBox(width: 4),
          Text(
            SeatPlate.hudNumbers(player),
            maxLines: 1,
            style: AllInText.mono(10, color: c.textMuted),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(
          initial: player.isHero ? 'Y' : (name.isEmpty ? '?' : name[0]),
          color: player.isHero ? c.gold : ring,
          size: avatar,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The plate is a fixed box on the felt: at 1.15× (§4.2.4) or
              // with a wide name the line scales down rather than clipping.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      softWrap: false,
                      style: AllInText.body(
                        compact ? 12 : 13,
                        weight: FontWeight.w600,
                        color: c.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    PositionPill(
                      label: positionLabel(player.position, seats),
                      fontSize: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [stackLine, const SizedBox(width: 6), hudLine],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.color,
    required this.size,
  });

  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5),
      ),
      child: Text(
        initial,
        style: AllInText.display(size * 0.46, color: color, height: 1),
      ),
    );
  }
}

class _AllInPill extends StatelessWidget {
  const _AllInPill({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AllInColors.chipRed.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AllInRadius.sm),
        border: Border.all(
          color: AllInColors.chipRed.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        'ALL-IN',
        maxLines: 1,
        style: AllInText.body(
          compact ? 9 : 10,
          weight: FontWeight.w700,
          color: AllInColors.chipRed,
          height: 1.1,
        ),
      ),
    );
  }
}

/// §11: three dots in sequence, or the static word "thinking".
class _Thinking extends StatefulWidget {
  const _Thinking({required this.reducedMotion});

  final bool reducedMotion;

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced =
        AllInMotion.of(
          context,
          AllInMotion.base,
          reduced: widget.reducedMotion,
        ) ==
        Duration.zero;

    if (reduced) {
      if (_controller.isAnimating) _controller.stop();
      return Text(
        'thinking',
        maxLines: 1,
        style: AllInText.mono(10, color: c.textFaint),
      );
    }
    if (!_controller.isAnimating) _controller.repeat();

    return Semantics(
      label: 'thinking',
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Opacity(
                    opacity: 0.35 + 0.65 * _pulse(i, _controller.value),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
  }

  double _pulse(int index, double t) {
    final phase = (t - index / 3) % 1.0;
    return phase < 0.34 ? 1 - (phase / 0.34) : 0;
  }
}

/// The white dealer disc — used on the plate corner nearest the pot and, at
/// 16 pt, left of the hero strip's position pill (§4.3, §4.4).
class DealerDisc extends StatelessWidget {
  const DealerDisc({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dealer button',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFFFF),
          boxShadow: [
            BoxShadow(
              color: AllInColors.dark.shadowColor.withValues(alpha: 0.35),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          'D',
          style: AllInText.display(
            size * 0.55,
            color: AllInColors.dark.ink900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// The 10 pt caps position tag (UTG / MP / CO / BTN / SB / BB; HU: BTN/SB).
class PositionPill extends StatelessWidget {
  const PositionPill({super.key, required this.label, this.fontSize = 11});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.text.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AllInRadius.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AllInText.body(
          fontSize,
          weight: FontWeight.w600,
          color: c.textMuted,
          height: 1.1,
        ).copyWith(letterSpacing: 0.4),
      ),
    );
  }
}
