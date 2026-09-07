// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/hand_history.dart';

void main() {
  final hands = (jsonDecode(File('/tmp/rev/hh_hands.json').readAsStringSync()) as List)
      .map((j) => HHHand.fromJson((j as Map).cast<String, Object?>()))
      .toList();
  final out = <String>[];
  for (int i = 0; i < hands.length; i++) {
    final h = hands[i];
    out.add('## $i id=${exportHandId(h)}');
    out.add(formatHand(h));
    for (final f in buildReplayFrames(h)) {
      out.add('f|${f.street.label}|${f.text}|${f.board.join(' ')}|${f.pot}|${f.folded.join(',')}|${f.revealAll ? 1 : 0}');
    }
  }
  File('/tmp/rev/hh_dart.txt').writeAsStringSync('${out.join('\n')}\n');
}
