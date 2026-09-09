/// Every pixel size the table varies by width and seat count, in one place:
/// DESIGN.md §4.2 (6-max at 390), §4.2.1 (heads-up), §4.2.2 (9-max) and
/// §4.2.3 (the 360 and 430 columns).
///
/// The felt itself is laid out in **fractions** (`FeltGeometry`), so this class
/// only carries the things that are absolute: plate, card, pill and chip sizes,
/// the page margin and the name truncation limit. Three tiers — < 390, < 430,
/// ≥ 430 — because that is exactly how §4.2.3 states them.
library;

import 'package:allin/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

@immutable
class TableMetrics {
  const TableMetrics({
    required this.seats,
    required this.tier,
    required this.margin,
    required this.plateVariant,
    required this.plateSize,
    required this.holeCardWidth,
    required this.cardPeek,
    required this.boardCardWidth,
    required this.boardGap,
    required this.heroCardWidth,
    required this.betPillMax,
    required this.heroBetPillMax,
    required this.potPillMax,
    required this.coachChipWidth,
    required this.nameLimit,
  });

  /// 2 · 6 · 9.
  final int seats;

  /// 0 = 360-class, 1 = 390-class, 2 = 430-class.
  final int tier;

  /// The page margin: 16, or 20 at 430 (§4.2.3).
  final double margin;

  final SeatPlateVariant plateVariant;
  final Size plateSize;
  final double holeCardWidth;
  final double cardPeek;
  final double boardCardWidth;
  final double boardGap;
  final double heroCardWidth;
  final double betPillMax;
  final double heroBetPillMax;
  final double potPillMax;
  final double coachChipWidth;

  /// Names truncate at 6 characters at 360 (§4.2.3), else the plate default.
  final int nameLimit;

  /// Hero cards overlap the felt's bottom rim by 44 pt (§4.4).
  static const double heroOverlap = 44;

  /// The gap between the hero cards' bottom and the hero strip (§4.2).
  static const double heroStripGap = 8;

  double get heroCardHeight => PlayingCardView.heightFor(heroCardWidth);

  /// How far the hero cards hang below the felt.
  double get heroOverhang => heroCardHeight - heroOverlap;

  double get boardWidth => BoardRow.widthFor(boardCardWidth, boardGap);

  static int tierFor(double width) => width < 390 ? 0 : (width < 430 ? 1 : 2);

  static TableMetrics of(double width, int seats) {
    final tier = tierFor(width);
    double pick(List<double> v) => v[tier];

    switch (seats) {
      case 2:
        return TableMetrics(
          seats: 2,
          tier: tier,
          margin: tier == 2 ? 20 : 16,
          plateVariant: SeatPlateVariant.hu,
          plateSize: Size(
            pick(const [148, 160, 176]),
            pick(const [60, 64, 70]),
          ),
          holeCardWidth: pick(const [30, 34, 38]),
          cardPeek: 24,
          boardCardWidth: pick(const [46, 52, 58]),
          boardGap: 6,
          heroCardWidth: pick(const [72, 80, 80]),
          betPillMax: pick(const [40, 44, 48]),
          heroBetPillMax: pick(const [36, 40, 44]),
          potPillMax: pick(const [120, 130, 143]),
          coachChipWidth: pick(const [274, 300, 330]),
          nameLimit: tier == 0 ? 6 : 12,
        );
      case 9:
        return TableMetrics(
          seats: 9,
          tier: tier,
          margin: tier == 2 ? 20 : 16,
          plateVariant: SeatPlateVariant.compact,
          plateSize: Size(pick(const [78, 84, 92]), pick(const [46, 50, 55])),
          holeCardWidth: pick(const [22, 24, 28]),
          cardPeek: pick(const [12, 14, 16]),
          boardCardWidth: pick(const [28, 32, 36]),
          boardGap: 3,
          // §10.3's call-site table: 9-max hero cards are 40×56 at 360 and
          // 64×90 at 390; 430 keeps the 6-max step.
          heroCardWidth: pick(const [40, 64, 72]),
          betPillMax: pick(const [40, 44, 48]),
          heroBetPillMax: pick(const [36, 40, 44]),
          potPillMax: pick(const [120, 130, 143]),
          coachChipWidth: pick(const [274, 300, 330]),
          nameLimit: tier == 0 ? 5 : 5,
        );
      default:
        return TableMetrics(
          seats: 6,
          tier: tier,
          margin: tier == 2 ? 20 : 16,
          plateVariant: SeatPlateVariant.standard,
          plateSize: Size(pick(const [96, 104, 112]), pick(const [54, 58, 60])),
          holeCardWidth: pick(const [28, 30, 34]),
          cardPeek: 24,
          boardCardWidth: pick(const [40, 44, 50]),
          boardGap: pick(const [5, 6, 6]),
          heroCardWidth: pick(const [64, 72, 80]),
          betPillMax: pick(const [40, 44, 48]),
          heroBetPillMax: pick(const [36, 40, 44]),
          potPillMax: pick(const [120, 130, 143]),
          coachChipWidth: pick(const [274, 300, 330]),
          nameLimit: tier == 0 ? 6 : 8,
        );
    }
  }
}
