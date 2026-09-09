/// Providers X0 / X1 own (DESIGN.md §9, §7.9, §7.10).
///
/// The settings *object* and the theme live in `app/providers/app_providers.dart`
/// — the shell reads them on every frame, so they cannot live behind a feature
/// import. What is here is everything only Settings and About need: the app
/// version, the external-link opener, and the three Data actions (back up,
/// restore, reset) as one injectable service.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/services/persistence/backup_service.dart';
import 'package:allin/services/share_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The build's version, read once (§9 "Version {x.y.z}", §15 About hero).
///
/// `package_info_plus` needs a platform channel; when there is none (a widget
/// test, a headless run) the future completes with [AppVersion.unknown]
/// instead of throwing — a missing version number must never blank the page.
class AppVersion {
  const AppVersion({required this.version, required this.build});

  /// `1.2.0`, or "—" when the platform could not answer.
  final String version;

  /// `+1` build number, empty when unknown.
  final String build;

  static const AppVersion unknown = AppVersion(version: '—', build: '');

  bool get isKnown => version != '—';

  /// "Version 1.2.0" — the pill and the Settings row share this.
  String get label => 'Version $version';
}

final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return AppVersion.unknown;
    return AppVersion(version: info.version, build: info.buildNumber);
  } catch (_) {
    return AppVersion.unknown;
  }
});

/// Opens an external URL. Injectable so About's links are testable without a
/// browser (§16.6: `url_launcher`, external application mode).
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _launchExternal(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

final urlOpenerProvider = Provider<UrlOpener>((ref) => _launchExternal);

/// What a Data action ended up doing, so the screen can show one line.
enum DataActionStatus {
  /// Finished; [DataActionResult.message] is the confirmation.
  ok,

  /// The user backed out (cancelled the picker or the share sheet).
  cancelled,

  /// Nothing was written; [DataActionResult.message] says why.
  failed,
}

class DataActionResult {
  const DataActionResult(this.status, this.message);

  const DataActionResult.ok(String message)
    : this(DataActionStatus.ok, message);
  const DataActionResult.cancelled() : this(DataActionStatus.cancelled, '');
  const DataActionResult.failed(String message)
    : this(DataActionStatus.failed, message);

  final DataActionStatus status;

  /// User-facing, already in the §7.9/§14 wording.
  final String message;

  bool get isOk => status == DataActionStatus.ok;
}

/// The three Data actions of §7.9 / §7.10, with every §14 failure mapped to
/// its own sentence. The screen decides which dialog to show; this class never
/// touches the widget tree.
class SettingsDataService {
  SettingsDataService(this._ref);

  final Ref _ref;

  /// §14: bytes that could not be read at all — deliberately distinct from
  /// "that file isn't an All-In backup".
  static const String unreadableFile =
      "That file couldn't be read. If it came from a cloud drive, download it "
      'to this phone first and try again.';

  static const String notABackup = "That file isn't an All-In backup.";

  static const String backupShared = 'Backup ready to save';

  static const String backupFailed =
      "Couldn't create the backup — free some space and try again.";

  static const String progressErased = 'Progress erased';

  /// X0 Data → "Back up all data (.json)" → share sheet (§7.9).
  Future<DataActionResult> shareBackup() async {
    final String json;
    try {
      json = await _ref.read(backupServiceProvider).export();
    } catch (_) {
      return const DataActionResult.failed(backupFailed);
    }
    final outcome = await _ref
        .read(shareServiceProvider)
        .shareBackup(json: json);
    return switch (outcome) {
      ShareOutcome.success => const DataActionResult.ok(backupShared),
      ShareOutcome.dismissed => const DataActionResult.cancelled(),
      ShareOutcome.unavailable => const DataActionResult.failed(backupFailed),
    };
  }

  /// The picker half of "Restore from backup…": returns the file's text, or a
  /// failure the screen turns into the §14 dialog. Null means "cancelled".
  Future<({String? json, String? error})> pickBackup() async {
    try {
      final picked = await _ref
          .read(fileServiceProvider)
          .pickJsonFile(dialogTitle: 'Choose an All-In backup');
      if (picked == null) return (json: null, error: null);
      if (picked.isEmpty) return (json: null, error: notABackup);
      return (json: picked.text, error: null);
    } catch (_) {
      return (json: null, error: unreadableFile);
    }
  }

  /// What the picked document is, before anything is written (X3's data).
  BackupPreview inspect(String json) =>
      _ref.read(backupServiceProvider).inspect(json);

  /// §14: a backup from a newer schema is refused with its own sentence.
  static String newerSchemaMessage(BackupPreview preview) =>
      'This backup was made by a newer version of All-In (backup v'
      '${preview.schemaVersion ?? BackupService.schemaVersion + 1}; this app '
      'reads v${BackupService.schemaVersion}). Update the app, then restore.';

  /// The X3 confirmation's body (§7.9).
  static String restoreBody(BackupPreview preview) {
    final when = formatBackupDate(preview.exportedAt);
    final hands = preview.handCount;
    return 'Your current stats, decisions, reads and hands will be replaced by '
        'the backup from $when ($hands hand${hands == 1 ? '' : 's'}).';
  }

  /// `12 March 2026`, or "an unknown date" when the file carries no stamp.
  static String formatBackupDate(int? exportedAt) {
    if (exportedAt == null || exportedAt <= 0) return 'an unknown date';
    final d = DateTime.fromMillisecondsSinceEpoch(exportedAt);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Writes the backup. Only called after [inspect] reported no problem.
  Future<DataActionResult> restore(String json) async {
    final BackupRestoreResult result;
    try {
      result = await _ref.read(backupServiceProvider).restore(json);
    } catch (_) {
      return const DataActionResult.failed(notABackup);
    }
    if (!result.ok) {
      return DataActionResult.failed(
        result.problem == BackupProblem.notABackup
            ? notABackup
            : 'That backup could not be restored.',
      );
    }
    final n = result.hands;
    return DataActionResult.ok('Backup restored — $n hand${n == 1 ? '' : 's'}');
  }

  /// X2's "Erase everything" (§7.10). Notes, leaks, review cards, goals,
  /// study and settings are deliberately untouched.
  Future<DataActionResult> resetProgress() async {
    try {
      await _ref.read(statsRepositoryProvider).resetStats();
    } catch (_) {
      return const DataActionResult.failed(
        "Progress couldn't be erased — try again.",
      );
    }
    return const DataActionResult.ok(progressErased);
  }
}

final settingsDataServiceProvider = Provider<SettingsDataService>(
  SettingsDataService.new,
);
