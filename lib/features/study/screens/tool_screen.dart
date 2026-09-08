/// S3 · Tool screens (DESIGN.md §6.6): range explorer, equity calculator,
/// pot-odds calculator, bluff calculator, multiway trainer, hand rankings —
/// one push each at `/study/tools/:tool`.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToolScreen extends ConsumerWidget {
  const ToolScreen({super.key, required this.tool});

  /// `range-explorer` · `equity` · `pot-odds` · `bluff` · `multiway` ·
  /// `rankings`.
  final String tool;

  /// Titles for the six tools; an unknown id reads "Tools".
  static const Map<String, String> titles = {
    'range-explorer': 'Range explorer',
    'equity': 'Equity calculator',
    'pot-odds': 'Pot-odds calculator',
    'bluff': 'Bluff calculator',
    'multiway': 'Multiway trainer',
    'rankings': 'Hand rankings',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: titles[tool] ?? 'Tools',
      body: Center(
        child: Text(
          'Coming in Study.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
