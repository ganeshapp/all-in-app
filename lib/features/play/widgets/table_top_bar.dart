/// The table's 44 pt top bar (DESIGN.md §4.2): `‹` · "Hand #12 · +4.5 bb" ·
/// the coach badge · the pace pill.
///
/// The title truncates to "#12 · +4.5" at 360 (§4.2); the badge is hidden when
/// the coach is off; the pace pill toggles on tap and opens P2 Options on a
/// long-press (§4.6).
library;

import 'package:allin/engine/format.dart';
import 'package:allin/engine/coach.dart';
import 'package:allin/features/play/widgets/play_copy.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

class TableTopBar extends StatelessWidget {
  const TableTopBar({
    super.key,
    required this.handNumber,
    required this.netBb,
    required this.paceMode,
    required this.compact,
    this.coachCount = 0,
    this.coachVerdict,
    this.showCoach = true,
    this.pulseBadge = false,
    this.reducedMotion = false,
    this.onBack,
    this.onTitle,
    this.onCoach,
    this.onPaceToggle,
    this.onPaceLongPress,
  });

  final int handNumber;
  final double netBb;
  final PaceMode paceMode;

  /// 360-class width: the title drops the words (§4.2).
  final bool compact;

  /// Notes this hand.
  final int coachCount;
  final Verdict? coachVerdict;

  /// The EV Coach setting — off hides the badge entirely (§14).
  final bool showCoach;

  /// §4.8: a blocking verdict queued behind an open sheet pulses the badge.
  final bool pulseBadge;
  final bool reducedMotion;

  final VoidCallback? onBack;
  final VoidCallback? onTitle;
  final VoidCallback? onCoach;
  final VoidCallback? onPaceToggle;
  final VoidCallback? onPaceLongPress;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final signed = fmtSigned(netBb);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Leave table',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AllInRadius.md),
                  onTap: onBack,
                  child: Icon(Icons.chevron_left, size: 26, color: c.text),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Hand $handNumber, $signed big blinds. Session',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AllInRadius.md),
                  onTap: onTitle,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  compact
                                      ? '#$handNumber · '
                                      : 'Hand #$handNumber · ',
                              style: AllInText.body(
                                15,
                                weight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                            TextSpan(
                              text: compact ? signed : '$signed bb',
                              style: AllInText.mono(
                                15,
                                color: netBb >= 0 ? c.good : c.bad,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showCoach)
            CoachBadge(
              count: coachCount,
              verdict: coachVerdict,
              pulse: pulseBadge,
              reducedMotion: reducedMotion,
              onTap: onCoach,
            ),
          _PacePill(
            mode: paceMode,
            onTap: onPaceToggle,
            onLongPress: onPaceLongPress,
          ),
        ],
      ),
    );
  }

  /// `title` is exposed so tests and the semantics tree agree on the string.
  static String titleFor(int handNumber, double netBb, {bool compact = false}) {
    final signed = fmtSigned(netBb);
    return compact
        ? '#$handNumber · $signed'
        : 'Hand #$handNumber · $signed bb';
  }
}

/// "▶ Step" / "▶▶ Auto" — 64×36 inside a 44 pt hit box (§4.2).
class _PacePill extends StatelessWidget {
  const _PacePill({required this.mode, this.onTap, this.onLongPress});

  final PaceMode mode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auto = mode == PaceMode.auto;
    final label = auto ? 'Auto' : 'Step';

    return Semantics(
      button: true,
      label: 'Pace, $label',
      child: SizedBox(
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AllInRadius.pill),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Center(
              // 64×36 is the §4.2 size; the box grows rather than clipping
              // when the label is wider (large text, a localised string).
              child: Container(
                constraints: const BoxConstraints(minWidth: 64, maxWidth: 96),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: c.ink700,
                  borderRadius: BorderRadius.circular(AllInRadius.pill),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      auto ? Icons.fast_forward_rounded : Icons.play_arrow,
                      size: 14,
                      color: c.gold,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AllInText.body(13, color: c.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The persistent §14 ticker line when a snapshot write has failed.
String? tickerOverrideFor({required bool saveFailed, required bool paused}) {
  if (saveFailed) return PlayCopy.cantSave;
  if (paused) return PlayCopy.pausedTapToContinue;
  return null;
}
