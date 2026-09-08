/// Router tests for DESIGN.md §16.1: every route resolves to the screen the
/// spec names, the tab bar hides exactly where §16.1 says, `/settings*`
/// redirects to the canonical `/stats/settings`, and `/play` never bounces to
/// `/table` (§2.1.1).
library;

import 'package:allin/app/app.dart';
import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/router.dart';
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
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Size kPhone = Size(390, 844);
const Size kSmallPhone = Size(360, 780);

void main() {
  /// Pumps the real app at [location] and returns its router.
  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    Size size = kPhone,
    List<Override> overrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final router = createRouter(initialLocation: location);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router), ...overrides],
        child: const AllInApp(),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('§16.1 routes resolve', () {
    final cases = <String, Type>{
      AllInRoutes.todayPath: TodayScreen,
      '/home/session/s1': SessionSummaryScreen,
      '/home/session/s1/hand/1712345678': ReplayerScreen,
      AllInRoutes.lobbyPath: LobbyScreen,
      '/play/session/s1': SessionSummaryScreen,
      '/play/session/s1/hand/1712345678': ReplayerScreen,
      AllInRoutes.drillsPath: DrillsScreen,
      AllInRoutes.studyPath: StudyScreen,
      '/study/lesson/pot-odds': LessonReaderScreen,
      '/study/tools/equity': ToolScreen,
      '/study/glossary': QuickReferenceScreen,
      AllInRoutes.progressPath: ProgressScreen,
      '/stats/hands': AllHandsScreen,
      '/stats/hand/1712345678': ReplayerScreen,
      '/stats/session/s1': SessionSummaryScreen,
      '/stats/session/s1/hand/1712345678': ReplayerScreen,
      AllInRoutes.settingsPath: SettingsScreen,
      AllInRoutes.aboutPath: AboutScreen,
      AllInRoutes.tablePath: TableScreen,
      '/table/read/3': ReadRangeScreen,
      '/table/hand/1712345678': ReplayerScreen,
      AllInRoutes.summaryTablePath: SessionSummaryScreen,
      '/table/summary/hand/1712345678': ReplayerScreen,
      '/lesson/pot-odds': LessonReaderScreen,
      AllInRoutes.placementPath: PlacementScreen,
      AllInRoutes.onboardingPath: OnboardingScreen,
      AllInRoutes.rangeEditorPath: RangeEditorScreen,
    };

    cases.forEach((path, screen) {
      testWidgets('$path → $screen', (tester) async {
        final router = await pumpAt(tester, path);
        expect(find.byType(screen), findsOneWidget);
        expect(locationOf(router), path);
      });
    });
  });

  group('route parameters reach the screen', () {
    testWidgets('/drills?mode=leaks&set=10', (tester) async {
      await pumpAt(tester, AllInRoutes.drillsWith(mode: 'leaks', set: 10));
      final screen = tester.widget<DrillsScreen>(find.byType(DrillsScreen));
      expect(screen.mode, 'leaks');
      expect(screen.setSize, 10);
    });

    testWidgets('/study/glossary?term= is a query, not a fragment', (
      tester,
    ) async {
      await pumpAt(tester, AllInRoutes.glossaryPath(term: 'potOdds'));
      expect(
        tester
            .widget<QuickReferenceScreen>(find.byType(QuickReferenceScreen))
            .term,
        'potOdds',
      );
    });

    testWidgets('/study/tools/:tool and /table/read/:seat', (tester) async {
      await pumpAt(tester, AllInRoutes.toolPath('pot-odds'));
      expect(
        tester.widget<ToolScreen>(find.byType(ToolScreen)).tool,
        'pot-odds',
      );

      await pumpAt(tester, AllInRoutes.readRangePath(4));
      expect(
        tester.widget<ReadRangeScreen>(find.byType(ReadRangeScreen)).seat,
        4,
      );
    });

    testWidgets('replayer gets :startedAt; summaries know read-only', (
      tester,
    ) async {
      await pumpAt(tester, AllInRoutes.statsHandPath(1712345678));
      expect(
        tester.widget<ReplayerScreen>(find.byType(ReplayerScreen)).startedAt,
        1712345678,
      );

      await pumpAt(
        tester,
        AllInRoutes.sessionPath(AllInRoutes.progressPath, 'abc'),
      );
      final readOnly = tester.widget<SessionSummaryScreen>(
        find.byType(SessionSummaryScreen),
      );
      expect(readOnly.readOnly, isTrue);
      expect(readOnly.sessionId, 'abc');

      await pumpAt(tester, AllInRoutes.summaryTablePath);
      final live = tester.widget<SessionSummaryScreen>(
        find.byType(SessionSummaryScreen),
      );
      expect(live.readOnly, isFalse);
      expect(live.sessionId, isNull);
    });

    testWidgets('/lesson/:id is the modal presentation', (tester) async {
      await pumpAt(tester, AllInRoutes.lessonModalPath('pot-odds'));
      expect(
        tester
            .widget<LessonReaderScreen>(find.byType(LessonReaderScreen))
            .presentation,
        LessonPresentation.modal,
      );

      await pumpAt(tester, AllInRoutes.lessonPath('pot-odds'));
      expect(
        tester
            .widget<LessonReaderScreen>(find.byType(LessonReaderScreen))
            .presentation,
        LessonPresentation.push,
      );
    });
  });

  group('legacy redirects (§16.1)', () {
    testWidgets('/settings → /stats/settings', (tester) async {
      final router = await pumpAt(tester, '/settings');
      expect(locationOf(router), AllInRoutes.settingsPath);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('/settings/data → /stats/settings?section=data', (
      tester,
    ) async {
      final router = await pumpAt(tester, '/settings/data');
      expect(locationOf(router), AllInRoutes.settingsSection('data'));
      expect(
        tester.widget<SettingsScreen>(find.byType(SettingsScreen)).section,
        'data',
      );
    });

    testWidgets('/home/settings and /home/settings/about', (tester) async {
      var router = await pumpAt(tester, '/home/settings');
      expect(locationOf(router), AllInRoutes.settingsPath);

      router = await pumpAt(tester, '/home/settings/about');
      expect(locationOf(router), AllInRoutes.aboutPath);
      expect(find.byType(AboutScreen), findsOneWidget);
    });
  });

  group('§2.1.1 the Play tab never redirects', () {
    testWidgets('/play shows the lobby even with a live session', (
      tester,
    ) async {
      final router = await pumpAt(
        tester,
        AllInRoutes.lobbyPath,
        overrides: [
          shellSessionProvider.overrideWithValue(
            const ShellSession(hands: 12, netBb: 4.5),
          ),
        ],
      );
      expect(find.byType(LobbyScreen), findsOneWidget);
      expect(find.byType(TableScreen), findsNothing);
      expect(locationOf(router), AllInRoutes.lobbyPath);
    });
  });

  group('§2.1 tab bar', () {
    test('hidesTabBar matches the §16.1 list', () {
      const hidden = [
        '/table',
        '/table/read/3',
        '/table/summary',
        '/table/summary/hand/1712345678',
        '/table/hand/1712345678',
        '/placement',
        '/onboarding',
        '/lesson/pot-odds',
        '/study/lesson/pot-odds',
        '/study/range-editor',
        '/stats/hand/1712345678',
        '/home/session/s1/hand/1712345678',
        '/play/session/s1/hand/1712345678',
        '/stats/session/s1/hand/1712345678',
      ];
      for (final location in hidden) {
        expect(
          TabScaffold.hidesTabBar(location),
          isTrue,
          reason: '$location must hide the bar',
        );
      }

      const visible = [
        '/home',
        '/home/session/s1',
        '/play',
        '/play/session/s1',
        '/drills?mode=leaks',
        '/study',
        '/study/tools/equity',
        '/study/glossary?term=potOdds',
        '/stats',
        '/stats/hands?filter=played',
        '/stats/session/s1',
        '/stats/settings',
        '/stats/settings/about',
      ];
      for (final location in visible) {
        expect(
          TabScaffold.hidesTabBar(location),
          isFalse,
          reason: '$location must keep the bar',
        );
      }
    });

    testWidgets('the bar is on screen on a tab root', (tester) async {
      await pumpAt(tester, AllInRoutes.todayPath);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(NavigationBar)).dy,
        lessThan(kPhone.height),
      );
    });

    testWidgets('a branch push slides the bar off screen', (tester) async {
      await pumpAt(tester, AllInRoutes.lessonPath('pot-odds'));
      expect(
        tester.getTopLeft(find.byType(NavigationBar)).dy,
        greaterThanOrEqualTo(kPhone.height - 0.5),
      );
    });

    testWidgets('a root-level modal has no bar at all', (tester) async {
      await pumpAt(tester, AllInRoutes.tablePath);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('tapping a tab switches branches', (tester) async {
      final router = await pumpAt(tester, AllInRoutes.todayPath);
      await tester.tap(find.text('Study'));
      await tester.pumpAndSettle();
      expect(find.byType(StudyScreen), findsOneWidget);
      expect(locationOf(router), AllInRoutes.studyPath);
    });

    testWidgets('re-tapping the active tab signals scroll-to-top', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = kPhone;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AllInApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(tabReselectProvider).seq, 0);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(container.read(tabReselectProvider).branch, 0);
      expect(container.read(tabReselectProvider).seq, 1);
    });
  });

  group('§2.1 session pill height gate', () {
    const session = ShellSession(hands: 12, netBb: 4.5);

    testWidgets('renders at 390×844', (tester) async {
      await pumpAt(
        tester,
        AllInRoutes.todayPath,
        overrides: [shellSessionProvider.overrideWithValue(session)],
      );
      expect(find.text('12 hands · +4.5 bb'), findsOneWidget);
      expect(find.text('Resume ›'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('below 800 pt the Play tab carries the session', (
      tester,
    ) async {
      await pumpAt(
        tester,
        AllInRoutes.todayPath,
        size: kSmallPhone,
        overrides: [shellSessionProvider.overrideWithValue(session)],
      );
      expect(find.text('Resume ›'), findsNothing);
      expect(find.text('Play · +4.5'), findsOneWidget);
    });
  });

  group('§11 / §13 app chrome', () {
    testWidgets('reduced motion zeroes route transitions', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = kPhone;
      addTearDown(tester.view.reset);

      final router = createRouter(reducedMotion: () => true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [routerProvider.overrideWithValue(router)],
          child: const AllInApp(),
        ),
      );
      await tester.pumpAndSettle();

      router.go(AllInRoutes.tablePath);
      await tester.pump();
      // No transition frames to wait for: the modal is already there.
      expect(find.byType(TableScreen), findsOneWidget);
    });

    testWidgets('text scaling is capped at 1.3×', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpAt(tester, AllInRoutes.todayPath);

      final context = tester.element(find.byType(TodayScreen));
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, 0.001));
      expect(tester.takeException(), isNull);
    });
  });

  group('settings + theme providers', () {
    test('defaults come from the persistence layer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.paceMode, PaceMode.manual);
      expect(settings.speedMs, PaceSpeed.normalMs);
      expect(settings.coachEnabled, isTrue);
      expect(settings.haptics, isTrue);
      expect(settings.autoDeal, isFalse);
      expect(settings.reducedMotion, isFalse);
      expect(settings.coachStrictness, CoachStrictness.standard);
      expect(settings.simQuality, SimQuality.standard);
      expect(container.read(reducedMotionProvider), isFalse);
      expect(container.read(hapticsEnabledProvider), isTrue);
    });

    test('stored settings and theme hydrate the providers', () {
      final store = KeyValueStore.memory();
      store.setJson(kSettingsKey, const {
        'reducedMotion': true,
        'haptics': false,
      });
      store.setString(kThemeKey, AppThemeMode.light.value);

      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(reducedMotionProvider), isTrue);
      expect(container.read(hapticsEnabledProvider), isFalse);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('updates persist and themeModeProvider follows the theme', () async {
      final store = KeyValueStore.memory();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      await container.read(themeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(store.getString(kThemeKey), AppThemeMode.light.value);

      await container
          .read(settingsProvider.notifier)
          .update(reducedMotion: true, paceMode: PaceMode.auto);
      expect(container.read(reducedMotionProvider), isTrue);
      final saved = SettingsStore(store).load();
      expect(saved.reducedMotion, isTrue);
      expect(saved.paceMode, PaceMode.auto);
    });
  });
}
