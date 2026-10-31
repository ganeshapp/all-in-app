import 'dart:convert';

import 'package:allin/services/persistence/serialization.dart';
import 'package:flutter_test/flutter_test.dart';

String _hand(List<Map<String, Object?>> actions, {int hero = 0}) => jsonEncode({
  'seats': [
    {'seat': 0, 'isHero': hero == 0},
    {'seat': 1, 'isHero': hero == 1},
  ],
  'actions': actions,
});

void main() {
  group('preflopFlagsFromHandJson', () {
    test('calling a raise is VPIP but not PFR', () {
      final f = preflopFlagsFromHandJson(
        _hand([
          {'street': 'preflop', 'seat': 0, 'type': 'post', 'amount': 10},
          {'street': 'preflop', 'seat': 1, 'type': 'raise', 'amount': 50},
          {'street': 'preflop', 'seat': 0, 'type': 'call', 'amount': 40},
        ]),
      );
      expect(f!.vpip, isTrue);
      expect(f.pfr, isFalse);
    });

    test('checking the big blind is NOT playing the hand', () {
      // The subtlety the whole backfill turns on: a blind is not voluntary.
      final f = preflopFlagsFromHandJson(
        _hand([
          {'street': 'preflop', 'seat': 0, 'type': 'post', 'amount': 20},
          {'street': 'preflop', 'seat': 0, 'type': 'check'},
          {'street': 'flop', 'seat': 0, 'type': 'bet', 'amount': 40},
        ]),
      );
      expect(f!.vpip, isFalse, reason: 'posting a blind is not VPIP');
      expect(f.pfr, isFalse, reason: 'and a flop bet is not a pre-flop raise');
    });

    test('raising is both', () {
      final f = preflopFlagsFromHandJson(
        _hand([
          {'street': 'preflop', 'seat': 0, 'type': 'raise', 'amount': 50},
        ]),
      );
      expect(f!.vpip, isTrue);
      expect(f.pfr, isTrue);
    });

    test('reads the hero seat from the payload, not a hardcoded 0', () {
      final f = preflopFlagsFromHandJson(
        _hand(hero: 1, [
          {'street': 'preflop', 'seat': 0, 'type': 'raise', 'amount': 50},
          {'street': 'preflop', 'seat': 1, 'type': 'fold'},
        ]),
      );
      expect(f!.vpip, isFalse, reason: "seat 0's raise is not the hero's");
    });

    test('an unusable payload returns null rather than guessing', () {
      expect(preflopFlagsFromHandJson('not json'), isNull);
      expect(preflopFlagsFromHandJson('{}'), isNull);
      expect(preflopFlagsFromHandJson('[]'), isNull);
    });
  });
}
