/// D0 / D1 widget tests (DESIGN.md §5.1–§5.7).
///
/// The contract: the spot is on screen with its answer row under the thumb;
/// answering raises the feedback panel **without covering the board or the
/// hero's cards**; every verdict shape renders; Review mode swaps the strip
/// and shows the empty state with "Next due"; and the whole screen survives
/// 360 / 390 / 430 in both themes at 1.0× and 1.3× text.
library;

import 'dart:async';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/drills/content/drill_copy.dart';
import 'package:allin/features/drills/providers/drill_generator.dart';
import 'package:allin/features/drills/providers/drill_stores.dart';
import 'package:allin/features/drills/screens/drills_screen.dart';
import 'package:allin/features/drills/widgets/feedback_content.dart';
import 'package:allin/features/drills/widgets/review_empty.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drill_test_kit.dart';

const int _t0 = 1750000000000;

List<Override> _overrides({
  required Puzzle Function(DrillGenRequest) puzzle,
  KeyValueStore? store,
  Clock? clock,
  bool swipeHint = false,
}) {
  final kv = store ?? KeyValueStore.memory();
  if (!swipeHint) {
    // Retire the §5.2 hint so its 1.2 s timer never outlives a test.
    unawaited(kv.setString(kDrillSwipeHintKey, '$kDrillSwipeHintLimit'));
  }
  return [
    keyValueStoreProvider.overrideWithValue(kv),
    drillClockProvider.overrideWithValue(clock ?? Clock.system),
    drillGeneratorProvider.overrideWithValue(FakeDrillGenerator(puzzle)),
  ];
}

Future<void> _answer(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // The rating delta flies for 600 ms before the strip rolls (§11).
  await tester.pump(const Duration(milliseconds: 700));
}

/// Opens one of D1's two disclosure rows, scrolling the panel body first —
/// the compact detent scrolls its middle (§5.1).
Future<void> _openLayer(WidgetTester tester, String label) async {
  final row = find.text(label);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// The mode chips h-scroll; `Review` is off-screen at 390 (§5.1).
Future<void> _scrollToReviewChip(WidgetTester tester) async {
  await tester.drag(find.text(DrillMode.mixed.label), const Offset(-220, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the answer row clears the tab bar (§5.1)', (tester) async {
    // Regression: `AllInScaffold` runs `SafeArea(bottom: false)`, so the whole
    // §5.1 budget was laid out under the tab bar and the answer row — the only
    // way to answer a spot — was pushed off screen entirely.
    const inset = 96.0;
    const size = Size(390, 844);
    await pumpDrills(
      tester,
      const DrillsScreen(),
      size: size,
      bottomInset: inset,
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );

    expect(find.byType(AnswerRow), findsOneWidget);
    final box = tester.getRect(find.byType(AnswerRow));
    expect(
      box.bottom,
      lessThanOrEqualTo(size.height - inset),
      reason: 'the answer row must sit above the tab bar, not behind it',
    );
    expect(find.text('Fold'), findsOneWidget);
  });

  testWidgets('the spot renders with its chips, stats, scrubber and options', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );

    expect(find.text('Drills'), findsOneWidget);
    expect(find.text(DrillMode.mixed.label), findsOneWidget);
    expect(find.text(DrillMode.pushfold.label), findsOneWidget);
    await _scrollToReviewChip(tester);
    expect(find.text(DrillMode.leaks.label), findsOneWidget);
    expect(find.byType(DrillTable), findsOneWidget);
    expect(find.byType(FrameScrubber), findsOneWidget);
    expect(find.byType(AnswerRow), findsOneWidget);
    expect(find.text(DrillCopy.yourHand), findsOneWidget);
    expect(find.text('KQs'), findsOneWidget);
    expect(
      find.text(DrillCopy.sourceHeuristic.split(' · ').first),
      findsOneWidget,
    );
    expect(find.text('Fold'), findsOneWidget);
    expect(find.text('Call 8 bb'), findsOneWidget);
    expect(find.text('Raise to 24 bb'), findsOneWidget);
    // The spot opens on the decision frame (§5.2).
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.byType(FeedbackPanel), findsNothing);
  });

  testWidgets('a right answer raises D1 with the verdict, the rating delta '
      'and the three layers', (tester) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await _answer(tester, 'Call 8 bb');

    expect(find.byType(FeedbackPanel), findsOneWidget);
    expect(find.text(DrillCopy.correct), findsOneWidget);
    expect(find.text('+18'), findsOneWidget);
    // Layer 1 is the coach's own sentence, not the engine's expert wording
    // (TONE.md): counts, big blinds, no "equity" / "pot odds" / hand codes.
    expect(
      find.textContaining('you need to win about 1 time in 4'),
      findsOneWidget,
    );
    expect(
      find.textContaining('the call makes money'),
      findsNothing,
      reason: 'the engine string belongs to layer 2, not layer 1',
    );
    expect(find.text(DrillCopy.folding), findsOneWidget);
    expect(
      find.textContaining('Calling: +2.6 bb per try'),
      findsOneWidget,
      reason: 'the verbatim outcomes template',
    );
    expect(find.text(CoachCopy.showMath), findsOneWidget);
    expect(find.text(CoachCopy.expertDetail), findsOneWidget);
    expect(find.text(DrillCopy.nextPuzzle), findsOneWidget);
    expect(find.text(DrillCopy.drillFiveSimilar), findsOneWidget);
    expect(find.text('Pot Odds & EV'), findsOneWidget);
  });

  testWidgets('a wrong answer shows the verbatim EV-loss line', (tester) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await _answer(tester, 'Fold');

    expect(find.text(DrillCopy.notOptimal), findsOneWidget);
    expect(
      find.text(
        'That choice costs about 2.6 bb every time — a blunder-sized '
        'leak.',
      ),
      findsOneWidget,
    );
    expect(find.text('-6'), findsOneWidget, reason: 'the rating delta');
  });

  testWidgets('a chart spot with no numbers opens layer 2 to the placeholder', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(
        puzzle:
            (_) => testPuzzle(
              kind: PuzzleKind.rfi,
              source: PuzzleSource.chart,
              street: Street.preflop,
              board: const [],
              equity: null,
              potOdds: null,
              toCall: 0,
              best: DrillAction.raise,
              options: const [
                DrillOption(action: DrillAction.fold, label: 'Fold'),
                DrillOption(
                  action: DrillAction.raise,
                  label: 'Raise to 2.5 bb',
                  amount: 2.5,
                ),
              ],
            ),
      ),
    );
    expect(find.text(DrillCopy.sourceChart.split(' · ').first), findsOneWidget);
    await _answer(tester, 'Raise to 2.5 bb');

    expect(find.text(DrillCopy.correct), findsOneWidget);
    expect(find.text(DrillCopy.folding), findsNothing);
    await _openLayer(tester, CoachCopy.showMath);
    // A chart spot has no equity arithmetic, but it does have the engine's own
    // percentage sentence — that is exactly what layer 2 is for, so the
    // "no math here" placeholder no longer applies.
    expect(find.text(CoachCopy.noMathChartSpot), findsNothing);
    expect(
      find.textContaining('the call makes money'),
      findsOneWidget,
      reason: 'the engine wording leads layer 2',
    );
  });

  testWidgets('layer 3 opens to the grading range, and to its own line for a '
      'leak spot', (tester) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await _answer(tester, 'Call 8 bb');
    await _openLayer(tester, CoachCopy.expertDetail);

    expect(find.text(DrillCopy.rangeItWasGradedAgainst), findsOneWidget);
    expect(find.text('CO opening range — 100 bb baseline'), findsOneWidget);
    expect(find.byType(RangeMatrix), findsOneWidget);
  });

  testWidgets('a leak spot keeps layer 3 and explains why it is empty', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(
        puzzle:
            (_) => testPuzzle(
              kind: PuzzleKind.leak,
              gradeRange: null,
              gradeRangeTitle: null,
              lessonId: null,
              lessonTitle: null,
            ),
      ),
    );
    expect(find.text(DrillCopy.sourceLeak.split(' · ').first), findsOneWidget);
    await _answer(tester, 'Call 8 bb');
    await _openLayer(tester, CoachCopy.expertDetail);

    expect(find.text(DrillCopy.noRangeForLeak), findsOneWidget);
    expect(find.byType(RangeMatrix), findsNothing);
  });

  testWidgets('the compact detent shows there is more note below', (
    tester,
  ) async {
    // §5.3 lets the compact middle scroll, but a sentence that simply stopped
    // under the grabber read as a rendering fault. The fade + chevron says
    // there is more, and tapping it expands.
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await _answer(tester, 'Call 8 bb');
    await tester.pumpAndSettle();

    final chevron = find.descendant(
      of: find.byType(FeedbackPanel),
      matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
    );
    expect(chevron, findsOneWidget);

    final compactTop = tester.getTopLeft(find.byType(FeedbackPanel)).dy;
    await tester.tap(chevron);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(FeedbackPanel)).dy,
      lessThan(compactTop),
      reason: 'tapping the affordance expands the panel',
    );
    // Expanded, there is nothing below the fold to advertise.
    expect(chevron, findsNothing);
  });

  testWidgets('the rating delta says what it counts', (tester) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await _answer(tester, 'Fold');
    expect(
      find.descendant(
        of: find.byType(DrillFeedbackHeader),
        matching: find.text(DrillCopy.ratingUnit),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the compact panel never covers the board or the hero cards', (
    tester,
  ) async {
    // §5.3: compact top = hero-cards bottom + 8. The 411×914 column is the
    // one that used to lose: a flat 220 pt panel floor beat the anchor, so the
    // panel was pinned *above* the hero's hole cards and cut in half the one
    // hand the user is being graded on.
    for (final size in const [
      Size(360, 780),
      Size(390, 844),
      Size(411, 914),
      Size(430, 932),
    ]) {
      await pumpDrills(
        tester,
        const DrillsScreen(),
        size: size,
        overrides: _overrides(puzzle: (_) => testPuzzle()),
      );
      await _answer(tester, 'Call 8 bb');

      final panelTop = tester.getTopLeft(find.byType(FeedbackPanel)).dy;
      final boardBottom = tester.getBottomLeft(find.byType(BoardRow)).dy;
      expect(
        panelTop,
        greaterThan(boardBottom),
        reason: 'compact top = hero-cards bottom + 8 at ${size.width}',
      );

      // The hero's own cards are the lowest thing on the felt; nothing about
      // them may be behind the panel.
      final cards = find.descendant(
        of: find.byType(DrillTable),
        matching: find.byType(PlayingCardView),
      );
      expect(cards, findsWidgets);
      final cardsBottom = tester
          .widgetList<PlayingCardView>(cards)
          .indexed
          .map((e) => tester.getRect(cards.at(e.$1)).bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(
        panelTop,
        greaterThanOrEqualTo(cardsBottom),
        reason: 'the hero hole cards must clear the panel at ${size.width}',
      );

      // §5.3 pins the primary at every detent.
      expect(find.text(DrillCopy.nextPuzzle), findsOneWidget);
      expect(
        tester.getRect(find.text(DrillCopy.nextPuzzle)).bottom,
        lessThanOrEqualTo(size.height),
        reason: 'Next puzzle stays pinned on screen at ${size.width}',
      );
    }
  });

  testWidgets('the whole screen survives every width, theme and text scale', (
    tester,
  ) async {
    for (final size in const [Size(360, 780), Size(390, 844), Size(430, 932)]) {
      for (final dark in const [true, false]) {
        for (final scale in const [1.0, 1.3]) {
          await pumpDrills(
            tester,
            const DrillsScreen(),
            size: size,
            dark: dark,
            textScale: scale,
            overrides: _overrides(puzzle: (_) => testPuzzle()),
          );
          expect(find.byType(AnswerRow), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('push/fold spots carry the stacks strip; ICM adds the banner', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(
        puzzle:
            (_) => testPuzzle(
              kind: PuzzleKind.pushfold,
              source: PuzzleSource.chart,
              street: Street.preflop,
              heroPos: Position.sb,
              board: const [],
              pot: 1.5,
              toCall: 0.5,
              equity: null,
              potOdds: null,
              best: DrillAction.raise,
              options: const [
                DrillOption(action: DrillAction.fold, label: 'Fold'),
                DrillOption(
                  action: DrillAction.raise,
                  label: 'Shove 12 bb',
                  amount: 12,
                ),
              ],
              frames: const [
                DrillFrame(
                  text: '12 bb stacks. Blinds 0.5/1.',
                  street: Street.preflop,
                  board: [],
                  pot: 1.5,
                ),
                DrillFrame(
                  text: 'Folded to you in the SB with 12 bb. Shove or fold?',
                  street: Street.preflop,
                  board: [],
                  pot: 1.5,
                ),
              ],
            ),
      ),
    );

    expect(find.byType(StacksStrip), findsOneWidget);
    expect(
      find.text('Stacks 12 bb · Blinds 0.5/1 · Nash chip-EV, no antes'),
      findsOneWidget,
    );
    expect(find.text(DrillCopy.sourceNash.split(' · ').first), findsOneWidget);
    expect(find.byType(IcmBanner), findsNothing);
    expect(find.text('You · 12 bb'), findsOneWidget);
    expect(find.text('Fold'), findsOneWidget);
    expect(find.text('Shove 12 bb'), findsOneWidget);
  });

  testWidgets(
    'a hardware keyboard answers with 1/2/3 and advances with Enter',
    (tester) async {
      var dealt = 0;
      await pumpDrills(
        tester,
        const DrillsScreen(),
        overrides: _overrides(
          puzzle: (_) {
            dealt++;
            return testPuzzle(
              hole: dealt == 1 ? const ['Kh', 'Qh'] : const ['Ah', 'Jd'],
            );
          },
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text(DrillCopy.correct), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FeedbackPanel), findsNothing);
      expect(find.text('AJo'), findsOneWidget);
    },
  );

  testWidgets('Review mode replaces the strip and shows the empty state', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await ReviewQueueStore(store).addMiss(testPuzzle(), nowMs: _t0);
    await ReviewQueueStore(
      store,
    ).review('postflop-bet|KQs|As7d2c|BB', true, nowMs: _t0);

    await pumpDrills(
      tester,
      const DrillsScreen(mode: 'leaks'),
      overrides: _overrides(
        puzzle: (_) => testPuzzle(),
        store: store,
        clock: FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ReviewEmptyState), findsOneWidget);
    expect(find.text(DrillCopy.nothingDue), findsOneWidget);
    expect(find.text(DrillCopy.allScheduled(1)), findsOneWidget);
    expect(find.textContaining('Next due:'), findsOneWidget);
    expect(find.text(DrillCopy.playASession), findsOneWidget);
    expect(find.text(DrillCopy.drillMixed), findsOneWidget);
    expect(find.byType(AnswerRow), findsNothing);
  });

  testWidgets('Review with no cards ever uses the other verbatim body', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(mode: 'leaks'),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(DrillCopy.noSpotsYet), findsOneWidget);
    expect(find.text(DrillCopy.noSpotsBody), findsOneWidget);
    expect(find.textContaining('Next due:'), findsNothing);
  });

  testWidgets('a due card badges the Review chip and serves a spot', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await ReviewQueueStore(store).addMiss(testPuzzle(), nowMs: _t0);

    await pumpDrills(
      tester,
      const DrillsScreen(mode: 'leaks'),
      overrides: _overrides(
        puzzle: (_) => testPuzzle(),
        store: store,
        clock: FakeClock(DateTime.fromMillisecondsSinceEpoch(_t0)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await _scrollToReviewChip(tester);
    expect(find.text('1'), findsOneWidget, reason: 'the Review count pill');
    expect(find.byType(ReviewEmptyState), findsNothing);
    expect(find.byType(AnswerRow), findsOneWidget);

    // Review answers show a schedule line and no rating delta (§5.5).
    await _answer(tester, 'Call 8 bb');
    expect(find.text('Next in 1 day · 1 of 3'), findsOneWidget);
    expect(find.text(DrillCopy.drillFiveSimilar), findsNothing);
  });

  testWidgets('the mode blurb sheet (D4) opens from the header ⓘ', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text(DrillMode.mixed.blurb), findsOneWidget);
  });

  testWidgets('the frame list (D2) opens from a long-press on the pill', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await tester.longPress(find.text('3 / 3'));
    await tester.pumpAndSettle();

    expect(find.text(DrillCopy.handReplay.toUpperCase()), findsOneWidget);
    expect(find.text('Blinds posted (0.5/1 bb).'), findsOneWidget);
    await tester.tap(find.text('Blinds posted (0.5/1 bb).'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('the source pill opens its grading paragraph', (tester) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await tester.tap(find.text(DrillCopy.sourceHeuristic.split(' · ').first));
    await tester.pumpAndSettle();

    expect(find.text(DrillCopy.gradingPostflop), findsOneWidget);
  });
  testWidgets('exploit spots show both numbers and ring the named seat', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(
        puzzle:
            (_) => testPuzzle(
              kind: PuzzleKind.exploit,
              street: Street.river,
              heroPos: Position.btn,
              board: const ['As', '7d', '2c', '9h', 'Ts'],
              pot: 9,
              toCall: 0,
              equity: 0.65,
              potOdds: null,
              gradeRange: const ['AKs'],
              gradeRangeTitle: 'What a Station calls a river bet with (~60%)',
              lessonId: 'exploits',
              lessonTitle: 'Exploiting the Archetypes',
              best: DrillAction.bet,
              options: const [
                DrillOption(action: DrillAction.check, label: 'Check back'),
                DrillOption(
                  action: DrillAction.bet,
                  label: 'Bet 5.4',
                  amount: 5.4,
                ),
              ],
              rationale:
                  'THE EXPLOIT: vs a balanced player your KQs (48% vs a sane '
                  'calling range) is a check.',
              frames: const [
                DrillFrame(
                  text:
                      'The BB is a CALLING STATION (calls ~60% of hands to '
                      'the river). You bet flop and turn; they called both.',
                  street: Street.preflop,
                  board: [],
                  pot: 5,
                ),
                DrillFrame(
                  text: 'River: As 7d 2c 9h Ts (pot 9 bb). The Station checks.',
                  street: Street.river,
                  board: ['As', '7d', '2c', '9h', 'Ts'],
                  pot: 9,
                ),
              ],
            ),
      ),
    );

    expect(
      find.text(DrillCopy.sourceExploit.split(' · ').first),
      findsOneWidget,
    );
    expect(find.text('46/7'), findsOneWidget, reason: "the Station's HUD");

    await _answer(tester, 'Bet 5.4');
    await _openLayer(tester, CoachCopy.showMath);
    expect(find.text(DrillCopy.balancedLine(48)), findsOneWidget);
    expect(find.text(DrillCopy.exploitLine(65)), findsOneWidget);
  });

  testWidgets('ICM bubble spots add the banner and the live stacks', (
    tester,
  ) async {
    const scenario = 'Even bubble';
    final icm = testPuzzle(
      kind: PuzzleKind.pushfold,
      source: PuzzleSource.chart,
      street: Street.preflop,
      heroPos: Position.sb,
      board: const [],
      pot: 1.5,
      toCall: 0.5,
      equity: null,
      potOdds: null,
      icm: true,
      best: DrillAction.raise,
      options: const [
        DrillOption(action: DrillAction.fold, label: 'Fold'),
        DrillOption(
          action: DrillAction.raise,
          label: 'Shove 25 bb',
          amount: 25,
        ),
      ],
      frames: const [
        DrillFrame(
          text:
              '$scenario — stacks: you (SB) 25 bb, BB 25 bb, '
              'others 25/25 bb.',
          street: Street.preflop,
          board: [],
          pot: 1.5,
        ),
        DrillFrame(
          text: 'Folded to you in the SB. Shove or fold?',
          street: Street.preflop,
          board: [],
          pot: 1.5,
        ),
      ],
    );
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => icm),
    );

    expect(find.byType(IcmBanner), findsOneWidget);
    expect(find.text(scenario), findsOneWidget);
    expect(find.text(DrillCopy.sourceIcm.split(' · ').first), findsOneWidget);
    expect(find.text('You · 25 bb'), findsOneWidget);
    expect(find.text('25 bb'), findsOneWidget, reason: "the BB's live stack");

    // The banner is two lines of type: it must not be clamped at 1.3×.
    await pumpDrills(
      tester,
      const DrillsScreen(),
      size: const Size(360, 780),
      textScale: 1.3,
      overrides: _overrides(puzzle: (_) => icm),
    );
    expect(find.byType(IcmBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the swipe hint shows on the first spots, then retires', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: _overrides(
          puzzle: (_) => testPuzzle(),
          store: store,
          swipeHint: true,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AllInAppTheme.dark(),
          home: const DrillsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(DrillCopy.swipeHint), findsOneWidget);
    expect(DrillHintStore(store).shown(), 1);

    // 1.2 s later it is gone and never comes back for that spot.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text(DrillCopy.swipeHint), findsNothing);

    // Past the fifth spot the hint is retired for good.
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(
        puzzle: (_) => testPuzzle(),
        store: KeyValueStore.memory({
          kDrillSwipeHintKey: '$kDrillSwipeHintLimit',
        }),
        swipeHint: true,
      ),
    );
    expect(find.text(DrillCopy.swipeHint), findsNothing);
  });

  testWidgets('the panel is inert: tapping the table never dismisses the '
      'verdict', (tester) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await _answer(tester, 'Call 8 bb');
    expect(find.byType(FeedbackPanel), findsOneWidget);

    await tester.tapAt(const Offset(195, 260));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackPanel), findsOneWidget);
    expect(find.text(DrillCopy.correct), findsOneWidget);
  });

  testWidgets('Next deals the following spot and clears the panel', (
    tester,
  ) async {
    var dealt = 0;
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(
        puzzle: (_) {
          dealt++;
          return testPuzzle(
            hole: dealt == 1 ? const ['Kh', 'Qh'] : const ['Ah', 'Jd'],
          );
        },
      ),
    );
    await _answer(tester, 'Call 8 bb');
    await tester.tap(find.text(DrillCopy.nextPuzzle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FeedbackPanel), findsNothing);
    expect(find.text('AJo'), findsOneWidget);
  });

  testWidgets('the Rating stat opens D3 with its verbatim tooltip', (
    tester,
  ) async {
    await pumpDrills(
      tester,
      const DrillsScreen(),
      overrides: _overrides(puzzle: (_) => testPuzzle()),
    );
    await tester.tap(find.textContaining('Rating'));
    await tester.pumpAndSettle();

    expect(find.text(DrillCopy.ratingTooltip), findsOneWidget);
    expect(find.text(CoachCopy.showMath), findsOneWidget);
    expect(find.text(CoachCopy.expertDetail), findsOneWidget);
    expect(find.text(DrillCopy.ratingNoTrend), findsOneWidget);
  });
}
