/// The `go_router` configuration — DESIGN.md §16.1 exactly: one
/// `StatefulShellRoute.indexedStack` with five branches, the root-level modal
/// routes (`parentNavigatorKey: rootKey`, `fullscreenDialog` where the spec
/// says so), the duplicated P10/P11/S1 hosts, and the legacy `/settings*`
/// redirects.
///
/// Two rules this file exists to keep: there is **no** redirect from `/play`
/// to `/table` (§2.1.1), and every route is built through [allInPage] so
/// reduced motion can zero its transition (§11).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/app/shell/tab_scaffold.dart';
import 'package:allin/features/drills/screens/drills_screen.dart';
import 'package:allin/features/drills/screens/placement_screen.dart';
import 'package:allin/features/home/screens/today_screen.dart';
import 'package:allin/features/onboarding/screens/onboarding_screen.dart';
import 'package:allin/features/play/screens/lobby_screen.dart';
import 'package:allin/features/play/screens/read_range_screen.dart';
import 'package:allin/features/play/screens/session_summary_screen.dart';
import 'package:allin/features/play/screens/table_screen.dart';
import 'package:allin/features/settings/screens/about_screen.dart';
import 'package:allin/features/settings/screens/settings_screen.dart';
import 'package:allin/features/stats/screens/all_hands_screen.dart';
import 'package:allin/features/stats/screens/progress_screen.dart';
import 'package:allin/features/stats/screens/replayer_screen.dart';
import 'package:allin/features/study/screens/lesson_reader_screen.dart';
import 'package:allin/features/study/screens/quick_reference_screen.dart';
import 'package:allin/features/study/screens/range_editor_screen.dart';
import 'package:allin/features/study/screens/study_screen.dart';
import 'package:allin/features/study/screens/tool_screen.dart';
import 'package:allin/services/persistence/hints_store.dart';
import 'package:allin/theme/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The cold-start flag of §2.1.1, kept inside the hints blob
/// (`allin.hints.v1.resumeOnLaunch`).
const String kResumeOnLaunchHint = 'resumeOnLaunch';

/// The one page builder for every route (§11). `fullscreenDialog` picks the
/// modal transition; reduced motion collapses either to zero.
Page<T> allInPage<T>(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool fullscreenDialog = false,
  bool reduced = false,
}) {
  final cupertino = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  final duration = AllInMotion.of(
    context,
    fullscreenDialog || cupertino ? AllInMotion.slide : AllInMotion.base,
    reduced: reduced,
  );

  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AllInMotion.ease,
        reverseCurve: AllInMotion.easeOut,
      );
      // iOS: slide up for modals, in from the right for pushes.
      // Android: fade-through for both (§16.2).
      if (!cupertino) {
        return FadeTransition(opacity: curved, child: child);
      }
      final begin = fullscreenDialog ? const Offset(0, 1) : const Offset(1, 0);
      return SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

/// Builds the app's router. [reducedMotion] is read per transition so the
/// Settings toggle takes effect without rebuilding the router.
GoRouter createRouter({
  String initialLocation = AllInRoutes.todayPath,
  GlobalKey<NavigatorState>? navigatorKey,
  bool Function()? reducedMotion,
}) {
  final rootKey =
      navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'allin-root');
  final branchKeys = <GlobalKey<NavigatorState>>[
    for (final name in const ['home', 'play', 'drills', 'study', 'stats'])
      GlobalKey<NavigatorState>(debugLabel: 'allin-$name'),
  ];

  bool reduced(BuildContext context) =>
      (reducedMotion?.call() ?? false) ||
      (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false);

  Page<dynamic> page(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    bool fullscreenDialog = false,
  }) => allInPage(
    context,
    state,
    child,
    fullscreenDialog: fullscreenDialog,
    reduced: reduced(context),
  );

  int handId(GoRouterState state) =>
      int.tryParse(state.pathParameters['startedAt'] ?? '') ?? -1;

  GoRoute replayer(String path, String name) => GoRoute(
    path: path,
    name: name,
    pageBuilder:
        (context, state) =>
            page(context, state, ReplayerScreen(startedAt: handId(state))),
  );

  GoRoute sessionSummary(String name, String replayerName) => GoRoute(
    path: 'session/:id',
    name: name,
    pageBuilder:
        (context, state) => page(
          context,
          state,
          SessionSummaryScreen(
            sessionId: state.pathParameters['id'],
            readOnly: true,
          ),
        ),
    routes: [replayer('hand/:startedAt', replayerName)],
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                TabScaffold(navigationShell: navigationShell),
        branches: [
          // ------------------------------------------------------ home / H0
          StatefulShellBranch(
            navigatorKey: branchKeys[0],
            routes: [
              GoRoute(
                path: AllInRoutes.todayPath,
                name: AllInRoutes.today,
                pageBuilder:
                    (context, state) =>
                        page(context, state, const TodayScreen()),
                routes: [
                  sessionSummary(
                    AllInRoutes.summaryHome,
                    AllInRoutes.replayerHome,
                  ),
                ],
              ),
            ],
          ),
          // ------------------------------------------------------ play / P0
          StatefulShellBranch(
            navigatorKey: branchKeys[1],
            routes: [
              GoRoute(
                path: AllInRoutes.lobbyPath,
                name: AllInRoutes.lobby,
                pageBuilder:
                    (context, state) =>
                        page(context, state, const LobbyScreen()),
                routes: [
                  sessionSummary(
                    AllInRoutes.summaryPlay,
                    AllInRoutes.replayerPlay,
                  ),
                ],
              ),
            ],
          ),
          // ---------------------------------------------------- drills / D0
          StatefulShellBranch(
            navigatorKey: branchKeys[2],
            routes: [
              GoRoute(
                path: AllInRoutes.drillsPath,
                name: AllInRoutes.drills,
                pageBuilder:
                    (context, state) => page(
                      context,
                      state,
                      DrillsScreen(
                        mode: state.uri.queryParameters['mode'],
                        setSize: int.tryParse(
                          state.uri.queryParameters['set'] ?? '',
                        ),
                      ),
                    ),
              ),
            ],
          ),
          // ----------------------------------------------------- study / S0
          StatefulShellBranch(
            navigatorKey: branchKeys[3],
            routes: [
              GoRoute(
                path: AllInRoutes.studyPath,
                name: AllInRoutes.study,
                pageBuilder:
                    (context, state) =>
                        page(context, state, const StudyScreen()),
                routes: [
                  GoRoute(
                    path: 'lesson/:id',
                    name: AllInRoutes.lesson,
                    pageBuilder:
                        (context, state) => page(
                          context,
                          state,
                          LessonReaderScreen(
                            lessonId: state.pathParameters['id'] ?? '',
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'tools/:tool',
                    name: AllInRoutes.tool,
                    pageBuilder:
                        (context, state) => page(
                          context,
                          state,
                          ToolScreen(tool: state.pathParameters['tool'] ?? ''),
                        ),
                  ),
                  GoRoute(
                    path: 'glossary',
                    name: AllInRoutes.quickReference,
                    pageBuilder:
                        (context, state) => page(
                          context,
                          state,
                          QuickReferenceScreen(
                            term: state.uri.queryParameters['term'],
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
          // ----------------------------------------------------- stats / T0
          StatefulShellBranch(
            navigatorKey: branchKeys[4],
            routes: [
              GoRoute(
                path: AllInRoutes.progressPath,
                name: AllInRoutes.progress,
                pageBuilder:
                    (context, state) =>
                        page(context, state, const ProgressScreen()),
                routes: [
                  GoRoute(
                    path: 'hands',
                    name: AllInRoutes.allHands,
                    pageBuilder:
                        (context, state) => page(
                          context,
                          state,
                          AllHandsScreen(
                            filter: state.uri.queryParameters['filter'],
                            tag: state.uri.queryParameters['tag'],
                          ),
                        ),
                  ),
                  replayer('hand/:startedAt', AllInRoutes.replayerStats),
                  sessionSummary(
                    AllInRoutes.summaryStats,
                    AllInRoutes.replayerStatsSession,
                  ),
                  GoRoute(
                    path: 'settings',
                    name: AllInRoutes.settings,
                    pageBuilder:
                        (context, state) => page(
                          context,
                          state,
                          SettingsScreen(
                            section: state.uri.queryParameters['section'],
                          ),
                        ),
                    routes: [
                      GoRoute(
                        path: 'about',
                        name: AllInRoutes.about,
                        pageBuilder:
                            (context, state) =>
                                page(context, state, const AboutScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------- root-level modals
      GoRoute(
        path: AllInRoutes.tablePath,
        name: AllInRoutes.table,
        parentNavigatorKey: rootKey,
        pageBuilder:
            (context, state) => page(
              context,
              state,
              const TableScreen(),
              fullscreenDialog: true,
            ),
        routes: [
          GoRoute(
            path: 'read/:seat',
            name: AllInRoutes.readRange,
            parentNavigatorKey: rootKey,
            pageBuilder:
                (context, state) => page(
                  context,
                  state,
                  ReadRangeScreen(
                    seat: int.tryParse(state.pathParameters['seat'] ?? '') ?? 0,
                  ),
                  fullscreenDialog: true,
                ),
          ),
          GoRoute(
            path: 'hand/:startedAt',
            name: AllInRoutes.replayerTable,
            parentNavigatorKey: rootKey,
            pageBuilder:
                (context, state) => page(
                  context,
                  state,
                  ReplayerScreen(startedAt: handId(state)),
                ),
          ),
          GoRoute(
            path: 'summary',
            name: AllInRoutes.summaryTable,
            parentNavigatorKey: rootKey,
            pageBuilder:
                (context, state) => page(
                  context,
                  state,
                  const SessionSummaryScreen(),
                  fullscreenDialog: true,
                ),
            routes: [
              GoRoute(
                path: 'hand/:startedAt',
                name: AllInRoutes.replayerSummary,
                parentNavigatorKey: rootKey,
                pageBuilder:
                    (context, state) => page(
                      context,
                      state,
                      ReplayerScreen(startedAt: handId(state)),
                    ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/lesson/:id',
        name: AllInRoutes.lessonModal,
        parentNavigatorKey: rootKey,
        pageBuilder:
            (context, state) => page(
              context,
              state,
              LessonReaderScreen(
                lessonId: state.pathParameters['id'] ?? '',
                presentation: LessonPresentation.modal,
              ),
              fullscreenDialog: true,
            ),
      ),
      GoRoute(
        path: AllInRoutes.placementPath,
        name: AllInRoutes.placement,
        parentNavigatorKey: rootKey,
        pageBuilder:
            (context, state) => page(
              context,
              state,
              const PlacementScreen(),
              fullscreenDialog: true,
            ),
      ),
      GoRoute(
        path: AllInRoutes.onboardingPath,
        name: AllInRoutes.onboarding,
        parentNavigatorKey: rootKey,
        pageBuilder:
            (context, state) => page(
              context,
              state,
              const OnboardingScreen(),
              fullscreenDialog: true,
            ),
      ),
      GoRoute(
        path: AllInRoutes.rangeEditorPath,
        name: AllInRoutes.rangeEditor,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          return page(
            context,
            state,
            RangeEditorScreen(
              initialHands: extra is Set<String> ? extra : const <String>{},
            ),
            fullscreenDialog: true,
          );
        },
      ),

      // ------------------------------------- legacy aliases (§16.1 redirects)
      GoRoute(
        path: '/settings',
        redirect: (context, state) => AllInRoutes.settingsPath,
      ),
      GoRoute(
        path: '/settings/data',
        redirect: (context, state) => AllInRoutes.settingsSection('data'),
      ),
      GoRoute(
        path: '/home/settings',
        redirect: (context, state) => AllInRoutes.settingsPath,
      ),
      GoRoute(
        path: '/home/settings/about',
        redirect: (context, state) => AllInRoutes.aboutPath,
      ),
    ],
  );
}

/// The app's router. Cold start only: if the app was killed while `/table` was
/// the active location, `allin.hints.v1.resumeOnLaunch` sends the user back to
/// the felt once, and the flag is cleared here (§2.1.1).
final routerProvider = Provider<GoRouter>((ref) {
  final store = ref.read(keyValueStoreProvider);
  var initial = AllInRoutes.todayPath;

  final hints = store.getJsonMap(kHintsKey);
  if (hints[kResumeOnLaunchHint] == true) {
    initial = AllInRoutes.tablePath;
    hints.remove(kResumeOnLaunchHint);
    store.setJson(kHintsKey, hints);
  }

  return createRouter(
    initialLocation: initial,
    reducedMotion: () => ref.read(settingsProvider).reducedMotion,
  );
});
