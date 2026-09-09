/// T0 · Progress — the Stats tab root (DESIGN.md §7.1): KPIs, charts, the
/// coaching review, recent hands and the practice heatmap.
///
/// Card order is §7.1's, which is the desktop's re-cut for a phone: the three
/// questions a learner asks first ("am I improving?", "what's my leak?",
/// "which hand was that?") come before the breakdowns.
///
/// Freshness: play, drills and settings all write through their own repository
/// instances, so the tab re-reads its snapshot whenever it is shown again —
/// on first build, on a tab re-tap, and after any push it made returns.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/stats/providers/data_actions.dart';
import 'package:allin/features/stats/providers/import_provider.dart';
import 'package:allin/features/stats/providers/replay_model.dart';
import 'package:allin/features/stats/providers/stats_metrics.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/features/stats/widgets/breakdown_cards.dart';
import 'package:allin/features/stats/widgets/charts_cards.dart';
import 'package:allin/features/stats/widgets/coaching_review_card.dart';
import 'package:allin/features/stats/widgets/data_card.dart';
import 'package:allin/features/stats/widgets/heatmap_card.dart';
import 'package:allin/features/stats/widgets/import_flow.dart';
import 'package:allin/features/stats/widgets/kpi_grid.dart';
import 'package:allin/features/stats/widgets/note_editor_sheet.dart';
import 'package:allin/features/stats/widgets/recent_hands_card.dart';
import 'package:allin/services/persistence.dart';
import 'package:allin/services/share_service.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The stats branch's index in the tab scaffold (§2.1).
const int _statsBranch = 4;

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final ScrollController _scroll = ScrollController();
  ImportFlowController? _import;
  String? _tagFilter;
  bool _backingUp = false;
  int _importRequest = 0;

  @override
  void initState() {
    super.initState();
    _importRequest = ref.read(importRequestProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    ref.read(statsRevisionProvider.notifier).bump();
  }

  ImportFlowController get _flow =>
      _import ??= ImportFlowController(
        ref: ref,
        onSeeHands:
            () => context.push(AllInRoutes.allHandsPath(filter: 'imported')),
        onReviewNow: () => context.go(AllInRoutes.drillsWith(mode: 'leaks')),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stats = ref.watch(statsProvider);

    ref.listen(importProvider, (previous, next) {
      _flow.handle(context, previous, next);
    });

    // Settings' "Import hands (.txt)" row raises a counter and comes here
    // (§2.6); T3 belongs to this feature, so this is where it opens.
    ref.listen(importRequestProvider, (previous, next) {
      if (next == _importRequest) return;
      _importRequest = next;
      _flow.start(context);
    });

    // Re-tapping the Stats tab scrolls this page to the top (§2.1, §12).
    ref.listen(tabReselectProvider, (previous, next) {
      if (next.branch != _statsBranch || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      _refresh();
    });

    return AllInScaffold(
      title: StatsCopy.title,
      subtitle: StatsCopy.subtitle,
      actions: [
        IconButton(
          tooltip: StatsCopy.settingsAction,
          icon: Icon(Icons.settings_outlined, color: c.textMuted),
          onPressed:
              () => context
                  .push(AllInRoutes.settingsPath)
                  .then((_) => _refresh()),
        ),
      ],
      body: stats.when(
        loading: () => const _Loading(),
        error: (_, _) => _Error(onRetry: _refresh),
        data: _content,
      ),
    );
  }

  Widget _content(StatsMetrics metrics) {
    final settings = ref.watch(settingsProvider);
    final notes = ref.watch(notesProvider);
    final tags = ref.watch(allTagsProvider);
    final cells = ref.watch(heatmapProvider);
    final due = ref.watch(dueLeakCountProvider);
    final recent = ref.watch(recentHandsProvider);

    return ListView(
      controller: _scroll,
      // The shell's chrome (tab bar + Session pill) is published as
      // `MediaQuery.padding.bottom`; reserving it here keeps the Data card's
      // last rows — "Import hands" and "Reset all progress" — reachable.
      padding: EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        KpiGrid(metrics: metrics),
        const SizedBox(height: AllInSpace.md),
        CumulativeChartCard(metrics: metrics),
        const SizedBox(height: AllInSpace.md),
        CoachingReviewCard(
          metrics: metrics,
          dueCount: due,
          onReviewSpots:
              () => context.go(AllInRoutes.drillsWith(mode: 'leaks')),
          onOpenLesson:
              (lesson) => context.push(AllInRoutes.lessonPath(lesson)),
          onOpenDecision: _openDecision,
        ),
        const SizedBox(height: AllInSpace.md),
        _recentHands(recent, notes, tags, settings.reducedMotion),
        const SizedBox(height: AllInSpace.md),
        ArchetypeCard(metrics: metrics),
        const SizedBox(height: AllInSpace.md),
        PositionsCard(metrics: metrics),
        const SizedBox(height: AllInSpace.md),
        StyleNumbersCard(metrics: metrics),
        const SizedBox(height: AllInSpace.md),
        ReadAccuracyCard(metrics: metrics),
        const SizedBox(height: AllInSpace.md),
        PracticeCard(cells: cells),
        const SizedBox(height: AllInSpace.md),
        DataCard(
          busy: _backingUp,
          onBackup: _backup,
          onImport: () => _flow.start(context),
          onReset: _reset,
        ),
      ],
    );
  }

  Widget _recentHands(
    AsyncValue<List<StoredHand>> recent,
    Map<String, HandNote> notes,
    List<String> tags,
    bool reducedMotion,
  ) {
    final all = recent.valueOrNull ?? const <StoredHand>[];
    final tag = _tagFilter;
    final filtered =
        tag == null ? all : HandsRepository.filterByTag(all, notes, tag);
    final rows =
        filtered.length <= kRecentHandsShown
            ? filtered
            : filtered.sublist(0, kRecentHandsShown);

    return RecentHandsCard(
      hands: rows,
      notes: notes,
      tags: tags,
      tagFilter: tag,
      reducedMotion: reducedMotion,
      onTagFilter: (t) => setState(() => _tagFilter = t),
      onImport: () => _flow.start(context),
      onOpen: _openHand,
      onNote: _note,
      onExport: _export,
      onAllHands:
          () => context
              .push(AllInRoutes.allHandsPath(tag: _tagFilter))
              .then((_) => _refresh()),
    );
  }

  /* ------------------------------------------------------------ actions */

  void _openHand(StoredHand hand) => context
      .push(AllInRoutes.statsHandPath(hand.startedAt))
      .then((_) => _refresh());

  Future<void> _note(StoredHand hand) async {
    await showHandNoteEditor(
      context,
      ref,
      startedAt: hand.startedAt,
      handId: hand.hand.id,
    );
  }

  Future<void> _export(StoredHand hand) async {
    final outcome = await ref
        .read(statsDataActionsProvider)
        .shareHand(hand.hand);
    if (!mounted) return;
    if (outcome == ShareOutcome.unavailable) {
      AllInToast.show(context, StatsCopy.shareFailed);
    }
  }

  /// A −EV row opens the hand it came from, at the frame it came from, when
  /// that hand is still stored (§7.1). When it is not, the row stays inert.
  Future<void> _openDecision(DecisionRecord decision) async {
    final hands = ref.read(recentHandsProvider).valueOrNull;
    if (hands == null) return;
    for (final stored in hands) {
      final model = ReplayModel.of(stored.hand, coachNotes: stored.coachNotes);
      final frame = model.frameForNote(
        street: decision.street,
        action: decision.action,
      );
      final note = model.noteAt(frame);
      if (note == null) continue;
      if (!mounted) return;
      await context.push(
        Uri(
          path: AllInRoutes.statsHandPath(stored.startedAt),
          queryParameters: {
            'street': decision.street,
            'action': decision.action,
          },
        ).toString(),
      );
      if (mounted) _refresh();
      return;
    }
  }

  Future<void> _backup() async {
    setState(() => _backingUp = true);
    ShareOutcome outcome;
    try {
      outcome = await ref.read(statsDataActionsProvider).shareBackup();
    } catch (_) {
      outcome = ShareOutcome.unavailable;
    }
    if (!mounted) return;
    setState(() => _backingUp = false);
    final message = switch (outcome) {
      ShareOutcome.success => StatsCopy.backupShared,
      ShareOutcome.dismissed => null,
      ShareOutcome.unavailable => StatsCopy.backupFailed,
    };
    if (message != null) AllInToast.show(context, message);
  }

  Future<void> _reset() async {
    final erased = await showResetProgressDialog(context, ref);
    if (!mounted || !erased) return;
    setState(() => _tagFilter = null);
    AllInToast.show(context, StatsCopy.resetDone);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.colors.gold,
      ),
    ),
  );
}

/// §14 "Storage · quota / DB error": the page says something and offers the
/// one action that can help.
class _Error extends StatelessWidget {
  const _Error({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AllInSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            StatsCopy.storageProblem,
            textAlign: TextAlign.center,
            style: AllInText.body(15, color: c.textMuted, height: 1.5),
          ),
          const SizedBox(height: AllInSpace.lg),
          AllInButton.secondary(
            label: 'Try again',
            expand: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
