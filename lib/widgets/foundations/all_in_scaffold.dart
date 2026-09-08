/// `AllInScaffold` — the page scaffold every tab root and pushed screen uses
/// (DESIGN.md §10.1; header proportions from the §3.1 wireframe).
///
/// Safe areas via `SafeArea`, a large Bricolage 28 title with an optional
/// muted subtitle, trailing actions laid out on a 44 pt band (§12), and a
/// pinned `bottom` slot that sits above the tab bar / home-indicator inset.
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class AllInScaffold extends StatelessWidget {
  const AllInScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    required this.body,
    this.bottom,
    this.leading,
    this.background,
    this.headerPadding = const EdgeInsets.fromLTRB(
      AllInSpace.lg,
      AllInSpace.sm,
      AllInSpace.lg,
      AllInSpace.md,
    ),
  });

  /// Large title (Bricolage 28). Null renders no header block.
  final String? title;

  /// One muted line under the title (Inter 13) — "Wednesday · 4 days in a row".
  final String? subtitle;

  /// Trailing header controls (gear, ✕, Done…). Each is expected to be ≥ 44 pt.
  final List<Widget> actions;

  /// Leading control (a back chevron on pushed screens).
  final Widget? leading;

  final Widget body;

  /// Pinned slot above the tab bar / bottom inset (a primary CTA, a pill…).
  final Widget? bottom;

  final Color? background;
  final EdgeInsets headerPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasHeader =
        title != null ||
        subtitle != null ||
        actions.isNotEmpty ||
        leading != null;

    return Scaffold(
      backgroundColor: background ?? c.ink900,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (hasHeader) _header(context, c), Expanded(child: body)],
        ),
      ),
      bottomNavigationBar:
          bottom == null
              ? null
              : Container(
                decoration: BoxDecoration(
                  color: background ?? c.ink900,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AllInSpace.lg,
                      AllInSpace.md,
                      AllInSpace.lg,
                      AllInSpace.md,
                    ),
                    child: bottom,
                  ),
                ),
              ),
    );
  }

  Widget _header(BuildContext context, AllInColors c) {
    return Padding(
      padding: headerPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AllInSpace.sm),
          ],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: AllInText.display(
                          28,
                          color: c.text,
                          height: 1.15,
                        ),
                      ),
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AllInText.body(13, color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AllInSpace.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in actions)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: a,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
