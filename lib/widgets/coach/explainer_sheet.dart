/// `ExplainerSheet` — the one-idea explainer (DESIGN.md §10.5, §7.2).
///
/// `CoachNoteView` with no verdict header: title · the verbatim body · two
/// `DisclosureRow`s, **always** rendered, in the same two places with the same
/// two labels · an optional footer button. It is the single widget behind T1
/// (every ⓘ tile and dotted stat label), D3, D4, H2, the drill source-pill
/// sheet, the tool-screen and lesson ⓘ sheets and About's "How the grading
/// works" rows.
///
/// When [math] / [expert] are null the rows still open — to [CoachCopy]'s
/// written placeholders, never to blank space (§7.2, §14).
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/disclosure_row.dart';
import 'coach_note_view.dart';

class ExplainerSheet extends StatelessWidget {
  const ExplainerSheet({
    super.key,
    required this.title,
    required this.body,
    this.math,
    this.expert,
    this.footer,
    this.mathExtra,
    this.expertExtra,
    this.mathPlaceholder = CoachCopy.noMathDefinition,
    this.expertPlaceholder = CoachCopy.nothingExtra,
    this.alwaysExpandMath = false,
    this.onDisclosureToggle,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  /// Inter 17 semibold.
  final String title;

  /// Layer 1: the verbatim body, Inter 15/1.5, always open.
  final String body;

  /// Layer 2 ("Show me the math"). Null opens to [mathPlaceholder].
  final String? math;

  /// Layer 3 ("Expert detail"). Null opens to [expertPlaceholder].
  final String? expert;

  /// The optional footer button ("Review these spots ›", a lesson link).
  final Widget? footer;

  /// Rare widget bodies (a healthy-range band, a small chart) appended under
  /// the row's text.
  final Widget? mathExtra;
  final Widget? expertExtra;

  /// Overridable so the coach sheet's and the drill panel's wordings can be
  /// reused verbatim on surfaces that need them (§7.2).
  final String mathPlaceholder;
  final String expertPlaceholder;

  final bool alwaysExpandMath;
  final ValueChanged<bool>? onDisclosureToggle;
  final bool enableHaptics;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
        ),
        const SizedBox(height: AllInSpace.sm),
        Text(body, style: AllInText.body(15, color: c.text, height: 1.5)),
        const SizedBox(height: AllInSpace.sm),
        DisclosureRow(
          key: ValueKey('math-$title'),
          label: CoachCopy.showMath,
          expandedLabel: CoachCopy.hideMath,
          initiallyExpanded: alwaysExpandMath,
          onToggle: onDisclosureToggle,
          enableHaptics: enableHaptics,
          reducedMotion: reducedMotion,
          child: _body(context, math ?? mathPlaceholder, mathExtra),
        ),
        DisclosureRow(
          key: ValueKey('expert-$title'),
          label: CoachCopy.expertDetail,
          expandedLabel: CoachCopy.hideExpert,
          tone: DisclosureTone.muted,
          onToggle: onDisclosureToggle,
          enableHaptics: enableHaptics,
          reducedMotion: reducedMotion,
          child: _body(context, expert ?? expertPlaceholder, expertExtra),
        ),
        if (footer != null) ...[const SizedBox(height: AllInSpace.md), footer!],
      ],
    );
  }

  Widget _body(BuildContext context, String text, Widget? extra) {
    final line = Text(
      text,
      style: AllInText.body(15, color: context.colors.textMuted, height: 1.45),
    );
    if (extra == null) return line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [line, const SizedBox(height: AllInSpace.md), extra],
    );
  }
}
