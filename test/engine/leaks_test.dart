// Port of the desktop scripts/leaks_test.ts (6 assertions) plus threshold
// boundary checks and verbatim copy pins.
import 'package:allin/engine/leaks.dart';
import 'package:flutter_test/flutter_test.dart';

DecisionRecord d(String verdict, String action) => DecisionRecord(
  verdict: verdict,
  action: action,
  equity: 0.3,
  potOdds: 0.25,
  evBb: -1,
  street: 'flop',
  villainArchetype: 'TAG',
  ts: 0,
);

List<DecisionRecord> rep(int n, String verdict, String action) =>
    List.generate(n, (_) => d(verdict, action));

void main() {
  test('empty → no leaks', () {
    final empty = leaksFromDecisions([]);
    expect(empty.total, 0);
    expect(empty.leaks, isEmpty);
  });

  test('fold mistakes', () {
    final folds = leaksFromDecisions([
      ...rep(4, 'mistake', 'fold'),
      ...rep(6, 'ok', 'call'),
    ]);
    expect(folds.total, 10);
    expect(folds.foldMistakes, 4);
    expect(folds.mistakes, 4);
    expect(
      folds.leaks.any((l) => l.toLowerCase().contains('fold too often')),
      isTrue,
    );
    expect(folds.leaks, [kLeakFoldTooOften]);
  });

  test('call mistakes', () {
    final calls = leaksFromDecisions([
      ...rep(4, 'mistake', 'call'),
      ...rep(6, 'ok', 'check'),
    ]);
    expect(calls.callMistakes, 4);
    expect(
      calls.leaks.any((l) => l.toLowerCase().contains('call too wide')),
      isTrue,
    );
    expect(calls.leaks, [kLeakCallTooWide]);
  });

  test('clean play', () {
    final clean = leaksFromDecisions([
      ...rep(6, 'ok', 'call'),
      ...rep(4, 'great', 'bet'),
    ]);
    expect(clean.mistakes, 0);
    expect(clean.great, 4);
    expect(clean.leaks.any((l) => l.contains('No clear')), isTrue);
    expect(clean.leaks, [kLeakCleanDiscipline]);
  });

  test('info excluded', () {
    final withInfo = leaksFromDecisions([
      d('info', 'check'),
      d('info', 'check'),
      d('ok', 'call'),
    ]);
    expect(withInfo.total, 1);
  });

  test('copy is verbatim desktop text', () {
    expect(
      kLeakFoldTooOften,
      "You fold too often when you're getting the right price — look for more +EV calls.",
    );
    expect(
      kLeakCallTooWide,
      'You call too wide for the pot odds — fold your weakest hands more.',
    );
    expect(
      kLeakCleanDiscipline,
      'No clear −EV mistakes flagged — solid discipline. Keep refining the thin spots.',
    );
  });

  test('thresholds: needs 8 decisions, 3 mistakes and > 12 % rate', () {
    // 7 decisions: below the minimum, nothing reported even when clean.
    expect(leaksFromDecisions(rep(7, 'ok', 'call')).leaks, isEmpty);
    expect(leaksFromDecisions(rep(8, 'ok', 'call')).leaks, [
      kLeakCleanDiscipline,
    ]);
    // 2 fold mistakes out of 8 = 25 % but fewer than 3 → not reported.
    final two = leaksFromDecisions([
      ...rep(2, 'mistake', 'fold'),
      ...rep(6, 'ok', 'call'),
    ]);
    expect(two.leaks, isEmpty);
    expect(two.mistakes, 2);
    // 3 of 25 = 12 % exactly → not > 0.12 → not reported.
    final exact = leaksFromDecisions([
      ...rep(3, 'mistake', 'fold'),
      ...rep(22, 'ok', 'call'),
    ]);
    expect(exact.leaks, isEmpty);
    // 3 of 24 = 12.5 % → reported.
    final over = leaksFromDecisions([
      ...rep(3, 'mistake', 'fold'),
      ...rep(21, 'ok', 'call'),
    ]);
    expect(over.leaks, [kLeakFoldTooOften]);
    // Both fold and call leaks can fire together; thin/great are counted.
    final both = leaksFromDecisions([
      ...rep(3, 'mistake', 'fold'),
      ...rep(3, 'mistake', 'call'),
      ...rep(1, 'mistake', 'raise'),
      ...rep(2, 'thin', 'call'),
      ...rep(1, 'great', 'bet'),
    ]);
    expect(both.total, 10);
    expect(both.mistakes, 7);
    expect(both.thin, 2);
    expect(both.great, 1);
    expect(both.leaks, [kLeakFoldTooOften, kLeakCallTooWide]);
  });

  test('DecisionRecord json round-trip', () {
    final r = DecisionRecord(
      verdict: 'thin',
      action: 'raise',
      equity: 0.41,
      potOdds: 0.2,
      evBb: 1.5,
      street: 'turn',
      villainArchetype: null,
      position: 'BTN',
      ts: 1750000000000,
    );
    final back = DecisionRecord.fromJson(r.toJson());
    expect(back.verdict, 'thin');
    expect(back.action, 'raise');
    expect(back.equity, 0.41);
    expect(back.potOdds, 0.2);
    expect(back.evBb, 1.5);
    expect(back.street, 'turn');
    expect(back.villainArchetype, isNull);
    expect(back.position, 'BTN');
    expect(back.ts, 1750000000000);
  });
}
