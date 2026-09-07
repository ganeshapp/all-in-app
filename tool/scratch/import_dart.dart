// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/hh_import.dart';

void main() {
  const now = 1700000000000;
  final r = parsePokerStars(File('/tmp/rev/import_corpus.txt').readAsStringSync(), now: now);
  final out = <String>[];
  out.add('skipped=${r.skipped} hands=${r.hands.length}');
  for (final h in r.hands) {
    out.add(jsonEncode(h.toJson()));
  }
  final a = analyzeImported(r.hands, now: now);
  out.add('reviewed=${a.reviewed} leaks=${a.leaks.length}');
  for (final l in a.leaks) {
    out.add(jsonEncode(l.toJson()));
  }
  File('/tmp/rev/import_dart.txt').writeAsStringSync('${out.join('\n')}\n');
}
