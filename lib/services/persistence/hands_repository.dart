/// Replayable hands (DESIGN.md §7.5 "Recent hands (T0) and All hands (T2)",
/// §7.7 replayer, §7.8 import).
///
/// Every finished hand — played or imported — is stored as a `hand_json`
/// payload in `hand_history`; this repository decodes those payloads into
/// [StoredHand]s and applies the two filters the UI offers: the
/// "Played / Imported / All" segmented control and the tag chips.
///
/// Reads go through [StatsRepository.loadRecentHands] so the key-value
/// fallback (docs/port/persistence-stats-settings.md §2.1) applies here too.
/// Whether a hand was imported is read from the payload's `imported` flag —
/// the same thing the desktop's row badge tests — not from the `source`
/// column, so a hand restored from a backup keeps its original badge.
library;

import 'dart:convert';

import '../../engine/engine.dart' show HHHand, ImportedHand;
import 'notes_repository.dart';
import 'serialization.dart';
import 'stats_repository.dart';

/// The "Played / Imported / All" filter of DESIGN §7.5.
enum HandSource { all, played, imported }

/// A decoded `hand_json` row.
class StoredHand {
  const StoredHand({
    required this.hand,
    required this.imported,
    required this.coachNotes,
    required this.json,
  });

  /// The replayable hand ([ImportedHand] when [imported] is true).
  final HHHand hand;

  /// Renders the `imported` badge and drives the source filter.
  final bool imported;

  /// The coach's verdicts for this hand, when it was played with the coach on
  /// (DESIGN §16.4 `hand_json.coachNotes[]`).
  final List<CoachNoteRecord> coachNotes;

  /// The raw decoded payload — kept so an unknown future field survives a
  /// read/modify/write cycle.
  final Map<String, Object?> json;

  /// The hand's identity everywhere else in the app: note key, deep link,
  /// leak id (docs/port §6.6).
  int get startedAt => hand.startedAt;

  /// Hero net in big blinds. Imported hands report winnings only.
  double get netBb => hand.bb == 0 ? 0 : hand.heroNet / hand.bb;
}

class HandsRepository {
  HandsRepository({required StatsRepository stats}) : _stats = stats;

  /// Rows scanned by [handByStartedAt] before giving up (DESIGN §14: a hand
  /// that is no longer there shows the replayer's own empty state).
  static const int lookupScanLimit = 500;

  final StatsRepository _stats;

  /// Most recent first. [limit] is applied to the stored rows *before*
  /// filtering, exactly as the desktop does (it filters the list it already
  /// loaded), so "Imported" shows the imported hands among the last [limit].
  Future<List<StoredHand>> recentHands({
    int limit = 50,
    HandSource source = HandSource.all,
    String? tag,
    Map<String, HandNote> notes = const {},
  }) async {
    final rows = await _stats.loadRecentHands(limit: limit);
    var hands = decodeHands(rows);
    if (source != HandSource.all) {
      final wantImported = source == HandSource.imported;
      hands = hands.where((h) => h.imported == wantImported).toList();
    }
    if (tag != null) hands = filterByTag(hands, notes, tag);
    return hands;
  }

  /// One hand by its `startedAt` key, or null when it was reset, pruned or
  /// never saved.
  Future<StoredHand?> handByStartedAt(
    int startedAt, {
    int limit = lookupScanLimit,
  }) async {
    for (final h in decodeHands(await _stats.loadRecentHands(limit: limit))) {
      if (h.startedAt == startedAt) return h;
    }
    return null;
  }

  /// How many hands of [source] are among the last [limit] stored rows.
  Future<int> count({
    HandSource source = HandSource.all,
    int limit = lookupScanLimit,
  }) async => (await recentHands(limit: limit, source: source)).length;

  /// Decodes payloads, skipping any row that will not parse (the desktop
  /// silently drops corrupt rows too).
  static List<StoredHand> decodeHands(List<String> payloads) {
    final out = <StoredHand>[];
    for (final raw in payloads) {
      final h = decodeHand(raw);
      if (h != null) out.add(h);
    }
    return out;
  }

  /// One payload, or null when it is not a readable hand.
  static StoredHand? decodeHand(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = decoded.cast<String, Object?>();
      final imported = json['imported'] == true;
      return StoredHand(
        hand: imported ? ImportedHand.fromJson(json) : HHHand.fromJson(json),
        imported: imported,
        coachNotes: coachNotesFromHandJson(json),
        json: json,
      );
    } catch (_) {
      return null;
    }
  }

  /// The tag-chip filter of DESIGN §7.5 / docs/port §7.9: keep hands whose
  /// note carries [tag]. Empty result renders "No hands carry that tag among
  /// the recent ones."
  static List<StoredHand> filterByTag(
    List<StoredHand> hands,
    Map<String, HandNote> notes,
    String tag,
  ) =>
      hands
          .where(
            (h) => notes[handNoteKey(h.startedAt)]?.tags.contains(tag) ?? false,
          )
          .toList();
}
