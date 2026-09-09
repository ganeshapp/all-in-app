/// `ProgressBarThin` — the 4 / 8 pt gold bar used by the goal card, the study
/// progress line and the import sheet (DESIGN.md §10.1).
library;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';

class ProgressBarThin extends StatelessWidget {
  const ProgressBarThin({
    super.key,
    required this.value,
    this.max = 1,
    this.height = 4,
    this.color,
    this.trackColor,
    this.semanticLabel,
    this.reducedMotion = false,
  });

  final double value;
  final double max;

  /// 4 pt for inline progress, 8 pt for the goal card (§3.1).
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;
  final bool reducedMotion;

  double get _fraction {
    if (max <= 0) return 0;
    return (value / max).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      label: semanticLabel,
      value: '${(_fraction * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: trackColor ?? c.ink600,
              borderRadius: radius,
            ),
            // The fill must be aligned inside loose constraints: `DecoratedBox`
            // forwards the (tight) incoming width, which would clamp the fill
            // back up to 100 % however small the fraction is.
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LayoutBuilder(
                builder:
                    (context, constraints) => AnimatedContainer(
                      duration: AllInMotion.of(
                        context,
                        AllInMotion.base,
                        reduced: reducedMotion,
                      ),
                      curve: AllInMotion.ease,
                      width: constraints.maxWidth * _fraction,
                      height: height,
                      decoration: BoxDecoration(
                        color: color ?? c.gold,
                        borderRadius: radius,
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
