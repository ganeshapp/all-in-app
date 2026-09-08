/// Missed-drill review cards (docs/port/persistence-stats-settings.md §6.7;
/// DESIGN.md §5.5).
///
/// One key, `allin.review.v1`: a newest-first array of
/// `{ id, puzzle, srs }`, capped at 80. Unlike the leak queue this one **is**
/// de-duplicated: the id is derived from the puzzle's identity fields
/// (`kind|handLabel|board|heroPos`), so missing the same spot twice does not
/// add a second card.
library;

import '../../engine/engine.dart'
    show
        Puzzle,
        SrsState,
        isDue,
        isGraduated,
        kReviewCap,
        newSrs,
        reviewCardId,
        reviewSrs;
import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kReviewKey = 'allin.review.v1';

// The cap (`kReviewCap = 80`) and the de-duplication key (`reviewCardId`)
// are the engine's — `lib/engine/puzzles.dart` already ports them.

/// One scheduled repeat of a spot the user got wrong.
class ReviewCard {
  const ReviewCard({required this.id, required this.puzzle, required this.srs});

  /// `"<kind>|<handLabel>|<board>|<heroPos>"` — see [cardId].
  final String id;
  final Puzzle puzzle;
  final SrsState srs;

  ReviewCard copyWith({SrsState? srs}) =>
      ReviewCard(id: id, puzzle: puzzle, srs: srs ?? this.srs);

  Map<String, Object?> toJson() => {
    'id': id,
    'puzzle': puzzle.toJson(),
    'srs': srs.toJson(),
  };

  static ReviewCard fromJson(Map<String, Object?> j) => ReviewCard(
    id: j['id'] as String,
    puzzle: Puzzle.fromJson((j['puzzle'] as Map).cast<String, Object?>()),
    srs: SrsState.fromJson((j['srs'] as Map).cast<String, Object?>()),
  );

  /// The de-duplication key of docs/port §6.7 (the engine's `reviewCardId`).
  static String cardId(Puzzle p) => reviewCardId(p);
}

class ReviewQueueStore {
  ReviewQueueStore(this._store);

  final KeyValueStore _store;

  /// Newest first. Cards whose puzzle no longer parses (a spot shape from a
  /// future build) are dropped rather than crashing the queue.
  List<ReviewCard> load() {
    final out = <ReviewCard>[];
    for (final raw in _store.getJsonList(kReviewKey)) {
      if (raw is! Map) continue;
      try {
        out.add(ReviewCard.fromJson(raw.cast<String, Object?>()));
      } catch (_) {
        // Skip.
      }
    }
    return out;
  }

  Future<bool> save(List<ReviewCard> cards) => _store.setJson(
    kReviewKey,
    cards.take(kReviewCap).map((c) => c.toJson()).toList(),
  );

  /// Adds a card for a missed [puzzle]; a no-op when that spot is already
  /// queued.
  Future<List<ReviewCard>> addMiss(Puzzle puzzle, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final id = ReviewCard.cardId(puzzle);
    final cards = load();
    if (cards.any((c) => c.id == id)) return cards;
    final next =
        [
          ReviewCard(id: id, puzzle: puzzle, srs: newSrs(now)),
          ...cards,
        ].take(kReviewCap).toList();
    await save(next);
    return next;
  }

  /// Grades a card; a graduated card leaves the queue.
  Future<List<ReviewCard>> review(String id, bool correct, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final next = <ReviewCard>[];
    for (final c in load()) {
      if (c.id != id) {
        next.add(c);
        continue;
      }
      final srs = reviewSrs(c.srs, correct, now);
      if (correct && isGraduated(srs)) continue;
      next.add(c.copyWith(srs: srs));
    }
    await save(next);
    return next;
  }

  List<ReviewCard> dueCards({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return load().where((c) => isDue(c.srs, now)).toList();
  }

  /// The next due time among the not-yet-due cards ("Next due" empty state).
  int? nextDueAt({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final pending =
        load().where((c) => !isDue(c.srs, now)).map((c) => c.srs.due).toList()
          ..sort();
    return pending.isEmpty ? null : pending.first;
  }

  Future<bool> clear() => _store.setJson(kReviewKey, const <Object?>[]);
}
