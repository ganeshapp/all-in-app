/// `RangePresetRow` — the horizontally scrolling preset chips above the painter
/// buttons (DESIGN.md §10.4; the list and semantics in §4.9 and §6.5).
///
/// Presets **replace** the current paint and count as one stroke, so the screen
/// records an `UndoController` entry before applying one.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/preflop_charts.g.dart';
import '../../engine/notation.dart';
import '../../engine/ranges.dart';
import '../../engine/types.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

@immutable
class RangePreset {
  const RangePreset({
    required this.id,
    required this.label,
    required this.labels,
  });

  final String id;

  /// Chip text — "Top 10 %", "25 %", "BTN", "Any two", "Clear".
  final String label;

  /// The set the preset paints; empty for "Clear".
  final Set<HandLabel> labels;
}

class RangePresetRow extends StatelessWidget {
  const RangePresetRow({
    super.key,
    required this.presets,
    required this.onPick,
    this.selectedId,
    this.padding = const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final List<RangePreset> presets;
  final ValueChanged<RangePreset> onPick;

  /// Optional gold outline on the chip that produced the current paint.
  final String? selectedId;
  final EdgeInsets padding;
  final bool enableHaptics;
  final bool reducedMotion;

  /// 36 pt of paint inside a 44 pt hit band (§12).
  static const double chipHeight = 36;
  static const double hitHeight = 44;

  /// The P7 / S6 list: top-percent ranges, the 100 bb position opens, then
  /// "Any two" and "Clear" (§4.9, §6.5).
  static List<RangePreset> defaults({bool anyTwo = true, bool clear = true}) {
    return <RangePreset>[
      ..._topPercents,
      ..._positions,
      if (anyTwo)
        RangePreset(
          id: 'any-two',
          label: 'Any two',
          labels: allLabels().toSet(),
        ),
      if (clear)
        const RangePreset(id: 'clear', label: 'Clear', labels: <HandLabel>{}),
    ];
  }

  static final List<RangePreset> _topPercents = <RangePreset>[
    for (final pct in <int>[10, 15, 25, 40, 55])
      RangePreset(
        id: 'top-$pct',
        label: pct == 10 ? 'Top 10 %' : '$pct %',
        labels: topPercentRange(pct),
      ),
  ];

  static final List<RangePreset> _positions = <RangePreset>[
    for (final pos in <String>['UTG', 'MP', 'CO', 'BTN'])
      RangePreset(
        id: 'open-$pos',
        label: pos,
        labels: chartToSet(kRfi100[pos] ?? const <String, double>{}),
      ),
    RangePreset(id: 'defend-BB', label: 'BB', labels: _bbDefend()),
  ];

  /// BB defending the button open: everything it three-bets or calls with.
  static Set<HandLabel> _bbDefend() {
    final chart =
        kVsRfi100['BB_vs_BTN'] ?? const <String, Map<String, double>>{};
    final merged = <String, double>{};
    for (final part in <String>['threebet', 'call']) {
      (chart[part] ?? const <String, double>{}).forEach((label, freq) {
        final current = merged[label] ?? 0;
        merged[label] = current > freq ? current : freq;
      });
    }
    return chartToSet(merged);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hitHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: AllInSpace.sm),
        itemBuilder: (context, i) {
          final preset = presets[i];
          return _PresetChip(
            preset: preset,
            selected: preset.id == selectedId,
            reducedMotion: reducedMotion,
            onTap: () {
              if (enableHaptics) HapticFeedback.selectionClick();
              onPick(preset);
            },
          );
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
    required this.reducedMotion,
  });

  final RangePreset preset;
  final bool selected;
  final VoidCallback onTap;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: preset.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: RangePresetRow.hitHeight,
          child: Center(
            child: AnimatedContainer(
              duration: AllInMotion.of(
                context,
                AllInMotion.fast,
                reduced: reducedMotion,
              ),
              curve: AllInMotion.ease,
              height: RangePresetRow.chipHeight,
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
              decoration: BoxDecoration(
                color: selected ? c.gold : c.ink700,
                borderRadius: BorderRadius.circular(AllInRadius.md),
                border: Border.all(color: selected ? c.gold : c.line),
              ),
              alignment: Alignment.center,
              child: Text(
                preset.label,
                maxLines: 1,
                style: AllInText.body(
                  13,
                  weight: FontWeight.w600,
                  color: selected ? c.ink900 : c.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
