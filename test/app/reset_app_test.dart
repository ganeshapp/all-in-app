import 'dart:async';

import 'package:allin/app/app.dart';
import 'package:allin/app/app_runtime.dart';
import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/providers/reset_provider.dart';
import 'package:allin/app/reset_copy.dart';
import 'package:allin/features/drills/providers/drill_provider.dart';
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/features/onboarding/screens/onboarding_screen.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/providers/hand_reads_provider.dart';
import 'package:allin/engine/types.dart' show Street;
import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/features/stats/providers/data_actions.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AllInApp)));

void main() {
  for (final fromSettings in [false, true]) {
    testWidgets(
      'full reset from ${fromSettings ? 'Settings' : 'Stats'} restarts fresh',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = KeyValueStore.memory();
        await OnboardingStore(store).markOnboarded();
        await SettingsStore(store).save(
          const AppSettings(
            haptics: false,
            fourColorDeck: true,
            paceMode: PaceMode.auto,
          ),
        );
        await ThemeStore(store).save(AppThemeMode.light);
        await DrillStore(store).save(
          const DrillState(
            rating: 1400,
            solved: 12,
            correct: 8,
            streak: 3,
            best: 6,
          ),
        );
        // Seed every other category, including unknown future app keys.
        for (final key in [
          'allin.drill_answers.v1',
          'allin.leaks.v1',
          'allin.review.v1',
          'allin.goals.v1',
          'allin.handnotes.v1',
          'allin.future.v1',
        ]) {
          await store.setJson(key, {'old': true});
        }
        await store.setString('unrelated.preference', 'preserved');
        await tester.pumpWidget(AppRuntime(store: store));
        await tester.pumpAndSettle();
        final before = scope(tester);
        final oldStore = before.read(keyValueStoreProvider);
        await before.read(studyProgressProvider.notifier).complete('position');
        before.read(sessionProvider.notifier).newSession();
        await tester.pump(const Duration(milliseconds: 10));
        expect(before.read(sessionProvider).active, isTrue);
        before
            .read(handReadsProvider.notifier)
            .submit(
              HandRead(
                sessionId: before.read(sessionProvider).startedAt,
                handNumber: 1,
                seat: 1,
                playerName: 'Ivey',
                street: Street.preflop,
                selected: {'AKo'},
                estimatedRange: {'AKo', 'AA'},
                rangeOverlap: .8,
                submittedAt: 1,
              ),
            );
        await tester.pump();
        expect(before.read(handReadsProvider), hasLength(1));
        expect(before.read(drillScoreboardProvider).solved, 12);
        expect(before.read(studyCompletedCountProvider), 1);
        expect(before.read(themeProvider), AppThemeMode.light);
        expect(before.read(onboardingSeenProvider), isTrue);

        var finished = false;
        final reset =
            fromSettings
                ? before.read(settingsDataServiceProvider).resetProgress()
                : before.read(statsDataActionsProvider).resetProgress();
        unawaited(reset.then((_) => finished = true));
        await tester.pumpAndSettle();
        expect(finished, isTrue);
        final after = scope(tester);
        expect(identical(before, after), isFalse);
        expect(after.read(sessionProvider).active, isFalse);
        expect(after.read(handReadsProvider), isEmpty);
        expect(after.read(drillScoreboardProvider).solved, 0);
        expect(after.read(drillScoreboardProvider).rating, 1000);
        expect(after.read(studyCompletedCountProvider), 0);
        expect(after.read(themeProvider), AppThemeMode.dark);
        expect(after.read(settingsProvider).fourColorDeck, isFalse);
        expect(after.read(onboardingSeenProvider), isFalse);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(
          (await after.read(statsRepositoryProvider).loadStats()).handsPlayed,
          0,
        );
        expect(
          await after.read(statsRepositoryProvider).loadRecentHands(),
          isEmpty,
        );
        expect(after.read(sessionRepositoryProvider).hasSnapshot, isFalse);
        expect(store.keys(), {'unrelated.preference'});
        // A late save from the previous session must not recreate progress.
        expect(await oldStore.setString(kSessionSnapshotKey, 'old'), isFalse);
        await tester.pump(const Duration(seconds: 10));
        expect(store.keys(), {'unrelated.preference'});
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a failed erase stays visible and can be retried', (
    tester,
  ) async {
    final store = _FailOnceStore();
    await OnboardingStore(store).markOnboarded();
    await tester.pumpWidget(AppRuntime(store: store));
    await tester.pumpAndSettle();
    unawaited(scope(tester).read(resetAppProvider)());
    await tester.pumpAndSettle();
    expect(find.text(AppResetCopy.failed), findsOneWidget);
    expect(store.keys(), isNotEmpty);
    await tester.tap(find.text(AppResetCopy.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppResetCopy.failed), findsNothing);
    expect(scope(tester).read(onboardingSeenProvider), isFalse);
    expect(store.keys(), isEmpty);
  });
}

class _FailOnceStore extends MemoryKeyValueStore {
  bool fail = true;
  @override
  Future<bool> remove(String key) async {
    if (fail) {
      fail = false;
      return false;
    }
    return super.remove(key);
  }
}
