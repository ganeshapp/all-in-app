/// P3 · P4 · P5 and "Explain last move" (DESIGN.md §4.8, §4.10).
///
/// The four things that must never regress: a blocking mistake pauses the hand
/// and cannot be scrimmed away, a non-blocking note is a chip that opens the
/// sheet, "View range" pushes P5 **inside** the sheet, and the badge's list
/// replaces itself with the note it was tapped on.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/coach_copy.dart';
import 'package:allin/features/play/widgets/coach_sheet.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/features/play/widgets/player_sheet.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/* -------------------------------------------------------------- fixtures */

const List<String> kBoard = <String>['7d', '2c', '9s', 'Kd', '3c'];

CoachReview callReview({
  int id = 1,
  bool blocking = true,
  Verdict verdict = Verdict.mistake,
  List<String>? steps,
  bool withRange = true,
}) => CoachReview(
  id: id,
  kind: ReviewKind.decision,
  blocking: blocking,
  verdict: verdict,
  title: 'Your call',
  equity: 0.17,
  potOdds: 0.25,
  evChips: -40,
  villainName: 'Ivey',
  villainArchetype: Archetype.tag,
  villainRange: withRange ? topPercentRange(15).toList() : null,
  board: kBoard,
  plain:
      'You paid 8 bb to win a pot of 24 bb — you need to win about 1 time in '
      '4. Your hand wins about 1 time in 6 — not enough.',
  text: 'Only 17 % equity against a range that needs 25 %.',
  steps: steps,
  expert: const <String>['The simulation ran 3 000 trials.'],
  opponents: 1,
  multiway: false,
);

CoachReview betReview({int id = 2}) => CoachReview(
  id: id,
  kind: ReviewKind.decision,
  blocking: false,
  verdict: Verdict.great,
  title: 'Your bet',
  board: const <String>['7d', '2c', '9s'],
  plain: 'Betting with the goods on a wet board — good.',
  text: 'Value bet.',
);

CoachSheetRequest request(
  CoachReview review, {
  List<CoachReview>? notes,
  int? handNumber,
  CoachSheetPage? initialPage,
}) => CoachSheetRequest(
  review: review,
  bigBlind: 20,
  heroCards: const <String>['Qs', 'Qh'],
  notes: notes,
  handNumber: handNumber,
  initialPage: initialPage,
);

/// Pumps a host screen with one "open" button and taps it.
Future<void> pumpHost(
  WidgetTester tester, {
  required ProviderContainer container,
  required void Function(BuildContext context) onOpen,
  Size size = phone390,
  double textScale = 1.0,
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
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            ),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Center(
                  child: TextButton(
                    onPressed: () => onOpen(context),
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Pumps a host screen and opens P3 on it.
Future<void> pumpSheet(
  WidgetTester tester, {
  required ProviderContainer container,
  required CoachSheetRequest req,
  Size size = phone390,
  double textScale = 1.0,
  bool dark = true,
}) => pumpHost(
  tester,
  container: container,
  size: size,
  textScale: textScale,
  dark: dark,
  onOpen: (context) => defaultCoachSheet(context, req),
);

/// The hero's action for the spot the seeded table stopped on.
poker.Action heroCall(ProviderContainer container) {
  final legal = container.read(sessionProvider).legal!;
  return legal.toCall > 0
      ? const poker.Action.call()
      : const poker.Action.check();
}

/// Scrolls [finder] into the sheet's viewport before tapping it.
Future<void> tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('P3 · a blocking mistake (§4.8)', () {
    testWidgets('opens with "Got it", no grabber, and ignores the scrim', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(tester, container: container, req: request(callReview()));

      expect(find.byType(CoachNoteView), findsOneWidget);
      expect(find.text(CoachCopy.gotIt), findsOneWidget);

      final sheet = tester.widget<AllInSheet>(find.byType(AllInSheet));
      expect(sheet.blocking, isTrue);
      expect(sheet.showGrabber, isFalse);
      expect(sheet.dismissible, isFalse);

      // A scrim tap must not dismiss an acknowledgement (§2.4, §2.5).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(CoachNoteView), findsOneWidget);

      // The sheet is at M and the note is taller than that, so the
      // acknowledgement is one scroll down — it is still the only way out.
      await tapIn(tester, find.text(CoachCopy.gotIt));
      expect(find.byType(CoachNoteView), findsNothing);
    });

    testWidgets('shows the verdict, layer 1 and the equity bar', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(tester, container: container, req: request(callReview()));

      expect(find.text('Mistake'), findsOneWidget);
      expect(find.text('EV Coach · Your call · River'), findsOneWidget);
      expect(find.byType(EquityBar), findsOneWidget);
      expect(
        find.textContaining('you need to win about 1 time in 4'),
        findsOneWidget,
      );
      // The EV tile prints evChips / bb.
      expect(find.text('-2.0 bb'), findsOneWidget);
    });
  });

  group('P3 · a non-blocking note', () {
    testWidgets('closes on "Close" and on a scrim tap', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(callReview(blocking: false, verdict: Verdict.thin)),
      );

      final sheet = tester.widget<AllInSheet>(find.byType(AllInSheet));
      expect(sheet.blocking, isFalse);
      expect(sheet.showGrabber, isTrue);
      expect(find.text(CoachCopy.close), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(CoachNoteView), findsNothing);
    });

    testWidgets('both disclosure rows open to a written line (§14)', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(callReview(blocking: false)),
      );

      await tapIn(tester, find.text(CoachCopy.showMath));
      expect(find.text(CoachCopy.noMathVerdict), findsOneWidget);

      await tapIn(tester, find.text(CoachCopy.expertDetail));
      expect(find.text('The simulation ran 3 000 trials.'), findsOneWidget);
    });
  });

  group('P5 · the assumed range, inside the sheet (§4.8)', () {
    testWidgets('View range shows the matrix, the combos and comes back', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(callReview(blocking: false)),
      );

      await tapIn(tester, find.text(CoachCopy.viewRange));

      expect(find.text("Ivey's assumed range"), findsOneWidget);
      expect(find.text(CoachSheetCopy.assumedRangeBody), findsOneWidget);
      expect(find.byType(RangeMatrix), findsOneWidget);
      expect(find.byType(RangeLegend), findsOneWidget);

      final combos = combosInSet(topPercentRange(15));
      expect(
        find.textContaining('$combos combos'),
        findsOneWidget,
        reason: 'the footer counts the range the coach used',
      );

      // The back chevron returns to the note.
      await tapIn(tester, find.text("Ivey's assumed range"));
      expect(find.byType(CoachNoteView), findsOneWidget);
      expect(find.byType(RangeMatrix), findsNothing);
    });

    testWidgets('a note with no range has no View range button', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(callReview(blocking: false, withRange: false)),
      );
      expect(find.text(CoachCopy.viewRange), findsNothing);
    });
  });

  group('P4 · the hand\'s notes (§4.8)', () {
    testWidgets('opens on the list and a row replaces it with that note', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(
          callReview(blocking: false),
          notes: <CoachReview>[callReview(blocking: false), betReview()],
          handNumber: 12,
        ),
      );

      // No live chip (`activeReviewId` is null) and more than one note, so the
      // badge's entry is the list.
      expect(find.text('Coach notes · Hand #12'), findsOneWidget);
      expect(find.byType(CoachNotesList), findsOneWidget);
      expect(find.text('Your bet · Flop'), findsOneWidget);

      await tapIn(tester, find.text('Your bet · Flop'));
      expect(find.byType(CoachNoteView), findsOneWidget);
      expect(find.text('Nice play'), findsOneWidget);

      // …and the back chevron returns to the list.
      await tapIn(tester, find.text('Coach notes · Hand #12'));
      expect(find.byType(CoachNotesList), findsOneWidget);
    });

    testWidgets('one note opens the note, with a row up to the list', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(
          callReview(blocking: false),
          notes: <CoachReview>[callReview(blocking: false)],
          handNumber: 3,
        ),
      );
      expect(find.byType(CoachNoteView), findsOneWidget);
      expect(find.byType(CoachNotesList), findsNothing);
    });

    testWidgets('a blocking note never offers the list', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(
          callReview(),
          notes: <CoachReview>[callReview(), betReview()],
          handNumber: 12,
        ),
      );
      expect(find.byType(CoachNoteView), findsOneWidget);
      expect(find.text(CoachSheetCopy.allNotes(2)), findsNothing);
    });
  });

  group('§4.10 · Explain last move', () {
    testWidgets('a bot read reads as a read, with the blurb at layer 3', (
      tester,
    ) async {
      final container = makeContainer(coachEnabled: true);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      notifier.stepBot();
      await settleWidgets(tester);
      notifier.explainLastBotMove();

      final log = container.read(sessionProvider).reviewLog;
      expect(log, isNotEmpty, reason: 'interpretBot produced a note');
      final read = log.last;
      expect(read.kind, ReviewKind.bot);

      await pumpSheet(tester, container: container, req: request(read));

      expect(find.textContaining('Bot read · '), findsOneWidget);
      expect(find.text(read.text), findsOneWidget);

      await tapIn(tester, find.text(CoachCopy.showMath));
      expect(find.text(CoachCopy.noMathRead), findsOneWidget);

      await tapIn(tester, find.text(CoachCopy.expertDetail));
      final blurb = kArchetypes[read.villainArchetype]!.blurb;
      expect(find.text(blurb), findsOneWidget);
    });
  });

  group('§4.8 · the live table', () {
    testWidgets('a blocking mistake pauses the loop and opens P3 itself', (
      tester,
    ) async {
      // Seed 2 reaches the hero with a call that the coach grades as a
      // blocking mistake — the only verdict that stops the hand.
      final container = makeContainer(seed: 2, coachEnabled: true);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      stepToHero(notifier, () => container.read(sessionProvider));
      expect(container.read(sessionProvider).heroToAct, isTrue);

      await pumpApp(tester, container: container, location: '/table');
      await tester.runAsync(() => notifier.heroAction(heroCall(container)));
      await settleWidgets(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final session = container.read(sessionProvider);
      expect(session.reviewLog, isNotEmpty);
      expect(session.reviewLog.last.blocking, isTrue);
      // §4.8: the loop pauses the moment the verdict lands.
      expect(session.paused, isTrue);
      expect(session.loopBlocked, isTrue);

      // …and the sheet opened itself, blocking.
      expect(find.byType(CoachNoteView), findsOneWidget);
      final sheet = tester.widget<AllInSheet>(find.byType(AllInSheet));
      expect(sheet.blocking, isTrue);

      // A scrim tap does nothing; "Got it" resumes the hand.
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CoachNoteView), findsOneWidget);

      await tester.ensureVisible(find.text(CoachCopy.gotIt));
      await tester.pump();
      await tester.tap(find.text(CoachCopy.gotIt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CoachNoteView), findsNothing);
      expect(container.read(sessionProvider).paused, isFalse);
    });

    testWidgets('a non-blocking note is a chip, and the chip opens P3', (
      tester,
    ) async {
      // Seed 1's call is a "Reasonable" verdict: a chip, not a pause.
      final container = makeContainer(seed: 1, coachEnabled: true);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      stepToHero(notifier, () => container.read(sessionProvider));
      expect(container.read(sessionProvider).heroToAct, isTrue);

      await pumpApp(tester, container: container, location: '/table');
      await tester.runAsync(() => notifier.heroAction(heroCall(container)));
      await settleWidgets(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final session = container.read(sessionProvider);
      expect(session.reviewLog, isNotEmpty);
      expect(session.reviewLog.last.blocking, isFalse);
      expect(session.paused, isFalse);
      expect(find.byType(CoachNoteView), findsNothing);

      expect(find.byType(CoachChip), findsOneWidget);
      await tester.tap(find.byType(CoachChip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CoachNoteView), findsOneWidget);
    });
  });

  group('P6 · the player sheet (§4.3)', () {
    Future<ProviderContainer> seated(WidgetTester tester) async {
      final container = makeContainer(seed: 5);
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);
      return container;
    }

    testWidgets('names the archetype, explains the HUD, opens the read', (
      tester,
    ) async {
      final container = await seated(tester);
      final table = container.read(sessionProvider).table!;
      final player = table.players[1];
      PlayerSheetResult? result;

      await pumpHost(
        tester,
        container: container,
        onOpen: (context) async {
          result = await PlayerSheet.show(
            context,
            player: player,
            seats: 6,
            bigBlind: table.bigBlind,
            canRead: true,
            canExplain: false,
          );
        },
      );

      final config = kArchetypes[player.archetype]!;
      expect(find.textContaining(config.name), findsOneWidget);
      expect(find.text(config.blurb), findsOneWidget);
      // Under 8 observed hands the HUD is "–" and reads are earned.
      expect(
        find.text(PlayCopy.readsAreEarned(player.handsSeen)),
        findsOneWidget,
      );
      expect(find.text(PlayCopy.explainTheirLastMove), findsNothing);

      await tapIn(tester, find.text(PlayCopy.readTheirRange));
      expect(result, PlayerSheetResult.readRange);
    });

    testWidgets('hand over disables the read and says why (§14)', (
      tester,
    ) async {
      final container = await seated(tester);
      final table = container.read(sessionProvider).table!;

      await pumpHost(
        tester,
        container: container,
        onOpen:
            (context) => PlayerSheet.show(
              context,
              player: table.players[1],
              seats: 6,
              bigBlind: table.bigBlind,
              canRead: false,
              canExplain: true,
              handOver: true,
            ),
      );

      expect(find.text(PlayCopy.handOverReadsReopen), findsOneWidget);
      expect(find.text(PlayCopy.explainTheirLastMove), findsOneWidget);
    });
  });

  group('the sheet renders everywhere', () {
    for (final size in <Size>[phone360, phone390, phone430]) {
      testWidgets('at ${size.width.toInt()}', (tester) async {
        final container = makeContainer();
        addTearDown(container.dispose);
        await pumpSheet(
          tester,
          container: container,
          req: request(callReview(blocking: false)),
          size: size,
        );
        expect(tester.takeException(), isNull);
        await tapIn(tester, find.text(CoachCopy.viewRange));
        expect(tester.takeException(), isNull);
        expect(find.byType(RangeMatrix), findsOneWidget);
      });
    }

    testWidgets('in the light theme at 1.3× text', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        container: container,
        req: request(callReview(blocking: false)),
        size: phone360,
        textScale: 1.3,
        dark: false,
      );
      expect(tester.takeException(), isNull);
      await tapIn(tester, find.text(CoachCopy.viewRange));
      expect(tester.takeException(), isNull);
    });
  });
}
