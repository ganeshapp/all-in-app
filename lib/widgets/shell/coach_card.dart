/// `CoachCard` — Home's coach's-note card (DESIGN.md §10.2, §3.4).
///
/// The coach's identity disc, one verbatim sentence, and "Show me why ›" which
/// opens H1 with the same sentence as layer 1. Gold is the coach's identity
/// here, never a verdict colour (§16.5).
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/all_in_card.dart';

class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.note,
    this.label = 'Coach',
    this.actionLabel = 'Show me why ›',
    this.onTap,
  });

  /// The verbatim sentence (§3.4's four sources).
  final String note;

  /// The identity line beside the disc.
  final String label;

  /// The affordance that opens H1. Hidden when [onTap] is null.
  final String actionLabel;

  final VoidCallback? onTap;

  static const double minHeight = 96;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard.plain(
      onTap: onTap,
      semanticLabel: '$label. $note',
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: minHeight - 2 * AllInSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.gold.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.gold.withValues(alpha: 0.35)),
                  ),
                  child: Text('C', style: AllInText.display(13, color: c.gold)),
                ),
                const SizedBox(width: AllInSpace.sm),
                Text(
                  label,
                  style: AllInText.body(
                    15,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AllInSpace.sm),
            Text(note, style: AllInText.body(15, color: c.text, height: 1.45)),
            if (onTap != null) ...[
              const SizedBox(height: AllInSpace.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  actionLabel,
                  style: AllInText.body(
                    14,
                    weight: FontWeight.w600,
                    color: c.gold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
