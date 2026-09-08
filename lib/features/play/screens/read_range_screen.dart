/// P7 · Read range: Guess → Peek — full-screen modal over the table at
/// `/table/read/:seat` (DESIGN.md §4.9, §16.1).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadRangeScreen extends ConsumerWidget {
  const ReadRangeScreen({super.key, required this.seat});

  /// Seat index of the bot whose range is being read (`:seat`).
  final int seat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Read their range',
      body: Center(
        child: Text(
          'Coming in Play.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
