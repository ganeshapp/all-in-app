/// O0 · Onboarding tour → placement intro (DESIGN.md §8) — a full-screen
/// modal at `/onboarding` over everything else.
///
/// Five pages: the four verbatim tour pages (§8.1) and the optional placement
/// intro (§8.2). Horizontal paging and the primary button both advance; system
/// back goes to the previous page and, on page 1, gives the §2.5 blocked-back
/// response — a 120 ms 4 pt shake plus `selectionClick`, with the shake
/// dropped entirely under reduced motion and *nothing at all* when haptics are
/// off too (✕ and "Skip" are both on screen and are the stated exit).
///
/// Every close path — ✕, "Skip", "Skip — start playing" and the hand-off to
/// the placement test — calls `markSeen()`, so the tour never mounts itself
/// again (`allin.onboarded.v1`). Settings → "Run again" clears the flag and
/// pushes this route straight back.
library;

import 'dart:math' as math;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/onboarding/content/tour_copy.dart';
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/features/onboarding/widgets/tour_page.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  /// §2.5 blocked back: 120 ms, 4 pt horizontal.
  static const Duration shakeDuration = Duration(milliseconds: 120);
  static const double shakeAmplitude = 4;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: OnboardingScreen.shakeDuration,
  );

  int _page = 0;
  bool _leaving = false;

  @override
  void dispose() {
    _pages.dispose();
    _shake.dispose();
    super.dispose();
  }

  bool get _reduced => ref.read(reducedMotionProvider);

  /* ------------------------------------------------------------ navigation */

  void _goTo(int page) {
    final duration = AllInMotion.of(
      context,
      AllInMotion.base,
      reduced: _reduced,
    );
    if (duration == Duration.zero) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: duration, curve: AllInMotion.ease);
    }
  }

  /// §2.5: back on page 1 is refused, never silently. Motion is never the sole
  /// channel — reduced motion leaves the haptic, and with haptics off the
  /// screen's own ✕ and "Skip" carry the answer.
  void _blockedBack() {
    ref.read(hapticsProvider).blockedBack();
    if (_reduced) return;
    _shake.forward(from: 0).whenComplete(() {
      if (mounted) _shake.value = 0;
    });
  }

  /// Every close path of §8: mark the tour seen, then leave.
  Future<void> _close() async {
    if (_leaving) return;
    _leaving = true;
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.todayPath);
    }
  }

  /// §8.2 "Calibrate me" → D5 in place, in the same modal slot.
  Future<void> _calibrate() async {
    if (_leaving) return;
    _leaving = true;
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.pushReplacement(AllInRoutes.placementPath);
  }

  /* ----------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final reduced = settings.reducedMotion;
    final onPlacement = _page == TourCopy.placementPage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page == 0) {
          _blockedBack();
        } else {
          _goTo(_page - 1);
        }
      },
      child: AllInScaffold(
        leading: _HeaderIconButton(
          icon: Icons.close_rounded,
          label: TourCopy.close,
          onTap: _close,
        ),
        actions: [
          _SkipButton(
            label: TourCopy.skip,
            enableHaptics: settings.haptics,
            reducedMotion: reduced,
            onPressed: _close,
          ),
        ],
        body: AnimatedBuilder(
          animation: _shake,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(_shakeOffset, 0),
                child: child,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AllInSpace.lg,
                  0,
                  AllInSpace.lg,
                  AllInSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        TourCopy.title,
                        style: AllInText.display(
                          28,
                          color: c.text,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      onPlacement
                          ? TourCopy.placementDescriptor
                          : TourCopy.tourDescriptor(_page + 1),
                      style: AllInText.body(13, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: TourCopy.pageCount,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    if (i == TourCopy.placementPage) {
                      return const _PlacementIntroPage();
                    }
                    final copy = TourCopy.pages[i];
                    return TourPage(
                      copy: copy,
                      illustration:
                          i == TourCopy.pages.length - 1
                              ? TourCoachNotePreview(reducedMotion: reduced)
                              : null,
                    );
                  },
                ),
              ),
              if (!onPlacement)
                Padding(
                  padding: const EdgeInsets.only(top: AllInSpace.md),
                  child: TourDots(
                    count: TourCopy.pages.length,
                    current: _page,
                    reducedMotion: reduced,
                  ),
                ),
            ],
          ),
        ),
        bottom:
            onPlacement
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AllInButton.primary(
                      label: TourCopy.placementStart,
                      size: AllInButtonSize.lg,
                      expand: true,
                      trailing: Icons.track_changes_rounded,
                      enableHaptics: settings.haptics,
                      reducedMotion: reduced,
                      onPressed: _calibrate,
                    ),
                    const SizedBox(height: AllInSpace.sm),
                    AllInButton.ghost(
                      label: TourCopy.placementSkip,
                      expand: true,
                      enableHaptics: settings.haptics,
                      reducedMotion: reduced,
                      onPressed: _close,
                    ),
                  ],
                )
                : AllInButton.primary(
                  label:
                      _page == TourCopy.pages.length - 1
                          ? TourCopy.continueLabel
                          : TourCopy.next,
                  size: AllInButtonSize.lg,
                  expand: true,
                  trailing: Icons.chevron_right_rounded,
                  enableHaptics: settings.haptics,
                  reducedMotion: reduced,
                  onPressed: () => _goTo(_page + 1),
                ),
      ),
    );
  }

  /// Two decaying 4 pt wobbles across the 120 ms, ending exactly where it
  /// started.
  double get _shakeOffset =>
      OnboardingScreen.shakeAmplitude *
      (1 - _shake.value) *
      math.sin(_shake.value * 4 * math.pi);
}

/// Page 5 (§8.2): the placement paragraph, verbatim. Its two buttons live in
/// the pinned `bottom` slot, like every other page's primary.
class _PlacementIntroPage extends StatelessWidget {
  const _PlacementIntroPage();

  @override
  Widget build(BuildContext context) => TourPage(
    copy: const TourPageCopy(
      id: 'placement',
      icon: Icons.speed_rounded,
      title: TourCopy.placementTitle,
      body: TourCopy.placementBody,
    ),
  );
}

/// The four page pills (§8.1: gold for the current page and every page before
/// it, `ink700` after).
class TourDots extends StatelessWidget {
  const TourDots({
    super.key,
    required this.count,
    required this.current,
    this.reducedMotion = false,
  });

  final int count;
  final int current;
  final bool reducedMotion;

  static const double pillWidth = 20;
  static const double pillHeight = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: AllInMotion.of(
                    context,
                    AllInMotion.fast,
                    reduced: reducedMotion,
                  ),
                  width: pillWidth,
                  height: pillHeight,
                  decoration: BoxDecoration(
                    color: i <= current ? c.gold : c.ink700,
                    borderRadius: BorderRadius.circular(AllInRadius.pill),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The ✕ — 44 pt, like every other target (§12).
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 24, color: context.colors.text),
      ),
    ),
  );
}

/// "Skip" as a 44 pt text button (§8.1).
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.label,
    required this.onPressed,
    required this.enableHaptics,
    required this.reducedMotion,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => Center(
    child: AllInButton.ghost(
      label: label,
      size: AllInButtonSize.sm,
      enableHaptics: enableHaptics,
      reducedMotion: reducedMotion,
      onPressed: onPressed,
    ),
  );
}
