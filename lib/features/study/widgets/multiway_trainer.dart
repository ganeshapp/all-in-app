/// `MultiwayTrainer` — DESIGN.md §6.5 over docs/port/study-curriculum.md §12.4.
/// Six fixed scenarios; on every scenario change five concurrent
/// `equityVsField` runs (1 200 trials each) go through [EquityService] so the
/// UI thread never blocks, and the bars only update when **all five** land.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_controls.dart';

/// Verbatim desktop footer (§12.4 step 5).
const String kMultiwayFooter =
    'Each extra opponent is another chance someone holds a better hand, so '
    'equity falls — fast for one-pair hands, more slowly for the nuts (the '
    'best possible hand). This is why you tighten up and value-bet more '
    'carefully the more players are in the pot.';

class MultiwayTrainer extends ConsumerStatefulWidget {
  const MultiwayTrainer({super.key, this.available = 326});

  /// Content width this block was given.
  final double available;

  @override
  ConsumerState<MultiwayTrainer> createState() => _MultiwayTrainerState();
}

class _MultiwayTrainerState extends ConsumerState<MultiwayTrainer> {
  int _idx = 0;
  int _opp = 2;
  List<double>? _series;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final generation = ++_generation;
    setState(() => _series = null);
    final scenario = kMultiwayScenarios[_idx];
    final service = ref.read(studyEquityServiceProvider);
    try {
      final results = await Future.wait(<Future<dynamic>>[
        for (var n = 1; n <= 5; n++)
          service.vsField(
            hero: scenario.hero,
            board: scenario.board,
            opponents: n,
            iters: 1200,
            key: 'study-multiway-$n',
          ),
      ]);
      if (!mounted || generation != _generation) return;
      setState(
        () => _series = <double>[for (final r in results) (r.equity as double)],
      );
    } catch (_) {
      // A superseded or failed run leaves the bars in their loading state;
      // picking another scenario starts a fresh one (§14).
      if (!mounted || generation != _generation) return;
      setState(() => _series = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    final fourColor = ref.watch(
      settingsProvider.select((s) => s.fourColorDeck),
    );
    final haptics = ref.watch(hapticsEnabledProvider);
    final scenario = kMultiwayScenarios[_idx];
    final series = _series;
    final cur = series?[_opp - 1];
    final curColor =
        cur == null
            ? c.textMuted
            : cur >= 0.6
            ? c.good
            : cur >= 0.4
            ? c.gold
            : c.bad;

    return StudyWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AllInSpace.sm,
            runSpacing: AllInSpace.xs,
            children: <Widget>[
              for (var i = 0; i < kMultiwayScenarios.length; i++)
                _ScenarioChip(
                  label: kMultiwayScenarios[i].name,
                  selected: i == _idx,
                  reducedMotion: reduced,
                  onTap: () {
                    if (i == _idx) return;
                    setState(() => _idx = i);
                    _run();
                  },
                ),
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          Wrap(
            spacing: AllInSpace.xs,
            runSpacing: AllInSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final card in scenario.hero)
                PlayingCardView(
                  card: card,
                  width: 40,
                  fourColorDeck: fourColor,
                ),
              const SizedBox(width: AllInSpace.xs),
              if (scenario.board.isEmpty)
                Text(
                  '(pre-flop)',
                  style: AllInText.body(12.5, color: c.textFaint),
                )
              else ...<Widget>[
                Text('on', style: AllInText.body(12.5, color: c.textFaint)),
                const SizedBox(width: AllInSpace.xs),
                for (final card in scenario.board)
                  PlayingCardView(
                    card: card,
                    width: 36,
                    fourColorDeck: fourColor,
                  ),
              ],
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          StudyField(
            label: 'Opponents',
            valueText: '$_opp',
            value: _opp.toDouble(),
            min: 1,
            max: 5,
            step: 1,
            semanticLabel: 'Opponents',
            enableHaptics: haptics,
            onChanged: (v) => setState(() => _opp = v.round()),
          ),
          const SizedBox(height: AllInSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    cur == null ? '—' : fmtPct(cur),
                    style: AllInText.display(36, color: curColor),
                  ),
                  Text(
                    'EQUITY VS $_opp',
                    style: AllInText.eyebrow(c.textFaint),
                  ),
                ],
              ),
              const SizedBox(width: AllInSpace.md),
              Expanded(
                child: _BarChart(
                  series: series,
                  opp: _opp,
                  reducedMotion: reduced,
                  onPick: (n) => setState(() => _opp = n),
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          Text(
            kMultiwayFooter,
            style: AllInText.body(12.5, color: c.textFaint, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.reducedMotion,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: AllInMotion.of(
                context,
                AllInMotion.fast,
                reduced: reducedMotion,
              ),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.gold : c.ink600,
                borderRadius: BorderRadius.circular(AllInRadius.sm),
              ),
              child: Text(
                label,
                style: AllInText.body(
                  11.8,
                  weight: FontWeight.w600,
                  color: selected ? c.ink900 : c.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Five 44-wide columns; tapping one sets the opponent count (§12.4).
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.series,
    required this.opp,
    required this.onPick,
    required this.reducedMotion,
  });

  final List<double>? series;
  final int opp;
  final ValueChanged<int> onPick;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The two labels grow with the text scale, so the chart does too — a
    // fixed 110 pt box overflowed by 9.5 pt as soon as a bar filled it.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SizedBox(
      height: 110 * scale.clamp(1.0, 1.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (var n = 1; n <= 5; n++)
            Expanded(
              child: Semantics(
                button: true,
                selected: n == opp,
                label:
                    series == null
                        ? '$n opponent${n > 1 ? 's' : ''}: calculating'
                        : '$n opponent${n > 1 ? 's' : ''}: '
                            '${fmtPct(series![n - 1])}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(n),
                  child: _Column(
                    value: series?[n - 1],
                    index: n,
                    active: n == opp,
                    reducedMotion: reducedMotion,
                    empty: c.ink700,
                    activeColor: c.gold,
                    idleColor: c.ink500,
                    label: n == opp ? c.text : c.textFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.value,
    required this.index,
    required this.active,
    required this.reducedMotion,
    required this.empty,
    required this.activeColor,
    required this.idleColor,
    required this.label,
  });

  final double? value;
  final int index;
  final bool active;
  final bool reducedMotion;
  final Color empty;
  final Color activeColor;
  final Color idleColor;
  final Color label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The bar is a *fraction* of whatever height is left after the two
    // labels, never a fixed 90 pt: a full bar plus its labels overflowed the
    // column by 9.5 pt, and by more at 1.3× text.
    final factor = value == null ? 0.05 : value!.clamp(0.05, 1.0);
    final bar = FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: factor,
      child: Container(
        decoration: BoxDecoration(
          color: value == null ? empty : (active ? activeColor : idleColor),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AllInRadius.sm),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AllInSpace.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            value == null ? '—' : '${(value! * 100).round()}%',
            style: AllInText.mono(10.5, color: label),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: value == null && !reducedMotion ? _Shimmer(child: bar) : bar,
          ),
          const SizedBox(height: 2),
          Text('$index', style: AllInText.body(10, color: c.textFaint)),
        ],
      ),
    );
  }
}

/// The §11 shimmer: a pulsing opacity, replaced by a flat bar under reduced
/// motion (never a frozen gradient).
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_controller),
      child: widget.child,
    );
  }
}
