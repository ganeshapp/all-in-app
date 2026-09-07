// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:allin/engine/bot_brain.dart';
import 'package:allin/engine/types.dart';

void main() {
  final cases = jsonDecode(File('/tmp/rev/nr_cases.json').readAsStringSync()) as List;
  const kinds = {'aggro': NarrowKind.aggro, 'call': NarrowKind.call, 'check': NarrowKind.check};
  final out = <String>[];
  for (int k = 0; k < cases.length; k++) {
    final c = cases[k] as Map<String, dynamic>;
    final stored = (c['stored'] as List).cast<HandLabel>();
    final board = (c['board'] as List).cast<Card>();
    final kind = kinds[c['kind'] as String]!;
    final actual = c['actual'] as HandLabel;
    final res = narrowRange(stored, board, kind, actual);
    out.add('$k|${c['kind']}|$actual|${board.join(' ')}|${stored.join(',')}|=>|${res.join(',')}');
  }
  File('/tmp/rev/nr_dart.txt').writeAsStringSync('${out.join('\n')}\n');
}
