/// The two chart cards of DESIGN.md §7.3: "Cumulative winnings (bb)" and
/// "Range-read accuracy".
///
/// Both are drag-to-inspect and neither is tappable: `LineChart` and
/// `MiniBars` each put a 200 ms `LongPressGestureRecognizer` in the arena, so
/// scrolling past the card never spawns a value label and a scrub never lets
/// the page slide out from under the thumb (§7.3, §12). This file only decides
/// what the floating labels *say* — the gesture contract lives in the shared
/// widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/stats_metrics.dart';
import '../stats_copy.dart';
import '../stats_format.dart';
import 'stats_section.dart';

/// §7.1's cumulative chart: 170 tall, tone by the sign of the lifetime net,
/// the desktop's empty line under two points.
class CumulativeChartCard extends ConsumerWidget {
  const CumulativeChartCard({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);

    // The window can be shorter than the lifetime (§5 keeps 800 rows), so the
    // scrub label counts lifetime hands, not indices into the window.
    final offset = metrics.handsPlayed - metrics.cumulative.length;

    return StatsSection(
      title: StatsCopy.cumulativeCard,
      child: LineChart(
        values: metrics.cumulative,
        color: metrics.netBb >= 0 ? c.good : c.bad,
        emptyText: StatsCopy.chartEmpty,
        enableHaptics: settings.haptics,
        reducedMotion: settings.reducedMotion,
        labelBuilder:
            (index, value) => StatsCopy.chartScrubLabel(
              (offset > 0 ? offset : 0) + index + 1,
              value,
            ),
      ),
    );
  }
}

/// §7.3's MiniBars strip: the last 30 Peek scores, one 44 pt gesture band, a
/// label that follows the finger.
class ReadAccuracyCard extends ConsumerWidget {
  const ReadAccuracyCard({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final scores = metrics.readScores;
    final guesses = metrics.guesses;
    final offset = guesses.length - scores.length;

    return StatsSection(
      title: StatsCopy.readAccuracyCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniBars(
            values: scores,
            color: c.info,
            emptyText: StatsCopy.readsEmpty,
            enableHaptics: settings.haptics,
            reducedMotion: settings.reducedMotion,
            labelBuilder:
                (index, value) => StatsCopy.readScrubLabel(
                  index: offset + index + 1,
                  score: value,
                  detail: _detail(offset + index),
                ),
          ),
          if (scores.isNotEmpty) ...[
            const SizedBox(height: AllInSpace.sm),
            Text(
              StatsCopy.readsCaption(scores.length),
              style: AllInText.body(12, color: c.textFaint),
            ),
          ],
        ],
      ),
    );
  }

  /// "Nit, flop, 3 days ago" — the read's own context, from the record the
  /// bar was drawn from.
  String _detail(int index) {
    final guesses = metrics.guesses;
    if (index < 0 || index >= guesses.length) return '';
    final g = guesses[index];
    return [
      if (g.archetype != null) g.archetype!.label,
      g.street,
      relativeDayLabel(g.ts),
    ].join(', ');
  }
}
