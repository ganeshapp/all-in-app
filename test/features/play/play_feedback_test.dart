import 'dart:math';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

class _MistakeCoach extends EquityService {
  @override
  Future<CoachReview?> evaluateHero(
    TableState state,
    poker.Action action,
    int id, {
    CoachSettings settings = CoachSettings.defaults,
    Object? key = EquityService.coachKey,
    Duration? timeout,
  }) async => CoachReview(
    id: id,
    kind: ReviewKind.decision,
    blocking: false,
    verdict: Verdict.mistake,
    title: 'Your call',
    board: state.board,
    text: 'This call costs more than it earns.',
  );
}

ProviderContainer feedbackContainer({
  required bool coach,
  bool haptics = true,
}) {
  final store = KeyValueStore.memory();
  store.setJson(
    kSettingsKey,
    AppSettings(coachEnabled: coach, haptics: haptics).toJson(),
  );
  return ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      playRandomProvider.overrideWithValue(Random(11)),
      equityServiceProvider.overrideWith((ref) => _MistakeCoach()),
      hapticDriverProvider.overrideWithValue(RecordingHapticDriver()),
    ],
  );
}

void main() {
  for (final enabled in [true, false]) {
    testWidgets('each coach verdict announces once; haptics enabled=$enabled', (
      tester,
    ) async {
      final platformHaptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            platformHaptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final container = feedbackContainer(coach: true, haptics: enabled);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier)..newSession();
      SessionState read() => container.read(sessionProvider);
      stepToHero(notifier, read);
      await pumpApp(tester, container: container, location: '/table');
      final driver =
          container.read(hapticDriverProvider) as RecordingHapticDriver;
      driver.clear();
      for (var note = 1; note <= 2; note++) {
        expect(read().heroToAct, isTrue);
        await notifier.heroAction(
          read().legal!.canCheck
              ? const poker.Action.check()
              : const poker.Action.call(),
        );
        await tester.pump();
        final review = read().activeReview!;
        expect(find.byType(CoachChip), findsOneWidget);
        expect(
          driver.played.where((p) => p == HapticPattern.warning).length,
          enabled ? note : 0,
        );
        var moves = 0;
        while (!read().heroToAct && !read().handOver && moves < 30) {
          notifier.stepBot();
          await tester.pump();
          moves++;
        }
        expect(moves, greaterThan(0));
        expect(read().activeReview!.id, review.id);
        expect(
          driver.played.where((p) => p == HapticPattern.warning).length,
          enabled ? note : 0,
        );
        // The old chip emitted heavyImpact each time changing seats/bet pills
        // remounted it. All verdict feedback must go through the driver above.
        expect(platformHaptics, isNot(contains('HapticFeedback.heavyImpact')));
        if (note == 1 && read().handOver) {
          notifier.deal();
          stepToHero(notifier, read);
          await tester.pump();
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
