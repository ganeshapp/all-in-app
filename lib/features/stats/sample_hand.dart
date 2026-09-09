/// The sample hand behind §7.8's "Export a sample".
///
/// When a file yields no hands, All-In offers to share one hand written in
/// exactly the dialect the importer reads, so the user can compare. Building
/// it from a real [HHHand] and running the real `formatHand` (rather than
/// pasting a text blob) means the sample can never drift from the exporter —
/// `test/features/stats/import_flow_test.dart` parses it straight back.
///
/// The hand is the canonical fixture of
/// `docs/port/persistence-stats-settings.md` §9.1: 6-max, 10/20, hero on the
/// button with A♠K♠ against Dwan's Q♥Q♦.
library;

import '../../engine/engine.dart';

/// Wall-clock the sample is stamped with: 2026-06-19 12:00 local, the
/// fixture's own timestamp.
final DateTime kSampleHandTime = DateTime(2026, 6, 19, 12);

/// A complete, replayable, exportable hand.
HHHand buildSampleHand({DateTime? at}) {
  final startedAt = (at ?? kSampleHandTime).millisecondsSinceEpoch;
  const names = ['You', 'Ivey', 'Polk', 'Dwan', 'Selbst', 'Galfond'];
  const positions = [
    Position.btn,
    Position.sb,
    Position.bb,
    Position.utg,
    Position.mp,
    Position.co,
  ];

  return HHHand(
    id: 7,
    startedAt: startedAt,
    button: 0,
    sb: 10,
    bb: 20,
    sbSeat: 1,
    bbSeat: 2,
    seats: [
      for (var i = 0; i < names.length; i++)
        HHSeat(
          seat: i,
          name: names[i],
          stack: 2000,
          isHero: i == 0,
          position: positions[i],
        ),
    ],
    holes: {
      0: const ['As', 'Ks'],
      3: const ['Qh', 'Qd'],
    },
    actions: [
      _action(Street.preflop, 4, names[4], ActionType.fold, 0),
      _action(Street.preflop, 5, names[5], ActionType.fold, 0),
      _action(Street.preflop, 3, names[3], ActionType.raise, 60),
      _action(Street.preflop, 0, names[0], ActionType.call, 60),
      _action(Street.preflop, 1, names[1], ActionType.fold, 0),
      _action(Street.preflop, 2, names[2], ActionType.fold, 0),
      _action(Street.flop, 3, names[3], ActionType.bet, 80),
      _action(Street.flop, 0, names[0], ActionType.call, 80),
      _action(Street.turn, 3, names[3], ActionType.check, 0),
      _action(Street.turn, 0, names[0], ActionType.check, 0),
      _action(Street.river, 3, names[3], ActionType.check, 0),
      _action(Street.river, 0, names[0], ActionType.bet, 120),
      _action(Street.river, 3, names[3], ActionType.call, 120),
    ],
    board: const ['Ah', 'Kd', '7c', '2s', '9h'],
    potResults: const [
      PotResult(winners: [0], amount: 520, potLabel: 'Pot'),
    ],
    heroNet: 260,
  );
}

/// The sample as PokerStars-style text — what the share sheet sends.
String sampleHandHistory({DateTime? at}) =>
    formatSession([buildSampleHand(at: at)]);

HHAction _action(
  Street street,
  int seat,
  String name,
  ActionType type,
  num amount,
) => HHAction(
  street: street,
  seat: seat,
  name: name,
  type: type,
  amount: amount,
  allIn: false,
);
