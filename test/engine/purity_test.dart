import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/engine/` is pure Dart (docs/ARCHITECTURE.md): no Flutter, no dart:ui,
/// no dart:io. This test walks every file under the directory and fails on
/// any offending import/export so the rule cannot regress silently.
void main() {
  const forbidden = ['package:flutter', 'dart:ui', 'dart:io'];
  final directive = RegExp(
    '''^\\s*(import|export)\\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  test('lib/engine has no Flutter, dart:ui or dart:io imports', () {
    final dir = Directory('lib/engine');
    expect(dir.existsSync(), isTrue, reason: 'lib/engine must exist');
    final files =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final violations = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final m in directive.allMatches(source)) {
        final uri = m.group(2)!;
        for (final bad in forbidden) {
          if (uri == bad || uri.startsWith('$bad/')) {
            violations.add('${file.path}: ${m.group(0)!.trim()}');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('lib/engine/engine.dart barrel exports every engine module', () {
    final barrel = File('lib/engine/engine.dart');
    expect(barrel.existsSync(), isTrue, reason: 'barrel must exist');
    final source = barrel.readAsStringSync();
    final exported =
        directive
            .allMatches(source)
            .where((m) => m.group(1) == 'export')
            .map((m) => m.group(2)!)
            .toSet();
    final modules =
        Directory('lib/engine')
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.dart') && n != 'engine.dart')
            .toList()
          ..sort();
    final missing = modules.where((m) => !exported.contains(m)).toList();
    expect(missing, isEmpty, reason: 'not exported: ${missing.join(', ')}');
  });
}
