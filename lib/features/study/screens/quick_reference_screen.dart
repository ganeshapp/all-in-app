/// S4 · Quick reference + Glossary (DESIGN.md §6.7). `?term=` scrolls to and
/// flashes one entry; an unknown id opens at the top, never an error.
///
/// The content is not retyped: the five sections are the `cheat-sheet`
/// lesson's headings and key/value tables, and the glossary is `kGlossary` in
/// glossary order — the same single source of truth the S2 popovers read.
library;

import 'dart:async';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/content/glossary.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/features/study/widgets/lesson_blocks.dart';
import 'package:allin/features/study/widgets/study_chrome.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Verbatim (desktop, adapted) caption — §6.7.
const String kQuickReferenceCaption =
    'Every term below is also tappable wherever it appears in a lesson.';

/// The lesson the five reference sections come from.
const String kCheatSheetLessonId = 'cheat-sheet';

/// How long a deep-linked term stays washed gold (§6.7).
const Duration kTermFlashDuration = Duration(milliseconds: 600);

/// One row of the screen: a section heading, a key/value reference row, or a
/// glossary entry.
sealed class _Entry {
  const _Entry();

  /// Everything the search field matches against.
  String get haystack;
}

class _SectionEntry extends _Entry {
  const _SectionEntry(this.title);
  final String title;

  @override
  String get haystack => title;
}

class _RefEntry extends _Entry {
  const _RefEntry(this.label, this.value);
  final String label;
  final String value;

  @override
  String get haystack => '$label $value';
}

class _TermEntry extends _Entry {
  const _TermEntry(this.term);
  final GlossaryTerm term;

  @override
  String get haystack => '${term.key} ${term.term} ${term.definition}';
}

/// The cheat-sheet lesson flattened into [_Entry] rows, plus the glossary.
List<_Entry> _buildQuickReferenceEntries() {
  final entries = <_Entry>[];
  final lesson = lessonById(kCheatSheetLessonId);
  if (lesson != null) {
    for (final block in lesson.body) {
      if (block is HeadingBlock) {
        // "Glossary" is rendered from kGlossary below, not from the lesson's
        // paragraph copies of it — one source of truth (§6.7).
        if (block.text.toLowerCase() == 'glossary') break;
        entries.add(_SectionEntry(block.text));
      } else if (block is TableBlock) {
        for (final row in block.rows) {
          entries.add(
            _RefEntry(row.isEmpty ? '' : row[0], row.length > 1 ? row[1] : ''),
          );
        }
      }
    }
  }
  entries.add(const _SectionEntry('Glossary'));
  for (final term in kGlossary) {
    entries.add(_TermEntry(term));
  }
  return entries;
}

class QuickReferenceScreen extends ConsumerStatefulWidget {
  const QuickReferenceScreen({super.key, this.term});

  /// Glossary term id from `?term=`; null opens at the top.
  final String? term;

  @override
  ConsumerState<QuickReferenceScreen> createState() =>
      QuickReferenceScreenState();
}

/// Public only because `createState` may not return a private type.
class QuickReferenceScreenState extends ConsumerState<QuickReferenceScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _termKeys = <String, GlobalKey>{};
  late final List<_Entry> _entries = _buildQuickReferenceEntries();

  String _query = '';
  String? _flashing;

  /// Held so `dispose` can cancel it: a deep link that is closed inside 600 ms
  /// must not leave a timer behind (a real leak, and an immediate failure in
  /// widget tests).
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    final target = widget.term;
    if (target == null) return;
    // An unknown id is not an error: the screen simply opens at the top (§6.7).
    if (!kGlossary.any((t) => t.key == target)) return;
    _termKeys[target] = GlobalKey();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealTerm(target));
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _revealTerm(String id) async {
    final key = _termKeys[id];
    final target = key?.currentContext;
    if (target == null || !mounted) return;
    final reduced = ref.read(reducedMotionProvider);
    await Scrollable.ensureVisible(
      target,
      duration: reduced ? Duration.zero : AllInMotion.base,
      curve: AllInMotion.ease,
      alignment: 0.2,
    );
    if (!mounted) return;
    setState(() => _flashing = id);
    _flashTimer?.cancel();
    _flashTimer = Timer(kTermFlashDuration, () {
      if (!mounted) return;
      setState(() => _flashing = null);
    });
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.studyPath);
    }
  }

  List<_Entry> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    final kept = <_Entry>[];
    for (final entry in _entries) {
      if (entry is _SectionEntry) continue;
      if (entry.haystack.toLowerCase().contains(q)) kept.add(entry);
    }
    return kept;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    final visible = _visible;

    return AllInScaffold(
      title: 'Quick reference',
      leading: StudyBackChevron(onTap: _close),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AllInSpace.lg,
              0,
              AllInSpace.lg,
              AllInSpace.md,
            ),
            child: _SearchField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              onClear:
                  () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
            ),
          ),
          Expanded(
            // A laid-out column, not a `ListView`: the `?term=` deep link
            // scrolls a row into view through its `GlobalKey`, and a sliver
            // list has not laid out an off-screen row, so `ensureVisible`
            // would silently do nothing. Forty-odd short rows are cheap.
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                AllInSpace.lg,
                0,
                AllInSpace.lg,
                AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AllInSpace.lg),
                      child: Text(
                        'Nothing matches \u201C${_query.trim()}\u201D.',
                        style: AllInText.body(15, color: c.textMuted),
                      ),
                    ),
                  for (var index = 0; index < visible.length; index++)
                    switch (visible[index]) {
                      _SectionEntry(:final title) => Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : AllInSpace.lg,
                          bottom: AllInSpace.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: AllInText.display(18, color: c.text),
                              ),
                            ),
                            if (title == 'Glossary') ...<Widget>[
                              const SizedBox(height: AllInSpace.xs),
                              Text(
                                kQuickReferenceCaption,
                                style: AllInText.body(
                                  12.5,
                                  color: c.textFaint,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _RefEntry(:final label, :final value) => Padding(
                        padding: const EdgeInsets.only(bottom: AllInSpace.sm),
                        child: StatRowCard(
                          label: label,
                          value: value,
                          reducedMotion: reduced,
                        ),
                      ),
                      _TermEntry(:final term) => _GlossaryRow(
                        key: _termKeys.putIfAbsent(term.key, GlobalKey.new),
                        term: term,
                        highlighted: _flashing == term.key,
                        reducedMotion: reduced,
                      ),
                    },
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  static const String hint = 'Search terms and numbers';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: AllInSpace.md),
      decoration: BoxDecoration(
        color: c.ink850,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AllInRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, size: 18, color: c.textFaint),
          const SizedBox(width: AllInSpace.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AllInText.body(15, color: c.text),
              cursorColor: c.gold,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AllInText.body(15, color: c.textFaint),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder:
                (context, value, _) =>
                    value.text.isEmpty
                        ? const SizedBox.shrink()
                        : Semantics(
                          button: true,
                          label: 'Clear search',
                          excludeSemantics: true,
                          child: InkResponse(
                            onTap: onClear,
                            radius: 22,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: c.textMuted,
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

class _GlossaryRow extends StatelessWidget {
  const _GlossaryRow({
    super.key,
    required this.term,
    required this.highlighted,
    required this.reducedMotion,
  });

  final GlossaryTerm term;
  final bool highlighted;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AllInMotion.of(
        context,
        AllInMotion.base,
        reduced: reducedMotion,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.sm,
        vertical: AllInSpace.sm,
      ),
      decoration: BoxDecoration(
        color: highlighted ? c.gold.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(AllInRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            term.term,
            style: AllInText.body(15, weight: FontWeight.w600, color: c.text),
          ),
          const SizedBox(height: 2),
          Text(
            term.definition,
            style: AllInText.body(14, color: c.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
