/// Review mode with nothing due (DESIGN.md §5.5, §14 "Drills · Review,
/// nothing due" and "Review, no cards ever").
///
/// Two headlines and two bodies, both verbatim from the desktop, chosen by
/// whether any card has ever been scheduled; plus the mobile "Next due" line,
/// which is hidden when nothing is scheduled at all.
library;

import 'package:flutter/material.dart';

import '../../../engine/coach.dart' show Verdict;
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../content/drill_copy.dart';

class ReviewEmptyState extends StatelessWidget {
  const ReviewEmptyState({
    super.key,
    required this.totalCards,
    required this.nextDueAt,
    required this.now,
    required this.onPlay,
    required this.onDrillMixed,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  /// Leaks + review cards, due or not.
  final int totalCards;

  /// The earliest not-yet-due schedule, or null.
  final DateTime? nextDueAt;

  /// "Next due" is phrased relative to this instant.
  final DateTime now;

  final VoidCallback onPlay;
  final VoidCallback onDrillMixed;
  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasCards = totalCards > 0;
    final due = nextDueAt;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AllInSpace.lg,
          vertical: AllInSpace.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: VerdictBadge(verdict: Verdict.great, size: 48),
              ),
              const SizedBox(height: AllInSpace.lg),
              Text(
                hasCards ? DrillCopy.nothingDue : DrillCopy.noSpotsYet,
                textAlign: TextAlign.center,
                style: AllInText.display(22, color: c.text),
              ),
              const SizedBox(height: AllInSpace.md),
              Text(
                hasCards
                    ? DrillCopy.allScheduled(totalCards)
                    : DrillCopy.noSpotsBody,
                textAlign: TextAlign.center,
                style: AllInText.body(15, color: c.textMuted, height: 1.5),
              ),
              if (due != null) ...[
                const SizedBox(height: AllInSpace.md),
                Text(
                  DrillCopy.nextDue(due, now),
                  textAlign: TextAlign.center,
                  style: AllInText.mono(12, color: c.textFaint),
                ),
              ],
              const SizedBox(height: AllInSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: AllInButton.secondary(
                      label: DrillCopy.playASession,
                      leading: Icons.play_arrow_rounded,
                      onPressed: onPlay,
                      expand: true,
                      enableHaptics: enableHaptics,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                  const SizedBox(width: AllInSpace.sm),
                  Expanded(
                    child: AllInButton.secondary(
                      label: DrillCopy.drillMixed,
                      leading: Icons.my_location_rounded,
                      onPressed: onDrillMixed,
                      expand: true,
                      enableHaptics: enableHaptics,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
