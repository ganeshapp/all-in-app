/// P11 · Hand replayer (DESIGN.md §7.7) over a real `HHHand`: the frame walk,
/// the persisted coach-note strip, the §14 "hand not found" state and the
/// n > 10 refusal.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/providers/replay_model.dart';
import 'package:allin/features/stats/screens/replayer_screen.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'stats_harness.dart';

const CoachNoteRecord _riverNote = CoachNoteRecord(
  street: 'river',
  action: 'bet',
  verdict: 'great',
  title: 'Good value bet',
  plain: 'Two pair on a dry river gets called by worse.',
  steps: ['You bet 6 bb into 11 bb.'],
  expert: 'Villain calls with any pair here.',
  evBb: 1.5,
);

/// A table bigger than the felt draws (§7.7's one refusal).
HHHand _twelveHanded() {
  final seats = [
    for (var i = 0; i < 12; i++)
      HHSeat(
        seat: i,
        name: 'p$i',
        stack: 1000,
        isHero: i == 0,
        position: Position.values[i % 6],
      ),
  ];
  return HHHand(
    id: 12,
    startedAt: 1781838111000,
    button: 0,
    sb: 5,
    bb: 10,
    sbSeat: 1,
    bbSeat: 2,
    seats: seats,
    holes: {
      0: const ['Ac', 'Kc'],
    },
    actions: [
      HHAction(
        street: Street.preflop,
        seat: 0,
        name: 'p0',
        type: ActionType.raise,
        amount: 30,
        allIn: false,
      ),
    ],
    board: const [],
    heroNet: 15,
  );
}

void main() {
  _seatLayoutMatchesTheLiveFelt();
  final hand = sixMaxHand();
  final frames = buildReplayFrames(hand);

  testWidgets('opens on the last frame and steps backwards', (tester) async {
    final fixture = StatsFixture();
    await fixture.addHand(hand, netBb: 13);
    await pumpStats(
      tester,
      ReplayerScreen(startedAt: hand.startedAt),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.replayTitle(hand.id)), findsOneWidget);
    // §10 of the port doc: the replayer opens on the winner line.
    expect(find.text(frames.last.text), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Previous'));
    await tester.pumpAndSettle();
    expect(find.text(frames[frames.length - 2].text), findsWidgets);

    await tester.tap(find.bySemanticsLabel('First'));
    await tester.pumpAndSettle();
    expect(find.text(frames.first.text), findsWidgets);
    expect(find.textContaining('Blinds'), findsWidgets);
  });

  testWidgets('steps to the hand either side without leaving P11', (
    tester,
  ) async {
    // Reviewing a session means reading its hands in order; the only route to
    // the next one used to be back out to the list and find your place again.
    final fixture = StatsFixture();
    final older = sixMaxHand(
      startedAt: hand.startedAt - 60000,
      id: hand.id - 1,
    );
    await fixture.addHand(older, netBb: -2);
    await fixture.addHand(hand, netBb: 13);

    await pumpStats(
      tester,
      ReplayerScreen(startedAt: hand.startedAt),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.replayTitle(hand.id)), findsOneWidget);
    // Newest hand: there is nothing newer to step to.
    expect(
      tester.getSemantics(find.bySemanticsLabel(StatsCopy.replayNewerHand)),
      isNot(matchesSemantics(hasEnabledState: true, isEnabled: true)),
    );

    await tester.tap(find.text(StatsCopy.replayOlderHand));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.replayTitle(older.id)), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(StatsCopy.replayNewerHand));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.replayTitle(hand.id)), findsOneWidget);
  });

  testWidgets('long-pressing the pill lists every frame', (tester) async {
    final fixture = StatsFixture();
    await fixture.addHand(hand, netBb: 13);
    await pumpStats(
      tester,
      ReplayerScreen(startedAt: hand.startedAt),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.bySemanticsLabel(RegExp('^Frame ${frames.length} of')),
    );
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.replayFrames), findsOneWidget);
    expect(find.text(frames.first.text), findsWidgets);
  });

  testWidgets('the stored coach note appears on its own frame only', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await fixture.addHand(hand, netBb: 13, coachNotes: const [_riverNote]);
    final model = ReplayModel.of(hand, coachNotes: const [_riverNote]);
    final noteFrame = model.frameForNote(street: 'river', action: 'bet');

    await pumpStats(
      tester,
      ReplayerScreen(startedAt: hand.startedAt, street: 'river', action: 'bet'),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    expect(noteFrame, lessThan(model.lastIndex));
    expect(
      find.textContaining(_riverNote.title),
      findsOneWidget,
      reason: 'the strip carries the note for this frame',
    );

    // Stepping to the end leaves the strip empty (fixed 48 pt, no jump).
    await tester.tap(find.bySemanticsLabel('Decision'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_riverNote.title), findsNothing);
  });

  testWidgets('a hand that is no longer stored shows the §14 state', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await pumpStats(
      tester,
      const ReplayerScreen(startedAt: 42),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.replayMissing), findsOneWidget);
    expect(find.text(StatsCopy.allHandsRow), findsOneWidget);
    // Felt, scrubber and timeline are not rendered.
    expect(find.byType(FrameScrubber), findsNothing);
    expect(find.byType(FeltCanvas), findsNothing);
  });

  testWidgets('more than ten seats writes the action out instead', (
    tester,
  ) async {
    final big = _twelveHanded();
    final fixture = StatsFixture();
    await fixture.addHand(big, netBb: 1.5);
    await pumpStats(
      tester,
      ReplayerScreen(startedAt: big.startedAt),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.replayTooManySeats(12)), findsOneWidget);
    expect(find.byType(FeltCanvas), findsNothing);
    // The scrubber still works.
    expect(find.byType(FrameScrubber), findsOneWidget);
  });

  group('the felt renders at every width and theme', () {
    for (final size in const [Size(360, 780), Size(430, 932)]) {
      for (final dark in const [true, false]) {
        testWidgets('${size.width.toInt()} dark=$dark', (tester) async {
          final fixture = StatsFixture();
          await fixture.addHand(hand, netBb: 13);
          await pumpStats(
            tester,
            ReplayerScreen(startedAt: hand.startedAt),
            fixture: fixture,
            size: size,
            dark: dark,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(FeltCanvas), findsOneWidget);
        });
      }
    }
  });
}

void _seatLayoutMatchesTheLiveFelt() {
  group('seat layout matches the live table', () {
    // The live anchors, from `felt_canvas.dart`'s `_seatFractions` for 6-max.
    // A player who sat on your right all hand must still be on your right in
    // the replay: mirroring the table made the person who acted before you
    // look like they acted after you.
    const live = <int, Offset>{
      1: Offset(0.89, 0.675),
      2: Offset(0.89, 0.315),
      3: Offset(0.50, 0.14),
      4: Offset(0.11, 0.315),
      5: Offset(0.11, 0.675),
    };

    test('the hero sits at the bottom', () {
      final hero = replaySeatPos(6, 0);
      expect(hero.dx, closeTo(0.5, 0.01));
      expect(hero.dy, greaterThan(0.8), reason: 'bottom of the felt');
    });

    test('every seat lands on the same side as the live felt', () {
      /// -1 left of centre, 0 centred, 1 right of centre.
      int side(double v) => v < 0.49 ? -1 : (v > 0.51 ? 1 : 0);

      for (final e in live.entries) {
        final got = replaySeatPos(6, e.key);
        // Same side of the table — the sign is the whole bug. Seat 3 sits
        // dead centre at the top, which is why this compares sides rather
        // than signs.
        expect(
          side(got.dx),
          side(e.value.dx),
          reason: 'seat ${e.key} is on the wrong side',
        );
        expect(
          side(got.dy),
          side(e.value.dy),
          reason: 'seat ${e.key} is at the wrong height',
        );
      }
    });

    test('seat 1 is on the hero right, not the left', () {
      expect(replaySeatPos(6, 1).dx, greaterThan(0.5));
      expect(replaySeatPos(6, 5).dx, lessThan(0.5));
    });
  });
}
