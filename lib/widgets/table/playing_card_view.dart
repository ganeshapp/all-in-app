/// `PlayingCardView` — one playing card, face or back (DESIGN.md §10.3).
///
/// Width-driven: every dimension derives from [width] exactly as
/// docs/port/design-brand-onboarding.md §5 specifies, so adding a new call-site
/// width is a one-line change and never touches this file. Card ranks are
/// graphics, not prose: they never scale with the system text size (§13).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Face/back renderer for a single engine [Card] (`"Ah"`, `"Td"`, …).
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    this.card,
    required this.width,
    this.faceDown = false,
    this.dimmed = false,
    this.glow = false,
    this.fourColorDeck = false,
    this.greyscale = false,
  });

  /// Two-char engine card. `null` renders the back (same as [faceDown]).
  final String? card;

  /// The only size input; see the §10.3 call-site table.
  final double width;
  final bool faceDown;

  /// 55 % opacity — folded seats and reveal rows (§4.12).
  final bool dimmed;

  /// Gold glow — the hero's cards on their turn (§4.4).
  final bool glow;

  /// Settings → four-colour deck: ♦ blue, ♣ green (§9).
  final bool fourColorDeck;

  /// Desaturates a revealed folded hand (§4.12 step 1).
  final bool greyscale;

  // §10.3 call-site shorthands. These are the widths this spec uses; the widget
  // itself accepts any double.
  static const double xs = 22;
  static const double s = 30;
  static const double m = 44;
  static const double l = 52;
  static const double xl = 72;
  static const double xxl = 80;

  /// height = width × 1.4, rounded to whole pt.
  static double heightFor(double width) => (width * 1.4).roundToDouble();

  /// radius = width × 0.125, rounded to whole pt, floor 4 (§10.3).
  static double radiusFor(double width) =>
      math.max(4, (width * 0.125).roundToDouble());

  /// ♠ ♥ ♦ ♣ for the engine's `c d h s` suit chars.
  static String suitGlyph(String suit) => switch (suit) {
    'h' => '♥',
    'd' => '♦',
    'c' => '♣',
    _ => '♠',
  };

  /// Two-colour deck: ♠♣ black, ♥♦ red. Four-colour: ♦ blue, ♣ green (§1.4).
  static Color suitColor(String suit, {bool fourColorDeck = false}) =>
      switch (suit) {
        'h' => AllInColors.suitRed,
        'd' => fourColorDeck ? AllInColors.suitBlue : AllInColors.suitRed,
        'c' => fourColorDeck ? AllInColors.suitGreen : AllInColors.suitBlack,
        _ => AllInColors.suitBlack,
      };

  /// "T" prints as "10"; every other rank is its own character.
  static String rankGlyph(String rank) => rank == 'T' ? '10' : rank;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = heightFor(w);
    final radius = radiusFor(w);
    final showBack = faceDown || card == null || card!.length < 2;

    Widget face = showBack ? _back(w, h, radius) : _face(w, h, radius);

    if (greyscale) {
      face = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: face,
      );
    }
    if (dimmed) face = Opacity(opacity: 0.55, child: face);

    return Semantics(
      label: showBack ? 'Face-down card' : _semanticLabel(card!),
      image: true,
      child: SizedBox(
        width: w,
        height: h,
        child:
            glow
                ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        color: AllInColors.dark.gold.withValues(alpha: 0.55),
                        blurRadius: w * 0.30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: face,
                )
                : face,
      ),
    );
  }

  Widget _face(double w, double h, double radius) {
    final rank = rankGlyph(card![0]);
    final suit = card![1];
    final ink = suitColor(suit, fourColorDeck: fourColorDeck);
    final glyph = suitGlyph(suit);

    return MediaQuery.withNoTextScaling(
      child: Container(
        width: w,
        height: h,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AllInColors.cardFaceTop, AllInColors.cardFaceBottom],
          ),
          border: Border.all(
            color: AllInColors.dark.shadowColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: w * 0.12,
              top: h * 0.06,
              child: Text(
                rank,
                style: AllInText.display(
                  (w * 0.36).roundToDouble(),
                  color: ink,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: w * 0.13,
              top: h * 0.34,
              child: Text(
                glyph,
                style: AllInText.body(
                  (w * 0.26).roundToDouble(),
                  color: ink,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              right: w * 0.08,
              bottom: h * 0.04,
              child: Opacity(
                opacity: 0.92,
                child: Text(
                  glyph,
                  style: AllInText.body(
                    (w * 0.50).roundToDouble(),
                    color: ink,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _back(double w, double h, double radius) {
    final gold = AllInColors.dark.gold;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.55, 1],
          colors: [
            AllInColors.cardBackA,
            AllInColors.cardBackB,
            AllInColors.cardBackC,
          ],
        ),
        border: Border.all(
          color: AllInColors.dark.shadowColor.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(math.max(2, radius - 2)),
            border: Border.all(color: gold.withValues(alpha: 0.45), width: 1),
          ),
          child: Center(
            child: Container(
              width: w * 0.34,
              height: w * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: gold.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Map<String, String> _rankWords = {
    'A': 'ace',
    'K': 'king',
    'Q': 'queen',
    'J': 'jack',
    'T': 'ten',
    '9': 'nine',
    '8': 'eight',
    '7': 'seven',
    '6': 'six',
    '5': 'five',
    '4': 'four',
    '3': 'three',
    '2': 'two',
  };

  static const Map<String, String> _suitWords = {
    's': 'spades',
    'h': 'hearts',
    'd': 'diamonds',
    'c': 'clubs',
  };

  /// "queen of spades" — §13 screen-reader wording.
  static String _semanticLabel(String card) {
    final rank = _rankWords[card[0]] ?? card[0];
    final suit = _suitWords[card[1]] ?? card[1];
    return '$rank of $suit';
  }
}
