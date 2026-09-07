/// Level 5 "Practice" — ported verbatim from the desktop
/// `src/components/study/lessons.tsx` (`LEVELS[4]`) and the glossary in
/// `src/components/study/Term.tsx`.
///
/// Rendering notes for the lesson reader:
///  * The first [ParagraphBlock] of every lesson is the desktop `Lead`
///    (slightly larger, full text colour).
///  * The Quick Reference "stat rows" (label left, mono gold value right) are
///    two-column [TableBlock]s with an all-empty header — the desktop draws no
///    header row, so the reader should skip a header whose cells are all empty.
///  * The glossary paragraphs mirror `GLOSSARY` in glossary order, formatted
///    `**term** — definition`, exactly as the desktop cheat sheet does.
library;

import 'lesson_model.dart';

const Level kLevel5Practice = Level(
  id: 'practice',
  title: 'Practice',
  icon: 'target',
  lessons: [
    _cheatSheet,
    _rangeExplorer,
    _equityCalculator,
    _drillPotOdds,
    _drillOuts,
    _drillRange,
  ],
);

/// Header used by the key/value stat-row tables (no visible header row).
const List<String> _kvHeader = ['', ''];

const Lesson _cheatSheet = Lesson(
  id: 'cheat-sheet',
  title: 'Quick Reference',
  minutes: 4,
  body: [
    ParagraphBlock(
      'Everything worth memorising, on one page. Come back to it any time.',
    ),
    HeadingBlock('Equity from outs (2 / 4 rule)'),
    TableBlock(
      header: _kvHeader,
      rows: [
        ['Per out — flop (×4) / turn (×2)', '≈ 4% / 2%'],
        ['Flush draw (9 outs)', '≈ 36% / 18%'],
        ['Open-ender (8)', '≈ 32% / 16%'],
        ['Gutshot (4)', '≈ 16% / 8%'],
      ],
    ),
    HeadingBlock('Common all-in matchups'),
    TableBlock(
      header: _kvHeader,
      rows: [
        ['Pair vs lower pair', '≈ 80 / 20'],
        ['Pair vs two overcards (race)', '≈ 55 / 45'],
        ['Dominated (AK vs AQ)', '≈ 70 / 30'],
        ['Set over set (flopped)', '≈ 90 / 10'],
      ],
    ),
    HeadingBlock('Prices'),
    TableBlock(
      header: _kvHeader,
      rows: [
        ['Break-even equity to call', 'call ÷ (pot + 2×bet)'],
        ['Pot bet → need', '33%'],
        ['Half-pot → need', '25%'],
        ['Bluff: pot bet → fold %', '50% (½-pot: 33%)'],
      ],
    ),
    HeadingBlock('SPR & position'),
    TableBlock(
      header: _kvHeader,
      rows: [
        ['SPR ≤ 3 → commit with', 'top pair+'],
        ['SPR 7+ → commit with', 'two pair / sets+'],
        ['UTG / CO / BTN opens', '~14% / 27% / 45%'],
        ['BB defend vs a raise', '~55%'],
      ],
    ),
    HeadingBlock('Glossary'),
    ParagraphBlock(
      'Tap any dotted term wherever it appears in a lesson to see this definition.',
    ),
    ParagraphBlock(
      '**UTG** — Under the Gun — the first seat to act pre-flop, just left of the big blind. '
      'The tightest position.',
    ),
    ParagraphBlock(
      '**MP** — Middle Position — a seat between the early players and the cutoff.',
    ),
    ParagraphBlock(
      '**CO** — Cutoff — the seat to the right of the button; a strong late position.',
    ),
    ParagraphBlock(
      '**BTN** — Button — the dealer seat. Acts last on every post-flop street; the best position.',
    ),
    ParagraphBlock(
      '**SB** — Small Blind — posts the smaller forced bet and acts first after the flop.',
    ),
    ParagraphBlock(
      '**BB** — Big Blind — posts the larger forced bet; last to act pre-flop. '
      'Also the unit we measure stacks and win-rate in.',
    ),
    ParagraphBlock(
      '**HUD** — Heads-Up Display — a small stats overlay on each opponent (here, their VPIP/PFR) '
      'that you read while playing.',
    ),
    ParagraphBlock(
      '**VPIP** — Voluntarily Put \$ In Pot — how often a player chooses to play a hand pre-flop '
      '(call or raise).',
    ),
    ParagraphBlock(
      '**PFR** — Pre-Flop Raise — how often a player raises pre-flop. Always ≤ VPIP.',
    ),
    ParagraphBlock(
      '**overcard** — A card higher in rank than your opponent\'s pair. '
      'AK vs 88 = two overcards (both beat the 8); A8 vs 99 = one overcard (only the ace beats the 9).',
    ),
    ParagraphBlock(
      '**set** — Three of a kind made when your pocket pair matches a board card (you hold 99, a 9 flops). '
      'Very strong and well disguised.',
    ),
    ParagraphBlock(
      '**kicker** — A side card that breaks ties within the same category. '
      'A-K beats A-Q on an ace because the king outkicks the queen.',
    ),
    ParagraphBlock(
      '**equity** — Your share of the pot — how often your hand wins if all remaining cards were dealt out.',
    ),
    ParagraphBlock(
      '**pot odds** — The price the pot offers you on a call: your call ÷ the final pot. '
      'Compare it to your equity.',
    ),
    ParagraphBlock(
      '**EV** — Expected Value — the average chips a decision wins or loses over the long run.',
    ),
    ParagraphBlock(
      '**SPR** — Stack-to-Pot Ratio — effective stack ÷ pot on the flop; tells you how committed you are.',
    ),
    ParagraphBlock(
      '**polarized** — A range of very strong hands and bluffs with little in between — usually bet large.',
    ),
    ParagraphBlock(
      '**c-bet** — Continuation bet — a follow-up bet on the flop by whoever raised pre-flop.',
    ),
    ParagraphBlock(
      '**range** — All the hands a player could have right now — not one specific holding.',
    ),
    ParagraphBlock(
      '**combo** — One specific two-card holding. 1,326 exist; AKs has 4 combos, AKo has 12, a pair has 6.',
    ),
    ParagraphBlock(
      '**blocker** — A card in your hand that removes combos from the opponent\'s range '
      '(you hold a card they\'d need).',
    ),
    ParagraphBlock(
      '**outs** — Cards still to come that improve you to a likely winner.',
    ),
    ParagraphBlock('**3-bet** — A re-raise of the first pre-flop raise.'),
    ParagraphBlock(
      '**draw** — An unmade hand that can improve — e.g. four to a flush or a straight.',
    ),
    ParagraphBlock('**the nuts** — The best possible hand on a given board.'),
  ],
);

const Lesson _rangeExplorer = Lesson(
  id: 'range-explorer',
  title: 'Range Explorer',
  minutes: 5,
  body: [
    ParagraphBlock(
      'Build ranges by hand. Load a position preset to see how a target percentage becomes real '
      'cells, or paint your own and watch the combo count — the same count the EV Coach quotes.',
    ),
    WidgetBlock(LessonWidgetKind.rangeExplorer),
  ],
);

const Lesson _equityCalculator = Lesson(
  id: 'equity-calculator',
  title: 'Equity Calculator',
  minutes: 5,
  body: [
    ParagraphBlock(
      'A free-form equity tool. Paint any two ranges, set a board, and the same Monte-Carlo engine '
      'the coach uses tells you how often you win.',
    ),
    WidgetBlock(LessonWidgetKind.equityCalculator),
  ],
);

const Lesson _drillPotOdds = Lesson(
  id: 'drill-potodds',
  title: 'Pot-Odds Drill',
  minutes: 5,
  body: [
    ParagraphBlock(
      'Random spots — compute the break-even equity in your head, then check yourself.',
    ),
    WidgetBlock(LessonWidgetKind.drillPotOdds),
  ],
);

const Lesson _drillOuts = Lesson(
  id: 'drill-outs',
  title: 'Outs → Equity Drill',
  minutes: 5,
  body: [
    ParagraphBlock(
      "Practise the 2/4 rule on random draws until it's automatic.",
    ),
    WidgetBlock(LessonWidgetKind.drillOuts),
  ],
);

const Lesson _drillRange = Lesson(
  id: 'drill-range',
  title: 'Range-Building Drill',
  minutes: 6,
  body: [
    ParagraphBlock(
      "Paint a position's opening range from memory, then score it against the standard.",
    ),
    WidgetBlock(LessonWidgetKind.drillRange),
  ],
);
