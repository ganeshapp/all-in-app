/// `DrillTable` — the fixed 6-anchor felt a drill spot is shown on
/// (DESIGN.md §5.1, §10.6; desktop `components/drills/DrillTable.tsx`).
///
/// Anchors are the desktop's, as fractions of the table box: hero
/// (0.50, 0.85), then clockwise from the lower right (0.89, 0.60) ·
/// (0.89, 0.18) · (0.50, 0.07) · (0.11, 0.18) · (0.11, 0.60), filled with the
/// non-hero seats in `ORDER`. The board sits at (0.50, 0.47) and the street
/// caption + pot pill just above it, which is what fixes the feedback panel's
/// compact top (§5.1: hero-cards bottom + 8).
///
/// Plates are **not** tappable (there is no archetype to inspect) — the whole
/// felt is one horizontal-drag target instead: swipe left / right scrubs the
/// replay one frame per 40 pt (§5.2, §12).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/format.dart';
import '../../engine/puzzles.dart';
import '../../engine/types.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../table/board_row.dart';
import '../table/felt_canvas.dart';
import '../table/playing_card_view.dart';
import '../table/pot_pill.dart';

/// The five non-hero anchors, clockwise from the lower right (§5.1).
const List<Offset> kDrillSeatAnchors = [
  Offset(0.89, 0.60),
  Offset(0.89, 0.18),
  Offset(0.50, 0.07),
  Offset(0.11, 0.18),
  Offset(0.11, 0.60),
];

/// The hero's anchor.
const Offset kDrillHeroAnchor = Offset(0.50, 0.85);

/// The board's anchor.
const Offset kDrillBoardAnchor = Offset(0.50, 0.47);

/// Card and plate sizes for a given table-box height (§5.1: 44×62 / 48×67 at
/// 390×844, 40×56 at 360×780).
@immutable
class DrillTableMetrics {
  const DrillTableMetrics({
    required this.heroCardWidth,
    required this.boardCardWidth,
    required this.plateWidth,
    required this.plateHeight,
  });

  final double heroCardWidth;
  final double boardCardWidth;
  final double plateWidth;
  final double plateHeight;

  /// The compact detent's ceiling: the bottom of the hero's cards (§5.1).
  double heroCardsBottom(double tableTop, double tableHeight) =>
      tableTop +
      tableHeight * kDrillHeroAnchor.dy +
      PlayingCardView.heightFor(heroCardWidth) / 2;

  static DrillTableMetrics forHeight(double height) =>
      height >= 285
          ? const DrillTableMetrics(
            heroCardWidth: 48,
            boardCardWidth: 44,
            plateWidth: 72,
            plateHeight: 36,
          )
          : const DrillTableMetrics(
            heroCardWidth: 40,
            boardCardWidth: 40,
            plateWidth: 66,
            plateHeight: 34,
          );
}

class DrillTable extends StatefulWidget {
  const DrillTable({
    super.key,
    required this.seats,
    required this.hole,
    required this.frame,
    this.bb = 1,
    this.captions = const <Position, String>{},
    this.heroCaption,
    this.highlightSeat,
    this.highlightColor,
    this.highlightHud,
    this.fourColorDeck = false,
    this.dimmed = false,
    this.enableHaptics = true,
    this.onPreviousFrame,
    this.onNextFrame,
    this.onTouchChanged,
    this.semanticLabel,
  });

  /// Six seats in `ORDER` (the puzzle's own list).
  final List<DrillSeatView> seats;

  /// The hero's two cards, face up.
  final List<String> hole;

  /// The frame being replayed — board, pot and street all come from it.
  final DrillFrame frame;

  /// Big blind the frame's pot is denominated in (1 for generated puzzles).
  final double bb;

  /// Overrides a seat's caption — the push/fold "45 bb" live stacks (§5.6).
  final Map<Position, String> captions;

  /// Overrides the hero's caption ("You ◆ 12 bb" in push/fold).
  final String? heroCaption;

  /// Exploit spots ring the named seat and show its HUD numbers (§5.7).
  final Position? highlightSeat;
  final Color? highlightColor;

  /// e.g. "46/7".
  final String? highlightHud;

  final bool fourColorDeck;

  /// The feedback panel dims the felt 20 % behind it (§5.3).
  final bool dimmed;
  final bool enableHaptics;

  /// Swipe right / left (40 pt per frame, §5.2).
  final VoidCallback? onPreviousFrame;
  final VoidCallback? onNextFrame;

  /// True while a finger is on the felt — the panel drops to compact (§5.2).
  final ValueChanged<bool>? onTouchChanged;

  final String? semanticLabel;

  /// One frame per 40 pt of horizontal travel (§5.2).
  static const double swipeThreshold = 40;

  @override
  State<DrillTable> createState() => _DrillTableState();
}

class _DrillTableState extends State<DrillTable> {
  double _dragX = 0;

  void _touch(bool down) => widget.onTouchChanged?.call(down);

  void _scrub(double delta) {
    _dragX += delta;
    while (_dragX.abs() >= DrillTable.swipeThreshold) {
      final forward = _dragX < 0; // drag left → next frame
      _dragX +=
          forward ? DrillTable.swipeThreshold : -DrillTable.swipeThreshold;
      final action = forward ? widget.onNextFrame : widget.onPreviousFrame;
      if (action == null) {
        _dragX = 0;
        return;
      }
      action();
      if (widget.enableHaptics) HapticFeedback.selectionClick();
    }
  }

  String _caption(DrillSeatView seat) {
    final override = widget.captions[seat.pos];
    if (override != null) return override;
    return seat.folded ? 'Folded' : 'In hand';
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.seats.firstWhere(
      (s) => s.isHero,
      orElse: () => widget.seats.first,
    );
    final others = widget.seats.where((s) => !s.isHero).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final m = DrillTableMetrics.forHeight(size.height);

        return Semantics(
          container: true,
          label: widget.semanticLabel ?? _summary(hero),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (_) {
              _dragX = 0;
              _touch(true);
            },
            onHorizontalDragUpdate: (d) => _scrub(d.delta.dx),
            onHorizontalDragEnd: (_) {
              _dragX = 0;
              _touch(false);
            },
            onHorizontalDragCancel: () {
              _dragX = 0;
              _touch(false);
            },
            child: Opacity(
              opacity: widget.dimmed ? 0.8 : 1,
              child: FeltCanvas(
                builder:
                    (context, felt) => [
                      // Street caption + pot pill, just above the board.
                      felt.at(
                        0.50,
                        0.35,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _streetCaption(widget.frame.street),
                              style: AllInText.eyebrow(
                                AllInColors.dark.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            PotPill(
                              street: widget.frame.street,
                              pot: widget.frame.pot,
                              bigBlind: widget.bb.round().clamp(1, 1 << 30),
                            ),
                          ],
                        ),
                      ),
                      felt.at(
                        kDrillBoardAnchor.dx,
                        kDrillBoardAnchor.dy,
                        child: BoardRow(
                          cards: widget.frame.board,
                          size: m.boardCardWidth,
                          fourColorDeck: widget.fourColorDeck,
                        ),
                      ),
                      for (var i = 0; i < others.length && i < 5; i++)
                        felt.at(
                          kDrillSeatAnchors[i].dx,
                          kDrillSeatAnchors[i].dy,
                          child: _DrillPlate(
                            seat: others[i],
                            caption: _caption(others[i]),
                            metrics: m,
                            ringColor:
                                others[i].pos == widget.highlightSeat
                                    ? widget.highlightColor
                                    : null,
                            hud:
                                others[i].pos == widget.highlightSeat
                                    ? widget.highlightHud
                                    : null,
                          ),
                        ),
                      felt.at(
                        kDrillHeroAnchor.dx,
                        kDrillHeroAnchor.dy,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final card in widget.hole)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: PlayingCardView(
                                  card: card,
                                  width: m.heroCardWidth,
                                  fourColorDeck: widget.fourColorDeck,
                                ),
                              ),
                          ],
                        ),
                      ),
                      felt.place(
                        Offset(
                          size.width * kDrillHeroAnchor.dx,
                          size.height * kDrillHeroAnchor.dy +
                              PlayingCardView.heightFor(m.heroCardWidth) / 2 +
                              2,
                        ),
                        alignment: Alignment.topCenter,
                        child: Text(
                          widget.heroCaption ?? 'You · ${hero.pos.label}',
                          style: AllInText.mono(
                            11,
                            color: AllInColors.dark.gold,
                          ),
                        ),
                      ),
                    ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _summary(DrillSeatView hero) {
    final board =
        widget.frame.board.isEmpty ? 'no board' : widget.frame.board.join(' ');
    return '${_streetCaption(widget.frame.street)}, pot '
        '${fmtBb(widget.frame.pot, widget.bb)} big blinds, $board. '
        'You are in the ${hero.pos.label} with ${widget.hole.join(' ')}.';
  }
}

/// Uppercase street caption (desktop `Pot`).
String _streetCaption(Street street) => switch (street) {
  Street.preflop => 'PRE-FLOP',
  Street.flop => 'FLOP',
  Street.turn => 'TURN',
  Street.river => 'RIVER',
  Street.showdown => 'SHOWDOWN',
};

class _DrillPlate extends StatelessWidget {
  const _DrillPlate({
    required this.seat,
    required this.caption,
    required this.metrics,
    this.ringColor,
    this.hud,
  });

  final DrillSeatView seat;
  final String caption;
  final DrillTableMetrics metrics;
  final Color? ringColor;
  final String? hud;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final folded = seat.folded;
    final captionColor =
        folded ? c.textFaint : (caption == 'In hand' ? c.info : c.text);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Two tucked cards; folded seats grey out (§5.1).
        Opacity(
          opacity: folded ? 0.25 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 2; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: PlayingCardView(
                    width: 20,
                    faceDown: true,
                    greyscale: folded,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Opacity(
          opacity: folded ? 0.5 : 1,
          child: Container(
            width: metrics.plateWidth,
            constraints: BoxConstraints(minHeight: metrics.plateHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.xs,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: c.ink800,
              borderRadius: BorderRadius.circular(AllInRadius.md),
              border: Border.all(
                color: ringColor ?? c.line,
                width: ringColor == null ? 1 : 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seat.pos.label,
                  maxLines: 1,
                  style: AllInText.body(
                    12,
                    weight: FontWeight.w700,
                    color: c.text,
                    height: 1.1,
                  ),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.body(10.5, color: captionColor, height: 1.2),
                ),
                if (hud != null)
                  Text(
                    hud!,
                    maxLines: 1,
                    style: AllInText.mono(10, color: ringColor ?? c.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
