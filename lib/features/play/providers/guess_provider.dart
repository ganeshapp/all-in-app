/// P7 · Read range — the Guess → Peek state machine (DESIGN.md §4.9,
/// `docs/port/play-loop-and-coach.md` §12).
///
/// The desktop keeps this in `useGame` as `guess`; on mobile P7 is a route, so
/// the paint, the reveal and the score live here and the screen is a pure
/// render of them. The pause is **not** here: the table wraps the push in
/// `setSurfaceOpen`, which is what stops the auto loop (§4.9's `openGuess` /
/// `closeGuess` pause, done once for every surface).
///
/// `peek()` is the only method with side effects: it resolves the bot's
/// assumed range with the engine's `villainRangeFor`, scores the paint with
/// `scoreGuess` (combo-weighted precision / recall / F1) and — only when
/// something was painted — records one `GuessRecord`, exactly like the desktop
/// store.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../engine/engine.dart';
import '../../../services/persistence/records.dart';
import '../../stats/providers/stats_providers.dart' show statsRevisionProvider;
import 'play_providers.dart';
import 'session_provider.dart';
import 'hand_reads_provider.dart';

@immutable
class GuessState {
  const GuessState({
    this.seat,
    this.handNumber = 0,
    this.sessionId = 0,
    this.street = Street.preflop,
    this.painted = const <HandLabel>{},
    this.presetId,
    this.revealed = false,
    this.scored = false,
    this.actual = const <HandLabel>{},
    this.score,
  });

  /// The seat being read, or null when P7 is closed.
  final int? seat;

  /// The hand the read belongs to, scoped by sessionId.
  final int handNumber;
  final int sessionId;

  /// The street the read was opened on (the `GuessRecord`'s street).
  final Street street;

  /// What the user has painted so far.
  final Set<HandLabel> painted;

  /// The preset chip that produced [painted], for its gold outline.
  final String? presetId;

  final bool revealed;

  /// Something was painted, so the read was graded and recorded.
  final bool scored;

  /// The coach's assumed range, resolved at Peek.
  final Set<HandLabel> actual;

  final GuessScore? score;

  bool get open => seat != null;

  int get paintedCombos => combosInSet(painted);
  int get actualCombos => combosInSet(actual);

  /// Combos in both sets — layer 2's "34 of the 48 combos".
  int get overlapCombos {
    var n = 0;
    for (final label in painted) {
      if (actual.contains(label)) n += comboCount(label);
    }
    return n;
  }

  GuessState copyWith({
    int? seat,
    int? handNumber,
    int? sessionId,
    Street? street,
    Set<HandLabel>? painted,
    String? presetId,
    bool clearPreset = false,
    bool? revealed,
    bool? scored,
    Set<HandLabel>? actual,
    GuessScore? score,
    bool clearSeat = false,
  }) => GuessState(
    seat: clearSeat ? null : (seat ?? this.seat),
    handNumber: handNumber ?? this.handNumber,
    sessionId: sessionId ?? this.sessionId,
    street: street ?? this.street,
    painted: painted ?? this.painted,
    presetId: clearPreset ? null : (presetId ?? this.presetId),
    revealed: revealed ?? this.revealed,
    scored: scored ?? this.scored,
    actual: actual ?? this.actual,
    score: score ?? this.score,
  );
}

class GuessNotifier extends Notifier<GuessState> {
  bool _alive = true;
  @override
  GuessState build() {
    ref.onDispose(() => _alive = false);
    return const GuessState();
  }

  /// Restore the locked prediction for this street, or start a fresh read.
  /// At hand-over only existing predictions may be reviewed.
  void open(int seat) {
    final session = ref.read(sessionProvider);
    final table = session.table;
    final hand = table?.handNumber ?? 0;
    final street = table?.street ?? Street.preflop;
    final saved = ref
        .read(handReadsProvider.notifier)
        .latest(
          session.startedAt,
          hand,
          seat,
          street: session.handOver ? null : street,
        );
    state = GuessState(
      seat: seat,
      handNumber: hand,
      sessionId: session.startedAt,
      street: saved?.street ?? street,
      painted: saved?.selected ?? const {},
      actual: saved?.estimatedRange ?? const {},
      revealed: saved != null || session.handOver,
      scored: saved != null,
      score:
          saved == null
              ? null
              : scoreGuess(
                saved.selected.toList(),
                saved.estimatedRange.toList(),
              ),
    );
  }

  /// The painter's every stroke, preset and Clear.
  void setPainted(Set<HandLabel> next, {String? presetId}) {
    if (state.revealed) return;
    state = state.copyWith(
      painted: <HandLabel>{...next},
      presetId: presetId,
      clearPreset: presetId == null,
    );
  }

  void clear() => setPainted(const <HandLabel>{});

  /// Port §12.1 `peek(painted)`. Resolves the assumed range, scores the paint
  /// and records the read. Nothing painted → revealed but never scored.
  void peek() {
    final seat = state.seat;
    if (seat == null || state.revealed) return;
    final table = ref.read(sessionProvider).table;
    if (table == null ||
        seat < 1 ||
        seat >= table.players.length ||
        table.phase == GamePhase.handOver ||
        state.sessionId != ref.read(sessionProvider).startedAt ||
        state.handNumber != table.handNumber ||
        state.street != table.street) {
      state = state.copyWith(revealed: true, scored: false);
      return;
    }
    final player = table.players[seat];
    final actual = villainRangeFor(table, player);
    final painted = state.painted;
    final scored = painted.isNotEmpty;
    final score = scored ? scoreGuess(painted.toList(), actual) : null;

    if (score != null) {
      ref
          .read(handReadsProvider.notifier)
          .submit(
            HandRead(
              sessionId: state.sessionId,
              handNumber: state.handNumber,
              seat: seat,
              playerName: player.name,
              street: state.street,
              selected: painted,
              estimatedRange: actual.toSet(),
              rangeOverlap: score.accuracy,
              submittedAt: ref.read(playClockProvider).nowMs,
            ),
          );
    }

    // A neutral acknowledgement; overlap is not a correctness verdict.
    ref.read(hapticsProvider).peekReveal();

    state = state.copyWith(
      revealed: true,
      scored: scored,
      actual: actual.toSet(),
      score: score,
    );

    if (score == null || player.archetype == null) return;
    _record(score.accuracy, player.archetype, state.street);
  }

  /// P7 closed (✕, Continue, system back). The pause is released by the
  /// table's `setSurfaceOpen(false)`; this only forgets the paint.
  void close() {
    if (!state.open) return;
    state = state.copyWith(
      clearSeat: true,
      painted: const <HandLabel>{},
      clearPreset: true,
      revealed: false,
      scored: false,
      actual: const <HandLabel>{},
    );
  }

  void _record(double accuracy, Archetype? archetype, Street street) {
    final record = GuessRecord(
      accuracy: accuracy,
      archetype: archetype,
      street: street.label,
      ts: ref.read(playClockProvider).nowMs,
    );
    () async {
      await ref.read(statsRepositoryProvider).persistGuess(record);
      if (!_alive) return;
      // Read accuracy is a Progress KPI (§7.2): let T0 re-read.
      ref.read(statsRevisionProvider.notifier).bump();
    }();
  }
}

/// P7's whole state. One notifier, because only one read is open at a time.
final guessProvider = NotifierProvider<GuessNotifier, GuessState>(
  GuessNotifier.new,
);
