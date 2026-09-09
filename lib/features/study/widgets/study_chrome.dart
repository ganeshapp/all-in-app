/// The small chrome pieces the Study screens share: the leading control
/// (a chevron on a push, "Done" on the S1 modal), a gold header text button,
/// and the 2 pt read-progress line under S1's top bar (DESIGN.md §6.2, §6.6).
library;

import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:flutter/material.dart';

/// 44 pt back chevron.
class StudyBackChevron extends StatelessWidget {
  const StudyBackChevron({super.key, required this.onTap, this.label = 'Back'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.chevron_left_rounded,
          size: 28,
          color: context.colors.text,
        ),
      ),
    ),
  );
}

/// A gold text control on a top bar ("Done", "Open lesson ›").
class StudyHeaderButton extends StatelessWidget {
  const StudyHeaderButton({
    super.key,
    required this.label,
    required this.onTap,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onTap;

  /// "Done" is semibold gold; secondary links are regular.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
          child: Text(
            label,
            style: AllInText.body(
              15,
              weight: emphasised ? FontWeight.w600 : FontWeight.w500,
              color: c.gold,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44 pt icon button for a top bar (the S1 "⋯" menu).
class StudyIconButton extends StatelessWidget {
  const StudyIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 22, color: context.colors.text),
      ),
    ),
  );
}

/// The thin gold read-progress line under S1's top bar (§6.2). It is a pure
/// progress *indicator*: it never scrolls anything and it animates only when
/// motion is allowed.
class ReadProgressLine extends StatelessWidget {
  const ReadProgressLine({
    super.key,
    required this.value,
    this.reducedMotion = false,
  });

  /// 0..1 of the scrollable extent.
  final double value;
  final bool reducedMotion;

  static const double height = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: AnimatedContainer(
            duration: AllInMotion.of(
              context,
              AllInMotion.fast,
              reduced: reducedMotion,
            ),
            color: c.gold,
          ),
        ),
      ),
    );
  }
}
