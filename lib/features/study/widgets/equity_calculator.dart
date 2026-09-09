/// `EquityCalculator` — DESIGN.md §6.5 over docs/port/study-curriculum.md
/// §12.6. Any range (or exact hand) vs any range on any board, stacked for a
/// phone: segmented mode, the two matrices, the board picked through the S5
/// keypad, the run button, the result panel and the board breakdowns.
///
/// Every simulation goes through [EquityService] (isolates); the UI thread
/// only ever expands combos for the footer count.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/equity.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/providers/study_math.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/services/equity_service.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'card_keypad_sheet.dart';
import 'range_board_breakdown_card.dart';
import 'study_controls.dart';

/// "5,000" — the samples line groups thousands (§12.6 result panel).
String groupThousands(int n) {
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class EquityCalculator extends ConsumerStatefulWidget {
  const EquityCalculator({super.key, required this.available});

  final double available;

  @override
  ConsumerState<EquityCalculator> createState() => _EquityCalculatorState();
}

class _EquityCalculatorState extends ConsumerState<EquityCalculator> {
  /// 0 = range vs range, 1 = exact hand vs range.
  int _mode = 0;
  Set<HandLabel> _hero = <HandLabel>{};
  List<Card> _heroCards = <Card>[];
  Set<HandLabel> _vill = <HandLabel>{};
  List<Card> _board = <Card>[];
  EquityResult? _result;
  bool _busy = false;

  bool get _handMode => _mode == 1;

  /// Any state change clears the result panel (§12.6).
  void _mutate(VoidCallback change) => setState(() {
    change();
    _result = null;
  });

  Future<void> _editBoard() async {
    final settings = ref.read(settingsProvider);
    final picked = await CardKeypadSheet.show(
      context,
      title: 'Board',
      initial: _board,
      max: 5,
      disabled: _handMode ? _heroCards.toSet() : const <Card>{},
      fourColorDeck: settings.fourColorDeck,
      reducedMotion: settings.reducedMotion,
    );
    if (picked == null || !mounted) return;
    _mutate(() => _board = picked);
  }

  Future<void> _editHeroCards() async {
    final settings = ref.read(settingsProvider);
    final picked = await CardKeypadSheet.show(
      context,
      title: 'Your hand',
      initial: _heroCards,
      max: 2,
      disabled: _board.toSet(),
      fourColorDeck: settings.fourColorDeck,
      reducedMotion: settings.reducedMotion,
    );
    if (picked == null || !mounted) return;
    _mutate(() => _heroCards = picked);
  }

  Future<void> _openEditor({required bool hero}) async {
    ref
        .read(rangeEditorTitleProvider.notifier)
        .set(hero ? 'Your range' : "Opponent's range");
    final result = await context.push<Set<HandLabel>>(
      AllInRoutes.rangeEditorPath,
      extra: <HandLabel>{...(hero ? _hero : _vill)},
    );
    if (result == null || !mounted) return;
    _mutate(() {
      if (hero) {
        _hero = result;
      } else {
        _vill = result;
      }
    });
  }

  bool get _canRun =>
      !_busy &&
      _vill.isNotEmpty &&
      (_handMode ? _heroCards.length == 2 : _hero.isNotEmpty);

  Future<void> _run() async {
    if (!_canRun) return;
    setState(() => _busy = true);
    final service = ref.read(studyEquityServiceProvider);
    try {
      final result =
          _handMode
              ? await service.vsRange(
                hero: _heroCards,
                board: _board,
                range: _vill.toList(),
                iters: 5000,
                key: 'study-equity',
              )
              : await service.rangeVsRange(
                heroRange: _hero.toList(),
                board: _board,
                villainRange: _vill.toList(),
                iters: 5000,
                key: 'study-equity',
              );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (_) {
      // Superseded, timed out or the isolate failed: no result, no error
      // screen — the user can press the button again (§14).
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  /// Hand-mode blockers: how many opponent combos the hero's two cards remove.
  ({int removed, int all})? get _blockers {
    if (!_handMode || _heroCards.length != 2 || _vill.isEmpty) return null;
    final all = expandAgainstBoard(_vill, _board).length;
    if (all == 0) return null;
    final withHero =
        expandAgainstBoard(_vill, <Card>[..._board, ..._heroCards]).length;
    return (removed: all - withHero, all: all);
  }

  String get _footerSummary {
    if (_handMode) {
      final hero = _heroCards.isEmpty ? '—' : _heroCards.join(' ');
      final vill =
          expandAgainstBoard(_vill, <Card>[..._board, ..._heroCards]).length;
      return '$hero vs $vill combos';
    }
    final hero = expandAgainstBoard(_hero, _board).length;
    final vill = expandAgainstBoard(_vill, _board).length;
    return '$hero vs $vill combos';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final reduced = ref.watch(reducedMotionProvider);
    final haptics = ref.watch(hapticsEnabledProvider);

    return StudyWidgetCard.wide(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyPad(
            child: AllInSegmented(
              labels: const <String>['Range', 'Hand'],
              value: _mode,
              semanticLabel: 'Your side',
              enableHaptics: haptics,
              reducedMotion: reduced,
              onChanged: (v) => _mutate(() => _mode = v),
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          if (_handMode)
            StudyPad(
              child: _HandPicker(
                cards: _heroCards,
                fourColorDeck: settings.fourColorDeck,
                onPick: _editHeroCards,
                onClear: () => _mutate(_heroCards.clear),
              ),
            )
          else
            _RangeSection(
              title: 'Your range',
              available: widget.available,
              value: _hero,
              enableHaptics: haptics,
              reducedMotion: reduced,
              onChanged: (next) => _mutate(() => _hero = next),
              onEdit: () => _openEditor(hero: true),
            ),
          const SizedBox(height: AllInSpace.md),
          _RangeSection(
            title: "Opponent's range",
            available: widget.available,
            value: _vill,
            enableHaptics: haptics,
            reducedMotion: reduced,
            onChanged: (next) => _mutate(() => _vill = next),
            onEdit: () => _openEditor(hero: false),
          ),
          const SizedBox(height: AllInSpace.sm),
          const StudyPad(child: StudyLegend()),
          const SizedBox(height: AllInSpace.md),
          StudyPad(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Board (${_board.length}/5)',
                    style: AllInText.body(
                      14,
                      weight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                if (_board.isNotEmpty)
                  StudyTextButton(
                    label: 'Clear board',
                    onTap: () => _mutate(_board.clear),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.xs),
          StudyPad(
            child: _BoardSlots(
              board: _board,
              fourColorDeck: settings.fourColorDeck,
              onTap: _editBoard,
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          StudyPad(
            child: Text(
              _footerSummary,
              style: AllInText.body(12.5, color: c.textFaint),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          StudyPad(
            child: AllInButton.primary(
              label: _busy ? 'Calculating…' : 'Calculate equity',
              size: AllInButtonSize.lg,
              expand: true,
              reducedMotion: reduced,
              enableHaptics: haptics,
              onPressed: _canRun ? _run : null,
            ),
          ),
          if (_result != null) ...<Widget>[
            const SizedBox(height: AllInSpace.md),
            StudyPad(
              child: _ResultPanel(
                result: _result!,
                blockers: _blockers,
                reducedMotion: reduced,
              ),
            ),
          ],
          if (_board.length >= 3) ...<Widget>[
            const SizedBox(height: AllInSpace.md),
            if (!_handMode && _hero.isNotEmpty)
              StudyPad(
                child: RangeBoardBreakdownCard(
                  title: 'Your range on this board',
                  range: _hero,
                  board: _board,
                ),
              ),
            if (!_handMode && _hero.isNotEmpty)
              const SizedBox(height: AllInSpace.sm),
            if (_vill.isNotEmpty)
              StudyPad(
                child: RangeBoardBreakdownCard(
                  title: "Opponent's range on this board",
                  range: _vill,
                  board: _board,
                  dead: _handMode ? _heroCards : const <Card>[],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RangeSection extends StatelessWidget {
  const _RangeSection({
    required this.title,
    required this.available,
    required this.value,
    required this.onChanged,
    required this.onEdit,
    required this.enableHaptics,
    required this.reducedMotion,
  });

  final String title;
  final double available;
  final Set<HandLabel> value;
  final ValueChanged<Set<HandLabel>> onChanged;
  final VoidCallback onEdit;
  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudyPad(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AllInText.body(
                    14,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              StudyTextButton(label: 'Edit', onTap: onEdit),
            ],
          ),
        ),
        Center(
          child: ScrollSafeRangeMatrix.editable(
            available: available,
            value: value,
            enableHaptics: enableHaptics,
            reducedMotion: reducedMotion,
            semanticLabel: title,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: AllInSpace.xs),
        StudyPad(
          child: Row(
            children: <Widget>[
              StudyTextButton(
                label: 'Any two',
                onTap: () => onChanged(allLabels().toSet()),
              ),
              StudyTextButton(
                label: 'Clear',
                onTap: () => onChanged(<HandLabel>{}),
              ),
              Expanded(
                child: ComboCounter(
                  combos: combosInSet(value),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HandPicker extends StatelessWidget {
  const _HandPicker({
    required this.cards,
    required this.fourColorDeck,
    required this.onPick,
    required this.onClear,
  });

  final List<Card> cards;
  final bool fourColorDeck;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Your exact hand',
                style: AllInText.body(
                  14,
                  weight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            if (cards.isNotEmpty)
              StudyTextButton(label: 'Clear', onTap: onClear),
          ],
        ),
        const SizedBox(height: AllInSpace.xs),
        Semantics(
          button: true,
          label:
              cards.isEmpty
                  ? 'Pick two cards'
                  : 'Your hand ${cards.join(' ')}, edit',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.all(AllInSpace.sm),
              decoration: BoxDecoration(
                color: c.ink800,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(AllInRadius.md),
              ),
              child:
                  cards.isEmpty
                      ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pick two cards below.',
                          style: AllInText.body(13, color: c.textFaint),
                        ),
                      )
                      : Row(
                        children: <Widget>[
                          for (final card in cards) ...<Widget>[
                            PlayingCardView(
                              card: card,
                              width: 40,
                              fourColorDeck: fourColorDeck,
                            ),
                            const SizedBox(width: AllInSpace.xs),
                          ],
                        ],
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoardSlots extends StatelessWidget {
  const _BoardSlots({
    required this.board,
    required this.fourColorDeck,
    required this.onTap,
  });

  final List<Card> board;
  final bool fourColorDeck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const width = 44.0;
    return Semantics(
      button: true,
      label: 'Board, ${board.length} of 5 cards. Edit',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < 5; i++) ...<Widget>[
                if (i < board.length)
                  PlayingCardView(
                    card: board[i],
                    width: width,
                    fourColorDeck: fourColorDeck,
                  )
                else
                  Container(
                    width: width,
                    height: PlayingCardView.heightFor(width),
                    decoration: BoxDecoration(
                      color: c.ink800,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(
                        PlayingCardView.radiusFor(width),
                      ),
                    ),
                  ),
                if (i < 4) const SizedBox(width: AllInSpace.xs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.blockers,
    required this.reducedMotion,
  });

  final EquityResult result;
  final ({int removed, int all})? blockers;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final samples = result.samples == 0 ? 1 : result.samples;
    final b = blockers;
    return AnimatedOpacity(
      opacity: 1,
      duration: AllInMotion.of(
        context,
        AllInMotion.base,
        reduced: reducedMotion,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Your equity',
                  style: AllInText.body(
                    14,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                fmtPct(result.equity),
                style: AllInText.mono(
                  18,
                  weight: FontWeight.w800,
                  color: c.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return Row(
                    children: <Widget>[
                      SizedBox(
                        width: w * result.win / samples,
                        child: ColoredBox(color: c.good),
                      ),
                      SizedBox(
                        width: w * result.tie / samples,
                        child: ColoredBox(color: c.warn),
                      ),
                      Expanded(child: ColoredBox(color: c.bad)),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          Wrap(
            spacing: AllInSpace.md,
            runSpacing: AllInSpace.xs,
            children: <Widget>[
              _Stat('Win', fmtPct(result.win / samples), c.good),
              _Stat('Tie', fmtPct(result.tie / samples), c.warn),
              _Stat('Lose', fmtPct(result.lose / samples), c.bad),
              Text(
                result.exact
                    ? '${groupThousands(result.samples)} matchups · exact'
                    : '${groupThousands(result.samples)} trials · '
                        '±${jsToFixed(2 * result.se * 100, 1)}%',
                style: AllInText.body(11.5, color: c.textFaint),
              ),
            ],
          ),
          if (b != null && b.removed > 0) ...<Widget>[
            const SizedBox(height: AllInSpace.sm),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Blockers:',
                    style: AllInText.body(
                      12.5,
                      weight: FontWeight.w600,
                      color: c.goldLight,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' your cards remove ${b.removed} of ${b.all} opponent '
                        'combos (${fmtPct(b.removed / b.all)}) — holding their '
                        'cards makes their strong hands rarer.',
                    style: AllInText.body(12.5, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: AllInText.body(11.5, weight: FontWeight.w600, color: color),
          ),
          TextSpan(
            text: value,
            style: AllInText.mono(11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
