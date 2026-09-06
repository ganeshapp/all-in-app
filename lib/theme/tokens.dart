import 'package:flutter/material.dart';

/// Brand colour tokens, mirrored from the desktop app's `src/styles/tokens.css`.
/// Two full palettes (dark is primary); everything else in the theme derives from these.
class AllInColors {
  const AllInColors({
    required this.ink900,
    required this.ink850,
    required this.ink800,
    required this.ink700,
    required this.ink600,
    required this.ink500,
    required this.ink400,
    required this.ink300,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.gold,
    required this.goldDark,
    required this.goldLight,
    required this.good,
    required this.bad,
    required this.warn,
    required this.info,
    required this.comboOffsuit,
    required this.line,
    required this.lineStrong,
    required this.shadowColor,
  });

  // Surfaces (darkest → lightest in dark mode).
  final Color ink900;
  final Color ink850;
  final Color ink800;
  final Color ink700;
  final Color ink600;
  final Color ink500;
  final Color ink400;
  final Color ink300;

  // Text.
  final Color text;
  final Color textMuted;
  final Color textFaint;

  // Accent.
  final Color gold;
  final Color goldDark;
  final Color goldLight;

  // Semantic.
  final Color good;
  final Color bad;
  final Color warn;
  final Color info;

  // Range-matrix offsuit cell (theme-specific; pair/suited are fixed).
  final Color comboOffsuit;

  // Hairlines.
  final Color line;
  final Color lineStrong;
  final Color shadowColor;

  // ---- theme-independent ----
  static const Color felt = Color(0xFF0E6B46);
  static const Color feltDark = Color(0xFF093D2A);
  static const Color feltLight = Color(0xFF15935F);
  static const Color rail = Color(0xFF2A1A10);
  static const Color railLight = Color(0xFF43291A);

  static const Color suitRed = Color(0xFFD83A3A);
  static const Color suitBlack = Color(0xFF1B2230);
  // Four-colour deck: ♠ black · ♥ red · ♦ blue · ♣ green.
  static const Color suitBlue = Color(0xFF2F6FD0);
  static const Color suitGreen = Color(0xFF2FAA66);

  static const Color comboPair = Color(0xFFB8442F);
  static const Color comboSuited = Color(0xFF2F8F5C);

  static const Color chipRed = Color(0xFFD23B3B);
  static const Color chipBlue = Color(0xFF2F6FD0);
  static const Color chipGreen = Color(0xFF2FAA66);
  static const Color chipBlack = Color(0xFF20242B);
  static const Color chipPurple = Color(0xFF8A5CD1);

  // Card faces.
  static const Color cardFaceTop = Color(0xFFFFFFFF);
  static const Color cardFaceBottom = Color(0xFFEEF2F6);
  static const Color cardBackA = Color(0xFF11805A);
  static const Color cardBackB = Color(0xFF0A4F34);
  static const Color cardBackC = Color(0xFF073A2A);

  static const AllInColors dark = AllInColors(
    ink900: Color(0xFF0B0F14),
    ink850: Color(0xFF0E131A),
    ink800: Color(0xFF11161D),
    ink700: Color(0xFF161D26),
    ink600: Color(0xFF1F2833),
    ink500: Color(0xFF2A3542),
    ink400: Color(0xFF3A4757),
    ink300: Color(0xFF55657A),
    text: Color(0xFFE9EEF4),
    textMuted: Color(0xFF9AA7B4),
    textFaint: Color(0xFF6B7888),
    gold: Color(0xFFE8C25A),
    goldDark: Color(0xFFC79A36),
    goldLight: Color(0xFFF4DD92),
    good: Color(0xFF3FBF7F),
    bad: Color(0xFFEC5A5A),
    warn: Color(0xFFE8B54A),
    info: Color(0xFF4F9BE8),
    comboOffsuit: Color(0xFF2C3A4A),
    line: Color(0x14FFFFFF),
    lineStrong: Color(0x29FFFFFF),
    shadowColor: Color(0xFF000000),
  );

  static const AllInColors light = AllInColors(
    ink900: Color(0xFFF4F6F9),
    ink850: Color(0xFFEEF1F5),
    ink800: Color(0xFFE8ECF2),
    ink700: Color(0xFFDFE5ED),
    ink600: Color(0xFFD2DAE4),
    ink500: Color(0xFFBAC4D1),
    ink400: Color(0xFF96A2B0),
    ink300: Color(0xFF768393),
    text: Color(0xFF11161E),
    textMuted: Color(0xFF4A5666),
    textFaint: Color(0xFF6E7B8B),
    gold: Color(0xFFB08420),
    goldDark: Color(0xFF8C6818),
    goldLight: Color(0xFF96701C),
    good: Color(0xFF1E965A),
    bad: Color(0xFFC83030),
    warn: Color(0xFFB0801C),
    info: Color(0xFF286CC8),
    comboOffsuit: Color(0xFF96A1AE),
    line: Color(0x1A000000),
    lineStrong: Color(0x2E000000),
    shadowColor: Color(0xFF0F1723),
  );
}

/// Radii, spacing and elevation tokens.
class AllInRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

class AllInSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Theme extension so widgets can do `context.colors.gold`.
class AllInTheme extends ThemeExtension<AllInTheme> {
  const AllInTheme({required this.colors});
  final AllInColors colors;

  @override
  AllInTheme copyWith({AllInColors? colors}) =>
      AllInTheme(colors: colors ?? this.colors);

  @override
  AllInTheme lerp(ThemeExtension<AllInTheme>? other, double t) =>
      t < 0.5 ? this : (other as AllInTheme? ?? this);
}

extension AllInThemeContext on BuildContext {
  AllInColors get colors => Theme.of(this).extension<AllInTheme>()!.colors;
}
