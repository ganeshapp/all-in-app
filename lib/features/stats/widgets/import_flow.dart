/// T3 · Import hands — the sheets of DESIGN.md §7.8.
///
/// The *work* is [ImportNotifier]; this file is the presentation contract:
///
/// 1. picker (the notifier opens it) — cancel shows nothing at all;
/// 2. a progress sheet S, non-dismissable while parsing, with a determinate
///    bar, a real "Reviewing your calls… 12 of 40" count, "Cancel", and
///    "Continue in the background" — dismissing it leaves the import running
///    and a toast lands when it finishes;
/// 3. a result sheet S with the verbatim summary and "See hands" /
///    "Review now" / "Done";
/// 4. one failure sheet per §14 file row: no hands, unreadable, too large.
///
/// [ImportFlowController] is what the screens hold: T0 and T2 both mount one,
/// hand it their navigation callbacks, and call [ImportFlowController.start].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/data_actions.dart';
import '../providers/import_provider.dart';
import '../stats_copy.dart';

/// Drives the §7.8 sheets from a screen's `State`.
///
/// A screen creates one in `initState`, calls [attach] with a
/// `ref.listen(importProvider, …)` handler, and disposes it. It is a plain
/// object rather than a widget because both T0 and T2 host the same flow from
/// different places in the tree.
class ImportFlowController {
  ImportFlowController({
    required this.ref,
    required this.onSeeHands,
    required this.onReviewNow,
  });

  final WidgetRef ref;

  /// "See hands" → T2 filtered to Imported.
  final VoidCallback onSeeHands;

  /// "Review now" → Drills Review (only when leaks were added).
  final VoidCallback onReviewNow;

  /// True while the progress sheet is on screen.
  bool _sheetOpen = false;

  /// True once "Continue in the background" was pressed: the result then
  /// arrives as a toast rather than re-opening a sheet the user dismissed.
  bool _backgrounded = false;

  /// One result per run.
  bool _resultShown = false;

  /// §7.8 step 1. Opens the picker; everything after is driven by [handle].
  Future<void> start(BuildContext context) async {
    final notifier = ref.read(importProvider.notifier);
    if (ref.read(importProvider).isRunning) {
      // A run is already going: bring its sheet back rather than starting a
      // second one.
      if (!_sheetOpen) {
        _backgrounded = false;
        await _showProgress(context);
      }
      return;
    }
    notifier.dismiss();
    _resultShown = false;
    _backgrounded = false;
    // The picker resolves before any parsing begins, so the sheet is opened
    // by the first `reading` state, not here.
    await notifier.pickAndImport();
  }

  /// The `ref.listen` body. [previous] may be null on the first delivery.
  void handle(BuildContext context, ImportState? previous, ImportState next) {
    if (next.isRunning) {
      // Only auto-open on the transition into a run; a user who sent the
      // sheet to the background keeps it there.
      if (!_sheetOpen &&
          !_backgrounded &&
          (previous == null || !previous.isRunning)) {
        _showProgress(context);
      }
      return;
    }
    if (next.phase == ImportPhase.done || next.phase == ImportPhase.failed) {
      // The progress sheet pops itself on the same state change; its own
      // continuation shows the result so the two sheets never overlap.
      if (!_sheetOpen) _finish(context, next);
    }
  }

  Future<void> _showProgress(BuildContext context) async {
    _sheetOpen = true;
    final settings = ref.read(settingsProvider);
    await AllInSheet.show<void>(
      context,
      detent: AllInSheetDetent.s,
      dismissible: false,
      showGrabber: false,
      reducedMotion: settings.reducedMotion,
      builder:
          (sheetContext) => _ImportProgressSheet(
            onBackground: () {
              _backgrounded = true;
              Navigator.of(sheetContext).pop();
            },
            onCancel: () {
              ref.read(importProvider.notifier).cancel();
              Navigator.of(sheetContext).pop();
            },
          ),
    );
    _sheetOpen = false;
    if (!context.mounted) return;
    // A run that finished while the sheet was closing still owes its result.
    final state = ref.read(importProvider);
    if (!state.isRunning) _finish(context, state);
  }

  void _finish(BuildContext context, ImportState state) {
    if (_resultShown) return;
    _resultShown = true;

    if (state.phase == ImportPhase.failed &&
        state.failure == ImportFailure.cancelled) {
      ref.read(importProvider.notifier).dismiss();
      AllInToast.show(context, StatsCopy.importCancelled);
      return;
    }

    final settings = ref.read(settingsProvider);

    if (state.phase == ImportPhase.done) {
      if (_backgrounded) {
        // §7.8 step 2: dismissed to the background — a toast when it is done.
        ref.read(importProvider.notifier).dismiss();
        AllInToast.show(
          context,
          StatsCopy.importFinishedToast(state.hands),
          reducedMotion: settings.reducedMotion,
        );
        return;
      }
      final summary = state.summary ?? '';
      final leaks = state.leaks;
      AllInSheet.show<void>(
        context,
        detent: AllInSheetDetent.s,
        reducedMotion: settings.reducedMotion,
        builder:
            (sheetContext) => _ImportResultSheet(
              summary: summary,
              leaks: leaks,
              onSeeHands: () {
                Navigator.of(sheetContext).pop();
                onSeeHands();
              },
              onReviewNow: () {
                Navigator.of(sheetContext).pop();
                onReviewNow();
              },
            ),
      ).whenComplete(() => ref.read(importProvider.notifier).dismiss());
      return;
    }

    AllInSheet.show<void>(
      context,
      detent: AllInSheetDetent.s,
      reducedMotion: settings.reducedMotion,
      builder:
          (sheetContext) => _ImportFailureSheet(
            failure: state.failure ?? ImportFailure.noHands,
            onExportSample:
                () => ref.read(statsDataActionsProvider).shareSampleHistory(),
          ),
    ).whenComplete(() => ref.read(importProvider.notifier).dismiss());
  }
}

class _ImportProgressSheet extends ConsumerWidget {
  const _ImportProgressSheet({
    required this.onBackground,
    required this.onCancel,
  });

  final VoidCallback onBackground;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(importProvider);
    // The run finished under the sheet: close it so the result sheet (or the
    // failure sheet) is the only thing the user is left looking at.
    if (!state.isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isCurrent) Navigator.of(context).pop();
      });
    }
    final analysing = state.phase == ImportPhase.analysing;
    final headline =
        analysing
            ? StatsCopy.importReviewing(state.analysedHands, state.totalHands)
            : StatsCopy.importReading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          StatsCopy.importTitle,
          style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
        ),
        const SizedBox(height: AllInSpace.md),
        Text(headline, style: AllInText.body(15, color: c.textMuted)),
        const SizedBox(height: AllInSpace.sm),
        ProgressBarThin(
          value: state.progress ?? 0,
          height: 6,
          semanticLabel: headline,
        ),
        if (state.fileName != null) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(
            state.fileName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AllInText.mono(12, color: c.textFaint),
          ),
        ],
        const SizedBox(height: AllInSpace.lg),
        AllInButton.ghost(
          label: StatsCopy.importContinue,
          expand: true,
          onPressed: onBackground,
        ),
        const SizedBox(height: AllInSpace.sm),
        AllInButton.ghost(
          label: StatsCopy.importCancel,
          expand: true,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _ImportResultSheet extends StatelessWidget {
  const _ImportResultSheet({
    required this.summary,
    required this.leaks,
    required this.onSeeHands,
    required this.onReviewNow,
  });

  final String summary;
  final int leaks;
  final VoidCallback onSeeHands;
  final VoidCallback onReviewNow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          StatsCopy.importTitle,
          style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
        ),
        const SizedBox(height: AllInSpace.md),
        Text(summary, style: AllInText.body(15, color: c.text, height: 1.5)),
        const SizedBox(height: AllInSpace.lg),
        AllInButton.secondary(
          label: StatsCopy.importSeeHands,
          expand: true,
          onPressed: onSeeHands,
        ),
        if (leaks > 0) ...[
          const SizedBox(height: AllInSpace.sm),
          AllInButton.secondary(
            label: StatsCopy.importReviewNow,
            expand: true,
            onPressed: onReviewNow,
          ),
        ],
        const SizedBox(height: AllInSpace.sm),
        AllInButton.ghost(
          label: StatsCopy.importDone,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ImportFailureSheet extends StatelessWidget {
  const _ImportFailureSheet({
    required this.failure,
    required this.onExportSample,
  });

  final ImportFailure failure;
  final VoidCallback onExportSample;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (String title, String body) = switch (failure) {
      ImportFailure.unreadable => (
        StatsCopy.fileUnreadableTitle,
        StatsCopy.fileUnreadable,
      ),
      ImportFailure.tooLarge => (
        StatsCopy.fileTooLargeTitle,
        StatsCopy.fileTooLarge,
      ),
      _ => (StatsCopy.importTitle, StatsCopy.importNoHands),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AllInText.body(17, weight: FontWeight.w600, color: c.text),
        ),
        const SizedBox(height: AllInSpace.md),
        Text(body, style: AllInText.body(15, color: c.text, height: 1.5)),
        const SizedBox(height: AllInSpace.lg),
        if (failure == ImportFailure.noHands) ...[
          AllInButton.secondary(
            label: StatsCopy.importExportSample,
            expand: true,
            onPressed: onExportSample,
          ),
          const SizedBox(height: AllInSpace.sm),
        ],
        AllInButton.ghost(
          label: StatsCopy.importOk,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The banner T0 and T2 show above their lists after an import, so the
/// summary stays readable after the sheet is gone (the desktop keeps it until
/// the next import, §11.5).
class ImportBanner extends StatelessWidget {
  const ImportBanner({super.key, required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard.info(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.md,
        AllInSpace.sm,
        AllInSpace.sm,
        AllInSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: AllInText.body(12, color: c.info, height: 1.5),
            ),
          ),
          InfoDismissButton(onPressed: onClose),
        ],
      ),
    );
  }
}

/// The banner's ✕ — 44 pt like every other target (§12).
class InfoDismissButton extends StatelessWidget {
  const InfoDismissButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Dismiss',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            onPressed: onPressed,
            icon: Icon(Icons.close, color: c.textFaint),
            tooltip: 'Dismiss',
          ),
        ),
      ),
    );
  }
}
