/// Does the table still hand over its chips to the line in the real logs?
///
///   dart run tool/_probe.dart [hands]
///
/// The hero is calibrated to the ACTUAL measured session, not a synthetic
/// maniac. From 769 real hands across two sessions:
///
///     VPIP 89%   PFR 74%   3-bet 84% of chances, averaging 7.0bb
///     folds to a bot's open: 0%      folds to a bot's 3-bet: 0%
///     post-flop: bets made hands, gives up otherwise
///
/// Calibrating to the real line matters. A previous probe re-raised to 3x
/// from any seat and reported the exploit dead; the app was paying out
/// +130 bb/100 at the same time, because that probe never made the spots the
/// player actually makes.
library;

import 'dart:math';

import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/cards.dart';
import 'package:allin/engine/equity.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';

Action hero(TableState s, Random rng) {
  final la = legalActions(s);
  final hole = s.players[0].hole!;
  if (s.street == Street.preflop) {
    final facing = la.toCall > 0;
    final reraise = s.currentBet > s.bigBlind;
    if (facing && reraise && la.canRaise && rng.nextDouble() < .84) {
      final to = min(la.maxRaiseTo, max(la.minRaiseTo, 7 * s.bigBlind));
      return Action.raise(to);
    }
    if (!facing && la.canRaise && rng.nextDouble() < .74) {
      final to = min(
        la.maxRaiseTo,
        max(la.minRaiseTo, (2.4 * s.bigBlind).round()),
      );
      return Action.raise(to);
    }
    // Never folds before the flop — 0% in 769 hands.
    if (la.canCall) return Action.call(amount: la.callAmount);
    return la.canCheck ? const Action.check() : const Action.fold();
  }
  final e =
      equityVsRandom(
        comboToInts((hole[0], hole[1])),
        s.board.map(cardToInt).toList(),
        iters: 200,
        rng: rng,
      ).equity;
  if (la.toCall > 0) {
    if (e > .72 && la.canRaise && rng.nextDouble() < .35) {
      final to = min(
        la.maxRaiseTo,
        max(la.minRaiseTo, s.currentBet + (s.pot * .8).round()),
      );
      return Action.raise(to);
    }
    return e > .55 ? Action.call(amount: la.callAmount) : const Action.fold();
  }
  if (la.canBet && e > .58) {
    return Action.bet(
      min(la.maxRaiseTo, max(la.minRaiseTo, (s.pot * .66).round())),
    );
  }
  return la.canCheck ? const Action.check() : const Action.fold();
}

void main(List<String> args) {
  final hands = args.isNotEmpty ? int.parse(args[0]) : 250;
  // "bots" puts a bot in seat 0 too, which takes the deliberately insane
  // probe hero out of the picture and measures the table's own health.
  final botsOnly = args.length > 1 && args[1] == 'bots';
  const seeds = [11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 222, 333];
  var netAll = 0.0;
  var tb = 0, tbTookIt = 0, tbFaced = 0, tbFolded = 0;
  var allIn = 0, flops = 0, showdowns = 0, dealt = 0;
  final allInBy = <String, int>{};
  final rates = <double>[];

  for (final seed in seeds) {
    final rng = Mulberry32(seed);
    var s = createTable(
      const GameConfig(
        seats: 6,
        startingStack: 2000,
        smallBlind: 10,
        bigBlind: 20,
      ),
      rng: rng,
    );
    if (botsOnly) {
      // Seat 0 has no archetype, so `decideBot` folds every hand there.
      s.players[0].archetype = Archetype.tag;
    }
    final bb = s.bigBlind;
    var net = 0.0;
    for (var h = 0; h < hands; h++) {
      for (final p in s.players) {
        p.stack = 2000;
      }
      s = startHand(s, rng: rng);
      final before = s.players[0].stack + s.players[0].committedTotal;
      var guard = 0;
      var threeBet = false;
      while (s.phase == GamePhase.betting && s.toAct != null && guard++ < 400) {
        final seat = s.toAct!;
        final street = s.street;
        final wasTb = threeBet && street == Street.preflop;
        if (seat == 0 && !botsOnly) {
          final a = hero(s, rng);
          if (street == Street.preflop &&
              a.type == ActionType.raise &&
              s.currentBet > s.bigBlind) {
            threeBet = true;
            tb++;
          }
          s = applyAction(s, seat, a);
        } else {
          final d = decideBot(s, seat, rng: rng);
          if (wasTb && s.currentBet > s.bigBlind * 4.5 && s.aggressor == 0) {
            tbFaced++;
            if (d.action.type == ActionType.fold) tbFolded++;
          }
          if (d.action.amount != null &&
              d.action.amount! >=
                  s.players[seat].stack + s.players[seat].committed) {
            allIn++;
            allInBy[street.label] = (allInBy[street.label] ?? 0) + 1;
          }
          s = applyAction(s, seat, d.action);
          if (d.range != null) s.botRanges[seat] = d.range!;
        }
      }
      dealt++;
      if (s.board.length >= 3) {
        flops++;
      }
      if ((s.summary?.showdown.length ?? 0) > 1) showdowns++;
      if (threeBet && s.board.isEmpty && s.players[0].stack > before) {
        tbTookIt++;
      }
      net += (s.players[0].stack - before) / bb;
    }
    rates.add(net / hands * 100);
    netAll += net;
  }
  final mean = rates.reduce((a, b) => a + b) / rates.length;
  final sorted = [...rates]..sort();
  final median = sorted[sorted.length ~/ 2];
  String pc(int a, int b) =>
      b == 0 ? '   -' : '${(100 * a / b).toStringAsFixed(1)}%';

  // ignore: avoid_print
  print('''
the logged line vs the table — $hands x ${seeds.length} seeds
  hero win rate            mean ${mean.toStringAsFixed(1)}  median ${median.toStringAsFixed(1)}   [real logs: +130]
  bots fold to the 3-bet   ${pc(tbFolded, tbFaced)}   [real logs: 94.5%]
  3-bets taken uncontested ${pc(tbTookIt, tb)}   [real logs: 93%]
  saw a flop               ${pc(flops, dealt)}   [live: ~60%]
  reached showdown         ${pc(showdowns, dealt)}   [live: ~25%]
  all-in actions           ${pc(allIn, dealt)}   [live: ~2%]
  all-ins by street        $allInBy
  (net ${netAll.toStringAsFixed(0)} bb over $dealt hands)''');
}
