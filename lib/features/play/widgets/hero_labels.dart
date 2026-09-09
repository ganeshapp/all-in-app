/// The hero strip's right-hand text (DESIGN.md §4.4): the price line while
/// facing a bet, the hand label otherwise, and the made hand at hand-over.
library;

import 'package:allin/engine/engine.dart';

const Map<String, String> _pluralRank = {
  'A': 'aces',
  'K': 'kings',
  'Q': 'queens',
  'J': 'jacks',
  'T': 'tens',
  '9': 'nines',
  '8': 'eights',
  '7': 'sevens',
  '6': 'sixes',
  '5': 'fives',
  '4': 'fours',
  '3': 'threes',
  '2': 'deuces',
};

const Map<String, String> _rankWord = {
  'A': 'ace',
  'K': 'king',
  'Q': 'queen',
  'J': 'jack',
  'T': 'ten',
};

/// `"QQ · pocket queens"` · `"AKs · ace-king suited"` · `"K♠ 9♠ · suited"`.
String heroHandLabel(List<Card>? hole) {
  if (hole == null || hole.length < 2) return '';
  final a = hole[0];
  final b = hole[1];
  final label = cardsToLabel(a, b);
  final ra = a[0];
  final rb = b[0];
  final suited = a[1] == b[1];

  if (ra == rb) {
    final plural = _pluralRank[ra];
    return plural == null ? label : '$label · pocket $plural';
  }
  final wa = _rankWord[ra];
  final wb = _rankWord[rb];
  if (wa != null && wb != null) {
    return '$label · $wa-$wb ${suited ? 'suited' : 'offsuit'}';
  }
  return '${prettyCard(a)} ${prettyCard(b)} · ${suited ? 'suited' : 'offsuit'}';
}

/// The made hand shown at hand-over ("Two pair, queens and sevens").
String heroMadeHand(TableState table) {
  final hero = table.players[0];
  final summary = table.summary;
  if (summary != null) {
    for (final entry in summary.showdown) {
      if (entry.playerId == 0 && entry.hand != null) return entry.hand!.name;
    }
  }
  final hole = hero.hole;
  if (hole == null || hole.length < 2 || table.board.length < 3) {
    return heroHandLabel(hole);
  }
  return evaluateCards([...hole, ...table.board]).name;
}

/// §4.5 A while dragging the rail: the opponent's price if they call.
///
/// `potOdds = call / (pot + call)` where `call` is what the biggest remaining
/// opponent would owe against [raiseTo].
String opponentTimes(TableState table, int raiseTo) {
  var owed = 0;
  for (final p in table.players) {
    if (p.isHero || p.hasFolded || p.isAllIn) continue;
    final need = (raiseTo - p.committed).clamp(0, p.stack);
    if (need > owed) owed = need;
  }
  if (owed <= 0) return '1';
  final added = (raiseTo - table.players[0].committed).clamp(
    0,
    table.players[0].stack,
  );
  final pot = table.pot + added;
  final potOdds = owed / (pot + owed);
  if (potOdds <= 0) return '1';
  final rounded = jsRound(1 / potOdds * 2) / 2;
  return rounded == rounded.truncateToDouble()
      ? jsIntString(rounded)
      : jsToFixed(rounded, 1);
}
