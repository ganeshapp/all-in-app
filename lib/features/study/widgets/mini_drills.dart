/// The three Study mini-drills — `PotOddsDrill`, `OutsDrill` and
/// `RangeBuildDrill` (docs/port/study-curriculum.md §16; DESIGN.md §6.5).
///
/// They are stateless across visits by design: the score starts at 0/0 every
/// time the lesson is opened, there is no SRS, no store, no analytics (§16).
library;

import 'dart:math' as math;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_controls.dart';
import 'study_text.dart';

/// The card every mini-drill sits in: target icon + title left, mono
/// "Score {right}/{total}" right, body, then a right-aligned footer (§16.1).
class DrillShell extends StatelessWidget {
  const DrillShell({
    super.key,
    required this.title,
    required this.right,
    required this.total,
    required this.child,
    required this.footer,
    this.wide = false,
  });

  final String title;
  final int right;
  final int total;
  final Widget child;
  final Widget footer;

  /// Drops the card's horizontal padding so an embedded `RangeMatrix` can use
  /// the full width; the shell's own rows keep it through [StudyPad] and the
  /// [child] pads whatever is not a grid (§6.5).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget pad(Widget w) => wide ? StudyPad(child: w) : w;
    return AllInCard.info(
      padding:
          wide
              ? const EdgeInsets.symmetric(vertical: AllInSpace.lg)
              : const EdgeInsets.all(AllInSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          pad(
            Row(
              children: <Widget>[
                Icon(Icons.adjust, size: 16, color: c.info),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    title,
                    style: AllInText.body(
                      14,
                      weight: FontWeight.w600,
                      color: c.info,
                    ),
                  ),
                ),
                Text(
                  'Score $right/$total',
                  style: AllInText.mono(12.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          child,
          const SizedBox(height: AllInSpace.lg),
          pad(Align(alignment: Alignment.centerRight, child: footer)),
        ],
      ),
    );
  }
}

/// The four answer buttons: 2 × 2 on a phone, 48 tall, mono bold (§16.1,
/// §16.7).
class DrillOptions extends StatelessWidget {
  const DrillOptions({
    super.key,
    required this.options,
    required this.picked,
    required this.correct,
    required this.suffix,
    required this.onPick,
  });

  final List<int> options;
  final int? picked;
  final int correct;
  final String suffix;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final answered = picked != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - AllInSpace.sm) / 2;
        return Wrap(
          spacing: AllInSpace.sm,
          runSpacing: AllInSpace.sm,
          children: <Widget>[
            for (final option in options)
              SizedBox(
                width: w,
                child: _OptionButton(
                  label: '$option$suffix',
                  // The correct test comes first, so a correct pick is never
                  // painted red (§16.1).
                  border:
                      !answered
                          ? c.line
                          : option == correct
                          ? c.good
                          : option == picked
                          ? c.bad
                          : c.line,
                  fill:
                      !answered
                          ? c.ink800
                          : option == correct
                          ? c.good.withValues(alpha: 0.15)
                          : option == picked
                          ? c.bad.withValues(alpha: 0.15)
                          : c.ink800,
                  textColor:
                      answered && (option == correct || option == picked)
                          ? c.text
                          : c.textMuted,
                  onTap: answered ? null : () => onPick(option),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.border,
    required this.fill,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color border;
  final Color fill;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AllInRadius.md),
          ),
          child: Text(
            label,
            style: AllInText.mono(
              14,
              weight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Correct. " / "Not quite. " + the explanation (§16.1).
class DrillExplain extends StatelessWidget {
  const DrillExplain({super.key, required this.ok, required this.body});

  final bool ok;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AllInSpace.md),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: ok ? 'Correct. ' : 'Not quite. ',
              style: AllInText.body(
                13,
                weight: FontWeight.w600,
                color: ok ? c.good : c.warn,
              ),
            ),
            TextSpan(
              text: body,
              style: AllInText.body(13, color: c.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ §16.2 pot odds */

class PotOddsDrill extends ConsumerStatefulWidget {
  const PotOddsDrill({super.key, this.random});

  /// Injected in tests; the app uses an unseeded `Random`.
  final math.Random? random;

  @override
  ConsumerState<PotOddsDrill> createState() => _PotOddsDrillState();
}

class _PotOddsDrillState extends ConsumerState<PotOddsDrill> {
  late final math.Random _rng = widget.random ?? math.Random();
  late PotOddsSpot _spot = makePotSpot(_rng);
  int? _picked;
  int _right = 0;
  int _total = 0;

  void _pick(int value) {
    if (_picked != null) return;
    final haptics = ref.read(studyHapticsProvider);
    haptics.drillAnswer();
    final ok = value == _spot.correct;
    ok ? haptics.drillCorrect() : haptics.drillWrong();
    setState(() {
      _picked = value;
      _total++;
      if (ok) _right++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final answered = _picked != null;
    return DrillShell(
      title: 'Pot-odds drill',
      right: _right,
      total: _total,
      footer: AllInButton(
        label: 'New spot',
        trailing: Icons.refresh,
        variant:
            answered ? AllInButtonVariant.primary : AllInButtonVariant.ghost,
        reducedMotion: ref.watch(reducedMotionProvider),
        enableHaptics: ref.watch(hapticsEnabledProvider),
        onPressed:
            () => setState(() {
              _spot = makePotSpot(_rng);
              _picked = null;
            }),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LessonRichText(
            _spot.prompt,
            style: AllInText.body(14.7, color: c.text, height: 1.5),
          ),
          const SizedBox(height: AllInSpace.md),
          DrillOptions(
            options: _spot.options,
            picked: _picked,
            correct: _spot.correct,
            suffix: '%',
            onPick: _pick,
          ),
          if (answered)
            DrillExplain(ok: _picked == _spot.correct, body: _spot.explanation),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- §16.3 outs */

class OutsDrill extends ConsumerStatefulWidget {
  const OutsDrill({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<OutsDrill> createState() => _OutsDrillState();
}

class _OutsDrillState extends ConsumerState<OutsDrill> {
  late final math.Random _rng = widget.random ?? math.Random();
  late OutsSpot _spot = makeOutsSpot(_rng);
  int? _picked;
  int _right = 0;
  int _total = 0;

  void _pick(int value) {
    if (_picked != null) return;
    final haptics = ref.read(studyHapticsProvider);
    haptics.drillAnswer();
    final ok = value == _spot.correct;
    ok ? haptics.drillCorrect() : haptics.drillWrong();
    setState(() {
      _picked = value;
      _total++;
      if (ok) _right++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final answered = _picked != null;
    return DrillShell(
      title: 'Outs → equity drill',
      right: _right,
      total: _total,
      footer: AllInButton(
        label: 'New spot',
        trailing: Icons.refresh,
        variant:
            answered ? AllInButtonVariant.primary : AllInButtonVariant.ghost,
        reducedMotion: ref.watch(reducedMotionProvider),
        enableHaptics: ref.watch(hapticsEnabledProvider),
        onPressed:
            () => setState(() {
              _spot = makeOutsSpot(_rng);
              _picked = null;
            }),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LessonRichText(
            _spot.prompt,
            style: AllInText.body(14.7, color: c.text, height: 1.5),
          ),
          const SizedBox(height: AllInSpace.md),
          DrillOptions(
            options: _spot.options,
            picked: _picked,
            correct: _spot.correct,
            suffix: '%',
            onPick: _pick,
          ),
          if (answered)
            DrillExplain(ok: _picked == _spot.correct, body: _spot.explanation),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------- §16.4 range building */

class RangeBuildDrill extends ConsumerStatefulWidget {
  const RangeBuildDrill({super.key, required this.available, this.random});

  /// Content width this block was given.
  final double available;
  final math.Random? random;

  @override
  ConsumerState<RangeBuildDrill> createState() => _RangeBuildDrillState();
}

class _RangeBuildDrillState extends ConsumerState<RangeBuildDrill> {
  late final math.Random _rng = widget.random ?? math.Random();
  late RangeTarget _target = kRangeTargets[randInt(_rng, 0, 3)];
  Set<HandLabel> _painted = <HandLabel>{};
  bool _checked = false;
  int _right = 0;
  int _total = 0;
  double _acc = 0;

  void _check() {
    if (_painted.isEmpty) return;
    final a = scoreRange(_painted, _target.labels);
    final haptics = ref.read(studyHapticsProvider);
    a >= kRangePassThreshold ? haptics.drillCorrect() : haptics.drillWrong();
    setState(() {
      _checked = true;
      _acc = a;
      _total++;
      if (a >= kRangePassThreshold) _right++;
    });
  }

  void _newDrill() {
    setState(() {
      // No no-repeat guard on desktop; the same target may come up again.
      _target = kRangeTargets[randInt(_rng, 0, 3)];
      _painted = <HandLabel>{};
      _checked = false;
      _acc = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = ref.watch(hapticsEnabledProvider);
    return DrillShell(
      title: 'Range-building drill',
      wide: true,
      right: _right,
      total: _total,
      footer:
          _checked
              ? AllInButton.primary(
                label: 'New drill',
                trailing: Icons.refresh,
                reducedMotion: reduced,
                enableHaptics: haptics,
                onPressed: _newDrill,
              )
              : AllInButton.primary(
                label: 'Check',
                reducedMotion: reduced,
                enableHaptics: haptics,
                onPressed: _painted.isEmpty ? null : _check,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyPad(
            child: LessonRichText(
              'Paint the standard **${_target.desc}**.',
              style: AllInText.body(14.7, color: c.text, height: 1.5),
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          Center(
            child:
                _checked
                    ? ScrollSafeRangeMatrix.compare(
                      available: widget.available,
                      painted: _painted,
                      actual: _target.labels,
                      enableHaptics: haptics,
                      reducedMotion: reduced,
                      semanticLabel: 'Your range compared with the standard',
                    )
                    : ScrollSafeRangeMatrix.editable(
                      available: widget.available,
                      value: _painted,
                      enableHaptics: haptics,
                      reducedMotion: reduced,
                      semanticLabel: 'Paint the range',
                      onChanged: (next) => setState(() => _painted = next),
                    ),
          ),
          const SizedBox(height: AllInSpace.sm),
          StudyPad(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AllInSpace.sm,
              runSpacing: AllInSpace.xs,
              children: <Widget>[
                StudyLegend(
                  mode:
                      _checked ? RangeLegendMode.compare : RangeLegendMode.kind,
                ),
                if (_checked)
                  Text(
                    '${fmtPct(_acc)} match',
                    style: AllInText.mono(
                      14,
                      weight: FontWeight.w700,
                      color: _acc >= kRangePassThreshold ? c.good : c.warn,
                    ),
                  )
                else
                  ComboCounter(combos: combosInSet(_painted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
