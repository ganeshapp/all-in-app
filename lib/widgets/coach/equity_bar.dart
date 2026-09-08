/// `EquityBar` — the "Win chance vs Ivey ⓘ 17 %" row, the 10 pt bar with the
/// white "needed" marker and the pot-odds caption (DESIGN.md §10.5, §4.8;
/// desktop `EVCoachPanel` body step 2 in docs/port/play-loop-and-coach.md §9).
///
/// Both ⓘ targets open the §6.3 term popover with the verbatim tooltip bodies;
/// they are 20 pt glyphs inside a 44 pt [HitSlop] (§12).
library;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/term_popover.dart';
import '../foundations/term_text.dart' show HitSlop;

class EquityBar extends StatelessWidget {
  const EquityBar({
    super.key,
    required this.equity,
    this.potOdds,
    this.villainName,
    this.color,
    this.height = 10,
    this.showCaption = true,
    this.onOpenGlossary,
    this.reducedMotion = false,
  });

  /// 0–1. Rendered as `round(equity × 100) %`, desktop parity.
  final double equity;

  /// 0–1; the white marker and the caption are drawn only when > 0.
  final double? potOdds;

  /// "Win chance vs Ivey" — the row reads "Win chance" when null.
  final String? villainName;

  /// The verdict colour of the note this bar belongs to. Defaults to `info`.
  final Color? color;

  final double height;
  final bool showCaption;

  /// "Open glossary ›" inside the popover; hidden when null.
  final void Function(String termId)? onOpenGlossary;

  final bool reducedMotion;

  /// The verbatim tooltip bodies of §4.8 / port §9.
  static const TermDefinition equityTerm = TermDefinition(
    id: 'equity',
    term: 'Win chance (equity)',
    definition:
        'how often your hand ends up best if the rest of the cards were dealt '
        'out with nobody folding.',
  );

  static const TermDefinition potOddsTerm = TermDefinition(
    id: 'pot-odds',
    term: 'Pot odds',
    definition:
        'the share of the final pot your call pays for. Win more often than '
        'this and the call makes money.',
  );

  static int _pct(double fraction) => jsRound(fraction * 100).toInt();

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = color ?? c.info;
    final equityPct = _pct(equity);
    final odds = potOdds ?? 0.0;
    final oddsPct = _pct(odds);
    final showMarker = odds > 0;
    final label =
        villainName == null || villainName!.isEmpty
            ? 'Win chance'
            : 'Win chance vs $villainName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(label, style: AllInText.body(14, color: c.textMuted)),
            ),
            _InfoDot(
              definition: equityTerm,
              onOpenGlossary: onOpenGlossary,
              reducedMotion: reducedMotion,
            ),
            const Spacer(),
            Text('$equityPct %', style: AllInText.mono(15, color: tone)),
          ],
        ),
        const SizedBox(height: AllInSpace.sm),
        Semantics(
          label:
              showMarker
                  ? 'Win chance $equityPct percent, $oddsPct percent needed'
                  : 'Win chance $equityPct percent',
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final fill = _clamp01(equity) * width;
                final markerX = (_clamp01(odds) * width - 1).clamp(
                  0.0,
                  width > 2 ? width - 2 : 0.0,
                );
                return SizedBox(
                  height: height,
                  width: width,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: c.ink600,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                      Container(
                        width: fill,
                        decoration: BoxDecoration(
                          color: tone,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                      if (showMarker)
                        Positioned(
                          left: markerX,
                          top: 0,
                          bottom: 0,
                          // The spec's "white 2 pt marker"; `cardFaceTop` is
                          // the token-legal pure white (§16.5 — no literals).
                          child: Container(
                            width: 2,
                            color: AllInColors.cardFaceTop,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (showCaption && showMarker) ...[
          const SizedBox(height: AllInSpace.xs),
          Row(
            children: [
              Flexible(
                child: Text(
                  'White line = $oddsPct % needed (pot odds)',
                  style: AllInText.body(13, color: c.textFaint),
                ),
              ),
              _InfoDot(
                definition: potOddsTerm,
                onOpenGlossary: onOpenGlossary,
                reducedMotion: reducedMotion,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A 20 pt ⓘ in a 44 pt target that opens the term popover.
class _InfoDot extends StatelessWidget {
  const _InfoDot({
    required this.definition,
    this.onOpenGlossary,
    this.reducedMotion = false,
  });

  final TermDefinition definition;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'About ${definition.term}',
      child: ExcludeSemantics(
        child: HitSlop(
          minSize: const Size(44, 44),
          child: TermPopover(
            termId: definition.id,
            definition: definition,
            onOpenGlossary: onOpenGlossary,
            reducedMotion: reducedMotion,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.xs),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: context.colors.textFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
