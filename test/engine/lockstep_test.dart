// Lockstep parity against the desktop TypeScript: whole bot-vs-bot hands
// (hand_engine + bot_brain, including the equity sampling the bots consume),
// then the hand-history export of every hand (hand_history), compared line
// by line with a transcript produced by the desktop code driven by the same
// mulberry32 stream (`Math.random = mulberry32(seed)` in Node 23).
//
// The fixture `test/fixtures/lockstep_bots.txt` holds one section per table
// configuration: decisions, log lines, stacks, pot results, the
// PokerStars-style export and the replay frames of every hand.
import 'dart:io';

import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Archetype> _arch = [
  Archetype.tag,
  Archetype.lag,
  Archetype.nit,
  Archetype.station,
];

/// Mirrors the Node harness: every `Math.random()` of the desktop (first
/// button, shuffle, bot decisions, unseeded equity samples) is one
/// `nextDouble()` of the same [Mulberry32]. Seat 0 gets an archetype so the
/// table is all bots; the hand-history recorder is the desktop store's.
List<String> transcript({
  required int seed,
  required int hands,
  required int seats,
  required int ante,
  required int stack,
}) {
  final rng = Mulberry32(seed);
  final config = GameConfig(
    seats: seats,
    startingStack: stack,
    smallBlind: 10,
    bigBlind: 20,
    ante: ante,
  );
  var state = createTable(config, rng: rng);
  state.players[0].archetype = _arch[seed % 4];
  final out = <String>[];
  int lastId = 0;
  for (int h = 0; h < hands; h++) {
    state = startHand(state, rng: rng);
    final nt = state;
    final n = nt.config.seats;
    final hh = HHHand(
      id: nt.handNumber,
      startedAt: 1750000000000 + nt.handNumber * 1000,
      button: nt.button,
      sb: nt.smallBlind,
      bb: nt.bigBlind,
      sbSeat: n == 2 ? nt.button : (nt.button + 1) % n,
      bbSeat: n == 2 ? (nt.button + 1) % n : (nt.button + 2) % n,
      seats:
          nt.players
              .map(
                (p) => HHSeat(
                  seat: p.id,
                  name: p.name,
                  stack: nt.stacksAtStart[p.id],
                  isHero: p.isHero,
                  position: p.position,
                ),
              )
              .toList(),
      holes: {0: nt.players[0].hole},
    );
    out.add(
      'H${state.handNumber} btn=${state.button} '
      'pos=${state.players.map((p) => p.position.label).join(',')}',
    );
    int guard = 0;
    while (state.phase == GamePhase.betting &&
        state.toAct != null &&
        guard++ < 5000) {
      final seat = state.toAct!;
      final dec = decideBot(state, seat, rng: rng);
      final amt = dec.action.amount;
      out.add('  d$seat ${dec.action.type.label}${amt != null ? ' $amt' : ''}');
      final p = state.players[seat];
      final la = legalActions(state);
      int amount = 0;
      bool allIn = false;
      if (dec.action.type == ActionType.call) {
        amount = la.callAmount;
        allIn = amount >= p.stack;
      } else if (dec.action.type == ActionType.bet ||
          dec.action.type == ActionType.raise) {
        amount = amt ?? 0;
        allIn = amount >= p.committed + p.stack;
      }
      hh.actions.add(
        HHAction(
          street: state.street,
          seat: seat,
          name: p.name,
          type: dec.action.type,
          amount: amount,
          allIn: allIn,
        ),
      );
      state = applyAction(state, seat, dec.action);
      if (dec.range != null) state.botRanges[seat] = dec.range!;
    }
    hh.board = List.of(state.board);
    hh.potResults = state.summary?.potResults ?? [];
    hh.heroNet = state.summary?.heroNetChips ?? 0;
    for (final p in state.players) {
      hh.holes[p.id] = p.hole;
    }
    for (final e in state.log) {
      if (e.id > lastId) {
        out.add('  [${e.street.label}] ${e.text}');
        lastId = e.id;
      }
    }
    out.add(
      '  stacks=${state.players.map((p) => p.stack).join(',')} '
      'pot=${state.pot} hero=${state.summary?.heroNetChips}',
    );
    final sm = state.summary!;
    final pots = sm.potResults
        .map((p) => '${p.winners.join('+')}|${p.amount}|${p.potLabel}')
        .join(';');
    final sd = sm.showdown
        .map(
          (e) =>
              '${e.playerId}:${e.hole.join()}:${e.hand?.score}:${e.hand?.name}',
        )
        .join(';');
    out.add(
      '  pots=$pots sd=$sd board=${sm.board.join()} net=${sm.heroNetChips}',
    );
    out.addAll(formatHand(hh).split('\n').map((l) => '  |$l'));
    for (final f in buildReplayFrames(hh)) {
      out.add(
        '  f ${f.street.label}|${f.text}|${f.board.join()}|${f.pot}|'
        '${f.folded.join(',')}|${f.revealAll ? 1 : 0}',
      );
    }
  }
  return out;
}

/// Blanks the wall-clock rendering in a PokerStars header line.
///
/// `formatHand` prints LOCAL time (desktop parity — `handHistory.ts` uses
/// `Date.getHours()`), so the one line carrying a date differs between a
/// machine in Asia/Seoul and a UTC CI runner even though the hand, its
/// `startedAt` and its export id are identical. Everything else in the
/// transcript stays byte-exact; only this substring is masked, and the local
/// rendering itself is pinned separately in parity_review_game_test.dart.
String _tzAgnostic(String line) => line.replaceFirst(
  RegExp(r' - \d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} ET'),
  ' - <local time> ET',
);

void main() {
  final sections = <String, List<String>>{};
  String? current;
  for (final line
      in File('test/fixtures/lockstep_bots.txt').readAsLinesSync()) {
    if (line.startsWith('### ')) {
      current = line.substring(4);
      sections[current] = [];
    } else if (current != null) {
      sections[current]!.add(line);
    }
  }

  group('desktop lockstep transcript', () {
    test('fixture has sections', () => expect(sections.length, 4));
    for (final entry in sections.entries) {
      final params = {
        for (final kv in entry.key.split(' '))
          kv.split('=')[0]: int.parse(kv.split('=')[1]),
      };
      test(entry.key, () {
        final got = transcript(
          seed: params['seed']!,
          hands: params['hands']!,
          seats: params['seats']!,
          ante: params['ante']!,
          stack: params['stack']!,
        );
        final want = entry.value;
        for (int i = 0; i < want.length && i < got.length; i++) {
          expect(
            _tzAgnostic(got[i]),
            _tzAgnostic(want[i]),
            reason: 'line ${i + 1} of ${entry.key}',
          );
        }
        expect(got.length, want.length, reason: 'transcript length');
      });
    }
  });
}
