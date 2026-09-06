/// Level 1 "Basics" of the Study curriculum, ported verbatim from the desktop
/// `src/components/study/lessons.tsx` (`LEVELS[0]`). Lesson ids, titles,
/// minutes and order are a public contract (drills deep-link by lesson id).
library;

import 'lesson_model.dart';

const Level kLevel1 = Level(
  id: 'basics',
  title: 'Basics',
  icon: 'book',
  lessons: [
    // ------------------------------------------------------------------
    // 7.1 hand-rankings — Hand Rankings (4 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'hand-rankings',
      title: 'Hand Rankings',
      minutes: 4,
      body: [
        ParagraphBlock(
          "Every hand of Texas Hold'em is a race to make the best five-card hand from your two hole "
          'cards and the five community cards. Memorising the ranking order is non-negotiable.',
        ),
        WidgetBlock(LessonWidgetKind.handRankings),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'When two players share the same category, the higher cards (kickers) decide it. Aces are '
              'high, except in the "wheel" straight 5-4-3-2-A where the ace plays low.',
        ),
        QuizBlock([
          QuizQuestion(
            prompt: 'Which hand wins: a flush or a straight?',
            options: ['Straight', 'Flush', 'They tie'],
            answer: 1,
            explanation:
                'A flush (five of one suit) beats a straight (five in a row, mixed suits).',
          ),
          QuizQuestion(
            prompt:
                "You hold A♦Q♣ on a board of A♠ K♦ 4♥ 9♣ 2♠. What's your hand?",
            options: ['Two pair', 'A pair of Aces, Queen kicker', 'Ace high'],
            answer: 1,
            explanation:
                'You pair your Ace; your second card (Q) is the kicker. No second pair is on board for you.',
          ),
        ]),
      ],
    ),

    // ------------------------------------------------------------------
    // 7.2 position — Position & the Button (5 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'position',
      title: 'Position & the Button',
      minutes: 5,
      body: [
        ParagraphBlock(
          'Position is the single most undervalued edge for new players. Acting last means you make '
          'every decision with more information than your opponents.',
        ),
        HeadingBlock('The six seats', level: 3),
        ParagraphBlock(
          'Each seat has a name and acts in a fixed order. The dealer **button** is the best seat '
          'because it acts last in every betting round after the flop. Moving clockwise from it, the '
          '**small blind** and **big blind** post forced bets, then play runs through the early '
          'and middle seats to the cutoff and back to the button. (Hover the dotted terms for a '
          'definition; the full glossary lives in Practice → Quick Reference.)',
        ),
        // Desktop renders these as a 2-column grid of six seat cards
        // (abbreviation as a glossary hover, full name, note).
        TableBlock(
          header: ['Seat', 'Name', 'Note'],
          rows: [
            [
              '{{UTG}}',
              'Under the Gun',
              'Earliest — acts first, play tightest',
            ],
            ['{{MP}}', 'Middle Position', 'Early / middle'],
            ['{{CO}}', 'Cutoff', 'Late — raise more hands'],
            [
              '{{BTN}}',
              'Button (dealer)',
              'Latest — best seat, most hands playable',
            ],
            ['{{SB}}', 'Small Blind', 'Forced bet, acts first post-flop'],
            ['{{BB}}', 'Big Blind', 'Forced bet, last to act pre-flop'],
          ],
        ),
        CalloutBlock(
          kind: CalloutKind.tip,
          title: 'Rule of thumb',
          body: 'Play fewer hands up front, more hands on the button.',
        ),
      ],
    ),

    // ------------------------------------------------------------------
    // 7.3 bankroll — Bankroll & Mindset (4 min)
    // ------------------------------------------------------------------
    Lesson(
      id: 'bankroll',
      title: 'Bankroll & Mindset',
      minutes: 4,
      body: [
        ParagraphBlock(
          'Poker is a game of edges realised over thousands of hands. Variance means even perfect play '
          'loses regularly in the short run.',
        ),
        ParagraphBlock(
          'Think in big blinds (bb), not chips — it makes decisions stake-independent. A solid winner '
          "earns only a few bb per 100 hands, so protect against tilt and never risk money you can't "
          'afford to lose. In this trainer your stack auto-resets, so focus on decision quality, not '
          'the scoreboard.',
        ),
        HeadingBlock('Win-rate: bb/100', level: 3),
        ParagraphBlock(
          'Win-rate is measured in big blinds won per 100 hands ("bb/100"). It\'s stake-independent, so '
          'you can compare any games. A strong winner makes only a few bb/100; anything from −5 to +10 '
          'is normal, and over small samples it swings wildly. The Stats page and the session rail both '
          'show your bb/100.',
        ),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              'Results are noise; decisions are signal. The EV Coach grades the decision.',
        ),
      ],
    ),
  ],
);
