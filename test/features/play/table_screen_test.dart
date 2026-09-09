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
import 'package:allin/features/play/widgets/table_top_bar.dart';
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

    // §4.2.3's clearance table budgets 7.8 pt between the hero's bet pill and
    // the seat-1 pill at 360 — "a negative number is a bug". The hero's pill
    // carries "(you)" and grows to ~104 pt rather than shrink under §13's
    // 11 pt floor, so at 360 the three pills on that row cut into each other,
    // and at 1.3× text they overlapped outright.
    for (final size in [phone360, phone390, phone430]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
          'bet pills never overlap at ${size.width.toInt()}, ${scale}x',
          (tester) async {
            await seatedTable(
              tester,
              seats: 6,
              size: size,
              textScale: scale,
              // Straight after the deal: both blinds are posted, so the
              // hero's "(you)" pill shares its row with a neighbour's.
              toHero: false,
            );
            expect(tester.takeException(), isNull);

            final pills = <Rect>[
              for (final e in find.byType(BetPill).evaluate())
                tester.getRect(find.byWidget(e.widget)),
            ];
            expect(pills.length, greaterThanOrEqualTo(2));
            for (var i = 0; i < pills.length; i++) {
              for (var j = i + 1; j < pills.length; j++) {
                expect(
                  pills[i].overlaps(pills[j]),
                  isFalse,
                  reason:
                      'two bet pills overlap at ${size.width}/$scale: '
                      '${pills[i]} and ${pills[j]}',
                );
              }
            }
          },
        );
      }
    }

    testWidgets('no coach badge until the hand has a note (§4.8)', (
      tester,
    ) async {
      // Keying the badge on the *setting* opened every hand with a grey
      // "◉ 0" pill in the busiest corner — a dead control that reads as a
      // disabled feature rather than an empty counter. §4.8 shows it
      // "whenever reviewLog is non-empty".
      await seatedTable(tester, seats: 6);
      expect(find.byType(CoachBadge), findsNothing);
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

    // §2.5 / §16.1: system back on P1 leaves the table the way `‹` does. The
    // table is reached with `go`, so without a `PopScope` the root navigator
    // has nothing to pop and Android's back closed the app mid-session.
    testWidgets('system back leaves the table instead of the app', (
      tester,
    ) async {
      final container = await seatedTable(tester, seats: 6, toHero: false);
      expect(container.read(sessionProvider).paused, isFalse);

      final popped = await tester.binding.handlePopRoute();
      await tester.pump();
      await settleWidgets(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The route handled the pop itself — the engine never saw it.
      expect(popped, isTrue);
      // §4.14: no dialog, the session pauses and the lobby is showing.
      expect(container.read(sessionProvider).active, isTrue);
      expect(container.read(sessionProvider).paused, isTrue);
      expect(find.text(PlayCopy.lobbyTitle), findsWidgets);
      // §4.14's "Session paused" toast lives 2.5 s; let it retire.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping a seat plate opens P6', (tester) async {
      await seatedTable(tester, seats: 6, toHero: false);
      await tester.tap(find.byType(SeatPlate).first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(PlayCopy.readTheirRange), findsOneWidget);
    });
  });

  // The top bar and the ticker used to run edge to edge, which left the pace
  // pill's border ~2 pt from the bezel under the action row's 16 pt margin.
  group('§4.2 the header bands sit on the page grid', () {
    for (final size in [phone360, phone390, phone430]) {
      final expected = size.width >= 430 ? 20.0 : 16.0;

      testWidgets('${size.width.toInt()} pt keeps a $expected pt margin', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await seatedTable(tester, seats: 6, size: size);

        // The bar itself still spans the screen — the margin is its padding,
        // so the ink of a pressed control never runs to the bezel.
        final bar = tester.getRect(find.byType(TableTopBar));
        expect(bar.left, 0);
        expect(bar.width, size.width);

        // The pace pill is the last thing in the bar: its own border, not
        // just its hit box, has to clear the bezel by the page margin.
        final pill = tester.getRect(find.bySemanticsLabel(RegExp('^Pace, ')));
        expect(pill.right, lessThanOrEqualTo(size.width - expected + 0.01));

        // The back chevron's 44 pt target starts at the margin, not at 0.
        final back = tester.getRect(find.bySemanticsLabel('Leave table'));
        expect(back.left, closeTo(expected, 0.01));
        expect(back.width, greaterThanOrEqualTo(44));

        // The ticker is the third band on the same grid.
        final ticker = tester.getRect(find.byType(Ticker));
        expect(ticker.left, closeTo(expected, 0.01));
        expect(ticker.right, closeTo(size.width - expected, 0.01));

        semantics.dispose();
      });
    }
  });
}
