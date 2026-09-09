/// `PotOddsCalculator` — DESIGN.md §6.5 (mobile layout) over the desktop maths
/// of docs/port/study-curriculum.md §12.2. Fields stacked, result tiles in one
/// three-column row, gold break-even box, then the verdict box.
///
/// Widget state is per-visit (§6.2): pot 10 · bet 6.5 · equity 50 every time.
library;

import 'package:allin/engine/format.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:flutter/material.dart';

import 'study_controls.dart';

class PotOddsCalculator extends StatefulWidget {
  const PotOddsCalculator({super.key, this.enableHaptics = true});

  final bool enableHaptics;

  @override
  State<PotOddsCalculator> createState() => _PotOddsCalculatorState();
}

class _PotOddsCalculatorState extends State<PotOddsCalculator> {
  int _pot = 10;
  double _bet = 6.5;
  int _eq = 50;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = PotOddsMath(pot: _pot, bet: _bet, eq: _eq);
    final tone = m.call ? c.good : c.bad;

    return StudyWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyField(
            label: 'Pot before the bet',
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
            label: "Opponent's bet",
            valueText: '${bbText(_bet)} bb',
            value: _bet,
            min: 0.5,
            max: 60,
            step: 0.5,
            semanticLabel: 'Bet',
            enableHaptics: widget.enableHaptics,
            onChanged: (v) => setState(() => _bet = v),
          ),
          const SizedBox(height: AllInSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: StudyResultTile(
                  label: 'You risk',
                  value: '${bbText(_bet)} bb',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StudyResultTile(
                  label: 'To win',
                  value: '${jsToFixed(m.toWin, 1)} bb',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StudyResultTile(
                  label: 'Getting',
                  value: '${jsToFixed(m.ratio, 1)} : 1',
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AllInSpace.md),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'BREAK-EVEN EQUITY',
                  textAlign: TextAlign.center,
                  style: AllInText.eyebrow(c.gold),
                ),
                const SizedBox(height: AllInSpace.xs),
                Text(
                  fmtPct(m.breakEven),
                  textAlign: TextAlign.center,
                  style: AllInText.display(30, color: c.goldLight),
                ),
                const SizedBox(height: AllInSpace.xs),
                Text(
                  m.breakEvenFormula,
                  textAlign: TextAlign.center,
                  style: AllInText.body(12.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          StudyField(
            label: 'Your equity estimate',
            valueText: '$_eq%',
            value: _eq.toDouble(),
            min: 0,
            max: 100,
            step: 1,
            semanticLabel: 'Your equity',
            enableHaptics: widget.enableHaptics,
            onChanged: (v) => setState(() => _eq = v.round()),
          ),
          const SizedBox(height: AllInSpace.md),
          Container(
            padding: const EdgeInsets.all(AllInSpace.lg),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              border: Border.all(color: tone),
              borderRadius: BorderRadius.circular(AllInRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'EV OF CALLING',
                        style: AllInText.eyebrow(c.textMuted),
                      ),
                      const SizedBox(height: AllInSpace.xs),
                      Text(
                        '${fmtSigned(m.ev)} bb',
                        style: AllInText.mono(
                          24,
                          weight: FontWeight.w800,
                          color: tone,
                        ),
                      ),
                      const SizedBox(height: AllInSpace.xs),
                      Text(
                        m.evFormula,
                        style: AllInText.body(11.5, color: c.textFaint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('DECISION', style: AllInText.eyebrow(c.textMuted)),
                    const SizedBox(height: AllInSpace.xs),
                    Text(
                      m.decision,
                      style: AllInText.display(
                        20,
                        weight: FontWeight.w700,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
