// ignore_for_file: avoid_print
import 'package:allin/engine/archetypes.dart';
import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/types.dart';

const _phaseLabels = {
  GamePhase.idle: 'idle',
  GamePhase.betting: 'betting',
  GamePhase.streetEnd: 'street-end',
  GamePhase.showdown: 'showdown',
  GamePhase.handOver: 'hand-over',
};
const _kindLabels = {
  LogKind.action: 'action',
  LogKind.deal: 'deal',
  LogKind.result: 'result',
  LogKind.info: 'info',
};
String _phase(GamePhase p) => _phaseLabels[p]!;
String _kind(LogKind k) => _kindLabels[k]!;

String dump(TableState s) {
  final P = s.players
      .map((p) => [
            p.id,
            p.name,
            p.archetype?.label ?? '-',
            p.stack,
            p.hole != null ? p.hole!.join() : '-',
            p.revealed ? 1 : 0,
            p.hasFolded ? 1 : 0,
            p.foldedStreet?.label ?? '-',
            p.isAllIn ? 1 : 0,
            p.committed,
            p.committedTotal,
            p.acted ? 1 : 0,
            p.position.label,
            p.lastAction != null
                ? '${p.lastAction!.label}@${p.lastAction!.street.label}'
                : '-',
            p.handsSeen,
            p.vpipCount,
            p.pfrCount,
            p.vpipThisHand ? 1 : 0,
            p.pfrThisHand ? 1 : 0,
          ].join('/'))
      .join(' ');
  final la = legalActions(s);
  final L = [
    la.toCall,
    la.canFold ? 1 : 0,
    la.canCheck ? 1 : 0,
    la.canCall ? 1 : 0,
    la.callAmount,
    la.canBet ? 1 : 0,
    la.canRaise ? 1 : 0,
    la.minRaiseTo,
    la.maxRaiseTo,
    la.potSize,
    la.bigBlind,
  ].join('/');
  final sum = s.summary;
  final sm = sum != null
      ? '${sum.handNumber}|${sum.potResults.map((r) => '${r.winners.join('+')}:${r.amount}:${r.potLabel}').join(';')}|'
          '${sum.showdown.map((e) => '${e.playerId}:${e.hole.join()}:${e.hand!.score}:${e.hand!.name}:${e.hadToShow ? 1 : 0}').join(';')}|'
          '${sum.board.join()}|${sum.heroNetChips}'
      : '-';
  return [
    'P $P',
    'B ${s.board.join()} deck=${s.deck.length}:${s.deck.join()}',
    'S street=${s.street.label} pot=${s.pot} cb=${s.currentBet} lrs=${s.lastRaiseSize} '
        'agg=${s.aggressor} toAct=${s.toAct} hn=${s.handNumber} phase=${_phase(s.phase)} '
        'logSeq=${s.logSeq} sas=${s.stacksAtStart.join(',')} btn=${s.button}',
    'L $L',
    'G ${s.log.map((e) => '${e.id}:${e.street.label}:${_kind(e.kind)}:${e.text}').join(' || ')}',
    'M $sm',
    'H hero=${heroSeat(s).id} heroTurn=${isHeroTurn(s) ? 1 : 0} '
        'order=${playersLeftOfButtonOrder(s).map((p) => p.id).join(',')}',
  ].join('\n');
}

final _all = allLabels();

String probe(TableState s, Mulberry32 botRng) {
  if (s.phase != GamePhase.betting || s.toAct == null) return '-';
  final d = decideBot(s, s.toAct!, rng: botRng);
  final a = d.action.amount;
  return '${d.action.type.label}${a != null ? ' $a' : ''} '
      'r=${d.range == null ? "null" : d.range!.join(",")}';
}

void seedRanges(TableState s, Mulberry32 pick) {
  for (final p in s.players) {
    final r = pick.next();
    if (r < 0.3) continue;
    if (r < 0.4) {
      s.botRanges[p.id] = <HandLabel>[];
      continue;
    }
    final size = (pick.next() * 60).floor();
    final set = <HandLabel>[];
    for (int i = 0; i < size; i++) {
      set.add(_all[(pick.next() * _all.length).floor()]);
    }
    s.botRanges[p.id] = set;
  }
}

void main(List<String> args) {
  final seed = int.parse(args[0]);
  final hands = int.parse(args[1]);
  final seats = int.parse(args[2]);
  final ante = int.parse(args[3]);
  final stack = int.parse(args[4]);
  final rng = Mulberry32(seed);
  final pick = Mulberry32(seed ^ 0x5bf03635);
  final botRng = Mulberry32(seed ^ 0x1234abcd);
  final config = GameConfig(
    seats: seats,
    startingStack: stack,
    smallBlind: 10,
    bigBlind: 20,
    ante: ante,
  );
  var s = createTable(config, rng: rng);
  s.players[0].archetype = archetypeForSeat(1 + (seed % 5));
  final out = <String>[];
  out.add('== createTable');
  out.add(dump(s));
  const types = [
    ActionType.fold,
    ActionType.check,
    ActionType.call,
    ActionType.bet,
    ActionType.raise,
    ActionType.post,
  ];
  for (int h = 0; h < hands; h++) {
    s = startHand(s, rng: rng);
    out.add('== startHand $h');
    out.add(dump(s));
    seedRanges(s, pick);
    out.add('  probe ${probe(s, botRng)}');
    int guard = 0;
    while (s.phase == GamePhase.betting && guard++ < 400) {
      final seat = s.toAct;
      final r = pick.next();
      final t = types[(pick.next() * 6).floor()];
      final useSeat =
          pick.next() < 0.08 ? (pick.next() * seats).floor() : (seat ?? 0);
      final la = legalActions(s);
      int? amount;
      final ar = pick.next();
      if (ar < 0.2) {
        amount = null;
      } else if (ar < 0.4) {
        amount = (pick.next() * 4000).floor() - 200;
      } else if (ar < 0.6) {
        amount = la.minRaiseTo;
      } else if (ar < 0.8) {
        amount = la.maxRaiseTo;
      } else {
        amount =
            (la.minRaiseTo + pick.next() * (la.maxRaiseTo - la.minRaiseTo + 1))
                .floor();
      }
      out.add('== act seat=$useSeat ${t.label} ${amount ?? "-"} '
          '(r=${jsToFixed(r, 6)})');
      s = applyAction(s, useSeat, Action(t, amount: amount));
      out.add(dump(s));
      if (pick.next() < 0.35) seedRanges(s, pick);
      out.add('  probe ${probe(s, botRng)}');
    }
  }
  print(out.join('\n'));
}
