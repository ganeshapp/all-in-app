/// One page of the O0 tour (DESIGN.md §8.1).
///
/// Geometry from the wireframe: a 72 pt icon tile (gold @ 15 %, glyph 32 gold),
/// the title in Bricolage 26 centred, the body in Inter 16/1.5 muted centred
/// and never wider than 326 pt. Page 4 swaps the tile for a live, inert
/// [CoachNoteView] so the three-layer anatomy is seen before it is met.
///
/// The page scrolls: at 1.3× text scale on a 360×780 phone the longest body
/// (page 2) is taller than the space between the header and the button.
library;

import 'package:allin/engine/coach.dart';
import 'package:allin/features/onboarding/content/tour_copy.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

class TourPage extends StatelessWidget {
  const TourPage({super.key, required this.copy, this.illustration});

  final TourPageCopy copy;

  /// Replaces the icon tile (page 4's coach note).
  final Widget? illustration;

  /// §8.1 "icon tile 72, gold @ 15 %, icon 32 gold".
  static const double tileSize = 72;
  static const double glyphSize = 32;

  /// §8.1 "max 326 wide".
  static const double bodyMaxWidth = 326;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.lg,
              vertical: AllInSpace.md,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    constraints.maxHeight.isFinite
                        ? constraints.maxHeight - AllInSpace.md * 2
                        : 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  illustration ?? TourIconTile(icon: copy.icon),
                  const SizedBox(height: AllInSpace.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: AllInText.display(26, color: c.text, height: 1.2),
                    ),
                  ),
                  const SizedBox(height: AllInSpace.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: bodyMaxWidth),
                    child: Text(
                      copy.body,
                      textAlign: TextAlign.center,
                      style: AllInText.body(
                        16,
                        color: c.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (copy.footnote != null) ...[
                    const SizedBox(height: AllInSpace.lg),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: bodyMaxWidth),
                      child: Text(
                        copy.footnote!,
                        textAlign: TextAlign.center,
                        style: AllInText.body(
                          13,
                          color: c.textFaint,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }
}

/// The gold tile behind a page's glyph.
class TourIconTile extends StatelessWidget {
  const TourIconTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final gold = context.colors.gold;
    return ExcludeSemantics(
      child: Container(
        width: TourPage.tileSize,
        height: TourPage.tileSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AllInRadius.xl),
        ),
        child: Icon(icon, size: TourPage.glyphSize, color: gold),
      ),
    );
  }
}

/// Page 4's illustration: a real [CoachNoteView] carrying the TONE.md example,
/// rendered read-only and behind an [IgnorePointer] so the disclosure rows are
/// visible as structure without inviting a tap that leads nowhere (§8.1).
class TourCoachNotePreview extends StatelessWidget {
  const TourCoachNotePreview({super.key, this.reducedMotion = false});

  final bool reducedMotion;

  /// The TONE.md layer-1 example, with layers 2 and 3 derived from the same
  /// numbers: 8 bb to call into a 24 bb pot, a hand that wins about 1 time
  /// in 3.
  static const CoachReview review = CoachReview(
    id: 0,
    kind: ReviewKind.decision,
    blocking: false,
    verdict: Verdict.great,
    title: 'Your call',
    equity: 0.33,
    potOdds: 0.25,
    evChips: 32,
    board: <String>['Ah', '7d', '2c', 'Ts', '4h'],
    plain:
        'You paid 8 bb to win a pot of 24 bb — you need to win about 1 time '
        'in 4. Your hand wins about 1 time in 3, so this call makes you '
        'money.',
    text: 'Call is +EV: your chance to win beats the price you were offered.',
    steps: <String>[
      'The pot was 16 bb and the bet was 8 bb, so calling 8 bb plays for 24 bb.',
      'Price: 8 ÷ 24 = 33 chips risked per 100 in the pot — you need to win '
          'about 25% of the time to break even.',
      'Your hand wins about 33% of the time against the hands they bet here.',
      '33% is more than 25%, so every call like this one makes money over '
          'time.',
    ],
    expert: <String>[
      'Equity 33% vs pot odds 25% — a 8% edge on an 8 bb call.',
      'Estimated by dealing thousands of random runouts against their likely '
          'hands; treat verdicts inside the margin of error as too close to '
          'call.',
    ],
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AllInCard(
          child: CoachNoteView(
            review: review,
            readOnly: true,
            reducedMotion: reducedMotion,
            enableHaptics: false,
          ),
        ),
      ),
    ),
  );
}
