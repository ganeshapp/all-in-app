/// `TabScaffold` — the `StatefulShellRoute` host from DESIGN.md §10.2: the
/// five-item Material 3 `NavigationBar` (§2.1), the Drills review badge, the
/// session-pill slot above the bar, and the rule that hides the whole bar on
/// the routes §16.1 lists.
///
/// Motion follows §11 (hide 250 / show 200, zeroed under reduced motion);
/// re-tapping the active tab pops its branch to the root and bumps
/// [tabReselectProvider] so the root can scroll itself to the top (§12).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// §11 durations that have no `AllInMotion` token of their own. They still go
/// through `AllInMotion.of` so reduced motion zeroes them.
const Duration _kBarHide = Duration(milliseconds: 250);
const Duration _kBarShow = Duration(milliseconds: 200);

/// Locations that hide the bar (§16.1). Root-level modals are listed too:
/// they cover the shell anyway, but the predicate is the single source of
/// truth and the tests assert it.
final List<RegExp> _kHiddenLocations = [
  RegExp(r'^/table(/.*)?$'),
  RegExp(r'^/placement$'),
  RegExp(r'^/onboarding$'),
  RegExp(r'^/lesson/.+$'),
  RegExp(r'^/study/lesson/.+$'),
  RegExp(r'^/study/range-editor$'),
  RegExp(r'^/stats/hand/.+$'),
  RegExp(r'^/home/session/[^/]+/hand/.+$'),
  RegExp(r'^/play/session/[^/]+/hand/.+$'),
  RegExp(r'^/stats/session/[^/]+/hand/.+$'),
];

class TabScaffold extends ConsumerWidget {
  const TabScaffold({super.key, required this.navigationShell});

  /// The shell built by `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell navigationShell;

  /// The pill only renders on tall screens at modest text scale (§2.1);
  /// below that the Play tab item carries the session instead.
  static const double pillHeight = 56;
  static const double pillGap = 8;
  static const double minHeightForPill = 800;
  static const double maxTextScaleForPill = 1.15;

  /// Whether the `NavigationBar` is hidden at [location] (path only).
  static bool hidesTabBar(String location) {
    final path = Uri.parse(location).path;
    return _kHiddenLocations.any((r) => r.hasMatch(path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final location = GoRouterState.of(context).uri.toString();
    final hidden = hidesTabBar(location);

    final session = ref.watch(shellSessionProvider);
    final due = ref.watch(drillsDueBadgeProvider);
    final reduced = ref.watch(reducedMotionProvider);

    final textScale = media.textScaler.scale(1);
    final pillFits =
        media.size.height >= minHeightForPill &&
        textScale <= maxTextScaleForPill;
    final showPill = session != null && pillFits;

    final barHeight =
        NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
    final chromeHeight =
        barHeight +
        media.padding.bottom +
        (showPill ? pillHeight + pillGap : 0);

    // The incoming route is laid out for a hidden bar from its first frame, so
    // nothing reflows while the bar slides away (§11).
    final body = MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          bottom: hidden ? media.padding.bottom : chromeHeight,
        ),
      ),
      child: navigationShell,
    );

    return Scaffold(
      backgroundColor: colors.ink900,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: hidden,
              child: AnimatedSlide(
                offset: hidden ? const Offset(0, 1) : Offset.zero,
                duration: AllInMotion.of(
                  context,
                  hidden ? _kBarHide : _kBarShow,
                  reduced: reduced,
                ),
                curve: AllInMotion.ease,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPill)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AllInSpace.lg,
                          right: AllInSpace.lg,
                          bottom: pillGap,
                        ),
                        child: _SessionPillSlot(session: session),
                      ),
                    _TabBar(
                      currentIndex: navigationShell.currentIndex,
                      due: due,
                      session: pillFits ? null : session,
                      onSelected: (index) => _onSelected(context, ref, index),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSelected(BuildContext context, WidgetRef ref, int index) {
    final reselected = index == navigationShell.currentIndex;
    // `initialLocation: true` pops the branch back to its root on a re-tap.
    navigationShell.goBranch(index, initialLocation: reselected);
    if (reselected) ref.read(tabReselectProvider.notifier).bump(index);
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.currentIndex,
    required this.due,
    required this.session,
    required this.onSelected,
  });

  final int currentIndex;
  final int due;

  /// Non-null only when the pill is height-gated out: the Play item then
  /// carries the session (§2.1).
  final ShellSession? session;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final playLabel =
        session == null ? 'Play' : 'Play · ${fmtSigned(session!.netBb)}';

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.light_mode_outlined),
          selectedIcon: Icon(Icons.light_mode),
          label: 'Home',
        ),
        NavigationDestination(
          icon: _SessionDot(
            show: session != null,
            child: const Icon(Icons.style_outlined),
          ),
          selectedIcon: _SessionDot(
            show: session != null,
            child: const Icon(Icons.style),
          ),
          label: playLabel,
        ),
        NavigationDestination(
          icon: Badge.count(
            count: due,
            isLabelVisible: due > 0,
            backgroundColor: colors.gold,
            textColor: AllInColors.dark.ink900,
            child: const Icon(Icons.track_changes_outlined),
          ),
          selectedIcon: Badge.count(
            count: due,
            isLabelVisible: due > 0,
            backgroundColor: colors.gold,
            textColor: AllInColors.dark.ink900,
            child: const Icon(Icons.track_changes),
          ),
          label: 'Drills',
        ),
        const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Study',
        ),
        const NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights),
          label: 'Stats',
        ),
      ],
    );
  }
}

/// The 6 pt gold dot on the Play icon while a session exists and the pill is
/// gated out (§2.1).
class _SessionDot extends StatelessWidget {
  const _SessionDot({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -1,
          right: -2,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.colors.gold,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stand-in for `SessionPill` (§10.2) until `features/play` wires the real
/// one: same 56 pt height, same copy, tap → the table.
class _SessionPillSlot extends StatelessWidget {
  const _SessionPillSlot({required this.session});

  final ShellSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hands = '${session.hands} hand${session.hands == 1 ? '' : 's'}';
    final net = '${fmtSigned(session.netBb)} bb';

    return Semantics(
      button: true,
      label: 'Session in progress, $hands, $net. Resume',
      child: Material(
        color: colors.ink800,
        borderRadius: BorderRadius.circular(AllInRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AllInRadius.lg),
          onTap: () => context.go(AllInRoutes.tablePath),
          child: Container(
            height: TabScaffold.pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AllInRadius.lg),
              border: Border.all(color: colors.line),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: colors.gold),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    '$hands · $net',
                    style: AllInText.mono(14, color: colors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Resume ›',
                  style: AllInText.body(
                    15,
                    weight: FontWeight.w600,
                    color: colors.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
