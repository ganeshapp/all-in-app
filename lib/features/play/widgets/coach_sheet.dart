/// P3 · the coach note as a bottom sheet, with P4 (the hand's notes) and P5
/// (the assumed range) inside it (DESIGN.md §4.8, §4.10).
///
/// One sheet, three pages, no sheet ever on top of another (§2.4): "View
/// range" **pushes** P5 inside this sheet and a notes row **replaces** the
/// sheet's content with the note. The transitions are the §11 slide-left /
/// slide-right, dropped to a crossfade under reduced motion.
///
/// **Seam.** The table opens whatever [coachSheetProvider] returns, falling
/// back to [defaultCoachSheet] (this file). The table's contract —
/// `setSurfaceOpen` around the sheet, `dismissReview()` after it closes,
/// blocking notes that cannot be scrimmed away — is enforced by
/// `AllInSheet.show`'s `blocking` flag here so an override cannot forget it.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/coach_copy.dart';
import 'package:allin/theme/motion.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which page of the sheet is showing (§4.8).
enum CoachSheetPage {
  /// P3 — the three-layer note.
  note,

  /// P4 — every note on this hand, newest first.
  notes,

  /// P5 — the assumed range the coach used.
  range,
}

/// What the table hands the sheet.
@immutable
class CoachSheetRequest {
  const CoachSheetRequest({
    required this.review,
    required this.bigBlind,
    required this.heroCards,
    this.alwaysExpandMath = false,
    this.reducedMotion = false,
    this.onViewRange,
    this.notes,
    this.handNumber,
    this.initialPage,
  });

  final CoachReview review;
  final int bigBlind;
  final List<String> heroCards;
  final bool alwaysExpandMath;
  final bool reducedMotion;

  /// Where "View range" goes when the note carries **no** range of its own.
  /// A note that has one shows P5 inside the sheet instead (§4.8: a sheet
  /// pushes inside itself, it never opens another surface), so the table's
  /// route-to-P7 callback is the fallback, not the default.
  final VoidCallback? onViewRange;

  /// P4's rows. Null reads the live `reviewLog` from the session, which is
  /// what the table wants; a host with its own history (the replayer, a test)
  /// passes it in.
  final List<CoachReview>? notes;

  /// "Coach notes · Hand #12". Null reads the live hand number.
  final int? handNumber;

  /// Forces the opening page. Null picks it the way §4.8 describes: the chip
  /// and the log open the note, the badge (whose chip has already folded away)
  /// opens the list when the hand has more than one note.
  final CoachSheetPage? initialPage;

  /// §4.8: a blocking note opens itself at M with no grabber, no scrim
  /// dismiss and no swipe-down; system back equals "Got it".
  bool get blocking => review.blocking;
}

typedef CoachSheetOpener =
    Future<void> Function(BuildContext context, CoachSheetRequest request);

/// Override to take over P3 (see the file docs).
final coachSheetProvider = Provider<CoachSheetOpener?>((ref) => null);

Future<void> defaultCoachSheet(
  BuildContext context,
  CoachSheetRequest request,
) => AllInSheet.show<void>(
  context,
  detent: AllInSheetDetent.m,
  maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
  blocking: request.blocking,
  dismissible: !request.blocking,
  showGrabber: !request.blocking,
  reducedMotion: request.reducedMotion,
  // The page pins its own footer ("View range" / "Got it"): at M, inside the
  // sheet's scroll view, the only way out of a blocking note was below the
  // fold until the user dragged the sheet to L (§1.1).
  scrollable: false,
  builder:
      (sheetContext) => CoachSheetBody(
        request: request,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
);

/// P4 straight away — the coach badge's own entry (§4.8). The hosting screen
/// still owns `setSurfaceOpen` / `dismissReview` around it.
Future<void> showCoachNotes(BuildContext context, CoachSheetRequest request) =>
    defaultCoachSheet(
      context,
      CoachSheetRequest(
        review: request.review,
        bigBlind: request.bigBlind,
        heroCards: request.heroCards,
        alwaysExpandMath: request.alwaysExpandMath,
        reducedMotion: request.reducedMotion,
        onViewRange: request.onViewRange,
        notes: request.notes,
        handNumber: request.handNumber,
        initialPage: CoachSheetPage.notes,
      ),
    );

/// The sheet's body: the page stack of §4.8. Public so a test (or another
/// host) can pump it without a sheet route around it.
class CoachSheetBody extends ConsumerStatefulWidget {
  const CoachSheetBody({
    super.key,
    required this.request,
    required this.onClose,
  });

  final CoachSheetRequest request;

  /// Dismisses the sheet — "Got it" on a blocking note, "Close" otherwise.
  final VoidCallback onClose;

  @override
  ConsumerState<CoachSheetBody> createState() => _CoachSheetBodyState();
}

class _CoachSheetBodyState extends ConsumerState<CoachSheetBody> {
  /// Null until the first build: the opening page is chosen from the live
  /// session, and `ref` may not be read before `initState` has returned.
  CoachSheetPage? _page;
  late CoachReview _review;

  /// The note was reached from P4, so its back chevron returns to the list.
  bool _fromList = false;

  /// Slide direction for the next transition (§11: push left, back right).
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _review = widget.request.review;
  }

  /// §4.8's two entries: the chip (a live note) opens P3; the badge — which is
  /// the only way in once the chip has folded away — opens P4 when the hand
  /// carries more than one note.
  CoachSheetPage _openingPage() {
    if (widget.request.blocking) return CoachSheetPage.note;
    if (_notes.length < 2) return CoachSheetPage.note;
    final live = ref.read(sessionProvider).activeReviewId;
    return live == null ? CoachSheetPage.notes : CoachSheetPage.note;
  }

  List<CoachReview> get _notes =>
      widget.request.notes ?? ref.watch(sessionProvider).reviewLog;

  int get _handNumber =>
      widget.request.handNumber ??
      ref.watch(sessionProvider.select((s) => s.table?.handNumber ?? 0));

  void _go(CoachSheetPage page, {bool forward = true, CoachReview? review}) {
    setState(() {
      _forward = forward;
      if (review != null) _review = review;
      _page = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_page == null) {
      _page = widget.request.initialPage ?? _openingPage();
      _fromList = _page == CoachSheetPage.notes;
    }
    final reduced =
        widget.request.reducedMotion || ref.watch(reducedMotionProvider);
    final duration = AllInMotion.of(
      context,
      AllInMotion.base,
      reduced: reduced,
    );
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AllInMotion.ease,
      switchOutCurve: AllInMotion.ease,
      layoutBuilder:
          (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, if (current != null) current],
          ),
      transitionBuilder: (child, animation) {
        if (reduced || duration == Duration.zero) {
          return FadeTransition(opacity: animation, child: child);
        }
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(_forward ? 0.15 : -0.15, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>('${_page!.name}-${_review.id}'),
        child: _body(reduced),
      ),
    );
  }

  Widget _body(bool reduced) {
    switch (_page!) {
      case CoachSheetPage.note:
        return _notePage(reduced);
      case CoachSheetPage.notes:
        return _notesPage(reduced);
      case CoachSheetPage.range:
        return _rangePage(reduced);
    }
  }

  /* ------------------------------------------------------------ P3 · note */

  /// §4.8: a bot read's layer 3 is the archetype blurb. `botMoveReview` does
  /// not carry one, so it is added here — a derived copy, never a mutation
  /// (the engine's objects are immutable by contract).
  CoachReview _withArchetypeBlurb(CoachReview r) {
    if (r.kind != ReviewKind.bot) return r;
    if (r.expert?.isNotEmpty ?? false) return r;
    final blurb =
        r.villainArchetype == null
            ? null
            : kArchetypes[r.villainArchetype]?.blurb;
    if (blurb == null) return r;
    return CoachReview(
      id: r.id,
      kind: r.kind,
      blocking: r.blocking,
      verdict: r.verdict,
      title: r.title,
      equity: r.equity,
      potOdds: r.potOdds,
      evChips: r.evChips,
      villainName: r.villainName,
      villainArchetype: r.villainArchetype,
      villainRange: r.villainRange,
      board: r.board,
      plain: r.plain,
      text: r.text,
      steps: r.steps,
      expert: <String>[blurb],
      opponents: r.opponents,
      multiway: r.multiway,
    );
  }

  Widget _notePage(bool reduced) {
    final request = widget.request;
    final haptics = ref.watch(hapticsEnabledProvider);
    final notes = _notes;
    final review = _withArchetypeBlurb(_review);
    final hasRange = _review.villainRange?.isNotEmpty ?? false;

    final note = CoachNoteView(
      review: review,
      bigBlind: request.bigBlind.toDouble(),
      blocking: request.blocking,
      readOnly: _fromList,
      heroCards: request.heroCards,
      alwaysExpandMath: request.alwaysExpandMath,
      enableHaptics: haptics,
      reducedMotion: reduced,
      pinnedFooter: true,
      cardBuilder:
          (context, card, width) => PlayingCardView(
            card: card,
            width: width,
            fourColorDeck: ref.watch(
              settingsProvider.select((s) => s.fourColorDeck),
            ),
          ),
      // §4.8: "View range" pushes P5 **inside** this sheet. A host's own
      // destination is only used when there is no range to show in place.
      onViewRange:
          hasRange ? () => _go(CoachSheetPage.range) : request.onViewRange,
      onDismiss: widget.onClose,
    );

    return _Page(
      footer: Builder(
        builder:
            (context) => note.footerButtons(context) ?? const SizedBox.shrink(),
      ),
      children: <Widget>[
        if (_fromList)
          _NavRow(
            label: CoachSheetCopy.notesTitle(_handNumber),
            leading: true,
            onTap:
                () => _go(
                  CoachSheetPage.notes,
                  forward: false,
                  review: request.review,
                ),
          )
        else if (!request.blocking && notes.length > 1)
          _NavRow(
            label: CoachSheetCopy.allNotes(notes.length),
            onTap: () {
              _fromList = true;
              _go(CoachSheetPage.notes);
            },
          ),
        note,
      ],
    );
  }

  /* ----------------------------------------------------------- P4 · notes */

  Widget _notesPage(bool reduced) {
    final notes = _notes;
    return _Page(
      children: <Widget>[
        CoachNotesList(
          reviews: notes,
          title: CoachSheetCopy.notesTitle(_handNumber),
          emptyText: CoachSheetCopy.noNotesYet,
          onTapNote: (review) {
            _fromList = true;
            _go(CoachSheetPage.note, review: review);
          },
        ),
        if (notes.isEmpty) ...<Widget>[
          const SizedBox(height: AllInSpace.md),
          AllInButton.ghost(
            label: CoachSheetCopy.close,
            expand: true,
            onPressed: widget.onClose,
            enableHaptics: ref.watch(hapticsEnabledProvider),
            reducedMotion: reduced,
          ),
        ],
      ],
    );
  }

  /* ----------------------------------------------------------- P5 · range */

  Widget _rangePage(bool reduced) {
    final c = context.colors;
    final range = <HandLabel>{...?_review.villainRange};
    final name = _review.villainName ?? 'Your opponent';

    return _Page(
      children: <Widget>[
        _NavRow(
          label: CoachSheetCopy.assumedRangeTitle(name),
          leading: true,
          semanticLabel: CoachSheetCopy.backToNote,
          onTap: () => _go(CoachSheetPage.note, forward: false),
        ),
        Text(
          CoachSheetCopy.assumedRangeBody,
          style: AllInText.body(13, color: c.textMuted, height: 1.4),
        ),
        const SizedBox(height: AllInSpace.md),
        LayoutBuilder(
          builder:
              (context, constraints) => Center(
                child: RangeMatrix.readOnly(
                  highlight: range,
                  width: constraints.maxWidth,
                  headerWidth: 18,
                  reducedMotion: reduced,
                  semanticLabel: CoachSheetCopy.assumedRangeTitle(name),
                ),
              ),
        ),
        const SizedBox(height: AllInSpace.md),
        CoachLegendRow(
          trailing: ComboCounter(
            combos: combosInSet(range),
            suffix: ' of all hands',
          ),
        ),
      ],
    );
  }
}

/// One page of the sheet. `AllInSheet` already scrolls its child (§10.1), so
/// every page is a plain `Column`.
/// One page of P3/P4/P5.
///
/// The sheet hands its box to this page (`scrollable: false`), so the page —
/// not the sheet — decides what scrolls. [footer] is **pinned** above the
/// bottom inset: §1.1 puts "Got it" in the bottom 160 pt, and as the last item
/// of the sheet's own scroll view it opened below the fold on every blocking
/// verdict — an extra drag on the most frequently repeated interruption in a
/// session. Same pattern as `FeedbackPanel`.
class _Page extends StatelessWidget {
  const _Page({required this.children, this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: SingleChildScrollView(
            primary: true,
            padding: EdgeInsets.fromLTRB(
              AllInSpace.lg,
              0,
              AllInSpace.lg,
              footer == null ? AllInSpace.xl + bottom : AllInSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AllInSpace.lg,
              0,
              AllInSpace.lg,
              AllInSpace.lg + bottom,
            ),
            child: footer,
          ),
      ],
    );
  }
}

/// The 44 pt row that moves between the sheet's pages: a back chevron on the
/// left when [leading], a disclosure chevron on the right otherwise.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.leading = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onTap;
  final bool leading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              children: <Widget>[
                if (leading)
                  Icon(Icons.chevron_left, size: 22, color: c.textMuted),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(
                      leading ? 17 : 14,
                      weight: leading ? FontWeight.w600 : FontWeight.w500,
                      color: leading ? c.text : c.goldLight,
                    ),
                  ),
                ),
                if (!leading)
                  Icon(Icons.chevron_right, size: 20, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `RangeLegend`'s three swatch pairs overflow a box under ≈ 302 pt (and any
/// box at 1.3× text), so every Play surface scrolls it horizontally until the
/// shared widget wraps. The counter keeps its intrinsic width.
class CoachLegendRow extends StatelessWidget {
  const CoachLegendRow({
    super.key,
    required this.trailing,
    this.mode = RangeLegendMode.kind,
  });

  final Widget trailing;
  final RangeLegendMode mode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Two `Flexible`s split the width in half, which clipped the compare
      // legend's third swatch ("Extr…") whenever the trailing count was wide.
      // `Wrap` gives the legend the width it needs and drops the count onto a
      // second line only when they genuinely do not both fit.
      return Wrap(
        spacing: AllInSpace.md,
        runSpacing: AllInSpace.xs,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            // Still scrollable as the last resort (360 at 1.3× text), but it
            // shrink-wraps whenever it fits, instead of taking half the row.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: RangeLegend(mode: mode),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: trailing,
          ),
        ],
      );
    },
  );
}
