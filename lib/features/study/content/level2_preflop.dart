/// Level 2 "Pre-flop" of the Study curriculum, ported verbatim from the
/// desktop `src/components/study/lessons.tsx` (`LEVELS[1]`).
///
/// Desktop blurb (never rendered by the desktop UI; [Level] has no blurb
/// field): "The 13×13 matrix and opening ranges."
library;

import 'lesson_model.dart';

const Level kLevel2Preflop = Level(
  id: 'preflop',
  title: 'Pre-flop',
  icon: 'cards',
  lessons: [
    Lesson(
      id: 'matrix',
      title: 'The 13×13 Matrix',
      minutes: 5,
      body: [
        ParagraphBlock(
          'The 169 distinct starting hands fit neatly into a 13×13 grid — the standard way to '
          'describe a range: the set of hands a player would choose to play.',
        ),
        ParagraphBlock(
          'Pairs run down the diagonal. Suited hands sit in the upper-right triangle (e.g. AKs), and '
          'offsuit hands in the lower-left (AKo). There are 1,326 actual two-card combos: 6 per pair, '
          '4 per suited hand, 12 per offsuit hand.',
        ),
        // Desktop: topPercentRange(15) — 37 labels / 204 combos (port spec §14.1).
        RangeBlock(
          title: 'A tight ~15% range',
          topPct: 15,
          note:
              "Highlighted = hands you'd play. Notice how strong pairs and big suited cards "
              '(A, K, Q, J, 10) dominate.',
        ),
      ],
    ),
    Lesson(
      id: 'opening-ranges',
      title: 'Opening Ranges by Position',
      minutes: 6,
      body: [
        ParagraphBlock(
          'How wide you open (raise when no one has bet yet) should grow as you get closer to the '
          'button.',
        ),
        // Desktop shows the next two diagrams side by side (2-column grid on wide screens).
        // chartToSet(PREFLOP_100.rfi.UTG) — 35 labels / 206 combos. The "~15%" / "~45%" titles are
        // the desktop's hand-written approximations (real widths 15.5% / 49.3%); kept as written.
        RangeBlock(title: 'UTG open · ~15%', chart: 'rfi:UTG'),
        // chartToSet(PREFLOP_100.rfi.BTN) — 97 labels / 654 combos.
        RangeBlock(title: 'Button open · ~45%', chart: 'rfi:BTN'),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              "From UTG you're under the gun with five players still to act — only premium hands "
              'profit. On the button just two blinds remain, so you can attack with a huge range.',
        ),
      ],
    ),
    Lesson(
      id: 'three-betting',
      title: '3-Betting',
      minutes: 5,
      body: [
        ParagraphBlock(
          'A 3-bet is a re-raise of an opener. Used well it builds pots with your best hands and '
          'steals the chips already in the pot with the right bluffs.',
        ),
        // Desktop: chartToSet(PREFLOP_100.vsRfi.BTN_vs_CO.threebet, 0.4). chartToSet keeps hands with
        // frequency >= min and this chart only holds 1.0 / 0.5 / 0.25 entries, so the 0.4 threshold
        // gives exactly the default (0.5) set: TT JJ QQ KK AA AJs AQs AKs AKo AQo A5s A4s A3s KQs
        // (14 labels / 82 combos, port spec §14.2).
        RangeBlock(
          title: 'BTN 3-bet vs a CO open · ~5%',
          chart: 'vsRfi:BTN_vs_CO:threebet',
          note:
              'Big pairs and AK to build the pot, plus small suited aces as bluffs — your ace makes '
              'AA/AK less likely, and can still make the best possible flush.',
        ),
        ParagraphBlock(
          'Against a tight opener (a Nit), 3-bet only your premiums — they fold everything else and '
          'call only when they crush you. Against a loose-aggressive opener, widen for value.',
        ),
      ],
    ),
    Lesson(
      id: 'hud-reading',
      title: 'Reading the HUD: VPIP & PFR',
      minutes: 5,
      body: [
        ParagraphBlock(
          'A **HUD** (Heads-Up Display) is the small stats overlay shown on each opponent. In All-In '
          'it displays two numbers like `22/18` — the two most important stats for reading a player.',
        ),
        // Desktop: two side-by-side info cards, each an H + P.
        HeadingBlock('VPIP'),
        ParagraphBlock(
          '*Voluntarily Put \$ In Pot* — the % of hands a player chooses to play (call or raise) '
          "pre-flop. Posting a blind doesn't count. High VPIP = loose; low = tight.",
        ),
        HeadingBlock('PFR'),
        ParagraphBlock(
          '*Pre-Flop Raise* — the % of hands they raise pre-flop. PFR is always ≤ VPIP. A big gap '
          'between them means a passive caller.',
        ),
        ParagraphBlock(
          'The gap tells the story. VPIP ≈ PFR is an aggressive, raise-or-fold player. A wide gap '
          '(e.g. 45/7) is a passive Calling Station who limps (just calls the minimum instead of '
          "raising) and calls. Here's how the four bots look:",
        ),
        // Desktop: four archetype rows (colour dot · mono "vpip/pfr" · name · blurb) in the order
        // TAG, LAG, Nit, Station, values from src/game/archetypes.ts. The desktop rows have no
        // header; the labels below exist only because TableBlock requires one. Archetype colours
        // (#2f6fd0, #8a5cd1, #2faa66, #d23b3b) are a rendering detail the reader may add.
        TableBlock(
          header: ['VPIP/PFR', 'Bot', 'Style'],
          rows: [
            [
              '`22/18`',
              'Tight-Aggressive',
              'Plays few hands but bets and raises them hard. The textbook winner.',
            ],
            [
              '`34/27`',
              'Loose-Aggressive',
              'Plays many hands with relentless pressure. Hard to put on a hand.',
            ],
            [
              '`12/9`',
              'Nit',
              'Extremely tight. If a Nit raises, believe them.',
            ],
            [
              '`46/7`',
              'Calling Station',
              'Calls far too much, rarely raises. Value-bet relentlessly, never bluff.',
            ],
          ],
        ),
        CalloutBlock(
          kind: CalloutKind.key,
          title: 'Key idea',
          body:
              "Hover a bot's HUD in the game to see these numbers and a reminder of what they mean.",
        ),
        QuizBlock([
          QuizQuestion(
            prompt: 'A player is 45/7. What kind of opponent is this?',
            options: [
              'A tight, aggressive regular',
              'A loose, passive calling station',
              'A maniac who raises everything',
            ],
            answer: 1,
            explanation:
                'High VPIP (45) but very low PFR (7) = plays many hands but rarely raises — '
                'a calling station. Value bet, never bluff.',
          ),
          QuizQuestion(
            prompt: 'Can a player have a PFR higher than their VPIP?',
            options: ['Yes', 'No'],
            answer: 1,
            explanation:
                'Raising pre-flop is a way of voluntarily putting money in, so every raise is '
                'also counted in VPIP. PFR ≤ VPIP always.',
          ),
        ]),
      ],
    ),
  ],
);
