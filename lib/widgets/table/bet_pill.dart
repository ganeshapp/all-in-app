/// `BetPill` — the 22 pt pill at a bet spot: a chip glyph plus a mono amount,
/// and the same component renders the seat's last-action pill (DESIGN.md
/// §10.3; colours and behaviour §4.3, geometry §4.2).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Action tone (§4.3): Raise/Bet gold · All-in chipRed · Call info ·
/// Check muted · Fold faint · blinds and antes post at the same anchor.
enum BetPillKind { bet, raise, call, check, fold, allIn, blind, ante }

class BetPill extends StatelessWidget {
  const BetPill({
    super.key,
    required this.kind,
    this.amount,
    this.bigBlind = 20,
    this.label,
    this.isHero = false,
    this.maxWidth = 44,
    this.onTap,
    this.semanticLabel,
    this.reducedMotion = false,
  });

  final BetPillKind kind;

  /// Chips committed. Null renders the label alone (Fold / Check).
  final num? amount;
  final int bigBlind;

  /// Overrides the derived text ("Fold", "SB", "3 bb", …).
  final String? label;

  /// The hero's own pill is narrower and reads "(you)" (§4.2).
  final bool isHero;

  /// 44 at 390 (hero 40); 48/44 at 430, 40/36 at 360 (§4.2).
  final double maxWidth;

  /// Tap the action pill → Explain last move (§4.10). Hit box 44 tall.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool reducedMotion;

  static const double height = 22;

  static Color toneOf(BuildContext context, BetPillKind kind) {
    final c = context.colors;
    return switch (kind) {
      BetPillKind.bet || BetPillKind.raise => c.gold,
      BetPillKind.allIn => AllInColors.chipRed,
      BetPillKind.call => c.info,
      BetPillKind.check => c.textMuted,
      BetPillKind.fold => c.textFaint,
      BetPillKind.blind || BetPillKind.ante => c.textMuted,
    };
  }

  /// Maps the engine's `PlayerLastAction.label` to a pill kind.
  static BetPillKind kindFromActionLabel(String actionLabel) =>
      switch (actionLabel) {
        'Raise' => BetPillKind.raise,
        'Bet' => BetPillKind.bet,
        'Call' => BetPillKind.call,
        'Check' => BetPillKind.check,
        'Fold' => BetPillKind.fold,
        'All-In' => BetPillKind.allIn,
        'SB' || 'BB' => BetPillKind.blind,
        _ => BetPillKind.check,
      };

  String _text() {
    if (label != null) return label!;
    if (amount != null && amount != 0) {
      return '${fmtBb(amount!, bigBlind)} bb';
    }
    return switch (kind) {
      BetPillKind.fold => 'Fold',
      BetPillKind.check => 'Check',
      BetPillKind.call => 'Call',
      BetPillKind.bet => 'Bet',
      BetPillKind.raise => 'Raise',
      BetPillKind.allIn => 'ALL-IN',
      BetPillKind.blind => 'Blind',
      BetPillKind.ante => 'Ante',
    };
  }

  /// The text this pill renders, "(you)" included.
  String get renderedText {
    final base = _text();
    return isHero ? '$base (you)' : base;
  }

  /// Whether the pill carries its 7 pt chip disc.
  bool get hasChip => amount != null && amount != 0;

  /// The width this pill will lay out at.
  ///
  /// Callers that have to keep pills off each other need this *before* the
  /// pill is built, because [maxWidth] is the §4.2 nominal width and not what
  /// the pill actually takes — see [build].
  double get layoutWidth => math.max(
    maxWidth,
    _needed(renderedText, _styleFor(hasChip), TextScaler.noScaling, hasChip),
  );

  /// The measured style. Colour does not affect width, so the caller-facing
  /// [layoutWidth] can build it without a `BuildContext`.
  static TextStyle _styleFor(bool hasChip) =>
      hasChip
          ? AllInText.mono(11)
          : AllInText.body(11, weight: FontWeight.w600);

  /// The width the pill's row needs at its full 11 pt type.
  static double _needed(
    String text,
    TextStyle style,
    TextScaler scaler,
    bool hasChip,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    // chip glyph 7 + 4 gap, plus the container's 7 pt of padding either side.
    return painter.maxIntrinsicWidth + (hasChip ? 11 : 0) + 14;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = toneOf(context, kind);
    final base = _text();
    final hasChip = this.hasChip;

    final style = _styleFor(
      hasChip,
    ).copyWith(color: hasChip ? c.goldLight : tone);
    final withYou = '$base (you)';
    final text = isHero ? withYou : base;

    // §13's 11 pt legibility floor. [maxWidth] is the §4.2 *nominal* pill
    // width, not a hard clip: "● 0.5 bb (you)" needs ~104 pt and the hero
    // budget is 36–44, so honouring the cap literally handed `FittedBox` a
    // 0.55 scale — about 6 pt type and a 4 px chip dot on the one number the
    // hero most needs to read. The pill therefore grows to whatever its own
    // text needs at 11 pt, and `FittedBox` only ever engages above 1.0× text
    // scale (where it can shrink back to, but never below, 11 pt).
    final atOnePoint = _needed(text, style, TextScaler.noScaling, hasChip);
    final width = math.max(maxWidth, atOnePoint);

    final pill = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, minHeight: height),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: AllInColors.dark.shadowColor.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(AllInRadius.pill),
          border: Border.all(color: tone.withValues(alpha: 0.35), width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasChip) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(text, maxLines: 1, style: style),
            ],
          ),
        ),
      ),
    );

    final animated = AnimatedScale(
      scale: 1,
      duration: AllInMotion.of(
        context,
        const Duration(milliseconds: 200),
        reduced: reducedMotion,
      ),
      curve: AllInMotion.ease,
      child: pill,
    );

    final labelled = Semantics(
      label: semanticLabel ?? (isHero ? withYou : text),
      button: onTap != null,
      child: animated,
    );

    if (onTap == null) return labelled;
    // §4.3: the action pill's hit box is 44 tall and the pill width + 8 pt.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: labelled,
          ),
        ),
      ),
    );
  }
}
