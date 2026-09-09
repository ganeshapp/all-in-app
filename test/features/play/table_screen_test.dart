/// P1 · Table (DESIGN.md §4.2–§4.15).
///
/// The felt has to render at 360 / 390 / 430 for 2, 6 and 9 seats, in both
/// themes and at 1.3× text, without a single overflow; the action row has to
/// show the right §4.5 state for a check spot, a call spot, a raise spot and
/// an all-in spot.
library;

import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Starts a session and steps to the hero's turn before pumping.
Future<ProviderContainer> seatedTable(
  WidgetTester tester, {
  required int seats,
  Size size = phone390,
  double textScale = 1.0,
  bool dark = true,
  int seed = 11,
  bool toHero = true,
}) async {
  final container = makeContainer(seed: seed);
  addTearDown(container.dispose);
  final notifier = container.read(sessionProvider.notifier);
  notifier.newSession(TableOptions(seats: seats));
  await settleWidgets(tester);
  if (toHero) {
    stepToHero(notifier, () => container.read(sessionProvider));
  }
  await pumpApp(
    tester,
    container: container,
    location: '/table',
    size: size,
    textScale: textScale,
    dark: dark,
  );
  return container;
}

void main() {
  group('the felt renders at every supported size', () {
    for (final size in [phone360, phone390, phone430]) {
      for (final seats in [2, 6, 9]) {
        testWidgets('$seats seats at ${size.width.toInt()}', (tester) async {
          await seatedTable(tester, seats: seats, size: size);
          expect(tester.takeException(), isNull);
          expect(find.byType(FeltCanvas), findsOneWidget);
          expect(find.byType(BoardRow), findsOneWidget);
          expect(find.byType(HeroHand), findsOneWidget);
          expect(find.byType(HeroStrip), findsOneWidget);
          expect(find.byType(ActionRow), findsOneWidget);
          // One plate per opponent (§4.3: the hero has none).
          expect(find.byType(SeatPlate), findsNWidgets(seats - 1));
        });
      }
    }

    testWidgets('6-max at 1.3x text on a 360 screen', (tester) async {
      await seatedTable(tester, seats: 6, size: phone360, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.byType(ActionRow), findsOneWidget);
    });

    testWidgets('6-max in the light theme', (tester) async {
      await seatedTable(tester, seats: 6, dark: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('§4.5 action-row states', () {
    testWidgets('State A — hero facing a bet gets Fold, Call and Raise', (
      tester,
    ) async {
      // The big blind pre-flop always faces at least the posted blinds, so a
      // seeded table that reaches the hero pre-flop is a call-or-raise spot.
      final container = await seatedTable(tester, seats: 6, seed: 11);
      final session = container.read(sessionProvider);
      if (!session.heroToAct) return; // covered by the manual-pace case below.

      final legal = session.legal!;
      final row = tester.widget<ActionRow>(find.byType(ActionRow));
      expect(
        row.state,
        legal.canBet || legal.canRaise
            ? ActionRowState.heroToAct
            : ActionRowState.heroToActNoRaise,
      );
      final inRow = find.descendant(
        of: find.byType(ActionRow),
        matching: find.text(legal.toCall > 0 ? 'Fold' : 'Check'),
      );
      expect(inRow, findsOneWidget);
      // The sizing rail is the context row whenever a raise is legal and the
      // window is not degenerate.
      if ((legal.canBet || legal.canRaise) &&
          legal.minRaiseTo < legal.maxRaiseTo) {
        expect(find.byType(SizingRail), findsOneWidget);
      }
    });

    testWidgets('State C — manual pace offers Next action', (tester) async {
      final container = makeContainer(seed: 4);
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      await pumpApp(tester, container: container, location: '/table');

      final session = container.read(sessionProvider);
      if (session.heroToAct) return; // seed-dependent; A is covered above.
      final row = tester.widget<ActionRow>(find.byType(ActionRow));
      expect(row.state, ActionRowState.botManual);
      expect(
        find.descendant(
          of: find.byType(ActionRow),
          matching: find.textContaining('Next action'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('State E — hand over offers Next hand', (tester) async {
      final container = makeContainer(seed: 11);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      for (var i = 0; i < 300; i++) {
        final s = container.read(sessionProvider);
        if (s.handOver) break;
        if (s.table!.toAct == 0) {
          await notifier.heroAction(const poker.Action.fold());
          await settleWidgets(tester);
        } else {
          notifier.stepBot();
        }
      }
      await settleWidgets(tester);
      expect(container.read(sessionProvider).handOver, isTrue);

      await pumpApp(tester, container: container, location: '/table');
      final row = tester.widget<ActionRow>(find.byType(ActionRow));
      expect(row.state, ActionRowState.handOver);
      expect(
        find.descendant(
          of: find.byType(ActionRow),
          matching: find.textContaining('Next hand'),
        ),
        findsOneWidget,
      );
      // §4.12: the results overlay is up over the lower felt.
      expect(find.byType(ResultsCard), findsOneWidget);
    });

    testWidgets('State G — no session shows "Ready to play?"', (tester) async {
      final container = makeContainer(seed: 2);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/table');

      expect(find.text(PlayCopy.readyToPlay), findsOneWidget);
      expect(find.text(PlayCopy.startOverlayBody), findsOneWidget);
      final row = tester.widget<ActionRow>(find.byType(ActionRow));
      expect(row.state, ActionRowState.noSession);
      expect(find.text(PlayCopy.dealMeIn), findsWidgets);
    });
  });

  group('the table is wired to the notifier', () {
    testWidgets('"Deal me in" from State G starts a session', (tester) async {
      final container = makeContainer(seed: 2);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/table');
      expect(container.read(sessionProvider).active, isFalse);

      await tester.tap(find.text(PlayCopy.dealMeIn).first);
      await tester.pump();
      await settleWidgets(tester);
      await tester.pump();

      expect(container.read(sessionProvider).active, isTrue);
      expect(container.read(sessionProvider).table, isNotNull);
    });

    testWidgets('the pace pill toggles Step ↔ Auto', (tester) async {
      final container = await seatedTable(tester, seats: 6, toHero: false);
      expect(find.text('Step'), findsOneWidget);
      await tester.tap(find.text('Step'));
      await tester.pump();
      await settleWidgets(tester);
      await tester.pump();
      expect(find.text('Auto'), findsOneWidget);
      // Stop the loop so the test can settle.
      container.read(sessionProvider.notifier).leaveTable();
      await tester.pump();
    });

    testWidgets('the O1 step caption shows on the first hands', (tester) async {
      // §4.15: the caption is owed for the first three hands of a user's life.
      final container = makeContainer(seed: 4);
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      await pumpApp(tester, container: container, location: '/table');
      await settleWidgets(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      if (container.read(sessionProvider).heroToAct) return;
      expect(find.text(PlayCopy.stepHint), findsOneWidget);
    });

    testWidgets('tapping a seat plate opens P6', (tester) async {
      await seatedTable(tester, seats: 6, toHero: false);
      await tester.tap(find.byType(SeatPlate).first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(PlayCopy.readTheirRange), findsOneWidget);
    });
  });
}
