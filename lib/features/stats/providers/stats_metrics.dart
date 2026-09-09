/// Every number the Progress tab shows, derived from one [StatsSnapshot].
///
/// Pure: no Riverpod, no Flutter, no I/O — the derivations of
/// `docs/port/persistence-stats-settings.md` §7.1–§7.8 translated one for one,
/// so they can be hand-checked in a test against a fixture snapshot
/// (`test/features/stats/stats_metrics_test.dart`).
///
/// Two invariants the desktop relies on and this file keeps:
///
/// * `chartBase + Σ history.netBb == netChips / bigBlind`, so the cumulative
///   chart's last point always equals the "Net" KPI however many old hands
///   have fallen out of the 800-row window (§5).
/// * every per-style net is divided by the number of styles in that hand, so
///   the four archetype nets sum to the true total (§7.1 `archAgg`).
library;

import '../../../engine/engine.dart';
import '../../../services/persistence.dart' show GuessRecord, StatsSnapshot;
import '../stats_copy.dart';

/// One row of "Hands vs each style" (§7.5).
class ArchetypeStat {
  const ArchetypeStat({
    required this.archetype,
    required this.hands,
    required this.net,
  });

  final Archetype archetype;

  /// Hands where this style put in more than one big blind.
  final int hands;

  /// Hero net in bb, split evenly between the styles in a multiway hand.
  final double net;
}

/// One row of "Winnings by position" (§7.7).
class PositionStat {
  const PositionStat({
    required this.position,
    required this.hands,
    required this.net,
    required this.rate,
  });

  final Position position;
  final int hands;

  /// Hero net in bb from this seat.
  final double net;

  /// bb/100 from this seat; 0 when no hand was tracked here.
  final double rate;
}

/// The desktop's `POS` order (§7.7).
const List<Position> kPositionOrder = [
  Position.utg,
  Position.mp,
  Position.co,
  Position.btn,
  Position.sb,
  Position.bb,
];

/// The desktop's archetype display order (§7.5).
const List<Archetype> kArchetypeOrder = [
  Archetype.tag,
  Archetype.lag,
  Archetype.nit,
  Archetype.station,
];

/// Reads below this mean, over at least [kReadLeakMinGuesses] reads, add the
/// read-accuracy sentence to the coaching review (§7.1 `allLeaks`).
const double kReadLeakThreshold = 0.5;
const int kReadLeakMinGuesses = 5;

/// Recent −EV rows shown under the coaching review (§7.6).
const int kRecentMistakeLimit = 5;

/// Peek scores drawn by `MiniBars` (§7.4).
const int kReadBarLimit = 30;

class StatsMetrics {
  const StatsMetrics({
    required this.snapshot,
    required this.chartBase,
    required this.cumulative,
    required this.archetypes,
    required this.positions,
    required this.leak,
    required this.allLeaks,
    required this.recentMistakes,
    required this.showdownHands,
    required this.showdownWon,
    required this.wonBb,
    required this.lostBb,
    required this.flopsSeen,
    required this.showdownsFromFlops,
    required this.aggressiveActions,
    required this.callActions,
  });

  /// The window every number below came from.
  final StatsSnapshot snapshot;

  /// `netChips / bigBlind − Σ history.netBb` — the offset that keeps the
  /// chart reconciled with the lifetime net (§5).
  final double chartBase;

  /// Running sum, one point per hand in the window (§7.1).
  final List<double> cumulative;

  final List<ArchetypeStat> archetypes;
  final List<PositionStat> positions;

  /// `leaksFromDecisions(decisions)` (§8).
  final LeakReport leak;

  /// [leak]'s sentences plus the read-accuracy line when it applies (§7.1).
  final List<String> allLeaks;

  /// The last five "mistake" decisions, newest first (§7.1).
  final List<DecisionRecord> recentMistakes;

  /// Hands that reached showdown, and how many of those hero won.
  final int showdownHands;
  final int showdownWon;

  /// Σ of positive and (absolute) negative hand results, in bb — the two
  /// halves of the Net explainer's arithmetic.
  final double wonBb;
  final double lostBb;

  /// Hands with `sawFlop == true` (records without the field are excluded,
  /// §7.8), and how many of those reached showdown.
  final int flopsSeen;
  final int showdownsFromFlops;

  /// Coached decisions that bet or raised, and that called (§7.8 AF).
  final int aggressiveActions;
  final int callActions;

  int get handsPlayed => snapshot.handsPlayed;
  int get netChips => snapshot.netChips;
  int get bigBlind => snapshot.bigBlind;
  List<GuessRecord> get guesses => snapshot.guesses;
  List<DecisionRecord> get decisions => snapshot.decisions;

  /// Lifetime net in big blinds.
  double get netBb => snapshot.bigBlind == 0 ? 0 : netChips / bigBlind;

  /// Lifetime bb/100.
  double get bb100 => handsPlayed > 0 ? (netBb / handsPlayed) * 100 : 0;

  /// Showdown win rate, 0 when nothing reached one.
  double get sdWin => showdownHands == 0 ? 0 : showdownWon / showdownHands;

  /// Mean Peek score over every read, 0 when there are none.
  double get avgAcc =>
      guesses.isEmpty
          ? 0
          : guesses.fold<double>(0, (a, g) => a + g.accuracy) / guesses.length;

  /// The scores `MiniBars` draws — the last [kReadBarLimit] reads.
  List<double> get readScores {
    final all = [for (final g in guesses) g.accuracy];
    return all.length <= kReadBarLimit
        ? all
        : all.sublist(all.length - kReadBarLimit);
  }

  /// Largest style sample, floored at 1 so the bars have a denominator.
  int get maxArchetypeHands =>
      archetypes.fold<int>(1, (a, s) => s.hands > a ? s.hands : a);

  /// Hands with a recorded position (§7.7 `tracked`).
  int get trackedPositions => positions.fold<int>(0, (a, p) => a + p.hands);

  /// Largest |bb/100| among the positions, floored at 1 (§7.7 `maxAbs`).
  double get maxPositionRate =>
      positions.fold<double>(1, (a, p) => p.rate.abs() > a ? p.rate.abs() : a);

  /// WTSD — null until at least one hand recorded `sawFlop` (§7.8).
  double? get wtsd => flopsSeen == 0 ? null : showdownsFromFlops / flopsSeen;

  /// W$SD — null until a hand reached showdown (§7.8).
  double? get wsd => showdownHands == 0 ? null : showdownWon / showdownHands;

  /// Aggression factor — null until a coached call exists (§7.8).
  double? get af => callActions == 0 ? null : aggressiveActions / callActions;

  /// True before any hand has been played *and* nothing else was ever
  /// recorded — the §14 "Stats · no hands" first-run screen.
  bool get isEmpty =>
      handsPlayed == 0 &&
      snapshot.history.isEmpty &&
      guesses.isEmpty &&
      decisions.isEmpty;

  /// bb/100 over the last [n] hands in the window — the trend companion to
  /// the lifetime KPI. Null when fewer than [n] hands are in the window, so a
  /// caller never prints a "last 100" built from 12 hands.
  double? bb100Over(int n) {
    final history = snapshot.history;
    if (n <= 0 || history.length < n) return null;
    final window = history.sublist(history.length - n);
    final net = window.fold<double>(0, (a, h) => a + h.netBb);
    return (net / n) * 100;
  }

  /// The trend windows the Progress tab and Home may show beside the KPI:
  /// last 100 and last 500 hands, absent until they are full.
  Map<int, double> get trendWindows => {
    for (final n in const [100, 500])
      if (bb100Over(n) case final double v) n: v,
  };
}

/// Derives every Progress number from [snapshot] (§7.1).
StatsMetrics computeStatsMetrics(StatsSnapshot snapshot) {
  final history = snapshot.history;
  final bb = snapshot.bigBlind == 0 ? 1 : snapshot.bigBlind;

  final historyBb = history.fold<double>(0, (a, h) => a + h.netBb);
  final chartBase = snapshot.netChips / bb - historyBb;

  final cumulative = <double>[];
  var acc = chartBase;
  for (final h in history) {
    acc += h.netBb;
    cumulative.add(acc);
  }

  var showdownHands = 0;
  var showdownWon = 0;
  var wonBb = 0.0;
  var lostBb = 0.0;
  var flopsSeen = 0;
  var showdownsFromFlops = 0;
  for (final h in history) {
    if (h.showdown) {
      showdownHands++;
      if (h.won) showdownWon++;
    }
    if (h.netBb >= 0) {
      wonBb += h.netBb;
    } else {
      lostBb += -h.netBb;
    }
    if (h.sawFlop == true) {
      flopsSeen++;
      if (h.showdown) showdownsFromFlops++;
    }
  }

  final archetypes = <ArchetypeStat>[
    for (final a in kArchetypeOrder)
      () {
        var hands = 0;
        var net = 0.0;
        for (final h in history) {
          if (!h.archetypes.contains(a)) continue;
          hands++;
          // Multiway hands split their result between the styles involved,
          // so the four nets sum to the true total (§7.1).
          net += h.netBb / (h.archetypes.isEmpty ? 1 : h.archetypes.length);
        }
        return ArchetypeStat(archetype: a, hands: hands, net: net);
      }(),
  ];

  final positions = <PositionStat>[
    for (final p in kPositionOrder)
      () {
        var hands = 0;
        var net = 0.0;
        for (final h in history) {
          if (h.position != p) continue;
          hands++;
          net += h.netBb;
        }
        return PositionStat(
          position: p,
          hands: hands,
          net: net,
          rate: hands == 0 ? 0 : (net / hands) * 100,
        );
      }(),
  ];

  var aggressive = 0;
  var calls = 0;
  for (final d in snapshot.decisions) {
    if (d.action == 'bet' || d.action == 'raise') aggressive++;
    if (d.action == 'call') calls++;
  }

  final leak = leaksFromDecisions(snapshot.decisions);

  final guesses = snapshot.guesses;
  final avgAcc =
      guesses.isEmpty
          ? 0.0
          : guesses.fold<double>(0, (a, g) => a + g.accuracy) / guesses.length;
  final allLeaks = <String>[
    ...leak.leaks,
    // The desktop appends this sentence after the decision leaks (§7.1).
    if (guesses.length >= kReadLeakMinGuesses && avgAcc < kReadLeakThreshold)
      StatsCopy.readAccuracyLeak,
  ];

  final mistakes = [
    for (final d in snapshot.decisions)
      if (d.verdict == 'mistake') d,
  ];
  final recent =
      (mistakes.length <= kRecentMistakeLimit
              ? mistakes
              : mistakes.sublist(mistakes.length - kRecentMistakeLimit))
          .reversed
          .toList();

  return StatsMetrics(
    snapshot: snapshot,
    chartBase: chartBase,
    cumulative: cumulative,
    archetypes: archetypes,
    positions: positions,
    leak: leak,
    allLeaks: allLeaks,
    recentMistakes: recent,
    showdownHands: showdownHands,
    showdownWon: showdownWon,
    wonBb: wonBb,
    lostBb: lostBb,
    flopsSeen: flopsSeen,
    showdownsFromFlops: showdownsFromFlops,
    aggressiveActions: aggressive,
    callActions: calls,
  );
}
