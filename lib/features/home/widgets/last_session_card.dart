/// §3.5's "Last session" row: the result line, the costliest decision under
/// it, and a chevron to the read-only P10 at `/home/session/:id`.
///
/// Money is signed and coloured by sign (§16.5); the row is one 64 pt target.
library;

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/home_providers.dart';

class LastSessionCard extends StatelessWidget {
  const LastSessionCard({super.key, required this.session, this.onTap});

  final HomeLastSession session;
  final VoidCallback? onTap;

  static const double minHeight = 64;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard.plain(
      onTap: onTap,
      semanticLabel: [
        session.line,
        if (session.costliest != null) session.costliest!,
      ].join('. '),
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: minHeight - 2 * AllInSpace.lg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.line,
                    style: AllInText.mono(15, color: c.money(session.netBb)),
                  ),
                  if (session.costliest != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      session.costliest!,
                      style: AllInText.body(13, color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AllInSpace.sm),
            Icon(Icons.chevron_right, size: 20, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
