/// D5 · Placement test — full-screen modal at `/placement`
/// (DESIGN.md §5.8), reached from onboarding and Settings → "Run again".
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlacementScreen extends ConsumerWidget {
  const PlacementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Placement test',
      body: Center(
        child: Text(
          'Coming in Drills.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
