/// One-shot coach marks and hint counters (DESIGN.md §16.4 "Coach-mark / hint
/// counters", §4.15 "O1 coach marks", §4.2 hero-strip swipe hint).
///
/// One key, `allin.hints.v1`:
/// `{ firstHands, swipeHint, revealCollapse, headsUpHands }`.
/// Each counter records how often the user has already been shown a hint, so
/// the table can obey "first three hands of the user's life only, never
/// again" across restarts. Mobile-only — the desktop has no equivalent.
library;

import 'key_value_store.dart';

/// Storage key *(mobile addition)*.
const String kHintsKey = 'allin.hints.v1';

/// How many hands still show the first-table coach marks.
const int kFirstHandsHintLimit = 3;

/// The four counters.
class HintCounters {
  const HintCounters({
    this.firstHands = 0,
    this.swipeHint = 0,
    this.revealCollapse = 0,
    this.headsUpHands = 0,
  });

  static const HintCounters defaults = HintCounters();

  /// Hands played with the first-table coach marks shown.
  final int firstHands;

  /// Times the "swipe up here for the hand log" mark has been shown.
  final int swipeHint;

  /// Times the reveal-collapse hint has been shown.
  final int revealCollapse;

  /// **Heads-up** hands the user has started, counted separately from
  /// [firstHands] *(mobile addition)*.
  ///
  /// §4.2.1's button explainer is owed for "the first three HU hands", and
  /// heads-up is not where most users start: a player whose first three hands
  /// of all time were 6-max had already spent [firstHands] and never saw it.
  final int headsUpHands;

  /// The O1 coach marks are still owed (DESIGN §4.15).
  bool get showsFirstTableMarks => firstHands < kFirstHandsHintLimit;

  HintCounters copyWith({
    int? firstHands,
    int? swipeHint,
    int? revealCollapse,
    int? headsUpHands,
  }) => HintCounters(
    firstHands: firstHands ?? this.firstHands,
    swipeHint: swipeHint ?? this.swipeHint,
    revealCollapse: revealCollapse ?? this.revealCollapse,
    headsUpHands: headsUpHands ?? this.headsUpHands,
  );

  Map<String, Object?> toJson() => {
    'firstHands': firstHands,
    'swipeHint': swipeHint,
    'revealCollapse': revealCollapse,
    'headsUpHands': headsUpHands,
  };

  static HintCounters fromJson(Object? json) {
    if (json is! Map) return defaults;
    return HintCounters(
      firstHands: (json['firstHands'] as num?)?.toInt() ?? 0,
      swipeHint: (json['swipeHint'] as num?)?.toInt() ?? 0,
      revealCollapse: (json['revealCollapse'] as num?)?.toInt() ?? 0,
      headsUpHands: (json['headsUpHands'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Which hint a counter belongs to.
enum HintKind { firstHands, swipeHint, revealCollapse, headsUpHands }

class HintsStore {
  HintsStore(this._store);

  final KeyValueStore _store;

  HintCounters load() => HintCounters.fromJson(_store.getJson(kHintsKey));

  Future<bool> save(HintCounters counters) =>
      _store.setJson(kHintsKey, counters.toJson());

  /// Records that [kind] was shown once more.
  Future<HintCounters> increment(HintKind kind) async {
    final c = load();
    final next = switch (kind) {
      HintKind.firstHands => c.copyWith(firstHands: c.firstHands + 1),
      HintKind.swipeHint => c.copyWith(swipeHint: c.swipeHint + 1),
      HintKind.revealCollapse => c.copyWith(
        revealCollapse: c.revealCollapse + 1,
      ),
      HintKind.headsUpHands => c.copyWith(headsUpHands: c.headsUpHands + 1),
    };
    await save(next);
    return next;
  }

  /// "Run again" also re-arms the coach marks, so a re-run tour is followed by
  /// the same first-table guidance.
  Future<bool> reset() => _store.remove(kHintsKey);
}
