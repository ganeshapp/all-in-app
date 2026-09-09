/// The drill session state machine (DESIGN.md §5.3–§5.5, docs/port/
/// drill-ux-srs-leaks.md §6): spot generation per mode, grading, the Elo step
/// with the desktop's pinned deltas, the SRS ladder and retirement, the daily
/// goal, "Drill 5 similar" and the placement seeding.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/drills/content/drill_copy.dart';
import 'package:allin/features/drills/providers/drill_generator.dart';
import 'package:allin/features/drills/providers/drill_provider.dart';
import 'package:allin/features/drills/providers/goals_provider.dart';
import 'package:allin/features/drills/providers/review_provider.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drill_test_kit.dart';

const int _t0 = 1750000000000;
const int _day = 86400000;

LeakSpot _leakSpot({String id = 'leak-1', SrsState? srs}) => LeakSpot(
  id: id,
  street: Street.flop,
  heroPos: Position.co,
  hole: const ['Ah', 'Kd'],
  board: const ['As', '7c', '2d'],
  pot: 6,
  toCall: 2,
  bb: 1,
  oppActive: const [Position.bb],
  options: const [
    DrillOption(action: DrillAction.fold, label: 'Fold'),
    DrillOption(action: DrillAction.call, label: 'Call 2.0 bb', amount: 2),
  ],
  best: DrillAction.fold,
  rationale: 'You called 2 bb needing more than this hand can win.',
  ts: _t0,
  srs: srs,
);

void main() {
  group('spot generation', () {
    test('every mode deals a valid spot and grades it', () async {
      // The real engine, on this isolate: each mode must produce a puzzle
      // that satisfies the port's invariants and grade without throwing.
      for (final mode in DrillMode.values.where((m) => m.isPractice)) {
        final container = drillContainer(
          generator: InProcessDrillGenerator(seed: 42),
        );
        final notifier = container.read(drillProvider.notifier);
        await pumpEventQueue();
        await notifier.setMode(mode);

        final session = container.read(drillProvider);
        expect(session.phase, DrillPhase.ready, reason: mode.label);
        final puzzle = session.puzzle!;
        expect(puzzle.frames.length, greaterThanOrEqualTo(2));
        expect(puzzle.options.length, inInclusiveRange(2, 3));
        expect(puzzle.seats, hasLength(6));
        expect(puzzle.accept, contains(puzzle.best));
        expect(puzzle.difficulty, inInclusiveRange(1, 3));
        expect(session.navIndex, puzzle.frames.length - 1);

        await notifier.answer(puzzle.options.first.action);
        final graded = container.read(drillProvider);
        expect(graded.isAnswered, isTrue);
        expect(graded.result!.rationale, puzzle.rationale);
      }
    });

    test(
      'Mixed asks for an adaptive draw, Push/Fold and Exploits do not',
      () async {
        final generator = FakeDrillGenerator((_) => testPuzzle());
        final container = drillContainer(generator: generator);
        final notifier = container.read(drillProvider.notifier);
        await pumpEventQueue();

        // §12 quirk 14: the launch spot is NOT adaptive.
        expect(generator.requests.first.kind, DrillGenKind.mixed);

        await notifier.next();
        expect(generator.requests.last.kind, DrillGenKind.adaptive);

        await notifier.setMode(DrillMode.pushfold);
        expect(generator.requests.last.kind, DrillGenKind.pushfold);

        await notifier.setMode(DrillMode.exploit);
        expect(generator.requests.last.kind, DrillGenKind.exploit);
      },
    );

    test('a generator failure lands in the error state and retries', () async {
      final generator = FakeDrillGenerator((_) => testPuzzle())..fail = true;
      final container = drillContainer(generator: generator);
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();

      expect(container.read(drillProvider).phase, DrillPhase.error);
      generator.fail = false;
      await notifier.retry();
      expect(container.read(drillProvider).phase, DrillPhase.ready);
    });
  });

  group('rating', () {
    test('the Elo step matches the desktop pins', () {
      // docs/port/drill-ux-srs-leaks.md §6.6.
      expect(eloDelta(900, 1, true), 15);
      expect(eloDelta(900, 1, false), -9);
      expect(eloDelta(1000, 2, true), 18);
      expect(eloDelta(1000, 2, false), -6);
      expect(eloDelta(1400, 3, true), 12);
      expect(eloDelta(1400, 3, false), -12);
      expect(applyRatingDelta(105, -22), 100, reason: 'floor is 100');
    });

    test('a right answer raises the rating and the streak, a wrong one '
        'resets the streak', () async {
      final generator = FakeDrillGenerator(
        (_) => testPuzzle(difficulty: 2, best: DrillAction.call),
      );
      final container = drillContainer(generator: generator);
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();

      await notifier.answer(DrillAction.call);
      var board = container.read(drillScoreboardProvider);
      expect(container.read(drillProvider).ratingDelta, 18);
      expect(board.rating, 1018);
      expect(board.streak, 1);
      expect(board.best, 1);
      expect(board.solved, 1);
      expect(board.correct, 1);
      expect(container.read(drillAccuracyProvider), 100);

      await notifier.next();
      await notifier.answer(DrillAction.fold);
      board = container.read(drillScoreboardProvider);
      expect(container.read(drillProvider).ratingDelta, lessThan(0));
      expect(board.streak, 0);
      expect(board.best, 1, reason: 'best is kept forever');
      expect(board.solved, 2);
      expect(container.read(drillAccuracyProvider), 50);
    });

    test('the scoreboard persists to allin.drills.v1', () async {
      final store = KeyValueStore.memory();
      final generator = FakeDrillGenerator((_) => testPuzzle());
      final container = drillContainer(store: store, generator: generator);
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();
      await notifier.answer(DrillAction.call);

      expect(DrillStore(store).load().rating, 1018);
      expect(DrillStore(store).loadAnswers(), hasLength(1));
    });
  });

  group('review queue', () {
    test(
      'a practice miss queues the spot once, keyed by its identity',
      () async {
        final store = KeyValueStore.memory();
        final generator = FakeDrillGenerator((_) => testPuzzle());
        final container = drillContainer(store: store, generator: generator);
        final notifier = container.read(drillProvider.notifier);
        await pumpEventQueue();

        await notifier.answer(DrillAction.fold);
        final cards = ReviewQueueStore(store).load();
        expect(cards, hasLength(1));
        expect(cards.single.id, 'postflop-bet|KQs|As7d2c|BB');

        // Missing the same spot again keeps the original schedule.
        await notifier.next();
        await notifier.answer(DrillAction.fold);
        expect(ReviewQueueStore(store).load(), hasLength(1));
      },
    );

    test('a card graduates after three spaced successes and retires', () async {
      final store = KeyValueStore.memory();
      final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0));
      await ReviewQueueStore(store).addMiss(testPuzzle(), nowMs: _t0);

      final container = drillContainer(
        store: store,
        clock: clock,
        generator: FakeDrillGenerator((_) => testPuzzle()),
      );
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();
      await notifier.setMode(DrillMode.leaks);

      expect(container.read(reviewCountsProvider).due, 1);

      // 1st success → 1 day.
      await notifier.answer(DrillAction.call);
      expect(
        container.read(drillProvider).scheduleLine,
        'Next in 1 day · 1 of 3',
      );
      expect(ReviewQueueStore(store).load(), hasLength(1));

      // 2nd success, a day later → 3 days.
      clock.advance(const Duration(milliseconds: _day));
      await notifier.next();
      await notifier.answer(DrillAction.call);
      expect(
        container.read(drillProvider).scheduleLine,
        'Next in 3 days · 2 of 3',
      );

      // 3rd success → retired.
      clock.advance(const Duration(milliseconds: _day * 3));
      await notifier.next();
      await notifier.answer(DrillAction.call);
      expect(container.read(drillProvider).scheduleLine, DrillCopy.retired);
      expect(ReviewQueueStore(store).load(), isEmpty);
      expect(container.read(reviewCountsProvider).due, 0);

      // §5.5: the feedback stays until Next; Next then shows the empty state.
      expect(container.read(drillProvider).isAnswered, isTrue);
      await notifier.next();
      expect(container.read(drillProvider).phase, DrillPhase.empty);
    });

    test('a wrong review answer brings the card back in 10 minutes and never '
        'touches the rating', () async {
      final store = KeyValueStore.memory();
      final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0));
      await ReviewQueueStore(store).addMiss(testPuzzle(), nowMs: _t0);

      final container = drillContainer(
        store: store,
        clock: clock,
        generator: FakeDrillGenerator((_) => testPuzzle()),
      );
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();
      await notifier.setMode(DrillMode.leaks);
      final before = container.read(drillScoreboardProvider);

      await notifier.answer(DrillAction.fold);
      final session = container.read(drillProvider);
      expect(session.scheduleLine, DrillCopy.backInTenMinutes);
      expect(session.ratingDelta, 0);

      final after = container.read(drillScoreboardProvider);
      expect(after.rating, before.rating);
      expect(after.solved, before.solved);
      expect(after.streak, before.streak);

      final card = ReviewQueueStore(store).load().single;
      expect(card.srs.due, _t0 + 600000);
      expect(card.srs.wins, 0);
      expect(card.srs.lapses, 1);
    });

    test(
      'leak spots are replayed and retired through the leak queue',
      () async {
        final store = KeyValueStore.memory();
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0));
        await LeakQueueStore(store).add(_leakSpot(), nowMs: _t0);

        final container = drillContainer(
          store: store,
          clock: clock,
          generator: FakeDrillGenerator((_) => testPuzzle()),
        );
        final notifier = container.read(drillProvider.notifier);
        await pumpEventQueue();
        await notifier.setMode(DrillMode.leaks);

        final session = container.read(drillProvider);
        expect(session.puzzle!.kind, PuzzleKind.leak);
        expect(session.leakId, 'leak-1');
        expect(session.puzzle!.frames, hasLength(2));
        expect(
          session.puzzle!.frames.last.text,
          'Action on you in the CO facing 2.0 bb. What\'s the play?',
        );
        expect(DrillCopy.sourceLabel(session.puzzle!), DrillCopy.sourceLeak);

        var now = _t0;
        for (var i = 0; i < 3; i++) {
          await notifier.answer(DrillAction.fold);
          final next = LeakQueueStore(store).load();
          if (i < 2) {
            expect(next, hasLength(1));
            now += (i == 0 ? 1 : 3) * _day;
            clock.set(DateTime.fromMillisecondsSinceEpoch(now));
            await notifier.next();
          } else {
            expect(next, isEmpty, reason: 'retired after three spaced wins');
          }
        }
      },
    );

    test('the empty state reports the total and the next due time', () async {
      final store = KeyValueStore.memory();
      final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0));
      await ReviewQueueStore(store).addMiss(testPuzzle(), nowMs: _t0);
      await ReviewQueueStore(
        store,
      ).review('postflop-bet|KQs|As7d2c|BB', true, nowMs: _t0);

      final container = drillContainer(
        store: store,
        clock: clock,
        generator: FakeDrillGenerator((_) => testPuzzle()),
      );
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();
      await notifier.setMode(DrillMode.leaks);

      expect(container.read(drillProvider).phase, DrillPhase.empty);
      final counts = container.read(reviewCountsProvider);
      expect(counts.due, 0);
      expect(counts.total, 1);
      expect(counts.scheduled, 1);
      expect(counts.nextDueAt, _t0 + _day);
    });
  });

  group('daily goal', () {
    test('every mode counts toward the goal, Review included', () async {
      final store = KeyValueStore.memory();
      final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0));
      await ReviewQueueStore(store).addMiss(testPuzzle(), nowMs: _t0);

      final container = drillContainer(
        store: store,
        clock: clock,
        generator: FakeDrillGenerator((_) => testPuzzle()),
      );
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();

      await notifier.answer(DrillAction.call);
      expect(container.read(goalsProvider).todayDrills, 1);

      await notifier.setMode(DrillMode.leaks);
      await notifier.answer(DrillAction.call);
      expect(container.read(goalsProvider).todayDrills, 2);
    });

    test(
      'the day-streak counts met days backwards and never counts down',
      () async {
        final store = KeyValueStore.memory();
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0));
        final goals = GoalsStore(store);
        for (final offset in [0, _day, 2 * _day]) {
          for (var i = 0; i < kDailyDrillGoal; i++) {
            await goals.record(ActivityKind.drill, nowMs: _t0 - offset);
          }
        }
        final container = drillContainer(
          store: store,
          clock: clock,
          generator: FakeDrillGenerator((_) => testPuzzle()),
        );
        expect(container.read(goalsProvider).dayStreak, 3);
        expect(container.read(goalsProvider).met, isTrue);
        expect(container.read(goalsProvider).progress, 1);
      },
    );
  });

  group('focus and navigation', () {
    test('"Drill 5 similar" serves five spots of the same family', () async {
      final generator = FakeDrillGenerator(
        (_) => testPuzzle(kind: PuzzleKind.rfi),
      );
      final container = drillContainer(generator: generator);
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();
      await notifier.answer(DrillAction.call);
      await notifier.drillSimilar();

      expect(generator.requests.last.kind, DrillGenKind.ofKind);
      expect(generator.requests.last.focusKind, 'rfi');
      expect(container.read(drillProvider).focusLeft, 4);

      for (var expected = 3; expected >= 0; expected--) {
        await notifier.next();
        expect(container.read(drillProvider).focusLeft, expected);
      }
      // The sixth draw is adaptive again.
      await notifier.next();
      expect(generator.requests.last.kind, DrillGenKind.adaptive);
    });

    test(
      'the scrubber index is clamped and answering snaps to the decision',
      () async {
        final generator = FakeDrillGenerator((_) => testPuzzle());
        final container = drillContainer(generator: generator);
        final notifier = container.read(drillProvider.notifier);
        await pumpEventQueue();

        expect(container.read(drillProvider).navIndex, 2);
        notifier.setNav(0);
        expect(container.read(drillProvider).navIndex, 0);
        notifier.previousFrame();
        expect(container.read(drillProvider).navIndex, 0);
        notifier.setNav(99);
        expect(container.read(drillProvider).navIndex, 2);
        notifier.setNav(1);

        await notifier.answer(DrillAction.call);
        expect(container.read(drillProvider).navIndex, 2);
      },
    );

    test(
      'a mode switch resets the focus (documented deviation from §6.9)',
      () async {
        final generator = FakeDrillGenerator((_) => testPuzzle());
        final container = drillContainer(generator: generator);
        final notifier = container.read(drillProvider.notifier);
        await pumpEventQueue();
        await notifier.answer(DrillAction.call);
        await notifier.drillSimilar();
        expect(container.read(drillProvider).focusLeft, 4);

        await notifier.setMode(DrillMode.pushfold);
        expect(container.read(drillProvider).focusLeft, 0);
        expect(container.read(drillProvider).focusKind, isNull);
      },
    );
  });

  group('bounded set', () {
    test('the counter runs to the set size, then the set clears', () async {
      final generator = FakeDrillGenerator((_) => testPuzzle());
      final container = drillContainer(generator: generator);
      final notifier = container.read(drillProvider.notifier);
      await pumpEventQueue();
      await notifier.applyRoute(mode: 'mixed', setSize: 2);

      await notifier.answer(DrillAction.call);
      expect(container.read(drillProvider).setAnswered, 1);
      expect(container.read(drillProvider).setJustFinished, isFalse);

      await notifier.next();
      await notifier.answer(DrillAction.call);
      final session = container.read(drillProvider);
      expect(session.setJustFinished, isTrue);
      expect(session.setCorrect, 2);
      expect(
        DrillCopy.setDone(
          session.setCorrect,
          session.setSize!,
          session.setDelta,
        ),
        'Set done — 2 of 2 · rating +36',
      );

      await notifier.next();
      expect(container.read(drillProvider).setSize, isNull);
    });
  });

  group('placement seeding', () {
    test('the bands map score → rating and keep the other counters', () async {
      final store = KeyValueStore.memory();
      await DrillStore(store).save(
        const DrillState(
          rating: 1000,
          solved: 12,
          correct: 9,
          streak: 3,
          best: 7,
        ),
      );
      final container = drillContainer(
        store: store,
        generator: FakeDrillGenerator((_) => testPuzzle()),
      );

      expect(DrillStore.placementRating(0), 900);
      expect(DrillStore.placementRating(2), 900);
      expect(DrillStore.placementRating(3), 1050);
      expect(DrillStore.placementRating(5), 1050);
      expect(DrillStore.placementRating(6), 1250);
      expect(DrillStore.placementRating(8), 1250);

      await container.read(drillScoreboardProvider.notifier).seedRating(1250);
      final board = container.read(drillScoreboardProvider);
      expect(board.rating, 1250);
      expect(board.solved, 12);
      expect(board.correct, 9);
      expect(board.streak, 3);
      expect(board.best, 7);
      expect(DrillStore(store).load().rating, 1250);
    });
  });
}
