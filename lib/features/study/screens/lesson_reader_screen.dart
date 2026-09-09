/// S1 · Lesson reader (DESIGN.md §6.2). Two routes, one widget: the
/// study-branch push `/study/lesson/:id` and the root-level modal
/// `/lesson/:id`, which shows "Done" instead of the back chevron (§16.1).
///
/// Three behaviours the spec is explicit about, and which the code below is
/// arranged around:
///
/// * **Completion is explicit.** "Next lesson" navigates and nothing else;
///   only "Mark complete" writes to the store.
/// * **Widget state is per visit.** The body is keyed by lesson id, so moving
///   to the next lesson rebuilds every slider, painted range and quiz pick
///   from scratch — and the scroll position returns to the top.
/// * **An unknown id never opens.** It lands on Study with the §14 toast; the
///   reader is not a 404 page.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/content/lesson_model.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/features/study/widgets/lesson_blocks.dart';
import 'package:allin/features/study/widgets/study_chrome.dart';
import 'package:allin/features/study/widgets/study_path.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// How the reader was presented — it decides the leading control only.
enum LessonPresentation {
  /// `/study/lesson/:id` — back chevron.
  push,

  /// `/lesson/:id` — full-screen modal with "Done".
  modal,
}

/// §14: the deep-link fallback for a lesson id this build does not have.
const String kUnknownLessonToast =
    "That lesson isn't in this version — here's the course.";

class LessonReaderScreen extends ConsumerStatefulWidget {
  const LessonReaderScreen({
    super.key,
    required this.lessonId,
    this.presentation = LessonPresentation.push,
  });

  /// Lesson id from the path; an unknown id falls back to Study (§14).
  final String lessonId;

  final LessonPresentation presentation;

  @override
  ConsumerState<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends ConsumerState<LessonReaderScreen> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _readProgress = ValueNotifier<double>(0);
  bool _bailedOut = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final lesson = lessonById(widget.lessonId);
    if (lesson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(studyLastReadProvider.notifier).set(widget.lessonId);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _readProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _readProgress.value = max <= 0 ? 0 : (_scroll.offset / max).clamp(0.0, 1.0);
  }

  bool get _isModal => widget.presentation == LessonPresentation.modal;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.studyPath);
    }
  }

  /// §14: never a 404 — Study, with a toast, and the id only in the console.
  void _bailOut() {
    if (_bailedOut) return;
    _bailedOut = true;
    final reduced = ref.read(reducedMotionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('Study: unknown lesson id "${widget.lessonId}"');
      context.go(AllInRoutes.studyPath);
      AllInToast.show(context, kUnknownLessonToast, reducedMotion: reduced);
    });
  }

  void _goToNext(String nextId) {
    _readProgress.value = 0;
    // `pushReplacement`, not `replace`: both keep the stack the same depth,
    // but `replace` swaps the *match* and, on a route reached declaratively
    // (a deep link, a cold start on the lesson), collapses to the parent —
    // "Next lesson" would drop the reader instead of advancing it.
    context.pushReplacement(
      _isModal
          ? AllInRoutes.lessonModalPath(nextId)
          : AllInRoutes.lessonPath(nextId),
    );
  }

  Future<void> _openMenu(Lesson lesson, bool done) async {
    final reduced = ref.read(reducedMotionProvider);
    await AllInSheet.show<void>(
      context,
      detent: AllInSheetDetent.s,
      reducedMotion: reduced,
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(
              AllInSpace.lg,
              0,
              AllInSpace.lg,
              AllInSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _MenuRow(
                  icon: done ? Icons.check_circle_rounded : Icons.check_rounded,
                  label: done ? 'Completed' : 'Mark complete',
                  enabled: !done,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _markComplete(lesson.id);
                  },
                ),
                _MenuRow(
                  icon: Icons.menu_book_rounded,
                  label: 'Quick reference & glossary',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push(AllInRoutes.glossaryPath());
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _markComplete(String id) {
    ref.read(studyProgressProvider.notifier).complete(id);
    ref.read(hapticsProvider).goalMet();
  }

  void _openGlossary(String termId) =>
      context.push(AllInRoutes.glossaryPath(term: termId));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lesson = lessonById(widget.lessonId);
    if (lesson == null) {
      _bailOut();
      return AllInScaffold(
        body: ColoredBox(color: c.ink900, child: const SizedBox.expand()),
      );
    }

    final reduced = ref.watch(reducedMotionProvider);
    final progress = ref.watch(studyProgressProvider);
    final done = progress.isComplete(lesson.id);
    final level = levelWithIndex(lesson.id);
    final nextId = nextLessonId(lesson.id);
    final width = MediaQuery.sizeOf(context).width;
    final contentWidth = width - 2 * AllInSpace.lg;

    // The first paragraph of a lesson is the desktop `Lead` (§6 prose blocks).
    var leadUsed = false;

    return AllInScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
            child: Row(
              children: <Widget>[
                if (_isModal)
                  StudyHeaderButton(
                    label: 'Done',
                    emphasised: true,
                    onTap: _close,
                  )
                else
                  StudyBackChevron(onTap: _close),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AllInSpace.sm,
                    ),
                    child: Eyebrow(
                      (level?.level.title ?? 'Study').toUpperCase(),
                      color: c.gold.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Text(
                  '${progress.completedCount}/${progress.total}',
                  style: AllInText.mono(13, color: c.textFaint),
                ),
                StudyIconButton(
                  icon: Icons.more_horiz_rounded,
                  semanticLabel: 'Lesson options',
                  onTap: () => _openMenu(lesson, done),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _readProgress,
            builder:
                (context, value, _) =>
                    ReadProgressLine(value: value, reducedMotion: reduced),
          ),
          Expanded(
            child: ListView(
              key: ValueKey<String>(lesson.id),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                AllInSpace.lg,
                AllInSpace.md,
                AllInSpace.lg,
                AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    lesson.title,
                    style: AllInText.display(28, color: c.text, height: 1.15),
                  ),
                ),
                const SizedBox(height: AllInSpace.xs),
                Text(
                  '${lesson.minutes} min read',
                  style: AllInText.body(13, color: c.textFaint),
                ),
                const SizedBox(height: AllInSpace.lg),
                for (final block in lesson.body) ...<Widget>[
                  Builder(
                    builder: (context) {
                      final isLead = block is ParagraphBlock && !leadUsed;
                      if (isLead) leadUsed = true;
                      return LessonBlockView(
                        block: block,
                        contentWidth: contentWidth,
                        isLead: isLead,
                        onOpenGlossary: _openGlossary,
                      );
                    },
                  ),
                  const SizedBox(height: kLessonBlockGap),
                ],
                const SizedBox(height: AllInSpace.lg),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  padding: const EdgeInsets.only(top: AllInSpace.xl),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            done
                                ? AllInButton.secondary(
                                  label: 'Completed',
                                  leading: Icons.check_rounded,
                                  expand: true,
                                  reducedMotion: reduced,
                                  onPressed: null,
                                )
                                : AllInButton.primary(
                                  label: 'Mark complete',
                                  expand: true,
                                  reducedMotion: reduced,
                                  enableHaptics: ref.watch(
                                    hapticsEnabledProvider,
                                  ),
                                  onPressed: () => _markComplete(lesson.id),
                                ),
                      ),
                      if (nextId != null) ...<Widget>[
                        const SizedBox(width: AllInSpace.sm),
                        Expanded(
                          child: AllInButton.outline(
                            label: 'Next lesson',
                            trailing: Icons.chevron_right_rounded,
                            expand: true,
                            reducedMotion: reduced,
                            enableHaptics: ref.watch(hapticsEnabledProvider),
                            onPressed: () => _goToNext(nextId),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.centerLeft,
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: enabled ? c.gold : c.textFaint),
              const SizedBox(width: AllInSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: AllInText.body(
                    15,
                    color: enabled ? c.text : c.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
