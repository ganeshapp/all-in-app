/// Lightweight opponent inference from public actions and exposed showdowns.
/// It never reads an opponent's hole cards, dials, archetype, or Peek range.
library;

import 'dart:math';

import 'cards.dart';
import 'equity.dart';
import 'evaluator.dart';
import 'notation.dart';
import 'prng.dart';
import 'profile.dart';
import 'types.dart';

String actionContext(Street street, double fraction, int opponents) =>
    '${street.name}:${fraction <= .4
        ? 'small'
        : fraction <= .85
        ? 'medium'
        : 'large'}:'
    '${opponents > 1 ? 'multi' : 'hu'}';

void observePublicAction(TableState s, Player p, Action action, int toCall) {
  if (action.type == ActionType.post) return;
  final aggressive =
      action.type == ActionType.bet || action.type == ActionType.raise;
  final event = ObservedAction(
    seat: p.id,
    street: s.street,
    type: action.type,
    pot: s.pot,
    price: max(0, toCall),
    wager:
        aggressive
            ? ((action.amount ?? (s.currentBet + s.lastRaiseSize)) -
                    p.committed)
                .clamp(0, p.stack)
            : 0,
    opponents:
        s.players
            .where((q) => q.id != p.id && !q.hasFolded && !q.sittingOut)
            .length,
    board: s.board,
    aggressor: s.aggressor,
  );
  s.observations.add(event);
  if (s.observations.length > 200) s.observations.removeAt(0);
  if (toCall <= 0 || s.street == Street.preflop || s.aggressor == null) return;
  // Price relative to the pot before the outstanding wager. This is the
  // decision actually faced (a short all-in call uses its actual price).
  final price = min(toCall, p.stack);
  final context = actionContext(
    s.street,
    price / max(1, s.pot - price),
    event.opponents,
  );
  final folded = action.type == ActionType.fold ? 1.0 : 0.0;
  p.memory.observe('fold:$context', folded);
  p.memory.observe('fold:$context@${s.aggressor}', folded);
}

/// Called only for real showdown contenders. Folded learning-reveal cards
/// must never be fed here. A loss is not evidence that an earlier bet bluffed.
void observeExposedShowdown(TableState s, List<int> exposedSeats) {
  for (final seat in exposedSeats) {
    final p = s.players[seat];
    if (p.hole == null) continue;
    final seen = <String>{};
    for (final a in s.observations) {
      if (a.seat != seat ||
          a.board.length < 3 ||
          (a.type != ActionType.bet && a.type != ActionType.raise)) {
        continue;
      }
      final context = actionContext(
        a.street,
        a.wager / max(1, a.pot),
        a.opponents,
      );
      // One sample per context/hand, not one per re-raise in a raising war.
      if (!seen.add(context)) continue;
      final strength =
          equityVsRandomCards(
            (p.hole![0], p.hole![1]),
            a.board,
            iters: 240,
            seed: hashSeed('${p.hole!.join()}|${a.board.join()}'),
          ).equity;
      // Weak aggression includes semi-bluffs. Evaluate on THAT street's board;
      // a draw hitting on the river cannot rewrite what the flop bet meant.
      p.memory.observe('weak:$context', strength < .5 ? 1 : 0);
    }
  }
}

double foldProbability(
  Player opponent, {
  required int bettor,
  required Street street,
  required double fraction,
  required int opponents,
}) {
  if (opponent.isAllIn) return 0;
  final r = opponent.recent;
  final generic = (r.foldToCbet + 6 * .45) / (r.faceCbet + 6);
  final prior = (generic + (fraction - .6) * .12).clamp(.12, .85);
  final context = actionContext(street, fraction, opponents);
  return opponent.memory
      .against('fold:$context', bettor, prior)
      .clamp(.04, .94);
}

double fieldFoldProbability(
  List<Player> opponents, {
  required int bettor,
  required Street street,
  required double fraction,
}) {
  var probability = 1.0;
  for (final q in opponents) {
    probability *= foldProbability(
      q,
      bettor: bettor,
      street: street,
      fraction: fraction,
      opponents: opponents.length,
    );
  }
  return opponents.isEmpty ? 0 : probability;
}

double observedWeakRate(Player p, ObservedAction a) {
  final r = p.recent;
  final aggression = (r.postAggro + 4 * .4) / (r.postAction + 4);
  final prior = (.16 + (aggression - .4) * .4).clamp(.07, .38);
  final context = actionContext(a.street, a.wager / max(1, a.pot), a.opponents);
  // Showdowns are a selected sample. Twelve virtual observations and bounded
  // influence prevent one exposed bluff from turning every hand into a call.
  return p.memory
      .estimate('weak:$context', prior, strength: 12)
      .clamp(.04, .65);
}

/// Board-relative strength proxy for likelihood weighting, not a solver EV.
/// Exact suit blockers and draw potential are evaluated for EACH combo.
(double, double) _features(List<int> hole, List<int> board) {
  final score = evaluateScore([...hole, ...board]);
  final category = score ~/ kCat;
  var strength = switch (category) {
    0 => .12,
    1 => .38,
    2 => .74,
    3 => .86,
    4 => .93,
    5 => .96,
    _ => .99,
  };
  final ranks = board.map(rankOf).toList()..sort();
  final holeRanks = hole.map(rankOf).toSet();
  if (category == 1) {
    final pair = (score >> 16) & 15;
    strength =
        pair >= ranks.last
            ? .66
            : pair >= ranks[ranks.length ~/ 2]
            ? .48
            : .32;
  }
  if (category == 1) {
    final pair = (score >> 16) & 15;
    if (!holeRanks.contains(pair)) strength = .18;
  }
  if (category == 3) {
    final trips = (score >> 16) & 15;
    if (!holeRanks.contains(trips)) strength = .25;
  }
  if (category == 0) {
    strength += hole.where((c) => rankOf(c) > ranks.last).length * .07;
  }
  if (board.length == 5 && evaluateScore(board) == score) strength = .12;
  var draw = 0.0;
  if (board.length < 5) {
    for (var suit = 0; suit < 4; suit++) {
      if (hole.any((c) => suitOf(c) == suit) &&
          [...hole, ...board].where((c) => suitOf(c) == suit).length == 4) {
        draw = .8;
      }
    }
    final unique = {...hole.map(rankOf), ...board.map(rankOf)};
    if (unique.contains(14)) unique.add(1);
    for (var low = 1; low <= 10; low++) {
      if (List.generate(5, (i) => low + i).where(unique.contains).length == 4) {
        draw = max(draw, .55);
      }
    }
  }
  return (strength, draw);
}

/// Weighted combos (integer replication) for the existing range-equity engine.
/// Sequential action likelihoods retain bluffs and slowplays instead of
/// discarding whole slices of a range after every check or bet.
List<IntCombo> publicOpponentCombos(
  TableState s,
  Player q,
  List<Card> ownHole,
) {
  final blocked = {...s.board, ...ownHole};
  final actions = s.observations.where((a) => a.seat == q.id).toList();
  final pre = actions.where((a) => a.street == Street.preflop).toList();
  final raised = pre.any(
    (a) => a.type == ActionType.raise || a.type == ActionType.bet,
  );
  final preRaises =
      s.observations
          .where(
            (a) =>
                a.street == Street.preflop &&
                (a.type == ActionType.raise || a.type == ActionType.bet),
          )
          .toList();
  final threebet = preRaises.skip(1).any((a) => a.seat == q.id);
  final labels =
      !q.vpipThisHand && !raised && q.position == Position.bb
          ? allLabels()
          : inferredPreflopRange(
            q,
            q.position,
            threebet
                ? PreflopAction.threebet
                : raised || q.pfrThisHand
                ? PreflopAction.open
                : PreflopAction.defend,
          );
  final candidates = {...labels, 'AA', 'KK', 'QQ', 'AKs'};
  final post = actions.where((a) => a.board.length >= 3).toList();
  // Legacy snapshots contain no action contexts. Use only a same-street move;
  // yesterday's flop bet is not a fresh turn bet.
  if (post.isEmpty && q.lastAction?.street == s.street && s.board.isNotEmpty) {
    final label = q.lastAction!.label;
    final type =
        label == 'Bet' || label == 'Raise'
            ? ActionType.bet
            : label == 'Call'
            ? ActionType.call
            : ActionType.check;
    post.add(
      ObservedAction(
        seat: q.id,
        street: s.street,
        type: type,
        pot: max(1, s.pot - s.currentBet),
        price: 0,
        wager: s.currentBet,
        opponents:
            s.players
                .where((p) => !p.hasFolded && !p.sittingOut && p.id != q.id)
                .length,
        board: s.board,
      ),
    );
  }
  final weighted = <(IntCombo, double)>[];
  var maximum = 0.0;
  for (final label in candidates) {
    for (final (a, b) in labelToCombos(label)) {
      if (blocked.contains(a) || blocked.contains(b)) continue;
      final combo = [cardToInt(a), cardToInt(b)];
      var weight = labels.contains(label) ? 1.0 : .12;
      for (final event in post) {
        final (strength, draw) = _features(
          combo,
          event.board.map(cardToInt).toList(),
        );
        if (event.type == ActionType.bet || event.type == ActionType.raise) {
          final weak = observedWeakRate(q, event);
          final size = event.wager / max(1, event.pot);
          final value =
              pow(
                strength,
                size > .85
                    ? 4
                    : size > .4
                    ? 2.5
                    : 1.5,
              ).toDouble();
          final bluff = (1 - strength) * (draw > 0 ? .65 + draw : .6);
          weight *= .025 + (1 - weak) * value + weak * bluff;
        } else if (event.type == ActionType.call) {
          weight *= .08 + .8 * strength + .4 * draw;
        } else if (event.type == ActionType.check) {
          weight *= .9 - .35 * strength; // traps always remain possible
        }
      }
      weighted.add((combo, weight));
      maximum = max(maximum, weight);
    }
  }
  return [
    for (final (combo, weight) in weighted)
      if (weight >= maximum * .02)
        for (var i = 0; i < max(1, (12 * weight / maximum).round()); i++) combo,
  ];
}

/// Conservative one-street EV gate; folding everyone and getting called are
/// separate outcomes. Deep future streets are deliberately not solved.
bool profitableBluff({
  required double foldProbability,
  required double equity,
  required int pot,
  required int risk,
  int callPrice = 0,
}) =>
    risk > 0 &&
    foldProbability * pot +
            (1 - foldProbability) *
                (equity * .75 * (pot + risk + max(0, risk - callPrice)) -
                    risk) >
        0;
