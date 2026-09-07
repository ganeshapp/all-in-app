// Port of the desktop scripts/hh_test.ts (41 assertions) plus full formatted
// texts, JSON payloads and replay frames pinned against the TypeScript
// (see hand_history_ref.dart — generated with Node 23, TZ=UTC).
import 'dart:convert';

import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hand_history_ref.dart';

// Date.UTC(2026, 5, 19, 12, 0, 0)
const int kStartedAt = 1781870400000;

HHAction act(
  Street street,
  int seat,
  String name,
  ActionType type,
  num amount, {
  bool allIn = false,
}) => HHAction(
  street: street,
  seat: seat,
  name: name,
  type: type,
  amount: amount,
  allIn: allIn,
);

HHSeat seat(int n, String name, num stack, Position pos, {bool hero = false}) =>
    HHSeat(seat: n, name: name, stack: stack, isHero: hero, position: pos);

final List<HHSeat> sixSeats = [
  seat(0, 'You', 2000, Position.btn, hero: true),
  seat(1, 'Ivey', 2000, Position.sb),
  seat(2, 'Polk', 2000, Position.bb),
  seat(3, 'Dwan', 2000, Position.utg),
  seat(4, 'Selbst', 2000, Position.mp),
  seat(5, 'Galfond', 2000, Position.co),
];

HHHand makeHand() => HHHand(
  id: 1,
  startedAt: kStartedAt,
  button: 0,
  sb: 10,
  bb: 20,
  sbSeat: 1,
  bbSeat: 2,
  seats: sixSeats,
  holes: {
    0: ['As', 'Ks'],
    3: ['Qh', 'Qd'],
  },
  actions: [
    act(Street.preflop, 3, 'Dwan', ActionType.raise, 60),
    act(Street.preflop, 0, 'You', ActionType.call, 60),
    act(Street.flop, 3, 'Dwan', ActionType.bet, 80),
    act(Street.flop, 0, 'You', ActionType.call, 80),
    act(Street.turn, 3, 'Dwan', ActionType.check, 0),
    act(Street.turn, 0, 'You', ActionType.check, 0),
    act(Street.river, 3, 'Dwan', ActionType.check, 0),
    act(Street.river, 0, 'You', ActionType.bet, 120),
    act(Street.river, 3, 'Dwan', ActionType.call, 120),
  ],
  board: ['Ah', 'Kd', '7c', '2s', '9h'],
  potResults: const [
    PotResult(winners: [0], amount: 520, potLabel: 'Pot'),
  ],
  heroNet: 260,
);

HHHand makeFoldout() => HHHand(
  id: 2,
  startedAt: kStartedAt + 60000,
  button: 0,
  sb: 10,
  bb: 20,
  sbSeat: 1,
  bbSeat: 2,
  seats: sixSeats,
  holes: {
    0: ['7h', '2c'],
    3: ['Ac', 'Ad'],
  },
  actions: [
    act(Street.preflop, 3, 'Dwan', ActionType.raise, 60),
    act(Street.preflop, 4, 'Selbst', ActionType.fold, 0),
    act(Street.preflop, 5, 'Galfond', ActionType.fold, 0),
    act(Street.preflop, 0, 'You', ActionType.fold, 0),
    act(Street.preflop, 1, 'Ivey', ActionType.fold, 0),
    act(Street.preflop, 2, 'Polk', ActionType.fold, 0),
  ],
  board: [],
  potResults: const [
    PotResult(winners: [3], amount: 90, potLabel: 'Pot'),
  ],
  heroNet: 0,
);

/// Three-way all-in with a side pot, split main pot, one seat never acting.
HHHand makeAllin() => HHHand(
  id: 103,
  startedAt: kStartedAt + 120000,
  button: 2,
  sb: 10,
  bb: 20,
  sbSeat: 3,
  bbSeat: 4,
  seats: [
    seat(0, 'You', 500, Position.mp, hero: true),
    seat(1, 'Ivey', 2000, Position.co),
    seat(2, 'Polk', 1200, Position.btn),
    seat(3, 'Dwan', 800, Position.sb),
    seat(4, 'Selbst', 3000, Position.bb),
    seat(5, 'Galfond', 2000, Position.utg),
  ],
  holes: {
    0: ['Jc', 'Jd'],
    1: ['Ac', 'Kc'],
    2: ['9s', '8s'],
    3: ['Ah', 'Kh'],
    4: ['3d', '3c'],
    5: ['7h', '2d'],
  },
  actions: [
    act(Street.preflop, 5, 'Galfond', ActionType.fold, 0),
    act(Street.preflop, 0, 'You', ActionType.raise, 60),
    act(Street.preflop, 1, 'Ivey', ActionType.raise, 180),
    act(Street.preflop, 2, 'Polk', ActionType.fold, 0),
    act(Street.preflop, 3, 'Dwan', ActionType.raise, 800, allIn: true),
    act(Street.preflop, 4, 'Selbst', ActionType.fold, 0),
    act(Street.preflop, 0, 'You', ActionType.call, 440, allIn: true),
    act(Street.preflop, 1, 'Ivey', ActionType.call, 620),
  ],
  board: ['Kd', 'Qs', 'Th', 'Ac', 'Qh'],
  potResults: const [
    PotResult(winners: [0, 1, 3], amount: 1530, potLabel: 'Main pot'),
    PotResult(winners: [1, 3], amount: 600, potLabel: 'Side pot 1'),
  ],
  heroNet: 10,
);

/// Heads-up (button posts SB), turn fold-out with an uncalled raise.
HHHand makeHu() => HHHand(
  id: 7,
  startedAt: kStartedAt + 180000,
  button: 1,
  sb: 10,
  bb: 20,
  sbSeat: 1,
  bbSeat: 0,
  seats: [
    seat(0, 'You', 1500, Position.bb, hero: true),
    seat(1, 'Ivey', 2500, Position.btn),
  ],
  holes: {
    0: ['Th', '9h'],
    1: ['Ad', '4d'],
  },
  actions: [
    act(Street.preflop, 1, 'Ivey', ActionType.raise, 50),
    act(Street.preflop, 0, 'You', ActionType.call, 30),
    act(Street.flop, 0, 'You', ActionType.check, 0),
    act(Street.flop, 1, 'Ivey', ActionType.bet, 50),
    act(Street.flop, 0, 'You', ActionType.raise, 175),
    act(Street.flop, 1, 'Ivey', ActionType.call, 125),
    act(Street.turn, 0, 'You', ActionType.bet, 300),
    act(Street.turn, 1, 'Ivey', ActionType.raise, 900),
    act(Street.turn, 0, 'You', ActionType.fold, 0),
  ],
  board: ['8h', '7c', '2d', 'Ks'],
  potResults: const [
    PotResult(winners: [1], amount: 1650, potLabel: 'Pot'),
  ],
  heroNet: -525,
);

/// Three-way chop of an odd pot: Math.round(100 / 3) = 33 each, total 99.
HHHand makeSplit() => HHHand(
  id: 9,
  startedAt: kStartedAt + 240000,
  button: 0,
  sb: 10,
  bb: 20,
  sbSeat: 1,
  bbSeat: 2,
  seats: sixSeats.sublist(0, 3),
  holes: {
    0: ['Ac', 'Kd'],
    1: ['Ad', 'Kc'],
    2: ['Ah', 'Ks'],
  },
  actions: [
    act(Street.preflop, 0, 'You', ActionType.call, 20),
    act(Street.preflop, 1, 'Ivey', ActionType.call, 10),
    act(Street.preflop, 2, 'Polk', ActionType.check, 0),
    act(Street.flop, 1, 'Ivey', ActionType.bet, 15),
    act(Street.flop, 2, 'Polk', ActionType.call, 15),
    act(Street.flop, 0, 'You', ActionType.call, 15),
    act(Street.turn, 1, 'Ivey', ActionType.check, 0),
    act(Street.turn, 2, 'Polk', ActionType.check, 0),
    act(Street.turn, 0, 'You', ActionType.check, 0),
    act(Street.river, 1, 'Ivey', ActionType.check, 0),
    act(Street.river, 2, 'Polk', ActionType.check, 0),
    act(Street.river, 0, 'You', ActionType.check, 0),
  ],
  board: ['Qs', 'Jh', 'Tc', '2c', '2d'],
  potResults: const [
    PotResult(winners: [0, 1, 2], amount: 100, potLabel: 'Pot'),
  ],
  heroNet: 0,
);

/// Imported-style real-money hand: fractional blinds/stacks/amounts must
/// print like JavaScript numbers (0.25, 33.75, 1.5 — never "50.0").
HHHand makeFrac() => HHHand(
  id: 123456,
  startedAt: kStartedAt,
  button: 1,
  sb: 0.25,
  bb: 0.5,
  sbSeat: 0,
  bbSeat: 1,
  seats: [
    seat(0, 'hero1', 50, Position.sb, hero: true),
    seat(1, 'villain', 33.75, Position.bb),
  ],
  holes: {
    0: ['Ah', 'Ad'],
  },
  actions: [
    act(Street.preflop, 0, 'hero1', ActionType.raise, 1.5),
    act(Street.preflop, 1, 'villain', ActionType.call, 1),
    act(Street.flop, 1, 'villain', ActionType.check, 0),
    act(Street.flop, 0, 'hero1', ActionType.bet, 2.25),
    act(Street.flop, 1, 'villain', ActionType.fold, 0),
  ],
  board: ['Kc', '7d', '2h'],
  potResults: const [
    PotResult(winners: [0], amount: 5, potLabel: 'Pot'),
  ],
  heroNet: 3,
);

/// The reference texts were produced with TZ=UTC; psDate prints LOCAL time,
/// so swap in this host's rendering of the same instant.
String localised(String refText, HHHand h) => refText.replaceAllMapped(
  RegExp(r'- \d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} ET'),
  (_) => '- ${psDate(h.startedAt)} ET',
);

void expectFrames(List<ReplayFrame> got, List<RefFrame> want) {
  expect(got.length, want.length);
  for (var i = 0; i < want.length; i++) {
    final g = got[i];
    final w = want[i];
    expect(g.text, w.text, reason: 'frame $i text');
    expect(g.street.label, w.street, reason: 'frame $i street');
    expect(g.board, w.board, reason: 'frame $i board');
    expect(g.pot, w.pot, reason: 'frame $i pot');
    expect(g.folded, w.folded, reason: 'frame $i folded');
    expect(g.revealAll, w.revealAll, reason: 'frame $i revealAll');
  }
}

void main() {
  group('scripts/hh_test.ts — showdown hand', () {
    final hand = makeHand();
    final out = formatHand(hand);

    test('header, blinds, hole cards and street lines', () {
      // Globally unique, monotonic export id (not the session-local #1).
      expect(
        out,
        contains(
          "PokerStars Hand #${hand.startedAt * 100 + 1}: Hold'em No Limit (10/20)",
        ),
      );
      expect(out, contains('Seat #1 is the button'));
      expect(out, contains('Ivey: posts small blind 10'));
      expect(out, contains('Polk: posts big blind 20'));
      expect(out, contains('*** HOLE CARDS ***'));
      expect(out, contains('Dealt to You [As Ks]'));
      expect(out, contains('Dwan: raises 40 to 60'));
      expect(out, contains('You: calls 60'));
      expect(out, contains('*** FLOP *** [Ah Kd 7c]'));
      expect(out, contains('Dwan: bets 80'));
      expect(out, contains('*** TURN *** [Ah Kd 7c] [2s]'));
      expect(out, contains('*** RIVER *** [Ah Kd 7c 2s] [9h]'));
      expect(out, contains('You: bets 120'));
    });

    test('showdown, collection and summary', () {
      expect(out, contains('*** SHOW DOWN ***'));
      expect(out, contains('You: shows [As Ks] (two pair, Aces and Kings)'));
      expect(out, contains('Dwan: shows [Qh Qd] (a pair of Queens)'));
      expect(out, contains('You collected 520 from pot'));
      expect(out, contains('*** SUMMARY ***'));
      expect(out, contains('Total pot 520'));
      expect(out, contains('Board [Ah Kd 7c 2s 9h]'));
      expect(
        out,
        contains(
          'Seat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings',
        ),
      );
      expect(
        out,
        contains('Seat 4: Dwan showed [Qh Qd] and lost with a pair of Queens'),
      );
      expect(out, contains('Seat 2: Ivey (small blind) folded before Flop'));
      expect(out, contains('Seat 3: Polk (big blind) folded before Flop'));
    });

    test('muck semantics: players who never reached showdown never show', () {
      expect(out, isNot(contains('Ivey: shows')));
      expect(out, isNot(contains('Selbst: shows')));
    });

    test('full text matches the TypeScript byte for byte', () {
      expect(out, localised(kRefHandText, hand));
      expect(exportHandId(hand), kRefHandExportId);
    });
  });

  group('scripts/hh_test.ts — fold-out hand', () {
    final foldout = makeFoldout();
    final out2 = formatHand(foldout);

    test('uncalled bet returned, no fabricated showdown', () {
      expect(
        out2,
        contains('PokerStars Hand #${foldout.startedAt * 100 + 2}:'),
      );
      expect(out2, contains('Uncalled bet (40) returned to Dwan'));
      expect(out2, contains('Dwan collected 50 from pot'));
      expect(out2, contains('Total pot 50'));
      expect(out2, contains('Seat 4: Dwan collected (50)'));
      expect(out2, contains('Seat 1: You (button) folded before Flop'));
      expect(out2, isNot(contains('*** SHOW DOWN ***')));
      expect(out2, isNot(contains('Dwan: shows')));
      expect(out2, isNot(contains('Board [')));
    });

    test('full text matches the TypeScript byte for byte', () {
      expect(out2, localised(kRefFoldoutText, foldout));
      expect(exportHandId(foldout), kRefFoldoutExportId);
    });
  });

  group('scripts/hh_test.ts — replay frames', () {
    final frames = buildReplayFrames(makeHand());

    test('shape of the replay', () {
      expect(frames.length, greaterThan(4));
      expect(frames[0].text, contains('Blinds'));
      final last = frames.last;
      expect(last.board.length, 5);
      expect(last.revealAll, isTrue);
      expect(last.pot, greaterThanOrEqualTo(frames[0].pot));
      expect(
        frames.any((f) => f.street == Street.flop && f.board.length == 3),
        isTrue,
      );
      expect(frames.where((f) => f.revealAll).length, 1);
    });

    test('every frame matches the TypeScript', () {
      expectFrames(frames, kRefHandFrames);
      expectFrames(buildReplayFrames(makeFoldout()), kRefFoldoutFrames);
      expectFrames(buildReplayFrames(makeAllin()), kRefAllinFrames);
      expectFrames(buildReplayFrames(makeHu()), kRefHuFrames);
      expectFrames(buildReplayFrames(makeSplit()), kRefSplitFrames);
      expectFrames(buildReplayFrames(makeFrac()), kRefFracFrames);
    });

    test('end street follows the dealt board', () {
      expect(buildReplayFrames(makeFoldout()).last.street, Street.preflop);
      expect(buildReplayFrames(makeHu()).last.street, Street.turn);
      expect(buildReplayFrames(makeFrac()).last.street, Street.flop);
      expect(buildReplayFrames(makeHand()).last.street, Street.showdown);
    });

    test('"Hand over." when nothing was awarded', () {
      final h = makeFoldout()..potResults = [];
      expect(buildReplayFrames(h).last.text, 'Hand over.');
    });
  });

  group('pinned full texts', () {
    test('three-way all-in with side pot and split main pot', () {
      final h = makeAllin();
      final out = formatHand(h);
      expect(out, localised(kRefAllinText, h));
      expect(exportHandId(h), kRefAllinExportId);
      expect(out, contains('Dwan: raises 620 to 800 and is all-in'));
      expect(out, contains('You: calls 440 and is all-in'));
      expect(out, contains('You collected 510 from pot'));
      expect(out, contains('Ivey collected 810 from pot'));
      expect(out, contains('Total pot 2130 | Rake 0'));
    });

    test('heads-up turn fold-out returns the uncalled raise', () {
      final h = makeHu();
      final out = formatHand(h);
      expect(out, localised(kRefHuText, h));
      expect(out, contains("Table 'All-In Dojo' 2-max Seat #2 is the button"));
      expect(out, contains('Uncalled bet (600) returned to Ivey'));
      expect(out, contains('Ivey collected 1050 from pot'));
      expect(out, contains('Seat 1: You (big blind) folded on the Turn'));
      expect(out, contains('Seat 2: Ivey (small blind) collected (1050)'));
    });

    test('odd chop rounds each share like Math.round', () {
      final h = makeSplit();
      final out = formatHand(h);
      expect(out, localised(kRefSplitText, h));
      expect(out, contains('You collected 33 from pot'));
      expect(out, contains('Total pot 99 | Rake 0'));
    });

    test('fractional (imported) amounts print like JavaScript numbers', () {
      final h = makeFrac();
      final out = formatHand(h);
      expect(out, localised(kRefFracText, h));
      expect(out, contains("Hold'em No Limit (0.25/0.5)"));
      expect(out, contains('Seat 2: villain (33.75 in chips)'));
      expect(out, contains('hero1: raises 1 to 1.5'));
      expect(out, contains('hero1 collected 2.75 from pot'));
      // A double that happens to be integral prints without ".0".
      final d = makeFrac()..sb = 0.25 + 0.75;
      expect(formatHand(d), contains("Hold'em No Limit (1/0.5)"));
    });

    test('formatSession joins hands with two blank lines', () {
      final a = makeHand();
      final b = makeFoldout();
      final parts = kRefSessionText.split('\n\n\n');
      expect(
        formatSession([a, b]),
        '${localised(parts[0], a)}\n\n\n${localised(parts[1], b)}',
      );
      expect(formatSession([]), '');
    });
  });

  group('formatter edge cases', () {
    test('a seat that never acted and never won is folded before Flop', () {
      final h = makeHand()..actions.removeWhere((a) => a.seat == 3);
      final out = formatHand(h);
      expect(out, contains('Seat 4: Dwan folded before Flop'));
      // Only one live player left: no genuine showdown.
      expect(out, isNot(contains('*** SHOW DOWN ***')));
      expect(out, contains('Uncalled bet (120) returned to You'));
      expect(out, contains('Seat 1: You (button) collected (400)'));
    });

    test(
      'unknown hero hole omits the Dealt line; missing blinds fall back',
      () {
        final h = makeFoldout()..holes = {};
        final out = formatHand(h);
        expect(out, isNot(contains('Dealt to')));
        final g =
            makeFoldout()
              ..sbSeat = 9
              ..bbSeat = 8;
        final out2 = formatHand(g);
        expect(out2, contains('SB: posts small blind 10'));
        expect(out2, contains('BB: posts big blind 20'));
      },
    );

    test('live player with unknown cards at showdown is "mucked"', () {
      final h =
          makeHand()
            ..holes = {
              0: ['As', 'Ks'],
            };
      final out = formatHand(h);
      expect(out, contains('You: shows [As Ks]'));
      expect(out, isNot(contains('Dwan: shows')));
      expect(out, contains('Seat 4: Dwan mucked'));
    });

    test('post actions render as "<name>: posts"', () {
      final h =
          makeFoldout()
            ..actions.insert(
              0,
              act(Street.preflop, 4, 'Selbst', ActionType.post, 20),
            );
      expect(formatHand(h), contains('Selbst: posts'));
    });

    test('a bet on a street beyond the board is still emitted', () {
      // Defensive branch: actions recorded on a street whose cards were
      // never stored (partial record) — no street header, lines still emitted.
      final h = makeHu()..board = [];
      final out = formatHand(h);
      expect(out, isNot(contains('*** FLOP ***')));
      expect(out, contains('You: raises 125 to 175'));
      expect(out, contains('Seat 1: You (big blind) folded on the Turn'));
    });
  });

  group('psDate / psHandName', () {
    test('psDate uses local time components, zero padded', () {
      expect(
        psDate(DateTime(2026, 6, 19, 12, 0, 0).millisecondsSinceEpoch),
        '2026/06/19 12:00:00',
      );
      expect(
        psDate(DateTime(2026, 1, 5, 3, 4, 5).millisecondsSinceEpoch),
        '2026/01/05 03:04:05',
      );
    });

    test('psHandName covers every category (pinned from the TypeScript)', () {
      for (final (hole, board, _, ps) in kRefPsHandNames) {
        expect(psHandName(hole, board), ps, reason: '$hole on $board');
      }
    });
  });

  group('JSON persistence (hand_json column)', () {
    test('toJson reproduces JSON.stringify(HHHand) exactly', () {
      expect(jsonEncode(makeHand().toJson()), kRefHandJson);
      expect(jsonEncode(makeFoldout().toJson()), kRefFoldoutJson);
      expect(jsonEncode(makeAllin().toJson()), kRefAllinJson);
      expect(jsonEncode(makeHu().toJson()), kRefHuJson);
      expect(jsonEncode(makeSplit().toJson()), kRefSplitJson);
      expect(jsonEncode(makeFrac().toJson()), kRefFracJson);
    });

    test('null hole entries are dropped like undefined; keys sorted', () {
      final h =
          makeFoldout()
            ..holes = {
              3: ['Ac', 'Ad'],
              1: null,
              0: ['7h', '2c'],
            };
      expect(jsonEncode(h.toJson()), kRefUndefHolesJson);
    });

    test('fromJson round-trips a desktop payload', () {
      for (final ref in [
        kRefHandJson,
        kRefFoldoutJson,
        kRefAllinJson,
        kRefHuJson,
        kRefSplitJson,
        kRefFracJson,
      ]) {
        final h = HHHand.fromJson(
          (jsonDecode(ref) as Map).cast<String, Object?>(),
        );
        expect(jsonEncode(h.toJson()), ref);
      }
      final h = HHHand.fromJson(
        (jsonDecode(kRefAllinJson) as Map).cast<String, Object?>(),
      );
      expect(h.id, 103);
      expect(h.seats[3].position, Position.sb);
      expect(h.holes[5], ['7h', '2d']);
      expect(h.actions[4].allIn, isTrue);
      expect(h.actions[4].type, ActionType.raise);
      expect(h.potResults[1].potLabel, 'Side pot 1');
      expect(h.potResults[1].winners, [1, 3]);
      expect(h.heroNet, 10);
      expect(formatHand(h), formatHand(makeAllin()));
      expectFrames(buildReplayFrames(h), kRefAllinFrames);
    });

    test('fromJson keeps fractional pot amounts (imported \$ hands)', () {
      // Desktop JSON.parse keeps 2.5; rounding it to 3 changed the replay's
      // closing line ("win 6 bb." instead of "win 5 bb."). Reference from
      // buildReplayFrames/formatHand in Node.
      const json =
          '{"id":7,"startedAt":1781870400000,"button":0,"sb":0.25,"bb":0.5,'
          '"sbSeat":1,"bbSeat":0,"seats":[{"seat":0,"name":"You","stack":50,'
          '"isHero":true,"position":"BB"},{"seat":1,"name":"Ivey","stack":50,'
          '"isHero":false,"position":"BTN"}],"holes":{"0":["Ah","Kd"]},'
          '"actions":[{"street":"preflop","seat":1,"name":"Ivey","type":"raise",'
          '"amount":1.5,"allIn":false},{"street":"preflop","seat":0,"name":"You",'
          '"type":"raise","amount":4.5,"allIn":false},{"street":"preflop",'
          '"seat":1,"name":"Ivey","type":"fold","amount":0,"allIn":false}],'
          '"board":[],"potResults":[{"winners":[0],"amount":2.5,'
          '"potLabel":"Pot"}],"heroNet":1.5}';
      final h = HHHand.fromJson(
        (jsonDecode(json) as Map).cast<String, Object?>(),
      );
      expect(h.potResults[0].amount, 2.5);
      expect(jsonEncode(h.toJson()), json);
      final frames = buildReplayFrames(h);
      expect(frames.map((f) => [f.text, f.pot]).toList(), [
        ['Blinds 0.5/1 bb posted.', 0.75],
        ['Ivey raises to 3 bb', 2],
        ['You raises to 9 bb', 6],
        ['Ivey folds', 6],
        ['You win 5 bb.', 6],
      ]);
      // formatHand rounds each share like the desktop (Math.round(2.5) = 3,
      // minus the 3 uncalled): "Total pot 0", hero "mucked".
      final text = formatHand(h);
      expect(text, contains('Uncalled bet (3) returned to You'));
      expect(text, contains('Total pot 0 | Rake 0'));
      expect(text, contains('Seat 1: You (big blind) mucked'));
      expect(text, contains('Seat 2: Ivey (small blind) folded before Flop'));
    });

    test('fromJson tolerates a minimal payload', () {
      final h = HHHand.fromJson({
        'id': 1,
        'startedAt': kStartedAt,
        'button': 0,
        'sb': 10,
        'bb': 20,
        'sbSeat': 1,
        'bbSeat': 2,
        'seats': [
          {
            'seat': 0,
            'name': 'You',
            'stack': 2000,
            'isHero': true,
            'position': 'BTN',
          },
        ],
      });
      expect(h.holes, isEmpty);
      expect(h.actions, isEmpty);
      expect(h.board, isEmpty);
      expect(h.potResults, isEmpty);
      expect(h.heroNet, 0);
    });
  });
}
