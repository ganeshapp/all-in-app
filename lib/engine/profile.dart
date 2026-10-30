/// Reading the other players — including the hero.
///
/// Five strangers sit down. None of them knows you. Over an hour they watch
/// what you do, form an opinion, and start playing back at you — each in their
/// own way, because they are not the same person. Then the session ends, the
/// table breaks, and the next one starts from nothing.
///
/// Everything here is built from facts anybody at the table could see: the
/// price somebody faced, what they did about it, and the hands they turned
/// over. No hole-card peeking, no omniscience.
///
/// 1:1 port of `src/game/profile.ts`.
library;

import 'ranges.dart';
import 'types.dart';

/// The label a human would reach for, once they have seen enough.
///
/// Names match the desktop string union exactly, so `.name` is the wire value.
enum PlayerStyle { unknown, rock, nit, tight, solid, loose, maniac, station }

/// What one seat has shown you so far.
class Read {
  const Read({
    required this.hands,
    required this.confidence,
    required this.vpip,
    required this.pfr,
    required this.threeBet,
    required this.foldToRaise,
    required this.foldTo3Bet,
    required this.foldToCbet,
    required this.cbet,
    required this.postAggro,
    required this.wtsd,
    required this.style,
  });

  /// Hands watched — everything below is worthless without it.
  final int hands;

  /// 0 → "no idea who this is", 1 → "I have seen plenty".
  final double confidence;
  final double vpip;
  final double pfr;
  final double threeBet;
  final double foldToRaise;
  final double foldTo3Bet;
  final double foldToCbet;
  final double cbet;
  final double postAggro;
  final double wtsd;
  final PlayerStyle style;
}

double _ratio(int a, int b, double dflt) => b > 0 ? a / b : dflt;

/// How much weight to give a statistic given how often it has been tested.
/// Ten observations is roughly the point a person says "he keeps doing that";
/// a handful is still a coincidence.
double _weight(int n, [int full = 12]) {
  if (n <= 0) return 0;
  final v = n / full;
  return v < 1 ? v : 1;
}

Read readPlayer(Player p) {
  final hands = p.handsSeen;
  final vpip = _ratio(p.vpipCount, hands, 0.25);
  final pfr = _ratio(p.pfrCount, hands, 0.18);
  final postAggro = _ratio(p.postAggroCount, p.postActionCount, 0.4);

  var style = PlayerStyle.unknown;
  if (hands >= 12) {
    final loose = vpip > 0.4;
    final veryLoose = vpip > 0.6;
    // Passive means passive overall. Someone raising half their hands
    // before the flop is not a calling station, whatever they do after it.
    final passive = postAggro < 0.3 && pfr < 0.3;
    if (veryLoose && pfr > 0.35) {
      style = PlayerStyle.maniac;
    } else if (loose && passive) {
      style = PlayerStyle.station;
    } else if (veryLoose) {
      style = PlayerStyle.maniac;
    } else if (loose) {
      style = PlayerStyle.loose;
    } else if (vpip < 0.12) {
      style = PlayerStyle.rock;
    } else if (vpip < 0.18) {
      style = PlayerStyle.nit;
    } else if (vpip < 0.24) {
      style = PlayerStyle.tight;
    } else {
      style = PlayerStyle.solid;
    }
  }

  return Read(
    hands: hands,
    confidence: _weight(hands, 25),
    vpip: vpip,
    pfr: pfr,
    threeBet: _ratio(p.threeBetCount, p.threeBetOpp, 0.07),
    foldToRaise: _ratio(p.foldToRaiseCount, p.faceRaiseCount, 0.6),
    foldTo3Bet: _ratio(p.foldTo3BetCount, p.face3BetCount, 0.6),
    foldToCbet: _ratio(p.foldToCbetCount, p.faceCbetCount, 0.5),
    cbet: _ratio(p.cbetCount, p.cbetOpp, 0.6),
    postAggro: postAggro,
    wtsd: _ratio(p.showdownCount, p.sawFlopCount, 0.3),
    style: style,
  );
}

/// What they just did pre-flop — the strongest single piece of evidence.
enum PreflopAction { open, call, threebet, defend }

/// The hands this player is likely holding, from what they have actually been
/// doing — not from a label stuck on them at the start of the session.
///
/// A raise is the top of their range, a call is the middle, a re-raise is the
/// very top.
List<HandLabel> inferredPreflopRange(
  Player p,
  Position pos,
  PreflopAction action,
) {
  final read = readPlayer(p);
  // Until there is a sample, fall back to a sane default rather than
  // pretending to know: a typical opening range, not "any two cards".
  final vpip = read.confidence > 0.2 ? read.vpip : 0.26;
  final pfr = read.confidence > 0.2 ? read.pfr : 0.19;
  final ranges = buildPreflopRanges(vpip * 100, pfr * 100, pos);

  switch (action) {
    case PreflopAction.threebet:
      // Re-raising range: scaled by how often they actually do it, floored
      // so a maniac's 3-bet is still wide and a rock's is still premium.
      var pct = read.threeBet * 100 * 1.6;
      if (pct < 2.5) pct = 2.5;
      if (pct > 30) pct = 30;
      return topPercentRange(pct).toList();
    case PreflopAction.open:
      return ranges.raise.toList();
    case PreflopAction.call:
    case PreflopAction.defend:
      // Calling range: what they play minus the top they would have raised.
      final flat = ranges.play.where((l) => !ranges.raise.contains(l)).toList();
      return flat.length >= 6 ? flat : ranges.play.toList();
  }
}

/* ------------------------------------------------------------- adaptation */

/// The knobs a bot turns once it thinks it has somebody figured out.
class Adjustment {
  const Adjustment({
    this.aggression = 1,
    this.stickiness = 1,
    this.defend = 1,
    this.threebet = 1,
    this.note,
  });

  /// Multiplier on how often it bets or raises at this player.
  final double aggression;

  /// Multiplier on how willing it is to call them down.
  final double stickiness;

  /// Multiplier on how wide it defends against their raises.
  final double defend;

  /// Multiplier on how often it re-raises them.
  final double threebet;

  /// One line, in the bot's own voice, about what it has noticed.
  final String? note;
}

const Adjustment kNoAdjustment = Adjustment();

class _Difficulty {
  const _Difficulty(this.gain, this.patience);

  /// How far they move.
  final double gain;

  /// How long before they move.
  final double patience;
}

const Map<TableDifficulty, _Difficulty> _kDifficulty = {
  TableDifficulty.casual: _Difficulty(0.45, 1.8),
  TableDifficulty.regular: _Difficulty(1, 1),
  TableDifficulty.tough: _Difficulty(1.55, 0.6),
};

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// How often to ignore the read and just play straight — the explore arm.
///
/// A bot that acts on a read every single time has two problems. It can be
/// read back, because its own behaviour becomes a function of yours. And it
/// never finds out when the read goes stale: having decided you fold to
/// continuation bets, it bets at you forever and never learns that you stopped.
///
/// So it probes. Early in a session there is nothing to lose — it has no read
/// worth protecting, so it tests constantly. As the read firms up, probing gets
/// expensive and the rate decays. It never reaches zero: the last few percent
/// are what stop you from reverse-engineering the thing.
///
/// Tough tables probe least, because they settle on the right read fastest and
/// waste the fewest chips finding out. Casual tables keep poking at it.
double exploreRate(
  Read read, [
  TableDifficulty difficulty = TableDifficulty.regular,
]) {
  final floor =
      difficulty == TableDifficulty.tough
          ? 0.07
          : difficulty == TableDifficulty.casual
          ? 0.17
          : 0.11;
  return floor + (1 - read.confidence) * 0.2;
}

/// What this particular opponent makes of that particular player.
///
/// Each archetype watches a different thing, because people do. The Nit is
/// looking for whether you are stealing from them; the Station is slowly
/// working out that your bets mean something; the LAG is hunting for somebody
/// who folds; the TAG is doing all of it, moderately. None of them turns into
/// the same player — they stay themselves and lean.
Adjustment adjustmentFor(
  Archetype? archetype,
  Player target, [
  TableDifficulty difficulty = TableDifficulty.regular,
]) {
  final read = readPlayer(target);
  final d = _kDifficulty[difficulty]!;
  // Nobody reacts to two hands. Confidence has to clear the patience bar.
  final c =
      _clamp(
        (read.confidence - 0.15 * d.patience) / (1 - 0.15 * d.patience),
        0,
        1,
      ) *
      d.gain;
  if (c <= 0.05) return kNoAdjustment;

  var aggression = 1.0;
  var stickiness = 1.0;
  var defend = 1.0;
  var threebet = 1.0;
  String? note;

  double lean(double base, double amount) => base + amount * c;
  // The dials may lean early, but nobody says "he keeps doing that" after
  // six hands. The sentence waits until the read is worth stating.
  String? spoken(String s) => c >= 0.3 ? s : null;

  switch (archetype) {
    case Archetype.nit:
      // Tight players notice one thing above all: somebody picking on them.
      if (read.pfr > 0.3 || read.threeBet > 0.18) {
        defend = lean(1, 0.55);
        threebet = lean(1, 0.8);
        // Deliberately NOT stickier. Somebody raising every pot before the
        // flop is not necessarily betting light after it, and calling them
        // down wider was measurably the most expensive thing the table did:
        // it paid off their value hands while the wider defence was already
        // costing chips out of position.
        note = spoken(
          '${target.name} raises a lot — I have to stop folding every time.',
        );
      }
      // But they still believe a quiet player completely.
      if (read.postAggro < 0.25 && read.hands >= 15) {
        stickiness = lean(1, -0.3);
        note ??= spoken('${target.name} only bets when they have it.');
      }
    case Archetype.station:
      // Calling stations do not stop calling. What they eventually learn is
      // which player's bets are always real — and stop paying that one off.
      if (read.postAggro < 0.35 && read.hands >= 18) {
        stickiness = lean(1, -0.45);
        note = spoken('${target.name} does not bluff. I keep paying them off.');
      }
      if (read.postAggro > 0.6) {
        stickiness = lean(1, 0.2);
        note ??= spoken('${target.name} bets at everything.');
      }
    case Archetype.lag:
      // Hunting for somebody who folds. Fastest to react, least disciplined.
      if (read.foldToCbet >= 0.5 || read.foldToRaise >= 0.68) {
        aggression = lean(1, 0.7);
        threebet = lean(1, 0.9);
        note = spoken(
          '${target.name} folds too much — I can bet at them relentlessly.',
        );
      }
      if (read.foldToCbet < 0.3 && read.hands >= 15) {
        aggression = lean(1, -0.35);
        stickiness = lean(1, 0.25);
        note ??= spoken('${target.name} never folds. Stop bluffing them.');
      }
    case Archetype.tag:
    case null:
      // TAG: reads everything, moves moderately, in the right direction.
      if (read.foldToCbet > 0.55) {
        aggression = lean(1, 0.4);
        note = spoken('${target.name} folds to most continuation bets.');
      } else if (read.foldToCbet < 0.3 && read.hands >= 15) {
        aggression = lean(1, -0.3);
        stickiness = lean(1, 0.2);
        note = spoken(
          '${target.name} calls down light — value bet, do not bluff.',
        );
      }
      if (read.threeBet > 0.2) {
        defend *= lean(1, 0.5);
        threebet *= lean(1, 0.6);
        note ??= spoken(
          '${target.name} re-raises constantly — I can play back.',
        );
      }
      if (read.vpip > 0.45) {
        defend *= lean(1, 0.35);
        note ??= spoken('${target.name} plays almost every hand.');
      }
  }

  // Somebody who folds to most bets is not defending light. So on the
  // occasions they DO put money in, it is real — and the right response is to
  // believe them more, not less. Without this, reading a player as a folder
  // only makes a bot bet harder at them, which is half a read: it collects the
  // small pots and then pays off every big one.
  if (read.foldToCbet > 0.5 && read.hands >= 12) {
    stickiness *= 1 - 0.35 * c;
  }

  // NOTE: the mirror rule — "stop believing a player who bets at everything" —
  // was tried and measurably HURT, because `postAggro` lumps pre-flop
  // aggression in with post-flop follow-through, so a player who raises every
  // pot and then only bets made hands reads as a bluffer and gets paid off.
  // Telling those two apart needs a post-flop-only aggression read against
  // what the player actually turns over, which is what `shownHands` is for.

  // A chart written for somebody opening one hand in five is the wrong chart
  // against somebody opening three in five. Scale by how far off they are.
  if (read.pfr > 0.26 && read.hands >= 12) {
    final timesWider = _clamp(read.pfr / 0.2, 1, 3.2);
    defend *= 1 + (timesWider - 1) * 0.55 * c;
  }

  return Adjustment(
    aggression: _clamp(aggression, 0.4, 2.2),
    stickiness: _clamp(stickiness, 0.45, 1.8),
    // Capped well short of the old 3.0 — see the desktop note: tripling a
    // defending range loses more at showdown than it wins pre-flop.
    defend: _clamp(defend, 0.6, 1.9),
    threebet: _clamp(threebet, 0.5, 2.6),
    note: note,
  );
}
