/// The §3.2 plan: priority order, the numbers each card prints, and the two
/// rules that are easy to get wrong (cards 2/5 are exclusive; the quick set
/// follows the weakest mode over its last 20 answers).
library;

import 'package:allin/engine/engine.dart' show DrillAction;
import 'package:allin/features/home/home_copy.dart';
import 'package:allin/features/home/providers/plan_provider.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_harness.dart';

void main() {
  group('plan order (§3.2)', () {
    test('first run: lesson, quick set, play — and nothing else', () {
      final container = homeContainer();
      final plan = container.read(planProvider);

      expect(plan.cards.map((c) => c.kind), [
        PlanCardKind.lesson,
        PlanCardKind.quickSet,
        PlanCardKind.play,
      ]);
      expect(plan.firstRun, isTrue);
      expect(plan.goalMet, isFalse);
      // §3.6: the first card is the primary one and it is the lesson.
      expect(plan.cards.first.title, startsWith('Continue: '));
      expect(plan.cards.first.subtitle, contains('0/31 done'));
    });

    test('reviews due come first, with the estimate and the button', () async {
      final store = KeyValueStore.memory();
      await seedLeaks(store, [
        leakSpot(id: 'a', best: DrillAction.fold),
        leakSpot(id: 'b', best: DrillAction.fold),
        leakSpot(id: 'c'),
        leakSpot(id: 'd'),
        leakSpot(id: 'e'),
      ]);
      final container = homeContainer(store: store);

      final plan = container.read(planProvider);
      final review = plan.cards.first;
      expect(review.kind, PlanCardKind.review);
      expect(review.title, HomeCopy.reviewTitle);
      expect(review.subtitle, '5 spots due · 2 are coach-flagged calls');
      // 5 spots × 20 s = 100 s → "~2 min".
      expect(review.estimate, '~2 min');
      expect(review.buttonLabel, HomeCopy.reviewButton);
      expect(review.route, '/drills?mode=leaks');
      expect(plan.cards.length, 4);
    });

    test('a paused session replaces Play 20 hands with Resume', () async {
      final store = KeyValueStore.memory();
      await seedSession(store, hands: 12, netChips: 90);
      final container = homeContainer(store: store);

      final plan = container.read(planProvider);
      expect(plan.cards.map((c) => c.kind), [
        PlanCardKind.resume,
        PlanCardKind.lesson,
        PlanCardKind.quickSet,
      ]);
      final resume = plan.entry(PlanCardKind.resume)!;
      expect(resume.subtitle, '12 hands, +4.5 bb · Coach on');
      expect(resume.estimate, '~6 min');
      expect(resume.route, '/table');
      expect(plan.entry(PlanCardKind.play), isNull);
      expect(plan.firstRun, isFalse);
    });

    test('never more than four cards', () async {
      final store = KeyValueStore.memory();
      await seedLeaks(store, [leakSpot(id: 'a')]);
      await seedSession(store);
      final container = homeContainer(store: store);

      expect(container.read(planProvider).cards.length, 4);
    });

    test('the goal being met is a line, not a change of plan', () async {
      final store = KeyValueStore.memory();
      await seedGoals(store, drills: 20);
      final container = homeContainer(store: store);

      final plan = container.read(planProvider);
      expect(plan.goalMet, isTrue);
      expect(plan.cards.length, 3);
    });

    test('play card reads the saved options and play settings', () async {
      final store = KeyValueStore.memory();
      await TableOptionsStore(store).save(const TableOptions(seats: 2));
      await SettingsStore(
        store,
      ).save(const AppSettings(coachEnabled: false, paceMode: PaceMode.auto));
      final container = homeContainer(store: store);

      final play = container.read(planProvider).entry(PlanCardKind.play)!;
      expect(play.title, 'Play 20 hands · Heads-up');
      expect(play.subtitle, 'Coach off · Auto pace');
      expect(play.estimate, '~6 min');
      expect(play.route, isNull);
    });

    test('a finished course keeps the card and changes the words', () async {
      final store = KeyValueStore.memory();
      await StudyProgressStore(
        store,
      ).save(StudyProgress(completed: List.of(kAllLessonIds)));
      final container = homeContainer(store: store);

      final lesson = container.read(planProvider).entry(PlanCardKind.lesson)!;
      expect(lesson.title, HomeCopy.lessonCompleteTitle);
      expect(lesson.route, '/study');
    });
  });

  group('quick set (§3.2 card 4)', () {
    test('mixed until a mode has five answers', () {
      expect(weakestMode(const []), QuickSetMode.mixed);
      expect(
        weakestMode([
          for (var i = 0; i < 4; i++) _answer('exploit', correct: false),
        ]),
        QuickSetMode.mixed,
      );
    });

    test('picks the weakest mode over its last twenty answers', () {
      final answers = [
        for (var i = 0; i < 10; i++) _answer('mixed', correct: true),
        // Old failures fall out of the window; the last 20 are all right.
        for (var i = 0; i < 10; i++) _answer('pushfold', correct: false),
        for (var i = 0; i < 20; i++) _answer('pushfold', correct: true),
        for (var i = 0; i < 6; i++) _answer('exploit', correct: i > 3),
      ];
      expect(weakestMode(answers), QuickSetMode.exploit);
    });

    test('the card deep-links with the set counter armed', () async {
      final store = KeyValueStore.memory();
      final drills = DrillStore(store);
      for (var i = 0; i < 6; i++) {
        await drills.recordAnswer(
          DrillAnswer(
            ts: homeNow().millisecondsSinceEpoch,
            mode: 'pushfold',
            kind: 'push/fold',
            correct: false,
            ratingAfter: 1000,
          ),
        );
      }
      await drills.save(
        const DrillState(rating: 1082, solved: 100, correct: 71),
      );
      final container = homeContainer(store: store);

      final set = container.read(planProvider).entry(PlanCardKind.quickSet)!;
      expect(set.title, 'A set of 10 push/fold spots');
      expect(set.subtitle, 'Rating 1,082 · 71 % accuracy');
      expect(set.route, '/drills?mode=pushfold&set=10');
      expect(set.estimate, '~4 min');
    });
  });

  group('estimates and placement', () {
    test('review minutes round up, never to zero', () {
      expect(reviewMinutes(0), 1);
      expect(reviewMinutes(1), 1);
      expect(reviewMinutes(3), 1);
      expect(reviewMinutes(4), 2);
      expect(reviewMinutes(5), 2);
      expect(reviewMinutes(10), 4);
    });

    test('day one follows the placement result, not the path order', () async {
      final store = KeyValueStore.memory();
      await DrillStore(store).save(const DrillState(rating: 1250));
      final container = homeContainer(store: store);

      final lesson = container.read(planProvider).entry(PlanCardKind.lesson)!;
      expect(lesson.route, '/study/lesson/threebet-pots');
      expect(lesson.subtitle, startsWith('Level 4 · '));
    });

    test('an un-placed rating falls back to the first incomplete lesson', () {
      final container = homeContainer();
      final lesson = container.read(planProvider).entry(PlanCardKind.lesson)!;
      expect(lesson.route, '/study/lesson/hand-rankings');
      expect(lesson.subtitle, startsWith('Level 1 · '));
    });
  });
}

DrillAnswer _answer(String mode, {required bool correct}) => DrillAnswer(
  ts: homeNow().millisecondsSinceEpoch,
  mode: mode,
  kind: 'chart',
  correct: correct,
  ratingAfter: 1000,
);
