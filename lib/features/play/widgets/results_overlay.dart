/// P8 · The hand-over results overlay (DESIGN.md §4.12), built on `ResultsCard`
/// (§10.3), plus `revealNote` ported verbatim from
/// `docs/port/play-loop-and-coach.md` §18.
///
/// What lives here:
///
/// * [HandOverContext] — everything the overlay needs, handed over by
///   `TableScreen` so the seam never reaches into the session notifier.
/// * [tableOverlayBuilderProvider] — the seam itself. Its default,
///   [defaultHandOverOverlay], is this file's [ResultsOverlay].
/// * [revealNote] / [foldPhrase] — port §18, verbatim.
///
/// "Your read 64 % ›" comes from P7's own `guessProvider.scoresBySeat`, scoped
/// here to the hand on the felt: `GuessState` only drops the map when P7 is
/// *opened* on a later hand, so a read from hand #12 would otherwise still
/// label hand #13's row (§4.12).
///
/// The card's band is fixed (y 372–560 at 390): it never grows up into the
/// board and never grows down into the hero cards. The coach row's 44 pt comes
/// out of the scrolling reveal list, and the 9-max overflow goes to P9
/// ([AllRevealsSheet]) rather than making the card taller.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/data/preflop_charts.g.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/guess_provider.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/all_reveals_sheet.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Everything the overlay needs, so the seam does not have to reach into the
/// session notifier itself.
@immutable
class HandOverContext {
  const HandOverContext({
    required this.table,
    required this.summary,
    required this.realisticReveal,
    required this.fourColorDeck,
    required this.reducedMotion,
    required this.collapsed,
    this.coach,
    this.onCoachTap,
    this.onExpand,
    this.onRow,
    this.onReadSeat,
    this.onTouch,
    this.onMore,
  });

  final TableState table;
  final HandSummary summary;
  final bool realisticReveal;
  final bool fourColorDeck;
  final bool reducedMotion;

  /// The learn-by-reveal collapse of §4.12.
  final bool collapsed;

  /// The verdict for this hand's last hero action, if it is still unread.
  final CoachChipContent? coach;
  final VoidCallback? onCoachTap;
  final VoidCallback? onExpand;
  final ValueChanged<int>? onRow;

  /// Overrides the built-in push to P7's compare grid (§4.9).
  final ValueChanged<int>? onReadSeat;

  /// Touching the card cancels the auto-deal countdown (§4.12).
  final VoidCallback? onTouch;

  /// 9-max: "All 8 hands ›" → P9. Overrides the built-in sheet.
  final VoidCallback? onMore;
}

typedef HandOverOverlayBuilder =
    Widget Function(BuildContext context, HandOverContext data);

/// Override this to take over P8 (see the file docs).
final tableOverlayBuilderProvider = Provider<HandOverOverlayBuilder?>(
  (ref) => null,
);

/// §4.12's card: the coach row, net, caption, sentence, then one reveal row
/// per seat that was dealt in.
Widget defaultHandOverOverlay(BuildContext context, HandOverContext data) =>
    ResultsOverlay(data: data);

/* ------------------------------------------------------------------ copy */

abstract final class ResultsCopy {
  /// Port §18's two captions *(desktop)*.
  static const String wonThePot = 'You won the pot';
  static const String handOver = 'Hand over';

  /// §4.12's 9-max overflow row.
  static String allHands(int n) => 'All $n hands ›';

  /// §4.12's read link.
  static String yourRead(double score) =>
      'Your read ${(score * 100).round()} %';
}

/* -------------------------------------------------------------- the card */

/// Rows in the card before the "All N hands ›" row appears. §4.12 gives the
/// overflow to 9-max only ("three rows + All 8 hands ›"); at 6-max the five
/// rows scroll inside the card.
const int kInlineRevealCap = 5;

/// §11: the card slides up over the lower felt in 240 ms.
const Duration kResultsSlide = Duration(milliseconds: 240);

class ResultsOverlay extends ConsumerWidget {
  const ResultsOverlay({super.key, required this.data});

  final HandOverContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = data.table;
    final summary = data.summary;
    final guess = ref.watch(guessProvider);
    final reads =
        guess.handNumber == table.handNumber
            ? guess.scoresBySeat
            : const <int, double>{};

    final rows = buildRevealRows(
      table: table,
      summary: summary,
      realisticReveal: data.realisticReveal,
      readLabel:
          (seat) => switch (reads[seat]) {
            final double score => ResultsCopy.yourRead(score),
            null => null,
          },
    );

    final overflow = rows.length > kInlineRevealCap;

    final card = ResultsCard(
      summary: resultsSummary(table, summary),
      rows: rows,
      coach: data.coach,
      onCoachTap: data.onCoachTap,
      collapsed: data.collapsed,
      onExpand: data.onExpand,
      onRow: data.onRow,
      onReadSeat: (seat) => _readSeat(context, ref, seat),
      onTouch: data.onTouch,
      moreLabel: overflow ? ResultsCopy.allHands(rows.length) : null,
      onMore: overflow ? () => _openAll(context, ref, rows) : null,
      fourColorDeck: data.fourColorDeck,
      reducedMotion: data.reducedMotion,
    );

    // Collapsed the card is a 44 pt strip, so it must not be stretched to the
    // whole band; expanded it fills the band and the reveal list scrolls.
    final sized =
        data.collapsed
            ? Align(alignment: Alignment.topCenter, child: card)
            : card;

    return _SlideUp(
      key: ValueKey('results-${table.handNumber}'),
      reducedMotion: data.reducedMotion,
      child: sized,
    );
  }

  /// §4.12: the read link opens the §4.9 compare grid for that seat. The push
  /// is wrapped in `setSurfaceOpen` exactly like the table's own eye glyph, so
  /// the auto loop stays parked for the whole modal.
  void _readSeat(BuildContext context, WidgetRef ref, int seat) {
    data.onTouch?.call();
    final onReadSeat = data.onReadSeat;
    if (onReadSeat != null) {
      onReadSeat(seat);
      return;
    }
    final notifier = ref.read(sessionProvider.notifier);
    notifier.setSurfaceOpen(true);
    context.push(AllInRoutes.readRangePath(seat)).whenComplete(() {
      notifier.setSurfaceOpen(false);
    });
  }

  /// §4.12: "All 8 hands ›" → P9.
  Future<void> _openAll(
    BuildContext context,
    WidgetRef ref,
    List<RevealRow> rows,
  ) async {
    data.onTouch?.call();
    final onMore = data.onMore;
    if (onMore != null) {
      onMore();
      return;
    }
    final notifier = ref.read(sessionProvider.notifier);
    notifier.setSurfaceOpen(true);
    final seat = await AllRevealsSheet.show(
      context,
      rows: rows,
      fourColorDeck: data.fourColorDeck,
      reducedMotion: data.reducedMotion,
    );
    notifier.setSurfaceOpen(false);
    if (seat != null) data.onRow?.call(seat);
  }
}

/// Port §18's header: the hero's net, the caption and the result sentence.
ResultsSummary resultsSummary(TableState table, HandSummary summary) {
  final bb = table.bigBlind;
  final netBb = bb == 0 ? 0.0 : summary.heroNetChips / bb;
  final won = summary.potResults.any((p) => p.winners.contains(0));

  final mainWinners =
      summary.potResults.isEmpty
          ? const <int>[]
          : summary.potResults.first.winners;
  final winnerNames = [
    for (final id in mainWinners)
      if (id >= 0 && id < table.players.length) table.players[id].name,
  ].join(', ');

  EvaluatedHand? winnerHand;
  for (final entry in summary.showdown) {
    if (mainWinners.contains(entry.playerId) && entry.hand != null) {
      winnerHand = entry.hand;
      break;
    }
  }

  return ResultsSummary(
    netBb: netBb,
    caption: won ? ResultsCopy.wonThePot : ResultsCopy.handOver,
    sentence:
        winnerNames.isEmpty
            ? ''
            : winnerHand != null
            ? '$winnerNames wins with ${winnerHand.name.toLowerCase()}.'
            : '$winnerNames takes it down.',
  );
}

/// One row per seat that was dealt in, in seat order.
///
/// "Realistic reveals" does not drop a folded seat from the list (the desktop
/// grid did): §4.12 keeps the row and shows face-down cards with the bare
/// "Folded on the turn." note, so the list never changes length mid-session.
List<RevealRow> buildRevealRows({
  required TableState table,
  required HandSummary summary,
  required bool realisticReveal,
  String? Function(int seat)? readLabel,
}) {
  final rows = <RevealRow>[];
  for (final p in table.players) {
    if (p.isHero) continue;
    final hole = p.hole;
    if (hole == null && !p.hasFolded) continue;

    final faceDown = hole == null || (realisticReveal && p.hasFolded);
    rows.add(
      RevealRow(
        playerId: p.id,
        name: p.name,
        cards: faceDown ? const ['', ''] : List<String>.of(hole),
        note:
            faceDown
                ? 'Folded ${foldPhrase(p.foldedStreet ?? Street.preflop)}.'
                : revealNote(p, summary.board, summary),
        faceDown: faceDown,
        folded: p.hasFolded,
        readLabel: readLabel?.call(p.id),
      ),
    );
  }
  return rows;
}

/// Port §18's `FOLD_PHRASE`, verbatim.
String foldPhrase(Street street) => switch (street) {
  Street.preflop => 'before the flop',
  Street.flop => 'on the flop',
  Street.turn => 'on the turn',
  Street.river => 'on the river',
  Street.showdown => 'at showdown',
};

/// Port §18's `revealNote`, verbatim (templates and branch order included).
String revealNote(Player p, List<Card> board, HandSummary summary) {
  final winners = <int>{for (final pot in summary.potResults) ...pot.winners};

  if (!p.hasFolded) {
    ShowdownEntry? sd;
    for (final entry in summary.showdown) {
      if (entry.playerId == p.id) {
        sd = entry;
        break;
      }
    }
    if (winners.contains(p.id)) {
      return sd?.hand != null
          ? 'Won with ${sd!.hand!.name.toLowerCase()}.'
          : 'Won — everyone else folded.';
    }
    return sd?.hand != null
        ? 'Showed ${sd!.hand!.name.toLowerCase()}.'
        : 'Reached the end without showing.';
  }

  final street = p.foldedStreet ?? Street.preflop;
  final base = 'Folded ${foldPhrase(street)}';

  if (street == Street.preflop) {
    final hole = p.hole;
    if (hole == null || hole.length < 2) return '$base.';
    final label = cardsToLabel(hole[0], hole[1]);
    final chart =
        p.position == Position.bb
            ? <String, double>{
              ...?kVsRfi100['BB_vs_BTN']?['call'],
              ...?kVsRfi100['BB_vs_BTN']?['threebet'],
            }
            : (kRfi100[p.position.label] ?? const <String, double>{});
    final inRange = (chart[label] ?? 0) > 0;
    return inRange
        ? '$base — playable, but gave it up.'
        : '$base — too weak to play from ${p.position.label}.';
  }

  final hole = p.hole;
  if (hole != null && board.length >= 3) {
    final made = evaluateCards([...hole, ...board]);
    return '$base — the full board would have given them '
        '${made.name.toLowerCase()}.';
  }
  return '$base.';
}

/* -------------------------------------------------------------- motion */

/// §11: "Results card · slide up over the lower felt · 240 ms". Zeroed under
/// reduced motion (and under the OS flag, via `AllInMotion.of`).
class _SlideUp extends StatefulWidget {
  const _SlideUp({super.key, required this.child, required this.reducedMotion});

  final Widget child;
  final bool reducedMotion;

  @override
  State<_SlideUp> createState() => _SlideUpState();
}

class _SlideUpState extends State<_SlideUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kResultsSlide,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AllInMotion.of(
      context,
      kResultsSlide,
      reduced: widget.reducedMotion,
    );
    if (duration == Duration.zero) return widget.child;

    final curved = CurvedAnimation(
      parent: _controller,
      curve: AllInMotion.easeOut,
    );
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: FractionalTranslation(
            translation: Offset(0, (1 - t) * 0.25),
            child: child,
          ),
        );
      },
    );
  }
}
