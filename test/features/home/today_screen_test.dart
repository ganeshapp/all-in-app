/// H0 · Today (DESIGN.md §3): what the screen shows in each state, where every
/// card goes, and the three layers behind the coach's sentence.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart' show DrillAction;
import 'package:allin/features/home/home_copy.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/settings/screens/settings_screen.dart';
import 'package:allin/features/stats/providers/stats_metrics.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_harness.dart';

void main() {
  group('§3.6 first run', () {
    testWidgets('the plan, the empty goal and the no-data coach line', (
      tester,
    ) async {
      final container = homeContainer();
      await pumpHome(tester, container: container);

      // Greeting + the first-run line instead of the streak (§3.5).
      expect(find.text('Good evening'), findsOneWidget);
      expect(find.text(HomeCopy.firstRunSubtitle), findsOneWidget);

      // Goal card at zero, with the caption that names the other half.
      expect(find.text('0 of 20'), findsOneWidget);
      expect(find.text(HomeCopy.goalCaptionDrills), findsOneWidget);

      // Three cards: lesson, quick set, play — no review, no resume.
      expect(find.byType(PlanCard), findsNWidgets(3));
      expect(find.text(HomeCopy.reviewTitle), findsNothing);
      expect(find.text(HomeCopy.resumeTitle), findsNothing);
      expect(find.text('Play 20 hands · 6-max'), findsOneWidget);

      // The coach says the no-data line; nothing else has anything to say.
      expect(find.text(HomeCopy.coachNoData), findsOneWidget);
      expect(find.text(HomeCopy.eyebrowLastSession), findsNothing);
      expect(find.text(HomeCopy.eyebrowPractice), findsNothing);
      expect(find.text(HomeCopy.goalMet), findsNothing);
    });
  });

  group('§3.2 states', () {
    testWidgets('reviews due are the primary card', (tester) async {
      final store = KeyValueStore.memory();
      await seedLeaks(store, [
        leakSpot(id: 'a', best: DrillAction.fold),
        leakSpot(id: 'b', best: DrillAction.fold),
        leakSpot(id: 'c'),
        leakSpot(id: 'd'),
        leakSpot(id: 'e'),
      ]);
      await pumpHome(tester, container: homeContainer(store: store));

      expect(find.text(HomeCopy.reviewTitle), findsOneWidget);
      expect(
        find.text('5 spots due · 2 are coach-flagged calls'),
        findsOneWidget,
      );
      expect(find.text('~2 min'), findsOneWidget);
      expect(find.text(HomeCopy.reviewButton), findsOneWidget);

      // It is first: the review card sits above the lesson card.
      final review = tester.getTopLeft(find.text(HomeCopy.reviewTitle)).dy;
      final lesson = tester.getTopLeft(find.textContaining('Continue: ')).dy;
      expect(review, lessThan(lesson));
    });

    testWidgets('a paused session shows Resume, not Play 20 hands', (
      tester,
    ) async {
      final store = KeyValueStore.memory();
      await seedSession(store, hands: 12, netChips: 90);
      await pumpHome(tester, container: homeContainer(store: store));

      expect(find.text(HomeCopy.resumeTitle), findsOneWidget);
      expect(find.text('12 hands, +4.5 bb · Coach on'), findsOneWidget);
      expect(find.textContaining('Play 20 hands'), findsNothing);
    });

    testWidgets('goal met shows the line and hides nothing', (tester) async {
      final store = KeyValueStore.memory();
      await seedGoals(store, drills: 20);
      await pumpHome(tester, container: homeContainer(store: store));

      expect(find.text(HomeCopy.goalMet), findsOneWidget);
      expect(find.text('20 of 20'), findsOneWidget);
      expect(find.byType(PlanCard), findsNWidgets(3));
    });

    testWidgets('the goal card counts hands when they lead', (tester) async {
      final store = KeyValueStore.memory();
      await seedGoals(store, drills: 2, hands: 20);
      await pumpHome(tester, container: homeContainer(store: store));

      expect(find.text('20 of 30'), findsOneWidget);
      expect(find.text(HomeCopy.goalCaptionHands), findsOneWidget);
    });

    testWidgets('the last session row and the practice heatmap', (
      tester,
    ) async {
      final store = KeyValueStore.memory();
      await seedGoals(store, drills: 3);
      await pumpHome(
        tester,
        container: homeContainer(store: store, sessions: [endedSession()]),
      );

      await reveal(tester, find.text('+12.5 bb · 41 hands · 2 mistakes'));
      expect(find.text(HomeCopy.eyebrowLastSession), findsOneWidget);
      expect(find.text('+12.5 bb · 41 hands · 2 mistakes'), findsOneWidget);
      expect(find.text('Costliest: a river call (-3.1 bb)'), findsOneWidget);
      expect(find.text(HomeCopy.eyebrowPractice), findsOneWidget);
      expect(find.text('1 active day'), findsOneWidget);
    });
  });

  group('navigation (§2.3, §2.6)', () {
    testWidgets('Start review opens Drills in Review mode', (tester) async {
      final store = KeyValueStore.memory();
      await seedLeaks(store, [leakSpot(id: 'a')]);
      final router = await pumpHome(
        tester,
        container: homeContainer(store: store),
      );

      await tester.tap(find.text(HomeCopy.reviewButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(locationOf(router), '/drills?mode=leaks');
    });

    testWidgets('the quick set arms the set counter', (tester) async {
      final router = await pumpHome(tester, container: homeContainer());

      await tester.tap(find.textContaining('A set of 10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(locationOf(router), '/drills?mode=mixed&set=10');
    });

    testWidgets('the lesson card jumps to the Study branch', (tester) async {
      final router = await pumpHome(tester, container: homeContainer());

      await tester.tap(find.textContaining('Continue: '));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(locationOf(router), '/study/lesson/hand-rankings');
    });

    testWidgets('Play 20 hands deals with the saved options', (tester) async {
      final container = homeContainer();
      final router = await pumpHome(tester, container: container);

      expect(container.read(sessionProvider).active, isFalse);
      await tester.tap(find.textContaining('Play 20 hands'));
      await tester.pump();

      expect(container.read(sessionProvider).active, isTrue);
      expect(locationOf(router), '/table');
    });

    testWidgets('Resume goes straight back to the felt', (tester) async {
      final store = KeyValueStore.memory();
      await seedSession(store);
      final router = await pumpHome(
        tester,
        container: homeContainer(store: store),
      );

      await tester.tap(find.text(HomeCopy.resumeTitle));
      await tester.pump();

      expect(locationOf(router), '/table');
    });

    testWidgets('the last session opens its read-only summary', (tester) async {
      final router = await pumpHome(
        tester,
        container: homeContainer(sessions: [endedSession()]),
      );

      await reveal(tester, find.text('+12.5 bb · 41 hands · 2 mistakes'));
      await tester.tap(find.text('+12.5 bb · 41 hands · 2 mistakes'));

      // A push keeps the declarative location, so the pushed match is what
      // carries the target (§16.1). The frame is deliberately not pumped:
      // P10's own `dispose` builds an `AnimationController` when it is torn
      // down un-shaken, which would fail this test for another feature's bug.
      expect(pushedLocation(router), '/home/session/4');
    });

    testWidgets('the last-session result follows the one money colour rule', (
      tester,
    ) async {
      // §13: a win is green, a loss is red and a flat session is neither. The
      // card used to sniff a leading "−" off the string, so "+0.0 bb" — a
      // session where nothing happened — was painted in the win green.
      final colours = AllInColors.dark;
      Future<Color?> colourOf(double netBb) async {
        await pumpHome(
          tester,
          container: homeContainer(sessions: [endedSession(netBb: netBb)]),
        );
        final line = find.textContaining('bb · 41 hands');
        await reveal(tester, line);
        return tester.widget<Text>(line).style?.color;
      }

      expect(await colourOf(12.5), colours.good);
      expect(await colourOf(-6), colours.bad);
      expect(await colourOf(0), colours.textMuted);
    });

    testWidgets('the heatmap opens Progress', (tester) async {
      final store = KeyValueStore.memory();
      await seedGoals(store, drills: 3);
      final router = await pumpHome(
        tester,
        container: homeContainer(store: store),
      );

      await reveal(tester, find.text(HomeCopy.eyebrowPractice));
      await tester.tap(find.text(HomeCopy.eyebrowPractice));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(locationOf(router), '/stats');
    });

    testWidgets('the gear opens the one canonical Settings', (tester) async {
      final router = await pumpHome(tester, container: homeContainer());

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(locationOf(router), '/stats/settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('sheets', () {
    testWidgets('H2 · the goal explainer is the verbatim tooltip', (
      tester,
    ) async {
      await pumpHome(tester, container: homeContainer());

      await tester.tap(find.text(HomeCopy.goalCaptionDrills));
      await tester.pumpAndSettle();

      expect(find.text(HomeCopy.goalSheetBody), findsOneWidget);
      expect(find.text('Show me the math'), findsOneWidget);
      expect(find.text('Expert detail'), findsOneWidget);
    });

    testWidgets('H1 · the coach note renders all three layers', (tester) async {
      final store = KeyValueStore.memory();
      await seedDecisions(store, total: 10, folds: 3);
      await seedLeaks(store, [leakSpot(id: 'a')]);
      await pumpHome(tester, container: homeContainer(store: store));

      await reveal(tester, find.text(HomeCopy.coachAction));
      await tester.tap(find.text(HomeCopy.coachAction));
      await tester.pumpAndSettle();

      // Layer 1 — the same sentence as the card.
      expect(
        find.textContaining('You fold too often'),
        findsAtLeastNWidgets(1),
      );

      // Layer 2 opens to the count behind it.
      await tester.tap(find.text('Show me the math'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('of your last 10 coached decisions'),
        findsOneWidget,
      );

      // Layer 3 opens to the rule.
      await tester.tap(find.text('Expert detail'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flagged when'), findsOneWidget);

      // The two buttons of §3.4.
      expect(find.text(HomeCopy.reviewTheseSpots), findsOneWidget);
    });

    testWidgets('H1s lesson button jumps to the lesson', (tester) async {
      final store = KeyValueStore.memory();
      await seedDecisions(store, total: 10, folds: 3);
      final router = await pumpHome(
        tester,
        container: homeContainer(store: store),
      );

      await reveal(tester, find.text(HomeCopy.coachAction));
      await tester.tap(find.text(HomeCopy.coachAction));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await tester.pumpAndSettle();

      expect(locationOf(router), '/study/lesson/pot-odds');
    });
  });

  group('layout (§13)', () {
    for (final size in const [phone360, phone390, phone430]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('renders at ${size.width} × $scale', (tester) async {
          final store = KeyValueStore.memory();
          await seedGoals(store, drills: 8);
          await seedLeaks(store, [
            leakSpot(id: 'a', best: DrillAction.fold),
            leakSpot(id: 'b'),
          ]);
          await pumpHome(
            tester,
            container: homeContainer(store: store, sessions: [endedSession()]),
            size: size,
            textScale: scale,
            dark: scale == 1.0,
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(PlanCard), findsWidgets);

          // §3.1: at the default type size the goal card and the primary plan
          // card are above the fold. At 1.3× everything grows (§13) — the
          // primary card only has to stay on screen.
          final primary = tester.getBottomLeft(find.text(HomeCopy.reviewTitle));
          expect(
            primary.dy,
            lessThan(scale == 1.0 ? size.height / 2 + 40 : size.height),
          );
        });
      }
    }

    testWidgets('every card clears the 44 pt floor (§12)', (tester) async {
      await pumpHome(tester, container: homeContainer());

      for (final card in tester.widgetList<PlanCard>(find.byType(PlanCard))) {
        final size = tester.getSize(find.byWidget(card));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      expect(
        tester.getSize(find.byType(GoalCard)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('§14 degraded states', () {
    testWidgets('the coach still speaks when the stats read fails', (
      tester,
    ) async {
      await pumpHome(
        tester,
        container: homeContainer(
          overrides: [statsProvider.overrideWith(_BrokenStats.new)],
        ),
      );

      // No numbers, no crash: the plan still stands and the coach falls back
      // to the line that asks for a session.
      expect(find.byType(PlanCard), findsNWidgets(3));
      expect(find.text(HomeCopy.coachNoData), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('freshness', () {
    testWidgets('a re-tap of the Home tab re-reads the stores', (tester) async {
      final store = KeyValueStore.memory();
      final container = homeContainer(store: store);
      await pumpHome(tester, container: container);
      expect(find.text('0 of 20'), findsOneWidget);

      // Play writes the goal through its own store instance.
      await seedGoals(store, drills: 4);
      container.read(tabReselectProvider.notifier).bump(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('4 of 20'), findsOneWidget);
    });
  });
}

/// §14 "Storage · quota / DB error": the lifetime snapshot cannot be read.
class _BrokenStats extends StatsNotifier {
  @override
  Future<StatsMetrics> build() async => throw StateError('no database');
}
