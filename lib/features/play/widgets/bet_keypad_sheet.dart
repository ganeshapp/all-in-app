/// P13 · Bet keypad (DESIGN.md §4.5): sheet S, 300 tall — mono 28 display,
/// the min/max caption, ±0.5 bb steppers, a 1–9 · . · 0 · ⌫ keypad, the same
/// seven detent chips and "Set · Raise to …".
///
/// "Set" clamps to `[minRaiseTo, maxRaiseTo]` and returns the value — it never
/// commits. There is no system keyboard on the table.
///
/// **The commit button is pinned.** Display + steppers stay at the top, "Set ·
/// Raise to …" stays at the bottom, and only the detent chips + keypad scroll
/// between them. §10.1 caps detent S at 40 % of the viewport (338 pt at 844,
/// 312 at 780), and §4.5's own parts — 48 display + 36 chips + four 48 pt key
/// rows + a 56 pt button — need ~412 pt, so *something* has to scroll. It is
/// never the button: the sheet exists to set a number and confirm it, and a
/// confirm button below the fold is the defect this layout fixes.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/raise_sizing.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

class BetKeypadSheet extends StatefulWidget {
  const BetKeypadSheet({
    super.key,
    required this.legal,
    required this.currentBet,
    required this.value,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  final LegalActions legal;

  /// `table.currentBet` — the desktop `setFraction` reads it.
  final int currentBet;

  /// The rail's current raise-to total, in chips.
  final int value;
  final bool enableHaptics;
  final bool reducedMotion;

  /// Opens the sheet and returns the chosen raise-to total, or null.
  static Future<int?> show(
    BuildContext context, {
    required LegalActions legal,
    required int currentBet,
    required int value,
    bool enableHaptics = true,
    bool reducedMotion = false,
  }) => AllInSheet.show<int>(
    context,
    detent: AllInSheetDetent.s,
    reducedMotion: reducedMotion,
    maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
    // P13 needs ~428 pt (display 56 + 16 + chips 36 + 16 + four 48 pt key
    // rows with 8 pt gaps + 8 + the 56 pt commit button + 16). At 411×914 the
    // flat 40 % detent gives 366 — short by exactly one key row, so ". 0 ⌫"
    // sat under the pinned button and the digit 0 and backspace were
    // unreachable without scrolling the presets out of view. The
    // `ConstrainedBox` still shrink-wraps: on a screen where the keypad fits
    // in less, the sheet is no taller than before.
    autoHeightFraction: 0.55,
    // The sheet hands the height to us so "Set · Raise to …" can be pinned.
    scrollable: false,
    child: BetKeypadSheet(
      legal: legal,
      currentBet: currentBet,
      value: value,
      enableHaptics: enableHaptics,
      reducedMotion: reducedMotion,
    ),
  );

  @override
  State<BetKeypadSheet> createState() => _BetKeypadSheetState();
}

class _BetKeypadSheetState extends State<BetKeypadSheet> {
  late String _entry = fmtBb(widget.value, widget.legal.bigBlind);

  int get _bigBlind => widget.legal.bigBlind;

  /// The typed bb string as a chip total, clamped to the legal window.
  int get _chips {
    final bb = double.tryParse(_entry) ?? 0;
    final raw = jsRound(bb * _bigBlind).toInt();
    return raw.clamp(widget.legal.minRaiseTo, widget.legal.maxRaiseTo);
  }

  void _type(String key) {
    setState(() {
      if (key == '⌫') {
        _entry = _entry.isEmpty ? '' : _entry.substring(0, _entry.length - 1);
        return;
      }
      if (key == '.') {
        if (_entry.contains('.')) return;
        _entry = _entry.isEmpty ? '0.' : '$_entry.';
        return;
      }
      if (_entry == '0') {
        _entry = key;
        return;
      }
      if (_entry.length >= 6) return;
      _entry = '$_entry$key';
    });
  }

  void _step(int deltaHalfBb) {
    final next = (_chips + deltaHalfBb * (_bigBlind ~/ 2)).clamp(
      widget.legal.minRaiseTo,
      widget.legal.maxRaiseTo,
    );
    setState(() => _entry = fmtBb(next, _bigBlind));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final detents = RaiseSizing.detents(widget.legal, widget.currentBet);
    final chips = _chips;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Stepper(label: '−', onTap: () => _step(-1)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_entry.isEmpty ? '0' : _entry} bb',
                      textAlign: TextAlign.center,
                      style: AllInText.mono(28, color: c.text),
                    ),
                    Text(
                      PlayCopy.keypadCaption(
                        fmtBb(widget.legal.minRaiseTo, _bigBlind),
                        fmtBb(widget.legal.maxRaiseTo, _bigBlind),
                      ),
                      textAlign: TextAlign.center,
                      style: AllInText.body(12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              _Stepper(label: '+', onTap: () => _step(1)),
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          // Everything between the display and the commit button gives way
          // first when the 40 % detent cannot hold all of §4.5's parts.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detents.length,
                      separatorBuilder:
                          (_, _) => const SizedBox(width: AllInSpace.sm),
                      itemBuilder: (context, i) {
                        final detent = detents[i];
                        return _DetentChip(
                          label: detent.label,
                          selected: detent.value == chips,
                          onTap:
                              () => setState(
                                () => _entry = fmtBb(detent.value, _bigBlind),
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AllInSpace.md),
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['.', '0', '⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AllInSpace.sm),
                      child: Row(
                        children: [
                          for (final key in row) ...[
                            if (key != row.first)
                              const SizedBox(width: AllInSpace.sm),
                            Expanded(
                              child: _Key(label: key, onTap: () => _type(key)),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          AllInButton.primary(
            label: 'Set · Raise to ${fmtBb(chips, _bigBlind)}',
            size: AllInButtonSize.lg,
            expand: true,
            reducedMotion: widget.reducedMotion,
            enableHaptics: widget.enableHaptics,
            onPressed: () => Navigator.of(context).pop(chips),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label:
          label == '+'
              ? 'Increase by half a big blind'
              : 'Decrease by half a big blind',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: c.ink700,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.md),
            onTap: onTap,
            child: Center(
              child: Text(label, style: AllInText.mono(20, color: c.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 48,
      child: Material(
        color: c.ink700,
        borderRadius: BorderRadius.circular(AllInRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AllInRadius.md),
          onTap: onTap,
          child: Center(
            child: Text(label, style: AllInText.mono(18, color: c.text)),
          ),
        ),
      ),
    );
  }
}

class _DetentChip extends StatelessWidget {
  const _DetentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.gold.withValues(alpha: 0.18) : c.ink700,
      borderRadius: BorderRadius.circular(AllInRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AllInRadius.pill),
        onTap: onTap,
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
          child: Text(
            label,
            style: AllInText.body(
              13,
              weight: FontWeight.w600,
              color: selected ? c.gold : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
