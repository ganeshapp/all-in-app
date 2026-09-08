/// `Eyebrow` — the small caps section label ("NEXT UP", "LAST SESSION").
/// DESIGN.md §10.1; style is `AllInText.eyebrow` (§16.5).
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.textAlign});

  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        textAlign: textAlign,
        style: AllInText.eyebrow(color ?? context.colors.textFaint),
      ),
    );
  }
}
