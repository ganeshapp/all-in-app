/// S1 · Lesson reader (DESIGN.md §6.2). Two routes, one widget: the
/// study-branch push `/study/lesson/:id` and the root-level modal
/// `/lesson/:id`, which shows "Done" instead of the back chevron (§16.1).
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the reader was presented — it decides the leading control only.
enum LessonPresentation {
  /// `/study/lesson/:id` — back chevron.
  push,

  /// `/lesson/:id` — full-screen modal with "Done".
  modal,
}

class LessonReaderScreen extends ConsumerWidget {
  const LessonReaderScreen({
    super.key,
    required this.lessonId,
    this.presentation = LessonPresentation.push,
  });

  /// Lesson id from the path; an unknown id falls back to Study (§14).
  final String lessonId;

  final LessonPresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Lesson',
      body: Center(
        child: Text(
          'Coming in Study.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
