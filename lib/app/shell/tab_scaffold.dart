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
import 'package:allin/features/play/providers/lobby_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
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
/// Where the Session pill is redundant: the Play lobby already shows a
/// full-width "Session in progress … Resume ›" card at the top of the same
/// screen, so the pill was a second copy of the same control (§2.2).
final RegExp _kPillRedundant = RegExp(r'^/play$');

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

  /// The `NavigationBar` label size (`app_theme.dart`).
  static const double labelSize = 11.5;

  /// §2.1's bar height, grown by one label line above 1.15×.
  ///
  /// That is exactly the point where the pill is gated out and the Play item
  /// takes the session on itself ("Play · +4.5"). At 360 × 1.3× that label
  /// wraps, and inside a fixed 68 pt bar the second line was painted straight
  /// through the active-indicator pill. `chromeHeight` is computed from the
  /// same number, so the routes that budget against it stay correct.
  static double barHeightFor(BuildContext context) {
    final base =
        NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
    final scaled = MediaQuery.textScalerOf(context).scale(labelSize);
    if (scaled <= labelSize * maxTextScaleForPill) return base;
    return base + scaled * 1.35;
  }

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
    final showPill =
        session != null &&
        pillFits &&
        !_kPillRedundant.hasMatch(Uri.parse(location).path);

    final barHeight = barHeightFor(context);
    final chromeHeight =
        barHeight +
        media.padding.bottom +
        // The pill now sits inside the bar's opaque surface with a gap above
        // *and* below it, so routes budgeting against `chromeHeight` still
        // clear it exactly (§5.1).
        (showPill ? pillHeight + pillGap * 2 : 0);

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
            // `NavigationBar` wraps itself in a `SafeArea`, and this bar is a
            // raw `Positioned` inside the Scaffold body, so that SafeArea also
            // applied the *status bar* inset — padding ~50 pt of dead space
            // above the bar and making it that much taller than
            // [chromeHeight] says. Routes that budget against `chromeHeight`
            // (Drills, §5.1) then lost their bottom band behind the bar.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
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
                  // The pill and the bar are **one opaque surface**. Floating
                  // the pill over a transparent band let live content scroll
                  // through the gaps around it — a paragraph sliced in half
                  // beside the pill, an eyebrow showing between pill and bar.
                  child: ColoredBox(
                    color: colors.ink850,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showPill)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AllInSpace.lg,
                              right: AllInSpace.lg,
                              top: pillGap,
                              bottom: pillGap,
                            ),
                            child: SessionPill(
                              session: session,
                              onResume: () => context.go(AllInRoutes.tablePath),
                              onEndSession: () => _endSession(context, ref),
                            ),
                          ),
                        _TabBar(
                          currentIndex: navigationShell.currentIndex,
                          due: due,
                          height: barHeight,
                          session: pillFits ? null : session,
                          onSelected:
                              (index) => _onSelected(context, ref, index),
                        ),
                      ],
                    ),
                  ),
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

    // §2.1: when the pill is height-gated out, the Play tab carries the
    // session — "tapping Play opens the lobby with the Resume card focused
    // and ringed gold for 2 s".
    if (index == 1 && ref.read(hasSessionProvider)) {
      ref.read(resumeFocusProvider.notifier).request();
    }
  }

  /// §4.13: the pill's swipe-left action. The session is written to the
  /// `sessions` table and its read-only P10 opens in the current branch.
  Future<void> _endSession(BuildContext context, WidgetRef ref) async {
    final id = await ref.read(sessionProvider.notifier).closeCurrentSession();
    if (!context.mounted || id == null) return;
    final branch = switch (navigationShell.currentIndex) {
      0 => AllInRoutes.todayPath,
      4 => AllInRoutes.progressPath,
      _ => AllInRoutes.lobbyPath,
    };
    context.push(AllInRoutes.sessionPath(branch, '$id'));
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.currentIndex,
    required this.due,
    required this.height,
    required this.session,
    required this.onSelected,
  });

  final int currentIndex;
  final int due;
  final double height;

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
      height: height,
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

/// `SessionPill` (§10.2): 56 pt, "● 12 hands · +4.5 bb   Resume ›", tap → the
/// table, swipe-left → End session (§4.13).
///
/// It lives here rather than in `lib/widgets/shell/` because that folder does
/// not exist yet; move it verbatim when the shell components land.
class SessionPill extends StatelessWidget {
  const SessionPill({
    super.key,
    required this.session,
    required this.onResume,
    required this.onEndSession,
  });

  final ShellSession session;
  final VoidCallback onResume;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hands = '${session.hands} hand${session.hands == 1 ? '' : 's'}';
    final net = '${fmtSigned(session.netBb)} bb';

    return Semantics(
      button: true,
      label: 'Session in progress, $hands, $net. Resume',
      // The swipe never removes the pill: it runs "End session" and springs
      // back, so a session can never be lost by a stray gesture (§2.1).
      child: Dismissible(
        key: const ValueKey('session-pill'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onEndSession();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AllInSpace.lg),
          decoration: BoxDecoration(
            color: colors.ink700,
            borderRadius: BorderRadius.circular(AllInRadius.lg),
          ),
          child: Text(
            'End session',
            style: AllInText.body(15, color: colors.bad),
          ),
        ),
        child: Material(
          color: colors.ink800,
          borderRadius: BorderRadius.circular(AllInRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.lg),
            onTap: onResume,
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
                  // Not gold: on the Drills tab this parks a second gold
                  // call-to-action ~12 pt under the drill's own gold primary,
                  // putting "leave the mode" in the same thumb slot as
                  // "Next puzzle". The gold live-dot already marks the pill
                  // as the session (§9's one-accent rule).
                  Text(
                    'Resume ›',
                    style: AllInText.body(
                      15,
                      weight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
