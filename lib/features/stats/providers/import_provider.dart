/// T3 · Import hands — the picker → progress → result flow of DESIGN.md §7.8,
/// with the desktop's exact order of operations
/// (`docs/port/persistence-stats-settings.md` §11.5): parse, **persist**,
/// analyse, add the leaks, then reload.
///
/// Three things the desktop does not do, all required here:
///
/// * **Nothing runs on the UI thread.** Parsing is regex-heavy and
///   `analyzeImported` runs a 2 500-sample equity simulation per hero call, so
///   both go through [importParserProvider] / [importAnalyserProvider], which
///   default to `compute` isolates and are overridden in tests.
/// * **Progress is real.** The file is split into hand blocks with the
///   parser's own rule (§11.2) and fed in chunks, so "Reading hands…" advances
///   per parsed hand and "Reviewing your calls… 12 of 40" is a true count.
/// * **It can be cancelled**, and it keeps running when the sheet is
///   dismissed to the background (§7.8 step 2).
///
/// The importer never throws: every failure is a state (§11.2's never-throws
/// contract, §14's file rows).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../engine/engine.dart';
import '../../../services/file_service.dart';
import 'stats_providers.dart';

/* --------------------------------------------------------------- chunks */

/// Hand blocks handed to one parser isolate.
const int kParseChunkBlocks = 50;

/// Hands written per `persistImportedHands` call (§14 "batches of 200").
const int kPersistBatch = 200;

/// Chunks the analysis is split into, so the progress count moves at least
/// twenty times on a large file without spawning an isolate per hand.
const int kAnalyseChunks = 20;

/// The parser's own block rule (§11.2): split on two or more newlines
/// followed by `PokerStars `, keep the blocks that start with it.
List<String> splitHandBlocks(String text) =>
    text
        .replaceAll('\r', '')
        .split(RegExp(r'\n{2,}(?=PokerStars )'))
        .map((b) => b.trim())
        .where((b) => b.startsWith('PokerStars '))
        .toList();

/* ---------------------------------------------------------------- state */

enum ImportPhase {
  /// No import has been started (or the result was dismissed).
  idle,

  /// Splitting and parsing the file — "Reading hands…".
  reading,

  /// Writing the parsed hands to `hand_history`.
  saving,

  /// Running the coach over the hero's calls — "Reviewing your calls… n of m".
  analysing,

  /// Finished; [ImportState.summary] carries the verbatim result line.
  done,

  /// Nothing was imported; [ImportState.failure] says why.
  failed,
}

enum ImportFailure {
  /// The file parsed but held no PokerStars-style hands (§7.8 step 4).
  noHands,

  /// The bytes could not be read at all (§14).
  unreadable,

  /// Refused before reading (§14 "huge file").
  tooLarge,

  /// The user cancelled the run.
  cancelled,
}

class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.fileName,
    this.parsedBlocks = 0,
    this.totalBlocks = 0,
    this.analysedHands = 0,
    this.totalHands = 0,
    this.hands = 0,
    this.skipped = 0,
    this.reviewed = 0,
    this.leaks = 0,
    this.failure,
  });

  final ImportPhase phase;
  final String? fileName;

  /// Blocks handed to the parser so far, and how many there are.
  final int parsedBlocks;
  final int totalBlocks;

  /// Hands reviewed so far, and how many will be.
  final int analysedHands;
  final int totalHands;

  /// The result counts (§7.8 step 3).
  final int hands;
  final int skipped;
  final int reviewed;
  final int leaks;

  final ImportFailure? failure;

  bool get isRunning =>
      phase == ImportPhase.reading ||
      phase == ImportPhase.saving ||
      phase == ImportPhase.analysing;

  /// 0..1 for the determinate bar, or null while there is nothing to measure.
  double? get progress => switch (phase) {
    ImportPhase.reading =>
      totalBlocks == 0 ? null : (parsedBlocks / totalBlocks).clamp(0.0, 1.0),
    ImportPhase.saving => 1,
    ImportPhase.analysing =>
      totalHands == 0 ? null : (analysedHands / totalHands).clamp(0.0, 1.0),
    _ => null,
  };

  /// The verbatim success line of §7.8 step 3 / §11.5.
  String? get summary =>
      phase == ImportPhase.done
          ? importSummaryText(
            hands: hands,
            skipped: skipped,
            reviewed: reviewed,
            leaks: leaks,
          )
          : null;

  ImportState copyWith({
    ImportPhase? phase,
    String? fileName,
    int? parsedBlocks,
    int? totalBlocks,
    int? analysedHands,
    int? totalHands,
    int? hands,
    int? skipped,
    int? reviewed,
    int? leaks,
    ImportFailure? failure,
  }) => ImportState(
    phase: phase ?? this.phase,
    fileName: fileName ?? this.fileName,
    parsedBlocks: parsedBlocks ?? this.parsedBlocks,
    totalBlocks: totalBlocks ?? this.totalBlocks,
    analysedHands: analysedHands ?? this.analysedHands,
    totalHands: totalHands ?? this.totalHands,
    hands: hands ?? this.hands,
    skipped: skipped ?? this.skipped,
    reviewed: reviewed ?? this.reviewed,
    leaks: leaks ?? this.leaks,
    failure: failure ?? this.failure,
  );
}

/* -------------------------------------------------------------- workers */

/// Parses one chunk of blocks; returns `{hands: List<String>, skipped: int}`.
typedef ImportParser = Future<Map<String, Object?>> Function(String chunk);

/// Reviews one chunk of hands; returns `{reviewed: int, leaks: List<String>}`.
typedef ImportAnalyser =
    Future<Map<String, Object?>> Function(Map<String, Object?> args);

/// `compute` by default; tests override both with in-process runners.
final importParserProvider = Provider<ImportParser>(
  (ref) => (chunk) => compute(parseChunkWorker, chunk),
);

final importAnalyserProvider = Provider<ImportAnalyser>(
  (ref) => (args) => compute(analyseChunkWorker, args),
);

/// Isolate entry point: parse, return JSON payloads (the shape that is
/// persisted) so nothing engine-specific has to cross the port.
Map<String, Object?> parseChunkWorker(String chunk) {
  final result = parsePokerStars(chunk);
  return {
    'hands': [for (final h in result.hands) jsonEncode(h.toJson())],
    'skipped': result.skipped,
  };
}

/// Isolate entry point: review already-parsed hands.
Map<String, Object?> analyseChunkWorker(Map<String, Object?> args) {
  final payloads = (args['hands'] as List).cast<String>();
  final now = (args['now'] as num?)?.toInt();
  final hands = <ImportedHand>[
    for (final raw in payloads)
      ImportedHand.fromJson((jsonDecode(raw) as Map).cast<String, Object?>()),
  ];
  final analysis = analyzeImported(hands, now: now);
  return {
    'reviewed': analysis.reviewed,
    'leaks': [for (final l in analysis.leaks) jsonEncode(l.toJson())],
  };
}

/* ------------------------------------------------------------- notifier */

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  int _run = 0;

  /// §7.8 step 1. Returns false when the user cancelled the picker (nothing
  /// is shown in that case — "Cancel → nothing").
  Future<bool> pickAndImport() async {
    final PickedFile? file;
    try {
      file = await ref.read(fileServiceProvider).pickTextFile();
    } on FileServiceException catch (e) {
      state = ImportState(
        phase: ImportPhase.failed,
        failure: switch (e.failure) {
          FileFailure.tooLarge => ImportFailure.tooLarge,
          FileFailure.unreadable => ImportFailure.unreadable,
        },
      );
      return true;
    }
    if (file == null) return false;
    await importText(file.text, fileName: file.name);
    return true;
  }

  /// The whole flow over already-read text (also the test entry point).
  Future<void> importText(String text, {String? fileName}) async {
    final run = ++_run;
    final blocks = splitHandBlocks(text);
    state = ImportState(
      phase: ImportPhase.reading,
      fileName: fileName,
      totalBlocks: blocks.length,
    );

    // ---- parse -----------------------------------------------------------
    final parse = ref.read(importParserProvider);
    final payloads = <String>[];
    var skipped = 0;
    for (var i = 0; i < blocks.length; i += kParseChunkBlocks) {
      if (_stale(run)) return;
      final end =
          i + kParseChunkBlocks < blocks.length
              ? i + kParseChunkBlocks
              : blocks.length;
      final chunk = blocks.sublist(i, end).join('\n\n');
      final result = await parse(chunk);
      if (_stale(run)) return;
      payloads.addAll((result['hands'] as List).cast<String>());
      skipped += (result['skipped'] as num?)?.toInt() ?? 0;
      state = state.copyWith(parsedBlocks: end);
    }

    if (payloads.isEmpty) {
      state = state.copyWith(
        phase: ImportPhase.failed,
        failure: ImportFailure.noHands,
        skipped: skipped,
      );
      return;
    }

    // ---- persist (before the analysis, exactly as the desktop) ------------
    state = state.copyWith(
      phase: ImportPhase.saving,
      hands: payloads.length,
      skipped: skipped,
      totalHands: payloads.length,
    );
    final stats = ref.read(statsRepositoryProvider);
    for (var i = 0; i < payloads.length; i += kPersistBatch) {
      if (_stale(run)) return;
      final end =
          i + kPersistBatch < payloads.length
              ? i + kPersistBatch
              : payloads.length;
      await stats.persistImportedHands(payloads.sublist(i, end));
    }
    // The hands are stored: they are in the list from here on, whatever the
    // analysis does.
    ref.read(statsRevisionProvider.notifier).bump();

    // ---- analyse ---------------------------------------------------------
    state = state.copyWith(phase: ImportPhase.analysing, analysedHands: 0);
    final analyse = ref.read(importAnalyserProvider);
    final size = _analyseChunkSize(payloads.length);
    var reviewed = 0;
    final leaks = <LeakSpot>[];
    for (var i = 0; i < payloads.length; i += size) {
      if (_stale(run)) return;
      final end = i + size < payloads.length ? i + size : payloads.length;
      final result = await analyse({
        'hands': payloads.sublist(i, end),
        'now': DateTime.now().millisecondsSinceEpoch,
      });
      if (_stale(run)) return;
      reviewed += (result['reviewed'] as num?)?.toInt() ?? 0;
      for (final raw in (result['leaks'] as List).cast<String>()) {
        try {
          leaks.add(
            LeakSpot.fromJson((jsonDecode(raw) as Map).cast<String, Object?>()),
          );
        } catch (_) {
          // A spot we cannot decode is one leak lost, never a failed import.
        }
      }
      state = state.copyWith(analysedHands: end, reviewed: reviewed);
    }

    // ---- hand the leaks to the Review queue -------------------------------
    await addLeakSpots(ref, leaks);
    if (_stale(run)) return;

    state = state.copyWith(
      phase: ImportPhase.done,
      reviewed: reviewed,
      leaks: leaks.length,
    );
    ref.read(statsRevisionProvider.notifier).bump();
  }

  /// The progress sheet's "Cancel". Hands already written stay written — they
  /// are valid replayable rows; only the review is abandoned.
  void cancel() {
    if (!state.isRunning) return;
    _run++;
    state = state.copyWith(
      phase: ImportPhase.failed,
      failure: ImportFailure.cancelled,
    );
  }

  /// Clears the result so the flow can be opened again.
  void dismiss() {
    if (state.isRunning) return;
    state = const ImportState();
  }

  bool _stale(int run) => run != _run;

  static int _analyseChunkSize(int hands) {
    final size = (hands / kAnalyseChunks).ceil();
    return size < 1 ? 1 : size;
  }
}

final importProvider = NotifierProvider<ImportNotifier, ImportState>(
  ImportNotifier.new,
);
