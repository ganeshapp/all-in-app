/// What an action is worth, in chips.
///
/// The bots used to decide by looking a frequency up in a chart and rolling a
/// die against it. That works where the chart has a row and collapses where it
/// does not — and the fallback was to fold. Two things followed, both visible
/// in real sessions:
///
///   - A re-raise is looked up as `myPosition_vs_raiserPosition`, and every
///     one of those charts is "defender versus an EARLIER seat". When the hero
///     3-bets, the raiser is in a LATER seat, so the lookup misses every time
///     and every adaptation term multiplies a zero. Bots folded 94.5% of the
///     time to a 7bb 3-bet across 769 hands and never adjusted.
///   - A bot folded for 12 chips into a pot of 534. That is not a mistuned
///     frequency. It is the absence of arithmetic.
///
/// So this is the evaluation function the policy was missing — the thing
/// centipawn loss is computed FROM, not a rule about any particular spot.
/// Give it the price, the pot, an equity estimate and a read on who is left,
/// and it prices fold / call / raise. The charts stay as a fast path for the
/// spots they cover; out of book now falls through to thinking.
///
/// Pricing only. The opponent response model it needs — "how often does THIS
/// player fold to a bet of THIS size in THIS spot" — already exists in
/// `opponent_model.dart`, with per-opponent memory, and is used rather than
/// duplicated here.
library;

import 'dart:math' as math;

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// How much of its raw equity a hand actually collects.
///
/// A hand that is 40% to win does not win 40% of the pot: it gets outplayed
/// out of position, folds some of its equity away on later streets, and is
/// worth less against several opponents than against one.
double realisation(int opponents, bool inPosition, [double spr = 2]) {
  final seats = math.max(1, opponents);
  // Deep money is worse for the caller, and much worse out of position: more
  // streets to be outplayed on, and every one of them acted on first. Without
  // this the evaluator treated calling as "see five cards and claim your
  // share", which is how bots ended up stacking off 13% of hands.
  final depth = _clamp((spr - 2) * (inPosition ? 0.016 : 0.03), 0, 0.3);
  // The bases are deliberately pessimistic: a caller gets neither five free
  // cards nor the last word.
  final base = _clamp(
    (inPosition ? 0.9 : 0.72) - (seats - 1) * 0.08 - depth,
    0.4,
    1,
  );
  // …but with nothing behind there is nothing left to misplay. Realisation
  // discounts future streets you might get outplayed on; a call that puts you
  // all-in has none, so it collects all five cards and its full share. Pricing
  // those calls at 0.72 understated every one of them by 28%, and the only
  // reason it did not show was a mixing band wide enough to take the call
  // anyway. Narrow the band and the bots started folding to a shove-every-hand
  // maniac — who went from losing to +1736bb.
  final committed = _clamp(1 - spr / 2, 0, 1);
  return _clamp(base + (1 - base) * committed, 0.4, 1);
}

/// Chips won or lost, on average, by calling [cost] to contest [pot].
double callEv(double equity, num pot, num cost, [double realise = 1]) {
  final share = _clamp(equity * realise, 0, 1);
  return share * (pot + cost) - cost;
}

/// Chips won or lost by raising, counting both ways it can end: everybody
/// folds, or somebody continues and the hand plays on for a bigger pot.
/// [toCall] is what WE already owed before raising. The caller matches our
/// raise from further along than us — they have the current bet in already, so
/// they put in `cost - toCall`, not `cost`. Counting their call as the full
/// `cost` inflated the called pot by exactly that much, enough to make the
/// raise outrank the call across a band of equities where this function's own
/// arithmetic says call.
double raiseEv(
  double equity,
  num pot,
  num cost,
  double foldsEverybody, [
  double realise = 1,
  num toCall = 0,
]) {
  final fe = _clamp(foldsEverybody, 0, 1);
  final share = _clamp(equity * realise, 0, 1);
  // Called: our raise plus theirs, and theirs is short by what we owed.
  final theirs = math.max(0, cost - toCall);
  final called = share * (pot + cost + theirs) - cost;
  return fe * pot + (1 - fe) * called;
}

enum PricedKind { fold, call, raise }

/// One priced option.
class PricedAction {
  const PricedAction(this.kind, this.ev, [this.to]);
  final PricedKind kind;
  final double ev;

  /// Total chips this street for a raise; the call amount for a call.
  final num? to;
}

/// Rank fold / call / raise by what each is worth.
///
/// Folding is the zero: chips already in the pot are not yours and do not
/// enter the comparison. That single convention is what makes a fold for 12
/// into 534 impossible to choose — any hand with more than about 2% equity
/// prices the call above zero, and no rule about "small bets" is needed.
List<PricedAction> priceActions({
  required double equity,
  required num pot,
  required num callCost,
  required bool canCall,
  bool canRaise = false,
  num? raiseTo,
  num? raiseCost,
  double foldsEverybody = 0.5,
  double realise = 1,

  /// What we owe before acting — see [raiseEv].
  num toCall = 0,
}) {
  final out = <PricedAction>[const PricedAction(PricedKind.fold, 0)];
  if (canCall) {
    out.add(
      PricedAction(
        PricedKind.call,
        callEv(equity, pot, callCost, realise),
        callCost,
      ),
    );
  }
  if (canRaise && raiseTo != null && raiseCost != null) {
    out.add(
      PricedAction(
        PricedKind.raise,
        raiseEv(equity, pot, raiseCost, foldsEverybody, realise, toCall),
        raiseTo,
      ),
    );
  }
  out.sort((a, b) => b.ev.compareTo(a.ev));
  return out;
}

/// Pick from priced options, mixing between ones that are close.
///
/// Always taking the top-EV action makes a bot that can be read off a single
/// decision, and real edges are rarely clean enough to justify it. Anything
/// within [band] chips of the best is a live option, chosen in proportion to
/// how close it is, so the mix moves with the spot instead of being a
/// constant somebody can learn.
PricedAction chooseByEv(List<PricedAction> ranked, double roll, double band) {
  if (ranked.isEmpty) return const PricedAction(PricedKind.fold, 0);
  final best = ranked.first.ev;
  final width = math.max(1e-9, band);
  final live = ranked.where((a) => best - a.ev <= width).toList();
  if (live.length == 1) return live.first;
  final weights = [for (final a in live) math.max(1e-6, width - (best - a.ev))];
  final total = weights.reduce((a, b) => a + b);
  var acc = 0.0;
  final target = _clamp(roll, 0, 0.999999) * total;
  for (var i = 0; i < live.length; i++) {
    acc += weights[i];
    if (target < acc) return live[i];
  }
  return live.last;
}
