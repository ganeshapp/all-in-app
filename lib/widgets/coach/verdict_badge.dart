/// `VerdictBadge` — the 24 / 28 / 32 pt disc that carries a coach verdict
/// (DESIGN.md §10.5).
///
/// Colour never travels alone (§13): the disc always pairs the verdict colour
/// with a glyph (✕ / i / ✓ / eye) and every call site prints the word beside
/// it. Verdict → colour is §16.5's non-negotiable mapping: `bad` mistake ·
/// `warn` thin · `info` reasonable and read · `good` great. Gold is never a
/// verdict colour.
library;

import 'package:flutter/material.dart';

import '../../engine/coach.dart';
import '../../theme/tokens.dart';

class VerdictBadge extends StatelessWidget {
  const VerdictBadge({
    super.key,
    required this.verdict,
    this.size = medium,
    this.read = false,
    this.semanticLabel,
  });

  final Verdict verdict;

  /// One of [small] (P4 rows), [medium] (chip, drill header) or [large]
  /// (the P3 sheet header).
  final double size;

  /// A bot read (`CoachReview.kind == ReviewKind.bot`) — eye glyph, "Read".
  final bool read;

  final String? semanticLabel;

  static const double small = 24;
  static const double medium = 28;
  static const double large = 32;

  /// §16.5: `bad` mistake · `warn` thin · `info` reasonable/read · `good` great.
  static Color colorOf(Verdict verdict, AllInColors c) => switch (verdict) {
    Verdict.mistake => c.bad,
    Verdict.thin => c.warn,
    Verdict.ok => c.info,
    Verdict.great => c.good,
    Verdict.info => c.info,
  };

  /// §4.8's glyph column: ✕ · i · ✓ · ✓ · eye.
  static IconData iconOf(Verdict verdict, {bool read = false}) {
    if (read) return Icons.visibility_outlined;
    return switch (verdict) {
      Verdict.mistake => Icons.close_rounded,
      Verdict.thin => Icons.priority_high_rounded,
      Verdict.ok => Icons.check_rounded,
      Verdict.great => Icons.check_rounded,
      Verdict.info => Icons.visibility_outlined,
    };
  }

  /// The verbatim `META` labels of §4.8.
  static String labelOf(Verdict verdict, {bool read = false}) {
    if (read) return 'Read';
    return switch (verdict) {
      Verdict.mistake => 'Mistake',
      Verdict.thin => 'Thin spot',
      Verdict.ok => 'Reasonable',
      Verdict.great => 'Nice play',
      Verdict.info => 'Read',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(verdict, context.colors);
    return Semantics(
      label: semanticLabel ?? labelOf(verdict, read: read),
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Icon(
            iconOf(verdict, read: read),
            size: (size * 0.55).roundToDouble(),
            color: color,
          ),
        ),
      ),
    );
  }
}
