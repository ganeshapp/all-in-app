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

import 'dart:math' as math;

import 'prng.dart' show hashSeed;
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
    required this.faceCbetWeight,
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

  /// Recency-weighted count of c-bets faced — how much the fold rate is worth
  /// trusting, as opposed to what it says.
  final double faceCbetWeight;

  final PlayerStyle style;
}

/// A rate, or [dflt] when nothing has been observed. Operates on the decayed
/// float accumulators, so [b] is a weight rather than a count.
double _ratio(double a, double b, double dflt) => b > 1e-9 ? a / b : dflt;

/// Below this many hands, no label — the numbers are noise.
const int kStyleMinHands = 12;

/// The label a human would put on these numbers.
///
/// One definition, used by the bots to read the table and by the Stats page to
/// tell the player how they have been playing. Two copies of these thresholds
/// would mean the app could call you a TAG while the bots treated you as a
/// station.
PlayerStyle classifyStyle(double vpip, double pfr, double postAggro) {
  final loose = vpip > 0.4;
  final veryLoose = vpip > 0.6;
  // Passive means passive overall. Someone raising half their hands before
  // the flop is not a calling station, whatever they do after it.
  final passive = postAggro < 0.3 && pfr < 0.3;
  if (veryLoose && pfr > 0.35) return PlayerStyle.maniac;
  if (loose && passive) return PlayerStyle.station;
  if (veryLoose) return PlayerStyle.maniac;
  if (loose) return PlayerStyle.loose;
  if (vpip < 0.12) return PlayerStyle.rock;
  if (vpip < 0.18) return PlayerStyle.nit;
  if (vpip < 0.24) return PlayerStyle.tight;
  return PlayerStyle.solid;
}

/// How much weight to give a statistic given how often it has been tested.
/// Ten observations is roughly the point a person says "he keeps doing that";
/// a handful is still a coincidence.
double _weight(int n, [int full = 12]) {
  if (n <= 0) return 0;
  final v = n / full;
  return v < 1 ? v : 1;
}

Read readPlayer(Player p) {
  // Every rate comes from the RECENCY-WEIGHTED window, not the lifetime
  // counters. Opponents change gear — somebody folds for thirty hands, then
  // picks up chips and starts playing back — and a cumulative average cannot
  // see it happen. `handsSeen` is still the sample size for confidence,
  // because trust should grow with how long you have been watching even
  // though the rates themselves only describe recent hands.
  final w = p.recent;
  final hands = p.handsSeen;
  final vpip = _ratio(w.vpip, w.hands, 0.25);
  final pfr = _ratio(w.pfr, w.hands, 0.18);
  final postAggro = _ratio(w.postAggro, w.postAction, 0.4);

  final style =
      hands >= kStyleMinHands
          ? classifyStyle(vpip, pfr, postAggro)
          : PlayerStyle.unknown;

  return Read(
    hands: hands,
    confidence: _weight(hands, 25),
    vpip: vpip,
    pfr: pfr,
    threeBet: _ratio(w.threeBet, w.threeBetOpp, 0.07),
    foldToRaise: _ratio(w.foldToRaise, w.faceRaise, 0.6),
    foldTo3Bet: _ratio(w.foldTo3Bet, w.face3Bet, 0.6),
    foldToCbet: _ratio(w.foldToCbet, w.faceCbet, 0.5),
    cbet: _ratio(w.cbet, w.cbetOpp, 0.6),
    postAggro: postAggro,
    wtsd: _ratio(w.showdown, w.sawFlop, 0.3),
    faceCbetWeight: w.faceCbet,
    style: style,
  );
}

/// What the table thinks this player is, as probabilities rather than a label.
///
/// Nobody sits down knowing the others are a TAG and two stations. They watch,
/// and they form an opinion that firms up and sometimes changes. So this starts
/// at a flat 25% each and moves as the evidence comes in — "80% station, 5%
/// nit" rather than "station".
///
/// Built only from the recency-weighted read, so a player who changes gear gets
/// re-assessed instead of being stuck with what they did an hour ago. The
/// declared archetype is never consulted; the bots genuinely do not know it.
typedef StyleBelief = Map<Archetype, double>;

class _Shape {
  const _Shape(this.vpip, this.pfr, this.aggro);
  final double vpip;
  final double pfr;
  final double aggro;
}

/// What each archetype looks like from the outside: VPIP, PFR, post-flop
/// aggression. The yardstick the observed numbers are compared against.
const Map<Archetype, _Shape> _kArchetypeShape = {
  Archetype.tag: _Shape(0.22, 0.18, 0.55),
  Archetype.lag: _Shape(0.34, 0.27, 0.68),
  Archetype.nit: _Shape(0.12, 0.09, 0.4),
  Archetype.station: _Shape(0.46, 0.07, 0.18),
};

StyleBelief archetypeBelief(Player p) {
  final read = readPlayer(p);
  final flat = 1 / Archetype.values.length;
  // Nothing watched yet: no opinion. Saying "probably a TAG" after two hands
  // would be worse than admitting there is no read.
  if (read.confidence <= 0.02) {
    return {for (final a in Archetype.values) a: flat};
  }
  // Sharpness grows with the sample, so early evidence nudges and later
  // evidence decides. Without this a single loose hand reads as a maniac.
  final sharpness = 1 + 7 * read.confidence;
  final scores = <Archetype, double>{};
  var total = 0.0;
  for (final a in Archetype.values) {
    final shape = _kArchetypeShape[a]!;
    // Squared error over the three signals that actually separate the four,
    // with PFR weighted hardest: it is what tells a station from a LAG, both
    // of whom play a lot of hands.
    final dv = (read.vpip - shape.vpip) / 0.18;
    final dp = (read.pfr - shape.pfr) / 0.12;
    final da = (read.postAggro - shape.aggro) / 0.3;
    final d = dv * dv + dp * dp * 1.5 + da * da;
    final s = math.exp(-d * sharpness * 0.5);
    scores[a] = s;
    total += s;
  }
  // Degenerate case: nothing fits at all. Fall back to no opinion rather than
  // dividing by zero.
  if (total <= 1e-12) return {for (final a in Archetype.values) a: flat};
  return {for (final a in Archetype.values) a: scores[a]! / total};
}

/// How willing this player is to let a bet go through, as a multiplier on how
/// often it is worth bluffing at them.
double _foldability(Player p) {
  final read = readPlayer(p);
  // Two sources, because each is weak alone. The direct observation is the
  // better evidence once there is enough of it; the archetype belief covers
  // the early hands, where a station who has not yet been bet at still looks
  // like everybody else.
  final belief = archetypeBelief(p);
  final expected =
      belief[Archetype.station]! * 0.2 +
      belief[Archetype.nit]! * 0.72 +
      belief[Archetype.tag]! * 0.55 +
      belief[Archetype.lag]! * 0.42;
  final trust = _clamp(read.faceCbetWeight / 8, 0, 1);
  final f = read.foldToCbet * trust + expected * (1 - trust);
  // 0.8 folds → 1.6x; 0.5 → 1.0x; 0.2 → 0.4x.
  return _clamp(f * 2, 0.35, 1.7);
}

/// Whether a bluff is worth running against the people still in the hand.
///
/// A bluff has to get through EVERYBODY, so the stickiest live opponent sets
/// the price: two nits are easy to bluff, one calling station makes it
/// hopeless no matter who else is in. That is why this takes the minimum over
/// the field rather than looking at one nominated villain — and why a flat
/// "bluff less multiway" damping is the wrong shape, since it cannot tell
/// three folders apart from one station.
double bluffViability(
  List<Player> opponents, [
  TableDifficulty difficulty = TableDifficulty.regular,
]) {
  final live = opponents.where((q) => !q.hasFolded && !q.sittingOut).toList();
  if (live.isEmpty) return 0;
  var worst = double.infinity;
  for (final q in live) {
    final f = _foldability(q);
    if (f < worst) worst = f;
  }
  // Each extra body is another hand that has to miss, on top of whoever is
  // hardest to move. Milder than 1/n, because who they are matters more than
  // how many: 1/n says bluffing three nits is hopeless, and it is not.
  final crowd = 1 / (1 + (live.length - 1) * 0.45);
  // A tougher table is better at picking the moment, not more reckless.
  final gain = _kDifficulty[difficulty]!.gain;
  final sharpen = 1 + (worst - 1) * 0.35 * math.min(gain, 1.3);
  return _clamp(worst * crowd * sharpen, 0.1, 1.8);
}

/// What a seat has learned about bluffing, this session.
class BluffPolicy {
  const BluffPolicy({
    required this.frequency,
    required this.minEquity,
    required this.attempts,
    required this.successRate,
  });

  /// Multiplier on how often to try it.
  final double frequency;

  /// The least equity a hand needs before it counts as a bluffing candidate.
  /// Zero means anything will do — 2-6 offsuit included. It climbs when the
  /// bluffs keep getting caught, so the bot falls back on hands that have
  /// something going for them instead of pure air.
  final double minEquity;
  final int attempts;
  final double successRate;
}

/// The bluffing bandit.
///
/// A fixed bluff rate is a rate somebody can work out and then simply call.
/// So the rate is not fixed: the bot tries it, watches what happens, and moves.
/// Getting through means it can afford to do it more often and with worse
/// hands; getting caught means it does it less and needs a hand with some
/// equity behind it. Both dials move, because a human caught bluffing twice
/// does not only slow down, they also stop doing it with total air.
///
/// The archetype sets the prior and nothing more. That part is who the bot is,
/// and it is also what stops a session of bad luck turning a Nit into a maniac.
BluffPolicy bluffPolicy(Player p) {
  final attempts = p.bluffAttempts;
  // Beta-style smoothing: with no history the archetype's prior stands, and it
  // takes a run of real evidence to move far from it.
  // Four, not six. Two properties pull against each other here: a bot that
  // opens a session firing at a table full of callers should notice inside
  // ten hands rather than forty, because the money it loses learning is money
  // it does not get back — but one caught bluff must not rewrite the policy
  // either. Four is where a single bad outcome moves the rate under a fifth,
  // and twenty hands of evidence all but replaces the prior.
  const priorWeight = 4;
  const priorRate = 0.5;
  final rate =
      (p.bluffWins + priorWeight * priorRate) / (attempts + priorWeight);
  // What the bluffing has actually been WORTH, in big blinds per attempt.
  //
  // This is the number that matters, not the success rate. How often a bluff
  // got through misses the asymmetry: the ones that work win a small pot and
  // the ones that get called lose a big one, so a bot can get through 43% of
  // the time and still be setting money on fire.
  //
  // Smoothed harder than the success rate, because chip results are far
  // noisier than fold counts: one big pot is worth twenty folds.
  const netPrior = 8;
  final meanNet = p.bluffNetBb / (attempts + netPrior);
  // About 3bb per attempt either way covers the useful range.
  final edge = _clamp(1 + meanNet / 3, 0.3, 1.9);
  return BluffPolicy(
    // The LEARNED multiplier only. How foldable the field is is a separate
    // factor applied once at the call site — folding both in here double
    // counts it, which is quietly how bluffing got suppressed to nothing.
    frequency: edge,
    // Caught more often than break-even → demand equity. The ceiling is 0.32
    // because past that there is nothing left to bluff with: the branch is
    // only reached with a weak hand in the first place.
    minEquity: _clamp((1 - edge) * 0.42, 0, 0.32),
    attempts: attempts,
    successRate: rate,
  );
}

/// Does this seat run a bluff on THIS hand at all?
///
/// Decided once per hand from a deterministic seed rather than re-rolled every
/// street. That is what produces barrels: a bot that fires the flop keeps
/// firing the turn instead of tossing a fresh coin, so "bet, check, bet" stops
/// being a reliable tell and you are left guessing whether the story is real.
///
/// Stateless on purpose — nothing to serialise, and both languages compute the
/// same answer from the same FNV-1a hash.
bool bluffsThisHand(int handNumber, int seat, double rate) {
  if (rate <= 0) return false;
  if (rate >= 1) return true;
  // FNV-1a leaves its top bits almost untouched by a one-character change, so
  // seat 1 and seat 2 in the same hand came out the same 97% of the time —
  // every bot at the table bluffing on the same hands. Finalise the hash
  // before using it as a probability.
  var h = hashSeed('bluff:$handNumber:$seat');
  h = (h ^ (h >>> 15)) & 0xFFFFFFFF;
  h = (h * 0x2c1b3c6d) & 0xFFFFFFFF;
  h = (h ^ (h >>> 12)) & 0xFFFFFFFF;
  h = (h * 0x297a2d39) & 0xFFFFFFFF;
  h = (h ^ (h >>> 15)) & 0xFFFFFFFF;
  return h / 0x100000000 < rate;
}

/// VPIP, PFR and the style they add up to, over some set of hands.
class StyleProfile {
  const StyleProfile({
    required this.hands,
    required this.vpipHands,
    required this.pfrHands,
    required this.postAggro,
  });

  /// Hands with the fields recorded. Rows written before VPIP was persisted
  /// are excluded rather than counted as folds.
  final int hands;
  final int vpipHands;
  final int pfrHands;

  /// Post-flop aggression over the coached decisions, which is what the
  /// classifier needs to tell a station from a nit.
  final double postAggro;

  static const StyleProfile empty = StyleProfile(
    hands: 0,
    vpipHands: 0,
    pfrHands: 0,
    postAggro: 0,
  );

  double? get vpip => hands == 0 ? null : vpipHands / hands;
  double? get pfr => hands == 0 ? null : pfrHands / hands;

  /// Null until there are enough hands for the label to mean anything.
  PlayerStyle? get style =>
      hands < kStyleMinHands
          ? null
          : classifyStyle(vpipHands / hands, pfrHands / hands, postAggro);
}

/// The style label in a sentence: "a TAG", "a calling station".
///
/// Tight and TAG are not the same thing — somebody who sees few flops and
/// never raises is tight and *passive*, a different leak — so the aggressive
/// names are only used when the raising backs them up.
String styleSentenceWord(PlayerStyle s, double vpip, double pfr) {
  final aggressive = vpip > 0 && pfr / vpip >= 0.6;
  return switch (s) {
    PlayerStyle.unknown => 'hard to label yet',
    PlayerStyle.rock => 'a rock — very tight',
    PlayerStyle.nit => 'a nit',
    PlayerStyle.tight =>
      aggressive ? 'a TAG — tight and aggressive' : 'tight but passive',
    PlayerStyle.solid =>
      aggressive ? 'solid and aggressive' : 'solid but passive',
    PlayerStyle.loose =>
      aggressive ? 'a LAG — loose and aggressive' : 'loose but passive',
    PlayerStyle.maniac => 'a maniac',
    PlayerStyle.station => 'a calling station',
  };
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
  final w = p.recent;
  // Eight prior hands prevent a couple of opens from becoming a certainty.
  // Each rate uses its own opportunity count, not lifetime hands played.
  final vpip = (w.vpip + 8 * .26) / (w.hands + 8);
  final pfr = (w.pfr + 8 * .19) / (w.hands + 8);
  final ranges = buildPreflopRanges(vpip * 100, pfr * 100, pos);

  switch (action) {
    case PreflopAction.threebet:
      // Re-raising range: scaled by how often they actually do it, floored
      // so a maniac's 3-bet is still wide and a rock's is still premium.
      var pct = (w.threeBet + 10 * .07) / (w.threeBetOpp + 10) * 100 * 1.6;
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
