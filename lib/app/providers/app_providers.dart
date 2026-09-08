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

import 'package:allin/services/persistence/app_database.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/settings_store.dart';
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

/// The live session, or null when there is none. Stub: null.
final shellSessionProvider = Provider<ShellSession?>((ref) => null);

/// Whether a session snapshot exists. Stub: false.
final hasSessionProvider = Provider<bool>(
  (ref) => ref.watch(shellSessionProvider) != null,
);

/// Review cards due — the badge on the Drills tab. Stub: 0.
final drillsDueBadgeProvider = Provider<int>((ref) => 0);

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
