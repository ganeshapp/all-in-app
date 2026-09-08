/// H0 · Today — the Home tab root (DESIGN.md §3).
///
/// Placeholder: the plan cards, goal ring and coach note land with the home
/// feature; only the body below is replaced.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Today',
      subtitle: 'What to do in the next five minutes.',
      body: Center(
        child: Text(
          'Coming in Home.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
