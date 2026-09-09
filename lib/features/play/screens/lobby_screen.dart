/// P0 · Play lobby — the Play tab root (DESIGN.md §4.1): the Resume card while
/// a snapshot exists, the NEW TABLE setup card with its live felt preview, the
/// last ten ended sessions and the never-played empty state.
///
/// The tab never auto-redirects to the table (§2.1.1): everything here is a
/// deliberate tap.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/format.dart';
import 'package:allin/features/play/providers/lobby_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/lobby_preview.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The three seat counts the segmented control offers, in label order.
const List<int> kSeatChoices = [2, 6, 9];

/// §4.1: "Antes [None ●][0.25 bb]" — 0.25 bb of a 20-chip blind is 5 chips.
const List<int> kAnteChoices = [0, 5];

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final ScrollController _scroll = ScrollController();

  /// §2.1: the Resume card rings gold for 2 s after a height-gated Play tap.
  bool _ringResume = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _focusResume() {
    if (!mounted) return;
    setState(() => _ringResume = true);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _ringResume = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // §2.1's "focus the Resume card", and §12's re-tap-scrolls-to-top.
    ref.listen<int>(resumeFocusProvider, (_, __) => _focusResume());
    ref.listen<TabReselect>(tabReselectProvider, (_, next) {
      if (next.branch == 1 && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: AllInMotion.of(
            context,
            AllInMotion.base,
            reduced: ref.read(reducedMotionProvider),
          ),
          curve: AllInMotion.ease,
        );
      }
    });

    final session = ref.watch(sessionProvider);
    final draft = ref.watch(lobbyDraftProvider);
    final settings = ref.watch(settingsProvider);
    final neverPlayed = ref.watch(neverPlayedProvider);
    final recent = ref.watch(recentSessionsProvider);

    return AllInScaffold(
      title: PlayCopy.lobbyTitle,
      subtitle: PlayCopy.lobbySubtitle,
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AllInSpace.lg,
          0,
          AllInSpace.lg,
          AllInSpace.xl,
        ),
        children: [
          if (session.active) ...[
            _ResumeCard(
              session: session,
              ringed: _ringResume,
              onResume: () => context.go(AllInRoutes.tablePath),
              onEnd: _endSession,
            ),
            const SizedBox(height: AllInSpace.lg),
          ],
          const Eyebrow(PlayCopy.newTable),
          const SizedBox(height: AllInSpace.sm),
          if (neverPlayed) ...[
            Text(
              PlayCopy.startOverlayBody,
              style: AllInText.body(13, color: context.colors.textMuted),
            ),
            const SizedBox(height: AllInSpace.md),
          ],
          _SetupCard(
            draft: draft,
            settings: settings,
            neverPlayed: neverPlayed,
            onSeats: ref.read(lobbyDraftProvider.notifier).setSeats,
            onAnte: ref.read(lobbyDraftProvider.notifier).setAnte,
            onPace:
                (mode) =>
                    ref.read(settingsProvider.notifier).update(paceMode: mode),
            onSpeed:
                (ms) => ref.read(settingsProvider.notifier).update(speedMs: ms),
            onCoach:
                (v) =>
                    ref.read(settingsProvider.notifier).update(coachEnabled: v),
            onDeal: _dealMeIn,
          ),
          if (neverPlayed) ...[
            const SizedBox(height: AllInSpace.md),
            Text(
              PlayCopy.firstTableCaption,
              textAlign: TextAlign.center,
              style: AllInText.body(13, color: context.colors.textMuted),
            ),
          ],
          ...recent.maybeWhen(
            data:
                (rows) =>
                    rows.isEmpty
                        ? const <Widget>[]
                        : <Widget>[
                          const SizedBox(height: AllInSpace.xl),
                          const Eyebrow(PlayCopy.recentSessions),
                          for (final row in rows)
                            _RecentRow(
                              record: row,
                              onTap: () => _openSummary(row.id),
                            ),
                        ],
            orElse: () => const <Widget>[],
          ),
        ],
      ),
    );
  }

  void _openSummary(int? id) {
    if (id == null) return;
    context.push(AllInRoutes.sessionPath(AllInRoutes.lobbyPath, '$id'));
  }

  /// §4.13: "End session … the lobby's Resume card overflow" — the session is
  /// written to the `sessions` table and its read-only P10 opens.
  Future<void> _endSession() async {
    final id = await ref.read(sessionProvider.notifier).closeCurrentSession();
    if (!mounted) return;
    _openSummary(id);
  }

  /// §4.1's "Deal me in", including the "Start a new table?" dialog when a
  /// paused session already exists.
  Future<void> _dealMeIn() async {
    final options = ref.read(lobbyDraftProvider);
    final notifier = ref.read(sessionProvider.notifier);

    if (!ref.read(sessionProvider).active) {
      notifier.newSession(options);
      if (!mounted) return;
      context.go(AllInRoutes.tablePath);
      return;
    }

    final hands = ref.read(sessionProvider).counters.hands;
    final replace = await AllInDialog.show<bool>(
      context,
      dialog: AllInDialog(
        title: PlayCopy.newTableOverPausedTitle,
        body: PlayCopy.newTableOverPausedBody(hands),
        actions: [
          AllInDialogAction(
            label: PlayCopy.keepPausedOne,
            onPressed:
                () => Navigator.of(context, rootNavigator: true).pop(false),
          ),
          AllInDialogAction(
            label: PlayCopy.newTableAction,
            isDefault: true,
            onPressed:
                () => Navigator.of(context, rootNavigator: true).pop(true),
          ),
        ],
      ),
    );
    if (replace != true || !mounted) return;

    // "New table" shows P10 for the old session first, then deals.
    final closedId = await notifier.startNewTable(options);
    if (!mounted) return;
    if (closedId != null) {
      await context.push(
        AllInRoutes.sessionPath(AllInRoutes.lobbyPath, '$closedId'),
      );
      if (!mounted) return;
    }
    context.go(AllInRoutes.tablePath);
  }
}

/* -------------------------------------------------------------- resume card */

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.session,
    required this.ringed,
    required this.onResume,
    required this.onEnd,
  });

  final SessionState session;
  final bool ringed;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hands = session.counters.hands;
    final line =
        '${session.options.seatsLabel} · $hands hand${hands == 1 ? '' : 's'} · '
        '${fmtSigned(session.netBb)} bb · ${relativeAge(session.savedAt)}';

    return AnimatedContainer(
      duration: AllInMotion.of(context, AllInMotion.base, reduced: false),
      curve: AllInMotion.ease,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AllInRadius.lg),
        border: Border.all(
          color: ringed ? c.gold : Colors.transparent,
          width: 2,
        ),
      ),
      child: AllInCard.glass(
        onTap: onResume,
        semanticLabel: '${PlayCopy.sessionInProgress}. $line. Resume',
        padding: const EdgeInsets.all(AllInSpace.md),
        child: SizedBox(
          height: height - 2 * AllInSpace.md,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: c.gold),
                        const SizedBox(width: AllInSpace.sm),
                        Flexible(
                          child: Text(
                            PlayCopy.sessionInProgress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AllInText.body(
                              15,
                              weight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AllInSpace.xs),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.mono(13, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Session options',
                child: PopupMenuButton<int>(
                  tooltip: '',
                  onSelected: (_) => onEnd(),
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem<int>(
                          value: 0,
                          child: Text(PlayCopy.endSession),
                        ),
                      ],
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: c.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AllInSpace.xs),
              Text(
                PlayCopy.resume,
                style: AllInText.body(
                  15,
                  weight: FontWeight.w600,
                  color: c.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------------------------------------------- setup card */

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.draft,
    required this.settings,
    required this.neverPlayed,
    required this.onSeats,
    required this.onAnte,
    required this.onPace,
    required this.onSpeed,
    required this.onCoach,
    required this.onDeal,
  });

  final TableOptions draft;
  final AppSettings settings;
  final bool neverPlayed;
  final ValueChanged<int> onSeats;
  final ValueChanged<int> onAnte;
  final ValueChanged<PaceMode> onPace;
  final ValueChanged<int> onSpeed;
  final ValueChanged<bool> onCoach;
  final VoidCallback onDeal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seatIndex = kSeatChoices.indexOf(draft.seats).clamp(0, 2);
    final anteIndex = kAnteChoices.indexOf(draft.ante).clamp(0, 1);

    return AllInCard.plain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LobbyFeltPreview(
            seats: draft.seats,
            ante: draft.ante,
            dashedBoard: neverPlayed,
          ),
          const SizedBox(height: AllInSpace.md),
          _Row(
            label: PlayCopy.tableRow,
            child: AllInSegmented(
              labels: PlayCopy.seatLabels,
              value: seatIndex,
              semanticLabel: PlayCopy.tableRow,
              onChanged: (i) => onSeats(kSeatChoices[i]),
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          _Row(
            label: PlayCopy.antesRow,
            child: AllInSegmented(
              labels: PlayCopy.anteLabels,
              value: anteIndex,
              semanticLabel: PlayCopy.antesRow,
              onChanged: (i) => onAnte(kAnteChoices[i]),
            ),
          ),
          if (draft.seats != 6) ...[
            const SizedBox(height: AllInSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: c.textFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    PlayCopy.chartsAssumeSixMax,
                    style: AllInText.body(12, color: c.textFaint),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AllInSpace.sm),
          _Row(
            label: PlayCopy.paceRow,
            child: Row(
              children: [
                Expanded(
                  child: AllInSegmented(
                    labels: PlayCopy.paceLabels,
                    value: settings.paceMode == PaceMode.auto ? 1 : 0,
                    semanticLabel: PlayCopy.paceRow,
                    onChanged:
                        (i) => onPace(i == 1 ? PaceMode.auto : PaceMode.manual),
                  ),
                ),
                if (settings.paceMode == PaceMode.auto) ...[
                  const SizedBox(width: AllInSpace.sm),
                  _SpeedMenu(speedMs: settings.speedMs, onChanged: onSpeed),
                ],
              ],
            ),
          ),
          const SizedBox(height: AllInSpace.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PlayCopy.evCoachRow,
                      style: AllInText.body(15, color: c.text),
                    ),
                    Text(
                      PlayCopy.evCoachCaption,
                      style: AllInText.body(12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              AllInSwitch(
                value: settings.coachEnabled,
                semanticLabel: PlayCopy.evCoachRow,
                onChanged: onCoach,
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.sm),
          Text(
            PlayCopy.stacksCaption,
            style: AllInText.body(12, color: c.textFaint),
          ),
          const SizedBox(height: AllInSpace.md),
          AllInButton.primary(
            label: PlayCopy.dealMeIn,
            size: AllInButtonSize.lg,
            expand: true,
            onPressed: onDeal,
          ),
        ],
      ),
    );
  }
}

/// A 44 pt label + control row, with the label given a fixed leading column so
/// the segmented controls line up.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 60,
        child: Text(
          label,
          style: AllInText.body(15, color: context.colors.text),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

/// "Normal ▾" — the Auto-only speed menu (§4.1), 44 pt tall.
class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.speedMs, required this.onChanged});

  final int speedMs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = PaceSpeed.all.indexOf(speedMs).clamp(0, 2);
    return Semantics(
      button: true,
      label: 'Speed, ${PlayCopy.speedLabels[index]}',
      child: PopupMenuButton<int>(
        tooltip: '',
        initialValue: speedMs,
        onSelected: onChanged,
        itemBuilder:
            (context) => [
              for (var i = 0; i < PaceSpeed.all.length; i++)
                PopupMenuItem<int>(
                  value: PaceSpeed.all[i],
                  child: Text(PlayCopy.speedLabels[i]),
                ),
            ],
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                PlayCopy.speedLabels[index],
                style: AllInText.body(15, color: c.text),
              ),
              Icon(Icons.arrow_drop_down, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------- recent rows */

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record, required this.onTap});

  final SessionRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seats = TableOptions(seats: record.seats).seatsLabel;
    final middle =
        '$seats · ${record.hands} hand${record.hands == 1 ? '' : 's'}';
    final net = '${fmtSigned(record.netBb)} bb';

    return Semantics(
      button: true,
      label: '${sessionStamp(record.endedAt)}, $middle, $net',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    sessionStamp(record.endedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(14, color: c.text),
                  ),
                ),
                Expanded(
                  child: Text(
                    middle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(14, color: c.textMuted),
                  ),
                ),
                Text(
                  net,
                  style: AllInText.mono(
                    14,
                    color: record.netBb >= 0 ? c.good : c.bad,
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

/* ----------------------------------------------------------------- helpers */

/// "8 min ago" / "2 h ago" / "3 d ago" — the Resume card's age (§4.1).
String relativeAge(int epochMs, {DateTime? now}) {
  if (epochMs <= 0) return 'just now';
  final then = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final delta = (now ?? DateTime.now()).difference(then);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) return '${delta.inHours} h ago';
  return '${delta.inDays} d ago';
}

/// "Today 18:10" / "Yesterday" / "12 Mar" — a recent session's stamp (§4.1).
String sessionStamp(int epochMs, {DateTime? now}) {
  if (epochMs <= 0) return '—';
  final then = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final today = now ?? DateTime.now();
  final day = DateTime(then.year, then.month, then.day);
  final start = DateTime(today.year, today.month, today.day);
  final days = start.difference(day).inDays;
  final hh = then.hour.toString().padLeft(2, '0');
  final mm = then.minute.toString().padLeft(2, '0');
  if (days == 0) return 'Today $hh:$mm';
  if (days == 1) return 'Yesterday';
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
  return '${then.day} ${months[then.month - 1]}';
}
