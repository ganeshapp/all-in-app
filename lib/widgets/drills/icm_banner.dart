/// `IcmBanner` — the gold-outline bubble banner on ICM push/fold spots
/// (DESIGN.md §5.6, §10.6):
///
/// ```
/// ┌ BUBBLE · 4 left, 3 paid · 50 / 30 / 20 ┐
/// │ Chip leader in the BB                  │
/// └────────────────────────────────────────┘
/// ```
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class IcmBanner extends StatelessWidget {
  const IcmBanner({
    super.key,
    required this.scenarioName,
    this.playersLeft = 4,
    this.paid = 3,
    this.payouts = const [50, 30, 20],
  });

  /// e.g. "Chip leader in the BB".
  final String scenarioName;
  final int playersLeft;
  final int paid;

  /// Payout percentages, largest first.
  final List<int> payouts;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.md,
        vertical: AllInSpace.xs,
      ),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AllInRadius.md),
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BUBBLE · $playersLeft left, $paid paid · '
            '${payouts.join(' / ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AllInText.eyebrow(c.gold),
          ),
          Text(
            scenarioName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AllInText.body(13, color: c.text),
          ),
        ],
      ),
    );
  }
}
