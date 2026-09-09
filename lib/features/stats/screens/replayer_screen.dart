/// P11 · Hand replayer (DESIGN.md §7.7). Pushed from five hosts — the stats
/// branch, the two session-summary copies, the table modal and the summary
/// over it — all sharing this widget (§16.1).
///
/// Opens on the **last** frame (the winner line, `revealAll`), so the first
/// thing the user sees is the finished hand and stepping backwards is the
/// normal interaction (`docs/port/persistence-stats-settings.md` §10).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Card;
import 'package:allin/features/stats/providers/data_actions.dart';
import 'package:allin/features/stats/providers/replay_model.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/features/stats/widgets/note_editor_sheet.dart';
import 'package:allin/features/stats/widgets/replay_felt.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/services/share_service.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReplayerScreen extends ConsumerStatefulWidget {
  const ReplayerScreen({
    super.key,
    required this.startedAt,
    this.street,
    this.action,
  });

  /// `hand.startedAt` — the hand record's identity (`:startedAt`).
  final int startedAt;

  /// Optional deep-link target: open on the frame carrying this street and
  /// action (how a coaching-review row lands "at that frame", §7.1).
  final String? street;
  final String? action;

  @override
  ConsumerState<ReplayerScreen> createState() => _ReplayerScreenState();
}

class _ReplayerScreenState extends ConsumerState<ReplayerScreen> {
  int? _index;
  bool _sharing = false;

  /// Set once the user steps to a sibling hand (§7.7 + the hand-to-hand step).
  ///
  /// The screen swaps the hand it is showing rather than pushing a new route:
  /// P11 is hosted by five different branches (§16.1) and each builds its own
  /// path, so re-deriving one here would be five ways to get the back stack
  /// wrong. Back still returns to wherever the user came in from.
  int? _startedAt;

  int get _hand => _startedAt ?? widget.startedAt;

  void _goToHand(int startedAt) {
    setState(() {
      _startedAt = startedAt;
      // A new hand has its own frames, and the deep link that opened this
      // route pointed at a frame of the *first* hand.
      _index = null;
    });
  }

  /// The query is read defensively: the screen is also constructed directly
  /// in tests, where there is no `GoRouterState`.
  String? _query(String key) {
    try {
      return GoRouterState.of(context).uri.queryParameters[key];
    } on Object catch (_) {
      return null;
    }
  }

  int _initialIndex(ReplayModel model) {
    // The route's deep link belongs to the hand the route was opened on; a
    // sibling hand opens on its last frame like any other (§7.7).
    if (_startedAt == null) {
      final street = widget.street ?? _query('street');
      final action = widget.action ?? _query('action');
      if (street != null && action != null) {
        return model.frameForNote(street: street, action: action);
      }
      final frame = int.tryParse(_query('frame') ?? '');
      if (frame != null) return frame.clamp(0, model.lastIndex);
    }
    return model.lastIndex;
  }

  void _go(int next, ReplayModel model) {
    final clamped = next.clamp(0, model.lastIndex);
    if (clamped == _index) return;
    setState(() => _index = clamped);
  }

  Future<void> _share(StoredHand stored) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final outcome = await ref
        .read(statsDataActionsProvider)
        .shareHand(stored.hand);
    if (!mounted) return;
    setState(() => _sharing = false);
    if (outcome == ShareOutcome.unavailable) {
      AllInToast.show(context, StatsCopy.shareFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hand = ref.watch(handProvider(_hand));

    return hand.when(
      loading: () => const _ReplayerShell(body: _Loading()),
      error: (_, _) => _ReplayerShell(body: _Missing(onAllHands: _allHands)),
      data: (stored) {
        if (stored == null) {
          return _ReplayerShell(body: _Missing(onAllHands: _allHands));
        }
        return _loaded(stored);
      },
    );
  }

  void _allHands() => context.go(AllInRoutes.allHandsPath());

  Widget _loaded(StoredHand stored) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final notes = ref.watch(notesProvider);
    final model = ReplayModel.of(stored.hand, coachNotes: stored.coachNotes);
    final index = _index ??= _initialIndex(model);
    final frame = model.frameAt(index);
    final hasNote = notes.containsKey(handNoteKey(stored.startedAt));

    return AllInScaffold(
      leading: _BackButton(onPressed: () => _pop()),
      title: StatsCopy.replayTitle(stored.hand.id),
      subtitle: stored.imported ? StatsCopy.importedBadge : null,
      actions: [
        IconButton(
          tooltip: hasNote ? StatsCopy.noteAction : StatsCopy.addNoteAction,
          icon: Icon(
            hasNote ? Icons.bookmark : Icons.bookmark_border,
            color: hasNote ? c.gold : c.textMuted,
          ),
          onPressed:
              () => showHandNoteEditor(
                context,
                ref,
                startedAt: stored.startedAt,
                handId: stored.hand.id,
              ),
        ),
        IconButton(
          tooltip: StatsCopy.replayShareText,
          icon: Icon(Icons.ios_share, color: c.textMuted),
          onPressed: _sharing ? null : () => _share(stored),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FrameText(text: frame.text, reducedMotion: settings.reducedMotion),
            const SizedBox(height: AllInSpace.sm),
            Expanded(
              child:
                  model.tooManySeats
                      ? _TooManySeats(model: model, frame: frame)
                      : LayoutBuilder(
                        builder:
                            (context, constraints) => ReplayFelt(
                              model: model,
                              frameIndex: index,
                              height: constraints.maxHeight.clamp(180.0, 360.0),
                              fourColorDeck: settings.fourColorDeck,
                              reducedMotion: settings.reducedMotion,
                              onNext: () => _go(index + 1, model),
                              onPrevious: () => _go(index - 1, model),
                            ),
                      ),
            ),
            _CoachNoteStrip(
              note: model.noteAt(index),
              onOpen: (note) => _openNote(note, stored),
            ),
            const SizedBox(height: AllInSpace.sm),
            FrameScrubber(
              index: index,
              count: model.frames.length,
              text: frame.text,
              enableHaptics: settings.haptics,
              onIndexChanged: (next) => _go(next, model),
              onPillLongPress: () => _showFrameList(model),
            ),
            SizedBox(
              height: 44,
              child: AllInSlider(
                value: index.toDouble(),
                min: 0,
                max: model.lastIndex.toDouble(),
                step: 1,
                enableHaptics: settings.haptics,
                semanticLabel: 'Replay step',
                semanticFormatter:
                    (v) => 'Frame ${v.round() + 1} of ${model.frames.length}',
                onChanged: (v) => _go(v.round(), model),
              ),
            ),
            _HandStepRow(
              neighbours: ref.watch(handNeighboursProvider(stored.startedAt)),
              onGo: _goToHand,
            ),
            const SizedBox(height: AllInSpace.sm),
          ],
        ),
      ),
    );
  }

  void _pop() {
    if (context.canPop()) {
      context.pop();
    } else {
      _allHands();
    }
  }

  /// P3, read-only: the note the coach left on this action, rebuilt from the
  /// record stored inside `hand_json` (§16.4).
  Future<void> _openNote(CoachNoteRecord note, StoredHand stored) {
    final settings = ref.read(settingsProvider);
    // `CoachNoteView` reads the street off the board it is given, so the board
    // has to be the one the *decision* saw — the stored hand's board is the
    // river, which made a pre-flop note's header read "· River" over five
    // community cards it was never computed against.
    final board = stored.hand.board;
    final Iterable<poker.Card> visible = switch (note.street) {
      'flop' => board.take(3),
      'turn' => board.take(4),
      'river' || 'showdown' => board.take(5),
      _ => const <poker.Card>[],
    };
    final review = CoachReview(
      id: 0,
      kind: ReviewKind.decision,
      blocking: false,
      verdict: Verdict.fromLabel(note.verdict),
      title: note.title,
      equity: note.equity,
      potOdds: note.potOdds,
      evChips: note.evBb,
      villainName: note.villainName,
      villainRange: note.villainRange,
      board: visible.toList(growable: false),
      plain: note.plain,
      text: note.text ?? note.plain,
      steps: note.steps,
      expert: note.expert == null ? null : <String>[note.expert!],
    );
    return AllInSheet.show<void>(
      context,
      detent: AllInSheetDetent.m,
      reducedMotion: settings.reducedMotion,
      builder:
          (sheetContext) => SingleChildScrollView(
            // `AllInSheet` draws chrome only; the body owns its padding.
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AllInSpace.lg,
                0,
                AllInSpace.lg,
                AllInSpace.xl + MediaQuery.paddingOf(sheetContext).bottom,
              ),
              child: CoachNoteView(
                review: review,
                readOnly: true,
                bigBlind: 1,
                alwaysExpandMath: settings.alwaysExpandMath,
                enableHaptics: settings.haptics,
                reducedMotion: settings.reducedMotion,
                onDismiss: () => Navigator.of(sheetContext).pop(),
                dismissLabel: CoachCopy.close,
              ),
            ),
          ),
    );
  }

  /// D2's frame list, reached by long-pressing the scrubber pill (§7.7).
  Future<void> _showFrameList(ReplayModel model) {
    final settings = ref.read(settingsProvider);
    final current = _index ?? model.lastIndex;
    return AllInSheet.show<void>(
      context,
      detent: AllInSheetDetent.m,
      reducedMotion: settings.reducedMotion,
      builder:
          (sheetContext) => _FrameList(
            model: model,
            current: current,
            onPick: (i) {
              Navigator.of(sheetContext).pop();
              _go(i, model);
            },
          ),
    );
  }
}

class _ReplayerShell extends StatelessWidget {
  const _ReplayerShell({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) => AllInScaffold(
    leading: _BackButton(
      onPressed:
          () =>
              context.canPop()
                  ? context.pop()
                  : context.go(AllInRoutes.allHandsPath()),
    ),
    title: 'Hand replay',
    body: body,
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    icon: Icon(Icons.chevron_left, color: context.colors.text),
    onPressed: onPressed,
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.colors.gold,
      ),
    ),
  );
}

/// §14: the hand was pruned, reset or never saved. Felt, scrubber and timeline
/// are not rendered.
class _Missing extends StatelessWidget {
  const _Missing({required this.onAllHands});

  final VoidCallback onAllHands;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            StatsCopy.replayMissing,
            textAlign: TextAlign.center,
            style: AllInText.body(15, color: c.textMuted, height: 1.5),
          ),
          const SizedBox(height: AllInSpace.lg),
          AllInButton.secondary(
            label: StatsCopy.allHandsRow,
            expand: true,
            onPressed: onAllHands,
          ),
        ],
      ),
    );
  }
}

class _FrameText extends StatelessWidget {
  const _FrameText({required this.text, required this.reducedMotion});

  final String text;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 24,
      child: AnimatedSwitcher(
        duration: AllInMotion.of(
          context,
          AllInMotion.fast,
          reduced: reducedMotion,
        ),
        child: Text(
          text,
          key: ValueKey(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AllInText.body(15, color: c.text),
        ),
      ),
    );
  }
}

/// Fixed 48 pt so the scrubber never jumps between frames with and without a
/// note (§7.7).
class _CoachNoteStrip extends StatelessWidget {
  const _CoachNoteStrip({required this.note, required this.onOpen});

  final CoachNoteRecord? note;
  final ValueChanged<CoachNoteRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = note;
    if (n == null) return const SizedBox(height: 48);
    final verdict = Verdict.fromLabel(n.verdict);

    return SizedBox(
      height: 48,
      child: Semantics(
        button: true,
        label: '${n.title}. ${n.plain}',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => onOpen(n),
            borderRadius: BorderRadius.circular(AllInRadius.md),
            child: Row(
              children: [
                VerdictBadge(verdict: verdict, size: VerdictBadge.small),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: Text(
                    '${n.title} · ${n.plain}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(12, color: c.textMuted, height: 1.3),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// §7.7's one refusal: more seats than the felt draws. The action is still
/// written out and every control still works.
class _TooManySeats extends StatelessWidget {
  const _TooManySeats({required this.model, required this.frame});

  final ReplayModel model;
  final ReplayFrame frame;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hand = model.hand;
    final heroSeats = model.seats.where((s) => s.isHero);
    final hero = heroSeats.isEmpty ? null : heroSeats.first;
    final hole = hero == null ? null : hand.holes[hero.seat];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AllInCard.plain(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (frame.board.isNotEmpty)
                  Center(child: BoardRow(cards: frame.board, size: 38)),
                if (hole != null && hole.length >= 2) ...[
                  const SizedBox(height: AllInSpace.md),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final card in hole) ...[
                          PlayingCardView(card: card, width: 38),
                          const SizedBox(width: AllInSpace.xs),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AllInSpace.md),
                Text(
                  StatsCopy.replayTooManySeats(model.seats.length),
                  style: AllInText.body(13, color: c.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          for (var i = 0; i < model.frames.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                model.frames[i].text,
                style: AllInText.body(13, color: c.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _FrameList extends StatelessWidget {
  const _FrameList({
    required this.model,
    required this.current,
    required this.onPick,
  });

  final ReplayModel model;
  final int current;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          StatsCopy.replayFrames,
          style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
        ),
        const SizedBox(height: AllInSpace.sm),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: model.frames.length,
            itemBuilder: (context, i) {
              final selected = i == current;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Frame ${i + 1}, ${model.frames[i].text}',
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: () => onPick(i),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${i + 1}',
                              style: AllInText.mono(
                                12,
                                color: selected ? c.gold : c.textFaint,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              model.frames[i].text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AllInText.body(
                                14,
                                color: selected ? c.gold : c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "‹ Older hand … Newer hand ›" — one step along T2's own order, so a
/// session can be reviewed hand after hand without leaving P11 *(new)*.
///
/// Older is on the left because the list runs newest first and the replayer is
/// usually entered at the newest hand: stepping left walks back through the
/// session the way it was played.
class _HandStepRow extends StatelessWidget {
  const _HandStepRow({required this.neighbours, required this.onGo});

  final HandNeighbours neighbours;
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context) {
    final older = neighbours.older;
    final newer = neighbours.newer;
    if (older == null && newer == null) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _HandStepButton(
            label: StatsCopy.replayOlderHand,
            icon: Icons.chevron_left_rounded,
            leading: true,
            onPressed: older == null ? null : () => onGo(older),
          ),
          const Spacer(),
          _HandStepButton(
            label: StatsCopy.replayNewerHand,
            icon: Icons.chevron_right_rounded,
            leading: false,
            onPressed: newer == null ? null : () => onGo(newer),
          ),
        ],
      ),
    );
  }
}

class _HandStepButton extends StatelessWidget {
  const _HandStepButton({
    required this.label,
    required this.icon,
    required this.leading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = onPressed == null ? c.textFaint : c.textMuted;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AllInText.body(13, color: color),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.xs),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading) Icon(icon, size: 18, color: color),
                Flexible(child: text),
                if (!leading) Icon(icon, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
