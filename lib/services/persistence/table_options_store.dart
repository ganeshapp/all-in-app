/// Table setup remembered between sessions (docs/port/
/// persistence-stats-settings.md §6.10; DESIGN.md §4.1 lobby).
///
/// One key, `allin.table.v1`: `{ seats: 2|6|9, ante: 0|5, botRebuy: bool }`,
/// sanitised on load (anything else becomes 6-max, no ante, rebuys on) and
/// saved with the options a session actually used.
library;

import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kTableOptionsKey = 'allin.table.v1';

/// Seats and ante for a new table.
class TableOptions {
  const TableOptions({this.seats = 6, this.ante = 0, this.botRebuy = true});

  static const TableOptions defaults = TableOptions();

  /// 2 (heads-up), 6 (6-max) or 9 (9-max).
  final int seats;

  /// Chips posted by every player each hand: 0 (none) or 5 (0.25 bb).
  final int ante;

  /// What happens to a bot that runs out of chips: `true` buys it back in so
  /// the table always has the same number of players, `false` lets it leave
  /// and the table plays down short-handed.
  final bool botRebuy;

  /// The lobby's segmented label for [seats].
  String get seatsLabel => switch (seats) {
    2 => 'Heads-up',
    9 => '9-max',
    _ => '6-max',
  };

  TableOptions copyWith({int? seats, int? ante, bool? botRebuy}) =>
      TableOptions(
        seats: seats ?? this.seats,
        ante: ante ?? this.ante,
        botRebuy: botRebuy ?? this.botRebuy,
      );

  Map<String, Object?> toJson() => {
    'seats': seats,
    'ante': ante,
    'botRebuy': botRebuy,
  };

  /// `loadTableOptions()`: only 2 and 9 escape the 6-max default, only 5
  /// escapes the no-ante default.
  static TableOptions fromJson(Object? json) {
    if (json is! Map) return defaults;
    final seats = json['seats'];
    final ante = json['ante'];
    return TableOptions(
      seats: (seats == 2 || seats == 9) ? seats! as int : 6,
      ante: ante == 5 ? 5 : 0,
      // Anything but an explicit `false` keeps the rebuys an older install
      // was already playing with.
      botRebuy: json['botRebuy'] != false,
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
