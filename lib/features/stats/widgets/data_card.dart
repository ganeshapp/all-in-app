/// T0's "Data" card and the X2 reset dialog (DESIGN.md §7.1, §7.9, §7.10).
///
/// The three rows are the same actions as X0 → Data; both surfaces run them
/// through [StatsDataActions], so "Back up" writes and shares the same
/// document from either place and "Reset all progress" clears the same tables.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/share_service.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../../widgets/widgets.dart';
import '../providers/data_actions.dart';
import '../stats_copy.dart';
import 'stats_section.dart';

class DataCard extends StatelessWidget {
  const DataCard({
    super.key,
    required this.onBackup,
    required this.onImport,
    required this.onReset,
    this.busy = false,
  });

  final VoidCallback onBackup;
  final VoidCallback onImport;
  final VoidCallback onReset;

  /// True while a backup is being written — the row shows a spinner rather
  /// than doing nothing on a second tap.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return StatsSection(
      title: StatsCopy.dataCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatsDataRow(
            label: StatsCopy.backupRow,
            caption: StatsCopy.backupCaption,
            icon: Icons.save_alt,
            busy: busy,
            onTap: busy ? null : onBackup,
          ),
          StatsDataRow(
            label: StatsCopy.importButton,
            icon: Icons.file_download_outlined,
            onTap: onImport,
          ),
          StatsDataRow(
            label: StatsCopy.resetRow,
            icon: Icons.delete_outline,
            destructive: true,
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

/// A 44 pt Data row with an optional caption underneath.
class StatsDataRow extends StatelessWidget {
  const StatsDataRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.caption,
    this.destructive = false,
    this.busy = false,
  });

  final String label;
  final String? caption;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = destructive ? c.bad : c.text;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: caption == null ? label : '$label. $caption',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AllInRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AllInSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child:
                      busy
                          ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.gold,
                            ),
                          )
                          : Icon(icon, size: 18, color: tone),
                ),
                const SizedBox(width: AllInSpace.sm),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: AllInText.body(15, color: tone)),
                        if (caption != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            caption!,
                            style: AllInText.body(
                              12,
                              color: c.textFaint,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// X2 (§7.10): a typed confirmation with a backup offer above it. Returns true
/// when everything was erased.
Future<bool> showResetProgressDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final erased = await AllInDialog.show<bool>(
    context,
    dialog: AllInDialog.typed(
      title: StatsCopy.resetTitle,
      body: StatsCopy.resetBody,
      confirmWord: StatsCopy.resetConfirmWord,
      confirmLabel: StatsCopy.resetConfirm,
      cancelLabel: StatsCopy.resetCancel,
      fieldLabel: StatsCopy.resetFieldLabel,
      content: _BackupFirst(ref: ref),
    ),
  );
  if (erased != true) return false;
  await ref.read(statsDataActionsProvider).resetProgress();
  return true;
}

/// "Download a backup first" plus the message the share sheet came back with
/// (§7.10 step 1).
class _BackupFirst extends StatefulWidget {
  const _BackupFirst({required this.ref});

  final WidgetRef ref;

  @override
  State<_BackupFirst> createState() => _BackupFirstState();
}

class _BackupFirstState extends State<_BackupFirst> {
  String? _message;
  bool _busy = false;

  Future<void> _backup() async {
    if (_busy) return;
    setState(() => _busy = true);
    String message;
    try {
      final outcome =
          await widget.ref.read(statsDataActionsProvider).shareBackup();
      message = switch (outcome) {
        ShareOutcome.success => StatsCopy.backupShared,
        ShareOutcome.dismissed => StatsCopy.backupDismissed,
        ShareOutcome.unavailable => StatsCopy.backupFailed,
      };
    } catch (_) {
      message = StatsCopy.backupFailed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AllInButton.secondary(
          label: StatsCopy.resetBackupFirst,
          leading: Icons.save_alt,
          expand: true,
          busy: _busy,
          onPressed: _busy ? null : _backup,
        ),
        if (_message != null && _message!.isNotEmpty) ...[
          const SizedBox(height: AllInSpace.sm),
          Text(_message!, style: AllInText.body(12, color: c.textFaint)),
        ],
      ],
    );
  }
}
