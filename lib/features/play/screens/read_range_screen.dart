/// P7: select a hand type or range, save it, then review the actual-card
/// result at hand-over. The estimated range comparison is a separate,
/// optional disclosure. The selection and result scroll above Continue.
/// The table owns pausing while this modal route is open.
library;

import 'dart:math' as math;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/guess_provider.dart';
import '../providers/hand_reads_provider.dart';
import '../widgets/hand_read_card.dart';
import '../widgets/hand_read_copy.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/coach_copy.dart';
import 'package:allin/features/play/widgets/coach_sheet.dart'
    show CoachLegendRow;
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadRangeScreen extends ConsumerStatefulWidget {
  const ReadRangeScreen({super.key, required this.seat});

  /// Seat index of the bot whose range is being read (`:seat`).
  final int seat;

  /// §4.9's page margin: on P7 the matrix *is* the screen.
  static const double pageMargin = 4;

  @override
  ConsumerState<ReadRangeScreen> createState() => _ReadRangeScreenState();
}

class _ReadRangeScreenState extends ConsumerState<ReadRangeScreen>
    with SingleTickerProviderStateMixin {
  final UndoController _undo = UndoController();
  late final GuessNotifier _guess = ref.read(guessProvider.notifier);

  /// §4.9's 3 s "Undo clear" prompt. An `AnimationController` rather than a
  /// `Timer` so it can never outlive the screen. Built eagerly: a `late final`
  /// would be constructed by `dispose` on a screen that never cleared, and a
  /// `Ticker` cannot be created while the element is unmounting.
  late final AnimationController _cleared;

  @override
  void initState() {
    super.initState();
    _cleared = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
      if (mounted && status == AnimationStatus.completed) setState(() {});
    });
    // Riverpod forbids writing to a provider while the tree is building, so
    // the reset lands on the next microtask; until then the screen renders
    // from `widget.seat`, which is all it needs.
    Future<void>.microtask(() {
      if (mounted) _guess.open(widget.seat);
    });
  }

  @override
  void dispose() {
    _cleared.dispose();
    _undo.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------- actions */

  /// ✕ · Continue · the pinned button. The paint is forgotten **after** the
  /// pop, so the route keeps its content through the exit transition; a
  /// system back skips this and `open()` resets on the next read instead.
  void _close() {
    Navigator.of(context).pop();
    _guess.close();
  }

  void _paint(Set<HandLabel> next) => _guess.setPainted(next);

  void _preset(RangePreset preset, Set<HandLabel> current) {
    _undo.record(current);
    _guess.setPainted(<HandLabel>{...preset.labels}, presetId: preset.id);
  }

  void _undoStroke() {
    final previous = _undo.undo();
    if (previous == null) return;
    _guess.setPainted(previous);
    if (_cleared.isAnimating) {
      _cleared.stop();
      setState(() {});
    }
  }

  void _clear(Set<HandLabel> current) {
    _undo.record(current);
    _guess.clear();
    _cleared.forward(from: 0);
    setState(() {});
  }

  void _peek() {
    _guess.peek();
    setState(() {});
  }

  /* --------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final reduced = ref.watch(reducedMotionProvider);
    final session = ref.watch(sessionProvider);
    final table = session.table;
    final raw = ref.watch(guessProvider);
    // A stale reveal from another seat or an earlier hand is not this screen's
    // state; `open()` clears it on the next microtask.
    final guess =
        raw.sessionId == session.startedAt &&
                raw.seat == widget.seat &&
                raw.handNumber == (table?.handNumber ?? 0)
            ? raw
            : const GuessState();

    final player =
        table == null || widget.seat < 1 || widget.seat >= table.players.length
            ? null
            : table.players[widget.seat];

    if (player == null) return _empty(context);

    final name = player.name;
    final config =
        player.archetype == null ? null : kArchetypes[player.archetype];
    final context1 = CoachSheetCopy.readContext(
      position: positionLabel(player.position, table!.config.seats),
      // The archetype's plain name only — the "(TAG)" / "(Station)" code the
      // desktop appended is layer-3 shorthand (TONE.md).
      archetype: config == null ? 'Player' : config.name,
      street: CoachNoteView.streetLabel(table.board),
    );

    return PopScope(
      // Before Peek back closes without scoring; after Peek it is Continue.
      // Both are the same pop — `dispose` forgets the paint (§2.5).
      canPop: true,
      child: AllInScaffold(
        body: AnimatedSwitcher(
          duration: AllInMotion.of(context, AllInMotion.base, reduced: reduced),
          child:
              guess.revealed
                  ? _reveal(context, guess, name, context1, reduced)
                  : _painter(context, guess, name, context1, reduced),
        ),
        bottom:
            !guess.revealed
                ? null
                : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AllInSpace.lg,
                    vertical: AllInSpace.sm,
                  ),
                  child: AllInButton.primary(
                    label: CoachSheetCopy.continueLabel,
                    size: _buttonSize(context),
                    expand: true,
                    onPressed: _close,
                    enableHaptics: ref.watch(hapticsEnabledProvider),
                    reducedMotion: reduced,
                  ),
                ),
      ),
    );
  }

  AllInButtonSize _buttonSize(BuildContext context) =>
      MediaQuery.sizeOf(context).height >= 800
          ? AllInButtonSize.lg
          : AllInButtonSize.md;

  /* ------------------------------------------------------------- painter */

  Widget _painter(
    BuildContext context,
    GuessState guess,
    String name,
    String contextLine,
    bool reduced,
  ) {
    final c = context.colors;
    final haptics = ref.watch(hapticsEnabledProvider);
    final width = MediaQuery.sizeOf(context).width;
    final box = width - 2 * ReadRangeScreen.pageMargin;
    // §4.9's per-width painter geometry: gap 1 at 360, 2 above it; the row
    // header grows with the screen.
    final gap = width >= 390 ? 2.0 : 1.0;
    final header = width >= 430 ? 22.0 : 20.0;
    final painted = guess.painted;

    return Column(
      key: const ValueKey<String>('read-range-painter'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TopBar(
          title: CoachSheetCopy.readTitle(name),
          onClose: _close,
          trailing:
              painted.isEmpty
                  ? _TextAction(
                    label: CoachSheetCopy.peek,
                    emphasised: true,
                    onTap: _peek,
                  )
                  : null,
        ),
        _Subtitle(lines: <String>[contextLine, CoachSheetCopy.readSubtitle]),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder:
                  (context, constraints) => RangeMatrix.editable(
                    value: painted,
                    width: math.min(box, constraints.maxHeight),
                    gap: gap,
                    headerWidth: header,
                    undoController: _undo,
                    enableHaptics: haptics,
                    reducedMotion: reduced,
                    semanticLabel: CoachSheetCopy.readTitle(name),
                    onChanged: _paint,
                  ),
            ),
          ),
        ),
        const SizedBox(height: AllInSpace.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
          child: CoachLegendRow(
            comparisonIsEstimate: true,
            trailing: ComboCounter(
              combos: combosInSet(painted),
              textAlign: TextAlign.right,
            ),
          ),
        ),
        const SizedBox(height: AllInSpace.sm),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AllInSpace.lg,
            0,
            AllInSpace.lg,
            4,
          ),
          child: Text(
            CoachSheetCopy.presetsLabel,
            style: AllInText.body(12, color: c.textFaint, height: 1.3),
          ),
        ),
        RangePresetRow(
          // §4.9's chip list exactly: five top-percent ranges then the five
          // 100 bb position opens. Clear is a button here, not a chip.
          presets: RangePresetRow.defaults(anyTwo: false, clear: false),
          selectedId: guess.presetId,
          enableHaptics: haptics,
          reducedMotion: reduced,
          onPick: (preset) => _preset(preset, painted),
        ),
        const SizedBox(height: AllInSpace.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
          child: Row(
            children: <Widget>[
              ListenableBuilder(
                listenable: _undo,
                builder:
                    (context, _) => AllInButton.ghost(
                      label: CoachSheetCopy.undo,
                      leading: Icons.undo_rounded,
                      size: _buttonSize(context),
                      onPressed: _undo.canUndo ? _undoStroke : null,
                      enableHaptics: haptics,
                      reducedMotion: reduced,
                    ),
              ),
              const SizedBox(width: AllInSpace.sm),
              AllInButton.ghost(
                label: CoachSheetCopy.clear,
                size: _buttonSize(context),
                onPressed: painted.isEmpty ? null : () => _clear(painted),
                enableHaptics: haptics,
                reducedMotion: reduced,
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: AllInButton.primary(
                  label:
                      painted.isEmpty
                          ? CoachSheetCopy.peek
                          : CoachSheetCopy.peekAndScore,
                  size: _buttonSize(context),
                  expand: true,
                  onPressed: _peek,
                  enableHaptics: haptics,
                  reducedMotion: reduced,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AllInSpace.xs),
        SizedBox(
          height: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
            child:
                _cleared.isAnimating
                    ? Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            CoachSheetCopy.clearedUndo,
                            style: AllInText.body(12, color: c.textMuted),
                          ),
                        ),
                        _TextAction(
                          label: CoachSheetCopy.undo,
                          emphasised: true,
                          compact: true,
                          onTap: _undoStroke,
                        ),
                      ],
                    )
                    : Text(
                      CoachSheetCopy.guessingIsOptional,
                      style: AllInText.body(12, color: c.textFaint),
                    ),
          ),
        ),
        const SizedBox(height: AllInSpace.sm),
      ],
    );
  }

  /* -------------------------------------------------------------- reveal */

  Widget _reveal(
    BuildContext context,
    GuessState guess,
    String name,
    String contextLine,
    bool reduced,
  ) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    // The optional comparison grid is compact; the whole result scrolls.
    final revealBox =
        width >= 430
            ? 334.0
            : width >= 390
            ? 305.0
            : 277.0;
    final revealWidth = math.min(revealBox, math.max(160.0, size.height - 420));
    final header = width >= 390 ? 20.0 : 18.0;

    final reads = ref.watch(handReadsProvider);
    final read =
        reads
            .where(
              (r) =>
                  r.sessionId == guess.sessionId &&
                  r.handNumber == guess.handNumber &&
                  r.seat == widget.seat &&
                  r.street == guess.street,
            )
            .firstOrNull;
    final c = context.colors;
    final haptics = ref.watch(hapticsEnabledProvider);
    final comparison = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child:
              guess.scored
                  ? RangeMatrix.compare(
                    comparisonIsEstimate: true,
                    painted: guess.painted,
                    actual: guess.actual,
                    width: revealWidth,
                    headerWidth: header,
                    reducedMotion: reduced,
                    semanticLabel: CoachSheetCopy.theirRange(
                      guess.actualCombos,
                    ),
                  )
                  : RangeMatrix.readOnly(
                    highlight: guess.actual,
                    width: revealWidth,
                    headerWidth: header,
                    reducedMotion: reduced,
                  ),
        ),
        const SizedBox(height: AllInSpace.sm),
        CoachLegendRow(
          comparisonIsEstimate: true,
          trailing: const SizedBox.shrink(),
          mode: guess.scored ? RangeLegendMode.compare : RangeLegendMode.kind,
        ),
        const SizedBox(height: AllInSpace.sm),
        Text(
          CoachSheetCopy.theirRange(guess.actualCombos),
          style: AllInText.mono(12, color: c.textMuted),
        ),
        if (guess.score case final score?) ...[
          const SizedBox(height: AllInSpace.md),
          Text(
            CoachSheetCopy.caught(score.recall),
            style: AllInText.body(15, color: c.text),
          ),
          Text(
            CoachSheetCopy.painted(score.precision),
            style: AllInText.body(15, color: c.text),
          ),
          DisclosureRow(
            label: CoachCopy.showMath,
            expandedLabel: CoachCopy.hideMath,
            enableHaptics: haptics,
            reducedMotion: reduced,
            child: Text(
              CoachSheetCopy.scoreMath(
                accuracy: score.accuracy,
                recall: score.recall,
                precision: score.precision,
                overlapCombos: guess.overlapCombos,
                actualCombos: guess.actualCombos,
                paintedCombos: guess.paintedCombos,
              ).join('\n\n'),
              style: AllInText.mono(13, color: c.textMuted),
            ),
          ),
        ],
        DisclosureRow(
          label: CoachCopy.expertDetail,
          expandedLabel: CoachCopy.hideExpert,
          enableHaptics: haptics,
          reducedMotion: reduced,
          child: Text(
            CoachSheetCopy.howTheRangeWasBuilt,
            style: AllInText.body(15, color: c.textMuted),
          ),
        ),
      ],
    );

    return Column(
      key: const ValueKey<String>('read-range-reveal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(title: CoachSheetCopy.revealTitle(name), onClose: _close),
        _Subtitle(
          lines: [read == null ? contextLine : HandReadCopy.context(read)],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AllInSpace.lg,
              0,
              AllInSpace.lg,
              AllInSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (read != null) ...[
                  HandReadCard(read: read),
                  const SizedBox(height: AllInSpace.md),
                  Text(
                    HandReadCopy.comparisonHint,
                    style: AllInText.body(14, color: c.textMuted, height: 1.4),
                  ),
                  DisclosureRow(
                    label: HandReadCopy.overlap(read.rangeOverlap),
                    enableHaptics: haptics,
                    reducedMotion: reduced,
                    child: comparison,
                  ),
                ] else if (guess.actual.isNotEmpty) ...[
                  Text(
                    CoachSheetCopy.nothingPainted(name),
                    style: AllInText.body(15, color: c.text),
                  ),
                  const SizedBox(height: AllInSpace.md),
                  comparison,
                  Text(
                    CoachSheetCopy.modelNotTheirCards,
                    style: AllInText.body(14, color: c.textMuted),
                  ),
                ] else ...[
                  Text(
                    HandReadCopy.noRead,
                    style: AllInText.display(25, color: c.text),
                  ),
                  const SizedBox(height: AllInSpace.sm),
                  Text(
                    HandReadCopy.noReadBody,
                    style: AllInText.body(15, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /* --------------------------------------------------------- empty state */

  Widget _empty(BuildContext context) => AllInScaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TopBar(title: CoachSheetCopy.readTitleGeneric, onClose: _close),
        const SizedBox(height: AllInSpace.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
          child: Text(
            CoachSheetCopy.nothingToRead,
            style: AllInText.body(15, color: context.colors.textMuted),
          ),
        ),
      ],
    ),
    bottom: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.lg,
        vertical: AllInSpace.sm,
      ),
      child: AllInButton.primary(
        label: CoachSheetCopy.close,
        expand: true,
        onPressed: _close,
      ),
    ),
  );
}

/// The 44 pt modal bar: ✕ · centred title · one optional text action (§4.9).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onClose, this.trailing});

  final String title;
  final VoidCallback onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          Semantics(
            button: true,
            label: CoachSheetCopy.close,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.close_rounded, size: 22, color: c.text),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AllInText.body(
                  17,
                  weight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }
}

/// The two muted lines under the bar (desktop's modal description).
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < lines.length; i++)
            Text(
              lines[i],
              style: AllInText.body(
                13,
                color: i == 0 ? c.textMuted : c.textFaint,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}

/// A 44 pt text button — "Peek" in the bar, "Undo" in the cleared strip.
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    this.emphasised = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasised;

  /// Inline in a 24 pt strip: the 44 pt target is kept by the slop, not the
  /// box (§12).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Text(
      label,
      style: AllInText.body(
        15,
        weight: FontWeight.w600,
        color: emphasised ? c.gold : c.text,
      ),
    );
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child:
              compact
                  ? HitSlop(minSize: const Size.square(44), child: text)
                  : Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AllInSpace.sm,
                    ),
                    alignment: Alignment.center,
                    child: text,
                  ),
        ),
      ),
    );
  }
}
