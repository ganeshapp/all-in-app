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
