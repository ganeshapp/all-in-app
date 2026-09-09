/// The coach's one sentence on Home, and the three layers behind it
/// (DESIGN.md §3.4).
///
/// Priority: a leak line from `leaksFromDecisions` · the read-accuracy line ·
/// yesterday's debrief line · the no-data line. The sentences are verbatim —
/// the three leak lines come from the engine itself (`engine/leaks.dart`), so
/// Home, Stats and the desktop can never word them differently.
///
/// The layers follow TONE.md: layer 1 is the sentence, "Show me the math" is
/// the count behind it and "Expert detail" is the rule that produced it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine.dart'
    show kLeakCallTooWide, kLeakFoldTooOften, kLeakMinDecisions;
import '../../../services/persistence/session_repository.dart';
import '../../drills/providers/review_provider.dart';
import '../../play/providers/lobby_providers.dart';
import '../../stats/providers/stats_metrics.dart';
import '../../stats/providers/stats_providers.dart';
import '../home_copy.dart';

/// Which of §3.4's four sources produced the sentence.
enum CoachNoteSource { foldLeak, callLeak, discipline, reads, debrief, none }

/// The lesson each source links to (§3.4).
const String kLeakLessonId = 'pot-odds';
const String kReadsLessonId = 'drill-range';

@immutable
class HomeCoachNote {
  const HomeCoachNote({
    required this.source,
    required this.sentence,
    this.math,
    this.expert,
    this.lessonId,
    this.dueSpots = 0,
  });

  final CoachNoteSource source;

  /// Layer 1 — the verbatim sentence on the card and in H1.
  final String sentence;

  /// Layer 2 ("Show me the math"). Null opens to the written placeholder.
  final String? math;

  /// Layer 3 ("Expert detail").
  final String? expert;

  /// The lesson H1's secondary button opens, or null when there is none.
  final String? lessonId;

  /// Spots due right now — H1 shows "Review these spots ›" when > 0.
  final int dueSpots;
}

/// Live: it re-reads whenever the stats snapshot, the ended sessions or the
/// review queues change.
final homeCoachNoteProvider = Provider<HomeCoachNote>((ref) {
  final due = ref.watch(reviewCountsProvider).due;
  final stats = ref.watch(statsProvider);
  final sessions = ref.watch(recentSessionsProvider);
  final metrics = stats.valueOrNull;

  if (metrics != null) {
    // 1 · a leak line, in the engine's own order.
    final leaks = metrics.leak.leaks;
    if (leaks.isNotEmpty) {
      return _leakNote(leaks.first, metrics, due);
    }

    // 2 · the read-accuracy line.
    if (metrics.guesses.length >= kReadLeakMinGuesses &&
        metrics.avgAcc < kReadLeakThreshold) {
      return HomeCoachNote(
        source: CoachNoteSource.reads,
        sentence: HomeCopy.coachReadLine,
        math: HomeCopy.coachMathReads(
          reads: metrics.guesses.length,
          mean: metrics.avgAcc,
        ),
        expert: HomeCopy.coachExpertReads,
        lessonId: kReadsLessonId,
        dueSpots: due,
      );
    }
  }

  // 3 · the last debrief's costliest decision.
  final debrief = _debrief(sessions.valueOrNull, due);
  if (debrief != null) return debrief;

  // 4 · nothing recorded yet.
  return HomeCoachNote(
    source: CoachNoteSource.none,
    sentence: HomeCopy.coachNoData,
    dueSpots: due,
  );
});

HomeCoachNote _leakNote(String sentence, StatsMetrics metrics, int due) {
  final leak = metrics.leak;
  if (sentence == kLeakFoldTooOften || sentence == kLeakCallTooWide) {
    final folds = sentence == kLeakFoldTooOften;
    return HomeCoachNote(
      source: folds ? CoachNoteSource.foldLeak : CoachNoteSource.callLeak,
      sentence: sentence,
      math: HomeCopy.coachMathMistakes(
        mistakes: folds ? leak.foldMistakes : leak.callMistakes,
        total: leak.total,
        folds: folds,
      ),
      expert: HomeCopy.coachExpertMistakes(folds: folds),
      lessonId: kLeakLessonId,
      dueSpots: due,
    );
  }
  return HomeCoachNote(
    source: CoachNoteSource.discipline,
    sentence: sentence,
    math: HomeCopy.coachMathClean(great: leak.great, total: leak.total),
    expert: HomeCopy.coachExpertClean,
    lessonId: kLeakLessonId,
    dueSpots: due,
  );
}

/// "Costliest: a {street} {action} ({evBb} bb) — it's in your Review queue."
/// from the most recent ended session's debrief counters (§3.4, §4.13).
HomeCoachNote? _debrief(List<SessionRecord>? sessions, int due) {
  if (sessions == null || sessions.isEmpty) return null;
  final summary = sessions.first.summary;
  final counters = summary == null ? null : summary['counters'];
  if (counters is! Map) return null;
  final label = counters['worstEvLabel'];
  final ev = (counters['worstEvBb'] as num?)?.toDouble();
  if (label is! String || label.isEmpty || ev == null || ev >= 0) return null;
  return HomeCoachNote(
    source: CoachNoteSource.debrief,
    sentence: HomeCopy.coachDebriefLine(label, ev),
    math: HomeCopy.coachMathDebrief(ev),
    expert: HomeCopy.coachExpertDebrief,
    dueSpots: due,
  );
}

/// The minimum number of coached decisions any leak line needs — re-exported
/// so a test can state the rule without importing the engine.
const int kCoachMinDecisions = kLeakMinDecisions;
