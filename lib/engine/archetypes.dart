/// The four bot archetypes — ported 1:1 from the desktop `src/game/archetypes.ts`.
///
/// Parameterised by VPIP / PFR plus a couple of behavioural knobs used by the
/// postflop heuristics in `bot_brain.dart`.
library;

import 'types.dart';

const Map<Archetype, ArchetypeConfig> kArchetypes = {
  Archetype.tag: ArchetypeConfig(
    archetype: Archetype.tag,
    name: 'Tight-Aggressive',
    blurb:
        'Plays few hands but bets and raises them hard. The textbook winner.',
    vpip: 22,
    pfr: 18,
    cbetFlop: 65,
    aggression: 0.72,
    stickiness: 0.28,
    color: '#2f6fd0',
  ),
  Archetype.lag: ArchetypeConfig(
    archetype: Archetype.lag,
    name: 'Loose-Aggressive',
    blurb: 'Plays many hands with relentless pressure. Hard to put on a hand.',
    vpip: 34,
    pfr: 27,
    cbetFlop: 72,
    aggression: 0.86,
    stickiness: 0.34,
    color: '#8a5cd1',
  ),
  Archetype.nit: ArchetypeConfig(
    archetype: Archetype.nit,
    name: 'Nit',
    blurb: 'Extremely tight. If a Nit raises, believe them.',
    vpip: 12,
    pfr: 9,
    cbetFlop: 55,
    aggression: 0.5,
    stickiness: 0.2,
    color: '#2faa66',
  ),
  Archetype.station: ArchetypeConfig(
    archetype: Archetype.station,
    name: 'Calling Station',
    blurb:
        'Calls far too much, rarely raises. Value-bet relentlessly, never bluff.',
    vpip: 46,
    pfr: 7,
    cbetFlop: 32,
    aggression: 0.18,
    stickiness: 0.82,
    color: '#d23b3b',
  ),
};

/// Display order: TAG, LAG, Nit, Station (desktop `ARCHETYPE_LIST`).
final List<ArchetypeConfig> kArchetypeList = List.unmodifiable([
  kArchetypes[Archetype.tag]!,
  kArchetypes[Archetype.lag]!,
  kArchetypes[Archetype.nit]!,
  kArchetypes[Archetype.station]!,
]);

const List<String> kBotNames = [
  'Ivey',
  'Negreanu',
  'Polk',
  'Selbst',
  'Hellmuth',
  'Brunson',
  'Antonius',
  'Dwan',
  'Galfond',
  'Chidwick',
];

/// Bot display name for a seat (seat 0 is hero; seats 1.. are bots).
String botNameFor(int seat) =>
    kBotNames[(seat - 1 + kBotNames.length) % kBotNames.length];

const List<Archetype> _seatOrder = [
  Archetype.tag,
  Archetype.station,
  Archetype.lag,
  Archetype.nit,
  Archetype.tag,
  Archetype.lag,
];

/// Deterministic-ish spread of archetypes across the bot seats (seat >= 1).
Archetype archetypeForSeat(int seat) =>
    _seatOrder[(seat - 1) % _seatOrder.length];
