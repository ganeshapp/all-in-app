/// `BluffCalculator` — DESIGN.md §6.5 over docs/port/study-curriculum.md §12.3.
/// Two stacked fields, then two stacked result boxes with their verbatim
/// captions. State resets per visit: pot 10 · bet 7.
library;

import 'package:allin/engine/format.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:flutter/material.dart';

import 'study_controls.dart';

class BluffCalculator extends StatefulWidget {
  const BluffCalculator({super.key, this.enableHaptics = true});

  final bool enableHaptics;

  @override
  State<BluffCalculator> createState() => _BluffCalculatorState();
}

class _BluffCalculatorState extends State<BluffCalculator> {
  int _pot = 10;
  double _bet = 7;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = BluffMath(pot: _pot, bet: _bet);

    return StudyWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyField(
            label: 'Pot',
            valueText: '${bbText(_pot)} bb',
            value: _pot.toDouble(),
            min: 1,
            max: 60,
            step: 1,
            semanticLabel: 'Pot',
            enableHaptics: widget.enableHaptics,
            onChanged: (v) => setState(() => _pot = v.round()),
          ),
          const SizedBox(height: AllInSpace.md),
          StudyField(
            label: 'Your bet',
            valueText: '${bbText(_bet)} bb (${fmtPct(m.betAsPot)} pot)',
            value: _bet,
            min: 0.5,
            max: 90,
            step: 0.5,
            semanticLabel: 'Bet',
            enableHaptics: widget.enableHaptics,
            onChanged: (v) => setState(() => _bet = v),
          ),
          const SizedBox(height: AllInSpace.md),
          _ResultBox(
            label: "If you're bluffing",
            value: fmtPct(m.foldNeeded),
            caption:
                'they must fold at least this often for the bluff to make money',
            labelColor: c.gold,
            valueColor: c.goldLight,
            background: c.gold.withValues(alpha: 0.10),
            border: null,
          ),
          const SizedBox(height: AllInSpace.sm),
          _ResultBox(
            label: 'If they call you',
            value: fmtPct(m.callerNeeds),
            caption:
                'they only need to win this often for their call to make money',
            labelColor: c.textFaint,
            valueColor: c.text,
            background: c.ink800,
            border: c.line,
          ),
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({
    required this.label,
    required this.value,
    required this.caption,
    required this.labelColor,
    required this.valueColor,
    required this.background,
    required this.border,
  });

  final String label;
  final String value;
  final String caption;
  final Color labelColor;
  final Color valueColor;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AllInSpace.md),
      decoration: BoxDecoration(
        color: background,
        border: border == null ? null : Border.all(color: border!),
        borderRadius: BorderRadius.circular(AllInRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: AllInText.eyebrow(labelColor)),
          const SizedBox(height: AllInSpace.xs),
          Text(value, style: AllInText.display(30, color: valueColor)),
          const SizedBox(height: AllInSpace.xs),
          Text(caption, style: AllInText.body(12.5, color: c.textMuted)),
        ],
      ),
    );
  }
}
