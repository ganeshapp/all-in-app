/// The compact hand-note editor behind P2's ✎ (DESIGN.md §4.11 hand rows).
///
/// **Seam.** The full P12 editor (§7.6: tags, the tag picker, delete) belongs
/// to `features/stats`. This is the minimum the Play sheet owes its own ✎ so
/// the control is never dead: read the note, edit it, save it. It writes the
/// same `allin.notes.v1` record P12 reads, so nothing has to be migrated when
/// P12 lands — delete this file and point the ✎ at P12.
library;

import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HandNoteSheet extends ConsumerStatefulWidget {
  const HandNoteSheet({super.key, required this.startedAt});

  /// The hand's `startedAt` — the notes repository's key.
  final int startedAt;

  static Future<void> show(
    BuildContext context, {
    required int startedAt,
    bool reducedMotion = false,
  }) => AllInSheet.show<void>(
    context,
    detent: AllInSheetDetent.s,
    reducedMotion: reducedMotion,
    maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
    child: HandNoteSheet(startedAt: startedAt),
  );

  @override
  ConsumerState<HandNoteSheet> createState() => _HandNoteSheetState();
}

class _HandNoteSheetState extends ConsumerState<HandNoteSheet> {
  late final TextEditingController _field = TextEditingController(
    text: ref.read(playNotesProvider).noteFor(widget.startedAt)?.note ?? '',
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(playNotesProvider);
    final text = _field.text.trim();
    final existing = repo.noteFor(widget.startedAt);
    await repo.setNote(
      widget.startedAt,
      note: text,
      tags: existing?.tags ?? const [],
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Note on this hand',
            style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
          ),
          const SizedBox(height: AllInSpace.md),
          TextField(
            controller: _field,
            maxLines: 4,
            autofocus: true,
            style: AllInText.body(15, color: c.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.ink900,
              hintText: 'What do you want to remember?',
              hintStyle: AllInText.body(15, color: c.textFaint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AllInRadius.md),
                borderSide: BorderSide(color: c.line),
              ),
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          AllInButton.primary(label: 'Save', expand: true, onPressed: _save),
        ],
      ),
    );
  }
}
