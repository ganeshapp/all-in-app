// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/hh_import.dart';

void main() {
  const now = 1700000000000;
  final r = parsePokerStars(File('/tmp/rev/corpus2.txt').readAsStringSync(), now: now);
  final out = <String>['skipped=${r.skipped} hands=${r.hands.length}'];
  for (final h in r.hands) {
    out.add(jsonEncode(h.toJson()));
    out.add(formatHand(h));
    for (final f in buildReplayFrames(h)) {
      out.add('f|${f.street.label}|${f.text}|${f.pot}');
    }
  }
  final a = analyzeImported(r.hands, now: now);
  out.add('reviewed=${a.reviewed} leaks=${a.leaks.length}');
  for (final l in a.leaks) {
    out.add(jsonEncode(l.toJson()));
  }
  File('/tmp/rev/import_dart2.txt').writeAsStringSync('${out.join('\n')}\n');
}
