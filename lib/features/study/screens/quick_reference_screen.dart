/// S4 · Quick reference + Glossary (DESIGN.md §6.7). `?term=` scrolls to and
/// flashes one entry; an unknown id opens at the top, never an error.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickReferenceScreen extends ConsumerWidget {
  const QuickReferenceScreen({super.key, this.term});

  /// Glossary term id from `?term=`; null opens at the top.
  final String? term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Quick reference',
      body: Center(
        child: Text(
          'Coming in Study.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
