import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/puzzles.dart';
void main() {
  final out = <String>[];
  for (var rating = 0; rating <= 3000; rating++) {
    for (final dif in [1, 2, 3]) {
      for (final c in [true, false]) {
        final d = eloDelta(rating, dif, c);
        out.add(jsonEncode([rating, dif, c, d, applyRatingDelta(rating, d)]));
      }
    }
  }
  File('/tmp/pz/dart_elo.txt').writeAsStringSync(out.join('\n'));
  stdout.writeln(out.length);
}
