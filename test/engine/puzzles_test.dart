// Drill generator + grader tests.
//
// The reference puzzles in puzzles_ref.dart were produced by running the
// desktop src/engine/puzzles.ts under Node 23 with
// `Math.random = mulberry32(seed)` installed before each generator call, so
// `Mulberry32(seed)` in Dart must reproduce the deal, every spot parameter,
// the seeded equity sims and the rationale text bit-for-bit. The structural
// checks below port scripts/puzzles_test.ts, scripts/preflop_test.ts and
// scripts/pushfold_test.ts.
import 'dart:convert';
import 'dart:math';

import 'package:allin/data/icm_scenarios.g.dart';
import 'package:allin/data/preflop_charts.g.dart';
import 'package:allin/data/pushfold_tables.g.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/puzzles.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'puzzles_ref.dart';

/* ----------------------------- helpers ----------------------------- */

/// First differing path between two decoded-JSON trees, or null when equal.
/// Numbers compare with `==` (JSON ints vs integral Dart doubles are equal).
String? _diff(Object? a, Object? b, [String path = r'$']) {
  if (a is Map && b is Map) {
    for (final k in {...a.keys, ...b.keys}) {
      if (!a.containsKey(k)) return '$path.$k missing in actual';
      if (!b.containsKey(k)) return '$path.$k unexpected in actual';
      final d = _diff(a[k], b[k], '$path.$k');
      if (d != null) return d;
    }
    return null;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return '$path length ${a.length} != ${b.length}';
    }
    for (var i = 0; i < a.length; i++) {
      final d = _diff(a[i], b[i], '$path[$i]');
      if (d != null) return d;
    }
    return null;
  }
  if (a is num && b is num) return a == b ? null : '$path: $a != $b';
  return a == b ? null : '$path: ${jsonEncode(a)} != ${jsonEncode(b)}';
}

int _expectBoard(Street s) => switch (s) {
  Street.preflop => 0,
  Street.flop => 3,
  Street.turn => 4,
  _ => 5,
};

/// scripts/pushfold_test.ts `width`: combo-weighted share of the 1326 combos.
double _width(Map<String, double>? r) {
  var acc = 0.0;
  for (final e in (r ?? const {}).entries) {
    final l = e.key;
    acc +=
        e.value *
        (l.length == 2
            ? 6
            : l.endsWith('s')
            ? 4
            : 12);
  }
  return acc / 1326;
}

const List<LeakSpot> _refLeakSpots = [
  LeakSpot(
    id: 'x',
    street: Street.flop,
    heroPos: Position.btn,
    hole: ['Ah', 'Kd'],
    board: ['As', '7c', '2d'],
    pot: 120,
    toCall: 40,
    bb: 20,
    oppActive: [Position.bb],
    options: [
      DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(action: DrillAction.call, label: 'Call', amount: 40),
      DrillOption(action: DrillAction.raise, label: 'Raise', amount: 160),
    ],
    best: DrillAction.fold,
    rationale: 'test',
    ts: 0,
  ),
  LeakSpot(
    id: 'y',
    street: Street.preflop,
    heroPos: Position.sb,
    hole: ['7c', '2d'],
    board: [],
    pot: 30,
    toCall: 0,
    bb: 20,
    oppActive: [Position.bb, Position.co],
    options: [
      DrillOption(action: DrillAction.check, label: 'Check'),
      DrillOption(action: DrillAction.bet, label: 'Bet', amount: 60),
    ],
    best: DrillAction.check,
    rationale: 'why',
    equity: 0.31,
    potOdds: 0.25,
    ts: 5,
  ),
  LeakSpot(
    id: 'z',
    street: Street.river,
    heroPos: Position.mp,
    hole: ['Qs', 'Qd'],
    board: ['2c', '5d', '9h', 'Kd', '3s'],
    pot: 1.5,
    toCall: 0.75,
    bb: 1,
    oppActive: [Position.utg],
    options: [
      DrillOption(action: DrillAction.fold, label: 'Fold'),
      DrillOption(action: DrillAction.call, label: 'Call', amount: 0.75),
    ],
    best: DrillAction.call,
    rationale: 'r',
    equity: 0.6,
    potOdds: 0.3333,
    ts: 9,
  ),
];

void main() {
  /* ------------------- desktop parity (seeded Math.random) ------------------- */

  group('desktop parity', () {
    final refs = (jsonDecode(kPuzzlesRefJson) as List).cast<Map>();
    var leakIdx = 0;

    for (final ref in refs) {
      final gen = ref['gen'] as String;
      final seed = ref['seed'] as int;
      final refPuzzle = (ref['puzzle'] as Map).cast<String, Object?>();
      final kind = refPuzzle['kind'];
      final leakNo = gen == 'leak' ? leakIdx++ : -1;

      test('$gen seed $seed ($kind) reproduces the desktop puzzle', () {
        final Puzzle p = switch (gen) {
          'puzzle' => generatePuzzle(rng: Mulberry32(seed)),
          'pushfold' => generatePushFold(rng: Mulberry32(seed)),
          'exploit' => generateExploit(rng: Mulberry32(seed)),
          'leak' => puzzleFromLeak(_refLeakSpots[leakNo]),
          _ => throw StateError(gen),
        };
        // Ids are a session counter (desktop SEQ); everything else is pinned.
        final actual = p.toJson()..remove('id');
        final expected = Map<String, Object?>.of(refPuzzle)..remove('id');
        expect(_diff(actual, expected), isNull);
        expect(
          actual.keys.toList(),
          expected.keys.toList(),
          reason: 'key order',
        );

        final grades = (ref['grades'] as Map).cast<String, Object?>();
        for (final a in DrillAction.values) {
          final g = gradePuzzle(p, a);
          final rg = (grades[a.label] as Map).cast<String, Object?>();
          expect(g.correct, rg['correct'], reason: '${a.label} correct');
          expect(g.evLossBb, rg['evLossBb'], reason: '${a.label} evLossBb');
          expect(g.best, p.best);
          expect(g.accept, p.accept);
          expect(g.rationale, p.rationale);
        }
      });
    }

    test('reference covers every puzzle kind', () {
      final kinds = refs.map((r) => (r['puzzle'] as Map)['kind']).toSet();
      expect(kinds, PuzzleKind.values.map((k) => k.label).toSet());
    });

    test('Elo update matches drillStore.ts', () {
      final rows = (jsonDecode(kEloRefJson) as List).cast<Map>();
      expect(rows, isNotEmpty);
      for (final r in rows) {
        final rating = r['rating'] as int;
        final difficulty = r['difficulty'] as int;
        final correct = r['correct'] as bool;
        final delta = eloDelta(rating, difficulty, correct);
        expect(delta, r['delta'], reason: '$rating d$difficulty $correct');
        expect(applyRatingDelta(rating, delta), r['next']);
      }
      expect(puzzleRating(1), 1000);
      expect(puzzleRating(2), 1200);
      expect(puzzleRating(3), 1400);
      expect(kDefaultRating, 1000);
      expect(kEloK, 24);
      expect(kMinRating, 100);
      expect(kReviewCap, 80);
    });

    test('same seed, same puzzle; different seeds differ', () {
      final a = generatePuzzle(rng: Mulberry32(77));
      final b = generatePuzzle(rng: Mulberry32(77));
      final c = generatePuzzle(rng: Mulberry32(78));
      expect(_diff(a.toJson()..remove('id'), b.toJson()..remove('id')), isNull);
      expect(
        _diff(a.toJson()..remove('id'), c.toJson()..remove('id')),
        isNotNull,
      );
    });
  });

  /* ---------------------- scripts/puzzles_test.ts ---------------------- */

  group('puzzles_test.ts', () {
    test('chart sanity (the membership the grader relies on)', () {
      expect(kRfi100['UTG']!['AA'], 1);
      expect(kRfi100['UTG']!['72o'] ?? 0, 0);
      expect(
        chartWidth(kRfi100['BTN']!),
        greaterThan(chartWidth(kRfi100['UTG']!)),
      );
    });

    test('800 generated puzzles are structurally coherent', () {
      final rng = Mulberry32(0xd211);
      final kinds = <PuzzleKind>{};
      var rfi = 0;
      var vs = 0;
      for (var i = 0; i < 800; i++) {
        final p = generatePuzzle(rng: rng);
        kinds.add(p.kind);
        if (p.kind == PuzzleKind.rfi) rfi++;
        if (p.kind == PuzzleKind.vsRaise) vs++;
        final why = '#$i ${p.kind.label} ${p.handLabel} ${p.board.join(' ')}';

        // structure
        expect(p.hole.length, 2, reason: why);
        expect(p.hole[0], isNot(p.hole[1]), reason: why);
        expect(p.board.length, _expectBoard(p.street), reason: why);
        expect(p.pot, greaterThan(0), reason: why);
        expect(p.toCall, greaterThanOrEqualTo(0), reason: why);
        expect(p.frames.length, greaterThanOrEqualTo(2), reason: why);
        expect(p.options.length, greaterThanOrEqualTo(2), reason: why);
        expect(p.accept, isNotEmpty, reason: why);
        expect(p.accept, contains(p.best), reason: why);
        expect(p.options.map((o) => o.action), contains(p.best), reason: why);
        expect(p.difficulty, inInclusiveRange(1, 3), reason: why);
        expect(p.bb, 1, reason: why);
        expect(p.rationale, isNotEmpty, reason: why);
        expect(p.gradeRange, isNotNull, reason: why);
        expect(p.lessonId, isNotNull, reason: why);

        // grading consistency
        expect(gradePuzzle(p, p.best).correct, isTrue, reason: why);
        for (final a in DrillAction.values) {
          final offered = p.options.any((o) => o.action == a);
          if (offered && !p.accept.contains(a)) {
            expect(gradePuzzle(p, a).correct, isFalse, reason: why);
          }
        }

        // postflop puzzles expose equity + odds where relevant
        if (p.kind == PuzzleKind.postflopBet) {
          expect(p.equity, isNotNull, reason: why);
          expect(p.potOdds, isNotNull, reason: why);
        }
        if (p.street != Street.preflop) {
          expect(p.equity, inInclusiveRange(0, 1), reason: why);
        }
      }
      expect(kinds.length, 7, reason: 'all seven cash puzzle kinds generated');
      expect(kinds, isNot(contains(PuzzleKind.pushfold)));
      // preflop_test.ts: both preflop puzzle kinds generate
      expect(rfi, greaterThan(100));
      expect(vs, greaterThan(100));
    });

    test('400 push/fold puzzles', () {
      final rng = Mulberry32(0x9f);
      var icm = 0;
      for (var i = 0; i < 400; i++) {
        final p = generatePushFold(rng: rng);
        expect(p.kind, PuzzleKind.pushfold);
        expect(p.street, Street.preflop);
        expect(p.board, isEmpty);
        expect(p.options.length, 2);
        expect(p.accept, contains(p.best));
        expect(p.options.map((o) => o.action), contains(p.best));
        expect(gradePuzzle(p, p.best).correct, isTrue);
        expect(p.source, PuzzleSource.chart);
        expect(p.lessonId, 'spr');
        if (p.icm == true) icm++;
      }
      expect(icm, inInclusiveRange(80, 190));
    });

    test('leak -> puzzle', () {
      final lp = puzzleFromLeak(_refLeakSpots[0]);
      expect(lp.kind, PuzzleKind.leak);
      expect(lp.best, DrillAction.fold);
      expect(gradePuzzle(lp, DrillAction.fold).correct, isTrue);
      expect(gradePuzzle(lp, DrillAction.call).correct, isFalse);
      expect(lp.seats.any((s) => s.isHero && s.pos == Position.btn), isTrue);
      expect(lp.frames.length, greaterThanOrEqualTo(2));
      expect(lp.frames[0].text, 'Flop: As 7c 2d');
      expect(
        lp.frames[1].text,
        "Action on you in the BTN facing 2.0 bb. What's the play?",
      );
      expect(lp.handLabel, 'AKo');
      expect(lp.accept, [DrillAction.fold]);
      expect(lp.difficulty, 2);
      expect(lp.source, PuzzleSource.heuristic);
      expect(lp.lessonId, isNull);
      expect(lp.icm, isNull);
      final seats = {for (final s in lp.seats) s.pos: s};
      expect(seats[Position.bb]!.active, isTrue);
      expect(seats[Position.bb]!.folded, isFalse);
      expect(seats[Position.utg]!.folded, isTrue);
      expect(seats[Position.btn]!.active, isFalse);

      final pre = puzzleFromLeak(_refLeakSpots[1]);
      expect(pre.frames[0].text, 'Pre-flop.');
      expect(pre.frames[1].text, "Action on you in the SB. What's the play?");
      expect(pre.equity, 0.31);
    });
  });

  /* ---------------------- scripts/preflop_test.ts ---------------------- */

  group('preflop_test.ts', () {
    const pairs = [
      'MP_vs_UTG',
      'CO_vs_UTG',
      'CO_vs_MP',
      'BTN_vs_UTG',
      'BTN_vs_MP',
      'BTN_vs_CO',
      'SB_vs_UTG',
      'SB_vs_MP',
      'SB_vs_CO',
      'SB_vs_BTN',
      'BB_vs_UTG',
      'BB_vs_MP',
      'BB_vs_CO',
      'BB_vs_BTN',
      'BB_vs_SB',
    ];

    test('structure', () {
      for (final pos in ['UTG', 'MP', 'CO', 'BTN', 'SB']) {
        expect((kRfi100[pos] ?? const {}).length, greaterThan(20), reason: pos);
      }
      for (final k in pairs) {
        expect(kVsRfi100[k]?['threebet'], isNotNull, reason: k);
        expect(kVsRfi100[k]?['call'], isNotNull, reason: k);
      }
    });

    test('frequencies are valid and never sum past 100%', () {
      var badFreq = 0;
      var overSum = 0;
      for (final chart in kRfi100.values) {
        for (final f in chart.values) {
          if (!(f > 0 && f <= 1)) badFreq++;
        }
      }
      for (final charts in kVsRfi100.values) {
        final threebet = charts['threebet']!;
        final call = charts['call']!;
        for (final f in [...threebet.values, ...call.values]) {
          if (!(f > 0 && f <= 1)) badFreq++;
        }
        for (final e in call.entries) {
          if (e.value + (threebet[e.key] ?? 0) > 1.001) overSum++;
        }
      }
      expect(badFreq, 0);
      expect(overSum, 0);
    });

    test('widths: positional monotonicity and sane bands', () {
      double w(String pos) => chartWidth(kRfi100[pos]!);
      expect(w('UTG'), lessThan(w('MP')));
      expect(w('MP'), lessThan(w('CO')));
      expect(w('CO'), lessThan(w('BTN')));
      expect(w('UTG'), inExclusiveRange(0.1, 0.2));
      expect(w('BTN'), inExclusiveRange(0.38, 0.52));
    });

    test('raiser position matters', () {
      double cont(String k) =>
          chartWidth(kVsRfi100[k]!['threebet']!) +
          chartWidth(kVsRfi100[k]!['call']!);
      expect(cont('BB_vs_BTN'), greaterThan(cont('BB_vs_UTG') + 0.1));
      expect(cont('BTN_vs_CO'), greaterThan(cont('BTN_vs_UTG')));
      expect(
        chartWidth(kVsRfi100['SB_vs_BTN']!['threebet']!),
        greaterThan(chartWidth(kVsRfi100['SB_vs_UTG']!['threebet']!)),
      );
    });

    test('the hands Chen got wrong', () {
      expect(kVsRfi100['BB_vs_BTN']!['threebet']!['A5s'] ?? 0, greaterThan(0));
      expect(kVsRfi100['BB_vs_UTG']!['threebet']!['KJo'] ?? 0, 0);
      expect(kVsRfi100['CO_vs_UTG']!['threebet']!['KJo'] ?? 0, 0);
      for (final k in pairs) {
        expect(kVsRfi100[k]!['threebet']!['AA'], 1, reason: k);
      }
      expect(kRfi100['UTG']!['72o'] ?? 0, 0);
      expect(kRfi100['BTN']!['72o'] ?? 0, 0);
      expect(kVsRfi100['BTN_vs_CO']!['call']!['76s'] ?? 0, greaterThan(0));
      expect(kRfi100['UTG']!['A5s'] ?? 0, greaterThan(0));
    });
  });

  /* ---------------------- scripts/pushfold_test.ts ---------------------- */

  group('pushfold_test.ts', () {
    test('table structure', () {
      for (final s in kPushFoldStacks) {
        expect(kNashShove[s]?['SB'], isNotNull, reason: 'stack $s');
        expect(kNashShove[s]?['BTN'], isNotNull, reason: 'stack $s');
        expect(kNashCall[s]?['SB>BB'], isNotNull, reason: 'stack $s');
      }
      for (final s in kPushFoldDrillStacks) {
        expect(kPushFoldStacks, contains(s));
      }
    });

    test('SB jams wider than BTN at every stack', () {
      for (final s in kPushFoldStacks) {
        expect(
          _width(kNashShove[s]!['SB']),
          greaterThan(_width(kNashShove[s]!['BTN'])),
          reason: 'stack $s',
        );
      }
    });

    test('positional monotonicity at 10bb', () {
      double w10(String p) => _width(kNashShove[10]![p]);
      expect(w10('UTG'), lessThan(w10('MP')));
      expect(w10('MP'), lessThan(w10('CO')));
      expect(w10('CO'), lessThan(w10('BTN')));
      expect(w10('BTN'), lessThan(w10('SB')));
    });

    test('stack monotonicity: shorter = wider', () {
      expect(
        _width(kNashShove[5]!['SB']),
        greaterThan(_width(kNashShove[10]!['SB'])),
      );
      expect(
        _width(kNashShove[10]!['SB']),
        greaterThan(_width(kNashShove[20]!['SB'])),
      );
      expect(
        _width(kNashCall[5]!['SB>BB']),
        greaterThan(_width(kNashCall[15]!['SB>BB'])),
      );
    });

    test('published-value neighbourhoods', () {
      expect(_width(kNashShove[10]!['SB']), inExclusiveRange(0.45, 0.68));
      expect(_width(kNashCall[10]!['SB>BB']), inExclusiveRange(0.28, 0.48));
    });

    test('hand-level sanity', () {
      for (final s in kPushFoldStacks) {
        expect(kNashShove[s]!['SB']?['AA'] ?? 0, 1, reason: 'stack $s');
        expect(kNashCall[s]!['SB>BB']?['AA'] ?? 0, 1, reason: 'stack $s');
      }
      expect(kNashShove[10]!['BTN']?['72o'] ?? 0, 0);
      expect(kNashShove[10]!['SB']?['A2o'] ?? 0, 1);
      expect(
        _width(kNashCall[10]!['SB>BB']),
        greaterThan(_width(kNashCall[10]!['BTN>BB'])),
      );
    });

    test('all weights are valid frequencies', () {
      var bad = 0;
      for (final s in kPushFoldStacks) {
        for (final t in [...kNashShove[s]!.values, ...kNashCall[s]!.values]) {
          for (final w in t.values) {
            if (!(w > 0 && w <= 1)) bad++;
          }
        }
      }
      expect(bad, 0);
    });

    test('500 generated push/fold puzzles coherent', () {
      final rng = Mulberry32(0xbeef);
      for (var i = 0; i < 500; i++) {
        final p = generatePushFold(rng: rng);
        expect(p.options.map((o) => o.action), contains(p.best));
        expect(p.accept, isNotEmpty);
        expect(p.accept, contains(p.best));
      }
    });
  });

  /* ------------------------------ unit ------------------------------ */

  group('helpers', () {
    test('jsNum formats like JavaScript template literals', () {
      expect(jsNum(1), '1');
      expect(jsNum(1.0), '1');
      expect(jsNum(0.5), '0.5');
      expect(jsNum(2.5), '2.5');
      expect(jsNum(4.6), '4.6');
      expect(jsNum(-0.0), '0');
      expect(jsNum(10.0), '10');
      expect(jsNum(7), '7');
    });

    test('pctOf / chartLabels05', () {
      expect(pctOf({'AA': 1.0, 'AKs': 0.5}), ((6 + 2) / 1326 * 100).round());
      expect(chartLabels05({'AA': 1.0, 'AKs': 0.5, '72o': 0.49}), [
        'AA',
        'AKs',
      ]);
      expect(chartLabels05(const {}), isEmpty);
      // insertion order, not strength order
      expect(chartLabels05({'72o': 0.6, 'AA': 1.0}), ['72o', 'AA']);
    });

    test('gradeFromFreq boundaries and copy', () {
      final clear = gradeFromFreq(
        1,
        'AA',
        10,
        DrillAction.raise,
        'shove',
        'C.',
      );
      expect(clear.best, DrillAction.raise);
      expect(clear.accept, [DrillAction.raise]);
      expect(
        clear.rationale,
        'C. AA is clearly inside the equilibrium shove range at 10 bb — shove.',
      );
      final never = gradeFromFreq(0, '72o', 8, DrillAction.call, 'call', 'C.');
      expect(never.best, DrillAction.fold);
      expect(never.accept, [DrillAction.fold]);
      expect(
        never.rationale,
        'C. 72o is outside the equilibrium call range at 8 bb — fold.',
      );
      final mixed = gradeFromFreq(
        0.35,
        'K9o',
        12,
        DrillAction.raise,
        'shove',
        'C.',
      );
      expect(mixed.best, DrillAction.fold);
      expect(mixed.accept, [DrillAction.fold, DrillAction.raise]);
      expect(
        mixed.rationale,
        'C. A true mixed spot: the equilibrium shoves K9o about 35% of the time here, so either answer is fine.',
      );
      // 0.2 / 0.8 are NOT mixed; 0.5 is aggressive; 0.97 is still "mixed" copy
      expect(gradeFromFreq(0.2, 'x', 5, DrillAction.raise, 's', 'c').accept, [
        DrillAction.fold,
      ]);
      expect(gradeFromFreq(0.8, 'x', 5, DrillAction.raise, 's', 'c').accept, [
        DrillAction.raise,
      ]);
      expect(
        gradeFromFreq(0.5, 'x', 5, DrillAction.raise, 's', 'c').best,
        DrillAction.raise,
      );
      expect(
        gradeFromFreq(0.97, 'x', 5, DrillAction.raise, 's', 'c').rationale,
        contains('A true mixed spot'),
      );
      expect(
        gradeFromFreq(0.98, 'x', 5, DrillAction.raise, 's', 'c').rationale,
        contains('clearly inside'),
      );
    });

    test('strengthSlice is deterministic, keeps >= 4 and appends a tail', () {
      final labels = chartLabels05(kVsRfi100['BB_vs_BTN']!['call']!);
      const board = ['Ah', '7d', '2c'];
      final a = strengthSlice(labels, board, 0.3, true);
      final b = strengthSlice(labels, board, 0.3, true);
      expect(a, b);
      final top = strengthSlice(labels, board, 0.3, false);
      expect(a.length, greaterThan(top.length));
      expect(a.sublist(0, top.length), top);
      expect(top.length, (labels.length * 0.3).round());
      expect(
        strengthSlice(labels.take(5).toList(), board, 0.1, false).length,
        4,
      );
      // A label fully blocked by the board is dropped (three aces leave no
      // AA combo: every combo holds a c/d/h ace).
      expect(strengthSlice(['AA'], ['Ah', 'Ad', '2c'], 1, false), ['AA']);
      expect(strengthSlice(['AA'], ['Ah', 'Ad', 'Ac'], 1, false), isEmpty);
    });

    test('jsObjectKeyOrder mimics JavaScript key enumeration', () {
      final m = jsObjectKeyOrder({
        'AA': 1.0,
        '99': 0.5,
        'K9o': 0.7,
        '22': 1.0,
        'TT': 1.0,
        '0': 2.0,
        '007': 3.0,
      });
      expect(m.keys.toList(), ['0', '22', '99', 'AA', 'K9o', 'TT', '007']);
      expect(m['99'], 0.5);
      // Merge semantics: an overwritten key keeps its slot, a new pair key
      // still jumps to the numeric block.
      final merged = jsObjectKeyOrder({
        ...{'AKs': 1.0, '77': 0.5},
        ...{'77': 1.0, '99': 1.0, 'A5s': 0.5},
      });
      expect(merged.keys.toList(), ['77', '99', 'AKs', 'A5s']);
      expect(merged['77'], 1.0);
    });

    test('gradePuzzle EV loss only for pot-odds spots', () {
      final p = puzzleFromLeak(
        _refLeakSpots[2],
      ); // equity 0.6, pot 1.5, toCall 0.75
      // evCall = 0.6 * 2.25 - 0.75 = 0.6 ; best call -> fold loses 0.6
      final g = gradePuzzle(p, DrillAction.fold);
      expect(g.correct, isFalse);
      expect(g.evLossBb, closeTo(0.6, 1e-12));
      expect(gradePuzzle(p, DrillAction.call).evLossBb, isNull);
      // raise has no EV model -> undefined
      expect(gradePuzzle(p, DrillAction.raise).evLossBb, isNull);
      // no equity -> undefined
      expect(
        gradePuzzle(
          puzzleFromLeak(_refLeakSpots[0]),
          DrillAction.call,
        ).evLossBb,
        isNull,
      );
      // toCall == 0 -> undefined even with equity
      expect(
        gradePuzzle(puzzleFromLeak(_refLeakSpots[1]), DrillAction.bet).evLossBb,
        isNull,
      );
    });

    test('ids increase and can be reset', () {
      resetPuzzleSeq(500);
      final a = generatePushFold(rng: Mulberry32(1));
      final b = generatePushFold(rng: Mulberry32(2));
      expect(a.id, 500);
      expect(b.id, 501);
      resetPuzzleSeq();
      expect(generatePushFold(rng: Mulberry32(3)).id, 1);
    });

    test('Puzzle JSON round-trips (review cards)', () {
      for (final seed in [1, 2, 3]) {
        for (final p in [
          generatePuzzle(rng: Mulberry32(seed)),
          generatePushFold(rng: Mulberry32(seed)),
          generateExploit(rng: Mulberry32(seed)),
        ]) {
          final j = p.toJson();
          final back = Puzzle.fromJson(
            (jsonDecode(jsonEncode(j)) as Map).cast<String, Object?>(),
          );
          expect(_diff(back.toJson(), j), isNull);
          expect(back.id, p.id);
          expect(back.holeCombo, (p.hole[0], p.hole[1]));
        }
      }
      for (final k in PuzzleKind.values) {
        expect(PuzzleKind.fromLabel(k.label), k);
      }
      expect(PuzzleKind.vsRaise.label, 'vs-raise');
      expect(PuzzleKind.riverDecision.label, 'river-decision');
      expect(PuzzleSource.fromLabel('heuristic'), PuzzleSource.heuristic);
    });

    test('reviewCardId matches reviewStore.ts', () {
      final p = puzzleFromLeak(_refLeakSpots[0]);
      expect(reviewCardId(p), 'leak|AKo|As7c2d|BTN');
      final pre = generatePushFold(rng: Mulberry32(4));
      expect(
        reviewCardId(pre),
        'pushfold|${pre.handLabel}||${pre.heroPos.label}',
      );
    });

    test('kDrillOrder / kStreetRangePct / stacks', () {
      expect(kDrillOrder.map((p) => p.label), [
        'UTG',
        'MP',
        'CO',
        'BTN',
        'SB',
        'BB',
      ]);
      expect(kStreetRangePct, {
        Street.flop: 45,
        Street.turn: 38,
        Street.river: 32,
      });
      expect(kPushFoldDrillStacks, [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
    });
  });

  group('drill-store helpers', () {
    test('adaptivePuzzle targets a difficulty band by rating', () {
      final low = Mulberry32(11);
      for (var i = 0; i < 12; i++) {
        expect(
          adaptivePuzzle(900, rng: low).difficulty,
          inInclusiveRange(1, 2),
        );
      }
      final high = Mulberry32(12);
      for (var i = 0; i < 12; i++) {
        expect(
          adaptivePuzzle(1500, rng: high).difficulty,
          inInclusiveRange(2, 3),
        );
      }
      final mid = Mulberry32(13);
      for (var i = 0; i < 12; i++) {
        expect(
          adaptivePuzzle(1100, rng: mid).difficulty,
          inInclusiveRange(1, 3),
        );
      }
    });

    test('generatePuzzleOfKind ("Drill similar")', () {
      final rng = Mulberry32(21);
      for (final k in [
        PuzzleKind.rfi,
        PuzzleKind.vsRaise,
        PuzzleKind.postflopBet,
        PuzzleKind.postflopCheck,
        PuzzleKind.threebetPot,
        PuzzleKind.checkRaise,
        PuzzleKind.riverDecision,
      ]) {
        expect(generatePuzzleOfKind(k, rng: rng).kind, k);
      }
    });

    test('exploit templates are the three desktop spots', () {
      final seen = <String>{};
      final rng = Mulberry32(5);
      for (var i = 0; i < 24; i++) {
        final p = generateExploit(rng: rng);
        expect(p.kind, PuzzleKind.exploit);
        expect(p.icm, isFalse);
        expect(p.lessonId, 'exploits');
        seen.add(p.gradeRangeTitle!);
        if (p.street == Street.river) {
          expect(p.best, DrillAction.bet);
          expect(p.equity, inInclusiveRange(0.56, 0.75));
        } else if (p.street == Street.turn) {
          expect(p.best, DrillAction.fold);
          expect(p.equity, lessThanOrEqualTo(0.38));
          expect(p.potOdds, closeTo(10 / 26, 1e-12));
        } else {
          expect(p.street, Street.preflop);
          expect(p.best, DrillAction.raise);
          expect(p.gradeRange!.length, 169);
        }
      }
      expect(seen, {
        'What a Station calls a river bet with (~60%)',
        'What a Nit raises the turn with (~4%)',
        "The exploit raise-range vs a Nit's blind: any two",
      });
    });

    test('ICM push/fold uses the bundled scenarios', () {
      final rng = Mulberry32(9);
      var icm = 0;
      for (var i = 0; i < 60 && icm < 6; i++) {
        final p = generatePushFold(rng: rng);
        if (p.icm != true) continue;
        icm++;
        final sc = kIcmScenarios.firstWhere(
          (s) => p.gradeRangeTitle!.endsWith('— ${s.name}'),
        );
        expect(p.frames[1].text, sc.blurb);
        expect(p.rationale, contains(r'(ICM, $EV)'));
        expect(
          p.rationale,
          contains('Bubble: 4 players left, 3 get paid (50/30/20).'),
        );
        if (p.heroPos == Position.sb) {
          expect(p.options[1].amount, sc.stacks[0]);
          expect(p.gradeRange, chartLabels05(sc.jam));
        } else {
          expect(p.heroPos, Position.bb);
          expect(p.gradeRange, chartLabels05(sc.call));
        }
      }
      expect(icm, 6);
    });
  });

  test('a 3000-trial flop drill generates in under 400 ms', () {
    // Warm up the JIT, then time the heaviest generator family.
    generatePuzzleOfKind(PuzzleKind.postflopBet, rng: Mulberry32(1));
    final sw = Stopwatch()..start();
    final rng = Mulberry32(2);
    for (var i = 0; i < 5; i++) {
      generatePuzzleOfKind(PuzzleKind.threebetPot, rng: rng);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds / 5, lessThan(400));
  });
}
