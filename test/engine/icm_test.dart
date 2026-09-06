// Port of the Malmuth-Harville part of the desktop scripts/icm_test.ts plus
// exact outputs pinned from running src/lib/icm.ts under Node 23. The
// bubble-table qualitative assertions of that script exercise the generated
// scenario tables and belong with the drills module.
import 'package:allin/engine/icm.dart';
import 'package:flutter_test/flutter_test.dart';

import 'format_ref.dart';

double sum(List<double> xs) => xs.fold(0.0, (a, b) => a + b);

void main() {
  const payouts = [0.5, 0.3, 0.2];

  test('equal stacks split the pool equally and shares sum to the pool', () {
    final even = icmShares([25, 25, 25, 25], payouts);
    for (final x in even) {
      expect(x, closeTo(0.25, 1e-9));
    }
    expect(sum(even), closeTo(1, 1e-9));
  });

  test('a monster stack is worth less than first-place money', () {
    final dom = icmShares([90, 4, 3, 3], payouts);
    expect(dom[0], lessThan(0.5));
    expect(dom[0], greaterThan(0.4));
  });

  test(
    'a busted stack has zero equity; the pool is still fully distributed',
    () {
      final bust = icmShares([0, 40, 30, 30], payouts);
      expect(bust[0], 0);
      expect(sum(bust), closeTo(1, 1e-9));
    },
  );

  test('doubling up is worth less than 2x — the heart of ICM', () {
    final base = icmShares([20, 20, 30, 30], payouts)[0];
    final doubled = icmShares([40, 0, 30, 30], payouts)[0];
    expect(doubled, lessThan(2 * base));
  });

  test(
    'edge cases: no payouts, more payouts than players, all-but-one busted',
    () {
      expect(icmShares([10, 20, 30], []), [0.0, 0.0, 0.0]);
      expect(icmShares([10, 20, 30], [1, 1, 1]), [1.0, 1.0, 1.0]);
      expect(icmShares([0, 0, 5], payouts), [0.0, 0.0, 0.5]);
      expect(icmShares([], payouts), isEmpty);
    },
  );

  test(
    'pinned bit-for-bit against the TypeScript (${kIcmRef.length} cases)',
    () {
      for (final (stacks, pay, want) in kIcmRef) {
        final got = icmShares(stacks, pay);
        expect(got.length, want.length);
        for (var i = 0; i < want.length; i++) {
          expect(got[i], want[i], reason: 'icmShares($stacks, $pay)[$i]');
        }
      }
    },
  );
}
