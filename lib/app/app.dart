/// `AllInApp` — the `MaterialApp.router` root (DESIGN.md §16.3): brand themes,
/// the explicit dark/light mode from Settings (§9), the 1.3× text-scale cap
/// the table's layout depends on (§13, §4.2.4), and the >600 pt "phone layout
/// centred in a 430-wide column" rule (§14).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/router.dart';
import 'package:allin/features/onboarding/widgets/onboarding_gate.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        // §8: first launch mounts O0 over the tab scaffold. The gate has to
        // sit here, above the routed subtree, and it was never mounted — so
        // the tour and the placement test never ran on a fresh install.
        final content = OnboardingGate(
          router: router,
          child: child ?? const SizedBox.shrink(),
        );
        final brightness = Theme.of(context).brightness;
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: maxTextScale),
          ),
          // §9: the status and navigation bars follow the theme *reactively*.
          // `main()` only styles the first frame; without this, switching to
          // Light at runtime left the clock, signal and battery white on the
          // #F4F6F9 page (~1.1:1) while the nav bar inverted correctly.
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: AllInAppTheme.overlayStyle(brightness),
            child:
                media.size.width > tabletBreakpoint
                    ? ColoredBox(
                      color:
                          brightness == Brightness.dark
                              ? AllInColors.dark.ink900
                              : AllInColors.light.ink900,
                      child: Center(
                        child: SizedBox(
                          width: phoneColumnWidth,
                          child: content,
                        ),
                      ),
                    )
                    : content,
          ),
        );
      },
    );
  }
}
