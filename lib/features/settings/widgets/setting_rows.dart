/// The X0 row vocabulary (DESIGN.md §9): a grouped list where every row is
/// "title (Inter 16) · description (Inter 13 muted, 2–3 lines) · control", at
/// least 56 pt tall and never smaller than the §12 44 pt floor.
///
/// Compositions only — every control is a §10.1 foundation. Nothing here
/// exports a §10 name (§16.3).
library;

import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// A titled group: `Eyebrow` label over one card of rows.
///
/// [flash] is §2.6's `?section=data` highlight — a gold border that fades out
/// once the group has been scrolled to.
class SettingGroup extends StatelessWidget {
  const SettingGroup({
    super.key,
    required this.label,
    required this.children,
    this.flash = false,
    this.reducedMotion = false,
  });

  final String label;
  final List<Widget> children;
  final bool flash;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: c.line));
      }
      rows.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AllInSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AllInSpace.xs,
              bottom: AllInSpace.sm,
            ),
            // The default `textFaint`, like every other screen's group label
            // (Home "NEXT UP", Play "NEW TABLE", Study "TOOLS", Stats). Gold
            // is the coach's accent; six gold headings down a settings page
            // spent it on structural chrome.
            child: Eyebrow(label),
          ),
          AnimatedContainer(
            duration: AllInMotion.of(
              context,
              AllInMotion.base,
              reduced: reducedMotion,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AllInRadius.lg),
              border: Border.all(
                color: flash ? c.gold : Colors.transparent,
                width: 2,
              ),
            ),
            child: AllInCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row. [trailing] sits on the right of the title (switches, small
/// buttons, chevrons); [below] takes the full width under the description
/// (segmented controls, which do not fit beside a title at 360 pt).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.description,
    this.descriptionSpans,
    this.trailing,
    this.below,
    this.onTap,
    this.danger = false,
    this.enabled = true,
    this.semanticLabel,
  });

  final String title;
  final String? description;

  /// Rich alternative to [description] — the four-colour row paints each suit
  /// glyph in the colour it is naming (§9). Wins over [description] when set.
  final List<InlineSpan>? descriptionSpans;
  final Widget? trailing;
  final Widget? below;

  /// Makes the whole row a target (the `›` rows of the Data group).
  final VoidCallback? onTap;

  /// Paints the title in `bad` — "Reset all progress" (§9).
  final bool danger;

  /// Greyed out but still readable (Speed while Pace is Step).
  final bool enabled;

  final String? semanticLabel;

  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleColor =
        danger
            ? c.bad
            : enabled
            ? c.text
            : c.textFaint;

    // §9's wireframe: the control sits beside the **title**, and the
    // description runs the full width of the row underneath it. Keeping the
    // description inside the title's column squeezed it into a ~20-character
    // ribbon on the four-colour row, whose trailing carries four preview
    // cards as well as the switch.
    final titleText = Text(
      title,
      style: AllInText.body(16, weight: FontWeight.w600, color: titleColor),
    );
    final descriptionStyle = AllInText.body(
      13,
      color: enabled ? c.textMuted : c.textFaint,
      height: 1.45,
    );
    final spans = descriptionSpans;
    final descriptionText =
        spans != null
            ? Text.rich(TextSpan(children: spans), style: descriptionStyle)
            : description == null
            ? null
            : Text(description!, style: descriptionStyle);

    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.lg,
        vertical: AllInSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleText),
              if (trailing != null) ...[
                const SizedBox(width: AllInSpace.md),
                trailing!,
              ],
            ],
          ),
          if (descriptionText != null) ...[
            const SizedBox(height: AllInSpace.xs),
            descriptionText,
          ],
          if (below != null) ...[const SizedBox(height: AllInSpace.md), below!],
        ],
      ),
    );

    final constrained = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: body,
    );

    if (onTap == null) {
      return Semantics(
        container: true,
        label: semanticLabel,
        child: constrained,
      );
    }
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel ?? title,
      child: InkWell(onTap: onTap, child: ExcludeSemantics(child: constrained)),
    );
  }
}

/// The `›` chevron the Data and About rows end with.
class SettingChevron extends StatelessWidget {
  const SettingChevron({super.key, this.tone});

  final Color? tone;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.chevron_right_rounded,
    size: 22,
    color: tone ?? context.colors.textMuted,
  );
}

/// The live `A♠ A♥ A♦ A♣` preview beside the four-colour-deck switch (§9).
class FourColourDeckPreview extends StatelessWidget {
  const FourColourDeckPreview({super.key, required this.fourColorDeck});

  final bool fourColorDeck;

  /// §9: "preview cards 26 wide update live".
  static const double cardWidth = 26;

  static const List<String> cards = ['As', 'Ah', 'Ad', 'Ac'];

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(right: AllInSpace.xs),
            child: PlayingCardView(
              card: card,
              width: cardWidth,
              fourColorDeck: fourColorDeck,
            ),
          ),
      ],
    ),
  );
}

/// A faint line under a row — the backup caption of §7.9 and the message
/// `saveText` returns after a backup (§7.10).
class SettingNote extends StatelessWidget {
  const SettingNote(this.text, {super.key, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AllInSpace.lg,
      0,
      AllInSpace.lg,
      AllInSpace.md,
    ),
    child: Text(
      text,
      style: AllInText.body(12.5, color: tone ?? context.colors.textFaint),
    ),
  );
}
