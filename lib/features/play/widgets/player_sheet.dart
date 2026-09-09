/// P6 · Player sheet (DESIGN.md §4.3) — sheet **M** at every width, because
/// its content measures ≈ 380 pt and the S detent is capped at 40 % of the
/// viewport.
///
/// Header line, the archetype blurb, the VPIP/PFR tiles (or the "reads are
/// earned" paragraph under 8 observed hands), and the two 48 pt actions:
/// "Read their range" → P7 and "Explain their last move" → P3. A disabled
/// action reads at 40 % with the reason in a caption — never a dead button.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// What P6 returns to the table.
enum PlayerSheetResult { readRange, explain }

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({
    super.key,
    required this.player,
    required this.seats,
    required this.bigBlind,
    required this.canRead,
    required this.canExplain,
    this.handOver = false,
  });

  final Player player;
  final int seats;
  final int bigBlind;

  /// The seat is still in the hand and the table is in a betting phase.
  final bool canRead;

  /// This seat was the last actor and it is a bot (§4.10).
  final bool canExplain;

  /// Hand-over disables "Read their range" with the §4.3 caption.
  final bool handOver;

  /// Opens P6 and returns the action the user chose, if any.
  static Future<PlayerSheetResult?> show(
    BuildContext context, {
    required Player player,
    required int seats,
    required int bigBlind,
    required bool canRead,
    required bool canExplain,
    bool handOver = false,
    bool reducedMotion = false,
    VoidCallback? onClose,
  }) => AllInSheet.show<PlayerSheetResult>(
    context,
    detent: AllInSheetDetent.m,
    reducedMotion: reducedMotion,
    maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
    onClose: onClose,
    child: PlayerSheet(
      player: player,
      seats: seats,
      bigBlind: bigBlind,
      canRead: canRead,
      canExplain: canExplain,
      handOver: handOver,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final config =
        player.archetype == null ? null : kArchetypes[player.archetype];
    final seen = player.handsSeen;
    final enough = seen >= SeatPlate.minSample;
    final ring = archetypeColor(player.archetype);

    final head = <String>[
      player.name,
      positionLabel(player.position, seats),
      if (config != null) '${config.name} (${player.archetype!.label})',
    ].join(' · ');

    // `AllInSheet` already wraps its child in a scroll view (§10.1), so this
    // is a plain Column — a nested ListView would have unbounded height.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        AllInSpace.sm,
        AllInSpace.lg,
        AllInSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: Text(
                  head,
                  style: AllInText.body(
                    17,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          if (seats == 9) ...[
            const SizedBox(height: AllInSpace.xs),
            Text(
              PlayCopy.nineMaxApproximate,
              style: AllInText.body(12, color: c.textFaint),
            ),
          ],
          if (config != null) ...[
            const SizedBox(height: AllInSpace.sm),
            Text(config.blurb, style: AllInText.body(14, color: c.textMuted)),
          ],
          const SizedBox(height: AllInSpace.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'VPIP',
                  value:
                      enough
                          ? '${(player.vpipCount / seen * 100).round()} %'
                          : '–',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: 'PFR',
                  value:
                      enough
                          ? '${(player.pfrCount / seen * 100).round()} %'
                          : '–',
                  sub: '$seen hand${seen == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          Text(
            enough
                ? PlayCopy.hudExplained(seen)
                : PlayCopy.readsAreEarned(seen),
            style: AllInText.body(13, color: c.textMuted),
          ),
          const SizedBox(height: AllInSpace.lg),
          AllInButton.primary(
            label: PlayCopy.readTheirRange,
            leading: Icons.visibility_outlined,
            expand: true,
            onPressed:
                canRead
                    ? () =>
                        Navigator.of(context).pop(PlayerSheetResult.readRange)
                    : null,
          ),
          if (!canRead) ...[
            const SizedBox(height: AllInSpace.xs),
            Text(
              handOver
                  ? PlayCopy.handOverReadsReopen
                  : PlayCopy.readsUnavailable,
              style: AllInText.body(12, color: c.textFaint),
            ),
          ],
          if (canExplain) ...[
            const SizedBox(height: AllInSpace.sm),
            AllInButton.secondary(
              label: PlayCopy.explainTheirLastMove,
              leading: Icons.adjust_rounded,
              expand: true,
              onPressed:
                  () => Navigator.of(context).pop(PlayerSheetResult.explain),
            ),
          ],
        ],
      ),
    );
  }
}
