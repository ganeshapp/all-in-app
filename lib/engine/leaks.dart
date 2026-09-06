/// Pure leak-detection over recorded coach decisions — ported 1:1 from the
/// desktop `src/lib/leaks.ts`. The sentences are product copy (see
/// docs/TONE.md) and must stay verbatim.
library;

/// Valid [DecisionRecord.verdict] values.
const List<String> kDecisionVerdicts = [
  'mistake',
  'thin',
  'ok',
  'great',
  'info',
];

/// Valid [DecisionRecord.action] values.
const List<String> kDecisionActions = [
  'fold',
  'check',
  'call',
  'bet',
  'raise',
  'post',
];

/// One coached hero decision, appended by the coach after every verdict and
/// persisted to the `decisions` table.
class DecisionRecord {
  const DecisionRecord({
    required this.verdict,
    required this.action,
    required this.equity,
    required this.potOdds,
    required this.evBb,
    required this.street,
    required this.villainArchetype,
    this.position,
    required this.ts,
  });

  /// "mistake" | "thin" | "ok" | "great" | "info" (see [kDecisionVerdicts]).
  final String verdict;

  /// "fold" | "check" | "call" | "bet" | "raise" | "post" (see [kDecisionActions]).
  final String action;

  /// 0..1
  final double equity;

  /// 0..1
  final double potOdds;
  final double evBb;
  final String street;

  /// "TAG" | "LAG" | "Nit" | "Station" | null.
  final String? villainArchetype;

  /// Hero's seat position when the decision was made.
  final String? position;

  /// Epoch ms.
  final int ts;

  Map<String, Object?> toJson() => {
    'verdict': verdict,
    'action': action,
    'equity': equity,
    'potOdds': potOdds,
    'evBb': evBb,
    'street': street,
    'villainArchetype': villainArchetype,
    'position': position,
    'ts': ts,
  };

  static DecisionRecord fromJson(Map<String, Object?> j) => DecisionRecord(
    verdict: j['verdict'] as String,
    action: j['action'] as String,
    equity: (j['equity'] as num).toDouble(),
    potOdds: (j['potOdds'] as num).toDouble(),
    evBb: (j['evBb'] as num).toDouble(),
    street: j['street'] as String,
    villainArchetype: j['villainArchetype'] as String?,
    position: j['position'] as String?,
    ts: (j['ts'] as num).toInt(),
  );
}

/// Aggregate of the coached-decision log plus up to three plain-English leaks.
class LeakReport {
  const LeakReport({
    required this.total,
    required this.mistakes,
    required this.thin,
    required this.great,
    required this.foldMistakes,
    required this.callMistakes,
    required this.leaks,
  });

  /// Coached decisions excluding "info" verdicts.
  final int total;
  final int mistakes;
  final int thin;
  final int great;
  final int foldMistakes;
  final int callMistakes;
  final List<String> leaks;
}

/// Coaching sentences (verbatim desktop copy).
const String kLeakFoldTooOften =
    "You fold too often when you're getting the right price — look for more +EV calls.";
const String kLeakCallTooWide =
    'You call too wide for the pot odds — fold your weakest hands more.';
const String kLeakCleanDiscipline =
    'No clear −EV mistakes flagged — solid discipline. Keep refining the thin spots.';

/// Minimum number of coached (non-info) decisions before any leak is reported.
const int kLeakMinDecisions = 8;

/// A fold/call mistake leak needs at least this many such mistakes...
const int kLeakMinMistakes = 3;

/// ...and they must exceed this fraction of all coached decisions.
const double kLeakMistakeRate = 0.12;

LeakReport leaksFromDecisions(List<DecisionRecord> decisions) {
  final dec = decisions.where((d) => d.verdict != 'info').toList();
  final mistakes = dec.where((d) => d.verdict == 'mistake').toList();
  final thin = dec.where((d) => d.verdict == 'thin').length;
  final great = dec.where((d) => d.verdict == 'great').length;
  final foldMistakes = mistakes.where((d) => d.action == 'fold').length;
  final callMistakes = mistakes.where((d) => d.action == 'call').length;

  final leaks = <String>[];
  final n = dec.length;
  if (n >= kLeakMinDecisions) {
    if (foldMistakes >= kLeakMinMistakes &&
        foldMistakes / n > kLeakMistakeRate) {
      leaks.add(kLeakFoldTooOften);
    }
    if (callMistakes >= kLeakMinMistakes &&
        callMistakes / n > kLeakMistakeRate) {
      leaks.add(kLeakCallTooWide);
    }
    if (mistakes.isEmpty) {
      leaks.add(kLeakCleanDiscipline);
    }
  }

  return LeakReport(
    total: n,
    mistakes: mistakes.length,
    thin: thin,
    great: great,
    foldMistakes: foldMistakes,
    callMistakes: callMistakes,
    leaks: leaks,
  );
}
