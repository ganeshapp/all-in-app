/// `DisclosureRow` — the "▸ Show me the math" row (DESIGN.md §10.1, TONE.md
/// layers 2 and 3).
///
/// 48 pt tall, the chevron rotates as the row expands inline (`AnimatedSize`
/// on the §11 token), and the row is **always rendered** even when there is
/// nothing behind it: §14 says it opens to "No math…" rather than vanishing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

enum DisclosureTone { gold, muted }

class DisclosureRow extends StatefulWidget {
  const DisclosureRow({
    super.key,
    required this.label,
    this.expandedLabel,
    this.child,
    this.tone = DisclosureTone.gold,
    this.alwaysRendered = true,
    this.initiallyExpanded = false,
    this.onToggle,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  /// Collapsed label ("Show me the math").
  final String label;

  /// Optional different label once open ("Hide the math").
  final String? expandedLabel;

  /// What the row reveals. Null + [alwaysRendered] renders the row alone.
  final Widget? child;
  final DisclosureTone tone;

  /// False lets a caller drop the row entirely when there is no content.
  final bool alwaysRendered;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onToggle;
  final bool enableHaptics;
  final bool reducedMotion;

  static const double rowHeight = 48;

  @override
  State<DisclosureRow> createState() => _DisclosureRowState();
}

class _DisclosureRowState extends State<DisclosureRow> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onToggle?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.alwaysRendered && widget.child == null) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final fg = widget.tone == DisclosureTone.gold ? c.gold : c.textMuted;
    final duration = AllInMotion.of(
      context,
      AllInMotion.fast,
      reduced: widget.reducedMotion,
    );
    final label =
        _expanded ? (widget.expandedLabel ?? widget.label) : widget.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: label,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DisclosureRow.rowHeight,
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: duration,
                      curve: AllInMotion.ease,
                      child: Icon(Icons.chevron_right, size: 20, color: fg),
                    ),
                    const SizedBox(width: AllInSpace.xs),
                    Flexible(
                      child: Text(
                        label,
                        style: AllInText.body(
                          14,
                          weight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: AllInMotion.ease,
          alignment: Alignment.topCenter,
          child:
              _expanded && widget.child != null
                  ? Padding(
                    padding: const EdgeInsets.only(
                      left: AllInSpace.xl,
                      bottom: AllInSpace.md,
                    ),
                    child: widget.child,
                  )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
