/// `ModeChips` — the Drills mode picker (DESIGN.md §5.1, §10.6).
///
/// Verbatim labels `Mixed` · `Push / Fold` · `Exploits` · `Review`; Review
/// carries the due-count pill when `badge > 0` (the same number badges the
/// tab). Chips are 36 tall with a 44 pt hit band and scroll horizontally.
/// Long-press (or the header's ⓘ) opens D4 with the mode blurb.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

@immutable
class ModeChipData {
  const ModeChipData({required this.id, required this.label, this.badge = 0});

  final String id;
  final String label;

  /// Review's due count; 0 hides the pill.
  final int badge;
}

class ModeChips extends StatelessWidget {
  const ModeChips({
    super.key,
    required this.modes,
    required this.value,
    required this.onChanged,
    this.onLongPress,
    this.enableHaptics = true,
  });

  final List<ModeChipData> modes;
  final String value;
  final ValueChanged<String> onChanged;

  /// Long-press a chip → D4 (the mode blurb).
  final ValueChanged<String>? onLongPress;
  final bool enableHaptics;

  static const double height = 44;
  static const double chipHeight = 36;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
        itemCount: modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AllInSpace.sm),
        itemBuilder: (context, i) {
          final mode = modes[i];
          final selected = mode.id == value;
          return Semantics(
            button: true,
            selected: selected,
            label:
                mode.badge > 0
                    ? '${mode.label}, ${mode.badge} due'
                    : mode.label,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (selected) return;
                  if (enableHaptics) HapticFeedback.lightImpact();
                  onChanged(mode.id);
                },
                onLongPress:
                    onLongPress == null
                        ? null
                        : () {
                          if (enableHaptics) HapticFeedback.mediumImpact();
                          onLongPress!.call(mode.id);
                        },
                child: Center(
                  child: Container(
                    height: chipHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AllInSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? c.gold : c.ink800,
                      borderRadius: BorderRadius.circular(AllInRadius.pill),
                      border: Border.all(color: selected ? c.gold : c.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mode.label,
                          style: AllInText.body(
                            14,
                            weight: FontWeight.w600,
                            color:
                                selected
                                    ? AllInColors.dark.ink900
                                    : c.textMuted,
                          ),
                        ),
                        if (mode.badge > 0) ...[
                          const SizedBox(width: AllInSpace.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selected ? AllInColors.dark.ink900 : c.gold,
                              borderRadius: BorderRadius.circular(
                                AllInRadius.pill,
                              ),
                            ),
                            child: Text(
                              '${mode.badge}',
                              style: AllInText.mono(
                                11,
                                color:
                                    selected ? c.gold : AllInColors.dark.ink900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
