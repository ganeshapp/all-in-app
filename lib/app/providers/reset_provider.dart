import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Replaces the entire running app after clearing its data. Both Data screens
/// use this callback, installed by AppRuntime outside the scope being reset.
final resetAppProvider = Provider<Future<bool> Function()>((ref) {
  throw StateError('Reset requires AppRuntime.');
});
