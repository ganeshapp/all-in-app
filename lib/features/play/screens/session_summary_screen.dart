/// P10 · Session summary (DESIGN.md §4.13). One widget, five routes: the live
/// summary over the table (`/table/summary`) and the read-only copies in the
/// home, play and stats branches (`/{branch}/session/:id`) — §16.1.
///
/// Decisions before money (TONE.md): the debrief card is the first thing under
/// the title, the money tiles come after it, and the two never share a colour
/// scale (principle 8).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/summary_provider.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/screens/lobby_screen.dart'
    show sessionStamp;
import 'package:allin/features/play/widgets/hand_note_sheet.dart';
import 'package:allin/services/share_service.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
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
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen>
    with SingleTickerProviderStateMixin {
  /// The last data we rendered. "Done" and "New session" reset the session
  /// while the route is still on screen, so the numbers are held here rather
  /// than blinking to zero during the transition.
  SessionSummaryData? _last;

  /// True once a button that navigates away has been pressed.
  bool _leaving = false;

  /// §2.5's blocked-back shake (busted). Built eagerly: a `late final` here
  /// would be *created* by `dispose()` on a screen that never shook.
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _live => widget.sessionId == null && !widget.readOnly;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionSummaryProvider(widget.sessionId));
    final data = async.valueOrNull;
    if (data != null && !_leaving) _last = data;
    final summary = _last ?? data;

    if (summary == null) {
      return AllInScaffold(
        title: SummaryCopy.title,
        body: Center(
          child:
              async.hasError
                  ? _Message(text: SummaryCopy.storageProblem)
                  : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
        ),
      );
    }

    if (summary.missing) return _missing(context);

    final busted = _live && summary.busted;
    final canClose = _live && !busted;

    final content = _Body(
      summary: summary,
      readOnly: widget.readOnly,
      onReplay: (startedAt) => _openReplay(summary, startedAt),
      onNote: _openNote,
      onReview: _openReviewQueue,
    );

    return PopScope(
      canPop: !busted,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _onClosed();
        } else {
          _blockedBack();
        }
      },
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          // One 4 pt there-and-back over the 120 ms.
          final dx = 4 * (t <= 0.5 ? t * 2 : (1 - t) * 2);
          return Transform.translate(
            offset: Offset(
              t == 0 ? 0 : dx * (t < 0.25 || t > 0.75 ? 1 : -1),
              0,
            ),
            child: child,
          );
        },
        child: AllInScaffold(
          title: _title(summary),
          subtitle: widget.readOnly ? _subtitle(summary) : null,
          leading:
              canClose
                  ? _CloseButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                  : null,
          body: content,
          bottom: _actions(summary, busted: busted),
        ),
      ),
    );
  }

  String _title(SessionSummaryData summary) {
    if (widget.readOnly) return SummaryCopy.readOnlyTitle;
    return summary.busted ? SummaryCopy.bustedTitle : SummaryCopy.title;
  }

  String _subtitle(SessionSummaryData summary) =>
      '${sessionStamp(summary.startedAt)} · '
      '${SummaryCopy.seatsLabel(summary.seats)}';

  Widget _missing(BuildContext context) => AllInScaffold(
    title: SummaryCopy.readOnlyTitle,
    body: Padding(
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: _Message(
        text:
            "That session isn't saved any more — it may have been cleared by "
            'Reset all progress.',
      ),
    ),
    bottom: AllInButton.primary(
      label: SummaryCopy.done,
      expand: true,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );

  /* ------------------------------------------------------------- actions */

  Widget _actions(SessionSummaryData summary, {required bool busted}) {
    final share = AllInButton.secondary(
      label: SummaryCopy.share,
      leading: Icons.ios_share_rounded,
      expand: true,
      onPressed: summary.hasHands ? () => _share(summary) : null,
    );

    if (widget.readOnly) {
      return Row(
        children: [
          Expanded(child: share),
          const SizedBox(width: AllInSpace.sm),
          Expanded(
            child: AllInButton.primary(
              label: SummaryCopy.done,
              expand: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: share),
            const SizedBox(width: AllInSpace.sm),
            Expanded(
              flex: 2,
              child: AllInButton.primary(
                label: SummaryCopy.newSession,
                expand: true,
                onPressed: _newSession,
              ),
            ),
          ],
        ),
        if (!busted) ...[
          const SizedBox(height: AllInSpace.xs),
          AllInButton.ghost(
            label: SummaryCopy.done,
            expand: true,
            onPressed: _done,
          ),
        ],
      ],
    );
  }

  /// §4.13: "Share replaces the desktop's Copy + Export" — the session's
  /// PokerStars text, attached as `all-in-session-….txt`.
  Future<void> _share(SessionSummaryData summary) async {
    final outcome = await ref
        .read(shareServiceProvider)
        .shareSession(
          handHistory: formatSession(summary.history),
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            summary.startedAt > 0
                ? summary.startedAt
                : summary.history.first.startedAt,
          ),
        );
    if (!mounted || outcome != ShareOutcome.unavailable) return;
    // The OS confirms a completed share; only a failure needs a word (§14).
    AllInToast.show(
      context,
      SummaryCopy.storageProblem,
      reducedMotion: ref.read(reducedMotionProvider),
    );
  }

  /// ✕ / system back: the session continues (§4.13, desktop parity).
  void _onClosed() {
    if (_live && !_leaving) ref.read(sessionProvider.notifier).closeSummary();
  }

  /// §2.5's blocked-back response: a 120 ms 4 pt shake plus `selectionClick`.
  /// Under reduced motion the haptic alone is the answer.
  void _blockedBack() {
    ref.read(hapticsProvider).blockedBack();
    final reduced =
        ref.read(reducedMotionProvider) ||
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (reduced) return;
    _shake
      ..reset()
      ..forward();
  }

  /// "New session" rebuilds the table: the old session is recorded first so it
  /// shows up in Recent sessions (§4.1).
  Future<void> _newSession() async {
    setState(() => _leaving = true);
    final options = ref.read(sessionProvider).options;
    await ref.read(sessionProvider.notifier).startNewTable(options);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AllInRoutes.tablePath);
    }
  }

  /// "Done" ends the session and returns to the lobby (§4.13).
  Future<void> _done() async {
    setState(() => _leaving = true);
    await ref.read(sessionProvider.notifier).finishSession();
    if (!mounted) return;
    context.go(AllInRoutes.lobbyPath);
  }

  /* ---------------------------------------------------------- navigation */

  void _openReplay(SessionSummaryData summary, int startedAt) {
    final id = widget.sessionId;
    if (id == null) {
      context.push(AllInRoutes.summaryHandPath(startedAt));
      return;
    }
    context.push(AllInRoutes.sessionHandPath(_branchPath(), id, startedAt));
  }

  /// P10 is hosted by three branches; a `push` must stay inside the one the
  /// user is on (§16.1).
  String _branchPath() {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith(AllInRoutes.todayPath)) return AllInRoutes.todayPath;
    if (path.startsWith(AllInRoutes.progressPath)) {
      return AllInRoutes.progressPath;
    }
    return AllInRoutes.lobbyPath;
  }

  Future<void> _openNote(int startedAt) => HandNoteSheet.show(
    context,
    startedAt: startedAt,
    reducedMotion: ref.read(reducedMotionProvider),
  );

  /// §4.13: the costliest decision "is in your Review queue".
  void _openReviewQueue() {
    setState(() => _leaving = true);
    context.go(AllInRoutes.drillsWith(mode: 'leaks'));
  }
}

/* ------------------------------------------------------------------ body */

class _Body extends ConsumerWidget {
  const _Body({
    required this.summary,
    required this.readOnly,
    required this.onReplay,
    required this.onNote,
    required this.onReview,
  });

  final SessionSummaryData summary;
  final bool readOnly;
  final ValueChanged<int> onReplay;
  final ValueChanged<int> onNote;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final notes = ref.watch(playNotesProvider);
    final reduced = ref.watch(reducedMotionProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.xl,
      ),
      children: [
        Text(
          SummaryCopy.handsPlayed(summary.hands),
          style: AllInText.body(15, color: c.text),
        ),
        const SizedBox(height: AllInSpace.md),
        _DebriefCard(
          debrief: summary.debrief,
          reducedMotion: reduced,
          onReview: onReview,
        ),
        const SizedBox(height: AllInSpace.md),
        _Tiles(summary: summary),
        const SizedBox(height: AllInSpace.lg),
        Text(
          SummaryCopy.showdownLine(summary.showdowns),
          style: AllInText.body(13, color: c.textMuted, height: 1.4),
        ),
        const SizedBox(height: AllInSpace.lg),
        const Eyebrow(SummaryCopy.reviewHands),
        if (summary.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AllInSpace.md),
            child: Text(
              SummaryCopy.noHands,
              style: AllInText.body(13, color: c.textMuted),
            ),
          ),
        for (final row in summary.rows)
          SummaryHandRowView(
            key: ValueKey('summary-hand-${row.id}-${row.startedAt}'),
            row: row,
            hasNote: notes.noteFor(row.startedAt)?.isEmpty == false,
            onReplay: () => onReplay(row.startedAt),
            onNote: () => onNote(row.startedAt),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------ debrief card */

/// §4.13's three-layer debrief: the paragraph, the best / costliest lines and
/// the two disclosure rows, which render even when there is nothing behind
/// them (§4.8's placeholders).
class _DebriefCard extends StatelessWidget {
  const _DebriefCard({
    required this.debrief,
    required this.reducedMotion,
    required this.onReview,
  });

  final SessionDebrief debrief;
  final bool reducedMotion;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final costliest = debrief.costliest;

    return AllInCard.gold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Eyebrow(SummaryCopy.debriefEyebrow),
          const SizedBox(height: AllInSpace.sm),
          Text(
            debrief.paragraph,
            style: AllInText.body(15, color: c.text, height: 1.45),
          ),
          if (debrief.best != null) ...[
            const SizedBox(height: AllInSpace.sm),
            Text(
              debrief.best!,
              style: AllInText.body(15, color: c.text, height: 1.45),
            ),
          ],
          if (costliest != null) ...[
            const SizedBox(height: AllInSpace.sm),
            if (debrief.hasFlagged)
              Semantics(
                button: true,
                label: '$costliest ${SummaryCopy.reviewSpots}',
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onReview,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              costliest,
                              style: AllInText.body(
                                15,
                                color: c.text,
                                height: 1.45,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: c.gold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                costliest,
                style: AllInText.body(15, color: c.text, height: 1.45),
              ),
          ],
          const SizedBox(height: AllInSpace.sm),
          DisclosureRow(
            label: CoachCopy.showMath,
            expandedLabel: CoachCopy.hideMath,
            reducedMotion: reducedMotion,
            child: _Lines(
              lines: debrief.mathLines,
              placeholder: CoachCopy.noMathVerdict,
              mono: true,
            ),
          ),
          DisclosureRow(
            label: CoachCopy.expertDetail,
            expandedLabel: CoachCopy.hideExpert,
            tone: DisclosureTone.muted,
            reducedMotion: reducedMotion,
            child: _Lines(
              lines: debrief.expertLines,
              placeholder: CoachCopy.nothingExtra,
            ),
          ),
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({
    required this.lines,
    required this.placeholder,
    this.mono = false,
  });

  final List<String> lines;
  final String placeholder;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (lines.isEmpty) {
      return Text(placeholder, style: AllInText.body(14, color: c.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(
              bottom: line == lines.last ? 0 : AllInSpace.sm,
            ),
            child: Text(
              line,
              style:
                  mono
                      ? AllInText.mono(13, color: c.text)
                      : AllInText.body(14, color: c.textMuted, height: 1.45),
            ),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ tiles */

class _Tiles extends StatelessWidget {
  const _Tiles({required this.summary});

  final SessionSummaryData summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Net',
                value: '${fmtSigned(summary.netBb)} bb',
                tone: StatTone.money(summary.netBb),
              ),
            ),
            const SizedBox(width: AllInSpace.sm),
            Expanded(
              child: StatTile(
                label: 'bb / 100',
                value: fmtSigned(summary.bb100),
                // NET and bb/100 are the same signed money quantity at two
                // scales; painting one and not the other gave one card two
                // colour rules (§13 / principle 8).
                tone: StatTone.money(summary.bb100),
              ),
            ),
          ],
        ),
        const SizedBox(height: AllInSpace.sm),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Biggest win',
                value: '${fmtSigned(summary.biggestWinBb)} bb',
                // A session with no winning hand reads "+0.0 bb"; colouring
                // that green (and the matching "Biggest loss +0.0 bb" red)
                // states an outcome that never happened, so a zero stays
                // neutral — which is exactly what `StatTone.money` encodes.
                tone: StatTone.money(summary.biggestWinBb),
              ),
            ),
            const SizedBox(width: AllInSpace.sm),
            Expanded(
              child: StatTile(
                label: 'Biggest loss',
                value: '${fmtSigned(summary.biggestLossBb)} bb',
                tone: StatTone.money(summary.biggestLossBb),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------- rows */

/// "Hand #41  +6.0 bb  ▷ Replay  ✎" — tap opens P11, swipe-left offers Note
/// (§4.13, §12).
class SummaryHandRowView extends StatelessWidget {
  const SummaryHandRowView({
    super.key,
    required this.row,
    required this.hasNote,
    required this.onReplay,
    required this.onNote,
  });

  final SummaryHandRow row;
  final bool hasNote;
  final VoidCallback onReplay;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Dismissible(
      key: ValueKey('summary-swipe-${row.id}-${row.startedAt}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      confirmDismiss: (_) async {
        onNote();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
        color: c.gold.withValues(alpha: 0.16),
        child: Text(
          SummaryCopy.note,
          style: AllInText.body(13, weight: FontWeight.w600, color: c.gold),
        ),
      ),
      child: Semantics(
        button: true,
        label:
            'Hand ${row.id}, ${fmtSigned(row.netBb)} big blinds, replay'
            '${hasNote ? ', has a note' : ''}',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReplay,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      'Hand #${row.id}',
                      style: AllInText.mono(14, color: c.text),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${fmtSigned(row.netBb)} bb',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.mono(
                        14,
                        color: row.netBb >= 0 ? c.good : c.bad,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Replay hand ${row.id}',
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onReplay,
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                                color: c.textMuted,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                SummaryCopy.replay,
                                style: AllInText.body(13, color: c.textMuted),
                              ),
                              const SizedBox(width: AllInSpace.sm),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _IconAction(
                    icon: Icons.edit_outlined,
                    label: 'Note on hand ${row.id}',
                    color: hasNote ? c.gold : c.textMuted,
                    onTap: onNote,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.md),
            onTap: onTap,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- chrome */

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.md),
            onTap: onPressed,
            child: Icon(Icons.close_rounded, color: context.colors.text),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: AllInText.body(15, color: context.colors.textMuted, height: 1.45),
  );
}
