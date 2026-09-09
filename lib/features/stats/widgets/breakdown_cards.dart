/// The three breakdown cards of DESIGN.md §7.4: "Hands vs each style",
/// "Winnings by position" and "Style numbers".
///
/// Every number and every sentence is the desktop's
/// (`docs/port/persistence-stats-settings.md` §7.5, §7.7, §7.8); the mobile
/// specifics are the row heights (44), the 8 pt diverging bar, and the three
/// style rows opening T1 with `title = label`, `body = blurb`, footer
/// "Healthy range: {band}".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine.dart' show fmtPct, fmtSigned, kArchetypes;
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/stats_metrics.dart';
import '../stats_copy.dart';
import 'stats_section.dart';

/// §7.5 — one row per archetype: colour dot, name, signed net, sample bar.
class ArchetypeCard extends StatelessWidget {
  const ArchetypeCard({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = metrics.maxArchetypeHands;

    return StatsSection(
      title: StatsCopy.archetypesCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final stat in metrics.archetypes) ...[
            if (stat != metrics.archetypes.first)
              const SizedBox(height: AllInSpace.md),
            _ArchetypeRow(stat: stat, max: max, colors: c),
          ],
        ],
      ),
    );
  }
}

class _ArchetypeRow extends StatelessWidget {
  const _ArchetypeRow({
    required this.stat,
    required this.max,
    required this.colors,
  });

  final ArchetypeStat stat;
  final int max;
  final AllInColors colors;

  @override
  Widget build(BuildContext context) {
    final tint = archetypeColor(stat.archetype);
    final name = kArchetypes[stat.archetype]!.name;
    final net = '${fmtSigned(stat.net)} bb';

    return Semantics(
      label: '$name, $net, ${stat.hands} hands',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint,
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(14, color: colors.text),
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Text(
                  net,
                  style: AllInText.mono(
                    14,
                    color: stat.net >= 0 ? colors.good : colors.bad,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressBarThin(
              value: stat.hands.toDouble(),
              max: max.toDouble(),
              color: tint,
            ),
          ],
        ),
      ),
    );
  }
}

/// §7.7 — six diverging rows and the verbatim footnote.
class PositionsCard extends StatelessWidget {
  const PositionsCard({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (metrics.trackedPositions == 0) {
      return StatsSection(
        title: StatsCopy.positionsCard,
        child: Text(
          StatsCopy.positionsEmpty,
          style: AllInText.body(14, color: c.textMuted, height: 1.5),
        ),
      );
    }

    final maxAbs = metrics.maxPositionRate;

    return StatsSection(
      title: StatsCopy.positionsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final stat in metrics.positions)
            _PositionRow(stat: stat, maxAbs: maxAbs),
          const SizedBox(height: AllInSpace.sm),
          Text(
            StatsCopy.positionsFootnote,
            style: AllInText.body(12, color: c.textFaint, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.stat, required this.maxAbs});

  final PositionStat stat;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rate = stat.hands == 0 ? '—' : '${fmtSigned(stat.rate, 0)}/100';

    return Semantics(
      label: '${stat.position.label}, $rate, ${stat.hands} hands',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  stat.position.label,
                  style: AllInText.body(
                    13,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Expanded(
                child: DivergingBar(value: stat.rate, max: maxAbs, height: 8),
              ),
              const SizedBox(width: AllInSpace.sm),
              SizedBox(
                width: 62,
                child: Text(
                  rate,
                  textAlign: TextAlign.right,
                  style: AllInText.mono(13, color: c.text),
                ),
              ),
              const SizedBox(width: AllInSpace.xs),
              SizedBox(
                width: 34,
                child: Text(
                  '${stat.hands}h',
                  textAlign: TextAlign.right,
                  style: AllInText.mono(11, color: c.textFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §7.8 — WTSD · W$SD · AF, each a dotted label that opens T1, and the
/// verbatim footnote.
class StyleNumbersCard extends ConsumerWidget {
  const StyleNumbersCard({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return StatsSection(
      title: StatsCopy.styleCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DottedStatRow(
            label: StatsCopy.wtsdLabel,
            value: metrics.wtsd == null ? '—' : fmtPct(metrics.wtsd!),
            onExplain:
                () => _explain(
                  context,
                  ref,
                  label: StatsCopy.wtsdLabel,
                  blurb: StatsCopy.wtsdBlurb,
                  band: StatsCopy.wtsdBand,
                  math: StatsCopy.wtsdMath(
                    showdowns: metrics.showdownsFromFlops,
                    flops: metrics.flopsSeen,
                  ),
                ),
          ),
          DottedStatRow(
            label: StatsCopy.wsdLabel,
            value: metrics.wsd == null ? '—' : fmtPct(metrics.wsd!),
            onExplain:
                () => _explain(
                  context,
                  ref,
                  label: StatsCopy.wsdLabel,
                  blurb: StatsCopy.wsdBlurb,
                  band: StatsCopy.wsdBand,
                  math: StatsCopy.wsdMath(
                    won: metrics.showdownWon,
                    showdowns: metrics.showdownHands,
                  ),
                ),
          ),
          DottedStatRow(
            label: StatsCopy.afLabel,
            value: metrics.af == null ? '—' : metrics.af!.toStringAsFixed(1),
            onExplain:
                () => _explain(
                  context,
                  ref,
                  label: StatsCopy.afLabel,
                  blurb: StatsCopy.afBlurb,
                  band: StatsCopy.afBand,
                  math: StatsCopy.afMath(
                    aggressive: metrics.aggressiveActions,
                    calls: metrics.callActions,
                  ),
                ),
          ),
          const SizedBox(height: AllInSpace.sm),
          Text(
            StatsCopy.styleFootnote,
            style: AllInText.body(12, color: c.textFaint, height: 1.5),
          ),
        ],
      ),
    );
  }

  /// T1 for a style number (§7.2's table): title = label, body = blurb,
  /// "Show me the math" = the healthy band plus the metric's own formula,
  /// "Expert detail" = the desktop footnote.
  void _explain(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String blurb,
    required String band,
    required String math,
  }) => showStatsExplainer(
    context,
    ref,
    title: label,
    body: blurb,
    math: math,
    mathExtra: _HealthyRange(band: band),
    expert: StatsCopy.styleFootnote,
  );
}

class _HealthyRange extends StatelessWidget {
  const _HealthyRange({required this.band});

  final String band;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.md,
        vertical: AllInSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.ink850,
        borderRadius: BorderRadius.circular(AllInRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Text(
        StatsCopy.healthyRange(band),
        style: AllInText.mono(13, color: c.textMuted),
      ),
    );
  }
}
