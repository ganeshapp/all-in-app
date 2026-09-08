/// P10 · Session summary (DESIGN.md §4.13). One widget, five routes: the
/// live summary over the table (`/table/summary`) and the read-only copies in
/// the home, play and stats branches (`/{branch}/session/:id`) — §16.1.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({
    super.key,
    this.sessionId,
    this.readOnly = false,
  });

  /// The ended session's id; null for the live session over the table.
  final String? sessionId;

  /// True for the copies opened from Home, the lobby and Progress: no
  /// "New session", no end-session actions.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Session summary',
      body: Center(
        child: Text(
          'Coming in Play.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
