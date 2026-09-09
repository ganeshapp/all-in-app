/// The 48 pt context row (DESIGN.md §4.5). It never changes height — only its
/// contents — so the felt never jumps:
///
/// * **A** the sizing rail, or the muted price line when nothing can be raised,
///   or §4.5's "Only one raise size" line when the rail is degenerate;
/// * **C** ghost "Explain last move" + a caption (+ `⏭` once the hero is out);
/// * **D** a spinner and "{name} is thinking…" + `⏭`;
/// * **E** ghost "Explain last move" + the auto-deal countdown;
/// * **F** the whole row at 40 % and inert.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:flutter/material.dart';

/// Which shape the row takes. Derived by the table screen from the engine.
enum ContextRowMode { rail, note, waiting, handOver, empty }

class TableContextRow extends StatelessWidget {
  const TableContextRow({
    super.key,
    required this.mode,
    this.rail,
    this.note,
    this.caption,
    this.thinkingName,
    this.canExplain = false,
    this.onExplain,
    this.showSkip = false,
    this.skipSemanticLabel = PlayCopy.skipToMyTurn,
    this.onSkip,
    this.autoDealDeadline,
    this.onAutoDealElapsed,
    this.dimmed = false,
    this.reducedMotion = false,
  });

  final ContextRowMode mode;

  /// The `SizingRail`, already built by the caller (it owns the value).
  final Widget? rail;

  /// The muted line for the price / degenerate-rail forms.
  final String? note;

  /// The §4.5 C/D caption beside "Explain last move".
  final String? caption;

  /// Auto pace: the thinking bot's name.
  final String? thinkingName;

  final bool canExplain;
  final VoidCallback? onExplain;

  final bool showSkip;
  final String skipSemanticLabel;
  final VoidCallback? onSkip;

  /// Epoch ms the auto-deal countdown ends (§4.5 E).
  final int? autoDealDeadline;
  final VoidCallback? onAutoDealElapsed;

  final bool dimmed;
  final bool reducedMotion;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: switch (mode) {
        ContextRowMode.rail => rail ?? const SizedBox.shrink(),
        ContextRowMode.note => _note(context, note ?? ''),
        ContextRowMode.waiting => _waiting(context),
        ContextRowMode.handOver => _handOver(context),
        ContextRowMode.empty => const SizedBox.expand(),
      },
    );
    if (!dimmed) return row;
    return IgnorePointer(child: Opacity(opacity: 0.40, child: row));
  }

  Widget _note(BuildContext context, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: AllInText.body(13, color: context.colors.textMuted),
      ),
    ),
  );

  Widget _waiting(BuildContext context) {
    final c = context.colors;
    final name = thinkingName;
    return Row(
      children: [
        if (name != null) ...[
          _Spinner(reducedMotion: reducedMotion),
          const SizedBox(width: AllInSpace.sm),
          Flexible(
            child: Text(
              '$name is thinking…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AllInText.body(13, color: c.textMuted),
            ),
          ),
          const SizedBox(width: AllInSpace.sm),
        ],
        if (canExplain) _GhostExplain(onPressed: onExplain),
        if (name == null && caption != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AllInSpace.sm),
              child: Text(
                caption!,
                maxLines: 2,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: AllInText.body(12, color: c.textFaint),
              ),
            ),
          )
        else
          const Spacer(),
        if (showSkip) _SkipButton(label: skipSemanticLabel, onPressed: onSkip),
      ],
    );
  }

  Widget _handOver(BuildContext context) {
    final deadline = autoDealDeadline;
    return Row(
      children: [
        if (canExplain) _GhostExplain(onPressed: onExplain),
        const Spacer(),
        if (deadline != null)
          _Countdown(
            deadline: deadline,
            reducedMotion: reducedMotion,
            onElapsed: onAutoDealElapsed,
          ),
      ],
    );
  }
}

/// The ghost "◉ Explain last move" button — 44 pt tall (§4.5 C/D/E).
class _GhostExplain extends StatelessWidget {
  const _GhostExplain({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: PlayCopy.explainLastMove,
      child: Opacity(
        opacity: enabled ? 1 : 0.40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.md),
            onTap: onPressed,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.adjust_rounded, size: 16, color: c.gold),
                  const SizedBox(width: 6),
                  Text(
                    PlayCopy.explainLastMove,
                    maxLines: 1,
                    style: AllInText.body(13, color: c.gold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `⏭` — 44×44 (§4.5 D, and §4.5 C once the hero is out of the hand).
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.md),
            onTap: onPressed,
            child: Icon(Icons.skip_next_rounded, size: 22, color: c.textMuted),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.reducedMotion});

  final bool reducedMotion;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced =
        AllInMotion.of(
          context,
          AllInMotion.base,
          reduced: widget.reducedMotion,
        ) ==
        Duration.zero;
    final dot = Icon(Icons.circle_outlined, size: 16, color: c.textMuted);
    if (reduced) {
      if (_controller.isAnimating) _controller.stop();
      return dot;
    }
    if (!_controller.isAnimating) _controller.repeat();
    return RotationTransition(turns: _controller, child: dot);
  }
}

/// The 3 s auto-deal ring; a static counting caption under reduced motion.
class _Countdown extends StatefulWidget {
  const _Countdown({
    required this.deadline,
    required this.reducedMotion,
    this.onElapsed,
  });

  final int deadline;
  final bool reducedMotion;
  final VoidCallback? onElapsed;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  double _fraction = 1;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final left = widget.deadline - DateTime.now().millisecondsSinceEpoch;
    final clamped = left.clamp(0, 3000);
    if (!mounted) return;
    setState(() {
      _fraction = clamped / 3000;
      _seconds = (clamped / 1000).ceil();
    });
    if (left <= 0) {
      _timer?.cancel();
      widget.onElapsed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced =
        AllInMotion.of(
          context,
          AllInMotion.base,
          reduced: widget.reducedMotion,
        ) ==
        Duration.zero;
    final label = '$_seconds s';
    if (reduced) {
      return Semantics(
        liveRegion: true,
        label: 'Next hand in $label',
        child: Text(label, style: AllInText.mono(13, color: c.textMuted)),
      );
    }
    return Semantics(
      label: 'Next hand in $label',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: CustomPaint(
            size: const Size(24, 24),
            painter: _RingPainter(fraction: _fraction, color: c.gold),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Text(
                  '$_seconds',
                  style: AllInText.mono(11, color: c.textMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color;
    canvas.drawArc(
      rect.deflate(1),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
