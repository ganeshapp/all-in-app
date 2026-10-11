/// Counting outs — the number a player can actually reach at the table.
///
/// The coach's equity figure comes from thousands of simulated runouts, which
/// nobody can do in their head. Outs are the human version of the same idea,
/// and the app already teaches them (Study → "Counting Outs & the 2/4 Rule"),
/// so the coach should speak the same language: "four outs — the four 3s make
/// your straight" rather than only "26% equity".
///
/// An out here is a card that takes the hero from BEHIND to AHEAD of the hands
/// the opponents would actually be holding — not a card that merely improves
/// the hand. A queen that pairs you is no out when they are betting a board
/// that beats a pair of queens.
///
/// 1:1 port of `src/engine/outs.ts`.
library;

import 'cards.dart';
import 'equity.dart' show IntCombo;
import 'evaluator.dart';
import 'types.dart';

/// Indexed by `rankOf(card) - 2`, because [rankOf] returns 2..14.
const List<String> _rankPlurals = [
  '2s',
  '3s',
  '4s',
  '5s',
  '6s',
  '7s',
  '8s',
  '9s',
  '10s',
  'jacks',
  'queens',
  'kings',
  'aces',
];

/// Indexed by [suitOf], which indexes SUITS = ["c", "d", "h", "s"].
const List<String> _suitPlurals = ['clubs', 'diamonds', 'hearts', 'spades'];

const List<String> _countWords = [
  'no',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
];

/// Share of their hands you must beat to call yourself ahead.
const double kAheadBar = 0.7;

/// One pair has to clear a much higher bar before it counts as an out. A pair
/// that beats 70% of their hands still folds to the next bet; a straight that
/// beats 70% of them is a hand you keep betting. This is the difference
/// between telling someone they have seven outs on 6-5-4 with Q2o and telling
/// them the truth, which is four.
const double kOnePairBar = 0.9;

/// One group of outs that make the same kind of hand.
class OutGroup {
  const OutGroup({
    required this.cards,
    required this.cardsLabel,
    required this.makes,
    this.caution,
  });

  /// The cards themselves, so the UI can show them if it wants.
  final List<Card> cards;

  /// "the four 3s", "nine hearts", "three queens".
  final String cardsLabel;

  /// What they make: "a straight", "a pair".
  final String makes;

  /// Set when the hand this makes is the losing end of it — a straight any
  /// higher card also completes, or a low flush. The most valuable thing the
  /// count can tell you, and the thing that cost the Q2o hand 100 bb.
  final String? caution;
}

class OutsResult {
  const OutsResult({
    required this.count,
    required this.groups,
    required this.ahead,
    required this.share,
    this.holdUp,
  });

  static const OutsResult none = OutsResult(
    count: 0,
    groups: [],
    ahead: false,
    share: 0.5,
  );

  /// Cards that turn a losing hand into a winning one.
  final int count;
  final List<OutGroup> groups;

  /// True when the hero is already ahead of most of the range.
  final bool ahead;

  /// Share of the opponents' hands the hero currently beats.
  final double share;

  /// How often the biggest group of outs still wins once it arrives.
  final double? holdUp;
}

/// "the four 3s" / "nine hearts" / "two cards" for a mixed group.
String _nameCards(List<int> cards) {
  final n = cards.length;
  final count = n < _countWords.length ? _countWords[n] : '$n';
  final byRank = <int, int>{};
  for (final c in cards) {
    byRank[rankOf(c)] = (byRank[rankOf(c)] ?? 0) + 1;
  }
  final suits = <int>{for (final c in cards) suitOf(c)};

  // All one suit is a flush draw: "nine hearts" beats listing nine ranks.
  if (suits.length == 1 && byRank.length > 2) {
    return '$count ${_suitPlurals[suits.first]}';
  }

  // Otherwise name the ranks, which is how a player counts them.
  if (byRank.length <= 3) {
    final parts = [
      for (final e in byRank.entries)
        '${e.value == 4 ? 'the ' : ''}'
            '${e.value < _countWords.length ? _countWords[e.value] : e.value} '
            '${_rankPlurals[e.key - 2]}',
    ];
    final last = parts.removeLast();
    return parts.isEmpty ? last : '${parts.join(', ')} and $last';
  }
  if (suits.length == 1) return '$count ${_suitPlurals[suits.first]}';
  return '$count cards';
}

/// Plain name for what the improved hand is.
String _makesName(EvaluatedHand h) {
  final n = h.name.toLowerCase();
  if (n.startsWith('straight flush') || n.startsWith('royal')) {
    return 'a straight flush';
  }
  if (n.startsWith('four of a kind')) return 'four of a kind';
  if (n.startsWith('full house')) return 'a full house';
  if (n.startsWith('flush')) return 'a flush';
  if (n.startsWith('straight')) return 'a straight';
  if (n.startsWith('three of a kind')) return 'three of a kind';
  if (n.startsWith('two pair')) return 'two pair';
  if (n.startsWith('pair')) return 'a pair';
  return n;
}

/// Is this straight the losing end — would a card the hero does not hold make
/// a bigger one for somebody else? Drawing to the bottom end is the trap the
/// 2/4 rule alone never warns you about.
String? _straightCaution(IntCombo hero, List<int> board, int card) {
  final made = evaluateInts([hero[0], hero[1], ...board, card]);
  if (!made.name.toLowerCase().startsWith('straight')) return null;
  final mine = made.score;
  final seen = <int>{hero[0], hero[1], ...board, card};
  final free = [
    for (int i = 0; i < 52; i++)
      if (!seen.contains(i)) i,
  ];
  for (int a = 0; a < free.length; a++) {
    for (int b = a + 1; b < free.length; b++) {
      final theirs = evaluateInts([free[a], free[b], ...board, card]);
      if (theirs.score > mine &&
          theirs.name.toLowerCase().startsWith('straight')) {
        return 'it is the low end — a higher straight is possible on that card';
      }
    }
  }
  return null;
}

/// Is this flush beatable by a higher one of the same suit?
String? _flushCaution(IntCombo hero, List<int> board, int card) {
  final made = evaluateInts([hero[0], hero[1], ...board, card]);
  if (!made.name.toLowerCase().startsWith('flush')) return null;
  final suit = suitOf(card);
  int mineHigh = -1;
  for (final c in [hero[0], hero[1]]) {
    if (suitOf(c) == suit && rankOf(c) > mineHigh) mineHigh = rankOf(c);
  }
  final seen = <int>{hero[0], hero[1], ...board, card};
  for (int r = mineHigh + 1; r <= 14; r++) {
    final higher = (r - 2) * 4 + suit;
    if (higher >= 0 && higher < 52 && !seen.contains(higher)) {
      return 'a higher card of that suit beats it';
    }
  }
  return null;
}

/// Count the hero's outs against the hands the opponents are actually holding.
///
/// [ranges] is one range per opponent still in the hand. The hero is "ahead"
/// when they already beat most of those hands; a card is an out when it flips
/// them from behind to ahead.
OutsResult countOuts(
  IntCombo hero,
  List<int> board,
  List<List<IntCombo>> ranges, {
  int sampleCap = 120,
}) {
  if (board.length < 3 || board.length > 4) return OutsResult.none;

  final used = <int>{hero[0], hero[1], ...board};
  final pool = <IntCombo>[];
  for (final r in ranges) {
    for (final c in r) {
      if (!used.contains(c[0]) && !used.contains(c[1])) pool.add(c);
    }
  }
  if (pool.isEmpty) return OutsResult.none;

  // Evenly thin a large range rather than taking the first N, which would be
  // sorted by label and bias toward one corner of the grid.
  final step = (pool.length / sampleCap).ceil().clamp(1, pool.length);
  final sample = <IntCombo>[];
  for (int i = 0; i < pool.length; i += step) {
    sample.add(pool[i]);
  }

  double beats(List<int> extra) {
    final mine = evaluateInts([hero[0], hero[1], ...board, ...extra]).score;
    int ahead = 0;
    int counted = 0;
    for (final c in sample) {
      if (extra.contains(c[0]) || extra.contains(c[1])) continue;
      counted++;
      if (mine > evaluateInts([c[0], c[1], ...board, ...extra]).score) {
        ahead++;
      }
    }
    return counted == 0 ? 0 : ahead / counted;
  }

  // Beating one opponent is not beating three: a hand has to get past all of
  // them, so the shares multiply.
  final opponents = ranges.isEmpty ? 1 : ranges.length;
  double beatsAll(List<int> extra) {
    final one = beats(extra);
    double acc = 1;
    for (int i = 0; i < opponents; i++) {
      acc *= one;
    }
    return acc;
  }

  final share = beatsAll(const []);
  if (share >= kAheadBar) {
    return OutsResult(count: 0, groups: const [], ahead: true, share: share);
  }

  final winners = <int>[];
  for (int c = 0; c < 52; c++) {
    if (used.contains(c)) continue;
    final after = evaluateInts([hero[0], hero[1], ...board, c]);
    final onePair = after.name.toLowerCase().startsWith('pair');
    if (beatsAll([c]) >= (onePair ? kOnePairBar : kAheadBar)) winners.add(c);
  }
  if (winners.isEmpty) {
    return OutsResult(count: 0, groups: const [], ahead: false, share: share);
  }

  // Group by the hand each card makes, so the count reads as poker rather
  // than as a list of 47 cards.
  final byMakes = <String, List<int>>{};
  for (final c in winners) {
    final key = _makesName(evaluateInts([hero[0], hero[1], ...board, c]));
    byMakes.putIfAbsent(key, () => <int>[]).add(c);
  }

  final groups = <OutGroup>[];
  for (final e in byMakes.entries) {
    // An open-ended draw can have one end that wins and one that does not, so
    // the warning has to describe the group rather than its first card.
    final flagged = [
      for (final c in e.value)
        if ((_straightCaution(hero, board, c) ??
                _flushCaution(hero, board, c)) !=
            null)
          c,
    ];
    final sampleCaution =
        flagged.isEmpty
            ? null
            : (_straightCaution(hero, board, flagged.first) ??
                _flushCaution(hero, board, flagged.first));
    groups.add(
      OutGroup(
        cards: [for (final c in e.value) intToCard(c)],
        cardsLabel: _nameCards(e.value),
        makes: e.key,
        caution:
            flagged.isEmpty
                ? null
                : flagged.length == e.value.length
                ? sampleCaution
                : 'the low ones can still lose to a better version of the '
                    'same hand',
      ),
    );
  }
  groups.sort((a, b) => b.cards.length - a.cards.length);

  // How often the headline out actually holds up once it lands. Four outs you
  // only win four times in five with are not really four outs, and this is
  // exactly what a draw to the small end of a straight hides.
  final holdUp = beatsAll([cardToInt(groups.first.cards.first)]);

  return OutsResult(
    count: winners.length,
    groups: groups,
    ahead: false,
    share: share,
    holdUp: holdUp,
  );
}

/// "four outs: the four 3s make a straight, though it is the low end".
String describeOuts(OutsResult o) {
  if (o.ahead || o.count == 0) return '';
  final n = o.count < _countWords.length ? _countWords[o.count] : '${o.count}';
  final parts = [
    for (final g in o.groups)
      g.caution == null
          ? '${g.cardsLabel} make ${g.makes}'
          : '${g.cardsLabel} make ${g.makes} — though ${g.caution}',
  ];
  return '$n out${o.count == 1 ? '' : 's'}: ${parts.join('; ')}';
}

/// The 2/4 rule the app teaches, as a fraction.
double ruleOfTwoFour(int outs, int cardsToCome) {
  final v = outs * (cardsToCome >= 2 ? 4 : 2) / 100;
  return v > 1 ? 1 : v;
}
