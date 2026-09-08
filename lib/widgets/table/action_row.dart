/// `ActionRow` — the 56 pt row in States A–G (DESIGN.md §10.3; every state,
/// label and guard is §4.5).
///
/// The row keeps its height in every state; only its contents change. Labels
/// are always the exact commit ("Bet 4.5" / "Raise to 7.5" / "All-in 100") and
/// tapping commits immediately — there is no confirm step, ever.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/format.dart';
import '../../engine/types.dart';
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

  /// Above 1.3× the labels drop their amounts into the hero strip (§4.2.4).
  static bool dropAmounts(TextScaler scaler) => scaler.scale(17) > 17 * 1.3;

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

  String _raiseLabel(LegalActions legal, bool dropAmounts) {
    final to = widget.raiseTo ?? legal.minRaiseTo;
    final isAllIn = to >= legal.maxRaiseTo;
    if (isAllIn) return dropAmounts ? 'All-in' : 'All-in ${_bb(to)}';
    if (legal.canBet && legal.toCall == 0) {
      return dropAmounts ? 'Bet' : 'Bet ${_bb(to)}';
    }
    return dropAmounts ? 'Raise' : 'Raise to ${_bb(to)}';
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

    return Stack(
      children: [
        Positioned.fill(child: withLongPress),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.6,
              heightFactor: 1,
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
  }
}
