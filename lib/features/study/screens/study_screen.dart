/// S0 · Study — the Study tab root (DESIGN.md §6.1): the progress header, the
/// "Continue" card, the tools grid, the pinned Quick reference row, and the
/// five levels with sticky headers over 31 lesson rows.
///
/// Levels are always expanded (no accordion): one less tap, and the pinned
/// header is what keeps orientation while 31 rows scroll past.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/features/study/widgets/study_path.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  /// The shell's branch index for Study — re-tapping it scrolls S0 to the top
  /// (§2.1, §12).
  static const int branchIndex = 3;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop(bool reduced) {
    if (!_scroll.hasClients) return;
    if (reduced) {
      _scroll.jumpTo(0);
      return;
    }
    _scroll.animateTo(
      0,
      duration: AllInMotion.base,
      curve: AllInMotion.easeOut,
    );
  }

  void _openLesson(String id) {
    ref.read(studyLastReadProvider.notifier).set(id);
    context.push(AllInRoutes.lessonPath(id));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = ref.watch(reducedMotionProvider);
    final progress = ref.watch(studyProgressProvider);
    final continueLesson = ref.watch(studyContinueLessonProvider);
    final lastRead = ref.watch(studyLastReadProvider);
    final completed = progress.completed.toSet();
    final active = lastRead ?? continueLesson?.id;

    ref.listen(tabReselectProvider, (previous, next) {
      if (next.branch == StudyScreen.branchIndex) _scrollToTop(reduced);
    });

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final headerExtent = 48 * textScale.clamp(1.0, 1.5);

    return AllInScaffold(
      title: 'Study',
      body: CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AllInSpace.lg,
              0,
              AllInSpace.lg,
              AllInSpace.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(<Widget>[
                StudyProgressHeader(
                  completed: progress.completedCount,
                  total: progress.total,
                  reducedMotion: reduced,
                ),
                const SizedBox(height: AllInSpace.lg),
                ContinueCard(
                  lesson: continueLesson,
                  levelTitle:
                      continueLesson == null
                          ? null
                          : levelForLesson(continueLesson.id)?.title,
                  onTap:
                      () => _openLesson(
                        continueLesson?.id ?? kAllLessonIds.first,
                      ),
                ),
                const SizedBox(height: AllInSpace.lg),
                const Eyebrow('Tools'),
                const SizedBox(height: AllInSpace.sm),
                ToolsGrid(
                  onOpen: (tool) => context.push(AllInRoutes.toolPath(tool.id)),
                ),
                const SizedBox(height: AllInSpace.sm),
                QuickReferenceRow(
                  onTap: () => context.push(AllInRoutes.glossaryPath()),
                ),
              ]),
            ),
          ),
          for (var i = 0; i < kLevels.length; i++)
            SliverMainAxisGroup(
              slivers: <Widget>[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _LevelHeaderDelegate(
                    extent: headerExtent,
                    background: c.ink900,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AllInSpace.lg,
                      ),
                      child: LevelHeader(
                        level: kLevels[i],
                        index: i,
                        done: progress.completedInLevel(kLevels[i]),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AllInSpace.lg,
                    0,
                    AllInSpace.lg,
                    AllInSpace.md,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final lesson = kLevels[i].lessons[index];
                      return LessonRow(
                        lesson: lesson,
                        done: completed.contains(lesson.id),
                        active: lesson.id == active,
                        reducedMotion: reduced,
                        onTap: () => _openLesson(lesson.id),
                      );
                    }, childCount: kLevels[i].lessons.length),
                  ),
                ),
              ],
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _LevelHeaderDelegate({
    required this.extent,
    required this.child,
    required this.background,
  });

  final double extent;
  final Widget child;
  final Color background;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: background, child: child);

  @override
  bool shouldRebuild(_LevelHeaderDelegate old) =>
      old.extent != extent ||
      old.child != child ||
      old.background != background;
}
