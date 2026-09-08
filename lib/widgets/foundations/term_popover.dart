/// `TermPopover` — the anchored ≤ 280×180 definition card (DESIGN.md §10.1,
/// §6.3; presented with `OverlayPortal` + `CompositedTransformFollower` per
/// §16.2).
///
/// Wrap the thing that opens it (a dotted term, an ⓘ) as [child]. Definitions
/// come from [AllInGlossary], which the app fills once at bootstrap from the
/// study glossary — the widget layer never imports a feature.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// One glossary entry as the widget layer sees it.
class TermDefinition {
  const TermDefinition({
    required this.id,
    required this.term,
    required this.definition,
  });

  /// The `{{key}}` used in lesson text.
  final String id;

  /// Display form ("3-bet", "the nuts").
  final String term;
  final String definition;
}

/// Process-wide term lookup. `AllInGlossary.register(...)` is called once at
/// startup with the study glossary; widgets stay pure presentation.
class AllInGlossary {
  AllInGlossary._();

  static Map<String, TermDefinition> _terms = const <String, TermDefinition>{};

  static Map<String, TermDefinition> get terms => _terms;

  static void register(Iterable<TermDefinition> definitions) {
    _terms = <String, TermDefinition>{for (final d in definitions) d.id: d};
  }

  static TermDefinition? lookup(String id) => _terms[id];
}

class TermPopover extends StatefulWidget {
  const TermPopover({
    super.key,
    required this.termId,
    required this.child,
    this.definition,
    this.onOpenGlossary,
    this.openOnTap = true,
    this.controller,
    this.maxWidth = 280,
    this.maxHeight = 180,
    this.reducedMotion = false,
  });

  /// Glossary key; resolved through [AllInGlossary] when [definition] is null.
  final String termId;

  /// The anchor.
  final Widget child;

  /// Explicit definition (Stats explainers pass their own one-liner).
  final TermDefinition? definition;

  /// "Open glossary ›" → S4 scrolled to this term. Hidden when null.
  final void Function(String termId)? onOpenGlossary;

  /// False when the caller drives the popover through [controller].
  final bool openOnTap;
  final TermPopoverController? controller;
  final double maxWidth;
  final double maxHeight;
  final bool reducedMotion;

  @override
  State<TermPopover> createState() => _TermPopoverState();
}

/// Opens / closes a [TermPopover] from outside it.
class TermPopoverController extends ChangeNotifier {
  _TermPopoverState? _state;

  bool get isOpen => _state?._portal.isShowing ?? false;

  void open() => _state?._open();

  void close() => _state?._close();

  void toggle() => isOpen ? close() : open();

  void _notify() => notifyListeners();
}

class _TermPopoverState extends State<TermPopover> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _anchorKey = GlobalKey();

  Offset _followerOffset = Offset.zero;
  Alignment _targetAnchor = Alignment.bottomLeft;
  Alignment _followerAnchor = Alignment.topLeft;
  double _width = 280;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(TermPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    super.dispose();
  }

  TermDefinition? get _definition =>
      widget.definition ?? AllInGlossary.lookup(widget.termId);

  void _open() {
    final media = MediaQuery.of(context);
    _width = math.min(widget.maxWidth, media.size.width - AllInSpace.xl);

    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final topLeft = box.localToGlobal(Offset.zero);
      final spaceBelow =
          media.size.height -
          media.padding.bottom -
          (topLeft.dy + box.size.height);
      final below = spaceBelow >= widget.maxHeight + AllInSpace.md;
      _targetAnchor = below ? Alignment.bottomLeft : Alignment.topLeft;
      _followerAnchor = below ? Alignment.topLeft : Alignment.bottomLeft;

      final minX = AllInSpace.md;
      final maxX = math.max(minX, media.size.width - _width - AllInSpace.md);
      final wantedX = topLeft.dx.clamp(minX, maxX);
      _followerOffset = Offset(wantedX - topLeft.dx, below ? 6 : -6);
    }
    _portal.show();
    widget.controller?._notify();
  }

  void _close() {
    _portal.hide();
    widget.controller?._notify();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(
          key: _anchorKey,
          child:
              widget.openOnTap
                  ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _open,
                    child: widget.child,
                  )
                  : widget.child,
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final c = context.colors;
    final def = _definition;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: _targetAnchor,
            followerAnchor: _followerAnchor,
            offset: _followerOffset,
            child: Align(
              alignment: Alignment.topLeft,
              child: AnimatedOpacity(
                opacity: 1,
                duration: AllInMotion.of(
                  context,
                  AllInMotion.fast,
                  reduced: widget.reducedMotion,
                ),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Material(
                    type: MaterialType.transparency,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _width,
                        maxHeight: widget.maxHeight,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.ink700,
                          borderRadius: BorderRadius.circular(AllInRadius.lg),
                          border: Border.all(color: c.lineStrong),
                          boxShadow: [
                            BoxShadow(
                              color: c.shadowColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AllInSpace.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                def?.term ?? widget.termId,
                                style: AllInText.display(
                                  15,
                                  weight: FontWeight.w700,
                                  color: c.goldLight,
                                ),
                              ),
                              const SizedBox(height: AllInSpace.xs),
                              Text(
                                def?.definition ??
                                    'No definition for this term yet.',
                                style: AllInText.body(14, color: c.text),
                              ),
                              if (widget.onOpenGlossary != null) ...[
                                const SizedBox(height: AllInSpace.sm),
                                Semantics(
                                  button: true,
                                  label: 'Open glossary',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      _close();
                                      widget.onOpenGlossary!(widget.termId);
                                    },
                                    child: SizedBox(
                                      height: 44,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Open glossary ›',
                                          style: AllInText.body(
                                            14,
                                            weight: FontWeight.w600,
                                            color: c.gold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
