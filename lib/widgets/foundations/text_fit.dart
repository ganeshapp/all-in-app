/// Shrink-to-fit measurement shared by the components that must not ellipsise
/// a *name* (DESIGN.md §13: "a truncated label names nothing").
///
/// Two callers rely on it — `AllInSegmented` and S0's tools grid — and both
/// used to do the same thing wrong: estimate the fitted size as
/// `size * room / widest` and trust it. Text width is not linear in font size
/// (per-glyph advances round), so that estimate lands a fraction of a pixel
/// over the box and the label ellipsises anyway — "Heads-up" at 360 pt,
/// "Range explorer" in a 106 pt tile. [fitFontSize] verifies the estimate by
/// re-measuring and steps down until it genuinely fits.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// [style] as a `Text` inside [context] would actually paint it: merged over
/// the ambient `DefaultTextStyle`, which is where the theme's `letterSpacing`
/// lives.
TextStyle resolve(BuildContext context, TextStyle style) =>
    DefaultTextStyle.of(context).style.merge(style);

/// The width [label] needs on one unwrapped line at [size].
double measureLabelWidth(
  String label,
  TextStyle style,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: direction,
    maxLines: 1,
    // [style] already carries the rendered size, so scaling again would
    // double-count the user's text-size setting.
    textScaler: TextScaler.noScaling,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The largest size ≤ [size] at which **every** label in [labels] fits
/// [width] on one line, never going below [minSize].
///
/// [styleAt] builds the style the label is measured in — pass the heaviest
/// weight the component can render, so changing which item is selected never
/// reflows the row. It must be the style the `Text` will actually paint with,
/// i.e. **merged over the ambient `DefaultTextStyle`** — the Material 2021
/// typography that ships under `AllInText` adds `letterSpacing: 0.3`, which is
/// 4 px across "Range explorer" and was exactly the margin these two callers
/// were short by. [resolve] does that merge.
///
/// Returns [size] unchanged when the labels already fit or [width] is not
/// usable. When even [minSize] does not fit, [minSize] is returned and the
/// caller's own `TextOverflow` takes over — an ellipsis is the better failure
/// below the legibility floor.
double fitFontSize({
  required Iterable<String> labels,
  required double width,
  required double size,
  required double minSize,
  required TextDirection direction,
  required TextStyle Function(double size) styleAt,
}) {
  if (!width.isFinite || width <= 0 || labels.isEmpty) return size;

  double widest(double at) {
    final style = styleAt(at);
    var w = 0.0;
    for (final label in labels) {
      w = math.max(w, measureLabelWidth(label, style, direction));
    }
    return w;
  }

  final full = widest(size);
  if (full <= width) return size;

  // The linear estimate, then verified. Twelve 2 % steps reach ~0.78 of the
  // estimate, which is far past any rounding error; the floor stops it first
  // in practice.
  final floor = math.min(minSize, size);
  var candidate = math.max(size * width / full, floor);
  for (var i = 0; i < 12 && candidate > floor; i++) {
    if (widest(candidate) <= width) return candidate;
    candidate = math.max(candidate * 0.98, floor);
  }
  return candidate;
}
