/// `ActionRow` — the 56 pt row in States A–G (DESIGN.md §10.3; every state,
/// label and guard is §4.5).
///
/// The row keeps its height in every state; only its contents change. Labels
/// are always the exact commit ("Bet 4.5" / "Raise to 7.5" / "All-in 100") and
/// tapping commits immediately — there is no confirm step, ever.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../engine/types.dart';
import '../../theme/typography.dart';
import '../foundations/all_in_button.dart';

/// §4.5's states. F (`paused`) dims whatever [ActionRow.underlyingState] would
/// have drawn; C and D cover "hero is out of the hand" unchanged.
enum ActionRowState {
  /// A — hero to act, can bet/raise.
  heroToAct,

  /// B — hero to act, cannot raise.
  heroToActNoRaise,

  /// C — bot to act, Manual pace.
  botManual,

  /// D — bot to act, Auto pace.
  botAuto,

  /// E — hand over.
  handOver,

  /// F — paused (blocking note up, P7 open, app backgrounded).
  paused,

  /// G — no session (deep link / after reset).
  noSession,
}

class ActionRow extends StatefulWidget {
  const ActionRow({
    super.key,
    required this.state,
    this.legal,
    this.bigBlind = 20,
    this.heroStack = 0,
    this.raiseTo,
    this.underlyingState = ActionRowState.botManual,
    this.autoPaused = false,
    this.onFold,
    this.onCheckCall,
    this.onBetRaise,
    this.onRaiseAmountTap,
    this.onRaiseLongPress,
    this.onNextAction,
    this.onNextActionHoldStart,
    this.onNextActionHoldEnd,
    this.onPauseResume,
    this.onNextHand,
    this.onDealMeIn,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final ActionRowState state;

  /// Straight from `legalActions()`; required for States A and B.
  final LegalActions? legal;
  final int bigBlind;

  /// The hero's remaining stack — decides "Call all-in 37 bb" (§4.5).
  final int heroStack;

  /// The sizing rail's current raise-to total, in chips.
  final int? raiseTo;

  /// What state F is dimming.
  final ActionRowState underlyingState;

  /// Auto pace, user-paused: the button reads "Paused · tap to resume ▶".
  final bool autoPaused;

  final VoidCallback? onFold;
  final VoidCallback? onCheckCall;
  final VoidCallback? onBetRaise;

  /// Tap the mono amount (the button's right 60 %) → P13 bet keypad (§4.5).
  final VoidCallback? onRaiseAmountTap;

  /// Long-press Raise (500 ms) → P13 bet keypad.
  final VoidCallback? onRaiseLongPress;

  final VoidCallback? onNextAction;

  /// Hold "Next action" → fast-forward at the Fast delay while held (§4.5 C).
  final VoidCallback? onNextActionHoldStart;
  final VoidCallback? onNextActionHoldEnd;
  final VoidCallback? onPauseResume;
  final VoidCallback? onNextHand;
  final VoidCallback? onDealMeIn;

  final bool enableHaptics;
  final bool reducedMotion;

  static const double height = 56;
  static const double gap = 8;

  /// Fold — and a Raise button that has just become "All-in …" — ignore taps
  /// for 150 ms after the row appears (§4.5).
  static const Duration tapGuard = Duration(milliseconds: 150);

  /// The labels drop their amounts into the hero strip at 1.3× (§4.2.4).
  ///
  /// The spec says "above 1.3×", but 1.3× is already past the row's budget at
  /// every supported width: at 411 pt the two commit buttons rendered
  /// "Call 1 …" and "Raise t…", and §4.5 makes the exact commit
  /// unconditional — "Raise to 7.5" is never "Raise to …". So the step is
  /// taken *at* 1.3× rather than one notch later.
  static bool dropAmounts(TextScaler scaler) =>
      scaler.scale(17) >= 17 * 1.3 - 0.01;

  /// Width of the "tap the amount" zone, measured from the right edge.
  ///
  /// The label is centred, so the zone is `(width − label) / 2 + amount`: the
  /// trailing gap plus the amount run itself. Never narrower than a 44 pt hit
  /// target and never wider than 35 % of the button, so the verb — and with it
  /// the button's visual centre — always commits.
  @visibleForTesting
  static double amountZoneWidth(
    TextScaler scaler,
    String label,
    double buttonWidth,
  ) {
    if (!buttonWidth.isFinite || buttonWidth <= 0) return 0;
    final ceiling = math.max(44.0, buttonWidth * 0.35);
    // The amount run is the trailing number and its unit: "7.5 bb", "100 bb".
    final match = _amountRun.firstMatch(label);
    // "Raise" / "Bet" / "All-in" with the amount dropped (§4.2.3): there is no
    // amount to aim at, so the zone falls back to its ceiling.
    if (match == null) return math.min(ceiling, buttonWidth);
    final amount = match.group(0)!;

    final style = AllInText.body(17, weight: FontWeight.w600, height: 1.1);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final full = math.min(measure(label), buttonWidth);
    final zone = (buttonWidth - full) / 2 + measure(amount);
    return zone.clamp(
      math.min(44.0, buttonWidth),
      math.min(ceiling, buttonWidth),
    );
  }

  static final RegExp _amountRun = RegExp(r'\d[\d.]*(?: bb)?$');

  @override
  State<ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<ActionRow> {
  bool _guarded = true;
  bool _allInGuarded = false;
  Timer? _rowTimer;
  Timer? _allInTimer;
  String? _lastRaiseLabel;

  @override
  void initState() {
    super.initState();
    _armRowGuard();
  }

  @override
  void didUpdateWidget(ActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _armRowGuard();
  }

  @override
  void dispose() {
    _rowTimer?.cancel();
    _allInTimer?.cancel();
    super.dispose();
  }

  /// §4.5: the row swallows a tap meant for the state it replaced.
  void _armRowGuard() {
    _rowTimer?.cancel();
    _guarded = true;
    _rowTimer = Timer(ActionRow.tapGuard, () {
      if (mounted) setState(() => _guarded = false);
    });
  }

  void _armAllInGuard() {
    _allInTimer?.cancel();
    _allInGuarded = true;
    _allInTimer = Timer(ActionRow.tapGuard, () {
      if (mounted) setState(() => _allInGuarded = false);
    });
  }

  String _bb(num chips) => fmtBb(chips, widget.bigBlind);

  String _callLabel(LegalActions legal, bool dropAmounts) {
    if (legal.canCheck) return 'Check';
    final commitsStack =
        widget.heroStack > 0 && legal.callAmount >= widget.heroStack;
    if (dropAmounts) return commitsStack ? 'Call all-in' : 'Call';
    return commitsStack
        ? 'Call all-in ${_bb(legal.callAmount)} bb'
        : 'Call ${_bb(legal.callAmount)} bb';
  }

  /// §4.5 / DESIGN.md:1839 write these as "Call 2.5 bb" / "Raise to 7.5 bb".
  /// "Call" kept its unit while "Raise to 2.7", "Bet 4.5" and "All-in 100"
  /// dropped it — inside the same row, next to a felt that says "Pot 4 bb". A
  /// beginner reading "Raise to 2.7" has no idea 2.7 of what. The narrow-width
  /// `dropAmounts` fallback (§4.2.3) still drops the number entirely.
  String _raiseLabel(LegalActions legal, bool dropAmounts) {
    final to = widget.raiseTo ?? legal.minRaiseTo;
    final isAllIn = to >= legal.maxRaiseTo;
    if (isAllIn) return dropAmounts ? 'All-in' : 'All-in ${_bb(to)} bb';
    if (legal.canBet && legal.toCall == 0) {
      return dropAmounts ? 'Bet' : 'Bet ${_bb(to)} bb';
    }
    return dropAmounts ? 'Raise' : 'Raise to ${_bb(to)} bb';
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = widget.state == ActionRowState.paused;
    final state = dimmed ? widget.underlyingState : widget.state;

    final row = SizedBox(
      height: ActionRow.height,
      child: switch (state) {
        ActionRowState.heroToAct ||
        ActionRowState.heroToActNoRaise => _heroRow(state),
        ActionRowState.botManual => _fullWidth(
          label: 'Next action  ›',
          variant: AllInButtonVariant.secondary,
          onPressed: widget.onNextAction,
          onLongPressStart: widget.onNextActionHoldStart,
          onLongPressEnd: widget.onNextActionHoldEnd,
        ),
        ActionRowState.botAuto => _fullWidth(
          label:
              widget.autoPaused
                  ? 'Paused · tap to resume ▶'
                  : 'Pause · tap the table',
          variant: AllInButtonVariant.secondary,
          onPressed: widget.onPauseResume,
        ),
        ActionRowState.handOver => _fullWidth(
          label: 'Next hand  ›',
          variant: AllInButtonVariant.primary,
          onPressed: widget.onNextHand,
        ),
        ActionRowState.noSession => _fullWidth(
          label: 'Deal me in',
          variant: AllInButtonVariant.primary,
          onPressed: widget.onDealMeIn,
        ),
        // F never nests: `underlyingState` is never `paused`.
        ActionRowState.paused => const SizedBox.shrink(),
      },
    );

    if (!dimmed) return row;
    return IgnorePointer(child: Opacity(opacity: 0.40, child: row));
  }

  Widget _fullWidth({
    required String label,
    required AllInButtonVariant variant,
    VoidCallback? onPressed,
    VoidCallback? onLongPressStart,
    VoidCallback? onLongPressEnd,
  }) {
    final button = AllInButton(
      label: label,
      variant: variant,
      size: AllInButtonSize.lg,
      expand: true,
      onPressed: onPressed,
      enableHaptics: widget.enableHaptics,
      reducedMotion: widget.reducedMotion,
    );
    if (onLongPressStart == null && onLongPressEnd == null) return button;
    return GestureDetector(
      onLongPressStart: (_) => onLongPressStart?.call(),
      onLongPressEnd: (_) => onLongPressEnd?.call(),
      onLongPressCancel: onLongPressEnd,
      child: button,
    );
  }

  Widget _heroRow(ActionRowState state) {
    final legal = widget.legal;
    if (legal == null) return const SizedBox.shrink();

    final scaler = MediaQuery.textScalerOf(context);
    final drop = ActionRow.dropAmounts(scaler);
    final showFold = legal.canFold && legal.toCall > 0;
    final showRaise =
        state == ActionRowState.heroToAct && (legal.canBet || legal.canRaise);

    final callLabel = _callLabel(legal, drop);
    final call = AllInButton(
      label: callLabel,
      variant: AllInButtonVariant.secondary,
      size: AllInButtonSize.lg,
      expand: true,
      semanticLabel:
          legal.canCheck ? 'Check' : 'Call ${_bb(legal.callAmount)} big blinds',
      onPressed: widget.onCheckCall,
      enableHaptics: widget.enableHaptics,
      reducedMotion: widget.reducedMotion,
    );

    final children = <Widget>[];

    if (showFold) {
      children.add(
        Expanded(
          flex: 28,
          child: AllInButton(
            label: 'Fold',
            variant: AllInButtonVariant.danger,
            size: AllInButtonSize.lg,
            expand: true,
            semanticLabel: 'Fold',
            // The button stays live-looking; the guard swallows the tap.
            onPressed: () {
              if (_guarded) return;
              widget.onFold?.call();
            },
            enableHaptics: widget.enableHaptics,
            reducedMotion: widget.reducedMotion,
          ),
        ),
      );
    }

    if (showRaise) {
      final raiseLabel = _raiseLabel(legal, drop);
      final isAllIn = raiseLabel.startsWith('All-in');
      if (isAllIn &&
          _lastRaiseLabel != null &&
          !_lastRaiseLabel!.startsWith('All-in')) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _armAllInGuard());
      }
      _lastRaiseLabel = raiseLabel;

      if (children.isNotEmpty) {
        children.add(const SizedBox(width: ActionRow.gap));
      }
      children.add(Expanded(flex: showFold ? 34 : 45, child: call));
      children.add(const SizedBox(width: ActionRow.gap));
      children.add(
        Expanded(
          flex: showFold ? 38 : 55,
          child: _RaiseButton(
            label: raiseLabel,
            semanticLabel: '$raiseLabel big blinds',
            onPressed: () {
              if (isAllIn && _allInGuarded) return;
              widget.onBetRaise?.call();
            },
            onAmountTap: widget.onRaiseAmountTap,
            onLongPress: widget.onRaiseLongPress,
            enableHaptics: widget.enableHaptics,
            reducedMotion: widget.reducedMotion,
          ),
        ),
      );
    } else {
      _lastRaiseLabel = null;
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: ActionRow.gap));
      }
      // Facing an all-in (or B): Call grows to fill the remaining width.
      children.add(Expanded(flex: showFold ? 72 : 100, child: call));
    }

    return Row(children: children);
  }
}

/// The gold commit button, plus §4.5's "tap the amount → keypad" zone.
class _RaiseButton extends StatelessWidget {
  const _RaiseButton({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.onAmountTap,
    this.onLongPress,
    required this.enableHaptics,
    required this.reducedMotion,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;
  final VoidCallback? onAmountTap;
  final VoidCallback? onLongPress;
  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final button = AllInButton(
      label: label,
      variant: AllInButtonVariant.primary,
      size: AllInButtonSize.lg,
      expand: true,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      enableHaptics: enableHaptics,
      reducedMotion: reducedMotion,
    );

    final withLongPress =
        onLongPress == null
            ? button
            : GestureDetector(onLongPress: onLongPress, child: button);

    if (onAmountTap == null) return withLongPress;

    // §4.5's "tap the amount" opens P13 — but only over the *amount*.
    //
    // The zone used to be the right 60 % of an opaque button whose label is
    // centred, so the visual centre of "Bet 3" / "Raise to 4" — the natural
    // thumb target — landed inside it and opened a sheet instead of
    // committing. On the two-button row the button is ~203 dp wide, the zone
    // started at 81 dp and the centred label spanned ~70–134 dp.
    //
    // The zone is now measured: it runs from the right edge back to the start
    // of the amount run, so the verb (and the button's visual centre) always
    // belongs to the commit action. Long-press anywhere is still the second
    // way into P13.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: withLongPress),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: ActionRow.amountZoneWidth(
                    MediaQuery.maybeTextScalerOf(context) ??
                        TextScaler.noScaling,
                    label,
                    constraints.maxWidth,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAmountTap,
                    onLongPress: onLongPress,
                    child: Semantics(
                      button: true,
                      label: 'Edit raise size',
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
