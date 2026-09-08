/// `ChipStack` — the three-disc chip stack used by the bet and pot animations
/// (DESIGN.md §10.3; motion §11 "chips plate → bet spot", "pot to winner").
library;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class ChipStack extends StatelessWidget {
  const ChipStack({
    super.key,
    required this.amount,
    this.color,
    this.bigBlind = 20,
    this.discSize = 14,
    this.showAmount = false,
  });

  /// Chips (engine units). Only used for the optional caption and to pick a
  /// denomination colour when [color] is null.
  final num amount;

  /// Overrides the denomination colour.
  final Color? color;
  final int bigBlind;

  /// Diameter of one disc.
  final double discSize;

  /// Renders "4.5 bb" in mono under the stack.
  final bool showAmount;

  /// Desktop denomination ladder, by size in big blinds.
  static Color denominationColor(num chips, int bigBlind) {
    final bb = bigBlind <= 0 ? 1 : bigBlind;
    final inBb = chips / bb;
    if (inBb >= 50) return AllInColors.chipPurple;
    if (inBb >= 20) return AllInColors.chipBlack;
    if (inBb >= 10) return AllInColors.chipGreen;
    if (inBb >= 3) return AllInColors.chipBlue;
    return AllInColors.chipRed;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disc = color ?? denominationColor(amount, bigBlind);
    final overlap = discSize * 0.42;
    final stackHeight = discSize + overlap * 2;

    return Semantics(
      label: '${fmtBb(amount, bigBlind)} big blinds',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: discSize,
            height: stackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    top: i * overlap,
                    child: _Disc(size: discSize, color: disc, shade: i / 3),
                  ),
              ],
            ),
          ),
          if (showAmount) ...[
            const SizedBox(height: 2),
            Text(
              '${fmtBb(amount, bigBlind)} bb',
              style: AllInText.mono(11, color: c.goldLight),
            ),
          ],
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color, required this.shade});

  final double size;
  final Color color;
  final double shade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.72,
      decoration: BoxDecoration(
        color: Color.lerp(color, AllInColors.dark.ink900, shade * 0.35),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: AllInColors.dark.shadowColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
    );
  }
}
