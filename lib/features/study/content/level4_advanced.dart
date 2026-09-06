/// Level 4 "Advanced" of the Study curriculum, ported verbatim from the desktop
/// `src/components/study/lessons.tsx` (`LEVELS[3]`). Lesson ids, titles,
/// minutes and order are a public contract: drills deep-link by lesson id
/// (`exploits`, `spr`, `threebet-pots`, `turn-river`) and onboarding placement
/// lands on `threebet-pots`.
library;

import 'lesson_model.dart';

const Level kLevel4Advanced = Level(
  id: 'advanced',
  title: 'Advanced',
  icon: 'bolt',
  lessons: [
    // ------------------------------------------------------------------
    // 10.1 combinatorics — Combinatorics & Blockers (6 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'combinatorics',
      title: 'Combinatorics & Blockers',
      minutes: 6,
      body: [
        ParagraphBlock(
          'Counting combos turns "I feel like he has it" into a number. There are 6 ways to make any '
          'pocket pair, 4 ways for a suited hand, 12 for an offsuit hand.',
        ),
        ParagraphBlock(
          "A blocker is a card in your hand that removes combos from your opponent's range. Holding "
          "the A♠ on a flush-draw board means they can't have the ace-high flush draw (you hold the "
          'A♠) — fewer of their bluffs and value hands exist, which makes your bluffs and calls work '
          'more often.',
        ),
        HeadingBlock('Worked example', level: 3),
        ParagraphBlock(
          'The board is K♠ 9♦ 4♣. How many combos of top pair (a King) can your opponent have? '
          'Normally KK = 6 and each non-paired King hand like KQ = 16 combos — but the K♠ on the '
          'board is a blocker. With one King gone, KK drops to 3 combos and KQ to 12. Counting this '
          'way tells you there are far fewer value hands than it feels like.',
        ),
        // Desktop renders these as a 3-column grid of stat cells
        // (big mono number on top, small label underneath).
        TableBlock(
          header: ['Hand type', 'Combos'],
          rows: [
            ['Any pocket pair', '6 combos'],
            ['Suited (e.g. AKs)', '4 combos'],
            ['Offsuit (e.g. AKo)', '12 combos'],
          ],
        ),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'Holding one card of a pair cuts their pair combos from 6 down to 3.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt:
                'How many combos of pocket Aces (AA) are there before any cards are dealt?',
            options: ['4', '6', '12'],
            answer: 1,
            explanation:
                'Choose 2 of the 4 aces: C(4,2) = 6 combos. Every pocket pair has 6.',
          ),
          QuizQuestion(
            prompt:
                'You hold A♠. How many combos of AA can your opponent now have?',
            options: ['6', '3', '1'],
            answer: 1,
            explanation:
                'Your A♠ removes one ace, leaving 3 aces → C(3,2) = 3 combos. '
                "That's the power of a blocker.",
          ),
          QuizQuestion(
            prompt: 'How many combos does an offsuit hand like KQo have?',
            options: ['4', '12', '16'],
            answer: 1,
            explanation:
                '4 kings × 3 non-matching-suit queens = 12 offsuit combos.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.2 hand-reading — Hand Reading: Narrowing a Range (7 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'hand-reading',
      title: 'Hand Reading: Narrowing a Range',
      minutes: 7,
      body: [
        ParagraphBlock(
          "Good players don't guess one hand — they track a whole range and shrink it street by "
          "street as the story unfolds. Here's the repeatable method.",
        ),
        HeadingBlock('The four steps', level: 3),
        ParagraphBlock(
          "1. **Start wide** from their position and type — a Nit's UTG range is tiny; a LAG's "
          'button range is huge. 2. **Subtract on every action**: a raise keeps value plus chosen '
          "bluffs; a call removes both the very top (they'd raise) and the bottom (they'd fold). "
          '3. **Apply the board**: ask "which of their hands improved, and would they keep betting '
          'or calling it?" Remove the complete misses they\'d give up. 4. **Compare** your hand to '
          'the handful of combos left — not to one imagined holding.',
        ),
        // Desktop: a 3-column grid of three read-only range diagrams built with
        // topPercentRange(40 / 20 / 10); no notes.
        RangeBlock(title: 'Pre-flop: opens ~40%', topPct: 40),
        RangeBlock(title: 'Continues flop ~20%', topPct: 20),
        RangeBlock(title: 'Bets again on turn ~10%', topPct: 10),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'By the river, big aggressive lines are often **polarized** — the best possible hand '
              "or a bluff. Don't pay off the value half with a hand that only beats bluffs unless "
              'the price is right.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt:
                'A call (rather than a raise) usually removes which hands from a range?',
            options: [
              'Only the weakest hands',
              'Both the strongest (would raise) and the weakest (would fold)',
              'Nothing — calls are random',
            ],
            answer: 1,
            explanation:
                'Calling trims a range at both ends: the strongest hands raise, the weakest fold, '
                'leaving the middle.',
          ),
          QuizQuestion(
            prompt:
                'A tight player check-raises the river. Their range is best described as…',
            options: [
              'Wide and weak',
              'Polarized — very strong hands and a few bluffs',
              'Exactly one hand',
            ],
            answer: 1,
            explanation:
                'Big river aggression from a tight player is polarized: value or bluff, little in '
                'between.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.3 exploits — Exploiting the Archetypes (6 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'exploits',
      title: 'Exploiting the Archetypes',
      minutes: 6,
      body: [
        ParagraphBlock(
          'The bots in the Sandbox play four classic styles. Each leaks differently.',
        ),
        // Desktop: four archetype cards in the order TAG, LAG, Nit, Station. Each has a
        // header line "{name} ({key})" with a faint mono "VPIP x / PFR y" (values from
        // game/archetypes.ts) and the advice text underneath. No callout, no quiz.
        HeadingBlock('Tight-Aggressive (TAG)', level: 3),
        ParagraphBlock('`VPIP 22 / PFR 18`'),
        ParagraphBlock(
          "Solid and balanced. Respect their raises; pick spots, don't bluff into strength.",
        ),
        HeadingBlock('Loose-Aggressive (LAG)', level: 3),
        ParagraphBlock('`VPIP 34 / PFR 27`'),
        ParagraphBlock(
          'Hyper-aggressive. Trap with strong hands and let them keep betting into you.',
        ),
        HeadingBlock('Nit (Nit)', level: 3),
        ParagraphBlock('`VPIP 12 / PFR 9`'),
        ParagraphBlock(
          'Folds too much. Steal relentlessly, but believe them when they finally raise.',
        ),
        HeadingBlock('Calling Station (Station)', level: 3),
        ParagraphBlock('`VPIP 46 / PFR 7`'),
        ParagraphBlock(
          'Calls everything. Never bluff — value bet thin and bet big with strong hands.',
        ),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.4 multiway — Playing Multiway (6 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'multiway',
      title: 'Playing Multiway',
      minutes: 6,
      body: [
        ParagraphBlock(
          'Almost everything else assumes one opponent. Add players and the maths shifts — this is '
          'the piece most training tools skip.',
        ),
        HeadingBlock('Your equity to win drops', level: 3),
        ParagraphBlock(
          'A hand that wins ~55% heads-up might win only ~30% against three opponents — more '
          'players means more ways to be beaten. Drawing hands also get paid less reliably because '
          "someone may already have the made hand you're drawing to.",
        ),
        HeadingBlock(
          'Pot odds still hold, but realised equity is lower',
          level: 3,
        ),
        ParagraphBlock(
          'Break-even equity (call ÷ final pot) is unchanged, but your real chance of winning is '
          'lower multiway and players still to act can wake up with a hand. So continue with a '
          'stronger range, bluff less (someone usually calls), and value-bet your big hands bigger. '
          'Speculative hands — suited connectors, small pairs — go up in value because implied odds '
          'are huge when you hit.',
        ),
        HeadingBlock('See it for yourself', level: 3),
        ParagraphBlock(
          'Pick a hand and slide the opponent count — watch equity fall as the field grows.',
        ),
        WidgetBlock(LessonWidgetKind.multiwayEquityTrainer),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'The in-game EV Coach now computes your equity against the whole field in multiway '
              'pots (not just heads-up), so its numbers already reflect this. Stronger hands still '
              'matter more the more players are in.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt:
                'As more players enter the pot, your continuing range should get…',
            options: ['Wider', 'Tighter', 'Unchanged'],
            answer: 1,
            explanation:
                'More opponents = more ways to lose, so tighten up and continue with stronger hands.',
          ),
          QuizQuestion(
            prompt: 'Multiway, should you bluff more or less than heads-up?',
            options: ['More', 'Less'],
            answer: 1,
            explanation:
                "With more players, it's far likelier someone calls — bluffs get through much less "
                'often.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.5 spr — SPR & Commitment (5 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'spr',
      title: 'SPR & Commitment',
      minutes: 5,
      body: [
        ParagraphBlock(
          'Stack-to-Pot Ratio (SPR) = the effective stack divided by the pot on the flop. One '
          'number tells you how committed you are and which hands are worth stacking off (putting '
          'your whole stack in).',
        ),
        // Desktop: three stat rows (mono SPR band on the left, guideline on the right).
        TableBlock(
          header: ['SPR', 'Guideline'],
          rows: [
            [
              'SPR ≤ 3 (low)',
              'Committed — get it in with top pair / overpair or better.',
            ],
            [
              'SPR 4–6 (medium)',
              'Top pair good kicker is playable, but big draws and two pair want the money in.',
            ],
            [
              'SPR 7+ (high)',
              'Stack off only with two pair, sets and better — one pair rarely justifies 100bb.',
            ],
          ],
        ),
        ParagraphBlock(
          'SPR is set **before** the flop: more raises and callers build a bigger pot and shrink '
          "the SPR, widening what you'll commit. 3-bet pots are low-SPR (commit lighter); limped "
          '(everyone just called the minimum) and single-raised pots are high-SPR (need a stronger '
          'hand to stack off).',
        ),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'Decide your stack-off threshold on the flop from the SPR — then stop agonising street '
              'by street.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt: 'A high SPR means you should commit your stack with…',
            options: [
              'Any top pair',
              'Stronger hands (two pair, sets+)',
              'Any pair',
            ],
            answer: 1,
            explanation:
                'Deep relative to the pot, one pair is rarely worth stacking off — you want two pair '
                'or better.',
          ),
          QuizQuestion(
            prompt: 'A 3-bet pot tends to create a…',
            options: ['Low SPR', 'High SPR'],
            answer: 0,
            explanation:
                'The bigger pre-flop pot relative to remaining stacks means a low SPR, so you commit '
                'lighter.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.6 threebet-pots — Playing 3-Bet Pots (6 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'threebet-pots',
      title: 'Playing 3-Bet Pots',
      minutes: 6,
      body: [
        ParagraphBlock(
          'Re-raised pots are a different game: ranges are tighter, the pot is bigger relative to '
          'stacks, and one bet can commit you.',
        ),
        ParagraphBlock(
          'After a 3-bet and call, the pot is ~20 bb with ~90 bb behind — an SPR around 4-5 instead '
          'of 12+. That changes everything: **top pair good kicker becomes a stack-off hand** where '
          "in a single-raised pot you'd keep the pot small with it. Meanwhile hands that love deep "
          "stacks (small pairs hunting sets, suited connectors) lose value — there isn't enough "
          'money behind to pay off their big hits.',
        ),
        HeadingBlock('Who has the range advantage?', level: 3),
        ParagraphBlock(
          "The 3-bettor's range is packed with big pairs and big cards, so A-high and K-high flops "
          "favor them massively — c-bet small and often. Low connected flops hit the CALLER's pairs "
          'and suited hands more; as the 3-bettor, slow down there. This "who does the flop help?" '
          'question decides most 3-bet pots.',
        ),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'Before the flop comes down, know your plan: with QQ+ in a 3-bet pot at SPR 4, the '
              'answer is usually "all the chips are going in". Deciding this early stops you from '
              'talking yourself into a fold on a scary-looking turn.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt:
                'In a 3-bet pot at SPR ~4 you hold A♥K♦ and flop K♠8♦3♣. Your default plan is…',
            options: [
              'Value bet and be willing to stack off',
              'Check to keep the pot small',
              'Bet once, then give up unimproved',
            ],
            answer: 0,
            explanation:
                "Top pair top kicker at low SPR in a range-vs-range battle you're winning is a "
                'stack-off hand. Small pots are for single-raised, deep-stack situations.',
          ),
          QuizQuestion(
            prompt:
                'Which hand LOSES the most value moving from a single-raised pot to a 3-bet pot?',
            options: ['6♥6♣ (set mining)', 'Q♥Q♦ (overpair potential)', 'A♠K♠'],
            answer: 0,
            explanation:
                "Set mining needs ~10x implied odds. In a 3-bet pot there isn't enough money behind "
                'relative to the price — small pairs hate re-raised pots.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.7 equity-realization — Equity Realization (5 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'equity-realization',
      title: 'Equity Realization',
      minutes: 5,
      body: [
        ParagraphBlock(
          'Raw equity is what your hand would win at showdown with no more betting. You never get '
          'that — position and playability decide how much of it you actually collect.',
        ),
        ParagraphBlock(
          '9♠8♠ has ~38% equity against a big-card hand, but it **realizes** more than that in '
          'position (you see cheap turns, bluff good rivers, fold before big mistakes) and less out '
          'of position. As a rule: in position with a playable hand you realize 100%+ of raw '
          'equity; out of position with a weak offsuit hand you might realize only 70-80%.',
        ),
        HeadingBlock('What this changes', level: 3),
        ParagraphBlock(
          "It's the hidden reason behind chart shapes you've seen: suited and connected hands "
          'defend wide IN POSITION; offsuit junk folds even at "correct" pot odds OUT of position. '
          'When the coach says a call is marginal, ask: am I in position to realize my share? A '
          "break-even call by raw equity is a losing call if you'll only realize 80% of it.",
        ),
        CalloutBlock(
          kind: CalloutKind.tip,
          title: 'Rule of thumb',
          body:
              'Discount your equity ~10-20% when out of position with a hand that plays poorly '
              '(offsuit, disconnected). Marginal calls need that margin.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt: 'Which hand realizes its raw equity BEST?',
            options: [
              'T♠9♠ on the button',
              'T♠9♠ in the small blind',
              'K♣3♦ in the small blind',
            ],
            answer: 0,
            explanation:
                'Suited, connected, and in position: it sees cheap cards, wins extra pots with '
                'bluffs, and escapes cheaply when beaten. The same hand out of position realizes '
                'less; K3o out of position is the worst of all worlds.',
          ),
          QuizQuestion(
            prompt:
                "You're getting exactly break-even pot odds out of position with a weak offsuit "
                'hand. The call is…',
            options: [
              "A losing call — you won't realize full equity",
              'Exactly break-even',
              'Profitable — pot odds are all that matter',
            ],
            answer: 0,
            explanation:
                'Pot-odds math assumes you collect your full showdown equity. Out of position with '
                "a poorly-playing hand you won't — so break-even by the formula is losing in "
                'practice.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.8 turn-river — Turn & River Play (6 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'turn-river',
      title: 'Turn & River Play',
      minutes: 6,
      body: [
        ParagraphBlock(
          'Each street, ranges get narrower and equities move toward the extremes. By the river '
          'there are no draws left — only value bets, bluffs, and bluff-catchers.',
        ),
        HeadingBlock('The turn: the pressure street', level: 3),
        ParagraphBlock(
          'Calling the flop is cheap; calling the turn is not. Bet again on turns that improve your '
          'range or dent theirs (overcards to their pairs, completing YOUR draws). With one card to '
          'come, draws are worth roughly **2% per out** — half their flop value — so the price to '
          "chase gets worse exactly as the bets get bigger. That's why the coach's turn verdicts "
          'flip to fold more often than beginners expect.',
        ),
        HeadingBlock('The river: pure decisions', level: 3),
        ParagraphBlock(
          'River betting is binary: **value** (worse hands call) or **bluff** (better hands fold). '
          "Before betting, name the actual hands that call you while losing — if you can't, it "
          "isn't a value bet. Facing a bet, your hand is usually a bluff-catcher: it beats bluffs, "
          'loses to value. Then the only question is "does this player bluff here often enough?" — '
          'count the price (a pot-sized bet needs them bluffing 1 time in 3), then judge the player.',
        ),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              '"What am I trying to get called by / what am I trying to fold out?" If a river bet '
              'has no answer to either question, check.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt:
                'You river a weak top pair. Your opponent (a Nit who never bluffs) bets the pot. '
                'Your hand beats bluffs but loses to all their value hands. Call or fold?',
            options: [
              'Fold — no bluffs means no bluff-catching',
              'Call — you need to defend your MDF',
              'Raise as a bluff',
            ],
            answer: 0,
            explanation:
                'A bluff-catcher is only worth calling if there are bluffs to catch. Against a '
                'player who has them, the same call is fine — the player, not the formula, decides '
                'river calls.',
          ),
          QuizQuestion(
            prompt:
                'A flush draw (9 outs) on the TURN is worth roughly what equity?',
            options: ['~18% (2% per out)', '~36% (4% per out)', '~9%'],
            answer: 0,
            explanation:
                "With one card to come it's ~2% per out. The 4% shortcut is for flop-to-river with "
                'both cards — a common and expensive mix-up.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 10.9 synthesis — Putting It Together (3 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'synthesis',
      title: 'Putting It Together',
      minutes: 3,
      body: [
        ParagraphBlock(
          'You now have the full toolkit: rankings, position, ranges, odds and exploits.',
        ),
        ParagraphBlock(
          'Head to the Sandbox. Before each decision, use Guess Range to test your read, then act '
          'and let the EV Coach grade you. Watch your bb/100 and read accuracy climb on the Stats '
          'page over time. That feedback loop — decide, measure, adjust — is how real players '
          'improve.',
        ),
        CalloutBlock(
          kind: CalloutKind.tip,
          title: 'Your move',
          body: 'Open the Play tab and run 50 hands focusing only on position.',
        ),
      ],
    ),
  ],
);
