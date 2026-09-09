/// `CoachingReviewCard` — DESIGN.md §7.1 / §7.4 and the desktop's
/// "Coaching review" card (`docs/port/persistence-stats-settings.md` §7.6).
///
/// Three verdict boxes, then each leak sentence as a tappable bolt row (→ the
/// three-layer sheet of §3.4, so the numbers behind the sentence are one tap
/// away), then the "Recent −EV decisions" rows, then "Review these spots ›"
/// when the Review queue has something due.
///
/// A −EV row opens the hand it came from at the frame it came from, when that
/// hand is still stored (§7.1); when it is not, the row is inert copy rather
/// than a dead button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine.dart'
    show
        DecisionRecord,
        kLeakCallTooWide,
        kLeakCleanDiscipline,
        kLeakFoldTooOften;
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/stats_metrics.dart';
import '../stats_copy.dart';
import 'stats_section.dart';

class CoachingReviewCard extends ConsumerWidget {
  const CoachingReviewCard({
    super.key,
    required this.metrics,
    required this.dueCount,
    this.onReviewSpots,
    this.onOpenLesson,
    this.onOpenDecision,
  });

  final StatsMetrics metrics;

  /// Spots due in the Review queue; the button appears only above zero.
  final int dueCount;

  final VoidCallback? onReviewSpots;

  /// `(lessonId)` — the secondary button inside the leak sheet (§3.4).
  final ValueChanged<String>? onOpenLesson;

  /// Opens the hand behind a −EV decision at its frame, when it is stored.
  final ValueChanged<DecisionRecord>? onOpenDecision;

  /// The lessons §3.4 links each sentence to.
  static const String potOddsLesson = 'pot-odds';
  static const String rangeLesson = 'drill-range';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final leak = metrics.leak;

    if (leak.total == 0) {
      return StatsSection(
        title: StatsCopy.coachingReviewCard,
        child: Text(
          StatsCopy.coachingReviewEmpty,
          style: AllInText.body(14, color: c.textMuted, height: 1.5),
        ),
      );
    }

    return StatsSection(
      title: StatsCopy.coachingReviewCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _VerdictBox(
                  label: StatsCopy.verdictMistakes,
                  value: leak.mistakes,
                  color: c.bad,
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: _VerdictBox(
                  label: StatsCopy.verdictThinSpots,
                  value: leak.thin,
                  color: c.warn,
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: _VerdictBox(
                  label: StatsCopy.verdictGreatPlays,
                  value: leak.great,
                  color: c.good,
                ),
              ),
            ],
          ),
          for (final sentence in metrics.allLeaks) ...[
            const SizedBox(height: AllInSpace.sm),
            _LeakRow(
              sentence: sentence,
              onTap: () => _explainLeak(context, ref, sentence),
            ),
          ],
          if (metrics.recentMistakes.isNotEmpty) ...[
            const SizedBox(height: AllInSpace.md),
            Text(
              StatsCopy.recentNegativeEv,
              style: AllInText.body(13, weight: FontWeight.w600, color: c.text),
            ),
            for (final d in metrics.recentMistakes)
              _DecisionRow(
                decision: d,
                onTap: onOpenDecision == null ? null : () => onOpenDecision!(d),
              ),
          ],
          if (dueCount > 0 && onReviewSpots != null) ...[
            const SizedBox(height: AllInSpace.md),
            AllInButton.secondary(
              label: StatsCopy.reviewTheseSpots,
              expand: true,
              onPressed: onReviewSpots,
            ),
          ],
        ],
      ),
    );
  }

  /// §3.4's H1: the sentence, the numbers behind it, the rule, and a way on.
  void _explainLeak(BuildContext context, WidgetRef ref, String sentence) {
    final leak = metrics.leak;
    final (String math, String expert, String lesson) = switch (sentence) {
      kLeakFoldTooOften => (
        StatsCopy.leakMath(
          kind: 'folds',
          count: leak.foldMistakes,
          total: leak.total,
        ),
        StatsCopy.leakExpert,
        potOddsLesson,
      ),
      kLeakCallTooWide => (
        StatsCopy.leakMath(
          kind: 'calls',
          count: leak.callMistakes,
          total: leak.total,
        ),
        StatsCopy.leakExpert,
        potOddsLesson,
      ),
      kLeakCleanDiscipline => (
        StatsCopy.cleanDisciplineMath,
        StatsCopy.cleanDisciplineExpert,
        potOddsLesson,
      ),
      _ => (StatsCopy.readLeakMath, StatsCopy.readLeakExpert, rangeLesson),
    };

    showStatsExplainer(
      context,
      ref,
      title: StatsCopy.coachingReviewCard,
      body: sentence,
      math: math,
      expert: expert,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onOpenLesson != null)
            AllInButton.secondary(
              label: StatsCopy.openTheLesson,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                onOpenLesson!(lesson);
              },
            ),
          if (dueCount > 0 && onReviewSpots != null) ...[
            const SizedBox(height: AllInSpace.sm),
            AllInButton.ghost(
              label: StatsCopy.reviewTheseSpots,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                onReviewSpots!();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _VerdictBox extends StatelessWidget {
  const _VerdictBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label, $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AllInSpace.sm,
            vertical: AllInSpace.md,
          ),
          decoration: BoxDecoration(
            color: c.ink850,
            borderRadius: BorderRadius.circular(AllInRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value', style: AllInText.mono(22, color: color)),
              const SizedBox(height: 2),
              Eyebrow(label, color: c.textFaint, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeakRow extends StatelessWidget {
  const _LeakRow({required this.sentence, required this.onTap});

  final String sentence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: sentence,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AllInSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt, size: 16, color: c.gold),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    sentence,
                    style: AllInText.body(14, color: c.text, height: 1.45),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision, this.onTap});

  final DecisionRecord decision;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = StatsCopy.decisionRow(
      street: decision.street,
      action: decision.action,
      archetype: decision.villainArchetype,
    );
    final right = StatsCopy.decisionNumbers(
      equity: decision.equity,
      potOdds: decision.potOdds,
      evBb: decision.evBb,
    );

    return Semantics(
      button: onTap != null,
      label: '$left, $right',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(14, color: c.text),
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                // The numbers never wrap and never clip: at 1.3× the line
                // scales down rather than pushing the row off screen (§13).
                Expanded(
                  flex: 6,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      right,
                      maxLines: 1,
                      style: AllInText.mono(12, color: c.bad),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
