/// Every user-facing string the Play feature shows, in one place.
///
/// `(desktop)` strings are verbatim from the desktop app (TONE.md forbids
/// paraphrasing them); `(new)` strings are DESIGN.md's mobile wording, quoted
/// exactly. This file is the feature's stand-in for `l10n/strings.dart`
/// (§16.7) until that table lands.
library;

abstract final class PlayCopy {
  /* ------------------------------------------------------------ P0 lobby */

  static const String lobbyTitle = 'Play';

  /// §4.1 *(new)*.
  static const String lobbySubtitle =
      'Six seats, four kinds of opponent, one coach.';

  static const String newTable = 'NEW TABLE';
  static const String recentSessions = 'RECENT SESSIONS';
  static const String sessionInProgress = 'Session in progress';
  static const String resume = 'Resume ›';
  static const String dealMeIn = 'Deal me in';

  /// §4.1, the desktop start-overlay paragraph, shown on the first visit.
  static const String startOverlayBody =
      'A session deals hand after hand against a fixed table of bots. Your '
      'stack carries over, so wins and losses stick until you end the session.';

  /// §4.1 empty state *(new)*.
  static const String firstTableCaption =
      'Your first table. The coach explains every decision in plain English.';

  /// §4.1, verbatim desktop note shown when seats ≠ 6.
  static const String chartsAssumeSixMax =
      'Coach charts assume 6-max — verdicts at other table sizes use the '
      'nearest position as an approximation.';

  static const String stacksCaption = 'Stacks  100 bb each · blinds 0.5 / 1';

  static const String tableRow = 'Table';
  static const String antesRow = 'Antes';
  static const String paceRow = 'Pace';
  static const String evCoachRow = 'EV Coach';
  static const String evCoachCaption = 'Grades every decision';

  static const List<String> seatLabels = ['Heads-up', '6-max', '9-max'];
  static const List<String> anteLabels = ['None', '0.25 bb'];
  static const List<String> paceLabels = ['Manual', 'Auto'];
  static const List<String> speedLabels = ['Slow', 'Normal', 'Fast'];

  /// §4.1's dialog *(new)*.
  static const String newTableOverPausedTitle = 'Start a new table?';
  static String newTableOverPausedBody(int hands) =>
      'Your paused session ($hands hand${hands == 1 ? '' : 's'}) will be '
      'summarised and closed.';
  static const String keepPausedOne = 'Keep paused one';
  static const String newTableAction = 'New table';

  /* ------------------------------------------------------------- P1 table */

  /// §4.2 — the ticker before anything has happened *(desktop)*.
  static const String tickerEmpty = 'Actions will appear here.';

  static const String handLogCopied = 'Hand log copied';

  /// §4.5 C, first three hands only *(new)*.
  static const String stepHint = 'Tap the table or Next action to step';

  /// §4.5 C/D while the hero is out of the hand *(new)*.
  static const String foldedPlayingOut = 'You folded — playing it out';
  static const String allInRunningOut = "You're all-in — running it out";

  static const String explainLastMove = 'Explain last move';
  static const String explainTheirLastMove = 'Explain their last move';

  /// §4.5's screen-reader label for `⏭` while the hero is out.
  static const String finishHand = 'Finish hand';
  static const String skipToMyTurn = 'Skip to my turn';

  /// §4.5 A, when the rail is hidden because nothing can be raised.
  static String callingInto(String call, String pot) =>
      'Calling $call into $pot';

  /// §4.5 A facing an all-in *(new)*.
  static String allInCall(String call, String win) =>
      'All-in call — $call to win $win';

  /// §4.5's degenerate rail *(new)*.
  static String onlyOneRaiseSize(String allIn) =>
      'Only one raise size — all-in $allIn bb';

  /// §4.5 A while dragging the rail *(new)*.
  static String opponentPrice(String times) =>
      'If they call they need to win about 1 in $times';

  /// §2.5 / §4.6 *(new)*.
  static const String pausedTapToContinue = 'Paused — tap to continue';

  /// §4.14 *(new)*.
  static const String sessionPaused =
      'Session paused — resume from Home or Play';

  /// §14 *(new)* — a snapshot write failed.
  static const String cantSave = "Can't save — free some space";

  /// §14 *(new)* — the coach gave up on this decision.
  static const String coachSkipped = 'Coach skipped this one.';

  /// §14 *(new)* — the coach failed twice.
  static const String coachOffForSession =
      'EV Coach turned off for this session — it kept failing. Your hands are '
      'unaffected.';

  /* ------------------------------------------------------------ P14 dialog */

  static const String leaveTableTitle = 'Leave table?';

  /// §4.14 *(new)*.
  static const String leaveTableBody =
      "Your session can't be saved right now. Leave anyway? This hand will be "
      'lost.';

  /* --------------------------------------------------------- State G / §4.15 */

  /// *(desktop)*.
  static const String readyToPlay = 'Ready to play?';

  /* ------------------------------------------------------------ O1 marks */

  /// §4.15 *(new)*.
  static const String markEye = 'Tap the eye to read their range';
  static const String markSwipe =
      'Swipe up here for the hand log and your session';

  /// §4.2.1 *(new)* — the first three heads-up hands.
  static const String headsUpHint =
      "You're the button — you act first pre-flop, last after it";

  /* --------------------------------------------------------------- P2 sheet */

  static const List<String> sessionSegments = ['Log', 'Session', 'Options'];
  static const String endSession = 'End session';

  /// §4.11 *(new)*.
  static const String earlierHands = 'Earlier hands — open the Session tab ›';

  /// §4.6, verbatim desktop helper copy (the "→ key" clause is dropped).
  static const String paceManualHelp =
      "Step through each player's action yourself.";
  static const String paceAutoHelp =
      'Bots act automatically at the chosen speed.';

  /// §4.6 *(new)* — Seats / Antes are not editable mid-session.
  static const String endsThisSessionFirst = 'Ends this session first';

  static const String autoDealRow = 'Auto-deal next hand';
  static const String realisticRevealsRow = 'Realistic reveals';
  static const String fourColorDeckRow = 'Four-colour deck';

  /* -------------------------------------------------------------- P6 sheet */

  static const String readTheirRange = 'Read their range';

  /// §4.3 *(desktop)* — the HUD tooltip body.
  static String hudExplained(int hands) =>
      'Observed over $hands hand${hands == 1 ? '' : 's'} this session — VPIP = '
      'how often they put money in pre-flop, PFR = how often they raise. Each '
      "player's exact numbers vary, so watch them settle.";

  /// §4.3 *(desktop)* — under 8 observed hands.
  static String readsAreEarned(int seen) =>
      'Stats appear after 8 observed hands ($seen so far) — reads are earned, '
      'not given.';

  /// §4.3 *(new)* — a disabled action's reason.
  static const String handOverReadsReopen =
      'Hand over — reads reopen on the next deal';

  /// §4.3 *(new)* — the other reason "Read their range" is off: the seat is
  /// out of the hand, so there is no range left to read.
  static const String readsUnavailable = 'Out of the hand — no range to read';

  /// §4.2.2 *(new)*.
  static const String nineMaxApproximate =
      '(approximate — 9-max uses 6-max labels)';

  /* ------------------------------------------------------------- P13 keypad */

  static const String betKeypadTitle = 'Bet size';
  static String keypadCaption(String min, String max) => 'min $min · max $max';

  /* ------------------------------------------------------------ P2 Session */

  static const String bb100Tooltip =
      'Big blinds won per 100 hands — the standard poker win-rate, independent '
      'of stake. +5 is strong; pros live roughly between −5 and +10. Small '
      'samples swing wildly.';

  static const String yourStyleTooltip =
      'How often YOU voluntarily put money in pre-flop, and how often you '
      'raise. Most winning 6-max players sit around 22–28 VPIP and 16–22 PFR. '
      'Much higher = too loose; a big gap between the numbers = too passive.';
}
