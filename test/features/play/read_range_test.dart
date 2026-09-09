/// P7 · Read range: Guess → Peek (DESIGN.md §4.9, port §12).
///
/// What must never regress: the painter renders at every supported width, a
/// painted guess is scored and recorded, an empty guess reveals the range and
/// records nothing, closing before Peek scores nothing, and the reveal fits
/// 390×844 and 360×780 without a single overflow.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/guess_provider.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/coach_copy.dart';
import 'package:allin/services/persistence/records.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// A seated 6-max table with the read modal open on seat 1.
Future<ProviderContainer> readingSeatOne(
  WidgetTester tester, {
  Size size = phone390,
  double textScale = 1.0,
  bool dark = true,
  int seed = 11,
}) async {
  final container = makeContainer(seed: seed);
  addTearDown(container.dispose);
  final notifier = container.read(sessionProvider.notifier);
  notifier.newSession(const TableOptions(seats: 6));
  await settleWidgets(tester);
  await pumpApp(
    tester,
    container: container,
    location: '/table/read/1',
    size: size,
    textScale: textScale,
    dark: dark,
  );
  return container;
}

String seatName(ProviderContainer container) =>
    container.read(sessionProvider).table!.players[1].name;

Future<List<GuessRecord>> guesses(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late List<GuessRecord> found;
  await tester.runAsync(() async {
    final snapshot = await container.read(statsRepositoryProvider).loadStats();
    found = snapshot.guesses;
  });
  return found;
}

void main() {
  group('the painter (§4.9)', () {
    testWidgets('names the seat, its context and paints', (tester) async {
      final container = await readingSeatOne(tester);
      final name = seatName(container);

      expect(find.text(CoachSheetCopy.readTitle(name)), findsOneWidget);
      expect(find.text(CoachSheetCopy.readSubtitle), findsOneWidget);
      // The chips are named where they are, not four lines above them.
      expect(find.text(CoachSheetCopy.presetsLabel), findsOneWidget);
      expect(find.byType(RangeMatrix), findsOneWidget);
      expect(find.byType(RangePresetRow), findsOneWidget);
      expect(find.text(CoachSheetCopy.guessingIsOptional), findsOneWidget);
      // Nothing painted yet: the primary button is the plain "Peek".
      expect(find.text(CoachSheetCopy.peekAndScore), findsNothing);

      final matrix = tester.widget<RangeMatrix>(find.byType(RangeMatrix));
      expect(matrix.mode, RangeMatrixMode.editable);
    });

    testWidgets('the context line names the archetype without its code', (
      tester,
    ) async {
      final container = await readingSeatOne(tester);
      final player = container.read(sessionProvider).table!.players[1];
      final config = kArchetypes[player.archetype!]!;

      final line = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.contains(config.name), orElse: () => '');

      expect(line, contains(config.name));
      // TONE.md: "(TAG)" / "(Station)" is layer-3 shorthand, not a subtitle.
      expect(line, isNot(contains('(${player.archetype!.label})')));
    });

    testWidgets('a preset paints, Clear empties and Undo brings it back', (
      tester,
    ) async {
      final container = await readingSeatOne(tester);
      final combos = combosInSet(topPercentRange(10));

      await tester.tap(find.text('Top 10 %'));
      await tester.pump();
      expect(container.read(guessProvider).painted, isNotEmpty);
      expect(find.textContaining('$combos combos'), findsOneWidget);
      expect(find.text(CoachSheetCopy.peekAndScore), findsOneWidget);

      await tester.tap(find.text(CoachSheetCopy.clear));
      await tester.pump();
      expect(container.read(guessProvider).painted, isEmpty);
      expect(find.text('Nothing painted yet'), findsOneWidget);
      // §4.9: Clear is one stroke, and the 3 s prompt says so.
      expect(find.text(CoachSheetCopy.clearedUndo), findsOneWidget);

      await tester.tap(find.text(CoachSheetCopy.undo).first);
      await tester.pump();
      expect(combosInSet(container.read(guessProvider).painted), combos);
    });
  });

  group('Peek (§4.9, port §12)', () {
    testWidgets('scores a painted guess and records one read', (tester) async {
      final container = await readingSeatOne(tester);
      final name = seatName(container);

      await tester.tap(find.text('25 %'));
      await tester.pump();
      await tester.tap(find.text(CoachSheetCopy.peekAndScore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final guess = container.read(guessProvider);
      expect(guess.revealed, isTrue);
      expect(guess.scored, isTrue);
      expect(guess.actual, isNotEmpty);
      expect(guess.score, isNotNull);

      // The grade word is the headline, and the percentage is not.
      expect(find.text(guess.grade!.label), findsOneWidget);
      expect(find.text(CoachSheetCopy.revealTitle(name)), findsOneWidget);
      expect(
        find.text(CoachSheetCopy.theirRange(guess.actualCombos)),
        findsOneWidget,
      );
      expect(find.text(CoachSheetCopy.continueLabel), findsOneWidget);
      expect(find.text(CoachSheetCopy.exactCardsAtHandOver), findsOneWidget);

      final matrix = tester.widget<RangeMatrix>(find.byType(RangeMatrix));
      expect(matrix.mode, RangeMatrixMode.compare);
      final legend = tester.widget<RangeLegend>(find.byType(RangeLegend));
      expect(legend.mode, RangeLegendMode.compare);

      // Layer 2 carries the desktop's own numbers.
      await tester.tap(find.text(CoachCopy.showMath));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Score: ${fmtPct(guess.score!.accuracy)}'),
        findsOneWidget,
      );

      await settleWidgets(tester);
      final recorded = await guesses(tester, container);
      expect(recorded, hasLength(1));
      expect(recorded.single.accuracy, closeTo(guess.score!.accuracy, 1e-9));
      expect(recorded.single.street, Street.preflop.label);
      // §4.12: the score is remembered for the seat, for the results card.
      expect(container.read(seatReadScoreProvider(1)), isNotNull);
    });

    testWidgets('an empty guess reveals the range and records nothing', (
      tester,
    ) async {
      final container = await readingSeatOne(tester);
      final name = seatName(container);

      await tester.tap(find.text(CoachSheetCopy.peek).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final guess = container.read(guessProvider);
      expect(guess.revealed, isTrue);
      expect(guess.scored, isFalse);
      expect(find.text(CoachSheetCopy.nothingPainted(name)), findsOneWidget);

      final matrix = tester.widget<RangeMatrix>(find.byType(RangeMatrix));
      expect(matrix.mode, RangeMatrixMode.readOnly);
      expect(matrix.highlight, isNotEmpty);

      await settleWidgets(tester);
      expect(await guesses(tester, container), isEmpty);
    });

    testWidgets('closing before Peek scores nothing (desktop parity)', (
      tester,
    ) async {
      final container = await readingSeatOne(tester);

      await tester.tap(find.text('25 %'));
      await tester.pump();
      expect(container.read(guessProvider).painted, isNotEmpty);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final guess = container.read(guessProvider);
      expect(guess.revealed, isFalse);
      expect(guess.painted, isEmpty, reason: 'the paint is forgotten');
      await settleWidgets(tester);
      expect(await guesses(tester, container), isEmpty);
    });

    testWidgets('Continue closes the modal', (tester) async {
      final container = await readingSeatOne(tester);
      await tester.tap(find.text(CoachSheetCopy.peek).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(CoachSheetCopy.continueLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RangeMatrix), findsNothing);
      expect(container.read(guessProvider).open, isFalse);
    });
  });

  group('it fits', () {
    for (final size in <Size>[phone360, phone390, phone430]) {
      testWidgets('the painter at ${size.width.toInt()}', (tester) async {
        await readingSeatOne(tester, size: size);
        expect(tester.takeException(), isNull);
        final matrix = tester.widget<RangeMatrix>(find.byType(RangeMatrix));
        // §4.9: the grid never exceeds the box it was given.
        expect(matrix.width, lessThanOrEqualTo(size.width - 8));
      });

      testWidgets('the reveal at ${size.width.toInt()}', (tester) async {
        await readingSeatOne(tester, size: size);
        await tester.tap(find.text('25 %'));
        await tester.pump();
        await tester.tap(find.text(CoachSheetCopy.peekAndScore));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        expect(find.text(CoachSheetCopy.continueLabel), findsOneWidget);
        expect(find.byType(RangeMatrix), findsOneWidget);
      });
    }

    testWidgets('the painter in the light theme at 1.3× text on 360', (
      tester,
    ) async {
      await readingSeatOne(tester, size: phone360, textScale: 1.3, dark: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('§14 · nothing to read', () {
    testWidgets('a deep link with no session offers a way out', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/table/read/1');

      expect(find.text(CoachSheetCopy.nothingToRead), findsOneWidget);
      expect(find.text(CoachSheetCopy.close), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
