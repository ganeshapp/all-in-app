/// P12 · Hand note editor (DESIGN.md §7.6).
///
/// Sheet M, keyboard-aware: the content scrolls and the Save row is pushed up
/// by `MediaQuery.viewInsetsOf`, so it stays visible above the keyboard (§14
/// "Any sheet · keyboard up"). Key is `startedAt`, exactly as the desktop's
/// `handKey` — the note survives a reset, because `resetStats` never touches
/// `allin.handnotes.v1`.
///
/// The desktop's "bookmark" *is* the `review later` tag (§15.4): there is no
/// separate flag here either.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../services/persistence.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/stats_providers.dart';
import '../stats_copy.dart';
import '../stats_format.dart';

/// Opens P12 for [startedAt]. Returns true when the note was saved or removed.
Future<bool> showHandNoteEditor(
  BuildContext context,
  WidgetRef ref, {
  required int startedAt,
  required int handId,
}) async {
  final settings = ref.read(settingsProvider);
  final saved = await AllInSheet.show<bool>(
    context,
    detent: AllInSheetDetent.m,
    reducedMotion: settings.reducedMotion,
    builder:
        (sheetContext) => HandNoteEditor(startedAt: startedAt, handId: handId),
  );
  return saved ?? false;
}

class HandNoteEditor extends ConsumerStatefulWidget {
  const HandNoteEditor({
    super.key,
    required this.startedAt,
    required this.handId,
  });

  final int startedAt;
  final int handId;

  @override
  ConsumerState<HandNoteEditor> createState() => _HandNoteEditorState();
}

class _HandNoteEditorState extends ConsumerState<HandNoteEditor> {
  late final TextEditingController _text;
  late final TextEditingController _custom;
  late List<String> _tags;
  late final bool _hadNote;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(notesProvider)[handNoteKey(widget.startedAt)];
    _hadNote = existing != null;
    _text = TextEditingController(text: existing?.note ?? '');
    _custom = TextEditingController();
    _tags = List<String>.of(existing?.tags ?? const <String>[]);
  }

  @override
  void dispose() {
    _text.dispose();
    _custom.dispose();
    super.dispose();
  }

  /// Preset chips plus any custom tag already on this note (§7.6).
  List<String> get _chips => [
    ...kPresetTags,
    ..._tags.where((t) => !kPresetTags.contains(t)),
  ];

  bool get _canSave => _text.text.trim().isNotEmpty || _tags.isNotEmpty;

  void _toggle(String tag) {
    final notes = ref.read(notesProvider.notifier);
    setState(() => _tags = notes.toggleTag(_tags, tag));
  }

  void _addCustom() {
    final raw = _custom.text.trim().toLowerCase();
    if (raw.isEmpty) return;
    _custom.clear();
    if (_tags.contains(raw)) return;
    _toggle(raw);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final notes = ref.read(notesProvider.notifier);
    final ok = await notes.save(
      widget.startedAt,
      note: _text.text.trim(),
      tags: _tags,
    );
    ref.read(statsRevisionProvider.notifier).bump();
    if (!mounted) return;
    Navigator.of(context).pop(ok);
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(notesProvider.notifier).remove(widget.startedAt);
    ref.read(statsRevisionProvider.notifier).bump();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    // `AllInSheet` draws chrome only — every sheet body owns its own padding.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AllInSpace.lg,
        AllInSpace.sm,
        AllInSpace.lg,
        insets + AllInSpace.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    StatsCopy.noteTitle(widget.handId),
                    style: AllInText.body(
                      17,
                      weight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    noteDateLabel(widget.startedAt),
                    style: AllInText.body(13, color: c.textMuted),
                  ),
                  const SizedBox(height: AllInSpace.md),
                  _NoteField(
                    controller: _text,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: AllInSpace.lg),
                  Eyebrow(StatsCopy.noteTags),
                  const SizedBox(height: AllInSpace.sm),
                  Wrap(
                    spacing: AllInSpace.sm,
                    runSpacing: AllInSpace.sm,
                    children: [
                      for (final tag in _chips)
                        _TagChip(
                          label: tag,
                          selected: _tags.contains(tag),
                          onTap: () => _toggle(tag),
                        ),
                    ],
                  ),
                  const SizedBox(height: AllInSpace.sm),
                  _CustomTagField(controller: _custom, onSubmit: _addCustom),
                ],
              ),
            ),
          ),
          const SizedBox(height: AllInSpace.lg),
          Row(
            children: [
              if (_hadNote)
                Expanded(
                  child: AllInButton.ghost(
                    label: StatsCopy.noteRemove,
                    onPressed: _busy ? null : _remove,
                    expand: true,
                    semanticLabel: StatsCopy.noteRemove,
                  ),
                ),
              if (_hadNote) const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: AllInButton.ghost(
                  label: StatsCopy.noteCancel,
                  expand: true,
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: AllInButton.primary(
                  label: StatsCopy.noteSave,
                  expand: true,
                  onPressed: _canSave && !_busy ? _save : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      minLines: 4,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      style: AllInText.body(15, color: c.text, height: 1.45),
      decoration: InputDecoration(
        hintText: StatsCopy.notePlaceholder,
        hintStyle: AllInText.body(14, color: c.textFaint, height: 1.45),
        filled: true,
        fillColor: c.ink850,
        contentPadding: const EdgeInsets.all(AllInSpace.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AllInRadius.md),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AllInRadius.md),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AllInRadius.md),
          borderSide: BorderSide(color: c.gold),
        ),
      ),
    );
  }
}

class _CustomTagField extends StatelessWidget {
  const _CustomTagField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onSubmit(),
        textInputAction: TextInputAction.done,
        autocorrect: false,
        inputFormatters: [LengthLimitingTextInputFormatter(24)],
        style: AllInText.body(14, color: c.text),
        decoration: InputDecoration(
          hintText: StatsCopy.noteCustomTag,
          hintStyle: AllInText.body(14, color: c.textFaint),
          isDense: true,
          filled: true,
          fillColor: c.ink850,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AllInSpace.md,
            vertical: AllInSpace.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AllInRadius.pill),
            borderSide: BorderSide(color: c.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AllInRadius.pill),
            borderSide: BorderSide(color: c.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AllInRadius.pill),
            borderSide: BorderSide(color: c.gold),
          ),
        ),
      ),
    );
  }
}

/// A 36 pt chip inside a 44 pt tap target (§7.6, §12).
class _TagChip extends StatelessWidget {
  const _TagChip({
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
        // Every box here shrink-wraps horizontally, or the chip fills the
        // `Wrap` and the five presets stack into five full-width rows
        // (§7.6 asks for chips: 36 tall inside a 44 pt target). Both `Center`
        // and `Container(alignment:)` take `constraints.biggest` unless a
        // `widthFactor` says otherwise.
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
                decoration: BoxDecoration(
                  color: selected ? c.gold.withValues(alpha: 0.16) : c.ink850,
                  borderRadius: BorderRadius.circular(AllInRadius.pill),
                  border: Border.all(color: selected ? c.gold : c.line),
                ),
                // `widthFactor: 1` keeps the horizontal shrink-wrap while the
                // label still centres in the 36 pt height.
                child: Align(
                  widthFactor: 1,
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
      ),
    );
  }
}
