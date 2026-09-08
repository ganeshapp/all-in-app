/// `AllInCard` — the surface card behind every list row, tile and callout
/// (DESIGN.md §10.1).
///
/// `.plain` ink800 + line border · `.glass` ink800 @ 92 % · `.gold` gold @ 6 %
/// fill with a gold @ 25 % border · `.info` the same recipe in `info`.
/// Under "reduce transparency" (§13) the glass variant becomes opaque ink800.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

enum AllInCardVariant { plain, glass, gold, info }

class AllInCard extends StatelessWidget {
  const AllInCard({
    super.key,
    required this.child,
    this.variant = AllInCardVariant.plain,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
    this.onTap,
    this.borderRadius = AllInRadius.lg,
    this.borderWidth = 1,
    this.reduceTransparency = false,
    this.semanticLabel,
  });

  const AllInCard.plain({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
    this.onTap,
    this.borderRadius = AllInRadius.lg,
    this.borderWidth = 1,
    this.reduceTransparency = false,
    this.semanticLabel,
  }) : variant = AllInCardVariant.plain;

  const AllInCard.glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
    this.onTap,
    this.borderRadius = AllInRadius.lg,
    this.borderWidth = 1,
    this.reduceTransparency = false,
    this.semanticLabel,
  }) : variant = AllInCardVariant.glass;

  const AllInCard.gold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
    this.onTap,
    this.borderRadius = AllInRadius.lg,
    this.borderWidth = 1,
    this.reduceTransparency = false,
    this.semanticLabel,
  }) : variant = AllInCardVariant.gold;

  const AllInCard.info({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
    this.onTap,
    this.borderRadius = AllInRadius.lg,
    this.borderWidth = 1,
    this.reduceTransparency = false,
    this.semanticLabel,
  }) : variant = AllInCardVariant.info;

  final Widget child;
  final AllInCardVariant variant;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderRadius;

  /// 1 pt normally; the primary plan card draws its gold border at 1.5 (§3.1).
  final double borderWidth;
  final bool reduceTransparency;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fill, Color border) = switch (variant) {
      AllInCardVariant.plain => (c.ink800, c.line),
      AllInCardVariant.glass => (
        reduceTransparency ? c.ink800 : c.ink800.withValues(alpha: 0.92),
        c.line,
      ),
      AllInCardVariant.gold => (
        c.gold.withValues(alpha: 0.06),
        c.gold.withValues(alpha: 0.25),
      ),
      AllInCardVariant.info => (
        c.info.withValues(alpha: 0.06),
        c.info.withValues(alpha: 0.25),
      ),
    };

    final radius = BorderRadius.circular(borderRadius);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      surface = Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            // Whole card = one target; §3.1 sizes the smallest at 64/72 pt.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: surface,
            ),
          ),
        ),
      );
    } else if (semanticLabel != null) {
      surface = Semantics(label: semanticLabel, child: surface);
    }
    return surface;
  }
}
