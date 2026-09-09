/// Layer 1 for D1 — the drill verdict's always-visible sentence, in the coach's
/// voice (docs/TONE.md).
///
/// `lib/engine` is never touched: its rationales are the desktop's and are
/// pinned by `test/engine/puzzles_ref.dart`. They are also written for an
/// expert — "T8o is outside the CO continuing range vs a UTG open (~10%
/// continues) — fold." — and rendering them as layer 1 put the app's single
/// most-repeated teaching surface in exactly the vocabulary TONE.md bans:
/// hand codes, seat codes, "continuing range", "equity", "pot odds", "jams",
/// "ICM".
///
/// This is the same trick `lib/features/play/hand_log_format.dart` plays on the
/// engine's log: re-render the sentence on the phone from the puzzle's
/// *structured* fields (kind, handLabel, heroPos, equity, potOdds, best,
/// accept, gradeRange), leaving the engine's own wording to layer 2 —
/// "Show me the math" — where percentages and range talk belong.
///
/// [DrillRationale.plain] returns null when the mobile layer has nothing
/// better to say than the engine (Review/leak spots, which replay the user's
/// own hand and already carry a coach-authored note); the panel falls back to
/// the engine string in that case.
library;

import '../../../engine/engine.dart';

abstract final class DrillRationale {
  /// Layer 1, or null to fall back to [Puzzle.rationale].
  static String? plain(Puzzle p) => switch (p.kind) {
    PuzzleKind.rfi => _rfi(p),
    PuzzleKind.vsRaise => _vsRaise(p),
    PuzzleKind.pushfold => _pushFold(p),
    PuzzleKind.exploit => _exploit(p),
    PuzzleKind.postflopBet ||
    PuzzleKind.postflopCheck ||
    PuzzleKind.threebetPot ||
    PuzzleKind.checkRaise ||
    PuzzleKind.riverDecision => _postflop(p),
    // Review replays the user's own hand; its note is already the coach's.
    PuzzleKind.leak => null,
  };

  /* ------------------------------------------------------- vocabulary */

  static const Map<String, String> _rankWords = {
    'A': 'ace',
    'K': 'king',
    'Q': 'queen',
    'J': 'jack',
    'T': 'ten',
    '9': 'nine',
    '8': 'eight',
    '7': 'seven',
    '6': 'six',
    '5': 'five',
    '4': 'four',
    '3': 'three',
    '2': 'two',
  };

  static const Map<String, String> _plurals = {
    'ace': 'aces',
    'king': 'kings',
    'queen': 'queens',
    'jack': 'jacks',
    'ten': 'tens',
    'nine': 'nines',
    'eight': 'eights',
    'seven': 'sevens',
    'six': 'sixes',
    'five': 'fives',
    'four': 'fours',
    'three': 'threes',
    'two': 'twos',
  };

  /// "T8o" → "ten and eight of different suits"; "KQs" → "king and queen of
  /// the same suit"; "88" → "a pair of eights". The `s` / `o` suffix is never
  /// explained anywhere on the drill screen, so layer 1 spells it out.
  static String handInWords(HandLabel label) {
    if (label.length < 2) return label;
    final a = _rankWords[label[0]] ?? label[0];
    final b = _rankWords[label[1]] ?? label[1];
    if (label.length == 2 || label[0] == label[1]) {
      return 'a pair of ${_plurals[a] ?? '${a}s'}';
    }
    return label.endsWith('s')
        ? '$a and $b of the same suit'
        : '$a and $b of different suits';
  }

  /// Seat codes, in words. "CO" and "UTG" mean nothing in week one.
  static String seatInWords(Position p) => switch (p) {
    Position.utg => 'the first seat to act',
    Position.mp => 'middle position',
    Position.co => 'one seat before the button',
    Position.btn => 'the button, where you act last',
    Position.sb => 'the small blind',
    Position.bb => 'the big blind',
  };

  /// Share of all starting hands, as a count: "1 hand in 5", "7 hands in 10".
  ///
  /// Always used parenthetically ("(roughly 1 hand in 5)") so the sentence
  /// around it never has to agree with a number it does not know.
  static String? _shareInWords(List<HandLabel>? range) {
    if (range == null || range.isEmpty) return null;
    final share = combosInSet(range) / 1326.0;
    if (share <= 0 || share >= 1) return null;
    final phrase = fmtTimes(share).replaceAll('time', 'hand');
    // "almost never" / "almost every hand" carry no count to put in brackets.
    return phrase.startsWith('about ') ? phrase.substring(6) : null;
  }

  static bool _isMixed(Puzzle p) => p.accept.length > 1;

  /* ---------------------------------------------------------- pre-flop */

  static String _rfi(Puzzle p) {
    final hand = handInWords(p.handLabel);
    final seat = seatInWords(p.heroPos);
    if (_isMixed(p)) {
      return 'You are in $seat with $hand. This one sits right on the '
          'line — raising and folding work out about the same, so either '
          'is fine. Just calling the big blind (players call that limping) '
          'is the one thing that loses money.';
    }
    if (p.best == DrillAction.raise) {
      return 'You are in $seat with $hand, and that is strong enough to open '
          'the betting from there. Raise — just calling the big blind '
          '(players call that limping) gives away the pot you could have '
          'won without a fight.';
    }
    final share = _shareInWords(p.gradeRange);
    final bracket = share == null ? '' : ' (roughly $share)';
    return 'You are in $seat with $hand. That is outside the hands worth '
        'opening from there$bracket, so folding is right.';
  }

  static String _vsRaise(Puzzle p) {
    final hand = handInWords(p.handLabel);
    if (_isMixed(p)) {
      return 'Someone has already raised, and $hand is a genuine mix here: '
          'more than one answer makes about the same money over time, so '
          'any of them is fine.';
    }
    return switch (p.best) {
      DrillAction.raise =>
        'Someone has already raised and you hold $hand — strong enough to '
            'raise them back rather than just call. Re-raising is what makes '
            'money with it.',
      DrillAction.call =>
        'Someone has already raised. $hand is worth playing on, but not '
            'worth raising again — call and see the flop.',
      _ => () {
        final share = _shareInWords(p.gradeRange);
        final bracket = share == null ? '' : ' (roughly $share)';
        return 'Someone has already raised, and $hand is too weak to keep '
            'paying to see what comes. It is outside the hands worth '
            'continuing with from your seat$bracket, so folding is right.';
      }(),
    };
  }

  static String _pushFold(Puzzle p) {
    final hand = handInWords(p.handLabel);
    final seat = seatInWords(p.heroPos);
    final bubble = p.icm == true;
    final stakes =
        bubble
            ? ' You are one place away from the money, so going broke here '
                'costs you more than the chips are worth — the answer is '
                'tighter than it would be for chips alone.'
            : '';
    final facingAllIn = p.options.any((o) => o.action == DrillAction.call);

    if (facingAllIn) {
      final verdict =
          _isMixed(p)
              ? 'This one is right on the line — calling and folding are both '
                  'fine.'
              : p.best == DrillAction.call
              ? 'That is strong enough to call for your whole stack.'
              : 'That is not strong enough to put your whole stack in. Fold.';
      return 'Your opponent has moved all in, so your only choices are call '
          'or fold. You hold $hand. $verdict$stakes';
    }

    final verdict =
        _isMixed(p)
            ? 'This one is right on the line — moving in and folding are both '
                'fine.'
            : p.best == DrillAction.raise
            ? 'That is strong enough to move all in.'
            : 'That is not strong enough to move all in. Fold.';
    return 'Your stack is short enough that there is no play left after the '
        'flop: it is all in or fold, nothing in between. You are in $seat '
        'with $hand. $verdict$stakes';
  }

  /* --------------------------------------------------------- post-flop */

  static String _postflop(Puzzle p) {
    final equity = p.equity;
    final odds = p.potOdds;
    if (equity == null) return _postflopNoNumbers(p);

    final wins = fmtTimes(equity);
    if (odds != null && p.toCall > 0) {
      final need = fmtNeed(odds);
      final verdict =
          _isMixed(p)
              ? 'Those two are close enough that calling and folding are both '
                  'fine.'
              : p.best == DrillAction.fold
              ? 'Your hand does not win often enough for that price, so '
                  'folding is right — calling would lose money over time.'
              : equity > 0.72
              ? 'That is well past the price — good enough to raise for value, '
                  'not just call.'
              : 'Your hand wins more often than the price asks for, so calling '
                  'makes money.';
      return 'You would pay ${fmtBbAmount(p.toCall, p.bb)} to win a pot of '
          '${fmtBbAmount(p.pot, p.bb)}, so you need to win $need for the call '
          'to break even. Against the hands your opponent can have here, '
          'yours wins $wins. $verdict';
    }

    final verdict =
        _isMixed(p)
            ? 'That is right on the border, so betting and checking are both '
                'fine.'
            : p.best == DrillAction.bet
            ? 'You are ahead often enough that betting gets paid off by worse '
                'hands.'
            : 'That is not enough to bet for value — check and keep the pot '
                'small.';
    return 'Against the hands your opponent can have here, yours wins $wins. '
        '$verdict';
  }

  static String _postflopNoNumbers(Puzzle p) => switch (p.best) {
    DrillAction.bet =>
      'You hold ${handInWords(p.handLabel)}. It is strong enough here that '
          'betting gets paid off by worse hands.',
    DrillAction.check =>
      'You hold ${handInWords(p.handLabel)}. It is not strong enough to bet '
          'for value — check and keep the pot small.',
    DrillAction.call =>
      'You hold ${handInWords(p.handLabel)}. It is worth the price to keep '
          'playing, so call.',
    _ =>
      'You hold ${handInWords(p.handLabel)}. It is not worth paying to carry '
          'on here, so fold.',
  };

  /* ----------------------------------------------------------- exploit */

  static String _exploit(Puzzle p) {
    final action = switch (p.best) {
      DrillAction.bet => 'bet',
      DrillAction.raise => 'raise',
      DrillAction.call => 'call',
      DrillAction.check => 'check',
      DrillAction.fold => 'fold',
    };
    return 'This is a spot where what you know about this particular '
        'opponent changes the answer: against an average player the '
        'standard play would be something else, but against this one the '
        'move that makes the most money is to $action. "Show me the math" '
        'has both numbers side by side.';
  }
}

/// `2.5` chips at `bb` → "2.5 bb". Layer 1 speaks big blinds (TONE.md).
String fmtBbAmount(num chips, num bb) =>
    '${fmtBb(chips, bb.round().clamp(1, 1 << 30))} bb';
