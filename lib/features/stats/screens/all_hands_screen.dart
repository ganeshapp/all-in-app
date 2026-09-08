/// T2 · All hands (DESIGN.md §7.5) — `/stats/hands?filter=…&tag=…`.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AllHandsScreen extends ConsumerWidget {
  const AllHandsScreen({super.key, this.filter, this.tag});

  /// `all` · `played` · `imported`; null means all.
  final String? filter;

  /// Tag chip filter from `?tag=`.
  final String? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'All hands',
      body: Center(
        child: Text(
          'Coming in Stats.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
