/// D5's three pieces: the 8-segment progress indicator, one question page and
/// the result card (DESIGN.md §5.8).
library;

import 'package:flutter/material.dart';

import '../../../theme/motion.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../content/placement_test.dart';

/// `▰▰▰▱▱▱▱▱` — one segment per question, filled for the ones behind you.
class PlacementProgress extends StatelessWidget {
  const PlacementProgress({super.key, required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: PlacementCopy.progress(done),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 44,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < total; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Container(
                      width: 12,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < done ? c.gold : c.ink600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One question per screen; the options are already shuffled.
class PlacementQuestionPage extends StatelessWidget {
  const PlacementQuestionPage({
    super.key,
    required this.index,
    required this.question,
    required this.options,
    required this.onPick,
    this.picked,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final int index;
  final PlacementQuestion question;
  final List<String> options;
  final ValueChanged<String> onPick;

  /// The chosen option once tapped — the page locks and tints for 350 ms.
  final String? picked;

  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow(PlacementCopy.progress(index)),
          const SizedBox(height: AllInSpace.md),
          Text(
            question.question,
            style: AllInText.display(22, color: c.text, height: 1.25),
          ),
          const SizedBox(height: AllInSpace.xl),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AllInSpace.sm),
                      child: _OptionButton(
                        label: option,
                        state: _stateFor(option),
                        reducedMotion: reducedMotion,
                        onTap: picked == null ? () => onPick(option) : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          Text(
            PlacementCopy.footer,
            textAlign: TextAlign.center,
            style: AllInText.body(12, color: c.textFaint, height: 1.4),
          ),
          SizedBox(
            height: AllInSpace.lg + MediaQuery.paddingOf(context).bottom,
          ),
        ],
      ),
    );
  }

  _OptionState _stateFor(String option) {
    if (picked == null) return _OptionState.idle;
    if (option == question.answer) return _OptionState.right;
    if (option == picked) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

enum _OptionState { idle, right, wrong, dimmed }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
    required this.reducedMotion,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fill, Color fg, Color border) = switch (state) {
      _OptionState.idle => (c.ink800, c.text, c.line),
      _OptionState.right => (c.good.withValues(alpha: 0.18), c.good, c.good),
      _OptionState.wrong => (c.bad.withValues(alpha: 0.18), c.bad, c.bad),
      _OptionState.dimmed => (c.ink800, c.textFaint, c.line),
    };

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: AllInMotion.of(
              context,
              AllInMotion.fast,
              reduced: reducedMotion,
            ),
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.lg,
              vertical: AllInSpace.md,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AllInRadius.md),
              border: Border.all(color: border),
            ),
            child: Text(
              label,
              style: AllInText.body(17, color: fg, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gold result card and its two buttons.
class PlacementResultPage extends StatelessWidget {
  const PlacementResultPage({
    super.key,
    required this.score,
    required this.onLesson,
    required this.onStart,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final int score;

  /// "Take me there" → the advised lesson as a Study-branch push.
  final ValueChanged<String> onLesson;
  final VoidCallback onStart;
  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final result = PlacementResult.forScore(score);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AllInSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          AllInCard.gold(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.headline,
                  style: AllInText.display(26, color: c.gold, height: 1.2),
                ),
                const SizedBox(height: AllInSpace.md),
                Text(
                  result.body(score),
                  style: AllInText.body(16, color: c.text, height: 1.5),
                ),
              ],
            ),
          ),
          const Spacer(),
          AllInButton.secondary(
            label: PlacementCopy.takeMeThere,
            size: AllInButtonSize.md,
            expand: true,
            enableHaptics: enableHaptics,
            reducedMotion: reducedMotion,
            onPressed: () => onLesson(result.lessonId),
          ),
          const SizedBox(height: AllInSpace.sm),
          AllInButton.primary(
            label: PlacementCopy.startPlaying,
            size: AllInButtonSize.lg,
            expand: true,
            enableHaptics: enableHaptics,
            reducedMotion: reducedMotion,
            onPressed: onStart,
          ),
          SizedBox(
            height: AllInSpace.lg + MediaQuery.paddingOf(context).bottom,
          ),
        ],
      ),
    );
  }
}
