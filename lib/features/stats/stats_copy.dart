/// Every user-facing string the Stats tab renders, in one place.
///
/// Copy marked *(desktop)* is ported verbatim from
/// `docs/port/persistence-stats-settings.md` §7, §11.5 and §13.1; copy marked
/// *(mobile)* is DESIGN.md §7's own wording. Nothing here is paraphrased and
/// nothing is assembled from fragments at a call site — TONE.md governs these
/// sentences, so they live together and move together.
///
/// This file is the Stats slice of the `l10n/strings.dart` table DESIGN §16.3
/// asks for; when that table lands these constants move into it unchanged.
library;

import '../../engine/engine.dart'
    show fmtNeed, fmtPct, fmtSigned, fmtTimes, jsToFixed, kArchetypes;

abstract final class StatsCopy {
  /* ------------------------------------------------------------ T0 header */

  /// §7.1 page title *(desktop h1)*.
  static const String title = 'Your progress';

  /// §7.1 subtitle *(desktop)*.
  static const String subtitle = 'Decisions, not results — but we track both.';

  /* --------------------------------------------------------------- KPIs */

  static const String kpiHands = 'Hands';
  static const String kpiNet = 'Net';
  static const String kpiWinRate = 'Win rate';
  static const String kpiShowdown = 'Showdown';
  static const String kpiReadAccuracy = 'Read acc.';

  /// §7.2 sub-lines *(desktop)*.
  static const String kpiWinRateSub = 'bb/100 (lifetime)';
  static const String kpiShowdownSub = 'won';

  /// "{n} reads" *(desktop)*.
  static String kpiReadsSub(int n) => '$n reads';

  /* --------------------------------------------- T1 explainers (§7.2) */

  /// The Win-rate tooltip title *(desktop)*.
  static const String winRateTitle = 'bb / 100';

  /// The Win-rate body, unchanged from the desktop tooltip *(desktop)*.
  static const String winRateBody =
      'Big blinds won per 100 hands — the standard, stake-independent '
      'win-rate. Roughly: +5 is a strong winner; expect wild swings under a '
      'few thousand hands.';

  static const String handsBody =
      'Every hand you finished, counted once at hand-over.';
  static const String handsMath =
      'A count — every hand you finished. Imported hands are not counted.';
  static const String handsExpert =
      'Hands are recorded at hand-over, so leaving a session mid-hand loses '
      'only that hand.';

  static const String netBody =
      'Your lifetime result in big blinds — everything you have won minus '
      'everything you have lost.';
  static const String netExpert =
      'Play money — and results say less than decisions. Coaching review is '
      'the number that moves first.';

  /// "The sum of every hand's result in big blinds: {won} won − {lost} lost =
  /// {net}." *(mobile)*. The minus is U+2212.
  static String netMath({
    required double won,
    required double lost,
    required double net,
  }) =>
      "The sum of every hand's result in big blinds: ${jsToFixed(won, 1)} won "
      '− ${jsToFixed(lost, 1)} lost = ${fmtSigned(net)}.';

  static const String winRateExpert =
      'Under a few thousand hands this is mostly variance; your '
      'coached-mistake rate is the honest signal.';

  /// "{net} bb over {hands} hands × 100 = {bb100} bb/100." *(mobile)*.
  static String winRateMath({
    required double net,
    required int hands,
    required double bb100,
  }) =>
      '${fmtSigned(net)} bb over $hands hands × 100 = ${fmtSigned(bb100)} '
      'bb/100.';

  static const String showdownBody =
      'How often you won the hands that went all the way to a showdown.';
  static const String showdownExpert =
      'Only hands that reached showdown count here; hands everyone folded to '
      'you are in Net.';

  /// "{won} of the {reached} hands that reached showdown were won." *(mobile)*.
  static String showdownMath({required int won, required int reached}) =>
      '$won of the $reached hands that reached showdown were won.';

  static const String readAccuracyBody =
      'How close your painted ranges have been to the range the coach '
      'assumed, averaged over every Peek you have scored.';

  /// §4.9's prose says "(recall + precision) / 2", but the engine scores the
  /// *harmonic* mean (`coach.dart`: `2·p·r / (p + r)`), so the arithmetic mean
  /// cannot reproduce the number printed above it — TONE.md's honesty rule
  /// makes the code the authority. The spec cross-reference is dropped too: a
  /// section number means nothing to a user. Mirrors the Peek card
  /// (`play/widgets/coach_copy.dart`).
  static const String readAccuracyExpert =
      'Each score balances two things — how much of their range you covered, '
      'and how much of what you painted was really in it. '
      'Score = 2 × coverage × precision ÷ (coverage + precision).';

  /// "The mean of your last {n} Peek scores: {list}." *(mobile)*.
  static String readAccuracyMath({required int n, required String list}) =>
      'The mean of your last $n Peek scores: $list.';

  /* --------------------------------------------------------- chart cards */

  static const String cumulativeCard = 'Cumulative winnings (bb)';

  /// §7.3 / desktop `LineChart` empty state *(desktop)*.
  static const String chartEmpty = 'Play a few hands to see your trend.';

  static const String readAccuracyCard = 'Range-read accuracy';

  /// Desktop `MiniBars` empty state *(desktop)*.
  static const String readsEmpty = 'No reads logged yet.';

  /// "Last {n} Peek scores." *(desktop)*.
  static String readsCaption(int n) => 'Last $n Peek scores.';

  /// The floating scrub label — "Hand 212 · +31.5 bb" *(mobile §7.3)*.
  static String chartScrubLabel(int hand, double value) =>
      'Hand $hand · ${fmtSigned(value)} bb';

  /// "Read 14 · 71% · flop, 3 days ago" *(mobile §7.3)*.
  static String readScrubLabel({
    required int index,
    required double score,
    required String detail,
  }) => 'Read $index · ${fmtPct(score)} · $detail';

  /* ------------------------------------------------------ coaching review */

  static const String coachingReviewCard = 'Coaching review';

  /// Desktop empty state, with "EV Coach" glossed the first time it appears
  /// on this screen (TONE.md).
  static const String coachingReviewEmpty =
      'Play with the coach on — it grades every decision by how much money it '
      "makes or loses (that's the EV Coach) — and your reviewed decisions, "
      'leaks and mistakes will appear here.';

  static const String verdictMistakes = 'Mistakes';
  static const String verdictThinSpots = 'Thin spots';
  static const String verdictGreatPlays = 'Great plays';

  /// The desktop heading is "Recent −EV decisions"; "−EV" is never glossed on
  /// this screen, so the phone says what it means and leaves the term to the
  /// ⓘ explainer (TONE.md).
  static const String recentNegativeEv = 'Decisions that cost you money';

  /// The ⓘ on that heading: where the banned shorthand is actually taught.
  static const String recentNegativeEvBody =
      'The decisions in your coached log that lost the most money on average. '
      'Each row shows the price the pot was offering, how often your hand '
      'actually won, and what the choice cost.';
  static const String recentNegativeEvExpert =
      'Ranked by expected value (EV) — the average big blinds a decision wins '
      'or loses if you made it many times. Coaches write a losing one as −EV.';

  static const String reviewTheseSpots = 'Review these spots ›';

  /// The read-accuracy leak line appended to `leaksFromDecisions`.
  ///
  /// The desktop wording named two things that do not exist on the phone:
  /// nothing is labelled "Guess & Peek" (the flow is the eye on a seat, titled
  /// "Read {name}'s range") and there is no "Range-Building exercise" — the
  /// Study lesson is called "Range-Building Drill". A beginner sent looking
  /// for two names that appear on no screen is simply stuck, so the line uses
  /// the labels the app actually shows and the card routes to the lesson.
  static const String readAccuracyLeak =
      'Your reads on what opponents might hold are often off — tap the eye on '
      'a seat during a hand to practise, or open the Range-Building Drill in '
      'Study.';

  /// H1's "Show me the math" for a fold-mistake leak *(mobile §3.4)*.
  static String leakMath({
    required String kind,
    required int count,
    required int total,
  }) =>
      '$count of your last $total coached decisions were $kind the coach '
      'flagged — ${fmtPct(total == 0 ? 0 : count / total)}.';

  /// H1's "Expert detail" for the two leak lines *(mobile §3.4)*.
  static const String leakExpert =
      'Flagged when ≥ 3 fold mistakes and > 12 % of coached decisions.';

  static const String cleanDisciplineMath =
      'No decision in your coached log carries the "mistake" verdict.';
  static const String cleanDisciplineExpert =
      'Said once you have at least 8 coached decisions and none of them was '
      'flagged as a mistake.';

  static const String readLeakMath =
      'Your mean Peek score is under 50 % over at least five reads.';
  static const String readLeakExpert =
      'Recall and precision are averaged against the range the coach assumed '
      'for that villain, so a wide-but-right guess still scores.';

  static const String openTheLesson = 'Open the lesson ›';

  /// "River call vs a Calling Station" — CSS-capitalised street + action.
  ///
  /// The desktop suffixes the raw `Archetype.label` ("TAG", "LAG", "Nit",
  /// "Station"). Those codes are glossed nowhere on this screen and "TAG" is
  /// exactly the kind of abbreviation TONE.md bans, so the row prints the
  /// archetype's readable `name` instead ("Tight-Aggressive").
  static String decisionRow({
    required String street,
    required String action,
    String? archetype,
  }) {
    final head = '${_capitalise(street)} $action';
    if (archetype == null) return head;
    return '$head vs ${archetypeName(archetype)}';
  }

  /// `Archetype.label` → the readable name from `kArchetypes`.
  static String archetypeName(String label) {
    for (final entry in kArchetypes.entries) {
      if (entry.key.label == label) return entry.value.name;
    }
    return label;
  }

  /// The desktop writes "17% eq · 25% needed · −2.0 bb". "eq" is never
  /// glossed on this screen and TONE.md wants counts, not percentages, at
  /// layer 1 — so the row reads "needed 1 time in 4 · won about 1 time in 6".
  /// The bb amount is returned separately so the row can colour it on the
  /// money scale rather than painting a *gain* in the loss colour (§13).
  static String decisionNumbers({
    required double equity,
    required double potOdds,
  }) => 'needed ${fmtNeed(potOdds)} · won ${fmtTimes(equity)}';

  /// The signed money at the end of a decision row: "−2.0 bb".
  static String decisionAmount(double evBb) => '${fmtSigned(evBb)} bb';

  /* -------------------------------------------------------- style / table */

  static const String archetypesCard = 'Hands vs each style';

  static const String positionsCard = 'Winnings by position';

  /// Desktop empty state *(desktop)*.
  static const String positionsEmpty =
      'Position is tracked from every new hand you play.';

  /// Desktop footnote *(desktop)*.
  static const String positionsFootnote =
      'Everyone wins most from the button (acting last) and loses from the '
      'blinds (forced money, acting first). Worry only if your '
      'early-position numbers are deep red — that usually means playing too '
      'many weak hands up front.';

  static const String styleCard = 'Style numbers';

  /// Desktop footnote *(desktop)*.
  static const String styleFootnote =
      'Small samples swing wildly — treat these as a mirror after a few '
      'hundred hands, not a verdict after ten.';

  static const String wtsdLabel = 'Went to showdown (WTSD)';
  static const String wtsdBand = '24–32%';
  static const String wtsdBlurb =
      'Of the hands where you saw a flop, how often you reached showdown. '
      'Too high = calling down too much; too low = giving up too easily.';

  static const String wsdLabel = r'Won at showdown (W$SD)';
  static const String wsdBand = '49–56%';
  static const String wsdBlurb =
      'When you did reach showdown, how often you won. Very high can '
      "ironically mean you only call when it's obvious — you might be "
      'folding too many winners.';

  static const String afLabel = 'Aggression factor (AF)';
  static const String afBand = '2.0–4.0';
  static const String afBlurb =
      'Your bets + raises divided by your calls, over coached decisions. '
      'Below ~1.5 means you call far more than you pressure — the most '
      'common beginner leak.';

  /// The footer line of a style-number explainer *(desktop)*.
  static String healthyRange(String band) => 'Healthy range: $band';

  static String wtsdMath({required int showdowns, required int flops}) =>
      '$showdowns of the $flops hands where you saw a flop reached showdown.';

  static String wsdMath({required int won, required int showdowns}) =>
      '$won of the $showdowns hands that reached showdown were won.';

  static String afMath({required int aggressive, required int calls}) =>
      '$aggressive bets and raises ÷ $calls calls, over your coached '
      'decisions.';

  /* --------------------------------------------------------- recent hands */

  static const String recentHandsCard = 'Recent hands';
  static const String allHandsRow = 'All hands ›';
  static const String allHandsTitle = 'All hands';

  /// Desktop empty state *(desktop)*.
  static const String handsEmpty =
      'Finished hands appear here and stay replayable after a restart.';

  /// Desktop tag-filtered empty state *(desktop)*.
  static const String handsEmptyForTag =
      'No hands carry that tag among the recent ones.';

  static const String importButton = 'Import hands (.txt)';
  static const String importShort = 'Import';
  static const String importedBadge = 'imported';
  static const String tagAll = 'all';
  static const String loadMore = 'Load more';

  static const String filterAll = 'All';
  static const String filterPlayed = 'Played';
  static const String filterImported = 'Imported';

  static const String swipeNote = 'Note';
  static const String swipeExport = 'Export';

  /* ---------------------------------------------------- P12 note editor */

  /// "Note on hand #41" *(mobile §7.6)*.
  static String noteTitle(int handId) => 'Note on hand #$handId';

  /// The textarea placeholder *(desktop)*.
  static const String notePlaceholder =
      "What happened, and what's the lesson? (e.g. 'called the river with a "
      "bluff-catcher vs a Nit — their range had no bluffs')";

  static const String noteTags = 'Tags';
  static const String noteCustomTag = '+ custom, Enter';
  static const String noteRemove = 'Remove note';
  static const String noteCancel = 'Cancel';
  static const String noteSave = 'Save';
  static const String noteSaved = 'Note saved';
  static const String noteRemoved = 'Note removed';

  /* -------------------------------------------------------- P11 replayer */

  /// "Hand #41 replay" *(desktop)*.
  static String replayTitle(int handId) => 'Hand #$handId replay';

  /// §14: the hand is gone *(mobile)*.
  static const String replayMissing =
      'Hand not found — it may have been cleared by Reset all progress, or '
      'it was never saved.';

  /// §7.7's refusal state for a table bigger than the felt draws *(mobile)*.
  static String replayTooManySeats(int seats) =>
      'This table had $seats seats — All-In draws up to 10. The action is '
      'written out below; the felt is only a picture.';

  static const String replayShareText = "Share this hand's text";

  /// P11's hand-to-hand step *(mobile addition)*. Reviewing a session means
  /// reading its hands in order; without these the only way to the next one is
  /// back out to the list and find your place again.
  static const String replayNewerHand = 'Newer hand';
  static const String replayOlderHand = 'Older hand';
  static const String replayFrames = 'Frames';
  static const String shareHand = 'Share this hand';
  static const String shareFailed = "Couldn't open the share sheet";
  static const String shared = 'Shared';

  /* --------------------------------------------------------- T3 import */

  static const String importTitle = 'Import hands';
  static const String importReading = 'Reading hands…';

  /// "Reviewing your calls… 12 of 40" *(mobile §7.8)*.
  static String importReviewing(int done, int total) =>
      'Reviewing your calls… $done of $total';

  static const String importContinue = 'Continue in the background';
  static const String importCancel = 'Cancel';
  static const String importDone = 'Done';
  static const String importSeeHands = 'See hands';
  static const String importReviewNow = 'Review now';

  /// §7.8 step 4 *(mobile)*.
  static const String importNoHands =
      "Couldn't find any hands in that file. All-In reads PokerStars-style "
      'text histories — export a session to see the format.';

  /// The toast when the progress sheet was dismissed to the background and
  /// the import then finished (§7.8 step 2) *(mobile)*.
  static String importFinishedToast(int hands) =>
      'Imported $hands hand${hands == 1 ? '' : 's'}';

  static const String importExportSample = 'Export a sample';
  static const String importOk = 'OK';
  static const String importCancelled = 'Import cancelled';

  /// §14 "file picked but unreadable or not valid UTF-8" *(mobile)*.
  static const String fileUnreadableTitle = "That file couldn't be read";
  static const String fileUnreadable =
      "That file couldn't be read. If it came from a cloud drive, download "
      'it to this phone first and try again.';

  /// §14's "huge file" row, phrased for a picker that refuses before reading
  /// *(mobile addition — the desktop has no size limit)*.
  static const String fileTooLargeTitle = 'That file is too large';
  static const String fileTooLarge =
      'All-In reads hand histories up to 16 MB — about ten thousand hands. '
      'Split the file and import it in parts.';

  /* ----------------------------------------------------------- T0 · data */

  static const String dataCard = 'Data';
  static const String backupRow = 'Back up all data (.json)';

  /// §7.9 caption under the backup row *(mobile)*.
  static const String backupCaption =
      'A safety copy of your stats, decisions, reads and hands. Restore it '
      'from this screen on a new phone.';

  /// What the share sheet came back with, shown in faint under the backup
  /// button (§7.10 step 1 shows `saveText`'s message; on a phone the sheet is
  /// the save) *(mobile)*.
  static const String backupShared = 'Backup ready to save';
  static const String backupDismissed = '';
  static const String backupFailed =
      "Couldn't create the backup — free some space and try again.";

  static const String restoreRow = 'Restore from backup…';
  static const String resetRow = 'Reset all progress';

  /// §7.10 *(desktop)*.
  static const String resetTitle = 'Reset all progress?';
  static const String resetBody =
      'This permanently deletes your lifetime stats, decisions, reads, and '
      'saved hands.';
  static const String resetBackupFirst = 'Download a backup first';
  static const String resetFieldLabel = 'Type RESET to confirm:';
  static const String resetConfirmWord = 'RESET';
  static const String resetConfirm = 'Erase everything';
  static const String resetCancel = 'Cancel';
  static const String resetDone = 'Progress erased';

  /// §7.9 X3 *(mobile)*.
  static const String restoreTitle = 'Restore this backup?';

  /// "Your current stats, decisions, reads and hands will be replaced by the
  /// backup from {date} ({hands} hands)." *(mobile)*.
  static String restoreBody({required String date, required int hands}) =>
      'Your current stats, decisions, reads and hands will be replaced by '
      'the backup from $date ($hands hands).';

  static const String restoreConfirm = 'Restore';
  static const String restoreDone = 'Backup restored';

  /// §14 "wrong file / corrupt" *(mobile)*.
  static const String restoreNotABackup = "That file isn't an All-In backup.";

  /// §14 "newer schema" *(mobile)*.
  static String restoreNewerSchema({required int backup, required int app}) =>
      'This backup was made by a newer version of All-In (backup v$backup; '
      'this app reads v$app). Update the app, then restore.';

  /// §14 "Storage · quota / DB error" *(mobile)*.
  static const String storageProblem = "Some data couldn't be saved";

  /* -------------------------------------------------------- P practice */

  static const String practiceCard = 'Practice';

  /// Desktop caption when nothing is logged *(desktop)*.
  static const String practiceEmpty =
      'Each day you practice lights a square; hitting the daily goal '
      '(20 drills or 30 hands) makes it gold.';

  /// "{n} active day{s} in the last 16 weeks. Gold = daily goal met.
  /// Consistency beats bingeing." *(desktop)*.
  static String practiceCaption(int activeDays) =>
      '$activeDays active day${activeDays == 1 ? '' : 's'} in the last 16 '
      'weeks. Gold = daily goal met. Consistency beats bingeing.';

  /// "2026-09-03: 24 reps · goal met" *(desktop)*.
  static String practiceCell({
    required String key,
    required int count,
    required bool met,
  }) => '$key: $count reps${met ? ' · goal met' : ''}';

  /// The §13 summary node for the grid *(mobile)*.
  static String practiceSemantics(int activeDays) =>
      'Practice heatmap, $activeDays active days in the last 16 weeks';

  /* --------------------------------------------------------------- misc */

  static const String settingsAction = 'Settings';
  static const String noteAction = 'Edit note';
  static const String addNoteAction = 'Add a note / tag';

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
