/// The sizing rail's seven detents (DESIGN.md §4.5) — pure arithmetic over
/// `legalActions()`, so it is testable without a widget.
///
/// `Min · 1/3 · 1/2 · 2/3 · 3/4 · Pot · All-in`, evenly spaced **regardless of
/// value**:
/// a collapsed detent keeps its slot and only loses its label, which is why
/// `SizingRail` is handed all seven every time.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/widgets/widgets.dart';

abstract final class RaiseSizing {
  /// Slot index of the default (2/3 — the desktop 0.66 rule).
  static const int defaultIndex = 3;

  /// ASCII fractions, not `⅓ ½ ⅔ ¾`.
  ///
  /// Inter ships `½` and `¾` (Latin-1 Supplement) but not `⅓` / `⅔` (Number
  /// Forms), and `AllInFonts.fallback` sends every missing glyph to Bricolage
  /// Grotesque — so in one seven-item row two labels rendered raised, heavy
  /// and slashed while their two neighbours sat on the baseline, light and
  /// level. The rail and the P13 preset chips are the primary betting
  /// surface; they render in one face.
  static const List<String> labels = [
    'Min',
    '1/3',
    '1/2',
    '2/3',
    '3/4',
    'Pot',
    'All-in',
  ];

  static const List<String> semanticLabels = [
    'minimum raise',
    'one third pot',
    'half pot',
    'two thirds pot',
    'three quarters pot',
    'pot',
    'all in',
  ];

  /// The fractions behind the five middle detents.
  static const List<double> fractions = [1 / 3, 0.5, 2 / 3, 0.75, 1];

  /// The desktop `setFraction`: `add = round((pot + toCall) × f)`, then
  /// `raiseTo = currentBet > 0 ? currentBet + add : add`, clamped.
  static int valueForFraction(
    LegalActions legal,
    int currentBet,
    double fraction,
  ) {
    final add = jsRound((legal.potSize + legal.callAmount) * fraction).toInt();
    final raw = currentBet > 0 ? currentBet + add : add;
    return raw.clamp(legal.minRaiseTo, legal.maxRaiseTo);
  }

  /// All seven detents, in slot order.
  static List<RailDetent> detents(LegalActions legal, int currentBet) {
    final values = <int>[
      legal.minRaiseTo,
      for (final f in fractions) valueForFraction(legal, currentBet, f),
      legal.maxRaiseTo,
    ];
    // Monotonic: a fraction that clamps below its left neighbour would put the
    // rail's knob to the left of a detent with a bigger value.
    for (var i = 1; i < values.length; i++) {
      if (values[i] < values[i - 1]) values[i] = values[i - 1];
    }
    return [
      for (var i = 0; i < values.length; i++)
        RailDetent(
          label: labels[i],
          value: values[i],
          // §4.2.3: at 360 the two thirds render as unlabelled ticks.
          optionalLabel: i == 1 || i == 3,
          semanticLabel: semanticLabels[i],
        ),
    ];
  }

  /// The rail's opening value: 2/3, clamped.
  static int defaultValue(LegalActions legal, int currentBet) =>
      detents(legal, currentBet)[defaultIndex].value;

  /// §4.5: the only legal raise is the shove — the rail hides entirely.
  static bool isDegenerate(LegalActions legal) =>
      legal.minRaiseTo >= legal.maxRaiseTo;
}
