/// T0's "Recent hands" card and the tag-chip filter it shares with T2
/// (DESIGN.md §7.5, `docs/port/persistence-stats-settings.md` §7.9).
///
/// The card is presentational: the screen owns the data, the filter and every
/// navigation, so the same rows render identically in T0's five-row card and
/// in T2's full list.
library;

import 'package:flutter/material.dart';

import '../../../services/persistence.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../stats_copy.dart';
import 'hand_row.dart';
import 'stats_section.dart';

/// `all` + one chip per tag in use across *all* notes (§7.9). Tapping the
/// selected tag clears the filter.
class TagFilterRow extends StatelessWidget {
  const TagFilterRow({
    super.key,
    required this.tags,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tags;

  /// Null = "all".
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: StatsCopy.tagAll,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final tag in tags)
            _Chip(
              label: tag,
              selected: selected == tag,
              onTap: () => onSelect(selected == tag ? null : tag),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(right: AllInSpace.sm),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.gold.withValues(alpha: 0.16) : c.ink850,
                  borderRadius: BorderRadius.circular(AllInRadius.pill),
                  border: Border.all(color: selected ? c.gold : c.line),
                ),
                child: Text(
                  label,
                  style: AllInText.body(
                    13,
                    color: selected ? c.gold : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rows themselves plus the two verbatim empty states.
class HandList extends StatelessWidget {
  const HandList({
    super.key,
    required this.hands,
    required this.notes,
    required this.filtered,
    required this.onOpen,
    required this.onNote,
    this.onExport,
    this.reducedMotion = false,
  });

  final List<StoredHand> hands;
  final Map<String, HandNote> notes;

  /// True when a tag or source filter is active — picks the empty line.
  final bool filtered;

  final ValueChanged<StoredHand> onOpen;
  final ValueChanged<StoredHand> onNote;
  final ValueChanged<StoredHand>? onExport;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (hands.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AllInSpace.sm),
        child: Text(
          filtered ? StatsCopy.handsEmptyForTag : StatsCopy.handsEmpty,
          style: AllInText.body(14, color: c.textMuted, height: 1.5),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hand in hands)
          HandRow(
            key: ValueKey(hand.startedAt),
            hand: hand,
            note: notes[handNoteKey(hand.startedAt)],
            reducedMotion: reducedMotion,
            onOpen: () => onOpen(hand),
            onNote: () => onNote(hand),
            onExport: onExport == null ? null : () => onExport!(hand),
          ),
      ],
    );
  }
}

/// T0's card: header + Import, the chip row, five rows, "All hands ›".
class RecentHandsCard extends StatelessWidget {
  const RecentHandsCard({
    super.key,
    required this.hands,
    required this.notes,
    required this.tags,
    required this.tagFilter,
    required this.onTagFilter,
    required this.onImport,
    required this.onOpen,
    required this.onNote,
    required this.onAllHands,
    this.onExport,
    this.reducedMotion = false,
  });

  final List<StoredHand> hands;
  final Map<String, HandNote> notes;
  final List<String> tags;
  final String? tagFilter;
  final ValueChanged<String?> onTagFilter;
  final VoidCallback onImport;
  final ValueChanged<StoredHand> onOpen;
  final ValueChanged<StoredHand> onNote;
  final ValueChanged<StoredHand>? onExport;
  final VoidCallback onAllHands;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StatsSection(
      title: StatsCopy.recentHandsCard,
      action: AllInButton.ghost(
        label: StatsCopy.importShort,
        leading: Icons.file_download_outlined,
        size: AllInButtonSize.sm,
        onPressed: onImport,
        semanticLabel: StatsCopy.importButton,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tags.isNotEmpty) ...[
            TagFilterRow(
              tags: tags,
              selected: tagFilter,
              onSelect: onTagFilter,
            ),
            const SizedBox(height: AllInSpace.xs),
          ],
          HandList(
            hands: hands,
            notes: notes,
            filtered: tagFilter != null,
            reducedMotion: reducedMotion,
            onOpen: onOpen,
            onNote: onNote,
            onExport: onExport,
          ),
          const SizedBox(height: AllInSpace.xs),
          Semantics(
            button: true,
            label: StatsCopy.allHandsTitle,
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onAllHands,
                borderRadius: BorderRadius.circular(AllInRadius.md),
                child: SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      StatsCopy.allHandsRow,
                      style: AllInText.body(14, color: c.gold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
