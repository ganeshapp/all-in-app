// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/hand_history.dart';
import 'package:allin/engine/hh_import.dart';
void main() {
  final r = parsePokerStars(File('/tmp/lockstep/frac_hand.txt').readAsStringSync(), now: 1700000000000);
  print(jsonEncode(r.hands[0].toJson()));
  final a = analyzeImported(r.hands, now: 1700000000000);
  print('${a.reviewed} ${jsonEncode(a.leaks.map((l) => l.toJson()).toList())}');
  print(formatHand(r.hands[0]));
  for (final f in buildReplayFrames(r.hands[0])) {
    print('f ${f.street.label}|${f.text}|${f.board.join()}|${f.pot}|${f.folded.join(",")}|${f.revealAll ? 1 : 0}');
  }
}
