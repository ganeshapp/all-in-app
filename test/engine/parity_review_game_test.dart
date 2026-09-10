// Adversarial parity review pins for hand_engine / archetypes / bot_brain /
// hand_history / hh_import.
//
// Every expectation below was produced by running the desktop TypeScript
// (`src/game/engine.ts`, `src/game/archetypes.ts`, `src/game/botBrain.ts`,
// `src/game/handHistory.ts`, `src/lib/hhImport.ts`) under Node 23
// (`node --experimental-transform-types`) on the same inputs, with
// `Math.random` replaced by the same mulberry32 stream the Dart side is
// driven with. The review ran differential fuzzes of
//   * 240 hand_engine tables (2–9 seats, antes, sub-min raises, all-in
//     run-outs, side pots) — 88 704 transcript lines, byte-identical;
//   * 800 bot_brain tables with and without jittered per-seat dials plus
//     3 000 narrowRange cases — 47 000 lines, byte-identical;
//   * 300 randomised hand histories through formatHand / buildReplayFrames /
//     parsePokerStars / analyzeImported, 4 000 showdowns through psHandName,
//     and 3 000 strings through the `Number.parseFloat` port.
// The cases pinned here are the ones that exercise paths the module tests
// did not cover: degenerate actions (amount-less raise, `post`, negative
// bet), split-pot rounding with an uncalled bet, `narrowRange` on long
// stored ranges, hand-history names that collide with the parser's own
// vocabulary, a button seat number past the end of the table (negative
// position offset), and the NaN-amount corrupt-import path that used to
// throw out of `formatHand`.
library;

import 'package:allin/engine/archetypes.dart';
import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/hh_import.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reference texts were produced with a fixed clock; `psDate` prints
/// LOCAL time, so normalise the header's date to whatever this machine says.
/// Rewrites the header's timestamp AND its export id from `startedAt`.
///
/// `psDate` renders LOCAL time (desktop parity — `handHistory.ts` uses
/// `Date.getHours()`), and a hand parsed out of a history text carries a
/// `startedAt` that was itself read as local time. Both the printed date and
/// the export id (`startedAt * 100 + id % 100`) therefore move with the
/// machine's timezone, so a fixture written on one cannot be compared
/// literally on another — that is what broke CI on a UTC runner while passing
/// in Asia/Seoul. The expectation is anchored to the hand under test instead.
String _normaliseDate(String text, int startedAt, {int? exportId}) {
  var out = text.replaceFirst(
    RegExp(r' - \d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} ET'),
    ' - ${psDate(startedAt)} ET',
  );
  if (exportId != null) {
    out = out.replaceFirst(
      RegExp(r'PokerStars Hand #\d+:'),
      'PokerStars Hand #$exportId:',
    );
  }
  return out;
}

HHHand _craftedHand() => HHHand(
  id: 7,
  startedAt: 1750000000000,
  button: 2,
  sb: 10,
  bb: 20,
  sbSeat: 0,
  bbSeat: 1,
  seats: const [
    HHSeat(
      seat: 0,
      name: 'You',
      stack: 1000,
      isHero: true,
      position: Position.sb,
    ),
    HHSeat(
      seat: 1,
      name: 'Ivey',
      stack: 1000,
      isHero: false,
      position: Position.bb,
    ),
    HHSeat(
      seat: 2,
      name: 'Polk',
      stack: 1000,
      isHero: false,
      position: Position.btn,
    ),
  ],
  holes: {
    0: const ['Ah', 'Kd'],
    1: const ['Ac', 'Ks'],
    2: null,
  },
  actions: const [
    HHAction(
      street: Street.preflop,
      seat: 2,
      name: 'Polk',
      type: ActionType.post,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 2,
      name: 'Polk',
      type: ActionType.raise,
      amount: 60,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 0,
      name: 'You',
      type: ActionType.call,
      amount: 50,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 1,
      name: 'Ivey',
      type: ActionType.call,
      amount: 40,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 0,
      name: 'You',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 1,
      name: 'Ivey',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 2,
      name: 'Polk',
      type: ActionType.bet,
      amount: 90,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 0,
      name: 'You',
      type: ActionType.raise,
      amount: 265,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 1,
      name: 'Ivey',
      type: ActionType.call,
      amount: 265,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 2,
      name: 'Polk',
      type: ActionType.fold,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.turn,
      seat: 0,
      name: 'You',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.turn,
      seat: 1,
      name: 'Ivey',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.river,
      seat: 0,
      name: 'You',
      type: ActionType.bet,
      amount: 175,
      allIn: false,
    ),
    HHAction(
      street: Street.river,
      seat: 1,
      name: 'Ivey',
      type: ActionType.fold,
      amount: 0,
      allIn: false,
    ),
  ],
  board: const ['2c', '7d', 'Qs', '9h', '3d'],
  potResults: const [
    PotResult(winners: [0, 1], amount: 725, potLabel: 'Pot'),
  ],
  heroNet: 100,
);

/// A hand history whose amounts do not parse to numbers. The desktop's
/// `Number.parseFloat` yields NaN for these and every downstream string
/// prints "NaN" — it never throws.
const String _corruptBlock =
    '''PokerStars Hand #909: Hold'em No Limit (10/20) - 2025/09/09 09:09:09 ET
Table 'Corrupt' 3-max Seat #1 is the button
Seat 1: A (500 in chips)
Seat 2: B (500 in chips)
Seat 3: C (500 in chips)
B: posts small blind 10
C: posts big blind 20
*** HOLE CARDS ***
Dealt to A [Ah Kd]
A: calls \$.
B: folds
C: checks
*** FLOP *** [2c 3d 4h]
C: bets ,
A: calls ..
*** SUMMARY ***
Total pot 60 | Rake 0
Seat 1: A (button) mucked''';

const String _collidingNamesBlock =
    '''PokerStars Hand #55: Hold'em No Limit (10/20) - 2025/05/05 05:05:05 ET
Table 'Trap' 6-max Seat #2 is the button
Seat 1: Seat 5: Bob (1000 in chips)
Seat 2: he: folds (1000 in chips)
Seat 3: x collected 999 from (1000 in chips)
Seat 4: shows [Ah] guy (1000 in chips)
Seat 5: posts small blind (1000 in chips)
Seat 6: Normal (1000 in chips)
Seat 3: posts small blind 10
Seat 4: posts big blind 20
*** HOLE CARDS ***
Dealt to Normal [Ah Kd]
Seat 5: folds
Normal: raises 40 to 60
Seat 1: Seat 5: Bob: calls 60
he: folds: calls 60
x collected 999 from: folds
shows [Ah] guy: folds
*** FLOP *** [2c 3d 4h]
Seat 1: Seat 5: Bob: checks
he: folds: bets 100
Normal: calls 100
Seat 1: Seat 5: Bob: folds
*** TURN *** [2c 3d 4h] [9s]
he: folds: bets 200
Normal: calls 200
*** RIVER *** [2c 3d 4h 9s] [Td]
he: folds: checks
Normal: checks
*** SHOW DOWN ***
he: folds: shows [7c 7d] (a pair of Sevens)
Normal: shows [Ah Kd] (high card Ace)
he: folds collected 750 from pot
*** SUMMARY ***
Total pot 750 | Rake 0
Board [2c 3d 4h 9s Td]
Seat 1: Seat 5: Bob folded on the Flop
Seat 2: he: folds (button) showed [7c 7d] and won (750) with a pair of Sevens
Seat 6: Normal showed [Ah Kd] and lost with high card Ace''';

const String _farButtonBlock =
    '''PokerStars Hand #202: Hold'em No Limit (1/2) - 2025/02/02 02:02:02 ET
Table 'Neg' 3-max Seat #11 is the button
Seat 1: P1 (200 in chips)
Seat 2: P2 (200 in chips)
Seat 3: P3 (200 in chips)
P1: posts small blind 1
P2: posts big blind 2
*** HOLE CARDS ***
Dealt to P3 [Qd Qs]
P3: raises 4 to 6
P1: folds
P2: calls 4
*** FLOP *** [2h 2d 2s]
P2: checks
P3: bets 8
P2: raises 40 to 48
P3: calls 40
*** TURN *** [2h 2d 2s] [Kh]
P2: bets 100
P3: calls 100
*** RIVER *** [2h 2d 2s Kh] [3c]
P2: checks
P3: checks
*** SHOW DOWN ***
P2: shows [Ks Kd] (a full house, Kings full of Twos)
P3: shows [Qd Qs] (a full house, Twos full of Queens)
P2 collected 309 from pot
*** SUMMARY ***
Total pot 309 | Rake 0
Board [2h 2d 2s Kh 3c]
Seat 1: P1 (small blind) folded before Flop
Seat 2: P2 (big blind) showed [Ks Kd] and won (309) with a full house, Kings full of Twos
Seat 3: P3 showed [Qd Qs] and lost with a full house, Twos full of Queens''';

void main() {
  group('archetypes: seat wrap-around (TS-pinned)', () {
    test('botNameFor wraps both ways round the 10 names', () {
      expect([0, 1, 5, 9, 10, 11, 20].map(botNameFor).toList(), [
        'Chidwick',
        'Ivey',
        'Hellmuth',
        'Galfond',
        'Chidwick',
        'Ivey',
        'Chidwick',
      ]);
    });

    test('archetypeForSeat cycles TAG/Station/LAG/Nit/TAG/LAG', () {
      expect(
        [
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          12,
        ].map(archetypeForSeat).map((a) => a.label).toList(),
        ['TAG', 'Station', 'LAG', 'Nit', 'TAG', 'LAG', 'TAG', 'LAG'],
      );
    });
  });

  group('hand_engine: degenerate actions', () {
    // Amount-less raise (falls back to currentBet + lastRaiseSize), an
    // amount-less bet (min(bb, maxTotal)), `raise` to 0 and `bet` to -50
    // (both clamp through commit), a `post` no-op, and an over-sized call /
    // raise clamped to the stack — driven by the same mulberry32(983)
    // stream Node used for `Math.random`.
    test('log transcript matches the desktop for a 6-max table', () {
      final rng = Mulberry32(983);
      var s = createTable(
        const GameConfig(
          seats: 6,
          startingStack: 500,
          smallBlind: 10,
          bigBlind: 20,
        ),
        rng: rng,
      );
      s = startHand(s, rng: rng);
      const seq = <Action>[
        Action(ActionType.raise),
        Action(ActionType.call),
        Action(ActionType.post),
        Action(ActionType.check),
        Action(ActionType.bet),
        Action(ActionType.raise, amount: 0),
        Action(ActionType.bet, amount: -50),
        Action(ActionType.call, amount: 99999),
        Action(ActionType.raise, amount: 999999),
      ];
      int i = 0;
      int guard = 0;
      while (s.phase == GamePhase.betting && s.toAct != null && guard++ < 60) {
        s = applyAction(s, s.toAct!, seq[i++ % seq.length]);
      }
      expect(
        s.log.map((e) => e.text).join(' // '),
        'Hand #1 · blinds 10/20 // Negreanu raises to 40 // Polk calls 40 // '
        'Hellmuth checks // You bets 20 // Ivey raises to 0 // '
        'Negreanu bets 20 // Polk calls -20 // Selbst raises to 500 (all-in) // '
        'Hellmuth raises to 500 (all-in) // You calls 480 (all-in) // '
        'Negreanu checks // Polk bets 20 // Ivey raises to 0 // '
        'Negreanu bets 20 // Polk calls -20 // Ivey raises to 500 (all-in) // '
        'Negreanu raises to 500 (all-in) // Polk calls 460 (all-in) // '
        'Flop — Kd 6d 7c // Turn — Kd 6d 7c 5s // River — Kd 6d 7c 5s 2c // '
        'Selbst wins 3000 (Pot)',
      );
      expect(s.phase, GamePhase.handOver);
      expect(s.pot, 3000);
      expect(s.lastRaiseSize, 20);
      expect(s.players.map((p) => p.stack).toList(), [0, 0, 0, 0, 3000, 0]);
    });

    test('applyAction never mutates the state it was handed', () {
      final rng = Mulberry32(4711);
      var s = createTable(
        const GameConfig(
          seats: 6,
          startingStack: 400,
          smallBlind: 10,
          bigBlind: 20,
        ),
        rng: rng,
      );
      s = startHand(s, rng: rng);
      s.botRanges[1] = ['AA', 'KK'];
      final before = s;
      final beforePot = before.pot;
      final beforeStacks = before.players.map((p) => p.stack).toList();
      final beforeLog = before.log.length;
      final beforeRange = List<HandLabel>.of(before.botRanges[1]!);
      final after = applyAction(before, before.toAct!, const Action.raise(120));
      expect(after.pot, isNot(beforePot));
      expect(before.pot, beforePot);
      expect(before.players.map((p) => p.stack).toList(), beforeStacks);
      expect(before.log.length, beforeLog);
      expect(before.botRanges[1], beforeRange);
      expect(identical(before.botRanges[1], after.botRanges[1]), isFalse);
    });
  });

  group('bot_brain: narrowRange on long stored ranges (TS-pinned)', () {
    // Ranges with duplicate labels and labels the board fully blocks, on the
    // river (exact evaluateInts scores) and on the flop (seeded 80-trial
    // equity samples) — the ordering below is the desktop's stable sort.
    test('river, aggro', () {
      final kept = narrowRange(
        'QJs,99,74s,43o,T3s,J4s,Q9s,T6o,Q8o,55,T8o,AKs,ATo,A3o,Q4o,A3s,Q8s,92s,'
                'A9s,T4s,63o,Q4o,65o,88,K8o,A9o,Q8s,QJo,86s,T2o,K9s,77,52s,K3o,'
                'K7o,K9s'
            .split(','),
        const ['7h', '3c', '4d', '4h', 'Qc'],
        NarrowKind.aggro,
        '87o',
      );
      expect(
        kept.join(','),
        '77,Q4o,Q4o,74s,43o,65o,J4s,T4s,QJs,QJo,Q9s,Q8o,Q8s,Q8s,99,88,T6o,T2o,'
        '92s,86s,52s',
      );
    });

    test('flop, aggro', () {
      final kept = narrowRange(
        'KJs,AA,77,ATs,Q6o,T3s,J3s,84s,A7o,A6o,J2o,J6o,93s,J7o,Q4o,Q8s,A8o,92o,'
                'J2o,93s,86o,32s,44,72s,64s,74s,Q4o,K5s,K6s,96o,A4s,A8s'
            .split(','),
        const ['9h', '3h', 'Ts'],
        NarrowKind.aggro,
        'T9s',
      );
      expect(
        kept.join(','),
        'T3s,93s,93s,ATs,AA,92o,96o,77,J3s,KJs,Q8s,44,32s,K5s,J2o,84s,72s,74s,'
        '64s',
      );
    });

    test('river, check', () {
      final kept = narrowRange(
        '82o,A3o,Q5s,KQo,72o,ATo,98o,84o,Q8o,JTs,QTo,T9o,AQo,54o,Q3o,KQs,Q5o,'
                '83s,62s,AKo,98o,Q4s,K3o,KTo,A3o,75o,92o,86s,AKo'
            .split(','),
        const ['5d', 'Jc', 'As', '7d', '6c'],
        NarrowKind.check,
        'T5o',
      );
      expect(
        kept.join(','),
        '75o,AKo,AKo,AQo,ATo,A3o,A3o,JTs,72o,86s,62s,Q5s,Q5o,54o,KQo,KQs,KTo,'
        'K3o,QTo,Q8o,Q3o,Q4s,T9o,92o,82o,83s',
      );
    });

    test('flop, check', () {
      final kept = narrowRange(
        'T6s,K3s,K9o,AQo,T5s,32s,A3o,Q9o,94s,J8s,62s,K6s,QJo,Q8s,AQs,K6o,T5s,'
                'J6s,J9s,97s,Q2o,K4s,99,QTo,Q6s,K6o,43o,K9s,83s,J8s,42s,K2s,98s,'
                'A3o,J4s,K7o,44,64s,T2s,J3s,86s'
            .split(','),
        const ['Kd', '6d', 'Tc'],
        NarrowKind.check,
        'T9o',
      );
      expect(
        kept.join(','),
        'K2s,T2s,T6s,K9o,QTo,T5s,T5s,J6s,K4s,K3s,QJo,AQo,AQs,Q9o,86s,62s,99,'
        '64s,Q6s,44,Q8s,J3s,98s,A3o,Q2o,A3o,J9s,97s,J8s,J8s,94s,J4s,83s,42s,'
        '43o,32s',
      );
    });
  });

  group('hand_history: split-pot rounding, uncalled bet, post line', () {
    // 725 split two ways is Math.round(362.5) = 363 each; the hero's 175
    // uncalled river bet comes back off his share (363 - 175 = 188), so the
    // summary's "Total pot" is 551, not 725.
    test('formatHand matches the desktop verbatim', () {
      final h = _craftedHand();
      expect(
        formatHand(h),
        _normaliseDate(
          '''PokerStars Hand #175000000000007: Hold'em No Limit (10/20) - 2025/06/16 00:06:40 ET
Table 'All-In Dojo' 3-max Seat #3 is the button
Seat 1: You (1000 in chips)
Seat 2: Ivey (1000 in chips)
Seat 3: Polk (1000 in chips)
You: posts small blind 10
Ivey: posts big blind 20
*** HOLE CARDS ***
Dealt to You [Ah Kd]
Polk: posts
Polk: raises 40 to 60
You: calls 50
Ivey: calls 40
*** FLOP *** [2c 7d Qs]
You: checks
Ivey: checks
Polk: bets 90
You: raises 175 to 265
Ivey: calls 265
Polk: folds
*** TURN *** [2c 7d Qs] [9h]
You: checks
Ivey: checks
*** RIVER *** [2c 7d Qs 9h] [3d]
You: bets 175
Ivey: folds
Uncalled bet (175) returned to You
You collected 188 from pot
Ivey collected 363 from pot
*** SUMMARY ***
Total pot 551 | Rake 0
Board [2c 7d Qs 9h 3d]
Seat 1: You (small blind) collected (188)
Seat 2: Ivey (big blind) folded on the River
Seat 3: Polk (button) folded on the Flop''',
          h.startedAt,
        ),
      );
    });

    test('buildReplayFrames matches the desktop verbatim', () {
      final frames = buildReplayFrames(_craftedHand());
      expect(
        frames
            .map(
              (f) =>
                  '${f.street.label}|${f.text}|${f.board.join()}|${f.pot}|'
                  '${f.folded.join(',')}|${f.revealAll ? 1 : 0}',
            )
            .toList(),
        [
          'preflop|Blinds 0.5/1 bb posted.||30||0',
          'preflop|||30||0',
          'preflop|Polk raises to 3 bb||90||0',
          'preflop|You calls 2.5 bb||140||0',
          'preflop|Ivey calls 2 bb||180||0',
          'flop|Flop: 2c 7d Qs|2c7dQs|180||0',
          'flop|You checks|2c7dQs|180||0',
          'flop|Ivey checks|2c7dQs|180||0',
          'flop|Polk bets 4.5 bb|2c7dQs|270||0',
          'flop|You raises to 13.3 bb|2c7dQs|535||0',
          'flop|Ivey calls 13.3 bb|2c7dQs|800||0',
          'flop|Polk folds|2c7dQs|800|2|0',
          'turn|Turn: 2c 7d Qs 9h|2c7dQs9h|800|2|0',
          'turn|You checks|2c7dQs9h|800|2|0',
          'turn|Ivey checks|2c7dQs9h|800|2|0',
          'river|River: 2c 7d Qs 9h 3d|2c7dQs9h3d|800|2|0',
          'river|You bets 8.8 bb|2c7dQs9h3d|975|2|0',
          'river|Ivey folds|2c7dQs9h3d|975|2,1|0',
          'showdown|You, Ivey win 36.3 bb.|2c7dQs9h3d|975|2,1|1',
        ],
      );
    });
  });

  group('hh_import: parser edge cases (TS-pinned)', () {
    test('names that collide with the parser vocabulary', () {
      final r = parsePokerStars(_collidingNamesBlock, now: 0);
      expect(r.skipped, 0);
      expect(r.hands.length, 1);
      final h = r.hands.single;
      expect(h.seats.map((s) => s.name).toList(), [
        'Seat 5: Bob',
        'he: folds',
        'x collected 999 from',
        'shows [Ah] guy',
        'posts small blind',
        'Normal',
      ]);
      expect(h.heroName, 'Normal');
      expect(h.holes[5], ['Ah', 'Kd']);
      expect(h.holes[1], ['7c', '7d']);
      // "Seat 5: folds" resolves to the name "Seat 5", which is not a seat,
      // so no action is recorded for it — exactly as on the desktop.
      expect(
        h.actions
            .take(6)
            .map((a) => '${a.name}/${a.type.label}/${a.amount}')
            .toList(),
        [
          'Normal/raise/60',
          'he: folds/call/60',
          'x collected 999 from/fold/0',
          'shows [Ah] guy/fold/0',
          'he: folds/bet/100',
          'Normal/call/100',
        ],
      );
      expect(h.potResults.single.winners, [1]);
      expect(h.potResults.single.amount, 750);
    });

    test('a button seat number past the table falls back to MP', () {
      // JS `%` keeps the dividend's sign, so seats 0 and 2 index the position
      // table with -1 / -2 and land on the desktop's "MP" fallback.
      final r = parsePokerStars(_farButtonBlock, now: 0);
      expect(r.hands.length, 1);
      final h = r.hands.single;
      expect(h.button, 10);
      expect(h.seats.map((s) => s.position.label).toList(), [
        'MP',
        'BTN',
        'MP',
      ]);
      expect(h.sbSeat, 0);
      expect(h.bbSeat, 1);
      expect(h.id, 202);
    });
  });

  group('hand_history: corrupt (NaN) amounts behave like the desktop', () {
    // REGRESSION: `formatHand` sorted the per-seat commitments with
    // `(b.amt - a.amt).sign.toInt()`, which throws "Infinity or NaN toInt"
    // as soon as one amount is NaN — and `Math.round(...).toInt()` did the
    // same for the collected shares. JS `Array.prototype.sort` treats a NaN
    // comparator result as 0 and `Math.round(NaN)` is just NaN, so the
    // desktop prints "NaN" and finishes. Exporting an imported session that
    // contained a mangled amount line used to crash here.
    test('a mangled amount parses to NaN on both sides', () {
      final r = parsePokerStars(_corruptBlock, now: 0);
      expect(r.skipped, 0);
      final amounts = r.hands.single.actions.map((a) => a.amount).toList();
      expect(amounts.length, 5);
      expect((amounts[0] as double).isNaN, isTrue);
      expect(amounts[1], 0);
      expect(amounts[2], 0);
      expect((amounts[3] as double).isNaN, isTrue);
      expect((amounts[4] as double).isNaN, isTrue);
    });

    test('formatHand does not throw and matches the desktop text', () {
      final h = parsePokerStars(_corruptBlock, now: 0).hands.single;
      expect(
        formatHand(h),
        _normaliseDate(
          '''PokerStars Hand #175737654900009: Hold'em No Limit (10/20) - 2025/09/09 09:09:09 ET
Table 'All-In Dojo' 3-max Seat #1 is the button
Seat 1: A (500 in chips)
Seat 2: B (500 in chips)
Seat 3: C (500 in chips)
B: posts small blind 10
C: posts big blind 20
*** HOLE CARDS ***
Dealt to A [Ah Kd]
A: calls NaN
B: folds
C: checks
*** FLOP *** [2c 3d 4h]
C: bets NaN
A: calls NaN
*** SUMMARY ***
Total pot 0 | Rake 0
Board [2c 3d 4h]
Seat 1: A (button) mucked
Seat 2: B (small blind) folded before Flop
Seat 3: C (big blind) mucked''',
          h.startedAt,
          exportId: exportHandId(h),
        ),
      );
    });

    test('buildReplayFrames propagates NaN like the desktop', () {
      final h = parsePokerStars(_corruptBlock, now: 0).hands.single;
      expect(
        buildReplayFrames(h).map((f) => '${f.text} | pot=${f.pot}').toList(),
        [
          'Blinds 0.5/1 bb posted. | pot=30',
          'A calls NaN bb | pot=NaN',
          'B folds | pot=NaN',
          'C checks | pot=NaN',
          'Flop: 2c 3d 4h | pot=NaN',
          'C bets NaN bb | pot=NaN',
          'A calls NaN bb | pot=NaN',
          'Hand over. | pot=NaN',
        ],
      );
    });

    test('analyzeImported skips NaN calls, like the desktop', () {
      final r = parsePokerStars(_corruptBlock, now: 0);
      final a = analyzeImported(r.hands, now: 0);
      expect(a.reviewed, 0);
      expect(a.leaks, isEmpty);
    });
  });
}
