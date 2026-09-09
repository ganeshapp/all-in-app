/// Shared plumbing for the Stats widget tests: a hermetic provider scope over
/// an in-memory key-value store, a fake picker, a fake share sheet and
/// in-process import workers (no isolates in a widget test).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/stats/providers/import_provider.dart';
import 'package:allin/services/file_service.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/services/share_service.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const Size phone390 = Size(390, 844);

/// Records what was shared and answers with a fixed outcome.
class FakeShareAdapter extends ShareAdapter {
  FakeShareAdapter({this.outcome = ShareOutcome.success});

  final ShareOutcome outcome;
  final List<String> texts = [];
  final List<String> files = [];

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    texts.add(text);
    return outcome;
  }

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    String? text,
    String? subject,
    String? mimeType,
  }) async {
    files.add(path);
    return outcome;
  }
}

/// A picker that hands back [contents] (or cancels when it is null). Share
/// staging goes to a real temp directory, so `path_provider`'s platform
/// channel is never touched.
FileService fakePicker({String? contents, String name = 'hands.txt'}) =>
    FileService(
      pickFiles: ({
        required List<String> allowedExtensions,
        String? dialogTitle,
      }) async {
        if (contents == null) return null;
        final bytes = Uint8List.fromList(contents.codeUnits);
        return FilePickerResult([
          PlatformFile(name: name, size: bytes.length, bytes: bytes),
        ]);
      },
      temporaryDirectory:
          () async => Directory.systemTemp.createTemp('allin_stats_share'),
    );

/// The in-memory backing store plus the repository writing into it, so a test
/// can seed hands, guesses and decisions through the real code path.
class StatsFixture {
  StatsFixture() : store = MemoryKeyValueStore(), _hands = <String>[] {
    stats = StatsRepository(database: AppDatabase(), store: store);
  }

  final MemoryKeyValueStore store;
  final List<String> _hands;
  late final StatsRepository stats;

  Future<void> addHand(
    HHHand hand, {
    double netBb = 1,
    bool showdown = true,
    bool won = true,
    List<Archetype> archetypes = const [Archetype.tag],
    Position position = Position.btn,
    bool sawFlop = true,
    List<CoachNoteRecord> coachNotes = const [],
  }) async {
    _hands.add(hand.startedAt.toString());
    await stats.persistHand(
      HandRecord(
        n: _hands.length,
        netBb: netBb,
        potBb: 4,
        showdown: showdown,
        won: won,
        archetypes: archetypes,
        position: position,
        sawFlop: sawFlop,
        handJson: encodeHandJson(hand, coachNotes: coachNotes),
        ts: hand.startedAt,
      ),
      netBb * 20,
    );
  }

  Future<void> addImported(List<String> payloads) =>
      stats.persistImportedHands(payloads);

  Future<void> addGuess(GuessRecord rec) => stats.persistGuess(rec);

  Future<void> addDecision(DecisionRecord rec) => stats.persistDecision(rec);
}

/// Every override the Stats screens need to run without a platform.
List<Override> statsOverrides({
  required StatsFixture fixture,
  FileService? files,
  ShareAdapter? share,
}) {
  final picker = files ?? fakePicker();
  return [
    keyValueStoreProvider.overrideWithValue(fixture.store),
    fileServiceProvider.overrideWithValue(picker),
    shareServiceProvider.overrideWithValue(
      ShareService(files: picker, adapter: share ?? FakeShareAdapter()),
    ),
    // Isolates are unavailable in a widget test; the workers are the same
    // functions, run in process.
    importParserProvider.overrideWithValue(
      (chunk) async => parseChunkWorker(chunk),
    ),
    importAnalyserProvider.overrideWithValue(
      (args) async => analyseChunkWorker(args),
    ),
  ];
}

/// Pumps [child] inside the app theme at a given size and text scale (§13).
Future<void> pumpStats(
  WidgetTester tester,
  Widget child, {
  required StatsFixture fixture,
  List<Override> overrides = const [],
  FileService? files,
  ShareAdapter? share,
  bool dark = true,
  double textScale = 1.0,
  Size size = phone390,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...statsOverrides(fixture: fixture, files: files, share: share),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AllInAppTheme.dark() : AllInAppTheme.light(),
        home: Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child,
              ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A small, complete 6-max hand: hero on the button with A♠K♠ against Dwan's
/// Q♥Q♦ — the canonical fixture of the port doc §9.1.
HHHand sixMaxHand({int startedAt = 1781838000000, int id = 7}) {
  const names = ['You', 'Ivey', 'Polk', 'Dwan', 'Selbst', 'Galfond'];
  const positions = [
    Position.btn,
    Position.sb,
    Position.bb,
    Position.utg,
    Position.mp,
    Position.co,
  ];
  HHAction act(Street s, int seat, ActionType t, num amount) => HHAction(
    street: s,
    seat: seat,
    name: names[seat],
    type: t,
    amount: amount,
    allIn: false,
  );

  return HHHand(
    id: id,
    startedAt: startedAt,
    button: 0,
    sb: 10,
    bb: 20,
    sbSeat: 1,
    bbSeat: 2,
    seats: [
      for (var i = 0; i < names.length; i++)
        HHSeat(
          seat: i,
          name: names[i],
          stack: 2000,
          isHero: i == 0,
          position: positions[i],
        ),
    ],
    holes: {
      0: const ['As', 'Ks'],
      3: const ['Qh', 'Qd'],
    },
    actions: [
      act(Street.preflop, 3, ActionType.raise, 60),
      act(Street.preflop, 0, ActionType.call, 60),
      act(Street.preflop, 1, ActionType.fold, 0),
      act(Street.preflop, 2, ActionType.fold, 0),
      act(Street.flop, 3, ActionType.bet, 80),
      act(Street.flop, 0, ActionType.call, 80),
      act(Street.turn, 3, ActionType.check, 0),
      act(Street.turn, 0, ActionType.check, 0),
      act(Street.river, 3, ActionType.check, 0),
      act(Street.river, 0, ActionType.bet, 120),
      act(Street.river, 3, ActionType.call, 120),
    ],
    board: const ['Ah', 'Kd', '7c', '2s', '9h'],
    potResults: const [
      PotResult(winners: [0], amount: 520, potLabel: 'Pot'),
    ],
    heroNet: 260,
  );
}
