// EV coach tests. Reference verdicts/strings in coach_ref.dart were produced
// by running the desktop `evaluateHero` (src/store/gameStore.ts) under Node 23
// with the equity facade stubbed to fixed results — the same stubs are used
// here, so every review must match the TypeScript byte for byte.
import 'dart:math';

import 'package:allin/engine/coach.dart';
import 'package:allin/engine/equity.dart';
import 'package:allin/engine/hand_engine.dart';
import 'package:allin/engine/prng.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coach_ref.dart';

const GameConfig kConfig = GameConfig(
  seats: 6,
  startingStack: 2000,
  smallBlind: 10,
  bigBlind: 20,
);

/// Mirror of the reference script's `Spec` / `makeState`.
class Spec {
  const Spec({
    required this.button,
    required this.hole,
    this.street,
    this.board = const [],
    this.pot = 0,
    this.currentBet = 0,
    this.aggressor,
    this.folded = const [],
    this.committed = const {},
    this.botRanges = const {},
  });
  final int button;
  final List<Card> hole;
  final Street? street;
  final List<Card> board;
  final int pot;
  final int currentBet;
  final int? aggressor;
  final List<int> folded;
  final Map<int, int> committed;
  final Map<int, List<HandLabel>> botRanges;

  Spec copyWith({
    int? currentBet,
    int? aggressor,
    bool clearAggressor = false,
    Map<int, int>? committed,
    Map<int, List<HandLabel>>? botRanges,
  }) => Spec(
    button: button,
    hole: hole,
    street: street,
    board: board,
    pot: pot,
    currentBet: currentBet ?? this.currentBet,
    aggressor: clearAggressor ? null : (aggressor ?? this.aggressor),
    folded: folded,
    committed: committed ?? this.committed,
    botRanges: botRanges ?? this.botRanges,
  );
}

TableState makeState(Spec sp) {
  final t = createTable(kConfig, rng: Random(1));
  t.button = sp.button;
  final s = startHand(t, rng: Random(1));
  s.players[0].hole = List<Card>.of(sp.hole);
  if (sp.street != null) {
    s.street = sp.street!;
    s.board = List<Card>.of(sp.board);
    s.pot = sp.pot;
    s.currentBet = sp.currentBet;
    s.aggressor = sp.aggressor;
    for (final p in s.players) {
      p.committed = 0;
    }
    sp.committed.forEach((seat, v) => s.players[seat].committed = v);
  }
  for (final f in sp.folded) {
    s.players[f].hasFolded = true;
  }
  sp.botRanges.forEach((seat, r) => s.botRanges[seat] = List.of(r));
  s.toAct = 0;
  return s;
}

EquityResult r(double equity, double se, int samples, bool exact) =>
    EquityResult(
      equity: equity,
      win: 0,
      tie: 0,
      lose: 0,
      samples: samples,
      se: se,
      exact: exact,
    );

typedef Stub = EquityResult Function(EquityRequest req, int n);

class Scenario {
  const Scenario(this.spec, this.action, this.stub, {this.settings});
  final Spec spec;
  final Action action;
  final Stub stub;
  final CoachSettings? settings;
}

const Spec flopVs1 = Spec(
  button: 3,
  hole: ['As', 'Ks'],
  street: Street.flop,
  board: ['Kh', '7d', '2c'],
  pot: 200,
  currentBet: 100,
  aggressor: 1,
  folded: [2, 3, 4, 5],
  committed: {1: 100},
);

const Spec riverCheck = Spec(
  button: 3,
  hole: ['As', 'Ks'],
  street: Street.river,
  board: ['Kh', '7d', '2c', '9s', '3h'],
  pot: 300,
  folded: [2, 3, 4, 5],
);

const Spec flopCheck = Spec(
  button: 3,
  hole: ['As', 'Ks'],
  street: Street.flop,
  board: ['Kh', '7d', '2c'],
  pot: 100,
  folded: [2, 3, 4, 5],
);

final Map<String, Scenario> scenarios = {
  'foldSpill': Scenario(
    flopVs1,
    const Action.fold(),
    (_, _) => r(0.8, 0.01, 1600, false),
  ),
  'badCall': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => r(0.25, 0.01, 1600, false),
  ),
  'thinCall': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => r(0.35, 0.01, 1600, false),
  ),
  'greatCall': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => r(0.8, 0.01, 1600, false),
  ),
  'okCall': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => r(0.45, 0.012, 1600, false),
  ),
  'noiseCall': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => r(0.3, 0.03, 1600, false),
  ),
  'missedValueRiver': Scenario(
    riverCheck,
    const Action.check(),
    (_, _) => r(0.9, 0, 990, true),
  ),
  'missedValueRiverThin': Scenario(
    riverCheck,
    const Action.check(),
    (_, _) => r(0.7, 0, 990, true),
  ),
  'expensiveBluff': Scenario(
    const Spec(
      button: 3,
      hole: ['5h', '4h'],
      street: Street.flop,
      board: ['Kh', '7d', '2c'],
      pot: 100,
      folded: [4, 5],
    ),
    const Action.bet(100),
    (_, _) => r(0.15, 0.01, 1600, false),
  ),
  'valueBet': Scenario(
    const Spec(
      button: 3,
      hole: ['As', 'Ks'],
      street: Street.turn,
      board: ['Kh', '7d', '2c', '9s'],
      pot: 200,
      folded: [2, 3, 4, 5],
    ),
    const Action.bet(130),
    (_, _) => r(0.75, 0, 44000, true),
  ),
  'bluffRaise': Scenario(
    const Spec(
      button: 3,
      hole: ['5h', '4h'],
      street: Street.flop,
      board: ['Kh', '7d', '2c'],
      pot: 150,
      currentBet: 50,
      aggressor: 1,
      folded: [2, 3, 4, 5],
      committed: {1: 50},
    ),
    const Action.raise(200),
    (_, _) => r(0.3, 0.02, 1600, false),
  ),
  'solidBet': Scenario(
    const Spec(
      button: 3,
      hole: ['Qs', 'Js'],
      street: Street.flop,
      board: ['Kh', '7d', '2c'],
      pot: 100,
      folded: [2, 3, 4, 5],
    ),
    const Action.bet(40),
    (_, _) => r(0.5, 0.012, 1600, false),
  ),
  'preflopFieldCall': Scenario(
    const Spec(button: 3, hole: ['As', 'Ks']),
    const Action.call(),
    (_, _) => r(0.55, 0.012, 1600, false),
  ),
  'escalation': Scenario(
    flopVs1,
    const Action.call(),
    (_, n) =>
        n == 1 ? r(0.34, 0.012, 1600, false) : r(0.36, 0.006, 6400, false),
  ),
  'storedRange': Scenario(
    flopVs1.copyWith(
      botRanges: {
        1: ['AA', 'KK', 'AKs', 'AKo', 'QQ'],
      },
    ),
    const Action.call(),
    (_, _) => r(0.8, 0, 44000, true),
  ),
  'runnerThrows': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => throw StateError('boom'),
  ),
  'relaxedBadCall': Scenario(
    flopVs1,
    const Action.call(),
    (_, _) => r(0.29, 0.005, 4000, false),
    settings: const CoachSettings(
      strictness: CoachStrictness.relaxed,
      simQuality: SimQuality.high,
    ),
  ),
  'strictFold': Scenario(
    flopVs1,
    const Action.fold(),
    (_, _) => r(0.42, 0.005, 1600, false),
    settings: const CoachSettings(strictness: CoachStrictness.strict),
  ),
  'standardFoldNoNote': Scenario(
    flopVs1,
    const Action.fold(),
    (_, _) => r(0.42, 0.005, 1600, false),
  ),
  'foldFree': Scenario(
    flopVs1.copyWith(currentBet: 0, committed: {}, clearAggressor: true),
    const Action.fold(),
    (_, _) => r(0.8, 0.01, 1600, false),
  ),
  'checkPreflop': Scenario(
    const Spec(button: 0, hole: ['As', 'Ks']),
    const Action.check(),
    (_, _) => r(0.9, 0.01, 1600, false),
  ),
  'checkFlopMedium': Scenario(
    flopCheck,
    const Action.check(),
    (_, _) => r(0.7, 0.01, 1600, false),
  ),
  'checkFlopStrong': Scenario(
    flopCheck,
    const Action.check(),
    (_, _) => r(0.9, 0.01, 1600, false),
  ),
};

Map<String, Object?> callJson(EquityRequest c) => {
  'mode': c.mode.label,
  'hero': c.hero,
  'board': c.board,
  if (c.mode == EquityMode.range) 'rangeLen': c.range.length,
  if (c.mode == EquityMode.field) 'opponents': c.opponents,
  'iters': c.iters,
  'seed': c.seed,
};

Future<(CoachReview?, List<EquityRequest>)> runScenario(Scenario sc) async {
  final calls = <EquityRequest>[];
  final review = await evaluateHero(
    makeState(sc.spec),
    sc.action,
    7,
    settings: sc.settings ?? CoachSettings.defaults,
    runEquity: (req) {
      calls.add(req);
      return sc.stub(req, calls.length);
    },
  );
  return (review, calls);
}

void main() {
  final refScenarios = kCoachRef['scenarios'] as Map<String, Object?>;

  test('reference covers every scenario and vice versa', () {
    expect(scenarios.keys.toSet(), refScenarios.keys.toSet());
  });

  test('seat names / archetypes / positions match the desktop table', () {
    final s = makeState(const Spec(button: 3, hole: ['As', 'Ks']));
    final seats = [
      for (final p in s.players)
        {
          'id': p.id,
          'name': p.name,
          if (p.archetype != null) 'archetype': p.archetype!.label,
          'position': p.position.label,
        },
    ];
    expect(seats, kCoachRef['seats']);
    expect(firstOpponentInHand(makeState(flopVs1)), kCoachRef['firstOpp']);
  });

  group('evaluateHero matches the desktop review', () {
    for (final entry in scenarios.entries) {
      test(entry.key, () async {
        final expected = refScenarios[entry.key] as Map<String, Object?>;
        final (review, calls) = await runScenario(entry.value);
        expect(review?.toJson(), expected['review']);
        expect(calls.map(callJson).toList(), expected['calls']);
      });
    }
  });

  group('verdict rules', () {
    Future<CoachReview?> run(String name) async =>
        (await runScenario(scenarios[name]!)).$1;

    test('fold spill', () async {
      final v = (await run('foldSpill'))!;
      expect(v.verdict, Verdict.mistake);
      expect(v.blocking, isFalse);
      expect(v.title, 'Fold spills value');
      expect(v.evChips, 140);
      expect(v.potOdds, closeTo(1 / 3, 1e-12));
      expect(
        v.plain,
        'You folded a moneymaker. Calling 5 bb to win a 15 bb pot only needs a win about 1 time in 3 — and your hand wins about 8 times in 10. That call was worth about +7.0 bb.',
      );
      expect(v.expert![0], 'Ivey (TAG) range ≈ 204 combos (position + action).');
      expect(
        v.expert![1],
        'Simulation precision: ±2.0% on the equity (1,600 trials).',
      );
    });

    test('blocking bad call carries its own minus sign (-1.3 bb)', () async {
      final v = (await run('badCall'))!;
      expect(v.verdict, Verdict.mistake);
      expect(v.blocking, isTrue);
      expect(v.title, 'Your call');
      expect(v.evChips, -25);
      expect(
        v.text,
        "Against Ivey's range your AKs has only 25% equity, but calling needs 33%. This call costs about -1.3 bb — folding is better.",
      );
      expect(
        v.plain,
        'You paid 5 bb to win a pot of 15 bb — you need to win about 1 time in 3. Your hand wins about 1 time in 4 — not enough. Over time this call loses money; folding is better.',
      );
      expect(v.steps![3], 'Because EV < 0, folding is the higher-EV play.');
    });

    test('thin call escalates the sim near the line', () async {
      final (v, calls) = await runScenario(scenarios['thinCall']!);
      expect(v!.verdict, Verdict.thin);
      expect(v.blocking, isFalse);
      expect(calls.length, 2);
      expect(calls[1].iters, 6400);
      expect(calls[1].seed, calls[0].seed + 1);
      expect(
        v.plain,
        'You paid 5 bb to win a pot of 15 bb — you need to win about 1 time in 3. Your hand wins about 1 time in 3 — just barely enough. A close call, not a mistake.',
      );
    });

    test('great call', () async {
      final v = (await run('greatCall'))!;
      expect(v.verdict, Verdict.great);
      expect(
        v.text,
        "80% equity vs Ivey's range, needing 33% — a clear call worth +7.0 bb.",
      );
      expect(v.steps![3], 'Because EV > 0, calling beats folding.');
    });

    test('inside the noise band a losing call is only thin', () async {
      final v = (await run('noiseCall'))!;
      expect(v.verdict, Verdict.thin);
      expect(
        v.plain,
        'Genuinely too close to call: the numbers say roughly break-even here. Either choice is fine.',
      );
      expect(
        v.text,
        "Looks slightly losing (~-0.5 bb), but it's within the simulation's margin of error — either choice is reasonable here.",
      );
    });

    test('missed value on the river', () async {
      final v = (await run('missedValueRiver'))!;
      expect(v.verdict, Verdict.mistake);
      expect(v.title, 'Missed value');
      expect(v.potOdds, isNull);
      expect(v.evChips, isNull);
      expect(
        v.text,
        '90% equity checked on the river — a value bet (~198 chips) was available.',
      );
      expect(
        v.expert!.last,
        'Post-flop aggression verdicts are heuristic (no solver) — treat as guidance, not gospel.',
      );
      expect(
        v.expert![1],
        "Exact count — every possible holding and runout was enumerated, so there's no simulation noise.",
      );
      final thin = (await run('missedValueRiverThin'))!;
      expect(thin.verdict, Verdict.thin);
      expect(
        thin.plain,
        'Your hand wins about 7 times in 10 — usually strong enough for a small value bet here. Checking is cautious but leaves some money behind.',
      );
    });

    test('check rules: preflop / medium flop → null, strong flop → mistake', () async {
      expect(await run('checkPreflop'), isNull);
      expect(await run('checkFlopMedium'), isNull);
      final v = (await run('checkFlopStrong'))!;
      expect(v.verdict, Verdict.mistake);
      expect(
        v.text,
        '90% equity checked back — a value bet (~66 chips) was available.',
      );
    });

    test('expensive bluff (multiway fold-equity model)', () async {
      final v = (await run('expensiveBluff'))!;
      expect(v.verdict, Verdict.mistake);
      expect(v.title, 'Expensive bluff');
      expect(v.multiway, isTrue);
      expect(v.opponents, 3);
      expect(v.evChips, closeTo(-25.0, 1e-9));
      expect(
        v.plain,
        "A very expensive bluff: if anyone calls, your hand wins only about 1 time in 7, and with 3 opponents someone usually calls. You'd need folds about 5 times in 10 just to break even — this bet loses money over time.",
      );
      expect(
        v.text,
        'Bluffing 100% pot with 15% equity vs the 3-player field: estimated EV -1.3 bb.',
      );
      expect(
        v.steps![3],
        'EV ≈ 20% × 100 + 80% × (15% × 300 − 100) ≈ -25 chips.',
      );
      expect(
        v.expert![0],
        'Equity is run against 3 opponents as random hands (1600-trial sim) — more players, lower equity.',
      );
    });

    test('value bet', () async {
      final v = (await run('valueBet'))!;
      expect(v.verdict, Verdict.great);
      expect(v.title, 'Your bet');
      expect(v.evChips, closeTo(0.75 * 330 - 130, 1e-9));
      expect(
        v.plain,
        'Betting with the goods: if someone calls, your hand wins about 8 times in 10. Money goes in with the best of it — and every fold is profit too.',
      );
      expect(v.text, "Strong value — 75% equity vs Ivey's range. Betting is correct.");
      expect(
        v.steps![1],
        'A bet also wins when opponents fold — fold equity isn\'t shown here, so treat this as the "called" floor.',
      );
    });

    test('bluff raise is thin, solid bet is ok', () async {
      final raise = (await run('bluffRaise'))!;
      expect(raise.verdict, Verdict.thin);
      expect(raise.title, 'Your raise');
      expect(
        raise.text,
        'Aggressive: only 30% equity if called. Works as a bluff but relies on folds.',
      );
      final bet = (await run('solidBet'))!;
      expect(bet.verdict, Verdict.ok);
      expect(bet.title, 'Your bet');
      expect(
        bet.text,
        "50% equity vs Ivey's range — a reasonable bet — worse hands may call, and every fold wins you the pot.",
      );
    });

    test('fold rules: no note below foldFlagBb, never when free', () async {
      expect(await run('standardFoldNoNote'), isNull);
      expect((await run('strictFold'))!.verdict, Verdict.mistake);
      expect(await run('foldFree'), isNull);
    });

    test('runner failure falls back to equity 0.5', () async {
      final v = (await run('runnerThrows'))!;
      expect(v.equity, 0.5);
      expect(v.verdict, Verdict.ok);
      expect(
        v.expert![1],
        'Simulation precision: ±0.0% on the equity (0 trials).',
      );
    });

    test('stored bot range beats the archetype fallback', () async {
      final (v, calls) = await runScenario(scenarios['storedRange']!);
      expect(v!.villainRange, ['AA', 'KK', 'AKs', 'AKo', 'QQ']);
      expect(calls.single.range, ['AA', 'KK', 'AKs', 'AKo', 'QQ']);
      expect(v.expert![0], 'Ivey (TAG) range ≈ 34 combos (position + action).');
    });

    test('preflop multiway grades vs the field', () async {
      final (v, calls) = await runScenario(scenarios['preflopFieldCall']!);
      expect(calls.single.mode, EquityMode.field);
      expect(calls.single.opponents, 5);
      expect(v!.villainName, 'Hellmuth'); // the BB is the preflop aggressor
      expect(v.steps![0], 'AKs vs the 5-player field on a pre-flop board → 55% equity.');
    });

    test('relaxed strictness + high quality', () async {
      final (v, calls) = await runScenario(scenarios['relaxedBadCall']!);
      expect(calls.single.iters, 4000);
      expect(v!.verdict, Verdict.mistake);
      expect(v.blocking, isTrue);
    });

    test('hero without cards → null', () async {
      final s = makeState(flopVs1);
      s.players[0].hole = null;
      expect(await evaluateHero(s, const Action.call(), 1), isNull);
    });
  });

  test('seed string matches the desktop hashSeed input', () async {
    final (_, calls) = await runScenario(scenarios['foldSpill']!);
    expect(calls.single.seed, hashSeed('1|flop|fold|AsKs|Kh7d2c'));
    expect(calls.single.seed, 2289540689);
  });

  test('default runner uses the real equity engine deterministically', () async {
    final s = makeState(riverCheck);
    final a = await evaluateHero(s, const Action.check(), 1);
    final b = await evaluateHero(s, const Action.check(), 1);
    expect(a, isNotNull);
    expect(a!.equity, b!.equity);
    expect(a.verdict, Verdict.mistake); // AK top-pair on a dry river vs TAG
    expect(a.expert![1], startsWith('Exact count'));
    final req = EquityRequest(
      hero: const ['As', 'Ks'],
      board: const ['Kh', '7d', '2c'],
      mode: EquityMode.random,
      range: const [],
      opponents: 1,
      iters: 500,
      seed: 42,
    );
    expect(req.run(), equityVsRandomCards(('As', 'Ks'), req.board, iters: 500, seed: 42));
    expect(EquityRequest.fromJson(req.toJson()).toJson(), req.toJson());
  });

  test('coachThresholds / base iters / defaults', () {
    expect(coachThresholds(CoachStrictness.relaxed).mistakeBb, -0.6);
    expect(coachThresholds(CoachStrictness.relaxed).foldFlagBb, 2.5);
    expect(coachThresholds(CoachStrictness.standard).mistakeBb, -0.3);
    expect(coachThresholds(CoachStrictness.standard).foldFlagBb, 1.5);
    expect(coachThresholds(CoachStrictness.strict).mistakeBb, -0.15);
    expect(coachThresholds(CoachStrictness.strict).foldFlagBb, 1.0);
    expect(baseItersFor(SimQuality.standard), 1600);
    expect(baseItersFor(SimQuality.high), 4000);
    expect(CoachSettings.defaults.strictness, CoachStrictness.standard);
    expect(CoachSettings.defaults.simQuality, SimQuality.standard);
    expect(CoachSettings.defaults.baseIters, 1600);
    expect(CoachSettings.defaults.thresholds.mistakeBb, -0.3);
    expect(CoachStrictness.fromLabel('bogus'), CoachStrictness.standard);
    expect(SimQuality.fromLabel('high'), SimQuality.high);
  });

  test('scoreGuess pins (Node reference)', () {
    final ref = kCoachRef['guess'] as Map<String, Object?>;
    void check(String key, GuessScore g) {
      final e = ref[key] as Map<String, Object?>;
      expect(g.accuracy, e['accuracy'], reason: '$key accuracy');
      expect(g.precision, e['precision'], reason: '$key precision');
      expect(g.recall, e['recall'], reason: '$key recall');
    }

    check('aaKk', scoreGuess(['AA', 'KK'], ['AA', 'AKs']));
    check('same', scoreGuess(['AKo'], ['AKo']));
    check('miss', scoreGuess(['72o'], ['AA']));
    check('dupes', scoreGuess(['AA', 'AA'], ['AA']));
    check('wide', scoreGuess(['AKs', 'AKo', 'AA'], ['AA']));
    check('empty', scoreGuess([], ['AA']));
    check(
      'big',
      scoreGuess(
        [
          'AA', 'KK', 'QQ', 'JJ', 'TT', 'AKs', 'AQs', 'AJs', 'KQs', 'AKo', //
          'AQo', 'T9s', '98s', '76o',
        ],
        [
          'AA', 'KK', 'QQ', 'JJ', 'AKs', 'AKo', 'AQs', 'KQo', 'JTs', 'T9s', //
          '22',
        ],
      ),
    );
    final g = scoreGuess(['AA', 'KK'], ['AA', 'AKs']);
    expect(g.precision, 0.5);
    expect(g.recall, 0.6);
    expect(g.accuracy, closeTo(0.5454545454545454, 1e-15));
  });

  test('interpretBot pins (all archetypes × labels)', () {
    final ref = kCoachRef['bots'] as Map<String, Object?>;
    final s = makeState(const Spec(button: 3, hole: ['As', 'Ks']));
    for (final seat in [1, 2, 3, 4, 5]) {
      final p = s.players[seat];
      for (final label in [
        'Fold',
        'Check',
        'Call',
        'All-In',
        'Bet',
        'Raise',
        'SB',
        null,
      ]) {
        p.lastAction =
            label == null ? null : PlayerLastAction(label, Street.preflop);
        final key = '$seat:${p.archetype!.label}:${label ?? 'null'}';
        expect(interpretBot(p), ref[key], reason: key);
      }
    }
    expect(interpretBot(s.players[0]), '');
    expect(
      interpretBot(
        s.players[4]..lastAction = const PlayerLastAction('Raise', Street.flop),
      ),
      'A raise from a Nit is a red flag — expect a premium. Fold your marginal hands.',
    );
  });

  test('villainRangeFor: stored range, archetype fallback, hero → []', () {
    final s = makeState(const Spec(button: 3, hole: ['As', 'Ks']));
    final bb = s.players[5];
    final fallback = villainRangeFor(s, bb);
    expect(
      fallback,
      buildPreflopRanges(22, 18, Position.bb).play.toList(),
    );
    expect(fallback.first, 'AA');
    s.botRanges[5] = ['AA', 'KK'];
    expect(villainRangeFor(s, bb), ['AA', 'KK']);
    s.botRanges[5] = [];
    expect(villainRangeFor(s, bb), fallback);
    expect(villainRangeFor(s, s.players[0]), isEmpty);
  });

  test('firstOpponentInHand skips folded seats and falls back to 1', () {
    final s = makeState(const Spec(button: 3, hole: ['As', 'Ks']));
    expect(firstOpponentInHand(s), 1);
    s.players[1].hasFolded = true;
    s.players[2].hasFolded = true;
    expect(firstOpponentInHand(s), 3);
    for (final p in s.players) {
      p.hasFolded = true;
    }
    expect(firstOpponentInHand(s), 1);
  });

  test('botMoveReview builds the desktop "bot" note', () {
    final s = makeState(flopVs1);
    final p = s.players[1]..lastAction = const PlayerLastAction('Bet', Street.flop);
    final rv = botMoveReview(s, p, 3)!;
    expect(rv.kind, ReviewKind.bot);
    expect(rv.verdict, Verdict.info);
    expect(rv.blocking, isFalse);
    expect(rv.title, "Ivey's bet");
    expect(rv.villainArchetype, Archetype.tag);
    expect(rv.villainRange, villainRangeFor(s, p));
    expect(rv.board, ['Kh', '7d', '2c']);
    expect(rv.text, interpretBot(p));
    p.lastAction = null;
    expect(botMoveReview(s, p, 4)!.title, "Ivey's move");
    expect(botMoveReview(s, s.players[0], 5), isNull);
  });

  test('CoachReview JSON round-trip', () async {
    final (v, _) = await runScenario(scenarios['badCall']!);
    final json = v!.toJson();
    expect(CoachReview.fromJson(json).toJson(), json);
    final bot = botMoveReview(makeState(flopVs1), makeState(flopVs1).players[1], 9)!;
    expect(CoachReview.fromJson(bot.toJson()).toJson(), bot.toJson());
    expect(Verdict.fromLabel('great'), Verdict.great);
    expect(ReviewKind.fromLabel('bot'), ReviewKind.bot);
  });
}
