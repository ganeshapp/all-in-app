/// `StacksStrip` — the 28 pt push/fold line between the table and the
/// navigator (DESIGN.md §5.6, §10.6): the frame's verbatim text, e.g.
/// "Stacks 12 bb · Blinds 0.5/1 · Nash chip-EV, no antes".
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class StacksStrip extends StatelessWidget {
  const StacksStrip({super.key, required this.text});

  final String text;

  static const double height = 28;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AllInText.mono(12, color: context.colors.textMuted),
      ),
    ),
  );
}
