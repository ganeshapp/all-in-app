/// The deterministic five-minute plan (DESIGN.md §3.2).
///
/// [PlanNotifier] is a *composition*: it watches the review queues, the daily
/// goal, the course, the live session and the drill scoreboard and turns them
/// into at most four cards in a fixed priority order. It owns no rules of its
/// own — every number it prints is read from the feature that maintains it, so
/// Home can never disagree with Drills, Study or Play.
///
/// Priority (§3.2): 1 review due · 2 resume session · 3 continue lesson ·
/// 4 quick set · 5 play 20 hands. Cards 2 and 5 are mutually exclusive, which
/// is what keeps the list at four.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../app/routes.dart';
import '../../../engine/engine.dart' show DrillAction, isDue;
import '../../../services/persistence/drill_store.dart';
import '../../../services/persistence/settings_store.dart' show PaceMode;
import '../../drills/providers/drill_provider.dart';
import '../../drills/providers/drill_stores.dart';
import '../../drills/providers/review_provider.dart';
import '../../play/providers/play_providers.dart';
import '../../play/providers/session_provider.dart';
import '../../study/content/curriculum.dart';
import '../../study/content/lesson_model.dart';
import '../../study/providers/study_providers.dart';
import '../home_copy.dart';
import 'home_providers.dart';

/// The practice modes a quick set can be built from (§3.2 card 4). Review is
/// not one of them: it is card 1.
enum QuickSetMode {
  mixed('mixed', 'mixed'),
  pushFold('pushfold', 'push/fold'),
  exploit('exploit', 'exploit');

  const QuickSetMode(this.id, this.word);

  /// The `/drills?mode=` id, which is also the answers ring's `mode`.
  final String id;

  /// The word inside "A set of 10 {word} spots".
  final String word;
}

/// Which of §3.2's five cards an entry is.
enum PlanCardKind { review, resume, lesson, quickSet, play }

/// One plan card, already resolved to the strings it renders.
@immutable
class PlanEntry {
  const PlanEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.estimate,
    this.buttonLabel,
    this.route,
  });

  final PlanCardKind kind;
  final String title;
  final String subtitle;

  /// "~2 min", or null for the lesson card (its read time is in the subtitle).
  final String? estimate;

  /// Only the primary card carries an explicit button (§3.1).
  final String? buttonLabel;

  /// Where a tap goes. Null for [PlanCardKind.play], which deals a new session
  /// before navigating to the table.
  final String? route;
}

/// Everything the plan list needs, in one immutable read.
@immutable
class PlanState {
  const PlanState({
    required this.cards,
    required this.goalMet,
    required this.firstRun,
  });

  static const PlanState empty = PlanState(
    cards: <PlanEntry>[],
    goalMet: false,
    firstRun: true,
  );

  /// At most four, the first styled primary (§3.2).
  final List<PlanEntry> cards;

  /// §3.2's "Goal met — anything else is a bonus" line above the list.
  final bool goalMet;

  /// Nothing played, no lesson read, no drill answered (§3.6) — the header
  /// replaces the streak line with the first-run sentence.
  final bool firstRun;

  PlanEntry? entry(PlanCardKind kind) {
    for (final card in cards) {
      if (card.kind == kind) return card;
    }
    return null;
  }
}

/// How many spots a quick set holds (§3.2 card 4).
const int kQuickSetSize = 10;

/// The window §3.2 measures a mode's accuracy over.
const int kModeWindow = 20;

/// A mode needs this many answers before it can be called the weakest.
const int kModeMinAnswers = 5;

/// §3.2 card 1: 20 s per due spot, rounded up to the minute.
int reviewMinutes(int due) {
  if (due <= 0) return 1;
  final minutes = (due * 20 + 59) ~/ 60;
  return minutes < 1 ? 1 : minutes;
}

/// §3.2 card 2 and 5: 20 hands at ~18 s each.
const int kSessionMinutes = 6;

/// §3.2 card 4.
const int kQuickSetMinutes = 4;

/// The mode with the weakest accuracy over its last [kModeWindow] answers,
/// among those with at least [kModeMinAnswers]; Mixed otherwise (§3.2).
QuickSetMode weakestMode(List<DrillAnswer> answers) {
  QuickSetMode? worst;
  var worstRate = 2.0;
  for (final mode in QuickSetMode.values) {
    final own = [
      for (final a in answers)
        if (a.mode == mode.id) a,
    ];
    if (own.length < kModeMinAnswers) continue;
    final window =
        own.length <= kModeWindow ? own : own.sublist(own.length - kModeWindow);
    final hits = window.where((a) => a.correct).length;
    final rate = hits / window.length;
    if (rate < worstRate) {
      worstRate = rate;
      worst = mode;
    }
  }
  return worst ?? QuickSetMode.mixed;
}

class PlanNotifier extends Notifier<PlanState> {
  @override
  PlanState build() {
    final now = ref.watch(homeClockProvider).nowMs;

    // 1 · Review due — leaks + missed drills (§5.5).
    final counts = ref.watch(reviewCountsProvider);
    final leaks = ref.watch(leakQueueProvider);
    final flaggedCalls =
        leaks
            .where((s) => isDue(s.srs, now) && s.best == DrillAction.fold)
            .length;

    // 2 / 5 · The live session, or the saved table options.
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final options = ref.watch(tableOptionsStoreProvider).load();

    // 3 · The course.
    final lesson = ref.watch(studyContinueLessonProvider);
    final done = ref.watch(studyCompletedCountProvider);

    // 4 · The drill scoreboard and the answers ring.
    final board = ref.watch(drillScoreboardProvider);
    final accuracy = ref.watch(drillAccuracyProvider);
    final answers = ref.watch(drillStoreProvider).loadAnswers();

    final goals = ref.watch(homeGoalProvider);

    final hasSession = session.active && session.counters.hands > 0;
    final cards = <PlanEntry>[];

    if (counts.due > 0) {
      cards.add(
        PlanEntry(
          kind: PlanCardKind.review,
          title: HomeCopy.reviewTitle,
          subtitle: HomeCopy.reviewSubtitle(counts.due, flaggedCalls),
          estimate: HomeCopy.estimateMinutes(reviewMinutes(counts.due)),
          buttonLabel: HomeCopy.reviewButton,
          route: AllInRoutes.drillsWith(mode: 'leaks'),
        ),
      );
    }

    if (hasSession) {
      cards.add(
        PlanEntry(
          kind: PlanCardKind.resume,
          title: HomeCopy.resumeTitle,
          subtitle: HomeCopy.resumeSubtitle(
            hands: session.counters.hands,
            netBb: session.netBb,
            coachOn: settings.coachEnabled && !session.coachOffThisSession,
          ),
          estimate: HomeCopy.estimateMinutes(kSessionMinutes),
          route: AllInRoutes.tablePath,
        ),
      );
    }

    // The same clause `studyContinueLessonProvider` applies on the first day:
    // nothing completed yet and the placement test named this lesson.
    final fromPlacement =
        done == 0 &&
        lesson != null &&
        placementLessonForRating(board.rating) == lesson.id;
    cards.add(_lessonCard(lesson, done, fromPlacement: fromPlacement));

    final mode = weakestMode(answers);
    cards.add(
      PlanEntry(
        kind: PlanCardKind.quickSet,
        title: HomeCopy.quickSetTitle(mode.word),
        subtitle: HomeCopy.quickSetSubtitle(
          rating: board.rating,
          accuracy: accuracy,
        ),
        estimate: HomeCopy.estimateMinutes(kQuickSetMinutes),
        route: AllInRoutes.drillsWith(mode: mode.id, set: kQuickSetSize),
      ),
    );

    if (!hasSession) {
      cards.add(
        PlanEntry(
          kind: PlanCardKind.play,
          title: HomeCopy.playTitle(options.seats),
          subtitle: HomeCopy.playSubtitle(
            coachOn: settings.coachEnabled,
            manual: settings.paceMode == PaceMode.manual,
          ),
          estimate: HomeCopy.estimateMinutes(kSessionMinutes),
        ),
      );
    }

    return PlanState(
      cards: cards,
      goalMet: goals.met,
      firstRun: !hasSession && done == 0 && board.solved == 0,
    );
  }

  /// §3.2 card 3, including §14's "all 31 complete" wording.
  ///
  /// *Which* lesson is not decided here: `studyContinueLessonProvider` owns
  /// that rule — placement suggestion on the first day, first incomplete in
  /// path order after — and Study's Continue card reads the same provider, so
  /// the two screens cannot name different lessons.
  PlanEntry _lessonCard(Lesson? next, int done, {bool fromPlacement = false}) {
    final total = kAllLessonIds.length;
    if (next == null) {
      return PlanEntry(
        kind: PlanCardKind.lesson,
        title: HomeCopy.lessonCompleteTitle,
        subtitle: HomeCopy.lessonCompleteSubtitle(total),
        route: AllInRoutes.studyPath,
      );
    }

    final id = next.id;
    final lesson = next;
    final level = kLevels.indexWhere((l) => l.lessons.any((x) => x.id == id));

    return PlanEntry(
      kind: PlanCardKind.lesson,
      title: HomeCopy.lessonTitle(lesson.title),
      subtitle: HomeCopy.lessonSubtitle(
        level: level < 0 ? 1 : level + 1,
        minutes: lesson.minutes,
        done: done,
        total: total,
        fromPlacement: fromPlacement,
      ),
      route: AllInRoutes.lessonPath(id),
    );
  }
}

final planProvider = NotifierProvider<PlanNotifier, PlanState>(
  PlanNotifier.new,
);
