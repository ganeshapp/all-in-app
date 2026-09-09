/// S3 · Tool screens (DESIGN.md §6.6): range explorer, equity calculator,
/// pot-odds calculator, bluff calculator, multiway trainer, hand rankings —
/// one push each at `/study/tools/:tool`.
///
/// A tool screen *is* its lesson's widget given the whole screen, with that
/// lesson's lead paragraph as the intro and an "Open lesson ›" link back to
/// the prose. It never re-implements the widget.
library;

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

class ToolScreen extends ConsumerWidget {
  const ToolScreen({super.key, required this.tool});

  /// `range-explorer` · `equity` · `pot-odds` · `bluff` · `multiway` ·
  /// `rankings`.
  final String tool;

  /// Titles for the six tools; an unknown id reads "Tools".
  static Map<String, String> get titles => <String, String>{
    for (final t in kStudyTools) t.id: t.label,
  };

  /// The lead paragraph of [lessonId] — the intro §6.6 asks for.
  static String? leadOf(String lessonId) {
    final lesson = lessonById(lessonId);
    if (lesson == null) return null;
    for (final block in lesson.body) {
      if (block is ParagraphBlock) return block.text;
    }
    return null;
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.studyPath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final spec = studyToolById(tool);
    final contentWidth = MediaQuery.sizeOf(context).width - 2 * AllInSpace.lg;
    final lead = spec == null ? null : leadOf(spec.lessonId);

    return AllInScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AllInSpace.sm),
            child: Row(
              children: <Widget>[
                StudyBackChevron(onTap: () => _close(context)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AllInSpace.sm,
                    ),
                    child: Text(
                      spec?.label ?? 'Tools',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AllInText.display(20, color: c.text),
                    ),
                  ),
                ),
                if (spec != null)
                  StudyHeaderButton(
                    label: 'Open lesson ›',
                    onTap: () {
                      ref
                          .read(studyLastReadProvider.notifier)
                          .set(spec.lessonId);
                      context.push(AllInRoutes.lessonPath(spec.lessonId));
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                spec == null
                    ? _UnknownTool(
                      onOpen:
                          (t) => context.replace(AllInRoutes.toolPath(t.id)),
                    )
                    : ListView(
                      padding: EdgeInsets.fromLTRB(
                        AllInSpace.lg,
                        AllInSpace.md,
                        AllInSpace.lg,
                        AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: <Widget>[
                        if (lead != null) ...<Widget>[
                          Text(
                            lead,
                            style: AllInText.body(
                              16,
                              color: c.textMuted,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: kLessonBlockGap),
                        ],
                        LessonWidgetView(
                          kind: spec.kind,
                          contentWidth: contentWidth,
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

/// A `:tool` segment this build does not know (an old deep link). Rather than
/// an error page, the six real tools — one tap to where the user was going.
class _UnknownTool extends StatelessWidget {
  const _UnknownTool({required this.onOpen});

  final ValueChanged<StudyTool> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AllInSpace.lg,
        AllInSpace.md,
        AllInSpace.lg,
        AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Text(
          "That tool isn't in this version — here are the ones that are.",
          style: AllInText.body(15, color: c.textMuted, height: 1.5),
        ),
        const SizedBox(height: AllInSpace.lg),
        ToolsGrid(onOpen: onOpen),
      ],
    );
  }
}
