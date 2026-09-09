/// The P11 replayer's view model (DESIGN.md §7.7).
///
/// `buildReplayFrames` is the engine's, verbatim (`play-loop-and-coach.md`
/// §21) — this file adds only what the *screen* needs and the engine cannot
/// know:
///
/// * **frame → action** ([ReplayModel.actionIndex]). The frame list is
///   blinds · (board · actions)* · result; the same walk over `hand.actions`
///   reproduces which frame is which action without re-deriving a single
///   number. That mapping is what lets a plate carry "raises to 3 bb" and what
///   matches a stored coach note to the frame it belongs to.
/// * **seat order and geometry** for a table of any size: the importer accepts
///   `seats.length >= 2`, so 3-, 5-, 7- and 8-handed hands are ordinary and
///   the felt is polar rather than one of §4.2's three hand-tuned tables.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import '../../../engine/engine.dart';
import '../../../services/persistence.dart' show CoachNoteRecord;

/// The largest table the felt draws; above it §7.7's refusal state applies.
const int kMaxReplaySeats = 10;

/// Desktop `seatPos(n, i)` (§7.7): hero (i = 0) at the bottom, increasing i
/// counter-clockwise on screen, one formula for any n >= 2.
Offset replaySeatPos(int n, int i) {
  final theta = math.pi / 2 + 2 * math.pi * i / n;
  return Offset(0.5 + 0.39 * math.cos(theta), 0.5 + 0.40 * math.sin(theta));
}

/// One seat as the replayer draws it.
class ReplaySeat {
  const ReplaySeat({
    required this.seat,
    required this.name,
    required this.position,
    required this.stack,
    required this.isHero,
    required this.anchor,
  });

  final int seat;
  final String name;
  final Position position;

  /// Stack at hand start, in the file's own units (§7.7).
  final num stack;
  final bool isHero;

  /// Fractional felt anchor from [replaySeatPos].
  final Offset anchor;
}

class ReplayModel {
  ReplayModel._({
    required this.hand,
    required this.frames,
    required this.actionIndex,
    required this.seats,
    required this.coachNotes,
  });

  factory ReplayModel.of(
    HHHand hand, {
    List<CoachNoteRecord> coachNotes = const [],
  }) {
    final frames = buildReplayFrames(hand);
    final heroes = hand.seats.where((s) => s.isHero);
    final hero =
        heroes.isNotEmpty
            ? heroes.first
            : (hand.seats.isEmpty ? null : hand.seats.first);
    final ordered = <HHSeat>[
      if (hero != null) hero,
      ...hand.seats.where((s) => s != hero),
    ];
    final n = ordered.length;
    final seats = <ReplaySeat>[
      for (var i = 0; i < n; i++)
        ReplaySeat(
          seat: ordered[i].seat,
          name: ordered[i].name,
          position: ordered[i].position,
          stack: ordered[i].stack,
          isHero: ordered[i].isHero,
          anchor: replaySeatPos(n, i),
        ),
    ];
    return ReplayModel._(
      hand: hand,
      frames: frames,
      actionIndex: _actionIndexFor(hand, frames.length),
      seats: seats,
      coachNotes: coachNotes,
    );
  }

  final HHHand hand;
  final List<ReplayFrame> frames;

  /// Same length as [frames]; the index into `hand.actions` for an action
  /// frame, null for the blinds frame, a board frame or the result frame.
  final List<int?> actionIndex;

  final List<ReplaySeat> seats;
  final List<CoachNoteRecord> coachNotes;

  int get lastIndex => frames.isEmpty ? 0 : frames.length - 1;

  /// True when the table is bigger than the felt draws (§7.7's one refusal).
  bool get tooManySeats => seats.length > kMaxReplaySeats;

  ReplayFrame frameAt(int index) =>
      frames.isEmpty
          ? const ReplayFrame(
            text: 'Hand over.',
            street: Street.preflop,
            board: [],
            pot: 0,
            folded: [],
          )
          : frames[index.clamp(0, lastIndex)];

  /// The action this frame shows, or null when it is a blinds / board /
  /// result frame.
  HHAction? actionAt(int index) {
    if (index < 0 || index >= actionIndex.length) return null;
    final i = actionIndex[index];
    if (i == null || i < 0 || i >= hand.actions.length) return null;
    return hand.actions[i];
  }

  /// Each seat's most recent action at [index], phrased as the plate's
  /// caption line ("raises to 3 bb"). §7.7: the bet amount renders on the
  /// plate, never at a separate bet spot.
  Map<int, String> captionsAt(int index) {
    final out = <int, String>{};
    final upTo = index.clamp(0, lastIndex);
    for (var f = 0; f <= upTo; f++) {
      final a = actionAt(f);
      if (a == null) continue;
      out[a.seat] = _captionFor(a);
    }
    return out;
  }

  /// The stored coach note whose street and action match this frame's action
  /// (§7.7). Null on frames that are not a hero action, and on every frame of
  /// an imported hand (it carries no notes).
  CoachNoteRecord? noteAt(int index) {
    final a = actionAt(index);
    if (a == null) return null;
    final heroes = seats.where((s) => s.isHero);
    final heroSeat =
        heroes.isNotEmpty ? heroes.first : (seats.isEmpty ? null : seats.first);
    if (heroSeat == null || a.seat != heroSeat.seat) return null;
    for (final note in coachNotes) {
      if (note.street == a.street.label && note.action == a.type.label) {
        return note;
      }
    }
    return null;
  }

  /// The frame a stored coach note belongs to — how the coaching-review rows
  /// open a hand "at that frame" (§7.1). Falls back to the last frame.
  int frameForNote({required String street, required String action}) {
    for (var f = 0; f < frames.length; f++) {
      final a = actionAt(f);
      if (a == null) continue;
      if (a.street.label == street && a.type.label == action) return f;
    }
    return lastIndex;
  }

  String _captionFor(HHAction a) {
    final allIn = a.allIn ? ' (all-in)' : '';
    return switch (a.type) {
      ActionType.fold => 'folds',
      ActionType.check => 'checks',
      ActionType.call => 'calls ${_bb(a.amount)} bb$allIn',
      ActionType.bet => 'bets ${_bb(a.amount)} bb$allIn',
      ActionType.raise => 'raises to ${_bb(a.amount)} bb$allIn',
      ActionType.post => 'posts ${_bb(a.amount)} bb',
    };
  }

  /// The engine's own in-replay big-blind formatter (`buildReplayFrames`):
  /// integers plain, everything else to one decimal.
  String _bb(num chips) {
    if (hand.bb == 0) return '$chips';
    final v = chips / hand.bb;
    final isInteger = v.isFinite && v == v.truncateToDouble();
    return isInteger ? jsIntString(v) : jsToFixed(v, 1);
  }

  /// The frame walk of `buildReplayFrames`, structurally: blinds, then per
  /// street a board frame (when that street was dealt) and one frame per
  /// action, then the result frame.
  static List<int?> _actionIndexFor(HHHand h, int frameCount) {
    final out = <int?>[null]; // blinds
    const order = [Street.preflop, Street.flop, Street.turn, Street.river];
    for (final street in order) {
      final dealt = switch (street) {
        Street.preflop => true,
        Street.flop => h.board.length >= 3,
        Street.turn => h.board.length >= 4,
        _ => h.board.length >= 5,
      };
      if (!dealt) continue;
      if (street != Street.preflop) out.add(null); // board frame
      for (var i = 0; i < h.actions.length; i++) {
        if (h.actions[i].street == street) out.add(i);
      }
    }
    out.add(null); // result
    // A defensive clamp: the mapping must be exactly as long as the frames it
    // describes, whatever a future engine change does.
    if (out.length > frameCount) return out.sublist(0, frameCount);
    while (out.length < frameCount) {
      out.add(null);
    }
    return out;
  }
}
