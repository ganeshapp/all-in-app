/// Core domain types — ported from the desktop app's `src/types/poker.ts`
/// (plus the drill/leak/SRS records shared by several engine modules).
///
/// Conventions (mirror the TypeScript so port docs apply verbatim):
/// * A [Card] is a 2-char string: rank then suit, e.g. "Ah", "Td", "2c".
///   The int encoding used by the evaluator/equity code is
///   `(rankIndex) * 4 + suitIndex` with ranks 2..A → 0..12 and suits in
///   [kSuits] order (c, d, h, s), exactly as `cards.ts`.
/// * Money is in chips (ints). Default big blind 20, stacks 2000.
/// * State classes here are MUTABLE with an explicit [clone]; engine
///   functions never mutate their input — they clone, mutate the clone and
///   return it (the same discipline as `game/engine.ts`).
/// * No Flutter imports anywhere under `lib/engine/`.
library;

typedef Card = String;

const List<String> kRanks = [
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
  'J',
  'Q',
  'K',
  'A',
];
const List<String> kSuits = ['c', 'd', 'h', 's'];

/// Ranks in descending order — used for the 13×13 matrix (A high, top-left).
const List<String> kRanksDesc = [
  'A',
  'K',
  'Q',
  'J',
  'T',
  '9',
  '8',
  '7',
  '6',
  '5',
  '4',
  '3',
  '2',
];

/// Made-hand categories, ordered weakest → strongest (index == desktop value).
enum HandCategory {
  highCard('High Card'),
  pair('Pair'),
  twoPair('Two Pair'),
  trips('Three of a Kind'),
  straight('Straight'),
  flush('Flush'),
  fullHouse('Full House'),
  quads('Four of a Kind'),
  straightFlush('Straight Flush');

  const HandCategory(this.label);
  final String label;
}

class EvaluatedHand {
  const EvaluatedHand({
    required this.category,
    required this.score,
    required this.name,
  });

  final HandCategory category;

  /// Monotonic score; higher is better. Safe to compare across any 5–7 card hands.
  final int score;
  final String name;

  @override
  String toString() => 'EvaluatedHand($name, $score)';
}

/// Hand label for the 13×13 grid, e.g. "AKs", "AKo", "TT".
typedef HandLabel = String;

enum Position {
  utg('UTG'),
  mp('MP'),
  co('CO'),
  btn('BTN'),
  sb('SB'),
  bb('BB');

  const Position(this.label);
  final String label;

  static Position fromLabel(String label) =>
      Position.values.firstWhere((p) => p.label == label);
}

enum Street {
  preflop('preflop'),
  flop('flop'),
  turn('turn'),
  river('river'),
  showdown('showdown');

  const Street(this.label);
  final String label;

  static Street fromLabel(String label) =>
      Street.values.firstWhere((s) => s.label == label);
}

enum ActionType {
  fold('fold'),
  check('check'),
  call('call'),
  bet('bet'),
  raise('raise'),
  post('post');

  const ActionType(this.label);
  final String label;

  static ActionType fromLabel(String label) =>
      ActionType.values.firstWhere((a) => a.label == label);
}

class Action {
  const Action(this.type, {this.amount, this.allIn = false});
  const Action.fold() : this(ActionType.fold);
  const Action.check() : this(ActionType.check);
  const Action.call({int? amount}) : this(ActionType.call, amount: amount);
  const Action.bet(int amount) : this(ActionType.bet, amount: amount);
  const Action.raise(int amount) : this(ActionType.raise, amount: amount);

  final ActionType type;

  /// Total chips this action puts in front of the player on this street (bet/raise/call).
  final int? amount;
  final bool allIn;

  @override
  String toString() =>
      'Action(${type.label}${amount != null ? ' $amount' : ''})';
}

enum Archetype {
  tag('TAG'),
  lag('LAG'),
  nit('Nit'),
  station('Station');

  const Archetype(this.label);
  final String label;

  static Archetype fromLabel(String label) =>
      Archetype.values.firstWhere((a) => a.label == label);
}

class ArchetypeConfig {
  const ArchetypeConfig({
    required this.archetype,
    required this.name,
    required this.blurb,
    required this.vpip,
    required this.pfr,
    required this.cbetFlop,
    required this.aggression,
    required this.stickiness,
    required this.color,
  });

  final Archetype archetype;
  final String name;
  final String blurb;
  final double vpip; // %
  final double pfr; // %
  final double cbetFlop; // %
  /// Aggression factor used to bias bet/raise vs call postflop.
  final double aggression;

  /// How sticky they are with marginal made hands (calldown tendency 0..1).
  final double stickiness;

  /// Hex colour string e.g. "#2f6fd0".
  final String color;
}

/// Per-session jitter of behavioural knobs, so the archetype label isn't a full spoiler.
class Dials {
  const Dials({
    required this.aggression,
    required this.stickiness,
    required this.cbetFlop,
  });
  final double aggression;
  final double stickiness;
  final double cbetFlop;
}

class PlayerLastAction {
  const PlayerLastAction(this.label, this.street);

  /// "Raise", "Call", "Check", "Fold", "All-In", "Bet", "SB", "BB"
  final String label;
  final Street street;
}

class Player {
  Player({
    required this.id,
    required this.name,
    required this.isHero,
    this.archetype,
    required this.stack,
    this.hole,
    this.revealed = false,
    this.foldedStreet,
    this.hasFolded = false,
    this.isAllIn = false,
    this.committed = 0,
    this.committedTotal = 0,
    this.acted = false,
    this.position = Position.btn,
    this.lastAction,
    this.handsSeen = 0,
    this.vpipCount = 0,
    this.pfrCount = 0,
    this.vpipThisHand = false,
    this.pfrThisHand = false,
    this.dials,
    this.sittingOut = false,
  });

  /// Seat index 0..n-1; 0 is hero.
  final int id;
  String name;
  final bool isHero;
  Archetype? archetype;
  int stack;

  /// Two cards, or null before the deal.
  List<Card>? hole;

  /// Cards revealed — at showdown, or the end-of-hand learning reveal.
  bool revealed;

  /// Street this player folded on (null while still in the hand).
  Street? foldedStreet;
  bool hasFolded;
  bool isAllIn;

  /// Chips committed on the current street.
  int committed;

  /// Total chips committed across all streets this hand.
  int committedTotal;

  /// Has acted since the last bet/raise on the current street.
  bool acted;
  Position position;
  PlayerLastAction? lastAction;

  /// Observed live stats (for the HUD).
  int handsSeen;
  int vpipCount;
  int pfrCount;

  /// Transient per-hand flags backing the observed counters.
  bool vpipThisHand;
  bool pfrThisHand;
  Dials? dials;
  bool sittingOut;

  Player clone() => Player(
    id: id,
    name: name,
    isHero: isHero,
    archetype: archetype,
    stack: stack,
    hole: hole == null ? null : List<Card>.of(hole!),
    revealed: revealed,
    foldedStreet: foldedStreet,
    hasFolded: hasFolded,
    isAllIn: isAllIn,
    committed: committed,
    committedTotal: committedTotal,
    acted: acted,
    position: position,
    lastAction: lastAction,
    handsSeen: handsSeen,
    vpipCount: vpipCount,
    pfrCount: pfrCount,
    vpipThisHand: vpipThisHand,
    pfrThisHand: pfrThisHand,
    dials: dials,
    sittingOut: sittingOut,
  );
}

enum GamePhase { idle, betting, streetEnd, showdown, handOver }

class PotResult {
  const PotResult({
    required this.winners,
    required this.amount,
    required this.potLabel,
  });
  final List<int> winners; // player ids

  /// Chips. `num` (desktop `number`) because imported real-money hands keep
  /// fractional $ amounts; played hands are always ints.
  final num amount;
  final String potLabel; // "Pot" / "Main pot" / "Side pot 1"
}

class ShowdownEntry {
  const ShowdownEntry({
    required this.playerId,
    required this.hole,
    required this.hand,
    required this.hadToShow,
  });
  final int playerId;
  final List<Card> hole;
  final EvaluatedHand? hand; // null if folded / mucked
  final bool hadToShow;
}

class HandSummary {
  const HandSummary({
    required this.handNumber,
    required this.potResults,
    required this.showdown,
    required this.board,
    required this.heroNetChips,
  });
  final int handNumber;
  final List<PotResult> potResults;
  final List<ShowdownEntry> showdown;
  final List<Card> board;
  final int heroNetChips;
}

enum LogKind { action, deal, result, info }

class LogEntry {
  const LogEntry({
    required this.id,
    required this.street,
    required this.text,
    required this.kind,
  });
  final int id;
  final Street street;
  final String text;
  final LogKind kind;
}

class GameConfig {
  const GameConfig({
    required this.seats,
    required this.startingStack,
    required this.smallBlind,
    required this.bigBlind,
    this.ante = 0,
  });

  /// 2, 6, or 9.
  final int seats;
  final int startingStack; // chips
  final int smallBlind;
  final int bigBlind;

  /// Optional ante posted by every player each hand (chips).
  final int ante;

  GameConfig copyWith({
    int? seats,
    int? startingStack,
    int? smallBlind,
    int? bigBlind,
    int? ante,
  }) => GameConfig(
    seats: seats ?? this.seats,
    startingStack: startingStack ?? this.startingStack,
    smallBlind: smallBlind ?? this.smallBlind,
    bigBlind: bigBlind ?? this.bigBlind,
    ante: ante ?? this.ante,
  );
}

class LegalActions {
  const LegalActions({
    required this.toCall,
    required this.canFold,
    required this.canCheck,
    required this.canCall,
    required this.callAmount,
    required this.canBet,
    required this.canRaise,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.potSize,
    required this.bigBlind,
  });

  final int toCall;
  final bool canFold;
  final bool canCheck;
  final bool canCall;
  final int callAmount;
  final bool canBet;
  final bool canRaise;

  /// Minimum legal total bet/raise (chips put out this street).
  final int minRaiseTo;

  /// Maximum (all-in) total.
  final int maxRaiseTo;
  final int potSize;
  final int bigBlind;
}

/// The full table state (desktop `GameState`). Mutable; see library docs.
class TableState {
  TableState({
    required this.config,
    required this.players,
    required this.button,
    this.street = Street.preflop,
    List<Card>? board,
    List<Card>? deck,
    this.pot = 0,
    this.currentBet = 0,
    required this.lastRaiseSize,
    this.aggressor,
    this.toAct,
    this.handNumber = 0,
    required this.smallBlind,
    required this.bigBlind,
    this.phase = GamePhase.idle,
    List<LogEntry>? log,
    this.logSeq = 1,
    Map<int, List<HandLabel>>? botRanges,
    List<int>? stacksAtStart,
    this.summary,
  }) : board = board ?? <Card>[],
       deck = deck ?? <Card>[],
       log = log ?? <LogEntry>[],
       botRanges = botRanges ?? <int, List<HandLabel>>{},
       stacksAtStart = stacksAtStart ?? players.map((p) => p.stack).toList();

  final GameConfig config;
  List<Player> players;
  int button;
  Street street;
  List<Card> board;
  List<Card> deck;
  int pot;

  /// Highest chips committed on the current street.
  int currentBet;

  /// Size of the last full bet/raise (for min-raise math).
  int lastRaiseSize;
  int? aggressor;
  int? toAct;
  int handNumber;
  int smallBlind;
  int bigBlind;
  GamePhase phase;
  List<LogEntry> log;
  int logSeq;

  /// Per-bot perceived holding range (labels) for the Peek feature.
  Map<int, List<HandLabel>> botRanges;
  List<int> stacksAtStart;
  HandSummary? summary;

  Player get hero => players[0];
  bool get isHeroTurn => phase == GamePhase.betting && toAct == 0;

  TableState clone() => TableState(
    config: config,
    players: players.map((p) => p.clone()).toList(),
    button: button,
    street: street,
    board: List<Card>.of(board),
    deck: List<Card>.of(deck),
    pot: pot,
    currentBet: currentBet,
    lastRaiseSize: lastRaiseSize,
    aggressor: aggressor,
    toAct: toAct,
    handNumber: handNumber,
    smallBlind: smallBlind,
    bigBlind: bigBlind,
    phase: phase,
    log: List<LogEntry>.of(log),
    logSeq: logSeq,
    botRanges: {
      for (final e in botRanges.entries) e.key: List<HandLabel>.of(e.value),
    },
    stacksAtStart: List<int>.of(stacksAtStart),
    summary: summary,
  );
}

/* ---------------- Drill / leak / SRS records shared across modules ---------------- */

enum DrillAction {
  fold('fold'),
  check('check'),
  call('call'),
  bet('bet'),
  raise('raise');

  const DrillAction(this.label);
  final String label;

  static DrillAction fromLabel(String label) =>
      DrillAction.values.firstWhere((a) => a.label == label);
}

class DrillOption {
  const DrillOption({required this.action, required this.label, this.amount});
  final DrillAction action;
  final String label;

  /// Total bet/raise size (bb in drills, chips in leak spots captured from play) for bet/raise.
  final double? amount;

  Map<String, Object?> toJson() => {
    'action': action.label,
    'label': label,
    'amount': amount,
  };
  static DrillOption fromJson(Map<String, Object?> j) => DrillOption(
    action: DrillAction.fromLabel(j['action'] as String),
    label: j['label'] as String,
    amount: (j['amount'] as num?)?.toDouble(),
  );
}

/// Spaced-repetition scheduling state (desktop `lib/srs.ts` `SrsState`).
class SrsState {
  const SrsState({
    required this.due,
    required this.intervalDays,
    required this.ease,
    required this.wins,
    required this.lapses,
  });
  final int due; // epoch ms
  final double intervalDays;
  final double ease;
  final int wins;
  final int lapses;

  SrsState copyWith({
    int? due,
    double? intervalDays,
    double? ease,
    int? wins,
    int? lapses,
  }) => SrsState(
    due: due ?? this.due,
    intervalDays: intervalDays ?? this.intervalDays,
    ease: ease ?? this.ease,
    wins: wins ?? this.wins,
    lapses: lapses ?? this.lapses,
  );

  Map<String, Object?> toJson() => {
    'due': due,
    'intervalDays': intervalDays,
    'ease': ease,
    'wins': wins,
    'lapses': lapses,
  };
  static SrsState fromJson(Map<String, Object?> j) => SrsState(
    due: (j['due'] as num).toInt(),
    intervalDays: (j['intervalDays'] as num).toDouble(),
    ease: (j['ease'] as num).toDouble(),
    wins: (j['wins'] as num).toInt(),
    lapses: (j['lapses'] as num).toInt(),
  );
}

/// A coach-flagged mistake captured from play (or an imported hand), re-served as a drill.
class LeakSpot {
  const LeakSpot({
    required this.id,
    required this.street,
    required this.heroPos,
    required this.hole,
    required this.board,
    required this.pot,
    required this.toCall,
    required this.bb,
    required this.oppActive,
    required this.options,
    required this.best,
    required this.rationale,
    this.equity,
    this.potOdds,
    required this.ts,
    this.srs,
  });

  final String id;
  final Street street;
  final Position heroPos;
  final List<Card> hole;
  final List<Card> board;
  /// Coach leaks: chips with `bb` = table big blind. Hand-history import
  /// leaks: already in big blinds with `bb = 1` (may be fractional).
  final num pot;
  final num toCall;
  final num bb;
  final List<Position> oppActive;
  final List<DrillOption> options;
  final DrillAction best;
  final String rationale;
  final double? equity;
  final double? potOdds;
  final int ts;
  final SrsState? srs;

  LeakSpot copyWith({SrsState? srs, bool clearSrs = false}) => LeakSpot(
    id: id,
    street: street,
    heroPos: heroPos,
    hole: hole,
    board: board,
    pot: pot,
    toCall: toCall,
    bb: bb,
    oppActive: oppActive,
    options: options,
    best: best,
    rationale: rationale,
    equity: equity,
    potOdds: potOdds,
    ts: ts,
    srs: clearSrs ? null : (srs ?? this.srs),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'street': street.label,
    'heroPos': heroPos.label,
    'hole': hole,
    'board': board,
    'pot': pot,
    'toCall': toCall,
    'bb': bb,
    'oppActive': oppActive.map((p) => p.label).toList(),
    'options': options.map((o) => o.toJson()).toList(),
    'best': best.label,
    'rationale': rationale,
    'equity': equity,
    'potOdds': potOdds,
    'ts': ts,
    'srs': srs?.toJson(),
  };

  static LeakSpot fromJson(Map<String, Object?> j) => LeakSpot(
    id: j['id'] as String,
    street: Street.fromLabel(j['street'] as String),
    heroPos: Position.fromLabel(j['heroPos'] as String),
    hole: (j['hole'] as List).cast<String>(),
    board: (j['board'] as List).cast<String>(),
    pot: j['pot'] as num,
    toCall: j['toCall'] as num,
    bb: j['bb'] as num,
    oppActive:
        (j['oppActive'] as List)
            .map((p) => Position.fromLabel(p as String))
            .toList(),
    options:
        (j['options'] as List)
            .map(
              (o) => DrillOption.fromJson((o as Map).cast<String, Object?>()),
            )
            .toList(),
    best: DrillAction.fromLabel(j['best'] as String),
    rationale: j['rationale'] as String,
    equity: (j['equity'] as num?)?.toDouble(),
    potOdds: (j['potOdds'] as num?)?.toDouble(),
    ts: (j['ts'] as num).toInt(),
    srs:
        j['srs'] == null
            ? null
            : SrsState.fromJson((j['srs'] as Map).cast<String, Object?>()),
  );
}
