/// `FrameScrubber` — the 44 pt replay row (DESIGN.md §5.2, §10.6). Shared with
/// the hand replayer (§7.7): same row, same long-press-to-frame-list, same
/// `selectionClick` per frame.
///
/// `‹‹` first · `‹` previous · centre pill "● 5 / 6 · CO bets 5 bb" · `›` next
/// · `››` decision. Buttons are 44×44 and disabled (40 % opacity) at the ends;
/// the accessibility labels are the desktop's "First", "Previous", "Next" and
/// "Decision".
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class FrameScrubber extends StatelessWidget {
  const FrameScrubber({
    super.key,
    required this.index,
    required this.count,
    required this.text,
    required this.onIndexChanged,
    this.onPillLongPress,
    this.enableHaptics = true,
    this.semanticPrefix = 'Frame',
  });

  /// Zero-based frame index.
  final int index;

  /// Frame count; the last frame is the decision point.
  final int count;

  /// The current frame's text, ellipsised in the pill.
  final String text;

  final ValueChanged<int> onIndexChanged;

  /// Long-press the pill → D2 frame list (§5.2).
  final VoidCallback? onPillLongPress;

  final bool enableHaptics;

  /// Screen-reader prefix for the pill ("Frame 5 of 6").
  final String semanticPrefix;

  static const double height = 44;

  void _go(int next) {
    if (next == index || next < 0 || next >= count) return;
    if (enableHaptics) HapticFeedback.selectionClick();
    onIndexChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final atStart = index <= 0;
    final atEnd = index >= count - 1;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          _ScrubButton(
            icon: Icons.first_page,
            label: 'First',
            enabled: !atStart,
            onTap: () => _go(0),
          ),
          _ScrubButton(
            icon: Icons.chevron_left,
            label: 'Previous',
            enabled: !atStart,
            onTap: () => _go(index - 1),
          ),
          Expanded(
            child: Semantics(
              button: onPillLongPress != null,
              label: '$semanticPrefix ${index + 1} of $count. $text',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress:
                      onPillLongPress == null
                          ? null
                          : () {
                            if (enableHaptics) HapticFeedback.mediumImpact();
                            onPillLongPress!.call();
                          },
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AllInSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: c.ink800,
                      borderRadius: BorderRadius.circular(AllInRadius.pill),
                      border: Border.all(color: c.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: c.gold),
                        const SizedBox(width: AllInSpace.sm),
                        Text(
                          '${index + 1} / $count',
                          style: AllInText.mono(12, color: c.text),
                        ),
                        // Hosts that show the frame text full width beside
                        // the scrubber ([FrameTextLine]) pass an empty string;
                        // the pill is then just "● 4 / 4".
                        if (text.isNotEmpty) ...[
                          const SizedBox(width: AllInSpace.sm),
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AllInText.body(12, color: c.textMuted),
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
          _ScrubButton(
            icon: Icons.chevron_right,
            label: 'Next',
            enabled: !atEnd,
            onTap: () => _go(index + 1),
          ),
          _ScrubButton(
            icon: Icons.last_page,
            label: 'Decision',
            enabled: !atEnd,
            onTap: () => _go(count - 1),
          ),
        ],
      ),
    );
  }
}

class _ScrubButton extends StatelessWidget {
  const _ScrubButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 20, color: c.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frame's own sentence, full width, crossfading between frames.
///
/// The one line that says *what the spot is* does not belong inside a pill:
/// ellipsised at ~28 characters it read "Action on you in the CO…" /
/// "BB checks. Action on y…", so understanding the situation you are being
/// graded on cost a long-press into the frame list on every spot. The hand
/// replayer (§7.7) already gives the same kind of line its own row; this is
/// that row, shared.
class FrameTextLine extends StatelessWidget {
  const FrameTextLine({
    super.key,
    required this.text,
    this.reducedMotion = false,
    this.maxLines = 2,
  });

  final String text;
  final bool reducedMotion;
  final int maxLines;

  /// The band a host reserves for it at 1.0× text scale.
  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedSwitcher(
      duration: AllInMotion.of(
        context,
        AllInMotion.fast,
        reduced: reducedMotion,
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AllInText.body(13.5, color: c.text, height: 1.25),
      ),
    );
  }
}
