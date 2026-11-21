// The evaluation function. These are the properties that make it an
// evaluator rather than another table of magic numbers — the arithmetic the
// bots were missing when one of them folded for 12 chips into a pot of 534.
import 'package:allin/engine/evaluate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the zero point', () {
    // Folding is the zero. Chips already in the pot are not yours and must
    // not enter the comparison — that single convention is what makes the
    // real bug (a fold for 12 into 534) impossible to choose.
    test('12 into 534 is a call, and by a mile', () {
      final ranked = priceActions(
        equity: 0.25,
        pot: 534,
        callCost: 12,
        canCall: true,
      );
      expect(ranked.first.kind, PricedKind.call);
      final call = ranked.firstWhere((a) => a.kind == PricedKind.call);
      expect(call.ev, greaterThan(100));
    });

    test('even a nearly dead hand calls 12 into 534', () {
      expect(
        priceActions(
          equity: 0.04,
          pot: 534,
          callCost: 12,
          canCall: true,
        ).first.kind,
        PricedKind.call,
      );
      // And the line is where it should be, not wherever is convenient.
      expect(
        priceActions(
          equity: 0.01,
          pot: 534,
          callCost: 12,
          canCall: true,
        ).first.kind,
        PricedKind.fold,
      );
    });

    test('the price matters, not the size of the number', () {
      expect(
        priceActions(
          equity: 0.4,
          pot: 100,
          callCost: 20,
          canCall: true,
        ).first.kind,
        PricedKind.call,
      );
      expect(
        priceActions(
          equity: 0.4,
          pot: 100,
          callCost: 300,
          canCall: true,
        ).first.kind,
        PricedKind.fold,
      );
    });
  });

  group('callEv', () {
    test('at the pot odds, calling is exactly zero', () {
      // 50 to win 100 needs 50/150 = 33.3%.
      expect(callEv(1 / 3, 100, 50).abs(), lessThan(1e-9));
      expect(callEv(0.34, 100, 50), greaterThan(0));
      expect(callEv(0.32, 100, 50), lessThan(0));
    });

    test('poor realisation is worth less', () {
      expect(callEv(0.5, 100, 50, 0.5), lessThan(callEv(0.5, 100, 50)));
    });
  });

  group('raiseEv', () {
    test('a pure bluff is fold equity minus what it loses', () {
      expect(
        (raiseEv(0, 100, 50, 0.6) - (0.6 * 100 + 0.4 * -50)).abs(),
        lessThan(1e-9),
      );
    });

    // The caller matches our raise from further along than us: they already
    // have the current bet in. Counting their call as our full cost inflated
    // the called pot and made the raise outrank the call for a band of
    // equities where this function's own arithmetic says call.
    test('the caller only owes the raise minus what we owed', () {
      // Pot 240, we owe 110, we raise to 352 so our cost is 302. They put in
      // 302 - 110 = 192, so a called pot is 240 + 302 + 192 = 734, not 844.
      const pot = 240, cost = 302, toCall = 110;
      final got = raiseEv(1, pot, cost, 0, 1, toCall);
      expect(got, closeTo(pot + cost + (cost - toCall) - cost, 1e-9));
      // Over-counting is strictly generous, so the corrected figure is lower.
      expect(got, lessThan(raiseEv(1, pot, cost, 0)));
      // With nothing owed the two agree — that is the pre-existing contract.
      expect(raiseEv(0.5, pot, cost, 0.3, 1, 0), raiseEv(0.5, pot, cost, 0.3));
    });

    test('more folds, and a better hand, are each worth more', () {
      expect(
        raiseEv(0.5, 100, 50, 0.9),
        greaterThan(raiseEv(0.5, 100, 50, .1)),
      );
      expect(
        raiseEv(0.9, 100, 50, 0.2),
        greaterThan(raiseEv(0.2, 100, 50, .2)),
      );
    });
  });

  group('realisation', () {
    test('position is worth something and a crowd realises less', () {
      expect(realisation(1, true), greaterThan(realisation(1, false)));
      expect(realisation(3, false), lessThan(realisation(1, false)));
    });

    test('deep money is worse for the caller', () {
      expect(realisation(1, false, 20), lessThan(realisation(1, false, 2)));
    });

    test('stays a fraction at any input', () {
      for (final c in [(1, true, 1.0), (5, false, 50.0), (2, true, 0.0)]) {
        final r = realisation(c.$1, c.$2, c.$3);
        expect(r, greaterThan(0), reason: '$c');
        expect(r, lessThanOrEqualTo(1), reason: '$c');
      }
    });
  });

  group('chooseByEv', () {
    final ranked = priceActions(
      equity: 0.45,
      pot: 100,
      callCost: 30,
      canCall: true,
      canRaise: true,
      raiseTo: 90,
      raiseCost: 90,
      foldsEverybody: 0.5,
    );

    test('with no band the best action is always taken', () {
      final kinds = {
        for (var i = 0; i < 50; i++) chooseByEv(ranked, i / 50, 0).kind,
      };
      expect(kinds.length, 1);
    });

    test('with a wide band it mixes', () {
      final kinds = {
        for (var i = 0; i < 50; i++) chooseByEv(ranked, i / 50, 1000).kind,
      };
      expect(kinds.length, greaterThan(1));
    });

    // Mixing must never reach past the band into a clearly worse action.
    // This is the property that broke first: a band taken as a share of the
    // pot grew with the pot, and bots called off 157bb with J2o because a
    // -900 call counted as "close enough".
    test('a 900-worse call is never mixed in on a 50-chip band', () {
      const lopsided = [
        PricedAction(PricedKind.fold, 0),
        PricedAction(PricedKind.call, -900),
      ];
      for (var i = 0; i < 50; i++) {
        expect(chooseByEv(lopsided, i / 50, 50).kind, PricedKind.fold);
      }
    });

    // When the bot cannot cover the re-raise the engine returns the raiser's
    // excess uncalled, so those chips were never winnable. The branch passes
    // the reduced pot; this pins what that reduction is worth.
    test('a pot it cannot win does not make the call positive', () {
      // Stack 100 against a 350 re-raise into a pot of 480: 250 comes back.
      const onTable = 480, toCall = 350, canPay = 100;
      final winnable = onTable - (toCall - canPay);
      final honest = priceActions(
        equity: 0.25,
        pot: winnable,
        callCost: canPay,
        canCall: true,
        realise: 0.72,
      );
      final inflated = priceActions(
        equity: 0.25,
        pot: onTable,
        callCost: canPay,
        canCall: true,
        realise: 0.72,
      );
      expect(honest.first.kind, PricedKind.fold);
      expect(inflated.first.kind, PricedKind.call);
    });

    test('no options at all is a fold', () {
      expect(chooseByEv(const [], 0.5, 10).kind, PricedKind.fold);
    });
  });
}
