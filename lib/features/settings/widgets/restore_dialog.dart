/// X3 · "Restore this backup?" (DESIGN.md §7.9) and the three refusals §14
/// keeps deliberately distinct: a newer schema, a file that is not an All-In
/// backup, and bytes that could not be read at all.
///
/// Every one of these runs **before anything is written** — `BackupService`
/// inspects the document first, so a refused restore leaves the user's stats
/// exactly as they were.
library;

import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/services/persistence/backup_service.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

abstract final class RestoreCopy {
  static const String title = 'Restore this backup?';
  static const String restore = 'Restore';
  static const String cancel = 'Cancel';

  /// The refusals all share one title; the body is what differs (§14).
  static const String refusedTitle = "Can't restore this backup";
  static const String ok = 'OK';
}

/// The X3 confirmation. Resolves true when the user chose "Restore".
Future<bool> showRestoreBackupDialog(
  BuildContext context, {
  required BackupPreview preview,
}) async {
  final confirmed = await AllInDialog.show<bool>(
    context,
    dialog: AllInDialog(
      title: RestoreCopy.title,
      body: SettingsDataService.restoreBody(preview),
      actions: [
        AllInDialogAction(
          label: RestoreCopy.cancel,
          onPressed:
              () => Navigator.of(context, rootNavigator: true).pop(false),
        ),
        AllInDialogAction(
          label: RestoreCopy.restore,
          isDefault: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A one-button refusal: the §14 wording for whichever problem was found.
Future<void> showBackupProblemDialog(
  BuildContext context, {
  required String message,
}) => AllInDialog.show<void>(
  context,
  dialog: AllInDialog(
    title: RestoreCopy.refusedTitle,
    body: message,
    actions: [
      AllInDialogAction(
        label: RestoreCopy.ok,
        isDefault: true,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  ),
);
