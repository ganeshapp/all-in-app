/// S6 · Range editor — full-screen modal at `/study/range-editor`
/// (DESIGN.md §6.5). Returns the painted set with `pop(result)`.
///
/// S6 exists so that serious edits never happen in a scroll view: nothing on
/// this screen scrolls behind the grid, so the painter owns every gesture and
/// the loupe, the header selectors and undo all behave exactly as on P7
/// (§4.9). System back is "Done" and keeps the edits — there is no Cancel,
/// because a painter with an undo stack does not need one.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/features/study/widgets/study_chrome.dart';
import 'package:allin/features/study/widgets/study_controls.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RangeEditorScreen extends ConsumerStatefulWidget {
  const RangeEditorScreen({
    super.key,
    this.initialHands = const <String>{},
    this.title,
  });

  /// Hand labels ("AKs", "77") the editor opens with.
  final Set<String> initialHands;

  /// Which range is being painted ("Your range" / "Opponent's range"). Null
  /// reads it from [rangeEditorTitleProvider], which is how the router — which
  /// only forwards `extra` — gets the title across.
  final String? title;

  @override
  ConsumerState<RangeEditorScreen> createState() => _RangeEditorScreenState();
}

class _RangeEditorScreenState extends ConsumerState<RangeEditorScreen> {
  late Set<HandLabel> _painted = <HandLabel>{...widget.initialHands};
  final UndoController _undo = UndoController();
  String? _preset;

  @override
  void dispose() {
    _undo.dispose();
    super.dispose();
  }

  void _apply(String? id, Set<HandLabel> labels) {
    _undo.record(_painted);
    setState(() {
      _painted = labels;
      _preset = id;
    });
  }

  void _done() => Navigator.of(context).pop(<HandLabel>{..._painted});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = ref.watch(hapticsEnabledProvider);
    final String title = widget.title ?? ref.watch(rangeEditorTitleProvider);
    final width = MediaQuery.sizeOf(context).width;
    final box = width - 2 * AllInSpace.lg;

    return PopScope<Object?>(
      // System back is Done: it keeps the edits and returns them (§16.1).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _done();
      },
      child: AllInScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AllInSpace.sm,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AllInText.display(22, color: c.text),
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _undo,
                    builder:
                        (context, _) =>
                            _undo.canUndo
                                ? StudyHeaderButton(
                                  label: 'Undo',
                                  onTap: () {
                                    final previous = _undo.undo();
                                    if (previous == null) return;
                                    setState(() {
                                      _painted = previous;
                                      _preset = null;
                                    });
                                  },
                                )
                                : const SizedBox(width: 44, height: 44),
                  ),
                  StudyHeaderButton(
                    label: 'Done',
                    emphasised: true,
                    onTap: _done,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AllInSpace.sm),
            RangePresetRow(
              selectedId: _preset,
              enableHaptics: haptics,
              reducedMotion: reduced,
              presets: RangePresetRow.defaults(),
              onPick:
                  (preset) => _apply(preset.id, <HandLabel>{...preset.labels}),
            ),
            const SizedBox(height: AllInSpace.md),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    Center(
                      child: RangeMatrix.editable(
                        value: _painted,
                        width: box,
                        undoController: _undo,
                        enableHaptics: haptics,
                        reducedMotion: reduced,
                        semanticLabel: title,
                        onChanged:
                            (next) => setState(() {
                              _painted = next;
                              _preset = null;
                            }),
                      ),
                    ),
                    const SizedBox(height: AllInSpace.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AllInSpace.lg,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: AllInSpace.sm,
                        runSpacing: AllInSpace.xs,
                        children: <Widget>[
                          const StudyLegend(),
                          ComboCounter(combos: combosInSet(_painted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
