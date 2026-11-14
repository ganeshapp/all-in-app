import 'key_value_store.dart';

/// One running app's access to preferences. Retiring it drains already-issued
/// writes and rejects later ones, including async work from disposed screens.
class StorageLease extends KeyValueStore {
  StorageLease(this._store);

  final KeyValueStore _store;
  final Set<Future<bool>> _writes = {};
  bool _retired = false;

  @override
  String? getString(String key) => _store.getString(key);

  @override
  Set<String> keys() => _store.keys();

  Future<bool> _write(Future<bool> Function() action) async {
    if (_retired) return false;
    final future = action();
    _writes.add(future);
    try {
      return await future;
    } finally {
      _writes.remove(future);
    }
  }

  @override
  Future<bool> setString(String key, String value) =>
      _write(() => _store.setString(key, value));

  @override
  Future<bool> remove(String key) => _write(() => _store.remove(key));

  Future<void> retire() async {
    _retired = true;
    await Future.wait(_writes.toList());
  }
}
