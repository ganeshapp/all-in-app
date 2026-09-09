/// P1 · Table — the root-level full-screen modal at `/table`
/// (DESIGN.md §4.2–§4.15, §16.1).
///
/// The vertical budget of §4.2 is fixed: the top bar, ticker, hero strip,
/// context row and action row never change height, so the felt is the only
/// flexible band and nothing on screen jumps between states. Every state §4.5
/// lists is here — A–G, the hero-out variants, the paused/blocking dim — and
/// every control is wired to the real `SessionNotifier`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/router.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/engine/types.dart' as poker show Action;
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/features/onboarding/widgets/coach_marks.dart';
import 'package:allin/features/play/providers/raise_sizing.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/providers/table_layout_provider.dart';
import 'package:allin/features/play/widgets/bet_keypad_sheet.dart';
import 'package:allin/features/play/widgets/coach_sheet.dart';
import 'package:allin/features/play/widgets/hand_over_overlay.dart';
import 'package:allin/features/play/widgets/hero_labels.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/features/play/widgets/player_sheet.dart';
import 'package:allin/features/play/widgets/session_sheet.dart';
import 'package:allin/features/play/widgets/table_context_row.dart';
import 'package:allin/features/play/widgets/table_felt.dart';
import 'package:allin/features/play/widgets/table_top_bar.dart';
import 'package:allin/services/persistence/hints_store.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// §4.2.4: the felt's own text stops scaling at 1.15×.
const double kFeltMaxTextScale = 1.15;

/// §4.8's chip lifetimes.
const Duration kChipLifetime = Duration(seconds: 4);
const Duration kChipLifetimeLong = Duration(seconds: 8);

/// §4.14: the "Resumed — …" caption lives for 2 s.
const Duration kResumeCaption = Duration(seconds: 2);

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen>
    with WidgetsBindingObserver {
  /// The sizing rail's value in chips, and the spot it was computed for.
  int? _raiseTo;
  String? _raiseSignature;
  bool _dragging = false;

  Timer? _chipTimer;
  Timer? _captionTimer;

  /// §4.14: the "Session paused" toast shows once per session.
  bool _pauseToastShown = false;

  /// §4.12's learn-by-reveal counter: three consecutive sub-1 s "Next hand"
  /// taps collapse the results card until two are opened again.
  int _fastNextRun = 0;
  int _slowNextRun = 0;
  bool _collapseResults = false;
  DateTime? _handOverAt;

  /// P10 is on screen (pushed by "End session" or by a bust).
  bool _summaryOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chipTimer?.cancel();
    _captionTimer?.cancel();
    super.dispose();
  }

  void _afterFirstFrame() {
    if (!mounted) return;
    // §4.14: a snapshot whose table half could not be decoded deals a fresh
    // hand on the table's first frame.
    ref.read(sessionProvider.notifier).ensureHand();
    _setResumeOnLaunch(true);
    // The session may have been dealt before the table was built (Resume, a
    // restored snapshot), in which case `ref.listen` never sees the change —
    // so the O1 counter is bumped for the hand already on the felt.
    final table = ref.read(sessionProvider).table;
    if (table != null) {
      ref.read(coachMarksProvider.notifier).handStarted(table.handNumber);
    }
    if (ref.read(sessionProvider).resumeCaption != null) _armCaptionTimer();
  }

  /// §2.1.1's cold-start flag: set while the table is the active location.
  void _setResumeOnLaunch(bool value) {
    final store = ref.read(keyValueStoreProvider);
    final hints = store.getJsonMap(kHintsKey);
    if (value) {
      hints[kResumeOnLaunchHint] = true;
    } else {
      hints.remove(kResumeOnLaunchHint);
    }
    store.setJson(kHintsKey, hints);
  }

  void _armCaptionTimer() {
    _captionTimer?.cancel();
    _captionTimer = Timer(kResumeCaption, () {
      if (mounted) ref.read(sessionProvider.notifier).clearResumeCaption();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // §4.6: backgrounding pauses immediately; the first tap resumes after
    // 700 ms so the user can re-orient.
    if (state == AppLifecycleState.resumed) return;
    ref.read(sessionProvider.notifier).pauseForBackground();
  }

  /* ------------------------------------------------------------- sizing */

  /// §4.5: the default is recomputed whenever `toAct / street / currentBet /
  /// phase / handNumber` change.
  int? _syncRaiseTo(TableState? table, LegalActions? legal) {
    if (table == null || legal == null || table.toAct != 0) {
      _raiseSignature = null;
      return null;
    }
    final signature =
        '${table.handNumber}:${table.street}:${table.currentBet}:'
        '${table.phase}:${table.toAct}';
    if (signature != _raiseSignature) {
      _raiseSignature = signature;
      _raiseTo = RaiseSizing.defaultValue(legal, table.currentBet);
    }
    return _raiseTo?.clamp(legal.minRaiseTo, legal.maxRaiseTo);
  }

  /* ------------------------------------------------------------ surfaces */

  Future<T?> _withSurface<T>(Future<T?> Function() open) async {
    final notifier = ref.read(sessionProvider.notifier);
    notifier.setSurfaceOpen(true);
    try {
      return await open();
    } finally {
      notifier.setSurfaceOpen(false);
    }
  }

  Future<void> _openSessionSheet([int? segment]) async {
    final result = await _withSurface(
      () => SessionSheet.show(
        context,
        initialSegment: segment,
        reducedMotion: ref.read(reducedMotionProvider),
        onReplay:
            (startedAt) => context.push(AllInRoutes.tableHandPath(startedAt)),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case SessionSheetResult.endSession:
        await _endSession();
      case SessionSheetResult.openReview:
        await _openCoachSheet();
      case null:
        break;
    }
  }

  Future<void> _endSession() async {
    ref.read(sessionProvider.notifier).endSession();
    await _showSummary();
  }

  /// P10 over the table. Idempotent: `endSession()` and the bust watcher both
  /// ask for it, and the route must be pushed exactly once (§4.12, §4.13).
  Future<void> _showSummary() async {
    if (_summaryOpen || !mounted) return;
    _summaryOpen = true;
    try {
      await context.push(AllInRoutes.summaryTablePath);
    } finally {
      _summaryOpen = false;
    }
  }

  Future<void> _openPlayerSheet(int seat) async {
    final table = ref.read(sessionProvider).table;
    if (table == null || seat >= table.players.length) return;
    final player = table.players[seat];
    final handOver = table.phase == GamePhase.handOver;
    final result = await _withSurface(
      () => PlayerSheet.show(
        context,
        player: player,
        seats: table.config.seats,
        bigBlind: table.bigBlind,
        canRead:
            !handOver && table.phase == GamePhase.betting && !player.hasFolded,
        canExplain:
            ref.read(sessionProvider).canExplain &&
            ref.read(sessionProvider).lastActorSeat == seat,
        handOver: handOver,
        reducedMotion: ref.read(reducedMotionProvider),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case PlayerSheetResult.readRange:
        _openReadRange(seat);
      case PlayerSheetResult.explain:
        await _explainLastMove();
    }
  }

  void _openReadRange(int seat) {
    final notifier = ref.read(sessionProvider.notifier);
    notifier.setSurfaceOpen(true);
    context.push(AllInRoutes.readRangePath(seat)).whenComplete(() {
      if (mounted) notifier.setSurfaceOpen(false);
    });
  }

  Future<void> _explainLastMove() async {
    ref.read(sessionProvider.notifier).explainLastBotMove();
    if (!mounted) return;
    await _openCoachSheet();
  }

  /// P3. Blocking notes are opened by [_watchCoach]; this is the tap path.
  Future<void> _openCoachSheet() async {
    final session = ref.read(sessionProvider);
    final review = session.activeReview ?? session.reviewLog.lastOrNull;
    if (review == null) return;
    final opener = ref.read(coachSheetProvider) ?? defaultCoachSheet;
    final table = session.table;
    final notifier = ref.read(sessionProvider.notifier);
    notifier.setSurfaceOpen(true);
    try {
      await opener(
        context,
        CoachSheetRequest(
          review: review,
          bigBlind: session.bigBlind,
          heroCards: List<String>.of(table?.players[0].hole ?? const []),
          alwaysExpandMath: ref.read(settingsProvider).alwaysExpandMath,
          reducedMotion: ref.read(reducedMotionProvider),
          onViewRange:
              review.villainRange == null || session.lastActorSeat == null
                  ? null
                  : () => _openReadRange(session.lastActorSeat!),
        ),
      );
    } finally {
      notifier.setSurfaceOpen(false);
    }
    if (mounted) ref.read(sessionProvider.notifier).dismissReview();
  }

  /* ------------------------------------------------------------- leaving */

  Future<void> _leave() async {
    final session = ref.read(sessionProvider);
    // §4.14 / P14: the only case that asks is a snapshot that cannot be saved.
    if (session.saveFailed) {
      final leave = await AllInDialog.show<bool>(
        context,
        dialog: AllInDialog(
          title: PlayCopy.leaveTableTitle,
          body: PlayCopy.leaveTableBody,
          actions: [
            AllInDialogAction(
              label: 'Cancel',
              onPressed:
                  () => Navigator.of(context, rootNavigator: true).pop(false),
            ),
            AllInDialogAction(
              label: 'Leave',
              isDestructive: true,
              onPressed:
                  () => Navigator.of(context, rootNavigator: true).pop(true),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    ref.read(sessionProvider.notifier).leaveTable();
    _setResumeOnLaunch(false);
    if (!_pauseToastShown && mounted) {
      _pauseToastShown = true;
      AllInToast.show(context, PlayCopy.sessionPaused);
    }
    if (mounted) context.go(AllInRoutes.lobbyPath);
  }

  /* -------------------------------------------------------------- watchers */

  /// The chip's 4 s / 8 s lifetime, and blocking notes opening themselves.
  void _watchCoach(SessionState? before, SessionState after) {
    if (before?.activeReviewId == after.activeReviewId) return;
    _chipTimer?.cancel();
    final review = after.activeReview;
    if (review == null) return;

    if (review.blocking) {
      // §4.8: the sheet opens itself; the loop is already paused.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCoachSheet();
      });
      return;
    }
    if (after.handOver) return; // the chip becomes the results card's row.

    final slow = ref.read(settingsProvider).speedMs == PaceSpeed.slowMs;
    final long = slow || review.verdict == Verdict.mistake;
    _chipTimer = Timer(long ? kChipLifetimeLong : kChipLifetime, () {
      if (mounted) ref.read(sessionProvider.notifier).dismissChip();
    });
  }

  void _watchHand(SessionState? before, SessionState after) {
    final table = after.table;
    if (table == null) return;
    if (before?.table?.handNumber != table.handNumber) {
      ref.read(coachMarksProvider.notifier).handStarted(table.handNumber);
      setState(() {
        _handOverAt = null;
        _raiseSignature = null;
      });
    }
    if (after.handOver && before?.handOver != true) {
      _handOverAt = DateTime.now();
    }
    if (after.resumeCaption != null && before?.resumeCaption == null) {
      _armCaptionTimer();
    }
    // §4.12: busting at the deal ends the session and opens P10 by itself.
    if (after.sessionEnded && before?.sessionEnded != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSummary());
    }
  }

  /* ---------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionProvider, (before, after) {
      _watchCoach(before, after);
      _watchHand(before, after);
    });

    final session = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestCoachMarks(session, settings),
    );
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = settings.haptics;
    final c = context.colors;
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final table = session.table;
    final metrics = TableMetrics.of(width, session.options.seats);
    final coachOn = settings.coachEnabled && !session.coachOffThisSession;

    return Scaffold(
      backgroundColor: c.ink900,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.padding.bottom),
          child: Column(
            children: [
              TableTopBar(
                handNumber: table?.handNumber ?? 0,
                netBb: session.netBb,
                paceMode: settings.paceMode,
                compact: width < 390,
                coachCount: session.reviewLog.length,
                coachVerdict:
                    session.reviewLog.isEmpty
                        ? null
                        : session.reviewLog.last.verdict,
                showCoach: coachOn,
                pulseBadge: session.pendingBlocking != null,
                reducedMotion: reduced,
                onBack: _leave,
                onTitle: () => _openSessionSheet(SessionSegment.session),
                onCoach: _openCoachSheet,
                onPaceToggle: () {
                  ref
                      .read(sessionProvider.notifier)
                      .setPace(
                        settings.paceMode == PaceMode.auto
                            ? PaceMode.manual
                            : PaceMode.auto,
                      );
                  ref.read(hapticsProvider).toggle();
                },
                onPaceLongPress:
                    () => _openSessionSheet(SessionSegment.options),
              ),
              _TickerBand(
                session: session,
                onTap: () => _openSessionSheet(SessionSegment.log),
              ),
              if (session.resumeCaption != null)
                _Caption(text: session.resumeCaption!),
              Expanded(
                child: MediaQuery(
                  data: media.copyWith(
                    textScaler: media.textScaler.clamp(
                      maxScaleFactor: kFeltMaxTextScale,
                    ),
                  ),
                  child: _FeltBand(
                    session: session,
                    metrics: metrics,
                    settings: settings,
                    reducedMotion: reduced,
                    enableHaptics: haptics,
                    coachOn: coachOn,
                    collapseResults: _collapseResults,
                    onSeatTap: _openPlayerSheet,
                    onSeatEye: _openReadRange,
                    onSeatLongPress: _openReadRange,
                    onActionPill: (_) => _explainLastMove(),
                    onChipTap: _openCoachSheet,
                    onCoachRowTap: _openCoachSheet,
                    onDealMeIn: () {
                      ref.read(sessionProvider.notifier).newSession();
                    },
                    onFeltTap: () {
                      ref.read(coachMarksProvider.notifier).dismiss();
                      ref.read(sessionProvider.notifier).tapFelt();
                    },
                    onResultsTouch:
                        () =>
                            ref.read(sessionProvider.notifier).cancelAutoDeal(),
                  ),
                ),
              ),
              const SizedBox(height: TableMetrics.heroStripGap),
              if (ref.watch(visibleCoachMarkProvider) == CoachMark.swipe)
                const Padding(
                  padding: EdgeInsets.only(bottom: AllInSpace.xs),
                  child: CoachMarkCaption(
                    mark: CoachMark.swipe,
                    pointer: CoachMarkPointer.down,
                  ),
                ),
              _heroStrip(session, metrics, width, haptics),
              const SizedBox(height: AllInSpace.xs),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: metrics.margin),
                child: _contextRow(session, settings, reduced, haptics),
              ),
              const SizedBox(height: AllInSpace.sm),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: metrics.margin),
                child: _actionRow(session, settings, reduced, haptics),
              ),
              const SizedBox(height: AllInSpace.sm),
            ],
          ),
        ),
      ),
    );
  }

  /* ------------------------------------------------------------ hero strip */

  Widget _heroStrip(
    SessionState session,
    TableMetrics metrics,
    double width,
    bool haptics,
  ) {
    final table = session.table;
    if (table == null) {
      return const SizedBox(height: HeroStrip.height);
    }
    final hero = table.players[0];
    final legal = session.legal;
    final short = HeroStrip.useShortForm(
      width: width,
      seats: table.config.seats,
      textScaler: MediaQuery.textScalerOf(context),
    );

    String? price;
    if (_dragging && _raiseTo != null) {
      price = PlayCopy.opponentPrice(opponentTimes(table, _raiseTo!));
    } else if (session.heroToAct && legal != null && legal.toCall > 0) {
      price = HeroStrip.priceLineFor(
        toCall: legal.callAmount,
        bigBlind: table.bigBlind,
        potOdds: legal.callAmount / (table.pot + legal.callAmount),
        short: short,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.margin),
      child: HeroStrip(
        position: hero.position,
        stack: hero.stack,
        bigBlind: table.bigBlind,
        seats: table.config.seats,
        isButton: table.button == 0,
        priceLine: price,
        handLabel:
            session.handOver ? heroMadeHand(table) : heroHandLabel(hero.hole),
        allIn: hero.isAllIn,
        enableHaptics: haptics,
        onTapLeft: () => _openSessionSheet(SessionSegment.session),
        onSwipeUp: () {
          ref.read(coachMarksProvider.notifier).dismiss();
          _openSessionSheet();
        },
      ),
    );
  }

  /* ----------------------------------------------------------- context row */

  Widget _contextRow(
    SessionState session,
    AppSettings settings,
    bool reduced,
    bool haptics,
  ) {
    final table = session.table;
    final notifier = ref.read(sessionProvider.notifier);
    if (table == null) {
      return const TableContextRow(mode: ContextRowMode.empty);
    }

    final legal = session.legal;
    final value = _syncRaiseTo(table, legal);
    final auto = settings.paceMode == PaceMode.auto;
    final dimmed = session.paused || session.pendingBlocking != null;
    final marks = ref.watch(coachMarksProvider);

    // ---- hero to act -----------------------------------------------------
    if (table.toAct == 0 && table.phase == GamePhase.betting) {
      final canAggro = legal != null && (legal.canBet || legal.canRaise);
      if (canAggro && !RaiseSizing.isDegenerate(legal)) {
        return TableContextRow(
          mode: ContextRowMode.rail,
          dimmed: dimmed,
          reducedMotion: reduced,
          rail: SizingRail(
            min: legal.minRaiseTo,
            max: legal.maxRaiseTo,
            detents: RaiseSizing.detents(legal, table.currentBet),
            value: value ?? legal.minRaiseTo,
            bigBlind: table.bigBlind,
            enableHaptics: haptics,
            reducedMotion: reduced,
            semanticLabel: 'Bet size',
            onChanged:
                (v) => setState(() {
                  _raiseTo = v;
                  _dragging = true;
                }),
            onChangeEnd:
                (v) => setState(() {
                  _raiseTo = v;
                  _dragging = false;
                }),
          ),
        );
      }
      // The rail hides: either nothing can be raised, or the only legal raise
      // is the shove (§4.5's degenerate case).
      final note =
          legal == null
              ? ''
              : canAggro
              ? PlayCopy.onlyOneRaiseSize(
                fmtBb(legal.maxRaiseTo, table.bigBlind),
              )
              : legal.callAmount >= table.players[0].stack
              ? PlayCopy.allInCall(
                '${fmtBb(legal.callAmount, table.bigBlind)} bb',
                '${fmtBb(table.pot + legal.callAmount, table.bigBlind)} bb',
              )
              : PlayCopy.callingInto(
                '${fmtBb(legal.callAmount, table.bigBlind)} bb',
                '${fmtBb(table.pot, table.bigBlind)} bb',
              );
      return TableContextRow(
        mode: ContextRowMode.note,
        note: note,
        dimmed: dimmed,
        reducedMotion: reduced,
      );
    }

    // ---- hand over --------------------------------------------------------
    if (session.handOver) {
      return TableContextRow(
        mode: ContextRowMode.handOver,
        canExplain: session.canExplain,
        onExplain: session.canExplain ? _explainLastMove : null,
        autoDealDeadline: session.autoDealDeadline,
        onAutoDealElapsed: notifier.deal,
        dimmed: dimmed,
        reducedMotion: reduced,
      );
    }

    // ---- bot to act (C / D), including "hero is out of the hand" ----------
    final heroOut = session.heroOutOfHand;
    final thinking = session.thinking && auto && table.toAct != null;
    final caption =
        heroOut
            ? (table.players[0].hasFolded
                ? PlayCopy.foldedPlayingOut
                : PlayCopy.allInRunningOut)
            : (!auto && marks.visible == CoachMark.step
                ? PlayCopy.stepHint
                : null);

    return TableContextRow(
      mode: ContextRowMode.waiting,
      thinkingName: thinking ? table.players[table.toAct!].name : null,
      caption: caption,
      canExplain: session.canExplain,
      onExplain: session.canExplain ? _explainLastMove : null,
      showSkip: auto || heroOut,
      skipSemanticLabel: heroOut ? PlayCopy.finishHand : PlayCopy.skipToMyTurn,
      onSkip: notifier.skipToMyTurn,
      dimmed: dimmed,
      reducedMotion: reduced,
    );
  }

  /* ------------------------------------------------------------ action row */

  Widget _actionRow(
    SessionState session,
    AppSettings settings,
    bool reduced,
    bool haptics,
  ) {
    final notifier = ref.read(sessionProvider.notifier);
    final table = session.table;
    if (table == null || !session.active) {
      return ActionRow(
        state: ActionRowState.noSession,
        enableHaptics: haptics,
        reducedMotion: reduced,
        onDealMeIn: () => notifier.newSession(),
      );
    }

    final legal = session.legal;
    final auto = settings.paceMode == PaceMode.auto;
    final heroTurn = table.toAct == 0 && table.phase == GamePhase.betting;
    final underlying =
        session.handOver
            ? ActionRowState.handOver
            : heroTurn
            ? (legal != null && (legal.canBet || legal.canRaise)
                ? ActionRowState.heroToAct
                : ActionRowState.heroToActNoRaise)
            : auto
            ? ActionRowState.botAuto
            : ActionRowState.botManual;

    // State F: a blocking note or an open surface dims the zone and makes it
    // inert; the reason is on screen (the sheet, or the ticker).
    final blocked =
        session.pendingBlocking != null ||
        (session.paused && !auto) ||
        (session.activeReview?.blocking ?? false);
    final state = blocked ? ActionRowState.paused : underlying;
    final value = _syncRaiseTo(table, legal);

    return ActionRow(
      state: state,
      underlyingState: underlying,
      legal: legal,
      bigBlind: table.bigBlind,
      heroStack: table.players[0].stack,
      raiseTo: value,
      autoPaused: auto && session.paused,
      enableHaptics: haptics,
      reducedMotion: reduced,
      onFold: () => notifier.heroAction(const poker.Action.fold()),
      onCheckCall: () {
        final la = legal;
        if (la == null) return;
        notifier.heroAction(
          la.canCheck ? const poker.Action.check() : const poker.Action.call(),
        );
      },
      onBetRaise: () {
        final la = legal;
        final amount = value;
        if (la == null || amount == null) return;
        notifier.heroAction(
          table.currentBet > 0
              ? poker.Action.raise(amount)
              : poker.Action.bet(amount),
        );
      },
      onRaiseAmountTap: () => _openKeypad(table, legal, value),
      onRaiseLongPress: () => _openKeypad(table, legal, value),
      onNextAction: () {
        ref.read(coachMarksProvider.notifier).dismiss();
        notifier.stepBot();
      },
      onNextActionHoldStart: notifier.startFastForward,
      onNextActionHoldEnd: notifier.stopFastForward,
      onPauseResume: notifier.togglePause,
      onNextHand: () {
        _recordRevealSpeed();
        notifier.deal();
      },
      onDealMeIn: () => notifier.newSession(),
    );
  }

  Future<void> _openKeypad(
    TableState table,
    LegalActions? legal,
    int? value,
  ) async {
    if (legal == null || value == null) return;
    final next = await _withSurface(
      () => BetKeypadSheet.show(
        context,
        legal: legal,
        currentBet: table.currentBet,
        value: value,
        enableHaptics: ref.read(hapticsEnabledProvider),
        reducedMotion: ref.read(reducedMotionProvider),
      ),
    );
    if (next != null && mounted) setState(() => _raiseTo = next);
  }

  /// O1 (§4.15): ask for the caption whose surface is on screen right now.
  /// `CoachMarksNotifier.request` shows only the one this hand owes, so all
  /// three can be asked for unconditionally.
  void _requestCoachMarks(SessionState session, AppSettings settings) {
    if (!mounted) return;
    final table = session.table;
    if (table == null || table.phase != GamePhase.betting) return;
    final marks = ref.read(coachMarksProvider.notifier);

    if (session.heroToAct) {
      // 3 — above the hero strip on the first hero turn.
      marks.request(CoachMark.swipe);
      return;
    }
    if (session.heroOutOfHand) return;
    if (settings.paceMode != PaceMode.auto) {
      // 1 — under the action row in State C.
      marks.request(CoachMark.step);
    }
    // 2 — next to the first eye glyph that appears.
    final anyEye = table.players.any(
      (p) => !p.isHero && !p.hasFolded && p.hole != null,
    );
    if (anyEye) marks.request(CoachMark.eye);
  }

  /// §4.12's learn-by-reveal heuristic.
  void _recordRevealSpeed() {
    final at = _handOverAt;
    if (at == null) return;
    final fast = DateTime.now().difference(at) < const Duration(seconds: 1);
    setState(() {
      if (fast) {
        _fastNextRun += 1;
        _slowNextRun = 0;
        if (_fastNextRun >= 3) _collapseResults = true;
      } else {
        _slowNextRun += 1;
        _fastNextRun = 0;
        if (_slowNextRun >= 2) _collapseResults = false;
      }
    });
  }
}

/* ------------------------------------------------------------------ bands */

/// The 18 pt ticker, plus the §14 override lines.
class _TickerBand extends ConsumerWidget {
  const _TickerBand({required this.session, required this.onTap});

  final SessionState session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = session.table;
    final marks = ref.watch(coachMarksProvider);
    final override = tickerOverrideFor(
      saveFailed: session.saveFailed,
      paused: session.paused && session.active,
    );

    // §4.2.1: the first three heads-up hands explain the button instead.
    final headsUpHint =
        session.options.seats == 2 && marks.armed
            ? kHeadsUpFirstHandsTicker
            : null;

    final entry =
        override != null
            ? LogEntry(
              id: -1,
              street: table?.street ?? Street.preflop,
              text: override,
              kind: LogKind.info,
            )
            : headsUpHint != null
            ? LogEntry(
              id: -2,
              street: table?.street ?? Street.preflop,
              text: headsUpHint,
              kind: LogKind.info,
            )
            : (table == null || table.log.isEmpty ? null : table.log.last);

    return Ticker(
      entry: entry,
      emptyText: PlayCopy.tickerEmpty,
      onTap: onTap,
      onLongPress: () {
        final log = table?.log;
        if (log == null || log.isEmpty) return;
        Clipboard.setData(
          ClipboardData(text: log.map((e) => e.text).join('\n')),
        );
        AllInToast.show(context, PlayCopy.handLogCopied);
      },
    );
  }
}

/// The 2 s "Resumed — …" caption (§4.14).
class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AllInSpace.lg,
      vertical: AllInSpace.xs,
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AllInText.body(12, color: context.colors.textFaint),
    ),
  );
}

/// The felt, the hero cards that overlap its bottom rim, and the O1 eye mark.
class _FeltBand extends ConsumerWidget {
  const _FeltBand({
    required this.session,
    required this.metrics,
    required this.settings,
    required this.reducedMotion,
    required this.enableHaptics,
    required this.coachOn,
    required this.collapseResults,
    required this.onSeatTap,
    required this.onSeatEye,
    required this.onSeatLongPress,
    required this.onActionPill,
    required this.onChipTap,
    required this.onCoachRowTap,
    required this.onDealMeIn,
    required this.onFeltTap,
    required this.onResultsTouch,
  });

  final SessionState session;
  final TableMetrics metrics;
  final AppSettings settings;
  final bool reducedMotion;
  final bool enableHaptics;
  final bool coachOn;
  final bool collapseResults;
  final SeatCallback onSeatTap;
  final SeatCallback onSeatEye;
  final SeatCallback onSeatLongPress;
  final SeatCallback onActionPill;
  final VoidCallback onChipTap;
  final VoidCallback onCoachRowTap;
  final VoidCallback onDealMeIn;
  final VoidCallback onFeltTap;
  final VoidCallback onResultsTouch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = session.table;

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = metrics.heroCardHeight;
        // The felt is the only flexible band (§4.2); it absorbs whatever the
        // fixed rows leave, never less than zero.
        final feltHeight = math.max(
          0.0,
          constraints.maxHeight - metrics.heroOverhang,
        );

        if (table == null || !session.active) {
          // State G (§4.5, §4.15).
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.margin),
            child: SizedBox(
              height: feltHeight,
              child: EmptyFelt(
                seats: session.options.seats,
                metrics: metrics,
                title: PlayCopy.readyToPlay,
                body: PlayCopy.startOverlayBody,
                actionLabel: PlayCopy.dealMeIn,
                onAction: onDealMeIn,
              ),
            ),
          );
        }

        final hero = table.players[0];
        final chip = _chipContent();
        final overlay = _overlay(context, ref, table);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: metrics.margin,
              right: metrics.margin,
              top: 0,
              height: feltHeight,
              child: TableFelt(
                table: table,
                metrics: metrics,
                thinkingSeat: session.thinking ? table.toAct : null,
                stepMode: settings.paceMode != PaceMode.auto,
                fourColorDeck: settings.fourColorDeck,
                realisticReveal: settings.realisticReveal,
                reducedMotion: reducedMotion,
                enableHaptics: enableHaptics,
                showEyes: !session.handOver,
                rebought: session.rebought,
                chip: chip,
                onChipTap: onChipTap,
                onChipSwipeUp: onChipTap,
                onChipSwipeDown:
                    () => ref.read(sessionProvider.notifier).dismissChip(),
                onSeatTap: onSeatTap,
                onSeatEye: (seat) {
                  ref.read(coachMarksProvider.notifier).dismiss();
                  onSeatEye(seat);
                },
                onSeatLongPress: onSeatLongPress,
                onActionPill: onActionPill,
                onFeltTap: onFeltTap,
                overlay: overlay,
                dimmed:
                    session.pendingBlocking != null ||
                    (session.activeReview?.blocking ?? false),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: feltHeight - TableMetrics.heroOverlap,
              height: heroHeight,
              child: Center(
                child: HeroHand(
                  cards: List<String>.of(hero.hole ?? const []),
                  size: metrics.heroCardWidth,
                  active: session.heroToAct,
                  folded: hero.hasFolded,
                  fourColorDeck: settings.fourColorDeck,
                  enableHaptics: enableHaptics,
                  reducedMotion: reducedMotion,
                ),
              ),
            ),
            if (ref.watch(visibleCoachMarkProvider) == CoachMark.eye)
              Positioned(
                left: metrics.margin,
                right: metrics.margin,
                top: feltHeight * 0.32,
                child: const Center(
                  child: CoachMarkCaption(
                    mark: CoachMark.eye,
                    pointer: CoachMarkPointer.up,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The chip content for a live, non-blocking verdict (§4.8), or the §14
  /// "coach is thinking" shimmer.
  CoachChipContent? _chipContent() {
    if (!coachOn) return null;
    if (session.coachComputing) {
      return const CoachChipContent(verdict: Verdict.info);
    }
    final review = session.activeReview;
    if (review == null || review.blocking) return null;
    return CoachChipContent(
      verdict: review.verdict,
      title: CoachChip.verdictLabel(review.verdict),
      clause: CoachChip.firstClause(review.plain ?? review.text),
    );
  }

  Widget? _overlay(BuildContext context, WidgetRef ref, TableState table) {
    final summary = table.summary;
    if (!session.handOver || summary == null) return null;
    final builder =
        ref.watch(tableOverlayBuilderProvider) ?? defaultHandOverOverlay;
    final review = session.activeReview;
    return builder(
      context,
      HandOverContext(
        table: table,
        summary: summary,
        realisticReveal: settings.realisticReveal,
        fourColorDeck: settings.fourColorDeck,
        reducedMotion: reducedMotion,
        collapsed: collapseResults,
        coach:
            coachOn && review != null && !review.blocking
                ? CoachChipContent(
                  verdict: review.verdict,
                  title: CoachChip.verdictLabel(review.verdict),
                  clause: CoachChip.firstClause(review.plain ?? review.text),
                )
                : null,
        onCoachTap: onCoachRowTap,
        onExpand: onResultsTouch,
        onRow: onSeatTap,
        onTouch: onResultsTouch,
      ),
    );
  }
}
