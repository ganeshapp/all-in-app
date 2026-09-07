import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/format.dart';
void main() {
  final out = <String>[];
  final vals = <List<num>>[];
  for (var k = 1; k <= 64; k++) {
    for (final d in [0, 1, 2, 3]) {
      vals.addAll([[k / 2, d], [-k / 2, d], [k / 4, d], [-k / 4, d], [k / 8, d], [-k / 8, d], [k / 16, d], [-k / 16, d]]);
    }
  }
  for (final e in vals) {
    final v = e[0].toDouble(); final d = e[1].toInt();
    out.add(jsonEncode([v == v.truncateToDouble() ? v.toInt() : v, d, jsToFixed(v, d)]));
  }
  File('/tmp/pz/dart_fixed.txt').writeAsStringSync(out.join('\n'));
  stdout.writeln(out.length);
}
