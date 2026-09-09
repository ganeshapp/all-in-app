/// P10 · session summary (DESIGN.md §4.13; port §20).
library;

import 'dart:math';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/providers/summary_provider.dart';
import 'package:allin/features/play/screens/session_summary_screen.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/services/clock.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence/app_database.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/services/share_service.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// An in-memory `sessions` table: the widget tests must not touch sqflite
/// (there is no database in a widget test) but P10's read-only copies still
/// have to read back exactly the payload `SessionNotifier` wrote.
class FakeSessionRepository extends SessionRepository {
  FakeSessionRepository({required super.database, required super.store});

  final List<SessionRecord> rows = [];

  @override
  Future<int?> recordEndedSession(SessionRecord record) async {
    rows.add(record);
    return rows.length;
  }

  @override
  Future<SessionRecord?> sessionById(int id) async =>
      id >= 1 && id <= rows.length ? rows[id - 1].copyWith(id: id) : null;

  @override
  Future<List<SessionRecord>> recentSessions({int limit = 10}) async =>
      rows.reversed.toList();
}

/// [makeContainer] plus the in-memory sessions table and an optional share
/// service.
ProviderContainer summaryContainer({int seed = 7, ShareService? share}) {
  final kv = KeyValueStore.memory();
  kv.setJson(kSettingsKey, const AppSettings(coachEnabled: false).toJson());

  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      appDatabaseProvider.overrideWithValue(null),
      playRandomProvider.overrideWithValue(Random(seed)),
      playClockProvider.overrideWithValue(FakeClock()),
      hapticDriverProvider.overrideWithValue(RecordingHapticDriver()),
      equityServiceProvider.overrideWith(
        (ref) => EquityService.inProcess(timeout: const Duration(seconds: 5)),
      ),
      sessionRepositoryProvider.overrideWith(
        (ref) => FakeSessionRepository(
          database: AppDatabase(),
          store: ref.watch(keyValueStoreProvider),
        ),
      ),
      if (share != null) shareServiceProvider.overrideWithValue(share),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Plays [hands] complete hands with a passive hero.
void playSession(ProviderContainer container, {int hands = 3}) {
  final notifier = container.read(sessionProvider.notifier);
  notifier.newSession();
  for (var hand = 0; hand < hands; hand++) {
    if (hand > 0) notifier.deal();
    for (var i = 0; i < 400; i++) {
      final state = container.read(sessionProvider);
      final table = state.table!;
      if (table.phase == GamePhase.handOver) break;
      if (table.toAct == 0) {
        final legal = state.legal!;
        notifier.heroAction(
          legal.canCheck
              ? const poker.Action.check()
              : const poker.Action.fold(),
        );
      } else {
        notifier.stepBot();
      }
    }
  }
}

/// Captures what "Share" hands to the OS.
class RecordingShareService extends ShareService {
  RecordingShareService();

  String? handHistory;
  DateTime? startedAt;

  @override
  Future<ShareOutcome> shareSession({
    required String handHistory,
    required DateTime startedAt,
  }) async {
    this.handHistory = handHistory;
    this.startedAt = startedAt;
    return ShareOutcome.success;
  }
}

const SessionCounters kExampleCounters = SessionCounters(
  hands: 41,
  coachedDecisions: 18,
  flaggedDecisions: 2,
  bestEvBb: 3.2,
  bestEvLabel: 'turn raise',
  worstEvBb: -3.1,
  worstEvLabel: 'river call',
);

/// The table sits under P10 with perpetual animations (turn ring, shimmer),
/// so `pumpAndSettle` can never settle there — pump a fixed run of frames.
Future<void> settleFrames(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Resolves P10's async data on the *real* event loop: inside `testWidgets`
/// the fake-async zone never completes the repository's futures on its own.
Future<void> warmSummary(
  WidgetTester tester,
  ProviderContainer container, [
  String? id,
]) => tester.runAsync(() => container.read(sessionSummaryProvider(id).future));

void main() {
  group('debrief (§4.13)', () {
    test('the wireframe example, word for word', () {
      final debrief = buildDebrief(
        counters: kExampleCounters,
        lifetimeCoached: 336,
        lifetimeFlagged: 47,
      );

      expect(
        debrief.paragraph,
        '18 coached decisions, 2 flagged as mistakes '
        '(11 % vs your usual 14 % — cleaner than average).',
      );
      expect(debrief.best, 'Best: a turn raise worth +3.2 bb.');
      expect(
        debrief.costliest,
        "Costliest: a river call (-3.1 bb) — it's in your Review queue.",
      );
      expect(
        debrief.mathLines.first,
        '2 of 18 coached decisions were flagged this session = 11 %.',
      );
      expect(debrief.mathLines[1], 'Lifetime: 47 of 336 = 14 %.');
      expect(
        debrief.mathLines[2],
        "Best and costliest are the highest and lowest EV among this session's "
        'coached decisions: +3.2 bb and -3.1 bb.',
      );
      expect(debrief.expertLines, kDebriefExpertLines);
      expect(debrief.expertLines.first, contains('0.25 bb on Standard'));
    });

    test('a rougher session says so, and ±2 points says nothing', () {
      final rough = buildDebrief(
        counters: const SessionCounters(
          coachedDecisions: 10,
          flaggedDecisions: 3,
        ),
        lifetimeCoached: 200,
        lifetimeFlagged: 28,
      );
      expect(
        rough.paragraph,
        contains('(30 % vs your usual 14 % — a rougher one)'),
      );

      final level = buildDebrief(
        counters: const SessionCounters(
          coachedDecisions: 20,
          flaggedDecisions: 3,
        ),
        lifetimeCoached: 200,
        lifetimeFlagged: 28,
      );
      expect(level.paragraph, contains('(15 % vs your usual 14 %)'));
      expect(level.paragraph, isNot(contains('average')));
    });

    test('a small sample warns, and a first session makes no comparison', () {
      final debrief = buildDebrief(
        counters: const SessionCounters(
          coachedDecisions: 8,
          flaggedDecisions: 1,
        ),
        lifetimeCoached: 8,
        lifetimeFlagged: 1,
      );
      // Nothing outside this session to compare with.
      expect(debrief.paragraph, '8 coached decisions, 1 flagged as mistake.');
      expect(
        debrief.mathLines.last,
        '8 decisions is a small sample — one flagged call moves this by '
        '13 points.',
      );
    });

    test('no coached decisions renders the degenerate card', () {
      final debrief = buildDebrief(
        counters: const SessionCounters(hands: 12),
        lifetimeCoached: 300,
        lifetimeFlagged: 40,
      );
      expect(debrief.paragraph, SummaryCopy.noCoachedDecisions);
      expect(debrief.mathLines, isEmpty);
      expect(debrief.expertLines, isEmpty);
      expect(debrief.best, isNull);
      expect(debrief.costliest, isNull);
    });
  });

  group('numbers from a played session', () {
    test('hands, net, bb/100, biggest pots and showdowns', () async {
      final container = summaryContainer();
      playSession(container, hands: 4);
      final session = container.read(sessionProvider);

      final data = await container.read(sessionSummaryProvider(null).future);

      expect(data.live, isTrue);
      expect(data.hands, 4);
      expect(data.hands, session.history.length);
      expect(data.netBb, closeTo(session.netBb, 0.0001));
      expect(data.bb100, closeTo(session.netBb / 4 * 100, 0.0001));

      final nets = [
        for (final h in session.history) h.heroNet / session.bigBlind,
      ];
      expect(data.biggestWinBb, nets.reduce((a, b) => a > b ? a : b));
      expect(data.biggestLossBb, nets.reduce((a, b) => a < b ? a : b));
      expect(
        data.showdowns,
        session.history.where((h) => h.board.length == 5).length,
      );
      expect(data.rows.first.id, session.history.last.id);
      expect(data.rows.last.id, session.history.first.id);
    });

    test('an ended session round-trips through the sessions row', () async {
      final container = summaryContainer();
      playSession(container, hands: 2);
      final before = container.read(sessionProvider);

      final id = await container.read(sessionProvider.notifier).finishSession();
      expect(id, isNotNull);

      final data = await container.read(sessionSummaryProvider('$id').future);
      expect(data.live, isFalse);
      expect(data.missing, isFalse);
      expect(data.hands, 2);
      expect(data.netBb, closeTo(before.netBb, 0.0001));
      expect(data.history.length, 2);
      expect(data.seats, before.options.seats);
    });

    test('an unknown id is the §14 missing state, never a crash', () async {
      final container = summaryContainer();
      final data = await container.read(sessionSummaryProvider('4321').future);
      expect(data.missing, isTrue);
      expect(data.hands, 0);
    });
  });

  group('screen', () {
    testWidgets('the live summary shows the debrief, the tiles and the rows', (
      tester,
    ) async {
      final container = summaryContainer();
      playSession(container, hands: 3);
      container.read(sessionProvider.notifier).endSession();

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      expect(find.text(SummaryCopy.title), findsOneWidget);
      expect(find.text('3 hands played this session.'), findsOneWidget);
      expect(
        find.text(SummaryCopy.debriefEyebrow.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(SummaryCopy.noCoachedDecisions), findsOneWidget);
      expect(find.text('NET'), findsOneWidget);
      expect(find.text('BB / 100'), findsOneWidget);
      expect(find.text('BIGGEST WIN'), findsOneWidget);
      expect(find.text('BIGGEST LOSS'), findsOneWidget);
      expect(find.text('REVIEW HANDS'), findsOneWidget);
      // Newest first; the third row is below the fold in this viewport.
      expect(find.text('Hand #3'), findsOneWidget);
      expect(find.text('Hand #2'), findsOneWidget);
      expect(find.byType(SummaryHandRowView), findsWidgets);
      expect(find.text(SummaryCopy.newSession), findsOneWidget);
      expect(find.text(SummaryCopy.done), findsOneWidget);
      expect(find.text(SummaryCopy.share), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every money tile follows the one signed-money rule', (
      tester,
    ) async {
      // §13 / principle 8: NET and BB/100 are the same signed quantity, so
      // they cannot get two colour rules in one card, and a flat zero is not
      // a win. `StatTone.money` is the single place that rule lives.
      final container = summaryContainer();
      playSession(container, hands: 3);
      container.read(sessionProvider.notifier).endSession();

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      final data = container.read(sessionSummaryProvider(null)).value!;
      final expected = <String, num>{
        'NET': data.netBb,
        'BB / 100': data.bb100,
        'BIGGEST WIN': data.biggestWinBb,
        'BIGGEST LOSS': data.biggestLossBb,
      };
      for (final MapEntry(key: label, value: v) in expected.entries) {
        final tile = tester.widget<StatTile>(
          find.ancestor(of: find.text(label), matching: find.byType(StatTile)),
        );
        expect(tile.tone, StatTone.money(v), reason: label);
      }
    });

    testWidgets('both disclosure rows are there and open to a written line', (
      tester,
    ) async {
      final container = summaryContainer();
      playSession(container, hands: 1);
      container.read(sessionProvider.notifier).endSession();

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      await tester.tap(find.text(CoachCopy.showMath));
      await settleFrames(tester);
      expect(find.text(CoachCopy.noMathVerdict), findsOneWidget);

      await tester.tap(find.text(CoachCopy.expertDetail));
      await settleFrames(tester);
      expect(find.text(CoachCopy.nothingExtra), findsOneWidget);
    });

    testWidgets('✕ closes the summary and the session continues', (
      tester,
    ) async {
      final container = summaryContainer();
      playSession(container, hands: 1);
      container.read(sessionProvider.notifier).endSession();
      expect(container.read(sessionProvider).sessionEnded, isTrue);

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      await tester.tap(find.bySemanticsLabel('Close'));
      await settleFrames(tester);

      expect(find.byType(SessionSummaryScreen), findsNothing);
      expect(container.read(sessionProvider).sessionEnded, isFalse);
      expect(container.read(sessionProvider).active, isTrue);
    });

    testWidgets('busted: no ✕, no Done, and back is refused', (tester) async {
      final container = summaryContainer();
      playSession(container, hands: 1);
      // Bust the hero: an empty stack at the next deal ends the session.
      final table = container.read(sessionProvider).table!;
      table.players[0].stack = 0;
      container.read(sessionProvider.notifier).deal();
      expect(container.read(sessionProvider).busted, isTrue);

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      expect(find.text(SummaryCopy.bustedTitle), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsNothing);
      expect(find.text(SummaryCopy.done), findsNothing);
      expect(find.text(SummaryCopy.newSession), findsOneWidget);

      await systemBack(tester);
      await settleFrames(tester);
      expect(find.byType(SessionSummaryScreen), findsOneWidget);
    });

    testWidgets('the read-only copy has Done and the session stamp', (
      tester,
    ) async {
      final container = summaryContainer();
      playSession(container, hands: 2);
      final id = await container.read(sessionProvider.notifier).finishSession();

      await warmSummary(tester, container, '$id');
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.sessionPath(AllInRoutes.lobbyPath, '$id'),
      );
      await settleFrames(tester);

      expect(find.text(SummaryCopy.readOnlyTitle), findsOneWidget);
      expect(find.textContaining('6-max'), findsOneWidget);
      expect(find.text(SummaryCopy.newSession), findsNothing);
      expect(find.text(SummaryCopy.done), findsOneWidget);
      expect(find.text('Hand #2'), findsOneWidget);
    });

    testWidgets('Share hands the PokerStars text to the share sheet', (
      tester,
    ) async {
      final share = RecordingShareService();
      final container = summaryContainer(share: share);
      playSession(container, hands: 2);
      final session = container.read(sessionProvider);
      container.read(sessionProvider.notifier).endSession();

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      await tester.tap(find.text(SummaryCopy.share));
      await settleFrames(tester);

      expect(share.handHistory, formatSession(session.history));
      expect(share.handHistory, contains('PokerStars Hand #'));
      expect(
        share.startedAt,
        DateTime.fromMillisecondsSinceEpoch(session.startedAt),
      );
    });

    testWidgets('a session with no hands disables Share and says so', (
      tester,
    ) async {
      final container = summaryContainer();
      container.read(sessionProvider.notifier).newSession();
      container.read(sessionProvider.notifier).endSession();

      await warmSummary(tester, container);
      await pumpApp(
        tester,
        container: container,
        location: AllInRoutes.summaryTablePath,
      );
      await settleFrames(tester);

      expect(find.text('0 hands played this session.'), findsOneWidget);
      expect(find.text(SummaryCopy.noHands), findsOneWidget);
      final share = tester.widget<AllInButton>(
        find.widgetWithText(AllInButton, SummaryCopy.share),
      );
      expect(share.onPressed, isNull);
    });

    testWidgets('renders at every width, both themes and 1.3× text', (
      tester,
    ) async {
      for (final size in [phone360, phone390, phone430]) {
        for (final dark in [true, false]) {
          final container = summaryContainer();
          playSession(container, hands: 2);
          container.read(sessionProvider.notifier).endSession();

          await warmSummary(tester, container);
          await pumpApp(
            tester,
            container: container,
            location: AllInRoutes.summaryTablePath,
            size: size,
            textScale: 1.3,
            dark: dark,
          );
          await settleFrames(tester);
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('the empty-session debrief tells the truth about the coach', () {
    SessionDebrief debriefWith({required bool coachWasOff}) => buildDebrief(
      counters: const SessionCounters(),
      lifetimeCoached: 0,
      lifetimeFlagged: 0,
      coachWasOff: coachWasOff,
    );

    test('says the coach was off only when it really was', () {
      expect(
        debriefWith(coachWasOff: true).paragraph,
        SummaryCopy.noCoachedDecisions,
      );
      expect(
        debriefWith(coachWasOff: true).paragraph,
        contains('the EV Coach was off'),
      );
    });

    test('with the coach on, never claims it was off', () {
      final d = debriefWith(coachWasOff: false);
      expect(d.paragraph, SummaryCopy.noDecisionsYet);
      expect(d.paragraph, isNot(contains('was off')));
      expect(d.paragraph, isNot(contains('No coached decisions')));
    });

    test('both variants keep the two placeholder disclosure rows', () {
      for (final off in [true, false]) {
        final d = debriefWith(coachWasOff: off);
        expect(d.mathLines, isEmpty);
        expect(d.expertLines, isEmpty);
      }
    });

    test('a coached decision outranks either degenerate line', () {
      final d = buildDebrief(
        counters: const SessionCounters(
          coachedDecisions: 4,
          flaggedDecisions: 1,
        ),
        lifetimeCoached: 0,
        lifetimeFlagged: 0,
        coachWasOff: false,
      );
      expect(d.paragraph, isNot(SummaryCopy.noDecisionsYet));
      expect(d.paragraph, isNot(SummaryCopy.noCoachedDecisions));
    });
  });
}

/// Posts a real `popRoute` on the navigation channel (`simulateSystemBack`
/// does not exist in this Flutter).
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}
