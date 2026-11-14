import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/hand_reads_provider.dart';
import 'hand_read_copy.dart';

/// The actual-card result, deliberately separate from the estimated range.
class HandReadCard extends ConsumerWidget {
  const HandReadCard({super.key, required this.read});
  final HandRead read;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AllInCard.plain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            HandReadCopy.heading(read),
            style: AllInText.display(
              25,
              color: read.hit == true ? c.good : c.text,
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          if (read.status == HandReadStatus.revealed) ...[
            Row(
              children: [
                for (final card in read.shownCards)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PlayingCardView(
                      card: card,
                      width: 44,
                      fourColorDeck: ref.watch(settingsProvider).fourColorDeck,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AllInSpace.sm),
          ],
          Text(
            HandReadCopy.body(read),
            style: AllInText.body(15, color: c.text, height: 1.45),
          ),
          const SizedBox(height: AllInSpace.sm),
          Text(
            HandReadCopy.selected(read.selected.length),
            style: AllInText.body(13, color: c.goldLight),
          ),
          DisclosureRow(
            label: HandReadCopy.yourSelection,
            enableHaptics: ref.watch(hapticsEnabledProvider),
            reducedMotion: ref.watch(reducedMotionProvider),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HandReadCopy.selection(read),
                  style: AllInText.mono(13, color: c.text),
                ),
                const SizedBox(height: AllInSpace.sm),
                Text(
                  HandReadCopy.typeHint,
                  style: AllInText.body(13, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
