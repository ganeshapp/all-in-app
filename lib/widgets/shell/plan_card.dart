/// `PlanCard` — Home's plan card (DESIGN.md §10.2, anatomy in §3.1).
///
/// 16 pt padding, radius `AllInRadius.xl`, a 20 pt icon in a 32 pt gold-tinted
/// square, title Inter 17 semibold, subtitle Inter 14 muted, estimate mono 13
/// right-aligned. The primary card draws a 1.5 pt gold border and carries an
/// explicit 44 pt button for first-day users; every other card is tappable as
/// a whole (one 72 pt target).
///
/// Nothing here is fixed-height: §13 asks for 1.3× dynamic type without
/// truncation, so the wireframe's 96 / 72 are minimum heights and the card
/// grows instead of clipping.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/all_in_card.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.estimate,
    this.button,
    this.primary = false,
    this.onTap,
    this.semanticLabel,
  });

  /// The 20 pt glyph in the gold-tinted square.
  final IconData icon;

  final String title;
  final String? subtitle;

  /// "~2 min" — mono 13, right-aligned. Null renders no time column.
  final String? estimate;

  /// The primary card's 44 pt button (an [AllInButton]).
  final Widget? button;

  /// Gold 1.5 pt border + the button row (§3.1).
  final bool primary;

  final VoidCallback? onTap;

  /// Screen-reader label for the whole card; defaults to the visible text.
  final String? semanticLabel;

  /// §3.1's card heights, as minimums.
  static const double primaryMinHeight = 96;
  static const double minHeight = 72;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AllInRadius.md),
          ),
          child: Icon(icon, size: 20, color: c.gold),
        ),
        const SizedBox(width: AllInSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AllInText.body(
                  17,
                  weight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AllInText.body(14, color: c.textMuted, height: 1.3),
                ),
              ],
            ],
          ),
        ),
        if (estimate != null) ...[
          const SizedBox(width: AllInSpace.sm),
          Text(estimate!, style: AllInText.mono(13, color: c.textFaint)),
        ],
      ],
    );

    return AllInCard(
      variant: primary ? AllInCardVariant.gold : AllInCardVariant.plain,
      borderRadius: AllInRadius.xl,
      borderWidth: primary ? 1.5 : 1,
      padding: const EdgeInsets.all(AllInSpace.lg),
      onTap: onTap,
      semanticLabel: semanticLabel ?? _label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              (primary ? primaryMinHeight : minHeight) - 2 * AllInSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            head,
            if (button != null) ...[
              const SizedBox(height: AllInSpace.md),
              Align(alignment: Alignment.centerRight, child: button),
            ],
          ],
        ),
      ),
    );
  }

  String get _label => [
    title,
    if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
    if (estimate != null) estimate!,
  ].join(', ');
}
