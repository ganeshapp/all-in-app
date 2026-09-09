/// H1 (the coach's note detail) and H2 (the goal explainer) — DESIGN.md §3.3,
/// §3.4. Both are sheets, not routes (§16.1), opened with `AllInSheet.show`.
///
/// Both bodies are `ExplainerSheet`, which §10.5 defines as `CoachNoteView`
/// with no verdict header — the same anatomy, the same two disclosure labels,
/// the same order. H1 has no verdict to show (its subject is a pattern across
/// sessions, not one graded decision), so the header is exactly what it drops.
///
/// Both are presented on the **root** navigator. H1's buttons jump to another
/// tab, and a `StatefulShellRoute.indexedStack` mutes a hidden branch's
/// tickers: a sheet closing into a tab jump on the branch navigator would
/// freeze half-way through its exit and still be there on the way back. Above
/// the shell it always finishes — and the 40 % scrim covers the tab bar,
/// which is what §2.4 describes anyway.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/widgets.dart';
import '../../study/content/curriculum.dart';
import '../home_copy.dart';
import '../providers/coach_note_provider.dart';

/// H2 · the goal explainer (sheet S), with the verbatim desktop tooltip.
Future<void> showHomeGoalSheet(BuildContext context, WidgetRef ref) {
  final settings = ref.read(settingsProvider);
  return AllInSheet.show<void>(
    context,
    detent: AllInSheetDetent.s,
    useRootNavigator: true,
    reducedMotion: settings.reducedMotion,
    child: _SheetBody(
      child: ExplainerSheet(
        title: HomeCopy.goalSheetTitle,
        body: HomeCopy.goalSheetBody,
        math: HomeCopy.goalSheetMath,
        expert: HomeCopy.goalSheetExpert,
        alwaysExpandMath: settings.alwaysExpandMath,
        enableHaptics: settings.haptics,
        reducedMotion: settings.reducedMotion,
      ),
    ),
  );
}

/// What H1's footer buttons ask the screen to do — the sheet never navigates
/// itself, so one place decides where Home's taps go (§2.3).
enum CoachSheetAction { lesson, review }

/// H1 · the coach's note (sheet M): the same sentence as layer 1, the numbers
/// behind it, the rule that produced it, and up to two buttons (§3.4).
Future<CoachSheetAction?> showHomeCoachSheet(
  BuildContext context,
  WidgetRef ref, {
  required HomeCoachNote note,
}) {
  final settings = ref.read(settingsProvider);
  final lessonId = note.lessonId;
  final lesson = lessonId == null ? null : lessonById(lessonId);

  return AllInSheet.show<CoachSheetAction>(
    context,
    useRootNavigator: true,
    reducedMotion: settings.reducedMotion,
    // The builder gives the sheet's own context: with `useRootNavigator` the
    // presenting context's `Navigator.of` is the branch navigator, and popping
    // that would pop Home itself.
    builder: (sheetContext) {
      final buttons = <Widget>[
        if (lesson != null)
          AllInButton.secondary(
            label: lesson.title,
            leading: Icons.menu_book_rounded,
            expand: true,
            enableHaptics: settings.haptics,
            reducedMotion: settings.reducedMotion,
            onPressed:
                () => Navigator.of(sheetContext).pop(CoachSheetAction.lesson),
          ),
        if (note.dueSpots > 0)
          AllInButton.ghost(
            label: HomeCopy.reviewTheseSpots,
            expand: true,
            enableHaptics: settings.haptics,
            reducedMotion: settings.reducedMotion,
            onPressed:
                () => Navigator.of(sheetContext).pop(CoachSheetAction.review),
          ),
      ];

      return _SheetBody(
        child: ExplainerSheet(
          title: HomeCopy.coachSheetTitle,
          body: note.sentence,
          math: note.math,
          expert: note.expert,
          alwaysExpandMath: settings.alwaysExpandMath,
          enableHaptics: settings.haptics,
          reducedMotion: settings.reducedMotion,
          footer:
              buttons.isEmpty
                  ? null
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final b in buttons) ...[
                        b,
                        if (b != buttons.last)
                          const SizedBox(height: AllInSpace.sm),
                      ],
                    ],
                  ),
        ),
      );
    },
  );
}

/// `AllInSheet` draws no horizontal padding of its own (§10.1 chrome is the
/// grabber and the corners), so every Home sheet pads its own body.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AllInSpace.lg,
      AllInSpace.sm,
      AllInSpace.lg,
      AllInSpace.xl + MediaQuery.paddingOf(context).bottom,
    ),
    child: child,
  );
}
