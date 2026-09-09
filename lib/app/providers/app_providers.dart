/// The providers the app shell needs: the persisted settings and theme
/// (DESIGN.md §9, docs/port/persistence-stats-settings.md §6) on top of the
/// `services/persistence` stores, and the two shell signals the tab bar reads
/// — the Drills badge count and the live-session state behind `SessionPill`
/// (DESIGN.md §2.1).
///
/// The settings *shape* lives in `services/persistence/settings_store.dart`;
/// this file only owns the Riverpod layer over it. Features replace the stubs
/// at the bottom by overriding them in `ProviderScope`; nothing else about the
/// shell changes.
library;

import 'package:allin/features/drills/providers/review_provider.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/file_service.dart';
import 'package:allin/services/haptics.dart';
import 'package:allin/services/persistence/app_database.dart';
import 'package:allin/services/persistence/backup_service.dart';
import 'package:allin/services/persistence/hints_store.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/onboarding_store.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/services/persistence/stats_repository.dart';
import 'package:allin/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On-device key-value storage. `main.dart` overrides this with the
/// `shared_preferences` store; the in-memory default keeps tests hermetic and
/// is also the §14 "storage unavailable" fallback.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => KeyValueStore.memory(),
);

/// The opened sqflite database, or null when it could not be opened — the
/// repositories then fall back to the key-value store (§14).
final appDatabaseProvider = Provider<AppDatabase?>((ref) => null);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(keyValueStoreProvider)),
);

final themeStoreProvider = Provider<ThemeStore>(
  (ref) => ThemeStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.onboarded.v1` — the O0 gate (§8) and Settings → "Run again" (§9).
final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => OnboardingStore(ref.watch(keyValueStoreProvider)),
);

/// `allin.hints.v1` — the O1 coach-mark counters (§4.15, §16.4).
final hintsStoreProvider = Provider<HintsStore>(
  (ref) => HintsStore(ref.watch(keyValueStoreProvider)),
);

/// What actually vibrates the phone. Overridden with a
/// [RecordingHapticDriver] in tests (§16.6 platform adapter).
final hapticDriverProvider = Provider<HapticDriver>(
  (ref) => const PlatformHapticDriver(),
);

/// The app's [Haptics], already gated by Settings → Haptics (§9, §11). It is
/// rebuilt when the setting flips, so no call site has to re-read the flag.
final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(
    enabled: ref.watch(hapticsEnabledProvider),
    driver: ref.watch(hapticDriverProvider),
  ),
);

/// Stats, hands, reads and decisions. When the database could not be opened
/// the repository is handed a fresh (unopened) handle and pins itself to the
/// key-value fallback on its first call (§14 "Storage · quota / DB error").
final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(
    database: ref.watch(appDatabaseProvider) ?? AppDatabase(),
    store: ref.watch(keyValueStoreProvider),
  ),
);

/// The paused-session snapshot and the ended-session table (§16.4).
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    database: ref.watch(appDatabaseProvider) ?? AppDatabase(),
    store: ref.watch(keyValueStoreProvider),
  ),
);

/// Backup export / inspect / restore behind X0 Data (§7.9, X3).
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    stats: ref.watch(statsRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
  ),
);

/// The system file picker (§7.8 import, §7.9 restore).
final fileServiceProvider = Provider<FileService>((ref) => FileService());

/// The share sheet (§4.13, §7.9).
final shareServiceProvider = Provider<ShareService>(
  (ref) => ShareService(files: ref.watch(fileServiceProvider)),
);

/// The live settings object. Every change persists the whole object, like the
/// desktop store's `update(partial)`.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).load();

  /// Partial update — pass only what changed.
  Future<void> update({
    bool? fourColorDeck,
    bool? reducedMotion,
    bool? realisticReveal,
    CoachStrictness? coachStrictness,
    SimQuality? simQuality,
    bool? haptics,
    bool? alwaysExpandMath,
    PaceMode? paceMode,
    int? speedMs,
    bool? coachEnabled,
    bool? autoDeal,
  }) => replace(
    state.copyWith(
      fourColorDeck: fourColorDeck,
      reducedMotion: reducedMotion,
      realisticReveal: realisticReveal,
      coachStrictness: coachStrictness,
      simQuality: simQuality,
      haptics: haptics,
      alwaysExpandMath: alwaysExpandMath,
      paceMode: paceMode,
      speedMs: speedMs,
      coachEnabled: coachEnabled,
      autoDeal: autoDeal,
    ),
  );

  /// Swaps in a whole settings object (a restored backup, the reset flow).
  Future<void> replace(AppSettings next) async {
    state = next;
    await ref.read(settingsStoreProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Dark or light — explicit, never "system" (§9). Stored under its own key.
class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => ref.read(themeStoreProvider).load();

  Future<void> set(AppThemeMode mode) async {
    state = mode;
    await ref.read(themeStoreProvider).save(mode);
  }

  Future<void> toggle() =>
      set(state == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark);
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(
  ThemeNotifier.new,
);

/// The Material theme mode for `MaterialApp.router`.
final themeModeProvider = Provider<ThemeMode>(
  (ref) =>
      ref.watch(themeProvider) == AppThemeMode.light
          ? ThemeMode.light
          : ThemeMode.dark,
);

/// Settings → Reduce motion. Widgets still pass this through
/// `AllInMotion.of(context, d, reduced: …)`, which also honours the OS flag.
final reducedMotionProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.reducedMotion)),
);

/// Settings → Haptics.
final hapticsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.haptics)),
);

/// A pending "open the hand-history import flow" request (T3, §7.8).
///
/// X0's Data group can reach T3 but must not own it: the picker → progress →
/// result flow, the Review-queue hand-off and the "See hands" button are all
/// `features/stats`. So Settings raises this counter and navigates to T0,
/// which watches it and presents T3 (§2.6 does the same job for the reverse
/// direction with `/stats/settings?section=data`).
class ImportRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Ask the Stats tab to open T3 on its next build.
  void request() => state = state + 1;
}

final importRequestProvider = NotifierProvider<ImportRequestNotifier, int>(
  ImportRequestNotifier.new,
);

// ---------------------------------------------------------------- shell stubs

/// What the shell needs to know about a live session to render `SessionPill`
/// (§2.1) or the compact Play-tab label. `features/play` overrides
/// [shellSessionProvider] with the real snapshot.
@immutable
class ShellSession {
  const ShellSession({required this.hands, required this.netBb});

  /// Hands played so far this session.
  final int hands;

  /// Net result in big blinds (signed).
  final double netBb;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShellSession && other.hands == hands && other.netBb == netBb;

  @override
  int get hashCode => Object.hash(hands, netBb);
}

/// The live session, or null when there is none. Delegates to
/// `features/play`'s `SessionNotifier`, so the pill, the Play-tab dot and the
/// lobby's Resume card can never disagree (§2.1). Tests still override it with
/// `overrideWithValue`.
final shellSessionProvider = Provider<ShellSession?>(
  (ref) => ref.watch(playShellSessionProvider),
);

/// Whether a session exists — paused or on screen (§2.1, §4.1).
final hasSessionProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider.select((s) => s.active)),
);

/// Review cards due — the badge on the Drills tab (§5.4). Delegates to the
/// Drills feature's live count over `allin.leaks.v1` + `allin.review.v1`, so
/// the badge, the Review chip's pill and the empty state can never disagree.
final drillsDueBadgeProvider = Provider<int>(
  (ref) => ref.watch(drillsDueCountProvider),
);

/// Bumped every time the already-active tab is tapped; a tab root watches it
/// and scrolls itself to the top (§2.1, §12).
@immutable
class TabReselect {
  const TabReselect({required this.branch, required this.seq});

  /// Branch index 0–4 (home, play, drills, study, stats); -1 before any tap.
  final int branch;

  /// Increments on every re-tap so repeats on the same branch still notify.
  final int seq;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabReselect && other.branch == branch && other.seq == seq;

  @override
  int get hashCode => Object.hash(branch, seq);
}

class TabReselectNotifier extends Notifier<TabReselect> {
  @override
  TabReselect build() => const TabReselect(branch: -1, seq: 0);

  void bump(int branch) =>
      state = TabReselect(branch: branch, seq: state.seq + 1);
}

final tabReselectProvider = NotifierProvider<TabReselectNotifier, TabReselect>(
  TabReselectNotifier.new,
);
