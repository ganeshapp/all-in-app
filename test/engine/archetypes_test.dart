import 'package:allin/engine/archetypes.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARCHETYPES map covers every archetype with the desktop numbers', () {
    expect(kArchetypes.length, Archetype.values.length);
    for (final a in Archetype.values) {
      expect(kArchetypes[a]!.archetype, a);
    }
    final tag = kArchetypes[Archetype.tag]!;
    expect(tag.name, 'Tight-Aggressive');
    expect(
      tag.blurb,
      'Plays few hands but bets and raises them hard. The textbook winner.',
    );
    expect(tag.vpip, 22);
    expect(tag.pfr, 18);
    expect(tag.cbetFlop, 65);
    expect(tag.aggression, 0.72);
    expect(tag.stickiness, 0.28);
    expect(tag.color, '#2f6fd0');

    final lag = kArchetypes[Archetype.lag]!;
    expect(lag.name, 'Loose-Aggressive');
    expect(
      lag.blurb,
      'Plays many hands with relentless pressure. Hard to put on a hand.',
    );
    expect(lag.vpip, 34);
    expect(lag.pfr, 27);
    expect(lag.cbetFlop, 72);
    expect(lag.aggression, 0.86);
    expect(lag.stickiness, 0.34);
    expect(lag.color, '#8a5cd1');

    final nit = kArchetypes[Archetype.nit]!;
    expect(nit.name, 'Nit');
    expect(nit.blurb, 'Extremely tight. If a Nit raises, believe them.');
    expect(nit.vpip, 12);
    expect(nit.pfr, 9);
    expect(nit.cbetFlop, 55);
    expect(nit.aggression, 0.5);
    expect(nit.stickiness, 0.2);
    expect(nit.color, '#2faa66');

    final station = kArchetypes[Archetype.station]!;
    expect(station.name, 'Calling Station');
    expect(
      station.blurb,
      'Calls far too much, rarely raises. Value-bet relentlessly, never bluff.',
    );
    expect(station.vpip, 46);
    expect(station.pfr, 7);
    expect(station.cbetFlop, 32);
    expect(station.aggression, 0.18);
    expect(station.stickiness, 0.82);
    expect(station.color, '#d23b3b');
  });

  test('ARCHETYPE_LIST order is TAG, LAG, Nit, Station', () {
    expect(kArchetypeList.map((c) => c.archetype).toList(), [
      Archetype.tag,
      Archetype.lag,
      Archetype.nit,
      Archetype.station,
    ]);
    expect(kArchetypeList.map((c) => c.archetype.label).toList(), [
      'TAG',
      'LAG',
      'Nit',
      'Station',
    ]);
  });

  test('botNameFor cycles the ten names starting at seat 1 (pinned)', () {
    const want = {
      0: 'Chidwick',
      1: 'Ivey',
      2: 'Negreanu',
      3: 'Polk',
      4: 'Selbst',
      5: 'Hellmuth',
      6: 'Brunson',
      7: 'Antonius',
      8: 'Dwan',
      9: 'Galfond',
      10: 'Chidwick',
      11: 'Ivey',
    };
    for (final e in want.entries) {
      expect(botNameFor(e.key), e.value, reason: 'seat ${e.key}');
    }
  });

  test('archetypeForSeat spreads TAG/Station/LAG/Nit/TAG/LAG (pinned)', () {
    const want = {
      1: Archetype.tag,
      2: Archetype.station,
      3: Archetype.lag,
      4: Archetype.nit,
      5: Archetype.tag,
      6: Archetype.lag,
      7: Archetype.tag,
      8: Archetype.station,
      9: Archetype.lag,
      10: Archetype.nit,
      11: Archetype.tag,
    };
    for (final e in want.entries) {
      expect(archetypeForSeat(e.key), e.value, reason: 'seat ${e.key}');
    }
  });
}
