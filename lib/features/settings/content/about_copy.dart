/// X1 · About — every string on the page, verbatim from the desktop
/// (docs/port/design-brand-onboarding.md §13.2,
/// docs/port/persistence-stats-settings.md §15) with exactly the edits
/// DESIGN.md §9 permits:
///
/// * "click the eye" → "tap the eye" and "Hover any dotted term" → "Tap any
///   dotted term" (the only two permitted edits to the four "How to use it"
///   bodies),
/// * "(SQLite on desktop, browser storage on the web)" → "(everything is
///   stored on this phone)",
/// * the tech-stack sentence is restated for Flutter,
/// * the roadmap drops the desktop auto-update and PWA rows for
///   "Hand-history import from more sites" and "Share a hand as an image",
/// * the "Play online" / "Download desktop" tiles are cut (§15.5) and a
///   "Rate All-In" row replaces the GitHub release check.
///
/// These lines encode the product's honesty commitments — that post-flop
/// coaching is a heuristic and not a solver, that this is a play-money
/// trainer. Do not paraphrase them.
library;

import 'package:flutter/foundation.dart';

/// One "How to use it" / "Good to know" entry.
@immutable
class AboutEntry {
  const AboutEntry({required this.title, required this.body});

  final String title;
  final String body;
}

/// A bullet whose lead phrase is bold ("How the grading works").
@immutable
class AboutBullet {
  const AboutBullet({
    required this.lead,
    required this.body,
    this.good = false,
  });

  /// Bold lead-in, in `text`.
  final String lead;

  /// The rest of the sentence, muted.
  final String body;

  /// Renders with the `good` check glyph instead of the `info` glyph.
  final bool good;
}

abstract final class AboutCopy {
  static const String appName = 'All-In · Poker Dojo';

  static const String description =
      'A clean, offline-first Texas Hold\'em trainer that takes you from the '
      'rules to solid, EV-aware play — by actually doing the math with you, '
      'not just showing answers.';

  // ------------------------------------------------------------------ links
  static const String siteUrl = 'https://gapp.in/poker';
  static const String authorUrl = 'https://www.gapp.in';
  static const String authorLabel = 'www.gapp.in';

  /// The Android listing. `com.gapp.allin` is this app's application id.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.gapp.allin';

  /// iOS has no numeric id until the first submission; the product page on
  /// the author's site links onward to the listing, so the row still works.
  static const String appStoreUrl = siteUrl;

  static const String rateTitle = 'Rate All-In';
  static const String rateSubtitle =
      'A rating helps other players find the app.';

  static const String linkFailed = "Couldn't open that link.";

  // ----------------------------------------------------------- how to use it
  static const String howToUseHeading = 'How to use it';

  static const List<AboutEntry> modes = [
    AboutEntry(
      title: 'Play',
      body:
          'Start a session and play hand-after-hand against four bot '
          'archetypes. Step through the action manually or auto-play, tap the '
          'eye on a player to guess/peek their range, and let the EV Coach '
          'grade your decisions with the math behind them.',
    ),
    AboutEntry(
      title: 'Drills',
      body:
          'Chess-puzzle-style practice. Replay a spot to the decision point, '
          'then choose fold/call/raise for instant feedback and a '
          'self-adjusting rating. Four modes: Mixed cash spots (pre-flop '
          'charts + post-flop pot-odds/equity), short-stack Push/Fold, '
          'Exploits vs known player types, and Review — your own '
          'coach-flagged mistakes, re-served until you fix them.',
    ),
    AboutEntry(
      title: 'Study',
      body:
          'A 5-level course from rules and position to hand-reading, '
          'bet-sizing, implied odds, SPR and multiway play — with interactive '
          'range, pot-odds, bluff and multiway-equity calculators, a '
          'quick-reference cheat sheet, and optional quizzes. Tap any dotted '
          'term for a definition.',
    ),
    AboutEntry(
      title: 'Stats',
      body:
          'Track your win-rate (bb/100), range-read accuracy and results vs '
          'each archetype, see a coaching review of your leaks, replay any '
          'hand step-by-step from the session summary, and export a '
          "session's hands as a PokerStars-style history.",
    ),
  ];

  // ------------------------------------------------------------ good to know
  static const String goodToKnowHeading = 'Good to know';

  static const List<AboutBullet> goodToKnow = [
    AboutBullet(
      lead: '',
      body:
          'Fully offline — your hands and progress stay on your machine '
          '(everything is stored on this phone).',
      good: true,
    ),
    AboutBullet(
      lead: '',
      body:
          'Coaching and drills are graded by honest heuristics, not a solver '
          '— see "How the grading works" below for exactly what that means.',
    ),
    AboutBullet(
      lead: '',
      body:
          "It's a play-money trainer for learning. Variance is real: even "
          'good play swings, so judge yourself on decisions (the coach) more '
          'than short-term results.',
    ),
  ];

  // ---------------------------------------------------- how the grading works
  static const String gradingHeading = 'How the grading works';

  static const String gradingIntro =
      'An honest summary of where the "right answers" come from, so you know '
      'how much to trust each verdict:';

  static const List<AboutBullet> grading = [
    AboutBullet(
      lead: 'Pre-flop charts',
      body:
          ' (drills and study diagrams) are self-authored consensus baselines '
          'for 100bb 6-max — solid standard play keyed by your position and '
          "the raiser's, with mixed frequencies where real strategies mix. "
          "They're not direct solver output; bot ranges still use a "
          'simplified model that\'s being upgraded next.',
    ),
    AboutBullet(
      lead: 'Post-flop coaching',
      body:
          " compares your pot odds with your hand's chance of winning, "
          'estimated by dealing thousands of random runouts against the '
          "opponent's likely hands (a Monte-Carlo simulation). That catches "
          "clear mistakes well, but it can't see everything a solver sees — "
          'treat close verdicts as guidance, not gospel.',
    ),
    AboutBullet(
      lead: 'Push/fold drills',
      good: true,
      body:
          ' use Nash equilibrium tables we computed ourselves (chip-EV, no '
          'antes, one caller at a time) — mixed-frequency hands accept either '
          'answer, like the real equilibrium does. A third of push/fold reps '
          'are ICM bubble spots — solved the same way, but in tournament '
          'money instead of chips. Ante variants are still to come.',
    ),
  ];

  // -------------------------------------------------------------- roadmap
  static const String roadmapHeading = 'On the roadmap';

  static const String roadmapIntro =
      'Coming next (see the project README for the full, prioritised list):';

  static const List<String> roadmap = [
    'Configurable table — stack depths, 9-max, antes',
    'Import your real online hand histories for coaching',
    'Hand-history import from more sites',
    'Share a hand as an image',
  ];

  static const String roadmapFootnote =
      "It's evolving — feedback and ideas are welcome.";

  // -------------------------------------------------------------- built by
  static const String builtByHeading = 'Built by';
  static const String author = 'Gapp';

  static const String builtByBody =
      'Designed and built by Gapp. Made with Flutter and Dart. Thanks for '
      'playing — feedback is always welcome.';

  static const String footer = 'All-In · Poker Dojo — © Gapp';
}
