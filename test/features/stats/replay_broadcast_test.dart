import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/providers/replay_model.dart';
import 'package:allin/features/stats/screens/replayer_screen.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/features/stats/widgets/replay_broadcast.dart';
import 'package:allin/features/stats/widgets/replay_felt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'stats_harness.dart';

HHHand broadcastHand() {
  final h = sixMaxHand();
  // The legacy sixMaxHand fixture omits two pre-flop folds.
  h.actions.insertAll(1, [
    for (final seat in [4, 5])
      HHAction(
        street: Street.preflop,
        seat: seat,
        name: h.seats[seat].name,
        type: ActionType.fold,
        amount: 0,
        allIn: false,
      ),
  ]);
  return h;
}

void main() {
  testWidgets('scrubbing coalesces work and never displays stale equity', (
    tester,
  ) async {
    final fixture = StatsFixture();
    final hand = broadcastHand();
    final model = ReplayModel.of(hand);
    var index = 0;
    late StateSetter update;
    final requests = <ReplayEquityRequest>[];
    final pending = <Completer<ReplayEquity>>[];
    await pumpStats(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Scaffold(
            body: ReplayBroadcast(
              model: model,
              index: index,
              fourColorDeck: false,
              reducedMotion: true,
              onNext: () {},
              onPrevious: () {},
            ),
          );
        },
      ),
      fixture: fixture,
      overrides: [
        replayEquityRunnerProvider.overrideWithValue((r) {
          requests.add(r);
          final c = Completer<ReplayEquity>();
          pending.add(c);
          return c.future;
        }),
      ],
    );
    expect(requests.single.board, isEmpty); // never the hand's final board
    update(
      () => index = model.frames.indexWhere((f) => f.street == Street.flop),
    );
    await tester.pump();
    update(
      () => index = model.frames.indexWhere((f) => f.street == Street.turn),
    );
    await tester.pump();
    expect(requests.length, 1); // no unbounded isolate fan-out
    pending[0].complete(const ReplayEquity({0: .9, 3: .1}));
    await tester.pump();
    expect(requests.length, 2);
    expect(requests.last.board.length, 4);
    expect(tester.widget<ReplayFelt>(find.byType(ReplayFelt)).equities, isNull);
    pending[1].complete(const ReplayEquity({0: .7, 3: .3}, exact: true));
    await tester.pumpAndSettle();
    expect(find.text('70.0%'), findsOneWidget);
    expect(find.text('90.0%'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<ReplayFelt>(find.byType(ReplayFelt)).broadcast, false);
    expect(find.text('70.0%'), findsNothing);
  });

  for (final size in [const Size(360, 780), const Size(430, 932)]) {
    for (final dark in [true, false]) {
      testWidgets('broadcast replay fits $size theme=$dark at large text', (
        tester,
      ) async {
        final fixture = StatsFixture();
        final hand = broadcastHand();
        await fixture.addHand(hand, netBb: 13);
        final key = GlobalKey();
        await pumpStats(
          tester,
          RepaintBoundary(
            key: key,
            child: ReplayerScreen(startedAt: hand.startedAt),
          ),
          fixture: fixture,
          size: size,
          dark: dark,
          textScale: 1.3,
        );
        await tester.pumpAndSettle();
        expect(find.text(StatsCopy.equityExact), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.bySemanticsLabel('First'));
        await tester.pumpAndSettle();
        expect(find.text(StatsCopy.equityUnknown), findsOneWidget);
        await tester.tap(find.byTooltip(StatsCopy.equityHelpTitle));
        await tester.pumpAndSettle();
        expect(find.text(StatsCopy.equityHelp), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Decision'));
        await tester.pumpAndSettle();
        if (Platform.environment['ALLIN_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/allin-replay-${size.width.toInt()}-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
