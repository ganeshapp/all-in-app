/// One replayable hand as a row (DESIGN.md §7.5) and the swipe container it
/// sits in.
///
/// Row 56, two lines when a note exists: "Hand #41 · Today 18:10" · signed net
/// · ✎ (gold when a note exists) · an "imported" badge when `h.imported`.
/// Swipe-left reveals "Note" and "Export" — 72 pt each, both over the 44 pt
/// floor, and the row itself stays a tap target for the replayer.
library;

import 'package:flutter/material.dart';

import '../../../services/persistence.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../engine/engine.dart' show fmtSigned;
import '../stats_copy.dart';
import '../stats_format.dart';

class HandRow extends StatelessWidget {
  const HandRow({
    super.key,
    required this.hand,
    this.note,
    required this.onOpen,
    required this.onNote,
    this.onExport,
    this.reducedMotion = false,
  });

  final StoredHand hand;
  final HandNote? note;

  /// Tap the row → P11.
  final VoidCallback onOpen;

  /// Tap ✎, or the swipe action → P12.
  final VoidCallback onNote;

  /// Swipe-left "Export" — shares this hand's text.
  final VoidCallback? onExport;

  final bool reducedMotion;

  bool get _hasNote =>
      note != null && (note!.note.trim().isNotEmpty || note!.tags.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final net = fmtSigned(hand.netBb);
    final time = handTimeLabel(hand.startedAt);

    // The row is two targets, not one: the body opens P11 and the ✎ opens
    // P12. Only the body's own text is excluded from semantics — wrapping the
    // whole row would swallow the ✎ button's label (§13).
    final body = Semantics(
      button: true,
      label: [
        'Hand ${hand.hand.id}',
        time,
        '$net big blinds',
        if (hand.imported) StatsCopy.importedBadge,
        if (_hasNote) 'has a note',
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AllInSpace.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Hand #${hand.hand.id} · $time',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AllInText.body(14, color: c.text),
                              ),
                            ),
                            if (hand.imported) ...[
                              const SizedBox(width: AllInSpace.sm),
                              const _ImportedBadge(),
                            ],
                          ],
                        ),
                        if (_hasNote) ...[
                          const SizedBox(height: 2),
                          _NoteLine(note: note!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    '$net bb',
                    style: AllInText.mono(
                      14,
                      color: hand.netBb >= 0 ? c.good : c.bad,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return SwipeActionRow(
      reducedMotion: reducedMotion,
      actions: [
        SwipeAction(
          label: StatsCopy.swipeNote,
          icon: Icons.edit_outlined,
          onPressed: onNote,
        ),
        if (onExport != null)
          SwipeAction(
            label: StatsCopy.swipeExport,
            icon: Icons.ios_share,
            onPressed: onExport!,
          ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: body),
          Align(
            alignment: Alignment.topCenter,
            child: _NoteButton(hasNote: _hasNote, onPressed: onNote),
          ),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note});

  final HandNote note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (final tag in note.tags) ...[
          Container(
            margin: const EdgeInsets.only(right: AllInSpace.xs),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AllInRadius.pill),
            ),
            child: Text(tag, style: AllInText.body(11, color: c.gold)),
          ),
        ],
        if (note.note.trim().isNotEmpty)
          Expanded(
            child: Text(
              note.note.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AllInText.body(12, color: c.textMuted),
            ),
          ),
      ],
    );
  }
}

class _ImportedBadge extends StatelessWidget {
  const _ImportedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.ink700,
        borderRadius: BorderRadius.circular(AllInRadius.pill),
        border: Border.all(color: c.line),
      ),
      child: Text(
        StatsCopy.importedBadge,
        style: AllInText.body(10, color: c.textFaint),
      ),
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.hasNote, required this.onPressed});

  final bool hasNote;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = hasNote ? StatsCopy.noteAction : StatsCopy.addNoteAction;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(
              hasNote ? Icons.bookmark : Icons.bookmark_border,
              color: hasNote ? c.gold : c.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// One revealed action behind a row.
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// A row that reveals [actions] on a left swipe (§7.5, §12 "swipe-left →
/// Note · Export").
///
/// The drag is horizontal-only, so the enclosing vertical `Scrollable` keeps
/// every vertical pointer — the same one-owner-per-pointer rule the charts
/// follow (§7.3). Tapping an action closes the row first, so a second swipe
/// never lands on a half-open row.
class SwipeActionRow extends StatefulWidget {
  const SwipeActionRow({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 76,
    this.reducedMotion = false,
  });

  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;
  final bool reducedMotion;

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: AllInMotion.fast,
    value: 0,
  );

  double get _maxReveal => widget.actions.length * widget.actionWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slide.duration = AllInMotion.of(
      context,
      AllInMotion.fast,
      reduced: widget.reducedMotion,
    );
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    if (_maxReveal <= 0) return;
    final next = (_slide.value - d.primaryDelta! / _maxReveal).clamp(0.0, 1.0);
    _slide.value = next;
  }

  void _end(DragEndDetails d) {
    final fling = d.primaryVelocity ?? 0;
    if (fling < -200) {
      _slide.animateTo(1);
    } else if (fling > 200) {
      _slide.animateTo(0);
    } else {
      _slide.animateTo(_slide.value >= 0.5 ? 1 : 0);
    }
  }

  void _run(SwipeAction action) {
    _slide.animateTo(0);
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final reveal = _slide.value * _maxReveal;
        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: ClipRect(
                  child: SizedBox(
                    width: reveal,
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      maxWidth: _maxReveal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final a in widget.actions)
                            _SwipeButton(
                              action: a,
                              width: widget.actionWidth,
                              onPressed: () => _run(a),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The translation wraps the detector, not the other way round:
            // an opaque detector at the row's full width would sit on top of
            // the revealed buttons and swallow their taps.
            Transform.translate(
              offset: Offset(-reveal, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _drag,
                onHorizontalDragEnd: _end,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SwipeButton extends StatelessWidget {
  const _SwipeButton({
    required this.action,
    required this.width,
    required this.onPressed,
  });

  final SwipeAction action;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: action.label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: Size(width, 44),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AllInRadius.md),
              ),
              backgroundColor: c.ink800,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 16, color: c.textMuted),
                const SizedBox(height: 2),
                Text(
                  action.label,
                  style: AllInText.body(11, color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
