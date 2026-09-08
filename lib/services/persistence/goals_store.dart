/// Daily activity, the daily goal and the streak (docs/port/
/// persistence-stats-settings.md §6.4; DESIGN.md §3.3 goal card, §7.11
/// practice heatmap).
///
/// One key, `allin.goals.v1`, holding
/// `{ "<YYYY-MM-DD>": { drills, hands } }` — unbounded, tiny, and keyed in
/// **local** time (§19 trap 3: no UTC anywhere in this subsystem).
library;

import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kGoalsKey = 'allin.goals.v1';

/// Either target hits the daily goal.
const int kDailyDrillGoal = 20;
const int kDailyHandGoal = 30;

const int _dayMs = 86400000;

/// Local-time `YYYY-MM-DD` for an epoch-ms instant (desktop `dayKey`).
String dayKey(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// What was practised on one day.
class DailyActivity {
  const DailyActivity({this.drills = 0, this.hands = 0});

  final int drills;
  final int hands;

  /// Total reps — what a heatmap cell counts.
  int get total => drills + hands;

  Map<String, Object?> toJson() => {'drills': drills, 'hands': hands};

  static DailyActivity fromJson(Object? json) {
    if (json is! Map) return const DailyActivity();
    return DailyActivity(
      drills: (json['drills'] as num?)?.toInt() ?? 0,
      hands: (json['hands'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What kind of rep was practised.
enum ActivityKind { drill, hand }

/// One cell of the practice heatmap (DESIGN §7.11).
class HeatmapCell {
  const HeatmapCell({
    required this.key,
    required this.count,
    required this.met,
  });

  /// Local `YYYY-MM-DD`.
  final String key;

  /// Drills + hands that day.
  final int count;

  /// The daily goal was met — the gold cell.
  final bool met;
}

/// `metGoal(day)` — 20 drills **or** 30 hands.
bool metGoal(DailyActivity? day) =>
    day != null &&
    (day.drills >= kDailyDrillGoal || day.hands >= kDailyHandGoal);

class GoalsStore {
  GoalsStore(this._store);

  final KeyValueStore _store;

  /// The whole map, keyed by [dayKey].
  Map<String, DailyActivity> load() => {
    for (final e in _store.getJsonMap(kGoalsKey).entries)
      e.key: DailyActivity.fromJson(e.value),
  };

  /// Today's counts (zeroes when nothing was done yet).
  DailyActivity today({int? nowMs}) =>
      load()[dayKey(nowMs ?? DateTime.now().millisecondsSinceEpoch)] ??
      const DailyActivity();

  /// Increments today's drill or hand count. Called once per answered drill
  /// and once per finished hand.
  Future<DailyActivity> record(ActivityKind kind, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final all = load();
    final key = dayKey(now);
    final prev = all[key] ?? const DailyActivity();
    final next = DailyActivity(
      drills: prev.drills + (kind == ActivityKind.drill ? 1 : 0),
      hands: prev.hands + (kind == ActivityKind.hand ? 1 : 0),
    );
    all[key] = next;
    await _write(all);
    return next;
  }

  /// Consecutive goal-met days ending today (if today is met) or yesterday.
  ///
  /// Steps back in fixed 86 400 000 ms hops like the desktop, so a DST change
  /// can skip or repeat a calendar day — an accepted quirk (§6.4).
  int streak({int? nowMs}) {
    final all = load();
    var t = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (!metGoal(all[dayKey(t)])) t -= _dayMs;
    var n = 0;
    while (metGoal(all[dayKey(t)])) {
      n++;
      t -= _dayMs;
    }
    return n;
  }

  /// The heatmap grid: `weeks * 7` cells, oldest first, today last.
  List<HeatmapCell> heatmapCells({int weeks = 16, int? nowMs}) {
    final all = load();
    final now = DateTime.fromMillisecondsSinceEpoch(
      nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    final midnight =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final cells = <HeatmapCell>[];
    for (var i = weeks * 7 - 1; i >= 0; i--) {
      final key = dayKey(midnight - i * _dayMs);
      final day = all[key];
      cells.add(
        HeatmapCell(key: key, count: day?.total ?? 0, met: metGoal(day)),
      );
    }
    return cells;
  }

  /// Days with any activity among [cells] — the caption's number.
  static int activeDays(List<HeatmapCell> cells) =>
      cells.where((c) => c.count > 0).length;

  Future<bool> _write(Map<String, DailyActivity> all) => _store.setJson(
    kGoalsKey,
    {for (final e in all.entries) e.key: e.value.toJson()},
  );
}
