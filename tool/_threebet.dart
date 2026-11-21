/// Fold-to-3-bet, hand by hand, at a price you choose.
///
///   dart run tool/_threebet.dart [3-bet size in chips]
///
/// The leak this measures: across 769 logged hands the bots folded 94.5% of
/// the time to a 7bb 3-bet and never adjusted. A re-raise is looked up as
/// `myPosition_vs_raiserPosition` and the brain skips charts entirely once
/// the bet is past 4.5bb, so there was no book for the spot and the fallback
/// was to fold.
///
/// Two spots, because they are priced completely differently and only one of
/// them was the leak:
///
///   - the bot has ALREADY OPENED and faces a re-raise. It is getting a good
///     price on the chips it still owes, and folding here is the error the
///     logs are full of.
///   - the bot has NOT acted and faces an open plus a 3-bet behind it. It
///     owes the whole raise, out of position, with a player still to act.
///     Folding most hands here is correct, so a low fold rate would be the
///     bug.
///
/// Which is why the regression test in `bot_brain_test.dart` asserts the
/// SPREAD between them and the response to price, not a magic rate.
library;

import 'dart:math';

import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/types.dart';

const GameConfig _cfg = GameConfig(
  seats: 6,
  startingStack: 2000,
  smallBlind: 10,
  bigBlind: 20,
);

const List<String> _deck = [
  '2c', '3d', '4h', '5s', '6c', '7d', '8h', '9s', 'Tc', 'Jd', //
  '9c', 'Th', '2s', 'Js', '3h', '8d', 'Kc', 'Qc',
];

const Map<int, List<String>> _holes = {
  0: ['Ah', 'Qd'],
  1: ['5c', '6d'],
  2: ['Ks', 'Kd'],
  3: ['4c', '4d'],
  4: ['Jc', 'Tc'],
  5: ['6s', '5h'],
};

class _Fixed implements Random {
  _Fixed(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => (v * max).toInt();
  @override
  bool nextBool() => v < 0.5;
}

/// Hands with a claim to continue for a good price. Deliberately NOT the
/// set a chart would hold — if the measure encoded the exploit it is meant
/// to catch, it would stop being a measure.
const List<List<String>> kContinues = [
  ['Ac', 'Ad'], ['Kc', 'Kd'], ['Qc', 'Qd'], ['Jc', 'Jd'], //
  ['Tc', 'Td'], ['9c', '9d'], ['8c', '8d'], ['7c', '7d'],
  ['Ac', 'Kd'], ['Ac', 'Ks'], ['Ac', 'Qs'], ['Ac', 'Js'],
  ['Kc', 'Qs'], ['Ad', '5d'], ['Jc', 'Ts'], ['Qc', 'Js'],
];

TableState _seat(int seat, Archetype a, List<String> hole) {
  var s = createTable(_cfg, rng: Random(1));
  s.button = 0;
  s.players[seat].archetype = a;
  s = startHand(s, rng: Random(7));
  s.deck = List<String>.of(_deck);
  for (final p in s.players) {
    p.hole = List<String>.of(p.id == seat ? hole : _holes[p.id]!);
  }
  return s;
}

/// Seat 3 (UTG) opens 50, folds through to seat 0 (BTN) who makes it [to],
/// the blinds fold, and UTG has to answer for [to] - 50.
TableState opened(Archetype a, List<String> hole, int to) {
  var s = _seat(3, a, hole);
  s = applyAction(s, 3, const Action.raise(50));
  s = applyAction(s, 4, const Action.fold());
  s = applyAction(s, 5, const Action.fold());
  s = applyAction(s, 0, Action.raise(to));
  s = applyAction(s, 1, const Action.fold());
  s = applyAction(s, 2, const Action.fold());
  return s;
}

/// Seat 3 opens 50, seat 4 makes it [to], and seat 5 (CO) has to answer for
/// the lot with seat 3 still behind.
TableState cold(Archetype a, List<String> hole, int to) {
  var s = _seat(5, a, hole);
  s = applyAction(s, 3, const Action.raise(50));
  return applyAction(s, 4, Action.raise(to));
}

/// Fold rate over [kContinues] x five RNG draws, and which hands survived.
(double, List<String>) foldRate(
  TableState Function(Archetype, List<String>) spot,
  Archetype arch,
  int seat,
) {
  var folds = 0, seen = 0;
  final kept = <String>[];
  for (final hole in kContinues) {
    final s = spot(arch, hole);
    var f = 0;
    for (final r in [0.05, 0.3, 0.5, 0.7, 0.95]) {
      seen++;
      if (decideBot(s, seat, rng: _Fixed(r)).action.type == ActionType.fold) {
        folds++;
        f++;
      }
    }
    if (f < 5) kept.add('${hole[0][0]}${hole[1][0]}');
  }
  return (folds / max(1, seen), kept);
}

void main(List<String> args) {
  final to = args.isNotEmpty ? int.parse(args[0]) : 160;
  for (final (label, spot, seat) in [
    ('already opened, owes ${to - 50} into ${80 + to}', opened, 3),
    ('cold, owes $to into ${30 + 50 + to}', cold, 5),
  ]) {
    // ignore: avoid_print
    print('\n$label  (3-bet to $to):');
    for (final arch in Archetype.values) {
      final (rate, kept) = foldRate((a, h) => spot(a, h, to), arch, seat);
      // ignore: avoid_print
      print(
        '  ${arch.name.padRight(8)} folds '
        '${(100 * rate).toStringAsFixed(0).padLeft(3)}%   keeps: '
        '${kept.join(" ")}',
      );
    }
  }
}
