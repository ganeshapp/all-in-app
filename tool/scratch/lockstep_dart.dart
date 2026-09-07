// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:math' as math;
import 'package:allin/engine/archetypes.dart';
import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/hh_import.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';

const List<Archetype> arch = [
  Archetype.tag,
  Archetype.lag,
  Archetype.nit,
  Archetype.station,
];

String amt(num? a) => a == null ? '' : ' ${a is int ? a : a}';

void main(List<String> args) {
  final seed = int.parse(args[0]);
  final hands = int.parse(args[1]);
  final seats = int.parse(args[2]);
  final ante = int.parse(args[3]);
  final stack = int.parse(args[4]);
  const now = 1700000000000;
  final rng = Mulberry32(seed);
  final config = GameConfig(
    seats: seats,
    startingStack: stack,
    smallBlind: 10,
    bigBlind: 20,
    ante: ante,
  );
  var state = createTable(config, rng: rng);
  state.players[0].archetype = arch[seed % 4];
  if (args.length > 5 && int.parse(args[5]) != 0) {
    double jitter(double v, double frac, double lo, double hi) => math.min(
        hi, math.max(lo, v * (1 - frac + rng.nextDouble() * 2 * frac)));
    for (final p in state.players) {
      if (p.isHero) continue;
      final cfg = kArchetypes[p.archetype!]!;
      p.dials = Dials(
        aggression: jitter(cfg.aggression, 0.2, 0.05, 0.95),
        stickiness: jitter(cfg.stickiness, 0.2, 0.05, 0.95),
        cbetFlop: jitter(cfg.cbetFlop.toDouble(), 0.15, 20, 95),
      );
    }
  }
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
      seats: nt.players
          .map((p) => HHSeat(
                seat: p.id,
                name: p.name,
                stack: nt.stacksAtStart[p.id],
                isHero: p.isHero,
                position: p.position,
              ))
          .toList(),
      holes: {0: nt.players[0].hole},
    );
    out.add('H${state.handNumber} btn=${state.button} '
        'pos=${state.players.map((p) => p.position.label).join(',')}');
    int guard = 0;
    while (state.phase == GamePhase.betting &&
        state.toAct != null &&
        guard++ < 5000) {
      final seat = state.toAct!;
      final dec = decideBot(state, seat, rng: rng);
      final a = dec.action.amount;
      out.add('  d$seat ${dec.action.type.label}${a != null ? ' $a' : ''} '
          'r=${dec.range == null ? "null" : dec.range!.join(",")}');
      final p = state.players[seat];
      final la = legalActions(state);
      int amount = 0;
      bool allIn = false;
      if (dec.action.type == ActionType.call) {
        amount = la.callAmount;
        allIn = amount >= p.stack;
      } else if (dec.action.type == ActionType.bet ||
          dec.action.type == ActionType.raise) {
        amount = a ?? 0;
        allIn = amount >= p.committed + p.stack;
      }
      hh.actions.add(HHAction(
        street: state.street,
        seat: seat,
        name: p.name,
        type: dec.action.type,
        amount: amount,
        allIn: allIn,
      ));
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
    out.add('  stacks=${state.players.map((p) => p.stack).join(',')} '
        'pot=${state.pot} hero=${state.summary?.heroNetChips}');
    final sm = state.summary!;
    out.add('  pots=${sm.potResults.map((p) => '${p.winners.join('+')}|${p.amount}|${p.potLabel}').join(';')} '
        'sd=${sm.showdown.map((e) => '${e.playerId}:${e.hole.join()}:${e.hand?.score}:${e.hand?.name}').join(';')} '
        'board=${sm.board.join()} net=${sm.heroNetChips}');
    out.add('  json=${jsonEncode(hh.toJson())}');
    final text = formatHand(hh);
    out.addAll(text.split('\n').map((l) => '  |$l'));
    for (final f in buildReplayFrames(hh)) {
      out.add('  f ${f.street.label}|${f.text}|${f.board.join()}|${f.pot}|'
          '${f.folded.join(',')}|${f.revealAll ? 1 : 0}');
    }
    final parsed = parsePokerStars(text, now: now);
    out.add('  parsed=${parsed.hands.length}/${parsed.skipped} '
        '${parsed.hands.isEmpty ? 'undefined' : jsonEncode(parsed.hands[0].toJson())}');
    final an = analyzeImported(parsed.hands, now: now);
    out.add('  analyzed=${an.reviewed} '
        '${an.leaks.map((l) => jsonEncode(l.toJson())).join(' ; ')}');
  }
  print(out.join('\n'));
}
