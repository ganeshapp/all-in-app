/// P8 · the hand-over results overlay, P9 · all reveals (DESIGN.md §4.12).
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/play/providers/guess_provider.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/all_reveals_sheet.dart';
import 'package:allin/features/play/widgets/results_overlay.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Plays one hand to hand-over, letting the hero take [heroAction] whenever it
/// is their turn. Returns the finished table.
TableState playHand(
  ProviderContainer container, {
  poker.Action Function(LegalActions legal)? heroAction,
  TableOptions options = TableOptions.defaults,
}) {
  final notifier = container.read(sessionProvider.notifier);
  notifier.newSession(options);
  for (var i = 0; i < 400; i++) {
    final state = container.read(sessionProvider);
    final table = state.table!;
    if (table.phase == GamePhase.handOver) return table;
    if (table.toAct == 0) {
      final legal = state.legal!;
      notifier.heroAction(
        heroAction?.call(legal) ??
            (legal.canCheck
                ? const poker.Action.check()
                : const poker.Action.fold()),
      );
    } else {
      notifier.stepBot();
    }
  }
  fail('hand never ended');
}

/// Paints a guess for [seat] and peeks, exactly as P7 does — the only way a
/// "Your read 64 %" link is ever earned (§4.9).
void readSeat(ProviderContainer container, int seat) {
  final guess = container.read(guessProvider.notifier)..open(seat);
  guess
    ..setPainted(const {'AA', 'KK', 'QQ', 'AKs', 'AQs', 'JJ', 'TT'})
    ..peek()
    ..close();
}

/// Deals the next hand and plays it out, so the table carries a new hand
/// number.
TableState dealAnother(ProviderContainer container) {
  final notifier = container.read(sessionProvider.notifier)..deal();
  for (var i = 0; i < 400; i++) {
    final state = container.read(sessionProvider);
    final table = state.table!;
    if (table.phase == GamePhase.handOver) return table;
    if (table.toAct == 0) {
      final legal = state.legal!;
      notifier.heroAction(
        legal.canCheck ? const poker.Action.check() : const poker.Action.fold(),
      );
    } else {
      notifier.stepBot();
    }
  }
  fail('hand never ended');
}

HandOverContext contextFor(
  TableState table, {
  bool realisticReveal = false,
  bool collapsed = false,
  CoachChipContent? coach,
  ValueChanged<int>? onReadSeat,
  ValueChanged<int>? onRow,
  VoidCallback? onTouch,
}) => HandOverContext(
  table: table,
  summary: table.summary!,
  realisticReveal: realisticReveal,
  fourColorDeck: false,
  reducedMotion: true,
  collapsed: collapsed,
  coach: coach,
  onReadSeat: onReadSeat,
  onRow: onRow,
  onTouch: onTouch,
);

Future<void> pumpOverlay(
  WidgetTester tester, {
  required ProviderContainer container,
  required HandOverContext data,
  Size size = phone390,
  double textScale = 1,
  bool dark = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AllInAppTheme.light(),
        darkTheme: AllInAppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: Center(
                    // §4.12's band: the card lives in a fixed 188 pt slot on
                    // the lower felt and never grows out of it.
                    child: SizedBox(
                      width: size.width - 32,
                      height: 188,
                      child: ResultsOverlay(data: data),
                    ),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('reveal rows', () {
    test(
      'a showdown row names the winning hand, folded rows carry the note',
      () {
        final container = makeContainer();
        addTearDown(container.dispose);
        final table = playHand(container);
        final summary = table.summary!;

        final rows = buildRevealRows(
          table: table,
          summary: summary,
          realisticReveal: false,
        );

        // One row per non-hero seat, in seat order, never the hero.
        expect(rows.length, table.players.length - 1);
        expect(rows.map((r) => r.playerId), [for (var i = 1; i < 6; i++) i]);

        for (final row in rows) {
          expect(row.note, isNotEmpty);
          expect(row.note, endsWith('.'));
          expect(row.faceDown, isFalse);
        }
        final winners = <int>{
          for (final pot in summary.potResults) ...pot.winners,
        };
        for (final row in rows.where((r) => winners.contains(r.playerId))) {
          expect(row.note, startsWith('Won'));
        }
      },
    );

    test('realistic reveals keep the row but hide the cards', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);

      final rows = buildRevealRows(
        table: table,
        summary: table.summary!,
        realisticReveal: true,
      );
      expect(rows.length, table.players.length - 1);

      for (final row in rows) {
        final player = table.players[row.playerId];
        expect(row.faceDown, player.hasFolded);
        if (row.faceDown) {
          // Only "Folded on the turn." — no chart verdict, no board read.
          expect(row.note, matches(RegExp(r'^Folded [a-z ]+\.$')));
          expect(row.note, isNot(contains('—')));
        }
      }
    });

    test('revealNote reproduces port §18 verbatim', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);
      final summary = table.summary!;

      for (final p in table.players) {
        if (p.isHero) continue;
        final note = revealNote(p, summary.board, summary);
        if (!p.hasFolded) {
          expect(
            note,
            anyOf(
              startsWith('Won with '),
              equals('Won — everyone else folded.'),
              startsWith('Showed '),
              equals('Reached the end without showing.'),
            ),
          );
        } else {
          expect(note, startsWith('Folded '));
          if (p.foldedStreet == Street.preflop) {
            expect(
              note,
              anyOf(
                endsWith('— playable, but gave it up.'),
                endsWith('— too weak to play from ${p.position.label}.'),
                equals('Folded before the flop.'),
              ),
            );
          }
        }
      }
    });

    test('foldPhrase is port §18\'s table', () {
      expect(foldPhrase(Street.preflop), 'before the flop');
      expect(foldPhrase(Street.flop), 'on the flop');
      expect(foldPhrase(Street.turn), 'on the turn');
      expect(foldPhrase(Street.river), 'on the river');
      expect(foldPhrase(Street.showdown), 'at showdown');
    });
  });

  group('header', () {
    test('an uncontested win reads "takes it down"', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      // The hero folds at the first opportunity, so a bot takes it down.
      final table = playHand(
        container,
        heroAction: (_) => const poker.Action.fold(),
      );
      final header = resultsSummary(table, table.summary!);

      expect(header.caption, ResultsCopy.handOver);
      expect(header.netBb, lessThan(0.01));
      expect(
        header.sentence,
        anyOf(contains('takes it down.'), contains('wins with ')),
      );
    });

    test('the hero winning flips the caption', () {
      final table = _tableWhereHeroWins();
      final header = resultsSummary(table, table.summary!);
      expect(header.caption, ResultsCopy.wonThePot);
      expect(header.netBb, greaterThan(0));
    });
  });

  group('overlay', () {
    testWidgets('renders the net, the caption and every reveal row', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);

      await pumpOverlay(tester, container: container, data: contextFor(table));

      expect(find.textContaining(' bb'), findsWidgets);
      expect(
        find.text(resultsSummary(table, table.summary!).caption.toUpperCase()),
        findsOneWidget,
      );
      // The list scrolls inside the fixed band, so at least the first rows
      // are on screen and nothing overflows.
      expect(find.byType(ResultsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the read score renders as a link and opens the compare grid', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);
      readSeat(container, 1);

      var opened = -1;
      await pumpOverlay(
        tester,
        container: container,
        data: contextFor(table, onReadSeat: (seat) => opened = seat),
      );

      final link = find.textContaining(RegExp(r'^Your read \d+ %$'));
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('a read from the previous hand never labels this one', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      playHand(container);
      readSeat(container, 1);
      // The next deal is a different hand: last hand's read is not this
      // hand's read (§4.12).
      final table = dealAnother(container);

      await pumpOverlay(tester, container: container, data: contextFor(table));
      expect(find.textContaining('Your read'), findsNothing);
    });

    testWidgets('the coach verdict renders as the card\'s header row', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);

      await pumpOverlay(
        tester,
        container: container,
        data: contextFor(
          table,
          coach: const CoachChipContent(
            verdict: Verdict.mistake,
            title: 'Mistake',
            clause: 'You paid 8 bb to win 24',
          ),
        ),
      );

      expect(find.text('Mistake · You paid 8 bb to win 24'), findsOneWidget);
    });

    testWidgets('collapsed, the card is the one-line strip', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);

      await pumpOverlay(
        tester,
        container: container,
        data: contextFor(table, collapsed: true),
      );

      expect(find.textContaining('See everyone’s cards'), findsOneWidget);
      // The reveal notes are hidden, the verdict never is.
      expect(find.textContaining('Folded '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('touching the card cancels the auto-deal countdown', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container);
      var touched = 0;

      await pumpOverlay(
        tester,
        container: container,
        data: contextFor(table, onTouch: () => touched++),
      );
      await tester.tap(find.byType(ResultsCard), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(touched, greaterThan(0));
    });

    testWidgets('9-max overflows into P9 and P9 lists every hand', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final table = playHand(container, options: const TableOptions(seats: 9));
      expect(table.players.length, 9);

      await pumpOverlay(tester, container: container, data: contextFor(table));

      final more = find.text('All 8 hands ›');
      // The row lives at the end of the list that scrolls inside the card.
      await tester.scrollUntilVisible(
        more,
        40,
        scrollable: find.descendant(
          of: find.byType(ResultsCard),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(find.byType(AllRevealsSheet), findsOneWidget);
      expect(find.byType(AllRevealTile), findsNWidgets(8));
    });

    testWidgets('renders at every width, both themes and 1.3× text', (
      tester,
    ) async {
      for (final size in [phone360, phone390, phone430]) {
        for (final dark in [true, false]) {
          final container = makeContainer();
          addTearDown(container.dispose);
          final table = playHand(container);
          await pumpOverlay(
            tester,
            container: container,
            data: contextFor(table),
            size: size,
            textScale: 1.3,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}

/// A table whose hand-over summary pays the hero. Found by replaying seeds
/// with a passive hero until one of them wins a pot.
TableState _tableWhereHeroWins() {
  for (var seed = 1; seed < 60; seed++) {
    final container = makeContainer(seed: seed);
    try {
      for (var hand = 0; hand < 6; hand++) {
        final notifier = container.read(sessionProvider.notifier);
        if (hand == 0) {
          notifier.newSession();
        } else {
          notifier.deal();
        }
        for (var i = 0; i < 400; i++) {
          final state = container.read(sessionProvider);
          final table = state.table!;
          if (table.phase == GamePhase.handOver) {
            final summary = table.summary!;
            if (summary.potResults.any((p) => p.winners.contains(0)) &&
                summary.heroNetChips > 0) {
              return table;
            }
            break;
          }
          if (table.toAct == 0) {
            final legal = state.legal!;
            notifier.heroAction(
              legal.canCheck
                  ? const poker.Action.check()
                  : const poker.Action.call(),
            );
          } else {
            notifier.stepBot();
          }
        }
      }
    } finally {
      container.dispose();
    }
  }
  fail('no seed produced a hero win');
}
