import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/persistence/app_database.dart';
import '../services/persistence/key_value_store.dart';
import '../services/persistence/storage_lease.dart';
import '../theme/app_theme.dart';
import 'app.dart';
import 'reset_copy.dart';
import 'providers/app_providers.dart';
import 'providers/reset_provider.dart';

/// Owns the provider scope so a factory reset also discards cached progress,
/// navigation, coach work and live table timers, exactly as a fresh launch.
class AppRuntime extends StatefulWidget {
  const AppRuntime({
    super.key,
    required this.store,
    this.database,
    this.overrides = const [],
    this.child = const AllInApp(),
  });

  final KeyValueStore store;
  final AppDatabase? database;
  final List<Override> overrides;
  final Widget child;

  @override
  State<AppRuntime> createState() => _AppRuntimeState();
}

class _AppRuntimeState extends State<AppRuntime> {
  late StorageLease _lease = StorageLease(widget.store);
  late AppDatabase? _database = widget.database;
  bool _resetting = false;
  bool _failed = false;
  int _generation = 0;

  Future<bool> _reset() async {
    if (_resetting && !_failed) return false;
    setState(() {
      _resetting = true;
      _failed = false;
    });
    // Immediately fence old writes, then unmount the whole scope before
    // erasing. SQLite is closed too: a captured old handle cannot write into
    // the new database, and its fallback preferences lease is retired.
    final drained = _lease.retire();
    await WidgetsBinding.instance.endOfFrame;
    try {
      await drained;
      final oldDatabase = _database;
      if (oldDatabase != null) {
        await oldDatabase.retire();
        _database = oldDatabase.freshHandle();
        await _database!.eraseAllData();
      }
      await widget.store.clearAllInKeys();
      if (!mounted) return false;
      _restart();
      return true;
    } catch (_) {
      // Never report success if either storage backend refused the erase.
      // Stay outside the old scope; retry cannot revive a pending old save.
      if (mounted) setState(() => _failed = true);
      return false;
    }
  }

  void _restart() {
    setState(() {
      _lease = StorageLease(widget.store);
      _generation++;
      _resetting = false;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resetting) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AllInAppTheme.dark(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_failed) const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      _failed ? AppResetCopy.failed : AppResetCopy.resetting,
                      textAlign: TextAlign.center,
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _reset,
                        child: const Text(AppResetCopy.retry),
                      ),
                      TextButton(
                        onPressed: _restart,
                        child: const Text(AppResetCopy.back),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ProviderScope(
      key: ValueKey(_generation),
      overrides: [
        keyValueStoreProvider.overrideWithValue(_lease),
        appDatabaseProvider.overrideWithValue(_database),
        resetAppProvider.overrideWithValue(_reset),
        ...widget.overrides,
      ],
      child: widget.child,
    );
  }
}
