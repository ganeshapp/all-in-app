// EquityService: isolate parity with the synchronous engine, memoisation,
// request coalescing/cancellation and the §14 give-up rule for the coach.
import 'dart:async';
import 'dart:math';

import 'package:allin/engine/coach.dart' as coach;
import 'package:allin/engine/engine.dart';
import 'package:allin/services/equity_service.dart';
import 'package:flutter_test/flutter_test.dart';

const GameConfig kConfig = GameConfig(
  seats: 6,
  startingStack: 2000,
  smallBlind: 10,
  bigBlind: 20,
);

/// A flop spot: hero (As Ks) on Kh 7d 2c facing a 100-chip bet from seat 1.
TableState flopState() {
  final table = createTable(kConfig, rng: Random(1));
  table.button = 3;
  final s = startHand(table, rng: Random(1));
  s.players[0].hole = <Card>['As', 'Ks'];
  s.street = Street.flop;
  s.board = <Card>['Kh', '7d', '2c'];
  s.pot = 200;
  s.currentBet = 100;
  s.aggressor = 1;
  for (final p in s.players) {
    p.committed = 0;
  }
  s.players[1].committed = 100;
  for (final seat in <int>[2, 3, 4, 5]) {
    s.players[seat].hasFolded = true;
  }
  s.toAct = 0;
  return s;
}

/// Counts runner invocations; runs the job in-process.
class CountingRunner {
  int calls = 0;
  final List<EquityJob> jobs = <EquityJob>[];

  Future<EquityResult> call(EquityJob job) async {
    calls++;
    jobs.add(job);
    return job.run();
  }
}

/// Holds every job until the test releases it.
class GatedRunner {
  final List<EquityJob> jobs = <EquityJob>[];
  final List<Completer<EquityResult>> gates = <Completer<EquityResult>>[];

  int get calls => jobs.length;

  Future<EquityResult> call(EquityJob job) {
    jobs.add(job);
    final gate = Completer<EquityResult>();
    gates.add(gate);
    return gate.future;
  }

  void release(int index) {
    if (!gates[index].isCompleted) gates[index].complete(jobs[index].run());
  }

  void releaseAll() {
    for (var i = 0; i < gates.length; i++) {
      release(i);
    }
  }
}

void main() {
  group('parity with the synchronous engine (real isolates)', () {
    late EquityService service;

    setUp(() => service = EquityService());
    tearDown(() => service.dispose());

    test('vsRange matches equityVsRangeCards for a fixed seed', () async {
      const hero = <Card>['As', 'Ks'];
      const board = <Card>['Kh', '7d', '2c'];
      const range = <HandLabel>['AA', 'KK', 'AKs', 'QJs', '77'];
      final expected = equityVsRangeCards(
        (hero[0], hero[1]),
        board,
        range,
        iters: 600,
        seed: 42,
      );
      final actual = await service.vsRange(
        hero: hero,
        board: board,
        range: range,
        iters: 600,
        seed: 42,
      );
      expect(actual, expected);
    });

    test('vsRandom matches equityVsRandomCards for a fixed seed', () async {
      const hero = <Card>['Ad', 'Qd'];
      const board = <Card>['2h', '7s', 'Ts'];
      final expected = equityVsRandomCards(
        (hero[0], hero[1]),
        board,
        iters: 500,
        seed: 7,
      );
      final actual = await service.vsRandom(
        hero: hero,
        board: board,
        iters: 500,
        seed: 7,
      );
      expect(actual, expected);
    });

    test('vsField matches equityVsFieldCards for a fixed seed', () async {
      const hero = <Card>['9c', '9h'];
      final expected = equityVsFieldCards(
        (hero[0], hero[1]),
        const <Card>[],
        3,
        iters: 500,
        seed: 11,
      );
      final actual = await service.vsField(
        hero: hero,
        opponents: 3,
        iters: 500,
        seed: 11,
      );
      expect(actual, expected);
    });

    test('rangeVsRange matches equityRangeVsRange for a fixed seed', () async {
      const heroRange = <HandLabel>['AKs', 'QQ'];
      const villRange = <HandLabel>['JJ', 'TT', 'AQo'];
      const board = <Card>['Kh', '7d', '2c'];
      List<IntCombo> expand(List<HandLabel> labels) => <IntCombo>[
        for (final label in labels)
          for (final combo in labelToCombos(label)) comboToInts(combo),
      ];
      final expected = equityRangeVsRange(
        expand(heroRange),
        board.map(cardToInt).toList(growable: false),
        expand(villRange),
        iters: 500,
        seed: 5,
      );
      final actual = await service.rangeVsRange(
        heroRange: heroRange,
        board: board,
        villainRange: villRange,
        iters: 500,
        seed: 5,
      );
      expect(actual, expected);
    });
  });

  group('memoisation', () {
    test('an identical seeded request is served from the LRU', () async {
      final runner = CountingRunner();
      final service = EquityService(runner: runner.call);
      addTearDown(service.dispose);

      final first = await service.vsRandom(
        hero: const <Card>['As', 'Ks'],
        iters: 200,
        seed: 3,
      );
      final second = await service.vsRandom(
        hero: const <Card>['As', 'Ks'],
        iters: 200,
        seed: 3,
      );

      expect(runner.calls, 1);
      expect(second, first);
      expect(service.stats.hits, 1);
      expect(service.stats.misses, 1);
    });

    test('seed, iters, board and range are all part of the key', () async {
      final runner = CountingRunner();
      final service = EquityService(runner: runner.call);
      addTearDown(service.dispose);

      await service.vsRandom(hero: const ['As', 'Ks'], iters: 200, seed: 3);
      await service.vsRandom(hero: const ['As', 'Ks'], iters: 200, seed: 4);
      await service.vsRandom(hero: const ['As', 'Ks'], iters: 300, seed: 3);
      await service.vsRandom(
        hero: const ['As', 'Ks'],
        board: const ['2c', '7d', 'Kh'],
        iters: 200,
        seed: 3,
      );
      await service.vsRange(
        hero: const ['As', 'Ks'],
        range: const ['AA'],
        iters: 200,
        seed: 3,
      );

      expect(runner.calls, 5);
      expect(service.stats.hits, 0);
    });

    test('unseeded requests are never memoised', () async {
      final runner = CountingRunner();
      final service = EquityService(runner: runner.call);
      addTearDown(service.dispose);

      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100);
      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100);

      expect(runner.calls, 2);
      expect(service.stats.hits, 0);
    });

    test('the LRU evicts the least recently used entry', () async {
      final runner = CountingRunner();
      final service = EquityService(runner: runner.call, cacheSize: 1);
      addTearDown(service.dispose);

      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 1);
      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 2);
      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 1);

      expect(runner.calls, 3);
    });

    test('clearCache forgets results', () async {
      final runner = CountingRunner();
      final service = EquityService(runner: runner.call);
      addTearDown(service.dispose);

      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 1);
      service.clearCache();
      await service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 1);

      expect(runner.calls, 2);
    });

    test('identical concurrent requests share one job', () async {
      final runner = GatedRunner();
      final service = EquityService(runner: runner.call, maxConcurrent: 2);
      addTearDown(service.dispose);

      final a = service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 9);
      final b = service.vsRandom(hero: const ['As', 'Ks'], iters: 100, seed: 9);
      runner.releaseAll();

      expect(await a, await b);
      expect(runner.calls, 1);
      expect(service.stats.started, 1);
    });
  });

  group('coalescing and cancellation', () {
    test('a superseded queued request never runs', () async {
      final runner = GatedRunner();
      final service = EquityService(runner: runner.call, maxConcurrent: 1);
      addTearDown(service.dispose);

      // Occupies the single slot.
      final busy = service.vsRandom(
        hero: const ['As', 'Ks'],
        iters: 100,
        seed: 1,
      );
      // Queued behind it under the same key: the second supersedes the first.
      final stale = service.vsRandom(
        hero: const ['Qd', 'Qh'],
        iters: 100,
        seed: 2,
        key: 'coach',
      );
      final fresh = service.vsRandom(
        hero: const ['7c', '2d'],
        iters: 100,
        seed: 3,
        key: 'coach',
      );

      await expectLater(stale, throwsA(isA<EquityCancelled>()));
      expect(runner.calls, 1, reason: 'only the busy job has started');

      runner.release(0);
      await busy;
      runner.releaseAll();
      await fresh;

      expect(runner.calls, 2, reason: 'the superseded job was dropped');
      expect(service.stats.dropped, 1);
      expect(runner.jobs.map((j) => j.hero.join()), ['AsKs', '7c2d']);
    });

    test('cancel() drops the delivery but keeps finished work', () async {
      final runner = GatedRunner();
      final service = EquityService(runner: runner.call, maxConcurrent: 1);
      addTearDown(service.dispose);

      final pending = service.vsRandom(
        hero: const ['As', 'Ks'],
        iters: 100,
        seed: 1,
        key: 'coach',
      );
      service.cancel('coach');
      await expectLater(pending, throwsA(isA<EquityCancelled>()));

      runner.releaseAll();
      await pumpEventQueue();

      // The isolate had already been paid for, so the answer is memoised.
      final again = await service.vsRandom(
        hero: const ['As', 'Ks'],
        iters: 100,
        seed: 1,
      );
      expect(runner.calls, 1);
      expect(again.samples, greaterThan(0));
    });

    test('cancelAll drops everything pending', () async {
      final runner = GatedRunner();
      final service = EquityService(runner: runner.call, maxConcurrent: 1);
      addTearDown(service.dispose);

      final a = service.vsRandom(
        hero: const ['As', 'Ks'],
        iters: 100,
        seed: 1,
        key: 'a',
      );
      final b = service.vsRandom(
        hero: const ['Qd', 'Qh'],
        iters: 100,
        seed: 2,
        key: 'b',
      );
      service.cancelAll();

      await expectLater(a, throwsA(isA<EquityCancelled>()));
      await expectLater(b, throwsA(isA<EquityCancelled>()));
      expect(runner.calls, 1, reason: 'b never left the queue');
    });
  });

  group('evaluateHero', () {
    test('matches the engine coach run synchronously', () async {
      final service = EquityService.inProcess();
      addTearDown(service.dispose);
      final action = const Action(ActionType.call);

      final expected = await coach.evaluateHero(flopState(), action, 1);
      final actual = await service.evaluateHero(flopState(), action, 1);

      expect(actual, isNotNull);
      expect(actual!.verdict, expected!.verdict);
      expect(actual.title, expected.title);
      expect(actual.text, expected.text);
      expect(actual.plain, expected.plain);
      expect(actual.equity, expected.equity);
      expect(actual.evChips, expected.evChips);
      expect(actual.blocking, expected.blocking);
      expect(service.coachFailures, 0);
    });

    test(
      'a superseded evaluation resolves to null, not a 50 % verdict',
      () async {
        final runner = GatedRunner();
        final service = EquityService(runner: runner.call, maxConcurrent: 1);
        addTearDown(service.dispose);

        final review = service.evaluateHero(
          flopState(),
          const Action(ActionType.call),
          1,
        );
        await pumpEventQueue();
        service.cancel(EquityService.coachKey);
        runner.releaseAll();

        expect(await review, isNull);
        expect(service.coachFailures, 0, reason: 'cancelling is not a failure');
      },
    );

    test('gives up after the timeout and records a failure', () async {
      final service = EquityService(
        runner: (job) => Completer<EquityResult>().future, // never resolves
        timeout: const Duration(milliseconds: 40),
      );
      addTearDown(service.dispose);

      final review = await service.evaluateHero(
        flopState(),
        const Action(ActionType.call),
        1,
      );

      expect(review, isNull);
      expect(service.coachFailures, 1);
      expect(service.stats.timeouts, greaterThanOrEqualTo(1));
    });

    test('an isolate error produces no review at all', () async {
      final service = EquityService(
        runner: (job) => Future<EquityResult>.error(StateError('isolate died')),
      );
      addTearDown(service.dispose);

      final review = await service.evaluateHero(
        flopState(),
        const Action(ActionType.call),
        1,
      );

      expect(review, isNull);
      expect(service.coachFailures, 1);
      expect(service.stats.errors, greaterThanOrEqualTo(1));
    });
  });
}
