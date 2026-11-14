import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/play/providers/guess_provider.dart';
import 'package:allin/features/play/providers/hand_reads_provider.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/hand_read_copy.dart';
import 'package:allin/services/persistence/hand_reads_store.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

HandRead prediction({
  Set<String> selected = const {'AKo'},
  Street street = Street.preflop,
  int hand = 1,
}) => HandRead(
  sessionId: 10,
  handNumber: hand,
  seat: 1,
  playerName: 'Ivey',
  street: street,
  selected: selected,
  estimatedRange: allLabels().toSet(),
  rangeOverlap: scoreGuess(selected.toList(), allLabels()).accuracy,
  submittedAt: 10,
);

void main() {
  test('a precise correct read hits even when model overlap is very low', () {
    final read = prediction().finish(HandReadStatus.revealed, ['Ah', 'Ks']);
    expect(read.rangeOverlap, lessThan(.1));
    expect(read.actualHand, 'AKo');
    expect(read.hit, isTrue);
    expect(HandReadCopy.heading(read), 'Called it · AKo');
    expect(HandReadCopy.selected(read.selected.length), '1 hand type selected');
  });

  test('suits matter to suitedness; wider hits disclose their breadth', () {
    expect(
      prediction().finish(HandReadStatus.revealed, ['Ah', 'Kh']).hit,
      isFalse,
    );
    final wide = prediction(
      selected: {'AKo', 'AQo', 'KK', 'QQ'},
    ).finish(HandReadStatus.revealed, ['Ah', 'Ks']);
    expect(wide.hit, isTrue);
    expect(HandReadCopy.heading(wide), 'Read hit · AKo');
    expect(HandReadCopy.body(wide), contains('4 selected hand types'));
    final all = prediction(
      selected: allLabels().toSet(),
    ).finish(HandReadStatus.revealed, ['Ah', 'Ks']);
    expect(HandReadCopy.body(all), contains('169 selected hand types'));
    expect(HandReadCopy.heading(all), isNot(contains('Called it')));
  });

  test(
    'pending, unshown and abandoned reads have no hit and no cards after load',
    () {
      for (final status in [
        HandReadStatus.pending,
        HandReadStatus.unshown,
        HandReadStatus.abandoned,
      ]) {
        final read =
            HandRead.fromJson(
              prediction().finish(status, ['Ah', 'Ks']).toJson(),
            )!;
        expect(read.shownCards, isEmpty);
        expect(read.actualHand, isNull);
        expect(read.hit, isNull);
      }
      expect(
        HandRead.fromJson({
          'selected': ['nope'],
        }),
        isNull,
      );
      final corrupt = prediction().finish(HandReadStatus.revealed, [
        'Ah',
        'Ah',
      ]);
      expect(
        HandRead.fromJson(corrupt.toJson())!.status,
        HandReadStatus.unshown,
      );
    },
  );

  test(
    'store round-trips both measurements, and full reset erases reads',
    () async {
      final kv = KeyValueStore.memory();
      final store = HandReadsStore(kv);
      await store.save([
        prediction().finish(HandReadStatus.revealed, ['Ah', 'Ks']),
      ]);
      expect(store.load().single.hit, isTrue);
      expect(store.load().single.rangeOverlap, lessThan(.1));
      expect(store.load().single.selected, {'AKo'});
      await kv.clearAllInKeys();
      expect(store.load(), isEmpty);
    },
  );

  test(
    'submission is locked per street; different streets keep separate reads',
    () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(handReadsProvider.notifier);
      n.submit(prediction());
      n.submit(prediction(selected: {'AA'}));
      n.submit(prediction(selected: {'AA'}, street: Street.flop));
      expect(c.read(handReadsProvider), hasLength(2));
      expect(c.read(handReadsProvider).first.selected, {'AKo'});
    },
  );

  test(
    'only completed hands reveal predictions, respecting realistic reveal',
    () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final session = c.read(sessionProvider.notifier)
        ..newSession(const TableOptions(seats: 2));
      final table = c.read(sessionProvider).table!;
      final n = c.read(handReadsProvider.notifier)..submit(prediction());
      n.finishHand(10, table, realisticReveal: false);
      expect(c.read(handReadsProvider).single.status, HandReadStatus.pending);
      final over = table.clone();
      over.phase = GamePhase.handOver;
      over.players[1].hasFolded = true;
      n.finishHand(10, over, realisticReveal: true);
      expect(c.read(handReadsProvider).single.status, HandReadStatus.unshown);
      expect(c.read(handReadsProvider).single.shownCards, isEmpty);
      session.endSession();
    },
  );

  test(
    'live read is locked, persists, and is resolved by the real play loop',
    () async {
      final kv = KeyValueStore.memory();
      final c = makeContainer(store: kv);
      addTearDown(c.dispose);
      final session = c.read(sessionProvider.notifier)..newSession();
      final table = c.read(sessionProvider).table!;
      final actual = cardsToLabel(
        table.players[1].hole![0],
        table.players[1].hole![1],
      );
      final guess = c.read(guessProvider.notifier)..open(1);
      guess
        ..setPainted({actual})
        ..peek()
        ..close()
        ..open(1);
      expect(c.read(guessProvider).revealed, isTrue);
      guess
        ..setPainted({'AA', 'KK'})
        ..peek();
      expect(c.read(handReadsProvider), hasLength(1));
      expect(c.read(handReadsProvider).single.selected, {actual});
      expect(c.read(handReadsProvider).single.shownCards, isEmpty);
      for (var i = 0; i < 400 && !c.read(sessionProvider).handOver; i++) {
        final s = c.read(sessionProvider);
        if (s.heroToAct) {
          session.heroAction(
            s.legal!.canCheck
                ? const poker.Action.check()
                : const poker.Action.fold(),
          );
        } else {
          session.stepBot();
        }
      }
      expect(c.read(sessionProvider).handOver, isTrue);
      expect(c.read(handReadsProvider).single.hit, isTrue);
      guess
        ..open(2)
        ..setPainted({'AA'})
        ..peek();
      expect(
        c.read(handReadsProvider),
        hasLength(1),
        reason: 'no predictions after seeing the cards',
      );
      await settle();
      final restored = HandReadsStore(kv).load().single;
      expect(restored.hit, isTrue);
      expect(restored.selected, {actual});
      guess.open(1);
      expect(c.read(guessProvider).painted, {actual});
      final oldId = c.read(sessionProvider).startedAt;
      session.newSession();
      expect(c.read(sessionProvider).startedAt, isNot(oldId));
      guess.open(1);
      expect(c.read(guessProvider).revealed, isFalse);
      expect(c.read(guessProvider).painted, isEmpty);
    },
  );

  test(
    'restart reconciles completed or lost snapshots without peeking early',
    () async {
      final kv = KeyValueStore.memory();
      final c = makeContainer(store: kv);
      addTearDown(c.dispose);
      c.read(sessionProvider.notifier).newSession();
      final table = c.read(sessionProvider).table!.clone();
      await settle();
      final n = c.read(handReadsProvider.notifier)..submit(prediction());
      n.reconcileSession(10, table, realisticReveal: false);
      expect(c.read(handReadsProvider).single.status, HandReadStatus.pending);
      await settle();
      final reloaded = makeContainer(store: kv);
      addTearDown(reloaded.dispose);
      expect(
        reloaded.read(handReadsProvider).single.status,
        HandReadStatus.pending,
      );
      table.phase = GamePhase.handOver;
      reloaded
          .read(handReadsProvider.notifier)
          .reconcileSession(10, table, realisticReveal: false);
      expect(
        reloaded.read(handReadsProvider).single.status,
        HandReadStatus.revealed,
      );
      final later = prediction(hand: 2);
      reloaded.read(handReadsProvider.notifier)
        ..submit(later)
        ..reconcileSession(0, null, realisticReveal: false);
      expect(
        reloaded.read(handReadsProvider).last.status,
        HandReadStatus.abandoned,
      );
    },
  );

  test('unfinished reads are excluded when their session ends', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    final n = c.read(handReadsProvider.notifier)..submit(prediction());
    n.abandonSession(10);
    expect(c.read(handReadsProvider).single.status, HandReadStatus.abandoned);
    expect(c.read(handReadsProvider).single.hit, isNull);
  });
}
