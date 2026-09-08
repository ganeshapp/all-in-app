/// `StatTile` — label + mono value (+ optional sub-line) used by the KPI grid,
/// the session sheet, the results card and every calculator (DESIGN.md §10.1,
/// §7.2). `onInfo` opens the one-idea explainer (T1) from a 44 pt ⓘ target.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

enum StatTone { neutral, good, bad, gold }

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.tone = StatTone.neutral,
    this.onInfo,
    this.onTap,
    this.height = heightSmall,
    this.infoSemanticLabel,
  });

  final String label;

  /// Always mono — every changing number is mono (§16.5).
  final String value;
  final String? sub;
  final StatTone tone;

  /// Opens the explainer sheet; renders the ⓘ button when non-null.
  final VoidCallback? onInfo;
  final VoidCallback? onTap;

  /// §10.1 sizes: 72 (KPI row) and 96 (hero tiles). Treated as a minimum so
  /// the tile grows instead of clipping at 1.3× text (§13).
  final double height;
  final String? infoSemanticLabel;

  static const double heightSmall = 72;
  static const double heightLarge = 96;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final valueColor = switch (tone) {
      StatTone.neutral => c.text,
      StatTone.good => c.good,
      StatTone.bad => c.bad,
      StatTone.gold => c.gold,
    };
    final big = height >= heightLarge;

    final content = Padding(
      padding: const EdgeInsets.all(AllInSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.eyebrow(c.textFaint),
                ),
              ),
              if (onInfo != null) const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AllInSpace.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AllInText.mono(
              big ? 26 : 20,
              weight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AllInText.body(12, color: c.textMuted),
            ),
          ],
        ],
      ),
    );

    final semantics = <String>[label, value, if (sub != null) sub!].join(', ');

    Widget tile = Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: c.ink800,
        borderRadius: BorderRadius.circular(AllInRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Stack(
        children: [
          ExcludeSemantics(child: content),
          if (onInfo != null)
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: infoSemanticLabel ?? 'About $label',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onInfo,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: c.textFaint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      tile = Semantics(
        button: true,
        container: true,
        explicitChildNodes: true,
        label: semantics,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: tile,
        ),
      );
    } else {
      tile = Semantics(
        container: true,
        explicitChildNodes: true,
        label: semantics,
        child: tile,
      );
    }
    return tile;
  }
}
