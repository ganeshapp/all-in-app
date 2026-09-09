/// The small shared parts every §6.5 study widget is built from: the card
/// shell, the label-left / mono-value-right "Field" over an `AllInSlider`, the
/// result tile, and the scroll-safe wrapper around an embedded `RangeMatrix`
/// (DESIGN.md §6.5 "Painting inside a scroll view — who wins the drag").
library;

import 'package:allin/engine/types.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Rounded card every study widget sits in (line border, `ink850`, 16 pt pad).
class StudyWidgetCard extends StatelessWidget {
  const StudyWidgetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
  });

  /// A card whose *horizontal* padding is zero, so an embedded `RangeMatrix`
  /// may use the card's full width.
  ///
  /// A 16 pt pad on both sides costs the grid 32 pt, which at 360 drops the
  /// solved cell below [RangeMatrixGeometry.labelFloorCell] and silently
  /// deletes every in-cell label. The matrix-bearing widgets therefore pad
  /// their own text rows with [StudyPad] and hand the matrix the whole width;
  /// the scroll gutters `ScrollSafeRangeMatrix` reserves are then real 24 pt
  /// margins rather than the card's padding wearing two hats (§6.5).
  const StudyWidgetCard.wide({super.key, required this.child})
    : padding = const EdgeInsets.symmetric(vertical: AllInSpace.lg);

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AllInCard.plain(padding: padding, child: child);
  }
}

/// The horizontal padding a [StudyWidgetCard.wide] child opts back into.
class StudyPad extends StatelessWidget {
  const StudyPad({super.key, required this.child});

  final Widget child;

  /// The inset a normal [StudyWidgetCard] would have applied.
  static const EdgeInsets insets = EdgeInsets.symmetric(
    horizontal: AllInSpace.lg,
  );

  @override
  Widget build(BuildContext context) => Padding(padding: insets, child: child);
}

/// `RangeLegend` inside a horizontal scroller.
///
/// The §10.4 legend is a single `Row` of three swatch-plus-label pairs and it
/// overflows a 296 pt box at 1.0× (and by 68 pt at 1.3×), which is every
/// embedded study matrix at 360 pt. Shrinking the text would fight §13 and
/// clipping would hide a key, so the strip scrolls sideways instead: nothing
/// is lost, the page still scrolls vertically, and the wrapper disappears the
/// day `RangeLegend` learns to wrap (see the feature report).
class StudyLegend extends StatelessWidget {
  const StudyLegend({super.key, this.mode = RangeLegendMode.kind});

  final RangeLegendMode mode;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const ClampingScrollPhysics(),
    child: RangeLegend(mode: mode),
  );
}

/// Label left (muted 14), mono value right (semibold 14), slider under it.
class StudyField extends StatelessWidget {
  const StudyField({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.semanticLabel,
    this.enableHaptics = true,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String? semanticLabel;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: AllInText.body(14, color: c.textMuted)),
            ),
            Text(valueText, style: AllInText.mono(14, color: c.text)),
          ],
        ),
        AllInSlider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          step: step,
          onChanged: onChanged,
          semanticLabel: semanticLabel ?? label,
          semanticFormatter: (v) => valueText,
          enableHaptics: enableHaptics,
        ),
      ],
    );
  }
}

/// Tiny uppercase label over a mono value — §12's "Result tile".
class StudyResultTile extends StatelessWidget {
  const StudyResultTile({
    super.key,
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.sm,
        vertical: AllInSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.ink800,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AllInRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: AllInText.eyebrow(c.textFaint),
          ),
          const SizedBox(height: AllInSpace.xs),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AllInText.mono(14, color: tone ?? c.text),
          ),
        ],
      ),
    );
  }
}

/// A `RangeMatrix` embedded in a vertically scrolling page.
///
/// The grid claims every drag that starts inside its cells (§6.5), so the page
/// needs somewhere else to be scrolled from: this reserves a real, invisible
/// gutter on both sides of the matrix box. The gutter is 24 pt whenever the
/// remaining box still solves to a legible cell, and 16 pt on the narrowest
/// phones — never zero.
class ScrollSafeRangeMatrix extends StatelessWidget {
  /// Editable (the explorer, the calculator's two ranges, the range drill).
  const ScrollSafeRangeMatrix.editable({
    super.key,
    required this.available,
    required Set<HandLabel> this.value,
    required ValueChanged<Set<HandLabel>> this.onChanged,
    this.undoController,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  }) : highlight = const <HandLabel>{},
       painted = const <HandLabel>{},
       actual = const <HandLabel>{},
       _mode = RangeMatrixMode.editable;

  /// Read-only illustration (a lesson `RangeBlock`).
  const ScrollSafeRangeMatrix.readOnly({
    super.key,
    required this.available,
    required this.highlight,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  }) : value = null,
       onChanged = null,
       undoController = null,
       painted = const <HandLabel>{},
       actual = const <HandLabel>{},
       _mode = RangeMatrixMode.readOnly;

  /// Grading colours (the range-building drill after Check).
  const ScrollSafeRangeMatrix.compare({
    super.key,
    required this.available,
    required this.painted,
    required this.actual,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  }) : value = null,
       onChanged = null,
       undoController = null,
       highlight = const <HandLabel>{},
       _mode = RangeMatrixMode.compare;

  /// The content width the page gives this block (page width − margins).
  final double available;
  final Set<HandLabel>? value;
  final ValueChanged<Set<HandLabel>>? onChanged;
  final UndoController? undoController;
  final Set<HandLabel> highlight;
  final Set<HandLabel> painted;
  final Set<HandLabel> actual;
  final bool enableHaptics;
  final bool reducedMotion;
  final String? semanticLabel;
  final RangeMatrixMode _mode;

  /// §6.5: 24 pt of scrollable gutter on each side, 16 when the box would
  /// otherwise drop the matrix below a legible cell.
  static double gutterFor(double available) => available - 48 >= 300 ? 24 : 16;

  /// The box the matrix itself may occupy inside [available].
  static double boxFor(double available) =>
      available - 2 * gutterFor(available);

  @override
  Widget build(BuildContext context) {
    // The caller's `available` is what the *page* offers; the real constraint
    // is what this row actually gets (a card's border and any padding have
    // already been taken out of it). Trusting the caller instead cost 5.5 pt
    // of overflow at 360 pt, so the layout is solved from the constraints and
    // `available` is only the fallback for an unbounded parent.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : available;
        return _build(width);
      },
    );
  }

  Widget _build(double available) {
    final gutter = gutterFor(available);
    final box = boxFor(available);
    final matrix = switch (_mode) {
      RangeMatrixMode.editable => RangeMatrix.editable(
        value: value ?? const <HandLabel>{},
        onChanged: onChanged!,
        undoController: undoController,
        width: box,
        headerWidth: 18,
        gap: 1,
        semanticLabel: semanticLabel,
        enableHaptics: enableHaptics,
        reducedMotion: reducedMotion,
      ),
      RangeMatrixMode.readOnly => RangeMatrix.readOnly(
        highlight: highlight,
        width: box,
        headerWidth: 18,
        gap: 1,
        semanticLabel: semanticLabel,
        enableHaptics: enableHaptics,
        reducedMotion: reducedMotion,
      ),
      RangeMatrixMode.compare => RangeMatrix.compare(
        painted: painted,
        actual: actual,
        width: box,
        headerWidth: 18,
        gap: 1,
        semanticLabel: semanticLabel,
        enableHaptics: enableHaptics,
        reducedMotion: reducedMotion,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Real estate, deliberately empty: a drag here scrolls the page.
        SizedBox(width: gutter, height: 1),
        matrix,
        SizedBox(width: gutter, height: 1),
      ],
    );
  }
}
