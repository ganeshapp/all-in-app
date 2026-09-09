import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// Builds the app's [ThemeData] from the brand tokens. Features never read
/// colours from `ColorScheme` directly for brand surfaces — they use
/// `context.colors` (see tokens.dart); the scheme exists so Material widgets
/// (sheets, dialogs, switches, ripples) land on the right colours by default.
class AllInAppTheme {
  static ThemeData dark() => _build(AllInColors.dark, Brightness.dark);
  static ThemeData light() => _build(AllInColors.light, Brightness.light);

  /// Transparent bars so the felt and the tab bar own the safe areas; icon
  /// brightness follows the **resolved** brightness of the theme in force.
  ///
  /// This is keyed on [Brightness] rather than on `AppThemeMode` so a future
  /// `system` mode cannot invert the status bar: whatever `MaterialApp`
  /// actually rendered is what the bars are told about. `AllInApp` publishes it
  /// through an `AnnotatedRegion`, which re-applies it on every theme change —
  /// setting it once in `main()` left the clock, signal and battery white on
  /// the #F4F6F9 page after switching to Light at runtime.
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          dark ? AllInColors.dark.ink850 : AllInColors.light.ink850,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static ThemeData _build(AllInColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.gold,
      onPrimary: AllInColors.dark.ink900,
      secondary: c.goldLight,
      onSecondary: AllInColors.dark.ink900,
      error: c.bad,
      onError: Colors.white,
      surface: c.ink800,
      onSurface: c.text,
      surfaceContainerLowest: c.ink900,
      surfaceContainerLow: c.ink850,
      surfaceContainer: c.ink800,
      surfaceContainerHigh: c.ink700,
      surfaceContainerHighest: c.ink600,
      onSurfaceVariant: c.textMuted,
      outline: c.lineStrong,
      outlineVariant: c.line,
      shadow: c.shadowColor,
    );

    final text = TextTheme(
      displayLarge: AllInText.display(34, color: c.text),
      displayMedium: AllInText.display(30, color: c.text),
      displaySmall: AllInText.display(26, color: c.text),
      headlineLarge: AllInText.display(28, color: c.text),
      headlineMedium: AllInText.display(24, color: c.text),
      headlineSmall: AllInText.display(20, color: c.text),
      titleLarge: AllInText.display(18, weight: FontWeight.w700, color: c.text),
      titleMedium: AllInText.body(16, weight: FontWeight.w600, color: c.text),
      titleSmall: AllInText.body(14, weight: FontWeight.w600, color: c.text),
      bodyLarge: AllInText.body(16, color: c.text),
      bodyMedium: AllInText.body(15, color: c.text),
      bodySmall: AllInText.body(13, color: c.textMuted),
      labelLarge: AllInText.body(15, weight: FontWeight.w600, color: c.text),
      labelMedium: AllInText.body(
        13,
        weight: FontWeight.w600,
        color: c.textMuted,
      ),
      labelSmall: AllInText.eyebrow(c.textFaint),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.ink900,
      canvasColor: c.ink900,
      dividerColor: c.line,
      fontFamily: AllInFonts.body,
      textTheme: text,
      extensions: [AllInTheme(colors: c)],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.ink900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.text, size: 22),
        titleTextStyle: AllInText.display(20, color: c.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.ink850,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.gold.withValues(alpha: 0.15),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.gold : c.textFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AllInText.body(
            11.5,
            weight:
                s.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.gold : c.textFaint,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.ink800,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.4),
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AllInRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.ink800,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AllInRadius.lg),
        ),
        titleTextStyle: AllInText.display(19, color: c.text),
        contentTextStyle: AllInText.body(15, color: c.textMuted),
      ),
      cardTheme: CardThemeData(
        color: c.ink800,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AllInRadius.lg),
          side: BorderSide(color: c.line),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.gold : c.ink600,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.gold,
        inactiveTrackColor: c.ink600,
        thumbColor: c.gold,
        overlayColor: c.gold.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.gold,
        linearTrackColor: c.ink600,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink700,
        contentTextStyle: AllInText.body(14, color: c.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AllInRadius.pill),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.ink700,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          border: Border.all(color: c.line),
        ),
        textStyle: AllInText.body(13, color: c.text),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.gold,
        selectionColor: c.gold.withValues(alpha: 0.3),
      ),
      iconTheme: IconThemeData(color: c.text, size: 22),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
      ),
    );
  }
}
