/// App entry point (docs/ARCHITECTURE.md "Layout"): portrait lock, system UI
/// overlay style, on-device storage opened before the first frame, then the
/// `ProviderScope` around [AllInApp].
library;

import 'package:allin/app/app.dart';
import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/services/persistence/app_database.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/settings_store.dart';
import 'package:allin/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-first phone app; landscape is not supported (§14).
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Settings and the theme are key-value (desktop parity), read before the
  // first frame so the app never flashes the wrong theme.
  final store = await KeyValueStore.open();
  SystemChrome.setSystemUIOverlayStyle(_overlayStyle(ThemeStore(store).load()));

  // Hands, stats, reads and decisions live in sqflite. If the file cannot be
  // opened the app still runs: the repositories fall back to the key-value
  // store and the user sees the §14 "Some data couldn't be saved" toast.
  final database = AppDatabase();
  var databaseReady = true;
  try {
    await database.open();
  } catch (_) {
    databaseReady = false;
  }

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(databaseReady ? database : null),
      ],
      child: const AllInApp(),
    ),
  );
}

/// Transparent bars so the felt and the tab bar own the safe areas; icon
/// brightness follows the chosen theme.
SystemUiOverlayStyle _overlayStyle(AppThemeMode theme) {
  final dark = theme == AppThemeMode.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor:
        dark ? AllInColors.dark.ink850 : AllInColors.light.ink850,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}
