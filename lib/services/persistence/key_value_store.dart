/// Key-value storage — the mobile stand-in for the desktop's `localStorage`
/// (DESIGN.md §16.4 "JSON stores via `shared_preferences`";
/// docs/port/persistence-stats-settings.md §6 catalogues every key).
///
/// One JSON value per key, all prefixed `allin.`, byte-identical to the
/// desktop so a backup round-trips. Every read is total (a missing, empty or
/// corrupt value yields the caller's default) and every write swallows its
/// error and reports `false`, exactly like the TypeScript stores that wrap
/// `JSON.parse` in try/catch and ignore quota exceptions.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The `allin.` prefix every key in the catalogue shares.
const String kAllInKeyPrefix = 'allin.';

/// A tiny string/JSON store. Nothing here ever throws.
abstract class KeyValueStore {
  const KeyValueStore();

  /// The `shared_preferences`-backed store used by the app.
  static Future<KeyValueStore> open() async =>
      SharedPreferencesKeyValueStore(await SharedPreferences.getInstance());

  /// An in-memory store for tests and for the "storage unavailable" fallback.
  factory KeyValueStore.memory([Map<String, String>? seed]) =
      MemoryKeyValueStore;

  /// Raw string value, or null when absent (or unreadable).
  String? getString(String key);

  /// Writes a raw string. Returns false when the write failed.
  Future<bool> setString(String key, String value);

  /// Removes [key]. Returns false when the write failed.
  Future<bool> remove(String key);

  /// Every key currently present.
  Set<String> keys();

  /// Decoded JSON for [key], or null when absent/corrupt.
  Object? getJson(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// [getJson] narrowed to a map; an empty map on anything else.
  Map<String, Object?> getJsonMap(String key) {
    final v = getJson(key);
    return v is Map ? v.cast<String, Object?>() : <String, Object?>{};
  }

  /// [getJson] narrowed to a list; an empty list on anything else.
  List<Object?> getJsonList(String key) {
    final v = getJson(key);
    return v is List ? v : const <Object?>[];
  }

  /// Encodes [value] as compact JSON (no indentation, like the desktop's
  /// `JSON.stringify`) and stores it.
  Future<bool> setJson(String key, Object? value) {
    try {
      return setString(key, jsonEncode(value));
    } catch (_) {
      return Future<bool>.value(false);
    }
  }

  /// Removes every `allin.`-prefixed key. Used by tests and by a full wipe;
  /// no product flow calls it (Reset is deliberately narrower, DESIGN §7.10).
  Future<void> clearAllInKeys() async {
    for (final k in keys().where((k) => k.startsWith(kAllInKeyPrefix))) {
      await remove(k);
    }
  }
}

/// [KeyValueStore] over `shared_preferences`.
class SharedPreferencesKeyValueStore extends KeyValueStore {
  SharedPreferencesKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) {
    try {
      return _prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      return await _prefs.setString(key, value);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      return await _prefs.remove(key);
    } catch (_) {
      return false;
    }
  }

  @override
  Set<String> keys() {
    try {
      return _prefs.getKeys();
    } catch (_) {
      return const <String>{};
    }
  }
}

/// [KeyValueStore] backed by a plain map — tests, and the last-resort store
/// when `shared_preferences` itself is unavailable.
class MemoryKeyValueStore extends KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? seed])
    : _values = {...?seed},
      _writable = true;

  /// A store whose writes always fail — exercises the "quota exceeded" paths.
  MemoryKeyValueStore.readOnly([Map<String, String>? seed])
    : _values = {...?seed},
      _writable = false;

  final Map<String, String> _values;
  final bool _writable;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    if (!_writable) return false;
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (!_writable) return false;
    _values.remove(key);
    return true;
  }

  @override
  Set<String> keys() => _values.keys.toSet();
}
