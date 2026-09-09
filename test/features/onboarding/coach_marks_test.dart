/// O1 · the three first-table coach marks (DESIGN.md §4.15, §8.3).
///
/// "First three hands of the user's life only, never again" is a persistence
/// claim, so the counter is asserted across a fresh container over the same
/// storage — quitting between hands may neither repeat a caption nor skip one.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/features/onboarding/widgets/coach_marks.dart';
import 'package:allin/services/persistence/hints_store.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerOver(KeyValueStore store) {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('the counter (§4.15)', () {
    test('hands 1–3 each own one caption, in order', () async {
      final store = KeyValueStore.memory();
      final container = containerOver(store);
      final marks = container.read(coachMarksProvider.notifier);

      const expected = [CoachMark.step, CoachMark.eye, CoachMark.swipe];
      for (var hand = 1; hand <= 3; hand++) {
        await marks.handStarted(hand);
        final state = container.read(coachMarksProvider);
        expect(state.armed, isTrue, reason: 'hand $hand is still owed a mark');
        expect(state.markForThisHand, expected[hand - 1]);
      }
    });

    test(
      'the fourth hand turns them off, on this run and every later one',
      () async {
        final store = KeyValueStore.memory();
        final container = containerOver(store);
        final marks = container.read(coachMarksProvider.notifier);

        for (var hand = 1; hand <= 4; hand++) {
          await marks.handStarted(hand);
        }
        expect(container.read(coachMarksProvider).armed, isFalse);
        expect(container.read(coachMarksProvider).markForThisHand, isNull);

        // A fresh launch over the same storage stays off.
        final relaunched = containerOver(store);
        expect(relaunched.read(coachMarksProvider).armed, isFalse);
        await relaunched.read(coachMarksProvider.notifier).handStarted(5);
        expect(relaunched.read(coachMarksProvider).visible, isNull);
        expect(
          store.getJsonMap(kHintsKey)['firstHands'],
          lessThanOrEqualTo(kFirstHandsHintLimit + 1),
          reason: 'the counter parks one past the limit; it does not run away',
        );
      },
    );

    test('quitting between hands neither repeats nor skips', () async {
      final store = KeyValueStore.memory();

      await containerOver(
        store,
      ).read(coachMarksProvider.notifier).handStarted(1);

      // The app restarted: the counter survived, so hand 1's caption is not
      // replayed and hand 2 gets the *next* one, not the first one again.
      final second = containerOver(store);
      expect(second.read(coachMarksProvider).handsSeen, 1);
      await second.read(coachMarksProvider.notifier).handStarted(2);
      expect(second.read(coachMarksProvider).markForThisHand, CoachMark.eye);
      await second.read(coachMarksProvider.notifier).handStarted(3);
      expect(second.read(coachMarksProvider).markForThisHand, CoachMark.swipe);
    });

    test('heads-up owes its own three hands (§4.2.1)', () async {
      final store = KeyValueStore.memory();
      final container = containerOver(store);
      final marks = container.read(coachMarksProvider.notifier);

      // Four 6-max hands: the lifetime counter is spent, and the button
      // explainer has not been shown once, because it never applied.
      for (var hand = 1; hand <= 4; hand++) {
        await marks.handStarted(hand);
      }
      expect(container.read(coachMarksProvider).armed, isFalse);
      expect(container.read(coachMarksProvider).headsUpArmed, isFalse);

      // The user now sits heads-up for the first time.
      for (var hand = 5; hand <= 7; hand++) {
        await marks.handStarted(hand, headsUp: true);
        expect(
          container.read(coachMarksProvider).headsUpArmed,
          isTrue,
          reason: 'heads-up hand ${hand - 4} is still owed the explainer',
        );
      }

      // And it stops after three, on this run and the next.
      await marks.handStarted(8, headsUp: true);
      expect(container.read(coachMarksProvider).headsUpArmed, isFalse);
      final relaunched = containerOver(store);
      expect(relaunched.read(coachMarksProvider).headsUpArmed, isFalse);
      expect(
        store.getJsonMap(kHintsKey)['headsUpHands'],
        lessThanOrEqualTo(kFirstHandsHintLimit + 1),
      );
    });

    test('the same hand number never counts twice', () async {
      final container = containerOver(KeyValueStore.memory());
      final marks = container.read(coachMarksProvider.notifier);

      await marks.handStarted(1);
      await marks.handStarted(1);
      await marks.handStarted(1);

      expect(container.read(coachMarksProvider).handsSeen, 1);
    });
  });

  group('request / dismiss', () {
    test('only the caption this hand owes can be shown', () async {
      final container = containerOver(KeyValueStore.memory());
      final marks = container.read(coachMarksProvider.notifier);
      await marks.handStarted(1);

      marks.request(CoachMark.eye);
      expect(container.read(coachMarksProvider).visible, isNull);

      marks.request(CoachMark.step);
      expect(container.read(coachMarksProvider).visible, CoachMark.step);

      // Nothing else may take the slot while one is up.
      marks.request(CoachMark.eye);
      expect(container.read(coachMarksProvider).visible, CoachMark.step);
    });

    test('nothing is requestable once the marks are spent', () async {
      final container = containerOver(KeyValueStore.memory());
      final marks = container.read(coachMarksProvider.notifier);
      for (var hand = 1; hand <= 4; hand++) {
        await marks.handStarted(hand);
      }

      for (final mark in CoachMark.values) {
        marks.request(mark);
        expect(container.read(coachMarksProvider).visible, isNull);
      }
    });
  });

  group('CoachMarkCaption', () {
    Future<ProviderContainer> pumpCaption(
      WidgetTester tester, {
      required CoachMark mark,
      CoachMarkPointer pointer = CoachMarkPointer.down,
    }) async {
      final container = containerOver(KeyValueStore.memory());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AllInAppTheme.dark(),
            home: Scaffold(
              body: Center(
                child: CoachMarkCaption(mark: mark, pointer: pointer),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('renders nothing until its own caption is owed', (
      tester,
    ) async {
      final container = await pumpCaption(tester, mark: CoachMark.step);
      expect(find.text(CoachMark.step.caption), findsNothing);

      await container.read(coachMarksProvider.notifier).handStarted(1);
      container.read(coachMarksProvider.notifier).request(CoachMark.step);
      await tester.pumpAndSettle();

      expect(find.text(CoachMark.step.caption), findsOneWidget);
    });

    testWidgets('any tap dismisses it, and it never comes back', (
      tester,
    ) async {
      final container = await pumpCaption(tester, mark: CoachMark.step);
      await container.read(coachMarksProvider.notifier).handStarted(1);
      container.read(coachMarksProvider.notifier).request(CoachMark.step);
      await tester.pumpAndSettle();

      await tester.tap(find.text(CoachMark.step.caption));
      await tester.pumpAndSettle();
      expect(find.text(CoachMark.step.caption), findsNothing);

      // Hand 2 owes the eye, so the step caption cannot return.
      await container.read(coachMarksProvider.notifier).handStarted(2);
      container.read(coachMarksProvider.notifier).request(CoachMark.step);
      await tester.pumpAndSettle();
      expect(find.text(CoachMark.step.caption), findsNothing);
    });

    testWidgets('every pointer direction lays out without overflow', (
      tester,
    ) async {
      for (final pointer in CoachMarkPointer.values) {
        final container = await pumpCaption(
          tester,
          mark: CoachMark.swipe,
          pointer: pointer,
        );
        for (var hand = 1; hand <= 3; hand++) {
          await container.read(coachMarksProvider.notifier).handStarted(hand);
        }
        container.read(coachMarksProvider.notifier).request(CoachMark.swipe);
        await tester.pumpAndSettle();

        expect(find.text(CoachMark.swipe.caption), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$pointer');
      }
    });
  });

  test('the heads-up ticker line is the verbatim §4.15 sentence', () {
    expect(
      kHeadsUpFirstHandsTicker,
      "You're the button — you act first pre-flop, last after it",
    );
  });
}
