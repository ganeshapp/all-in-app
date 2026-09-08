/// P0 · Play lobby — the Play tab root (DESIGN.md §4.1): table setup, the
/// resume card, recent sessions and the never-played empty state.
///
/// Placeholder body; the tab never auto-redirects to the table (§2.1.1).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Play',
      subtitle: 'Six seats, four kinds of opponent, one coach.',
      body: Center(
        child: Text(
          'Coming in Play.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
