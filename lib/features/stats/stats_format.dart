/// Date and time wording for the Stats tab.
///
/// The desktop prints `new Date(h.startedAt).toLocaleString()` in the recent-
/// hands rows; DESIGN.md §7.1 writes the same thing as "Today 18:10", so the
/// row keeps its 56 pt height at 1.3× text scale instead of wrapping a full
/// locale date. Everything here is local time — the hand key is epoch ms and
/// every label derived from it must agree with the practice heatmap, which is
/// keyed by *local* midnight (`docs/port/persistence-stats-settings.md` §7.10).
library;

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Local midnight of [d], the day boundary every "today / yesterday" uses.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days between the two local midnights (negative for the future).
int daysBetween(DateTime from, DateTime to) =>
    startOfDay(to).difference(startOfDay(from)).inDays;

/// "Today 18:10" · "Yesterday 09:03" · "3 Sep 18:10" · "3 Sep 2025 18:10".
String handTimeLabel(int startedAt, {DateTime? now}) {
  final at = DateTime.fromMillisecondsSinceEpoch(startedAt);
  final today = now ?? DateTime.now();
  final days = daysBetween(at, today);
  if (days == 0) return 'Today ${_hhmm(at)}';
  if (days == 1) return 'Yesterday ${_hhmm(at)}';
  final year = at.year == today.year ? '' : ' ${at.year}';
  return '${at.day} ${_months[at.month - 1]}$year ${_hhmm(at)}';
}

/// The P12 sheet's description line — the same instant, spelled out.
String noteDateLabel(int startedAt, {DateTime? now}) {
  final at = DateTime.fromMillisecondsSinceEpoch(startedAt);
  return '${at.day} ${_months[at.month - 1]} ${at.year} · ${_hhmm(at)}';
}

/// "today" · "yesterday" · "3 days ago" · "12 Mar" — the tail of the
/// range-read scrub label (§7.3).
String relativeDayLabel(int ts, {DateTime? now}) {
  final at = DateTime.fromMillisecondsSinceEpoch(ts);
  final today = now ?? DateTime.now();
  final days = daysBetween(at, today);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  return '${at.day} ${_months[at.month - 1]}';
}
