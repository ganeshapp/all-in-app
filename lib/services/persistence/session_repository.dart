/// Session persistence (DESIGN.md §4.14 snapshot contract, §4.1 "Recent
/// sessions", §16.4 rows "Session snapshot" and "Ended sessions").
///
/// Two halves, both mobile additions (the desktop keeps a session in memory
/// and loses it on quit):
///
/// * **The live snapshot** under `allin.session.v1` — written at every hand
///   boundary and after every hero action, cleared on New session / End.
///   Resuming restores the exact table; if the table half cannot be decoded
///   the roster still resumes and the hand is abandoned, which is the
///   "that hand couldn't be restored" path of DESIGN §14.
/// * **Ended sessions** in the `sessions` table (schema v5) — the last ten
///   feed the lobby's Recent list and open the read-only summary (P10).
library;

import '../../engine/engine.dart' show Player, TableState;
import 'app_database.dart';
import 'key_value_store.dart';
import 'serialization.dart';
import 'settings_store.dart';
import 'table_options_store.dart';

/// Storage key *(mobile addition)*.
const String kSessionSnapshotKey = 'allin.session.v1';

/// A paused session, complete enough to deal the next hand.
class SessionSnapshot {
  const SessionSnapshot({
    required this.options,
    this.table,
    this.players = const [],
    this.session = const {},
    this.playSettings = AppSettings.defaults,
    this.reviewLog = const [],
    required this.savedAt,
    this.tableRestoreFailed = false,
  });

  /// Seats + ante the session was dealt with.
  final TableOptions options;

  /// The live table, or null when there was no hand in progress — or when the
  /// stored table could not be decoded ([tableRestoreFailed]).
  final TableState? table;

  /// The roster that outlives a hand: names, archetypes, dials, stacks and
  /// the HUD counters. Kept beside [table] so a session can still resume when
  /// the mid-hand state is unreadable.
  final List<Player> players;

  /// Session counters and hand history, owned by the play feature (hands,
  /// net, biggest win/loss, the `HHHand` list…). Free-form so this layer
  /// never has to move when that shape grows.
  final Map<String, Object?> session;

  /// The settings in force for the session (pace, speed, coach, auto-deal…).
  final AppSettings playSettings;

  /// The coach's review entries for the session, newest last. Free-form; the
  /// coach-note shape is [CoachNoteRecord].
  final List<Map<String, Object?>> reviewLog;

  /// Epoch ms of the write.
  final int savedAt;

  /// True when a snapshot existed but its `table` could not be decoded — the
  /// caller deals a fresh hand and shows the §4.14 caption.
  final bool tableRestoreFailed;

  SessionSnapshot copyWith({
    TableOptions? options,
    TableState? table,
    bool clearTable = false,
    List<Player>? players,
    Map<String, Object?>? session,
    AppSettings? playSettings,
    List<Map<String, Object?>>? reviewLog,
    int? savedAt,
  }) => SessionSnapshot(
    options: options ?? this.options,
    table: clearTable ? null : (table ?? this.table),
    players: players ?? this.players,
    session: session ?? this.session,
    playSettings: playSettings ?? this.playSettings,
    reviewLog: reviewLog ?? this.reviewLog,
    savedAt: savedAt ?? this.savedAt,
    tableRestoreFailed: tableRestoreFailed,
  );

  Map<String, Object?> toJson() => {
    'options': options.toJson(),
    'table': table == null ? null : tableStateToJson(table!),
    'players': players.map(playerToJson).toList(),
    'session': session,
    'playSettings': playSettings.toJson(),
    'reviewLog': reviewLog,
    'savedAt': savedAt,
  };

  /// Decodes a stored snapshot. The table is decoded defensively: a shape
  /// this build cannot read yields `table == null` and
  /// [tableRestoreFailed] `true` rather than losing the whole session.
  static SessionSnapshot fromJson(Map<String, Object?> j) {
    TableState? table;
    var failed = false;
    final rawTable = j['table'];
    if (rawTable is Map) {
      try {
        table = tableStateFromJson(rawTable.cast<String, Object?>());
      } catch (_) {
        failed = true;
      }
    }
    final players = <Player>[];
    for (final p in (j['players'] as List?) ?? const []) {
      if (p is! Map) continue;
      try {
        players.add(playerFromJson(p.cast<String, Object?>()));
      } catch (_) {
        // A roster entry this build cannot read is dropped; the session
        // still resumes with the seats it can decode.
      }
    }
    return SessionSnapshot(
      options: TableOptions.fromJson(j['options']),
      table: table,
      players: players,
      session:
          (j['session'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
      playSettings: AppSettings.fromJson(j['playSettings']),
      reviewLog: [
        for (final e in (j['reviewLog'] as List?) ?? const [])
          if (e is Map) e.cast<String, Object?>(),
      ],
      savedAt: (j['savedAt'] as num?)?.toInt() ?? 0,
      tableRestoreFailed: failed,
    );
  }
}

/// One finished session, as stored in the `sessions` table.
class SessionRecord {
  const SessionRecord({
    this.id,
    required this.startedAt,
    required this.endedAt,
    required this.seats,
    this.ante = 0,
    this.hands = 0,
    this.netBb = 0,
    this.bb100 = 0,
    this.mistakes = 0,
    this.summary,
  });

  /// Row id (null before insert).
  final int? id;
  final int startedAt;
  final int endedAt;
  final int seats;
  final int ante;
  final int hands;

  /// Hero net for the session, in big blinds.
  final double netBb;

  /// Win rate for the session.
  final double bb100;

  /// Coach-flagged decisions this session.
  final int mistakes;

  /// The P10 summary payload (debrief numbers + the session's hands).
  final Map<String, Object?>? summary;

  SessionRecord copyWith({int? id}) => SessionRecord(
    id: id ?? this.id,
    startedAt: startedAt,
    endedAt: endedAt,
    seats: seats,
    ante: ante,
    hands: hands,
    netBb: netBb,
    bb100: bb100,
    mistakes: mistakes,
    summary: summary,
  );
}

class SessionRepository {
  SessionRepository({
    required AppDatabase database,
    required KeyValueStore store,
  }) : _database = database,
       _store = store;

  /// Ended sessions listed in the lobby.
  static const int recentSessionLimit = 10;

  final AppDatabase _database;
  final KeyValueStore _store;

  /* ------------------------------- snapshot ------------------------------ */

  /// True when a paused session exists (the lobby's Resume card).
  bool get hasSnapshot => _store.getString(kSessionSnapshotKey) != null;

  Future<bool> saveSnapshot(SessionSnapshot snapshot) =>
      _store.setJson(kSessionSnapshotKey, snapshot.toJson());

  /// The paused session, or null when there is none (or it is unreadable).
  SessionSnapshot? loadSnapshot() {
    final raw = _store.getJson(kSessionSnapshotKey);
    if (raw is! Map) return null;
    try {
      return SessionSnapshot.fromJson(raw.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  /// New session / End session.
  Future<bool> clearSnapshot() => _store.remove(kSessionSnapshotKey);

  /* ---------------------------- ended sessions --------------------------- */

  /// Appends an ended session. Returns its row id, or null when the write
  /// failed (persistence is never allowed to break ending a session).
  Future<int?> recordEndedSession(SessionRecord record) async {
    try {
      await _database.open();
      return await _database.db.insert('sessions', _toRow(record));
    } catch (_) {
      return null;
    }
  }

  /// The most recent ended sessions, newest first.
  Future<List<SessionRecord>> recentSessions({
    int limit = recentSessionLimit,
  }) async {
    try {
      await _database.open();
      final rows = await _database.db.query(
        'sessions',
        orderBy: 'ended_at DESC, id DESC',
        limit: limit,
      );
      return rows.map(_fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<SessionRecord?> sessionById(int id) async {
    try {
      await _database.open();
      final rows = await _database.db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : _fromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Drops every ended session. Not part of the desktop's `resetStats`
  /// (it has no such table) — the Reset flow calls this alongside it so the
  /// lobby's Recent list matches the erased stats.
  Future<void> clearEndedSessions() async {
    try {
      await _database.open();
      await _database.db.delete('sessions');
    } catch (_) {
      // Never throws: reset is a user-facing action.
    }
  }

  static Map<String, Object?> _toRow(SessionRecord r) => {
    'started_at': r.startedAt,
    'ended_at': r.endedAt,
    'seats': r.seats,
    'ante': r.ante,
    'hands': r.hands,
    'net_bb': r.netBb,
    'bb100': r.bb100,
    'mistakes': r.mistakes,
    'summary_json': r.summary == null ? null : encodeJsonMap(r.summary!),
  };

  static SessionRecord _fromRow(Map<String, Object?> row) => SessionRecord(
    id: (row['id'] as num?)?.toInt(),
    startedAt: (row['started_at'] as num?)?.toInt() ?? 0,
    endedAt: (row['ended_at'] as num?)?.toInt() ?? 0,
    seats: (row['seats'] as num?)?.toInt() ?? 6,
    ante: (row['ante'] as num?)?.toInt() ?? 0,
    hands: (row['hands'] as num?)?.toInt() ?? 0,
    netBb: (row['net_bb'] as num?)?.toDouble() ?? 0,
    bb100: (row['bb100'] as num?)?.toDouble() ?? 0,
    mistakes: (row['mistakes'] as num?)?.toInt() ?? 0,
    summary: decodeJsonMap(row['summary_json']),
  );
}
