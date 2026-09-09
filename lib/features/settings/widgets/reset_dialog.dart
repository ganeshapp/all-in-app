/// X2 · "Reset all progress?" — the typed confirmation of DESIGN.md §7.10
/// (docs/port/persistence-stats-settings.md §7.11).
///
/// Copy is the desktop's, verbatim: the title, the description, the backup
/// offer, the "Type RESET to confirm:" label and the two buttons. The danger
/// button stays disabled until the field reads exactly `RESET` — a wrong entry
/// shows no error text, deliberately (§14 "Reset · typed wrong").
library;

import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Verbatim §7.10 copy.
abstract final class ResetCopy {
  static const String title = 'Reset all progress?';
  static const String body =
      'This permanently deletes your lifetime stats, decisions, reads, and '
      'saved hands.';
  static const String backupFirst = 'Download a backup first';
  static const String fieldLabel = 'Type RESET to confirm:';
  static const String confirmWord = 'RESET';
  static const String confirmLabel = 'Erase everything';
  static const String cancelLabel = 'Cancel';
}

/// Shows X2 and resolves to true when the user erased.
///
/// [onBackup] is the §7.9 share; its returned message is shown beneath the
/// button in faint text, exactly as the desktop shows `saveText`'s result.
Future<bool> showResetProgressDialog(
  BuildContext context, {
  required Future<DataActionResult> Function() onBackup,
}) async {
  final confirmed = await AllInDialog.show<bool>(
    context,
    dialog: AllInDialog.typed(
      title: ResetCopy.title,
      body: ResetCopy.body,
      confirmWord: ResetCopy.confirmWord,
      confirmLabel: ResetCopy.confirmLabel,
      cancelLabel: ResetCopy.cancelLabel,
      fieldLabel: ResetCopy.fieldLabel,
      content: ResetBackupOffer(onBackup: onBackup),
    ),
  );
  return confirmed ?? false;
}

/// The "Download a backup first" button plus the line it leaves behind.
class ResetBackupOffer extends StatefulWidget {
  const ResetBackupOffer({super.key, required this.onBackup});

  final Future<DataActionResult> Function() onBackup;

  @override
  State<ResetBackupOffer> createState() => _ResetBackupOfferState();
}

class _ResetBackupOfferState extends State<ResetBackupOffer> {
  DataActionResult? _result;
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.onBackup();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result.status == DataActionStatus.cancelled ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AllInButton.secondary(
          label: ResetCopy.backupFirst,
          expand: true,
          busy: _busy,
          leading: Icons.download_rounded,
          onPressed: _run,
        ),
        if (result != null) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: AllInText.body(
              12.5,
              color: result.isOk ? c.textFaint : c.bad,
            ),
          ),
        ],
      ],
    );
  }
}
