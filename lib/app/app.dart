/// `AllInApp` — the `MaterialApp.router` root (DESIGN.md §16.3): brand themes,
/// the explicit dark/light mode from Settings (§9), the 1.3× text-scale cap
/// the table's layout depends on (§13, §4.2.4), and the >600 pt "phone layout
/// centred in a 430-wide column" rule (§14).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/router.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AllInApp extends ConsumerWidget {
  const AllInApp({super.key});

  /// Text never scales past 1.3×; above it the action row drops amounts into
  /// the hero strip instead of growing (§13).
  static const double maxTextScale = 1.3;

  /// Wider than a phone: the phone layout is centred in this column (§14).
  static const double phoneColumnWidth = 430;
  static const double tabletBreakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'All-In',
      debugShowCheckedModeBanner: false,
      theme: AllInAppTheme.light(),
      darkTheme: AllInAppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = child ?? const SizedBox.shrink();
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: maxTextScale),
          ),
          child:
              media.size.width > tabletBreakpoint
                  ? ColoredBox(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AllInColors.dark.ink900
                            : AllInColors.light.ink900,
                    child: Center(
                      child: SizedBox(width: phoneColumnWidth, child: content),
                    ),
                  )
                  : content,
        );
      },
    );
  }
}
