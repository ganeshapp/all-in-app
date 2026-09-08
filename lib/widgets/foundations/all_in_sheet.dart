/// `AllInSheet` — the bottom-sheet wrapper (DESIGN.md §2.4, §10.1, §16.2).
///
/// Detents S (auto-height, capped at 40 % of the viewport), M (55 %) and
/// L (92 %). `maxHeightFraction` is the §2.4 table cap and clamps **all three**
/// detents, so a sheet presented from a `/table*` route can never cover the
/// context row + action row. `blocking` drops the grabber, the scrim tap and
/// the drag: only the sheet's own button advances (§2.4 Panel rules), and
/// system back is the acknowledgement (§2.5). Transitions pass the reduced
/// motion zero explicitly (§11) because `showModalBottomSheet` will not.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';

enum AllInSheetDetent { s, m, l }

class AllInSheet extends StatefulWidget {
  const AllInSheet({
    super.key,
    required this.child,
    this.detent = AllInSheetDetent.m,
    this.onClose,
    this.maxHeightFraction = 1,
    this.dismissible = true,
    this.showGrabber = true,
    this.blocking = false,
    this.onDetentChanged,
    this.reducedMotion = false,
  });

  final Widget child;
  final AllInSheetDetent detent;

  /// Called when the sheet is dismissed (scrim, swipe, system back).
  final VoidCallback? onClose;

  /// §2.4's cap, as a fraction of the screen height. 1 = uncapped.
  final double maxHeightFraction;

  /// False for the blocking coach note: no scrim dismiss, no swipe-down.
  final bool dismissible;
  final bool showGrabber;

  /// Panel behaviour: no grabber, no scrim dismiss, only its own button.
  final bool blocking;
  final ValueChanged<AllInSheetDetent>? onDetentChanged;
  final bool reducedMotion;

  static const double sFraction = 0.40;
  static const double mFraction = 0.55;
  static const double lFraction = 0.92;

  /// §11: sheets open in 250 ms and close in 200 ms.
  static const Duration openDuration = AllInMotion.base;
  static const Duration closeDuration = Duration(milliseconds: 200);

  static double fractionOf(AllInSheetDetent detent) => switch (detent) {
    AllInSheetDetent.s => sFraction,
    AllInSheetDetent.m => mFraction,
    AllInSheetDetent.l => lFraction,
  };

  /// The cap every sheet presented from a `/table*` route passes: the bottom
  /// 120 pt (context row + action row) plus the inset stay visible (§2.4).
  static double tableMaxHeightFraction(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    if (h <= 0) return 1;
    return ((h - 120 - media.padding.bottom) / h).clamp(0.1, 1.0);
  }

  /// Presents the sheet as a modal route and returns its result (§16.2).
  static Future<T?> show<T>(
    BuildContext context, {
    Widget? child,
    WidgetBuilder? builder,
    AllInSheetDetent detent = AllInSheetDetent.m,
    double maxHeightFraction = 1,
    bool dismissible = true,
    bool showGrabber = true,
    bool blocking = false,
    ValueChanged<AllInSheetDetent>? onDetentChanged,
    VoidCallback? onClose,
    bool reducedMotion = false,
    bool useRootNavigator = false,
  }) {
    assert(child != null || builder != null, 'Pass a child or a builder.');
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final reduced =
        reducedMotion ||
        MediaQuery.maybeDisableAnimationsOf(context) == true ||
        MediaQuery.accessibleNavigationOf(context);
    final controller = AnimationController(
      vsync: navigator,
      duration: reduced ? Duration.zero : openDuration,
      reverseDuration: reduced ? Duration.zero : closeDuration,
    );
    // The sheet future completes when the route is *popped*, which is before
    // the exit transition finishes — disposing there would freeze the sheet
    // half-way out. Wait for the controller to reach `dismissed` instead.
    var disposeScheduled = false;
    controller.addStatusListener((status) {
      if (status != AnimationStatus.dismissed || disposeScheduled) return;
      disposeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    });
    final canDismiss = dismissible && !blocking;

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: canDismiss,
      enableDrag: canDismiss,
      backgroundColor: Colors.transparent,
      // The scrim still fades under reduced motion — opacity is not motion.
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionAnimationController: controller,
      // `onClose` fires from the route's future instead of the widget, so a
      // scrim tap, a swipe-down and system back all report exactly once.
      builder:
          (sheetContext) => AllInSheet(
            detent: detent,
            maxHeightFraction: maxHeightFraction,
            dismissible: dismissible,
            showGrabber: showGrabber,
            blocking: blocking,
            onDetentChanged: onDetentChanged,
            reducedMotion: reduced,
            child: child ?? builder!(sheetContext),
          ),
    ).whenComplete(() => onClose?.call());
  }

  @override
  State<AllInSheet> createState() => _AllInSheetState();
}

class _AllInSheetState extends State<AllInSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();
  AllInSheetDetent? _reported;

  @override
  void initState() {
    super.initState();
    _reported = widget.detent;
    _controller.addListener(_onSize);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSize);
    _controller.dispose();
    super.dispose();
  }

  double _cap(double fraction) =>
      math.min(fraction, widget.maxHeightFraction.clamp(0.1, 1.0));

  void _onSize() {
    if (!_controller.isAttached || widget.onDetentChanged == null) return;
    final size = _controller.size;
    var nearest = AllInSheetDetent.s;
    var best = double.infinity;
    for (final d in AllInSheetDetent.values) {
      final delta = (size - _cap(AllInSheet.fractionOf(d))).abs();
      if (delta < best) {
        best = delta;
        nearest = d;
      }
    }
    if (nearest != _reported) {
      _reported = nearest;
      widget.onDetentChanged!(nearest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        widget.detent == AllInSheetDetent.s
            ? _autoHeight(context)
            : _draggable(context);

    if (!widget.blocking) return content;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // §2.5: on a blocking sheet, system back *is* the acknowledgement.
        widget.onClose?.call();
        Navigator.of(context).pop();
      },
      child: content,
    );
  }

  /// Detent S: hugs its content, capped at 40 % of the viewport (§10.1).
  Widget _autoHeight(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height * _cap(AllInSheet.sFraction);
    return _chrome(
      context,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: widget.child),
      ),
    );
  }

  Widget _draggable(BuildContext context) {
    final fractions =
        <double>{
            for (final d in AllInSheetDetent.values)
              _cap(AllInSheet.fractionOf(d)),
          }.toList()
          ..sort();
    final min = fractions.first;
    final max = fractions.last;
    final initial = _cap(AllInSheet.fractionOf(widget.detent)).clamp(min, max);
    final snaps = fractions
        .where((f) => f > min && f < max)
        .toList(growable: false);

    return DraggableScrollableSheet(
      controller: _controller,
      expand: false,
      snap: true,
      snapSizes: snaps.isEmpty ? null : snaps,
      initialChildSize: initial,
      minChildSize: min,
      maxChildSize: max,
      builder:
          (context, scrollController) => _chrome(
            context,
            child: SingleChildScrollView(
              controller: scrollController,
              child: widget.child,
            ),
          ),
    );
  }

  Widget _chrome(BuildContext context, {required Widget child}) {
    final c = context.colors;
    final showGrabber = widget.showGrabber && !widget.blocking;
    return Container(
      decoration: BoxDecoration(
        color: c.ink800,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AllInRadius.xl),
        ),
        border: Border(top: BorderSide(color: c.line)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showGrabber)
            Semantics(
              label: 'Drag handle',
              child: SizedBox(
                height: 20,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.ink500,
                      borderRadius: BorderRadius.circular(AllInRadius.pill),
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: AllInSpace.sm),
          Flexible(child: child),
        ],
      ),
    );
  }
}
