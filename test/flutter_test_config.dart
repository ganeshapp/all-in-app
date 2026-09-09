/// Loads the three bundled families (pubspec.yaml `fonts:`) into every widget
/// test before it runs.
///
/// Without this, `flutter test` paints every string in the built-in test font,
/// whose glyphs are all one em wide. Inter is far narrower, so a test-font
/// layout is not the layout the phone gets: strings that fit on the device
/// wrapped in tests, and — the reason this file exists — the shrink-to-fit
/// arithmetic in `AllInSegmented` and S0's tools grid measured a typeface the
/// app never renders. Any test that asserts something about wrapping,
/// truncation or fitted sizes has to measure Inter.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, String> _families = <String, String>{
  'Inter': 'Inter',
  'Bricolage Grotesque': 'Bricolage',
  'JetBrains Mono': 'JetBrainsMono',
};

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `flutter test` runs with the package root as its working directory.
  final dir = Directory('assets/fonts');
  if (dir.existsSync()) {
    for (final family in _families.entries) {
      final loader = FontLoader(family.key);
      var any = false;
      for (final file in dir.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (!name.endsWith('.ttf') || !name.startsWith(family.value)) continue;
        any = true;
        loader.addFont(
          Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()),
        );
      }
      if (any) await loader.load();
    }
  }

  await testMain();
}
