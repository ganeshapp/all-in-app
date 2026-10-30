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

import '../../../engine/engine.dart'
    show PlayerStyle, fmtPct, fmtSigned, kArchetypes;
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
              // A win rate is one number: "−250/100" is 8 mono characters and
              // wrapped onto a second line inside the old 62 pt column, which
              // the 44 pt row then had to clip.
              SizedBox(
                width: 68,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    rate,
                    maxLines: 1,
                    style: AllInText.mono(13, color: c.text),
                  ),
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
/// Which of the player's own gears actually makes money: each session is
/// labelled by how they played it, then the results are pooled.
class StyleWinRateCard extends StatelessWidget {
  const StyleWinRateCard({super.key, required this.metrics});

  final StatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spells = metrics.styleSpells;

    if (spells.isEmpty) {
      return StatsSection(
        title: StatsCopy.byStyleTitle,
        child: Text(
          StatsCopy.byStyleEmpty,
          style: AllInText.body(14, color: c.textMuted, height: 1.5),
        ),
      );
    }

    var maxAbs = 0.0;
    for (final s in spells) {
      final v = s.bb100.abs();
      if (v > maxAbs) maxAbs = v;
    }
    if (maxAbs == 0) maxAbs = 1;

    return StatsSection(
      title: StatsCopy.byStyleTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in spells) _StyleSpellRow(spell: s, maxAbs: maxAbs),
          const SizedBox(height: AllInSpace.sm),
          Text(
            StatsCopy.byStyleBlurb,
            style: AllInText.body(12, color: c.textFaint, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StyleSpellRow extends StatelessWidget {
  const _StyleSpellRow({required this.spell, required this.maxAbs});

  final StyleSpell spell;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rate = '${fmtSigned(spell.bb100, 0)}/100';
    final name = StyleNumbersCard.styleName(spell.style);

    return Semantics(
      label: '$name, $rate, ${spell.hands} hands',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.body(
                    13,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Expanded(
                child: DivergingBar(value: spell.bb100, max: maxAbs, height: 8),
              ),
              const SizedBox(width: AllInSpace.sm),
              SizedBox(
                width: 68,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    rate,
                    maxLines: 1,
                    style: AllInText.mono(13, color: c.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            label: StatsCopy.vpipLabel,
            value:
                metrics.lifetimeStyle.vpip == null
                    ? '—'
                    : fmtPct(metrics.lifetimeStyle.vpip!),
            onExplain:
                () => _explain(
                  context,
                  ref,
                  label: StatsCopy.vpipLabel,
                  blurb: StatsCopy.vpipBlurb,
                  band: StatsCopy.vpipBand,
                  math: StatsCopy.rateMath(
                    hits: metrics.lifetimeStyle.vpipHands,
                    of: metrics.lifetimeStyle.hands,
                  ),
                ),
          ),
          DottedStatRow(
            label: StatsCopy.pfrLabel,
            value:
                metrics.lifetimeStyle.pfr == null
                    ? '—'
                    : fmtPct(metrics.lifetimeStyle.pfr!),
            onExplain:
                () => _explain(
                  context,
                  ref,
                  label: StatsCopy.pfrLabel,
                  blurb: StatsCopy.pfrBlurb,
                  band: StatsCopy.pfrBand,
                  math: StatsCopy.rateMath(
                    hits: metrics.lifetimeStyle.pfrHands,
                    of: metrics.lifetimeStyle.hands,
                  ),
                ),
          ),
          DottedStatRow(
            label: StatsCopy.styleLabel,
            value: styleWord(
              metrics.lifetimeStyle.style,
              metrics.lifetimeStyle.vpip,
              metrics.lifetimeStyle.pfr,
            ),
            onExplain:
                () => _explain(
                  context,
                  ref,
                  label: StatsCopy.styleLabel,
                  blurb: StatsCopy.styleBlurb,
                  band: null,
                  math: StatsCopy.styleMeaning(
                    metrics.lifetimeStyle.style?.name ?? 'unknown',
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
    // A label has no "healthy range" — there is no number to be inside one.
    required String? band,
    required String math,
  }) => showStatsExplainer(
    context,
    ref,
    title: label,
    body: blurb,
    math: math,
    mathExtra: band == null ? null : _HealthyRange(band: band),
    expert: StatsCopy.styleFootnote,
  );

  /// The style label as the player sees it. The engine's names are terse
  /// because the bots use them; these are the words on the card.
  /// The label in the vocabulary players actually use.
  ///
  /// "Tight" and "TAG" are not the same thing — a player who sees 20% of
  /// flops and never raises is tight and *passive*, which is a different leak
  /// and deserves a different word. So the aggressive names are only used
  /// when the raising actually backs them up.
  static String styleWord(PlayerStyle? s, double? vpip, double? pfr) {
    final raises = (vpip ?? 0) > 0 ? (pfr ?? 0) / vpip! : 0.0;
    final aggressive = raises >= 0.6;
    return switch (s) {
      PlayerStyle.tight =>
        aggressive ? 'TAG (tight-aggressive)' : 'Tight but passive',
      PlayerStyle.loose =>
        aggressive ? 'LAG (loose-aggressive)' : 'Loose but passive',
      PlayerStyle.solid => aggressive ? 'TAG-ish (solid)' : 'Solid but passive',
      _ => styleName(s),
    };
  }

  static String styleName(PlayerStyle? s) => switch (s) {
    null => '—',
    PlayerStyle.unknown => '—',
    PlayerStyle.rock => 'Rock',
    PlayerStyle.nit => 'Nit',
    PlayerStyle.tight => 'Tight',
    PlayerStyle.solid => 'Solid',
    PlayerStyle.loose => 'Loose',
    PlayerStyle.maniac => 'Maniac',
    PlayerStyle.station => 'Calling station',
  };
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
