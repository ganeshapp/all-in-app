// Scratch differential harness (parity review) — not shipped.
import 'dart:convert';
import 'dart:io';

import 'package:allin/engine/format.dart';
import 'package:allin/engine/icm.dart';
import 'package:allin/engine/leaks.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/srs.dart';
import 'package:allin/engine/types.dart';

Object? num2json(num v) {
  final d = v.toDouble();
  if (d == d.truncateToDouble() && d.abs() < 1e15) return d.toInt();
  return d;
}

void main() {
  final out = StringBuffer();
  final rnd = Mulberry32(7);

  final vals = <double>[
    0, -0.0, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 0.05, -0.05, 0.049999, 1 / 3,
    2 / 3, -1 / 3, 100, -100, 1234567, -1234567, 999.95, -999.95, 0.15, 0.25,
    0.35, 0.45, 0.75, 1.005, -1.005, 12.345, -12.345, 1e-8, -1e-8, 1e6 + 0.5,
    20, 30, 45, 5,
  ];
  for (var i = 0; i < 400; i++) {
    vals.add((rnd.next() * 2000 - 1000) / (rnd.next() < 0.5 ? 1 : 7));
  }
  for (final v in vals) {
    out.writeln(jsonEncode(['fmtChips', num2json(v), fmtChips(v)]));
    out.writeln(jsonEncode(['fmtSigned0', num2json(v), fmtSigned(v, 0)]));
    out.writeln(jsonEncode(['fmtSigned1', num2json(v), fmtSigned(v)]));
    out.writeln(jsonEncode(['fmtSigned2', num2json(v), fmtSigned(v, 2)]));
    for (final bb in [1, 2, 20, 0.5]) {
      out.writeln(jsonEncode(['fmtBb', num2json(v), num2json(bb), fmtBb(v, bb)]));
    }
  }
  final fracs = <double>[
    0, 0.001, 0.02, 0.04, 0.040001, 0.05, 0.1, 0.125, 0.2, 0.25, 0.33, 0.4,
    0.44, 0.45, 0.449999, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.9, 0.925,
    0.93, 0.95, 1, -0.1, 1.4, 0.045, 0.0454, 0.14285714285,
  ];
  for (var i = 0; i < 400; i++) {
    fracs.add(rnd.next());
  }
  for (final f in fracs) {
    out.writeln(jsonEncode(['fmtPct0', num2json(f), fmtPct(f)]));
    out.writeln(jsonEncode(['fmtPct1', num2json(f), fmtPct(f, 1)]));
    out.writeln(jsonEncode(['fmtPct2', num2json(f), fmtPct(f, 2)]));
    out.writeln(jsonEncode(['fmtTimes', num2json(f), fmtTimes(f)]));
    out.writeln(jsonEncode(['fmtNeed', num2json(f), fmtNeed(f)]));
  }

  final scen = <List<List<num>>>[
    [[100, 100, 100, 100], [50, 30, 20]],
    [[1000, 10, 500, 3000], [50, 30, 20]],
    [[0, 100, 200], [50, 30, 20]],
    [[5, 5], [100]],
    [[1], [50, 30, 20]],
    [[], [50]],
    [[10, 20, 30, 40, 50], [45, 27, 18, 10]],
    [[0, 0, 0], [50, 30, 20]],
  ];
  for (var i = 0; i < 30; i++) {
    final n = 2 + (rnd.next() * 4).floor();
    final st = [for (var k = 0; k < n; k++) (rnd.next() * 5000).floor()];
    final pk = 1 + (rnd.next() * 4).floor();
    final py = [for (var k = 0; k < pk; k++) (rnd.next() * 100).floor()];
    scen.add([st, py]);
  }
  for (final s in scen) {
    out.writeln(jsonEncode([
      'icm',
      s[0].map(num2json).toList(),
      s[1].map(num2json).toList(),
      icmShares(s[0], s[1]).map(num2json).toList(),
    ]));
  }

  {
    const now = 1700000000000;
    for (var seq = 0; seq < 60; seq++) {
      var s = newSrs(now);
      Object srsJson(SrsState x) => {
            'due': x.due,
            'intervalDays': num2json(x.intervalDays),
            'ease': num2json(x.ease),
            'reps': x.wins,
            'lapses': x.lapses,
          };
      final trace = <Object?>[srsJson(s)];
      var t = now;
      for (var i = 0; i < 10; i++) {
        final correct = rnd.next() < 0.65;
        t += (rnd.next() * 5000000).floor();
        s = reviewSrs(s, correct, t);
        trace.add([
          correct,
          t,
          srsJson(s),
          isDue(s, t),
          isDue(s, t + 86400000 * 30),
          isGraduated(s),
        ]);
      }
      out.writeln(jsonEncode(['srs', seq, trace]));
    }
  }

  {
    const verdicts = ['mistake', 'thin', 'ok', 'great', 'info'];
    const actions = ['fold', 'check', 'call', 'bet', 'raise', 'post'];
    for (var seq = 0; seq < 60; seq++) {
      final n = (rnd.next() * 20).floor();
      final dec = [
        for (var k = 0; k < n; k++)
          DecisionRecord(
            verdict: verdicts[(rnd.next() * 5).floor()],
            action: actions[(rnd.next() * 6).floor()],
            equity: rnd.next(),
            potOdds: rnd.next(),
            evBb: rnd.next() * 4 - 2,
            street: 'flop',
            villainArchetype: null,
            ts: 0,
          ),
      ];
      final r = leaksFromDecisions(dec);
      out.writeln(jsonEncode([
        'leaks',
        seq,
        [for (final d in dec) [d.verdict, d.action]],
        {
          'total': r.total,
          'mistakes': r.mistakes,
          'thin': r.thin,
          'great': r.great,
          'foldMistakes': r.foldMistakes,
          'callMistakes': r.callMistakes,
          'leaks': r.leaks,
        },
      ]));
    }
  }
  stdout.write(out.toString());
}
