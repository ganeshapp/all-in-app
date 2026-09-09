/// Every user-facing string the Home tab renders, in one place.
///
/// Copy marked *(desktop)* is ported verbatim (the leak sentences come from the
/// engine itself, `engine/leaks.dart`, so they can never drift); copy marked
/// *(mobile)* is DESIGN.md §3's own wording, quoted exactly. Nothing here is
/// paraphrased and nothing is assembled from fragments at a call site —
/// TONE.md governs these sentences, so they live together and move together.
///
/// This file is the Home slice of the `l10n/strings.dart` table §16.3 asks
/// for; when that table lands these constants move into it unchanged.
library;

import '../../engine/engine.dart' show fmtChips, fmtPct, fmtSigned;

abstract final class HomeCopy {
  /* ------------------------------------------------------------- header */

  /// §3.5 — "Good morning" (05–12), "Good afternoon" (12–18), else evening.
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String weekday(DateTime now) => weekdays[now.weekday - 1];

  /// §3.3: "{weekday} · {n} days in a row"; the streak fragment is omitted at
  /// zero and the line never counts down.
  static String streakLine(DateTime now, int streak) =>
      streak <= 0
          ? weekday(now)
          : '${weekday(now)} · $streak ${streak == 1 ? 'day' : 'days'} in a row';

  /// §3.5 — the first run after onboarding replaces the streak line *(new)*.
  static const String firstRunSubtitle =
      'Start with a session — the coach explains as you go.';

  static const String settingsAction = 'Settings';

  /* ---------------------------------------------------------- goal card */

  static const String goalLabel = 'Today';

  /// §3.3: "{drills} of 20" / "{hands} of 30".
  static String goalCount(int done, int target) => '$done of $target';

  /// §3.3 captions *(new)*.
  static const String goalCaptionDrills =
      'drills · or 30 hands — either counts';
  static const String goalCaptionHands = 'hands · or 20 drills — either counts';

  /// §3.2's line above the list when the goal is met *(new)*.
  static const String goalMet = 'Goal met — anything else is a bonus';

  /// H2 (§3.3) — the verbatim desktop Today tooltip.
  static const String goalSheetTitle = 'Today';
  static const String goalSheetBody =
      'A quiet daily goal: 20 drill answers (or 30 hands) keeps the day-streak '
      'alive. No reminders, no guilt — just a nudge to come back tomorrow.';
  static const String goalSheetMath =
      'The ring fills at 20 drill answers. Thirty played hands fill it just as '
      'well — whichever you reach first keeps the day.';
  static const String goalSheetExpert =
      'The day-streak counts back from today, and skips today until it is met '
      "— so a morning visit never shows a broken streak. It doesn't count "
      'down and is never coloured.';

  /* -------------------------------------------------------- plan cards */

  static const String eyebrowNextUp = 'NEXT UP';
  static const String eyebrowLastSession = 'LAST SESSION';
  static const String eyebrowPractice = 'PRACTICE';

  // 1 · Review due (§3.2).
  static const String reviewTitle = 'Clear your review';
  static const String reviewButton = 'Start review';

  static String reviewSubtitle(int due, int flaggedCalls) {
    final base = '$due ${due == 1 ? 'spot' : 'spots'} due';
    if (flaggedCalls <= 0) return base;
    return '$base · $flaggedCalls ${flaggedCalls == 1 ? 'is' : 'are'} '
        'coach-flagged ${flaggedCalls == 1 ? 'call' : 'calls'}';
  }

  // 2 · Resume session (§3.2).
  static const String resumeTitle = 'Resume your table';

  static String resumeSubtitle({
    required int hands,
    required double netBb,
    required bool coachOn,
  }) =>
      '$hands ${hands == 1 ? 'hand' : 'hands'}, ${fmtSigned(netBb)} bb · '
      'Coach ${coachOn ? 'on' : 'off'}';

  // 3 · Continue lesson (§3.2).
  static String lessonTitle(String title) => 'Continue: $title';

  static String lessonSubtitle({
    required int level,
    required int minutes,
    required int done,
    required int total,
  }) => 'Level $level · $minutes min read · $done/$total done';

  /// §14 "Study · all 31 complete".
  static const String lessonCompleteTitle =
      'Course complete — revisit any lesson';

  static String lessonCompleteSubtitle(int total) => '$total/$total done';

  // 4 · Quick set (§3.2).
  static String quickSetTitle(String mode) => 'A set of 10 $mode spots';

  static String quickSetSubtitle({
    required double rating,
    required int accuracy,
  }) => 'Rating ${fmtChips(rating)} · $accuracy % accuracy';

  // 5 · Play 20 hands (§3.2).
  static String playTitle(int seats) =>
      'Play 20 hands · ${seats == 2 ? 'Heads-up' : '$seats-max'}';

  static String playSubtitle({required bool coachOn, required bool manual}) =>
      'Coach ${coachOn ? 'on' : 'off'} · ${manual ? 'Manual' : 'Auto'} pace';

  /// §3.2's estimates.
  static String estimateMinutes(int minutes) => '~$minutes min';

  /* --------------------------------------------------------- coach card */

  static const String coachLabel = 'Coach';
  static const String coachAction = 'Show me why ›';

  /// §3.4 source 2 — the read-accuracy line.
  ///
  /// The desktop wording sent the user after two names that appear on no
  /// screen in this app: nothing is labelled "Guess & Peek" (the flow is the
  /// eye on a seat, titled "Read {name}'s range") and the Study lesson is
  /// called "Range-Building Drill", not a "Range-Building exercise".
  static const String coachReadLine =
      'Your reads on what opponents might hold are often off — tap the eye on '
      'a seat during a hand to practise, or open the Range-Building Drill in '
      'Study.';

  /// §3.4 source 3 — yesterday's debrief line *(desktop shape)*.
  static String coachDebriefLine(String label, double evBb) =>
      'Costliest: a $label (${fmtSigned(evBb)} bb) — '
      "it's in your Review queue.";

  /// §3.4 source 4 — nothing recorded yet *(new)*.
  ///
  /// This is the first coach sentence a new user ever reads, and Home never
  /// explains "EV" anywhere, so the name is glossed in the same breath it
  /// first appears (TONE.md). The Review and Stats empty states say the same.
  static const String coachNoData =
      'Play a session with the coach on — it grades every decision by how '
      "much money it makes or loses (that's the EV Coach) — and I'll start "
      'noticing patterns.';

  /* ------------------------------------------------------------- H1 */

  static const String coachSheetTitle = "Coach's note";
  static const String reviewTheseSpots = 'Review these spots ›';

  /// §3.4's layer 2 for a fold / call leak *(new)*.
  static String coachMathMistakes({
    required int mistakes,
    required int total,
    required bool folds,
  }) =>
      '$mistakes of your last $total coached decisions were '
      '${folds ? 'folds' : 'calls'} the coach flagged — '
      '${fmtPct(total == 0 ? 0 : mistakes / total)}.';

  /// §3.4's layer 3 for a fold / call leak *(new)*.
  static String coachExpertMistakes({required bool folds}) =>
      'Flagged when ≥ 3 ${folds ? 'fold' : 'call'} mistakes and > 12 % of '
      'coached decisions.';

  /// Layer 2 / 3 for the "no clear −EV mistakes" line *(new)*.
  static String coachMathClean({required int great, required int total}) =>
      'Nothing was flagged in your last $total coached decisions, and $great '
      'of them were called great.';
  static const String coachExpertClean =
      'The line appears once at least 8 coached decisions carry no mistakes at '
      'all. It is a report, not a target — thin spots still cost money.';

  /// Layer 2 / 3 for the read-accuracy line *(new)*.
  static String coachMathReads({required int reads, required double mean}) =>
      'Your last $reads range reads matched the real range '
      '${fmtPct(mean)} of the time on average.';
  static const String coachExpertReads =
      'Flagged when you have logged at least 5 reads and they average under '
      '50 % of the range right.';

  /// Layer 2 / 3 for the debrief line *(new)*.
  static String coachMathDebrief(double evBb) =>
      'That decision cost about ${fmtSigned(evBb)} bb against the line the '
      'coach would have taken.';
  static const String coachExpertDebrief =
      'Every flagged decision is queued on a spaced schedule: beat the spot '
      'three times over days and it retires.';

  /* ------------------------------------------------------ last session */

  /// §3.5 — "{fmtSigned(net)} bb · {hands} hands · {m} mistakes".
  static String lastSessionLine({
    required double netBb,
    required int hands,
    required int mistakes,
  }) =>
      '${fmtSigned(netBb)} bb · $hands ${hands == 1 ? 'hand' : 'hands'} · '
      '$mistakes ${mistakes == 1 ? 'mistake' : 'mistakes'}';

  /// §3.5 — the costliest decision under the line.
  static String lastSessionCostliest(String label, double evBb) =>
      'Costliest: a $label (${fmtSigned(evBb)} bb)';

  /* ---------------------------------------------------------- practice */

  /// §3.5 caption.
  static String activeDays(int n) => '$n active ${n == 1 ? 'day' : 'days'}';

  /// The right-hand label on the §3.1 practice row.
  static const String practiceWeeks = '5 wk';

  static const String practiceSemantics =
      'Practice heatmap, the last five weeks. Opens Progress.';
}
