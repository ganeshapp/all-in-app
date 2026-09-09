/// `RangeBoardBreakdownCard` — "how does this range hit this board"
/// (DESIGN.md §6.5, docs/port/study-curriculum.md §12.7). One card per range:
/// made-hand rows (label · bar · percentage), then the draws footer.
library;

import 'package:allin/engine/format.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;

/// Category buckets in the fixed display order of §12.7 (strongest first).
const List<HandCategory> kBreakdownOrder = <HandCategory>[
  HandCategory.straightFlush,
  HandCategory.quads,
  HandCategory.fullHouse,
  HandCategory.flush,
  HandCategory.straight,
  HandCategory.trips,
  HandCategory.twoPair,
  HandCategory.pair,
  HandCategory.highCard,
];

class RangeBoardBreakdownCard extends StatelessWidget {
  const RangeBoardBreakdownCard({
    super.key,
    required this.title,
    required this.range,
    required this.board,
    this.dead = const <Card>[],
  });

  final String title;
  final Set<HandLabel> range;
  final List<Card> board;

  /// Extra removed cards — the hero's exact hand in hand mode.
  final List<Card> dead;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (board.length < 3 || range.isEmpty) return const SizedBox.shrink();
    final b = breakdownRange(range, board, dead);
    if (b.total == 0) return const SizedBox.shrink();

    final buckets = <(HandCategory, int)>[
      for (final cat in kBreakdownOrder)
        if ((b.catCount[cat.index] ?? 0) > 0) (cat, b.catCount[cat.index]!),
    ];
    final max = buckets.fold<int>(1, (a, e) => e.$2 > a ? e.$2 : a);

    Color toneFor(HandCategory cat) {
      if (cat.index >= HandCategory.straight.index) return c.good;
      if (cat.index >= HandCategory.pair.index) return c.gold;
      return c.ink500;
    }

    return AllInCard.plain(
      padding: const EdgeInsets.all(AllInSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AllInText.body(
                    12.8,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Text(
                '${b.total} combos on ${board.join(' ')}',
                style: AllInText.body(10.9, color: c.textFaint),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.sm),
          for (final bucket in buckets)
            Padding(
              padding: const EdgeInsets.only(bottom: AllInSpace.xs),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 86,
                    child: Text(
                      bucket.$1.label,
                      style: AllInText.body(11.5, color: c.textMuted),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 10,
                        color: c.ink700,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (bucket.$2 / max).clamp(0.0, 1.0),
                          child: Container(color: toneFor(bucket.$1)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      fmtPct(bucket.$2 / b.total),
                      textAlign: TextAlign.end,
                      style: AllInText.mono(11.5, color: c.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          if (board.length < 5 && (b.flushDraws > 0 || b.oesds > 0))
            Padding(
              padding: const EdgeInsets.only(top: AllInSpace.xs),
              child: Wrap(
                spacing: AllInSpace.lg,
                children: <Widget>[
                  if (b.flushDraws > 0)
                    Text(
                      'Flush draws: ${fmtPct(b.flushDraws / b.total)}',
                      style: AllInText.body(11.2, color: c.textFaint),
                    ),
                  if (b.oesds > 0)
                    Text(
                      'Open-enders: ${fmtPct(b.oesds / b.total)}',
                      style: AllInText.body(11.2, color: c.textFaint),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
