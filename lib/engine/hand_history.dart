/// Structured hand-history recording + PokerStars-style export.
///
/// Port of the desktop `src/game/handHistory.ts`. The emitted text follows
/// the widely-imported PokerStars Hold'em history layout so sessions can be
/// loaded into trackers / replayers: globally unique hand ids, real muck
/// semantics (folded players never show cards, whatever the in-app learning
/// reveal displays), uncalled bets returned, and per-seat summary lines.
/// Amounts are in chips (play-money style).
///
/// [HHHand.toJson] / [HHHand.fromJson] produce exactly the desktop's
/// `JSON.stringify(HHHand)` payload (same field names, same key order,
/// `holes` keyed by seat-number strings with unknown holes omitted) so the
/// `hand_json` column round-trips between the two apps.
library;

import 'package:collection/collection.dart';

import 'evaluator.dart';
import 'format.dart';
import 'types.dart';

/// One recorded action. `amount`: call → chips called; bet/raise → total
/// "to" on this street; fold/check → 0.
class HHAction {
  const HHAction({
    required this.street,
    required this.seat,
    required this.name,
    required this.type,
    required this.amount,
    required this.allIn,
  });

  final Street street;
  final int seat;
  final String name;
  final ActionType type;

  /// Chips. `num` because imported real-money hands may carry fractional
  /// amounts (desktop `number`); played hands are always ints.
  final num amount;
  final bool allIn;

  Map<String, Object?> toJson() => {
    'street': street.label,
    'seat': seat,
    'name': name,
    'type': type.label,
    'amount': amount,
    'allIn': allIn,
  };

  static HHAction fromJson(Map<String, Object?> j) => HHAction(
    street: Street.fromLabel(j['street'] as String),
    seat: (j['seat'] as num).toInt(),
    name: j['name'] as String,
    type: ActionType.fromLabel(j['type'] as String),
    amount: j['amount'] as num,
    allIn: j['allIn'] as bool,
  );
}

class HHSeat {
  const HHSeat({
    required this.seat,
    required this.name,
    required this.stack,
    required this.isHero,
    required this.position,
  });

  final int seat;
  final String name;

  /// Chips at the start of the hand.
  final num stack;
  final bool isHero;
  final Position position;

  Map<String, Object?> toJson() => {
    'seat': seat,
    'name': name,
    'stack': stack,
    'isHero': isHero,
    'position': position.label,
  };

  static HHSeat fromJson(Map<String, Object?> j) => HHSeat(
    seat: (j['seat'] as num).toInt(),
    name: j['name'] as String,
    stack: j['stack'] as num,
    isHero: j['isHero'] as bool,
    position: Position.fromLabel(j['position'] as String),
  );
}

class HHHand {
  HHHand({
    required this.id,
    required this.startedAt,
    required this.button,
    required this.sb,
    required this.bb,
    required this.sbSeat,
    required this.bbSeat,
    required this.seats,
    Map<int, List<Card>?>? holes,
    List<HHAction>? actions,
    List<Card>? board,
    List<PotResult>? potResults,
    this.heroNet = 0,
  }) : holes = holes ?? <int, List<Card>?>{},
       actions = actions ?? <HHAction>[],
       board = board ?? <Card>[],
       potResults = potResults ?? <PotResult>[];

  /// Session-local hand number (restarts at 1 each session).
  int id;

  /// Epoch milliseconds — the unique key for notes/tags and export ids.
  int startedAt;
  int button;
  num sb;
  num bb;
  int sbSeat;
  int bbSeat;
  List<HHSeat> seats;

  /// Seat → hole cards (only known ones; a null entry means "unknown", the
  /// desktop's `undefined`, and is dropped from JSON).
  Map<int, List<Card>?> holes;
  List<HHAction> actions;
  List<Card> board;
  List<PotResult> potResults;

  /// Chips; imported hands: winnings only (approximate).
  num heroNet;

  Map<String, Object?> toJson() {
    final holeKeys = holes.keys.where((k) => holes[k] != null).toList()..sort();
    return {
      'id': id,
      'startedAt': startedAt,
      'button': button,
      'sb': sb,
      'bb': bb,
      'sbSeat': sbSeat,
      'bbSeat': bbSeat,
      'seats': seats.map((s) => s.toJson()).toList(),
      'holes': {for (final k in holeKeys) '$k': holes[k]},
      'actions': actions.map((a) => a.toJson()).toList(),
      'board': board,
      'potResults': potResults.map(_potToJson).toList(),
      'heroNet': heroNet,
    };
  }

  static HHHand fromJson(Map<String, Object?> j) => HHHand(
    id: (j['id'] as num).toInt(),
    startedAt: (j['startedAt'] as num).toInt(),
    button: (j['button'] as num).toInt(),
    sb: j['sb'] as num,
    bb: j['bb'] as num,
    sbSeat: (j['sbSeat'] as num).toInt(),
    bbSeat: (j['bbSeat'] as num).toInt(),
    seats:
        (j['seats'] as List)
            .map((s) => HHSeat.fromJson((s as Map).cast<String, Object?>()))
            .toList(),
    holes: {
      for (final e in ((j['holes'] as Map?) ?? const {}).entries)
        if (e.value != null)
          int.parse(e.key as String): (e.value as List).cast<Card>(),
    },
    actions:
        ((j['actions'] as List?) ?? const [])
            .map((a) => HHAction.fromJson((a as Map).cast<String, Object?>()))
            .toList(),
    board: ((j['board'] as List?) ?? const []).cast<Card>(),
    potResults:
        ((j['potResults'] as List?) ?? const [])
            .map((p) => _potFromJson((p as Map).cast<String, Object?>()))
            .toList(),
    heroNet: (j['heroNet'] as num?) ?? 0,
  );
}

Map<String, Object?> _potToJson(PotResult p) => {
  'winners': p.winners,
  'amount': p.amount,
  'potLabel': p.potLabel,
};

PotResult _potFromJson(Map<String, Object?> j) => PotResult(
  winners: (j['winners'] as List).map((w) => (w as num).toInt()).toList(),
  // PotResult.amount is an int in the shared types; fractional amounts can
  // only come from imported real-money hands and are rounded here.
  amount: jsRound((j['amount'] as num).toDouble()).toInt(),
  potLabel: j['potLabel'] as String,
);

const List<Street> _streetOrder = [
  Street.preflop,
  Street.flop,
  Street.turn,
  Street.river,
];

int _seatNo(int seat) => seat + 1;

/// JavaScript `${number}` for chip amounts: ints print as ints, integral
/// doubles without a trailing ".0", fractions as-is.
String _jsNum(num v) {
  if (v is int) return v.toString();
  final d = v.toDouble();
  if (d.isFinite && d == d.truncateToDouble()) return jsIntString(d);
  return d.toString();
}

({String line, num newStreetBet}) _actionLine(HHAction a, num streetBet) {
  final all = a.allIn ? ' and is all-in' : '';
  switch (a.type) {
    case ActionType.fold:
      return (line: '${a.name}: folds', newStreetBet: streetBet);
    case ActionType.check:
      return (line: '${a.name}: checks', newStreetBet: streetBet);
    case ActionType.call:
      return (
        line: '${a.name}: calls ${_jsNum(a.amount)}$all',
        newStreetBet: streetBet,
      );
    case ActionType.bet:
      return (
        line: '${a.name}: bets ${_jsNum(a.amount)}$all',
        newStreetBet: a.amount,
      );
    case ActionType.raise:
      final by = a.amount - streetBet;
      return (
        line:
            '${a.name}: raises ${_jsNum(by > 0 ? by : 0)} to ${_jsNum(a.amount)}$all',
        newStreetBet: a.amount,
      );
    case ActionType.post:
      return (line: '${a.name}: posts', newStreetBet: streetBet);
  }
}

/// Globally unique, monotonic export id (session-local ids restart at 1).
int exportHandId(HHHand h) => h.startedAt * 100 + (h.id % 100);

String _pad2(int n) => n.toString().padLeft(2, '0');

/// PokerStars-style timestamp in LOCAL time: `2026/06/19 12:00:00`.
String psDate(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${d.year}/${_pad2(d.month)}/${_pad2(d.day)} '
      '${_pad2(d.hour)}:${_pad2(d.minute)}:${_pad2(d.second)}';
}

/// "Two Pair, Aces & Kings" -> "two pair, Aces and Kings" (PS descriptor style).
String psHandName(List<Card> hole, List<Card> board) {
  final n = evaluateCards([
    ...hole,
    ...board,
  ]).name.replaceFirst(' & ', ' and ');
  if (n.startsWith('Pair of')) return 'a pair of${n.substring(7)}';
  if (n.startsWith('Two Pair')) return 'two pair${n.substring(8)}';
  if (n.startsWith('Three of a Kind')) {
    return 'three of a kind${n.substring(15)}';
  }
  if (n.startsWith('Straight Flush')) {
    return 'a straight flush${n.substring(14)}';
  }
  if (n.startsWith('Straight')) return 'a straight${n.substring(8)}';
  if (n.startsWith('Flush')) return 'a flush${n.substring(5)}';
  if (n.startsWith('Full House')) return 'a full house${n.substring(10)}';
  if (n.startsWith('Four of a Kind')) return 'four of a kind${n.substring(14)}';
  if (n == 'Royal Flush') return 'a royal flush';
  if (n.endsWith('High')) return 'high card ${n.substring(0, n.length - 5)}';
  return n.toLowerCase();
}

const Map<Street, String> _foldStreetPhrase = {
  Street.preflop: 'before Flop',
  Street.flop: 'on the Flop',
  Street.turn: 'on the Turn',
  Street.river: 'on the River',
};

String _nameOf(HHHand h, int? seat, [String fallback = '']) =>
    h.seats.firstWhereOrNull((s) => s.seat == seat)?.name ?? fallback;

/// PokerStars-style text for one hand (desktop `formatHand`, verbatim).
String formatHand(HHHand h) {
  final lines = <String>[];
  lines.add(
    "PokerStars Hand #${exportHandId(h)}: Hold'em No Limit "
    '(${_jsNum(h.sb)}/${_jsNum(h.bb)}) - ${psDate(h.startedAt)} ET',
  );
  lines.add(
    "Table 'All-In Dojo' ${h.seats.length}-max "
    'Seat #${_seatNo(h.button)} is the button',
  );

  for (final s in h.seats) {
    lines.add(
      'Seat ${_seatNo(s.seat)}: ${s.name} (${_jsNum(s.stack)} in chips)',
    );
  }

  final sbName = _nameOf(h, h.sbSeat, 'SB');
  final bbName = _nameOf(h, h.bbSeat, 'BB');
  lines.add('$sbName: posts small blind ${_jsNum(h.sb)}');
  lines.add('$bbName: posts big blind ${_jsNum(h.bb)}');

  lines.add('*** HOLE CARDS ***');
  final hero = h.seats.firstWhereOrNull((s) => s.isHero);
  if (hero != null && h.holes[hero.seat] != null) {
    final hole = h.holes[hero.seat]!;
    lines.add('Dealt to ${hero.name} [${hole[0]} ${hole[1]}]');
  }

  // Who folded, and on which street. Seats that never acted and never
  // won are treated as folded before the flop (defensive for partial
  // records — the live engine always records an explicit fold).
  final winners = <int>{for (final p in h.potResults) ...p.winners};
  final foldedOn = <int, Street>{};
  for (final a in h.actions) {
    if (a.type == ActionType.fold && !foldedOn.containsKey(a.seat)) {
      foldedOn[a.seat] = a.street;
    }
  }
  for (final s in h.seats) {
    if (!foldedOn.containsKey(s.seat) &&
        !winners.contains(s.seat) &&
        !h.actions.any((a) => a.seat == s.seat)) {
      foldedOn[s.seat] = Street.preflop;
    }
  }
  final live = h.seats.where((s) => !foldedOn.containsKey(s.seat)).toList();

  // Per-street committed chips, kept per street so the last betting
  // street tells us about any uncalled bet.
  final committed = <int, num>{};
  void emitStreet(Street street) {
    final acts = h.actions.where((a) => a.street == street).toList();
    if (street == Street.preflop) {
      committed[h.sbSeat] = h.sb;
      committed[h.bbSeat] = h.bb;
    } else {
      if (street == Street.flop && h.board.length >= 3) {
        lines.add('*** FLOP *** [${h.board.sublist(0, 3).join(' ')}]');
      } else if (street == Street.turn && h.board.length >= 4) {
        lines.add(
          '*** TURN *** [${h.board.sublist(0, 3).join(' ')}] [${h.board[3]}]',
        );
      } else if (street == Street.river && h.board.length >= 5) {
        lines.add(
          '*** RIVER *** [${h.board.sublist(0, 4).join(' ')}] [${h.board[4]}]',
        );
      } else if (acts.isEmpty) {
        return;
      }
      if (acts.isNotEmpty) {
        for (final s in h.seats) {
          committed[s.seat] = 0;
        }
      }
    }
    num streetBet = street == Street.preflop ? h.bb : 0;
    for (final a in acts) {
      if (a.type == ActionType.call) {
        committed[a.seat] = (committed[a.seat] ?? 0) + a.amount;
      } else if (a.type == ActionType.bet || a.type == ActionType.raise) {
        committed[a.seat] = a.amount;
      }
      final r = _actionLine(a, streetBet);
      streetBet = r.newStreetBet;
      lines.add(r.line);
    }
  }

  _streetOrder.forEach(emitStreet);

  // Uncalled bet: on the final betting street, any excess of the top
  // committed amount over the second-highest is returned to its owner.
  // (Stable sort like JS Array.prototype.sort.)
  final commits =
      h.seats.map((s) => (seat: s.seat, amt: committed[s.seat] ?? 0)).toList();
  mergeSort(commits, compare: (a, b) => (b.amt - a.amt).sign.toInt());
  final uncalled = commits.length > 1 ? commits[0].amt - commits[1].amt : 0;
  final int? uncalledSeat = uncalled > 0 ? commits[0].seat : null;
  if (uncalledSeat != null) {
    final name = _nameOf(h, uncalledSeat);
    lines.add('Uncalled bet (${_jsNum(uncalled)}) returned to $name');
  }

  // What each seat actually collects (pot totals minus any returned bet).
  final collected = <int, num>{};
  for (final p in h.potResults) {
    for (final w in p.winners) {
      collected[w] =
          (collected[w] ?? 0) + jsRound(p.amount / p.winners.length).toInt();
    }
  }
  if (uncalledSeat != null) {
    final v = (collected[uncalledSeat] ?? 0) - uncalled;
    collected[uncalledSeat] = v > 0 ? v : 0;
  }

  // Showdown: only genuine ones (river dealt, 2+ players still in).
  final wentToShowdown = h.board.length == 5 && live.length > 1;
  if (wentToShowdown) {
    lines.add('*** SHOW DOWN ***');
    for (final s in live) {
      final hole = h.holes[s.seat];
      if (hole != null) {
        lines.add(
          '${s.name}: shows [${hole[0]} ${hole[1]}] '
          '(${psHandName(hole, h.board)})',
        );
      }
    }
  }
  for (final e in collected.entries) {
    if (e.value > 0) {
      final name = _nameOf(h, e.key);
      lines.add('$name collected ${_jsNum(e.value)} from pot');
    }
  }

  // Summary
  final totalPot = collected.values.fold<num>(0, (a, b) => a + b);
  lines.add('*** SUMMARY ***');
  lines.add('Total pot ${_jsNum(totalPot)} | Rake 0');
  if (h.board.isNotEmpty) lines.add('Board [${h.board.join(' ')}]');
  for (final s in h.seats) {
    final tag =
        s.seat == h.sbSeat
            ? ' (small blind)'
            : s.seat == h.bbSeat
            ? ' (big blind)'
            : s.seat == h.button
            ? ' (button)'
            : '';
    final won = collected[s.seat] ?? 0;
    final hole = h.holes[s.seat];
    final foldStreet = foldedOn[s.seat];
    if (foldStreet != null) {
      lines.add(
        'Seat ${_seatNo(s.seat)}: ${s.name}$tag folded '
        '${_foldStreetPhrase[foldStreet] ?? 'before Flop'}',
      );
    } else if (wentToShowdown && hole != null) {
      final outcome = won > 0 ? 'won (${_jsNum(won)})' : 'lost';
      lines.add(
        'Seat ${_seatNo(s.seat)}: ${s.name}$tag showed [${hole[0]} ${hole[1]}] '
        'and $outcome with ${psHandName(hole, h.board)}',
      );
    } else if (won > 0) {
      lines.add(
        'Seat ${_seatNo(s.seat)}: ${s.name}$tag collected (${_jsNum(won)})',
      );
    } else {
      lines.add('Seat ${_seatNo(s.seat)}: ${s.name}$tag mucked');
    }
  }

  return lines.join('\n');
}

/// Whole session: hands separated by two blank lines (desktop `formatSession`).
String formatSession(List<HHHand> hands) =>
    hands.map(formatHand).join('\n\n\n');

/* ---- Step-by-step replay frames (for the in-app hand replayer) ---- */

class ReplayFrame {
  const ReplayFrame({
    required this.text,
    required this.street,
    required this.board,
    required this.pot,
    required this.folded,
    this.revealAll = false,
  });

  final String text;
  final Street street;
  final List<Card> board;
  final num pot;
  final List<int> folded;
  final bool revealAll;

  @override
  String toString() => 'ReplayFrame(${street.label}, $text, pot $pot)';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Desktop `buildReplayFrames`: blinds frame, one frame per action, a board
/// frame per dealt street, and a final reveal-all result frame.
List<ReplayFrame> buildReplayFrames(HHHand h) {
  final frames = <ReplayFrame>[];
  final committed = <int, num>{};
  for (final s in h.seats) {
    committed[s.seat] = 0;
  }
  committed[h.sbSeat] = h.sb;
  committed[h.bbSeat] = h.bb;
  num pot = h.sb + h.bb;
  final folded = <int>[];
  String bb(num chips) {
    final v = chips / h.bb;
    final isInteger = v.isFinite && v == v.truncateToDouble();
    return isInteger ? jsIntString(v) : jsToFixed(v, 1);
  }

  frames.add(
    ReplayFrame(
      text: 'Blinds ${bb(h.sb)}/${bb(h.bb)} bb posted.',
      street: Street.preflop,
      board: const [],
      pot: pot,
      folded: const [],
    ),
  );

  for (final street in _streetOrder) {
    final List<Card>? boardForStreet = switch (street) {
      Street.preflop => <Card>[],
      Street.flop => h.board.length >= 3 ? h.board.sublist(0, 3) : null,
      Street.turn => h.board.length >= 4 ? h.board.sublist(0, 4) : null,
      _ => h.board.length >= 5 ? h.board.sublist(0, 5) : null,
    };

    if (street != Street.preflop) {
      if (boardForStreet == null) continue;
      for (final s in h.seats) {
        committed[s.seat] = 0;
      }
      frames.add(
        ReplayFrame(
          text: '${_cap(street.label)}: ${boardForStreet.join(' ')}',
          street: street,
          board: boardForStreet,
          pot: pot,
          folded: List<int>.of(folded),
        ),
      );
    }

    final vis = boardForStreet ?? <Card>[];
    for (final a in h.actions.where((x) => x.street == street)) {
      var text = '';
      final allIn = a.allIn ? ' (all-in)' : '';
      if (a.type == ActionType.fold) {
        folded.add(a.seat);
        text = '${a.name} folds';
      } else if (a.type == ActionType.check) {
        text = '${a.name} checks';
      } else if (a.type == ActionType.call) {
        pot += a.amount;
        committed[a.seat] = (committed[a.seat] ?? 0) + a.amount;
        text = '${a.name} calls ${bb(a.amount)} bb$allIn';
      } else if (a.type == ActionType.bet) {
        pot += a.amount - (committed[a.seat] ?? 0);
        committed[a.seat] = a.amount;
        text = '${a.name} bets ${bb(a.amount)} bb$allIn';
      } else if (a.type == ActionType.raise) {
        pot += a.amount - (committed[a.seat] ?? 0);
        committed[a.seat] = a.amount;
        text = '${a.name} raises to ${bb(a.amount)} bb$allIn';
      }
      frames.add(
        ReplayFrame(
          text: text,
          street: street,
          board: vis,
          pot: pot,
          folded: List<int>.of(folded),
        ),
      );
    }
  }

  final winnerIds = <int>{for (final p in h.potResults) ...p.winners}.toList();
  final names =
      winnerIds.map((id) => _nameOf(h, id, 'Seat ${id + 1}')).toList();
  final total = h.potResults.fold<num>(0, (a, b) => a + b.amount);
  final endStreet =
      h.board.length >= 5
          ? Street.showdown
          : h.board.length == 4
          ? Street.turn
          : h.board.length == 3
          ? Street.flop
          : Street.preflop;
  frames.add(
    ReplayFrame(
      text:
          names.isNotEmpty
              ? '${names.join(', ')} win ${bb(total)} bb.'
              : 'Hand over.',
      street: endStreet,
      board: List<Card>.of(h.board),
      pot: pot,
      folded: List<int>.of(folded),
      revealAll: true,
    ),
  );

  return frames;
}
