/// `StatsStrip` — the Drills scoreboard line (DESIGN.md §5.1, §5.4, §10.6).
///
/// Line 1 (32 pt, mono): "Rating {n}" in gold · "{acc} %" · "streak {n}" ·
/// "best {n}"; every stat is a 44-tall target that opens D3. Line 2: the Today
/// ring + "{min(today,20)}/20 today" (gold when met) and "Day streak {n}",
/// hidden at 0. At 360 the two lines merge into one (§5.1's band table). In
/// Review mode the whole strip is replaced by "Review · {n} due · {n}
/// scheduled".
///
/// Motion (§11): the rating delta flies to the strip 600 ms after the verdict
/// and the number rolls over 200 ms; a correct answer pulses the streak, a
/// wrong one shakes it as it resets.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Which stat a tap opened D3 for.
enum DrillStat { rating, accuracy, streak, best, today, dayStreak }

class StatsStrip extends StatefulWidget {
  const StatsStrip({
    super.key,
    required this.rating,
    required this.accuracy,
    required this.streak,
    required this.best,
    required this.todayDrills,
    required this.dayStreak,
    this.merged = false,
    this.onStatTap,
    this.answerToken = 0,
    this.lastAnswerCorrect,
    this.reducedMotion = false,
  }) : reviewDue = null,
       reviewScheduled = null;

  /// Review mode: "Review · {due} due · {scheduled} scheduled" (§5.1).
  const StatsStrip.review({
    super.key,
    required int due,
    required int scheduled,
    this.reducedMotion = false,
  }) : reviewDue = due,
       reviewScheduled = scheduled,
       rating = 0,
       accuracy = 0,
       streak = 0,
       best = 0,
       todayDrills = 0,
       dayStreak = 0,
       merged = false,
       onStatTap = null,
       answerToken = 0,
       lastAnswerCorrect = null;

  final double rating;
  final int accuracy;
  final int streak;
  final int best;
  final int todayDrills;
  final int dayStreak;

  /// One 32 pt line instead of two (360×780, §5.1).
  final bool merged;
  final ValueChanged<DrillStat>? onStatTap;

  /// Bumped once per answer; drives the rating roll and the streak pulse.
  final int answerToken;
  final bool? lastAnswerCorrect;
  final bool reducedMotion;

  final int? reviewDue;
  final int? reviewScheduled;

  /// The daily goal (§3.3, §5.4).
  static const int dailyGoal = 20;

  /// §11: the delta flies for 600 ms before the number rolls.
  static const Duration ratingDelay = Duration(milliseconds: 600);
  static const Duration ratingRoll = Duration(milliseconds: 200);
  static const Duration streakPulse = Duration(milliseconds: 200);

  @override
  State<StatsStrip> createState() => _StatsStripState();
}

class _StatsStripState extends State<StatsStrip>
    with SingleTickerProviderStateMixin {
  late double _shownRating = widget.rating;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: StatsStrip.streakPulse,
  );

  @override
  void didUpdateWidget(StatsStrip old) {
    super.didUpdateWidget(old);
    if (widget.rating != old.rating) {
      final reduced = _reduced;
      if (reduced) {
        _shownRating = widget.rating;
      } else {
        Future<void>.delayed(StatsStrip.ratingDelay, () {
          if (mounted) setState(() => _shownRating = widget.rating);
        });
      }
    }
    if (widget.answerToken != old.answerToken && !_reduced) {
      _pulse.forward(from: 0);
    }
  }

  bool get _reduced =>
      widget.reducedMotion ||
      MediaQuery.maybeDisableAnimationsOf(context) == true;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.reviewDue != null) {
      return SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Review · ${widget.reviewDue} due · '
            '${widget.reviewScheduled} scheduled',
            style: AllInText.mono(13, color: c.textMuted),
          ),
        ),
      );
    }

    final metGoal = widget.todayDrills >= StatsStrip.dailyGoal;
    final today = math.min(widget.todayDrills, StatsStrip.dailyGoal);

    final ratingChip = _Stat(
      onTap: () => widget.onStatTap?.call(DrillStat.rating),
      semanticLabel: 'Rating ${widget.rating.round()}',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _shownRating),
        duration: AllInMotion.of(
          context,
          StatsStrip.ratingRoll,
          reduced: widget.reducedMotion,
        ),
        builder:
            (context, value, _) => Text(
              'Rating ${value.round()}',
              style: AllInText.mono(13, color: c.gold),
            ),
      ),
    );

    final accuracy = _Stat(
      onTap: () => widget.onStatTap?.call(DrillStat.accuracy),
      semanticLabel: '${widget.accuracy} per cent accuracy',
      child: Text(
        '${widget.accuracy} %',
        style: AllInText.mono(13, color: c.textMuted),
      ),
    );

    final streak = _Stat(
      onTap: () => widget.onStatTap?.call(DrillStat.streak),
      semanticLabel: 'Streak ${widget.streak}, best ${widget.best}',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          final wrong = widget.lastAnswerCorrect == false;
          final dx = wrong ? math.sin(t * math.pi * 3) * 4 * (1 - t) : 0.0;
          final scale = wrong ? 1.0 : 1 + math.sin(t * math.pi) * 0.12;
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Text(
          widget.merged
              ? '${widget.streak}/${widget.best}'
              : 'streak ${widget.streak} · best ${widget.best}',
          style: AllInText.mono(13, color: c.textMuted),
        ),
      ),
    );

    final todayStat = _Stat(
      onTap: () => widget.onStatTap?.call(DrillStat.today),
      semanticLabel:
          '$today of ${StatsStrip.dailyGoal} drills today'
          '${widget.dayStreak > 0 ? ', day streak ${widget.dayStreak}' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TodayRing(
            value: today / StatsStrip.dailyGoal,
            color: metGoal ? c.gold : c.textMuted,
          ),
          const SizedBox(width: AllInSpace.sm),
          Text(
            '$today/${StatsStrip.dailyGoal}${widget.merged ? '' : ' today'}',
            style: AllInText.mono(13, color: metGoal ? c.gold : c.textMuted),
          ),
        ],
      ),
    );

    if (widget.merged) {
      return SizedBox(
        height: 32,
        child: Row(
          children: [
            Flexible(child: ratingChip),
            _dot(c),
            Flexible(child: accuracy),
            _dot(c),
            Flexible(child: streak),
            _dot(c),
            Flexible(child: todayStat),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Flexible(child: ratingChip),
              _dot(c),
              Flexible(child: accuracy),
              _dot(c),
              Flexible(child: streak),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              todayStat,
              if (widget.dayStreak > 0) ...[
                _dot(c),
                _Stat(
                  onTap: () => widget.onStatTap?.call(DrillStat.dayStreak),
                  semanticLabel: 'Day streak ${widget.dayStreak}',
                  child: Text(
                    'Day streak ${widget.dayStreak}',
                    style: AllInText.mono(13, color: c.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(AllInColors c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
    child: Text('·', style: AllInText.mono(13, color: c.textFaint)),
  );
}

/// One 44-tall tap target around a mono value (§5.1: "each stat a 44-tall
/// target → D3").
class _Stat extends StatelessWidget {
  const _Stat({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 20 pt "Today" ring.
class _TodayRing extends StatelessWidget {
  const _TodayRing({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    height: 16,
    child: CustomPaint(
      painter: _RingPainter(
        value: value.clamp(0, 1),
        color: color,
        track: context.colors.ink600,
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 2.5;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(stroke / 2),
      0,
      math.pi * 2,
      false,
      paint..color = track,
    );
    if (value > 0) {
      canvas.drawArc(
        rect.deflate(stroke / 2),
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
