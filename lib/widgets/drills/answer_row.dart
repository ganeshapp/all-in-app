/// `AnswerRow` — the 56 pt row of 2–3 drill options (DESIGN.md §5.1, §5.3,
/// §10.6).
///
/// Labels come **verbatim** from `option.label`; the row never composes one
/// (§15.2). Widths follow the table's action row: 28 / 34 / 38 % for three
/// options, 50 / 50 for two, fold leftmost and the aggressive action rightmost.
/// After an answer every option locks: accepted ones turn `good`, a wrong pick
/// turns `bad`, the rest dim (desktop `DrillControls`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/types.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class AnswerRow extends StatelessWidget {
  const AnswerRow({
    super.key,
    required this.options,
    required this.onAnswer,
    this.answered,
    this.accepted = const <DrillAction>[],
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  /// The puzzle's options, in the engine's order.
  final List<DrillOption> options;

  /// Fires once; the row locks afterwards.
  final ValueChanged<DrillAction> onAnswer;

  /// The chosen action, or null while unanswered.
  final DrillAction? answered;

  /// `GradeResult.accept` once answered.
  final List<DrillAction> accepted;

  final bool enableHaptics;
  final bool reducedMotion;

  static const double height = 56;
  static const double gap = 8;

  /// §5.1: three options take 28 / 34 / 38 %, two take half each.
  static List<int> flexFor(int count) =>
      count >= 3 ? const [28, 34, 38] : const [50, 50];

  @override
  Widget build(BuildContext context) {
    final flex = flexFor(options.length);
    final locked = answered != null;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              flex: i < flex.length ? flex[i] : 33,
              child: _AnswerButton(
                option: options[i],
                state: _stateFor(options[i].action, locked),
                onTap: locked ? null : () => _commit(options[i].action),
                reducedMotion: reducedMotion,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _commit(DrillAction action) {
    if (enableHaptics) HapticFeedback.mediumImpact();
    onAnswer(action);
  }

  _AnswerState _stateFor(DrillAction action, bool locked) {
    if (!locked) {
      return switch (action) {
        DrillAction.fold => _AnswerState.fold,
        DrillAction.check || DrillAction.call => _AnswerState.passive,
        DrillAction.bet || DrillAction.raise => _AnswerState.aggressive,
      };
    }
    if (accepted.contains(action)) return _AnswerState.correct;
    if (answered == action) return _AnswerState.wrong;
    return _AnswerState.dimmed;
  }
}

enum _AnswerState { fold, passive, aggressive, correct, wrong, dimmed }

class _AnswerButton extends StatefulWidget {
  const _AnswerButton({
    required this.option,
    required this.state,
    required this.onTap,
    required this.reducedMotion,
  });

  final DrillOption option;
  final _AnswerState state;
  final VoidCallback? onTap;
  final bool reducedMotion;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fill, Color fg, Color? border) = switch (widget.state) {
      _AnswerState.fold => (c.ink700, c.bad, c.bad.withValues(alpha: 0.4)),
      _AnswerState.passive => (c.ink600, c.text, null),
      _AnswerState.aggressive => (c.gold, AllInColors.dark.ink900, null),
      _AnswerState.correct => (c.good.withValues(alpha: 0.18), c.good, c.good),
      _AnswerState.wrong => (c.bad.withValues(alpha: 0.18), c.bad, c.bad),
      _AnswerState.dimmed => (c.ink700, c.textFaint, c.line),
    };

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: _semanticLabel(widget.option.label),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown:
              widget.onTap == null ? null : (_) => setState(() => _down = true),
          onTapCancel:
              widget.onTap == null ? null : () => setState(() => _down = false),
          onTapUp:
              widget.onTap == null
                  ? null
                  : (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: AllInMotion.of(
              context,
              const Duration(milliseconds: 120),
              reduced: widget.reducedMotion,
            ),
            curve: AllInMotion.ease,
            child: AnimatedContainer(
              duration: AllInMotion.of(
                context,
                const Duration(milliseconds: 120),
                reduced: widget.reducedMotion,
              ),
              height: AnswerRow.height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AllInRadius.md),
                border:
                    border == null ? null : Border.all(color: border, width: 1),
              ),
              child: Text(
                widget.option.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AllInText.body(
                  17,
                  weight: FontWeight.w600,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// §13: "Call 2 bb" reads as "Call 2 big blinds".
String _semanticLabel(String label) => label.replaceAll(' bb', ' big blinds');
