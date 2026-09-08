/// P11 · Hand replayer (DESIGN.md §7.7). Pushed from five hosts — the stats
/// branch, the two session-summary copies, the table modal and the summary
/// over it — all sharing this widget (§16.1).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReplayerScreen extends ConsumerWidget {
  const ReplayerScreen({super.key, required this.startedAt});

  /// `hand.startedAt` — the hand record's identity (`:startedAt`).
  final int startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Hand replay',
      body: Center(
        child: Text(
          'Coming in Stats.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
