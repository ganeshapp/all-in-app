/// `KpiGrid` — the 3 + 2 tile block of DESIGN.md §7.2.
///
/// Five tiles, never a horizontal scroller: three across the first row and two
/// across the second, so every number is on screen at 360, 390 and 430 pt.
/// Each tile carries a 44 pt ⓘ that opens T1 with the verbatim body, math and
/// expert lines of §7.2 — including for the stats whose "math" is a written
/// definition rather than an arithmetic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine.dart' show fmtPct, fmtSigned;
import '../../../theme/tokens.dart';
import '../../../widgets/widgets.dart';
import '../providers/stats_metrics.dart';
import '../stats_copy.dart';
import 'stats_section.dart';

/// Peek scores listed in the read-accuracy explainer. The mean is over every
/// read, but printing 800 percentages would be a wall of digits, so the line
/// shows the most recent [_scoreListLimit] and says so with an ellipsis.
const int _scoreListLimit = 12;

class KpiGrid extends ConsumerWidget {
  const KpiGrid({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // §13's money rule, from the one helper: a flat zero is neither a win nor
    // a loss, so it is muted instead of painted in the win green.
    final netTone = StatTone.money(metrics.netBb);
    final rateTone = StatTone.money(metrics.bb100);
    final reads = metrics.guesses.length;

    return Column(
      children: [
        // `IntrinsicHeight` is what lets the tiles in a row share a height
        // while each one sizes to its own content: `StatTile` treats its
        // height as a minimum so it grows at 1.3× text instead of clipping
        // (§13), and a stretched `Row` inside a scroll view has no height of
        // its own to stretch to.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: StatsCopy.kpiHands,
                  value: '${metrics.handsPlayed}',
                  onInfo: () => _explainHands(context, ref),
                  infoSemanticLabel: 'About hands',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: StatsCopy.kpiNet,
                  value: '${fmtSigned(metrics.netBb)} bb',
                  tone: netTone,
                  onInfo: () => _explainNet(context, ref),
                  infoSemanticLabel: 'About net',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: StatsCopy.kpiWinRate,
                  value: fmtSigned(metrics.bb100),
                  sub: StatsCopy.kpiWinRateSub,
                  tone: rateTone,
                  onInfo: () => _explainWinRate(context, ref),
                  infoSemanticLabel: 'About win rate',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AllInSpace.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: StatsCopy.kpiShowdown,
                  value: fmtPct(metrics.sdWin),
                  sub: StatsCopy.kpiShowdownSub,
                  onInfo: () => _explainShowdown(context, ref),
                  infoSemanticLabel: 'About showdown',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: StatsCopy.kpiReadAccuracy,
                  value: reads == 0 ? '\u2014' : fmtPct(metrics.avgAcc),
                  sub: StatsCopy.kpiReadsSub(reads),
                  onInfo: () => _explainReadAccuracy(context, ref),
                  infoSemanticLabel: 'About read accuracy',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _explainHands(BuildContext context, WidgetRef ref) => showStatsExplainer(
    context,
    ref,
    title: StatsCopy.kpiHands,
    body: StatsCopy.handsBody,
    math: StatsCopy.handsMath,
    expert: StatsCopy.handsExpert,
  );

  void _explainNet(BuildContext context, WidgetRef ref) => showStatsExplainer(
    context,
    ref,
    title: StatsCopy.kpiNet,
    body: StatsCopy.netBody,
    math: StatsCopy.netMath(
      won: metrics.wonBb,
      lost: metrics.lostBb,
      net: metrics.netBb,
    ),
    expert: StatsCopy.netExpert,
  );

  void _explainWinRate(BuildContext context, WidgetRef ref) =>
      showStatsExplainer(
        context,
        ref,
        title: StatsCopy.winRateTitle,
        body: StatsCopy.winRateBody,
        math: StatsCopy.winRateMath(
          net: metrics.netBb,
          hands: metrics.handsPlayed,
          bb100: metrics.bb100,
        ),
        expert: StatsCopy.winRateExpert,
        mathExtra: _TrendWindows(metrics: metrics),
      );

  void _explainShowdown(BuildContext context, WidgetRef ref) =>
      showStatsExplainer(
        context,
        ref,
        title: StatsCopy.kpiShowdown,
        body: StatsCopy.showdownBody,
        math: StatsCopy.showdownMath(
          won: metrics.showdownWon,
          reached: metrics.showdownHands,
        ),
        expert: StatsCopy.showdownExpert,
      );

  void _explainReadAccuracy(BuildContext context, WidgetRef ref) =>
      showStatsExplainer(
        context,
        ref,
        title: StatsCopy.kpiReadAccuracy,
        body: StatsCopy.readAccuracyBody,
        math: StatsCopy.readAccuracyMath(
          n: metrics.guesses.length,
          list: _scoreList(metrics),
        ),
        expert: StatsCopy.readAccuracyExpert,
      );

  static String _scoreList(StatsMetrics metrics) {
    final scores = [for (final g in metrics.guesses) g.accuracy];
    if (scores.isEmpty) return 'none yet';
    final shown =
        scores.length <= _scoreListLimit
            ? scores
            : scores.sublist(scores.length - _scoreListLimit);
    final text = shown.map(fmtPct).join(', ');
    return scores.length > shown.length ? '…, $text' : text;
  }
}

/// The trend companion to the lifetime win rate: bb/100 over the last 100 and
/// 500 hands, shown only once a window is full.
class _TrendWindows extends StatelessWidget {
  const _TrendWindows({required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final windows = metrics.trendWindows.entries.toList();
    if (windows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AllInSpace.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < windows.length; i++) ...[
              if (i > 0) const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: 'Last ${windows[i].key}',
                  value: fmtSigned(windows[i].value),
                  sub: 'bb/100',
                  tone: StatTone.money(windows[i].value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
