/// §7 — the Sessions list: how many you have played, how each one went, and
/// which style you were in at the time.
///
/// The Stats tab could show every hand and no sessions, so "how many sessions
/// have I played?", "how many did I finish up?" and "do I win more as a TAG
/// or as a LAG?" had no answer anywhere in the app. Home links to the last
/// session only; everything before it was unreachable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../engine/engine.dart'
    show PlayerStyle, StyleProfile, fmtSigned, styleSentenceWord;
import '../../../services/persistence.dart' show SessionRecord;
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../play/providers/lobby_providers.dart';
import '../../play/providers/session_provider.dart' show styleProfileFromJson;
import '../stats_copy.dart';
import 'stats_section.dart';

/// One row's worth of a stored session.
class SessionLine {
  const SessionLine({required this.record, required this.style});

  final SessionRecord record;

  /// How the hero played it, when the session stored it. Sessions that ended
  /// before the style was recorded simply have none.
  final StyleProfile? style;

  /// A session that ended with the hero out of chips. The summary's own
  /// numbers decide it: the hero finished down a full buy-in or worse and
  /// has nothing left.
  bool get busted {
    final payload = record.summary;
    if (payload == null) return false;
    return payload['busted'] == true;
  }
}

List<SessionLine> sessionLines(List<SessionRecord> rows) => [
  for (final r in rows)
    SessionLine(record: r, style: styleProfileFromJson(r.summary?['style'])),
];

class SessionsCard extends ConsumerWidget {
  const SessionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(allSessionsProvider);
    final rows = async.valueOrNull ?? const <SessionRecord>[];

    if (rows.isEmpty) {
      return StatsSection(
        title: StatsCopy.sessionsCard,
        child: Text(
          StatsCopy.sessionsEmpty,
          style: AllInText.body(14, color: c.textMuted, height: 1.5),
        ),
      );
    }

    final lines = sessionLines(rows);
    final won = lines.where((l) => l.record.netBb > 0).length;

    return StatsSection(
      title: StatsCopy.sessionsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            StatsCopy.sessionsSummary(
              sessions: lines.length,
              won: won,
              busted: lines.where((l) => l.busted).length,
            ),
            style: AllInText.body(13, color: c.textMuted, height: 1.5),
          ),
          const SizedBox(height: AllInSpace.sm),
          for (final line in lines) _SessionRow(line: line),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.line});

  final SessionLine line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = line.record;
    final net = fmtSigned(r.netBb);
    final style = line.style;
    final label =
        style?.style == null
            ? null
            : shortStyleWord(style!.style!, style.vpip!, style.pfr!);
    final when = sessionDateLabel(r.endedAt);

    return Semantics(
      button: true,
      label: [
        when,
        '${r.hands} hands',
        '$net big blinds',
        if (label != null) 'played as $label',
        if (line.busted) 'busted',
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap:
              () => context.go(
                AllInRoutes.sessionPath(
                  AllInRoutes.progressPath,
                  r.id?.toString() ?? 'live',
                ),
              ),
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              when,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AllInText.body(13, color: c.text),
                            ),
                          ),
                          if (label != null) ...[
                            const SizedBox(width: AllInSpace.xs),
                            _StyleChip(label: label),
                          ],
                          if (line.busted) ...[
                            const SizedBox(width: AllInSpace.xs),
                            _StyleChip(label: 'Busted', tone: c.bad),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.hands} hands · ${r.mistakes} flagged',
                        style: AllInText.body(11, color: c.textFaint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Text(
                  '$net bb',
                  style: AllInText.mono(
                    13,
                    color: r.netBb >= 0 ? c.good : c.bad,
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.label, this.tone});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colour = tone ?? c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AllInRadius.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AllInText.body(10, weight: FontWeight.w600, color: colour),
      ),
    );
  }
}

/// "TAG", "Station" — the tile-sized form of [styleSentenceWord].
String shortStyleWord(PlayerStyle s, double vpip, double pfr) {
  final aggressive = vpip > 0 && pfr / vpip >= 0.6;
  return switch (s) {
    PlayerStyle.unknown => '—',
    PlayerStyle.rock => 'Rock',
    PlayerStyle.nit => 'Nit',
    PlayerStyle.tight => aggressive ? 'TAG' : 'Tight-passive',
    PlayerStyle.solid => aggressive ? 'TAG-ish' : 'Solid',
    PlayerStyle.loose => aggressive ? 'LAG' : 'Loose-passive',
    PlayerStyle.maniac => 'Maniac',
    PlayerStyle.station => 'Station',
  };
}

/// "Sun 2 Nov · 15:00" — enough to tell two sessions apart.
String sessionDateLabel(int endedAtMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(endedAtMs);
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} · $hh:$mm';
}
