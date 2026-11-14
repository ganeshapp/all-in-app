import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../../play/providers/hand_reads_provider.dart';
import '../../play/widgets/hand_read_card.dart';
import '../../play/widgets/hand_read_copy.dart';
import 'stats_section.dart';

class HandReadingCard extends ConsumerWidget {
  const HandReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reads = ref.watch(handReadsProvider);
    final revealed = reads.where((r) => r.hit != null).toList();
    final singles = revealed.where((r) => r.selected.length == 1).toList();
    final hits = revealed.where((r) => r.hit == true).length;
    final pending =
        reads.where((r) => r.status == HandReadStatus.pending).length;
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    return StatsSection(
      title: HandReadCopy.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reads.isEmpty)
            Text(
              HandReadCopy.empty,
              style: AllInText.body(14, color: c.textMuted),
            )
          else ...[
            Text(
              HandReadCopy.summary(hits, revealed.length),
              style: AllInText.display(23, color: c.text),
            ),
            const SizedBox(height: AllInSpace.sm),
            if (revealed.isNotEmpty)
              Text(
                HandReadCopy.breadth(
                  revealed.fold<int>(0, (n, r) => n + r.selected.length) /
                      revealed.length,
                  singles.where((r) => r.hit == true).length,
                  singles.length,
                ),
                style: AllInText.body(14, color: c.textMuted),
              ),
            if (pending > 0)
              Text(
                HandReadCopy.pending(pending),
                style: AllInText.body(14, color: c.textMuted),
              ),
            const SizedBox(height: AllInSpace.sm),
            Text(
              HandReadCopy.sampleHint,
              style: AllInText.body(13, color: c.textFaint),
            ),
            DisclosureRow(
              label:
                  reads.length > 20
                      ? HandReadCopy.latestTwenty
                      : HandReadCopy.recent,
              enableHaptics: settings.haptics,
              reducedMotion: settings.reducedMotion,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final read in reads.reversed.take(20)) ...[
                    Text(
                      HandReadCopy.context(read),
                      style: AllInText.body(13, color: c.textMuted),
                    ),
                    const SizedBox(height: AllInSpace.xs),
                    HandReadCard(read: read),
                    const SizedBox(height: AllInSpace.md),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
