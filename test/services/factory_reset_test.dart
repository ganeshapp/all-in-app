import 'dart:async';
import 'dart:io';

import 'package:allin/services/persistence.dart';
import 'package:allin/services/persistence/storage_lease.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'reset clears all SQLite tables and retires old database access',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('allin_reset');
      addTearDown(() => dir.delete(recursive: true));
      final old = AppDatabase(
        factory: databaseFactoryFfi,
        path: '${dir.path}/data.db',
      );
      final handle = await old.open();
      for (final table in ['hand_history', 'range_guess', 'decisions']) {
        await handle.insert(table, {'ts': 123});
      }
      await handle.insert('sessions', {
        'started_at': 1,
        'ended_at': 2,
        'seats': 6,
      });
      await handle.update('user_stats', {
        'hands_played': 10,
        'net_chips': 200,
        'big_blind': 100,
      });
      // Queue a write just before reset, as an ending hand could do.
      final pending = handle.insert('decisions', {'ts': 456});
      await old.retire();
      await pending;
      final fresh = old.freshHandle();
      addTearDown(fresh.close);
      await fresh.eraseAllData();
      await expectLater(old.open(), throwsStateError);
      expect(() => old.db, throwsStateError);
      expect(() => handle.insert('decisions', {'ts': 789}), throwsA(anything));
      for (final table in [
        'hand_history',
        'range_guess',
        'decisions',
        'sessions',
        'sqlite_sequence',
      ]) {
        expect(await fresh.db.query(table), isEmpty, reason: table);
      }
      expect(await fresh.db.query('user_stats'), [
        {'id': 1, 'hands_played': 0, 'net_chips': 0, 'big_blind': 20},
      ]);
      await fresh.db.insert('sessions', {
        'started_at': 3,
        'ended_at': 4,
        'seats': 6,
      });
      expect((await fresh.db.query('sessions')).single['id'], 1);
    },
  );

  test(
    'retiring preferences waits for old writes and refuses future saves',
    () async {
      final store = _DelayedStore();
      final old = StorageLease(store);
      final pending = old.setString('allin.session.v1', 'old session');
      var drained = false;
      final retiring = old.retire().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      expect(await old.setString('allin.drills.v1', 'late'), isFalse);
      store.release.complete();
      await pending;
      await retiring;
      await store.clearAllInKeys();
      expect(store.keys(), isEmpty);
      expect(await old.setString('allin.session.v1', 'resurrected'), isFalse);
      final fresh = StorageLease(store);
      expect(await fresh.setString('allin.session.v1', 'new'), isTrue);
    },
  );
}

class _DelayedStore extends MemoryKeyValueStore {
  final release = Completer<void>();
  @override
  Future<bool> setString(String key, String value) async {
    await release.future;
    return super.setString(key, value);
  }
}
