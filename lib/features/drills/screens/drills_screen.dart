/// D0 · Drills — the Drills tab root (DESIGN.md §5.1–§5.7). Mode and set size
/// arrive as query parameters (`/drills?mode=leaks&set=10`, §2.6).
///
/// The screen is a **band stack**: mode chips, stats strip, the drill table
/// (which absorbs every point the compact heights have to give up), the
/// push/fold extras, the scrubber, the hand line and — never shrinking — the
/// 56 pt answer row (§5.1's band table). Because the bands are laid out by
/// hand rather than by `Expanded`, the screen knows exactly where the hero's
/// cards end, which is the one number D1's compact detent is derived from:
/// **compact top = hero-cards bottom + 8**.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_providers.dart';
import '../../../app/routes.dart';
import '../../../data/icm_scenarios.g.dart';
import '../../../engine/engine.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../content/drill_copy.dart';
import '../providers/drill_provider.dart';
import '../providers/drill_stores.dart';
import '../providers/goals_provider.dart';
import '../providers/review_provider.dart';
import '../widgets/drill_sheets.dart';
import '../widgets/feedback_content.dart';
import '../widgets/review_empty.dart';

/// §5.1's band heights at 390×844. The table takes whatever is left.
const double _chipsBand = 44;
const double _statsBand = 32;
const double _todayBand = 24;
const double _scrubberBand = 44;
const double _handBand = 26;
const double _answerBand = AnswerRow.height;

/// `IcmBanner.height` (36) is its **minimum**, not its size: two lines of type
/// need ~46 pt at 1.0× and more again at 1.3×. The band therefore reserves a
/// text-scaled 48 and the banner is never clamped.
const double _icmBand = 48;
const double _stacksBand = StacksStrip.height;
const double _gap = AllInSpace.sm;

/// Below this screen height the two stats lines merge into one (§5.1's
/// 360×780 column).
const double _mergeStatsBelow = 820;

/// The panel's compact detent never leaves less than this on screen.
const double _minPanelHeight = 220;

class DrillsScreen extends ConsumerStatefulWidget {
  const DrillsScreen({super.key, this.mode, this.setSize});

  /// `mixed` · `pushfold` · `exploit` · `leaks`; null keeps the last mode.
  final String? mode;

  /// Quick-set length from `?set=` (e.g. 10); null means the normal queue.
  final int? setSize;

  @override
  ConsumerState<DrillsScreen> createState() => _DrillsScreenState();
}

class _DrillsScreenState extends ConsumerState<DrillsScreen>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// The §5.2 hint runs on a controller rather than a `Timer` so it schedules
  /// frames: `pumpAndSettle` flushes it, and it can never outlive the screen.
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _hint.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        ref.read(drillProvider.notifier).dismissSwipeHint();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRoute());
  }

  @override
  void didUpdateWidget(covariant DrillsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.setSize != widget.setSize) {
      _applyRoute();
    }
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _applyRoute() {
    if (!mounted) return;
    unawaited(
      ref
          .read(drillProvider.notifier)
          .applyRoute(mode: widget.mode, setSize: widget.setSize),
    );
  }

  void _armHint() => _hint.forward(from: 0);

  /* ------------------------------------------------------------- intents */

  Future<void> _answer(DrillAction action) async {
    setState(() => _expanded = false);
    await ref.read(drillProvider.notifier).answer(action);
  }

  Future<void> _next() async {
    setState(() => _expanded = false);
    await ref.read(drillProvider.notifier).next();
  }

  /// §5.1 / §13: hardware keyboards still map 1 / 2 / 3 to the options and
  /// Enter to "Next puzzle" — silently, with no on-screen keycaps.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final session = ref.read(drillProvider);
    if (session.phase != DrillPhase.ready) return KeyEventResult.ignored;

    if (session.isAnswered) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        unawaited(_next());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
    ];
    final index = digits.indexOf(event.logicalKey);
    final options = session.puzzle?.options ?? const <DrillOption>[];
    if (index < 0 || index >= options.length) return KeyEventResult.ignored;
    unawaited(_answer(options[index].action));
    return KeyEventResult.handled;
  }

  /* --------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(drillProvider);
    final settings = ref.watch(settingsProvider);
    final reduced = settings.reducedMotion;

    ref.listen<bool>(drillProvider.select((s) => s.showSwipeHint), (_, next) {
      if (next) _armHint();
    });

    return PopScope(
      canPop: !(session.isAnswered && _expanded),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _expanded = false);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: AllInScaffold(
          title: DrillCopy.title,
          actions: [
            _HeaderInfoButton(
              onTap:
                  () => showDrillModeSheet(
                    context,
                    mode: session.mode,
                    reducedMotion: reduced,
                  ),
            ),
          ],
          body: LayoutBuilder(
            builder: (context, constraints) {
              // `AllInScaffold` runs `SafeArea(bottom: false)`, so this body
              // is laid out *under* the tab bar. §5.1's budget is a fixed
              // layout, not a scroll view, so it has to reserve that chrome
              // itself — otherwise the answer row lands behind the bar and
              // the spot cannot be answered at all.
              final inset = MediaQuery.paddingOf(context).bottom;
              // `removeBottom` as well as padding: the inset is consumed here
              // once, so the feedback panel (which pins its primary above
              // `MediaQuery.padding.bottom`) does not reserve it a second time
              // and starve its own body to nothing in the compact detent.
              return MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Padding(
                  padding: EdgeInsets.only(bottom: inset),
                  child: _Body(
                    constraints: constraints.deflate(
                      EdgeInsets.only(bottom: inset),
                    ),
                    session: session,
                    expanded: _expanded && !session.touchingTable,
                    onExpandedChanged: (v) => setState(() => _expanded = v),
                    onAnswer: _answer,
                    onNext: _next,
                    reducedMotion: reduced,
                    haptics: settings.haptics,
                    fourColorDeck: settings.fourColorDeck,
                    alwaysExpandMath: settings.alwaysExpandMath,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ body */

class _Body extends ConsumerWidget {
  const _Body({
    required this.constraints,
    required this.session,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onAnswer,
    required this.onNext,
    required this.reducedMotion,
    required this.haptics,
    required this.fourColorDeck,
    required this.alwaysExpandMath,
  });

  final BoxConstraints constraints;
  final DrillSession session;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<DrillAction> onAnswer;
  final VoidCallback onNext;
  final bool reducedMotion;
  final bool haptics;
  final bool fourColorDeck;
  final bool alwaysExpandMath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(drillProvider.notifier);
    final counts = ref.watch(reviewCountsProvider);
    final review = session.mode == DrillMode.leaks;
    final merged = MediaQuery.sizeOf(context).height < _mergeStatsBelow;
    final puzzle = session.puzzle;

    final chips = ModeChips(
      modes: [
        for (final m in DrillMode.values)
          ModeChipData(
            id: m.id,
            label: m.label,
            badge: m == DrillMode.leaks ? counts.due : 0,
          ),
      ],
      value: session.mode.id,
      enableHaptics: haptics,
      onChanged: (id) => notifier.setMode(DrillMode.fromId(id)),
      onLongPress:
          (id) => showDrillModeSheet(
            context,
            mode: DrillMode.fromId(id),
            reducedMotion: reducedMotion,
          ),
    );

    final strip =
        review
            ? _ReviewStrip(due: counts.due, scheduled: counts.scheduled)
            : _PracticeStrip(
              session: session,
              merged: merged,
              reducedMotion: reducedMotion,
            );
    final statsHeight = review || merged ? _statsBand : _statsBand + _todayBand;

    // Everything under the table, so the table can take the remainder.
    final showIcm = puzzle?.icm == true;
    final stacksLine = puzzle == null ? null : DrillCopy.stacksLineFor(puzzle);
    // Bands that hold *type* grow with the text scaler; the answer row and the
    // scrubber are fixed hit targets and never do (§5.1, §13).
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      2.0,
    );
    final icmHeight = _icmBand * textScale;
    final stacksHeight = _stacksBand * textScale;
    final handHeight = _handBand * textScale;
    final below =
        _gap +
        (showIcm ? icmHeight + _gap : 0) +
        (stacksLine != null ? stacksHeight + _gap : 0) +
        _scrubberBand +
        AllInSpace.xs +
        handHeight +
        _gap +
        _answerBand +
        _gap;

    final above = _chipsBand + statsHeight + AllInSpace.xs;
    final tableHeight = (constraints.maxHeight - above - below).clamp(
      160.0,
      constraints.maxHeight,
    );

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: _chipsBand, child: chips),
        // The 16 pt page margin (§16.5); without it the strip runs into both
        // bezels and "best N" is clipped by the right edge.
        SizedBox(
          height: statsHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
            child: strip,
          ),
        ),
        const SizedBox(height: AllInSpace.xs),
      ],
    );

    // ------------------------------------------------ the three body states
    if (session.phase == DrillPhase.empty && review) {
      return Column(
        children: [
          header,
          Expanded(
            child: ReviewEmptyState(
              totalCards: counts.total,
              nextDueAt:
                  counts.nextDueAt == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(counts.nextDueAt!),
              now: ref.read(drillClockProvider).now(),
              enableHaptics: haptics,
              reducedMotion: reducedMotion,
              onPlay: () => context.go(AllInRoutes.lobbyPath),
              onDrillMixed: () => notifier.setMode(DrillMode.mixed),
            ),
          ),
        ],
      );
    }

    if (session.phase == DrillPhase.error) {
      return Column(
        children: [
          header,
          Expanded(
            child: _DrillMessage(
              text: DrillCopy.dealFailed,
              action: AllInButton.secondary(
                label: DrillCopy.tryAgain,
                onPressed: notifier.retry,
                enableHaptics: haptics,
                reducedMotion: reducedMotion,
              ),
            ),
          ),
        ],
      );
    }

    if (session.phase != DrillPhase.ready || puzzle == null) {
      return Column(
        children: [
          header,
          const Expanded(child: _DrillMessage(text: DrillCopy.dealing)),
        ],
      );
    }

    // ------------------------------------------------------- the live spot
    final frame = session.frame ?? puzzle.frames.last;
    final metrics = DrillTableMetrics.forHeight(tableHeight);
    final compactTop = (metrics.heroCardsBottom(above, tableHeight) + 8).clamp(
      0.0,
      (constraints.maxHeight - _minPanelHeight).clamp(
        0.0,
        constraints.maxHeight,
      ),
    );
    final decoration = _SpotDecoration.of(puzzle);

    final content = Column(
      children: [
        header,
        SizedBox(
          height: tableHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: DrillTable(
                  seats: puzzle.seats,
                  hole: puzzle.hole,
                  frame: frame,
                  bb: puzzle.bb,
                  captions: decoration.captions,
                  heroCaption: decoration.heroCaption,
                  highlightSeat: decoration.seat,
                  highlightColor: decoration.color,
                  highlightHud: decoration.hud,
                  fourColorDeck: fourColorDeck,
                  dimmed: session.isAnswered,
                  enableHaptics: haptics,
                  onPreviousFrame: notifier.previousFrame,
                  onNextFrame: notifier.nextFrame,
                  onTouchChanged: notifier.setTouchingTable,
                ),
              ),
              if (session.showSwipeHint)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AllInSpace.sm,
                  child: IgnorePointer(
                    child: Center(
                      child: _SwipeHint(reducedMotion: reducedMotion),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        // Both bands sit on the 16 pt page margin like everything else on the
        // screen; without it the stacks line runs into the bezels and
        // ellipsises a stack size away.
        if (showIcm) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
            child: IcmBanner(
              scenarioName:
                  DrillCopy.icmScenarioName(puzzle) ?? DrillCopy.sourceIcm,
            ),
          ),
          const SizedBox(height: _gap),
        ],
        if (stacksLine != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
            child: StacksStrip(text: stacksLine),
          ),
          const SizedBox(height: _gap),
        ],
        SizedBox(
          height: _scrubberBand,
          child: FrameScrubber(
            index: session.navIndex.clamp(0, puzzle.frames.length - 1),
            count: puzzle.frames.length,
            text: frame.text,
            enableHaptics: haptics,
            onIndexChanged: notifier.setNav,
            onPillLongPress:
                () => DrillFrameListSheet.show(
                  context,
                  frames: puzzle.frames,
                  index: session.navIndex,
                  onPick: notifier.setNav,
                  reducedMotion: reducedMotion,
                ),
          ),
        ),
        const SizedBox(height: AllInSpace.xs),
        _HandLine(
          puzzle: puzzle,
          setCounter:
              session.setSize == null
                  ? null
                  : DrillCopy.setCounter(session.setAnswered, session.setSize!),
          onSource:
              () => showDrillSourceSheet(
                context,
                puzzle: puzzle,
                reducedMotion: reducedMotion,
              ),
        ),
        const SizedBox(height: _gap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
          child: AnswerRow(
            options: puzzle.options,
            answered: session.answered,
            accepted: session.result?.accept ?? const <DrillAction>[],
            enableHaptics: haptics,
            reducedMotion: reducedMotion,
            onAnswer: onAnswer,
          ),
        ),
        const SizedBox(height: _gap),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (session.isAnswered)
          AnimatedPositioned(
            duration: AllInMotion.of(
              context,
              FeedbackPanel.rise,
              reduced: reducedMotion,
            ),
            curve: AllInMotion.ease,
            left: 0,
            right: 0,
            bottom: 0,
            top: expanded ? 0 : compactTop,
            child: _Feedback(
              session: session,
              expanded: expanded,
              onExpandedChanged: onExpandedChanged,
              onNext: onNext,
              reducedMotion: reducedMotion,
              haptics: haptics,
              alwaysExpandMath: alwaysExpandMath,
            ),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------ stats strip */

class _PracticeStrip extends ConsumerWidget {
  const _PracticeStrip({
    required this.session,
    required this.merged,
    required this.reducedMotion,
  });

  final DrillSession session;
  final bool merged;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(drillScoreboardProvider);
    final goals = ref.watch(goalsProvider);
    return StatsStrip(
      rating: board.rating,
      accuracy: ref.watch(drillAccuracyProvider),
      streak: board.streak,
      best: board.best,
      todayDrills: goals.todayDrills,
      dayStreak: goals.dayStreak,
      merged: merged,
      answerToken: session.answerToken,
      lastAnswerCorrect: session.result?.correct,
      reducedMotion: reducedMotion,
      onStatTap:
          (stat) => showDrillStatSheet(
            context,
            stat: stat,
            answers: ref.read(drillStoreProvider).loadAnswers(),
            nowMs: ref.read(drillClockProvider).nowMs,
            reducedMotion: reducedMotion,
          ),
    );
  }
}

/// §5.1's Review-mode replacement for the stats strip.
///
/// This is `StatsStrip.review`'s line, rendered here rather than through the
/// library widget: `StatsStrip` declares `_pulse` as a `late final`
/// `AnimationController` that only the *practice* branch of its `build` ever
/// touches, so a `.review` instance creates the controller for the first time
/// inside `dispose()` — `createTicker` then looks up `TickerMode` on an
/// already-deactivated element and throws. Switching to Review and back would
/// crash the tab. The copy and metrics here are identical to that branch;
/// delete this widget and go back to `StatsStrip.review` once the library
/// widget builds `_pulse` in `initState` (see the feature report).
class _ReviewStrip extends StatelessWidget {
  const _ReviewStrip({required this.due, required this.scheduled});

  final int due;
  final int scheduled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _statsBand,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Review · $due due · $scheduled scheduled',
        style: AllInText.mono(13, color: context.colors.textMuted),
      ),
    ),
  );
}

/* -------------------------------------------------------------- hand line */

class _HandLine extends StatelessWidget {
  const _HandLine({
    required this.puzzle,
    required this.onSource,
    this.setCounter,
  });

  final Puzzle puzzle;
  final VoidCallback onSource;
  final String? setCounter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
      child: Row(
        children: [
          Text(
            DrillCopy.yourHand,
            style: AllInText.body(13, color: c.textMuted),
          ),
          const SizedBox(width: AllInSpace.sm),
          Text(puzzle.handLabel, style: AllInText.display(17, color: c.gold)),
          const Spacer(),
          Flexible(
            child: Semantics(
              button: true,
              label: DrillCopy.sourceLabel(puzzle),
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSource,
                  child: Text(
                    DrillCopy.sourceLabel(puzzle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AllInText.body(12, color: c.textFaint),
                  ),
                ),
              ),
            ),
          ),
          if (setCounter != null) ...[
            const SizedBox(width: AllInSpace.sm),
            Text(setCounter!, style: AllInText.mono(12, color: c.gold)),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ D1 assembly */

class _Feedback extends ConsumerWidget {
  const _Feedback({
    required this.session,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onNext,
    required this.reducedMotion,
    required this.haptics,
    required this.alwaysExpandMath,
  });

  final DrillSession session;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onNext;
  final bool reducedMotion;
  final bool haptics;
  final bool alwaysExpandMath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzle = session.puzzle!;
    final result = session.result!;
    final notifier = ref.read(drillProvider.notifier);
    final practice = session.mode.isPractice;
    final evLoss = result.evLossBb;
    final setSize = session.setSize;

    final actions = <Widget>[
      if (puzzle.lessonId != null)
        Expanded(
          child: AllInButton.secondary(
            label: puzzle.lessonTitle ?? DrillCopy.readTheLesson,
            leading: Icons.menu_book_rounded,
            expand: true,
            enableHaptics: haptics,
            reducedMotion: reducedMotion,
            onPressed:
                () =>
                    context.push(AllInRoutes.lessonModalPath(puzzle.lessonId!)),
          ),
        ),
      if (practice && puzzle.kind != PuzzleKind.leak)
        Expanded(
          child: AllInButton.secondary(
            label: DrillCopy.drillFiveSimilar,
            leading: Icons.my_location_rounded,
            expand: true,
            enableHaptics: haptics,
            reducedMotion: reducedMotion,
            onPressed: notifier.drillSimilar,
          ),
        ),
    ];

    return FeedbackPanel(
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      onNext: onNext,
      reducedMotion: reducedMotion,
      header: DrillFeedbackHeader(
        correct: result.correct,
        ratingDelta: practice ? session.ratingDelta : null,
        evLossLine:
            !result.correct && evLoss != null && evLoss > 0.05
                ? DrillCopy.evLossLine(evLoss)
                : null,
        scheduleLine: session.scheduleLine,
        setDoneLine:
            session.setJustFinished && setSize != null
                ? DrillCopy.setDone(
                  session.setCorrect,
                  setSize,
                  session.setDelta,
                )
                : null,
      ),
      body: DrillFeedbackBody(
        puzzle: puzzle,
        rationale: result.rationale,
        alwaysExpandMath: alwaysExpandMath,
        enableHaptics: haptics,
        reducedMotion: reducedMotion,
        onDisclosureToggle: (open) {
          if (open && !expanded) onExpandedChanged(true);
        },
        footerCaption:
            session.focusLeft > 0
                ? DrillCopy.moreOfThisType(session.focusLeft)
                : null,
        actions:
            actions.isEmpty
                ? null
                : Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AllInSpace.sm),
                      actions[i],
                    ],
                  ],
                ),
      ),
      primary: AllInButton.primary(
        label:
            session.setJustFinished
                ? DrillCopy.keepGoing
                : DrillCopy.nextPuzzle,
        size: AllInButtonSize.lg,
        trailing: Icons.chevron_right_rounded,
        expand: true,
        enableHaptics: haptics,
        reducedMotion: reducedMotion,
        onPressed: onNext,
      ),
    );
  }
}

/* ------------------------------------------------------- small components */

class _HeaderInfoButton extends StatelessWidget {
  const _HeaderInfoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'About this mode',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: context.colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DrillMessage extends StatelessWidget {
  const _DrillMessage({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AllInSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AllInText.body(
                15,
                color: context.colors.textMuted,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AllInSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.reducedMotion});

  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedOpacity(
      opacity: 1,
      duration: AllInMotion.of(
        context,
        AllInMotion.fast,
        reduced: reducedMotion,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AllInSpace.md,
          vertical: AllInSpace.xs,
        ),
        decoration: BoxDecoration(
          color: c.ink900.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AllInRadius.pill),
        ),
        child: Text(
          DrillCopy.swipeHint,
          style: AllInText.body(12, color: c.text),
        ),
      ),
    );
  }
}

/* ----------------------------------------------- push/fold + exploit dress */

/// Plate captions, hero caption and the exploit ring for one spot
/// (§5.6, §5.7).
class _SpotDecoration {
  const _SpotDecoration({
    this.captions = const <Position, String>{},
    this.heroCaption,
    this.seat,
    this.color,
    this.hud,
  });

  final Map<Position, String> captions;
  final String? heroCaption;
  final Position? seat;
  final Color? color;
  final String? hud;

  static _SpotDecoration of(Puzzle puzzle) {
    if (puzzle.kind == PuzzleKind.exploit) return _exploit(puzzle);
    if (puzzle.kind == PuzzleKind.pushfold) return _pushFold(puzzle);
    return const _SpotDecoration();
  }

  /// Every exploit template names the **BB** (Station river, Nit turn raise,
  /// Nit blind steal), so the ring goes there; the archetype comes from the
  /// verbatim first frame.
  static _SpotDecoration _exploit(Puzzle puzzle) {
    final text =
        puzzle.frames.isEmpty ? '' : puzzle.frames.first.text.toUpperCase();
    final archetype =
        text.contains('CALLING STATION')
            ? Archetype.station
            : text.contains('NIT')
            ? Archetype.nit
            : text.contains('LAG')
            ? Archetype.lag
            : text.contains('TAG')
            ? Archetype.tag
            : null;
    if (archetype == null) return const _SpotDecoration();
    final config = kArchetypes[archetype]!;
    return _SpotDecoration(
      seat: Position.bb,
      color: _hexColor(config.color),
      hud: '${config.vpip.round()}/${config.pfr.round()}',
    );
  }

  /// The live stacks of §5.6: the hero's on their own plate, and — on an ICM
  /// bubble — the SB's and the BB's from the shipped scenario.
  static _SpotDecoration _pushFold(Puzzle puzzle) {
    if (puzzle.icm == true) {
      final name = DrillCopy.icmScenarioName(puzzle);
      for (final scenario in kIcmScenarios) {
        if (scenario.name != name) continue;
        final sb = scenario.stacks[0];
        final bb = scenario.stacks[1];
        final heroStack = puzzle.heroPos == Position.sb ? sb : bb;
        return _SpotDecoration(
          captions: {Position.sb: '$sb bb', Position.bb: '$bb bb'}
            ..remove(puzzle.heroPos),
          heroCaption: 'You · $heroStack bb',
        );
      }
      return const _SpotDecoration();
    }
    final stack = _nashStack(puzzle);
    return _SpotDecoration(
      heroCaption: stack == null ? null : 'You · $stack bb',
    );
  }

  static final RegExp _stackFrame = RegExp(r'^([0-9.]+) bb stacks');

  static String? _nashStack(Puzzle puzzle) {
    if (puzzle.frames.isEmpty) return null;
    return _stackFrame.firstMatch(puzzle.frames.first.text)?.group(1);
  }

  /// `ArchetypeConfig.color` is a `#rrggbb` string (desktop parity).
  static Color? _hexColor(String hex) {
    final digits = hex.replaceFirst('#', '');
    if (digits.length != 6) return null;
    final value = int.tryParse(digits, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}
