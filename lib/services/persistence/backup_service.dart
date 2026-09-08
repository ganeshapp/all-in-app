/// Backup export and restore (DESIGN.md §7.9 "Back up all data (.json)" /
/// "Restore from backup…", §14 rows "Backup restore …";
/// docs/port/persistence-stats-settings.md §4 `exportBackup`).
///
/// The document is the desktop's — `{ exportedAt, backend, snapshot, hands }`
/// — plus two mobile keys, `schemaVersion` and `sessions`. A desktop backup
/// therefore restores here unchanged (it simply has no `sessions`, and its
/// missing `schemaVersion` reads as the desktop's v4), and a backup written
/// here still opens as a plain desktop document.
///
/// Restore replaces stats, decisions, reads, hands and ended sessions.
/// Notes, tags, leaks, review cards, goals, study progress, quiz results and
/// settings are untouched — the same line `resetStats` draws (DESIGN §7.9).
library;

import 'dart:convert';

import 'app_database.dart';
import 'records.dart';
import 'session_repository.dart';
import 'stats_repository.dart';

/// Why a file cannot be restored.
enum BackupProblem {
  /// The bytes parsed but are not an All-In backup.
  notABackup,

  /// Written by a newer build than this one reads.
  newerSchema,
}

/// What the X3 dialog needs to describe a picked file before touching
/// anything.
class BackupPreview {
  const BackupPreview({
    this.exportedAt,
    this.schemaVersion,
    this.handsPlayed = 0,
    this.handCount = 0,
    this.sessionCount = 0,
    this.problem,
  });

  /// Epoch ms the backup was taken ("the backup from {date}").
  final int? exportedAt;

  /// The schema the backup was written against (v4 for a desktop file).
  final int? schemaVersion;

  /// Lifetime hands in the backup.
  final int handsPlayed;

  /// Replayable hand payloads in the backup ("({hands} hands)").
  final int handCount;

  /// Ended sessions in the backup (0 for a desktop file).
  final int sessionCount;

  /// Non-null when the file cannot be restored.
  final BackupProblem? problem;

  bool get isRestorable => problem == null;
}

/// Counts to report after a restore.
class BackupRestoreResult {
  const BackupRestoreResult({
    this.hands = 0,
    this.guesses = 0,
    this.decisions = 0,
    this.handPayloads = 0,
    this.sessions = 0,
    this.problem,
  });

  /// Rows written to `hand_history` from `snapshot.history`.
  final int hands;
  final int guesses;
  final int decisions;

  /// Replayable payloads written back.
  final int handPayloads;
  final int sessions;

  /// Non-null when nothing was written.
  final BackupProblem? problem;

  bool get ok => problem == null;
}

class BackupService {
  BackupService({
    required StatsRepository stats,
    required SessionRepository sessions,
  }) : _stats = stats,
       _sessions = sessions;

  /// The schema this build reads and writes.
  static const int schemaVersion = AppDatabase.schemaVersion;

  /// A desktop file carries no `schemaVersion`; it is v4 by definition.
  static const int assumedDesktopSchemaVersion =
      AppDatabase.desktopSchemaVersion;

  final StatsRepository _stats;
  final SessionRepository _sessions;

  /// `allin-backup-YYYY-MM-DD.json` (DESIGN §7.9; local date, like the
  /// desktop's `toISOString().slice(0, 10)` in effect).
  static String fileName({DateTime? now}) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'allin-backup-${d.year}-$m-$day.json';
  }

  /// The whole document as compact JSON.
  Future<String> export({int? nowMs}) async {
    final backend = await _stats.ensureBackend();
    final snapshot = await _stats.loadStats();
    final hands = await _stats.loadRecentHands(
      limit:
          backend == StatsBackend.sqlite
              ? StatsRepository.backupHandLimit
              : StatsRepository.localHandsCap,
    );
    final sessions = await _sessions.recentSessions(limit: 1000);
    return jsonEncode({
      'exportedAt': nowMs ?? DateTime.now().millisecondsSinceEpoch,
      'backend': backend.name,
      'schemaVersion': schemaVersion,
      'snapshot': snapshot.toJson(),
      'hands': hands,
      'sessions': [
        for (final s in sessions)
          {
            'startedAt': s.startedAt,
            'endedAt': s.endedAt,
            'seats': s.seats,
            'ante': s.ante,
            'hands': s.hands,
            'netBb': s.netBb,
            'bb100': s.bb100,
            'mistakes': s.mistakes,
            'summary': s.summary,
          },
      ],
    });
  }

  /// Validates [json] without touching storage — the X3 dialog's data.
  BackupPreview inspect(String json) {
    final doc = _parse(json);
    if (doc == null) {
      return const BackupPreview(problem: BackupProblem.notABackup);
    }
    final version =
        (doc['schemaVersion'] as num?)?.toInt() ?? assumedDesktopSchemaVersion;
    final snapshot = StatsSnapshot.fromJson(doc['snapshot']);
    final preview = BackupPreview(
      exportedAt: (doc['exportedAt'] as num?)?.toInt(),
      schemaVersion: version,
      handsPlayed: snapshot.handsPlayed,
      handCount: _handPayloads(doc).length,
      sessionCount: ((doc['sessions'] as List?) ?? const []).length,
      problem: version > schemaVersion ? BackupProblem.newerSchema : null,
    );
    return preview;
  }

  /// Replaces stats, hands and ended sessions with the backup's contents.
  /// Refuses — writing nothing — when [inspect] reports a problem.
  Future<BackupRestoreResult> restore(String json) async {
    final preview = inspect(json);
    if (!preview.isRestorable) {
      return BackupRestoreResult(problem: preview.problem);
    }
    final doc = _parse(json);
    if (doc == null) {
      return const BackupRestoreResult(problem: BackupProblem.notABackup);
    }

    final snapshot = StatsSnapshot.fromJson(doc['snapshot']);
    final payloads = _handPayloads(doc);
    final written = await _stats.restore(
      snapshot: snapshot,
      handJsons: payloads,
    );

    await _sessions.clearEndedSessions();
    var sessions = 0;
    for (final raw in (doc['sessions'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final s = raw.cast<String, Object?>();
      final id = await _sessions.recordEndedSession(
        SessionRecord(
          startedAt: (s['startedAt'] as num?)?.toInt() ?? 0,
          endedAt: (s['endedAt'] as num?)?.toInt() ?? 0,
          seats: (s['seats'] as num?)?.toInt() ?? 6,
          ante: (s['ante'] as num?)?.toInt() ?? 0,
          hands: (s['hands'] as num?)?.toInt() ?? 0,
          netBb: (s['netBb'] as num?)?.toDouble() ?? 0,
          bb100: (s['bb100'] as num?)?.toDouble() ?? 0,
          mistakes: (s['mistakes'] as num?)?.toInt() ?? 0,
          summary: (s['summary'] as Map?)?.cast<String, Object?>(),
        ),
      );
      if (id != null) sessions++;
    }

    return BackupRestoreResult(
      hands: snapshot.history.length,
      guesses: snapshot.guesses.length,
      decisions: snapshot.decisions.length,
      handPayloads: written,
      sessions: sessions,
    );
  }

  /// A document is a backup when it parses to a map carrying a `snapshot`
  /// object — the one key every version has had.
  static Map<String, Object?>? _parse(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final doc = decoded.cast<String, Object?>();
    return doc['snapshot'] is Map ? doc : null;
  }

  /// `hands` as JSON strings. A hand-edited backup may hold objects instead;
  /// those are re-encoded rather than dropped.
  static List<String> _handPayloads(Map<String, Object?> doc) {
    final out = <String>[];
    for (final h in (doc['hands'] as List?) ?? const []) {
      if (h is String) {
        out.add(h);
      } else if (h is Map) {
        out.add(jsonEncode(h));
      }
    }
    return out;
  }
}
