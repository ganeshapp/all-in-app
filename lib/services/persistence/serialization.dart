/// JSON codecs for the engine's state objects (DESIGN.md §16.4: the session
/// snapshot stores a `TableState`, and `hand_json.coachNotes[]` rides along
/// with a saved hand).
///
/// The engine stays pure — it has no idea it is being persisted — so every
/// codec lives here as a plain function. [tableStateToJson] round-trips every
/// field, `botRanges`, `deck`, `log` and `summary` included, because a
/// resumed session must restore the exact table (street, board, pot, `toAct`;
/// DESIGN §4.14) and the Peek feature reads `botRanges`.
///
/// Decoders throw on a shape they cannot read; callers (see
/// `SessionRepository.loadSnapshot`) catch that and fall back to the
/// "that hand couldn't be restored" path of DESIGN §14.
library;

import 'dart:convert';

import '../../engine/engine.dart';

/* --------------------------------- Table --------------------------------- */

Map<String, Object?> gameConfigToJson(GameConfig c) => {
  'seats': c.seats,
  'startingStack': c.startingStack,
  'smallBlind': c.smallBlind,
  'bigBlind': c.bigBlind,
  'ante': c.ante,
};

GameConfig gameConfigFromJson(Map<String, Object?> j) => GameConfig(
  seats: (j['seats'] as num).toInt(),
  startingStack: (j['startingStack'] as num).toInt(),
  smallBlind: (j['smallBlind'] as num).toInt(),
  bigBlind: (j['bigBlind'] as num).toInt(),
  ante: (j['ante'] as num?)?.toInt() ?? 0,
);

Map<String, Object?> dialsToJson(Dials d) => {
  'aggression': d.aggression,
  'stickiness': d.stickiness,
  'cbetFlop': d.cbetFlop,
};

Dials dialsFromJson(Map<String, Object?> j) => Dials(
  aggression: (j['aggression'] as num).toDouble(),
  stickiness: (j['stickiness'] as num).toDouble(),
  cbetFlop: (j['cbetFlop'] as num).toDouble(),
);

Map<String, Object?> playerLastActionToJson(PlayerLastAction a) => {
  'label': a.label,
  'street': a.street.label,
};

PlayerLastAction playerLastActionFromJson(Map<String, Object?> j) =>
    PlayerLastAction(
      j['label'] as String,
      Street.fromLabel(j['street'] as String),
    );

Map<String, Object?> playerToJson(Player p) => {
  'id': p.id,
  'name': p.name,
  'isHero': p.isHero,
  'archetype': p.archetype?.label,
  'stack': p.stack,
  'hole': p.hole,
  'revealed': p.revealed,
  'foldedStreet': p.foldedStreet?.label,
  'hasFolded': p.hasFolded,
  'isAllIn': p.isAllIn,
  'committed': p.committed,
  'committedTotal': p.committedTotal,
  'acted': p.acted,
  'position': p.position.label,
  'lastAction':
      p.lastAction == null ? null : playerLastActionToJson(p.lastAction!),
  'handsSeen': p.handsSeen,
  'vpipCount': p.vpipCount,
  'pfrCount': p.pfrCount,
  'vpipThisHand': p.vpipThisHand,
  'pfrThisHand': p.pfrThisHand,
  'dials': p.dials == null ? null : dialsToJson(p.dials!),
  'sittingOut': p.sittingOut,
};

Player playerFromJson(Map<String, Object?> j) => Player(
  id: (j['id'] as num).toInt(),
  name: j['name'] as String,
  isHero: j['isHero'] as bool,
  archetype: _archetypeOrNull(j['archetype']),
  stack: (j['stack'] as num).toInt(),
  hole: (j['hole'] as List?)?.cast<Card>(),
  revealed: j['revealed'] == true,
  foldedStreet:
      j['foldedStreet'] == null
          ? null
          : Street.fromLabel(j['foldedStreet'] as String),
  hasFolded: j['hasFolded'] == true,
  isAllIn: j['isAllIn'] == true,
  committed: (j['committed'] as num?)?.toInt() ?? 0,
  committedTotal: (j['committedTotal'] as num?)?.toInt() ?? 0,
  acted: j['acted'] == true,
  position: Position.fromLabel(j['position'] as String),
  lastAction:
      j['lastAction'] == null
          ? null
          : playerLastActionFromJson(
            (j['lastAction'] as Map).cast<String, Object?>(),
          ),
  handsSeen: (j['handsSeen'] as num?)?.toInt() ?? 0,
  vpipCount: (j['vpipCount'] as num?)?.toInt() ?? 0,
  pfrCount: (j['pfrCount'] as num?)?.toInt() ?? 0,
  vpipThisHand: j['vpipThisHand'] == true,
  pfrThisHand: j['pfrThisHand'] == true,
  dials:
      j['dials'] == null
          ? null
          : dialsFromJson((j['dials'] as Map).cast<String, Object?>()),
  sittingOut: j['sittingOut'] == true,
);

Map<String, Object?> logEntryToJson(LogEntry e) => {
  'id': e.id,
  'street': e.street.label,
  'text': e.text,
  'kind': e.kind.name,
};

LogEntry logEntryFromJson(Map<String, Object?> j) => LogEntry(
  id: (j['id'] as num).toInt(),
  street: Street.fromLabel(j['street'] as String),
  text: j['text'] as String,
  kind: LogKind.values.firstWhere(
    (k) => k.name == j['kind'],
    orElse: () => LogKind.info,
  ),
);

Map<String, Object?> potResultToJson(PotResult r) => {
  'winners': r.winners,
  'amount': r.amount,
  'potLabel': r.potLabel,
};

PotResult potResultFromJson(Map<String, Object?> j) => PotResult(
  winners: (j['winners'] as List).map((w) => (w as num).toInt()).toList(),
  amount: j['amount'] as num,
  potLabel: j['potLabel'] as String? ?? 'Pot',
);

Map<String, Object?> evaluatedHandToJson(EvaluatedHand h) => {
  'category': h.category.name,
  'score': h.score,
  'name': h.name,
};

EvaluatedHand evaluatedHandFromJson(Map<String, Object?> j) => EvaluatedHand(
  category: HandCategory.values.firstWhere(
    (c) => c.name == j['category'],
    orElse: () => HandCategory.highCard,
  ),
  score: (j['score'] as num).toInt(),
  name: j['name'] as String,
);

Map<String, Object?> showdownEntryToJson(ShowdownEntry e) => {
  'playerId': e.playerId,
  'hole': e.hole,
  'hand': e.hand == null ? null : evaluatedHandToJson(e.hand!),
  'hadToShow': e.hadToShow,
};

ShowdownEntry showdownEntryFromJson(Map<String, Object?> j) => ShowdownEntry(
  playerId: (j['playerId'] as num).toInt(),
  hole: (j['hole'] as List).cast<Card>(),
  hand:
      j['hand'] == null
          ? null
          : evaluatedHandFromJson((j['hand'] as Map).cast<String, Object?>()),
  hadToShow: j['hadToShow'] == true,
);

Map<String, Object?> handSummaryToJson(HandSummary s) => {
  'handNumber': s.handNumber,
  'potResults': s.potResults.map(potResultToJson).toList(),
  'showdown': s.showdown.map(showdownEntryToJson).toList(),
  'board': s.board,
  'heroNetChips': s.heroNetChips,
};

HandSummary handSummaryFromJson(Map<String, Object?> j) => HandSummary(
  handNumber: (j['handNumber'] as num).toInt(),
  potResults:
      (j['potResults'] as List)
          .map((p) => potResultFromJson((p as Map).cast<String, Object?>()))
          .toList(),
  showdown:
      (j['showdown'] as List)
          .map((s) => showdownEntryFromJson((s as Map).cast<String, Object?>()))
          .toList(),
  board: (j['board'] as List).cast<Card>(),
  heroNetChips: (j['heroNetChips'] as num).toInt(),
);

/// The whole table, losslessly.
Map<String, Object?> tableStateToJson(TableState t) => {
  'config': gameConfigToJson(t.config),
  'players': t.players.map(playerToJson).toList(),
  'button': t.button,
  'street': t.street.label,
  'board': t.board,
  'deck': t.deck,
  'pot': t.pot,
  'currentBet': t.currentBet,
  'lastRaiseSize': t.lastRaiseSize,
  'aggressor': t.aggressor,
  'toAct': t.toAct,
  'handNumber': t.handNumber,
  'smallBlind': t.smallBlind,
  'bigBlind': t.bigBlind,
  'phase': t.phase.name,
  'log': t.log.map(logEntryToJson).toList(),
  'logSeq': t.logSeq,
  'botRanges': {for (final e in t.botRanges.entries) '${e.key}': e.value},
  'stacksAtStart': t.stacksAtStart,
  'summary': t.summary == null ? null : handSummaryToJson(t.summary!),
};

/// Inverse of [tableStateToJson]. Throws on a shape it cannot read.
TableState tableStateFromJson(Map<String, Object?> j) => TableState(
  config: gameConfigFromJson((j['config'] as Map).cast<String, Object?>()),
  players:
      (j['players'] as List)
          .map((p) => playerFromJson((p as Map).cast<String, Object?>()))
          .toList(),
  button: (j['button'] as num).toInt(),
  street: Street.fromLabel(j['street'] as String),
  board: (j['board'] as List?)?.cast<Card>(),
  deck: (j['deck'] as List?)?.cast<Card>(),
  pot: (j['pot'] as num?)?.toInt() ?? 0,
  currentBet: (j['currentBet'] as num?)?.toInt() ?? 0,
  lastRaiseSize: (j['lastRaiseSize'] as num).toInt(),
  aggressor: (j['aggressor'] as num?)?.toInt(),
  toAct: (j['toAct'] as num?)?.toInt(),
  handNumber: (j['handNumber'] as num?)?.toInt() ?? 0,
  smallBlind: (j['smallBlind'] as num).toInt(),
  bigBlind: (j['bigBlind'] as num).toInt(),
  phase: GamePhase.values.firstWhere(
    (p) => p.name == j['phase'],
    orElse: () => GamePhase.idle,
  ),
  log:
      ((j['log'] as List?) ?? const [])
          .map((e) => logEntryFromJson((e as Map).cast<String, Object?>()))
          .toList(),
  logSeq: (j['logSeq'] as num?)?.toInt() ?? 1,
  botRanges: {
    for (final e in ((j['botRanges'] as Map?) ?? const {}).entries)
      int.parse('${e.key}'): (e.value as List).cast<HandLabel>(),
  },
  stacksAtStart:
      (j['stacksAtStart'] as List?)?.map((s) => (s as num).toInt()).toList(),
  summary:
      j['summary'] == null
          ? null
          : handSummaryFromJson((j['summary'] as Map).cast<String, Object?>()),
);

/* ------------------------------ Coach notes ------------------------------ */

/// One three-layer coach verdict, stored inside a saved hand as
/// `hand_json.coachNotes[]` (DESIGN.md §16.4) so the replayer can show what
/// the coach said at the time.
class CoachNoteRecord {
  const CoachNoteRecord({
    required this.street,
    required this.action,
    required this.verdict,
    required this.title,
    required this.plain,
    this.text,
    this.steps = const [],
    this.expert,
    this.equity,
    this.potOdds,
    this.evBb,
    this.villainName,
    this.villainRange,
  });

  /// `Street` value as a string ("flop", …).
  final String street;

  /// The hero action graded ("call", "raise", …).
  final String action;

  /// "mistake" | "thin" | "ok" | "great" | "info".
  final String verdict;

  /// Headline, e.g. "Costly call".
  final String title;

  /// Layer 1 — plain English.
  final String plain;

  /// Optional extra layer-1 sentence.
  final String? text;

  /// Layer 2 — "Show me the math", one line per step.
  final List<String> steps;

  /// Layer 3 — "Expert detail".
  final String? expert;

  final double? equity;
  final double? potOdds;
  final double? evBb;
  final String? villainName;

  /// The range the verdict was computed against, as hand labels.
  final List<HandLabel>? villainRange;

  Map<String, Object?> toJson() => {
    'street': street,
    'action': action,
    'verdict': verdict,
    'title': title,
    'plain': plain,
    'text': text,
    'steps': steps,
    'expert': expert,
    'equity': equity,
    'potOdds': potOdds,
    'evBb': evBb,
    'villainName': villainName,
    'villainRange': villainRange,
  };

  static CoachNoteRecord fromJson(Map<String, Object?> j) => CoachNoteRecord(
    street: j['street'] as String? ?? '',
    action: j['action'] as String? ?? '',
    verdict: j['verdict'] as String? ?? 'info',
    title: j['title'] as String? ?? '',
    plain: j['plain'] as String? ?? '',
    text: j['text'] as String?,
    steps: ((j['steps'] as List?) ?? const []).map((s) => '$s').toList(),
    expert: j['expert'] as String?,
    equity: (j['equity'] as num?)?.toDouble(),
    potOdds: (j['potOdds'] as num?)?.toDouble(),
    evBb: (j['evBb'] as num?)?.toDouble(),
    villainName: j['villainName'] as String?,
    villainRange: (j['villainRange'] as List?)?.cast<HandLabel>(),
  );
}

/// The `hand_json` payload: the engine's `HHHand` JSON plus, when the coach
/// was on, a `coachNotes` array. Adding the key here keeps `lib/engine` pure.
String encodeHandJson(
  HHHand hand, {
  List<CoachNoteRecord> coachNotes = const [],
}) {
  final map = hand.toJson();
  if (coachNotes.isNotEmpty) {
    map['coachNotes'] = coachNotes.map((n) => n.toJson()).toList();
  }
  return jsonEncode(map);
}

/// The coach notes stored alongside a hand (empty when there are none).
List<CoachNoteRecord> coachNotesFromHandJson(Map<String, Object?> j) =>
    ((j['coachNotes'] as List?) ?? const [])
        .map(
          (n) => CoachNoteRecord.fromJson((n as Map).cast<String, Object?>()),
        )
        .toList();

/* -------------------------------- Helpers -------------------------------- */

/// Compact JSON for a stored blob (`summary_json`, `hand_json`, …).
String encodeJsonMap(Map<String, Object?> map) => jsonEncode(map);

/// Inverse of [encodeJsonMap]; null on absent or unreadable text.
Map<String, Object?>? decodeJsonMap(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final v = jsonDecode(raw);
    return v is Map ? v.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// Tolerant `Archetype` decode — an unknown label reads as null rather than
/// throwing, so one bad row cannot lose a whole snapshot.
Archetype? _archetypeOrNull(Object? label) {
  if (label is! String) return null;
  for (final a in Archetype.values) {
    if (a.label == label) return a;
  }
  return null;
}

/// Public form of the tolerant decode — repositories reuse it for the
/// `archetypes` / `archetype` text columns.
Archetype? archetypeOrNull(Object? label) => _archetypeOrNull(label);

/// Tolerant `Position` decode (empty string and unknown labels → null), the
/// desktop's `position: text || null`.
Position? positionOrNull(Object? label) {
  if (label is! String || label.isEmpty) return null;
  for (final p in Position.values) {
    if (p.label == label) return p;
  }
  return null;
}
