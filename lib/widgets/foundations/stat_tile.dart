/// `StatTile` — label + mono value (+ optional sub-line) used by the KPI grid,
/// the session sheet, the results card and every calculator (DESIGN.md §10.1,
/// §7.2). `onInfo` opens the one-idea explainer (T1) from a 44 pt ⓘ target.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

enum StatTone {
  neutral,
  good,
  bad,
  gold,

  /// A number that is deliberately *not* a result: a flat zero, or a stat
  /// that has nothing to say yet. Reads as a neutral fact, not a verdict.
  muted;

  /// The signed-money rule of §13 / principle 8, as a tile tone: a win is
  /// [good], a loss is [bad], and a flat zero is [muted] rather than green —
  /// "+0.0 bb" in the win colour draws the eye to nothing having happened.
  /// Mirrors `context.colors.money()` so tiles and inline numbers agree.
  static StatTone money(num value) =>
      value > 0 ? StatTone.good : (value < 0 ? StatTone.bad : StatTone.muted);
}

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

  /// The ⓘ hit target (§13's 44 pt floor) and the glyph centred inside it.
  static const double infoTarget = 44;
  static const double infoGlyph = 16;

  /// How far the ⓘ *glyph* reaches into the padded content box, plus 4 pt of
  /// air. Only this much is reserved beside the label — reserving the whole
  /// 44 pt target left "WIN RATE" 30 pt at 360 and it rendered as "WIN R…".
  /// The target keeps its 44 pt; it simply overlaps the label's dead space.
  static const double infoReserve =
      (infoTarget - infoGlyph) / 2 - AllInSpace.md + infoGlyph + 4;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final valueColor = switch (tone) {
      StatTone.neutral => c.text,
      StatTone.good => c.good,
      StatTone.bad => c.bad,
      StatTone.gold => c.gold,
      StatTone.muted => c.textMuted,
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
                  // Two lines rather than an ellipsis: at 360 pt and at 1.3×
                  // text a KPI label is wider than a third of the row, and a
                  // truncated stat name ("WIN R…") names nothing. The tile's
                  // height is a minimum, so it grows to hold the wrap (§13).
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.eyebrow(c.textFaint),
                ),
              ),
              if (onInfo != null) const SizedBox(width: infoReserve),
            ],
          ),
          const SizedBox(height: AllInSpace.xs),
          // The value is the tile. A label may wrap and a sub-line may
          // ellipsise, but "−10.5" truncated to "−10…" is the one thing this
          // component must never do — at 360 pt and 1.3× text a three-across
          // KPI row is narrower than the number. It scales down instead, and
          // only ever from 20/26 pt, so it stays far above §13's 11 pt floor.
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AllInText.mono(
                  big ? 26 : 20,
                  weight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
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
        // `passthrough`, not the default loose fit: a `StatTile` in a
        // stretched row (the KPI grid's `IntrinsicHeight`) is as tall as the
        // tallest tile beside it, and a loose `Stack` handed its child that
        // height as a *maximum* — so the Column shrank to its content and the
        // Stack's `topStart` alignment pinned it to the top. At 360 pt "WIN
        // RATE" wraps its label and its sub-line, and HANDS and NET beside it
        // floated at the top of a 120 pt tile over a band of dead space. With
        // the incoming constraints passed through, `MainAxisAlignment.center`
        // does what it says.
        fit: StackFit.passthrough,
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
                    width: infoTarget,
                    height: infoTarget,
                    child: Icon(
                      Icons.info_outline,
                      size: infoGlyph,
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
