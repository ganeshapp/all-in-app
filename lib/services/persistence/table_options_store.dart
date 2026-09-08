/// Table setup remembered between sessions (docs/port/
/// persistence-stats-settings.md §6.10; DESIGN.md §4.1 lobby).
///
/// One key, `allin.table.v1`: `{ seats: 2|6|9, ante: 0|5 }`, sanitised on
/// load (anything else becomes 6-max, no ante) and saved with the options a
/// session actually used.
library;

import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kTableOptionsKey = 'allin.table.v1';

/// Seats and ante for a new table.
class TableOptions {
  const TableOptions({this.seats = 6, this.ante = 0});

  static const TableOptions defaults = TableOptions();

  /// 2 (heads-up), 6 (6-max) or 9 (9-max).
  final int seats;

  /// Chips posted by every player each hand: 0 (none) or 5 (0.25 bb).
  final int ante;

  /// The lobby's segmented label for [seats].
  String get seatsLabel => switch (seats) {
    2 => 'Heads-up',
    9 => '9-max',
    _ => '6-max',
  };

  TableOptions copyWith({int? seats, int? ante}) =>
      TableOptions(seats: seats ?? this.seats, ante: ante ?? this.ante);

  Map<String, Object?> toJson() => {'seats': seats, 'ante': ante};

  /// `loadTableOptions()`: only 2 and 9 escape the 6-max default, only 5
  /// escapes the no-ante default.
  static TableOptions fromJson(Object? json) {
    if (json is! Map) return defaults;
    final seats = json['seats'];
    final ante = json['ante'];
    return TableOptions(
      seats: (seats == 2 || seats == 9) ? seats! as int : 6,
      ante: ante == 5 ? 5 : 0,
    );
  }
}

class TableOptionsStore {
  TableOptionsStore(this._store);

  final KeyValueStore _store;

  TableOptions load() =>
      TableOptions.fromJson(_store.getJson(kTableOptionsKey));

  Future<bool> save(TableOptions options) =>
      _store.setJson(kTableOptionsKey, options.toJson());
}
