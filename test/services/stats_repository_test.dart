/// `StatsRepository` round-trips, caps and fallback behaviour
/// (docs/port/persistence-stats-settings.md §2.1, §2.3, §3, §4).
library;

import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

HandRecord hand({
  int n = 1,
  double netBb = 1.5,
  double potBb = 4,
  bool showdown = true,
  bool won = true,
  List<Archetype> archetypes = const [Archetype.tag],
  Position? position = Position.btn,
  bool? sawFlop = true,
  String? handJson,
  int ts = 1700000000000,
}) => HandRecord(
  n: n,
  netBb: netBb,
  potBb: potBb,
  showdown: showdown,
  won: won,
  archetypes: archetypes,
  position: position,
  sawFlop: sawFlop,
  handJson: handJson,
  ts: ts,
);

DecisionRecord decision({String verdict = 'mistake', String action = 'call'}) =>
    DecisionRecord(
      verdict: verdict,
      action: action,
      equity: 0.31,
      potOdds: 0.4,
      evBb: -1.25,
      street: 'flop',
      villainArchetype: 'TAG',
      position: 'BB',
      ts: 1700000000001,
    );

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late AppDatabase db;
  late MemoryKeyValueStore store;
  late StatsRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('allin_stats_test');
    db = AppDatabase(factory: factory, path: '${dir.path}/allin.db');
    store = MemoryKeyValueStore();
    repo = StatsRepository(database: db, store: store);
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('sqlite backend', () {
    test(
      'persistHand round-trips every field and moves the counters',
      () async {
        await repo.persistHand(hand(n: 3, netBb: 2.5), 50);

        final s = await repo.loadStats();
        expect(repo.backend, StatsBackend.sqlite);
        expect(s.handsPlayed, 1);
        expect(s.netChips, 50);
        expect(s.bigBlind, 20);
        expect(s.history, hasLength(1));
        final h = s.history.single;
        expect(h.n, 3);
        expect(h.netBb, 2.5);
        expect(h.potBb, 4);
        expect(h.showdown, isTrue);
        expect(h.won, isTrue);
        expect(h.archetypes, [Archetype.tag]);
        expect(h.position, Position.btn);
        expect(h.sawFlop, isTrue);
        expect(h.ts, 1700000000000);
        // hand_json is written but deliberately not loaded into the window.
        expect(h.handJson, isNull);
      },
    );

    test('net chips round like JavaScript Math.round', () async {
      await repo.persistHand(hand(), 10.5);
      await repo.persistHand(hand(n: 2), -10.5);
      expect((await repo.loadStats()).netChips, 11 - 10);
    });

    test('history comes back chronologically, oldest first', () async {
      for (var i = 1; i <= 5; i++) {
        await repo.persistHand(hand(n: i, ts: 1700000000000 + i), 0);
      }
      final s = await repo.loadStats();
      expect(s.history.map((h) => h.n), [1, 2, 3, 4, 5]);
    });

    test('the window keeps the newest HISTORY_CAP rows', () async {
      await db.open();
      final batch = db.db.batch();
      for (var i = 1; i <= StatsRepository.historyCap + 50; i++) {
        batch.rawInsert(
          'INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, '
          "archetypes, ts) VALUES (?, 0, 0, 0, 0, '[]', ?)",
          [i, i],
        );
      }
      await batch.commit(noResult: true);

      final s = await repo.loadStats();
      expect(s.history, hasLength(StatsRepository.historyCap));
      expect(s.history.first.n, 51);
      expect(s.history.last.n, StatsRepository.historyCap + 50);
    });

    test('guesses and decisions round-trip', () async {
      await repo.persistGuess(
        const GuessRecord(
          accuracy: 0.62,
          archetype: Archetype.nit,
          street: 'flop',
          ts: 9,
        ),
      );
      await repo.persistDecision(decision());

      final s = await repo.loadStats();
      expect(s.guesses.single.accuracy, closeTo(0.62, 1e-9));
      expect(s.guesses.single.archetype, Archetype.nit);
      expect(s.guesses.single.street, 'flop');

      final d = s.decisions.single;
      expect(d.verdict, 'mistake');
      expect(d.action, 'call');
      expect(d.equity, closeTo(0.31, 1e-9));
      expect(d.potOdds, closeTo(0.4, 1e-9));
      expect(d.evBb, closeTo(-1.25, 1e-9));
      expect(d.villainArchetype, 'TAG');
      expect(d.position, 'BB');
    });

    test('imported hands are inert but replayable', () async {
      await repo.persistHand(hand(handJson: '{"id":1,"imported":false}'), 20);
      final written = await repo.persistImportedHands([
        '{"id":90,"imported":true}',
        '{"id":91,"imported":true}',
      ]);

      expect(written, 2);
      final s = await repo.loadStats();
      expect(s.handsPlayed, 1, reason: 'imports never touch user_stats');
      expect(s.netChips, 20);
      expect(s.history, hasLength(1), reason: 'source IS NULL filters imports');

      final recent = await repo.loadRecentHands();
      expect(recent, hasLength(3));
      expect(recent.first, contains('"id":91'), reason: 'newest first');
    });

    test('loadRecentHands honours its limit', () async {
      await repo.persistImportedHands([
        for (var i = 0; i < 10; i++) '{"id":$i}',
      ]);
      expect(await repo.loadRecentHands(limit: 4), hasLength(4));
    });

    test('resetStats empties the tables but keeps big_blind', () async {
      await repo.persistHand(hand(handJson: '{"id":1}'), 100);
      await repo.persistGuess(
        const GuessRecord(accuracy: 1, street: 'preflop', ts: 1),
      );
      await repo.persistDecision(decision());

      await repo.resetStats();

      final s = await repo.loadStats();
      expect(s.handsPlayed, 0);
      expect(s.netChips, 0);
      expect(s.bigBlind, 20);
      expect(s.history, isEmpty);
      expect(s.guesses, isEmpty);
      expect(s.decisions, isEmpty);
      expect(await repo.loadRecentHands(), isEmpty);
    });

    test('exportBackup produces the desktop document', () async {
      await repo.persistHand(hand(handJson: '{"id":1}'), 40);
      final doc = jsonDecode(await repo.exportBackup()) as Map<String, Object?>;

      expect(
        doc.keys,
        containsAll(['exportedAt', 'backend', 'snapshot', 'hands']),
      );
      expect(doc['backend'], 'sqlite');
      final snapshot = doc['snapshot']! as Map<String, Object?>;
      expect(snapshot['handsPlayed'], 1);
      expect(snapshot['netChips'], 40);
      expect(snapshot['bigBlind'], 20);
      expect((snapshot['history']! as List), hasLength(1));
      expect((doc['hands']! as List).single, '{"id":1}');
    });
  });

  group('fallback', () {
    late StatsRepository broken;

    setUp(() {
      broken = StatsRepository(
        database: AppDatabase(
          factory: factory,
          path: '/allin-no-such-directory/allin.db',
        ),
        store: store,
      );
    });

    test(
      'an unopenable database pins the local backend and notes why',
      () async {
        expect(await broken.ensureBackend(), StatsBackend.local);
        expect(
          broken.lastError,
          startsWith('SQLite unavailable, using localStorage'),
        );
        expect(broken.backendInfo().backend, StatsBackend.local);
      },
    );

    test('writes land in the desktop localStorage shapes', () async {
      await broken.persistHand(hand(n: 2, handJson: '{"id":2}'), 33.4);
      await broken.persistGuess(
        const GuessRecord(accuracy: 0.5, street: 'turn', ts: 4),
      );
      await broken.persistDecision(decision(verdict: 'thin'));

      final stored =
          jsonDecode(store.getString(StatsRepository.statsKey)!)
              as Map<String, Object?>;
      expect(stored['handsPlayed'], 1);
      expect(stored['netChips'], 33);
      expect(stored['bigBlind'], 20);
      expect((stored['history']! as List).single, isA<Map<String, Object?>>());
      expect(
        ((stored['history']! as List).single as Map).containsKey('handJson'),
        isFalse,
        reason: 'the snapshot never carries the payload',
      );
      expect(jsonDecode(store.getString(StatsRepository.handsKey)!), [
        '{"id":2}',
      ]);

      final s = await broken.loadStats();
      expect(s.history.single.n, 2);
      expect(s.guesses.single.street, 'turn');
      expect(s.decisions.single.verdict, 'thin');
    });

    test('the local hand list is capped at 100, newest first', () async {
      await broken.persistImportedHands([
        for (var i = 0; i < 120; i++) '{"id":$i}',
      ]);
      final hands = await broken.loadRecentHands(limit: 1000);
      expect(hands, hasLength(StatsRepository.localHandsCap));
      expect(hands.first, '{"id":0}');
    });

    test('resetStats clears both keys', () async {
      await broken.persistHand(hand(handJson: '{"id":1}'), 10);
      await broken.resetStats();
      expect((await broken.loadStats()).handsPlayed, 0);
      expect(store.getString(StatsRepository.handsKey), isNull);
    });

    test('a corrupt snapshot reads as the empty default', () async {
      await store.setString(StatsRepository.statsKey, 'not json {');
      final s = await broken.loadStats();
      expect(s.handsPlayed, 0);
      expect(s.bigBlind, 20);
      expect(s.history, isEmpty);
    });
  });
}
