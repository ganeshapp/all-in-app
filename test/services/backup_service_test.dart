/// `BackupService`: export, inspect and restore — including a desktop-shaped
/// document, which must import unchanged (DESIGN.md §7.9, §14 "Backup
/// restore" rows; docs/port/persistence-stats-settings.md §4).
library;

import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A backup exactly as All-In desktop 1.1.2 writes it: no `schemaVersion`,
/// no `sessions`, `hands` as `JSON.stringify(HHHand)` strings.
const String kDesktopBackup =
    r'{"exportedAt":1780000000000,"backend":"sqlite","snapshot":'
    r'{"handsPlayed":41,"netChips":250,"bigBlind":20,"history":['
    r'{"n":1,"netBb":2.5,"potBb":9,"showdown":true,"won":true,'
    r'"archetypes":["TAG","Nit"],"position":"BTN","sawFlop":true,'
    r'"ts":1780000000001},'
    r'{"n":2,"netBb":-1,"potBb":4,"showdown":false,"won":false,'
    r'"archetypes":[],"position":"SB","sawFlop":false,"ts":1780000000002}],'
    r'"guesses":[{"accuracy":0.62,"archetype":"LAG","street":"flop",'
    r'"ts":1780000000003}],'
    r'"decisions":[{"verdict":"mistake","action":"call","equity":0.31,'
    r'"potOdds":0.4,"evBb":-1.25,"street":"river",'
    r'"villainArchetype":"Station","position":"BB","ts":1780000000004}]},'
    r'"hands":["{\"id\":7,\"startedAt\":1781838000000,\"button\":0,\"sb\":10,\"bb\":20,\"sbSeat\":1,\"bbSeat\":2,\"seats\":[{\"seat\":0,\"name\":\"You\",\"stack\":2000,\"isHero\":true,\"position\":\"BTN\"}],\"holes\":{\"0\":[\"As\",\"Ks\"]},\"actions\":[],\"board\":[],\"potResults\":[],\"heroNet\":260}"]}';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late AppDatabase db;
  late MemoryKeyValueStore store;
  late StatsRepository stats;
  late SessionRepository sessions;
  late BackupService backup;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('allin_backup_test');
    db = AppDatabase(factory: factory, path: '${dir.path}/allin.db');
    store = MemoryKeyValueStore();
    stats = StatsRepository(database: db, store: store);
    sessions = SessionRepository(database: db, store: store);
    backup = BackupService(stats: stats, sessions: sessions);
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<void> seed() async {
    await stats.persistHand(
      HandRecord(
        n: 1,
        netBb: 2.5,
        potBb: 9,
        showdown: true,
        won: true,
        archetypes: const [Archetype.tag],
        position: Position.btn,
        sawFlop: true,
        ts: 1780000000001,
        handJson: encodeHandJson(
          HHHand(
            id: 1,
            startedAt: 1000,
            button: 0,
            sb: 10,
            bb: 20,
            sbSeat: 1,
            bbSeat: 2,
            seats: [
              HHSeat(
                seat: 0,
                name: 'You',
                stack: 2000,
                isHero: true,
                position: Position.btn,
              ),
            ],
            heroNet: 50,
          ),
        ),
      ),
      50,
    );
    await stats.persistGuess(
      const GuessRecord(
        accuracy: 0.62,
        archetype: Archetype.lag,
        street: 'flop',
        ts: 1780000000003,
      ),
    );
    await stats.persistDecision(
      const DecisionRecord(
        verdict: 'mistake',
        action: 'call',
        equity: 0.31,
        potOdds: 0.4,
        evBb: -1.25,
        street: 'river',
        villainArchetype: 'Station',
        position: 'BB',
        ts: 1780000000004,
      ),
    );
    await sessions.recordEndedSession(
      const SessionRecord(
        startedAt: 1780000000000,
        endedAt: 1780000600000,
        seats: 6,
        hands: 31,
        netBb: 12.5,
        bb100: 40.3,
        mistakes: 2,
        summary: {'best': 3.2},
      ),
    );
  }

  test('the file name is allin-backup-YYYY-MM-DD.json', () {
    expect(
      BackupService.fileName(now: DateTime(2026, 9, 7)),
      'allin-backup-2026-09-07.json',
    );
  });

  test(
    'export carries the desktop keys plus schemaVersion and sessions',
    () async {
      await seed();
      final doc =
          jsonDecode(await backup.export(nowMs: 42)) as Map<String, Object?>;

      expect(doc['exportedAt'], 42);
      expect(doc['backend'], 'sqlite');
      expect(doc['schemaVersion'], AppDatabase.schemaVersion);
      expect((doc['snapshot']! as Map)['handsPlayed'], 1);
      expect((doc['hands']! as List), hasLength(1));
      expect((doc['sessions']! as List), hasLength(1));
      expect(((doc['sessions']! as List).single as Map)['hands'], 31);
    },
  );

  test('export → restore is a round trip', () async {
    await seed();
    final doc = await backup.export();

    await stats.resetStats();
    await sessions.clearEndedSessions();
    expect((await stats.loadStats()).handsPlayed, 0);

    final result = await backup.restore(doc);
    expect(result.ok, isTrue);
    expect(result.hands, 1);
    expect(result.guesses, 1);
    expect(result.decisions, 1);
    expect(result.handPayloads, 1);
    expect(result.sessions, 1);

    final s = await stats.loadStats();
    expect(s.handsPlayed, 1);
    expect(s.netChips, 50);
    expect(s.bigBlind, 20);
    expect(s.history.single.netBb, 2.5);
    expect(s.history.single.position, Position.btn);
    expect(s.history.single.archetypes, [Archetype.tag]);
    expect(s.history.single.sawFlop, isTrue);
    expect(s.guesses.single.archetype, Archetype.lag);
    expect(s.decisions.single.verdict, 'mistake');
    expect(s.decisions.single.villainArchetype, 'Station');

    final hands = await stats.loadRecentHands();
    expect(hands, hasLength(1));
    expect(
      HHHand.fromJson(jsonDecode(hands.single) as Map<String, Object?>).id,
      1,
    );

    final restoredSessions = await sessions.recentSessions();
    expect(restoredSessions.single.hands, 31);
    expect(restoredSessions.single.summary!['best'], 3.2);
  });

  test('restoring twice does not double the stats', () async {
    await seed();
    final doc = await backup.export();
    await backup.restore(doc);
    await backup.restore(doc);

    final s = await stats.loadStats();
    expect(s.handsPlayed, 1);
    expect(s.history, hasLength(1));
    expect(await stats.loadRecentHands(), hasLength(1));
    expect(await sessions.recentSessions(), hasLength(1));
  });

  group('a desktop backup', () {
    test('inspects as a restorable v4 document', () {
      final preview = backup.inspect(kDesktopBackup);
      expect(preview.isRestorable, isTrue);
      expect(preview.problem, isNull);
      expect(preview.exportedAt, 1780000000000);
      expect(preview.schemaVersion, AppDatabase.desktopSchemaVersion);
      expect(preview.handsPlayed, 41);
      expect(preview.handCount, 1);
      expect(preview.sessionCount, 0);
    });

    test('restores every record', () async {
      final result = await backup.restore(kDesktopBackup);
      expect(result.ok, isTrue);
      expect(result.hands, 2);
      expect(result.guesses, 1);
      expect(result.decisions, 1);
      expect(result.handPayloads, 1);
      expect(result.sessions, 0);

      final s = await stats.loadStats();
      expect(s.handsPlayed, 41);
      expect(s.netChips, 250);
      expect(s.bigBlind, 20);
      expect(s.history.map((h) => h.n), [1, 2]);
      expect(s.history.first.archetypes, [Archetype.tag, Archetype.nit]);
      expect(s.history.first.position, Position.btn);
      expect(s.history.last.sawFlop, isFalse);
      expect(s.guesses.single.accuracy, closeTo(0.62, 1e-9));
      expect(s.guesses.single.archetype, Archetype.lag);
      expect(s.decisions.single.evBb, closeTo(-1.25, 1e-9));
      expect(s.decisions.single.position, 'BB');

      final hands = HandsRepository(stats: stats);
      final row = (await hands.recentHands()).single;
      expect(row.hand.id, 7);
      expect(row.startedAt, 1781838000000);
      expect(row.hand.holes[0], ['As', 'Ks']);
      expect(row.imported, isFalse);
    });

    test('does not touch notes, leaks, settings or study progress', () async {
      await NotesRepository(store).setNote(1781838000000, note: 'keep me');
      await SettingsStore(store).save(const AppSettings(fourColorDeck: true));
      await StudyProgressStore(store).complete('rules');

      await backup.restore(kDesktopBackup);

      expect(NotesRepository(store).noteFor(1781838000000)!.note, 'keep me');
      expect(SettingsStore(store).load().fourColorDeck, isTrue);
      expect(StudyProgressStore(store).load().isComplete('rules'), isTrue);
    });
  });

  group('refusals', () {
    test('a newer schema is refused before anything is written', () async {
      await seed();
      final newer = jsonEncode({
        'exportedAt': 1,
        'schemaVersion': AppDatabase.schemaVersion + 1,
        'snapshot': const StatsSnapshot().toJson(),
        'hands': const <String>[],
      });

      final preview = backup.inspect(newer);
      expect(preview.problem, BackupProblem.newerSchema);
      expect(preview.isRestorable, isFalse);

      final result = await backup.restore(newer);
      expect(result.ok, isFalse);
      expect(result.problem, BackupProblem.newerSchema);
      expect(
        (await stats.loadStats()).handsPlayed,
        1,
        reason: 'nothing was touched',
      );
    });

    test('anything that is not a backup is refused', () async {
      for (final junk in [
        'not json',
        '[]',
        '{"hello":"world"}',
        '{"snapshot":"nope"}',
      ]) {
        expect(
          backup.inspect(junk).problem,
          BackupProblem.notABackup,
          reason: junk,
        );
        expect((await backup.restore(junk)).problem, BackupProblem.notABackup);
      }
    });
  });
}
