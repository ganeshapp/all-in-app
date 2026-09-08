/// X0 · Settings (DESIGN.md §9) — the one canonical path `/stats/settings`;
/// both gears land here and `/settings*` redirects to it (§16.1).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.section});

  /// `?section=data` scrolls to and flashes the DATA group (§2.6).
  final String? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Settings',
      subtitle: 'Everything is saved on this device.',
      body: Center(
        child: Text(
          'Coming in Settings.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
