/// Pure Texas Hold'em hand state machine — ported 1:1 from the desktop
/// `src/game/engine.ts`.
///
/// 2/6/9-handed no-limit. Handles blinds and antes, betting rounds with
/// proper min-raise + short-all-in (no-reopen) rules, all-in run-outs and
/// side pots at showdown. Every entry point deep-copies the state it
/// receives and returns the copy; the caller's previous state is never
/// mutated. Randomness (first button, shuffle) is injectable via `rng`.
library;

import 'dart:math';

import 'archetypes.dart';
import 'cards.dart';
import 'evaluator.dart';
import 'types.dart';

const List<Position> _pos6 = [
  Position.btn,
  Position.sb,
  Position.bb,
  Position.utg,
  Position.mp,
  Position.co,
];

// 9-max approximated onto the six canonical labels the charts know.
const List<Position> _pos9 = [
  Position.btn,
  Position.sb,
  Position.bb,
  Position.utg,
  Position.utg,
  Position.mp,
  Position.mp,
  Position.co,
  Position.co,
];

/// Oldest log entries are dropped beyond this many.
const int kLogCap = 200;

void _pushLog(TableState s, Street street, String text, LogKind kind) {
  s.log.add(LogEntry(id: s.logSeq++, street: street, text: text, kind: kind));
  if (s.log.length > kLogCap) s.log.removeRange(0, s.log.length - kLogCap);
}

String _capitalize(String str) =>
    str.isEmpty ? str : str[0].toUpperCase() + str.substring(1);

/// Fresh idle table: `config.seats` players (seat 0 = hero), random button.
TableState createTable(GameConfig config, {Random? rng}) {
  final r = rng ?? Random();
  final players = <Player>[];
  for (int i = 0; i < config.seats; i++) {
    final isHero = i == 0;
    players.add(
      Player(
        id: i,
        name: isHero ? 'You' : botNameFor(i),
        isHero: isHero,
        archetype: isHero ? null : archetypeForSeat(i),
        stack: config.startingStack,
        hole: null,
        revealed: false,
        hasFolded: false,
        isAllIn: false,
        committed: 0,
        committedTotal: 0,
        acted: false,
        position: Position.btn,
        lastAction: null,
        handsSeen: 0,
        vpipCount: 0,
        pfrCount: 0,
        sittingOut: false,
      ),
    );
  }
  return TableState(
    config: config,
    players: players,
    button: r.nextInt(config.seats),
    street: Street.preflop,
    board: <Card>[],
    deck: <Card>[],
    pot: 0,
    currentBet: 0,
    lastRaiseSize: config.bigBlind,
    aggressor: null,
    toAct: null,
    handNumber: 0,
    smallBlind: config.smallBlind,
    bigBlind: config.bigBlind,
    phase: GamePhase.idle,
    log: <LogEntry>[],
    logSeq: 1,
    botRanges: <int, List<HandLabel>>{},
    stacksAtStart: players.map((p) => p.stack).toList(),
    summary: null,
  );
}

int _seatAtOffset(TableState s, int offset) =>
    (s.button + offset) % s.config.seats;

void _assignPositions(TableState s) {
  final order = _orderFromButton(s);
  final table =
      order.length < _posByCount.length ? _posByCount[order.length] : _pos9;
  for (int off = 0; off < order.length; off++) {
    s.players[order[off]].position =
        off < table.length ? table[off] : Position.mp;
  }
}

/// Seat labels by how many players are actually in the hand, indexed from the
/// button. A table playing down (`botRebuy: false`) passes through every size
/// on its way to heads-up, and the charts only know six names, so the short
/// tables drop the middle ones in the order a real table does.
const List<List<Position>> _posByCount = [
  [],
  [Position.btn],
  [Position.btn, Position.bb], // heads-up: the button is the small blind
  [Position.btn, Position.sb, Position.bb],
  [Position.btn, Position.sb, Position.bb, Position.utg],
  [Position.btn, Position.sb, Position.bb, Position.utg, Position.co],
  _pos6,
  [
    Position.btn,
    Position.sb,
    Position.bb,
    Position.utg,
    Position.utg,
    Position.mp,
    Position.co,
  ],
  [
    Position.btn,
    Position.sb,
    Position.bb,
    Position.utg,
    Position.utg,
    Position.mp,
    Position.mp,
    Position.co,
  ],
  _pos9,
];

/// Seats still in the game, in seat order.
List<int> seatedIds(TableState s) => [
  for (final p in s.players)
    if (!p.sittingOut) p.id,
];

/// Seats still in the game, ordered from the button round.
List<int> _orderFromButton(TableState s) {
  final seated = seatedIds(s);
  final i = seated.indexOf(s.button);
  final at = i < 0 ? 0 : i;
  return [...seated.sublist(at), ...seated.sublist(0, at)];
}

/// The next seat after [from] that is still in the game.
int _nextSeated(TableState s, int from) {
  final n = s.config.seats;
  for (int k = 1; k <= n; k++) {
    final q = (from + k) % n;
    if (!s.players[q].sittingOut) return q;
  }
  return from;
}

void _commit(TableState s, Player p, int amount) {
  final amt = max(0, min(amount, p.stack));
  p.stack -= amt;
  p.committed += amt;
  p.committedTotal += amt;
  s.pot += amt;
  if (p.stack == 0) p.isAllIn = true;
}

void _postBlind(TableState s, int seat, int amount, String label) {
  final p = s.players[seat];
  _commit(s, p, amount);
  p.lastAction = PlayerLastAction(label, Street.preflop);
}

/// Deal a new hand: advance the button (except for hand #1), auto-rebuy
/// busted stacks, shuffle + deal, post antes and blinds, pick the first actor.
TableState startHand(TableState prev, {Random? rng}) {
  final s = prev.clone();
  s.handNumber += 1;

  // An empty stack is either topped back up (the default: the table keeps its
  // shape so every hand is a full-ring rep) or it is the end of that bot's
  // game, and the table plays on short-handed. The hero is never sat out
  // here — the session layer ends the session on a busted hero.
  final rebuy = s.config.botRebuy;
  for (final p in s.players) {
    if (p.stack > 0 || p.sittingOut) continue;
    if (rebuy || p.isHero) {
      p.stack = s.config.startingStack;
    } else {
      p.sittingOut = true;
    }
  }

  // The button only ever sits on a player who is still in the game. The
  // `handNumber` guard keeps hand #1 on the button `createTable` drew — but
  // not when that seat is already out, which a restored play-down table can
  // hand us.
  if (s.handNumber > 1 || s.players[s.button].sittingOut) {
    s.button = _nextSeated(s, s.button);
  }

  for (final p in s.players) {
    p.hole = null;
    p.revealed = false;
    // A seat that is out plays no part in the hand, and every "is this player
    // still in?" test in the engine already asks `hasFolded`.
    p.hasFolded = p.sittingOut;
    p.foldedStreet = null;
    p.vpipThisHand = false;
    p.pfrThisHand = false;
    p.isAllIn = false;
    p.committed = 0;
    p.committedTotal = 0;
    p.acted = false;
    p.lastAction = null;
    if (!p.sittingOut) p.handsSeen += 1;
  }

  s.board = <Card>[];
  s.pot = 0;
  s.currentBet = s.bigBlind;
  s.lastRaiseSize = s.bigBlind;
  s.aggressor = null;
  s.summary = null;
  s.street = Street.preflop;
  s.phase = GamePhase.betting;
  s.botRanges = <int, List<HandLabel>>{};
  _assignPositions(s);

  s.deck = shuffle(makeDeck(), rng: rng);
  for (final p in s.players) {
    if (p.sittingOut) continue;
    final a = s.deck.removeLast();
    final b = s.deck.removeLast();
    p.hole = <Card>[a, b];
  }
  s.stacksAtStart = s.players.map((p) => p.stack).toList();

  // Antes (if configured) go straight to the pot: they count toward
  // side-pot totals but never toward matching the current street bet.
  final ante = s.config.ante;
  if (ante > 0) {
    for (final p in s.players) {
      if (p.sittingOut) continue;
      final a = min(ante, p.stack);
      p.stack -= a;
      p.committedTotal += a;
      s.pot += a;
      if (p.stack == 0) p.isAllIn = true;
    }
  }

  // Blinds and the first actor count round the players still in the game, so
  // a table that has played down to three deals like a three-handed table.
  final order = _orderFromButton(s);
  final headsUp = order.length == 2;
  final sbSeat = headsUp ? order[0] : order[1 % order.length];
  final bbSeat = headsUp ? order[1] : order[2 % order.length];
  _postBlind(s, sbSeat, s.smallBlind, 'SB');
  _postBlind(s, bbSeat, s.bigBlind, 'BB');
  s.aggressor = bbSeat;

  _pushLog(
    s,
    Street.preflop,
    'Hand #${s.handNumber} · blinds ${s.smallBlind}/${s.bigBlind}'
    '${ante > 0 ? ' · ante $ante' : ''}',
    LogKind.deal,
  );

  s.toAct =
      headsUp
          ? _nextLiveActor(s, sbSeat, true)
          : _nextLiveActor(s, order[3 % order.length], true);
  return s;
}

/// First seat from `start` (inclusive optional) that can still act.
int? _nextLiveActor(TableState s, int start, bool inclusive) {
  final n = s.config.seats;
  for (int k = inclusive ? 0 : 1; k < n + (inclusive ? 0 : 1); k++) {
    final q = (start + k) % n;
    final p = s.players[q];
    if (!p.hasFolded && !p.isAllIn) return q;
  }
  return null;
}

int? _nextToAct(TableState s, int fromSeat) {
  final n = s.config.seats;
  for (int k = 1; k <= n; k++) {
    final q = (fromSeat + k) % n;
    final p = s.players[q];
    if (p.hasFolded || p.isAllIn) continue;
    if (!p.acted || p.committed < s.currentBet) return q;
  }
  return null;
}

void _resetActedExcept(TableState s, int seat) {
  for (final p in s.players) {
    if (p.id == seat) continue;
    if (!p.hasFolded && !p.isAllIn) p.acted = false;
  }
}

/// What the seat to act may do. All-false/zero when nobody is to act.
LegalActions legalActions(TableState s) {
  final seat = s.toAct;
  if (seat == null) {
    return LegalActions(
      toCall: 0,
      canFold: false,
      canCheck: false,
      canCall: false,
      callAmount: 0,
      canBet: false,
      canRaise: false,
      minRaiseTo: 0,
      maxRaiseTo: 0,
      potSize: s.pot,
      bigBlind: s.bigBlind,
    );
  }
  final p = s.players[seat];
  final toCall = s.currentBet - p.committed;
  final maxTotal = p.committed + p.stack;
  return LegalActions(
    toCall: toCall,
    canFold: true,
    canCheck: toCall <= 0,
    canCall: toCall > 0 && p.stack > 0,
    callAmount: min(toCall, p.stack),
    canBet: s.currentBet == 0 && p.stack > 0,
    canRaise: s.currentBet > 0 && p.stack > toCall,
    minRaiseTo:
        s.currentBet == 0
            ? min(s.bigBlind, maxTotal)
            : min(s.currentBet + s.lastRaiseSize, maxTotal),
    maxRaiseTo: maxTotal,
    potSize: s.pot,
    bigBlind: s.bigBlind,
  );
}

/// Apply `action` for `seat` and advance the hand. Returns an unchanged copy
/// when it is not `seat`'s turn or the table is not in the betting phase.
/// Legality is NOT validated here — callers must obey [legalActions].
TableState applyAction(TableState prev, int seat, Action action) {
  final s = prev.clone();
  if (s.phase != GamePhase.betting || s.toAct != seat) return s;
  final p = s.players[seat];
  final toCall = s.currentBet - p.committed;
  final maxTotal = p.committed + p.stack;

  switch (action.type) {
    case ActionType.fold:
      p.hasFolded = true;
      p.foldedStreet = s.street;
      p.acted = true;
      p.lastAction = PlayerLastAction('Fold', s.street);
      _pushLog(s, s.street, '${p.name} folds', LogKind.action);
    case ActionType.check:
      p.acted = true;
      p.lastAction = PlayerLastAction('Check', s.street);
      _pushLog(s, s.street, '${p.name} checks', LogKind.action);
    case ActionType.call:
      if (s.street == Street.preflop && !p.vpipThisHand) {
        p.vpipThisHand = true;
        p.vpipCount += 1;
      }
      final amt = min(toCall, p.stack);
      _commit(s, p, amt);
      p.acted = true;
      p.lastAction = PlayerLastAction(p.isAllIn ? 'All-In' : 'Call', s.street);
      _pushLog(
        s,
        s.street,
        '${p.name} calls $amt${p.isAllIn ? ' (all-in)' : ''}',
        LogKind.action,
      );
    case ActionType.bet:
      if (s.street == Street.preflop) {
        if (!p.vpipThisHand) {
          p.vpipThisHand = true;
          p.vpipCount += 1;
        }
        if (!p.pfrThisHand) {
          p.pfrThisHand = true;
          p.pfrCount += 1;
        }
      }
      int to = max(action.amount ?? 0, min(s.bigBlind, maxTotal));
      to = min(to, maxTotal);
      _commit(s, p, to - p.committed);
      s.currentBet = to;
      s.lastRaiseSize = to;
      s.aggressor = seat;
      _resetActedExcept(s, seat);
      p.acted = true;
      p.lastAction = PlayerLastAction(p.isAllIn ? 'All-In' : 'Bet', s.street);
      _pushLog(
        s,
        s.street,
        '${p.name} bets $to${p.isAllIn ? ' (all-in)' : ''}',
        LogKind.action,
      );
    case ActionType.raise:
      if (s.street == Street.preflop) {
        if (!p.vpipThisHand) {
          p.vpipThisHand = true;
          p.vpipCount += 1;
        }
        if (!p.pfrThisHand) {
          p.pfrThisHand = true;
          p.pfrCount += 1;
        }
      }
      int to = action.amount ?? (s.currentBet + s.lastRaiseSize);
      to = min(to, maxTotal);
      final raiseSize = to - s.currentBet;
      _commit(s, p, to - p.committed);
      final fullRaise = raiseSize >= s.lastRaiseSize;
      if (to > s.currentBet) s.currentBet = to;
      if (fullRaise) {
        s.lastRaiseSize = raiseSize;
        _resetActedExcept(s, seat);
      }
      s.aggressor = seat;
      p.acted = true;
      p.lastAction = PlayerLastAction(p.isAllIn ? 'All-In' : 'Raise', s.street);
      _pushLog(
        s,
        s.street,
        '${p.name} raises to $to${p.isAllIn ? ' (all-in)' : ''}',
        LogKind.action,
      );
    case ActionType.post:
      break;
  }

  _advanceAfterAction(s, seat);
  return s;
}

void _advanceAfterAction(TableState s, int seat) {
  final live = s.players.where((p) => !p.hasFolded).toList();
  if (live.length == 1) {
    _settleByFold(s, live[0].id);
    return;
  }
  final n = _nextToAct(s, seat);
  if (n != null) {
    s.toAct = n;
    return;
  }
  _closeStreet(s);
}

void _burnDeal(TableState s, int count) {
  s.deck.removeLast(); // burn
  for (int i = 0; i < count; i++) {
    s.board.add(s.deck.removeLast());
  }
}

void _closeStreet(TableState s) {
  if (s.street == Street.river) {
    _settleShowdown(s);
    return;
  }
  if (s.street == Street.preflop) {
    _burnDeal(s, 3);
    s.street = Street.flop;
  } else if (s.street == Street.flop) {
    _burnDeal(s, 1);
    s.street = Street.turn;
  } else if (s.street == Street.turn) {
    _burnDeal(s, 1);
    s.street = Street.river;
  }

  for (final p in s.players) {
    p.committed = 0;
    p.acted = false;
    if (!p.hasFolded && !p.isAllIn) p.lastAction = null;
  }
  s.currentBet = 0;
  s.lastRaiseSize = s.bigBlind;
  s.aggressor = null;
  _pushLog(
    s,
    s.street,
    '${_capitalize(s.street.label)} — ${s.board.join(' ')}',
    LogKind.deal,
  );

  final canAct = s.players.where((p) => !p.hasFolded && !p.isAllIn).length;
  if (canAct <= 1) {
    _closeStreet(s); // run out remaining streets, then showdown
    return;
  }
  s.toAct = _nextLiveActor(s, _seatAtOffset(s, 1), true);
}

int _seatOrderFromButton(TableState s, int id) =>
    (id - s.button - 1 + s.config.seats) % s.config.seats;

/// One player's total contribution to the hand, for side-pot construction.
class PotContribution {
  const PotContribution({
    required this.id,
    required this.amt,
    required this.folded,
  });
  final int id;
  final int amt;
  final bool folded;
}

/// A pot level before the winners are known.
class RawPot {
  const RawPot({required this.amount, required this.eligible});
  final int amount;
  final List<int> eligible;

  @override
  String toString() => 'RawPot($amount, $eligible)';
}

class PotBreakdown {
  const PotBreakdown({required this.pots, this.uncalled});
  final List<RawPot> pots;

  /// Set when the last bet went uncalled and came back to its owner.
  final UncalledBet? uncalled;
}

/// The top of the last bet, when only one player put it in, was never called:
/// the dealer pushes it straight back, so it is not part of any pot. A folded
/// top contributor is a different thing — those chips are dead money and stay
/// in, which is why this only fires for a live player.
({List<PotContribution> rest, UncalledBet? uncalled}) _takeUncalled(
  List<PotContribution> contribs,
) {
  final live = contribs.where((c) => c.amt > 0).toList();
  if (live.length < 2) return (rest: contribs, uncalled: null);
  final byAmt = List<PotContribution>.of(live)..sort((a, b) => b.amt - a.amt);
  final top = byAmt[0];
  final second = byAmt[1];
  if (top.folded || top.amt <= second.amt) {
    return (rest: contribs, uncalled: null);
  }
  return (
    rest: [
      for (final c in contribs)
        if (c.id == top.id)
          PotContribution(id: c.id, amt: second.amt, folded: c.folded)
        else
          c,
    ],
    uncalled: UncalledBet(
      playerId: top.id,
      amount: top.amt - second.amt,
      inPot: false,
    ),
  );
}

bool _sameEligible(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Split total contributions into main + side pots.
///
/// A side pot exists to separate chips a short all-in player cannot win, so a
/// new one starts only where the set of players eligible for it changes.
/// Consecutive betting levels contested by exactly the same people are one
/// pot — splitting on every level turned a single three-way all-in into
/// "Main pot / Side pot 1 / Side pot 2 / Side pot 3", which reads like three
/// separate contests that never happened.
///
/// Folded players' chips are dead money in whichever level they reached; a
/// level with no live player rolls forward into the next one.
PotBreakdown buildSidePots(List<PotContribution> contribs) {
  final taken = _takeUncalled(contribs);
  var rem = taken.rest.where((c) => c.amt > 0).toList();
  final pots = <RawPot>[];
  int carry = 0;
  while (rem.isNotEmpty) {
    int mn = rem[0].amt;
    for (final c in rem) {
      if (c.amt < mn) mn = c.amt;
    }
    final amount = mn * rem.length + carry;
    final eligible = rem.where((c) => !c.folded).map((c) => c.id).toList();
    if (eligible.isEmpty) {
      carry = amount; // dead money rolls forward
    } else {
      carry = 0;
      if (pots.isNotEmpty && _sameEligible(pots.last.eligible, eligible)) {
        pots[pots.length - 1] = RawPot(
          amount: pots.last.amount + amount,
          eligible: eligible,
        );
      } else {
        pots.add(RawPot(amount: amount, eligible: eligible));
      }
    }
    rem =
        rem
            .map(
              (c) =>
                  PotContribution(id: c.id, amt: c.amt - mn, folded: c.folded),
            )
            .where((c) => c.amt > 0)
            .toList();
  }
  // Dead money with no level above it to join (only reachable when a folded
  // player out-contributed everyone still live) belongs to the last real pot
  // rather than vanishing off the table.
  if (carry > 0 && pots.isNotEmpty) {
    pots[pots.length - 1] = RawPot(
      amount: pots.last.amount + carry,
      eligible: pots.last.eligible,
    );
  }
  return PotBreakdown(pots: pots, uncalled: taken.uncalled);
}

void _settleByFold(TableState s, int winnerId) {
  final w = s.players[winnerId];
  final amount = s.pot;
  w.stack += amount;
  // Everyone folded, so the top of the winner's own bet was never called.
  // The pot result still reports the whole pot — the number the table has
  // been showing all hand — but the refund is recorded so the hand history
  // can account for it exactly instead of re-deriving it.
  int matched = 0;
  for (final p in s.players) {
    if (p.id != winnerId && p.committedTotal > matched) {
      matched = p.committedTotal;
    }
  }
  final excess = w.committedTotal - matched;
  s.summary = HandSummary(
    handNumber: s.handNumber,
    potResults: [
      PotResult(winners: [winnerId], amount: amount, potLabel: 'Pot'),
    ],
    showdown: const [],
    board: List<Card>.of(s.board),
    heroNetChips: s.players[0].stack - s.stacksAtStart[0],
    uncalled:
        excess > 0
            ? UncalledBet(playerId: winnerId, amount: excess, inPot: true)
            : null,
  );
  _pushLog(s, s.street, '${w.name} wins $amount (uncontested)', LogKind.result);
  // Learning reveal: at hand end every dealt hand is shown, folds included.
  for (final p in s.players) {
    if (p.hole != null) p.revealed = true;
  }
  s.toAct = null;
  s.phase = GamePhase.handOver;
}

void _settleShowdown(TableState s) {
  final liveIds =
      s.players.where((p) => !p.hasFolded).map((p) => p.id).toList();
  // Learning reveal: at hand end every dealt hand is shown, folds included.
  for (final p in s.players) {
    if (p.hole != null) p.revealed = true;
  }

  final evals = <int, EvaluatedHand>{};
  for (final id in liveIds) {
    final p = s.players[id];
    evals[id] = evaluateCards([...p.hole!, ...s.board]);
  }

  final contribs =
      s.players
          .map(
            (p) => PotContribution(
              id: p.id,
              amt: p.committedTotal,
              folded: p.hasFolded,
            ),
          )
          .toList();
  final breakdown = buildSidePots(contribs);
  final pots = breakdown.pots;
  final uncalled = breakdown.uncalled;
  final potResults = <PotResult>[];

  // The uncalled chips go back before anything is awarded, exactly as a
  // dealer returns them — they were never anybody's to win.
  if (uncalled != null) {
    s.players[uncalled.playerId].stack += uncalled.amount;
    _pushLog(
      s,
      Street.showdown,
      '${s.players[uncalled.playerId].name} gets ${uncalled.amount} back '
      '(uncalled bet)',
      LogKind.result,
    );
  }

  for (int idx = 0; idx < pots.length; idx++) {
    final pot = pots[idx];
    final contenders =
        pot.eligible.where((id) => liveIds.contains(id)).toList();
    if (contenders.isEmpty) continue;
    int best = -1;
    var winners = <int>[];
    for (final id in contenders) {
      final sc = evals[id]!.score;
      if (sc > best) {
        best = sc;
        winners = [id];
      } else if (sc == best) {
        winners.add(id);
      }
    }
    final share = pot.amount ~/ winners.length;
    final rem = pot.amount - share * winners.length;
    for (final id in winners) {
      s.players[id].stack += share;
    }
    if (rem > 0) {
      final sorted = List<int>.of(winners)..sort(
        (a, b) => _seatOrderFromButton(s, a) - _seatOrderFromButton(s, b),
      );
      s.players[sorted[0]].stack += rem;
    }
    potResults.add(
      PotResult(
        winners: winners,
        amount: pot.amount,
        potLabel:
            pots.length > 1 ? (idx == 0 ? 'Main pot' : 'Side pot $idx') : 'Pot',
      ),
    );
  }

  final showdown =
      liveIds
          .map(
            (id) => ShowdownEntry(
              playerId: id,
              hole: List<Card>.of(s.players[id].hole!),
              hand: evals[id],
              hadToShow: true,
            ),
          )
          .toList();

  s.summary = HandSummary(
    handNumber: s.handNumber,
    potResults: potResults,
    showdown: showdown,
    board: List<Card>.of(s.board),
    heroNetChips: s.players[0].stack - s.stacksAtStart[0],
    uncalled: uncalled,
  );
  for (final pr in potResults) {
    _pushLog(
      s,
      Street.showdown,
      '${pr.winners.map((id) => s.players[id].name).join(', ')} '
      'wins ${pr.amount} (${pr.potLabel})',
      LogKind.result,
    );
  }
  s.toAct = null;
  s.phase = GamePhase.handOver;
}

/* ---- Small read helpers used by the store / UI ---- */

Player heroSeat(TableState s) => s.players[0];

/// Seats in order button+1 … button+n (mod n).
List<Player> playersLeftOfButtonOrder(TableState s) {
  final n = s.config.seats;
  final out = <Player>[];
  for (int k = 1; k <= n; k++) {
    out.add(s.players[(s.button + k) % n]);
  }
  return out;
}

bool isHeroTurn(TableState s) => s.phase == GamePhase.betting && s.toAct == 0;
