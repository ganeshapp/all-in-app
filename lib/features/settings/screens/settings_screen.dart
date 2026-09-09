/// X0 · Settings (DESIGN.md §9) — the one canonical path `/stats/settings`;
/// both gears land here and `/settings*` redirects to it (§16.1).
///
/// Six groups, in the §9 order: Table & cards · Coach · Play · Learning ·
/// Data · About. Every control writes through `SettingsStore` (or the theme
/// store) and takes effect immediately — the theme and reduce-motion rows
/// change the running app, not the next launch.
///
/// Descriptions are the desktop's verbatim copy
/// (docs/port/persistence-stats-settings.md §14); the rows this spec adds are
/// marked *(new)* below.
library;

import 'dart:async';

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/features/settings/widgets/reset_dialog.dart';
import 'package:allin/features/settings/widgets/restore_dialog.dart';
import 'package:allin/features/settings/widgets/setting_rows.dart';
import 'package:allin/services/persistence/backup_service.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every user-facing string on X0, in one table (§16.7).
abstract final class SettingsCopy {
  static const String title = 'Settings';
  static const String subtitle = 'Everything is saved on this device.';

  // ------------------------------------------------------- table & cards
  static const String tableGroup = 'Table & cards';
  static const String fourColour = 'Four-colour deck';
  static const String fourColourDesc =
      '♠ black · ♥ red · ♦ blue · ♣ green. Makes suits unmistakable at a '
      'glance — recommended, and essential if you have trouble telling red '
      'suits apart.';
  static const String realisticReveals = 'Realistic reveals';
  static const String realisticRevealsDesc =
      "By default the app shows everyone's cards when a hand ends — folded "
      'hands included — because seeing what people folded builds intuition. '
      'Turn this on to hide folded hands, like a real table.';
  static const String theme = 'Theme';
  static const String themeDesc = 'Light or dark.';
  static const String reduceMotion = 'Reduce motion';
  static const String reduceMotionDesc =
      "Disables animations and transitions. Also honors your system's "
      'reduced-motion preference automatically.';
  static const String haptics = 'Haptics';

  /// *(new)* — the desktop has no haptics.
  static const String hapticsDesc =
      'Small taps when you act, when a verdict lands and when a control '
      'snaps into place.';

  // --------------------------------------------------------------- coach
  static const String coachGroup = 'Coach';
  static const String strictness = 'Strictness';
  static const String strictnessDesc =
      'How eagerly the coach interrupts. Relaxed only flags clear blunders; '
      'strict calls out smaller EV losses too.';
  static const String simQuality = 'Simulation quality';
  static const String simQualityDesc =
      'High runs 2.5× more Monte-Carlo trials per verdict — slightly slower, '
      'tighter error bars. Late streets are always computed exactly either '
      'way.';
  static const String alwaysExpand = 'Always expand "Show me the math"';

  /// *(new)*.
  static const String alwaysExpandDesc =
      'Opens the working under every coach note without a tap.';

  // ---------------------------------------------------------------- play
  static const String playGroup = 'Play';
  static const String pace = 'Pace';
  static const String paceStepDesc =
      "Step through each player's action yourself.";
  static const String paceAutoDesc =
      'Bots act automatically at the chosen speed.';
  static const String speed = 'Speed';
  static const String speedAutoDesc = 'How fast the bots act on Auto.';
  static const String speedStepDesc =
      'Switch Pace to Auto to change how fast the bots act.';
  static const String evCoach = 'EV Coach';
  static const String evCoachDesc =
      'Grades your decisions and explains the money behind them. Turn it off '
      'for a quiet table.';
  static const String autoDeal = 'Auto-deal next hand';
  static const String autoDealDesc =
      'Deals the next hand for you when one ends.';

  // ------------------------------------------------------------ learning
  static const String learningGroup = 'Learning';
  static const String tour = 'Tour & placement';
  static const String tourDesc =
      'Re-run the first-launch tour and the placement quiz (recalibrates your '
      'drill rating).';
  static const String runAgain = 'Run again';

  // ---------------------------------------------------------------- data
  static const String dataGroup = 'Data';
  static const String backup = 'Back up all data (.json)';

  /// *(new)* — §7.9's caption under the row.
  static const String backupDesc =
      'A safety copy of your stats, decisions, reads and hands. Restore it '
      'from this screen on a new phone.';
  static const String restore = 'Restore from backup…';
  static const String restoreDesc =
      'Replaces your stats, decisions, reads and hands with a backup file. '
      'Notes, drills and study progress are left alone.';
  static const String importHands = 'Import hands (.txt)';
  static const String importHandsDesc =
      'Read a PokerStars-style text history. Imported hands never count '
      'toward your play stats.';
  static const String reset = 'Reset all progress';
  static const String resetDesc =
      'Deletes your lifetime stats, decisions, reads and saved hands. Notes, '
      'drills, study and settings are kept.';

  // --------------------------------------------------------------- about
  static const String aboutGroup = 'About';
  static const String about = 'About All-In';
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.section});

  /// `?section=data` scrolls to and flashes the DATA group (§2.6).
  final String? section;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final GlobalKey _dataKey = GlobalKey();
  bool _flashData = false;
  bool _busy = false;
  Timer? _flashTimer;

  /// How long the §2.6 highlight stays on the DATA group.
  static const Duration _flashDuration = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    if (widget.section == 'data') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealData());
    }
  }

  Future<void> _revealData() async {
    final target = _dataKey.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        alignment: 0.1,
      );
    }
    if (!mounted) return;
    setState(() => _flashData = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(_flashDuration, () {
      if (!mounted) return;
      setState(() => _flashData = false);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    AllInToast.show(
      context,
      message,
      reducedMotion: ref.read(reducedMotionProvider),
    );
  }

  /* ------------------------------------------------------------- actions */

  Future<void> _backup() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref.read(settingsDataServiceProvider).shareBackup();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.status != DataActionStatus.cancelled) _toast(result.message);
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final data = ref.read(settingsDataServiceProvider);
    final picked = await data.pickBackup();
    if (!mounted) return;
    setState(() => _busy = false);

    if (picked.error != null) {
      await showBackupProblemDialog(context, message: picked.error!);
      return;
    }
    final json = picked.json;
    if (json == null) return; // cancelled

    final preview = data.inspect(json);
    if (!mounted) return;
    if (!preview.isRestorable) {
      await showBackupProblemDialog(
        context,
        message:
            preview.problem == BackupProblem.newerSchema
                ? SettingsDataService.newerSchemaMessage(preview)
                : SettingsDataService.notABackup,
      );
      return;
    }

    final confirmed = await showRestoreBackupDialog(context, preview: preview);
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final result = await data.restore(json);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(result.message);
  }

  Future<void> _reset() async {
    final data = ref.read(settingsDataServiceProvider);
    final erased = await showResetProgressDialog(
      context,
      onBackup: data.shareBackup,
    );
    if (!erased || !mounted) return;
    final result = await data.resetProgress();
    if (!mounted) return;
    _toast(result.message);
  }

  void _importHands() {
    // T3 belongs to `features/stats` (§7.8); Settings raises the request and
    // hands the user to the Stats tab, which presents it.
    ref.read(importRequestProvider.notifier).request();
    context.go(AllInRoutes.progressPath);
  }

  Future<void> _runTourAgain() async {
    // §8.3: the first-table coach marks are re-armed with the tour, so the
    // hint counters are cleared before `runAgain` re-reads them.
    await ref.read(hintsStoreProvider).reset();
    await ref.read(onboardingSeenProvider.notifier).runAgain();
    if (!mounted) return;
    // §9: "presents O0 immediately (no app reload)". The gate deliberately
    // does not react to the flag flipping, so this push is the presentation.
    context.push(AllInRoutes.onboardingPath);
  }

  /* --------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(themeProvider);
    final version = ref.watch(appVersionProvider);
    final reduced = settings.reducedMotion;
    final haptics = settings.haptics;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    // At large text sizes the four preview cards no longer fit beside the
    // title and the switch; they drop to their own line instead of shrinking
    // (§13 — card ranks are graphics and never scale).
    final previewBesideSwitch = textScale <= 1.15;
    final preview = FourColourDeckPreview(
      fourColorDeck: settings.fourColorDeck,
    );

    Widget switchFor(String label, bool value, ValueChanged<bool> onChanged) =>
        AllInSwitch(
          value: value,
          semanticLabel: label,
          enableHaptics: haptics,
          onChanged: onChanged,
        );

    Widget segmented(
      String label,
      List<String> labels,
      int value,
      ValueChanged<int> onChanged,
    ) => AllInSegmented(
      labels: labels,
      value: value,
      semanticLabel: label,
      enableHaptics: haptics,
      reducedMotion: reduced,
      onChanged: onChanged,
    );

    return AllInScaffold(
      title: SettingsCopy.title,
      subtitle: SettingsCopy.subtitle,
      leading: _BackChevron(onTap: () => _pop(context)),
      // Deliberately not a lazy `ListView`: §2.6's `?section=data` scrolls to
      // the DATA group on the first frame, and `Scrollable.ensureVisible`
      // cannot reach a group that has not been built yet.
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AllInSpace.lg,
          AllInSpace.sm,
          AllInSpace.lg,
          AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------------------------------------------ table & cards
            SettingGroup(
              label: SettingsCopy.tableGroup,
              reducedMotion: reduced,
              children: [
                SettingRow(
                  title: SettingsCopy.fourColour,
                  description: SettingsCopy.fourColourDesc,
                  below: previewBesideSwitch ? null : preview,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (previewBesideSwitch) ...[
                        preview,
                        const SizedBox(width: AllInSpace.sm),
                      ],
                      switchFor(
                        SettingsCopy.fourColour,
                        settings.fourColorDeck,
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .update(fourColorDeck: v),
                      ),
                    ],
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.realisticReveals,
                  description: SettingsCopy.realisticRevealsDesc,
                  trailing: switchFor(
                    SettingsCopy.realisticReveals,
                    settings.realisticReveal,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .update(realisticReveal: v),
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.theme,
                  description: SettingsCopy.themeDesc,
                  below: segmented(
                    SettingsCopy.theme,
                    const ['Dark', 'Light'],
                    theme == AppThemeMode.light ? 1 : 0,
                    (i) => ref
                        .read(themeProvider.notifier)
                        .set(i == 1 ? AppThemeMode.light : AppThemeMode.dark),
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.reduceMotion,
                  description: SettingsCopy.reduceMotionDesc,
                  trailing: switchFor(
                    SettingsCopy.reduceMotion,
                    settings.reducedMotion,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .update(reducedMotion: v),
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.haptics,
                  description: SettingsCopy.hapticsDesc,
                  trailing: switchFor(
                    SettingsCopy.haptics,
                    settings.haptics,
                    (v) =>
                        ref.read(settingsProvider.notifier).update(haptics: v),
                  ),
                ),
              ],
            ),

            // -------------------------------------------------------- coach
            SettingGroup(
              label: SettingsCopy.coachGroup,
              reducedMotion: reduced,
              children: [
                SettingRow(
                  title: SettingsCopy.strictness,
                  description: SettingsCopy.strictnessDesc,
                  below: segmented(
                    SettingsCopy.strictness,
                    const ['Relaxed', 'Standard', 'Strict'],
                    CoachStrictness.values.indexOf(settings.coachStrictness),
                    (i) => ref
                        .read(settingsProvider.notifier)
                        .update(coachStrictness: CoachStrictness.values[i]),
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.simQuality,
                  description: SettingsCopy.simQualityDesc,
                  below: segmented(
                    SettingsCopy.simQuality,
                    const ['Standard', 'High'],
                    SimQuality.values.indexOf(settings.simQuality),
                    (i) => ref
                        .read(settingsProvider.notifier)
                        .update(simQuality: SimQuality.values[i]),
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.alwaysExpand,
                  description: SettingsCopy.alwaysExpandDesc,
                  trailing: switchFor(
                    SettingsCopy.alwaysExpand,
                    settings.alwaysExpandMath,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .update(alwaysExpandMath: v),
                  ),
                ),
              ],
            ),

            // --------------------------------------------------------- play
            SettingGroup(
              label: SettingsCopy.playGroup,
              reducedMotion: reduced,
              children: [
                SettingRow(
                  title: SettingsCopy.pace,
                  description:
                      settings.paceMode == PaceMode.auto
                          ? SettingsCopy.paceAutoDesc
                          : SettingsCopy.paceStepDesc,
                  below: segmented(
                    SettingsCopy.pace,
                    const ['Step', 'Auto'],
                    settings.paceMode == PaceMode.auto ? 1 : 0,
                    (i) => ref
                        .read(settingsProvider.notifier)
                        .update(
                          paceMode: i == 1 ? PaceMode.auto : PaceMode.manual,
                        ),
                  ),
                ),
                _SpeedRow(
                  enabled: settings.paceMode == PaceMode.auto,
                  speedMs: settings.speedMs,
                  haptics: haptics,
                  reducedMotion: reduced,
                  onChanged:
                      (ms) => ref
                          .read(settingsProvider.notifier)
                          .update(speedMs: ms),
                ),
                SettingRow(
                  title: SettingsCopy.evCoach,
                  description: SettingsCopy.evCoachDesc,
                  trailing: switchFor(
                    SettingsCopy.evCoach,
                    settings.coachEnabled,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .update(coachEnabled: v),
                  ),
                ),
                SettingRow(
                  title: SettingsCopy.autoDeal,
                  description: SettingsCopy.autoDealDesc,
                  trailing: switchFor(
                    SettingsCopy.autoDeal,
                    settings.autoDeal,
                    (v) =>
                        ref.read(settingsProvider.notifier).update(autoDeal: v),
                  ),
                ),
              ],
            ),

            // ----------------------------------------------------- learning
            SettingGroup(
              label: SettingsCopy.learningGroup,
              reducedMotion: reduced,
              children: [
                SettingRow(
                  title: SettingsCopy.tour,
                  description: SettingsCopy.tourDesc,
                  trailing: AllInButton.secondary(
                    label: SettingsCopy.runAgain,
                    size: AllInButtonSize.sm,
                    enableHaptics: haptics,
                    reducedMotion: reduced,
                    onPressed: _runTourAgain,
                  ),
                ),
              ],
            ),

            // --------------------------------------------------------- data
            SettingGroup(
              key: _dataKey,
              label: SettingsCopy.dataGroup,
              flash: _flashData,
              reducedMotion: reduced,
              children: [
                SettingRow(
                  title: SettingsCopy.backup,
                  description: SettingsCopy.backupDesc,
                  trailing: const SettingChevron(),
                  onTap: _busy ? null : _backup,
                ),
                SettingRow(
                  title: SettingsCopy.restore,
                  description: SettingsCopy.restoreDesc,
                  trailing: const SettingChevron(),
                  onTap: _busy ? null : _restore,
                ),
                SettingRow(
                  title: SettingsCopy.importHands,
                  description: SettingsCopy.importHandsDesc,
                  trailing: const SettingChevron(),
                  onTap: _busy ? null : _importHands,
                ),
                SettingRow(
                  title: SettingsCopy.reset,
                  description: SettingsCopy.resetDesc,
                  danger: true,
                  trailing: SettingChevron(tone: context.colors.bad),
                  onTap: _busy ? null : _reset,
                ),
              ],
            ),

            // -------------------------------------------------------- about
            SettingGroup(
              label: SettingsCopy.aboutGroup,
              reducedMotion: reduced,
              children: [
                SettingRow(
                  title:
                      version.hasValue && version.requireValue.isKnown
                          ? '${SettingsCopy.about} · '
                              '${version.requireValue.label}'
                          : SettingsCopy.about,
                  trailing: const SettingChevron(),
                  onTap: () => context.push(AllInRoutes.aboutPath),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.progressPath);
    }
  }
}

/// Speed is an Auto-only control (§4.6): on Step it stays visible and legible
/// but inert, and its description says what to do about that.
class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.enabled,
    required this.speedMs,
    required this.haptics,
    required this.reducedMotion,
    required this.onChanged,
  });

  final bool enabled;
  final int speedMs;
  final bool haptics;
  final bool reducedMotion;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = PaceSpeed.all.indexOf(speedMs);
    final control = AllInSegmented(
      labels: const ['Slow', 'Normal', 'Fast'],
      value: index < 0 ? 1 : index,
      semanticLabel: SettingsCopy.speed,
      enableHaptics: haptics,
      reducedMotion: reducedMotion,
      onChanged: (i) => onChanged(PaceSpeed.all[i]),
    );

    return SettingRow(
      title: SettingsCopy.speed,
      description:
          enabled ? SettingsCopy.speedAutoDesc : SettingsCopy.speedStepDesc,
      enabled: enabled,
      below:
          enabled
              ? control
              : ExcludeSemantics(
                child: IgnorePointer(
                  child: Opacity(opacity: 0.45, child: control),
                ),
              ),
    );
  }
}

/// The `‹` of a pushed screen (§2.4). 44 pt, like every other target.
class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.chevron_left_rounded,
          size: 28,
          color: context.colors.text,
        ),
      ),
    ),
  );
}
