// Scratch differential harness (parity review) — not shipped.
import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/engine/puzzles.dart';

void main(List<String> args) {
  final which = args.isNotEmpty ? args[0] : 'mixed';
  final n = args.length > 1 ? int.parse(args[1]) : 40;
  final out = StringBuffer();
  for (var s = 1; s <= n; s++) {
    final rng = Mulberry32(s);
    final p = which == 'pushfold'
        ? generatePushFold(rng: rng)
        : which == 'exploit'
            ? generateExploit(rng: rng)
            : generatePuzzle(rng: rng);
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
    out.writeln(jsonEncode({'p': j, 'grades': grades}));
  }
  stdout.write(out.toString());
}
