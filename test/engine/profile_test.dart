/// The opponent model: what a seat reads off another seat, and how each
/// archetype leans once it thinks it has somebody figured out.
///
/// Mirrors `../poker/scripts/profile_test.ts` assertion for assertion; the
/// numeric agreement with the desktop is pinned separately by the lockstep
/// fixture, which replays every bot decision in both languages.
library;

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
