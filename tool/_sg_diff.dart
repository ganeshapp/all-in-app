import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/coach.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/prng.dart';
void main() {
  final r = Mulberry32(999);
  int ri(int n) => (r.next() * n).toInt();
  final labels = allLabels();
  final out = <String>[];
  for (var i = 0; i < 800; i++) {
    List<String> mk() {
      final n = ri(70);
      return [for (var k = 0; k < n; k++) labels[ri(169)]];
    }
    final painted = i % 9 == 0 ? <String>[] : mk();
    final actual = i % 11 == 0 ? <String>[] : mk();
    final s = scoreGuess(painted, actual);
    out.add(jsonEncode([painted, actual, {'accuracy': s.accuracy, 'precision': s.precision, 'recall': s.recall}]));
  }
  stdout.write(out.join('\n'));
}
