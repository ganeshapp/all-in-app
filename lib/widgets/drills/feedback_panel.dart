/// `FeedbackPanel` — D1, the two-detent drill verdict panel (DESIGN.md §5.3,
/// §2.4 "Panel", §10.6).
///
/// It is a **panel, not a sheet**: there is no scrim, dragging down past the
/// compact detent does not dismiss it, and only its own primary button
/// advances (system back collapses it to compact — the host screen owns that
/// `PopScope`). The header and the primary button are pinned; only the middle
/// scrolls, which is what makes the compact detent fit at 390×844 (§5.1).
///
/// Overscrolling the expanded panel past 60 pt shows "Release for the next
/// puzzle" and fires [onNext] on release — the one-thumb chain of §5.3.
library;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class FeedbackPanel extends StatefulWidget {
  const FeedbackPanel({
    super.key,
    required this.expanded,
    required this.onExpandedChanged,
    required this.header,
    required this.body,
    required this.primary,
    this.onNext,
    this.scrollController,
    this.reducedMotion = false,
  });

  /// Compact (false) or expanded (true, 92 %).
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// Pinned: verdict badge, rating delta, EV-loss line, schedule line.
  final Widget header;

  /// Scrolls: rationale, outcomes box, the two disclosure rows, secondary row.
  final Widget body;

  /// Pinned at the bottom: "Next puzzle".
  final Widget primary;

  /// Overscroll-to-next (§5.3).
  final VoidCallback? onNext;

  final ScrollController? scrollController;
  final bool reducedMotion;

  /// Overscroll needed before the release-for-next hint arms (§5.3).
  static const double overscrollForNext = 60;

  /// A drag of this many points switches detent.
  static const double detentDrag = 40;

  /// §11: the panel springs up in 280 ms.
  static const Duration rise = Duration(milliseconds: 280);

  @override
  State<FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<FeedbackPanel> {
  double _drag = 0;
  double _overscroll = 0;
  bool _armed = false;

  void _dragUpdate(DragUpdateDetails d) {
    _drag += d.delta.dy;
    if (_drag <= -FeedbackPanel.detentDrag && !widget.expanded) {
      _drag = 0;
      widget.onExpandedChanged(true);
    } else if (_drag >= FeedbackPanel.detentDrag && widget.expanded) {
      _drag = 0;
      widget.onExpandedChanged(false);
    }
    // Dragging down at the compact detent does nothing: the verdict stays.
  }

  bool _onScroll(ScrollNotification n) {
    if (widget.onNext == null || !widget.expanded) return false;
    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final over = n.metrics.pixels - n.metrics.maxScrollExtent;
      _overscroll = over > 0 ? over : 0;
      final armed = _overscroll >= FeedbackPanel.overscrollForNext;
      if (armed != _armed) setState(() => _armed = armed);
    } else if (n is ScrollEndNotification) {
      if (_armed) {
        _armed = false;
        _overscroll = 0;
        widget.onNext!.call();
      } else if (_overscroll != 0) {
        setState(() => _overscroll = 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.ink800,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AllInRadius.lg),
          ),
          border: Border(top: BorderSide(color: c.line)),
          boxShadow: [
            BoxShadow(
              color: c.shadowColor,
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _drag = 0,
              onVerticalDragUpdate: _dragUpdate,
              onVerticalDragEnd: (_) => _drag = 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label:
                        widget.expanded
                            ? 'Collapse the feedback panel'
                            : 'Expand the feedback panel',
                    onTap: () => widget.onExpandedChanged(!widget.expanded),
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AllInSpace.sm,
                        ),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.ink500,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AllInSpace.lg,
                      0,
                      AllInSpace.lg,
                      AllInSpace.sm,
                    ),
                    child: widget.header,
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AllInSpace.lg,
                    0,
                    AllInSpace.lg,
                    AllInSpace.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      widget.body,
                      AnimatedOpacity(
                        opacity: _armed ? 1 : 0,
                        duration: AllInMotion.of(
                          context,
                          AllInMotion.fast,
                          reduced: widget.reducedMotion,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: AllInSpace.sm),
                          child: Text(
                            'Release for the next puzzle',
                            textAlign: TextAlign.center,
                            style: AllInText.body(12, color: c.textFaint),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AllInSpace.lg,
                AllInSpace.sm,
                AllInSpace.lg,
                AllInSpace.sm + MediaQuery.paddingOf(context).bottom,
              ),
              child: widget.primary,
            ),
          ],
        ),
      ),
    );
  }
}
