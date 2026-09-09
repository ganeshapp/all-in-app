/// The Stats tab's Riverpod layer (DESIGN.md §7; §16.3
/// `features/stats/providers/`).
///
/// Everything the tab reads goes through here: the lifetime snapshot and its
/// derived metrics ([statsProvider]), hand notes and tags ([notesProvider]),
/// the replayable-hand lists ([recentHandsProvider], [allHandsProvider],
/// [handProvider]), the practice heatmap ([heatmapProvider]) and the
/// Review-queue count the coaching review links to ([dueLeakCountProvider]).
///
/// **Freshness.** Play writes hands through its own repository instance, so a
/// notifier that only loaded once would show stale numbers the moment the user
/// left the table. Every read here watches [statsRevisionProvider]; the tab
/// bumps it when it becomes visible, and every write in this feature (import,
/// reset, restore, a saved note) bumps it too.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../engine/engine.dart' show LeakSpot;
import '../../../services/persistence.dart';
import 'stats_metrics.dart';

/* -------------------------------------------------------------- stores */

/// Hand notes / bookmarks / tags (`allin.handnotes.v1`).
final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(keyValueStoreProvider)),
);

/// Replayable hands, decoded from the `hand_json` payloads.
final handsRepositoryProvider = Provider<HandsRepository>(
  (ref) => HandsRepository(stats: ref.watch(statsRepositoryProvider)),
);

/// Daily activity behind the practice heatmap (`allin.goals.v1`).
final goalsStoreProvider = Provider<GoalsStore>(
  (ref) => GoalsStore(ref.watch(keyValueStoreProvider)),
);

/// The coach's flagged spots (`allin.leaks.v1`) — written by the play loop and
/// by the hand-history importer, read by Drills' Review mode.
final leakQueueStoreProvider = Provider<LeakQueueStore>(
  (ref) => LeakQueueStore(ref.watch(keyValueStoreProvider)),
);

/* ------------------------------------------------------------ freshness */

/// Bumped whenever stored stats, hands, notes or leaks may have changed.
class StatsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Re-read everything on the next build.
  void bump() => state = state + 1;
}

final statsRevisionProvider = NotifierProvider<StatsRevisionNotifier, int>(
  StatsRevisionNotifier.new,
);

/* ---------------------------------------------------------------- stats */

/// The lifetime snapshot, derived into every number of §7.
///
/// Loading and error are real states: the repository never throws, but the
/// database open behind it can be slow on a cold start, and §14 asks for a
/// screen that says something in both cases rather than a blank page.
class StatsNotifier extends AsyncNotifier<StatsMetrics> {
  @override
  Future<StatsMetrics> build() async {
    ref.watch(statsRevisionProvider);
    final snapshot = await ref.watch(statsRepositoryProvider).loadStats();
    return computeStatsMetrics(snapshot);
  }

  /// Re-read the snapshot, keeping the current numbers on screen while the
  /// new ones load (no flash of empty state on a tab revisit).
  Future<void> refresh() async {
    final repository = ref.read(statsRepositoryProvider);
    state = await AsyncValue.guard(
      () async => computeStatsMetrics(await repository.loadStats()),
    );
  }

  /// X2 "Erase everything" (§7.10): wipes stats, hands, reads, decisions and
  /// the ended-session list. Notes, tags, leaks, review cards, goals, study
  /// progress and settings survive, exactly as the desktop's `resetStats`.
  Future<void> reset() async {
    await ref.read(statsRepositoryProvider).resetStats();
    await ref.read(sessionRepositoryProvider).clearEndedSessions();
    ref.read(statsRevisionProvider.notifier).bump();
  }
}

final statsProvider = AsyncNotifierProvider<StatsNotifier, StatsMetrics>(
  StatsNotifier.new,
);

/* ---------------------------------------------------------------- notes */

/// Every hand note, keyed by `String(startedAt)` (§7.6).
class NotesNotifier extends Notifier<Map<String, HandNote>> {
  @override
  Map<String, HandNote> build() {
    ref.watch(statsRevisionProvider);
    return ref.watch(notesRepositoryProvider).loadAll();
  }

  NotesRepository get _repository => ref.read(notesRepositoryProvider);

  /// The note on one hand, or null.
  HandNote? noteFor(int startedAt) => state[handNoteKey(startedAt)];

  /// Saves (or replaces) a note; an empty note removes it, so the ✎ never
  /// goes gold for a note with nothing in it.
  Future<bool> save(
    int startedAt, {
    String note = '',
    List<String> tags = const [],
  }) async {
    if (note.trim().isEmpty && tags.isEmpty) return remove(startedAt);
    final ok = await _repository.setNote(startedAt, note: note, tags: tags);
    state = _repository.loadAll();
    return ok;
  }

  /// "Remove note" (§7.6).
  Future<bool> remove(int startedAt) async {
    final ok = await _repository.remove(startedAt);
    state = _repository.loadAll();
    return ok;
  }

  /// Adds or removes [tag], lower-cased like the editor's custom field.
  List<String> toggleTag(List<String> tags, String tag) =>
      _repository.toggleTag(tags, tag);
}

final notesProvider = NotifierProvider<NotesNotifier, Map<String, HandNote>>(
  NotesNotifier.new,
);

/// Every tag in use across all notes — the chip row of §7.5.
final allTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(notesProvider);
  final used = <String>{for (final n in notes.values) ...n.tags};
  final presets = kPresetTags.where(used.contains).toList();
  final custom = used.where((t) => !kPresetTags.contains(t)).toList()..sort();
  return [...presets, ...custom];
});

/* ---------------------------------------------------------------- hands */

/// Rows the desktop loads for the Stats tab (`loadRecentHands(30)`).
const int kRecentHandsLimit = 30;

/// Rows T0's "Recent hands" card shows (§7.5).
const int kRecentHandsShown = 5;

/// Rows T2 loads per page (§7.5, §14 "> 1 000 rows → 100 at a time").
const int kAllHandsPage = 100;

/// The last [kRecentHandsLimit] hands, played and imported, newest first.
final recentHandsProvider = FutureProvider<List<StoredHand>>((ref) {
  ref.watch(statsRevisionProvider);
  return ref
      .watch(handsRepositoryProvider)
      .recentHands(limit: kRecentHandsLimit);
});

/// T2's page: the last [limit] stored hands, unfiltered (the screen applies
/// the source and tag filters so changing a chip never refetches).
final allHandsProvider = FutureProvider.family<List<StoredHand>, int>((
  ref,
  limit,
) {
  ref.watch(statsRevisionProvider);
  return ref.watch(handsRepositoryProvider).recentHands(limit: limit);
});

/// One hand by `startedAt` for the replayer; null when it is no longer stored
/// (§14 "pruned, reset or never saved").
final handProvider = FutureProvider.family<StoredHand?, int>((ref, startedAt) {
  ref.watch(statsRevisionProvider);
  return ref.watch(handsRepositoryProvider).handByStartedAt(startedAt);
});

/// The hands either side of [startedAt] in T2's own order (newest first), so
/// P11 can step from one hand to the next without a round trip through the
/// list *(mobile addition)*.
///
/// `.older` is the next row down the list; `.newer` is the row above it. Both
/// are null when the hand is not in the loaded page — an imported hand opened
/// by deep link after the page moved on, say — which simply disables the two
/// controls.
typedef HandNeighbours = ({int? newer, int? older});

final handNeighboursProvider = Provider.family<HandNeighbours, int>((
  ref,
  startedAt,
) {
  final hands =
      ref.watch(allHandsProvider(kAllHandsPage)).valueOrNull ??
      const <StoredHand>[];
  final i = hands.indexWhere((h) => h.startedAt == startedAt);
  if (i < 0) return (newer: null, older: null);
  return (
    newer: i > 0 ? hands[i - 1].startedAt : null,
    older: i < hands.length - 1 ? hands[i + 1].startedAt : null,
  );
});

/* ------------------------------------------------------------- practice */

/// 16 weeks × 7 cells, oldest first (§7.11).
final heatmapProvider = Provider<List<HeatmapCell>>((ref) {
  ref.watch(statsRevisionProvider);
  return ref.watch(goalsStoreProvider).heatmapCells();
});

/* ---------------------------------------------------------------- leaks */

/// Spots whose SRS schedule has come due — the coaching review's
/// "Review these spots ›" appears only when this is > 0 (§7.1).
final dueLeakCountProvider = Provider<int>((ref) {
  ref.watch(statsRevisionProvider);
  return ref.watch(leakQueueStoreProvider).dueSpots().length;
});

/// Adds [spots] to the Review queue (the importer's hand-off, §7.8 step 6).
Future<void> addLeakSpots(Ref ref, List<LeakSpot> spots) async {
  final store = ref.read(leakQueueStoreProvider);
  for (final spot in spots) {
    await store.add(spot);
  }
}
