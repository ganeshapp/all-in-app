/// Every user-facing string P3 · P4 · P5 · P7 show (DESIGN.md §4.8–§4.10).
///
/// `(desktop)` strings are verbatim from the desktop app
/// (`docs/port/play-loop-and-coach.md` §9, §10, §12); `(new)` strings are
/// DESIGN.md's mobile wording, quoted exactly. Nothing here is paraphrased —
/// the engine's own note text (`plain`, `text`, `steps`, `expert`) is never
/// touched at all, it is rendered as it arrives.
library;

import '../../../engine/engine.dart';

abstract final class CoachSheetCopy {
  /* ----------------------------------------------------------- P4 · list */

  /// §4.8's list title.
  static String notesTitle(int handNumber) => 'Coach notes · Hand #$handNumber';

  /// The row at the top of P3 that reaches P4 when the hand has more than one
  /// note *(new)*.
  static String allNotes(int count) => 'All notes this hand ($count)';

  /// §14 — the badge is never empty in practice, but a deep-linked sheet is.
  static const String noNotesYet =
      'No coach notes on this hand yet. Play an action and the coach grades '
      'it.';

  /* ---------------------------------------------------------- P5 · range */

  /// §4.8 — "Ivey's assumed range".
  static String assumedRangeTitle(String name) => "$name's assumed range";

  /// *(desktop)* `RangeViewModal`'s description.
  static const String assumedRangeBody =
      'This is the range the coach used for its equity estimate, based on '
      'archetype, position and action so far.';

  /// The back chevron's accessible name.
  static const String backToNote = 'Back to the note';

  /* ---------------------------------------------------------- P7 · read */

  /// *(desktop)* `GuessModal` title.
  static String readTitle(String name) => "Read $name's range";

  /// The route's own title when there is no seat to name (§14).
  static const String readTitleGeneric = 'Read their range';

  /// The second subtitle line.
  ///
  /// The desktop's "Optionally paint your guess, or just peek to study their
  /// range." sat over a 13×13 grid of codes (AKs / AKo / T8o) and explained
  /// none of it: "range" is undefined at layer 1, "paint" never says
  /// tap-or-drag, and the s/o suffix appears nowhere else on the screen (the
  /// legend only colours Pairs / Suited / Offsuit). A first-week player could
  /// not start — and the reveal then graded them "Way off" (TONE.md).
  static const String readSubtitle =
      "Their \u2018range\u2019 is every hand they would play here. Drag "
      'across the squares to mark the ones you think they hold — "s" means '
      'both cards the same suit, "o" means different suits. The chips below '
      'are shortcuts — the strongest 10 % of all hands, 15 %, and so on. Or '
      'just tap Peek to see their range.';

  /// "BTN · Tight-Aggressive (TAG) · Flop" *(desktop)*.
  static String readContext({
    required String position,
    required String archetype,
    required String street,
  }) => '$position · $archetype · $street';

  static const String peek = 'Peek';
  static const String peekAndScore = 'Peek & score';
  static const String undo = 'Undo';
  static const String clear = 'Clear';
  static const String continueLabel = 'Continue';
  static const String close = 'Close';

  /// *(desktop)* the painter's footer hint.
  static const String guessingIsOptional =
      'Guessing is optional — peek any time.';

  /// §4.9 — Clear is one stroke, so Undo brings it back *(new)*.
  static const String clearedUndo = 'Cleared';

  static String revealTitle(String name) => "$name's range revealed";

  static String theirRange(int combos) => 'Their range: $combos combos';

  /// *(desktop)* the caption under the score card.
  static const String exactCardsAtHandOver =
      "Everyone's exact cards are revealed when the hand ends.";

  /// *(desktop)* nothing was painted, so nothing is scored (§14).
  static String nothingPainted(String name) =>
      "Here's $name's assumed range. Paint a guess first next time for an "
      'accuracy score.';

  /// §14 — P7 opened with no hand to read (a deep link, or the hand ended
  /// under the modal) *(new)*.
  static const String nothingToRead =
      'No range to read here — reads open while a hand is in play.';

  /* ------------------------------------------------- P7 · the score card */

  /// Layer 1, plain-English recall *(new)*.
  static String caught(double recall) =>
      'You caught ${fmtTimes(recall)} of the hands they play here.';

  /// Layer 1, plain-English precision *(new)*.
  ///
  /// `fmtTimes` returns a *frequency* ("almost every time", "about 7 times in
  /// 10"), so the sentence has to put it in the predicate — as a subject it
  /// reads "Almost every time of what you painted was right."
  static String painted(double precision) =>
      'Of the hands you painted, you were right ${fmtTimes(precision)}.';

  /// Layer 2 — the desktop's own numbers, mono (§4.9).
  static List<String> scoreMath({
    required double accuracy,
    required double recall,
    required double precision,
    required int overlapCombos,
    required int actualCombos,
    required int paintedCombos,
  }) => <String>[
    'Score: ${fmtPct(accuracy)}',
    'Coverage (recall): ${fmtPct(recall)} — $overlapCombos of the '
        '$actualCombos combos they actually play',
    'Precision: ${fmtPct(precision)} — $overlapCombos of the $paintedCombos '
        'combos you painted',
    // §4.9 prints "Score = (recall + precision) / 2"; the engine (and the
    // desktop it is ported from) scores the *harmonic* mean, which is what is
    // stated here — a formula that does not reproduce the number above it
    // would fail TONE.md's honesty rule.
    'Score = 2 × recall × precision ÷ (recall + precision)',
  ];

  /// Layer 3 line 1 *(new)*.
  static String combosNotHands({
    required int paintedCombos,
    required int actualCombos,
    required int overlapCombos,
  }) =>
      'Painted $paintedCombos combos; their range holds $actualCombos; '
      '$overlapCombos overlap. These are combos, not hands — AKs is 4 combos, '
      'AKo is 12, a pair is 6, so painting one pair cell is worth less than '
      'one offsuit cell.';

  /// Layer 3 line 2 *(new)*.
  static const String howTheRangeWasBuilt =
      "Their range was built from this archetype's opening and continuing "
      'frequencies for this position and the action so far, then filtered by '
      'the board. It is the same range the EV Coach used for its equity '
      'estimate on this street — grading you against one model and advising '
      'you from another would be dishonest.';

  /// Layer 3 line 3 *(new)*.
  static const String modelNotTheirCards =
      'This is the coach\'s model of what they would play here, not the two '
      'cards they were dealt. Their actual hand shows at hand-over. A '
      "'Way off' score against a hand they should not have had is the model "
      'being right and the deck being the deck.';

  /// The read badge P8 puts on the seat row at hand-over (§4.12).
  static String yourRead(double accuracy) => 'Your read ${fmtPct(accuracy)}';
}
