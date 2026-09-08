/// JSON codecs for the engine's state objects
/// (`lib/services/persistence/serialization.dart`, DESIGN.md §16.4).
library;

import 'dart:convert';
import 'dart:math';

import 'package:allin/engine/engine.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

TableState dealtTable() {
  final rng = Random(7);
  var t = createTable(
    const GameConfig(
      seats: 6,
      startingStack: 2000,
      smallBlind: 10,
      bigBlind: 20,
    ),
    rng: rng,
  );
  t = startHand(t, rng: rng);
  return t;
}

void main() {
  group('tableStateToJson', () {
    test('round-trips a dealt table field for field', () {
      final t = dealtTable();
      t.botRanges[1] = ['AKs', 'QQ', 'JTs'];
      t.summary = const HandSummary(
        handNumber: 4,
        potResults: [
          PotResult(winners: [0], amount: 520, potLabel: 'Main pot'),
        ],
        showdown: [
          ShowdownEntry(
            playerId: 0,
            hole: ['As', 'Ks'],
            hand: EvaluatedHand(
              category: HandCategory.twoPair,
              score: 123456,
              name: 'two pair, Aces and Kings',
            ),
            hadToShow: true,
          ),
        ],
        board: ['Ah', 'Kd', '7c', '2s', '9h'],
        heroNetChips: 260,
      );

      final back = tableStateFromJson(
        jsonDecode(jsonEncode(tableStateToJson(t))) as Map<String, Object?>,
      );

      expect(back.button, t.button);
      expect(back.street, t.street);
      expect(back.board, t.board);
      expect(back.deck, t.deck, reason: 'the deck must survive a resume');
      expect(back.deck, isNotEmpty);
      expect(back.pot, t.pot);
      expect(back.currentBet, t.currentBet);
      expect(back.lastRaiseSize, t.lastRaiseSize);
      expect(back.aggressor, t.aggressor);
      expect(back.toAct, t.toAct);
      expect(back.handNumber, t.handNumber);
      expect(back.smallBlind, t.smallBlind);
      expect(back.bigBlind, t.bigBlind);
      expect(back.phase, t.phase);
      expect(back.logSeq, t.logSeq);
      expect(back.stacksAtStart, t.stacksAtStart);
      expect(back.config.seats, 6);
      expect(back.config.ante, t.config.ante);
      expect(back.botRanges[1], ['AKs', 'QQ', 'JTs']);

      expect(back.log.map((e) => e.text), t.log.map((e) => e.text));
      expect(back.log.map((e) => e.kind), t.log.map((e) => e.kind));
      expect(back.log.map((e) => e.street), t.log.map((e) => e.street));

      expect(back.summary!.handNumber, 4);
      expect(back.summary!.potResults.single.amount, 520);
      expect(back.summary!.potResults.single.potLabel, 'Main pot');
      expect(
        back.summary!.showdown.single.hand!.category,
        HandCategory.twoPair,
      );
      expect(back.summary!.showdown.single.hand!.score, 123456);
      expect(back.summary!.board, ['Ah', 'Kd', '7c', '2s', '9h']);
      expect(back.summary!.heroNetChips, 260);
    });

    test('round-trips every player field', () {
      final t = dealtTable();
      final p = t.players[1];
      p.dials = const Dials(aggression: 1.2, stickiness: 0.4, cbetFlop: 0.66);
      p.lastAction = const PlayerLastAction('Raise', Street.preflop);
      p.handsSeen = 12;
      p.vpipCount = 5;
      p.pfrCount = 3;
      p.vpipThisHand = true;
      p.revealed = true;
      p.foldedStreet = Street.flop;
      p.hasFolded = true;
      p.sittingOut = true;

      final back = tableStateFromJson(
        jsonDecode(jsonEncode(tableStateToJson(t))) as Map<String, Object?>,
      );
      final q = back.players[1];

      expect(q.id, p.id);
      expect(q.name, p.name);
      expect(q.isHero, isFalse);
      expect(q.archetype, p.archetype);
      expect(q.stack, p.stack);
      expect(q.hole, p.hole);
      expect(q.revealed, isTrue);
      expect(q.foldedStreet, Street.flop);
      expect(q.hasFolded, isTrue);
      expect(q.committed, p.committed);
      expect(q.committedTotal, p.committedTotal);
      expect(q.position, p.position);
      expect(q.lastAction!.label, 'Raise');
      expect(q.lastAction!.street, Street.preflop);
      expect(q.handsSeen, 12);
      expect(q.vpipCount, 5);
      expect(q.pfrCount, 3);
      expect(q.vpipThisHand, isTrue);
      expect(q.dials!.aggression, 1.2);
      expect(q.dials!.stickiness, 0.4);
      expect(q.dials!.cbetFlop, 0.66);
      expect(q.sittingOut, isTrue);
    });

    test('a table with no summary stays null', () {
      final t = dealtTable();
      final back = tableStateFromJson(tableStateToJson(t));
      expect(back.summary, isNull);
    });
  });

  group('hand json + coach notes', () {
    HHHand sampleHand() => HHHand(
      id: 7,
      startedAt: 1781838000000,
      button: 0,
      sb: 10,
      bb: 20,
      sbSeat: 1,
      bbSeat: 2,
      seats: [
        HHSeat(
          seat: 0,
          name: 'You',
          stack: 2000,
          isHero: true,
          position: Position.btn,
        ),
      ],
      holes: {
        0: ['As', 'Ks'],
      },
      heroNet: 260,
    );

    test('encodeHandJson adds coachNotes and keeps the engine shape', () {
      final json = encodeHandJson(
        sampleHand(),
        coachNotes: const [
          CoachNoteRecord(
            street: 'river',
            action: 'call',
            verdict: 'mistake',
            title: 'Costly call',
            plain: 'You needed 33% and had 22%.',
            steps: ['pot 6 bb', 'to call 3 bb'],
            expert: 'Villain has no bluffs here.',
            equity: 0.22,
            potOdds: 0.33,
            evBb: -1.1,
            villainName: 'Dwan',
            villainRange: ['AA', 'KK'],
          ),
        ],
      );

      final map = jsonDecode(json) as Map<String, Object?>;
      expect(map['id'], 7);
      expect(map['startedAt'], 1781838000000);
      expect(HHHand.fromJson(map).holes[0], ['As', 'Ks']);

      final notes = coachNotesFromHandJson(map);
      expect(notes, hasLength(1));
      expect(notes.single.verdict, 'mistake');
      expect(notes.single.steps, ['pot 6 bb', 'to call 3 bb']);
      expect(notes.single.villainRange, ['AA', 'KK']);
      expect(notes.single.evBb, -1.1);
    });

    test('a hand without coach notes has no coachNotes key', () {
      final map =
          jsonDecode(encodeHandJson(sampleHand())) as Map<String, Object?>;
      expect(map.containsKey('coachNotes'), isFalse);
      expect(coachNotesFromHandJson(map), isEmpty);
    });
  });

  group('tolerant decoders', () {
    test('archetypeOrNull and positionOrNull swallow junk', () {
      expect(archetypeOrNull('TAG'), Archetype.tag);
      expect(archetypeOrNull('Wizard'), isNull);
      expect(archetypeOrNull(null), isNull);
      expect(positionOrNull('BTN'), Position.btn);
      expect(positionOrNull(''), isNull);
      expect(positionOrNull(42), isNull);
    });

    test('decodeJsonMap survives bad input', () {
      expect(decodeJsonMap('{"a":1}'), {'a': 1});
      expect(decodeJsonMap('['), isNull);
      expect(decodeJsonMap(null), isNull);
      expect(decodeJsonMap('[1,2]'), isNull);
    });
  });
}
