/// S0 · Study — the Study tab root (DESIGN.md §6.1): continue card, the five
/// levels, tools and quick reference.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Study',
      body: Center(
        child: Text(
          'Coming in Study.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
