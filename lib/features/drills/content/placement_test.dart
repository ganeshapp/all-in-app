/// D5 · the placement test's questions and result copy (DESIGN.md §5.8;
/// docs/port/drill-ux-srs-leaks.md §10 — every string verbatim).
///
/// Option lists are stored **correct-answer-first** exactly like the desktop's
/// and shuffled once per question with Fisher–Yates when the test starts, so
/// the answer key is `index == 0` of the unshuffled list.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

/// One question; `options.first` is the right answer before shuffling.
@immutable
class PlacementQuestion {
  const PlacementQuestion({required this.question, required this.options});

  final String question;
  final List<String> options;

  /// The verbatim answer.
  String get answer => options.first;
}

/// The eight questions, verbatim and in order.
const List<PlacementQuestion> kPlacementQuestions = [
  PlacementQuestion(
    question: 'Which beats which?',
    options: [
      'A flush beats a straight',
      'A straight beats a flush',
      'They tie',
    ],
  ),
  PlacementQuestion(
    question: 'The best seat at the table is…',
    options: [
      'The button — you act last after the flop',
      'Under the gun — you act first',
      "The big blind — you've already paid",
    ],
  ),
  PlacementQuestion(
    question:
        'The pot is 10 bb and your opponent bets 5 bb. To call profitably '
        'you need to win about…',
    options: ['1 time in 4', '1 time in 2', '2 times in 3'],
  ),
  PlacementQuestion(
    question:
        'A flush draw on the flop (9 outs, two cards to come) has roughly '
        'what chance of hitting?',
    options: ['About 36%', 'About 18%', 'About 9%'],
  ),
  PlacementQuestion(
    question: 'Why 3-bet (re-raise) before the flop?',
    options: [
      'Value with big hands, plus pressure with the right bluffs',
      'Only ever with aces',
      'To see a cheap flop',
    ],
  ),
  PlacementQuestion(
    question:
        'In a 3-bet pot with a low stack-to-pot ratio, top pair top kicker '
        'is usually…',
    options: [
      'A hand worth your whole stack',
      'A fold to any bet',
      'A hand to keep the pot tiny with',
    ],
  ),
  PlacementQuestion(
    question:
        'Against a player who never bluffs, their big river bet means you '
        'should…',
    options: [
      "Fold hands that only beat bluffs — even if folding is 'exploitable'",
      "Call just often enough that bluffing can't profit",
      'Always raise',
    ],
  ),
  PlacementQuestion(
    question:
        'With 10 big blinds in the small blind, folded to you, a solid '
        'strategy is…',
    options: [
      'Go all-in with over half your hands',
      'Only go all-in with premium pairs',
      'Just call the minimum and decide later',
    ],
  ),
];

/// One question's options in the order they are shown.
@immutable
class PlacementShuffle {
  const PlacementShuffle(this.options);

  final List<String> options;
}

/// Fisher–Yates once per question, exactly like the desktop.
List<PlacementShuffle> shufflePlacement(Random rng) => [
  for (final q in kPlacementQuestions)
    PlacementShuffle(_fisherYates(q.options, rng)),
];

List<String> _fisherYates(List<String> source, Random rng) {
  final out = [...source];
  for (var i = out.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}

/// The result card's three bands (verbatim).
@immutable
class PlacementResult {
  const PlacementResult({
    required this.headline,
    required this.advice,
    required this.lessonId,
    required this.rating,
  });

  final String headline;
  final String advice;

  /// The lesson "Take me there" opens as a Study-branch push (§5.8).
  final String lessonId;

  /// What `seedRating` writes.
  final double rating;

  /// `{score}/8 — drills are calibrated to match. {advice}`
  String body(int score) =>
      '$score/8 — drills are calibrated to match. $advice';

  /// Bands: ≤ 2 → 900 · ≤ 5 → 1050 · else 1250.
  static PlacementResult forScore(int score) {
    if (score <= 2) {
      return const PlacementResult(
        headline: 'Starting fresh — perfect.',
        advice:
            'Begin with Level 1: Hand Rankings. The course assumes nothing.',
        lessonId: 'hand-rankings',
        rating: 900,
      );
    }
    if (score <= 5) {
      return const PlacementResult(
        headline: 'You know the basics.',
        advice:
            'Start at Pot Odds & EV — the math that powers every decision '
            'here.',
        lessonId: 'pot-odds',
        rating: 1050,
      );
    }
    return const PlacementResult(
      headline: 'Solid foundations.',
      advice:
          'Jump into the advanced track — 3-bet pots and river play — and let '
          'the drills find your edges.',
      lessonId: 'threebet-pots',
      rating: 1250,
    );
  }
}

abstract final class PlacementCopy {
  static const String intro =
      'Eight quick questions calibrate the drills to your level — harder '
      "spots if you're experienced, clearer ones if you're new. No grade, no "
      'judgment, and you can skip it.';
  static const String skip = 'Skip — start playing';
  static const String calibrate = 'Calibrate me';
  static const String title = 'Placement test';

  /// The eyebrow over each question (verbatim).
  static String progress(int index) => 'Question ${index + 1} of 8';

  /// *(new)* — the faint footer under the options (§5.8).
  static const String footer = 'No grade, no judgment — you can stop any time.';

  static const String takeMeThere = 'Take me there';
  static const String startPlaying = 'Start playing';

  /// The tap → advance delay (§5.8: good/bad tint 350 ms, then advance).
  static const Duration advanceDelay = Duration(milliseconds: 350);
}
