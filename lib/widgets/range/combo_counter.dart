/// `ComboCounter` — "148 combos · 11% of hands" under a `RangeMatrix`
/// (DESIGN.md §10.4; copy and the empty state in §4.9).
library;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../engine/notation.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class ComboCounter extends StatelessWidget {
  const ComboCounter({
    super.key,
    required this.combos,
    this.total = kTotalCombos,
    this.suffix = ' of hands',
    this.emptyText = 'Nothing painted yet',
    this.textAlign,
  });

  /// Combo-weighted size of the painted set (`combosInSet`).
  final int combos;

  /// Denominator for the percentage; 1326 = every two-card combo.
  final int total;

  /// Trailing words after the percentage ("of hands", " of all hands").
  final String suffix;

  /// Shown at zero (§4.9).
  final String emptyText;
  final TextAlign? textAlign;

  String get text =>
      combos <= 0
          ? emptyText
          : '$combos combos · ${fmtPct(combos / total)}$suffix';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      textAlign: textAlign,
      style:
          combos <= 0
              ? AllInText.body(12, color: c.textMuted)
              : AllInText.mono(12, color: c.goldLight),
    );
  }
}
