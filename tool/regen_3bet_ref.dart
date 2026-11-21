/// Re-pins the facing-a-3-bet entries of `test/engine/bot_brain_ref.dart`
/// from THIS engine.
///
///   dart run tool/regen_3bet_ref.dart
///
/// Every other entry in that file is a desktop pin and stays one: the port
/// is still expected to match `../poker` on chart lookups, range narrowing
/// and exact-equity river spots. The facing-3-bet branch is the one place
/// the mobile policy deliberately diverged — it now prices fold / call /
/// 4-bet instead of continuing only with AA/KK/QQ/AK — so those entries
/// cannot come from the desktop generator any more.
///
/// Run this only for a deliberate policy change, the same rule as
/// `ALLIN_UPDATE_BOT_FIXTURE=1 flutter test test/engine/lockstep_test.dart`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/types.dart';

// Mirrors the scenario fixtures at the top of bot_brain_test.dart. Keep the
// two in step: the test asserts pot/currentBet/position before deciding, so
// a drift here fails loudly rather than silently re-pinning a different spot.
const GameConfig _cfg = GameConfig(
  seats: 6,
  startingStack: 2000,
  smallBlind: 10,
  bigBlind: 20,
);

const List<Card> _deck = [
  '2c', '3d', '4h', '5s', '6c', '7d', '8h', '9s', 'Tc', 'Jd', //
  '9c', 'Th', '2s', 'Js', '3h', '8d', 'Kc', 'Qc',
];

const Map<int, List<Card>> _holes = {
  0: ['Ah', 'Qd'],
  1: ['5c', '6d'],
  2: ['Ks', 'Kd'],
  3: ['4c', '4d'],
  4: ['Jc', 'Tc'],
  5: ['6s', '5h'],
};

class _FixedRandom implements Random {
  _FixedRandom(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => (v * max).toInt();
  @override
  bool nextBool() => v < 0.5;
}

TableState _setup(Map<int, Archetype> archs, Map<int, List<Card>> holes) {
  var s = createTable(_cfg, rng: Random(1));
  s.button = 0;
  for (final e in archs.entries) {
    s.players[e.key].archetype = e.value;
  }
  s = startHand(s, rng: Random(7));
  s.deck = List<Card>.of(_deck);
  for (final p in s.players) {
    p.hole = List<Card>.of(holes[p.id] ?? _holes[p.id]!);
  }
  return s;
}

/// UTG opens 50, MP 3-bets to 160, and seat 5 (CO) has to answer.
TableState _threeBet(Archetype a, List<Card> hole) {
  var s = _setup({5: a}, {5: hole});
  s = applyAction(s, 3, const Action.raise(50));
  return applyAction(s, 4, const Action.raise(160));
}

/// The shape `_pinPre` reads: the asserted spot, then the decision.
Map<String, dynamic> _entry(TableState s, int seat, double r) {
  final la = legalActions(s);
  final d = decideBot(s, seat, rng: _FixedRandom(r));
  return {
    'action': {
      'type': d.action.type.label,
      if (d.action.amount != null) 'amount': d.action.amount,
    },
    'range': d.range,
    'la': {
      'toCall': la.toCall,
      'canFold': la.canFold,
      'canCheck': la.canCheck,
      'canCall': la.canCall,
      'callAmount': la.callAmount,
      'canBet': la.canBet,
      'canRaise': la.canRaise,
      'minRaiseTo': la.minRaiseTo,
      'maxRaiseTo': la.maxRaiseTo,
      'potSize': s.pot,
      'bigBlind': s.bigBlind,
    },
    'pot': s.pot,
    'currentBet': s.currentBet,
    'street': s.street.label,
    'board': s.board,
    'pos': s.players[seat].position.label,
  };
}

void main() {
  final nitQQ = _threeBet(Archetype.nit, ['Qc', 'Qd']);
  final tagAA = _threeBet(Archetype.tag, ['Ac', 'Ad']);
  final stationA5 = _threeBet(Archetype.station, ['Ac', '5c']);
  final station72 = _threeBet(Archetype.station, ['7c', '2d']);

  final fresh = <String, Map<String, dynamic>>{
    'P7_nit_co_QQ_vs_3bet_020': _entry(nitQQ, 5, 0.2),
    'P7b_nit_co_QQ_vs_3bet_050': _entry(nitQQ, 5, 0.5),
    'P7c_tag_co_AA_vs_3bet_050': _entry(tagAA, 5, 0.5),
    'P7d_tag_co_AA_vs_3bet_090': _entry(tagAA, 5, 0.9),
    'P8_station_co_72o_vs_3bet_000': _entry(station72, 5, 0.0),
    'P8b_station_co_A5s_vs_3bet_010': _entry(stationA5, 5, 0.1),
    'P8c_station_co_A5s_vs_3bet_090': _entry(stationA5, 5, 0.9),
  };

  final path = 'test/engine/bot_brain_ref.dart';
  final lines = File(path).readAsLinesSync();
  final at = lines.indexWhere((l) => l.trimLeft().startsWith('{"preflop"'));
  if (at < 0) throw StateError('could not find the JSON line in $path');

  final ref = jsonDecode(lines[at]) as Map<String, dynamic>;
  final pre = ref['preflop'] as Map<String, dynamic>;
  for (final e in fresh.entries) {
    if (!pre.containsKey(e.key)) {
      throw StateError('${e.key} is not in the reference — scenario renamed?');
    }
    // ignore: avoid_print
    print('${e.key.padRight(32)} ${jsonEncode(e.value['action'])}');
    pre[e.key] = e.value;
  }
  lines[at] = jsonEncode(ref);
  File(path).writeAsStringSync('${lines.join('\n')}\n');
  // ignore: avoid_print
  print('\nre-pinned ${fresh.length} entries in $path');
}
