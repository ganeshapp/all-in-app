/// The P11 felt (DESIGN.md §7.7) — the shared table renderer
/// (`lib/widgets/table/`, §16.3) driven by a [ReplayModel] instead of a live
/// `TableState`.
///
/// It is **parametric**, not one of §4.2's three hand-tuned tables: the
/// importer accepts any hand with two or more seats, so 3-, 5-, 7- and
/// 8-handed hands are ordinary here. Seats sit on the polar anchors of
/// [replaySeatPos]; the pot and the board keep the 6-max anchors at every seat
/// count, because the replayer has no bet pills, coach chip or action row to
/// collide with.
///
/// Chips are shown in hundredths of a big blind (`bigBlind: 100`), so a
/// real-money import with a $0.05 blind still reads "100 bb" rather than
/// dividing by a rounded-to-zero unit.
library;

import 'package:flutter/material.dart' hide Card;

import '../../../engine/engine.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/replay_model.dart';

/// Chips per big blind in the plate's display unit.
const int _unit = 100;

/// Placeholder for a seat whose cards are unknown — never rendered face-up.
const List<Card> _hidden = ['Ah', 'Ah'];

class ReplayFelt extends StatelessWidget {
  const ReplayFelt({
    super.key,
    required this.model,
    required this.frameIndex,
    this.height = 360,
    this.fourColorDeck = false,
    this.reducedMotion = false,
    this.onNext,
    this.onPrevious,
  });

  final ReplayModel model;
  final int frameIndex;
  final double height;
  final bool fourColorDeck;
  final bool reducedMotion;

  /// Swipe left / right on the felt (§7.7, the drill navigator's gesture).
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  SeatPlateVariant get _variant {
    final n = model.seats.length;
    if (n <= 4) return SeatPlateVariant.hu;
    if (n <= 6) return SeatPlateVariant.standard;
    return SeatPlateVariant.compact;
  }

  @override
  Widget build(BuildContext context) {
    final hand = model.hand;
    final frame = model.frameAt(frameIndex);
    final captions = model.captionsAt(frameIndex);
    final bb = hand.bb == 0 ? 1 : hand.bb;
    final variant = _variant;
    final n = model.seats.length;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -120) {
          onNext?.call();
        } else if (v > 120) {
          onPrevious?.call();
        }
      },
      child: SizedBox(
        height: height,
        child: FeltCanvas(
          layout: FeltLayout.fromSeats(n),
          semanticSummary: frame.text,
          builder: (context, felt) {
            return [
              felt.place(
                felt.potAnchor,
                child: PotPill(
                  street: frame.street,
                  pot: frame.pot / bb * _unit,
                  bigBlind: _unit,
                ),
              ),
              felt.place(
                felt.boardAnchor,
                child: BoardRow(
                  cards: frame.board,
                  size: n >= 7 ? 32 : 38,
                  gap: n >= 7 ? 3 : 6,
                  fourColorDeck: fourColorDeck,
                  reducedMotion: reducedMotion,
                ),
              ),
              for (final seat in model.seats)
                felt.place(
                  felt.anchor(seat.anchor.dx, seat.anchor.dy),
                  child: _Seat(
                    seat: seat,
                    variant: variant,
                    seats: n,
                    folded: frame.folded.contains(seat.seat),
                    hole: hand.holes[seat.seat],
                    revealAll: frame.revealAll,
                    caption: captions[seat.seat],
                    stackUnits: (seat.stack / bb * _unit).round(),
                    nameLimit: n >= 10 ? 4 : null,
                    fourColorDeck: fourColorDeck,
                    reducedMotion: reducedMotion,
                  ),
                ),
            ];
          },
        ),
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.seat,
    required this.variant,
    required this.seats,
    required this.folded,
    required this.hole,
    required this.revealAll,
    required this.caption,
    required this.stackUnits,
    required this.nameLimit,
    required this.fourColorDeck,
    required this.reducedMotion,
  });

  final ReplaySeat seat;
  final SeatPlateVariant variant;
  final int seats;
  final bool folded;
  final List<Card>? hole;
  final bool revealAll;
  final String? caption;
  final int stackUnits;
  final int? nameLimit;
  final bool fourColorDeck;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // §7.7: hole cards show when they are known *and* it is the hero or the
    // final reveal-all frame; a folded seat shows none at all.
    final known = hole != null && hole!.length >= 2;
    final showHole = known && (seat.isHero || revealAll);
    final player = Player(
      id: seat.seat,
      name: seat.name,
      isHero: seat.isHero,
      stack: stackUnits,
      hole: folded ? null : (showHole ? hole : _hidden),
      position: seat.position,
      hasFolded: folded,
    );

    final plate = SeatPlate(
      player: player,
      variant: variant,
      state: folded ? SeatPlateState.folded : SeatPlateState.idle,
      bigBlind: _unit,
      seats: seats,
      showHole: showHole,
      nameLimit: nameLimit,
      fourColorDeck: fourColorDeck,
      reducedMotion: reducedMotion,
    );

    final size = SeatPlate.defaultPlateSize(variant);

    return Opacity(
      opacity: folded ? 0.25 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          plate,
          SizedBox(
            width: size.width,
            height: 14,
            child:
                caption == null
                    ? null
                    : Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AllInText.mono(10, color: c.goldLight),
                    ),
          ),
        ],
      ),
    );
  }
}
