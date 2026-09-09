/// P2's hand list carries the coach's verdict (§4.13).
///
/// `reviewLog` is emptied by every deal and `HHHand` carries no notes, so the
/// session keeps the worst verdict per finished hand. Without it the Session
/// tab's rows were "#4  +0.0 bb" and nothing else: after 60 hands there was no
/// way to find the hand you wanted to re-examine.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

CoachReview _review(int id, Verdict verdict, {ReviewKind? kind}) => CoachReview(
  id: id,
  kind: kind ?? ReviewKind.decision,
  blocking: false,
  verdict: verdict,
  title: 'x',
  board: const [],
  text: 'x',
);

void main() {
  group('worstVerdict', () {
    test('ranks mistake over thin over great', () {
      expect(
        worstVerdict([
          _review(1, Verdict.great),
          _review(2, Verdict.thin),
          _review(3, Verdict.mistake),
        ]),
        Verdict.mistake,
      );
      expect(
        worstVerdict([_review(1, Verdict.great), _review(2, Verdict.thin)]),
        Verdict.thin,
      );
      expect(worstVerdict([_review(1, Verdict.great)]), Verdict.great);
    });

    test('a hand the coach never flagged gets no dot', () {
      expect(worstVerdict(const []), isNull);
      expect(
        worstVerdict([_review(1, Verdict.ok), _review(2, Verdict.info)]),
        isNull,
      );
    });

    test('bot reads are not the hero\'s verdict', () {
      expect(
        worstVerdict([_review(1, Verdict.mistake, kind: ReviewKind.bot)]),
        isNull,
      );
    });
  });

  test('a finished hand keeps its worst verdict after the next deal', () async {
    final container = makeContainer(seed: 7, coachEnabled: true);
    addTearDown(container.dispose);
    final notifier = container.read(sessionProvider.notifier);
    SessionState read() => container.read(sessionProvider);

    // Every note seen while each hand was live, by hand number.
    final seen = <int, List<CoachReview>>{};
    final counted = <int>{};
    container.listen<SessionState>(sessionProvider, (_, next) {
      final number = next.table?.handNumber;
      if (number == null) return;
      for (final r in next.reviewLog) {
        if (!counted.add(r.id)) continue;
        (seen[number] ??= <CoachReview>[]).add(r);
      }
    });

    notifier.newSession(const TableOptions(seats: 6));
    await settle();
    for (var hand = 0; hand < 12; hand++) {
      for (var i = 0; i < 60 && !read().handOver; i++) {
        // A blocking verdict parks the loop until P3 is acknowledged.
        if (read().activeReview?.blocking ?? false) {
          notifier.dismissReview();
          await settle();
          continue;
        }
        if (read().table?.toAct == 0) {
          final legal = read().legal;
          if (legal == null) break;
          await notifier.heroAction(
            legal.canCheck ? const Action.check() : const Action.call(),
          );
        } else {
          notifier.stepBot();
        }
        await settle();
      }
      if (!read().handOver) break;
      notifier.deal();
      await settle();
    }

    final state = read();
    expect(state.history, isNotEmpty);
    expect(seen, isNotEmpty, reason: 'the coach never said anything');
    expect(
      state.handVerdicts,
      isNotEmpty,
      reason: 'no finished hand kept a verdict',
    );
    for (final hand in state.history) {
      expect(
        state.handVerdicts[hand.startedAt],
        worstVerdict(seen[hand.id] ?? const []),
        reason: 'hand #${hand.id}',
      );
    }
  });
}
