// Port of scripts/hhimport_test.ts plus exact pins against the desktop
// parser/analyzer (see hh_import_ref.dart for how the references were made).
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/hh_import.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';

import 'hh_import_ref.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// JSON-decoded view of a Dart object, with integral doubles folded to ints
/// (JS has one number type, so `99` and `99.0` serialise the same there).
Object? norm(Object? v) {
  if (v is Map) {
    // JSON.stringify drops undefined members; Dart toJson writes null.
    return {
      for (final e in v.entries)
        if (e.value != null) e.key.toString(): norm(e.value),
    };
  }
  if (v is List) return v.map(norm).toList();
  if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
  return v;
}

Object? decodeRef(String json, [int? startedAt]) =>
    norm(jsonDecode(json.replaceFirst('@@', '$startedAt')));

const deepEq = DeepCollectionEquality();

/// analyzeImported with startedAt pinned like the reference run.
ImportAnalysis analyzeFixed(List<ImportedHand> hands) {
  for (var i = 0; i < hands.length; i++) {
    hands[i].startedAt = 1781000000000 + i * 1000;
  }
  return analyzeImported(hands, now: 1);
}

List<Object?> leaksJson(ImportAnalysis a) => [
  for (final l in a.leaks)
    norm(
      l.toJson()
        ..remove('ts')
        ..remove('srs'),
    ),
];

void expectAnalysis(ImportAnalysis a, String key) {
  final ref = kRefAnalysis[key]!;
  expect(a.reviewed, ref.reviewed, reason: '$key reviewed');
  expect(a.leaks.length, ref.leaks.length, reason: '$key leak count');
  final got = leaksJson(a);
  for (var i = 0; i < ref.leaks.length; i++) {
    final want = norm(jsonDecode(ref.leaks[i]));
    expect(
      deepEq.equals(got[i], want),
      isTrue,
      reason:
          '$key leak $i\n got: ${jsonEncode(got[i])}\nwant: ${ref.leaks[i]}',
    );
  }
}

HHHand roundTripHand() => HHHand(
  id: 7,
  startedAt: DateTime(2026, 6, 19, 12, 0, 0).millisecondsSinceEpoch,
  button: 0,
  sb: 10,
  bb: 20,
  sbSeat: 1,
  bbSeat: 2,
  seats: const [
    HHSeat(
      seat: 0,
      name: 'You',
      stack: 2000,
      isHero: true,
      position: Position.btn,
    ),
    HHSeat(
      seat: 1,
      name: 'Ivey',
      stack: 2000,
      isHero: false,
      position: Position.sb,
    ),
    HHSeat(
      seat: 2,
      name: 'Polk',
      stack: 2000,
      isHero: false,
      position: Position.bb,
    ),
    HHSeat(
      seat: 3,
      name: 'Dwan',
      stack: 2000,
      isHero: false,
      position: Position.utg,
    ),
    HHSeat(
      seat: 4,
      name: 'Selbst',
      stack: 2000,
      isHero: false,
      position: Position.mp,
    ),
    HHSeat(
      seat: 5,
      name: 'Galfond',
      stack: 2000,
      isHero: false,
      position: Position.co,
    ),
  ],
  holes: {
    0: ['As', 'Ks'],
    3: ['Qh', 'Qd'],
  },
  actions: const [
    HHAction(
      street: Street.preflop,
      seat: 4,
      name: 'Selbst',
      type: ActionType.fold,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 5,
      name: 'Galfond',
      type: ActionType.fold,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 3,
      name: 'Dwan',
      type: ActionType.raise,
      amount: 60,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 0,
      name: 'You',
      type: ActionType.call,
      amount: 60,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 1,
      name: 'Ivey',
      type: ActionType.fold,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.preflop,
      seat: 2,
      name: 'Polk',
      type: ActionType.fold,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 3,
      name: 'Dwan',
      type: ActionType.bet,
      amount: 80,
      allIn: false,
    ),
    HHAction(
      street: Street.flop,
      seat: 0,
      name: 'You',
      type: ActionType.call,
      amount: 80,
      allIn: false,
    ),
    HHAction(
      street: Street.turn,
      seat: 3,
      name: 'Dwan',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.turn,
      seat: 0,
      name: 'You',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.river,
      seat: 3,
      name: 'Dwan',
      type: ActionType.check,
      amount: 0,
      allIn: false,
    ),
    HHAction(
      street: Street.river,
      seat: 0,
      name: 'You',
      type: ActionType.bet,
      amount: 120,
      allIn: false,
    ),
    HHAction(
      street: Street.river,
      seat: 3,
      name: 'Dwan',
      type: ActionType.call,
      amount: 120,
      allIn: false,
    ),
  ],
  board: const ['Ah', 'Kd', '7c', '2s', '9h'],
  potResults: const [
    PotResult(winners: [0], amount: 520, potLabel: 'Pot'),
  ],
  heroNet: 260,
);

void main() {
  group('round-trip against our own exporter', () {
    final hand = roundTripHand();
    final text = formatHand(hand);

    test('formatHand matches the desktop text', () {
      // The export id embeds the local-time startedAt; everything else is
      // byte-identical to the desktop output.
      final expected = kRefRoundTripText.replaceFirst(
        RegExp(r'Hand #\d+:'),
        'Hand #${exportHandId(hand)}:',
      );
      expect(text, expected);
    });

    test('parses back (scripts/hhimport_test.ts assertions)', () {
      final r = parsePokerStars(text);
      expect(r.hands.length, 1);
      expect(r.skipped, 0);
      final h = r.hands[0];
      expect(h.sb, 10);
      expect(h.bb, 20);
      expect(h.seats.length, 6);
      expect(h.heroName, 'You');
      expect(h.seats.firstWhere((s) => s.isHero).name, 'You');
      expect(h.holes[0]!.join(), 'AsKs');
      expect(h.holes[3]!.join(), 'QhQd');
      expect(h.board.join(), 'AhKd7c2s9h');
      expect(h.actions.where((a) => a.type == ActionType.fold).length, 4);
      expect(
        h.actions.any((a) => a.type == ActionType.raise && a.amount == 60),
        isTrue,
      );
      expect(
        h.potResults.any((p) => p.winners.contains(0) && p.amount > 0),
        isTrue,
      );
      expect(h.imported, isTrue);
      expect(h.id, 7);
      expect(h.startedAt, hand.startedAt);
      expect(h.button, 0);
      expect(h.sbSeat, 1);
      expect(h.bbSeat, 2);
      expect(h.heroNet, 520);
    });

    test('parsed JSON is byte-identical to the desktop', () {
      final h = parsePokerStars(text).hands[0];
      final want = kRefRoundTripJson.replaceFirst('@@', '${hand.startedAt}');
      expect(jsonEncode(h.toJson()), want);
    });

    test('ImportedHand JSON round-trips through fromJson', () {
      final h = parsePokerStars(text).hands[0];
      final json = jsonEncode(h.toJson());
      final back = ImportedHand.fromJson(
        (jsonDecode(json) as Map).cast<String, Object?>(),
      );
      expect(jsonEncode(back.toJson()), json);
      expect(back.heroName, 'You');
      expect(back.imported, isTrue);
      expect(back, isA<HHHand>());
    });

    test('exporting the imported hand again reproduces the text', () {
      final h = parsePokerStars(text).hands[0];
      expect(formatHand(h), text);
    });

    test('analyzer reviews both hero calls and flags nothing (AKs)', () {
      final hands = parsePokerStars(text).hands;
      expectAnalysis(analyzeFixed(hands), 'roundTrip');
    });
  });

  group('genuine PokerStars fixture (\$ amounts, real-site quirks)', () {
    final real = parsePokerStars(fixture('hh_import_real_ps.txt'));

    test('parses with the TS assertions', () {
      expect(real.hands.length, 1);
      expect(real.skipped, 0);
      final rh = real.hands[0];
      expect(rh.sb, 0.05);
      expect(rh.bb, 0.1);
      expect(rh.heroName, 'hero_name');
      expect(rh.holes[2]!.join(), 'JhJc');
      expect(rh.holes[0]!.join(), 'QdTh');
      expect(rh.board.length, 5);
      expect(rh.potResults.any((p) => p.amount == 4.53), isTrue);
      // Best-effort: positions come from the button offset only, so the
      // posted blinds in the file do not override them (desktop behaviour).
      expect(rh.seats.map((s) => s.position.label), ['SB', 'BTN', 'BB']);
      expect(rh.seats.map((s) => s.stack), [10, 12.35, 9.4]);
      expect(rh.actions.length, 10);
      expect(rh.actions.last.type, ActionType.call);
      expect(rh.actions.last.amount, 1.55);
      expect(rh.heroNet, 0);
      expect(rh.id, 799999);
    });

    test('parsed JSON is byte-identical to the desktop', () {
      final startedAt = DateTime(2024, 3, 7, 21, 14, 11).millisecondsSinceEpoch;
      expect(real.hands[0].startedAt, startedAt);
      expect(
        jsonEncode(real.hands[0].toJson()),
        kRefRealJson.replaceFirst('@@', '$startedAt'),
      );
    });

    test('reasonable calls are not flagged (conservative analyzer)', () {
      final a = analyzeFixed(
        parsePokerStars(fixture('hh_import_real_ps.txt')).hands,
      );
      expect(a.leaks, isEmpty);
      expectAnalysis(a, 'real');
    });
  });

  group('analyzer: hopeless call', () {
    test('bad-call hand parses and pins the desktop JSON', () {
      final parsed = parsePokerStars(fixture('hh_import_bad_call.txt'));
      expect(parsed.hands.length, 1);
      final startedAt = DateTime(2026, 6, 19, 12, 0, 0).millisecondsSinceEpoch;
      expect(
        jsonEncode(parsed.hands[0].toJson()),
        kRefBadJson.replaceFirst('@@', '$startedAt'),
      );
    });

    test('100bb call with 72o is flagged for Review', () {
      final parsed = parsePokerStars(fixture('hh_import_bad_call.txt'));
      final a = analyzeFixed(parsed.hands);
      expect(a.reviewed, greaterThanOrEqualTo(1));
      expect(a.leaks.length, 1);
      final l = a.leaks[0];
      expect(l.best, DrillAction.fold);
      expect(l.id, 'imp-1781000000000-preflop');
      expect(l.street, Street.preflop);
      expect(l.heroPos, Position.btn);
      expect(l.hole, ['7h', '2c']);
      expect(l.board, isEmpty);
      expect(l.pot, 101);
      expect(l.toCall, 99);
      expect(l.bb, 1);
      expect(l.oppActive, [Position.bb]);
      expect(l.options.map((o) => o.label), ['Fold', 'Call 99.0 bb']);
      expect(l.options[1].amount, 99);
      expect(l.equity, 0.3584);
      expect(l.potOdds, 0.495);
      expect(l.ts, 1);
      expect(
        l.rationale,
        'Imported hand: you called 99.0 bb needing 50% but 72o wins only ~36% even against a random hand — real ranges make it worse.',
      );
      expectAnalysis(a, 'bad');
    });

    test('ts defaults to the wall clock', () {
      final parsed = parsePokerStars(fixture('hh_import_bad_call.txt'));
      final before = DateTime.now().millisecondsSinceEpoch;
      final a = analyzeImported(parsed.hands);
      expect(a.leaks[0].ts, greaterThanOrEqualTo(before));
    });

    test('seeds use the desktop string shape (street label, JS number)', () {
      expect(hashSeed('imp|1781000000000|preflop|1980'), kRefSeeds['bad']);
      expect(hashSeed('imp|1781000000000|river|1.55'), kRefSeeds['real']);
      expect(hashSeed('imp|1781000000000|flop|500'), kRefSeeds['multiFlop']);
    });
  });

  group('multi-hand file with streets, all-ins and junk blocks', () {
    final multi = parsePokerStars(fixture('hh_import_multistreet.txt'));

    test('two hands parse, the broken header is skipped', () {
      expect(multi.hands.length, 2);
      expect(multi.skipped, kRefMultiSkipped);
      final starts = [
        DateTime(2026, 6, 19, 12, 5, 0).millisecondsSinceEpoch,
        DateTime(2026, 6, 19, 12, 6, 0).millisecondsSinceEpoch,
      ];
      for (var i = 0; i < 2; i++) {
        expect(multi.hands[i].startedAt, starts[i]);
        expect(
          jsonEncode(multi.hands[i].toJson()),
          kRefMultiJson[i].replaceFirst('@@', '${starts[i]}'),
          reason: 'hand $i',
        );
      }
      // all-in suffixes
      final h2 = multi.hands[1];
      expect(h2.actions.map((a) => a.allIn), [false, true, true]);
      expect(h2.holes[1]!.join(), 'AhAd');
      expect(h2.holes[3]!.join(), 'KcQc');
      expect(h2.heroNet, 4000);
      expect(h2.potResults.length, 1);
      expect(h2.potResults[0].amount, 4000);
    });

    test('flop and turn calls flagged, river (exact) and preflop not', () {
      final a = analyzeFixed(multi.hands);
      expect(a.reviewed, 5);
      expect(a.leaks.map((l) => l.id), [
        'imp-1781000000000-flop',
        'imp-1781000000000-turn',
      ]);
      expect(a.leaks[0].pot, 31.5);
      expect(a.leaks[0].toCall, 25);
      expect(a.leaks[0].board, ['As', 'Ks', 'Qs']);
      expect(a.leaks[1].board, ['As', 'Ks', 'Qs', 'Js']);
      expect(a.leaks[1].potOdds, closeTo(0.3194888178913738, 1e-15));
      expectAnalysis(a, 'multi');
    });

    test('hands without a hero hole are skipped by the analyzer', () {
      final h = multi.hands[0];
      h.holes.remove(2);
      final a = analyzeImported([h], now: 1);
      expect(a.reviewed, 0);
      expect(a.leaks, isEmpty);
    });
  });

  group('edge cases', () {
    test('empty text', () {
      final r = parsePokerStars('');
      expect(r.hands, isEmpty);
      expect(r.skipped, 0);
    });

    test('text without a PokerStars header yields nothing', () {
      final r = parsePokerStars('hello\n\nworld');
      expect(r.hands, isEmpty);
      expect(r.skipped, 0);
    });

    test('fewer than two seats is skipped', () {
      final r = parsePokerStars(
        "PokerStars Hand #1: Hold'em No Limit (1/2) - 2026/01/01 00:00:00 ET\nSeat 1: a (100 in chips)",
      );
      expect(r.hands, isEmpty);
      expect(r.skipped, 1);
    });

    test('CRLF input parses identically', () {
      final text = fixture('hh_import_bad_call.txt').replaceAll('\n', '\r\n');
      final r = parsePokerStars(text);
      expect(r.hands.length, 1);
      final startedAt = DateTime(2026, 6, 19, 12, 0, 0).millisecondsSinceEpoch;
      expect(
        jsonEncode(r.hands[0].toJson()),
        kRefCrlfJson.replaceFirst('@@', '$startedAt'),
      );
    });

    test('header without a date uses `now`; blinds fall back to button+1/+2', () {
      final r = parsePokerStars(
        "PokerStars Hand #77: Hold'em No Limit (1/2) \nTable 'X' Seat #2 is the button\nSeat 1: a (100 in chips)\nSeat 2: b (200 in chips)\nSeat 3: c (300 in chips)\n",
        now: 123456,
      );
      expect(r.hands.length, 1);
      final h = r.hands[0];
      expect(h.startedAt, 123456);
      expect(h.sbSeat, 2);
      expect(h.bbSeat, 0);
      expect(h.heroName, isNull);
      expect(h.holes, isEmpty);
      expect(
        jsonEncode(h.toJson()),
        kRefNoDateJson.replaceFirst('@@', '123456'),
      );
    });

    test('negative button offset falls back to MP like the desktop', () {
      final r = parsePokerStars(
        "PokerStars Hand #9: Hold'em No Limit (1/2) - 2026/01/01 00:00:00 ET\nTable 'X' Seat #9 is the button\nSeat 1: a (100 in chips)\nSeat 2: b (100 in chips)\nSeat 9: c (100 in chips)\n",
      );
      expect(
        r.hands[0].seats.map((s) => '${s.seat}:${s.position.label}'),
        kRefNegOffPositions,
      );
    });

    test('ten seats clamp onto the nine-entry position table', () {
      final seats = [
        for (var i = 1; i <= 10; i++) 'Seat $i: p$i (100 in chips)',
      ].join('\n');
      final r = parsePokerStars(
        "PokerStars Hand #10: Hold'em No Limit (1/2) - 2026/01/01 00:00:00 ET\nTable 'X' Seat #1 is the button\n$seats",
      );
      expect(
        r.hands[0].seats.map((s) => '${s.seat}:${s.position.label}'),
        kRefTenSeatPositions,
      );
    });

    test('comma-separated dollar amounts and fractional stacks', () {
      final r = parsePokerStars(
        "PokerStars Hand #9: Hold'em No Limit (\$1,000/\$2,000) - 2026/01/01 00:00:00 ET\nTable 'X' Seat #1 is the button\nSeat 1: a (\$1,234.50 in chips)\nSeat 2: b (\$100 in chips)\na: posts small blind \$1,000\nb: posts big blind \$2,000\nDealt to a [Ah Kh]\na: raises \$2,000 to \$4,000\nb: calls \$2,000 and is all-in\n",
      );
      final h = r.hands[0];
      expect(h.sb, 1000);
      expect(h.bb, 2000);
      expect(h.seats[0].stack, 1234.5);
      expect(h.actions[0].amount, 4000);
      expect(h.actions[1].allIn, isTrue);
      final startedAt = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      expect(
        jsonEncode(h.toJson()),
        kRefCommaAmountsJson.replaceFirst('@@', '$startedAt'),
      );
    });

    test('hand id keeps the last six digits of the site id', () {
      String hand(String id) =>
          "PokerStars Hand #$id: Hold'em No Limit (1/2) - 2026/01/01 00:00:00 ET\nSeat 1: a (100 in chips)\nSeat 2: b (100 in chips)";
      expect(parsePokerStars(hand('241537799999')).hands[0].id, kRefBigId);
      expect(parsePokerStars(hand('42')).hands[0].id, kRefSmallId);
    });

    test('actions by unknown players are ignored', () {
      final r = parsePokerStars(
        "PokerStars Hand #1: Hold'em No Limit (1/2) - 2026/01/01 00:00:00 ET\nSeat 1: a (100 in chips)\nSeat 2: b (100 in chips)\nghost: raises 2 to 4\na: calls 4\nDealt to ghost [Ah Kh]\n",
      );
      final h = r.hands[0];
      expect(h.actions.map((a) => a.name), ['a']);
      expect(h.heroName, isNull);
    });
  });

  group('import-result copy (desktop StatsView, verbatim)', () {
    test('empty file messages', () {
      expect(
        importEmptyText(0),
        "Couldn't find any PokerStars-style hands in that file.",
      );
      expect(
        importEmptyText(2),
        "Couldn't find any PokerStars-style hands in that file (2 blocks unparseable).",
      );
    });

    test('summary messages', () {
      expect(
        importSummaryText(hands: 1, skipped: 0, reviewed: 3, leaks: 0),
        'Imported 1 hand · reviewed 3 of your calls · no clear mistakes found. Imported hands never count toward your play stats.',
      );
      expect(
        importSummaryText(hands: 12, skipped: 2, reviewed: 30, leaks: 1),
        'Imported 12 hands (2 skipped) · reviewed 30 of your calls · 1 questionable one added to the Review queue. Imported hands never count toward your play stats.',
      );
      expect(
        importSummaryText(hands: 2, skipped: 0, reviewed: 4, leaks: 3),
        'Imported 2 hands · reviewed 4 of your calls · 3 questionable ones added to the Review queue. Imported hands never count toward your play stats.',
      );
    });
  });
}
