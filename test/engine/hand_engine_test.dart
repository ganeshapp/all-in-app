import 'dart:math';

import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

/* ------------------------------------------------------------------
   Reference outputs below were computed by driving the desktop
   TypeScript engine (src/game/engine.ts) through the same scripted
   scenarios with Node 23 (`node --experimental-transform-types`), with
   the deck and hole cards overridden after `startHand` so the shuffle
   does not matter.
   ------------------------------------------------------------------ */

const GameConfig _cfg6 = GameConfig(
  seats: 6,
  startingStack: 2000,
  smallBlind: 10,
  bigBlind: 20,
);

/// Deck tail (cards come off the END): burn 2d, flop 8d 9d Qd, burn 3h,
/// turn Th, burn 2s, river 3s.
const List<Card> _deckStraight = [
  '2c', '3d', '4h', '5s', '6c', '7d', '8h', '9s', 'Tc', 'Jd', //
  '3s', '2s', 'Th', '3h', 'Qd', '9d', '8d', '2d',
];

/// burn Qd, flop Kd Ad 7c, burn 2s, turn 9h, burn Ks, river Qh.
const List<Card> _deckBroadway = [
  '2c', '3d', '4h', '5s', '6c', '7d', '8h', '9s', 'Tc', 'Jd', 'Qh', 'Ks', //
  '9h', '2s', '7c', 'Ad', 'Kd', 'Qd',
];

const List<List<Card>> _holesPairs = [
  ['As', 'Ah'],
  ['Kc', 'Kh'],
  ['Qs', 'Qc'],
  ['Js', 'Jc'],
  ['2h', '3h'],
  ['8c', '8d'],
];

const List<List<Card>> _holesJacks = [
  ['Jh', '2h'],
  ['Jc', '4c'],
  ['Js', '5c'],
  ['Ac', 'Kc'],
  ['6h', '7h'],
  ['Ah', 'Kh'],
];

TableState _setup(
  int seats,
  List<int> stacks,
  List<List<Card>> holes,
  List<Card> deckRest, {
  int ante = 0,
  int button = 0,
}) {
  var s = createTable(
    GameConfig(
      seats: seats,
      startingStack: 2000,
      smallBlind: 10,
      bigBlind: 20,
      ante: ante,
    ),
    rng: Random(1),
  );
  s.button = button;
  for (int i = 0; i < seats; i++) {
    s.players[i].stack = stacks[i];
  }
  s = startHand(s, rng: Random(7));
  s.deck = List<Card>.of(deckRest);
  for (int i = 0; i < seats; i++) {
    s.players[i].hole = List<Card>.of(holes[i]);
  }
  return s;
}

TableState _run(TableState s, List<(int, Action)> script) {
  for (final (seat, a) in script) {
    expect(s.toAct, seat, reason: 'expected seat $seat to act');
    s = applyAction(s, seat, a);
  }
  return s;
}

List<String> _logLines(TableState s) =>
    s.log.map((l) => '${l.street.label}|${l.kind.name}|${l.text}').toList();

List<int> _stacks(TableState s) => s.players.map((p) => p.stack).toList();

List<List<Object>> _pots(TableState s) =>
    s.summary!.potResults
        .map((p) => <Object>[p.winners, p.amount, p.potLabel])
        .toList();

/// Picks a random legal action (the sim tests have no bot brain).
Action _randomLegal(TableState s, Random rng) {
  final la = legalActions(s);
  final options = <Action>[];
  if (la.canCheck) options.add(const Action.check());
  if (la.canCall) {
    options.add(const Action.call());
    options.add(const Action.call());
  }
  if (la.toCall > 0) options.add(const Action.fold());
  if (la.canBet || la.canRaise) {
    final lo = la.minRaiseTo;
    final hi = la.maxRaiseTo;
    final amt = lo + rng.nextInt(hi - lo + 1);
    options.add(la.canBet ? Action.bet(amt) : Action.raise(amt));
  }
  return options[rng.nextInt(options.length)];
}

void main() {
  group('createTable', () {
    test('seats, names, archetypes, initial fields', () {
      final s = createTable(_cfg6, rng: Random(3));
      expect(s.players.length, 6);
      expect(s.players[0].name, 'You');
      expect(s.players[0].isHero, isTrue);
      expect(s.players[0].archetype, isNull);
      expect(s.players[1].name, 'Ivey');
      expect(s.players[1].archetype, Archetype.tag);
      expect(s.players[2].archetype, Archetype.station);
      expect(s.players[5].name, 'Hellmuth');
      for (final p in s.players) {
        expect(p.stack, 2000);
        expect(p.hole, isNull);
        expect(p.position, Position.btn);
        expect(p.lastAction, isNull);
      }
      expect(s.button, inInclusiveRange(0, 5));
      expect(s.phase, GamePhase.idle);
      expect(s.handNumber, 0);
      expect(s.currentBet, 0);
      expect(s.lastRaiseSize, 20);
      expect(s.logSeq, 1);
      expect(s.log, isEmpty);
      expect(s.stacksAtStart, [2000, 2000, 2000, 2000, 2000, 2000]);
      expect(s.summary, isNull);
      expect(s.toAct, isNull);
      expect(legalActions(s).canFold, isFalse);
      expect(legalActions(s).potSize, 0);
      expect(legalActions(s).bigBlind, 20);
    });

    test('button is seeded via rng', () {
      final a = createTable(_cfg6, rng: Random(42));
      final b = createTable(_cfg6, rng: Random(42));
      expect(a.button, b.button);
      expect(a.button, Random(42).nextInt(6));
    });
  });

  group('startHand', () {
    test('6-max blinds, positions, first actor, log line', () {
      final s = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesPairs,
        _deckStraight,
        button: 5,
      );
      expect(s.handNumber, 1);
      expect(s.button, 5, reason: 'hand #1 keeps the createTable button');
      expect(s.phase, GamePhase.betting);
      expect(s.players.map((p) => p.position.label).toList(), [
        'SB',
        'BB',
        'UTG',
        'MP',
        'CO',
        'BTN',
      ]);
      expect(s.players[0].committed, 10);
      expect(s.players[1].committed, 20);
      expect(s.players[0].lastAction!.label, 'SB');
      expect(s.players[1].lastAction!.label, 'BB');
      expect(s.pot, 30);
      expect(s.currentBet, 20);
      expect(s.lastRaiseSize, 20);
      expect(s.aggressor, 1);
      expect(s.toAct, 2);
      expect(_logLines(s), ['preflop|deal|Hand #1 · blinds 10/20']);
      expect(s.players.every((p) => p.handsSeen == 1), isTrue);
      expect(s.deck.length, _deckStraight.length, reason: 'deck overridden');
      final la = legalActions(s);
      expect(la.toCall, 20);
      expect(la.canFold, isTrue);
      expect(la.canCheck, isFalse);
      expect(la.canCall, isTrue);
      expect(la.callAmount, 20);
      expect(la.canBet, isFalse);
      expect(la.canRaise, isTrue);
      expect(la.minRaiseTo, 40);
      expect(la.maxRaiseTo, 2000);
      expect(la.potSize, 30);
    });

    test('deal order: each seat takes two cards off the end of the deck', () {
      final s = startHand(createTable(_cfg6, rng: Random(1)), rng: Random(9));
      final deck = List<Card>.of(s.deck);
      final dealt = <Card>[];
      for (final p in s.players) {
        dealt.addAll(p.hole!);
      }
      expect(dealt.toSet().length, 12);
      expect(deck.length, 40);
      expect(deck.toSet().intersection(dealt.toSet()), isEmpty);
      // Reproducible with the same seed.
      final t = startHand(createTable(_cfg6, rng: Random(1)), rng: Random(9));
      expect(t.players[0].hole, s.players[0].hole);
      expect(t.deck, s.deck);
    });

    test('button advances after hand #1, auto-rebuy, stacksAtStart', () {
      var s = createTable(_cfg6, rng: Random(1));
      s.button = 2;
      s = startHand(s, rng: Random(1));
      expect(s.button, 2);
      s.players[4].stack = 0;
      s = startHand(s, rng: Random(2));
      expect(s.button, 3);
      expect(s.handNumber, 2);
      expect(s.players[4].handsSeen, 2);
      // Rebuy happens before stacksAtStart, blinds after.
      expect(s.stacksAtStart[4], 2000);
      expect(s.stacksAtStart.length, 6);
      expect(s.summary, isNull);
      expect(s.botRanges, isEmpty);
    });

    test('heads-up: button posts the small blind and acts first', () {
      const cfg = GameConfig(
        seats: 2,
        startingStack: 2000,
        smallBlind: 10,
        bigBlind: 20,
      );
      for (final btn in [0, 1]) {
        var s = createTable(cfg, rng: Random(1));
        s.button = btn;
        s = startHand(s, rng: Random(1));
        final positions = s.players.map((p) => p.position).toList();
        expect(positions, contains(Position.btn));
        expect(positions, contains(Position.bb));
        final b = s.players.firstWhere((p) => p.position == Position.btn);
        expect(b.id, btn);
        expect(b.committed, 10);
        expect(b.lastAction!.label, 'SB');
        expect(s.toAct, b.id);
        expect(s.aggressor, 1 - btn);
      }
    });

    test('9-max positions', () {
      const cfg = GameConfig(
        seats: 9,
        startingStack: 2000,
        smallBlind: 10,
        bigBlind: 20,
      );
      var s = createTable(cfg, rng: Random(1));
      s.button = 4;
      s = startHand(s, rng: Random(1));
      expect(s.players.map((p) => p.position.label).toList(), [
        'MP', // off 5
        'MP', // off 6
        'CO', // off 7
        'CO', // off 8
        'BTN',
        'SB',
        'BB',
        'UTG',
        'UTG',
      ]);
      expect(s.players.where((p) => p.position == Position.btn).length, 1);
      expect(s.players.map((p) => p.position).toSet().length, 6);
      expect(s.toAct, 7);
      expect(s.players[5].committed, 10);
      expect(s.players[6].committed, 20);
    });

    test('unsupported seat count falls back to BTN/SB/BB/MP', () {
      const cfg = GameConfig(
        seats: 4,
        startingStack: 2000,
        smallBlind: 10,
        bigBlind: 20,
      );
      var s = createTable(cfg, rng: Random(1));
      s.button = 1;
      s = startHand(s, rng: Random(1));
      expect(s.players.map((p) => p.position.label).toList(), [
        'MP',
        'BTN',
        'SB',
        'BB',
      ]);
    });

    test('antes: pot + committedTotal, not committed; log suffix', () {
      final s = _setup(
        6,
        [2000, 2000, 2000, 100, 2000, 2000],
        _holesPairs,
        _deckStraight,
        ante: 5,
        button: 2,
      );
      expect(s.pot, 10 + 20 + 5 * 6);
      expect(_logLines(s), ['preflop|deal|Hand #1 · blinds 10/20 · ante 5']);
      final nonBlind = s.players[0];
      expect(nonBlind.committed, 0);
      expect(nonBlind.committedTotal, 5);
      expect(nonBlind.stack, 1995);
      expect(s.players[3].committed, 10);
      expect(s.players[3].committedTotal, 15);
      expect(s.players[3].stack, 85);
      expect(s.stacksAtStart[3], 100, reason: 'captured before antes');
      expect(s.toAct, 5);
    });

    test('short stack ante puts the player all-in', () {
      final s = _setup(
        6,
        [2000, 2000, 2000, 2000, 3, 2000],
        _holesPairs,
        _deckStraight,
        ante: 5,
        button: 0,
      );
      expect(s.players[4].stack, 0);
      expect(s.players[4].isAllIn, isTrue);
      expect(s.players[4].committedTotal, 3);
      expect(s.toAct, 3);
    });
  });

  group('scenario A: 3-way all-in with side pots + dead money', () {
    test('matches the desktop split', () {
      final s0 = _setup(
        6,
        [2000, 300, 800, 1500, 2000, 2000],
        _holesPairs,
        _deckBroadway,
      );
      final s = _run(s0, [
        (3, const Action.raise(1500)),
        (4, const Action.fold()),
        (5, const Action.call()),
        (0, const Action.fold()),
        (1, const Action.call()),
        (2, const Action.call()),
      ]);
      expect(s.phase, GamePhase.handOver);
      expect(s.pot, 4100);
      expect(s.board, ['Kd', 'Ad', '7c', '9h', 'Qh']);
      expect(s.street, Street.river);
      expect(_stacks(s), [2000, 1200, 1500, 1400, 2000, 500]);
      expect(s.players.map((p) => p.committedTotal).toList(), [
        0,
        300,
        800,
        1500,
        0,
        1500,
      ]);
      expect(_pots(s), [
        [
          [1],
          1200,
          'Main pot',
        ],
        [
          [2],
          1500,
          'Side pot 1',
        ],
        [
          [3],
          1400,
          'Side pot 2',
        ],
      ]);
      expect(s.summary!.heroNetChips, 0);
      expect(s.summary!.showdown.map((e) => e.playerId).toList(), [1, 2, 3, 5]);
      expect(s.summary!.showdown.map((e) => e.hand!.name).toList(), [
        'Three of a Kind, Kings',
        'Three of a Kind, Queens',
        'Pair of Jacks',
        'Pair of Eights',
      ]);
      expect(s.summary!.showdown.map((e) => e.hand!.score).toList(), [
        4058112,
        3992832,
        1830336,
        1633728,
      ]);
      expect(s.summary!.showdown.every((e) => e.hadToShow), isTrue);
      expect(s.summary!.board, s.board);
      expect(_logLines(s), [
        'preflop|deal|Hand #1 · blinds 10/20',
        'preflop|action|Polk raises to 1500 (all-in)',
        'preflop|action|Selbst folds',
        'preflop|action|Hellmuth calls 1500',
        'preflop|action|You folds',
        'preflop|action|Ivey calls 290 (all-in)',
        'preflop|action|Negreanu calls 780 (all-in)',
        'flop|deal|Flop — Kd Ad 7c',
        'turn|deal|Turn — Kd Ad 7c 9h',
        'river|deal|River — Kd Ad 7c 9h Qh',
        'showdown|result|Ivey wins 1200 (Main pot)',
        'showdown|result|Negreanu wins 1500 (Side pot 1)',
        'showdown|result|Polk wins 1400 (Side pot 2)',
      ]);
      expect(s.players.map((p) => p.vpipCount).toList(), [0, 1, 1, 1, 0, 1]);
      expect(s.players.map((p) => p.pfrCount).toList(), [0, 0, 0, 1, 0, 0]);
      expect(s.players.map((p) => p.lastAction?.label).toList(), [
        'Fold',
        'All-In',
        'All-In',
        'All-In',
        'Fold',
        null,
      ]);
      expect(s.players.every((p) => p.revealed), isTrue);
      expect(s.players[0].foldedStreet, Street.preflop);
      expect(s.toAct, isNull);
    });
  });

  group('scenario B: heads-up chopped pot', () {
    test('splits evenly, full log', () {
      final s0 = _setup(
        2,
        [2000, 2000],
        [
          ['Jh', '2h'],
          ['Jc', '4c'],
        ],
        _deckStraight,
      );
      final s = _run(s0, [
        (0, const Action.raise(55)),
        (1, const Action.call()),
        (1, const Action.check()),
        (0, const Action.check()),
        (1, const Action.check()),
        (0, const Action.check()),
        (1, const Action.check()),
        (0, const Action.check()),
      ]);
      expect(s.phase, GamePhase.handOver);
      expect(s.pot, 110);
      expect(_stacks(s), [2000, 2000]);
      expect(_pots(s), [
        [
          [0, 1],
          110,
          'Pot',
        ],
      ]);
      expect(s.summary!.showdown.map((e) => e.hand!.name).toList(), [
        'Straight, Queen high',
        'Straight, Queen high',
      ]);
      expect(_logLines(s), [
        'preflop|deal|Hand #1 · blinds 10/20',
        'preflop|action|You raises to 55',
        'preflop|action|Ivey calls 35',
        'flop|deal|Flop — 8d 9d Qd',
        'flop|action|Ivey checks',
        'flop|action|You checks',
        'turn|deal|Turn — 8d 9d Qd Th',
        'turn|action|Ivey checks',
        'turn|action|You checks',
        'river|deal|River — 8d 9d Qd Th 3s',
        'river|action|Ivey checks',
        'river|action|You checks',
        'showdown|result|You, Ivey wins 110 (Pot)',
      ]);
      expect(s.players.map((p) => p.position.label).toList(), ['BTN', 'BB']);
      expect(s.players.map((p) => p.vpipCount).toList(), [1, 1]);
      expect(s.players.map((p) => p.pfrCount).toList(), [1, 0]);
      expect(s.players.map((p) => p.lastAction?.label).toList(), [
        'Check',
        'Check',
      ]);
    });
  });

  group('scenario C: short all-in raise does not reopen action', () {
    test('utg may still call/raise; btn is not re-asked', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 70, 2000],
        _holesPairs,
        _deckStraight,
      );
      final mid = _run(s0, [
        (3, const Action.raise(60)),
        (4, const Action.raise(70)),
        (5, const Action.fold()),
        (0, const Action.call()),
        (1, const Action.fold()),
        (2, const Action.fold()),
      ]);
      expect(mid.toAct, 3);
      expect(mid.currentBet, 70);
      expect(mid.lastRaiseSize, 40, reason: 'short raise keeps lastRaiseSize');
      expect(mid.aggressor, 4);
      final la = legalActions(mid);
      expect(la.toCall, 10);
      expect(la.callAmount, 10);
      expect(la.canCheck, isFalse);
      expect(la.canRaise, isTrue);
      expect(la.minRaiseTo, 110);
      expect(la.maxRaiseTo, 2000);
      expect(la.potSize, 230);
      final s = _run(mid, [(3, const Action.call())]);
      expect(s.phase, GamePhase.betting);
      expect(s.street, Street.flop);
      expect(s.pot, 240);
      expect(s.board, ['8d', '9d', 'Qd']);
      expect(_stacks(s), [1930, 1990, 1980, 1930, 0, 2000]);
      expect(s.toAct, 3, reason: 'SB/BB folded; UTG is first live seat');
      expect(s.currentBet, 0);
      expect(s.lastRaiseSize, 20);
      expect(s.aggressor, isNull);
      expect(_logLines(s), [
        'preflop|deal|Hand #1 · blinds 10/20',
        'preflop|action|Polk raises to 60',
        'preflop|action|Selbst raises to 70 (all-in)',
        'preflop|action|Hellmuth folds',
        'preflop|action|You calls 70',
        'preflop|action|Ivey folds',
        'preflop|action|Negreanu folds',
        'preflop|action|Polk calls 10',
        'flop|deal|Flop — 8d 9d Qd',
      ]);
      expect(s.players.map((p) => p.lastAction?.label).toList(), [
        null,
        'Fold',
        'Fold',
        null,
        'All-In',
        'Fold',
      ]);
      expect(s.players.map((p) => p.vpipCount).toList(), [1, 0, 0, 1, 1, 0]);
      expect(s.players.map((p) => p.pfrCount).toList(), [0, 0, 0, 1, 1, 0]);
      expect(s.players.every((p) => !p.revealed), isTrue);
      expect(s.players.every((p) => p.committed == 0), isTrue);
    });
  });

  group('scenario D: antes + multi-street with a short all-in', () {
    test('five pot levels split as on desktop', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 100, 2000, 2000],
        _holesPairs,
        _deckStraight,
        ante: 5,
        button: 2,
      );
      final s = _run(s0, [
        (5, const Action.raise(60)),
        (0, const Action.raise(200)),
        (1, const Action.fold()),
        (2, const Action.call()),
        (3, const Action.call()),
        (4, const Action.fold()),
        (5, const Action.call()),
        (5, const Action.check()),
        (0, const Action.bet(300)),
        (2, const Action.fold()),
        (5, const Action.call()),
        (5, const Action.check()),
        (0, const Action.check()),
        (5, const Action.bet(100)),
        (0, const Action.call()),
      ]);
      expect(s.phase, GamePhase.handOver);
      expect(s.pot, 1545);
      expect(_stacks(s), [1395, 1995, 1795, 430, 1975, 2510]);
      expect(s.players.map((p) => p.committedTotal).toList(), [
        605,
        5,
        205,
        100,
        25,
        605,
      ]);
      expect(_pots(s), [
        [
          [3],
          30,
          'Main pot',
        ],
        [
          [3],
          100,
          'Side pot 1',
        ],
        [
          [3],
          300,
          'Side pot 2',
        ],
        [
          [5],
          315,
          'Side pot 3',
        ],
        [
          [5],
          800,
          'Side pot 4',
        ],
      ]);
      expect(s.summary!.heroNetChips, -605);
      expect(s.summary!.showdown.map((e) => e.playerId).toList(), [0, 3, 5]);
      expect(s.summary!.showdown.map((e) => e.hand!.name).toList(), [
        'Pair of Aces',
        'Straight, Queen high',
        'Three of a Kind, Eights',
      ]);
      expect(s.players.map((p) => p.position.label).toList(), [
        'MP',
        'CO',
        'BTN',
        'SB',
        'BB',
        'UTG',
      ]);
      expect(_logLines(s), [
        'preflop|deal|Hand #1 · blinds 10/20 · ante 5',
        'preflop|action|Hellmuth raises to 60',
        'preflop|action|You raises to 200',
        'preflop|action|Ivey folds',
        'preflop|action|Negreanu calls 200',
        'preflop|action|Polk calls 85 (all-in)',
        'preflop|action|Selbst folds',
        'preflop|action|Hellmuth calls 140',
        'flop|deal|Flop — 8d 9d Qd',
        'flop|action|Hellmuth checks',
        'flop|action|You bets 300',
        'flop|action|Negreanu folds',
        'flop|action|Hellmuth calls 300',
        'turn|deal|Turn — 8d 9d Qd Th',
        'turn|action|Hellmuth checks',
        'turn|action|You checks',
        'river|deal|River — 8d 9d Qd Th 3s',
        'river|action|Hellmuth bets 100',
        'river|action|You calls 100',
        'showdown|result|Polk wins 30 (Main pot)',
        'showdown|result|Polk wins 100 (Side pot 1)',
        'showdown|result|Polk wins 300 (Side pot 2)',
        'showdown|result|Hellmuth wins 315 (Side pot 3)',
        'showdown|result|Hellmuth wins 800 (Side pot 4)',
      ]);
      expect(s.players.map((p) => p.lastAction?.label).toList(), [
        'Call',
        'Fold',
        'Fold',
        'All-In',
        'Fold',
        'Bet',
      ]);
      expect(s.players[2].foldedStreet, Street.flop);
      expect(s.players[1].foldedStreet, Street.preflop);
    });
  });

  group('scenario E: uncontested pot', () {
    test('settleByFold', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesPairs,
        _deckStraight,
        button: 5,
      );
      final s = _run(s0, [
        (2, const Action.raise(50)),
        (3, const Action.fold()),
        (4, const Action.fold()),
        (5, const Action.fold()),
        (0, const Action.fold()),
        (1, const Action.fold()),
      ]);
      expect(s.phase, GamePhase.handOver);
      expect(s.pot, 80, reason: 'pot is not zeroed at hand end');
      expect(s.board, isEmpty);
      expect(s.street, Street.preflop);
      expect(_stacks(s), [1990, 1980, 2030, 2000, 2000, 2000]);
      expect(_pots(s), [
        [
          [2],
          80,
          'Pot',
        ],
      ]);
      expect(s.summary!.showdown, isEmpty);
      expect(s.summary!.heroNetChips, -10);
      expect(s.summary!.handNumber, 1);
      expect(
        _logLines(s).last,
        'preflop|result|Negreanu wins 80 (uncontested)',
      );
      expect(s.players.every((p) => p.revealed), isTrue);
      expect(s.players.map((p) => p.lastAction?.label).toList(), [
        'Fold',
        'Fold',
        'Raise',
        'Fold',
        'Fold',
        'Fold',
      ]);
      expect(s.toAct, isNull);
      expect(isHeroTurn(s), isFalse);
      // Further actions are ignored once the hand is over.
      final t = applyAction(s, 2, const Action.check());
      expect(t.phase, GamePhase.handOver);
      expect(t.log.length, s.log.length);
    });
  });

  group('scenario G: odd chip goes to the first seat left of the button', () {
    test('button 4: seat 0 gets the extra chip', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesJacks,
        _deckStraight,
        button: 4,
      );
      final s = _run(s0, [
        (1, const Action.raise(50)),
        (2, const Action.call()),
        (3, const Action.fold()),
        (4, const Action.fold()),
        (5, const Action.fold()),
        (0, const Action.call()),
        (0, const Action.check()),
        (1, const Action.check()),
        (2, const Action.check()),
        (0, const Action.check()),
        (1, const Action.check()),
        (2, const Action.check()),
        (0, const Action.check()),
        (1, const Action.check()),
        (2, const Action.check()),
      ]);
      expect(s.pot, 160);
      expect(_stacks(s), [2004, 2003, 2003, 2000, 2000, 1990]);
      expect(_pots(s), [
        [
          [0, 1, 2],
          40,
          'Main pot',
        ],
        [
          [0, 1, 2],
          120,
          'Side pot 1',
        ],
      ]);
      expect(s.summary!.heroNetChips, 4);
      expect(_logLines(s).sublist(_logLines(s).length - 2), [
        'showdown|result|You, Ivey, Negreanu wins 40 (Main pot)',
        'showdown|result|You, Ivey, Negreanu wins 120 (Side pot 1)',
      ]);
    });

    test('button 0: no remainder with a 150 pot', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesJacks,
        _deckStraight,
        button: 0,
      );
      final s = _run(s0, [
        (3, const Action.fold()),
        (4, const Action.fold()),
        (5, const Action.fold()),
        (0, const Action.raise(50)),
        (1, const Action.call()),
        (2, const Action.call()),
        (1, const Action.check()),
        (2, const Action.check()),
        (0, const Action.check()),
        (1, const Action.check()),
        (2, const Action.check()),
        (0, const Action.check()),
        (1, const Action.check()),
        (2, const Action.check()),
        (0, const Action.check()),
      ]);
      expect(s.pot, 150);
      expect(_stacks(s), [2000, 2000, 2000, 2000, 2000, 2000]);
      expect(_pots(s), [
        [
          [0, 1, 2],
          150,
          'Pot',
        ],
      ]);
      expect(_logLines(s)[1], 'preflop|action|Polk folds');
      expect(_logLines(s)[4], 'preflop|action|You raises to 50');
      expect(_logLines(s)[5], 'preflop|action|Ivey calls 40');
      expect(_logLines(s)[6], 'preflop|action|Negreanu calls 30');
      expect(
        _logLines(s).last,
        'showdown|result|You, Ivey, Negreanu wins 150 (Pot)',
      );
    });
  });

  group('scenario H: amount clamps', () {
    const holes = [
      ['Jh', '2h'],
      ['Jc', '4c'],
    ];

    test('raise without amount = min raise; over-stack raise = all-in', () {
      final s0 = _setup(2, [500, 2000], holes, _deckStraight);
      var s = _run(s0, [(0, const Action(ActionType.raise))]);
      expect(s.currentBet, 40);
      expect(s.lastRaiseSize, 20);
      expect(s.toAct, 1);
      var la = legalActions(s);
      expect(la.toCall, 20);
      expect(la.minRaiseTo, 60);
      expect(la.maxRaiseTo, 2000);
      expect(la.potSize, 60);

      s = _run(s, [(1, const Action.raise(99999))]);
      expect(s.currentBet, 2000);
      expect(s.lastRaiseSize, 1960);
      expect(_stacks(s), [460, 0]);
      expect(s.players[1].isAllIn, isTrue);
      expect(s.toAct, 0);
      la = legalActions(s);
      expect(la.toCall, 1960);
      expect(la.canCall, isTrue);
      expect(la.callAmount, 460);
      expect(la.canRaise, isFalse);
      expect(la.minRaiseTo, 500);
      expect(la.maxRaiseTo, 500);
      expect(la.potSize, 2040);
      expect(s.log.map((l) => l.text).toList(), [
        'Hand #1 · blinds 10/20',
        'You raises to 40',
        'Ivey raises to 2000 (all-in)',
      ]);

      s = _run(s, [(0, const Action.call())]);
      expect(s.phase, GamePhase.handOver);
      expect(s.pot, 2500);
      expect(s.board, ['8d', '9d', 'Qd', 'Th', '3s']);
      expect(_stacks(s), [500, 2000]);
      expect(_pots(s), [
        [
          [0, 1],
          1000,
          'Main pot',
        ],
        [
          [1],
          1500,
          'Side pot 1',
        ],
      ]);
      expect(s.summary!.heroNetChips, 0);
      expect(_logLines(s).sublist(3), [
        'preflop|action|You calls 460 (all-in)',
        'flop|deal|Flop — 8d 9d Qd',
        'turn|deal|Turn — 8d 9d Qd Th',
        'river|deal|River — 8d 9d Qd Th 3s',
        'showdown|result|You, Ivey wins 1000 (Main pot)',
        'showdown|result|Ivey wins 1500 (Side pot 1)',
      ]);
    });

    test('postflop legal actions and bet-below-bb clamp', () {
      final s0 = _setup(2, [2000, 2000], holes, _deckStraight);
      final t0 = _run(s0, [
        (0, const Action.call()),
        (1, const Action.check()),
      ]);
      expect(t0.street, Street.flop);
      expect(t0.toAct, 1, reason: 'BB acts first postflop heads-up');
      var la = legalActions(t0);
      expect(la.toCall, 0);
      expect(la.canFold, isTrue);
      expect(la.canCheck, isTrue);
      expect(la.canCall, isFalse);
      expect(la.callAmount, 0);
      expect(la.canBet, isTrue);
      expect(la.canRaise, isFalse);
      expect(la.minRaiseTo, 20);
      expect(la.maxRaiseTo, 1980);
      expect(la.potSize, 40);

      final t1 = _run(t0, [(1, const Action.bet(3))]);
      expect(t1.currentBet, 20);
      expect(t1.lastRaiseSize, 20);
      expect(t1.aggressor, 1);
      expect(t1.toAct, 0);
      la = legalActions(t1);
      expect(la.toCall, 20);
      expect(la.minRaiseTo, 40);
      expect(la.maxRaiseTo, 1980);
      expect(la.potSize, 60);
      expect(t1.log.map((l) => l.text).toList(), [
        'Hand #1 · blinds 10/20',
        'You calls 10',
        'Ivey checks',
        'Flop — 8d 9d Qd',
        'Ivey bets 20',
      ]);
      expect(t1.players[1].lastAction!.label, 'Bet');
      expect(t1.players[1].lastAction!.street, Street.flop);
    });

    test('bet re-opens action for everyone else', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesJacks,
        _deckStraight,
        button: 0,
      );
      final s = _run(s0, [
        (3, const Action.call()),
        (4, const Action.call()),
        (5, const Action.fold()),
        (0, const Action.call()),
        (1, const Action.call()),
        (2, const Action.check()),
        // flop: seats 1,2,3,4,0 live
        (1, const Action.check()),
        (2, const Action.check()),
        (3, const Action.check()),
        (4, const Action.bet(40)),
      ]);
      expect(s.toAct, 0);
      expect(s.players[1].acted, isFalse);
      expect(s.players[2].acted, isFalse);
      expect(s.players[3].acted, isFalse);
      expect(s.players[4].acted, isTrue);
      expect(s.players[5].acted, isFalse, reason: 'closeStreet reset it');
      final t = _run(s, [
        (0, const Action.call()),
        (1, const Action.fold()),
        (2, const Action.call()),
        (3, const Action.raise(120)),
      ]);
      expect(t.toAct, 4);
      expect(t.lastRaiseSize, 80);
      expect(t.currentBet, 120);
      final u = _run(t, [(4, const Action.call()), (0, const Action.fold())]);
      expect(u.toAct, 2);
      final v = _run(u, [(2, const Action.call())]);
      expect(v.street, Street.turn);
      expect(v.toAct, 2, reason: 'seat 1 folded; seat 2 is first live seat');
    });
  });

  group('applyAction guards', () {
    test('no-op when it is not that seat\'s turn or phase != betting', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesJacks,
        _deckStraight,
        button: 0,
      );
      final s1 = applyAction(s0, 0, const Action.fold());
      expect(s1.toAct, 3);
      expect(s1.players[0].hasFolded, isFalse);
      expect(s1.log.length, 1);
      final idle = createTable(_cfg6, rng: Random(1));
      final s2 = applyAction(idle, 0, const Action.fold());
      expect(s2.phase, GamePhase.idle);
    });

    test('input state is never mutated', () {
      final s0 = _setup(
        6,
        [2000, 2000, 2000, 2000, 2000, 2000],
        _holesJacks,
        _deckStraight,
        button: 0,
      );
      final potBefore = s0.pot;
      final deckBefore = List<Card>.of(s0.deck);
      final logBefore = s0.log.length;
      final s1 = _run(s0, [
        (3, const Action.raise(60)),
        (4, const Action.call()),
        (5, const Action.call()),
        (0, const Action.call()),
        (1, const Action.call()),
        (2, const Action.call()),
      ]);
      expect(s1.street, Street.flop);
      expect(s0.pot, potBefore);
      expect(s0.deck, deckBefore);
      expect(s0.log.length, logBefore);
      expect(s0.players[3].stack, 2000 - 0);
      expect(s0.players[3].acted, isFalse);
      expect(s0.board, isEmpty);
      expect(s0.street, Street.preflop);
      expect(identical(s0.players[0], s1.players[0]), isFalse);
      // startHand on a finished state does not touch it either.
      final s2 = startHand(s1, rng: Random(1));
      expect(s2.handNumber, 2);
      expect(s1.handNumber, 1);
      expect(s1.board.length, 3);
    });
  });

  group('buildSidePots', () {
    test('dead money in a level with no live player rolls forward', () {
      final pots = buildSidePots(const [
        PotContribution(id: 0, amt: 30, folded: true),
        PotContribution(id: 1, amt: 20, folded: false),
        PotContribution(id: 2, amt: 100, folded: true),
        PotContribution(id: 3, amt: 200, folded: false),
        PotContribution(id: 4, amt: 0, folded: true),
      ]);
      expect(pots.map((p) => [p.amount, p.eligible]).toList(), [
        [
          80,
          [1, 3],
        ],
        [
          30,
          [3],
        ],
        [
          140,
          [3],
        ],
        [
          100,
          [3],
        ],
      ]);
    });

    test(
      'trailing dead level with no eligible player is dropped (as desktop)',
      () {
        final pots = buildSidePots(const [
          PotContribution(id: 0, amt: 100, folded: true),
          PotContribution(id: 1, amt: 50, folded: false),
          PotContribution(id: 2, amt: 50, folded: false),
        ]);
        expect(pots.map((p) => [p.amount, p.eligible]).toList(), [
          [
            150,
            [1, 2],
          ],
        ]);
      },
    );

    test('folded short contribution is dead money in the main pot', () {
      final pots = buildSidePots(const [
        PotContribution(id: 0, amt: 20, folded: false),
        PotContribution(id: 1, amt: 20, folded: false),
        PotContribution(id: 2, amt: 5, folded: true),
        PotContribution(id: 3, amt: 0, folded: true),
      ]);
      expect(pots.map((p) => [p.amount, p.eligible]).toList(), [
        [
          15,
          [0, 1],
        ],
        [
          30,
          [0, 1],
        ],
      ]);
    });
  });

  group('log capping', () {
    test('keeps the newest 200 entries with monotonically increasing ids', () {
      var s = createTable(_cfg6, rng: Random(5));
      final rng = Random(11);
      int hands = 0;
      while (s.log.length < 200 || hands < 40) {
        s = startHand(s, rng: rng);
        int guard = 0;
        while (s.phase == GamePhase.betting &&
            s.toAct != null &&
            guard++ < 5000) {
          s = applyAction(s, s.toAct!, _randomLegal(s, rng));
        }
        hands++;
      }
      expect(s.log.length, kLogCap);
      expect(s.logSeq, greaterThan(kLogCap));
      expect(s.log.last.id, s.logSeq - 1);
      for (int i = 1; i < s.log.length; i++) {
        expect(s.log[i].id, s.log[i - 1].id + 1);
      }
    });
  });

  group('read helpers', () {
    test('heroSeat / playersLeftOfButtonOrder / isHeroTurn', () {
      var s = createTable(_cfg6, rng: Random(1));
      s.button = 3;
      expect(heroSeat(s).id, 0);
      expect(playersLeftOfButtonOrder(s).map((p) => p.id).toList(), [
        4,
        5,
        0,
        1,
        2,
        3,
      ]);
      expect(isHeroTurn(s), isFalse);
      s = startHand(s, rng: Random(1));
      expect(s.toAct, 0);
      expect(isHeroTurn(s), isTrue);
      expect(s.isHeroTurn, isTrue);
      s = applyAction(s, 0, const Action.fold());
      expect(isHeroTurn(s), isFalse);
    });
  });

  group('simulation invariants (scripts/sim_test.ts)', () {
    test('600 random 6-max hands', () {
      var state = createTable(_cfg6, rng: Random(2024));
      final rng = Random(99);
      int showdowns = 0;
      int allInRunouts = 0;
      for (int h = 0; h < 600; h++) {
        state = startHand(state, rng: rng);
        final startSum = state.stacksAtStart.fold(0, (a, b) => a + b);
        int guard = 0;
        while (state.phase == GamePhase.betting && state.toAct != null) {
          expect(guard++, lessThan(5000), reason: 'loop guard exceeded');
          final seat = state.toAct!;
          state = applyAction(state, seat, _randomLegal(state, rng));
        }
        expect(state.phase, GamePhase.handOver, reason: 'hand completed');
        expect(state.players.every((p) => p.stack >= 0), isTrue);
        final endSum = state.players.fold(0, (a, p) => a + p.stack);
        expect(endSum, startSum, reason: 'chip conservation');
        expect([0, 3, 4, 5], contains(state.board.length));
        // 12 dealt, then burn+3, burn+1, burn+1.
        const deckLeft = {0: 40, 3: 36, 4: 34, 5: 32};
        expect(state.deck.length, deckLeft[state.board.length]);
        final summary = state.summary!;
        final dist = summary.potResults.fold<num>(0, (a, b) => a + b.amount);
        expect(dist, state.pot, reason: 'pot fully distributed');
        expect(summary.handNumber, state.handNumber);
        expect(
          summary.heroNetChips,
          state.players[0].stack - state.stacksAtStart[0],
        );
        expect(state.players.every((p) => p.revealed), isTrue);
        if (summary.showdown.isNotEmpty) showdowns++;
        if (state.board.length == 5 && summary.showdown.length >= 2) {
          if (state.players.any((p) => p.isAllIn)) allInRunouts++;
        }
        if (summary.showdown.isEmpty) {
          expect(summary.potResults.length, 1);
          expect(summary.potResults[0].potLabel, 'Pot');
        } else {
          expect(state.board.length, 5);
          for (final e in summary.showdown) {
            expect(e.hand, isNotNull);
            expect(state.players[e.playerId].hasFolded, isFalse);
          }
        }
      }
      expect(showdowns, greaterThan(0));
      expect(allInRunouts, greaterThan(0));
      expect(state.handNumber, 600);
      expect(state.players.every((p) => p.handsSeen == 600), isTrue);
    });
  });

  group('table configurations (scripts/table_config_test.ts)', () {
    const configs = <(String, GameConfig, int)>[
      (
        'heads-up',
        GameConfig(seats: 2, startingStack: 2000, smallBlind: 10, bigBlind: 20),
        250,
      ),
      (
        '6-max + ante',
        GameConfig(
          seats: 6,
          startingStack: 2000,
          smallBlind: 10,
          bigBlind: 20,
          ante: 5,
        ),
        250,
      ),
      (
        '9-max',
        GameConfig(seats: 9, startingStack: 2000, smallBlind: 10, bigBlind: 20),
        200,
      ),
      (
        '9-max + ante',
        GameConfig(
          seats: 9,
          startingStack: 2000,
          smallBlind: 10,
          bigBlind: 20,
          ante: 5,
        ),
        150,
      ),
    ];

    for (final (name, config, hands) in configs) {
      test(name, () {
        var state = createTable(config, rng: Random(7));
        final rng = Random(name.hashCode);
        for (int h = 0; h < hands; h++) {
          state = startHand(state, rng: rng);
          final totalBefore =
              state.players.fold(0, (a, p) => a + p.stack) + state.pot;

          if (h == 0 || h == 1) {
            final positions = state.players.map((p) => p.position).toList();
            if (config.seats == 2) {
              expect(positions, contains(Position.btn));
              expect(positions, contains(Position.bb));
              final btn = state.players.firstWhere(
                (p) => p.position == Position.btn,
              );
              expect(
                btn.committed,
                config.smallBlind,
                reason: '$name: HU button posts the small blind',
              );
              expect(
                state.toAct,
                btn.id,
                reason: '$name: HU button acts first preflop',
              );
            }
            if (config.seats == 9) {
              expect(positions.where((p) => p == Position.btn).length, 1);
              expect(positions.toSet().length, greaterThanOrEqualTo(5));
            }
            if (config.ante > 0) {
              expect(
                state.pot,
                config.smallBlind +
                    config.bigBlind +
                    config.ante * config.seats,
                reason: '$name: antes in the pot',
              );
              final nonBlind = state.players.any(
                (p) => p.committed == 0 && p.committedTotal > 0,
              );
              expect(
                nonBlind,
                isTrue,
                reason: '$name: antes count toward totals only',
              );
            }
          }

          int guard = 0;
          while (state.phase == GamePhase.betting &&
              state.toAct != null &&
              guard++ < 6000) {
            state = applyAction(state, state.toAct!, _randomLegal(state, rng));
          }
          expect(state.phase, GamePhase.handOver, reason: '$name: completes');
          final totalAfter = state.players.fold(0, (a, p) => a + p.stack);
          expect(totalAfter, totalBefore, reason: '$name: chip conservation');
          expect(state.players.every((p) => p.stack >= 0), isTrue);
          final dist = state.summary!.potResults.fold<num>(
            0,
            (a, b) => a + b.amount,
          );
          expect(dist, state.pot, reason: '$name: pot fully distributed');
        }
      });
    }
  });
}
