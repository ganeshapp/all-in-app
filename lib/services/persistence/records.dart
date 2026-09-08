/// The persisted play-stat records (docs/port/persistence-stats-settings.md
/// §3 and §2.3) — `HandRecord`, `GuessRecord` and the `StatsSnapshot` window
/// the Progress tab computes every number from (DESIGN.md §7).
///
/// `DecisionRecord` is the third record and lives in `lib/engine/leaks.dart`
/// (the leak rules consume it), so it is re-exported here for callers that
/// want all three from one import.
library;

import '../../engine/engine.dart' show Archetype, DecisionRecord, Position;
import 'serialization.dart' show archetypeOrNull, positionOrNull;

export '../../engine/leaks.dart' show DecisionRecord;

/// One finished hand of play. Written by the play loop's `finalizeHand`.
class HandRecord {
  const HandRecord({
    required this.n,
    required this.netBb,
    required this.potBb,
    required this.showdown,
    required this.won,
    this.archetypes = const [],
    this.position,
    this.sawFlop,
    this.handJson,
    required this.ts,
  });

  /// `table.handNumber` — the session hand number.
  final int n;

  /// Hero net for the hand, in big blinds.
  final double netBb;

  /// Total pot, in big blinds.
  final double potBb;

  /// The hand reached showdown.
  final bool showdown;

  /// Hero was among the winners.
  final bool won;

  /// Every non-hero player with an archetype who committed more than one big
  /// blind (the BB post alone does not count).
  final List<Archetype> archetypes;

  /// Hero's position this hand (schema v2+; null on older rows).
  final Position? position;

  /// Hero did not fold pre-flop (schema v3+; null on older rows, which are
  /// then excluded from WTSD).
  final bool? sawFlop;

  /// The full replayable `HHHand` payload. Persisted to `hand_history`, never
  /// loaded back into the snapshot window.
  final String? handJson;

  /// Epoch ms at hand end.
  final int ts;

  HandRecord copyWith({String? handJson, bool clearHandJson = false}) =>
      HandRecord(
        n: n,
        netBb: netBb,
        potBb: potBb,
        showdown: showdown,
        won: won,
        archetypes: archetypes,
        position: position,
        sawFlop: sawFlop,
        handJson: clearHandJson ? null : (handJson ?? this.handJson),
        ts: ts,
      );

  /// The desktop's local-storage shape. `handJson` is omitted by default,
  /// exactly as `persistHand`'s fallback path does.
  Map<String, Object?> toJson({bool includeHandJson = false}) => {
    'n': n,
    'netBb': netBb,
    'potBb': potBb,
    'showdown': showdown,
    'won': won,
    'archetypes': archetypes.map((a) => a.label).toList(),
    'position': position?.label,
    'sawFlop': sawFlop,
    if (includeHandJson) 'handJson': handJson,
    'ts': ts,
  };

  static HandRecord fromJson(Map<String, Object?> j) => HandRecord(
    n: (j['n'] as num?)?.toInt() ?? 0,
    netBb: (j['netBb'] as num?)?.toDouble() ?? 0,
    potBb: (j['potBb'] as num?)?.toDouble() ?? 0,
    showdown: j['showdown'] == true,
    won: j['won'] == true,
    archetypes: decodeArchetypes(j['archetypes']),
    position: positionOrNull(j['position']),
    sawFlop: j['sawFlop'] == null ? null : j['sawFlop'] == true,
    handJson: j['handJson'] as String?,
    ts: (j['ts'] as num?)?.toInt() ?? 0,
  );

  /// `["TAG","Nit"]` → enums, dropping anything unrecognised.
  static List<Archetype> decodeArchetypes(Object? json) {
    if (json is! List) return const [];
    return [
      for (final a in json)
        if (archetypeOrNull(a) case final Archetype v) v,
    ];
  }
}

/// One graded range read (Guess & Peek).
class GuessRecord {
  const GuessRecord({
    required this.accuracy,
    this.archetype,
    required this.street,
    required this.ts,
  });

  /// F1 of the painted range vs the actual one, 0..1.
  final double accuracy;
  final Archetype? archetype;

  /// `Street` value as a string.
  final String street;
  final int ts;

  Map<String, Object?> toJson() => {
    'accuracy': accuracy,
    'archetype': archetype?.label,
    'street': street,
    'ts': ts,
  };

  static GuessRecord fromJson(Map<String, Object?> j) => GuessRecord(
    accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
    archetype: archetypeOrNull(j['archetype']),
    street: j['street'] as String? ?? 'preflop',
    ts: (j['ts'] as num?)?.toInt() ?? 0,
  );
}

/// The lifetime counters plus the capped window every Progress number is
/// derived from. Arrays are chronological (oldest first) and hold at most
/// [StatsSnapshot.historyCap] entries each.
class StatsSnapshot {
  const StatsSnapshot({
    this.handsPlayed = 0,
    this.netChips = 0,
    this.bigBlind = defaultBigBlind,
    this.history = const [],
    this.guesses = const [],
    this.decisions = const [],
  });

  /// Rows loaded per table, and the in-memory window size (`HISTORY_CAP`).
  static const int historyCap = 800;

  /// Chips. Never updated by any code path — the desktop's `big_blind`
  /// column is a constant, and every bb conversion divides by it.
  static const int defaultBigBlind = 20;

  /// The empty snapshot returned when nothing is stored yet.
  static const StatsSnapshot empty = StatsSnapshot();

  /// Lifetime count of played hands (imported hands never count).
  final int handsPlayed;

  /// Lifetime hero net in chips.
  final int netChips;
  final int bigBlind;
  final List<HandRecord> history;
  final List<GuessRecord> guesses;
  final List<DecisionRecord> decisions;

  StatsSnapshot copyWith({
    int? handsPlayed,
    int? netChips,
    int? bigBlind,
    List<HandRecord>? history,
    List<GuessRecord>? guesses,
    List<DecisionRecord>? decisions,
  }) => StatsSnapshot(
    handsPlayed: handsPlayed ?? this.handsPlayed,
    netChips: netChips ?? this.netChips,
    bigBlind: bigBlind ?? this.bigBlind,
    history: history ?? this.history,
    guesses: guesses ?? this.guesses,
    decisions: decisions ?? this.decisions,
  );

  Map<String, Object?> toJson() => {
    'handsPlayed': handsPlayed,
    'netChips': netChips,
    'bigBlind': bigBlind,
    'history': history.map((h) => h.toJson()).toList(),
    'guesses': guesses.map((g) => g.toJson()).toList(),
    'decisions': decisions.map((d) => d.toJson()).toList(),
  };

  /// Tolerant decode: anything unexpected falls back to the default.
  static StatsSnapshot fromJson(Object? json) {
    if (json is! Map) return empty;
    final j = json.cast<String, Object?>();
    return StatsSnapshot(
      handsPlayed: (j['handsPlayed'] as num?)?.toInt() ?? 0,
      netChips: (j['netChips'] as num?)?.toInt() ?? 0,
      bigBlind: (j['bigBlind'] as num?)?.toInt() ?? defaultBigBlind,
      history: _decodeList(j['history'], HandRecord.fromJson),
      guesses: _decodeList(j['guesses'], GuessRecord.fromJson),
      decisions: _decodeList(j['decisions'], _decodeDecision),
    );
  }

  static List<T> _decodeList<T>(
    Object? json,
    T Function(Map<String, Object?>) decode,
  ) {
    if (json is! List) return const [];
    final out = <T>[];
    for (final e in json) {
      if (e is! Map) continue;
      try {
        out.add(decode(e.cast<String, Object?>()));
      } catch (_) {
        // One malformed row never costs the whole snapshot.
      }
    }
    return out;
  }

  static DecisionRecord _decodeDecision(Map<String, Object?> j) =>
      DecisionRecord(
        verdict: j['verdict'] as String? ?? 'ok',
        action: j['action'] as String? ?? 'call',
        equity: (j['equity'] as num?)?.toDouble() ?? 0,
        potOdds: (j['potOdds'] as num?)?.toDouble() ?? 0,
        evBb: (j['evBb'] as num?)?.toDouble() ?? 0,
        street: j['street'] as String? ?? 'preflop',
        villainArchetype: j['villainArchetype'] as String?,
        position: j['position'] as String?,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}
