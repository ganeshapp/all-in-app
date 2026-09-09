/// The mobile rewrite of the engine's hand log (DESIGN.md §4.2 ticker, §4.11
/// P2 Log; the deviation is recorded in docs/ARCHITECTURE.md).
///
/// The engine keeps the desktop's strings ("You raises to 58", chips); every
/// mobile surface shows second-person verbs for the hero and big blinds. These
/// tests pin the whole rewritten set, including the lines a real hand produces.
library;

import 'dart:math';

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/hand_log_format.dart';
import 'package:flutter_test/flutter_test.dart';

const int _bb = 20;

LogEntry _entry(String text, [LogKind kind = LogKind.action]) =>
    LogEntry(id: 1, street: Street.preflop, text: text, kind: kind);

String _render(String text, {LogKind kind = LogKind.action, int bb = _bb}) =>
    HandLog.line(_entry(text, kind), bigBlind: bb).text;

void main() {
  group('the hero speaks in the second person (§4.2)', () {
    test('every action verb agrees with "you"', () {
      expect(_render('You folds'), 'You fold');
      expect(_render('You checks'), 'You check');
      expect(_render('You calls 40'), 'You call 2 bb');
      expect(_render('You bets 30'), 'You bet 1.5 bb');
      expect(_render('You raises to 58'), 'You raise to 2.9 bb');
      expect(_render('You posts SB 10'), 'You post SB 0.5 bb');
      expect(_render('You posts BB 20'), 'You post BB 1 bb');
      expect(
        _render('You posts small blind 10'),
        'You post small blind 0.5 bb',
      );
      expect(_render('You posts big blind 20'), 'You post big blind 1 bb');
      expect(_render('You posts ante 5'), 'You post ante 0.25 bb');
    });

    test('all-in keeps its suffix', () {
      expect(_render('You calls 740 (all-in)'), 'You call 37 bb (all-in)');
      expect(_render('You bets 2000 (all-in)'), 'You bet 100 bb (all-in)');
      expect(
        _render('You raises to 2000 (all-in)'),
        'You raise to 100 bb (all-in)',
      );
    });

    test('wins, uncontested and split pots', () {
      expect(
        _render('You wins 88 (uncontested)', kind: LogKind.result),
        'You win 4.4 bb (uncontested)',
      );
      expect(
        _render('You wins 520 (Pot)', kind: LogKind.result),
        'You win 26 bb (Pot)',
      );
      expect(
        _render('You, Ivey wins 520 (Main pot)', kind: LogKind.result),
        'You and Ivey win 26 bb (Main pot)',
      );
      expect(
        _render('You, Ivey, Polk wins 300 (Side pot 1)', kind: LogKind.result),
        'You, Ivey and Polk win 15 bb (Side pot 1)',
      );
    });
  });

  group('bots stay in the third person', () {
    test('every action verb is untouched but the amount is in bb', () {
      expect(_render('Ivey folds'), 'Ivey folds');
      expect(_render('Ivey checks'), 'Ivey checks');
      expect(_render('Ivey calls 50'), 'Ivey calls 2.5 bb');
      expect(_render('Ivey bets 20'), 'Ivey bets 1 bb');
      expect(_render('Negreanu raises to 60'), 'Negreanu raises to 3 bb');
      expect(_render('Dwan posts SB 10'), 'Dwan posts SB 0.5 bb');
      expect(_render('Dwan posts BB 20'), 'Dwan posts BB 1 bb');
      expect(
        _render('Hellmuth calls 740 (all-in)'),
        'Hellmuth calls 37 bb (all-in)',
      );
    });

    test('winners keep singular / plural agreement', () {
      expect(
        _render('Hellmuth wins 270 (Main pot)', kind: LogKind.result),
        'Hellmuth wins 13.5 bb (Main pot)',
      );
      expect(
        _render('Polk wins 88 (uncontested)', kind: LogKind.result),
        'Polk wins 4.4 bb (uncontested)',
      );
      expect(
        _render('Ivey, Polk wins 300 (Pot)', kind: LogKind.result),
        'Ivey and Polk win 15 bb (Pot)',
      );
    });
  });

  group('deal lines', () {
    test('the hand header converts the blinds and the ante', () {
      expect(
        _render('Hand #3 · blinds 10/20', kind: LogKind.deal),
        'Hand #3 · blinds 0.5 / 1 bb',
      );
      expect(
        _render('Hand #12 · blinds 10/20 · ante 5', kind: LogKind.deal),
        'Hand #12 · blinds 0.5 / 1 bb · ante 0.25 bb',
      );
    });

    test('the header converts against its own blinds', () {
      expect(
        _render('Hand #1 · blinds 25/50', kind: LogKind.deal, bb: 20),
        'Hand #1 · blinds 0.5 / 1 bb',
      );
    });

    test('street lines carry no chips and are passed through', () {
      expect(_render('Flop — 9s 3s 8d', kind: LogKind.deal), 'Flop — 9s 3s 8d');
      expect(
        _render('Turn — 9s 3s 8d Ad', kind: LogKind.deal),
        'Turn — 9s 3s 8d Ad',
      );
      expect(
        _render('River — 9s 3s 8d Ad Qd', kind: LogKind.deal),
        'River — 9s 3s 8d Ad Qd',
      );
    });
  });

  group('line metadata', () {
    test('isHero marks the hero rows P2 renders in text colour (§4.11)', () {
      expect(HandLog.line(_entry('You folds'), bigBlind: _bb).isHero, isTrue);
      expect(
        HandLog.line(
          _entry('You, Ivey wins 520 (Pot)', LogKind.result),
          bigBlind: _bb,
        ).isHero,
        isTrue,
      );
      expect(HandLog.line(_entry('Ivey folds'), bigBlind: _bb).isHero, isFalse);
      expect(
        HandLog.line(
          _entry('Flop — 9s 3s 8d', LogKind.deal),
          bigBlind: _bb,
        ).isHero,
        isFalse,
      );
    });

    test('id, street and kind survive the rewrite', () {
      const source = LogEntry(
        id: 42,
        street: Street.river,
        text: 'You raises to 58',
        kind: LogKind.action,
      );
      final line = HandLog.line(source, bigBlind: _bb);
      expect(line.id, 42);
      expect(line.street, Street.river);
      expect(line.kind, LogKind.action);
      expect(line.entry, same(source));
    });

    test('mobile-authored ticker lines pass through unchanged (§14)', () {
      const paused = 'Paused — tap to continue';
      expect(_render(paused, kind: LogKind.info), paused);
      const hint = "You're the button — you act first pre-flop, last after it";
      expect(_render(hint, kind: LogKind.info), hint);
    });

    test('clipboardText joins the rewritten lines (§4.2 long-press)', () {
      final log = [
        _entry('Hand #3 · blinds 10/20', LogKind.deal),
        _entry('Ivey raises to 60'),
        _entry('You calls 60'),
        _entry('Ivey wins 130 (Pot)', LogKind.result),
      ];
      expect(
        HandLog.clipboardText(log, bigBlind: _bb),
        [
          'Hand #3 · blinds 0.5 / 1 bb',
          'Ivey raises to 3 bb',
          'You call 3 bb',
          'Ivey wins 6.5 bb (Pot)',
        ].join('\n'),
      );
    });
  });

  test('every line a real hand writes is rewritten (no chip amounts left)', () {
    final rng = Random(3);
    var s = createTable(
      const GameConfig(
        seats: 6,
        startingStack: 2000,
        smallBlind: 10,
        bigBlind: 20,
        ante: 5,
      ),
      rng: rng,
    );
    for (var h = 0; h < 8; h++) {
      s = startHand(s, rng: rng);
      var guard = 0;
      while (s.phase != GamePhase.handOver && guard++ < 400) {
        final seat = s.toAct;
        if (seat == null) break;
        final legal = legalActions(s);
        final roll = rng.nextInt(10);
        final Action action;
        if (roll < 2 && legal.canFold) {
          action = const Action(ActionType.fold);
        } else if (roll < 6 && legal.canRaise) {
          action = Action(ActionType.raise, amount: legal.minRaiseTo);
        } else if (roll < 7 && legal.canBet) {
          action = Action(ActionType.bet, amount: legal.minRaiseTo);
        } else if (legal.canCheck) {
          action = const Action(ActionType.check);
        } else if (legal.canCall) {
          action = const Action(ActionType.call);
        } else {
          action = const Action(ActionType.fold);
        }
        s = applyAction(s, seat, action);
      }
    }

    final lines = HandLog.lines(s.log, bigBlind: s.bigBlind);
    expect(lines, isNotEmpty);
    // Every action / result line has a rewritten amount, and no line still
    // reads as third-person "You".
    for (final line in lines) {
      expect(line.text, isNot(contains('You folds')));
      expect(line.text, isNot(contains('You checks')));
      expect(line.text, isNot(contains('You calls')));
      expect(line.text, isNot(contains('You bets')));
      expect(line.text, isNot(contains('You raises')));
      expect(line.text, isNot(contains('You wins')));
      if (line.kind == LogKind.deal && line.text.startsWith('Hand #')) {
        expect(line.text, contains('blinds 0.5 / 1 bb'));
        expect(line.text, contains('ante 0.25 bb'));
      }
      final amount = RegExp(
        r'(?:to |calls |bets |wins |win |call |bet ) *(\d)',
      );
      if (amount.hasMatch(line.text)) {
        expect(line.text, contains(' bb'), reason: line.text);
      }
    }
    // The engine's own strings are untouched — the parity tests still hold.
    expect(s.log.any((e) => e.text == 'You folds'), isTrue);
  });

  group('replay frames speak the phone\'s voice (§7.7)', () {
    test('the hero gets the second person', () {
      expect(HandLog.replayFrame('You calls 2.5 bb'), 'You call 2.5 bb');
      expect(HandLog.replayFrame('You folds'), 'You fold');
      expect(HandLog.replayFrame('You checks'), 'You check');
      expect(HandLog.replayFrame('You bets 9 bb'), 'You bet 9 bb');
      expect(
        HandLog.replayFrame('You raises to 100 bb (all-in)'),
        'You raise to 100 bb (all-in)',
      );
    });

    test('a bot keeps the third person', () {
      expect(HandLog.replayFrame('Dwan calls 2.5 bb'), 'Dwan calls 2.5 bb');
      expect(HandLog.replayFrame('Dwan folds'), 'Dwan folds');
    });

    test('the result line agrees with its subject', () {
      // `buildReplayFrames` writes "win" for every subject (desktop parity).
      expect(HandLog.replayFrame('Dwan win 39 bb.'), 'Dwan wins 39 bb.');
      expect(HandLog.replayFrame('hero win 200 bb.'), 'hero wins 200 bb.');
      expect(HandLog.replayFrame('You win 26 bb.'), 'You win 26 bb.');
      expect(
        HandLog.replayFrame('Dwan, Ivey win 39 bb.'),
        'Dwan, Ivey win 39 bb.',
      );
    });

    test('board and blind frames pass through untouched', () {
      expect(HandLog.replayFrame('Flop: Ah Kd 7c'), 'Flop: Ah Kd 7c');
      expect(
        HandLog.replayFrame('Blinds 0.5/1 bb posted.'),
        'Blinds 0.5/1 bb posted.',
      );
      expect(HandLog.replayFrame('Hand over.'), 'Hand over.');
    });
  });
}
