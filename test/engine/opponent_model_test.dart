import 'dart:math';
import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence/serialization.dart';
import 'package:flutter_test/flutter_test.dart';

TableState river() {
  final s = startHand(
    createTable(
      const GameConfig(
        seats: 6,
        startingStack: 2000,
        smallBlind: 10,
        bigBlind: 20,
      ),
      rng: Random(1),
    ),
    rng: Random(2),
  );
  s.street = Street.river;
  s.board = ['Kc', '8d', '3h', '2s', '9c'];
  s.pot = 400;
  s.currentBet = 100;
  s.toAct = 1;
  s.aggressor = 0;
  for (final p in s.players) {
    p.hasFolded = p.id > 1;
    p.committed = 0;
  }
  s.players[0].committed = 100;
  s.players[0].hole = ['Ah', 'Qd'];
  s.players[1].hole = ['8s', '8h'];
  return s;
}

ObservedAction bet({int seat = 0, int wager = 100}) => ObservedAction(
  seat: seat,
  street: Street.river,
  type: ActionType.bet,
  pot: 300,
  price: 0,
  wager: wager,
  opponents: 1,
  board: ['Kc', '8d', '3h', '2s', '9c'],
);

void main() {
  test('one observation shrinks to a prior; repeated evidence changes it', () {
    final m = OpponentMemory();
    m.observe('x', 1);
    expect(m.estimate('x', .2), lessThan(.3));
    for (var i = 0; i < 30; i++) {
      m.observe('x', 1);
    }
    expect(m.estimate('x', .2), greaterThan(.75));
    m.decay(.1);
    expect(m.estimate('x', .2), lessThan(.5));
  });
  test(
    'fold model conditions on opponent, street and size; all-ins never fold',
    () {
      final p = river().players[0];
      double predict(
        int bettor, {
        Street street = Street.river,
        double fraction = .3,
      }) => foldProbability(
        p,
        bettor: bettor,
        street: street,
        fraction: fraction,
        opponents: 1,
      );
      final baseline = predict(1);
      for (var i = 0; i < 25; i++) {
        p.memory.observe('fold:river:small:hu', 1);
        p.memory.observe('fold:river:small:hu@1', 1);
      }
      expect(predict(1), greaterThan(baseline + .3));
      expect(predict(1), greaterThan(predict(2)));
      expect(predict(1, street: Street.flop), closeTo(baseline, 1e-12));
      expect(predict(1, fraction: 1), lessThan(predict(1)));
      p.isAllIn = true;
      expect(predict(1), 0);
    },
  );
  test(
    'every bot and hero generates public observations without mutating input',
    () {
      final s = river();
      final next = applyAction(s, 1, const Action.call());
      expect(s.observations, isEmpty);
      expect(s.players[1].memory.values, isEmpty);
      expect(next.observations.last.seat, 1);
      expect(next.players[1].memory.values['fold:river:small:hu'], [0, 1]);
    },
  );
  test(
    'only exposed contenders teach weak aggression, never learning-reveal folds',
    () {
      final s = river();
      s.observations = [bet(), bet(seat: 2)];
      s.players[2].hole = ['7h', '6h'];
      observeExposedShowdown(s, [0, 1]);
      expect(s.players[0].memory.values['weak:river:small:hu'], [1, 1]);
      expect(s.players[2].memory.values, isEmpty);
      // A set betting for value is not a bluff just because it later loses.
      s.observations = [bet(seat: 1)];
      observeExposedShowdown(s, [1]);
      expect(s.players[1].memory.values['weak:river:small:hu'], [0, 1]);
    },
  );
  test(
    'range and decisions ignore opponents private cards, ranges, deck and dials',
    () {
      final a = river();
      a.observations = [bet()];
      final b = a.clone();
      b.players[0].hole = ['Ks', 'Kh'];
      b.players[0].archetype = Archetype.station;
      b.botRanges[0] = ['KK'];
      b.deck = b.deck.reversed.toList();
      b.players[0].bluffAttempts = 100;
      b.players[0].bluffWins = 100;
      expect(
        publicOpponentCombos(a, a.players[0], a.players[1].hole!),
        publicOpponentCombos(b, b.players[0], b.players[1].hole!),
      );
      for (var seed = 0; seed < 12; seed++) {
        final x = decideBot(a.clone(), 1, rng: Random(seed));
        final y = decideBot(b.clone(), 1, rng: Random(seed));
        expect(
          (x.action.type, x.action.amount),
          (y.action.type, y.action.amount),
        );
      }
    },
  );
  test('caught bluffs increase weak combos, observed value reduces them', () {
    final s = river();
    s.observations = [bet()];
    final p = s.players[0];
    final unknown = observedWeakRate(p, bet());
    for (var i = 0; i < 25; i++) {
      p.memory.observe('weak:river:small:hu', 1);
    }
    expect(observedWeakRate(p, bet()), greaterThan(unknown));
    final bluffing = publicOpponentCombos(s, p, s.players[1].hole!);
    p.memory.values.clear();
    for (var i = 0; i < 25; i++) {
      p.memory.observe('weak:river:small:hu', 0);
    }
    final value = publicOpponentCombos(s, p, s.players[1].hole!);
    double weakShare(List<List<int>> combos) =>
        combos
            .where(
              (c) =>
                  categoryOfScore(
                    evaluateScore([...c, ...s.board.map(cardToInt)]),
                  ) ==
                  HandCategory.highCard,
            )
            .length /
        combos.length;
    expect(weakShare(bluffing), greaterThan(weakShare(value)));
  });
  test('a bluff catcher continues more against repeatedly exposed bluffs', () {
    final s = river();
    s.players[1].hole = ['8s', '7h'];
    s.players[1].archetype = Archetype.tag;
    s.players[0].vpipThisHand = true;
    s.observations = [bet(wager: 250)];
    s.pot = 550;
    s.currentBet = 250;
    s.players[0].committed = 250;
    int continues(bool bluffer) {
      s.players[0].memory.values.clear();
      for (var n = 0; n < 25; n++) {
        s.players[0].memory.observe('weak:river:medium:hu', bluffer ? 1 : 0);
      }
      var count = 0;
      for (var n = 0; n < 32; n++) {
        if (decideBot(s.clone(), 1, rng: Random(n)).action.type !=
            ActionType.fold) {
          count++;
        }
      }
      return count;
    }

    final value = continues(false);
    final bluff = continues(true);
    expect(bluff, greaterThan(value), reason: 'bluffs=$bluff, value=$value');
  });

  test(
    'multiway bluff must get through everyone; losing bluffs are rejected',
    () {
      final s = river();
      final one = fieldFoldProbability(
        [s.players[0]],
        bettor: 1,
        street: Street.flop,
        fraction: .6,
      );
      final two = fieldFoldProbability(
        [s.players[0], s.players[2]],
        bettor: 1,
        street: Street.flop,
        fraction: .6,
      );
      expect(two, lessThan(one));
      expect(
        profitableBluff(foldProbability: .1, equity: .05, pot: 100, risk: 80),
        false,
      );
      expect(
        profitableBluff(foldProbability: .8, equity: .05, pot: 100, risk: 60),
        true,
      );
    },
  );
  test(
    'memory and pending action contexts survive save/resume, legacy defaults empty',
    () {
      final s = river();
      s.observations = [bet()];
      s.aggressorPreflop = 0;
      s.players[0].memory.observe('weak:river:small:hu', 1);
      s.players[1].bluffedThisHand = true;
      final restored = tableStateFromJson(tableStateToJson(s));
      expect(restored.observations.single.board, s.board);
      expect(restored.players[0].memory.toJson(), s.players[0].memory.toJson());
      expect(restored.aggressorPreflop, 0);
      expect(restored.players[1].bluffedThisHand, true);
      final old = tableStateToJson(s)..remove('observations');
      expect(tableStateFromJson(old).observations, isEmpty);
      restored.players[0].memory.observe('weak:river:small:hu', 0);
      expect(s.players[0].memory.values['weak:river:small:hu'], [1, 1]);
    },
  );
}
