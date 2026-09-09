/// P10's numbers and copy (DESIGN.md §4.13; docs/port/play-loop-and-coach.md
/// §20).
///
/// One shape, [SessionSummaryData], feeds both hosts:
///
/// * the **live** summary over the table (`/table/summary`), built from
///   `SessionNotifier`'s counters and hand history, and
/// * the **read-only** copies (`/{branch}/session/:id`), built from the
///   `sessions` row the notifier wrote when the session ended.
///
/// The debrief is computed here rather than in the widget so the three-layer
/// copy of §4.13 — layer 1's paragraph, "Show me the math"'s counts and
/// "Expert detail"'s rules — can be asserted without pumping a screen.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/* --------------------------------------------------------------- copy */

abstract final class SummaryCopy {
  /// §4.13 titles.
  static const String title = 'Session summary';
  static const String bustedTitle = 'Session over — you busted';
  static const String readOnlyTitle = 'Session';

  static String handsPlayed(int hands) =>
      '$hands hand${hands == 1 ? '' : 's'} played this session.';

  /// The debrief card's eyebrow *(desktop)*.
  static const String debriefEyebrow = 'How you played (before how it paid)';

  /// §4.13 *(new)* — the degenerate debrief, when the coach was switched off.
  static const String noCoachedDecisions =
      'No coached decisions this session — the EV Coach was off.';

  /// The same degenerate case with the coach ON: nothing was graded because no
  /// decision reached it (a session ended before the hero acted). Saying "the
  /// EV Coach was off" here would be a lie the user can disprove in one tap —
  /// see the copy-change table in docs/ARCHITECTURE.md.
  static const String noDecisionsYet =
      'No decisions to grade yet — the EV Coach had nothing to weigh in on this '
      'session.';

  /// §4.13, verbatim.
  static String showdownLine(int showdowns) =>
      '$showdowns hand${showdowns == 1 ? '' : 's'} reached showdown. Replay '
      'any hand below, or export the full history for a poker tracker.';

  static const String reviewHands = 'REVIEW HANDS';
  static const String share = 'Share';
  static const String newSession = 'New session';
  static const String done = 'Done';
  static const String replay = 'Replay';
  static const String note = 'Note';

  /// §4.13 — nothing was played, so there is nothing to replay or share.
  static const String noHands =
      'No hands played this session — nothing to replay yet.';

  /// The read-only host's subtitle: "Today 18:10 · 6-max".
  static String seatsLabel(int seats) => switch (seats) {
    2 => 'Heads-up',
    9 => '9-max',
    _ => '6-max',
  };

  /// §4.13's mistakes link.
  static const String reviewSpots = 'Review these spots ›';

  /// §14's storage family — the only failure "Share" can hit.
  static const String storageProblem = "Some data couldn't be saved";
}

/* --------------------------------------------------------------- debrief */

/// The three layers of §4.13's debrief card.
@immutable
class SessionDebrief {
  const SessionDebrief({
    required this.paragraph,
    required this.mathLines,
    required this.expertLines,
    this.best,
    this.costliest,
    this.hasFlagged = false,
  });

  /// Layer 1 — the paragraph. Never empty.
  final String paragraph;

  /// "Best: a turn raise worth +3.2 bb."
  final String? best;

  /// "Costliest: a river call (−3.1 bb) — it's in your Review queue."
  final String? costliest;

  /// Layer 2 — the counts, mono.
  final List<String> mathLines;

  /// Layer 3 — the rule behind "flagged".
  final List<String> expertLines;

  /// The costliest line links into the Review queue only when something was
  /// actually flagged.
  final bool hasFlagged;
}

/// §4.13's expert layer, verbatim *(all new)*.
const List<String> kDebriefExpertLines = [
  "A decision is flagged when the coach's EV estimate for your action is "
      'below the best legal action by more than the strictness threshold — '
      '0.5 bb on Relaxed, 0.25 bb on Standard, 0.1 bb on Strict — and the gap '
      "is outside the simulation's noise band for that spot.",
  "'Cleaner than average' means this session's rate is at least 2 points "
      "under your lifetime rate; '— a rougher one' is 2 points over; inside "
      '±2 the clause is omitted.',
  'Only decisions made with the EV Coach on are counted, so a session played '
      'with it off shows no card at all.',
];

/// Builds §4.13's debrief from this session's counters and the lifetime
/// decision totals.
SessionDebrief buildDebrief({
  required SessionCounters counters,
  required int lifetimeCoached,
  required int lifetimeFlagged,
  bool coachWasOff = true,
}) {
  final n = counters.coachedDecisions;
  final m = counters.flaggedDecisions;

  if (n == 0) {
    return SessionDebrief(
      paragraph:
          coachWasOff
              ? SummaryCopy.noCoachedDecisions
              : SummaryCopy.noDecisionsYet,
      mathLines: const <String>[],
      expertLines: const <String>[],
    );
  }

  final sessionRate = (m / n * 100).round();
  final lifeRate =
      lifetimeCoached > 0
          ? (lifetimeFlagged / lifetimeCoached * 100).round()
          : null;

  // The comparison only means something once the user has decisions outside
  // this session (port §20).
  final compare = lifeRate != null && lifetimeCoached > n;
  final judgement =
      !compare
          ? ''
          : sessionRate <= lifeRate - 2
          ? ' — cleaner than average'
          : sessionRate >= lifeRate + 2
          ? ' — a rougher one'
          : '';
  final rateClause =
      compare ? ' ($sessionRate % vs your usual $lifeRate %$judgement)' : '';

  final paragraph =
      '$n coached decision${n == 1 ? '' : 's'}, $m flagged as '
      'mistake${m == 1 ? '' : 's'}$rateClause.';

  final bestEv = counters.bestEvBb;
  final bestLabel = counters.bestEvLabel;
  final worstEv = counters.worstEvBb;
  final worstLabel = counters.worstEvLabel;

  final best =
      bestEv == null || bestLabel == null
          ? null
          : 'Best: a $bestLabel worth ${fmtSigned(bestEv)} bb.';
  // With a single coached decision the best and the costliest are the same
  // action; printing it twice would read as two separate spots.
  final costliest =
      worstEv == null || worstLabel == null || n < 2
          ? null
          : 'Costliest: a $worstLabel (${fmtSigned(worstEv)} bb)'
              '${m > 0 ? " — it's in your Review queue." : '.'}';

  final math = <String>[
    '$m of $n coached decision${n == 1 ? '' : 's'} '
        '${m == 1 ? 'was' : 'were'} flagged this session = $sessionRate %.',
    if (lifeRate != null)
      'Lifetime: $lifetimeFlagged of $lifetimeCoached = $lifeRate %.',
    if (bestEv != null && worstEv != null)
      "Best and costliest are the highest and lowest EV among this session's "
          'coached decisions: ${fmtSigned(bestEv)} bb and '
          '${fmtSigned(worstEv)} bb.',
    if (n < 10)
      '$n decision${n == 1 ? '' : 's'} is a small sample — one flagged call '
          'moves this by ${(100 / n).round()} points.',
  ];

  return SessionDebrief(
    paragraph: paragraph,
    best: best,
    costliest: costliest,
    mathLines: math,
    expertLines: kDebriefExpertLines,
    hasFlagged: m > 0,
  );
}

/* ------------------------------------------------------------------ data */

/// One row of §4.13's "Review hands" list.
@immutable
class SummaryHandRow {
  const SummaryHandRow({
    required this.id,
    required this.startedAt,
    required this.netBb,
  });

  /// Session-local hand number ("Hand #41").
  final int id;

  /// The notes / replayer key.
  final int startedAt;
  final double netBb;
}

@immutable
class SessionSummaryData {
  const SessionSummaryData({
    required this.live,
    required this.busted,
    required this.startedAt,
    required this.endedAt,
    required this.seats,
    required this.bigBlind,
    required this.hands,
    required this.netBb,
    required this.bb100,
    required this.biggestWinBb,
    required this.biggestLossBb,
    required this.showdowns,
    required this.counters,
    required this.debrief,
    required this.rows,
    required this.history,
    this.missing = false,
  });

  /// The summary of the session that is still on the felt (`/table/summary`).
  final bool live;

  /// The hero busted: no ✕, no "Done", back is blocked (§2.5).
  final bool busted;

  final int startedAt;
  final int endedAt;
  final int seats;
  final int bigBlind;
  final int hands;
  final double netBb;
  final double bb100;
  final double biggestWinBb;
  final double biggestLossBb;

  /// Hands that reached the river (port §20's approximation).
  final int showdowns;

  final SessionCounters counters;
  final SessionDebrief debrief;

  /// Newest first, as §4.13 draws them.
  final List<SummaryHandRow> rows;

  /// The hands themselves, oldest first — what "Share" formats.
  final List<HHHand> history;

  /// The `sessions` row could not be read (reset, pruned, bad id).
  final bool missing;

  bool get hasHands => history.isNotEmpty;

  static SessionSummaryData empty({bool live = false, bool missing = false}) =>
      SessionSummaryData(
        live: live,
        busted: false,
        startedAt: 0,
        endedAt: 0,
        seats: 6,
        bigBlind: kBigBlind,
        hands: 0,
        netBb: 0,
        bb100: 0,
        biggestWinBb: 0,
        biggestLossBb: 0,
        showdowns: 0,
        counters: const SessionCounters(),
        debrief: buildDebrief(
          counters: const SessionCounters(),
          lifetimeCoached: 0,
          lifetimeFlagged: 0,
        ),
        rows: const [],
        history: const [],
        missing: missing,
      );
}

/// Shared assembly for both hosts (port §20's computations).
SessionSummaryData assembleSummary({
  required bool live,
  required bool busted,
  required int startedAt,
  required int endedAt,
  required int seats,
  required int bigBlind,
  required SessionCounters counters,
  required List<HHHand> history,
  required int lifetimeCoached,
  required int lifetimeFlagged,
  bool coachWasOff = true,
  int? handsFallback,
  double? netBbOverride,
  double? bb100Override,
}) {
  final bb = bigBlind <= 0 ? kBigBlind : bigBlind;
  final nets = [for (final h in history) h.heroNet / bb];
  final hands = history.isNotEmpty ? history.length : (handsFallback ?? 0);
  final netBb = netBbOverride ?? counters.netChips / bb;
  final bb100 = bb100Override ?? (hands > 0 ? netBb / hands * 100 : 0.0);

  return SessionSummaryData(
    live: live,
    busted: busted,
    startedAt: startedAt,
    endedAt: endedAt,
    seats: seats,
    bigBlind: bb,
    hands: hands,
    netBb: netBb,
    bb100: bb100,
    biggestWinBb:
        nets.isEmpty
            ? counters.biggestWinChips / bb
            : nets.reduce((a, b) => a > b ? a : b),
    biggestLossBb:
        nets.isEmpty
            ? counters.biggestLossChips / bb
            : nets.reduce((a, b) => a < b ? a : b),
    showdowns: history.where((h) => h.board.length == 5).length,
    counters: counters,
    debrief: buildDebrief(
      counters: counters,
      lifetimeCoached: lifetimeCoached,
      lifetimeFlagged: lifetimeFlagged,
      coachWasOff: coachWasOff,
    ),
    rows: [
      for (final h in history.reversed)
        SummaryHandRow(id: h.id, startedAt: h.startedAt, netBb: h.heroNet / bb),
    ],
    history: history,
  );
}

/* -------------------------------------------------------------- providers */

/// Lifetime coached / flagged decision totals (`stats.decisions`).
final lifetimeDecisionsProvider = FutureProvider<({int coached, int flagged})>((
  ref,
) async {
  final snapshot = await ref.watch(statsRepositoryProvider).loadStats();
  final decisions = snapshot.decisions;
  return (
    coached: decisions.length,
    flagged: decisions.where((d) => d.verdict == kMistakeVerdict).length,
  );
});

/// `DecisionRecord.verdict` for a flagged decision (port §7.6).
const String kMistakeVerdict = 'mistake';

/// P10's data. `null` id = the live session over the table; any other id is a
/// row in the `sessions` table (the read-only copies).
final sessionSummaryProvider =
    FutureProvider.family<SessionSummaryData, String?>((ref, id) async {
      final lifetime = await ref.watch(lifetimeDecisionsProvider.future);

      if (id == null) {
        final session = ref.watch(sessionProvider);
        if (!session.active && session.history.isEmpty) {
          return SessionSummaryData.empty(live: true);
        }
        return assembleSummary(
          live: true,
          busted: session.busted,
          startedAt: session.startedAt,
          endedAt: 0,
          seats: session.options.seats,
          bigBlind: session.bigBlind,
          counters: session.counters,
          history: session.history,
          lifetimeCoached: lifetime.coached,
          lifetimeFlagged: lifetime.flagged,
          handsFallback: session.counters.hands,
          netBbOverride: session.netBb,
          bb100Override: session.bb100,
          // Only claim "the coach was off" when it actually was: either the
          // setting is off, or it was switched off during this session.
          coachWasOff:
              !ref.read(settingsProvider).coachEnabled ||
              session.coachOffThisSession,
        );
      }

      final rowId = int.tryParse(id);
      if (rowId == null) return SessionSummaryData.empty(missing: true);
      final record = await ref
          .watch(sessionRepositoryProvider)
          .sessionById(rowId);
      if (record == null) return SessionSummaryData.empty(missing: true);
      return summaryFromRecord(
        record,
        lifetimeCoached: lifetime.coached,
        lifetimeFlagged: lifetime.flagged,
      );
    });

/// Decodes the `summary_json` the notifier wrote (`counters` + `hands`).
SessionSummaryData summaryFromRecord(
  SessionRecord record, {
  required int lifetimeCoached,
  required int lifetimeFlagged,
}) {
  final payload = record.summary ?? const <String, Object?>{};
  final counters = SessionCounters.fromJson(payload['counters']);
  final history = <HHHand>[];
  for (final raw in (payload['hands'] as List?) ?? const []) {
    if (raw is! Map) continue;
    try {
      history.add(HHHand.fromJson(raw.cast<String, Object?>()));
    } catch (_) {
      // A hand this build cannot decode is dropped; the numbers still show.
    }
  }
  final bb = history.isEmpty ? kBigBlind : history.first.bb.round();

  return assembleSummary(
    live: false,
    busted: false,
    startedAt: record.startedAt,
    endedAt: record.endedAt,
    seats: record.seats,
    bigBlind: bb,
    counters: counters,
    history: history,
    lifetimeCoached: lifetimeCoached,
    lifetimeFlagged: lifetimeFlagged,
    handsFallback: record.hands,
    netBbOverride: record.netBb,
    bb100Override: record.bb100,
  );
}
