/// Picking and reading user files, and staging files for the share sheet —
/// DESIGN.md §7.8 (import hands `.txt`), §7.9 (backup / restore `.json`) and
/// the §14 rows "file picked but unreadable or not valid UTF-8" and
/// "huge file (> 5 000 hands)".
///
/// This service does I/O only. It never decides what a file *means*: a
/// `.json` that reads fine but is not an All-In backup is the restore code's
/// problem ("That file isn't an All-In backup."), while bytes that cannot be
/// read at all are this service's ([FileFailure.unreadable] → "That file
/// couldn't be read…"). §14 deliberately keeps those two messages distinct.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Why a pick could not be turned into text.
enum FileFailure {
  /// Bigger than the limit we are willing to hold in memory.
  tooLarge,

  /// Not decodable as text: binary bytes, a revoked cloud permission, a
  /// truncated download.
  unreadable,
}

/// Thrown by [FileService] when a file was chosen but cannot be read.
/// [message] is a developer string; user copy lives with the screen (§14).
class FileServiceException implements Exception {
  const FileServiceException(this.failure, this.message);

  final FileFailure failure;
  final String message;

  @override
  String toString() => 'FileServiceException(${failure.name}: $message)';
}

/// A file the user picked, already decoded to text.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.text,
    required this.sizeBytes,
    this.path,
  });

  /// File name including extension, as the OS reported it.
  final String name;

  /// Decoded contents (UTF-8, or the fallbacks in [FileService.decodeText]).
  final String text;

  /// Size on disk in bytes.
  final int sizeBytes;

  /// Absolute path of the (possibly cached) copy, when the platform gave one.
  final String? path;

  /// Lower-case extension without the dot (`txt`, `json`, or '' when none).
  String get extension {
    final i = name.lastIndexOf('.');
    return i <= 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  bool get isEmpty => text.trim().isEmpty;

  @override
  String toString() => 'PickedFile($name, $sizeBytes bytes)';
}

/// Opens the picker. Injectable so tests never touch a platform channel.
typedef PickFilesFn =
    Future<FilePickerResult?> Function({
      required List<String> allowedExtensions,
      String? dialogTitle,
    });

/// Resolves the directory temporary share files are written to.
typedef TempDirectoryFn = Future<Directory> Function();

/// Picks, reads and stages files.
class FileService {
  FileService({PickFilesFn? pickFiles, TempDirectoryFn? temporaryDirectory})
    : _pickFiles = pickFiles ?? _pickWithFilePicker,
      _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final PickFilesFn _pickFiles;
  final TempDirectoryFn _temporaryDirectory;

  /// Hand-history imports: § 14 expects thousands of hands, and a PokerStars
  /// text history runs ~1.5 kB per hand, so 16 MB covers ~10 000 hands while
  /// still refusing the 2 GB video someone picked by mistake.
  static const int maxTextBytes = 16 * 1024 * 1024;

  /// Backups are one JSON object of at most a few thousand records.
  static const int maxJsonBytes = 32 * 1024 * 1024;

  /// Sub-directory of the temp dir that share staging files live in, so
  /// [clearTemporaryFiles] can wipe ours and nothing else.
  static const String tempFolder = 'allin-share';

  /// §7.8 step 1: pick a `.txt` hand history. Returns null when the user
  /// cancelled (§7.8 "Cancel → nothing"); throws [FileServiceException] when
  /// the bytes cannot be read.
  Future<PickedFile?> pickTextFile({String? dialogTitle}) => pickFile(
    extensions: const ['txt'],
    maxBytes: maxTextBytes,
    dialogTitle: dialogTitle,
  );

  /// §7.9 restore: pick a `.json` backup. Same null / throw contract.
  Future<PickedFile?> pickJsonFile({String? dialogTitle}) => pickFile(
    extensions: const ['json'],
    maxBytes: maxJsonBytes,
    dialogTitle: dialogTitle,
  );

  /// The general form. [extensions] are lower-case and dot-less.
  Future<PickedFile?> pickFile({
    required List<String> extensions,
    int maxBytes = maxTextBytes,
    String? dialogTitle,
  }) async {
    final FilePickerResult? result;
    try {
      result = await _pickFiles(
        allowedExtensions: extensions,
        dialogTitle: dialogTitle,
      );
    } catch (e) {
      throw FileServiceException(FileFailure.unreadable, 'picker failed: $e');
    }
    final picked =
        result?.files.isNotEmpty ?? false ? result!.files.first : null;
    if (picked == null) return null; // cancelled

    if (picked.size > maxBytes) {
      throw FileServiceException(
        FileFailure.tooLarge,
        '${picked.size} bytes exceeds the $maxBytes limit',
      );
    }

    // The size guard runs before the bytes are loaded, so a huge pick can
    // never be read into memory: we only ever hold `maxBytes` at a time.
    Uint8List? bytes = picked.bytes;
    if (bytes == null) {
      final path = picked.path;
      if (path == null) {
        throw FileServiceException(
          FileFailure.unreadable,
          'no path and no bytes for ${picked.name}',
        );
      }
      try {
        bytes = await File(path).readAsBytes();
      } catch (e) {
        throw FileServiceException(
          FileFailure.unreadable,
          'read failed for $path: $e',
        );
      }
    }
    if (bytes.length > maxBytes) {
      throw FileServiceException(
        FileFailure.tooLarge,
        '${bytes.length} bytes exceeds the $maxBytes limit',
      );
    }

    return PickedFile(
      name: picked.name,
      text: decodeText(bytes),
      sizeBytes: bytes.length,
      path: picked.path,
    );
  }

  /// Decode [bytes] as text, with the fallbacks a phone actually needs:
  /// a UTF-8 BOM is stripped, UTF-16 (either endianness, BOM-marked) is
  /// decoded, and a file that is not valid UTF-8 but contains no NUL bytes
  /// falls back to Latin-1 — that is a Windows-exported hand history, and
  /// refusing it would be pedantry. Anything with NUL bytes (a PDF renamed
  /// to `.json`, §14) throws [FileFailure.unreadable].
  static String decodeText(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // UTF-16 BOMs.
    if (bytes.length >= 2) {
      final b0 = bytes[0];
      final b1 = bytes[1];
      if (b0 == 0xFF && b1 == 0xFE) {
        return _decodeUtf16(bytes, 2, littleEndian: true);
      }
      if (b0 == 0xFE && b1 == 0xFF) {
        return _decodeUtf16(bytes, 2, littleEndian: false);
      }
    }

    var view = bytes;
    // UTF-8 BOM.
    if (view.length >= 3 &&
        view[0] == 0xEF &&
        view[1] == 0xBB &&
        view[2] == 0xBF) {
      view = Uint8List.sublistView(view, 3);
    }

    try {
      return utf8.decode(view);
    } on FormatException {
      if (_looksBinary(view)) {
        throw const FileServiceException(
          FileFailure.unreadable,
          'not valid UTF-8 and contains NUL bytes',
        );
      }
      return latin1.decode(view, allowInvalid: true);
    }
  }

  /// Write [contents] into the app's temp share folder and return the file —
  /// the staging step behind every "Share" in §7.9.
  Future<File> writeTemporaryFile(String fileName, String contents) async {
    final dir = Directory(
      p.join((await _temporaryDirectory()).path, tempFolder),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, sanitizeFileName(fileName)));
    await file.writeAsString(contents, flush: true);
    return file;
  }

  /// Delete everything staged for sharing (safe to call at any time; a share
  /// sheet still holding a file keeps its own copy).
  Future<void> clearTemporaryFiles() async {
    final dir = Directory(
      p.join((await _temporaryDirectory()).path, tempFolder),
    );
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Busy or already gone — nothing depends on this succeeding.
      }
    }
  }

  /// Strip path separators and characters that Android/iOS or a desktop the
  /// file lands on would reject. Keeps the extension.
  static String sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return cleaned.isEmpty ? 'all-in-file' : cleaned;
  }

  static bool _looksBinary(Uint8List bytes) {
    final n = bytes.length < 8192 ? bytes.length : 8192;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  static String _decodeUtf16(
    Uint8List bytes,
    int start, {
    required bool littleEndian,
  }) {
    final units = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }

  static Future<FilePickerResult?> _pickWithFilePicker({
    required List<String> allowedExtensions,
    String? dialogTitle,
  }) => FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: false,
    withData: false,
  );
}
