/// Reading an opponent's move the way a player does — from the action, the
/// price, the board and the order things happened in. No simulation.
///
/// The old `interpretBot` was handed a [Player] and nothing else, so the best
/// it could manage was archetype boilerplate: "Negreanu (LAG) calls with lots
/// of hands… expect them to call you down with medium ones." That is the same
/// sentence whether the board is three low cards in a row or three aces, which
/// is why it reads as nothing at all.
///
/// A read is built from: the street; what they did and how big; what this
/// board does for the hands that call versus the hands that raise; whether a
/// draw just arrived; how many players are in; and the order of their actions
/// across streets. The player's style is the LAST sentence and is phrased as
/// an adjustment to the read above it — never the headline.
///
/// 1:1 port of `src/game/botRead.ts`.
library;

import 'cards.dart';
import 'types.dart';

/// Everything the read needs, captured at the moment they acted.
class BotMoveSnapshot {
  const BotMoveSnapshot({
    required this.name,
    this.archetype,
    required this.street,
    required this.board,
    required this.action,
    required this.amount,
    required this.pot,
    required this.playersIn,
    required this.wasPreflopRaiser,
    required this.checkedThisStreet,
    required this.betLastStreet,
    required this.handsSeen,
    required this.rangeCombos,
  });

  final String name;
  final Archetype? archetype;
  final Street street;

  /// The board they were looking at — not the one dealt after they acted.
  final List<Card> board;

  /// One of fold / check / call / bet / raise.
  final ActionType action;

  /// Chips this action put in beyond what they had already committed.
  final int amount;

  /// Pot before the action.
  final int pot;

  /// Players still in the hand when they acted, hero included.
  final int playersIn;

  final bool wasPreflopRaiser;

  /// They checked earlier on this same street, then raised.
  final bool checkedThisStreet;

  /// They bet the previous street.
  final bool betLastStreet;

  /// Hands seen from this seat, for an honest style note.
  final int handsSeen;

  /// Size of their remaining likely holdings, if the app has a read at all.
  final int rangeCombos;
}

enum ReadConfidence { solid, weak, none }

class BotRead {
  const BotRead({
    required this.title,
    required this.plain,
    required this.steps,
    required this.expert,
    required this.confidence,
  });

  final String title;

  /// Layer 1 — plain English, no arithmetic.
  final String plain;

  /// Layer 2 — the numbers behind it.
  final List<String> steps;

  /// Layer 3 — the reasoning, usable at a table with no screen.
  final List<String> expert;

  final ReadConfidence confidence;
}

/* ----------------------------------------------------------- board shape */

class BoardShape {
  const BoardShape({
    required this.phrase,
    required this.lowConnected,
    required this.broadway,
    required this.paired,
    required this.twoTone,
    required this.monotone,
    required this.dry,
  });

  /// "three low cards in a row", "three big cards"…
  final String phrase;
  final bool lowConnected;
  final bool broadway;
  final bool paired;
  final bool twoTone;
  final bool monotone;

  /// Nothing much to draw to.
  final bool dry;
}

BoardShape boardShape(List<Card> board) {
  final ints = [for (final c in board) cardToInt(c)];
  final suits = [0, 0, 0, 0];
  final ranks = <int>[];
  final counts = <int, int>{};
  for (final c in ints) {
    suits[c & 3]++;
    final r = (c >> 2) + 2;
    ranks.add(r);
    counts[r] = (counts[r] ?? 0) + 1;
  }
  final maxSuit = suits.fold<int>(0, (a, b) => b > a ? b : a);
  final monotone = board.length >= 3 && maxSuit >= 3;
  final twoTone = !monotone && maxSuit >= 2;
  final paired = counts.values.any((n) => n >= 2);
  final sorted = ranks.toSet().toList()..sort();
  final span = sorted.length >= 3 ? sorted.last - sorted.first : 99;
  final connected = sorted.length >= 3 && span <= 4;
  final allLow = ranks.isNotEmpty && ranks.every((r) => r <= 9);
  final allBig = ranks.isNotEmpty && ranks.every((r) => r >= 10);
  final lowConnected = connected && allLow;
  final dry = !connected && !twoTone && !monotone;

  final String phrase;
  if (paired) {
    phrase = 'a paired board';
  } else if (monotone) {
    phrase = 'three cards of one suit';
  } else if (lowConnected) {
    phrase = 'three low cards in a row';
  } else if (connected) {
    phrase = 'a run of connected cards';
  } else if (allBig) {
    phrase = 'three big cards';
  } else if (twoTone) {
    phrase = 'two cards of one suit, so a flush draw is out there';
  } else {
    phrase = 'scattered cards with nothing much to draw to';
  }

  return BoardShape(
    phrase: phrase,
    lowConnected: lowConnected,
    broadway: allBig,
    paired: paired,
    twoTone: twoTone,
    monotone: monotone,
    dry: dry,
  );
}

/// "about half the pot", "the size of the pot"…
String sizeWord(double frac) {
  if (frac < 0.25) return 'about a quarter of the pot';
  if (frac < 0.4) return 'about a third of the pot';
  if (frac < 0.6) return 'about half the pot';
  if (frac < 0.85) return 'about two-thirds of the pot';
  if (frac < 1.15) return 'the size of the pot';
  return 'more than the whole pot';
}

const Map<Street, String> _streetWord = {
  Street.preflop: 'before the flop',
  Street.flop: 'on the flop',
  Street.turn: 'on the turn',
  Street.river: 'on the river',
  Street.showdown: 'at showdown',
};

enum _StyleMode { aggressive, call, passive }

/// The style note, last and phrased as an adjustment. Below fifteen hands the
/// honest answer is that we do not know them yet — which is also the right
/// order to think in, so the read never leans on it.
String _styleNote(BotMoveSnapshot s, _StyleMode mode) {
  if (s.handsSeen < 15) {
    return 'You have only seen ${s.handsSeen} hand'
        '${s.handsSeen == 1 ? '' : 's'} from ${s.name}, which is not enough '
        'to call them anything yet — so this read leans on the board and the '
        'action instead, which is the right order anyway.';
  }
  final a = s.archetype;
  if (mode == _StyleMode.aggressive) {
    if (a == Archetype.nit) {
      return 'One adjustment: ${s.name} has put money in on very few hands '
          'all session. When someone this tight raises, drop the missed-hand '
          'half of the read entirely.';
    }
    if (a == Archetype.lag) {
      return 'One adjustment: ${s.name} bets and raises far more hands than '
          'most, so the missed-hand half of the read is bigger than it looks. '
          'Same read, fold a little less often.';
    }
    if (a == Archetype.station) {
      return 'One adjustment: ${s.name} almost never raises, which makes this '
          'read stronger rather than weaker. Believe it.';
    }
    return 'One adjustment: ${s.name} has raised a tight set of hands all '
        'session, so take this at close to face value.';
  }
  if (mode == _StyleMode.passive) {
    if (a == Archetype.station) {
      return 'One adjustment: a check from someone who calls as much as '
          '${s.name} really is a weak hand — they call, they do not check '
          'strong ones.';
    }
    if (a == Archetype.nit) {
      return 'One adjustment: ${s.name} folds most hands, so pots like this '
          'one are there for the taking more often than against anybody else '
          'at the table.';
    }
    if (a == Archetype.lag) {
      return 'One adjustment: ${s.name} checks strong hands more often than '
          'most to set up a raise later. Bet, but do not commit your stack to '
          'that bet.';
    }
    return 'One adjustment: nothing to add — a solid player\'s check means '
        'what it says above.';
  }
  if (a == Archetype.station) {
    return 'One adjustment: ${s.name} calls far too much, so the call itself '
        'tells you almost nothing. Keep betting the hands that are ahead and '
        'stop bluffing them.';
  }
  if (a == Archetype.nit) {
    return 'One adjustment: even a tight player\'s call is a real hand — they '
        'would have raised their very best, so this is the middle of a narrow '
        'set.';
  }
  if (a == Archetype.lag) {
    return 'One adjustment: ${s.name} calls with a lot of hands and plans to '
        'take the pot on a later card. Expect a bet at you next street '
        'whether it helped them or not.';
  }
  return 'One adjustment: nothing to add — a solid player\'s call means what '
      'it says above.';
}

/* -------------------------------------------------------------- the read */

BotRead readBotAction(BotMoveSnapshot s) {
  final shape = boardShape(s.board);
  final where = _streetWord[s.street] ?? 'on this street';
  final frac = s.pot > 0 ? s.amount / s.pot : 0.0;
  final size = sizeWord(frac);
  final multi = s.playersIn > 2;
  final steps = <String>[];
  final expert = <String>[];
  final method =
      'This read comes from the board, the size and how ${s.name} has played '
      'this hand — no simulation. More in About → How the grading works.';

  /* ---- fold ---- */
  if (s.action == ActionType.fold) {
    final left = s.playersIn - 1;
    return BotRead(
      title: '${s.name}\'s fold',
      plain:
          '${s.name} folds. Their hand no longer matters — what matters is '
          'that one fewer player can beat you, so the hands worth betting '
          'just got wider.',
      steps: ['$left player${left == 1 ? '' : 's'} left in the hand.'],
      expert: [
        'The plan from here — every player who folds makes the pot easier to '
            'win and your own hand worth more. Against one opponent you can '
            'bet hands you would check against three.',
        method,
      ],
      confidence: ReadConfidence.solid,
    );
  }

  /* ---- check ---- */
  if (s.action == ActionType.check) {
    final gaveUp = s.betLastStreet;
    return BotRead(
      title: '${s.name}\'s check',
      plain:
          gaveUp
              ? '${s.name} bet the last card and has now checked. That pairing '
                  'is the clearest signal in poker: they were betting a hand '
                  'that wanted to win right there, it did not, and they have '
                  'given up on it. Bet, almost regardless of what you hold.'
              : '${s.name} checks $where. On ${shape.phrase} a check is '
                  'usually a hand that could not stand a bet — this is a pot '
                  'you can take by betting at it.',
      steps: [
        'Pot ${s.pot} chips; checking costs them nothing and gives you the '
            'choice.',
      ],
      expert: [
        gaveUp
            ? 'What the check said — betting then checking is a line that '
                'strong hands almost never take. A hand good enough to bet the '
                'last card is good enough to bet this one, so the hands left '
                'are the ones that missed.'
            : 'What the check said — checking keeps the pot small, which is '
                'what the weak part of their hands wants. Some players check '
                'strong hands here to raise you later, so size your bet to '
                'find out cheaply rather than to commit.',
        'The plan from here — bet, and have an answer ready for a raise. If '
            'they raise after checking, that is the one line that is almost '
            'always real.',
        _styleNote(s, _StyleMode.passive),
        method,
      ],
      confidence: ReadConfidence.solid,
    );
  }

  /* ---- call ---- */
  if (s.action == ActionType.call) {
    steps.add('${s.name} called ${s.amount} into a ${s.pot} pot.');
    if (s.rangeCombos > 0) {
      steps.add(
        'About ${s.rangeCombos} hands are still consistent with how they have '
        'played.',
      );
    }
    return BotRead(
      title: '${s.name}\'s call',
      plain:
          shape.lowConnected
              ? '${s.name} called $where on ${shape.phrase}. A call on this '
                  'board keeps in exactly the hands it suits — small pairs and '
                  'connected cards — and folds out the big cards. Their hand '
                  'just got stronger on average, not weaker.'
              : '${s.name} called $where. A call is the widest action in '
                  'poker: it keeps every hand that is good enough to continue '
                  'and none that is good enough to raise. Expect middling '
                  'strength, and expect to be called again.',
      steps: steps,
      expert: [
        'What their action said — calling leaves their strongest hands in and '
            'their weakest out, so the set of hands narrows from both ends. '
            'Against one caller your bluffs work less often and your good '
            'hands get paid more.',
        'The plan from here — decide now what you do on the next card. A '
            'caller who checks to you again is usually giving up; a caller who '
            'suddenly bets or raises has either hit or decided you have '
            'nothing.',
        _styleNote(s, _StyleMode.call),
        method,
      ],
      confidence:
          s.rangeCombos > 0 ? ReadConfidence.solid : ReadConfidence.weak,
    );
  }

  /* ---- bet / raise ---- */
  final isRaise = s.action == ActionType.raise;
  final checkRaise = isRaise && s.checkedThisStreet;
  steps.add(
    '${s.name} ${isRaise ? 'raised to' : 'bet'} ${s.amount} into a ${s.pot} '
    'pot — ${(frac * 100).round()}% of it.',
  );
  if (s.rangeCombos > 0) {
    steps.add(
      'About ${s.rangeCombos} hands are still consistent with how they have '
      'played.',
    );
  }

  String plain;
  if (checkRaise) {
    plain =
        '${s.name} checked, let you bet, then raised — a check-raise. It is '
        'the strongest line in poker, because it needs you to put money in '
        'first and risks the pot if you simply fold. Players do not build '
        'that with nothing. Unless you have a hand you would happily get all '
        'the chips in with, this is a fold.';
    expert.add(
      'What the raise said — a check-raise gives up the chance to win the pot '
      'by betting, so it is made by hands that want more money in, not fewer. '
      'On ${shape.phrase} the hands that do that here are the ones already '
      'past one pair.',
    );
  } else if (s.street == Street.river && shape.twoTone) {
    plain =
        '${s.name} bet $size on the river, on a board where a flush was '
        'possible. A river bet is the one bet that can never be a draw — by '
        'now they either have a hand or they are telling a story. The question '
        'is simply whether the card that just came helped them.';
    expert.add(
      'What the bet said — on the river there is nothing left to draw to, so '
      'the bet is either a hand that wants to be called or a hand that cannot '
      'win any other way. Big river bets on a completed draw are far more '
      'often real than not.',
    );
  } else if (shape.lowConnected) {
    plain =
        '${s.name} bet $size $where on ${shape.phrase}. This is the one board '
        'that hits the hands that CALL far harder than the hands that RAISE — '
        'small pairs and connected cards like 8-7 and 7-6. Big cards have '
        'nothing here. So when money goes in on a board like this, the person '
        'putting it in usually really has it, and the hands you make are the '
        'bottom of everything.';
    expert.add(
      'What the bet said — low connected boards reverse the usual order. '
      'Before the flop the strong hands are big cards; on three low cards in a '
      'row the big cards are the weakest thing on the table and the hands that '
      'just called are the strongest. Treat a bet here with more respect than '
      'the same bet on big cards.',
    );
  } else if (shape.broadway) {
    plain =
        '${s.name} bet $size $where on ${shape.phrase}. Big cards are what '
        'most players raise with before the flop, so this board hits the '
        'raiser\'s hands and misses the caller\'s. A bet here is expected '
        'whether or not it connected — it is the most routine bet in poker, '
        'and the least informative.';
    expert.add(
      'What the bet said — on a board of big cards the person who raised '
      'before the flop can credibly have all of them, so they bet nearly every '
      'time. That makes the bet cheap to make and cheap to believe. Give it '
      'less weight than the same bet on low cards.',
    );
  } else if (shape.paired) {
    plain =
        '${s.name} bet $size $where on ${shape.phrase}. Paired boards miss '
        'almost everybody, which cuts both ways: they rarely have three of a '
        'kind, and neither do you. Most of the time this is a bet at the pot '
        'rather than a bet with a hand.';
    expert.add(
      'What the bet said — a pair on the board means fewer hands improved, so '
      'both of you missed more often than usual. That makes the bet more '
      'likely to be a try at the pot, and a raise more likely to be believed.',
    );
  } else {
    plain =
        '${s.name} bet $size $where on ${shape.phrase}. Size is the tell '
        'here: small bets are cheap to make with anything, big bets ask you to '
        'pay to find out. '
        '${frac >= 0.6 ? 'This one is big enough that it wants to be called by worse or to make you fold — not a hand looking for a cheap look.' : 'This one is small enough that it costs them little to try, so do not fold anything decent to it.'}';
    expert.add(
      'What the bet said — on ${shape.phrase} there is less to draw to, so '
      'bets are made by made hands and by nothing, with little in between. '
      'Work out which by what they do when you do not go away.',
    );
  }

  if (s.wasPreflopRaiser && s.street == Street.flop && !isRaise) {
    expert.add(
      'What the bet said — they raised before the flop and are following it '
      'up, which players call a c-bet (continuation bet). Good players make it '
      'on roughly two flops in three whether the flop helped them or not, so '
      'on its own it is close to no information. The size and the board are '
      'what carry the meaning.',
    );
  }

  expert.add(
    multi
        ? 'The plan from here — they bet into ${s.playersIn - 1} other '
            'players, not one. Betting into a crowd with a weak hand is a good '
            'way to lose a big pot, so the hands that do it skew strong. Fold '
            'more here than you would heads-up.'
        : 'The plan from here — name the hand you are continuing with before '
            'you put chips in. If you cannot say what you beat that keeps '
            'betting, that is the answer.',
  );
  expert.add(
    shape.lowConnected
        ? 'What would change the answer — the same bet on three big cards. '
            'There the bet is at the pot and the hands that called before the '
            'flop have missed, so you stop folding pairs.'
        : 'What would change the answer — the same bet from a player who has '
            'been betting every pot, or a size small enough to be cheap. '
            'Either turns this from a hand to respect into a hand to look up.',
  );
  expert.add(_styleNote(s, _StyleMode.aggressive));
  expert.add(method);

  return BotRead(
    title:
        '${s.name}\'s '
        '${checkRaise
            ? 'check-raise'
            : isRaise
            ? 'raise'
            : 'bet'}',
    plain: plain,
    steps: steps,
    expert: expert,
    confidence: s.rangeCombos > 0 ? ReadConfidence.solid : ReadConfidence.weak,
  );
}
