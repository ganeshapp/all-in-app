/// D1 layer 1 — the mobile-authored drill verdict (docs/TONE.md).
///
/// The engine's rationales are the desktop's and stay pinned; these tests fix
/// the *translation*: no hand codes, no seat codes, no "equity" / "pot odds" /
/// "range" / "jam" / "ICM" at layer 1, chances as counts and money in bb.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/drills/content/drill_rationale.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drill_test_kit.dart';

/// Every term TONE.md keeps out of layer 1. Lower-case entries are matched
/// case-insensitively; the upper-case seat/metric codes are matched as whole
/// words so ordinary English ("costs", "covers") is not a false positive.
const List<String> _bannedPhrases = [
  'equity',
  'pot odds',
  'continuing range',
  'jams',
  'villain',
  r'$EV',
  '%',
];

const List<String> _bannedCodes = [
  'ICM',
  'UTG',
  'MP',
  'CO',
  'BTN',
  'SB',
  'BB',
  'SPR',
];

void _isPlainEnglish(String? text, {required String reason}) {
  expect(text, isNotNull, reason: reason);
  for (final term in _bannedPhrases) {
    expect(
      text!.toLowerCase(),
      isNot(contains(term.toLowerCase())),
      reason: '"$term" must not appear at layer 1 ($reason): $text',
    );
  }
  for (final code in _bannedCodes) {
    expect(
      RegExp('\\b$code\\b').hasMatch(text!),
      isFalse,
      reason: '"$code" must not appear at layer 1 ($reason): $text',
    );
  }
}

void main() {
  group('hands and seats in words', () {
    test('the s / o suffix is spelled out, pairs are named', () {
      expect(
        DrillRationale.handInWords('T8o'),
        'ten and eight of different suits',
      );
      expect(
        DrillRationale.handInWords('KQs'),
        'king and queen of the same suit',
      );
      expect(DrillRationale.handInWords('88'), 'a pair of eights');
      expect(DrillRationale.handInWords('AA'), 'a pair of aces');
      expect(DrillRationale.handInWords('66'), 'a pair of sixes');
    });

    test('seat codes become ordinary language', () {
      expect(DrillRationale.seatInWords(Position.co), contains('button'));
      expect(DrillRationale.seatInWords(Position.utg), contains('first seat'));
      for (final p in Position.values) {
        final words = DrillRationale.seatInWords(p);
        expect(words, isNot(contains(p.label)));
      }
    });
  });

  group('layer 1 replaces the engine wording', () {
    test('a pot-odds call is priced in counts and big blinds', () {
      final text = DrillRationale.plain(testPuzzle());
      _isPlainEnglish(text, reason: 'post-flop call');
      expect(text, contains('8 bb'));
      expect(text, contains('24 bb'));
      expect(text, contains('about 1 time in 4'));
      expect(text, contains('about 1 time in 3'));
      expect(text, contains('makes money'));
    });

    test('a fold verdict says the price is not met, without judging', () {
      final text = DrillRationale.plain(
        testPuzzle(equity: 0.09, potOdds: 0.33, best: DrillAction.fold),
      );
      _isPlainEnglish(text, reason: 'post-flop fold');
      expect(text, contains('folding is right'));
      expect(text, contains('lose money over time'));
    });

    test('a mixed spot says either answer is fine', () {
      final text = DrillRationale.plain(
        testPuzzle(
          best: DrillAction.call,
          accept: const [DrillAction.call, DrillAction.fold],
        ),
      );
      _isPlainEnglish(text, reason: 'mixed');
      expect(text, contains('both'));
    });

    test('a chart open names the seat and the share of hands', () {
      final text = DrillRationale.plain(
        testPuzzle(
          kind: PuzzleKind.rfi,
          source: PuzzleSource.chart,
          street: Street.preflop,
          heroPos: Position.co,
          board: const [],
          equity: null,
          potOdds: null,
          toCall: 0,
          best: DrillAction.fold,
          accept: const [DrillAction.fold],
        ),
      );
      _isPlainEnglish(text, reason: 'chart fold');
      expect(text, contains('one seat before the button'));
      expect(text, contains('folding is right'));
    });

    test('a hand facing a raise never says "continuing range"', () {
      final text = DrillRationale.plain(
        testPuzzle(
          kind: PuzzleKind.vsRaise,
          source: PuzzleSource.chart,
          street: Street.preflop,
          hole: const ['Th', '8c'],
          board: const [],
          equity: null,
          potOdds: null,
          toCall: 0,
          best: DrillAction.fold,
          accept: const [DrillAction.fold],
        ),
      );
      _isPlainEnglish(text, reason: 'vs a raise');
      expect(text, contains('ten and eight of different suits'));
      expect(text, contains('too weak'));
    });

    test('push/fold explains the shove without saying "jam" or "ICM"', () {
      final text = DrillRationale.plain(
        testPuzzle(
          kind: PuzzleKind.pushfold,
          source: PuzzleSource.chart,
          street: Street.preflop,
          heroPos: Position.sb,
          board: const [],
          equity: null,
          potOdds: null,
          toCall: 0,
          icm: true,
          best: DrillAction.raise,
          accept: const [DrillAction.raise],
          options: const [
            DrillOption(action: DrillAction.fold, label: 'Fold'),
            DrillOption(
              action: DrillAction.raise,
              label: 'Shove 10 bb',
              amount: 10,
            ),
          ],
        ),
      );
      _isPlainEnglish(text, reason: 'push/fold on the bubble');
      expect(text, contains('all in or fold'));
      expect(text, contains('one place away from the money'));
    });

    test('Review spots keep their own coach-authored note', () {
      expect(
        DrillRationale.plain(testPuzzle(kind: PuzzleKind.leak)),
        isNull,
        reason: 'the engine string is already the coach speaking',
      );
    });
  });
}
