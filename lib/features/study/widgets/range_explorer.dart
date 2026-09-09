/// `RangeExplorer` — DESIGN.md §6.5 over docs/port/study-curriculum.md §12.5.
/// Preset chips (h-scroll), an editable matrix at the embedded box, the legend
/// and the live combo counter, then the verbatim paragraph.
///
/// The matrix claims every drag that starts on a cell; the page is scrolled
/// from the 24 pt gutters `ScrollSafeRangeMatrix` reserves (§6.5).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_controls.dart';

/// Verbatim desktop paragraph (§12.5 step 4).
const String kRangeExplorerNote =
    'Load a preset to see how a target percentage maps to actual cells, or '
    'paint your own and watch the combo count. There are 1,326 total combos; '
    'that running count is exactly what the EV Coach means when it says an '
    'opponent\'s range is "≈ 450 combos."';

class RangeExplorer extends ConsumerStatefulWidget {
  const RangeExplorer({super.key, required this.available});

  /// Content width this block was given.
  final double available;

  @override
  ConsumerState<RangeExplorer> createState() => _RangeExplorerState();
}

class _RangeExplorerState extends ConsumerState<RangeExplorer> {
  late Set<HandLabel> _painted = topPercentRange(14);
  final UndoController _undo = UndoController();
  String? _selectedPreset = 'preset-14';

  @override
  void dispose() {
    _undo.dispose();
    super.dispose();
  }

  void _apply(String id, Set<HandLabel> labels) {
    _undo.record(_painted);
    setState(() {
      _painted = labels;
      _selectedPreset = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = ref.watch(hapticsEnabledProvider);
    final combos = combosInSet(_painted);

    return StudyWidgetCard.wide(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RangePresetRow(
            padding: StudyPad.insets,
            selectedId: _selectedPreset,
            enableHaptics: haptics,
            reducedMotion: reduced,
            presets: <RangePreset>[
              for (final p in kExplorerPresets)
                RangePreset(
                  id: 'preset-${p.pct}',
                  label: p.label,
                  labels: topPercentRange(p.pct),
                ),
              const RangePreset(
                id: 'clear',
                label: 'Clear',
                labels: <HandLabel>{},
              ),
            ],
            onPick:
                (preset) => _apply(preset.id, <HandLabel>{...preset.labels}),
          ),
          const SizedBox(height: AllInSpace.md),
          Center(
            child: ScrollSafeRangeMatrix.editable(
              available: widget.available,
              value: _painted,
              enableHaptics: haptics,
              reducedMotion: reduced,
              undoController: _undo,
              semanticLabel: 'Range explorer grid',
              onChanged:
                  (next) => setState(() {
                    _painted = next;
                    _selectedPreset = null;
                  }),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          // Wraps rather than truncates: at 360 the legend and the counter do
          // not fit on one line (§13 "nothing truncates below 1.5×").
          StudyPad(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AllInSpace.sm,
              runSpacing: AllInSpace.xs,
              children: <Widget>[
                const StudyLegend(),
                ComboCounter(combos: combos, suffix: ' of all hands'),
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          StudyPad(
            child: Text(
              kRangeExplorerNote,
              style: AllInText.body(13, color: c.textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
