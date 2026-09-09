/// S5 · Card keypad (DESIGN.md §6.5): a sheet M with four suit rows of 13 rank
/// keys. Keys are 26×36 inside a 44 pt row, rank `T` reads "10", glyphs are
/// suit-coloured, cards already in play are disabled at 30 %, and the sheet
/// stays open until "Done" so several cards can be picked in one visit.
library;

import 'package:allin/engine/types.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart' hide Card;

class CardKeypadSheet extends StatefulWidget {
  const CardKeypadSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.max,
    this.disabled = const <Card>{},
    this.fourColorDeck = false,
    this.reducedMotion = false,
  });

  /// "Board" / "Your hand" — the header reads "{title} · {n}/{max}".
  final String title;
  final List<Card> initial;

  /// 5 for the board, 2 for an exact hand.
  final int max;

  /// Cards in play elsewhere; shown at 30 % and not tappable.
  final Set<Card> disabled;
  final bool fourColorDeck;
  final bool reducedMotion;

  /// Opens the keypad and resolves with the picked cards, or null on dismiss.
  static Future<List<Card>?> show(
    BuildContext context, {
    required String title,
    required List<Card> initial,
    required int max,
    Set<Card> disabled = const <Card>{},
    bool fourColorDeck = false,
    bool reducedMotion = false,
  }) {
    return AllInSheet.show<List<Card>>(
      context,
      detent: AllInSheetDetent.m,
      reducedMotion: reducedMotion,
      builder:
          (_) => CardKeypadSheet(
            title: title,
            initial: initial,
            max: max,
            disabled: disabled,
            fourColorDeck: fourColorDeck,
            reducedMotion: reducedMotion,
          ),
    );
  }

  @override
  State<CardKeypadSheet> createState() => _CardKeypadSheetState();
}

class _CardKeypadSheetState extends State<CardKeypadSheet> {
  late final List<Card> _picked = List<Card>.of(widget.initial);

  void _toggle(Card card) {
    setState(() {
      if (_picked.contains(card)) {
        _picked.remove(card);
      } else if (_picked.length < widget.max) {
        _picked.add(card);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${widget.title} · ${_picked.length}/${widget.max}',
                  style: AllInText.body(
                    15,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              if (_picked.isNotEmpty)
                _TextButton(
                  label: 'Clear',
                  onTap: () => setState(_picked.clear),
                ),
            ],
          ),
          const SizedBox(height: AllInSpace.sm),
          SizedBox(
            height: PlayingCardView.heightFor(PlayingCardView.xs),
            child:
                _picked.isEmpty
                    ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Nothing picked yet',
                        style: AllInText.body(12.5, color: c.textFaint),
                      ),
                    )
                    : Row(
                      children: <Widget>[
                        for (final card in _picked) ...<Widget>[
                          PlayingCardView(
                            card: card,
                            width: PlayingCardView.xs,
                            fourColorDeck: widget.fourColorDeck,
                          ),
                          const SizedBox(width: AllInSpace.xs),
                        ],
                      ],
                    ),
          ),
          const SizedBox(height: AllInSpace.sm),
          for (final suit in kSuits)
            _SuitRow(
              suit: suit,
              picked: _picked,
              disabled: widget.disabled,
              full: _picked.length >= widget.max,
              fourColorDeck: widget.fourColorDeck,
              onTap: _toggle,
            ),
          const SizedBox(height: AllInSpace.md),
          AllInButton.primary(
            label: 'Done',
            size: AllInButtonSize.md,
            expand: true,
            reducedMotion: widget.reducedMotion,
            onPressed: () => Navigator.of(context).pop(List<Card>.of(_picked)),
          ),
        ],
      ),
    );
  }
}

class _SuitRow extends StatelessWidget {
  const _SuitRow({
    required this.suit,
    required this.picked,
    required this.disabled,
    required this.full,
    required this.fourColorDeck,
    required this.onTap,
  });

  final String suit;
  final List<Card> picked;
  final Set<Card> disabled;
  final bool full;
  final bool fourColorDeck;
  final ValueChanged<Card> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final glyph = PlayingCardView.suitGlyph(suit);
    final suitColor = PlayingCardView.suitColor(
      suit,
      fourColorDeck: fourColorDeck,
    );
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          for (final rank in kRanksDesc)
            Expanded(
              child: Builder(
                builder: (context) {
                  final card = '$rank$suit';
                  final isPicked = picked.contains(card);
                  final isDisabled =
                      disabled.contains(card) || (full && !isPicked);
                  final label = rank == 'T' ? '10' : rank;
                  return Semantics(
                    button: true,
                    enabled: !isDisabled,
                    selected: isPicked,
                    label: '$label $glyph',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isDisabled ? null : () => onTap(card),
                      child: Center(
                        child: Opacity(
                          opacity: isDisabled ? 0.3 : 1,
                          child: Container(
                            height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPicked ? c.gold : c.ink800,
                              border: Border.all(color: c.line),
                              borderRadius: BorderRadius.circular(
                                AllInRadius.sm,
                              ),
                            ),
                            child: FittedBox(
                              child: Text(
                                '$label$glyph',
                                style: AllInText.body(
                                  11.5,
                                  weight: FontWeight.w700,
                                  color: isPicked ? c.ink900 : suitColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
          child: Text(
            label,
            style: AllInText.body(13, weight: FontWeight.w600, color: c.gold),
          ),
        ),
      ),
    );
  }
}

/// A gold text button sized for lesson widgets ("Any two", "Clear", "Edit").
class StudyTextButton extends StatelessWidget {
  const StudyTextButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
          child: Text(
            label,
            style: AllInText.body(
              13,
              weight: FontWeight.w600,
              color: onTap == null ? c.textFaint : c.gold,
            ),
          ),
        ),
      ),
    );
  }
}
