/// O0 · every string on the onboarding tour (DESIGN.md §8.1, §8.2).
///
/// The four page bodies and the placement paragraph are **verbatim** from the
/// desktop (docs/port/design-brand-onboarding.md §12.3 and §12.4). The two
/// mobile additions §8 permits are marked *(new)*: the accessibility footer on
/// page 1 (§13 "the four-colour deck is offered in onboarding page 1's
/// footer") and the touch wording of the buttons.
///
/// Nothing here imports Flutter beyond `IconData`, so the copy can be asserted
/// in a pure test.
library;

import 'package:flutter/material.dart';

/// One tour page.
@immutable
class TourPageCopy {
  const TourPageCopy({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    this.footnote,
  });

  /// The desktop's step id (`play` · `target` · `book` · `coach`).
  final String id;

  /// The 32 pt gold glyph inside the 72 pt tile (§8.1).
  final IconData icon;

  /// Bricolage 26, centred.
  final String title;

  /// Inter 16/1.5 muted, centred, max 326 wide — verbatim.
  final String body;

  /// An extra muted line under the body (page 1's four-colour-deck offer).
  final String? footnote;
}

abstract final class TourCopy {
  /// The navigation title on every page (§8.1, desktop parity).
  static const String title = 'Welcome to All-In';

  /// Pages 1–4's descriptor; `{n}` is the 1-based page.
  static String tourDescriptor(int page) => 'A 60-second tour · $page of 4';

  /// Page 5's descriptor.
  static const String placementDescriptor = 'Optional placement';

  static const String skip = 'Skip';
  static const String close = 'Close';
  static const String next = 'Next';
  static const String continueLabel = 'Continue';

  /// Page 5 (§8.2).
  static const String placementTitle = 'Optional placement';
  static const String placementBody =
      'Eight quick questions calibrate the drills to your level — harder '
      "spots if you're experienced, clearer ones if you're new. No grade, no "
      'judgment, and you can skip it.';
  static const String placementSkip = 'Skip — start playing';
  static const String placementStart = 'Calibrate me';

  /// *(new)* §13 — the colour-blind offer lives in page 1's footer.
  static const String fourColourFootnote =
      'Trouble telling suits apart? Turn on the four-colour deck in Settings.';

  /// The four tour pages, verbatim (docs/port/design-brand-onboarding §12.3).
  static const List<TourPageCopy> pages = [
    TourPageCopy(
      id: 'play',
      icon: Icons.play_arrow_rounded,
      title: 'Play against real-ish opponents',
      body:
          'Four bot styles with genuinely different tendencies. The EV Coach '
          'watches every decision and explains — in plain English first — '
          "whether it made money. At the end of each hand, everyone's cards "
          "are revealed, folds included: that's how you build intuition.",
      footnote: fourColourFootnote,
    ),
    TourPageCopy(
      id: 'target',
      icon: Icons.track_changes_rounded,
      title: 'Drill like chess puzzles',
      body:
          'Short spots with instant feedback: the answer, why, how much a '
          'mistake costs in big blinds, and the exact set of hands (the '
          'range) you were graded against. Anything you miss — and anything '
          'the coach flags in play — comes back on a spaced schedule until '
          "you've beaten it three times.",
    ),
    TourPageCopy(
      id: 'book',
      icon: Icons.menu_book_rounded,
      title: 'Study when you want the why',
      body:
          'A 31-lesson course from the rules up to 3-bet pots and river play, '
          'with interactive calculators. Drill feedback links straight to the '
          'lesson that teaches each concept.',
    ),
    TourPageCopy(
      id: 'coach',
      icon: Icons.balance_rounded,
      title: 'Judge decisions, not results',
      body:
          'Poker pays good decisions slowly and randomly. You\'ll lose hands '
          'you played perfectly and win hands you butchered. This app grades '
          'the decision — the only thing you control. That mindset is the '
          'whole game.',
    ),
  ];

  /// Pages 1–4 plus the placement intro.
  static const int pageCount = 5;

  /// The index of the placement intro (§8.2 "page 5").
  static const int placementPage = 4;
}
