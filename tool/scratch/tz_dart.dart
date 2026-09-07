// ignore_for_file: avoid_print
import 'package:allin/engine/hand_history.dart';
void main() {
  const cases = [
    [2024,3,10,2,30,0],[2024,3,10,3,0,0],[2024,11,3,1,30,0],[2024,11,3,2,0,0],
    [1970,1,1,0,0,0],[2038,1,19,3,14,7],[1999,12,31,23,59,59],[2024,2,29,0,0,0],
  ];
  for (final c in cases) {
    final t = DateTime(c[0],c[1],c[2],c[3],c[4],c[5]).millisecondsSinceEpoch;
    print('${c[0]}-${c[1]}-${c[2]} ${c[3]}:${c[4]}:${c[5]} -> $t -> ${psDate(t)}');
  }
}
