/// T0 · Progress — the Stats tab root (DESIGN.md §7.1): KPIs, charts, the
/// coaching review, recent hands and the practice heatmap.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Your progress',
      subtitle: 'Decisions, not results — but we track both.',
      body: Center(
        child: Text(
          'Coming in Stats.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
