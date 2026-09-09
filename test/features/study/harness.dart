/// Shared pump helpers for the Study feature tests.
///
/// The harness builds a **small local router** with only the five Study routes
/// (at the real `AllInRoutes` paths) instead of the app router: the screens
/// under test navigate for real — "Next lesson" replaces, the unknown-lesson
/// fallback goes to `/study` — without dragging every other feature's screen
/// into the compile.
///
/// Every pump overrides `studyEquityServiceProvider` with an in-process
/// service so no test ever spawns an isolate.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/features/study/screens/lesson_reader_screen.dart';
import 'package:allin/features/study/screens/quick_reference_screen.dart';
import 'package:allin/features/study/screens/range_editor_screen.dart';
import 'package:allin/features/study/screens/study_screen.dart';
import 'package:allin/features/study/screens/tool_screen.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The three phone widths §13 requires.
const List<Size> kStudySizes = <Size>[
  Size(360, 780),
  Size(390, 844),
  Size(430, 932),
];

const Size kPhone390 = Size(390, 844);

GoRouter buildStudyRouter({String initialLocation = AllInRoutes.studyPath}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: AllInRoutes.studyPath,
        builder: (context, state) => const StudyScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'lesson/:id',
            builder:
                (context, state) => LessonReaderScreen(
                  lessonId: state.pathParameters['id'] ?? '',
                ),
          ),
          GoRoute(
            path: 'tools/:tool',
            builder:
                (context, state) =>
                    ToolScreen(tool: state.pathParameters['tool'] ?? ''),
          ),
          GoRoute(
            path: 'glossary',
            builder:
                (context, state) => QuickReferenceScreen(
                  term: state.uri.queryParameters['term'],
                ),
          ),
        ],
      ),
      GoRoute(
        path: '/lesson/:id',
        builder:
            (context, state) => LessonReaderScreen(
              lessonId: state.pathParameters['id'] ?? '',
              presentation: LessonPresentation.modal,
            ),
      ),
      GoRoute(
        path: AllInRoutes.rangeEditorPath,
        builder: (context, state) {
          final extra = state.extra;
          return RangeEditorScreen(
            initialHands: extra is Set<String> ? extra : const <String>{},
          );
        },
      ),
    ],
  );
}

/// Overrides every Study test needs: hermetic storage, no isolates, no real
/// vibration.
List<Override> studyOverrides({
  KeyValueStore? store,
  RecordingHapticDriver? haptics,
}) => <Override>[
  keyValueStoreProvider.overrideWithValue(store ?? KeyValueStore.memory()),
  hapticDriverProvider.overrideWithValue(haptics ?? RecordingHapticDriver()),
  studyEquityServiceProvider.overrideWith(
    (ref) => EquityService.inProcess(timeout: null),
  ),
];

/// Pumps [child] on its own, with the Study overrides and no router.
Future<void> pumpStudyWidget(
  WidgetTester tester,
  Widget child, {
  bool dark = true,
  double textScale = 1.0,
  Size size = kPhone390,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[...studyOverrides(), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AllInAppTheme.dark() : AllInAppTheme.light(),
        home: Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(body: child),
              ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Pumps a Study screen behind the local router.
Future<GoRouter> pumpStudyApp(
  WidgetTester tester, {
  String location = AllInRoutes.studyPath,
  bool dark = true,
  double textScale = 1.0,
  Size size = kPhone390,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = buildStudyRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[...studyOverrides(), ...overrides],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: dark ? AllInAppTheme.dark() : AllInAppTheme.light(),
        routerConfig: router,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// The current location of [router].
String locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();
