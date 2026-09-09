/// P0 · Play lobby (DESIGN.md §4.1): the never-played empty state, the setup
/// card's live preview, the Resume card and the "Start a new table?" dialog.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/play/providers/lobby_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/screens/lobby_screen.dart';
import 'package:allin/features/play/widgets/lobby_preview.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('empty state (never played)', () {
    testWidgets('shows the first-table caption and no Recent section', (
      tester,
    ) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/play');

      expect(find.text(PlayCopy.lobbyTitle), findsWidgets);
      expect(find.text(PlayCopy.lobbySubtitle), findsOneWidget);
      expect(find.text(PlayCopy.newTable), findsOneWidget);
      expect(find.text(PlayCopy.firstTableCaption), findsOneWidget);
      expect(find.text(PlayCopy.startOverlayBody), findsOneWidget);
      expect(find.text(PlayCopy.recentSessions), findsNothing);
      expect(find.text(PlayCopy.sessionInProgress), findsNothing);
      expect(find.byType(LobbyFeltPreview), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 360, 390 and 430 in both themes', (tester) async {
      for (final size in [phone360, phone390, phone430]) {
        for (final dark in [true, false]) {
          final container = makeContainer(seed: 1);
          addTearDown(container.dispose);
          await pumpApp(
            tester,
            container: container,
            location: '/play',
            size: size,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('table setup', () {
    testWidgets('the felt preview re-seats itself when Table changes', (
      tester,
    ) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/play');

      expect(container.read(lobbyDraftProvider).seats, 6);
      expect(
        tester.widget<LobbyFeltPreview>(find.byType(LobbyFeltPreview)).seats,
        6,
      );

      await tester.tap(find.text('9-max'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(lobbyDraftProvider).seats, 9);
      expect(
        tester.widget<LobbyFeltPreview>(find.byType(LobbyFeltPreview)).seats,
        9,
      );
      // §4.1: the "charts assume 6-max" note only shows off 6-max.
      expect(find.textContaining('Coach charts assume 6-max'), findsOneWidget);
    });

    testWidgets('antes turn the ante chips on', (tester) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/play');

      expect(
        tester.widget<LobbyFeltPreview>(find.byType(LobbyFeltPreview)).ante,
        0,
      );
      await tester.tap(find.text('0.25 bb'));
      await tester.pump();
      expect(
        tester.widget<LobbyFeltPreview>(find.byType(LobbyFeltPreview)).ante,
        5,
      );
    });

    testWidgets('the speed menu appears only in Auto pace', (tester) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/play');

      expect(find.text('Normal'), findsNothing);
      await tester.tap(find.text('Auto'));
      await tester.pump();
      await settleWidgets(tester);
      await tester.pump();

      expect(container.read(settingsProvider).paceMode, PaceMode.auto);
      expect(find.text('Normal'), findsOneWidget);
    });

    testWidgets('"Deal me in" starts a session and opens the table', (
      tester,
    ) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      await pumpApp(tester, container: container, location: '/play');

      await tester.tap(find.text(PlayCopy.dealMeIn));
      await tester.pump();
      await settleWidgets(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(sessionProvider).active, isTrue);
      expect(container.read(sessionProvider).table, isNotNull);
    });
  });

  group('resume card', () {
    testWidgets('appears while a session exists, with the §4.1 line', (
      tester,
    ) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).newSession();
      await settleWidgets(tester);
      await pumpApp(tester, container: container, location: '/play');

      expect(find.text(PlayCopy.sessionInProgress), findsOneWidget);
      expect(find.text(PlayCopy.resume), findsWidgets);
      expect(find.textContaining('6-max · 0 hands'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Deal me in" over a paused session asks first', (
      tester,
    ) async {
      final container = makeContainer(seed: 1);
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).newSession();
      await settleWidgets(tester);
      await pumpApp(tester, container: container, location: '/play');

      await tester.tap(find.text(PlayCopy.dealMeIn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(PlayCopy.newTableOverPausedTitle), findsOneWidget);
      expect(find.text(PlayCopy.keepPausedOne), findsOneWidget);
      expect(find.text(PlayCopy.newTableAction), findsOneWidget);

      // "Keep paused one" leaves the session exactly as it was.
      final before = container.read(sessionProvider).startedAt;
      await tester.tap(find.text(PlayCopy.keepPausedOne));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(sessionProvider).startedAt, before);
      expect(container.read(sessionProvider).active, isTrue);
    });
  });

  group('helpers', () {
    test('relativeAge reads as §4.1 does', () {
      final now = DateTime(2026, 3, 12, 18, 10);
      expect(relativeAge(0), 'just now');
      expect(
        relativeAge(
          now.subtract(const Duration(minutes: 8)).millisecondsSinceEpoch,
          now: now,
        ),
        '8 min ago',
      );
      expect(
        relativeAge(
          now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
          now: now,
        ),
        '3 h ago',
      );
      expect(
        relativeAge(
          now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
          now: now,
        ),
        '2 d ago',
      );
    });

    test('sessionStamp reads Today / Yesterday / a date', () {
      final now = DateTime(2026, 3, 12, 20);
      expect(
        sessionStamp(
          DateTime(2026, 3, 12, 18, 10).millisecondsSinceEpoch,
          now: now,
        ),
        'Today 18:10',
      );
      expect(
        sessionStamp(DateTime(2026, 3, 11, 9).millisecondsSinceEpoch, now: now),
        'Yesterday',
      );
      expect(
        sessionStamp(DateTime(2026, 3, 2, 9).millisecondsSinceEpoch, now: now),
        '2 Mar',
      );
    });
  });
}
