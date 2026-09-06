import 'package:flutter/widgets.dart';

/// Motion tokens mirrored from the desktop keyframes. Every animated widget
/// reads [reduced] so the "reduce motion" setting (or the OS preference)
/// collapses durations to zero.
class AllInMotion {
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve easeOut = Curves.easeOutCubic;

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration deal = Duration(milliseconds: 340);
  static const Duration slide = Duration(milliseconds: 350);
  static const Duration chips = Duration(milliseconds: 420);

  /// Returns [d], or zero when motion is reduced.
  static Duration of(
    BuildContext context,
    Duration d, {
    required bool reduced,
  }) =>
      reduced || MediaQuery.maybeDisableAnimationsOf(context) == true
          ? Duration.zero
          : d;
}
