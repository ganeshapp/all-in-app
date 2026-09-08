/// D0 · Drills — the Drills tab root (DESIGN.md §5.1). Mode and set size
/// arrive as query parameters (`/drills?mode=leaks&set=10`, §2.6).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DrillsScreen extends ConsumerWidget {
  const DrillsScreen({super.key, this.mode, this.setSize});

  /// `mixed` · `pushfold` · `exploit` · `leaks`; null keeps the last mode.
  final String? mode;

  /// Quick-set length from `?set=` (e.g. 10); null means the normal queue.
  final int? setSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Drills',
      body: Center(
        child: Text(
          'Coming in Drills.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
