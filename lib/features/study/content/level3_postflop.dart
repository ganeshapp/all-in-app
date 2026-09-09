/// Level 3 "Post-flop" of the Study curriculum, ported verbatim from the
/// desktop `src/components/study/lessons.tsx` (`LEVELS[2]`).
///
/// Desktop blurb (not rendered anywhere in StudyView, kept here for parity):
/// "Board texture, pot odds and c-betting."
library;

import 'lesson_model.dart';

const Level kLevel3Postflop = Level(
  id: 'postflop',
  title: 'Post-flop',
  icon: 'target',
  lessons: [
    _boardTexture,
    _countingOuts,
    _estimatingEquity,
    _potOdds,
    _impliedOdds,
    _betSizing,
    _cbetting,
    _mdf,
    _checkRaising,
  ],
);

// ---------------------------------------------------------------------------
// 9.1 board-texture — Reading Board Texture
// ---------------------------------------------------------------------------

const Lesson _boardTexture = Lesson(
  id: 'board-texture',
  title: 'Reading Board Texture',
  minutes: 5,
  body: [
    ParagraphBlock(
      'Flops are either dry or wet, and that changes everything about how you bet.',
    ),
    HeadingBlock('Dry boards'),
    ParagraphBlock(
      'K♠ 7♦ 2♣ — disconnected, three different suits. Few draws exist, so the pre-flop raiser '
      'can follow up with a small bet very often.',
    ),
    HeadingBlock('Wet boards'),
    ParagraphBlock(
      'J♥ T♥ 9♠ — connected and suited. Many draws hit it; bet bigger with strong hands and '
      'check more marginal ones.',
    ),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          'The wetter the board, the larger your bets should be — and the more they should be '
          'strong hands or bluffs, not the in-between.',
    ),
  ],
);

// ---------------------------------------------------------------------------
// 9.2 counting-outs — Counting Outs & the 2/4 Rule
// ---------------------------------------------------------------------------

const Lesson _countingOuts = Lesson(
  id: 'counting-outs',
  title: 'Counting Outs & the 2/4 Rule',
  minutes: 5,
  body: [
    ParagraphBlock(
      'An "out" is a card that improves you to a likely winner. Counting outs lets you estimate '
      'your equity in seconds — no computer required.',
    ),
    HeadingBlock('The 2 & 4 rule'),
    ParagraphBlock(
      'On the flop (two cards to come) multiply your outs by 4. On the turn (one card to come) '
      'multiply by 2. It closely approximates the real percentage.',
    ),
    TableBlock(
      header: ['Draw', 'Outs', 'Flop', 'Turn'],
      rows: [
        ['Flush draw', '9', '36%', '18%'],
        ['Open-ended straight', '8', '32%', '16%'],
        ['Gutshot', '4', '16%', '8%'],
        ['Two overcards', '6', '24%', '12%'],
        ['Flush + gutshot', '12', '48%', '24%'],
        ['Pair → set', '2', '8%', '4%'],
      ],
    ),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          'Very big draws (12+ outs) slightly beat the ×4 cap — shade huge numbers down a little.',
    ),
    QuizBlock([
      QuizQuestion(
        prompt:
            "You flop a flush draw (9 outs). Roughly what's your equity by the river?",
        options: ['~18%', '~36%', '~50%'],
        answer: 1,
        explanation: 'Two cards to come → outs × 4 = 9 × 4 ≈ 36%.',
      ),
      QuizQuestion(
        prompt: 'On the turn you have a gutshot (4 outs). Your equity?',
        options: ['~8%', '~16%', '~24%'],
        answer: 0,
        explanation: 'One card to come → outs × 2 = 4 × 2 = 8%.',
      ),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// 9.3 estimating-equity — Estimating Equity
// ---------------------------------------------------------------------------

const Lesson _estimatingEquity = Lesson(
  id: 'estimating-equity',
  title: 'Estimating Equity',
  minutes: 5,
  body: [
    ParagraphBlock(
      "For made hands, memorise a handful of classic match-ups and you'll estimate equity at the "
      'table instantly — no simulation needed.',
    ),
    HeadingBlock('First, what\'s an "overcard"?'),
    ParagraphBlock(
      "An {{overcard}} is a card higher in rank than your opponent's pair. **AK vs 88** has two "
      "overcards — both beat the 8 — so it's nearly a coin flip (a \"race\"). **A8 vs 99** has "
      'just one overcard (only the ace beats the 9), so the pair is a much bigger favourite. '
      'The more, and higher, the overcards, the closer to 50/50.',
    ),
    TableBlock(
      header: ['Match-up', 'Equity'],
      rows: [
        ['Overpair vs underpair (KK vs 99)', '~82% / 18%'],
        ['Pair vs two overcards / a race (88 vs AKo)', '~55% / 45%'],
        ['Dominated (AK vs AQ)', '~73% / 27%'],
        ['Big suited vs pair (AKs vs QQ)', '~46% / 54%'],
        ['Pair vs one overcard (99 vs A8)', '~70% / 30%'],
        ['Set over set, flopped (an unavoidable collision)', '~90% / 10%'],
      ],
    ),
    ParagraphBlock(
      'The first five are pre-flop all-in match-ups. The last is an unavoidable post-flop '
      'collision: a {{set}} is a pocket pair that pairs the board, and when two players both flop '
      'sets the loser has almost no way to win (only the last card of their rank can make '
      'four-of-a-kind), hence ~90/10.',
    ),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          'Shortcuts: races ≈ 50/50, domination ≈ 70/30, a pair over a pair ≈ 80/20.',
    ),
    QuizBlock([
      QuizQuestion(
        prompt: 'KK vs 99 all-in pre-flop — about how often does KK win?',
        options: ['~60%', '~82%', '~95%'],
        answer: 1,
        explanation:
            'A bigger pair over a smaller pair is roughly an 80/20 favourite.',
      ),
      QuizQuestion(
        prompt: "AK vs QQ pre-flop — who's ahead?",
        options: ['AK, clearly', 'QQ, slightly (~54%)', 'Exactly 50/50'],
        answer: 1,
        explanation:
            'The pair is a small favourite over two overcards — about 54/46.',
      ),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// 9.4 pot-odds — Pot Odds, Break-even & EV
// ---------------------------------------------------------------------------

const Lesson _potOdds = Lesson(
  id: 'pot-odds',
  title: 'Pot Odds, Break-even & EV',
  minutes: 6,
  body: [
    // Layer 1 (TONE.md): the idea in ordinary words, with a count for the
    // chance, and both terms defined in the same breath they first appear —
    // this paragraph is also the lead the Pot odds tool screen shows (§6.6),
    // so it is the first thing a beginner reads about the subject anywhere.
    ParagraphBlock(
      'Calling costs chips now and pays you the pot when you win, so the question is always the '
      'same: does this hand win often enough to cover the price? Pay 5 bb to win a 20 bb pot and '
      'you need to win about 1 time in 4. Your chance of winning is your **equity**, the price '
      "you're being offered is your **pot odds**, and two formulas turn them into a decision.",
    ),
    HeadingBlock('From odds to a decision'),
    ParagraphBlock(
      '**Break-even equity** — the minimum chance of winning that makes a call profitable — is '
      'your call divided by the final pot: `call ÷ (pot + 2 × bet)`. The **value of calling** is '
      '`EV = equity × (final pot) − your call`. If EV is positive, call. Drag the sliders — '
      'including your own equity estimate — and watch the verdict flip.',
    ),
    WidgetBlock(LessonWidgetKind.potOddsCalculator),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          "The EV Coach during play computes your exact equity against each bot's range with a "
          'Monte Carlo simulation — this is the same maths, automated.',
    ),
    QuizBlock([
      QuizQuestion(
        prompt:
            'The pot is 10 bb and your opponent bets 5 bb. What equity do you need to call?',
        options: ['About 25%', 'About 33%', 'About 50%'],
        answer: 0,
        explanation:
            'You call 5 to win 15 (10 + their 5). Break-even = 5 / (10 + 5 + 5) = 5/20 = 25%.',
      ),
      QuizQuestion(
        prompt: 'A pot-sized bet always offers you what pot odds to call?',
        options: [
          '2-to-1 (need 33%)',
          '1-to-1 (need 50%)',
          '3-to-1 (need 25%)',
        ],
        answer: 0,
        explanation:
            "Against a pot-sized bet you're getting 2-to-1, so you need ~33% equity to break even.",
      ),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// 9.5 implied-odds — Implied & Reverse-Implied Odds
// ---------------------------------------------------------------------------

const Lesson _impliedOdds = Lesson(
  id: 'implied-odds',
  title: 'Implied & Reverse-Implied Odds',
  minutes: 5,
  body: [
    ParagraphBlock(
      'Pot odds only count the chips in the middle right now. Implied odds count the extra you '
      'expect to win on later streets when you complete your hand.',
    ),
    ParagraphBlock(
      "A draw that's slightly too expensive on direct odds can still be a profitable call if "
      "you'll get paid off when you hit. The deeper the stacks and the more disguised your draw, "
      'the larger your implied odds — which is why suited connectors and small pairs (set-mining) '
      'love deep stacks.',
    ),
    HeadingBlock('Reverse-implied odds'),
    ParagraphBlock(
      'The flip side: hands that win a small pot but lose a big one — a weak top pair, or a '
      "dominated draw (a low flush draw against a higher one). When you'll often be second-best "
      'as the money goes in, shade toward folding even when the immediate price looks okay.',
    ),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          'Implied odds reward hands that can make the best possible hand (sets, straights, '
          'flushes). Reverse-implied odds punish hands that make a second-best hand (weak aces, '
          'dominated draws).',
    ),
    QuizBlock([
      QuizQuestion(
        prompt: 'Implied odds are largest when…',
        options: [
          'Stacks are deep and your draw is hidden',
          'Stacks are shallow',
          "You're drawing to a small flush",
        ],
        answer: 0,
        explanation:
            'Deep stacks mean more to win on later streets; a hidden draw means you get paid when '
            'you hit.',
      ),
      QuizQuestion(
        prompt: 'Which hand suffers most from reverse-implied odds?',
        options: [
          'The ace-high flush draw',
          'A king-high flush draw against aggression',
          'A set',
        ],
        answer: 1,
        explanation:
            'A flush draw without the ace can complete and still lose a big pot to a higher '
            'flush — classic reverse-implied odds.',
      ),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// 9.6 bet-sizing — Bet Sizing
// ---------------------------------------------------------------------------

const Lesson _betSizing = Lesson(
  id: 'bet-sizing',
  title: 'Bet Sizing',
  minutes: 6,
  body: [
    ParagraphBlock(
      'Your bet size should follow your goal: get value, push out hands that could catch up, or '
      'fold out better hands.',
    ),
    HeadingBlock('Polarized → big'),
    ParagraphBlock(
      'When your range is the best possible hand or a bluff (and little in between), bet large — '
      'you want max value and max fold pressure.',
    ),
    HeadingBlock('Merged → small'),
    ParagraphBlock(
      'When you hold many decent-but-not-great hands, bet small to get called by worse and keep '
      'the pot manageable.',
    ),
    ParagraphBlock(
      'Size also **denies equity**: a bigger bet charges draws more to continue, so size up on '
      'wet boards. And your bluff size sets the price — a bet only profits as a bluff if your '
      'opponent folds often enough. Drag the sliders:',
    ),
    WidgetBlock(LessonWidgetKind.bluffCalculator),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          'Pure-bluff rule of thumb: a pot-sized bet needs your opponent to fold about 50% of the '
          'time; a half-pot bet about 33%; a third-pot about 25%.',
    ),
    QuizBlock([
      QuizQuestion(
        prompt:
            'A pot-sized bluff needs your opponent to fold roughly how often to break even?',
        options: ['~33%', '~50%', '~67%'],
        answer: 1,
        explanation:
            'Risk = pot, reward = pot, so break-even fold frequency = bet/(bet+pot) = 50%.',
      ),
      QuizQuestion(
        prompt:
            'With a polarized range (best possible hands or bluffs), you should bet…',
        options: ['Small', 'Big'],
        answer: 1,
        explanation:
            'Polarized ranges want big sizes — maximum value when called, maximum pressure to '
            'fold.',
      ),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// 9.7 cbetting — Continuation Betting
// ---------------------------------------------------------------------------

const Lesson _cbetting = Lesson(
  id: 'cbetting',
  title: 'Continuation Betting',
  minutes: 4,
  body: [
    ParagraphBlock(
      'A continuation bet (c-bet) is a follow-up bet on the flop by the pre-flop aggressor. It '
      'wins pots whether or not you connected.',
    ),
    ParagraphBlock(
      'C-bet more on dry boards that favour your range, and on boards where you can credibly '
      "represent the strongest hands. Slow down on wet boards that smash the caller's range, and "
      'against calling stations who never fold — value bet them instead.',
    ),
  ],
);

// ---------------------------------------------------------------------------
// 9.8 mdf — Minimum Defense Frequency
// ---------------------------------------------------------------------------

const Lesson _mdf = Lesson(
  id: 'mdf',
  title: 'Minimum Defense Frequency',
  minutes: 5,
  body: [
    ParagraphBlock(
      "How often must you continue against a bet so opponents can't profit by bluffing you with "
      'any two cards? That number is your minimum defense frequency (MDF).',
    ),
    ParagraphBlock(
      'A bluff risks the bet to win the pot. If you fold too often, ANY bluff shows a profit. '
      'The break-even point: `MDF = pot / (pot + bet)`. Against a half-pot bet you must continue '
      '10/(10+5) = 67% of the time; against a pot-sized bet, 50%.',
    ),
    HeadingBlock('When to use MDF vs pot odds'),
    ParagraphBlock(
      '**Pot odds** answer "is THIS hand profitable to call?" — the right question against '
      'players who rarely bluff. **MDF** answers "am I folding so much that bluffing me prints '
      "money?\" — the right question against aggressive players. Against the app's bots, pot "
      "odds usually rule: a Nit's big bet is almost never a bluff, so \"mathematically "
      'exploitable" folding is actually correct against them.',
    ),
    CalloutBlock(
      kind: CalloutKind.key,
      title: 'Key idea',
      body:
          'MDF is a shield, not a hammer. Reach for it when someone keeps betting at you street '
          'after street; ignore it when the bettor is honest. Knowing WHICH question to ask is '
          'the skill.',
    ),
    QuizBlock([
      QuizQuestion(
        prompt:
            'The pot is 12 bb and your opponent bets 6 bb (half pot). Roughly how often must you '
            "continue so they can't bluff any two cards profitably?",
        options: ['About 67%', 'About 50%', 'About 33%'],
        answer: 0,
        explanation:
            'MDF = pot / (pot + bet) = 12 / 18 = 67%. Fold more than a third and any-two bluffs '
            'profit.',
      ),
      QuizQuestion(
        prompt:
            'A Calling Station almost never bluffs. Which number should drive your call/fold '
            'decision vs their river bet?',
        options: [
          'Pot odds (is my hand good often enough?)',
          'MDF (am I folding too much?)',
          'Neither — always call',
        ],
        answer: 0,
        explanation:
            'MDF protects you from bluffers. When there are no bluffs to defend against, just ask '
            'whether your hand beats their value range often enough for the price.',
      ),
      QuizQuestion(
        prompt: 'Bigger bets mean your MDF…',
        options: [
          'goes down — you can fold more',
          'goes up — you must call more',
          "doesn't change",
        ],
        answer: 0,
        explanation:
            'MDF = pot/(pot+bet): as the bet grows the fraction shrinks. Big bets let you fold '
            'more; tiny bets demand wide defense.',
      ),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// 9.9 check-raising — Check-Raising
// ---------------------------------------------------------------------------

const Lesson _checkRaising = Lesson(
  id: 'check-raising',
  title: 'Check-Raising',
  minutes: 5,
  body: [
    ParagraphBlock(
      'Check with the intention of raising a bet — the strongest move you can make out of '
      "position, and one this course's bots respect.",
    ),
    ParagraphBlock(
      'Out of position you act first, which is a disadvantage. The check-raise flips that: you '
      "invite the in-position player's near-automatic continuation bet, then punish it. Your "
      'check-raising range should be built from two ends: **big hands** (sets, two pair, strong '
      'top pair on wet boards) that want a bigger pot, and **strong draws** (flush draws, '
      'open-enders — often with 8+ outs) that profit from folds now and can still hit when '
      'called.',
    ),
    HeadingBlock('Where it works'),
    ParagraphBlock(
      "Best on boards that favor the checker's range — low, connected flops that miss the "
      "raiser's big-card range. Size it meaningfully: around 3× their bet. Check-raising a dry "
      'A-K-x flop where the opener has all the aces mostly just donates information.',
    ),
    CalloutBlock(
      kind: CalloutKind.warning,
      title: 'Beware',
      body:
          'Never check-raising is itself a leak: it makes your checks an invitation to steal. '
          'Against auto-c-bettors, adding check-raises with draws is often the single most '
          'profitable adjustment.',
    ),
    QuizBlock([
      QuizQuestion(
        prompt:
            'Which hand type makes the best check-raise BLUFF on a 8♠7♠3♦ flop?',
        options: [
          'A♠9♠ (flush draw + overcard)',
          'K♦Q♣ (two overcards, no draw)',
          '3♣3♥ (bottom set)',
        ],
        answer: 0,
        explanation:
            'A set is a value raise, not a bluff. The ace-high flush draw has huge equity when '
            'called AND wins outright when they fold — the perfect semi-bluff (a bluff that can '
            'still improve to the best hand). KQ-high has too little to fall back on.',
      ),
      QuizQuestion(
        prompt: 'Why is the check-raise strongest OUT of position?',
        options: [
          'It converts acting first into a trap for automatic c-bets',
          'It hides your hand for later streets',
          "It's cheaper than betting",
        ],
        answer: 0,
        explanation:
            'Acting first is normally a cost. Checking invites the c-bet, and the raise punishes '
            "it — position's disadvantage becomes bait.",
      ),
    ]),
  ],
);
