/// Malmuth-Harville ICM: convert stacks into shares of the prize pool.
/// Standard tournament-equity model — P(player finishes next) is
/// proportional to stack, applied recursively down the payout places.
///
/// Ported 1:1 from the desktop `src/lib/icm.ts` (same recursion and summation
/// order, so results match bit-for-bit). The bubble push/fold tables built on
/// top of this live in `lib/data/icm_scenarios.g.dart`.
library;

/// Each player's expected share of the prize pool, in the units of [payouts].
/// Busted (zero) stacks get 0; players beyond `payouts.length` places earn
/// nothing for those finishes.
List<double> icmShares(List<num> stacks, List<num> payouts) {
  final n = stacks.length;
  final st = List<double>.generate(n, (i) => stacks[i].toDouble());
  final pay = List<double>.generate(
    payouts.length,
    (i) => payouts[i].toDouble(),
  );
  final shares = List<double>.filled(n, 0);

  void rec(List<int> remaining, int place, double prob) {
    if (prob < 1e-12 || place >= pay.length) return;
    var total = 0.0;
    for (final i in remaining) {
      total += st[i];
    }
    if (total <= 0) return;
    for (final i in remaining) {
      if (st[i] <= 0) continue;
      final p = prob * (st[i] / total);
      shares[i] += p * pay[place];
      rec(remaining.where((x) => x != i).toList(), place + 1, p);
    }
  }

  rec(
    [
      for (var i = 0; i < n; i++)
        if (st[i] > 0) i,
    ],
    0,
    1,
  );
  return shares;
}
