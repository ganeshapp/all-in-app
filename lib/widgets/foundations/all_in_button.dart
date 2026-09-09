/// `AllInButton` — the only button in the app (DESIGN.md §10.1).
///
/// Variants primary / secondary / outline / ghost / danger; sizes `sm` 36,
/// `md` 48, `lg` 56 — `sm` keeps a 44 pt hit target (§12). Press is a 0.97
/// scale over 120 ms with a commit haptic (§11); `busy` disables the button and
/// shows a spinner, which reduced motion replaces with the label alone (§11).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

enum AllInButtonVariant { primary, secondary, outline, ghost, danger }

enum AllInButtonSize { sm, md, lg }

class AllInButton extends StatefulWidget {
  const AllInButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AllInButtonVariant.primary,
    this.size = AllInButtonSize.md,
    this.leading,
    this.trailing,
    this.busy = false,
    this.expand = false,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  });

  const AllInButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AllInButtonSize.md,
    this.leading,
    this.trailing,
    this.busy = false,
    this.expand = false,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = AllInButtonVariant.primary;

  const AllInButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AllInButtonSize.md,
    this.leading,
    this.trailing,
    this.busy = false,
    this.expand = false,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = AllInButtonVariant.secondary;

  const AllInButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AllInButtonSize.md,
    this.leading,
    this.trailing,
    this.busy = false,
    this.expand = false,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = AllInButtonVariant.outline;

  const AllInButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AllInButtonSize.md,
    this.leading,
    this.trailing,
    this.busy = false,
    this.expand = false,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = AllInButtonVariant.ghost;

  const AllInButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AllInButtonSize.md,
    this.leading,
    this.trailing,
    this.busy = false,
    this.expand = false,
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : variant = AllInButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AllInButtonVariant variant;
  final AllInButtonSize size;

  /// Icon shown before / after the label (18 pt, tinted with the foreground).
  final IconData? leading;
  final IconData? trailing;

  /// Disables the button and shows the busy affordance.
  final bool busy;

  /// Stretch to the incoming width instead of hugging the label.
  final bool expand;
  final String? semanticLabel;
  final bool enableHaptics;
  final bool reducedMotion;

  /// Visual heights from §10.1. `sm` is 36 tall inside a 44 pt target.
  static double visualHeight(AllInButtonSize size) => switch (size) {
    AllInButtonSize.sm => 36,
    AllInButtonSize.md => 48,
    AllInButtonSize.lg => 56,
  };

  /// The tappable height — never below the §12 floor of 44.
  static double hitHeight(AllInButtonSize size) =>
      visualHeight(size) < 44 ? 44 : visualHeight(size);

  @override
  State<AllInButton> createState() => _AllInButtonState();
}

class _AllInButtonState extends State<AllInButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  void _commit() {
    if (!_enabled) return;
    if (widget.enableHaptics) {
      switch (widget.variant) {
        case AllInButtonVariant.primary:
        case AllInButtonVariant.secondary:
        case AllInButtonVariant.danger:
          HapticFeedback.mediumImpact();
        case AllInButtonVariant.outline:
        case AllInButtonVariant.ghost:
          HapticFeedback.lightImpact();
      }
    }
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced =
        widget.reducedMotion || MediaQuery.accessibleNavigationOf(context);
    final visual = AllInButton.visualHeight(widget.size);
    final hit = AllInButton.hitHeight(widget.size);

    final (Color fill, Color fg, Color? border) = switch (widget.variant) {
      // Gold is light in both themes, so the label is always the darkest ink
      // (matches `ColorScheme.onPrimary` in app_theme.dart) — §13 contrast.
      AllInButtonVariant.primary => (c.gold, AllInColors.dark.ink900, null),
      AllInButtonVariant.secondary => (c.ink600, c.text, null),
      AllInButtonVariant.outline => (Colors.transparent, c.text, c.lineStrong),
      AllInButtonVariant.ghost => (Colors.transparent, c.text, null),
      AllInButtonVariant.danger => (c.ink700, c.bad, c.bad),
    };

    final fontSize = switch (widget.size) {
      AllInButtonSize.sm => 14.0,
      AllInButtonSize.md => 15.0,
      AllInButtonSize.lg => 17.0,
    };
    // An `expand: true` button is sized by its parent, so this padding is only
    // breathing room around a centred label — it must not eat the width the
    // label needs (§4.5: "Raise to 7.5" is always the exact commit, never
    // "Raise to …").
    final pad =
        widget.expand
            ? AllInSpace.sm
            : switch (widget.size) {
              AllInButtonSize.sm => AllInSpace.md,
              AllInButtonSize.md => AllInSpace.lg,
              AllInButtonSize.lg => AllInSpace.xl,
            };

    final children = <Widget>[
      if (widget.leading != null) ...[
        Icon(widget.leading, size: 18, color: fg),
        const SizedBox(width: AllInSpace.sm),
      ],
      Flexible(
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AllInText.body(
            fontSize,
            weight: FontWeight.w600,
            color: fg,
            height: 1.1,
          ),
        ),
      ),
      if (widget.busy && !reduced) ...[
        const SizedBox(width: AllInSpace.sm),
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
        ),
      ] else if (widget.trailing != null) ...[
        const SizedBox(width: AllInSpace.sm),
        Icon(widget.trailing, size: 18, color: fg),
      ],
    ];

    final surface = ConstrainedBox(
      constraints: BoxConstraints(minHeight: visual, minWidth: 44),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          border: border == null ? null : Border.all(color: border, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: pad,
            vertical: AllInSpace.sm,
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: _enabled ? 1 : 0.45,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
            onTapCancel: _enabled ? () => setState(() => _down = false) : null,
            onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
            onTap: _enabled ? _commit : null,
            child: AnimatedScale(
              scale: _down ? 0.97 : 1,
              // §11: button press = scale 0.97 over 120 ms.
              duration: AllInMotion.of(
                context,
                const Duration(milliseconds: 120),
                reduced: reduced,
              ),
              curve: AllInMotion.ease,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: hit, minWidth: 44),
                child: Center(
                  widthFactor: widget.expand ? null : 1,
                  heightFactor: 1,
                  child: surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
