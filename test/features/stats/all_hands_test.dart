/// T2 · All hands and P12 · Hand note editor (DESIGN.md §7.5, §7.6).
library;

import 'dart:io';

import 'package:allin/features/stats/providers/data_actions.dart';
import 'package:allin/features/stats/screens/all_hands_screen.dart';
import 'package:allin/engine/engine.dart' show Verdict;
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:allin/services/share_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stats_harness.dart';

/// One imported hand, written the way `persistImportedHands` stores them.
String _importedPayload({required int startedAt, required int id}) {
  final hand = sixMaxHand(startedAt: startedAt, id: id);
  final json = hand.toJson();
  json['imported'] = true;
  json['heroName'] = 'You';
  return encodeJsonMap(json);
}

void main() {
  testWidgets('every stored hand is listed, played and imported', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await fixture.addHand(sixMaxHand(startedAt: 1781838000000, id: 1));
    await fixture.addHand(sixMaxHand(startedAt: 1781838060000, id: 2));
    await fixture.addImported([
      _importedPayload(startedAt: 1781838120000, id: 3),
    ]);

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    expect(find.textContaining('Hand #1'), findsOneWidget);
    expect(find.textContaining('Hand #2'), findsOneWidget);
    expect(find.textContaining('Hand #3'), findsOneWidget);
    expect(find.text(StatsCopy.importedBadge), findsOneWidget);
  });

  testWidgets('a row names the hand by its cards and the coach\'s worst call', (
    tester,
  ) async {
    // A date and an amount do not say which hand this was, and nothing said
    // which rows the coach flagged. Both come out of the stored payload —
    // `holes[0]` and `hand_json.coachNotes[]` (§16.4).
    CoachNoteRecord note(String verdict) => CoachNoteRecord(
      street: 'flop',
      action: 'call',
      verdict: verdict,
      title: 'Your call',
      plain: 'plain',
    );

    final fixture = StatsFixture();
    await fixture.addHand(
      sixMaxHand(startedAt: 1781838000000, id: 1),
      coachNotes: [note('great'), note('mistake'), note('ok')],
    );
    await fixture.addHand(sixMaxHand(startedAt: 1781838060000, id: 2));

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // `sixMaxHand` deals the hero As Ks.
    expect(find.text('A♠ K♠'), findsNWidgets(2));

    final dots = tester.widgetList<VerdictDot>(find.byType(VerdictDot));
    expect(dots.length, 2);
    // Most recent first, so the uncoached hand #2 leads. The worst of hand
    // #1's three notes stands for it; the uncoached row still reserves the
    // dot's box so the column stays aligned.
    expect(dots.first.verdict, isNull);
    expect(dots.last.verdict, Verdict.mistake);
  });

  testWidgets('the source filter narrows the list', (tester) async {
    final fixture = StatsFixture();
    await fixture.addHand(sixMaxHand(startedAt: 1781838000000, id: 1));
    await fixture.addImported([
      _importedPayload(startedAt: 1781838120000, id: 3),
    ]);

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    await tester.tap(find.text(StatsCopy.filterImported));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hand #3'), findsOneWidget);
    expect(find.textContaining('Hand #1'), findsNothing);

    await tester.tap(find.text(StatsCopy.filterPlayed));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hand #1'), findsOneWidget);
    expect(find.textContaining('Hand #3'), findsNothing);
  });

  testWidgets('a hand row colours its result on the one money scale', (
    tester,
  ) async {
    // §13: a hand you folded for nothing is not a win. `netBb >= 0` painted
    // "+0.0 bb" in the win green. The row reads the hero's net out of the
    // stored hand, so the fixture sets it in chips (bb = 20).
    final fixture = StatsFixture();
    for (final (i, chips) in <num>[60, -40, 0].indexed) {
      final hand = sixMaxHand(startedAt: 1781838000000 + i * 60000, id: i + 1);
      hand.heroNet = chips;
      await fixture.addHand(hand);
    }

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    final colours = AllInColors.dark;
    Color? colourOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(colourOf('+3.0 bb'), colours.good);
    expect(colourOf('-2.0 bb'), colours.bad);
    expect(colourOf('+0.0 bb'), colours.textMuted);
  });

  testWidgets('no hands at all shows the desktop empty line', (tester) async {
    final fixture = StatsFixture();
    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.handsEmpty), findsOneWidget);
  });

  testWidgets('a tag filter that matches nothing has its own line', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await fixture.addHand(sixMaxHand(startedAt: 1781838000000, id: 1));
    // A note on a hand that is *not* in the list, so the tag exists but the
    // filtered list is empty.
    final notes = NotesRepository(fixture.store);
    await notes.setNote(999, note: 'somewhere else', tags: ['big pot']);

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    await tester.tap(find.text('big pot'));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.handsEmptyForTag), findsOneWidget);
  });

  testWidgets('P12 saves a note with a tag, then removes it', (tester) async {
    final fixture = StatsFixture();
    final hand = sixMaxHand(startedAt: 1781838000000, id: 1);
    await fixture.addHand(hand);

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(StatsCopy.addNoteAction));
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.noteTitle(1)), findsOneWidget);
    expect(find.text(StatsCopy.notePlaceholder), findsOneWidget);

    // Save is disabled until there is something to save.
    final save = find.widgetWithText(GestureDetector, StatsCopy.noteSave);
    expect(save, findsWidgets);

    await tester.enterText(
      find.byType(TextField).first,
      'called the river with a bluff-catcher',
    );
    await tester.pump();
    await tester.tap(find.text('review later'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(StatsCopy.noteSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StatsCopy.noteSave));
    await tester.pumpAndSettle();

    final stored = NotesRepository(fixture.store).noteFor(hand.startedAt);
    expect(stored, isNotNull);
    expect(stored!.tags, ['review later']);
    expect(stored.note, 'called the river with a bluff-catcher');

    // The row now shows the tag chip and the note text.
    expect(find.text('review later'), findsWidgets);

    // Reopen and remove.
    await tester.tap(find.bySemanticsLabel(StatsCopy.noteAction));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(StatsCopy.noteRemove));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StatsCopy.noteRemove));
    await tester.pumpAndSettle();

    expect(NotesRepository(fixture.store).noteFor(hand.startedAt), isNull);
  });

  testWidgets('swipe-left reveals Note and Export', (tester) async {
    final fixture = StatsFixture();
    final hand = sixMaxHand(startedAt: 1781838000000, id: 1);
    await fixture.addHand(hand);

    await pumpStats(tester, const AllHandsScreen(), fixture: fixture);
    await tester.pumpAndSettle();

    // A horizontal drag reveals the two actions; the vertical axis still
    // belongs to the page (§7.5, §12).
    await tester.drag(find.textContaining('Hand #1'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.swipeNote), findsOneWidget);
    expect(find.text(StatsCopy.swipeExport), findsOneWidget);

    // The revealed buttons are live, not decoration.
    await tester.tap(find.text(StatsCopy.swipeNote));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.noteTitle(1)), findsOneWidget);
  });

  test(
    'exporting one hand stages its text and opens the share sheet',
    () async {
      final fixture = StatsFixture();
      final adapter = FakeShareAdapter();
      final container = ProviderContainer(
        overrides: statsOverrides(fixture: fixture, share: adapter),
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(statsDataActionsProvider)
          .shareHand(sixMaxHand());
      expect(outcome, ShareOutcome.success);
      expect(adapter.files, hasLength(1));
      expect(
        File(adapter.files.single).readAsStringSync(),
        startsWith('PokerStars Hand #'),
      );
    },
  );

  group('renders in both themes at every width', () {
    for (final size in const [Size(360, 780), Size(430, 932)]) {
      for (final dark in const [true, false]) {
        testWidgets('${size.width.toInt()} dark=$dark', (tester) async {
          final fixture = StatsFixture();
          await fixture.addHand(sixMaxHand());
          await pumpStats(
            tester,
            const AllHandsScreen(),
            fixture: fixture,
            size: size,
            dark: dark,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(StatsCopy.allHandsTitle), findsOneWidget);
        });
      }
    }
  });
}
