/// The in-lesson quiz (DESIGN.md §6.4; docs/port/study-curriculum.md §4).
///
/// Optional, never gates completion, and the only thing it persists is the
/// per-question result under `allin.quiz.v1` — the picks themselves reset with
/// every visit (§6.2).
///
/// Ordering is computed **once on mount**, exactly as the desktop's `useMemo`
/// does: previously-missed questions first (each group shuffled), and one
/// option permutation per question. "Try again" re-shuffles only that
/// question's options; the wrong attempt is already recorded.
library;

import 'dart:math' as math;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/features/study/content/study_progress.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/study_providers.dart';
import 'study_text.dart';

/// Verbatim desktop copy (§4.1).
const String kQuizTitle = 'Practice';
const String kQuizOptionalPill = 'optional';
const String kQuizSubline =
    "Test yourself — this doesn't affect lesson completion.";

/// "You missed {n} of these before — they're up first."
String quizMissedLine(int n) =>
    "You missed $n of these before — they're up first.";

class QuizCard extends ConsumerStatefulWidget {
  const QuizCard({
    super.key,
    required this.questions,
    this.onOpenGlossary,
    this.random,
  });

  final List<QuizQuestion> questions;
  final void Function(String termId)? onOpenGlossary;

  /// Injected by tests; the app shuffles with an unseeded `Random` (§4.2 —
  /// "no determinism required").
  final math.Random? random;

  @override
  ConsumerState<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends ConsumerState<QuizCard> {
  late final math.Random _rng = widget.random ?? math.Random();

  /// `keys[i] = String(hashSeed(questions[i].prompt))`.
  late final List<String> _keys = <String>[
    for (final q in widget.questions) StudyProgress.quizKey(q.prompt),
  ];

  /// Question indices in display order; missed-before first.
  late final List<int> _order;

  /// One option permutation per *question index* (not display position).
  late final List<List<int>> _perms;

  /// How many questions had a stored wrong last answer when the card mounted.
  late final int _missedBefore;

  /// Display position picked per question index; null = unanswered.
  final Map<int, int> _picked = <int, int>{};

  @override
  void initState() {
    super.initState();
    final progress = ref.read(studyProgressProvider);
    final idx = List<int>.generate(widget.questions.length, (i) => i);
    final missed = idx.where((i) => progress.wasMissed(_keys[i])).toList();
    final rest = idx.where((i) => !missed.contains(i)).toList();
    _missedBefore = missed.length;
    _order = <int>[..._shuffle(missed), ..._shuffle(rest)];
    _perms = <List<int>>[
      for (final q in widget.questions)
        _shuffle(List<int>.generate(q.options.length, (i) => i)),
    ];
  }

  List<int> _shuffle(List<int> source) {
    final out = List<int>.of(source);
    for (var i = out.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }

  void _pick(int question, int display) {
    if (_picked.containsKey(question)) return;
    final correct =
        _perms[question][display] == widget.questions[question].answer;
    final haptics = ref.read(studyHapticsProvider);
    correct ? haptics.drillCorrect() : haptics.drillWrong();
    setState(() => _picked[question] = display);
    ref
        .read(studyProgressProvider.notifier)
        .recordQuiz(_keys[question], correct);
  }

  void _tryAgain(int question) {
    setState(() {
      _picked.remove(question);
      _perms[question] = _shuffle(_perms[question]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    return AllInCard.info(
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // A Wrap, not a Row: at 1.3x the icon + title + pill are 9.6 pt
          // wider than a 360 pt card, and the pill dropping to a second line
          // is better than an overflow stripe (§13).
          Wrap(
            spacing: AllInSpace.sm,
            runSpacing: AllInSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.adjust, size: 16, color: c.info),
                  const SizedBox(width: AllInSpace.xs),
                  Text(
                    kQuizTitle,
                    style: AllInText.body(
                      14,
                      weight: FontWeight.w600,
                      color: c.info,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AllInRadius.pill),
                ),
                child: Text(
                  kQuizOptionalPill.toUpperCase(),
                  style: AllInText.eyebrow(c.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.xs),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: kQuizSubline,
                  style: AllInText.body(12.5, color: c.textFaint, height: 1.4),
                ),
                if (_missedBefore > 0)
                  TextSpan(
                    text: ' ${quizMissedLine(_missedBefore)}',
                    style: AllInText.body(12.5, color: c.warn, height: 1.4),
                  ),
              ],
            ),
          ),
          for (var display = 0; display < _order.length; display++)
            Padding(
              padding: const EdgeInsets.only(top: AllInSpace.lg),
              child: _Question(
                number: display + 1,
                question: widget.questions[_order[display]],
                perm: _perms[_order[display]],
                picked: _picked[_order[display]],
                reducedMotion: reduced,
                onOpenGlossary: widget.onOpenGlossary,
                onPick: (i) => _pick(_order[display], i),
                onTryAgain: () => _tryAgain(_order[display]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.number,
    required this.question,
    required this.perm,
    required this.picked,
    required this.onPick,
    required this.onTryAgain,
    required this.reducedMotion,
    required this.onOpenGlossary,
  });

  final int number;
  final QuizQuestion question;
  final List<int> perm;
  final int? picked;
  final ValueChanged<int> onPick;
  final VoidCallback onTryAgain;
  final bool reducedMotion;
  final void Function(String termId)? onOpenGlossary;

  /// A–E by *display* position (§4.1).
  static const List<String> letters = <String>['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final answered = picked != null;
    final correct = answered && perm[picked!] == question.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LessonRichText(
          '$number. ${question.prompt}',
          style: AllInText.body(
            14.5,
            weight: FontWeight.w500,
            color: c.text,
            height: 1.45,
          ),
          onOpenGlossary: onOpenGlossary,
          reducedMotion: reducedMotion,
        ),
        const SizedBox(height: AllInSpace.sm),
        for (var i = 0; i < perm.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Option(
              letter: letters[i.clamp(0, letters.length - 1)],
              text: question.options[perm[i]],
              state:
                  !answered
                      ? _OptionState.idle
                      : perm[i] == question.answer
                      ? _OptionState.correct
                      : i == picked
                      ? _OptionState.wrong
                      : _OptionState.idle,
              enabled: !answered,
              reducedMotion: reducedMotion,
              onTap: () => onPick(i),
            ),
          ),
        if (answered)
          Padding(
            padding: const EdgeInsets.only(top: AllInSpace.xs),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: correct ? 'Correct. ' : 'Not quite. ',
                        style: AllInText.body(
                          13,
                          weight: FontWeight.w600,
                          color: correct ? c.good : c.warn,
                        ),
                      ),
                      TextSpan(
                        text: question.explanation,
                        style: AllInText.body(
                          13,
                          color: c.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!correct)
                  Padding(
                    padding: const EdgeInsets.only(left: AllInSpace.sm),
                    child: _TryAgain(onTap: onTryAgain),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.letter,
    required this.text,
    required this.state,
    required this.enabled,
    required this.onTap,
    required this.reducedMotion,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final bool enabled;
  final VoidCallback onTap;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = switch (state) {
      _OptionState.correct => c.good,
      _OptionState.wrong => c.bad,
      _OptionState.idle => null,
    };
    final badge = switch (state) {
      _OptionState.correct => Icons.check_rounded,
      _OptionState.wrong => Icons.close_rounded,
      _OptionState.idle => null,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$letter. $text',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: AllInMotion.of(
            context,
            AllInMotion.fast,
            reduced: reducedMotion,
          ),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AllInSpace.sm,
            vertical: AllInSpace.sm,
          ),
          decoration: BoxDecoration(
            color: (tone ?? c.ink800).withValues(
              alpha: tone == null ? 1 : 0.15,
            ),
            border: Border.all(color: tone ?? c.line),
            borderRadius: BorderRadius.circular(AllInRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (tone ?? c.ink600).withValues(
                    alpha: tone == null ? 1 : 0.9,
                  ),
                  borderRadius: BorderRadius.circular(AllInRadius.sm),
                ),
                child:
                    badge == null
                        ? Text(
                          letter,
                          style: AllInText.mono(11, color: c.textMuted),
                        )
                        : Icon(badge, size: 14, color: c.ink900),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: Text(
                  text,
                  style: AllInText.body(
                    14,
                    color: tone == null ? c.textMuted : c.text,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TryAgain extends StatelessWidget {
  const _TryAgain({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Try again',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          child: Text(
            'Try again',
            style: AllInText.body(
              13,
              weight: FontWeight.w600,
              color: context.colors.gold,
            ),
          ),
        ),
      ),
    );
  }
}
