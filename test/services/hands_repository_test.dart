/// `HandsRepository` and `NotesRepository`: the replayable-hand list, its
/// two filters, and hand notes/tags (DESIGN.md §7.5, §7.6;
/// docs/port/persistence-stats-settings.md §6.6).
library;

import 'dart:io';

import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

HHHand playedHand({
  required int id,
  required int startedAt,
  num heroNet = 40,
}) => HHHand(
  id: id,
  startedAt: startedAt,
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
    HHSeat(
      seat: 1,
      name: 'Ivey',
      stack: 2000,
      isHero: false,
      position: Position.sb,
    ),
  ],
  holes: {
    0: ['As', 'Ks'],
  },
  board: const ['Ah', 'Kd', '7c'],
  heroNet: heroNet,
);

ImportedHand importedHand({required int id, required int startedAt}) =>
    ImportedHand(
      id: id,
      startedAt: startedAt,
      button: 0,
      sb: 0.05,
      bb: 0.1,
      sbSeat: 1,
      bbSeat: 0,
      seats: [
        HHSeat(
          seat: 0,
          name: 'hero_name',
          stack: 12.35,
          isHero: true,
          position: Position.btn,
        ),
      ],
      holes: {
        0: ['Jh', 'Jc'],
      },
      heroNet: 0,
      heroName: 'hero_name',
    );

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late AppDatabase db;
  late MemoryKeyValueStore store;
  late StatsRepository stats;
  late HandsRepository hands;
  late NotesRepository notes;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('allin_hands_test');
    db = AppDatabase(factory: factory, path: '${dir.path}/allin.db');
    store = MemoryKeyValueStore();
    stats = StatsRepository(database: db, store: store);
    hands = HandsRepository(stats: stats);
    notes = NotesRepository(store);
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<void> seed() async {
    await stats.persistHand(
      HandRecord(
        n: 1,
        netBb: 2,
        potBb: 5,
        showdown: true,
        won: true,
        ts: 1,
        handJson: encodeHandJson(playedHand(id: 1, startedAt: 1000)),
      ),
      40,
    );
    await stats.persistHand(
      HandRecord(
        n: 2,
        netBb: -1,
        potBb: 5,
        showdown: false,
        won: false,
        ts: 2,
        handJson: encodeHandJson(
          playedHand(id: 2, startedAt: 2000, heroNet: -20),
        ),
      ),
      -20,
    );
    await stats.persistImportedHands([
      encodeJsonMap(importedHand(id: 799999, startedAt: 3000).toJson()),
    ]);
  }

  test('decodes played and imported hands, newest first', () async {
    await seed();
    final rows = await hands.recentHands();

    expect(rows.map((h) => h.startedAt), [3000, 2000, 1000]);
    expect(rows.first.imported, isTrue);
    expect(rows.first.hand, isA<ImportedHand>());
    expect((rows.first.hand as ImportedHand).heroName, 'hero_name');
    expect(rows.last.imported, isFalse);
    expect(rows.last.hand.holes[0], ['As', 'Ks']);
    expect(rows.last.netBb, 2, reason: 'heroNet / bb');
  });

  test('filters by source', () async {
    await seed();
    expect(
      (await hands.recentHands(
        source: HandSource.imported,
      )).map((h) => h.startedAt),
      [3000],
    );
    expect(
      (await hands.recentHands(
        source: HandSource.played,
      )).map((h) => h.startedAt),
      [2000, 1000],
    );
    expect(await hands.count(source: HandSource.all), 3);
  });

  test('filters by tag through the notes store', () async {
    await seed();
    await notes.setNote(2000, note: 'bad river call', tags: ['big pot']);

    final tagged = await hands.recentHands(
      tag: 'big pot',
      notes: notes.loadAll(),
    );
    expect(tagged.map((h) => h.startedAt), [2000]);

    final none = await hands.recentHands(
      tag: 'thin value',
      notes: notes.loadAll(),
    );
    expect(none, isEmpty);
  });

  test('handByStartedAt finds a hand, or nothing after a reset', () async {
    await seed();
    expect((await hands.handByStartedAt(2000))!.hand.id, 2);
    expect(await hands.handByStartedAt(12345), isNull);

    await stats.resetStats();
    expect(await hands.handByStartedAt(2000), isNull);
  });

  test('a corrupt payload is skipped, not fatal', () async {
    await stats.persistImportedHands(['not json at all', '{"unexpected":1}']);
    await seed();
    final rows = await hands.recentHands();
    expect(rows.map((h) => h.startedAt), [3000, 2000, 1000]);
  });

  test('coach notes ride along with a played hand', () async {
    await stats.persistHand(
      HandRecord(
        n: 1,
        netBb: 0,
        potBb: 0,
        showdown: false,
        won: false,
        ts: 1,
        handJson: encodeHandJson(
          playedHand(id: 9, startedAt: 9000),
          coachNotes: const [
            CoachNoteRecord(
              street: 'flop',
              action: 'raise',
              verdict: 'great',
              title: 'Nice raise',
              plain: 'You had the equity to pressure.',
            ),
          ],
        ),
      ),
      0,
    );
    final row = (await hands.recentHands()).single;
    expect(row.coachNotes.single.verdict, 'great');
    expect(row.coachNotes.single.title, 'Nice raise');
  });

  group('NotesRepository', () {
    test('set, read, tag and remove', () async {
      await notes.setNote(
        1000,
        note: 'called too wide',
        tags: ['review later', 'bluff-catch'],
        nowMs: 42,
      );

      expect(notes.hasNote(1000), isTrue);
      final n = notes.noteFor(1000)!;
      expect(n.note, 'called too wide');
      expect(n.tags, ['review later', 'bluff-catch']);
      expect(n.ts, 42);
      expect(n.isEmpty, isFalse);

      await notes.remove(1000);
      expect(notes.hasNote(1000), isFalse);
    });

    test('keys are the hand startedAt, desktop-shaped', () async {
      await notes.setNote(1781838000000, note: 'x', nowMs: 1);
      final raw = store.getJsonMap(kHandNotesKey);
      expect(raw.keys, ['1781838000000']);
      expect((raw['1781838000000']! as Map)['note'], 'x');
      expect((raw['1781838000000']! as Map)['tags'], isEmpty);
    });

    test('allTags lists presets first, then custom ones', () async {
      await notes.setNote(1, tags: ['weird line', 'donk-lead'], nowMs: 1);
      await notes.setNote(2, tags: ['big pot', 'aggro'], nowMs: 1);
      expect(notes.allTags(), ['weird line', 'big pot', 'aggro', 'donk-lead']);
    });

    test('toggleTag lower-cases and toggles', () {
      expect(notes.toggleTag(const [], ' Big Pot '), ['big pot']);
      expect(notes.toggleTag(const ['big pot'], 'big pot'), isEmpty);
      expect(notes.toggleTag(const ['a'], '   '), ['a']);
    });

    test('a corrupt notes blob reads as empty', () async {
      await store.setString(kHandNotesKey, '[]');
      expect(notes.loadAll(), isEmpty);
      expect(notes.allTags(), isEmpty);
    });
  });
}
