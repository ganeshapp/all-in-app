/// Schema and migration tests for `lib/services/persistence/app_database.dart`
/// (docs/port/persistence-stats-settings.md §2.2; DESIGN.md §16.4).
///
/// Runs on a desktop host through `sqflite_common_ffi`, so `flutter test`
/// needs no device.
library;

import 'dart:io';

import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('allin_db_test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  String pathFor(String name) => '${dir.path}/$name';

  Future<Set<String>> tables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return {for (final r in rows) '${r['name']}'};
  }

  Future<Set<String>> columns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return {for (final r in rows) '${r['name']}'};
  }

  group('fresh database', () {
    test('creates every table at user_version 5', () async {
      final app = AppDatabase(factory: factory, path: pathFor('fresh.db'));
      final db = await app.open();

      expect(await AppDatabase.readUserVersion(db), AppDatabase.schemaVersion);
      expect(
        await tables(db),
        containsAll(<String>{
          'user_stats',
          'hand_history',
          'range_guess',
          'decisions',
          'sessions',
        }),
      );
      await app.close();
    });

    test('hand_history carries every desktop column, v1 through v4', () async {
      final app = AppDatabase(factory: factory, path: pathFor('cols.db'));
      final db = await app.open();

      expect(
        await columns(db, 'hand_history'),
        containsAll(<String>{
          'id',
          'n',
          'net_bb',
          'pot_bb',
          'showdown',
          'won',
          'archetypes',
          'ts',
          'position', // v2
          'hand_json', // v2
          'saw_flop', // v3
          'source', // v4
        }),
      );
      expect(await columns(db, 'decisions'), contains('position'));
      await app.close();
    });

    test('seeds the single user_stats row with the desktop defaults', () async {
      final app = AppDatabase(factory: factory, path: pathFor('seed.db'));
      final db = await app.open();

      final rows = await db.query('user_stats');
      expect(rows, hasLength(1));
      expect(rows.first['id'], 1);
      expect(rows.first['hands_played'], 0);
      expect(rows.first['net_chips'], 0);
      expect(rows.first['big_blind'], 20);
      await app.close();
    });

    test('open() is idempotent', () async {
      final app = AppDatabase(factory: factory, path: pathFor('twice.db'));
      final a = await app.open();
      final b = await app.open();
      expect(identical(a, b), isTrue);
      await app.close();
    });
  });

  group('migrations', () {
    /// Writes a database at [version] with only the DDL that version had.
    Future<void> seedOldSchema(String path, int version) async {
      final db = await factory.openDatabase(path);
      await AppDatabase.createBaseSchema(db);
      if (version >= 2) {
        await db.execute('ALTER TABLE hand_history ADD COLUMN position TEXT');
        await db.execute('ALTER TABLE hand_history ADD COLUMN hand_json TEXT');
        await db.execute('ALTER TABLE decisions ADD COLUMN position TEXT');
      }
      if (version >= 3) {
        await db.execute(
          'ALTER TABLE hand_history ADD COLUMN saw_flop INTEGER',
        );
      }
      if (version >= 4) {
        await db.execute('ALTER TABLE hand_history ADD COLUMN source TEXT');
      }
      await db.execute('PRAGMA user_version = $version');
      await db.close();
    }

    for (final from in [1, 2, 3, 4]) {
      test(
        'v$from → v5 adds the missing columns and the sessions table',
        () async {
          final path = pathFor('v$from.db');
          await seedOldSchema(path, from);

          final app = AppDatabase(factory: factory, path: path);
          final db = await app.open();

          expect(
            await AppDatabase.readUserVersion(db),
            AppDatabase.schemaVersion,
          );
          expect(await tables(db), contains('sessions'));
          expect(
            await columns(db, 'hand_history'),
            containsAll(<String>{
              'position',
              'hand_json',
              'saw_flop',
              'source',
            }),
          );
          expect(await columns(db, 'decisions'), contains('position'));
          await app.close();
        },
      );
    }

    test('a desktop v4 file keeps its rows', () async {
      final path = pathFor('desktop.db');
      await seedOldSchema(path, 4);
      final raw = await factory.openDatabase(path);
      await raw.rawInsert(
        'INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, '
        "archetypes, position, saw_flop, ts) VALUES (7, 2.5, 9.0, 1, 1, "
        "'[\"TAG\"]', 'BTN', 1, 1700000000000)",
      );
      await raw.rawUpdate(
        'UPDATE user_stats SET hands_played = 41, net_chips = 250 WHERE id = 1',
      );
      await raw.close();

      final app = AppDatabase(factory: factory, path: path);
      final db = await app.open();

      final stats = (await db.query('user_stats')).first;
      expect(stats['hands_played'], 41);
      expect(stats['net_chips'], 250);
      final hand = (await db.query('hand_history')).single;
      expect(hand['n'], 7);
      expect(hand['position'], 'BTN');
      expect(hand['source'], isNull);
      await app.close();
    });

    test('a v0 file whose tables already exist is not disturbed', () async {
      final path = pathFor('v0.db');
      final raw = await factory.openDatabase(path);
      await AppDatabase.createBaseSchema(raw);
      await raw.rawInsert(
        "INSERT INTO range_guess (accuracy, archetype, street, ts) "
        "VALUES (0.5, 'Nit', 'preflop', 1)",
      );
      await raw.close();

      final app = AppDatabase(factory: factory, path: path);
      final db = await app.open();

      expect(await AppDatabase.readUserVersion(db), AppDatabase.schemaVersion);
      expect((await db.query('range_guess')), hasLength(1));
      await app.close();
    });
  });

  test('sessions has the DESIGN §16.4 columns', () async {
    final app = AppDatabase(factory: factory, path: pathFor('sessions.db'));
    final db = await app.open();

    expect(
      await columns(db, 'sessions'),
      containsAll(<String>{
        'started_at',
        'ended_at',
        'seats',
        'ante',
        'hands',
        'net_bb',
        'bb100',
        'mistakes',
        'summary_json',
      }),
    );
    await app.close();
  });
}
