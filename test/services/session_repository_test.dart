/// `SessionRepository`: the paused-session snapshot and the ended-session
/// rows (DESIGN.md §4.14, §4.1, §16.4).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TableState dealtTable() {
  final rng = Random(11);
  var t = createTable(
    const GameConfig(
      seats: 6,
      startingStack: 2000,
      smallBlind: 10,
      bigBlind: 20,
    ),
    rng: rng,
  );
  return startHand(t, rng: rng);
}

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late AppDatabase db;
  late MemoryKeyValueStore store;
  late SessionRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('allin_session_test');
    db = AppDatabase(factory: factory, path: '${dir.path}/allin.db');
    store = MemoryKeyValueStore();
    repo = SessionRepository(database: db, store: store);
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('snapshot', () {
    test('round-trips the whole session', () async {
      final table = dealtTable();
      final snapshot = SessionSnapshot(
        options: const TableOptions(seats: 9, ante: 5),
        table: table,
        players: table.players,
        session: const {'hands': 12, 'netBb': 4.5, 'startedAt': 1700000000000},
        playSettings: const AppSettings(
          paceMode: PaceMode.auto,
          speedMs: PaceSpeed.fastMs,
          coachEnabled: false,
          autoDeal: true,
        ),
        reviewLog: const [
          {'kind': 'decision', 'verdict': 'thin'},
        ],
        savedAt: 1700000009999,
      );

      expect(repo.hasSnapshot, isFalse);
      await repo.saveSnapshot(snapshot);
      expect(repo.hasSnapshot, isTrue);

      final back = repo.loadSnapshot()!;
      expect(back.options.seats, 9);
      expect(back.options.ante, 5);
      expect(back.table!.handNumber, table.handNumber);
      expect(back.table!.board, table.board);
      expect(back.table!.toAct, table.toAct);
      expect(back.players, hasLength(6));
      expect(back.players.first.isHero, isTrue);
      expect(back.session['hands'], 12);
      expect(back.playSettings.paceMode, PaceMode.auto);
      expect(back.playSettings.speedMs, PaceSpeed.fastMs);
      expect(back.playSettings.coachEnabled, isFalse);
      expect(back.playSettings.autoDeal, isTrue);
      expect(back.reviewLog.single['verdict'], 'thin');
      expect(back.savedAt, 1700000009999);
      expect(back.tableRestoreFailed, isFalse);
    });

    test('a session between hands stores no table', () async {
      await repo.saveSnapshot(
        SessionSnapshot(options: const TableOptions(), savedAt: 1),
      );
      final back = repo.loadSnapshot()!;
      expect(back.table, isNull);
      expect(back.tableRestoreFailed, isFalse);
    });

    test('an unreadable table abandons the hand, not the session', () async {
      final table = dealtTable();
      final raw =
          jsonDecode(
                jsonEncode(
                  SessionSnapshot(
                    options: const TableOptions(seats: 2),
                    table: table,
                    players: table.players,
                    savedAt: 5,
                  ).toJson(),
                ),
              )
              as Map<String, Object?>;
      // Simulate a schema change this build cannot read.
      (raw['table']! as Map<String, Object?>)['street'] = 'fifth-street';
      await store.setString(kSessionSnapshotKey, jsonEncode(raw));

      final back = repo.loadSnapshot()!;
      expect(back.table, isNull);
      expect(back.tableRestoreFailed, isTrue);
      expect(back.options.seats, 2);
      expect(back.players, hasLength(6), reason: 'the roster still resumes');
    });

    test('corrupt JSON reads as no snapshot', () async {
      await store.setString(kSessionSnapshotKey, '{oops');
      expect(repo.loadSnapshot(), isNull);
    });

    test('clearSnapshot removes it', () async {
      await repo.saveSnapshot(
        SessionSnapshot(options: const TableOptions(), savedAt: 1),
      );
      await repo.clearSnapshot();
      expect(repo.hasSnapshot, isFalse);
      expect(repo.loadSnapshot(), isNull);
    });
  });

  group('ended sessions', () {
    SessionRecord record(int endedAt, {int hands = 10}) => SessionRecord(
      startedAt: endedAt - 600000,
      endedAt: endedAt,
      seats: 6,
      ante: 0,
      hands: hands,
      netBb: 12.5,
      bb100: 41.6,
      mistakes: 2,
      summary: {'best': 3.2, 'costliest': -3.1},
    );

    test('insert and read back, newest first', () async {
      for (var i = 1; i <= 3; i++) {
        expect(
          await repo.recordEndedSession(record(1700000000000 + i)),
          isNotNull,
        );
      }
      final rows = await repo.recentSessions();
      expect(rows.map((r) => r.endedAt), [
        1700000000003,
        1700000000002,
        1700000000001,
      ]);
      final r = rows.first;
      expect(r.seats, 6);
      expect(r.hands, 10);
      expect(r.netBb, 12.5);
      expect(r.bb100, 41.6);
      expect(r.mistakes, 2);
      expect(r.summary!['best'], 3.2);
      expect(r.id, isNotNull);
    });

    test('the lobby sees at most ten', () async {
      for (var i = 0; i < 14; i++) {
        await repo.recordEndedSession(record(1700000000000 + i));
      }
      expect(await repo.recentSessions(), hasLength(10));
      expect(await repo.recentSessions(limit: 3), hasLength(3));
    });

    test('sessionById finds one', () async {
      final id = await repo.recordEndedSession(record(1700000000000));
      final found = await repo.sessionById(id!);
      expect(found!.hands, 10);
      expect(await repo.sessionById(id + 999), isNull);
    });

    test('clearEndedSessions empties the table', () async {
      await repo.recordEndedSession(record(1700000000000));
      await repo.clearEndedSessions();
      expect(await repo.recentSessions(), isEmpty);
    });

    test('an unopenable database never throws', () async {
      final broken = SessionRepository(
        database: AppDatabase(
          factory: factory,
          path: '/allin-no-such-directory/allin.db',
        ),
        store: store,
      );
      expect(await broken.recordEndedSession(record(1)), isNull);
      expect(await broken.recentSessions(), isEmpty);
      expect(await broken.sessionById(1), isNull);
      await broken.clearEndedSessions();
    });
  });
}
