/// The coach-flagged leak queue (docs/port/persistence-stats-settings.md
/// §6.8; DESIGN.md §5.5 "Review / My leaks").
///
/// One key, `allin.leaks.v1`: a newest-first array of [LeakSpot], capped at
/// 60, each carrying its own SRS schedule. Producers are the live coach (a
/// "mistake" verdict) and the hand-history import analyzer — note the two use
/// different units (chips with `bb = bigBlind` vs big blinds with `bb = 1`,
/// docs/port §19 trap 4); this store never converts, it only persists.
///
/// Deliberately **no de-duplication by id**: the desktop stores duplicates,
/// and `review()` then retires them together (§6.8, §11.4).
library;

import '../../engine/engine.dart'
    show LeakSpot, isDue, isGraduated, newSrs, reviewSrs;
import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kLeaksKey = 'allin.leaks.v1';

/// How many spots the queue keeps.
const int kLeaksCap = 60;

class LeakQueueStore {
  LeakQueueStore(this._store);

  final KeyValueStore _store;

  /// Newest first. A spot stored before scheduling existed is backfilled with
  /// a fresh schedule seeded at its own timestamp, so it is due immediately.
  List<LeakSpot> load() {
    final out = <LeakSpot>[];
    for (final raw in _store.getJsonList(kLeaksKey)) {
      if (raw is! Map) continue;
      try {
        final spot = LeakSpot.fromJson(raw.cast<String, Object?>());
        out.add(spot.srs == null ? spot.copyWith(srs: newSrs(spot.ts)) : spot);
      } catch (_) {
        // One unreadable spot never costs the queue.
      }
    }
    return out;
  }

  Future<bool> save(List<LeakSpot> spots) => _store.setJson(
    kLeaksKey,
    spots.take(kLeaksCap).map((s) => s.toJson()).toList(),
  );

  /// Prepends [spot] (scheduling it if it arrived unscheduled) and trims to
  /// [kLeaksCap].
  Future<List<LeakSpot>> add(LeakSpot spot, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final scheduled = spot.srs == null ? spot.copyWith(srs: newSrs(now)) : spot;
    final next = [scheduled, ...load()].take(kLeaksCap).toList();
    await save(next);
    return next;
  }

  /// Grades every spot with [id] (ids are not unique) and retires the ones
  /// that graduated.
  Future<List<LeakSpot>> review(String id, bool correct, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final next = <LeakSpot>[];
    for (final s in load()) {
      if (s.id != id) {
        next.add(s);
        continue;
      }
      final srs = reviewSrs(s.srs ?? newSrs(now), correct, now);
      if (correct && isGraduated(srs)) continue;
      next.add(s.copyWith(srs: srs));
    }
    await save(next);
    return next;
  }

  /// Spots whose schedule has come due.
  List<LeakSpot> dueSpots({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return load().where((s) => isDue(s.srs, now)).toList();
  }

  /// The next due time among the not-yet-due spots — DESIGN §5.5's
  /// "Next due" empty state.
  int? nextDueAt({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final pending =
        load().where((s) => !isDue(s.srs, now)).map((s) => s.srs!.due).toList()
          ..sort();
    return pending.isEmpty ? null : pending.first;
  }

  Future<bool> clear() => _store.setJson(kLeaksKey, const <Object?>[]);
}
