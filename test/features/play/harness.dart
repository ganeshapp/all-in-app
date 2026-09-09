/// Shared scaffolding for the Play feature's tests: a hermetic
/// [ProviderContainer] with a seeded RNG, a fake clock, an in-process equity
/// service and an in-memory key-value store, plus the helpers that pump the
/// real router at a given phone size.
library;

import 'dart:math';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/router.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// §4.2.3's three supported widths.
const Size phone360 = Size(360, 780);
const Size phone390 = Size(390, 844);
const Size phone430 = Size(430, 932);

/// A container whose every source of nondeterminism is pinned.
ProviderContainer makeContainer({
  int seed = 7,
  KeyValueStore? store,
  FakeClock? clock,
  bool coachEnabled = false,
}) {
  final kv = store ?? KeyValueStore.memory();
  if (!coachEnabled) {
    // `SettingsNotifier.build` reads the store, so seed it before first read.
    kv.setJson(kSettingsKey, const AppSettings(coachEnabled: false).toJson());
  }
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      appDatabaseProvider.overrideWithValue(null),
      playRandomProvider.overrideWithValue(Random(seed)),
      playClockProvider.overrideWithValue(clock ?? FakeClock()),
      hapticDriverProvider.overrideWithValue(RecordingHapticDriver()),
      equityServiceProvider.overrideWith(
        (ref) => EquityService.inProcess(timeout: const Duration(seconds: 5)),
      ),
    ],
  );
  return container;
}

/// Lets every pending microtask and zero-duration future settle — the
/// notifier's `unawaited(_persist())` writes land here. Plain `test` only:
/// inside `testWidgets` the fake clock never advances on its own, so use
/// [settleWidgets].
Future<void> settle([int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// [settle] for widget tests. `testWidgets` runs inside a fake-async zone
/// where a zero-duration `Future` never completes on its own, so the real
/// timers the notifier posts have to be drained through `runAsync`.
Future<void> settleWidgets(WidgetTester tester, [int rounds = 6]) async {
  await tester.runAsync(() async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  });
}

/// Steps bots until it is the hero's turn or the hand is over.
void stepToHero(SessionNotifier notifier, SessionState Function() read) {
  for (var i = 0; i < 60; i++) {
    final table = read().table;
    if (table == null) return;
    if (table.phase != GamePhase.betting) return;
    if (table.toAct == 0) return;
    notifier.stepBot();
  }
}

/// Steps bots until the hand is over.
void stepToHandOver(SessionNotifier notifier, SessionState Function() read) {
  for (var i = 0; i < 200; i++) {
    final table = read().table;
    if (table == null || table.phase == GamePhase.handOver) return;
    if (table.toAct == 0) return;
    notifier.stepBot();
  }
}

/// Pumps the real router at [size] with [container] as the scope.
Future<void> pumpApp(
  WidgetTester tester, {
  required ProviderContainer container,
  required String location,
  Size size = phone390,
  double textScale = 1.0,
  bool dark = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = createRouter(initialLocation: location);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AllInAppTheme.light(),
        darkTheme: AllInAppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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
  await tester.pump(const Duration(milliseconds: 400));
}
