/// The two SRS-scheduled queues: coach-flagged leaks (`allin.leaks.v1`) and
/// missed-drill review cards (`allin.review.v1`)
/// (docs/port/persistence-stats-settings.md §6.7, §6.8; DESIGN.md §5.5).
library;

import 'dart:math';

import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

const int t0 = 1750000000000;
const int dayMs = 86400000;

LeakSpot leak({required String id, int ts = t0, SrsState? srs}) => LeakSpot(
  id: id,
  street: Street.river,
  heroPos: Position.bb,
  hole: const ['7h', '2c'],
  board: const ['Ah', 'Kd', '7c', '2s', '9h'],
  pot: 101,
  toCall: 99,
  bb: 1,
  oppActive: const [Position.btn],
  options: const [
    DrillOption(action: DrillAction.fold, label: 'Fold'),
    DrillOption(action: DrillAction.call, label: 'Call 99.0 bb', amount: 99),
  ],
  best: DrillAction.fold,
  rationale: 'Imported hand: you called 99.0 bb needing 50%…',
  equity: 0.3466,
  potOdds: 0.495,
  ts: ts,
  srs: srs,
);

void main() {
  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  group('LeakQueueStore', () {
    test('add prepends and schedules', () async {
      final leaks = LeakQueueStore(store);
      await leaks.add(leak(id: 'a'), nowMs: t0);
      await leaks.add(leak(id: 'b'), nowMs: t0);

      final all = leaks.load();
      expect(all.map((s) => s.id), ['b', 'a'], reason: 'newest first');
      expect(all.first.srs!.due, t0);
      expect(all.first.srs!.ease, 2.3);
    });

    test('round-trips every field through JSON', () async {
      await LeakQueueStore(store).add(leak(id: 'imp-1-preflop'), nowMs: t0);
      final s = LeakQueueStore(store).load().single;

      expect(s.id, 'imp-1-preflop');
      expect(s.street, Street.river);
      expect(s.heroPos, Position.bb);
      expect(s.hole, ['7h', '2c']);
      expect(s.board, ['Ah', 'Kd', '7c', '2s', '9h']);
      expect(s.pot, 101);
      expect(s.toCall, 99);
      expect(s.bb, 1);
      expect(s.oppActive, [Position.btn]);
      expect(s.options.last.label, 'Call 99.0 bb');
      expect(s.options.last.amount, 99);
      expect(s.best, DrillAction.fold);
      expect(s.equity, closeTo(0.3466, 1e-9));
      expect(s.potOdds, closeTo(0.495, 1e-9));
    });

    test('caps at 60, dropping the oldest', () async {
      final leaks = LeakQueueStore(store);
      for (var i = 0; i < kLeaksCap + 5; i++) {
        await leaks.add(leak(id: 'leak-$i'), nowMs: t0 + i);
      }
      final all = leaks.load();
      expect(all, hasLength(kLeaksCap));
      expect(all.first.id, 'leak-${kLeaksCap + 4}');
      expect(all.last.id, 'leak-5');
    });

    test('a spot stored without a schedule is due immediately', () async {
      await store.setJson(kLeaksKey, [
        leak(id: 'old', ts: t0).toJson()..remove('srs'),
      ]);
      final loaded = LeakQueueStore(store).load().single;
      expect(loaded.srs, isNotNull);
      expect(loaded.srs!.due, t0);
      expect(LeakQueueStore(store).dueSpots(nowMs: t0), hasLength(1));
    });

    test('three correct reviews retire a spot; a miss keeps it', () async {
      final leaks = LeakQueueStore(store);
      await leaks.add(leak(id: 'a'), nowMs: t0);

      await leaks.review('a', false, nowMs: t0);
      expect(leaks.load().single.srs!.lapses, 1);

      await leaks.review('a', true, nowMs: t0 + dayMs);
      await leaks.review('a', true, nowMs: t0 + 2 * dayMs);
      expect(leaks.load(), hasLength(1), reason: 'two wins do not graduate');

      await leaks.review('a', true, nowMs: t0 + 8 * dayMs);
      expect(leaks.load(), isEmpty);
    });

    test('duplicate ids are stored and retire together', () async {
      final leaks = LeakQueueStore(store);
      await leaks.add(leak(id: 'imp-1-preflop'), nowMs: t0);
      await leaks.add(leak(id: 'imp-1-preflop'), nowMs: t0);
      expect(
        leaks.load(),
        hasLength(2),
        reason: 'no de-duplication, as desktop',
      );

      for (var i = 1; i <= 3; i++) {
        await leaks.review('imp-1-preflop', true, nowMs: t0 + i * 10 * dayMs);
      }
      expect(leaks.load(), isEmpty);
    });

    test('dueSpots and nextDueAt split the queue', () async {
      final leaks = LeakQueueStore(store);
      await leaks.add(leak(id: 'due'), nowMs: t0);
      await leaks.add(leak(id: 'later'), nowMs: t0);
      await leaks.review('later', true, nowMs: t0);

      expect(leaks.dueSpots(nowMs: t0).map((s) => s.id), ['due']);
      expect(leaks.nextDueAt(nowMs: t0), t0 + dayMs);
      expect(leaks.dueSpots(nowMs: t0 + 2 * dayMs), hasLength(2));
    });

    test('clear empties it, and junk reads as empty', () async {
      final leaks = LeakQueueStore(store);
      await leaks.add(leak(id: 'a'), nowMs: t0);
      await leaks.clear();
      expect(leaks.load(), isEmpty);

      await store.setString(kLeaksKey, '{"not":"a list"}');
      expect(leaks.load(), isEmpty);
      expect(leaks.nextDueAt(nowMs: t0), isNull);
    });
  });

  group('ReviewQueueStore', () {
    Puzzle puzzle([int seed = 3]) => generatePuzzle(rng: Random(seed));

    test('addMiss stores a card keyed by the puzzle identity', () async {
      final review = ReviewQueueStore(store);
      final p = puzzle();
      await review.addMiss(p, nowMs: t0);

      final card = review.load().single;
      expect(card.id, ReviewCard.cardId(p));
      expect(card.id, contains('|'));
      expect(card.puzzle.handLabel, p.handLabel);
      expect(card.puzzle.best, p.best);
      expect(card.srs.due, t0);
    });

    test('the same spot is never queued twice', () async {
      final review = ReviewQueueStore(store);
      await review.addMiss(puzzle(), nowMs: t0);
      await review.addMiss(puzzle(), nowMs: t0 + 1);
      expect(review.load(), hasLength(1));
    });

    test('caps at 80', () async {
      final review = ReviewQueueStore(store);
      final cards = [
        for (var i = 0; i < kReviewCap + 5; i++)
          ReviewCard(id: 'card-$i', puzzle: puzzle(i + 1), srs: newSrs(t0)),
      ];
      await review.save(cards);
      expect(review.load(), hasLength(kReviewCap));
      expect(review.load().first.id, 'card-0');
    });

    test('three correct reviews retire a card', () async {
      final review = ReviewQueueStore(store);
      final p = puzzle();
      await review.addMiss(p, nowMs: t0);
      final id = ReviewCard.cardId(p);

      await review.review(id, true, nowMs: t0);
      await review.review(id, true, nowMs: t0 + dayMs);
      expect(review.load(), hasLength(1));
      await review.review(id, true, nowMs: t0 + 4 * dayMs);
      expect(review.load(), isEmpty);
    });

    test('a miss reschedules within ten minutes', () async {
      final review = ReviewQueueStore(store);
      final p = puzzle();
      await review.addMiss(p, nowMs: t0);
      await review.review(ReviewCard.cardId(p), false, nowMs: t0);

      final card = review.load().single;
      expect(card.srs.lapses, 1);
      expect(card.srs.due - t0, lessThanOrEqualTo(15 * 60000));
      expect(review.dueCards(nowMs: t0), isEmpty);
      expect(review.dueCards(nowMs: t0 + 11 * 60000), hasLength(1));
      expect(review.nextDueAt(nowMs: t0), card.srs.due);
    });

    test('an unreadable card is dropped, not fatal', () async {
      final review = ReviewQueueStore(store);
      await review.addMiss(puzzle(), nowMs: t0);
      final good = store.getJsonList(kReviewKey).single;
      await store.setJson(kReviewKey, [
        {'id': 'broken', 'puzzle': {}, 'srs': {}},
        good,
      ]);
      expect(review.load(), hasLength(1));
      expect(review.load().single.id, isNot('broken'));
    });

    test('clear empties it', () async {
      final review = ReviewQueueStore(store);
      await review.addMiss(puzzle(), nowMs: t0);
      await review.clear();
      expect(review.load(), isEmpty);
    });
  });
}
