/// The felt composition (DESIGN.md §4.2 / §4.2.1 / §4.2.2): seats, board, pot,
/// bet pills, the coach chip zone and the results-overlay band, anchored on
/// `FeltCanvas`'s fractions.
///
/// Play-only composition: every part comes from `lib/widgets/table/` (§16.3).
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/table_layout_provider.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// The one seat callback set the table screen wires up.
typedef SeatCallback = void Function(int seat);

class TableFelt extends StatelessWidget {
  const TableFelt({
    super.key,
    required this.table,
    required this.metrics,
    required this.thinkingSeat,
    required this.stepMode,
    required this.fourColorDeck,
    required this.realisticReveal,
    required this.reducedMotion,
    required this.enableHaptics,
    required this.showEyes,
    required this.rebought,
    this.chip,
    this.onChipTap,
    this.onChipSwipeUp,
    this.onChipSwipeDown,
    this.onSeatTap,
    this.onSeatEye,
    this.onSeatLongPress,
    this.onActionPill,
    this.onFeltTap,
    this.overlay,
    this.dimmed = false,
  });

  final TableState table;
  final TableMetrics metrics;

  /// Auto pace: the seat whose think delay is running (§4.3).
  final int? thinkingSeat;

  /// Manual pace — the turn ring breathes and shows the `▶` glyph (§4.3).
  final bool stepMode;

  final bool fourColorDeck;
  final bool realisticReveal;
  final bool reducedMotion;
  final bool enableHaptics;

  /// The eye is hidden at hand-over and when the coach cannot read (§4.3).
  final bool showEyes;

  /// Bots rebuilt to 100 bb this deal.
  final Set<int> rebought;

  /// The current non-blocking verdict, or null.
  final CoachChipContent? chip;
  final VoidCallback? onChipTap;
  final VoidCallback? onChipSwipeUp;
  final VoidCallback? onChipSwipeDown;

  final SeatCallback? onSeatTap;
  final SeatCallback? onSeatEye;
  final SeatCallback? onSeatLongPress;
  final SeatCallback? onActionPill;
  final VoidCallback? onFeltTap;

  /// P8's results card, supplied by the table screen's overlay seam (§4.12).
  final Widget? overlay;

  /// §4.8: the felt dims to 60 % behind a blocking note.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final layout = FeltLayout.fromSeats(table.config.seats);
    final bb = table.bigBlind;

    Widget felt = FeltCanvas(
      layout: layout,
      onTapBackground: onFeltTap,
      semanticSummary: _summary(),
      builder: (context, geometry) {
        final children = <Widget>[];

        // ---- pot ------------------------------------------------------
        children.add(
          geometry.place(
            geometry.potAnchor,
            child: PotPill(
              street: table.street,
              pot: table.pot,
              bigBlind: bb,
              maxWidth: metrics.potPillMax,
            ),
          ),
        );

        // ---- board ----------------------------------------------------
        children.add(
          geometry.place(
            geometry.boardAnchor,
            child: BoardRow(
              cards: table.board,
              size: metrics.boardCardWidth,
              gap: metrics.boardGap,
              fourColorDeck: fourColorDeck,
              reducedMotion: reducedMotion,
            ),
          ),
        );

        // ---- seats ----------------------------------------------------
        for (final seat in geometry.plateSeats) {
          if (seat >= table.players.length) continue;
          final player = table.players[seat];
          final anchor = geometry.seatAnchor(seat);
          final mirrored = anchor.dx < geometry.size.width / 2;
          assert(
            geometry.debugCardsClearRail(
              seat: seat,
              plateHeight: metrics.plateSize.height,
              peek: metrics.cardPeek,
            ),
          );
          children.add(
            geometry.place(
              anchor,
              child: SeatPlate(
                player: player,
                variant: metrics.plateVariant,
                plateSize: metrics.plateSize,
                holeCardWidth: metrics.holeCardWidth,
                cardPeek: metrics.cardPeek,
                nameLimit: metrics.nameLimit,
                state: _seatState(player),
                bigBlind: bb,
                seats: table.config.seats,
                showEye: showEyes && table.phase == GamePhase.betting,
                isButton: table.button == seat,
                showHole: _showHole(player),
                thinking: thinkingSeat == seat,
                rebought: rebought.contains(seat),
                turnMode: stepMode ? TurnRingMode.breathing : TurnRingMode.arc,
                mirrored: mirrored,
                fourColorDeck: fourColorDeck,
                realisticReveal: realisticReveal,
                enableHaptics: enableHaptics,
                reducedMotion: reducedMotion,
                onTap: onSeatTap == null ? null : () => onSeatTap!(seat),
                onEye: onSeatEye == null ? null : () => onSeatEye!(seat),
                onLongPress:
                    onSeatLongPress == null
                        ? null
                        : () => onSeatLongPress!(seat),
              ),
            ),
          );
        }

        // ---- bet / action pills ---------------------------------------
        for (final player in table.players) {
          final pill = _pillFor(player);
          if (pill == null) continue;
          children.add(
            geometry.place(
              geometry.betAnchor(player.id),
              child: BetPill(
                kind: pill.kind,
                amount: pill.amount,
                label: pill.label,
                bigBlind: bb,
                isHero: player.isHero,
                maxWidth:
                    player.isHero ? metrics.heroBetPillMax : metrics.betPillMax,
                reducedMotion: reducedMotion,
                semanticLabel: '${player.name} ${pill.label ?? ''}'.trim(),
                onTap:
                    onActionPill == null || player.isHero
                        ? null
                        : () => onActionPill!(player.id),
              ),
            ),
          );
        }

        // ---- coach chip zone ------------------------------------------
        final content = chip;
        if (content != null && overlay == null) {
          children.add(
            geometry.place(
              geometry.chipAnchor,
              child: CoachChip(
                key: ValueKey('chip-${content.title}-${content.clause}'),
                verdict: content.verdict,
                title: content.title,
                clause: content.clause,
                width: metrics.coachChipWidth,
                enableHaptics: enableHaptics,
                reducedMotion: reducedMotion,
                onTap: onChipTap,
                onSwipeUp: onChipSwipeUp,
                onSwipeDown: onChipSwipeDown,
              ),
            ),
          );
        }

        // ---- P8 results band (§4.12: y 372–560 of a 390 felt) ---------
        if (overlay != null) {
          children.add(
            Positioned(
              left: 0,
              right: 0,
              top: geometry.size.height * 0.525,
              bottom: geometry.size.height * 0.085,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
                child: overlay!,
              ),
            ),
          );
        }

        return children;
      },
    );

    if (dimmed) {
      felt = Opacity(opacity: 0.60, child: IgnorePointer(child: felt));
    }
    return felt;
  }

  SeatPlateState _seatState(Player p) {
    final summary = table.summary;
    if (summary != null &&
        summary.potResults.any((r) => r.winners.contains(p.id))) {
      return SeatPlateState.winner;
    }
    if (p.hasFolded) return SeatPlateState.folded;
    if (p.isAllIn) return SeatPlateState.allIn;
    if (table.phase == GamePhase.betting && table.toAct == p.id) {
      return SeatPlateState.toAct;
    }
    return SeatPlateState.idle;
  }

  /// Port §18: `isHero || (revealed && !(realisticReveal && hasFolded))`.
  bool _showHole(Player p) =>
      p.isHero || (p.revealed && !(realisticReveal && p.hasFolded));

  _Pill? _pillFor(Player p) {
    if (p.committed > 0) {
      final label = p.lastAction?.label;
      return _Pill(
        kind:
            label == null
                ? BetPillKind.blind
                : BetPill.kindFromActionLabel(label),
        amount: p.committed,
      );
    }
    final label = p.lastAction?.label;
    if (label == null) return null;
    if (label != 'Fold' && label != 'Check') return null;
    return _Pill(kind: BetPill.kindFromActionLabel(label), label: label);
  }

  /// §13's live table summary.
  String _summary() {
    final parts = <String>[
      PotPill.streetLabel(table.street),
      'pot ${fmtBb(table.pot, table.bigBlind)} big blinds',
    ];
    final toAct = table.toAct;
    if (table.phase == GamePhase.betting && toAct != null) {
      parts.add(
        toAct == 0 ? 'your turn' : '${table.players[toAct].name} to act',
      );
    }
    if (table.board.isNotEmpty) parts.add('board ${table.board.join(' ')}');
    return parts.join(', ');
  }
}

class _Pill {
  const _Pill({required this.kind, this.amount, this.label});

  final BetPillKind kind;
  final int? amount;
  final String? label;
}

/// State G (§4.5, §4.15): seat silhouettes plus the "Ready to play?" card.
class EmptyFelt extends StatelessWidget {
  const EmptyFelt({
    super.key,
    required this.seats,
    required this.metrics,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onAction,
  });

  final int seats;
  final TableMetrics metrics;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FeltCanvas(
      layout: FeltLayout.fromSeats(seats),
      builder:
          (context, geometry) => [
            for (final seat in geometry.plateSeats)
              geometry.place(
                geometry.seatAnchor(seat),
                child: Container(
                  width: metrics.plateSize.width,
                  height: metrics.plateSize.height,
                  decoration: BoxDecoration(
                    color: AllInColors.dark.ink900.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AllInRadius.md),
                    border: Border.all(
                      color: AllInColors.dark.line.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                ),
              ),
            geometry.place(
              geometry.boardAnchor,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: geometry.size.width * 0.82,
                ),
                child: AllInCard.glass(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AllInText.display(20, color: c.text),
                      ),
                      const SizedBox(height: AllInSpace.sm),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AllInText.body(13, color: c.textMuted),
                      ),
                      const SizedBox(height: AllInSpace.md),
                      AllInButton.primary(
                        label: actionLabel,
                        expand: true,
                        onPressed: onAction,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
    );
  }
}
