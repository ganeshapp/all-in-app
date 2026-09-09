/// Every user-facing string the Drills feature owns (DESIGN.md §5, docs/port/
/// drill-ux-srs-leaks.md §15, drills-charts-icm.md §5).
///
/// Copy is **verbatim from the desktop** unless a doc comment marks it
/// *(new)* (a mobile-only line DESIGN.md specifies) — TONE.md's rule. It lives
/// in one place so a wording change is one edit; it moves to
/// `lib/l10n/strings.dart` when that table lands (§16.5, §16.7).
library;

import 'package:allin/data/icm_scenarios.g.dart';
import 'package:allin/engine/engine.dart';

/// The four drill modes, in picker order (desktop `MODE_INFO`).
enum DrillMode {
  mixed('mixed', 'Mixed'),
  pushfold('pushfold', 'Push / Fold'),
  exploit('exploit', 'Exploits'),
  leaks('leaks', 'Review');

  const DrillMode(this.id, this.label);

  /// The persisted / deep-link id (`/drills?mode=leaks`, §2.6).
  final String id;

  /// The verbatim chip label.
  final String label;

  /// The verbatim blurb behind D4.
  String get blurb => switch (this) {
    DrillMode.mixed =>
      'Pre-flop charts + post-flop pot-odds/equity. Opponent type is '
          'irrelevant — play solid baseline poker.',
    DrillMode.pushfold =>
      'Short-stack shove/fold and call-a-shove spots, graded by computed Nash '
          'equilibrium tables (chip-EV, no antes).',
    DrillMode.exploit =>
      'Best deviation vs a KNOWN opponent type — the spots where the right '
          'play differs from balanced, with both numbers shown.',
    DrillMode.leaks =>
      'Your coach-flagged leaks and missed drills on a spaced schedule — beat '
          'a spot 3 times over days to retire it.',
  };

  /// The practice modes (everything but Review) update rating and streaks.
  bool get isPractice => this != DrillMode.leaks;

  /// The id used in the answers ring (`allin.drill_answers.v1`).
  String get ringId => this == DrillMode.leaks ? 'review' : id;

  static DrillMode fromId(String? id) => DrillMode.values.firstWhere(
    (m) => m.id == id,
    orElse: () => DrillMode.mixed,
  );
}

abstract final class DrillCopy {
  // ------------------------------------------------------------- header
  static const String title = 'Drills';

  /// D3 · the Rating tooltip (verbatim).
  static const String ratingTooltip =
      'A self-adjusting puzzle rating (like a chess puzzle ELO). Right answers '
      'raise it, wrong ones lower it, weighted by difficulty.';

  /// D3 · the daily-goal tooltip (verbatim; also H2, §3.3).
  static const String todayTooltip =
      'A quiet daily goal: 20 drill answers (or 30 hands) keeps the day-streak '
      'alive. No reminders, no guilt — just a nudge to come back tomorrow.';

  /// D3 · accuracy *(new)*.
  static const String accuracyTooltip =
      'Every answer you have given in the practice modes, as a percentage. '
      'Review answers are not counted — they are practice you already owe '
      'yourself, not a test.';

  /// D3 · streak / best *(new)*.
  static const String streakTooltip =
      'Consecutive right answers in the practice modes. One wrong answer '
      'resets it; your best run is kept forever.';

  /// D3 · Rating, layer 2 *(new)*.
  static const String ratingMath =
      'Each spot carries a rating of its own — 1000 for a clear one, 1200 for '
      'a standard one, 1400 for a close one. Beat a spot rated above you and '
      'you gain more than you would lose by missing an easy one; the gap '
      'decides the size, and no single answer moves it by more than 24.';

  /// D3 · Rating, layer 3 *(new)*.
  static const String ratingExpert =
      'Elo with K = 24 and a floor of 100. Expected score is '
      '1 / (1 + 10^((spot − you) / 400)), the change is '
      'round(24 × (score − expected)), and the spot rating is '
      '800 + 200 × difficulty. Review answers are excluded — a spot you have '
      'already missed is not a fair test.';

  /// D3 · Accuracy, layer 2 *(new)*.
  static const String accuracyMath =
      'Right answers ÷ answers given, in the practice modes only, rounded to '
      'a whole percent. It reads 0 % until you have answered once.';

  /// D3 · Today, layer 2 *(new)*.
  static const String todayMath =
      'The ring fills at 20 drill answers. Thirty played hands fill it just as '
      'well — whichever you reach first keeps the day.';

  /// D3 · the rating sparkline's heading *(new)*.
  static const String ratingTrend = 'Last 30 days';

  /// D3 · too few answers to draw a trend *(new)*.
  static const String ratingNoTrend =
      'Answer a few more spots and your rating trend appears here.';

  static String ratingTrendSemantics(int from, int to) =>
      'Rating over the last 30 days, from $from to $to.';

  static const String ratingTitle = 'Rating';
  static const String accuracyTitle = 'Accuracy';
  static const String streakTitle = 'Streak';
  static const String todayTitle = 'Today';
  static const String dayStreakTitle = 'Day streak';

  // -------------------------------------------------------- source pills
  static const String sourceLeak = 'Your flagged spot';
  static const String sourceExploit = 'Exploit · vs a known type';
  static const String sourceIcm = 'Push/Fold · ICM bubble';
  static const String sourceNash = 'Push/Fold · computed Nash';
  static const String sourceChart = 'Pre-flop chart · 100bb baseline';
  static const String sourceHeuristic = 'Post-flop heuristic · fundamentals';

  /// The pill for a spot (desktop `DrillControls`).
  static String sourceLabel(Puzzle p) {
    if (p.kind == PuzzleKind.leak) return sourceLeak;
    if (p.kind == PuzzleKind.exploit) return sourceExploit;
    if (p.kind == PuzzleKind.pushfold) {
      return p.icm == true ? sourceIcm : sourceNash;
    }
    return p.source == PuzzleSource.chart ? sourceChart : sourceHeuristic;
  }

  /// The matching paragraph from About's "How the grading works" (verbatim),
  /// shown when the source pill is tapped (§5.1).
  static String sourceExplainer(Puzzle p) {
    if (p.kind == PuzzleKind.leak) return gradingLeak;
    if (p.kind == PuzzleKind.pushfold) return gradingPushFold;
    return p.source == PuzzleSource.chart ? gradingCharts : gradingPostflop;
  }

  static const String gradingTitle = 'How the grading works';

  static const String gradingCharts =
      'Pre-flop charts (drills and study diagrams) are self-authored consensus '
      'baselines for 100bb 6-max — solid standard play keyed by your position '
      "and the raiser's, with mixed frequencies where real strategies mix. "
      "They're not direct solver output; bot ranges still use a simplified "
      'model that\'s being upgraded next.';

  static const String gradingPostflop =
      "Post-flop coaching compares your pot odds with your hand's chance of "
      'winning, estimated by dealing thousands of random runouts against the '
      "opponent's likely hands (a Monte-Carlo simulation). That catches clear "
      "mistakes well, but it can't see everything a solver sees — treat close "
      'verdicts as guidance, not gospel.';

  static const String gradingPushFold =
      'Push/fold drills use Nash equilibrium tables we computed ourselves '
      '(chip-EV, no antes, one caller at a time) — mixed-frequency hands '
      'accept either answer, like the real equilibrium does. A third of '
      'push/fold reps are ICM bubble spots — solved the same way, but in '
      'tournament money instead of chips. Ante variants are still to come.';

  /// *(new)* — leak spots are graded against the coach's own verdict.
  static const String gradingLeak =
      'This spot came from your own play: the coach flagged the decision at '
      'the table (or the hand-history importer did), and the answer is the '
      'line it says makes money. Beat it three times on the spaced schedule '
      'and it retires.';

  // -------------------------------------------------------- the spot line
  static const String yourHand = 'Your hand';

  /// *(new)* — the swipe hint, first five spots only (§5.2).
  static const String swipeHint = '◂ swipe to replay the action';

  // ------------------------------------------------------------ feedback
  static const String correct = 'Correct';
  static const String notOptimal = 'Not optimal';

  /// The EV-loss line (verbatim; only when wrong and `evLoss > 0.05`).
  static String evLossLine(double evLossBb) =>
      'That choice costs about ${jsToFixed(evLossBb, 1)} bb every time — '
      '${severity(evLossBb)}.';

  static String severity(double evLossBb) =>
      evLossBb < 0.5
          ? 'a small leak'
          : evLossBb < 1.5
          ? 'a real leak'
          : 'a blunder-sized leak';

  static const String folding = 'Folding: 0 bb — costs nothing more.';

  static String calling(double equity, double pot, double toCall, double odds) {
    final ev = equity * (pot + toCall) - toCall;
    return 'Calling: ${fmtSigned(ev)} bb per try — your hand wins '
        '${fmtTimes(equity)} and you need ${fmtNeed(odds)}.';
  }

  static String equityLine(double equity) => 'Equity: ${fmtPct(equity)}';
  static String potOddsLine(double odds) => 'Pot odds: ${fmtPct(odds)}';

  /// *(new)* — layer 2's arithmetic, spelled out (§5.3).
  static String mathSteps(double equity, double pot, double toCall) {
    final finalPot = pot + toCall;
    final ev = equity * finalPot - toCall;
    return 'Pot ${jsNum(pot)} + call ${jsNum(toCall)} = '
        '${jsNum(finalPot)} · ${fmtPct(equity)} × ${jsNum(finalPot)} − '
        '${jsNum(toCall)} ≈ ${fmtSigned(ev)} bb';
  }

  /// Layer 3's first body line — the desktop's own row label (§5.3, §15.2).
  static const String rangeItWasGradedAgainst =
      'The range it was graded against:';

  /// *(new)* — layer 3 for a leak puzzle, which has no grading range (§5.3).
  static const String noRangeForLeak =
      'No range for this spot — it was graded against your own flagged '
      'decision.';

  static const String readTheLesson = 'Read the lesson';
  static const String drillFiveSimilar = 'Drill 5 similar';
  static const String nextPuzzle = 'Next puzzle';

  /// Bounded set (§5.1): the Next button's label after the last answer.
  static const String keepGoing = 'Keep going';

  static String moreOfThisType(int left) =>
      '$left more of this spot type coming up';

  static String setCounter(int done, int size) => '$done of $size';

  /// *(new)* — the one-line strip after a bounded set's last answer (§5.1).
  static String setDone(int correct, int size, int ratingDelta) =>
      'Set done — $correct of $size · rating ${fmtSigned(ratingDelta, 0)}';

  /// Mixed-frequency push/fold hands accept either answer (§5.6, verbatim).
  static const String mixedFrequency =
      'Either answer is fine here — this hand is a mix in the equilibrium.';

  // -------------------------------------------------- review / SRS lines
  /// *(new)* — the schedule line in the review feedback header (§5.5).
  static const String backInTenMinutes = 'Back in 10 minutes';
  static const String retired = 'Retired — beaten 3 times';

  static String nextInDays(int days, int wins) =>
      'Next in $days day${days == 1 ? '' : 's'} · $wins of $kRetireReps';

  /// The schedule line for a graded review card.
  static String scheduleLine(SrsState srs, bool correct) {
    if (!correct) return backInTenMinutes;
    if (isGraduated(srs)) return retired;
    return nextInDays(srs.intervalDays.round(), srs.wins);
  }

  // ----------------------------------------------------- review empty (§5.5)
  static const String nothingDue = 'Nothing due right now';
  static const String noSpotsYet = 'No spots to review yet';

  static String allScheduled(int totalCards) =>
      'All $totalCards of your review spots are scheduled for later — spaced '
      'practice sticks best when you come back to it. Play or drill in the '
      'meantime.';

  static const String noSpotsBody =
      'Play a session with the EV Coach on, or miss a practice drill, and the '
      "spot lands here on a spaced-repetition schedule until you've beaten it "
      'three times.';

  static const String playASession = 'Play a session';
  static const String drillMixed = 'Drill Mixed';

  /// *(new)* — "Next due: tomorrow 09:14" (§5.5). Local time.
  static String nextDue(DateTime due, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    final clock =
        '${due.hour.toString().padLeft(2, '0')}:'
        '${due.minute.toString().padLeft(2, '0')}';
    final when =
        diff <= 0
            ? 'today'
            : diff == 1
            ? 'tomorrow'
            : 'in $diff days';
    return 'Next due: $when $clock';
  }

  // ------------------------------------------------------------ frame list
  static const String handReplay = 'Hand replay';
  static const String decisionPoint = 'Decision point';

  // ------------------------------------------------------- §14 edge states
  /// *(new)* — the spot is being dealt on the generator isolate.
  static const String dealing = 'Dealing a spot…';

  /// *(new)* — generation failed (a killed isolate, no memory).
  static const String dealFailed =
      "That spot couldn't be dealt. Nothing was lost — try another.";
  static const String tryAgain = 'Try again';

  // ------------------------------------------------- exploits (§5.7 layer 2)
  /// *(new)* — the balanced number the desktop prints inside the rationale.
  static String balancedLine(int pct) => 'Vs a balanced range: ~$pct %';

  /// *(new)* — the exploitative number.
  static String exploitLine(int pct) => 'Vs this opponent type: ~$pct %';

  /// The two percentages a `generateExploit` rationale carries. The desktop
  /// only prints them inside the paragraph, so §5.7's "two mono lines" have
  /// to read them back out of its verbatim templates
  /// (`"({n}% vs a sane calling range)"`, `"has ~{n}% equity — enough for"`).
  /// Returns null for template 2, which has no balanced equity to show.
  static int? balancedPctOf(String rationale) {
    for (final re in [
      RegExp(r'\((\d+)% vs a sane calling range\)'),
      RegExp(r'has ~(\d+)% equity'),
    ]) {
      final m = re.firstMatch(rationale);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    return null;
  }

  // ------------------------------------------------- push/fold (§5.6 strip)
  /// The stacks strip under a Nash push/fold spot. The stack size is read
  /// back from the engine's verbatim first frame ("12 bb stacks. Blinds
  /// 0.5/1.").
  static String stacksStrip(String stack) =>
      'Stacks $stack bb · Blinds 0.5/1 · Nash chip-EV, no antes';

  static final RegExp _stacksFrame = RegExp(r'^([0-9.]+) bb stacks');

  /// The stacks line for [puzzle], or null when it is not a push/fold spot.
  static String? stacksLineFor(Puzzle puzzle) {
    if (puzzle.kind != PuzzleKind.pushfold || puzzle.frames.isEmpty) {
      return null;
    }
    final first = puzzle.frames.first.text;
    if (puzzle.icm == true) return first;
    final m = _stacksFrame.firstMatch(first);
    return m == null ? first : stacksStrip(m.group(1)!);
  }

  /// The ICM scenario name, read back from the verbatim frame text
  /// ("{name} — stacks: …") and confirmed against the shipped scenarios.
  static String? icmScenarioName(Puzzle puzzle) {
    if (puzzle.icm != true || puzzle.frames.isEmpty) return null;
    final text = puzzle.frames.first.text;
    for (final scenario in kIcmScenarios) {
      if (text.startsWith(scenario.name)) return scenario.name;
    }
    final cut = text.indexOf(' — ');
    return cut > 0 ? text.substring(0, cut) : null;
  }
}
