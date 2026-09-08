/// S6 · Range editor — full-screen modal at `/study/range-editor`
/// (DESIGN.md §6.5). Returns the painted set with `pop(result)`.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RangeEditorScreen extends ConsumerWidget {
  const RangeEditorScreen({
    super.key,
    this.initialHands = const <String>{},
    this.title = 'Range editor',
  });

  /// Hand labels ("AKs", "77") the editor opens with.
  final Set<String> initialHands;

  /// Which range is being painted ("Your range" / "Opponent's range").
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: title,
      body: Center(
        child: Text(
          'Coming in Study.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
