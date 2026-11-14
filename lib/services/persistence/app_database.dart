/// SQLite schema + migrations (DESIGN.md §16.4 "schema v4 as desktop plus the
/// `sessions` table (v5 migration on mobile)"; docs/port/
/// persistence-stats-settings.md §2.2 pins the desktop DDL byte for byte).
///
/// The four desktop tables (`user_stats`, `hand_history`, `range_guess`,
/// `decisions`) are recreated with the same column names and types so a
/// desktop `allin.db` opens here untouched and a backup round-trips; the
/// mobile-only `sessions` table (ended sessions shown in the Play lobby,
/// DESIGN §4.1) arrives as the v5 migration.
///
/// `PRAGMA user_version` carries the version, exactly as the desktop's
/// `migrate()` does. Every `CREATE` is `IF NOT EXISTS` and every `ALTER` is
/// wrapped in try/catch, so a half-applied earlier run is harmless.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'serialization.dart';

/// Opens (and migrates) the app database.
///
/// Inject [factory] on a desktop test host (`sqflite_common_ffi`'s
/// `databaseFactoryFfi`) and [path] to place the file; the app uses the
/// platform default (`<databases>/allin.db`).
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;

  /// The schema version the desktop app ships (`SCHEMA_VERSION = 4`).
  static const int desktopSchemaVersion = 4;

  /// The version this app writes: desktop v4 + `sessions` (v5) + the
  /// pre-flop VPIP/PFR flags, backfilled from stored hands (v6).
  static const int schemaVersion = 6;

  /// File name inside the platform databases directory.
  static const String defaultFileName = 'allin.db';

  final DatabaseFactory? _factory;
  final String? _path;
  Database? _db;
  Future<Database>? _opening;
  bool _retired = false;

  /// The open handle. Throws [StateError] before [open] has completed.
  Database get db {
    if (_retired) throw StateError('This app session has been reset.');
    final d = _db;
    if (d == null) {
      throw StateError('AppDatabase.open() has not been awaited yet.');
    }
    return d;
  }

  bool get isOpen => _db != null;

  /// Resolved database path (only after [open]).
  String? get path => _resolvedPath;
  String? _resolvedPath;

  /// Idempotent: a second call returns the same handle.
  Future<Database> open() {
    if (_retired) {
      return Future.error(StateError('This app session has been reset.'));
    }
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<Database> _open() async {
    final f = _factory ?? databaseFactory;
    final target = _path ?? p.join(await f.getDatabasesPath(), defaultFileName);
    _resolvedPath = target;
    final d = await f.openDatabase(
      target,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await createBaseSchema(db);
          await migrate(db, 0);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // The desktop runs the base DDL on every start; a file written by
          // an older build may be missing a whole table, not just a column.
          await createBaseSchema(db);
          await migrate(db, oldVersion);
        },
        // A file from a newer build keeps its data; unknown columns are simply
        // never read. Deleting the user's hands would be a worse outcome than
        // running one version behind.
        onDowngrade: (db, oldVersion, newVersion) async {},
      ),
    );
    _db = d;
    return d;
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
  }

  /// Permanently disconnects the old app scope before a full reset. SQLite
  /// closes after queued operations; captured handles cannot be used again.
  Future<void> retire() async {
    _retired = true;
    try {
      await _opening;
    } catch (_) {
      // A failed open has no handle to close.
    }
    await close();
  }

  AppDatabase freshHandle() => AppDatabase(factory: _factory, path: _path);

  /// Full factory reset, intentionally separate from the narrower stats
  /// replacement used by backup restore. Throws on failure so UI can retry.
  Future<void> eraseAllData() async {
    final database = await open();
    await database.transaction((txn) async {
      for (final table in const [
        'hand_history',
        'range_guess',
        'decisions',
        'sessions',
        'user_stats',
      ]) {
        await txn.delete(table);
      }
      await txn.delete('sqlite_sequence');
      await txn.insert('user_stats', {'id': 1});
    });
  }

  /// The v1 DDL — verbatim from the desktop `ensureBackend()`.
  static Future<void> createBaseSchema(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS user_stats (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  hands_played INTEGER NOT NULL DEFAULT 0,
  net_chips INTEGER NOT NULL DEFAULT 0,
  big_blind INTEGER NOT NULL DEFAULT 20
)''');
    await db.execute('INSERT OR IGNORE INTO user_stats (id) VALUES (1)');
    await db.execute('''
CREATE TABLE IF NOT EXISTS hand_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  n INTEGER, net_bb REAL, pot_bb REAL,
  showdown INTEGER, won INTEGER, archetypes TEXT, ts INTEGER
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS range_guess (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  accuracy REAL, archetype TEXT, street TEXT, ts INTEGER
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS decisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  verdict TEXT, action TEXT, equity REAL, pot_odds REAL,
  ev_bb REAL, street TEXT, archetype TEXT, ts INTEGER
)''');
  }

  /// Applies every migration newer than [from] (0 for a fresh file) and sets
  /// `PRAGMA user_version`. Mirrors the desktop `migrate()` step for step,
  /// with v5 added for mobile.
  static Future<void> migrate(DatabaseExecutor db, int from) async {
    if (from < 2) {
      await _tryExecute(
        db,
        'ALTER TABLE hand_history ADD COLUMN position TEXT',
      );
      await _tryExecute(
        db,
        'ALTER TABLE hand_history ADD COLUMN hand_json TEXT',
      );
      await _tryExecute(db, 'ALTER TABLE decisions ADD COLUMN position TEXT');
    }
    if (from < 3) {
      await _tryExecute(
        db,
        'ALTER TABLE hand_history ADD COLUMN saw_flop INTEGER',
      );
    }
    if (from < 4) {
      await _tryExecute(db, 'ALTER TABLE hand_history ADD COLUMN source TEXT');
    }
    if (from < 5) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NOT NULL,
  seats INTEGER NOT NULL,
  ante INTEGER NOT NULL DEFAULT 0,
  hands INTEGER NOT NULL DEFAULT 0,
  net_bb REAL NOT NULL DEFAULT 0,
  bb100 REAL NOT NULL DEFAULT 0,
  mistakes INTEGER NOT NULL DEFAULT 0,
  summary_json TEXT
)''');
    }
    if (from < 6) {
      await _tryExecute(db, 'ALTER TABLE hand_history ADD COLUMN vpip INTEGER');
      await _tryExecute(db, 'ALTER TABLE hand_history ADD COLUMN pfr INTEGER');
      await _backfillPreflopFlags(db);
    }
    await db.execute('PRAGMA user_version = $schemaVersion');
  }

  /// Fills `vpip` / `pfr` for hands played before the columns existed.
  ///
  /// Without this the Stats page shows a dash for VPIP, PFR and style no
  /// matter how many thousand hands are behind you, because every historical
  /// row is null — a new number that only starts counting today is not a
  /// statistic, it is an apology. The answer is already in `hand_json`: it
  /// holds the full action list, so what the hero did before the flop can be
  /// recovered exactly rather than estimated.
  static Future<void> _backfillPreflopFlags(DatabaseExecutor db) async {
    const chunk = 500;
    while (true) {
      final rows = await db.rawQuery(
        'SELECT id, hand_json FROM hand_history '
        'WHERE vpip IS NULL AND hand_json IS NOT NULL '
        'ORDER BY id LIMIT $chunk',
      );
      if (rows.isEmpty) break;
      final batch = db is Database ? db.batch() : null;
      for (final row in rows) {
        final raw = row['hand_json'];
        if (raw is! String) continue;
        final flags = preflopFlagsFromHandJson(raw);
        final values = [
          flags == null ? 0 : (flags.vpip ? 1 : 0),
          flags == null ? 0 : (flags.pfr ? 1 : 0),
          row['id'],
        ];
        const sql = 'UPDATE hand_history SET vpip = ?, pfr = ? WHERE id = ?';
        if (batch != null) {
          batch.rawUpdate(sql, values);
        } else {
          await db.rawUpdate(sql, values);
        }
      }
      await batch?.commit(noResult: true);
      // No OFFSET: every row read here is written below, so the WHERE clause
      // shrinks by exactly the rows just handled. A payload that will not
      // parse is still written (as 0/0), which is what stops this spinning
      // on a row it can never satisfy.
      if (rows.length < chunk) break;
    }
  }

  /// Reads `PRAGMA user_version` (0 on a fresh file).
  static Future<int> readUserVersion(DatabaseExecutor db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    return v is int ? v : int.tryParse('$v') ?? 0;
  }

  static Future<void> _tryExecute(DatabaseExecutor db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {
      // Column already present — the desktop swallows this too.
    }
  }
}
