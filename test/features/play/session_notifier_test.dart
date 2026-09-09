/// `SessionNotifier` — the play loop end to end (DESIGN.md §4.1–§4.14).
///
/// Everything is pinned: a seeded `Random`, a `FakeClock` and an in-memory
/// key-value store, so a whole hand replays identically on every run.
library;

import 'dart:math';

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a whole hand through the notifier', () {
    test('deal → bot actions → hero action → hand over', () async {
      final container = makeContainer(seed: 11);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      SessionState read() => container.read(sessionProvider);

      notifier.newSession(const TableOptions(seats: 6));
      await settle();

      final dealt = read();
      expect(dealt.active, isTrue);
      expect(dealt.table, isNotNull);
      expect(dealt.table!.handNumber, 1);
      expect(dealt.table!.phase, GamePhase.betting);
      // Every non-hero seat got an archetype and jittered dials (port §4.1).
      for (final p in dealt.table!.players.skip(1)) {
        expect(p.archetype, isNotNull);
        expect(p.dials, isNotNull);
      }
      expect(dealt.table!.players[0].archetype, isNull);

      stepToHero(notifier, read);
      final beforeHero = read();

      if (beforeHero.table!.toAct == 0) {
        expect(beforeHero.heroToAct, isTrue);
        expect(beforeHero.legal, isNotNull);
        await notifier.heroAction(const Action.fold());
        await settle();
        expect(read().table!.players[0].hasFolded, isTrue);
      }

      stepToHandOver(notifier, read);
      // A hero left to act after the fold cannot happen; if the hand is still
      // live the hero is out of it and the bots finish on their own.
      for (var i = 0; i < 200 && !read().handOver; i++) {
        notifier.stepBot();
      }
      await settle();

      final over = read();
      expect(over.handOver, isTrue);
      expect(over.table!.summary, isNotNull);
      expect(over.counters.hands, 1);
      expect(over.history, hasLength(1));
      expect(over.history.single.actions, isNotEmpty);
    });

    test('the same seed replays the same hand', () async {
      List<String> play(int seed) {
        final container = makeContainer(seed: seed);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);
        SessionState read() => container.read(sessionProvider);
        notifier.newSession(const TableOptions(seats: 6));
        stepToHero(notifier, read);
        return read().table!.log.map((e) => e.text).toList();
      }

      expect(play(23), equals(play(23)));
    });

    test('auto-rebuys a busted bot and captions it for one hand', () async {
      final container = makeContainer(seed: 5);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      SessionState read() => container.read(sessionProvider);

      notifier.newSession(const TableOptions(seats: 6));
      await settle();
      // Bust seat 3 by hand, then deal: §4.3's "rebought" caption.
      read().table!.players[3].stack = 0;
      // Finish the current hand first so `deal()` runs its rebuy pass.
      for (var i = 0; i < 200 && !read().handOver; i++) {
        if (read().table!.toAct == 0) {
          await notifier.heroAction(const Action.fold());
        } else {
          notifier.stepBot();
        }
      }
      read().table!.players[3].stack = 0;
      notifier.deal();
      await settle();
      expect(read().rebought, contains(3));
      expect(read().table!.players[3].stack, greaterThan(0));
    });
  });

  group('session counters (§4.13)', () {
    for (final seed in const [3, 7, 11, 21, 42]) {
      test('best is a great play and costliest a mistake (seed $seed)', () async {
        final container = makeContainer(seed: seed, coachEnabled: true);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);
        SessionState read() => container.read(sessionProvider);

        final seen = <Verdict>{};
        final evByVerdict = <Verdict, List<double>>{};
        final counted = <int>{};
        container.listen<SessionState>(sessionProvider, (_, next) {
          final bb = next.table?.bigBlind ?? kBigBlind;
          for (final r in next.reviewLog) {
            if (r.kind != ReviewKind.decision || !counted.add(r.id)) continue;
            seen.add(r.verdict);
            (evByVerdict[r.verdict] ??= <double>[]).add((r.evChips ?? 0) / bb);
          }
        });

        notifier.newSession(const TableOptions(seats: 6));
        await settle();
        for (var hand = 0; hand < 12; hand++) {
          for (var i = 0; i < 40 && !read().handOver; i++) {
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

        final counters = read().counters;
        // Desktop parity: ranking every coached decision together let a flagged
        // mistake become the session's "best play" in the §4.13 debrief.
        final greats = evByVerdict[Verdict.great] ?? const <double>[];
        final mistakes = evByVerdict[Verdict.mistake] ?? const <double>[];
        expect(counters.coachedDecisions, greaterThan(0));
        expect(seen, isNotEmpty);

        if (greats.isEmpty) {
          expect(counters.bestEvBb, isNull);
        } else {
          expect(counters.bestEvBb, closeTo(greats.reduce(max), 1e-9));
        }
        if (mistakes.isEmpty) {
          expect(counters.worstEvBb, isNull);
        } else {
          expect(counters.worstEvBb, closeTo(mistakes.reduce(min), 1e-9));
        }
      });
    }
  });

  group('snapshot contract (§4.14)', () {
    test('a mid-hand snapshot restores the exact table', () async {
      final store = KeyValueStore.memory();
      final clock = FakeClock();

      final first = makeContainer(seed: 3, store: store, clock: clock);
      final notifier = first.read(sessionProvider.notifier);
      SessionState read() => first.read(sessionProvider);

      notifier.newSession(const TableOptions(seats: 6));
      await settle();
      stepToHero(notifier, read);
      if (read().table!.toAct == 0) {
        await notifier.heroAction(
          read().legal!.canCheck ? const Action.check() : const Action.call(),
        );
        await settle();
      }
      final before = read().table!;
      final expected = (
        hand: before.handNumber,
        street: before.street,
        pot: before.pot,
        toAct: before.toAct,
        board: List<Card>.of(before.board),
        heroStack: before.players[0].stack,
      );
      first.dispose();

      // A fresh container over the same storage is a cold launch.
      final second = makeContainer(seed: 99, store: store, clock: clock);
      addTearDown(second.dispose);
      final restored = second.read(sessionProvider);

      expect(restored.active, isTrue);
      expect(restored.table, isNotNull);
      expect(restored.table!.handNumber, expected.hand);
      expect(restored.table!.street, expected.street);
      expect(restored.table!.pot, expected.pot);
      expect(restored.table!.toAct, expected.toAct);
      expect(restored.table!.board, equals(expected.board));
      expect(restored.table!.players[0].stack, expected.heroStack);

      // §4.14: a restored session is paused and captions itself for 2 s.
      expect(restored.paused, isTrue);
      expect(restored.resumeCaption, startsWith('Resumed — Hand #'));
      expect(restored.savedAt, greaterThan(0));
    });

    test('a hand resumed mid-flight still counts when it ends', () async {
      final store = KeyValueStore.memory();
      final clock = FakeClock();

      final first = makeContainer(seed: 3, store: store, clock: clock);
      final notifier = first.read(sessionProvider.notifier);
      notifier.newSession(const TableOptions(seats: 6));
      await settle();
      stepToHero(notifier, () => first.read(sessionProvider));
      expect(first.read(sessionProvider).counters.hands, 0);
      first.dispose();

      final second = makeContainer(seed: 99, store: store, clock: clock);
      addTearDown(second.dispose);
      SessionState read() => second.read(sessionProvider);
      final resumed = second.read(sessionProvider.notifier);
      resumed.tapFelt(); // lift the §4.14 pause
      await settle();
      final handNumber = read().table!.handNumber;

      for (var i = 0; i < 200 && !read().handOver; i++) {
        if (read().table?.toAct == 0) {
          await resumed.heroAction(const Action.fold());
        } else {
          resumed.stepBot();
        }
        await settle();
      }
      expect(read().handOver, isTrue, reason: 'the hand should have finished');

      // Regression: `_currentHH` was null after a restore, so `_finalizeHand`
      // skipped the counters and the history for the whole hand.
      expect(read().counters.hands, 1);
      expect(read().history, hasLength(1));
      expect(read().history.single.id, handNumber);
    });

    test(
      'a restored Manual-pace session resumes on the first felt tap',
      () async {
        final store = KeyValueStore.memory();
        final clock = FakeClock();

        final first = makeContainer(seed: 3, store: store, clock: clock);
        final notifier = first.read(sessionProvider.notifier);
        notifier.newSession(const TableOptions(seats: 6));
        await settle();
        stepToHero(notifier, () => first.read(sessionProvider));
        first.dispose();

        final second = makeContainer(seed: 99, store: store, clock: clock);
        addTearDown(second.dispose);
        SessionState read() => second.read(sessionProvider);
        expect(read().paused, isTrue);

        // Manual pace: the first tap only lifts the pause (§4.6) …
        final before = read().table!;
        second.read(sessionProvider.notifier).tapFelt();
        await settle();
        expect(read().paused, isFalse);

        // … and from then on the table actually advances.
        second.read(sessionProvider.notifier).tapFelt();
        await settle();
        expect(
          read().table!.toAct != before.toAct ||
              read().table!.street != before.street ||
              read().table!.pot != before.pot,
          isTrue,
          reason: 'the felt tap after the pause must step the table',
        );
      },
    );

    test(
      'an unreadable table half abandons the hand and keeps the roster',
      () async {
        final store = KeyValueStore.memory();
        final first = makeContainer(seed: 3, store: store);
        final notifier = first.read(sessionProvider.notifier);
        notifier.newSession(const TableOptions(seats: 6));
        await settle();
        final names = [
          for (final p in first.read(sessionProvider).table!.players) p.name,
        ];
        first.dispose();

        // Corrupt only the table half of the snapshot, as a schema bump would.
        final raw = store.getJsonMap(kSessionSnapshotKey);
        raw['table'] = <String, Object?>{'nonsense': true};
        await store.setJson(kSessionSnapshotKey, raw);

        final second = makeContainer(seed: 3, store: store);
        addTearDown(second.dispose);
        final restored = second.read(sessionProvider);
        expect(restored.needsFreshHand, isTrue);
        expect(
          restored.resumeCaption,
          "Resumed — that hand couldn't be restored, dealing a fresh one",
        );

        second.read(sessionProvider.notifier).ensureHand();
        await settle();
        final fresh = second.read(sessionProvider);
        expect(fresh.table, isNotNull);
        expect([for (final p in fresh.table!.players) p.name], equals(names));
      },
    );

    test('every hero action writes a snapshot', () async {
      final store = KeyValueStore.memory();
      final container = makeContainer(seed: 8, store: store);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      SessionState read() => container.read(sessionProvider);

      notifier.newSession(const TableOptions(seats: 6));
      await settle();
      final afterDeal = store.getJsonMap(kSessionSnapshotKey);
      expect(afterDeal, isNotEmpty);
      final savedAt = (afterDeal['savedAt'] as num).toInt();

      stepToHero(notifier, read);
      if (read().table!.toAct == 0) {
        await notifier.heroAction(const Action.fold());
        await settle();
        final after = store.getJsonMap(kSessionSnapshotKey);
        expect(
          (after['savedAt'] as num).toInt(),
          greaterThanOrEqualTo(savedAt),
        );
        expect(after['table'], isNotNull);
      }
    });
  });

  group('pace and the auto loop', () {
    test('manual pace never advances on its own', () async {
      final container = makeContainer(seed: 4);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.newSession(const TableOptions(seats: 6));
      await settle();
      final before = container.read(sessionProvider).table!.toAct;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(container.read(sessionProvider).table!.toAct, before);
    });

    test(
      'an open surface blocks the loop and a blocking note queues',
      () async {
        final container = makeContainer(seed: 4);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);
        notifier.newSession(const TableOptions(seats: 6));
        await settle();

        notifier.setSurfaceOpen(true);
        expect(container.read(sessionProvider).loopBlocked, isTrue);
        final before = container.read(sessionProvider).table!.toAct;
        notifier.stepBot();
        expect(container.read(sessionProvider).table!.toAct, before);

        notifier.setSurfaceOpen(false);
        expect(container.read(sessionProvider).loopBlocked, isFalse);
      },
    );
  });

  group('ending a session', () {
    test(
      'closeCurrentSession records the row and clears the snapshot',
      () async {
        final store = KeyValueStore.memory();
        final container = makeContainer(seed: 6, store: store);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.newSession(const TableOptions(seats: 9, ante: 5));
        await settle();
        expect(container.read(sessionProvider).active, isTrue);

        await notifier.closeCurrentSession();
        expect(container.read(sessionProvider).active, isFalse);
        expect(store.getString(kSessionSnapshotKey), isNull);
        // The lobby's Recent list is told to refetch.
        expect(container.read(sessionsRevisionProvider), greaterThan(0));
        // Table options survive: the next "Deal me in" reuses them.
        expect(container.read(sessionProvider).options.seats, 9);
      },
    );
  });
}
