/// `AllInToast` — the 44 pt confirmation pill at the top of the content area,
/// 2.5 s (DESIGN.md §10.1; §16.2 presents it through an `Overlay` entry).
///
/// Confirmations only ("Hand history copied"), never errors that need a
/// decision — those are dialogs (§2.4).
library;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The `AllInScaffold` header band the toast has to clear: its 8 pt top
/// padding, the 44 pt title row and its 12 pt bottom padding.
const double _headerBand = AllInSpace.sm + 44 + AllInSpace.md;

class AllInToast extends StatelessWidget {
  const AllInToast({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  static const Duration duration = Duration(milliseconds: 2500);

  /// Shows [text] over the nearest overlay for 2.5 s. Replaces any toast that
  /// is still on screen so two confirmations never stack.
  static void show(
    BuildContext context,
    String text, {
    IconData? icon,
    Duration duration = AllInToast.duration,
    bool reducedMotion = false,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // Only entries still attached to a live overlay can be removed. Switching
    // the theme (§9) rebuilds `MaterialApp` and disposes the overlay a toast
    // in flight belongs to, and `remove()` on that entry asserts
    // `_owner != null` deep in the render tree — a red screen for a
    // confirmation pill.
    _removeCurrent();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (context) => _ToastHost(
            entry: entry,
            duration: duration,
            reducedMotion: reducedMotion,
            child: AllInToast(text: text, icon: icon),
          ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static OverlayEntry? _current;

  /// Removes the visible toast, if any (used when a route is torn down).
  static void dismiss() => _removeCurrent();

  static void _removeCurrent() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.lg,
              vertical: AllInSpace.sm,
            ),
            decoration: BoxDecoration(
              color: c.ink700,
              borderRadius: BorderRadius.circular(AllInRadius.pill),
              border: Border.all(color: c.lineStrong),
              boxShadow: [
                BoxShadow(
                  color: c.shadowColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: c.textMuted),
                  const SizedBox(width: AllInSpace.sm),
                ],
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AllInText.body(14, color: c.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.entry,
    required this.duration,
    required this.reducedMotion,
    required this.child,
  });

  final OverlayEntry entry;
  final Duration duration;
  final bool reducedMotion;
  final Widget child;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // §11: toast slides down / up in 200 ms.
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final reduced =
        widget.reducedMotion ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    _controller.duration = reduced ? Duration.zero : _controller.duration;
    await _controller.forward();
    await Future<void>.delayed(widget.duration);
    if (!mounted) return;
    await _controller.reverse();
    if (AllInToast._current == widget.entry) AllInToast._current = null;
    if (widget.entry.mounted) widget.entry.remove();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // §10.1 puts the pill at the top of the **content** area, not the top of
    // the screen: `padding.top + 8` landed it straight on the `AllInScaffold`
    // large title. Clear the header band instead (safe area + the 44 pt title
    // row + the header's own 12 pt bottom padding).
    final top = MediaQuery.paddingOf(context).top + _headerBand + AllInSpace.sm;
    return Positioned(
      top: top,
      left: AllInSpace.lg,
      right: AllInSpace.lg,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.4),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _controller, curve: AllInMotion.ease),
            ),
            // The root `Overlay` has no `Material` ancestor, so without this
            // the toast's `Text` picked up Flutter's "missing Material" debug
            // decoration — a yellow double underline under the sentence. It
            // wraps the *child*, not the `Positioned`, whose parent data
            // belongs to the overlay's own `Stack`.
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
