import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/coach.dart';
import 'package:allin/engine/equity.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';

String? diff(Object? a, Object? b, [String path = r'$']) {
  final all = <String>[];
  _diff(a, b, path, all);
  return all.isEmpty ? null : all.join(' | ');
}

void _diff(Object? a, Object? b, String path, List<String> out) {
  if (a is Map && b is Map) {
    for (final k in {...a.keys, ...b.keys}) {
      if (!a.containsKey(k)) {
        out.add('$path.$k missing in actual');
      } else if (!b.containsKey(k)) {
        out.add('$path.$k unexpected in actual');
      } else {
        _diff(a[k], b[k], '$path.$k', out);
      }
    }
    return;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      out.add('$path length ${a.length} != ${b.length}');
      return;
    }
    for (var i = 0; i < a.length; i++) {
      _diff(a[i], b[i], '$path[$i]', out);
    }
    return;
  }
  if (a is num && b is num) {
    if (a != b) out.add('$path: $a != $b');
    return;
  }
  if (a != b) out.add('$path: ${jsonEncode(a)} != ${jsonEncode(b)}');
}

TableState stateFrom(Map j) {
  final cfg = j['config'] as Map;
  final players = [
    for (final p in (j['players'] as List).cast<Map>())
      Player(
        id: p['id'] as int,
        name: p['name'] as String,
        isHero: p['isHero'] as bool,
        archetype: p['archetype'] == null ? null : Archetype.fromLabel(p['archetype'] as String),
        stack: p['stack'] as int,
        hole: (p['hole'] as List?)?.cast<String>(),
        hasFolded: p['hasFolded'] as bool,
        committed: p['committed'] as int,
        committedTotal: p['committedTotal'] as int,
        position: Position.fromLabel(p['position'] as String),
        lastAction: p['lastAction'] == null ? null : PlayerLastAction((p['lastAction'] as Map)['label'] as String, Street.fromLabel((p['lastAction'] as Map)['street'] as String)),
      ),
  ];
  return TableState(
    config: GameConfig(seats: cfg['seats'] as int, startingStack: 2000, smallBlind: (cfg['smallBlind'] as num).toInt(), bigBlind: cfg['bigBlind'] as int),
    players: players,
    button: j['button'] as int,
    street: Street.fromLabel(j['street'] as String),
    board: (j['board'] as List).cast<String>(),
    pot: j['pot'] as int,
    currentBet: j['currentBet'] as int,
    lastRaiseSize: j['lastRaiseSize'] as int,
    aggressor: j['aggressor'] as int?,
    toAct: j['toAct'] as int?,
    handNumber: j['handNumber'] as int,
    smallBlind: (j['smallBlind'] as num).toInt(),
    bigBlind: j['bigBlind'] as int,
    phase: GamePhase.betting,
    botRanges: {for (final e in (j['botRanges'] as Map).entries) int.parse(e.key as String): (e.value as List).cast<String>()},
  );
}

Future<void> main(List<String> args) async {
  final cases = (jsonDecode(File(args[0]).readAsStringSync()) as List).cast<Map>();
  var fails = 0;
  void report(String what, String? d) {
    if (d != null) {
      fails++;
      if (fails <= 40) print('MISMATCH $what: $d');
    }
  }
  for (final c in cases) {
    final i = c['i'];
    final st = stateFrom(c['state'] as Map);
    final s = c['settings'] as Map;
    final settings = CoachSettings(strictness: CoachStrictness.fromLabel(s['coachStrictness'] as String), simQuality: SimQuality.fromLabel(s['simQuality'] as String));
    for (final rv in (c['reviews'] as List).cast<Map>()) {
      final aj = rv['action'] as Map;
      final action = Action(ActionType.fromLabel(aj['type'] as String), amount: aj['amount'] as int?);
      final calls = <Map<String, Object?>>[];
      EquityResult runner(EquityRequest q) {
        final extra = q.mode == EquityMode.field ? q.opponents : q.mode == EquityMode.range ? q.range.length : 0;
        calls.add({'mode': q.mode.label, 'hero': q.hero, 'board': q.board, 'extra': extra, 'iters': q.iters, 'seed': q.seed});
        if (q.seed % 17 == 0) throw StateError('boom');
        final g = Mulberry32((q.seed ^ q.iters) & 0xFFFFFFFF);
        final equity = g.next();
        final se = 0.002 + 0.04 * g.next();
        final exact = g.next() < 0.2;
        final samples = exact ? 12345 : q.iters;
        return EquityResult(equity: equity, win: 0, tie: 0, lose: 0, samples: samples, se: se, exact: exact);
      }
      final r = await evaluateHero(st, action, 100 + (i as int), settings: settings, runEquity: runner);
      report('case $i ${aj['type']} calls', diff(calls, rv['calls']));
      final expected = rv['review'];
      if (expected == null) {
        if (r != null) report('case $i ${aj['type']}', 'expected null, got ${r.verdict}');
        continue;
      }
      if (r == null) { report('case $i ${aj['type']}', 'expected review, got null'); continue; }
      report('case $i ${aj['type']} review', diff(r.toJson(), expected));
    }
    for (final b in (c['bots'] as List).cast<Map>()) {
      final p = st.players[b['id'] as int];
      if (interpretBot(p) != b['interpret']) report('case $i bot ${b['id']} interpret', '${interpretBot(p)} vs ${b['interpret']}');
      report('case $i bot ${b['id']} range', diff(villainRangeFor(st, p), b['range']));
    }
    if (firstOpponentInHand(st) != c['firstOpp']) report('case $i firstOpp', '');
  }
  print('done, $fails mismatches over ${cases.length} cases');
}
