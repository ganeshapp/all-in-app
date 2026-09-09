/// `AllInSegmented` — the 2–4 way segmented control (DESIGN.md §10.1).
///
/// 36 pt tall inside a 44 pt hit band (§12); the selected segment is gold,
/// because gold marks the active choice everywhere (§16.5).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class AllInSegmented extends StatelessWidget {
  const AllInSegmented({
    super.key,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final List<String> labels;

  /// Index into [labels].
  final int value;
  final ValueChanged<int> onChanged;
  final String? semanticLabel;
  final bool enableHaptics;
  final bool reducedMotion;

  static const double trackHeight = 36;
  static const double hitHeight = 44;

  /// Label size before shrink-to-fit, in logical pixels at 1.0×.
  static const double labelSize = 13.5;

  /// The floor for [labelSize] once the row has to shrink. Below this the
  /// labels stop being legible, so ellipsis becomes the better failure (§13).
  static const double minLabelSize = 11.5;

  /// Padding inside one segment, per side.
  static const double _labelPad = AllInSpace.sm;

  /// The track's own 3 pt inset, per side.
  static const double _trackPad = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = AllInMotion.of(
      context,
      AllInMotion.fast,
      reduced: reducedMotion,
    );

    return Semantics(
      label: semanticLabel,
      container: true,
      child: SizedBox(
        height: hitHeight,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.ink700,
              borderRadius: BorderRadius.circular(AllInRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_trackPad),
              // §13: "Heads-up", "Manual" and "Standard" all ellipsed to
              // "Hea…", "Ma…", "Std…" at 360 pt × 1.3×, because every segment
              // is a fixed 1/n of the row. Measure the widest label against
              // the width this row actually got and shrink the whole set —
              // one size for all segments, so the row still reads as one
              // control — before falling back to ellipsis.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = _fittedLabelSize(context, constraints.maxWidth);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: _Segment(
                            label: labels[i],
                            selected: i == value,
                            duration: duration,
                            fontSize: size,
                            onTap: () {
                              if (i == value) return;
                              if (enableHaptics) {
                                HapticFeedback.selectionClick();
                              }
                              onChanged(i);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The label size, in final rendered pixels (text scale already folded in),
  /// at which every label fits its segment. Falls back to the scaled
  /// [labelSize] when the row is unbounded or already roomy enough.
  double _fittedLabelSize(BuildContext context, double innerWidth) {
    final target = MediaQuery.textScalerOf(context).scale(labelSize);
    if (!innerWidth.isFinite || labels.isEmpty) return target;

    // Each segment is an equal share of the track; the text keeps `_labelPad`
    // on both sides. The half-pixel guards against layout rounding.
    final room = innerWidth / labels.length - _labelPad * 2 - 0.5;
    if (room <= 0) return target;

    // Measured bold — the selected weight — so moving the selection never
    // reflows the row.
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final label in labels) {
      widest = math.max(widest, _measure(label, target, direction));
    }
    if (widest <= room) return target;
    return math.max(target * room / widest, math.min(minLabelSize, target));
  }

  static double _measure(String label, double size, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AllInText.body(size, weight: FontWeight.w700, height: 1.1),
      ),
      textDirection: direction,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.duration,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;

  /// Already in rendered pixels (see `AllInSegmented._fittedLabelSize`), so
  /// the label is drawn with `TextScaler.noScaling`.
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: AllInMotion.ease,
            height: AllInSegmented.trackHeight - 6,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSegmented._labelPad,
            ),
            decoration: BoxDecoration(
              color: selected ? c.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(AllInRadius.md - 3),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: AllInText.body(
                fontSize,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                // Gold is light in both themes — dark ink keeps 4.5:1 (§13).
                color: selected ? AllInColors.dark.ink900 : c.textMuted,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
