/// T0's "Practice" card — the 16 × 7 heatmap of DESIGN.md §7.11 and
/// `docs/port/persistence-stats-settings.md` §7.10.
///
/// Drag-to-inspect, never tap: an 11 pt cell is a quarter of the §12 floor, so
/// the grid claims the pointer after a 200 ms hold and a label follows the
/// finger. A plain tap does nothing — the grid is a picture of a habit, not a
/// control. `HeatmapGrid` owns that gesture; this card owns the two verbatim
/// captions and the §13 summary node.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../services/persistence.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../stats_copy.dart';
import 'stats_section.dart';

class PracticeCard extends ConsumerWidget {
  const PracticeCard({super.key, required this.cells});

  final List<HeatmapCell> cells;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final active = GoalsStore.activeDays(cells);

    return StatsSection(
      title: StatsCopy.practiceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: HeatmapGrid(
              cells: cells,
              enableHaptics: settings.haptics,
              reducedMotion: settings.reducedMotion,
              semanticLabel: StatsCopy.practiceSemantics(active),
              labelBuilder:
                  (cell) => StatsCopy.practiceCell(
                    key: cell.key,
                    count: cell.count,
                    met: cell.met,
                  ),
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          Text(
            active == 0
                ? StatsCopy.practiceEmpty
                : StatsCopy.practiceCaption(active),
            style: AllInText.body(12, color: c.textFaint, height: 1.5),
          ),
        ],
      ),
    );
  }
}
