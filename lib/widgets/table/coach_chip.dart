/// `CoachChip` — the 300×40 verdict chip in the felt's chip zone (DESIGN.md
/// §10.3; behaviour, copy and haptics §4.8; the "coach is computing" form is
/// §14).
///
/// Content is `label · first clause of layer 1`, so a beginner learns something
/// without tapping. Coach copy is never paraphrased — pass the engine's
/// `plain ?? text` through [CoachChip.firstClause].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/coach.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The chip's payload, reused verbatim by the results card's coach row (§4.12).
class CoachChipContent {
  const CoachChipContent({required this.verdict, this.title, this.clause});

  final Verdict verdict;

  /// "Your call · River" — carried for semantics and the results row.
  final String? title;

  /// The first clause of layer 1.
  final String? clause;
}

class CoachChip extends StatefulWidget {
  const CoachChip({
    super.key,
    required this.verdict,
    this.title,
    this.clause,
    this.onTap,
    this.onSwipeUp,
    this.onSwipeDown,
    this.width = 300,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : computing = false;

  /// §14: the ≤ 1.5 s "coach is computing" form. Reduced motion replaces the
  /// shimmer with the static caption "Coach is working…".
  const CoachChip.computing({
    super.key,
    this.width = 300,
    this.reducedMotion = false,
  }) : verdict = Verdict.info,
       title = null,
       clause = null,
       onTap = null,
       onSwipeUp = null,
       onSwipeDown = null,
       enableHaptics = false,
       computing = true;

  final Verdict verdict;
  final String? title;
  final String? clause;

  /// Tap → P3 at M.
  final VoidCallback? onTap;

  /// Swipe up → P3 at L.
  final VoidCallback? onSwipeUp;

  /// Swipe down → dismiss to the badge.
  final VoidCallback? onSwipeDown;

  /// 300 at 390; 274 at 360; 330 at 430 (§4.2.3).
  final double width;
  final bool enableHaptics;
  final bool reducedMotion;
  final bool computing;

  static const double height = 40;

  /// Desktop `META` labels (§4.8).
  static String verdictLabel(Verdict verdict) => switch (verdict) {
    Verdict.mistake => 'Mistake',
    Verdict.thin => 'Thin spot',
    Verdict.ok => 'Reasonable',
    Verdict.great => 'Nice play',
    Verdict.info => 'Read',
  };

  /// Verdict colours (§16.5). Gold is never a verdict colour.
  static Color verdictColor(BuildContext context, Verdict verdict) {
    final c = context.colors;
    return switch (verdict) {
      Verdict.mistake => c.bad,
      Verdict.thin => c.warn,
      Verdict.ok => c.info,
      Verdict.great => c.good,
      Verdict.info => c.info,
    };
  }

  /// §13: every verdict colour pairs with an icon and a word.
  static IconData verdictIcon(Verdict verdict) => switch (verdict) {
    Verdict.mistake => Icons.close_rounded,
    Verdict.thin => Icons.info_outline_rounded,
    Verdict.ok => Icons.check_rounded,
    Verdict.great => Icons.check_rounded,
    Verdict.info => Icons.visibility_outlined,
  };

  /// The first clause of layer 1: cut at the first " — ", ";" or full stop.
  static String firstClause(String text) {
    final match = RegExp(r'( — |;|\.(\s|$))').firstMatch(text);
    final cut = match == null ? text : text.substring(0, match.start);
    return cut.trim();
  }

  @override
  State<CoachChip> createState() => _CoachChipState();
}

class _CoachChipState extends State<CoachChip> {
  @override
  void initState() {
    super.initState();
    if (!widget.computing && widget.enableHaptics) {
      // §4.8: great/ok light · thin medium · mistake notification.warning.
      switch (widget.verdict) {
        case Verdict.mistake:
          HapticFeedback.heavyImpact();
        case Verdict.thin:
          HapticFeedback.mediumImpact();
        case Verdict.ok:
        case Verdict.great:
        case Verdict.info:
          HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (widget.computing) {
      return SizedBox(
        width: widget.width,
        height: CoachChip.height,
        child: Center(child: _Computing(reducedMotion: widget.reducedMotion)),
      );
    }

    final tone = CoachChip.verdictColor(context, widget.verdict);
    final label = CoachChip.verdictLabel(widget.verdict);
    final clause = widget.clause ?? widget.title ?? '';

    final chip = Container(
      width: widget.width,
      height: CoachChip.height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.ink800.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AllInRadius.md),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: AllInColors.dark.shadowColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          VerdictDisc(verdict: widget.verdict, size: 24),
          const SizedBox(width: AllInSpace.sm),
          Expanded(
            child: Text(
              clause.isEmpty ? label : '$label · $clause',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AllInText.body(13, color: c.text, height: 1.2),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
        ],
      ),
    );

    final entrance = _SpringIn(
      reducedMotion: widget.reducedMotion,
      child: chip,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      button: widget.onTap != null,
      label: [
        label,
        if (widget.title != null) widget.title!,
        if (clause.isNotEmpty) clause,
      ].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            final dy = details.velocity.pixelsPerSecond.dy;
            if (dy < -200) {
              widget.onSwipeUp?.call();
            } else if (dy > 200) {
              widget.onSwipeDown?.call();
            }
          },
          child: entrance,
        ),
      ),
    );
  }
}

/// The verdict disc: colour + icon, never colour alone (§13).
class VerdictDisc extends StatelessWidget {
  const VerdictDisc({super.key, required this.verdict, this.size = 24});

  final Verdict verdict;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = CoachChip.verdictColor(context, verdict);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.withValues(alpha: 0.16),
        border: Border.all(color: tone.withValues(alpha: 0.55), width: 1),
      ),
      child: Icon(
        CoachChip.verdictIcon(verdict),
        size: size * 0.62,
        color: tone,
      ),
    );
  }
}

/// §11: spring scale 0.9 → 1 over 260 ms; reduced motion appears in place.
class _SpringIn extends StatefulWidget {
  const _SpringIn({required this.child, required this.reducedMotion});

  final Widget child;
  final bool reducedMotion;

  @override
  State<_SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<_SpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        AllInMotion.of(
          context,
          const Duration(milliseconds: 260),
          reduced: widget.reducedMotion,
        ) ==
        Duration.zero;
    if (reduced) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.9,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: AllInMotion.ease)),
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

class _Computing extends StatefulWidget {
  const _Computing({required this.reducedMotion});

  final bool reducedMotion;

  @override
  State<_Computing> createState() => _ComputingState();
}

class _ComputingState extends State<_Computing>
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

    if (reduced) {
      if (_controller.isAnimating) _controller.stop();
      return Text(
        'Coach is working…',
        style: AllInText.body(13, color: c.textMuted),
      );
    }
    if (!_controller.isAnimating) _controller.repeat();

    return Semantics(
      label: 'Coach is working',
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Opacity(
                    opacity: 0.30 + 0.70 * _pulse(i, _controller.value),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
  }

  double _pulse(int index, double t) {
    final phase = (t - index / 3) % 1.0;
    return phase < 0.34 ? 1 - (phase / 0.34) : 0;
  }
}
