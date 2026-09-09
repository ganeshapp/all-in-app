/// P2 · Session sheet (§4.11 / §4.13) — the hand list.
///
/// The rows used to be "#4   +0.0 bb   ▶ ✎" and nothing else: after 60 hands
/// there was no way to find the hand you wanted to re-examine, and the coach's
/// own verdicts — the whole reason to re-examine one — were not in the list at
/// all. Each row now carries the hero's cards and a verdict dot.
library;

import 'package:allin/engine/engine.dart' as engine;
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/session_sheet.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Every dot painted in the sheet, by colour.
Set<Color?> _dots(WidgetTester tester) =>
    tester
        .widgetList<Container>(find.byType(Container))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .map((d) => d.color)
        .toSet();

void main() {
  testWidgets('a hand the coach flagged carries its verdict colour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = makeContainer(coachEnabled: true);
    addTearDown(container.dispose);
    final notifier = container.read(sessionProvider.notifier);

    // A handful of finished hands, at least one of them flagged.
    notifier.newSession(const TableOptions(seats: 6));
    await settleWidgets(tester);
    for (var hand = 0; hand < 6; hand++) {
      final state = container.read(sessionProvider);
      for (
        var i = 0;
        i < 60 && !container.read(sessionProvider).handOver;
        i++
      ) {
        if (container.read(sessionProvider).activeReview?.blocking ?? false) {
          notifier.dismissReview();
          continue;
        }
        if (container.read(sessionProvider).table?.toAct == 0) {
          final legal = container.read(sessionProvider).legal;
          if (legal == null) break;
          await notifier.heroAction(
            legal.canCheck
                ? const engine.Action.check()
                : const engine.Action.call(),
          );
        } else {
          notifier.stepBot();
        }
        await settleWidgets(tester);
      }
      expect(state, isNotNull);
      if (!container.read(sessionProvider).handOver) break;
      notifier.deal();
      await settleWidgets(tester);
    }

    final history = container.read(sessionProvider).history;
    expect(history, isNotEmpty, reason: 'no hand finished');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AllInAppTheme.dark(),
          home: const Scaffold(
            body: SessionSheet(initialSegment: SessionSegment.session),
          ),
        ),
      ),
    );
    await tester.pump();

    // Every finished hand is listed with the hero's own cards…
    expect(find.text('#${history.first.id}'), findsOneWidget);
    final hole = history.first.holes[0]!;
    expect(find.text(engine.prettyHoleCards(hole)), findsOneWidget);

    // …and a flagged hand carries §16.5's colour for its worst verdict.
    final verdicts = container.read(sessionProvider).handVerdicts;
    expect(verdicts, isNotEmpty, reason: 'the coach flagged nothing');
    final dots = _dots(tester);
    for (final entry in verdicts.entries) {
      expect(
        dots,
        contains(VerdictBadge.colorOf(entry.value, AllInColors.dark)),
        reason: 'no dot for ${entry.value}',
      );
    }
  });
}
