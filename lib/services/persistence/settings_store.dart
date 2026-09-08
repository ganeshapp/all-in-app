/// App settings and theme (docs/port/persistence-stats-settings.md §6.1/§6.2;
/// DESIGN.md §9 Settings and §16.4 "Play settings — inside
/// `allin.settings.v1`").
///
/// One key, `allin.settings.v1`, holding the desktop `AppSettings` object plus
/// the mobile additions (`haptics`, `alwaysExpandMath`) and the remembered
/// play settings (`paceMode`, `speedMs`, `coachEnabled`, `autoDeal` — DESIGN
/// §4.1 deviation: the desktop does not persist these). Loading merges the
/// stored object over the defaults and **keeps unknown keys**, so a settings
/// blob written by a newer build survives a round trip through this one.
///
/// The theme lives under its own key, `allin.theme`, as the raw string
/// "dark"/"light" — not JSON — exactly as the desktop writes it.
library;

import '../../engine/engine.dart'
    show CoachSettings, CoachStrictness, SimQuality;
import 'key_value_store.dart';

// The coach's own settings types are the engine's; re-exported here so a
// caller configuring settings does not have to import the engine as well.
export '../../engine/coach.dart'
    show
        CoachSettings,
        CoachStrictness,
        CoachThresholds,
        SimQuality,
        baseItersFor,
        coachThresholds;

/// Storage key (desktop parity).
const String kSettingsKey = 'allin.settings.v1';

/// Storage key for the theme (desktop parity; a raw string, not JSON).
const String kThemeKey = 'allin.theme';

// `CoachStrictness`, `SimQuality`, `CoachThresholds` and `coachThresholds`
// are the engine's (lib/engine/coach.dart) — the coach grades with them, so
// they must not be redeclared here.

/// Table pace: step through actions by hand, or let the bots act.
enum PaceMode {
  manual('manual'),
  auto('auto');

  const PaceMode(this.label);
  final String label;

  static PaceMode fromLabel(Object? v) =>
      PaceMode.values.firstWhere((p) => p.label == v, orElse: () => manual);
}

/// The three Auto speeds of DESIGN §4.6 (Slow / Normal / Fast).
abstract final class PaceSpeed {
  static const int slowMs = 1100;
  static const int normalMs = 700;
  static const int fastMs = 360;

  /// The three offered values, slowest first.
  static const List<int> all = [slowMs, normalMs, fastMs];
}

/// Everything under `allin.settings.v1`.
class AppSettings {
  const AppSettings({
    this.fourColorDeck = false,
    this.reducedMotion = false,
    this.coachStrictness = CoachStrictness.standard,
    this.simQuality = SimQuality.standard,
    this.realisticReveal = false,
    this.haptics = true,
    this.alwaysExpandMath = false,
    this.paceMode = PaceMode.manual,
    this.speedMs = PaceSpeed.normalMs,
    this.coachEnabled = true,
    this.autoDeal = false,
    this.extra = const {},
  });

  /// The defaults every load merges over.
  static const AppSettings defaults = AppSettings();

  /// ♠ black · ♥ red · ♦ blue · ♣ green.
  final bool fourColorDeck;

  /// Disable animations (the OS preference is honoured independently).
  final bool reducedMotion;
  final CoachStrictness coachStrictness;
  final SimQuality simQuality;

  /// Hide folded players' cards at hand end.
  final bool realisticReveal;

  /// *(mobile)* Haptic feedback, on by default (DESIGN §9).
  final bool haptics;

  /// *(mobile)* Open "Show me the math" by default on every coach surface.
  final bool alwaysExpandMath;

  /// *(mobile)* Remembered play settings — the desktop re-chooses these every
  /// session, which is friction on a phone (DESIGN §4.1).
  final PaceMode paceMode;

  /// Auto cadence in ms; one of [PaceSpeed.all].
  final int speedMs;
  final bool coachEnabled;
  final bool autoDeal;

  /// Keys this build does not know about, preserved verbatim on save.
  final Map<String, Object?> extra;

  /// The two settings the engine's coach reads, ready to hand to it.
  CoachSettings get coachSettings =>
      CoachSettings(strictness: coachStrictness, simQuality: simQuality);

  AppSettings copyWith({
    bool? fourColorDeck,
    bool? reducedMotion,
    CoachStrictness? coachStrictness,
    SimQuality? simQuality,
    bool? realisticReveal,
    bool? haptics,
    bool? alwaysExpandMath,
    PaceMode? paceMode,
    int? speedMs,
    bool? coachEnabled,
    bool? autoDeal,
    Map<String, Object?>? extra,
  }) => AppSettings(
    fourColorDeck: fourColorDeck ?? this.fourColorDeck,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    coachStrictness: coachStrictness ?? this.coachStrictness,
    simQuality: simQuality ?? this.simQuality,
    realisticReveal: realisticReveal ?? this.realisticReveal,
    haptics: haptics ?? this.haptics,
    alwaysExpandMath: alwaysExpandMath ?? this.alwaysExpandMath,
    paceMode: paceMode ?? this.paceMode,
    speedMs: speedMs ?? this.speedMs,
    coachEnabled: coachEnabled ?? this.coachEnabled,
    autoDeal: autoDeal ?? this.autoDeal,
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    'fourColorDeck': fourColorDeck,
    'reducedMotion': reducedMotion,
    'coachStrictness': coachStrictness.label,
    'simQuality': simQuality.label,
    'realisticReveal': realisticReveal,
    'haptics': haptics,
    'alwaysExpandMath': alwaysExpandMath,
    'paceMode': paceMode.label,
    'speedMs': speedMs,
    'coachEnabled': coachEnabled,
    'autoDeal': autoDeal,
  };

  /// `{ ...DEFAULTS, ...JSON.parse(stored) }` — missing keys default, unknown
  /// keys survive in [extra].
  static AppSettings fromJson(Object? json) {
    if (json is! Map) return defaults;
    final j = json.cast<String, Object?>();
    const known = {
      'fourColorDeck',
      'reducedMotion',
      'coachStrictness',
      'simQuality',
      'realisticReveal',
      'haptics',
      'alwaysExpandMath',
      'paceMode',
      'speedMs',
      'coachEnabled',
      'autoDeal',
    };
    return AppSettings(
      fourColorDeck: _bool(j['fourColorDeck'], defaults.fourColorDeck),
      reducedMotion: _bool(j['reducedMotion'], defaults.reducedMotion),
      coachStrictness: CoachStrictness.fromLabel(
        j['coachStrictness'] as String? ?? defaults.coachStrictness.label,
      ),
      simQuality: SimQuality.fromLabel(
        j['simQuality'] as String? ?? defaults.simQuality.label,
      ),
      realisticReveal: _bool(j['realisticReveal'], defaults.realisticReveal),
      haptics: _bool(j['haptics'], defaults.haptics),
      alwaysExpandMath: _bool(j['alwaysExpandMath'], defaults.alwaysExpandMath),
      paceMode: PaceMode.fromLabel(j['paceMode'] ?? defaults.paceMode.label),
      speedMs: (j['speedMs'] as num?)?.toInt() ?? defaults.speedMs,
      coachEnabled: _bool(j['coachEnabled'], defaults.coachEnabled),
      autoDeal: _bool(j['autoDeal'], defaults.autoDeal),
      extra: {
        for (final e in j.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;
}

/// Loads and saves [AppSettings].
class SettingsStore {
  SettingsStore(this._store);

  final KeyValueStore _store;

  AppSettings load() => AppSettings.fromJson(_store.getJson(kSettingsKey));

  Future<bool> save(AppSettings settings) =>
      _store.setJson(kSettingsKey, settings.toJson());

  /// `update(partial)`: applies [change] to the stored settings and saves the
  /// whole object back, like the desktop store.
  Future<AppSettings> update(AppSettings Function(AppSettings) change) async {
    final next = change(load());
    await save(next);
    return next;
  }
}

/// Dark or light — explicit, never "system" (DESIGN §9, desktop parity).
enum AppThemeMode {
  dark('dark'),
  light('light');

  const AppThemeMode(this.value);
  final String value;
}

/// The one-key theme store.
class ThemeStore {
  ThemeStore(this._store);

  final KeyValueStore _store;

  /// Anything other than the two literals reads as dark.
  AppThemeMode load() =>
      _store.getString(kThemeKey) == AppThemeMode.light.value
          ? AppThemeMode.light
          : AppThemeMode.dark;

  Future<bool> save(AppThemeMode mode) =>
      _store.setString(kThemeKey, mode.value);

  Future<AppThemeMode> toggle() async {
    final next =
        load() == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    await save(next);
    return next;
  }
}
