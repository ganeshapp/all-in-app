/// H0 · Today — the Home tab root (DESIGN.md §3).
///
/// One question: "what should I do in the next five minutes?". The answer is
/// the §3.2 plan — one primary card and at most three alternates, each stating
/// its time estimate and routing to the place that does the work — plus the
/// quiet goal card (§3.3), the coach's one sentence (§3.4) and the two rows
/// under it (§3.5).
///
/// Home owns no rules. Every card is a view over another feature's provider,
/// so the number here and the number there can never disagree; the only work
/// this screen does is deciding what to show first and where a tap goes.
///
/// Freshness: Play records hands through its own `GoalsStore` and its own
/// stats repository, so the goal, the queues and the lifetime numbers are
/// re-read when the tab appears and on a Home-tab re-tap.
///
/// Everything on this screen is local and live, which is why there is no
/// pull-to-refresh and no offline state (§3.5): there is nothing to be offline
/// from. The one read that can fail is the lifetime snapshot, and when it does
/// the plan is unaffected and the coach falls back to its no-data line (§14).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/drills/providers/goals_provider.dart';
import 'package:allin/features/drills/providers/review_provider.dart';
import 'package:allin/features/home/home_copy.dart';
import 'package:allin/features/home/providers/coach_note_provider.dart';
import 'package:allin/features/home/providers/home_providers.dart';
import 'package:allin/features/home/providers/plan_provider.dart';
import 'package:allin/features/home/widgets/home_sheets.dart';
import 'package:allin/features/home/widgets/last_session_card.dart';
import 'package:allin/features/home/widgets/mini_heatmap_card.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/services/persistence/settings_store.dart'
    show AppSettings;
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The home branch's index in the tab scaffold (§2.1).
const int kHomeBranch = 0;

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Re-read what other features wrote behind our back (§7 "Freshness").
  void _refresh() {
    if (!mounted) return;
    ref.read(goalsProvider.notifier).refresh();
    ref.read(leakQueueProvider.notifier).refresh();
    ref.read(reviewQueueProvider.notifier).refresh();
    ref.read(statsRevisionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = ref.watch(homeClockProvider).now();
    final plan = ref.watch(planProvider);
    final goal = ref.watch(homeGoalProvider);
    final note = ref.watch(homeCoachNoteProvider);
    final lastSession = ref.watch(homeLastSessionProvider);
    final cells = lastWeeks(ref.watch(heatmapProvider));
    final settings = ref.watch(settingsProvider);
    final activeDays = HeatmapGrid.activeDays(cells);

    // Re-tapping the Home tab scrolls this page to the top (§2.1, §12).
    ref.listen(tabReselectProvider, (previous, next) {
      if (next.branch != kHomeBranch) return;
      _refresh();
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });

    return AllInScaffold(
      title: HomeCopy.greeting(now),
      subtitle:
          plan.firstRun
              ? HomeCopy.firstRunSubtitle
              : HomeCopy.streakLine(now, goal.streak),
      actions: [
        IconButton(
          tooltip: HomeCopy.settingsAction,
          icon: Icon(Icons.settings_outlined, color: c.textMuted),
          // §16.1: Settings has one canonical path, in the Stats branch, and
          // the gear honestly moves the user there.
          onPressed: () => context.go(AllInRoutes.settingsPath),
        ),
      ],
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          AllInSpace.lg,
          0,
          AllInSpace.lg,
          MediaQuery.paddingOf(context).bottom + AllInSpace.lg,
        ),
        children: [
          GoalCard(
            label: HomeCopy.goalLabel,
            progress: goal.progress,
            count: goal.count,
            caption: goal.caption,
            reducedMotion: settings.reducedMotion,
            onTap: () => showHomeGoalSheet(context, ref),
          ),
          const SizedBox(height: AllInSpace.lg),
          const Eyebrow(HomeCopy.eyebrowNextUp),
          if (plan.goalMet) ...[
            const SizedBox(height: AllInSpace.sm),
            Text(HomeCopy.goalMet, style: AllInText.body(14, color: c.good)),
          ],
          const SizedBox(height: AllInSpace.md),
          for (var i = 0; i < plan.cards.length; i++) ...[
            _planCard(plan.cards[i], primary: i == 0, settings: settings),
            const SizedBox(height: AllInSpace.md),
          ],
          CoachCard(
            note: note.sentence,
            label: HomeCopy.coachLabel,
            actionLabel: HomeCopy.coachAction,
            onTap: () => _openCoachNote(note),
          ),
          if (lastSession != null) ...[
            const SizedBox(height: AllInSpace.lg),
            const Eyebrow(HomeCopy.eyebrowLastSession),
            const SizedBox(height: AllInSpace.md),
            LastSessionCard(
              session: lastSession,
              onTap: () => _openLastSession(lastSession.id),
            ),
          ],
          if (activeDays > 0) ...[
            const SizedBox(height: AllInSpace.lg),
            MiniHeatmapCard(
              cells: cells,
              onTap: () => context.go(AllInRoutes.progressPath),
            ),
          ],
        ],
      ),
    );
  }

  Widget _planCard(
    PlanEntry entry, {
    required bool primary,
    required AppSettings settings,
  }) {
    final label = entry.buttonLabel;
    return PlanCard(
      key: ValueKey(entry.kind),
      icon: _iconFor(entry.kind),
      title: entry.title,
      subtitle: entry.subtitle,
      estimate: entry.estimate,
      primary: primary,
      onTap: () => _openCard(entry),
      button:
          primary && label != null
              ? AllInButton.primary(
                label: label,
                size: AllInButtonSize.sm,
                enableHaptics: settings.haptics,
                reducedMotion: settings.reducedMotion,
                onPressed: () => _openCard(entry),
              )
              : null,
    );
  }

  static IconData _iconFor(PlanCardKind kind) => switch (kind) {
    PlanCardKind.review => Icons.donut_large,
    PlanCardKind.resume => Icons.play_arrow_rounded,
    PlanCardKind.lesson => Icons.menu_book_outlined,
    PlanCardKind.quickSet => Icons.adjust,
    PlanCardKind.play => Icons.style_outlined,
  };

  /* ------------------------------------------------------------ actions */

  void _openCard(PlanEntry entry) {
    if (entry.kind == PlanCardKind.play) {
      // §3.2 card 5: "launches with the saved options" — Home never shows
      // table setup, that is the lobby's job.
      ref.read(sessionProvider.notifier).newSession();
      context.go(AllInRoutes.tablePath);
      return;
    }
    final route = entry.route;
    if (route == null) return;
    context.go(route);
  }

  void _openLastSession(int? id) {
    if (id == null) return;
    context.push(AllInRoutes.sessionPath(AllInRoutes.todayPath, '$id'));
  }

  Future<void> _openCoachNote(HomeCoachNote note) async {
    final action = await showHomeCoachSheet(context, ref, note: note);
    if (action == null || !mounted) return;

    final lessonId = note.lessonId;
    switch (action) {
      case CoachSheetAction.lesson:
        if (lessonId != null) context.go(AllInRoutes.lessonPath(lessonId));
      case CoachSheetAction.review:
        context.go(AllInRoutes.drillsWith(mode: 'leaks'));
    }
  }
}
