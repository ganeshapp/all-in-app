/// The study glossary — single source of truth for hover/tap definitions
/// (`{{key}}` inline markup in lesson text) and the glossary section of the
/// Quick Reference lesson. Ported verbatim from the desktop
/// `src/components/study/Term.tsx` (`GLOSSARY`).
///
/// Order matters: the cheat sheet lists the terms in this order. Keys are the
/// exact strings the desktop uses in `<Term id="...">`.
library;

import 'lesson_model.dart';

const List<GlossaryTerm> kGlossary = [
  GlossaryTerm(
    key: 'UTG',
    term: 'UTG',
    definition:
        'Under the Gun — the first seat to act pre-flop, just left of the big blind. The tightest position.',
  ),
  GlossaryTerm(
    key: 'MP',
    term: 'MP',
    definition:
        'Middle Position — a seat between the early players and the cutoff.',
  ),
  GlossaryTerm(
    key: 'CO',
    term: 'CO',
    definition:
        'Cutoff — the seat to the right of the button; a strong late position.',
  ),
  GlossaryTerm(
    key: 'BTN',
    term: 'BTN',
    definition:
        'Button — the dealer seat. Acts last on every post-flop street; the best position.',
  ),
  GlossaryTerm(
    key: 'SB',
    term: 'SB',
    definition:
        'Small Blind — posts the smaller forced bet and acts first after the flop.',
  ),
  GlossaryTerm(
    key: 'BB',
    term: 'BB',
    definition:
        'Big Blind — posts the larger forced bet; last to act pre-flop. Also the unit we measure stacks and '
        'win-rate in.',
  ),
  GlossaryTerm(
    key: 'HUD',
    term: 'HUD',
    definition:
        'Heads-Up Display — a small stats overlay on each opponent (here, their VPIP/PFR) that you read while '
        'playing.',
  ),
  GlossaryTerm(
    key: 'VPIP',
    term: 'VPIP',
    definition:
        'Voluntarily Put \$ In Pot — how often a player chooses to play a hand pre-flop (call or raise).',
  ),
  GlossaryTerm(
    key: 'PFR',
    term: 'PFR',
    definition:
        'Pre-Flop Raise — how often a player raises pre-flop. Always ≤ VPIP.',
  ),
  GlossaryTerm(
    key: 'overcard',
    term: 'overcard',
    definition:
        "A card higher in rank than your opponent's pair. AK vs 88 = two overcards (both beat the 8); "
        'A8 vs 99 = one overcard (only the ace beats the 9).',
  ),
  GlossaryTerm(
    key: 'set',
    term: 'set',
    definition:
        'Three of a kind made when your pocket pair matches a board card (you hold 99, a 9 flops). Very strong '
        'and well disguised.',
  ),
  GlossaryTerm(
    key: 'kicker',
    term: 'kicker',
    definition:
        'A side card that breaks ties within the same category. A-K beats A-Q on an ace because the king '
        'outkicks the queen.',
  ),
  GlossaryTerm(
    key: 'equity',
    term: 'equity',
    definition:
        'Your share of the pot — how often your hand wins if all remaining cards were dealt out.',
  ),
  GlossaryTerm(
    key: 'potOdds',
    term: 'pot odds',
    definition:
        'The price the pot offers you on a call: your call ÷ the final pot. Compare it to your equity.',
  ),
  GlossaryTerm(
    key: 'EV',
    term: 'EV',
    definition:
        'Expected Value — the average chips a decision wins or loses over the long run.',
  ),
  GlossaryTerm(
    key: 'SPR',
    term: 'SPR',
    definition:
        'Stack-to-Pot Ratio — effective stack ÷ pot on the flop; tells you how committed you are.',
  ),
  GlossaryTerm(
    key: 'polarized',
    term: 'polarized',
    definition:
        'A range of very strong hands and bluffs with little in between — usually bet large.',
  ),
  GlossaryTerm(
    key: 'cbet',
    term: 'c-bet',
    definition:
        'Continuation bet — a follow-up bet on the flop by whoever raised pre-flop.',
  ),
  GlossaryTerm(
    key: 'range',
    term: 'range',
    definition:
        'All the hands a player could have right now — not one specific holding.',
  ),
  GlossaryTerm(
    key: 'combo',
    term: 'combo',
    definition:
        'One specific two-card holding. 1,326 exist; AKs has 4 combos, AKo has 12, a pair has 6.',
  ),
  GlossaryTerm(
    key: 'blocker',
    term: 'blocker',
    definition:
        "A card in your hand that removes combos from the opponent's range (you hold a card they'd need).",
  ),
  GlossaryTerm(
    key: 'outs',
    term: 'outs',
    definition: 'Cards still to come that improve you to a likely winner.',
  ),
  GlossaryTerm(
    key: 'threeBet',
    term: '3-bet',
    definition: 'A re-raise of the first pre-flop raise.',
  ),
  GlossaryTerm(
    key: 'draw',
    term: 'draw',
    definition:
        'An unmade hand that can improve — e.g. four to a flush or a straight.',
  ),
  GlossaryTerm(
    key: 'nuts',
    term: 'the nuts',
    definition: 'The best possible hand on a given board.',
  ),
];

/// Glossary keyed by [GlossaryTerm.key] for `{{key}}` lookups in lesson text.
final Map<String, GlossaryTerm> kGlossaryByKey = Map.unmodifiable({
  for (final t in kGlossary) t.key: t,
});

/// The term for [key], or null when the key is unknown (the reader then shows
/// the display text as plain text — the desktop `Term` does the same).
GlossaryTerm? glossaryTerm(String key) => kGlossaryByKey[key];
