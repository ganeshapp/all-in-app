/// `PotPill` — "PRE-FLOP · Pot 4.5 bb" at the pot anchor (DESIGN.md §10.3;
/// copy and colours from docs/port/design-brand-onboarding.md §6.2).
library;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../engine/types.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class PotPill extends StatelessWidget {
  const PotPill({
    super.key,
    required this.street,
    required this.pot,
    this.bigBlind = 20,
    this.maxWidth = 130,
  });

  final Street street;

  /// Chips.
  final num pot;
  final int bigBlind;

  /// ≤ 130 at 390 (120 at 360, 143 at 430) — §4.2 / §4.2.3.
  final double maxWidth;

  static const double height = 24;

  /// Desktop `STREET_LABEL`, upper-cased for the eyebrow.
  static String streetLabel(Street street) => switch (street) {
    Street.preflop => 'Pre-flop',
    Street.flop => 'Flop',
    Street.turn => 'Turn',
    Street.river => 'River',
    Street.showdown => 'Showdown',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount = '${fmtBb(pot, bigBlind)} bb';

    return Semantics(
      label: '${streetLabel(street)}, pot $amount',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, minHeight: height),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
          decoration: BoxDecoration(
            color: AllInColors.dark.shadowColor.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AllInRadius.pill),
            border: Border.all(color: c.gold.withValues(alpha: 0.30), width: 1),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  streetLabel(street).toUpperCase(),
                  style: AllInText.eyebrow(
                    const Color(0xFFFFFFFF).withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Text(
                  'Pot $amount',
                  style: AllInText.mono(12, color: c.goldLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
