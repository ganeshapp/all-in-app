/// Broadcast-style all-cards-known equity. Never used by the live bots.
library;

import 'cards.dart';
import 'evaluator.dart';
import 'prng.dart';
import 'types.dart';

class ReplayEquityRequest {
  ReplayEquityRequest({
    required Map<int, List<Card>?> holes,
    required List<int> activeSeats,
    required List<Card> board,
    this.iterations = 12000,
  }) : holes = Map.unmodifiable({
         for (final e in holes.entries)
           e.key: e.value == null ? null : List<Card>.unmodifiable(e.value!),
       }),
       activeSeats = List.unmodifiable(activeSeats.toList()..sort()),
       board = List.unmodifiable(board);

  final Map<int, List<Card>?> holes;
  final List<int> activeSeats;
  final List<Card> board;
  final int iterations;

  String get key {
    final seats = holes.keys.toList()..sort();
    return '${activeSeats.join(',')}|${board.join()}|'
        '${seats.map((s) => '$s:${holes[s]?.join() ?? '?'}').join(';')}|$iterations';
  }
}

class ReplayEquity {
  const ReplayEquity(this.shares, {this.exact = false, this.samples = 0});

  /// Expected share of a showdown, with tied winners splitting equally.
  /// Null means at least one live hand is unknown or the cards are invalid.
  final Map<int, double>? shares;
  final bool exact;
  final int samples;
}

ReplayEquity calculateReplayEquity(ReplayEquityRequest request) {
  final seats = request.activeSeats;
  if (seats.isEmpty || seats.toSet().length != seats.length) {
    return const ReplayEquity(null);
  }
  // A fold wins the hand regardless of whether the winner showed cards.
  if (seats.length == 1) return ReplayEquity({seats.single: 1}, exact: true);
  if (![0, 3, 4, 5].contains(request.board.length) || request.iterations < 1) {
    return const ReplayEquity(null);
  }
  if (seats.any((s) => request.holes[s]?.length != 2)) {
    return const ReplayEquity(null);
  }
  final known = [...request.board];
  for (final cards in request.holes.values) {
    if (cards == null) continue;
    if (cards.length != 2) return const ReplayEquity(null);
    known.addAll(cards);
  }
  final valid = RegExp(r'^[2-9TJQKA][cdhs]$');
  if (known.any((c) => !valid.hasMatch(c)) ||
      known.toSet().length != known.length) {
    return const ReplayEquity(null);
  }
  // All recorded folded cards are dead; unknown folded cards are marginalized.
  // Future board cards / burns / deck order are deliberately not inputs.
  final blocked = known.map(cardToInt).toSet();
  final deck = makeDeckInts()..removeWhere(blocked.contains);
  final board = request.board.map(cardToInt).toList();
  final missing = 5 - board.length;
  if (deck.length < missing) return const ReplayEquity(null);
  final buffers = [
    for (final s in seats)
      [
        ...request.holes[s]!.map(cardToInt),
        ...board,
        ...List.filled(missing, 0),
      ],
  ];
  final totals = List<double>.filled(seats.length, 0);
  final scores = List<int>.filled(seats.length, 0);
  var samples = 0;
  void score(List<int> runout) {
    var best = -1;
    var tied = 0;
    for (var s = 0; s < seats.length; s++) {
      for (var j = 0; j < missing; j++) {
        buffers[s][2 + board.length + j] = runout[j];
      }
      final value = scores[s] = evaluateScore(buffers[s]);
      if (value > best) {
        best = value;
        tied = 1;
      } else if (value == best) {
        tied++;
      }
    }
    for (var s = 0; s < seats.length; s++) {
      if (scores[s] == best) totals[s] += 1 / tied;
    }
    samples++;
  }

  if (missing == 0) {
    score(const []);
  } else if (missing == 1) {
    for (final card in deck) {
      score([card]);
    }
  } else if (missing == 2) {
    for (var i = 0; i < deck.length; i++) {
      for (var j = i + 1; j < deck.length; j++) {
        score([deck[i], deck[j]]);
      }
    }
  } else {
    final rng = Mulberry32(hashSeed(request.key));
    final runout = List<int>.filled(missing, 0);
    final swaps = List<int>.filled(missing, 0);
    for (var n = 0; n < request.iterations; n++) {
      for (var j = 0; j < missing; j++) {
        final k = swaps[j] = j + rng.nextInt(deck.length - j);
        final tmp = deck[j];
        deck[j] = deck[k];
        deck[k] = tmp;
        runout[j] = deck[j];
      }
      score(runout);
      for (var j = missing - 1; j >= 0; j--) {
        final k = swaps[j];
        final tmp = deck[j];
        deck[j] = deck[k];
        deck[k] = tmp;
      }
    }
  }
  return ReplayEquity(
    {for (var i = 0; i < seats.length; i++) seats[i]: totals[i] / samples},
    exact: missing <= 2,
    samples: samples,
  );
}
