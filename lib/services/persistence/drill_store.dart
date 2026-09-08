/// Drill rating and the recent-answers ring (docs/port/
/// persistence-stats-settings.md §6.9; DESIGN.md §5.4 and §16.4 "Drill
/// answers ring").
///
/// Two keys:
/// * `allin.drills.v1` — `{ rating, solved, correct, streak, best }`, the
///   desktop shape, accepted only when `rating` is a number.
/// * `allin.drill_answers.v1` *(mobile addition)* — the last 200
///   `{ ts, mode, kind, correct, ratingAfter }` answers, which drive the
///   weakest-mode quick set on Home and the rating sparkline.
library;

import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kDrillStateKey = 'allin.drills.v1';

/// Storage key *(mobile addition)*.
const String kDrillAnswersKey = 'allin.drill_answers.v1';

/// How many answers the ring keeps.
const int kDrillAnswersCap = 200;

/// The persisted drill scoreboard.
class DrillState {
  const DrillState({
    this.rating = 1000,
    this.solved = 0,
    this.correct = 0,
    this.streak = 0,
    this.best = 0,
  });

  static const DrillState defaults = DrillState();

  /// Elo-ish rating; the only field the placement test writes. The default
  /// is the engine's `kDefaultRating` (1000).
  final double rating;
  final int solved;
  final int correct;

  /// Current correct-answer streak.
  final int streak;

  /// Longest streak so far.
  final int best;

  DrillState copyWith({
    double? rating,
    int? solved,
    int? correct,
    int? streak,
    int? best,
  }) => DrillState(
    rating: rating ?? this.rating,
    solved: solved ?? this.solved,
    correct: correct ?? this.correct,
    streak: streak ?? this.streak,
    best: best ?? this.best,
  );

  Map<String, Object?> toJson() => {
    'rating': rating,
    'solved': solved,
    'correct': correct,
    'streak': streak,
    'best': best,
  };

  /// The stored object counts only when `rating` is a number, as on desktop.
  static DrillState fromJson(Object? json) {
    if (json is! Map || json['rating'] is! num) return defaults;
    return DrillState(
      rating: (json['rating'] as num).toDouble(),
      solved: (json['solved'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      best: (json['best'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One graded answer, kept in the ring.
class DrillAnswer {
  const DrillAnswer({
    required this.ts,
    required this.mode,
    required this.kind,
    required this.correct,
    required this.ratingAfter,
  });

  /// Epoch ms.
  final int ts;

  /// Drill mode id ("mixed", "pushfold", "exploit", "review").
  final String mode;

  /// Puzzle kind id (`PuzzleKind.label`).
  final String kind;
  final bool correct;

  /// The rating after this answer — the sparkline's y value.
  final double ratingAfter;

  Map<String, Object?> toJson() => {
    'ts': ts,
    'mode': mode,
    'kind': kind,
    'correct': correct,
    'ratingAfter': ratingAfter,
  };

  static DrillAnswer fromJson(Map<String, Object?> j) => DrillAnswer(
    ts: (j['ts'] as num?)?.toInt() ?? 0,
    mode: j['mode'] as String? ?? '',
    kind: j['kind'] as String? ?? '',
    correct: j['correct'] == true,
    ratingAfter: (j['ratingAfter'] as num?)?.toDouble() ?? 0,
  );
}

class DrillStore {
  DrillStore(this._store);

  final KeyValueStore _store;

  DrillState load() => DrillState.fromJson(_store.getJson(kDrillStateKey));

  Future<bool> save(DrillState state) =>
      _store.setJson(kDrillStateKey, state.toJson());

  /// The placement test's `seedRating`: only the rating changes.
  Future<DrillState> seedRating(double rating) async {
    final next = load().copyWith(rating: rating);
    await save(next);
    return next;
  }

  /// The placement bands of docs/port §6.9: ≤ 2 → 900, ≤ 5 → 1050, else 1250.
  static double placementRating(int score) =>
      score <= 2 ? 900 : (score <= 5 ? 1050 : 1250);

  /// The answer ring, oldest first.
  List<DrillAnswer> loadAnswers() => [
    for (final a in _store.getJsonList(kDrillAnswersKey))
      if (a is Map) DrillAnswer.fromJson(a.cast<String, Object?>()),
  ];

  /// Appends one answer, dropping the oldest beyond [kDrillAnswersCap].
  Future<List<DrillAnswer>> recordAnswer(DrillAnswer answer) async {
    final all = [...loadAnswers(), answer];
    final next =
        all.length <= kDrillAnswersCap
            ? all
            : all.sublist(all.length - kDrillAnswersCap);
    await _store.setJson(
      kDrillAnswersKey,
      next.map((a) => a.toJson()).toList(),
    );
    return next;
  }

  /// Accuracy per mode over the ring — the "weakest mode" quick set reads it.
  Map<String, double> accuracyByMode() {
    final counts = <String, int>{};
    final hits = <String, int>{};
    for (final a in loadAnswers()) {
      counts[a.mode] = (counts[a.mode] ?? 0) + 1;
      if (a.correct) hits[a.mode] = (hits[a.mode] ?? 0) + 1;
    }
    return {
      for (final e in counts.entries) e.key: (hits[e.key] ?? 0) / e.value,
    };
  }

  Future<bool> clearAnswers() => _store.remove(kDrillAnswersKey);
}
