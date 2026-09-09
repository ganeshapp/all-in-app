/// P2 · Session sheet (DESIGN.md §4.11) — sheet M with three segments:
///
/// * **Log** — this hand's engine log in full, the last 20 hands of the
///   session collapsed to 44 pt rows below it, and the "Earlier hands" row
///   that hands off to the Session tab;
/// * **Session** — the §4.13 stat tiles, the complete hand list and
///   "End session";
/// * **Options** — §4.6's pace, speed and switches, the two read-only
///   Seats / Antes rows and "End session".
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/hand_log_format.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/features/play/widgets/hand_note_sheet.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What P2 asks the table to do after it closes.
enum SessionSheetResult { endSession, openReview }

/// The three segments, by index.
abstract final class SessionSegment {
  static const int log = 0;
  static const int session = 1;
  static const int options = 2;
}

class SessionSheet extends ConsumerStatefulWidget {
  const SessionSheet({super.key, this.initialSegment, this.onReplay});

  /// Overrides the remembered segment (the ticker opens Log, the pace pill's
  /// long-press opens Options).
  final int? initialSegment;

  /// Push P11 for a finished hand of this session.
  final ValueChanged<int>? onReplay;

  /// Opens P2. Returns the action the table still has to perform.
  static Future<SessionSheetResult?> show(
    BuildContext context, {
    int? initialSegment,
    ValueChanged<int>? onReplay,
    bool reducedMotion = false,
    VoidCallback? onClose,
  }) => AllInSheet.show<SessionSheetResult>(
    context,
    detent: AllInSheetDetent.m,
    reducedMotion: reducedMotion,
    maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
    onClose: onClose,
    child: SessionSheet(initialSegment: initialSegment, onReplay: onReplay),
  );

  @override
  ConsumerState<SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<SessionSheet> {
  late int _segment =
      widget.initialSegment ?? ref.read(sessionSheetSegmentProvider);

  /// Only one collapsed hand is expanded at a time (§4.11).
  int? _expanded;

  void _select(int index) {
    setState(() => _segment = index);
    ref.read(sessionSheetSegmentProvider.notifier).select(index);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AllInSpace.lg,
            0,
            AllInSpace.lg,
            AllInSpace.md,
          ),
          child: AllInSegmented(
            labels: PlayCopy.sessionSegments,
            value: _segment,
            semanticLabel: 'Session sheet',
            onChanged: _select,
          ),
        ),
        Flexible(
          child: switch (_segment) {
            SessionSegment.session => _SessionTab(
              session: session,
              onReplay: widget.onReplay,
              onEnd: _end,
            ),
            SessionSegment.options => _OptionsTab(
              session: session,
              settings: ref.watch(settingsProvider),
              onEnd: _end,
            ),
            _ => _LogTab(
              session: session,
              expanded: _expanded,
              onExpand:
                  (n) => setState(() => _expanded = _expanded == n ? null : n),
              onEarlier: () => _select(SessionSegment.session),
              onNote: (r) => Navigator.of(context).pop(r),
            ),
          },
        ),
      ],
    );
  }

  void _end() => Navigator.of(context).pop(SessionSheetResult.endSession);
}

/* ------------------------------------------------------------------- Log */

/// One hand's slice of the engine log. The engine writes a `deal` entry
/// "Hand #N · blinds …" at the top of every hand, which is the split point.
class LogHand {
  const LogHand({required this.number, required this.entries});

  final int number;
  final List<LogEntry> entries;
}

List<LogHand> splitLog(List<LogEntry> log) {
  final hands = <LogHand>[];
  var current = <LogEntry>[];
  var number = 0;
  for (final entry in log) {
    if (entry.kind == LogKind.deal && entry.text.startsWith('Hand #')) {
      if (current.isNotEmpty) {
        hands.add(LogHand(number: number, entries: current));
      }
      current = <LogEntry>[];
      number =
          int.tryParse(
            entry.text.substring(6).split(' ').first.replaceAll('·', ''),
          ) ??
          number + 1;
    }
    current.add(entry);
  }
  if (current.isNotEmpty) hands.add(LogHand(number: number, entries: current));
  return hands;
}

class _LogTab extends StatelessWidget {
  const _LogTab({
    required this.session,
    required this.expanded,
    required this.onExpand,
    required this.onEarlier,
    required this.onNote,
  });

  final SessionState session;
  final int? expanded;
  final ValueChanged<int> onExpand;
  final VoidCallback onEarlier;
  final ValueChanged<SessionSheetResult> onNote;

  /// §4.11: "the list is capped at 20".
  static const int collapsedCap = 20;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final table = session.table;
    final hands = table == null ? <LogHand>[] : splitLog(table.log);
    final current = hands.isEmpty ? null : hands.last;
    final previous =
        hands.length < 2
            ? <LogHand>[]
            : hands.sublist(0, hands.length - 1).reversed.toList();
    final shown = previous.take(collapsedCap).toList();

    if (current == null || current.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AllInSpace.xl),
        child: Text(
          PlayCopy.tickerEmpty,
          textAlign: TextAlign.center,
          style: AllInText.body(14, color: c.textMuted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onLongPress: () => _copy(context, current, session.bigBlind),
            child: Eyebrow('HAND #${current.number}'),
          ),
          for (final entry in current.entries)
            _LogLine(line: HandLog.line(entry, bigBlind: session.bigBlind)),
          for (final review in session.reviewLog)
            _NoteRow(
              review: review,
              onTap: () => onNote(SessionSheetResult.openReview),
            ),
          for (final hand in shown)
            _CollapsedHand(
              hand: hand,
              bigBlind: session.bigBlind,
              netBb: _netFor(hand.number),
              expanded: expanded == hand.number,
              onTap: () => onExpand(hand.number),
              onLongPress: () => _copy(context, hand, session.bigBlind),
            ),
          if (previous.length > collapsedCap)
            Semantics(
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEarlier,
                  child: SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        PlayCopy.earlierHands,
                        style: AllInText.body(14, color: c.gold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double? _netFor(int number) {
    for (final h in session.history) {
      if (h.id == number) return h.heroNet / session.bigBlind;
    }
    return null;
  }

  void _copy(BuildContext context, LogHand hand, int bigBlind) {
    Clipboard.setData(
      ClipboardData(
        text: HandLog.clipboardText(hand.entries, bigBlind: bigBlind),
      ),
    );
    AllInToast.show(context, PlayCopy.handLogCopied);
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.line});

  /// Already rewritten for the phone — second person, big blinds.
  final HandLogLine line;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          line.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AllInText.body(
            14,
            color:
                line.isHero
                    ? context.colors.text
                    : Ticker.colorFor(context, line.kind),
          ),
        ),
      ),
    );
  }
}

/// A coach note, interleaved into the log as a badge row → P3 (§4.11).
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.review, required this.onTap});

  final CoachReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                VerdictDisc(verdict: review.verdict, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${CoachChip.verdictLabel(review.verdict)} · '
                    '${review.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AllInText.body(14, color: c.text),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedHand extends StatelessWidget {
  const _CollapsedHand({
    required this.hand,
    required this.bigBlind,
    required this.netBb,
    required this.expanded,
    required this.onTap,
    required this.onLongPress,
  });

  final LogHand hand;
  final int bigBlind;
  final double? netBb;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final net = netBb == null ? '' : ' (${fmtSigned(netBb!)} bb)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.arrow_drop_down
                          : Icons.arrow_right_rounded,
                      size: 20,
                      color: c.textMuted,
                    ),
                    Expanded(
                      child: Text(
                        'Hand #${hand.number}$net',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AllInText.body(14, color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: AllInSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in hand.entries)
                  _LogLine(line: HandLog.line(entry, bigBlind: bigBlind)),
              ],
            ),
          ),
      ],
    );
  }
}

/* --------------------------------------------------------------- Session */

class _SessionTab extends ConsumerWidget {
  const _SessionTab({
    required this.session,
    required this.onReplay,
    required this.onEnd,
  });

  final SessionState session;
  final ValueChanged<int>? onReplay;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hero = session.table?.players[0];
    final seen = hero?.handsSeen ?? 0;
    final enoughStyle = hero != null && seen >= SeatPlate.minSample;
    final style =
        enoughStyle
            ? '${(hero.vpipCount / seen * 100).round()}/'
                '${(hero.pfrCount / seen * 100).round()} · ${seen}h'
            : '—';
    final notes = ref.watch(playNotesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Hands',
                  value: '${session.counters.hands}',
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: 'Net',
                  value: '${fmtSigned(session.netBb)} bb',
                  tone: StatTone.money(session.netBb),
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.sm),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'bb / 100',
                  value: fmtSigned(session.bb100),
                  // The same signed money quantity as NET beside it, so it
                  // follows the same colour rule (§13 / principle 8).
                  tone: StatTone.money(session.bb100),
                  infoSemanticLabel: 'What bb per 100 means',
                  onInfo:
                      () => _explain(
                        context,
                        ref,
                        'bb / 100',
                        PlayCopy.bb100Tooltip,
                      ),
                ),
              ),
              const SizedBox(width: AllInSpace.sm),
              Expanded(
                child: StatTile(
                  label: 'Your style',
                  value: style,
                  // Before the sample is big enough the em dash is "no data
                  // yet", not a reading — it says so in the colour too, like
                  // the P6 VPIP/PFR tiles it mirrors.
                  tone: enoughStyle ? StatTone.neutral : StatTone.muted,
                  infoSemanticLabel: 'What VPIP and PFR mean',
                  onInfo:
                      () => _explain(
                        context,
                        ref,
                        'Your VPIP / PFR',
                        PlayCopy.yourStyleTooltip,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AllInSpace.lg),
          Eyebrow('HANDS THIS SESSION (${session.history.length})'),
          if (session.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AllInSpace.md),
              child: Text(
                PlayCopy.tickerEmpty,
                style: AllInText.body(13, color: c.textMuted),
              ),
            ),
          for (final hand in session.history.reversed)
            _HandRow(
              number: hand.id,
              startedAt: hand.startedAt,
              // A net amount alone does not identify a hand, so after 60 of
              // them there is no way to find the one you want to re-examine
              // without opening them one at a time. The hero's cards do.
              heroCards: hand.holes[0],
              netBb: hand.heroNet / session.bigBlind,
              // The coach's own verdict for the hand, so the list you scan
              // after a session shows where the mistakes were (§4.13).
              verdict: session.handVerdicts[hand.startedAt],
              hasNote: (notes.noteFor(hand.startedAt)?.note ?? '').isNotEmpty,
              onReplay:
                  onReplay == null ? null : () => onReplay!(hand.startedAt),
              onNote:
                  () => HandNoteSheet.show(context, startedAt: hand.startedAt),
            ),
          const SizedBox(height: AllInSpace.lg),
          AllInButton.danger(
            label: PlayCopy.endSession,
            expand: true,
            onPressed: onEnd,
          ),
        ],
      ),
    );
  }

  void _explain(
    BuildContext context,
    WidgetRef ref,
    String title,
    String body,
  ) {
    AllInSheet.show<void>(
      context,
      detent: AllInSheetDetent.s,
      reducedMotion: ref.read(reducedMotionProvider),
      maxHeightFraction: AllInSheet.tableMaxHeightFraction(context),
      child: ExplainerSheet(title: title, body: body),
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({
    required this.number,
    required this.startedAt,
    required this.heroCards,
    required this.netBb,
    required this.hasNote,
    required this.onReplay,
    required this.onNote,
    this.verdict,
  });

  final int number;
  final int startedAt;

  /// The hero's two cards, or null on a hand that was never dealt to them.
  final List<String>? heroCards;
  final double netBb;

  /// The worst verdict the coach gave in this hand, or null when it had
  /// nothing to flag.
  final Verdict? verdict;
  final bool hasNote;
  final VoidCallback? onReplay;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('#$number', style: AllInText.mono(14, color: c.text)),
          ),
          SizedBox(
            width: 64,
            child: Text(
              prettyHoleCards(heroCards),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AllInText.mono(13, color: c.textMuted),
            ),
          ),
          // §16.5's verdict colours as an 8 pt dot: the row keeps its 52 pt
          // rhythm and a scan down the list finds the flagged hands.
          VerdictDot(verdict: verdict),
          Expanded(
            child: Text(
              '${fmtSigned(netBb)} bb',
              textAlign: TextAlign.right,
              style: AllInText.mono(14, color: c.money(netBb)),
            ),
          ),
          const SizedBox(width: AllInSpace.sm),
          Semantics(
            button: true,
            label: 'Replay hand $number',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AllInRadius.md),
                  onTap: onReplay,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: onReplay == null ? c.textFaint : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Note on hand $number',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AllInRadius.md),
                  onTap: onNote,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: hasNote ? c.gold : c.textMuted,
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

/* --------------------------------------------------------------- Options */

class _OptionsTab extends ConsumerWidget {
  const _OptionsTab({
    required this.session,
    required this.settings,
    required this.onEnd,
  });

  final SessionState session;
  final AppSettings settings;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final notifier = ref.read(sessionProvider.notifier);
    final auto = settings.paceMode == PaceMode.auto;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AllInSpace.lg,
        0,
        AllInSpace.lg,
        AllInSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('PACE'),
          const SizedBox(height: AllInSpace.sm),
          AllInSegmented(
            labels: const ['Step', 'Auto'],
            value: auto ? 1 : 0,
            semanticLabel: 'Pace',
            onChanged:
                (i) =>
                    notifier.setPace(i == 1 ? PaceMode.auto : PaceMode.manual),
          ),
          const SizedBox(height: AllInSpace.xs),
          Text(
            auto ? PlayCopy.paceAutoHelp : PlayCopy.paceManualHelp,
            style: AllInText.body(13, color: c.textMuted),
          ),
          if (auto) ...[
            const SizedBox(height: AllInSpace.md),
            AllInSegmented(
              labels: PlayCopy.speedLabels,
              value: PaceSpeed.all.indexOf(settings.speedMs).clamp(0, 2),
              semanticLabel: 'Speed',
              onChanged: (i) => notifier.setSpeed(PaceSpeed.all[i]),
            ),
          ],
          const SizedBox(height: AllInSpace.lg),
          _SwitchRow(
            label: PlayCopy.evCoachRow,
            value: settings.coachEnabled,
            onChanged: notifier.setCoachEnabled,
          ),
          _SwitchRow(
            label: PlayCopy.autoDealRow,
            value: settings.autoDeal,
            onChanged: notifier.setAutoDeal,
          ),
          _SwitchRow(
            label: PlayCopy.realisticRevealsRow,
            value: settings.realisticReveal,
            onChanged:
                (v) => ref
                    .read(settingsProvider.notifier)
                    .update(realisticReveal: v),
          ),
          _SwitchRow(
            label: PlayCopy.fourColorDeckRow,
            value: settings.fourColorDeck,
            onChanged:
                (v) => ref
                    .read(settingsProvider.notifier)
                    .update(fourColorDeck: v),
          ),
          const SizedBox(height: AllInSpace.md),
          _ReadOnlyRow(
            label: 'Seats',
            value: session.options.seatsLabel,
            caption: PlayCopy.endsThisSessionFirst,
          ),
          _ReadOnlyRow(
            label: 'Antes',
            value: session.options.ante > 0 ? '0.25 bb' : 'none',
            caption: PlayCopy.endsThisSessionFirst,
          ),
          const SizedBox(height: AllInSpace.lg),
          AllInButton.danger(
            label: PlayCopy.endSession,
            expand: true,
            onPressed: onEnd,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AllInText.body(15, color: context.colors.text),
          ),
        ),
        AllInSwitch(value: value, semanticLabel: label, onChanged: onChanged),
      ],
    ),
  );
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: 0.40,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label — $value',
                style: AllInText.body(15, color: c.text),
              ),
            ),
            Text(caption, style: AllInText.body(12, color: c.textFaint)),
          ],
        ),
      ),
    );
  }
}
