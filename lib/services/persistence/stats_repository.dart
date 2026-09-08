/// Lifetime play statistics (docs/port/persistence-stats-settings.md §4) —
/// the Dart port of the desktop `src/db/stats.ts`, function for function.
///
/// SQLite is the primary backend; a key-value fallback mirrors the desktop's
/// `localStorage` shapes (`allin.stats.v1`, `allin.hands.v1`) so a single
/// failing statement degrades instead of crashing (DESIGN.md §14, row
/// "Storage · quota / DB error"). Once a SQL call fails the repository stays
/// on the fallback for the rest of the process, exactly like the desktop.
///
/// Nothing here throws: every method is user-facing.
library;

import 'dart:convert';

import '../../engine/engine.dart' show DecisionRecord, jsRound;
import 'app_database.dart';
import 'key_value_store.dart';
import 'records.dart';
import 'serialization.dart' show archetypeOrNull, positionOrNull;

/// Which storage the repository is currently using.
enum StatsBackend { sqlite, local }

/// Diagnostics for a debug screen: the live backend and the last error.
class BackendInfo {
  const BackendInfo({required this.backend, this.lastError});
  final StatsBackend? backend;

  /// `"<context>: <error>"`, or null when nothing has failed.
  final String? lastError;
}

class StatsRepository {
  StatsRepository({required AppDatabase database, required KeyValueStore store})
    : _database = database,
      _store = store;

  /// Rows loaded per table and the local array cap (`HISTORY_CAP`).
  static const int historyCap = StatsSnapshot.historyCap;

  /// Replayable hands kept in the key-value fallback (`LS_HANDS_CAP`).
  static const int localHandsCap = 100;

  /// Hands included in a backup taken from SQLite.
  static const int backupHandLimit = 100000;

  /// Fallback snapshot key (desktop `LS_KEY`).
  static const String statsKey = 'allin.stats.v1';

  /// Fallback replayable-hand key (desktop `LS_HANDS_KEY`).
  static const String handsKey = 'allin.hands.v1';

  /// `hand_history.source` for a hand-history import (desktop value).
  static const String sourceImport = 'import';

  /// `hand_history.source` for a hand payload written back by a backup
  /// restore *(mobile addition)*. Like `'import'` it keeps the row out of
  /// [loadStats] — the backup's own `snapshot.history` rows already carry the
  /// statistics, so counting the payloads again would double every number.
  /// Whether such a hand was originally played or imported is read from the
  /// payload's `imported` flag, exactly as the Stats list does.
  static const String sourceRestore = 'restore';

  final AppDatabase _database;
  final KeyValueStore _store;

  StatsBackend? _backend;
  String? _lastError;

  StatsBackend? get backend => _backend;
  String? get lastError => _lastError;
  BackendInfo backendInfo() =>
      BackendInfo(backend: _backend, lastError: _lastError);

  /// Opens SQLite once; any failure pins the fallback for the process.
  Future<StatsBackend> ensureBackend() async {
    final decided = _backend;
    if (decided != null) return decided;
    try {
      await _database.open();
      return _backend = StatsBackend.sqlite;
    } catch (e) {
      _noteError('SQLite unavailable, using localStorage', e);
      return _backend = StatsBackend.local;
    }
  }

  void _noteError(String context, Object e) {
    _lastError = '$context: $e';
  }

  void _fallBack(String context, Object e) {
    _noteError(context, e);
    _backend = StatsBackend.local;
  }

  /* -------------------------------- reads -------------------------------- */

  /// The lifetime counters plus the last [historyCap] rows of each table.
  /// Imported hands are excluded by `source IS NULL`; `hand_json` is not read.
  Future<StatsSnapshot> loadStats() async {
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        final db = _database.db;
        final stats = await db.query(
          'user_stats',
          columns: ['hands_played', 'net_chips', 'big_blind'],
          where: 'id = 1',
        );
        final head = stats.isEmpty ? const <String, Object?>{} : stats.first;

        final hands = await db.rawQuery(
          'SELECT n, net_bb, pot_bb, showdown, won, archetypes, position, '
          'saw_flop, ts FROM hand_history WHERE source IS NULL '
          'ORDER BY id DESC LIMIT $historyCap',
        );
        final guesses = await db.rawQuery(
          'SELECT accuracy, archetype, street, ts FROM range_guess '
          'ORDER BY id DESC LIMIT $historyCap',
        );
        final decisions = await db.rawQuery(
          'SELECT verdict, action, equity, pot_odds, ev_bb, street, archetype, '
          'position, ts FROM decisions ORDER BY id DESC LIMIT $historyCap',
        );

        return StatsSnapshot(
          handsPlayed: (head['hands_played'] as num?)?.toInt() ?? 0,
          netChips: (head['net_chips'] as num?)?.toInt() ?? 0,
          bigBlind:
              (head['big_blind'] as num?)?.toInt() ??
              StatsSnapshot.defaultBigBlind,
          history: hands.reversed.map(_handFromRow).toList(),
          guesses: guesses.reversed.map(_guessFromRow).toList(),
          decisions: decisions.reversed.map(_decisionFromRow).toList(),
        );
      } catch (e) {
        _fallBack('SQLite read failed, falling back', e);
      }
    }
    return _readLocal();
  }

  /// Replayable `hand_json` payloads, most recent first. Played *and*
  /// imported hands (the desktop applies no `source` filter here).
  ///
  /// A SQL failure here does **not** switch the backend permanently — it
  /// falls through to the fallback for this call only.
  Future<List<String>> loadRecentHands({int limit = 50}) async {
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        final rows = await _database.db.rawQuery(
          'SELECT hand_json FROM hand_history WHERE hand_json IS NOT NULL '
          'ORDER BY id DESC LIMIT ?',
          [limit],
        );
        return [
          for (final r in rows)
            if (r['hand_json'] case final String s) s,
        ];
      } catch (e) {
        _noteError('SQLite hand read failed', e);
      }
    }
    final hands = _readLocalHands();
    return hands.length <= limit ? hands : hands.sublist(0, limit);
  }

  /* -------------------------------- writes ------------------------------- */

  /// Appends one played hand and moves the lifetime counters.
  Future<void> persistHand(HandRecord rec, num netChipsDelta) async {
    final delta = jsRound(netChipsDelta.toDouble()).toInt();
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        final db = _database.db;
        await db.rawInsert(
          'INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, '
          'archetypes, position, saw_flop, hand_json, ts) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            rec.n,
            rec.netBb,
            rec.potBb,
            rec.showdown ? 1 : 0,
            rec.won ? 1 : 0,
            jsonEncode(rec.archetypes.map((a) => a.label).toList()),
            rec.position?.label,
            rec.sawFlop == null ? null : (rec.sawFlop! ? 1 : 0),
            rec.handJson,
            rec.ts,
          ],
        );
        await db.rawUpdate(
          'UPDATE user_stats SET hands_played = hands_played + 1, '
          'net_chips = net_chips + ? WHERE id = 1',
          [delta],
        );
        return;
      } catch (e) {
        _fallBack('SQLite write failed, falling back', e);
      }
    }
    final s = _readLocal();
    await _writeLocal(
      s.copyWith(
        handsPlayed: s.handsPlayed + 1,
        netChips: s.netChips + delta,
        history: _capped([...s.history, rec.copyWith(clearHandJson: true)]),
      ),
    );
    final handJson = rec.handJson;
    if (handJson != null) {
      final hands = [handJson, ..._readLocalHands()];
      await _writeLocalHands(hands);
    }
  }

  Future<void> persistGuess(GuessRecord rec) async {
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        await _database.db.rawInsert(
          'INSERT INTO range_guess (accuracy, archetype, street, ts) '
          'VALUES (?, ?, ?, ?)',
          [rec.accuracy, rec.archetype?.label, rec.street, rec.ts],
        );
        return;
      } catch (e) {
        _fallBack('SQLite write failed, falling back', e);
      }
    }
    final s = _readLocal();
    await _writeLocal(s.copyWith(guesses: _capped([...s.guesses, rec])));
  }

  Future<void> persistDecision(DecisionRecord rec) async {
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        await _database.db.rawInsert(
          'INSERT INTO decisions (verdict, action, equity, pot_odds, ev_bb, '
          'street, archetype, position, ts) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            rec.verdict,
            rec.action,
            rec.equity,
            rec.potOdds,
            rec.evBb,
            rec.street,
            rec.villainArchetype,
            rec.position,
            rec.ts,
          ],
        );
        return;
      } catch (e) {
        _fallBack('SQLite write failed, falling back', e);
      }
    }
    final s = _readLocal();
    await _writeLocal(s.copyWith(decisions: _capped([...s.decisions, rec])));
  }

  /// Stores imported hands as inert `source = 'import'` rows: replayable,
  /// never counted in `user_stats`, never returned by [loadStats].
  /// Returns how many were written (0 only if the fallback write failed).
  Future<int> persistImportedHands(List<String> handJsons) async =>
      _persistHandPayloads(handJsons, sourceImport);

  /// Shared by [persistImportedHands] and [restore]: writes replayable rows
  /// that never touch `user_stats`.
  Future<int> _persistHandPayloads(
    List<String> handJsons,
    String source,
  ) async {
    if (handJsons.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        final batch = _database.db.batch();
        for (final json in handJsons) {
          batch.rawInsert(
            'INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, '
            'archetypes, position, saw_flop, hand_json, source, ts) '
            "VALUES (0, 0, 0, 0, 0, '[]', NULL, NULL, ?, ?, ?)",
            [json, source, now],
          );
        }
        await batch.commit(noResult: true);
        return handJsons.length;
      } catch (e) {
        _fallBack('SQLite import write failed', e);
      }
    }
    final ok = await _writeLocalHands([...handJsons, ..._readLocalHands()]);
    return ok ? handJsons.length : 0;
  }

  /// Deletes every hand, guess and decision and zeroes the lifetime counters.
  /// `big_blind` survives, and so do notes, tags, leaks, review cards, goals,
  /// study progress, quiz results, settings, the drill rating, table options
  /// and the onboarding flag (DESIGN §7.10).
  Future<void> resetStats() async {
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        final db = _database.db;
        await db.delete('hand_history');
        await db.delete('range_guess');
        await db.delete('decisions');
        await db.rawUpdate(
          'UPDATE user_stats SET hands_played = 0, net_chips = 0 WHERE id = 1',
        );
        return;
      } catch (e) {
        _fallBack('SQLite reset failed, falling back', e);
      }
    }
    await _writeLocal(StatsSnapshot.empty);
    await _store.remove(handsKey);
  }

  /* -------------------------------- backup ------------------------------- */

  /// The desktop backup document, compact JSON:
  /// `{ exportedAt, backend, snapshot, hands }`.
  ///
  /// [BackupService] wraps this with the mobile additions; this method stays
  /// desktop-shaped so an All-In desktop backup and this one are the same
  /// document.
  Future<String> exportBackup() async {
    final b = await ensureBackend();
    return jsonEncode({
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'backend': b.name,
      'snapshot': (await loadStats()).toJson(),
      'hands': await loadRecentHands(
        limit: b == StatsBackend.sqlite ? backupHandLimit : localHandsCap,
      ),
    });
  }

  /// Replaces the stats tables with [snapshot] and [handJsons] (backup
  /// restore, DESIGN §7.9). Returns the number of hands written.
  Future<int> restore({
    required StatsSnapshot snapshot,
    List<String> handJsons = const [],
  }) async {
    await resetStats();
    if (await ensureBackend() == StatsBackend.sqlite) {
      try {
        final db = _database.db;
        final batch = db.batch();
        for (final h in snapshot.history) {
          batch.rawInsert(
            'INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, '
            'archetypes, position, saw_flop, hand_json, ts) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)',
            [
              h.n,
              h.netBb,
              h.potBb,
              h.showdown ? 1 : 0,
              h.won ? 1 : 0,
              jsonEncode(h.archetypes.map((a) => a.label).toList()),
              h.position?.label,
              h.sawFlop == null ? null : (h.sawFlop! ? 1 : 0),
              h.ts,
            ],
          );
        }
        for (final g in snapshot.guesses) {
          batch.rawInsert(
            'INSERT INTO range_guess (accuracy, archetype, street, ts) '
            'VALUES (?, ?, ?, ?)',
            [g.accuracy, g.archetype?.label, g.street, g.ts],
          );
        }
        for (final d in snapshot.decisions) {
          batch.rawInsert(
            'INSERT INTO decisions (verdict, action, equity, pot_odds, ev_bb, '
            'street, archetype, position, ts) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              d.verdict,
              d.action,
              d.equity,
              d.potOdds,
              d.evBb,
              d.street,
              d.villainArchetype,
              d.position,
              d.ts,
            ],
          );
        }
        batch.rawUpdate(
          'UPDATE user_stats SET hands_played = ?, net_chips = ? WHERE id = 1',
          [snapshot.handsPlayed, snapshot.netChips],
        );
        await batch.commit(noResult: true);
        // Hands come back as replayable rows; whether a hand was played or
        // imported is already inside its own payload (`imported: true`).
        return await _persistHandPayloads(
          handJsons.reversed.toList(),
          sourceRestore,
        );
      } catch (e) {
        _fallBack('SQLite restore failed, falling back', e);
      }
    }
    await _writeLocal(
      snapshot.copyWith(
        history: _capped(snapshot.history),
        guesses: _capped(snapshot.guesses),
        decisions: _capped(snapshot.decisions),
      ),
    );
    final ok = await _writeLocalHands(handJsons);
    return ok ? handJsons.take(localHandsCap).length : 0;
  }

  /* -------------------------------- helpers ------------------------------ */

  static List<T> _capped<T>(List<T> xs) =>
      xs.length <= historyCap ? xs : xs.sublist(xs.length - historyCap);

  StatsSnapshot _readLocal() =>
      StatsSnapshot.fromJson(_store.getJson(statsKey));

  Future<bool> _writeLocal(StatsSnapshot s) =>
      _store.setJson(statsKey, s.toJson());

  List<String> _readLocalHands() => [
    for (final h in _store.getJsonList(handsKey))
      if (h is String) h,
  ];

  Future<bool> _writeLocalHands(List<String> hands) => _store.setJson(
    handsKey,
    hands.length <= localHandsCap ? hands : hands.sublist(0, localHandsCap),
  );

  static HandRecord _handFromRow(Map<String, Object?> r) => HandRecord(
    n: (r['n'] as num?)?.toInt() ?? 0,
    netBb: (r['net_bb'] as num?)?.toDouble() ?? 0,
    potBb: (r['pot_bb'] as num?)?.toDouble() ?? 0,
    showdown: _truthy(r['showdown']),
    won: _truthy(r['won']),
    archetypes: HandRecord.decodeArchetypes(_decodeJson(r['archetypes'])),
    position: positionOrNull(r['position']),
    sawFlop: r['saw_flop'] == null ? null : _truthy(r['saw_flop']),
    ts: (r['ts'] as num?)?.toInt() ?? 0,
  );

  static GuessRecord _guessFromRow(Map<String, Object?> r) => GuessRecord(
    accuracy: (r['accuracy'] as num?)?.toDouble() ?? 0,
    archetype: archetypeOrNull(r['archetype']),
    street: '${r['street'] ?? 'preflop'}',
    ts: (r['ts'] as num?)?.toInt() ?? 0,
  );

  static DecisionRecord _decisionFromRow(Map<String, Object?> r) =>
      DecisionRecord(
        verdict: (r['verdict'] as String?) ?? 'ok',
        action: (r['action'] as String?) ?? 'call',
        equity: (r['equity'] as num?)?.toDouble() ?? 0,
        potOdds: (r['pot_odds'] as num?)?.toDouble() ?? 0,
        evBb: (r['ev_bb'] as num?)?.toDouble() ?? 0,
        street: '${r['street'] ?? 'preflop'}',
        villainArchetype: _nonEmpty(r['archetype']),
        position: _nonEmpty(r['position']),
        ts: (r['ts'] as num?)?.toInt() ?? 0,
      );

  static bool _truthy(Object? v) =>
      v == 1 || v == true || (v is num && v != 0) || v == '1';

  static String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;

  static Object? _decodeJson(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
