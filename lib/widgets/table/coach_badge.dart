/// `CoachBadge` — the top bar's `[◉ 3]` (DESIGN.md §10.3; behaviour §4.8).
///
/// Count = notes this hand; the disc takes the latest verdict's colour. Hidden
/// entirely when the coach is off, which is the caller's decision.
library;

import 'package:flutter/material.dart';

import '../../engine/coach.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'coach_chip.dart';

class CoachBadge extends StatefulWidget {
  const CoachBadge({
    super.key,
    required this.count,
    this.verdict,
    this.onTap,
    this.pulse = false,
    this.reducedMotion = false,
  });

  /// Notes recorded for this hand.
  final int count;

  /// Latest verdict; null before the first note.
  final Verdict? verdict;

  /// Tap → P4 Coach notes list.
  final VoidCallback? onTap;

  /// A blocking verdict queued behind an open sheet pulses the badge once
  /// (§4.8).
  final bool pulse;
  final bool reducedMotion;

  static const double size = 44;

  @override
  State<CoachBadge> createState() => _CoachBadgeState();
}

class _CoachBadgeState extends State<CoachBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(CoachBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !oldWidget.pulse) {
      final reduced =
          AllInMotion.of(
            context,
            AllInMotion.base,
            reduced: widget.reducedMotion,
          ) ==
          Duration.zero;
      if (!reduced) _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone =
        widget.verdict == null
            ? c.textMuted
            : CoachChip.verdictColor(context, widget.verdict!);

    return Semantics(
      button: true,
      label: 'Coach notes, ${widget.count}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: CoachBadge.size,
            height: CoachBadge.size,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder:
                    (context, child) => Transform.scale(
                      scale: 1 + 0.14 * (1 - (2 * _controller.value - 1).abs()),
                      child: child,
                    ),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: c.ink700,
                    borderRadius: BorderRadius.circular(AllInRadius.pill),
                    border: Border.all(
                      color: tone.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tone,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.count}',
                          style: AllInText.mono(12, color: c.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
