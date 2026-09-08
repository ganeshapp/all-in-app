/// `Ticker` — the 18 pt line under the top bar carrying the newest engine log
/// entry (DESIGN.md §10.3; behaviour and colours §4.2).
///
/// Tap → P2 Log. Long-press → copy the hand log. Empty at the very first deal:
/// "Actions will appear here." *(desktop)*.
library;

import 'package:flutter/material.dart';

import '../../engine/types.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class Ticker extends StatelessWidget {
  const Ticker({
    super.key,
    this.entry,
    this.onTap,
    this.onLongPress,
    this.emptyText = 'Actions will appear here.',
  });

  /// The newest `log` line; null renders [emptyText].
  final LogEntry? entry;

  /// Tap → P2 Log at L.
  final VoidCallback? onTap;

  /// Long-press → copies the hand's log ("Hand log copied" toast).
  final VoidCallback? onLongPress;
  final String emptyText;

  static const double height = 18;

  /// Result gold-light · deal info · action muted · info faint (§4.2).
  static Color colorFor(BuildContext context, LogKind kind) {
    final c = context.colors;
    return switch (kind) {
      LogKind.result => c.goldLight,
      LogKind.deal => c.info,
      LogKind.action => c.textMuted,
      LogKind.info => c.textFaint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = entry?.text ?? emptyText;
    final color = entry == null ? c.textFaint : colorFor(context, entry!.kind);

    return Semantics(
      liveRegion: true,
      label: text,
      button: onTap != null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: Ticker.height,
            width: double.infinity,
            child: MediaQuery.withClampedTextScaling(
              // §4.2.4: felt-adjacent text stops scaling at 1.15×.
              maxScaleFactor: 1.15,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AllInText.body(13, color: color, height: 1.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
