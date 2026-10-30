/// The opponent model: what a seat reads off another seat, and how each
/// archetype leans once it thinks it has somebody figured out.
///
/// Mirrors `../poker/scripts/profile_test.ts` assertion for assertion; the
/// numeric agreement with the desktop is pinned separately by the lockstep
/// fixture, which replays every bot decision in both languages.
library;

import 'dart:math' as math;

import 'package:allin/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// A seat with every counter at zero, then whatever the test overrides.
Player seat({
  String name = 'Villain',
  Archetype? archetype = Archetype.tag,
  Position position = Position.btn,
  int handsSeen = 0,
  int vpipCount = 0,
  int pfrCount = 0,
  int threeBetCount = 0,
  int threeBetOpp = 0,
  int foldToRaiseCount = 0,
  int faceRaiseCount = 0,
  int foldToCbetCount = 0,
  int faceCbetCount = 0,
  int postAggroCount = 0,
  int postActionCount = 0,
  int sawFlopCount = 0,
  int showdownCount = 0,
  int bluffAttempts = 0,
  int bluffWins = 0,
  double bluffNetBb = 0,
  RecentStats? recent,
}) => Player(
  id: 1,
  name: name,
  isHero: false,
  archetype: archetype,
  stack: 2000,
  position: position,
  handsSeen: handsSeen,
  vpipCount: vpipCount,
  pfrCount: pfrCount,
  threeBetCount: threeBetCount,
  threeBetOpp: threeBetOpp,
  foldToRaiseCount: foldToRaiseCount,
  faceRaiseCount: faceRaiseCount,
  foldToCbetCount: foldToCbetCount,
  faceCbetCount: faceCbetCount,
  postAggroCount: postAggroCount,
  postActionCount: postActionCount,
  sawFlopCount: sawFlopCount,
  showdownCount: showdownCount,
  bluffAttempts: bluffAttempts,
  bluffWins: bluffWins,
  bluffNetBb: bluffNetBb,
  // The bots read the recency window, not the lifetime counters, so a seat
  // described by counters has to have the window to match: "everything you
  // passed happened recently". Tests that care about the two diverging pass
  // `recent` explicitly.
  recent:
      recent ??
      RecentStats(
        hands: handsSeen.toDouble(),
        vpip: vpipCount.toDouble(),
        pfr: pfrCount.toDouble(),
        threeBet: threeBetCount.toDouble(),
        threeBetOpp: threeBetOpp.toDouble(),
        foldToRaise: foldToRaiseCount.toDouble(),
        faceRaise: faceRaiseCount.toDouble(),
        foldToCbet: foldToCbetCount.toDouble(),
        faceCbet: faceCbetCount.toDouble(),
        postAggro: postAggroCount.toDouble(),
        postAction: postActionCount.toDouble(),
        showdown: showdownCount.toDouble(),
        sawFlop: sawFlopCount.toDouble(),
      ),
);

void main() {
  group('readPlayer', () {
    test('no sample at all does not pretend to know anything', () {
      final r = readPlayer(seat());
      expect(r.hands, 0);
      expect(r.confidence, 0);
      expect(r.style, PlayerStyle.unknown);
    });

    test('under the 12-hand bar there is no label, however extreme', () {
      final r = readPlayer(seat(handsSeen: 11, vpipCount: 11, pfrCount: 11));
      expect(r.style, PlayerStyle.unknown);
    });

    test('plays everything and raises most of it reads as a maniac', () {
      final r = readPlayer(
        seat(
          handsSeen: 100,
          vpipCount: 98,
          pfrCount: 58,
          threeBetCount: 44,
          threeBetOpp: 100,
        ),
      );
      expect(r.style, PlayerStyle.maniac);
      expect(r.vpip, closeTo(0.98, 1e-9));
      expect(r.threeBet, closeTo(0.44, 1e-9));
    });

    test('a station is loose AND passive, not merely loose', () {
      final loosePassive = readPlayer(
        seat(
          handsSeen: 50,
          vpipCount: 25,
          pfrCount: 2,
          postAggroCount: 2,
          postActionCount: 40,
        ),
      );
      expect(loosePassive.style, PlayerStyle.station);

      // Raising half your hands disqualifies you — the bug that used to
      // label the hero a calling station.
      final looseAggro = readPlayer(
        seat(
          handsSeen: 50,
          vpipCount: 25,
          pfrCount: 26,
          postAggroCount: 20,
          postActionCount: 40,
        ),
      );
      expect(looseAggro.style, isNot(PlayerStyle.station));
    });

    test('tight labels split by how few hands they play', () {
      expect(
        readPlayer(seat(handsSeen: 50, vpipCount: 4)).style,
        PlayerStyle.rock,
      );
      expect(
        readPlayer(seat(handsSeen: 50, vpipCount: 7)).style,
        PlayerStyle.nit,
      );
    });

    test('rates divide by the chances they had, not by hands played', () {
      final r = readPlayer(
        seat(handsSeen: 40, foldToCbetCount: 7, faceCbetCount: 10),
      );
      expect(r.foldToCbet, closeTo(0.7, 1e-9));
    });
  });

  group('inferredPreflopRange', () {
    final maniac = seat(
      handsSeen: 60,
      vpipCount: 57,
      pfrCount: 35,
      threeBetCount: 24,
      threeBetOpp: 60,
    );
    final rock = seat(
      handsSeen: 60,
      vpipCount: 6,
      pfrCount: 4,
      threeBetCount: 1,
      threeBetOpp: 60,
    );

    test('a looser player gets a wider inferred range', () {
      final mOpen = inferredPreflopRange(
        maniac,
        Position.btn,
        PreflopAction.open,
      );
      final rOpen = inferredPreflopRange(
        rock,
        Position.btn,
        PreflopAction.open,
      );
      expect(mOpen.length, greaterThan(rOpen.length));
      expect(rOpen, isNotEmpty);
    });

    test('3-bet ranges scale with how often they actually 3-bet', () {
      final m3 = inferredPreflopRange(
        maniac,
        Position.btn,
        PreflopAction.threebet,
      );
      final r3 = inferredPreflopRange(
        rock,
        Position.btn,
        PreflopAction.threebet,
      );
      expect(m3.length, greaterThan(r3.length));
      // The tightest 3-bet range still has aces in it.
      expect(r3, contains('AA'));
    });

    test('a call is the middle of the range, not the top', () {
      final open = inferredPreflopRange(
        maniac,
        Position.btn,
        PreflopAction.open,
      );
      final call = inferredPreflopRange(
        maniac,
        Position.btn,
        PreflopAction.call,
      );
      expect(call, isNotEmpty);
      expect(call.join(), isNot(open.join()));
    });

    test('with no read it falls back to a sane range, not any-two', () {
      final blank = inferredPreflopRange(
        seat(),
        Position.co,
        PreflopAction.open,
      );
      expect(blank, isNotEmpty);
      expect(blank.length, lessThan(169));
    });
  });

  group('adjustmentFor', () {
    final hero = seat(
      name: 'You',
      handsSeen: 80,
      vpipCount: 78,
      pfrCount: 46,
      threeBetCount: 35,
      threeBetOpp: 80,
      postAggroCount: 30,
      postActionCount: 60,
      foldToCbetCount: 30,
      faceCbetCount: 40,
    );

    test('nobody adapts to a player they have barely seen', () {
      final a = adjustmentFor(
        Archetype.tag,
        seat(handsSeen: 1, vpipCount: 1, pfrCount: 1),
      );
      expect(a, same(kNoAdjustment));
    });

    test('each archetype reacts to the same player in character', () {
      final nit = adjustmentFor(Archetype.nit, hero);
      final lag = adjustmentFor(Archetype.lag, hero);
      final tag = adjustmentFor(Archetype.tag, hero);

      expect(nit.defend, greaterThan(1));
      expect(nit.threebet, greaterThan(1));
      expect(lag.aggression, greaterThan(1));
      expect(tag.defend, greaterThan(1));
      // With 80 hands of evidence the read is worth saying out loud.
      expect(nit.note, isNotNull);
      expect(lag.note, isNotNull);
    });

    test('the four archetypes do not collapse into one adjustment', () {
      final sigs = <String>{
        for (final a in Archetype.values)
          (() {
            final x = adjustmentFor(a, hero);
            return '${x.aggression.toStringAsFixed(2)}/'
                '${x.stickiness.toStringAsFixed(2)}';
          })(),
      };
      expect(sigs.length, greaterThan(2));
    });

    test('a player who folds to most bets is believed when they do bet', () {
      final folder = seat(
        handsSeen: 60,
        vpipCount: 15,
        pfrCount: 10,
        foldToCbetCount: 24,
        faceCbetCount: 30,
        postAggroCount: 5,
        postActionCount: 40,
      );
      expect(adjustmentFor(Archetype.tag, folder).stickiness, lessThan(1));
    });

    test('every dial stays inside its clamp on absurd input', () {
      final absurd = seat(
        handsSeen: 10000,
        vpipCount: 10000,
        pfrCount: 10000,
        threeBetCount: 10000,
        threeBetOpp: 10000,
        faceCbetCount: 10,
        foldToCbetCount: 10,
        postAggroCount: 100,
        postActionCount: 100,
      );
      for (final arch in Archetype.values) {
        final a = adjustmentFor(arch, absurd, TableDifficulty.tough);
        expect(a.aggression, inInclusiveRange(0.4, 2.2), reason: '$arch');
        expect(a.stickiness, inInclusiveRange(0.45, 1.8), reason: '$arch');
        expect(a.defend, inInclusiveRange(0.6, 1.9), reason: '$arch');
        expect(a.threebet, inInclusiveRange(0.5, 2.6), reason: '$arch');
      }
    });

    test('a tougher table adapts further', () {
      // pfr 0.275 clears the 0.26 "that chart is wrong" bar but stays under
      // the Nit's 0.3 "somebody is picking on me" trigger, so the dial
      // scales without saturating at its clamp.
      final moderate = seat(
        handsSeen: 40,
        vpipCount: 12,
        pfrCount: 11,
        threeBetCount: 4,
        threeBetOpp: 40,
      );
      final casual = adjustmentFor(
        Archetype.nit,
        moderate,
        TableDifficulty.casual,
      );
      final regular = adjustmentFor(
        Archetype.nit,
        moderate,
        TableDifficulty.regular,
      );
      final tough = adjustmentFor(
        Archetype.nit,
        moderate,
        TableDifficulty.tough,
      );
      expect(casual.defend, lessThan(regular.defend));
      expect(regular.defend, lessThan(tough.defend));
    });

    test('against a maniac the defend dial saturates at its clamp', () {
      // A real property of the design, and part of why "regular" and "tough"
      // play alike against an extreme opponent.
      final maniac = seat(
        handsSeen: 40,
        vpipCount: 38,
        pfrCount: 24,
        threeBetCount: 16,
        threeBetOpp: 40,
      );
      final regular = adjustmentFor(
        Archetype.nit,
        maniac,
        TableDifficulty.regular,
      );
      final tough = adjustmentFor(Archetype.nit, maniac, TableDifficulty.tough);
      expect(regular.defend, 1.9);
      expect(tough.defend, 1.9);
    });
  });

  group('recency weighting', () {
    test('a player who has loosened up reads loose NOW', () {
      // The whole point: not the average of the two stretches.
      final changedGear = seat(
        handsSeen: 60,
        vpipCount: 12, // tight over the session as a whole
        pfrCount: 6,
        recent: RecentStats(
          hands: 20,
          vpip: 17, // but wide over the last stretch
          pfr: 12,
          postAction: 10,
          postAggro: 7,
        ),
      );
      final read = readPlayer(changedGear);
      expect(read.vpip, greaterThan(0.7));
      expect(read.style, PlayerStyle.maniac);
      // Lifetime counters are untouched — Stats asks a different question.
      expect(changedGear.vpipCount, 12);
    });

    test('a maniac who has tightened up reads tight', () {
      final settled = seat(
        handsSeen: 60,
        vpipCount: 55,
        pfrCount: 40,
        recent: RecentStats(hands: 20, vpip: 3, pfr: 2),
      );
      expect(readPlayer(settled).vpip, lessThan(0.2));
    });
  });

  group('archetypeBelief', () {
    test('no hands watched means no opinion', () {
      final b = archetypeBelief(seat());
      for (final v in b.values) {
        expect(v, closeTo(0.25, 1e-9));
      }
      expect(b.values.reduce((a, x) => a + x), closeTo(1, 1e-9));
    });

    test('loose and passive reads mostly Station', () {
      final b = archetypeBelief(
        seat(
          handsSeen: 60,
          vpipCount: 28,
          pfrCount: 4,
          postAggroCount: 4,
          postActionCount: 40,
        ),
      );
      expect(b[Archetype.station]!, greaterThan(0.5));
      expect(b[Archetype.station]!, greaterThan(b[Archetype.lag]!));
      expect(b.values.reduce((a, x) => a + x), closeTo(1, 1e-9));
    });

    test('very tight reads as a Nit', () {
      final b = archetypeBelief(
        seat(
          handsSeen: 60,
          vpipCount: 7,
          pfrCount: 5,
          postAggroCount: 12,
          postActionCount: 30,
        ),
      );
      expect(b[Archetype.nit]!, greaterThan(b[Archetype.station]!));
      expect(b[Archetype.nit]!, greaterThan(b[Archetype.lag]!));
    });

    test('loose-aggressive is not mistaken for a station', () {
      final b = archetypeBelief(
        seat(
          handsSeen: 60,
          vpipCount: 21,
          pfrCount: 17,
          postAggroCount: 27,
          postActionCount: 40,
        ),
      );
      expect(b[Archetype.lag]! + b[Archetype.tag]!, greaterThan(0.6));
      expect(b[Archetype.station]!, lessThan(0.2));
    });

    test('a bigger sample gives a sharper opinion', () {
      double spread(StyleBelief b) => b.values.reduce(math.max);
      final thin = archetypeBelief(
        seat(handsSeen: 6, vpipCount: 3, postActionCount: 4),
      );
      final thick = archetypeBelief(
        seat(handsSeen: 120, vpipCount: 60, pfrCount: 2, postActionCount: 80),
      );
      expect(spread(thin), lessThan(spread(thick)));
    });
  });

  group('bluffViability', () {
    final folder = seat(
      handsSeen: 40,
      faceCbetCount: 20,
      foldToCbetCount: 17,
      vpipCount: 10,
      pfrCount: 7,
    );
    final station = seat(
      handsSeen: 40,
      faceCbetCount: 20,
      foldToCbetCount: 2,
      vpipCount: 20,
      pfrCount: 2,
      postActionCount: 30,
      postAggroCount: 3,
    );

    test('bluffing a folder beats bluffing a station', () {
      expect(
        bluffViability([folder]),
        greaterThan(bluffViability([station]) * 2),
      );
    });

    test('nobody left to bluff means no bluff', () {
      expect(bluffViability([]), 0);
    });

    test('one station in the field kills it for everyone', () {
      final twoFolders = bluffViability([folder, folder]);
      expect(bluffViability([folder, station]), lessThan(twoFolders));
      // And a crowd is harder than a heads-up pot, all else equal.
      expect(twoFolders, lessThan(bluffViability([folder])));
    });
  });

  group('bluffPolicy', () {
    final fresh = bluffPolicy(seat());

    test('a fresh seat demands little of a bluffing hand', () {
      expect(fresh.attempts, 0);
      expect(fresh.minEquity, inInclusiveRange(0, 0.32));
    });

    test('getting caught lowers the rate and tightens the range', () {
      final caught = bluffPolicy(
        seat(bluffAttempts: 30, bluffWins: 2, bluffNetBb: -90),
      );
      expect(caught.frequency, lessThan(fresh.frequency));
      expect(caught.minEquity, greaterThan(fresh.minEquity));
    });

    test('getting through raises the rate and widens to any two cards', () {
      final winning = bluffPolicy(
        seat(bluffAttempts: 30, bluffWins: 26, bluffNetBb: 90),
      );
      expect(winning.frequency, greaterThan(fresh.frequency));
      expect(winning.minEquity, 0);
      final caught = bluffPolicy(
        seat(bluffAttempts: 30, bluffWins: 2, bluffNetBb: -90),
      );
      expect(winning.frequency, greaterThan(caught.frequency * 2));
    });

    test('chips decide it, not the success rate', () {
      // The asymmetry a success rate cannot see: getting through more than
      // half the time and still losing money doing it.
      final throughButLosing = bluffPolicy(
        seat(bluffAttempts: 40, bluffWins: 22, bluffNetBb: -70),
      );
      expect(throughButLosing.frequency, lessThan(1));
      final rarelyThroughButPaying = bluffPolicy(
        seat(bluffAttempts: 40, bluffWins: 9, bluffNetBb: 60),
      );
      expect(rarelyThroughButPaying.frequency, greaterThan(1));
    });

    test('one unlucky hand does not rewrite the policy', () {
      final unlucky = bluffPolicy(
        seat(bluffAttempts: 1, bluffWins: 0, bluffNetBb: -4),
      );
      expect((unlucky.frequency - fresh.frequency).abs(), lessThan(0.25));
    });

    test('stays in range for any history', () {
      for (final a in [0, 1, 5, 50, 500]) {
        for (final w in [0, 1, a]) {
          for (final net in [-500.0, -5.0, 0.0, 5.0, 500.0]) {
            final pol = bluffPolicy(
              seat(
                bluffAttempts: a,
                bluffWins: math.min(w, a),
                bluffNetBb: net,
              ),
            );
            expect(pol.frequency, inInclusiveRange(0.3, 1.9));
            expect(pol.minEquity, inInclusiveRange(0, 0.32));
          }
        }
      }
    });
  });

  group('bluffsThisHand', () {
    test('is stable within a hand, which is what makes a barrel', () {
      final a = bluffsThisHand(42, 3, 0.5);
      for (var i = 0; i < 20; i++) {
        expect(bluffsThisHand(42, 3, 0.5), a);
      }
    });

    test('honours the extremes', () {
      expect(bluffsThisHand(42, 3, 0), isFalse);
      expect(bluffsThisHand(42, 3, 1), isTrue);
    });

    test('honours the rate over many hands', () {
      var hits = 0;
      const n = 4000;
      for (var h = 0; h < n; h++) {
        if (bluffsThisHand(h, 2, 0.3)) hits++;
      }
      expect(hits / n, closeTo(0.3, 0.04));
    });

    test('two seats in the same hand decide independently', () {
      var differ = 0;
      for (var h = 0; h < 200; h++) {
        if (bluffsThisHand(h, 1, 0.5) != bluffsThisHand(h, 2, 0.5)) differ++;
      }
      expect(differ, greaterThan(40));
    });
  });

  group('exploreRate', () {
    final blank = readPlayer(seat());
    final known = readPlayer(seat(handsSeen: 200, vpipCount: 50, pfrCount: 40));

    test('probing decays as the read firms up', () {
      expect(exploreRate(blank), greaterThan(exploreRate(known)));
    });

    test('probing never stops entirely', () {
      // This is what stops the bot from being read back.
      expect(exploreRate(known), greaterThan(0));
    });

    test('a tough table wastes fewer chips finding out', () {
      expect(
        exploreRate(known, TableDifficulty.tough),
        lessThan(exploreRate(known, TableDifficulty.casual)),
      );
    });

    test('is a probability at every difficulty', () {
      for (final d in TableDifficulty.values) {
        final r = exploreRate(blank, d);
        expect(r, greaterThan(0), reason: d.name);
        expect(r, lessThan(1), reason: d.name);
      }
    });
  });
}
