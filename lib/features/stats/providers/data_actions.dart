/// Export, share, backup, restore and reset — the actions behind T0's Data
/// card and the identical rows in Settings → Data (DESIGN.md §7.9, §7.10).
///
/// Settings owns the *rows*; Stats owns what they *do*, because every one of
/// them touches the stats tables ([StatsRepository]) or the replayable hands
/// this feature already decodes. `features/settings` therefore calls
/// [statsDataActionsProvider] rather than re-implementing any of it — the
/// public API is:
///
/// * [StatsDataActions.shareBackup] — "Back up all data (.json)"
/// * [StatsDataActions.pickBackup] + [StatsDataActions.restore] — "Restore
///   from backup…" and the X3 dialog's data
/// * [StatsDataActions.resetProgress] — X2's "Erase everything"
/// * [StatsDataActions.shareHand] / [StatsDataActions.shareSession] /
///   [StatsDataActions.shareSampleHistory] — the `⇪` affordances of §7.9
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../engine/engine.dart' show HHHand, formatSession;
import '../../../services/file_service.dart';
import '../../../services/persistence.dart';
import '../../../services/share_service.dart';
import '../sample_hand.dart';
import 'stats_providers.dart';

/// Why a picked file never became an action.
enum StatsFileProblem {
  /// The user dismissed the picker — §7.8 "Cancel → nothing".
  cancelled,

  /// Bytes that cannot be read as text (§14).
  unreadable,

  /// Larger than [FileService] is willing to hold in memory (§14).
  tooLarge,
}

/// A `.json` the user picked, already inspected by [BackupService].
class PickedBackup {
  const PickedBackup({this.file, this.preview, this.problem});

  final PickedFile? file;

  /// What X3 needs to describe the file before anything is written.
  final BackupPreview? preview;

  /// Non-null when there is nothing to restore.
  final StatsFileProblem? problem;

  bool get isPicked => file != null && preview != null;
}

/// The Data actions, injectable end to end (every dependency is a provider).
class StatsDataActions {
  const StatsDataActions(this._ref);

  final Ref _ref;

  /* ---------------------------------------------------------- backup */

  /// `exportBackup()` → share sheet with `allin-backup-YYYY-MM-DD.json`.
  Future<ShareOutcome> shareBackup() async {
    final json = await _ref.read(backupServiceProvider).export();
    return _ref.read(shareServiceProvider).shareBackup(json: json);
  }

  /// The backup document itself, for a caller that wants to show its size or
  /// write it somewhere else.
  Future<String> exportBackupJson() =>
      _ref.read(backupServiceProvider).export();

  /// Opens the `.json` picker and inspects the result **without writing**.
  Future<PickedBackup> pickBackup() async {
    final PickedFile? file;
    try {
      file = await _ref.read(fileServiceProvider).pickJsonFile();
    } on FileServiceException catch (e) {
      return PickedBackup(problem: _problemFor(e.failure));
    }
    if (file == null) {
      return const PickedBackup(problem: StatsFileProblem.cancelled);
    }
    final preview = _ref.read(backupServiceProvider).inspect(file.text);
    return PickedBackup(file: file, preview: preview);
  }

  /// Replaces stats, hands and ended sessions with the backup's contents.
  Future<BackupRestoreResult> restore(String json) async {
    final result = await _ref.read(backupServiceProvider).restore(json);
    _ref.read(statsRevisionProvider.notifier).bump();
    return result;
  }

  /* ----------------------------------------------------------- reset */

  /// X2 (§7.10). Notes, leaks, review cards, goals, study and settings stay.
  Future<void> resetProgress() => _ref.read(statsProvider.notifier).reset();

  /* ----------------------------------------------------------- share */

  /// One hand as PokerStars-style text (P11 `⇪`, T2 swipe-left "Export").
  Future<ShareOutcome> shareHand(HHHand hand) => _ref
      .read(shareServiceProvider)
      .shareHand(
        handHistory: formatSession([hand]),
        startedAt: DateTime.fromMillisecondsSinceEpoch(hand.startedAt),
      );

  /// A whole session as one `.txt` (§4.13 / §9's `formatSession`).
  Future<ShareOutcome> shareSession(
    List<HHHand> hands, {
    DateTime? startedAt,
  }) => _ref
      .read(shareServiceProvider)
      .shareSession(
        handHistory: formatSession(hands),
        startedAt:
            startedAt ??
            (hands.isEmpty
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(hands.first.startedAt)),
      );

  /// §7.8's "Export a sample": shares one hand in the exact dialect the
  /// importer reads, so a user with an unreadable file can see the format.
  Future<ShareOutcome> shareSampleHistory() => shareHand(buildSampleHand());

  static StatsFileProblem _problemFor(FileFailure failure) => switch (failure) {
    FileFailure.tooLarge => StatsFileProblem.tooLarge,
    FileFailure.unreadable => StatsFileProblem.unreadable,
  };
}

final statsDataActionsProvider = Provider<StatsDataActions>(
  StatsDataActions.new,
);
