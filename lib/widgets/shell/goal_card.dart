/// `GoalCard` — Home's daily-goal card (DESIGN.md §10.2, §3.3).
///
/// Label · an 8 pt gold bar · the mono count · one muted caption. The whole
/// card is one target and opens H2. There is no celebration at 100 %: the bar
/// simply completes (§3.3, §11 "Goal met — bar completes (no confetti)").
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/all_in_card.dart';
import '../foundations/progress_bar_thin.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.label,
    required this.progress,
    required this.count,
    required this.caption,
    this.onTap,
    this.reducedMotion = false,
  });

  /// "Today".
  final String label;

  /// 0–1, already clamped by the caller (`GoalsState.progress`).
  final double progress;

  /// "8 of 20" — mono 15.
  final String count;

  /// "drills · or 30 hands — either counts".
  final String caption;

  final VoidCallback? onTap;
  final bool reducedMotion;

  static const double minHeight = 84;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard.plain(
      onTap: onTap,
      semanticLabel: '$label, $count, $caption',
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: minHeight - 2 * AllInSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AllInText.body(15, weight: FontWeight.w600, color: c.text),
            ),
            const SizedBox(height: AllInSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ProgressBarThin(
                    value: progress,
                    height: 8,
                    reducedMotion: reducedMotion,
                  ),
                ),
                const SizedBox(width: AllInSpace.md),
                Text(count, style: AllInText.mono(15, color: c.text)),
              ],
            ),
            const SizedBox(height: AllInSpace.xs),
            Text(caption, style: AllInText.body(13, color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}
