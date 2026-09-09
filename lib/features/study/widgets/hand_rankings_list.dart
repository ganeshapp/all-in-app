/// `HandRankingsList` — the static ten-row ranking table (DESIGN.md §6.5,
/// docs/port/study-curriculum.md §12.1). Rows are 64 tall: rank circle 28 ·
/// name Inter 15 semibold · five cards 32×45 · example line faint.
library;

import 'package:allin/engine/types.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;

/// One ranking row, in desktop order (strongest first).
class HandRanking {
  const HandRanking(this.rank, this.name, this.cards, this.note);
  final int rank;
  final String name;
  final List<Card> cards;
  final String note;
}

const List<HandRanking> kHandRankings = <HandRanking>[
  HandRanking(1, 'Royal Flush', <Card>[
    'Ah',
    'Kh',
    'Qh',
    'Jh',
    'Th',
  ], 'A-K-Q-J-T, one suit'),
  HandRanking(2, 'Straight Flush', <Card>[
    '9s',
    '8s',
    '7s',
    '6s',
    '5s',
  ], 'Five in a row, one suit'),
  HandRanking(3, 'Four of a Kind', <Card>[
    'Qh',
    'Qd',
    'Qc',
    'Qs',
    '3d',
  ], 'All four of a rank'),
  HandRanking(4, 'Full House', <Card>[
    'Jh',
    'Jd',
    'Jc',
    '8s',
    '8h',
  ], 'Three of a kind + a pair'),
  HandRanking(5, 'Flush', <Card>[
    'Ad',
    'Jd',
    '8d',
    '5d',
    '2d',
  ], 'Five of one suit'),
  HandRanking(6, 'Straight', <Card>[
    '9h',
    '8s',
    '7d',
    '6c',
    '5h',
  ], 'Five in a row, mixed suits'),
  HandRanking(7, 'Three of a Kind', <Card>[
    '7h',
    '7d',
    '7c',
    'Ks',
    '2d',
  ], 'Three of a rank'),
  HandRanking(8, 'Two Pair', <Card>[
    'Ah',
    'Ad',
    '9c',
    '9s',
    '4d',
  ], 'Two different pairs'),
  HandRanking(9, 'One Pair', <Card>[
    'Th',
    'Td',
    'As',
    '7c',
    '3d',
  ], 'A single pair'),
  HandRanking(10, 'High Card', <Card>[
    'Ah',
    'Jd',
    '8c',
    '5s',
    '2d',
  ], 'Nothing — highest card plays'),
];

class HandRankingsList extends StatelessWidget {
  const HandRankingsList({
    super.key,
    required this.available,
    this.fourColorDeck = false,
  });

  /// Content width this block was given.
  final double available;
  final bool fourColorDeck;

  @override
  Widget build(BuildContext context) {
    // Five cards at 32 plus their gaps must fit next to the circle and the
    // name; on a narrow phone the cards shrink rather than overflow.
    final cardWidth = ((available - 28 - 8 - 24 - 4 * 3) / 5).clamp(18.0, 32.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < kHandRankings.length; i++) ...<Widget>[
          _RankingRow(
            row: kHandRankings[i],
            cardWidth: cardWidth,
            fourColorDeck: fourColorDeck,
          ),
          if (i < kHandRankings.length - 1)
            const SizedBox(height: AllInSpace.sm),
        ],
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.row,
    required this.cardWidth,
    required this.fourColorDeck,
  });

  final HandRanking row;
  final double cardWidth;
  final bool fourColorDeck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: '${row.rank}. ${row.name}. ${row.note}',
      excludeSemantics: true,
      child: AllInCard.plain(
        padding: const EdgeInsets.symmetric(
          horizontal: AllInSpace.md,
          vertical: AllInSpace.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${row.rank}',
                style: AllInText.mono(12, color: c.goldLight),
              ),
            ),
            const SizedBox(width: AllInSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    row.name,
                    style: AllInText.body(
                      15,
                      weight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  Text(
                    row.note,
                    style: AllInText.body(11.5, color: c.textFaint),
                  ),
                  const SizedBox(height: AllInSpace.xs),
                  Row(
                    children: <Widget>[
                      for (var i = 0; i < row.cards.length; i++) ...<Widget>[
                        PlayingCardView(
                          card: row.cards[i],
                          width: cardWidth,
                          fourColorDeck: fourColorDeck,
                        ),
                        if (i < row.cards.length - 1)
                          const SizedBox(width: AllInSpace.xs),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
