/// T3 · Import hands (DESIGN.md §7.8,
/// `docs/port/persistence-stats-settings.md` §11.5): the desktop's order of
/// operations, the verbatim summary, the Review-queue hand-off and every
/// failure path.
library;

import 'dart:io';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/providers/import_provider.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/features/stats/sample_hand.dart';
import 'package:allin/features/stats/screens/progress_screen.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stats_harness.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  test('a desktop fixture imports, is stored, and files its leak', () async {
    final fixture = StatsFixture();
    final container = ProviderContainer(
      overrides: statsOverrides(fixture: fixture),
    );
    addTearDown(container.dispose);

    await container
        .read(importProvider.notifier)
        .importText(_fixture('hh_import_bad_call.txt'), fileName: 'bad.txt');

    final state = container.read(importProvider);
    expect(state.phase, ImportPhase.done);
    expect(state.hands, 1);
    expect(state.skipped, 0);
    // The analyser reviews the one hero call and flags it (§11.4's worked
    // example: 72o calling 99 bb needing 50 %).
    expect(state.reviewed, 1);
    expect(state.leaks, 1);

    // The verbatim §11.5 summary.
    expect(
      state.summary,
      importSummaryText(hands: 1, skipped: 0, reviewed: 1, leaks: 1),
    );
    expect(
      state.summary,
      contains('Imported hands never count toward your play stats.'),
    );

    // Stored, badged, and outside the play stats.
    final hands = await container
        .read(handsRepositoryProvider)
        .recentHands(limit: 50);
    expect(hands, hasLength(1));
    expect(hands.single.imported, isTrue);
    final snapshot = await container.read(statsRepositoryProvider).loadStats();
    expect(snapshot.handsPlayed, 0);

    // And the spot is in the Review queue.
    expect(container.read(leakQueueStoreProvider).load(), hasLength(1));
  });

  test('a file with no hands changes nothing', () async {
    final fixture = StatsFixture();
    final container = ProviderContainer(
      overrides: statsOverrides(fixture: fixture),
    );
    addTearDown(container.dispose);

    await container
        .read(importProvider.notifier)
        .importText('not a hand history at all', fileName: 'junk.txt');

    final state = container.read(importProvider);
    expect(state.phase, ImportPhase.failed);
    expect(state.failure, ImportFailure.noHands);
    final hands = await container
        .read(handsRepositoryProvider)
        .recentHands(limit: 50);
    expect(hands, isEmpty);
  });

  test('the exported sample parses back through the importer', () {
    final text = sampleHandHistory();
    final parsed = parsePokerStars(text);
    expect(parsed.skipped, 0);
    expect(parsed.hands, hasLength(1));
    expect(parsed.hands.single.seats, hasLength(6));
  });

  testWidgets('the Data row runs the flow and shows the result sheet', (
    tester,
  ) async {
    final fixture = StatsFixture();
    final picker = fakePicker(contents: _fixture('hh_import_bad_call.txt'));
    await pumpStats(
      tester,
      const ProgressScreen(),
      fixture: fixture,
      files: picker,
    );
    await tester.pumpAndSettle();

    final row = find.text(StatsCopy.importButton);
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      find.text(importSummaryText(hands: 1, skipped: 0, reviewed: 1, leaks: 1)),
      findsOneWidget,
    );
    expect(find.text(StatsCopy.importSeeHands), findsOneWidget);
    // A leak was filed, so "Review now" is offered (§7.8 step 3).
    expect(find.text(StatsCopy.importReviewNow), findsOneWidget);

    // The S sheet caps at 40 % of the viewport and scrolls; "Done" is the
    // last row (§2.4).
    await tester.ensureVisible(find.text(StatsCopy.importDone));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StatsCopy.importDone));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.importSeeHands), findsNothing);
  });

  testWidgets('a file with no hands offers the sample instead', (tester) async {
    final fixture = StatsFixture();
    final picker = fakePicker(contents: 'nothing here');
    await pumpStats(
      tester,
      const ProgressScreen(),
      fixture: fixture,
      files: picker,
    );
    await tester.pumpAndSettle();

    final row = find.text(StatsCopy.importButton);
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.importNoHands), findsOneWidget);
    expect(find.text(StatsCopy.importExportSample), findsOneWidget);

    await tester.ensureVisible(find.text(StatsCopy.importOk));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StatsCopy.importOk));
    await tester.pumpAndSettle();
    expect(find.text(StatsCopy.importNoHands), findsNothing);
  });

  testWidgets('cancelling the picker shows nothing at all', (tester) async {
    final fixture = StatsFixture();
    await pumpStats(
      tester,
      const ProgressScreen(),
      fixture: fixture,
      files: fakePicker(),
    );
    await tester.pumpAndSettle();

    final row = find.text(StatsCopy.importButton);
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text(StatsCopy.importSeeHands), findsNothing);
    expect(find.text(StatsCopy.importNoHands), findsNothing);
    expect(find.text(StatsCopy.importReading), findsNothing);
  });
}
