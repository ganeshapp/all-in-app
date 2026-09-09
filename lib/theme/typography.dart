import 'package:flutter/material.dart';

/// Bundled font families (see pubspec.yaml). Display for headings and card
/// ranks, Inter for body, JetBrains Mono for every number that should line up.
class AllInFonts {
  static const String display = 'Bricolage Grotesque';
  static const String body = 'Inter';
  static const String mono = 'JetBrains Mono';

  /// Last-resort fallback for glyphs Inter and JetBrains Mono do not ship.
  ///
  /// It is deliberately *not* load-bearing for the §4.5 sizing rail: the rail
  /// and the P13 preset chips write their fractions in ASCII ("1/3", "2/3"),
  /// because falling back per-glyph mixed two typefaces inside a single row —
  /// `½`/`¾` in Inter beside `⅓`/`⅔` in Bricolage.
  static const List<String> fallback = <String>[display];
}

class AllInText {
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: AllInFonts.display,
    fontFamilyFallback: AllInFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: size >= 24 ? -0.5 : 0,
  );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: AllInFonts.body,
    fontFamilyFallback: AllInFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height ?? 1.4,
  );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) => TextStyle(
    fontFamily: AllInFonts.mono,
    fontFamilyFallback: AllInFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Small uppercase label ("HANDS", "NET", "BB/100").
  static TextStyle eyebrow(Color color) => TextStyle(
    fontFamily: AllInFonts.body,
    fontFamilyFallback: AllInFonts.fallback,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: color,
  );
}
