/// The share sheet — DESIGN.md §4.13 / §7.9 (share a session, a single hand,
/// or a `.json` backup) via `share_plus`.
///
/// Everything the app shares is text: a PokerStars-style hand history or a
/// backup document. Text small enough to read in a message goes as text; a
/// document goes as a *file*, because "Save to Files / Drive / AirDrop" (§7.9)
/// needs a name and an extension. Staging that file is [FileService]'s job.
///
/// The returned [ShareOutcome] is what the caller shows a toast for; note the
/// share_plus caveat that Android and macOS only report "the user picked an
/// action", never that anything was really sent.
library;

import 'dart:io';

import 'package:share_plus/share_plus.dart';

import 'clock.dart';
import 'file_service.dart';

/// Result of summoning the share sheet.
enum ShareOutcome {
  /// The user picked a target (iOS may additionally confirm completion).
  success,

  /// The user dismissed the sheet.
  dismissed,

  /// The platform gave no result, or sharing is not available here.
  unavailable,
}

/// Thin wrapper over `share_plus`, injectable for tests.
abstract class ShareAdapter {
  const ShareAdapter();

  Future<ShareOutcome> shareText(String text, {String? subject});

  Future<ShareOutcome> shareFile(
    String path, {
    String? text,
    String? subject,
    String? mimeType,
  });
}

/// The real adapter (§16.6: the share sheet is a thin platform adapter).
class PlatformShareAdapter extends ShareAdapter {
  const PlatformShareAdapter();

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    if (text.isEmpty) return ShareOutcome.unavailable;
    try {
      return _map(await Share.share(text, subject: subject));
    } catch (_) {
      return ShareOutcome.unavailable;
    }
  }

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    String? text,
    String? subject,
    String? mimeType,
  }) async {
    try {
      final result = await Share.shareXFiles(
        <XFile>[XFile(path, mimeType: mimeType)],
        text: text,
        subject: subject,
      );
      return _map(result);
    } catch (_) {
      return ShareOutcome.unavailable;
    }
  }

  static ShareOutcome _map(ShareResult result) {
    switch (result.status) {
      case ShareResultStatus.success:
        return ShareOutcome.success;
      case ShareResultStatus.dismissed:
        return ShareOutcome.dismissed;
      case ShareResultStatus.unavailable:
        return ShareOutcome.unavailable;
    }
  }
}

/// Shares hand histories and backups.
class ShareService {
  ShareService({
    FileService? files,
    ShareAdapter adapter = const PlatformShareAdapter(),
    Clock clock = Clock.system,
  }) : _files = files ?? FileService(),
       _adapter = adapter,
       _clock = clock;

  final FileService _files;
  final ShareAdapter _adapter;
  final Clock _clock;

  /// Plain text (the "Copy" affordance's sibling in §4.13).
  Future<ShareOutcome> shareText(String text, {String? subject}) =>
      _adapter.shareText(text, subject: subject);

  /// Share an already-staged file.
  Future<ShareOutcome> shareFile(
    File file, {
    String? text,
    String? subject,
    String? mimeType,
  }) => _adapter.shareFile(
    file.path,
    text: text,
    subject: subject,
    mimeType: mimeType,
  );

  /// Stage [contents] as [fileName] and share it. Returns
  /// [ShareOutcome.unavailable] if the file could not be written (out of
  /// space — the §14 "Some data couldn't be saved" family).
  Future<ShareOutcome> shareDocument({
    required String fileName,
    required String contents,
    String? subject,
    String? mimeType,
  }) async {
    final File file;
    try {
      file = await _files.writeTemporaryFile(fileName, contents);
    } catch (_) {
      return ShareOutcome.unavailable;
    }
    return _adapter.shareFile(file.path, subject: subject, mimeType: mimeType);
  }

  /// §4.13 / §7.9: share a whole session's hands as
  /// `all-in-session-2026-09-06-19-20-31.txt`.
  Future<ShareOutcome> shareSession({
    required String handHistory,
    required DateTime startedAt,
  }) => shareDocument(
    fileName: sessionFileName(startedAt),
    contents: handHistory,
    mimeType: 'text/plain',
  );

  /// §7.9: one hand, from P11's `⇪` or the T2 swipe action.
  Future<ShareOutcome> shareHand({
    required String handHistory,
    required DateTime startedAt,
  }) => shareDocument(
    fileName: handFileName(startedAt),
    contents: handHistory,
    mimeType: 'text/plain',
  );

  /// §7.9: `allin-backup-2026-09-07.json`.
  Future<ShareOutcome> shareBackup({required String json, DateTime? at}) =>
      shareDocument(
        fileName: backupFileName(at ?? _clock.now()),
        contents: json,
        mimeType: 'application/json',
      );

  /// Remove staged copies (call on session end / app resume housekeeping).
  Future<void> clearStagedFiles() => _files.clearTemporaryFiles();

  /* ------------------------------------------------------------- file names */

  /// Desktop parity: `"all-in-session-" + ISO.slice(0, 19) with ":"/"T" → "-"`.
  static String sessionFileName(DateTime startedAt) =>
      'all-in-session-${_stamp(startedAt)}.txt';

  /// The single-hand sibling of [sessionFileName].
  static String handFileName(DateTime startedAt) =>
      'all-in-hand-${_stamp(startedAt)}.txt';

  /// Desktop parity: `"allin-backup-" + ISO.slice(0, 10)`.
  static String backupFileName(DateTime at) =>
      'allin-backup-${at.toUtc().toIso8601String().substring(0, 10)}.json';

  static String _stamp(DateTime at) => at
      .toUtc()
      .toIso8601String()
      .substring(0, 19)
      .replaceAll(RegExp('[:T]'), '-');
}
