import 'dart:convert';
import 'dart:math';

import 'package:allin/data/preflop_charts.g.dart';
import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/cards.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot_brain_ref.dart';

/* ------------------------------------------------------------------
   Reference decisions in bot_brain_ref.dart were produced by driving the
   desktop botBrain.ts under Node 23 with `Math.random = () => r` (so the
   single `rnd` draw and every "fresh" draw of a decision return the same
   constant) on scripted states: 6-max, blinds 10/20, button on seat 0
   (seats: 0 BTN, 1 SB, 2 BB, 3 UTG, 4 MP, 5 CO), a fixed deck and fixed
   hole cards. The river scenarios only ever run exact equity (no RNG), so
   the Dart port must reproduce them bit-for-bit; narrowRange on the
   flop/turn uses the seeded generator and is pinned exactly as well.
   ------------------------------------------------------------------ */

const GameConfig _cfg = GameConfig(
  seats: 6,
  startingStack: 2000,
  smallBlind: 10,
  bigBlind: 20,
);

/// Cards come off the END: burn Qc, flop Kc 8d 3h, burn Js, turn 2s,
/// burn Th, river 9c.
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

/// `Math.random = () => v`.
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

TableState _setup(
  Map<int, Archetype> archs, [
  Map<int, List<Card>> holes = const {},
]) {
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

TableState _fold(TableState s, List<int> seats) {
  for (final q in seats) {
    s = applyAction(s, q, const Action.fold());
  }
  return s;
}

/// Preflop: UTG/MP/CO fold, hero (BTN) opens 50, SB folds, BB calls; flop
/// and turn check through; optionally BB checks the river and hero bets.
TableState _toRiver(Archetype arch, List<Card> hole, [int heroBets = 0]) {
  var s = _setup({2: arch}, {2: hole});
  s = _fold(s, [3, 4, 5]);
  s = applyAction(s, 0, const Action.raise(50));
  s = applyAction(s, 1, const Action.fold());
  s = applyAction(s, 2, const Action.call(amount: 30));
  for (int i = 0; i < 2; i++) {
    s = applyAction(s, 2, const Action.check());
    s = applyAction(s, 0, const Action.check());
  }
  if (heroBets > 0) {
    s = applyAction(s, 2, const Action.check());
    s = applyAction(s, 0, Action.bet(heroBets));
  }
  return s;
}

late final Map<String, dynamic> _ref =
    jsonDecode(kBotBrainRefJson) as Map<String, dynamic>;
Map<String, dynamic> _refPre(String k) =>
    (_ref['preflop'] as Map<String, dynamic>)[k] as Map<String, dynamic>;
Map<String, dynamic> _refRiver(String k) =>
    (_ref['river'] as Map<String, dynamic>)[k] as Map<String, dynamic>;
List<String> _refNarrow(String k) =>
    ((_ref['narrow'] as Map<String, dynamic>)[k] as List).cast<String>();
List<String> _refChart(String k) =>
    ((_ref['charts'] as Map<String, dynamic>)[k] as List).cast<String>();

void _expectDecision(BotDecision d, Map<String, dynamic> ref, String name) {
  final a = ref['action'] as Map<String, dynamic>;
  expect(d.action.type.label, a['type'], reason: '$name action type');
  expect(d.action.amount, a['amount'], reason: '$name action amount');
  final range = ref['range'];
  if (range == null) {
    expect(d.range, isNull, reason: '$name range');
  } else {
    expect(d.range, (range as List).cast<String>(), reason: '$name range');
  }
}

/// Decide for [seat] with `Math.random() == r`, then check against the
/// reference entry [name].
void _pinPre(TableState s, int seat, double r, String name) {
  final ref = _refPre(name);
  expect(s.street.label, ref['street']);
  expect(s.players[seat].position.label, ref['pos'], reason: '$name position');
  expect(s.pot, ref['pot'], reason: '$name pot');
  expect(s.currentBet, ref['currentBet'], reason: '$name currentBet');
  _expectDecision(decideBot(s, seat, rng: _FixedRandom(r)), ref, name);
}

void _pinRiver(TableState s, double r, String name) {
  final ref = _refRiver(name);
  expect(s.street, Street.river, reason: name);
  expect(s.board, (ref['board'] as List).cast<String>(), reason: name);
  expect(s.pot, ref['pot'], reason: '$name pot');
  expect(s.currentBet, ref['currentBet'], reason: '$name currentBet');
  _expectDecision(decideBot(s, 2, rng: _FixedRandom(r)), ref, name);
}

List<HandLabel> _bbVsBtnCall025() =>
    chartLabels(kVsRfi100['BB_vs_BTN']!['call']!, 0.25);

void main() {
  group('constants', () {
    test('DIALS and PREMIUM match the desktop', () {
      expect(kDials[Archetype.tag]!.open, 1.0);
      expect(kDials[Archetype.lag]!.threebet, 1.6);
      expect(kDials[Archetype.lag]!.limpWide, isTrue);
      expect(kDials[Archetype.nit]!.call, 0.8);
      expect(kDials[Archetype.station]!.open, 0.45);
      expect(kDials[Archetype.station]!.limpWide, isTrue);
      expect(kDials[Archetype.tag]!.limpWide, isFalse);
      expect(kPremiumList, ['AA', 'KK', 'QQ', 'AKs', 'AKo']);
      expect(kPremium, kPremiumList.toSet());
    });
  });

  group('chartLabels', () {
    test('keeps chart key order and the >= threshold (desktop reference)', () {
      expect(chartLabels(kRfi100['UTG']!, 0.4), _refChart('utg_040'));
      expect(chartLabels(kRfi100['UTG']!, 0.01), _refChart('utg_001'));
      expect(chartLabels(kRfi100['BTN']!, 0.4), _refChart('btn_040'));
      expect(
        chartLabels(kVsRfi100['BB_vs_SB']!['threebet']!, 0.25),
        _refChart('bbsb_3b_025'),
      );
      expect(
        chartLabels(kVsRfi100['BB_vs_SB']!['threebet']!, 0.5),
        _refChart('bbsb_3b_050'),
      );
      expect(
        chartLabels(kVsRfi100['MP_vs_UTG']!['call']!, 0.25),
        _refChart('mpvutg_call_025'),
      );
      // 0.5-frequency hands are included at min 0.5, excluded at 0.51.
      expect(chartLabels(kRfi100['UTG']!, 0.5), contains('A5s'));
      expect(chartLabels(kRfi100['UTG']!, 0.51), isNot(contains('A5s')));
      expect(chartLabels(const {}, 0.25), isEmpty);
    });
  });

  group('boardTexture / drawStrength', () {
    test('match the desktop for the reference boards', () {
      for (final t in (_ref['texture'] as List).cast<Map<String, dynamic>>()) {
        final board = (t['board'] as List).cast<String>();
        final tex = boardTexture(board.map(cardToInt).toList());
        expect(tex.wet, t['wet'], reason: 'wet $board');
        expect(tex.paired, t['paired'], reason: 'paired $board');
        expect(tex.highCard, t['highCard'], reason: 'highCard $board');
      }
      final draws = (_ref['draw'] as List).cast<Map<String, dynamic>>();
      expect(draws.length, greaterThan(100));
      for (final t in draws) {
        final board = (t['board'] as List).cast<String>();
        final hole = (t['hole'] as List).cast<String>();
        expect(
          drawStrength(
            [cardToInt(hole[0]), cardToInt(hole[1])],
            board.map(cardToInt).toList(),
          ),
          t['draw'],
          reason: 'draw $hole on $board',
        );
      }
    });

    test('documented quirks', () {
      List<int> ints(List<String> c) => c.map(cardToInt).toList();
      // Empty board: nothing wet, highCard 0.
      expect(boardTexture([]).wet, isFalse);
      expect(boardTexture([]).highCard, 0);
      // Ace counts low for connectivity: A23 is straighty.
      expect(boardTexture(ints(['Ah', '2d', '3c'])).wet, isTrue);
      // Monotone flop is flushy; a two-tone flop is not.
      expect(boardTexture(ints(['Qd', 'Jd', '9d'])).wet, isTrue);
      expect(boardTexture(ints(['Kc', '8d', '3h'])).wet, isFalse);
      // River: no draws at all.
      expect(drawStrength(ints(['As', 'Ks']), ints(['Qs', 'Js', '2s', '3d', '4h'])), 0);
      // A made straight still reads as a strong draw on the flop (as desktop).
      expect(drawStrength(ints(['Jh', 'Th']), ints(['Qd', '9c', '8s'])), 2);
      // Board-only run counts as an OESD for the holder.
      expect(drawStrength(ints(['As', 'Ks']), ints(['5c', '6d', '7h', '8s'])), 2);
      // Flush draw needs one of the hole cards in the suit.
      expect(drawStrength(ints(['As', '2s']), ints(['Ks', 'Qs', '3d'])), 2);
      expect(drawStrength(ints(['Ah', '2d']), ints(['Ks', 'Qs', '3s', '4s'])), 0);
      // Backdoor flush draw on the flop is weak (1); on the turn it is not.
      expect(drawStrength(ints(['As', '7d']), ints(['Ks', 'Qs', '3d'])), 1);
      expect(drawStrength(ints(['As', '7d']), ints(['Ks', 'Qs', '3d', '4h'])), 0);
      // Gutshot is weak.
      expect(drawStrength(ints(['Ah', 'Kd']), ints(['Qc', 'Js', '2h'])), 1);
    });
  });

  group('narrowRange', () {
    final stored = chartLabels(kRfi100['BTN']!, 0.4);

    test('reference stored range', () {
      expect(stored, _refNarrow('stored'));
      expect(stored.length, 97);
    });

    for (final board in const {
      'flop': ['Kc', '8d', '3h'],
      'turn': ['Kc', '8d', '3h', '2s'],
      'river': ['Kc', '8d', '3h', '2s', '9c'],
      'wetFlop': ['Qd', 'Jd', '9d'],
    }.entries) {
      for (final kind in NarrowKind.values) {
        test('${board.key} ${kind.name} matches the desktop exactly', () {
          for (final actual in ['KK', '72o']) {
            final key = '${board.key}_${kind.name}_$actual';
            final got = narrowRange(stored, board.value, kind, actual);
            expect(got, _refNarrow(key), reason: key);
            expect(got.length, lessThan(stored.length), reason: key);
            if (actual == 'KK') expect(got, contains('KK'));
            if (actual == '72o') expect(got, isNot(contains('72o')));
          }
        });
      }
    }

    test('small ranges pass through (same list) or gain the actual label', () {
      final small = ['AA', 'KK', 'QQ'];
      expect(
        identical(narrowRange(small, ['Kc', '8d', '3h'], NarrowKind.aggro, 'KK'), small),
        isTrue,
      );
      expect(
        narrowRange(small, ['Kc', '8d', '3h'], NarrowKind.aggro, 'KK'),
        _refNarrow('small_in'),
      );
      expect(
        narrowRange(small, ['Kc', '8d', '3h'], NarrowKind.aggro, '72o'),
        _refNarrow('small_add'),
      );
      expect(_refNarrow('small_add'), ['AA', 'KK', 'QQ', '72o']);
    });

    test('labels fully blocked by the board are dropped', () {
      final got = narrowRange(
        ['AA', 'KK', 'QQ', 'JJ', 'TT', '99', '88', '77', '66', '55'],
        ['Kc', 'Kd', 'Kh', 'Ks', '2c'],
        NarrowKind.call,
        'KK',
      );
      expect(got, _refNarrow('blocked'));
      expect(got, isNot(contains('KK')));
      expect(got.length, 7);
    });
  });

  group('decideBot preflop (desktop reference, Math.random pinned)', () {
    test('no archetype or no hole cards folds with an empty range', () {
      final s = _setup({});
      s.players[3].archetype = null;
      final d = decideBot(s, 3, rng: _FixedRandom(0));
      expect(d.action.type, ActionType.fold);
      expect(d.range, isEmpty);
      final s2 = _setup({3: Archetype.tag});
      s2.players[3].hole = null;
      expect(decideBot(s2, 3, rng: _FixedRandom(0)).action.type, ActionType.fold);
    });

    test('RFI: premiums always open, 2.5bb sizing', () {
      _pinPre(_setup({3: Archetype.tag}), 3, 0.99, 'P1_tag_utg_AA_099');
      _pinPre(
        _setup({3: Archetype.tag}, {3: ['Ac', 'Ad']}),
        3,
        0.99,
        'P1b_tag_utg_AA_099',
      );
    });

    test('RFI: Nit trims mixed opens (98s UTG = 0.5 * 0.35)', () {
      final s = _setup({3: Archetype.nit}, {3: ['9c', '8c']});
      _pinPre(s, 3, 0.30, 'P2_nit_utg_98s_030');
      _pinPre(s, 3, 0.10, 'P2b_nit_utg_98s_010');
    });

    test('RFI: Station limps playable hands, LAG rounds opens up', () {
      _pinPre(
        _setup({3: Archetype.station}, {3: ['9c', '8c']}),
        3,
        0.50,
        'P3_station_utg_98s_050',
      );
      final lag = _setup({3: Archetype.lag}, {3: ['9c', '8c']});
      _pinPre(lag, 3, 0.85, 'P4_lag_utg_98s_085');
      _pinPre(lag, 3, 0.95, 'P4b_lag_utg_98s_095');
    });

    test('RFI: junk never limps, even for loose types', () {
      _pinPre(_setup({3: Archetype.nit}, {3: ['7c', '2d']}), 3, 0.0, 'P_nit_utg_72o');
      _pinPre(
        _setup({3: Archetype.station}, {3: ['7c', '2d']}),
        3,
        0.0,
        'P_station_utg_72o',
      );
    });

    test('vs RFI: call / 3-bet / fold by chart frequency and archetype', () {
      var s = _setup({4: Archetype.tag}, {4: ['Ac', 'Qc']});
      s = applyAction(s, 3, const Action.raise(50));
      _pinPre(s, 4, 0.5, 'P5_tag_mp_AQs_vs_utg_050');

      var lag = _setup({4: Archetype.lag}, {4: ['Ac', '5c']});
      lag = applyAction(lag, 3, const Action.raise(50));
      _pinPre(lag, 4, 0.7, 'P5b_lag_mp_A5s_vs_utg_070');
      _pinPre(lag, 4, 0.9, 'P5c_lag_mp_A5s_vs_utg_090');

      var nit = _setup({4: Archetype.nit}, {4: ['Ac', '5c']});
      nit = applyAction(nit, 3, const Action.raise(50));
      _pinPre(nit, 4, 0.10, 'P5d_nit_mp_A5s_vs_utg_010');
    });

    test('vs RFI from the BB: Station flats wide, premiums stay aggressive', () {
      var s = _setup({2: Archetype.station}, {2: ['Ac', 'Ad']});
      s = applyAction(s, 3, const Action.raise(50));
      s = _fold(s, [4, 5, 0, 1]);
      _pinPre(s, 2, 0.3, 'P6_station_bb_AA_vs_utg_030');
      _pinPre(s, 2, 0.9, 'P6b_station_bb_AA_vs_utg_090');

      var aq = _setup({2: Archetype.station}, {2: ['Ac', 'Qc']});
      aq = applyAction(aq, 3, const Action.raise(50));
      aq = _fold(aq, [4, 5, 0, 1]);
      _pinPre(aq, 2, 0.5, 'P6c_station_bb_AQs_vs_utg_050');

      var junk = _setup({2: Archetype.tag}, {2: ['7c', '2d']});
      junk = applyAction(junk, 3, const Action.raise(50));
      junk = _fold(junk, [4, 5, 0, 1]);
      _pinPre(junk, 2, 0.0, 'P6d_tag_bb_72o_vs_utg_000');
    });

    test('vs 3-bet: AA/KK 4-bet or call, QQ class continues, junk folds', () {
      TableState threeBet(Archetype a, List<Card> hole) {
        var s = _setup({5: a}, {5: hole});
        s = applyAction(s, 3, const Action.raise(50));
        return applyAction(s, 4, const Action.raise(160));
      }

      final nitQQ = threeBet(Archetype.nit, ['Qc', 'Qd']);
      _pinPre(nitQQ, 5, 0.2, 'P7_nit_co_QQ_vs_3bet_020');
      _pinPre(nitQQ, 5, 0.5, 'P7b_nit_co_QQ_vs_3bet_050');
      final tagAA = threeBet(Archetype.tag, ['Ac', 'Ad']);
      _pinPre(tagAA, 5, 0.5, 'P7c_tag_co_AA_vs_3bet_050');
      _pinPre(tagAA, 5, 0.9, 'P7d_tag_co_AA_vs_3bet_090');
      _pinPre(
        threeBet(Archetype.station, ['7c', '2d']),
        5,
        0.0,
        'P8_station_co_72o_vs_3bet_000',
      );
      final stationA5 = threeBet(Archetype.station, ['Ac', '5c']);
      _pinPre(stationA5, 5, 0.1, 'P8b_station_co_A5s_vs_3bet_010');
      _pinPre(stationA5, 5, 0.9, 'P8c_station_co_A5s_vs_3bet_090');
    });

    test('BB with the option: raise over limps (3bb + 1bb per limper) or check', () {
      TableState limped(List<Card> hole) {
        var s = _setup({2: Archetype.tag}, {2: hole});
        s = applyAction(s, 3, const Action.call(amount: 20));
        s = _fold(s, [4, 5, 0]);
        return applyAction(s, 1, const Action.call(amount: 10));
      }

      _pinPre(limped(['8c', '8d']), 2, 0.5, 'P9_tag_bb_88_option_050');
      _pinPre(limped(['7c', '2d']), 2, 0.5, 'P9b_tag_bb_72o_option_050');
      // The check range is every label minus the >= 0.5 raise-over-limps chart.
      expect(
        _refPre('P9b_tag_bb_72o_option_050')['range'],
        _refChart('setdiff_all_minus_bbsb050'),
      );
    });

    test('an uncharted spot falls through to the 3-bet ladder', () {
      // MP raises over the UTG limp: UTG faces a raise from an MP aggressor,
      // and "UTG_vs_MP" is not a chart → AA still continues, 72o folds.
      var s = _setup({3: Archetype.tag}, {3: ['Ac', 'Ad']});
      s = applyAction(s, 3, const Action.call(amount: 20));
      s = applyAction(s, 4, const Action.raise(80));
      s = _fold(s, [5, 0, 1, 2]);
      expect(kVsRfi100.containsKey('UTG_vs_MP'), isFalse);
      final d = decideBot(s, 3, rng: _FixedRandom(0.5));
      expect(d.action.type, ActionType.raise);
      expect(d.action.amount, 208); // 80 * 2.6
      expect(d.range, kPremiumList);
      final call = decideBot(s, 3, rng: _FixedRandom(0.9));
      expect(call.action.type, ActionType.call);
      expect(call.action.amount, 60);
      s.players[3].hole = ['7c', '2d'];
      final junk = decideBot(s, 3, rng: _FixedRandom(0.0));
      expect(junk.action.type, ActionType.fold);
      expect(junk.range, isEmpty);
    });

    test('jittered dials override the archetype knobs', () {
      // QQ facing a 3-bet: 4-bet when rnd < 0.1 + 0.35 * aggression.
      var s = _setup({5: Archetype.nit}, {5: ['Qc', 'Qd']});
      s = applyAction(s, 3, const Action.raise(50));
      s = applyAction(s, 4, const Action.raise(160));
      // Nit aggression 0.5 → threshold 0.275: rnd 0.3 calls...
      expect(decideBot(s, 5, rng: _FixedRandom(0.3)).action.type, ActionType.call);
      // ...but a jittered aggression of 0.9 → 0.415 raises.
      s.players[5].dials = const Dials(aggression: 0.9, stickiness: 0.2, cbetFlop: 55);
      expect(decideBot(s, 5, rng: _FixedRandom(0.3)).action.type, ActionType.raise);
    });
  });

  group('decideBot postflop (river, exact equity, desktop reference)', () {
    test('monster not facing a bet: sized by rnd on a dry board', () {
      final s = _toRiver(Archetype.tag, ['Ks', 'Kd']);
      _pinRiver(s, 0.6, 'R1_tag_KK_nobet_060'); // 1.25 pot: 137.5 → 138
      _pinRiver(s, 0.1, 'R2_tag_KK_nobet_010'); // 0.66 pot
      _pinRiver(s, 0.3, 'R2b_tag_KK_nobet_030'); // 0.75 pot
      expect(_refRiver('R1_tag_KK_nobet_060')['action']['amount'], 138);
    });

    test('junk checks back; the stored range gains the actual label', () {
      _pinRiver(_toRiver(Archetype.station, ['7s', '2h']), 0.5, 'R3_station_72o_nobet_050');
      expect(_refRiver('R3_station_72o_nobet_050')['range'], ['72o']);
    });

    test('facing a bet: value raise / call by aggression and pot odds', () {
      final s = _toRiver(Archetype.tag, ['Ks', 'Kd'], 60);
      _pinRiver(s, 0.5, 'R4_tag_KK_vs_bet60_050'); // 60 + 170 * 0.8 = 196
      _pinRiver(s, 0.9, 'R4b_tag_KK_vs_bet60_090');
    });

    test('facing a bet with junk: pot odds and the station calldown', () {
      _pinRiver(_toRiver(Archetype.nit, ['7s', '2h'], 60), 0.5, 'R5_nit_72o_vs_bet60_050');
      final st = _toRiver(Archetype.station, ['7s', '2h'], 60);
      _pinRiver(st, 0.5, 'R5b_station_72o_vs_bet60_050');
      _pinRiver(st, 0.8, 'R5c_station_72o_vs_bet60_080');
      _pinRiver(
        _toRiver(Archetype.station, ['7s', '2h'], 100),
        0.5,
        'R5d_station_72o_vs_bet100_050',
      );
    });

    test('scare-card barrel: LAG bluffs the K-high river at aggression * 0.12', () {
      final s = _toRiver(Archetype.lag, ['7s', '2h']);
      _pinRiver(s, 0.05, 'R6_lag_72o_nobet_005');
      _pinRiver(s, 0.2, 'R6b_lag_72o_nobet_020');
    });

    test('with a stored range the returned range is narrowed (exact river)', () {
      final stored = _bbVsBtnCall025();
      var s = _toRiver(Archetype.tag, ['Ks', 'Kd']);
      s.botRanges = {2: List.of(stored)};
      _pinRiver(s, 0.6, 'R7_tag_KK_nobet_060_stored');
      s = _toRiver(Archetype.tag, ['Ks', 'Kd'], 60);
      s.botRanges = {2: List.of(stored)};
      _pinRiver(s, 0.9, 'R7b_tag_KK_vs_bet60_090_stored');
      s = _toRiver(Archetype.station, ['7s', '2h']);
      s.botRanges = {2: List.of(stored)};
      _pinRiver(s, 0.5, 'R7c_station_72o_nobet_050_stored');
      final ref = _refRiver('R7c_station_72o_nobet_050_stored');
      expect((ref['range'] as List).length, lessThan(stored.length));
      expect(ref['range'], contains('72o'));
    });

    test('equity vs the sole opponent\'s stored range is used heads-up', () {
      // Hero has no stored range, so these ran vs random. Give the villain
      // (seat 0) a narrow range the bot crushes → still a bet; a range that
      // crushes KK (only quads 99 / straight-making hands) → the equity
      // drops below the value threshold and the bot checks.
      var s = _toRiver(Archetype.tag, ['Ks', 'Kd']);
      s.botRanges = {0: ['22', '33', '44']};
      expect(decideBot(s, 2, rng: _FixedRandom(0.6)).action.type, ActionType.bet);
      s = _toRiver(Archetype.tag, ['Ks', 'Kd']);
      s.botRanges = {0: ['99', 'JT s'.replaceAll(' ', '')]};
      final d = decideBot(s, 2, rng: _FixedRandom(0.6));
      expect(d.action.type, ActionType.check);
    });

    test('flop decisions consume the injected rng (deterministic)', () {
      var s = _setup({2: Archetype.lag}, {2: ['Ks', 'Kd']});
      s = _fold(s, [3, 4, 5]);
      s = applyAction(s, 0, const Action.raise(50));
      s = applyAction(s, 1, const Action.fold());
      s = applyAction(s, 2, const Action.call(amount: 30));
      expect(s.street, Street.flop);
      final a = decideBot(s, 2, rng: Random(11));
      final b = decideBot(s, 2, rng: Random(11));
      expect(a.action.type, b.action.type);
      expect(a.action.amount, b.action.amount);
      expect(a.range, b.range);
      // Top set on a dry flop: never folds, always continues with a range
      // holding its own label.
      expect(a.action.type, isNot(ActionType.fold));
      expect(a.range, contains('KK'));
    });
  });

  group('bot_test.ts properties (all-bot tables)', () {
    const arch = [Archetype.tag, Archetype.lag, Archetype.nit, Archetype.station];
    const junk = {'72o', '82o', '92o', 'T2o', 'J2o', '83o', '73o', '62o', '52o', '42o', '32o'};

    test('Run A: premiums never fold, junk never calls big, ranges narrow', () {
      final rng = Random(2024);
      var state = createTable(_cfg, rng: rng);
      for (final p in state.players) {
        p.archetype = arch[p.id % arch.length];
      }
      int premiumFolds = 0;
      int junkBigCalls = 0;
      int decisions = 0;
      int rangeExclusions = 0;
      int postflopNarrowings = 0;
      int postflopGrowths = 0;
      int checkRaises = 0;
      int hands = 0;
      final sizings = <String>{};
      for (int h = 0; h < 400; h++) {
        state = startHand(state, rng: rng);
        final checkedThisStreet = <Street, Set<int>>{};
        int guard = 0;
        while (state.phase == GamePhase.betting && state.toAct != null && guard++ < 5000) {
          final seat = state.toAct!;
          final p = state.players[seat];
          final dec = decideBot(state, seat, rng: rng);
          if (state.street != Street.preflop) {
            final set = checkedThisStreet.putIfAbsent(state.street, () => <int>{});
            if (dec.action.type == ActionType.check) set.add(seat);
            if (dec.action.type == ActionType.bet && state.pot > 0) {
              final ratio = ((dec.action.amount ?? 0) / state.pot * 4).round() / 4;
              sizings.add(ratio.toStringAsFixed(2));
            }
            if (dec.action.type == ActionType.raise && set.contains(seat)) checkRaises++;
          }
          final hole = p.hole;
          final label = hole != null ? cardsToLabel(hole[0], hole[1]) : null;
          if (state.street == Street.preflop && label != null) {
            decisions++;
            final la = legalActions(state);
            if ((label == 'AA' || label == 'KK') && dec.action.type == ActionType.fold) {
              premiumFolds++;
            }
            if (junk.contains(label) &&
                dec.action.type == ActionType.call &&
                la.callAmount >= 8 * _cfg.bigBlind) {
              junkBigCalls++;
            }
          }
          if (dec.range != null && label != null && dec.action.type != ActionType.fold) {
            if (!dec.range!.contains(label)) rangeExclusions++;
            if (state.street != Street.preflop) {
              final before = state.botRanges[seat]?.length ?? 0;
              if (before > 8 && dec.range!.length < before) {
                postflopNarrowings++;
              } else if (before > 8 && dec.range!.length > before) {
                postflopGrowths++;
              }
            }
          }
          if (dec.range != null) state.botRanges[seat] = dec.range!;
          state = applyAction(state, seat, dec.action);
        }
        expect(state.phase, GamePhase.handOver, reason: 'hand completes');
        hands++;
      }
      expect(hands, 400);
      expect(decisions, greaterThan(1600), reason: 'saw plenty of preflop decisions');
      expect(premiumFolds, 0, reason: 'AA/KK never fold preflop');
      expect(junkBigCalls, 0, reason: 'junk never calls a big raise');
      expect(rangeExclusions, 0, reason: "stored range never excludes the bot's hand");
      expect(postflopNarrowings, greaterThan(60), reason: 'postflop actions narrow ranges');
      expect(postflopGrowths, 0, reason: 'postflop ranges never grow');
      expect(sizings.length, greaterThanOrEqualTo(3), reason: '3+ distinct sizings: $sizings');
      expect(checkRaises, greaterThan(0), reason: 'bots check-raise');
    });

    /// Drive [hands] hands with a scripted hero (seat 0); returns hero net chips.
    int heroNet(int hands, Random rng, Action Function(TableState s, LegalActions la) hero) {
      var state = createTable(_cfg, rng: rng);
      for (final p in state.players) {
        if (!p.isHero) p.archetype = arch[(p.id - 1) % arch.length];
      }
      int net = 0;
      for (int h = 0; h < hands; h++) {
        state = startHand(state, rng: rng);
        int guard = 0;
        while (state.phase == GamePhase.betting && state.toAct != null && guard++ < 5000) {
          final seat = state.toAct!;
          if (seat == 0) {
            state = applyAction(state, 0, hero(state, legalActions(state)));
          } else {
            state = applyAction(state, seat, decideBot(state, seat, rng: rng).action);
          }
        }
        net += state.summary?.heroNetChips ?? 0;
      }
      return net;
    }

    test('Run C: stabbing every check with any two loses', () {
      final net = heroNet(600, Random(7), (s, la) {
        if (s.street == Street.preflop) {
          if (la.canCheck) return const Action.check();
          if (la.canCall && la.callAmount <= _cfg.bigBlind) {
            return Action.call(amount: la.callAmount);
          }
          return const Action.fold();
        }
        if (la.canBet) return Action.bet(max(la.minRaiseTo, (s.pot * 0.66).round()));
        if (la.canCheck) return const Action.check();
        return const Action.fold();
      });
      expect(net, lessThan(0), reason: 'stab-every-check net ${net / _cfg.bigBlind} bb');
    });

    test('Run B: the open-jam maniac loses vs the field', () {
      final net = heroNet(400, Random(13), (s, la) {
        if (s.street == Street.preflop && la.canRaise) return Action.raise(la.maxRaiseTo);
        if (la.canCheck) return const Action.check();
        if (la.canCall) return Action.call(amount: la.callAmount);
        return const Action.fold();
      });
      expect(net, lessThan(0), reason: 'open-jam net ${net / _cfg.bigBlind} bb');
    });
  });
}
