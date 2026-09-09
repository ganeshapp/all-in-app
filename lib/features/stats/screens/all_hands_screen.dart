/// T2 · All hands (DESIGN.md §7.5) — `/stats/hands?filter=…&tag=…`.
///
/// `loadRecentHands(100)` with the tag chips, the "All / Played / Imported"
/// segmented control and rows 56 that open P11, edit a note (P12) or share the
/// hand's text. Lists longer than a page grow with "Load more" (§14 "> 1 000
/// rows → 100 at a time").
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/stats/providers/data_actions.dart';
import 'package:allin/features/stats/providers/import_provider.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/features/stats/stats_copy.dart';
import 'package:allin/features/stats/widgets/import_flow.dart';
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

class AllHandsScreen extends ConsumerStatefulWidget {
  const AllHandsScreen({super.key, this.filter, this.tag});

  /// `all` · `played` · `imported`; null means all.
  final String? filter;

  /// Tag chip filter from `?tag=`.
  final String? tag;

  @override
  ConsumerState<AllHandsScreen> createState() => _AllHandsScreenState();
}

class _AllHandsScreenState extends ConsumerState<AllHandsScreen> {
  late HandSource _source;
  late String? _tag;
  int _limit = kAllHandsPage;
  ImportFlowController? _import;

  @override
  void initState() {
    super.initState();
    _source = switch (widget.filter) {
      'played' => HandSource.played,
      'imported' => HandSource.imported,
      _ => HandSource.all,
    };
    _tag = widget.tag;
  }

  ImportFlowController get _flow =>
      _import ??= ImportFlowController(
        ref: ref,
        onSeeHands: () => setState(() => _source = HandSource.imported),
        onReviewNow: () => context.go(AllInRoutes.drillsWith(mode: 'leaks')),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final notes = ref.watch(notesProvider);
    final tags = ref.watch(allTagsProvider);
    final hands = ref.watch(allHandsProvider(_limit));
    final settings = ref.watch(settingsProvider);

    ref.listen(importProvider, (previous, next) {
      _flow.handle(context, previous, next);
    });

    return AllInScaffold(
      leading: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.chevron_left, color: c.text),
        onPressed:
            () =>
                context.canPop()
                    ? context.pop()
                    : context.go(AllInRoutes.progressPath),
      ),
      title: StatsCopy.allHandsTitle,
      actions: [
        IconButton(
          tooltip: StatsCopy.importButton,
          icon: Icon(Icons.file_download_outlined, color: c.textMuted),
          onPressed: () => _flow.start(context),
        ),
      ],
      body: ListView(
        // T2 keeps the tab bar (and the Session pill), so the shell's chrome
        // inset has to be reserved or the last hand rows sit under it.
        padding: EdgeInsets.fromLTRB(
          AllInSpace.lg,
          0,
          AllInSpace.lg,
          AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          AllInSegmented(
            labels: const [
              StatsCopy.filterAll,
              StatsCopy.filterPlayed,
              StatsCopy.filterImported,
            ],
            value: _source.index,
            semanticLabel: 'Hand source',
            enableHaptics: settings.haptics,
            reducedMotion: settings.reducedMotion,
            onChanged: (i) => setState(() => _source = HandSource.values[i]),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AllInSpace.sm),
            TagFilterRow(
              tags: tags,
              selected: _tag,
              onSelect: (t) => setState(() => _tag = t),
            ),
          ],
          const SizedBox(height: AllInSpace.sm),
          hands.when(
            loading: () => const _Loading(),
            error:
                (_, _) => Text(
                  StatsCopy.storageProblem,
                  style: AllInText.body(14, color: c.textMuted),
                ),
            data: (all) => _list(all, notes, settings.reducedMotion),
          ),
        ],
      ),
    );
  }

  Widget _list(
    List<StoredHand> all,
    Map<String, HandNote> notes,
    bool reducedMotion,
  ) {
    var rows = all;
    if (_source != HandSource.all) {
      final wantImported = _source == HandSource.imported;
      rows = rows.where((h) => h.imported == wantImported).toList();
    }
    final tag = _tag;
    if (tag != null) {
      rows = HandsRepository.filterByTag(rows, notes, tag);
    }
    final more = all.length >= _limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandList(
          hands: rows,
          notes: notes,
          filtered: tag != null || _source != HandSource.all,
          reducedMotion: reducedMotion,
          onOpen: _open,
          onNote: _note,
          onExport: _export,
        ),
        if (more) ...[
          const SizedBox(height: AllInSpace.md),
          AllInButton.ghost(
            label: StatsCopy.loadMore,
            expand: true,
            onPressed: () => setState(() => _limit += kAllHandsPage),
          ),
        ],
      ],
    );
  }

  void _open(StoredHand hand) =>
      context.push(AllInRoutes.statsHandPath(hand.startedAt));

  Future<void> _note(StoredHand hand) => showHandNoteEditor(
    context,
    ref,
    startedAt: hand.startedAt,
    handId: hand.hand.id,
  );

  Future<void> _export(StoredHand hand) async {
    final outcome = await ref
        .read(statsDataActionsProvider)
        .shareHand(hand.hand);
    if (!mounted) return;
    if (outcome == ShareOutcome.unavailable) {
      AllInToast.show(context, StatsCopy.shareFailed);
    }
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AllInSpace.xl),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.gold,
        ),
      ),
    ),
  );
}
