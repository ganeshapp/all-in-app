/// `AllInDialog` — the adaptive alert used for destructive or irreversible
/// choices (DESIGN.md §2.4, §10.1; `showAdaptiveDialog` per §16.2).
///
/// `AllInDialog.typed` adds the typed confirmation X2 needs (§7.10): the
/// destructive button stays disabled until the field reads exactly the
/// confirm word, and a wrong entry shows no error text.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// One button on a dialog. `isDestructive` paints it in `bad`.
class AllInDialogAction {
  const AllInDialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isDefault;
}

class AllInDialog extends StatefulWidget {
  const AllInDialog({
    super.key,
    required this.title,
    this.body,
    this.actions = const <AllInDialogAction>[],
    this.content,
  }) : confirmWord = null,
       confirmLabel = null,
       cancelLabel = null,
       fieldLabel = null,
       onConfirm = null;

  /// Destructive confirmation: the user types [confirmWord] to enable the
  /// danger button (§7.10 "Type RESET to confirm:").
  const AllInDialog.typed({
    super.key,
    required this.title,
    this.body,
    required this.confirmWord,
    required this.confirmLabel,
    this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.fieldLabel,
    this.content,
  }) : actions = const <AllInDialogAction>[];

  final String title;

  /// Plain-English description (TONE.md layer 1).
  final String? body;

  /// Extra content between the body and the actions (a backup button, a note).
  final Widget? content;
  final List<AllInDialogAction> actions;

  final String? confirmWord;
  final String? confirmLabel;
  final String? cancelLabel;
  final String? fieldLabel;
  final VoidCallback? onConfirm;

  bool get isTyped => confirmWord != null;

  /// Presents [dialog] adaptively and returns its result.
  static Future<T?> show<T>(
    BuildContext context, {
    required AllInDialog dialog,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    return showAdaptiveDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (_) => dialog,
    );
  }

  @override
  State<AllInDialog> createState() => _AllInDialogState();
}

class _AllInDialogState extends State<AllInDialog> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  bool get _confirmEnabled =>
      !widget.isTyped || _field.text == widget.confirmWord;

  bool _isCupertino(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  List<AllInDialogAction> _actions() {
    if (!widget.isTyped) return widget.actions;
    return [
      AllInDialogAction(
        label: widget.cancelLabel ?? 'Cancel',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      AllInDialogAction(
        label: widget.confirmLabel!,
        isDestructive: true,
        onPressed:
            _confirmEnabled
                ? () {
                  widget.onConfirm?.call();
                  Navigator.of(context).pop(true);
                }
                : null,
      ),
    ];
  }

  Widget _confirmField(BuildContext context, bool cupertino) {
    final c = context.colors;
    final style = AllInText.mono(15, color: c.text);
    final padding = const EdgeInsets.symmetric(
      horizontal: AllInSpace.md,
      vertical: AllInSpace.sm,
    );
    if (cupertino) {
      return CupertinoTextField(
        controller: _field,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        style: style,
        padding: padding,
        decoration: BoxDecoration(
          color: c.ink700,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          border: Border.all(color: c.lineStrong),
        ),
        onChanged: (_) => setState(() {}),
      );
    }
    return TextField(
      controller: _field,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: padding,
        filled: true,
        fillColor: c.ink700,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AllInRadius.md),
          borderSide: BorderSide(color: c.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AllInRadius.md),
          borderSide: BorderSide(color: c.gold),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cupertino = _isCupertino(context);

    final children = <Widget>[
      if (widget.body != null)
        Text(
          widget.body!,
          textAlign: cupertino ? TextAlign.center : TextAlign.start,
          style: AllInText.body(14, color: c.textMuted),
        ),
      if (widget.content != null) ...[
        const SizedBox(height: AllInSpace.md),
        widget.content!,
      ],
      if (widget.isTyped) ...[
        const SizedBox(height: AllInSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.fieldLabel ?? 'Type ${widget.confirmWord} to confirm:',
            style: AllInText.body(13, color: c.textMuted),
          ),
        ),
        const SizedBox(height: AllInSpace.sm),
        SizedBox(height: 44, child: _confirmField(context, cupertino)),
      ],
    ];

    final content =
        children.isEmpty
            ? null
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            );

    final actions = _actions();

    if (cupertino) {
      return CupertinoAlertDialog(
        title: Text(widget.title, style: AllInText.display(17, color: c.text)),
        content:
            content == null
                ? null
                : Padding(
                  padding: const EdgeInsets.only(top: AllInSpace.sm),
                  child: content,
                ),
        actions: [
          for (final a in actions)
            CupertinoDialogAction(
              isDestructiveAction: a.isDestructive,
              isDefaultAction: a.isDefault,
              onPressed: a.onPressed,
              child: Text(a.label),
            ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: c.ink800,
      titleTextStyle: AllInText.display(19, color: c.text),
      title: Text(widget.title),
      content: content,
      actionsPadding: const EdgeInsets.fromLTRB(
        AllInSpace.sm,
        0,
        AllInSpace.sm,
        AllInSpace.sm,
      ),
      actions: [
        for (final a in actions)
          TextButton(
            onPressed: a.onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 44),
              foregroundColor: a.isDestructive ? c.bad : c.gold,
              disabledForegroundColor: c.textFaint,
              textStyle: AllInText.body(15, weight: FontWeight.w600),
            ),
            child: Text(a.label),
          ),
      ],
    );
  }
}
