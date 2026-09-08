/// Injectable wall clock, so anything that reasons about time (SRS due dates,
/// the daily goal / practice heatmap keys, haptic throttles) can be tested
/// deterministically instead of sleeping.
///
/// DESIGN.md does not name a clock; it is the mechanical consequence of
/// §5.5 (Review "Next due"), §7.11 (practice heatmap day keys) and §11
/// (`selectionClick` "≥ 30 ms apart"), all of which are date/interval logic
/// that must be reproducible in tests.
library;

/// A source of "now". Inject one everywhere a date or an elapsed interval
/// decides behaviour; never call `DateTime.now()` in feature code.
abstract class Clock {
  const Clock();

  /// The system clock — the app-wide default.
  static const Clock system = SystemClock();

  /// Current local time.
  DateTime now();

  /// Milliseconds since the epoch (cheap monotonic-ish stamp for throttles).
  int get nowMs => now().millisecondsSinceEpoch;

  /// `YYYY-MM-DD` in local time — the day key the streak, daily goal and
  /// practice heatmap are bucketed by (desktop `allin.activity.v1`).
  String dayKey() {
    final d = now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m-$day';
  }
}

/// The real clock.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock tests drive by hand: it never advances on its own.
class FakeClock extends Clock {
  FakeClock([DateTime? start])
    : _now = start ?? DateTime.utc(2026, 1, 1, 12).toLocal();

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Move time forward (or back, with a negative duration).
  void advance(Duration d) => _now = _now.add(d);

  /// Jump to an absolute instant.
  void set(DateTime value) => _now = value;
}
