/// P1 · Table — the root-level full-screen modal at `/table`
/// (DESIGN.md §4.2, §16.1). The felt, seats, action zone and coach all arrive
/// with the play feature; this placeholder only holds the route.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Table',
      body: Center(
        child: Text(
          'Coming in Play.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
