/// The two pieces every Stats card is made of: a section card with an eyebrow
/// header (§7.1's stack of cards) and the T1 explainer presenter every ⓘ and
/// dotted label opens (§7.2).
///
/// §7.2 is categorical about the explainer: **both disclosure rows render,
/// always**, even when there is nothing behind them — [ExplainerSheet] already
/// does that, so this file only decides what goes into it and how it is
/// presented (sheet S, §2.2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';

/// A titled card: eyebrow, optional trailing action, then [child].
class StatsSection extends StatelessWidget {
  const StatsSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.onInfo,
    this.infoLabel,
    this.padding = const EdgeInsets.all(AllInSpace.lg),
  });

  final String title;
  final Widget child;

  /// A button on the header's right ("Import", "All hands ›").
  final Widget? action;

  /// Renders a 44 pt ⓘ beside the title when set (§7.2).
  final VoidCallback? onInfo;
  final String? infoLabel;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AllInCard.plain(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(child: Eyebrow(title)),
              if (onInfo != null)
                InfoButton(
                  onPressed: onInfo!,
                  semanticLabel: infoLabel ?? 'About $title',
                ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AllInSpace.md),
          child,
        ],
      ),
    );
  }
}

/// The 44 pt ⓘ target used by section headers and stat rows.
class InfoButton extends StatelessWidget {
  const InfoButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
  });

  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: const Icon(Icons.info_outline),
            color: context.colors.textFaint,
            onPressed: onPressed,
            tooltip: semanticLabel,
          ),
        ),
      ),
    );
  }
}

/// A dotted-underlined stat label that opens T1 (§7.4 style numbers).
class DottedStatRow extends StatelessWidget {
  const DottedStatRow({
    super.key,
    required this.label,
    required this.value,
    required this.onExplain,
  });

  final String label;

  /// Always mono — every changing number is mono (§16.5).
  final String value;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$label, $value',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onExplain,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AllInText.body(14, color: c.text).copyWith(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: c.textFaint,
                    ),
                  ),
                ),
                const SizedBox(width: AllInSpace.sm),
                Text(value, style: AllInText.mono(15, color: c.text)),
                const SizedBox(width: AllInSpace.xs),
                Icon(Icons.info_outline, size: 14, color: c.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents an explainer as a sheet S (§2.2 T1). One entry point so every ⓘ
/// in Stats behaves identically.
Future<void> showStatsExplainer(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  String? math,
  String? expert,
  Widget? footer,
  Widget? mathExtra,
}) {
  final settings = ref.read(settingsProvider);
  return AllInSheet.show<void>(
    context,
    detent: AllInSheetDetent.s,
    reducedMotion: settings.reducedMotion,
    builder:
        (sheetContext) => SingleChildScrollView(
          child: ExplainerSheet(
            title: title,
            body: body,
            math: math,
            expert: expert,
            footer: footer,
            mathExtra: mathExtra,
            alwaysExpandMath: settings.alwaysExpandMath,
            enableHaptics: settings.haptics,
            reducedMotion: settings.reducedMotion,
          ),
        ),
  );
}
