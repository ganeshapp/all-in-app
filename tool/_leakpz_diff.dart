import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/cards.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/puzzles.dart';
import 'package:allin/engine/types.dart';

Object? n2j(num v) {
  final d = v.toDouble();
  return (d == d.truncateToDouble() && d.abs() < 1e15) ? d.toInt() : d;
}

void main() {
  final r = Mulberry32(31337);
  int ri(int n) => (r.next() * n).toInt();
  T pick<T>(List<T> a) => a[ri(a.length)];
  const pos = [Position.utg, Position.mp, Position.co, Position.btn, Position.sb, Position.bb];
  const streets = [Street.preflop, Street.flop, Street.turn, Street.river];
  final out = <String>[];
  for (var i = 0; i < 600; i++) {
    final street = pick(streets);
    final n = street == Street.preflop ? 0 : street == Street.flop ? 3 : street == Street.turn ? 4 : 5;
    final d = shuffle(makeDeck(), rng: r);
    final heroPos = pick(pos);
    final opp = [for (final p in pos) if (p != heroPos && r.next() < 0.4) p];
    final bb = pick(<double>[1, 20, 40, 0.5, 3]);
    final toCall = pick(<double>[0, 0, 5, 100, 1, bb, bb * 2.5, -3]);
    final pot = pick(<double>[0, 30, 155, 2000, 7.5]);
    final spot = LeakSpot(
      id: '$i',
      street: street,
      heroPos: heroPos,
      hole: [d[0], d[1]],
      board: d.sublist(2, 2 + n),
      pot: pot,
      toCall: toCall,
      bb: bb,
      oppActive: opp,
      options: [
        const DrillOption(action: DrillAction.fold, label: 'Fold'),
        DrillOption(action: DrillAction.call, label: 'Call ${(toCall / bb).toStringAsFixed(1)} bb', amount: toCall),
        DrillOption(action: DrillAction.raise, label: 'Raise', amount: (pot + toCall).roundToDouble()),
      ],
      best: pick(const [DrillAction.fold, DrillAction.call, DrillAction.check, DrillAction.bet, DrillAction.raise]),
      rationale: 'because',
      equity: r.next() < 0.2 ? null : r.next(),
      potOdds: r.next() < 0.2 ? null : r.next(),
      ts: 1700000000000 + i,
    );
    final p = puzzleFromLeak(spot);
    final j = p.toJson();
    j['id'] = 0;
    final grades = [
      for (final a in DrillAction.values)
        () {
          final g = gradePuzzle(p, a);
          return {
            'correct': g.correct,
            'best': g.best.label,
            'accept': g.accept.map((x) => x.label).toList(),
            'rationale': g.rationale,
            if (g.evLossBb != null) 'evLossBb': g.evLossBb,
          };
        }(),
    ];
    out.add(jsonEncode({
      'spot': {
        'id': spot.id,
        'street': spot.street.label,
        'heroPos': spot.heroPos.label,
        'hole': spot.hole,
        'board': spot.board,
        'pot': n2j(spot.pot),
        'toCall': n2j(spot.toCall),
        'bb': n2j(spot.bb),
        'oppActive': [for (final p in spot.oppActive) p.label],
        'options': [
          for (final o in spot.options)
            {'action': o.action.label, 'label': o.label, if (o.amount != null) 'amount': n2j(o.amount!)}
        ],
        'best': spot.best.label,
        'rationale': spot.rationale,
        if (spot.equity != null) 'equity': spot.equity,
        if (spot.potOdds != null) 'potOdds': spot.potOdds,
        'ts': spot.ts,
      },
      'p': j,
      'grades': grades,
    }));
  }
  stdout.write(out.join('\n'));
}
