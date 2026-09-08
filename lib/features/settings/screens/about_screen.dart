/// X1 · About (DESIGN.md §9) — pushed from Settings at
/// `/stats/settings/about`.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'About',
      body: Center(
        child: Text(
          'Coming in Settings.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
