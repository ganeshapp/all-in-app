/// `AllInSegmented` — the 2–4 way segmented control (DESIGN.md §10.1).
///
/// 36 pt tall inside a 44 pt hit band (§12); the selected segment is gold,
/// because gold marks the active choice everywhere (§16.5).
library;

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
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: _Segment(
                        label: labels[i],
                        selected: i == value,
                        duration: duration,
                        onTap: () {
                          if (i == value) return;
                          if (enableHaptics) HapticFeedback.selectionClick();
                          onChanged(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;
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
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
            decoration: BoxDecoration(
              color: selected ? c.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(AllInRadius.md - 3),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AllInText.body(
                13.5,
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
