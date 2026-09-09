/// The felt composition (DESIGN.md §4.2 / §4.2.1 / §4.2.2): seats, board, pot,
/// bet pills, the coach chip zone and the results-overlay band, anchored on
/// `FeltCanvas`'s fractions.
///
/// Play-only composition: every part comes from `lib/widgets/table/` (§16.3).
library;

import 'dart:math' as math;

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
          // The cleared anchor, not the raw fraction: a felt that came out a
          // fraction of a point too short must not tuck the cards under the
          // rail (§4.2's invariant).
          final anchor = geometry.seatAnchorClearingRail(
            seat: seat,
            plateHeight: metrics.plateSize.height,
            peek: metrics.cardPeek,
          );
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
        // Built first, placed second: the hero's pill is the one that carries
        // "(you)" and so outgrows its §4.2 budget (36 pt at 360) to about 104,
        // and §4.2.3's clearance table wants 7.8 pt of daylight between it and
        // the seat-1 pill 11 pt above. It has to know how wide its neighbours
        // came out before it can find a row of its own.
        final pills = <int, ({BetPill widget, Offset anchor})>{};
        for (final player in table.players) {
          final pill = _pillFor(player);
          if (pill == null) continue;
          pills[player.id] = (
            widget: BetPill(
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
            anchor: geometry.betAnchor(player.id),
          );
        }
        final heroPillY = _heroBetPillY(pills);
        for (final entry in pills.entries) {
          final anchor =
              entry.key == 0
                  ? Offset(entry.value.anchor.dx, heroPillY)
                  : entry.value.anchor;
          children.add(geometry.place(anchor, child: entry.value.widget));
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

  /// Clearance the hero's pill keeps from a pill it would otherwise sit on.
  static const double heroPillClearance = 4;

  /// The y the hero's bet pill is drawn at: its §4.2 anchor, or far enough
  /// below a neighbour's pill to clear it.
  ///
  /// §4.2's clearance table budgets 7.8 pt between "hero pill right" and
  /// "seat-1 pill left" at 360 — but that assumes the hero's pill honours its
  /// 36 pt nominal width, and it does not: "● 0.5 bb (you)" needs ~104 pt at
  /// the 11 pt legibility floor, so at 360 the three pills on that row ran
  /// into each other, and at 1.3× text they overlapped outright. Where the
  /// row is wide enough the anchor is untouched; where it is not, the hero
  /// takes a row of its own, which is the one direction with space (the coach
  /// chip zone is 0.79).
  static double _heroBetPillY(
    Map<int, ({BetPill widget, Offset anchor})> pills,
  ) {
    final hero = pills[0];
    if (hero == null) return 0;
    var y = hero.anchor.dy;
    final heroHalf = hero.widget.layoutWidth / 2;
    for (final entry in pills.entries) {
      if (entry.key == 0) continue;
      final other = entry.value;
      // Rows that already clear each other vertically are fine.
      if ((other.anchor.dy - hero.anchor.dy).abs() >= BetPill.height) continue;
      final otherHalf = other.widget.layoutWidth / 2;
      final gap = (other.anchor.dx - hero.anchor.dx).abs();
      if (gap >= heroHalf + otherHalf + heroPillClearance) continue;
      y = math.max(y, other.anchor.dy + BetPill.height + heroPillClearance);
    }
    return y;
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
