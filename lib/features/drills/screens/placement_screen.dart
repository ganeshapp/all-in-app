/// D5 · Placement test — full-screen modal at `/placement`
/// (DESIGN.md §5.8), reached from onboarding (O0 page 5, which owns the
/// intro copy) and from Settings → "Run again".
///
/// Eight questions, one per screen, auto-advancing 350 ms after a tap. The
/// options are shuffled **once** with Fisher–Yates when the test starts, like
/// the desktop; the answer key is index 0 of the unshuffled list. Nothing is
/// written until the last answer: ✕ mid-quiz marks the tour seen and leaves
/// the rating untouched (§5.8, §6.10).
library;

import 'dart:math' as math;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/drills/content/placement_test.dart';
import 'package:allin/features/drills/providers/drill_provider.dart';
import 'package:allin/features/drills/widgets/placement_pages.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  /// §2.5 blocked back: 120 ms, 4 pt horizontal.
  static const Duration shakeDuration = Duration(milliseconds: 120);
  static const double shakeAmplitude = 4;

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: PlacementScreen.shakeDuration,
  );
  late final List<PlacementShuffle> _shuffled = shufflePlacement(math.Random());

  /// The answer picked per question, or null while unanswered.
  final List<String?> _picked = List<String?>.filled(
    kPlacementQuestions.length,
    null,
  );

  int _index = 0;
  bool _done = false;
  bool _leaving = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _reduced => ref.read(reducedMotionProvider);

  int get _score {
    var score = 0;
    for (var i = 0; i < kPlacementQuestions.length; i++) {
      if (_picked[i] == kPlacementQuestions[i].answer) score++;
    }
    return score;
  }

  /* ------------------------------------------------------------ behaviour */

  /// §2.5: back on Q1 is refused, never silently. Motion is never the only
  /// channel — reduced motion leaves the haptic, and with Haptics off the ✕
  /// on screen is the stated exit.
  void _blockedBack() {
    ref.read(hapticsProvider).blockedBack();
    if (_reduced) return;
    _shake.forward(from: 0).whenComplete(() {
      if (mounted) _shake.value = 0;
    });
  }

  Future<void> _pick(String option) async {
    if (_picked[_index] != null) return;
    setState(() => _picked[_index] = option);
    ref.read(hapticsProvider).actionCommitted();
    // The 350 ms is a dwell on the good/bad tint, not an animation, so
    // reduced motion keeps it: zeroing it would delete the feedback (§11 —
    // "shimmers have a static form, not a zero duration").
    await Future<void>.delayed(PlacementCopy.advanceDelay);
    if (!mounted) return;
    if (_index < kPlacementQuestions.length - 1) {
      setState(() => _index++);
    } else {
      await _finish();
    }
  }

  /// The only place the rating is written (§6.10 `seedRating`).
  Future<void> _finish() async {
    final result = PlacementResult.forScore(_score);
    await ref.read(drillScoreboardProvider.notifier).seedRating(result.rating);
    await ref.read(onboardingStoreProvider).markOnboarded();
    if (!mounted) return;
    setState(() => _done = true);
  }

  /// ✕ mid-quiz: the tour is seen, the rating is untouched.
  Future<void> _close() async {
    if (_leaving) return;
    _leaving = true;
    await ref.read(onboardingStoreProvider).markOnboarded();
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.todayPath);
    }
  }

  /// "Take me there" — the **Study-branch push**, not the `/lesson/:id`
  /// modal: this modal closes on the way out, so there is nothing to return
  /// to (§5.8).
  void _openLesson(String lessonId) {
    context.go(AllInRoutes.lessonPath(lessonId));
  }

  /* ---------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = ref.watch(hapticsEnabledProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_done) {
          _goHome();
        } else if (_index == 0) {
          _blockedBack();
        } else {
          setState(() => _index--);
        }
      },
      child: AllInScaffold(
        leading: _done ? null : _CloseButton(onTap: _close),
        actions:
            _done
                ? const <Widget>[]
                : [
                  Padding(
                    padding: const EdgeInsets.only(right: AllInSpace.sm),
                    child: PlacementProgress(
                      total: kPlacementQuestions.length,
                      done: _index,
                    ),
                  ),
                ],
        body: AnimatedBuilder(
          animation: _shake,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(_shakeOffset, 0),
                child: child,
              ),
          child:
              _done
                  ? PlacementResultPage(
                    score: _score,
                    enableHaptics: haptics,
                    reducedMotion: reduced,
                    onLesson: _openLesson,
                    onStart: _goHome,
                  )
                  : PlacementQuestionPage(
                    key: ValueKey(_index),
                    index: _index,
                    question: kPlacementQuestions[_index],
                    options: _shuffled[_index].options,
                    picked: _picked[_index],
                    enableHaptics: haptics,
                    reducedMotion: reduced,
                    onPick: _pick,
                  ),
        ),
      ),
    );
  }

  double get _shakeOffset =>
      PlacementScreen.shakeAmplitude *
      (1 - _shake.value) *
      math.sin(_shake.value * 4 * math.pi);
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: context.colors.text,
            ),
          ),
        ),
      ),
    );
  }
}
