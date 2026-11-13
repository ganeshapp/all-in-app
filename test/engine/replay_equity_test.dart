import 'package:allin/engine/replay_equity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReplayEquity run(
    Map<int, List<String>?> holes,
    List<String> board, {
    List<int>? active,
  }) => calculateReplayEquity(
    ReplayEquityRequest(
      holes: holes,
      activeSeats: active ?? holes.keys.toList(),
      board: board,
    ),
  );
  test('broadcast example: set versus made straight on turn', () {
    final r = run(
      {
        0: ['Js', 'Jc'],
        1: ['Td', '8d'],
      },
      ['Jh', '9h', '2h', '7c'],
    );
    expect(r.exact, true);
    expect(r.samples, 44);
    expect(r.shares![1], closeTo(34 / 44, 1e-12));
    expect(r.shares!.values.reduce((a, b) => a + b), closeTo(1, 1e-12));
  });
  test('flop enumerates unordered runouts; river winner is certain', () {
    final r = run(
      {
        0: ['As', 'Ah'],
        1: ['Ks', 'Kh'],
      },
      ['Ac', '2c', '7d'],
    );
    expect(r.samples, 990);
    expect(r.exact, true);
    expect(
      run(
        {
          0: ['As', 'Ah'],
          1: ['Ks', 'Kh'],
        },
        ['Ac', '2c', '7d', '8h', '9s'],
      ).shares,
      {0: 1, 1: 0},
    );
  });
  test('three-way board chop divides ties, not three 100% winners', () {
    final r = run(
      {
        0: ['2c', '3c'],
        1: ['4d', '5d'],
        7: ['6h', '7h'],
      },
      ['As', 'Ks', 'Qs', 'Js', 'Ts'],
    );
    for (final share in r.shares!.values) {
      expect(share, closeTo(1 / 3, 1e-12));
    }
  });
  test('folded cards are dead; sole survivor wins even with unknown cards', () {
    final r = run(
      {
        0: ['Js', 'Jc'],
        1: ['Td', '8d'],
        2: ['Qc', 'Qd'],
      },
      ['Jh', '9h', '2h', '7c'],
      active: [0, 1],
    );
    expect(r.samples, 42);
    expect(r.shares![1], closeTo(32 / 42, 1e-12));
    expect(run({0: null, 1: null}, [], active: [1]).shares, {1: 1});
  });
  test(
    'missing live cards and invalid cards never produce invented numbers',
    () {
      expect(
        run({
          0: ['As', 'Ah'],
          1: null,
        }, []).shares,
        null,
      );
      expect(
        run({
          0: ['As', 'Ah'],
          1: ['As', 'Kd'],
        }, []).shares,
        null,
      );
      expect(
        run({
          0: ['As', 'Ah'],
          1: ['XX', 'Kd'],
        }, []).shares,
        null,
      );
    },
  );
  test('preflop is reproducible and ignores map insertion order', () {
    final a = run({
      0: ['As', 'Ah'],
      1: ['Ks', 'Kh'],
    }, []);
    final b = run({
      1: ['Ks', 'Kh'],
      0: ['As', 'Ah'],
    }, []);
    expect(a.exact, false);
    expect(a.shares, b.shares);
    expect(a.shares![0], inInclusiveRange(.79, .84));
  });
}
