/// The §3.5 practice mini-heatmap: the last five columns of the full 16-week
/// grid, 12 pt cells, one 72 pt tap target that opens Progress.
///
/// It is a picture of a habit, not a control, so it passes
/// `inspectable: false` — the drag-to-inspect gesture belongs to the full grid
/// in Stats (§7.11, §12).
library;

import 'package:flutter/material.dart';

import '../../../services/persistence/goals_store.dart' show HeatmapCell;
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../home_copy.dart';

/// §3.5: five weeks × 7 = 35 cells.
const int kMiniHeatmapWeeks = 5;
const int kMiniHeatmapCells = kMiniHeatmapWeeks * 7;

/// The last [kMiniHeatmapCells] of `heatmapProvider`'s column-major list.
List<HeatmapCell> lastWeeks(List<HeatmapCell> cells) =>
    cells.length <= kMiniHeatmapCells
        ? cells
        : cells.sublist(cells.length - kMiniHeatmapCells);

class MiniHeatmapCard extends StatelessWidget {
  const MiniHeatmapCard({super.key, required this.cells, this.onTap});

  /// Already trimmed by [lastWeeks].
  final List<HeatmapCell> cells;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = HeatmapGrid.activeDays(cells);
    return AllInCard.plain(
      onTap: onTap,
      semanticLabel:
          '${HomeCopy.practiceSemantics} ${HomeCopy.activeDays(active)}.',
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow(HomeCopy.eyebrowPractice)),
              Text(
                HomeCopy.practiceWeeks,
                style: AllInText.mono(12, color: c.textFaint),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          ExcludeSemantics(
            child: HeatmapGrid(
              cells: cells,
              weeks: kMiniHeatmapWeeks,
              cellSize: 12,
              inspectable: false,
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          Text(
            HomeCopy.activeDays(active),
            style: AllInText.body(13, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
