import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../engine/engine.dart';
import '../../../services/persistence/hand_reads_store.dart';

export '../../../services/persistence/hand_reads_store.dart'
    show HandRead, HandReadStatus;

final handReadsStoreProvider = Provider<HandReadsStore>(
  (ref) => HandReadsStore(ref.watch(keyValueStoreProvider)),
);

class HandReadsNotifier extends Notifier<List<HandRead>> {
  Future<void> _write = Future.value();
  @override
  List<HandRead> build() => ref.read(handReadsStoreProvider).load();

  HandRead? latest(int sessionId, int handNumber, int seat, {Street? street}) {
    for (final read in state.reversed) {
      if (read.sessionId == sessionId &&
          read.handNumber == handNumber &&
          read.seat == seat &&
          (street == null || read.street == street)) {
        return read;
      }
    }
    return null;
  }

  /// One immutable prediction per seat/street. Reopening a saved read never
  /// lets hindsight replace the original selection or inflate its hit count.
  HandRead submit(HandRead read) {
    final existing = latest(
      read.sessionId,
      read.handNumber,
      read.seat,
      street: read.street,
    );
    if (existing != null) return existing;
    _save([...state, read]);
    return read;
  }

  void finishHand(
    int sessionId,
    TableState table, {
    required bool realisticReveal,
  }) {
    if (table.phase != GamePhase.handOver) return;
    _save([
      for (final read in state)
        if (read.sessionId != sessionId ||
            read.handNumber != table.handNumber ||
            read.status != HandReadStatus.pending)
          read
        else
          _finish(read, table, realisticReveal),
    ]);
  }

  HandRead _finish(HandRead read, TableState table, bool realisticReveal) {
    final player = table.players.where((p) => p.id == read.seat).firstOrNull;
    final hole = player?.hole;
    if (player == null ||
        hole == null ||
        hole.length != 2 ||
        (realisticReveal && player.hasFolded)) {
      return read.finish(HandReadStatus.unshown);
    }
    return read.finish(HandReadStatus.revealed, hole);
  }

  /// A restart can leave a saved prediction beside a finished or missing
  /// session snapshot. Resolve it without replaying any betting actions.
  void reconcileSession(
    int sessionId,
    TableState? table, {
    required bool realisticReveal,
  }) {
    _save([
      for (final read in state)
        if (read.status != HandReadStatus.pending)
          read
        else if (table == null ||
            read.sessionId != sessionId ||
            read.handNumber != table.handNumber)
          read.finish(HandReadStatus.abandoned)
        else if (table.phase == GamePhase.handOver)
          _finish(read, table, realisticReveal)
        else
          read,
    ]);
  }

  void abandonSession(int sessionId) => _save([
    for (final read in state)
      read.sessionId == sessionId && read.status == HandReadStatus.pending
          ? read.finish(HandReadStatus.abandoned)
          : read,
  ]);

  void _save(List<HandRead> reads) {
    if (reads.length == state.length &&
        Iterable<int>.generate(
          reads.length,
        ).every((i) => identical(reads[i], state[i]))) {
      return;
    }
    // Keep all current predictions even if a long session fills the history.
    final completed =
        reads.where((r) => r.status != HandReadStatus.pending).toList();
    final keep =
        completed.length > HandReadsStore.historyLimit
            ? completed
                .skip(completed.length - HandReadsStore.historyLimit)
                .map((r) => r.id)
                .toSet()
            : completed.map((r) => r.id).toSet();
    state = [
      for (final read in reads)
        if (read.status == HandReadStatus.pending || keep.contains(read.id))
          read,
    ];
    final store = ref.read(handReadsStoreProvider);
    final snapshot = state;
    // Preserve write order when a hand finishes immediately after submission.
    _write = _write.then((_) async {
      await store.save(snapshot);
    });
    unawaited(_write);
  }
}

final handReadsProvider = NotifierProvider<HandReadsNotifier, List<HandRead>>(
  HandReadsNotifier.new,
);
