/// PokerStars-dialect hand-history IMPORT.
///
/// Port of the desktop `src/lib/hhImport.ts`. Parses the layout this app
/// exports (round-trip tested against `hand_history.dart`) and tolerates the
/// common variations in genuine PokerStars files ($ amounts, seat
/// annotations, "posts small & big blinds", uncalled-bet lines). Amount
/// units are preserved as written (chips or $ both parse).
///
/// The analyzer ([analyzeImported]) flags clearly bad hero calls as
/// [LeakSpot]s for the Review queue. Villain ranges are unknown in imports,
/// so equity runs vs a random hand (exact on the river) and only CLEAR
/// mistakes are flagged.
library;

import 'dart:math' show min;

import 'cards.dart';
import 'equity.dart';
import 'format.dart';
import 'hand_history.dart';
import 'notation.dart';
import 'prng.dart';
import 'types.dart';

/* ------------------------------------------------------------------
   Model
   ------------------------------------------------------------------ */

/// An [HHHand] that came from a hand-history file (desktop `ImportedHand`):
/// `imported` is always true and `heroName` is the "Dealt to" name (null
/// when no hero was found). Serialises exactly like the desktop's
/// `JSON.stringify(ImportedHand)` — the HHHand payload plus `imported` and
/// `heroName` — so the `hand_json` column round-trips.
class ImportedHand extends HHHand {
  ImportedHand({
    required super.id,
    required super.startedAt,
    required super.button,
    required super.sb,
    required super.bb,
    required super.sbSeat,
    required super.bbSeat,
    required super.seats,
    super.holes,
    super.actions,
    super.board,
    super.potResults,
    super.heroNet,
    required this.heroName,
  });

  /// Always true — kept as a field so callers can test `hand.imported` on
  /// any [HHHand] via `is ImportedHand` or the JSON flag.
  bool get imported => true;

  /// The name on the "Dealt to" line, or null.
  String? heroName;

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'imported': true,
    'heroName': heroName,
  };

  static ImportedHand fromJson(Map<String, Object?> j) {
    final base = HHHand.fromJson(j);
    return ImportedHand(
      id: base.id,
      startedAt: base.startedAt,
      button: base.button,
      sb: base.sb,
      bb: base.bb,
      sbSeat: base.sbSeat,
      bbSeat: base.bbSeat,
      seats: base.seats,
      holes: base.holes,
      actions: base.actions,
      board: base.board,
      potResults: base.potResults,
      heroNet: base.heroNet,
      heroName: j['heroName'] as String?,
    );
  }
}

/// Result of [parsePokerStars]: the hands that parsed and how many blocks
/// were skipped.
class ParseResult {
  const ParseResult({required this.hands, required this.skipped});
  final List<ImportedHand> hands;
  final int skipped;
}

/// Result of [analyzeImported]: how many hero calls were reviewed and the
/// leak spots flagged for the Review queue.
class ImportAnalysis {
  const ImportAnalysis({required this.reviewed, required this.leaks});
  final int reviewed;
  final List<LeakSpot> leaks;
}

/* ------------------------------------------------------------------
   Parser
   ------------------------------------------------------------------ */

final RegExp _cardRe = RegExp(r'^[2-9TJQKA][cdhs]$');

List<Card> _parseCards(String inside) =>
    inside
        .trim()
        .split(RegExp(r'\s+'))
        .where((c) => _cardRe.hasMatch(c))
        .toList();

final RegExp _moneyChars = RegExp(r'[$,]');
final RegExp _floatPrefix = RegExp(
  r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
);

/// JS `Number.parseFloat(s.replace(/[$,]/g, ""))`: parses the longest
/// numeric prefix, NaN when there is none. Integral values come back as
/// Dart ints so they print and serialise like JS numbers (`2000`, not
/// `2000.0`).
num _num(String s) {
  final cleaned = s.replaceAll(_moneyChars, '').trimLeft();
  final m = _floatPrefix.firstMatch(cleaned);
  if (m == null) return double.nan;
  return _jsNumber(double.parse(m[0]!));
}

/// Normalise a double the way JS numbers behave: integral values become
/// ints (so `'$v'` and `jsonEncode` match `String(n)` / `JSON.stringify`).
num _jsNumber(double d) {
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 9007199254740992) {
    return d.toInt();
  }
  return d;
}

/// JS `${number}` for a Dart num.
String _jsNumString(num v) {
  if (v is int) return v.toString();
  final d = v.toDouble();
  if (d.isFinite && d == d.truncateToDouble()) return jsIntString(d);
  return d.toString();
}

/// Parse a text blob of one-or-more PokerStars-style hands. Unparseable
/// blocks are skipped (count returned), never thrown.
///
/// [now] (epoch ms) is used as `startedAt` for hands whose header carries no
/// date (desktop `Date.now()`); defaults to the wall clock.
ParseResult parsePokerStars(String text, {int? now}) {
  final blocks =
      text
          .replaceAll('\r', '')
          .split(RegExp(r'\n{2,}(?=PokerStars )'))
          .map((b) => b.trim())
          .where((b) => b.startsWith('PokerStars '))
          .toList();
  final hands = <ImportedHand>[];
  int skipped = 0;
  for (final block in blocks) {
    try {
      final h = _parseOne(block, now);
      if (h != null) {
        hands.add(h);
      } else {
        skipped++;
      }
    } catch (_) {
      skipped++;
    }
  }
  return ParseResult(hands: hands, skipped: skipped);
}

/// Mutable seat while parsing (the desktop mutates `HHSeat` in place).
class _SeatDraft {
  _SeatDraft(this.seat, this.name, this.stack);
  final int seat;
  final String name;
  final num stack;
  bool isHero = false;
  Position position = Position.btn;

  HHSeat build() => HHSeat(
    seat: seat,
    name: name,
    stack: stack,
    isHero: isHero,
    position: position,
  );
}

final RegExp _headerRe = RegExp(
  r'Hand #(\d+):.*\(\$?([\d.,]+)/\$?([\d.,]+)(?:\s|\))',
);
final RegExp _dateRe = RegExp(
  r'- (\d{4})[/-](\d{2})[/-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
);
final RegExp _buttonRe = RegExp(r'Seat #(\d+) is the button');
final RegExp _seatRe = RegExp(r'^Seat (\d+): (.+?) \(\$?([\d.,]+) in chips\)');
final RegExp _sbRe = RegExp(r'^(.+?): posts small blind');
final RegExp _bbRe = RegExp(r'^(.+?): posts big blind');
final RegExp _dealtRe = RegExp(r'^Dealt to (.+?) \[([^\]]+)\]');
final RegExp _flopRe = RegExp(r'^\*\*\* FLOP \*\*\* \[([^\]]+)\]');
final RegExp _turnRe = RegExp(r'^\*\*\* TURN \*\*\* \[[^\]]+\] \[([^\]]+)\]');
final RegExp _riverRe = RegExp(r'^\*\*\* RIVER \*\*\* \[[^\]]+\] \[([^\]]+)\]');
final RegExp _shownRe = RegExp(
  r'^(?:Seat \d+: )?(.+?)[:]? (?:shows|showed) \[([^\]]+)\]',
);
final RegExp _foldRe = RegExp(r'^(.+?): folds');
final RegExp _checkRe = RegExp(r'^(.+?): checks');
final RegExp _callRe = RegExp(r'^(.+?): calls \$?([\d.,]+)( and is all-in)?');
final RegExp _betRe = RegExp(r'^(.+?): bets \$?([\d.,]+)( and is all-in)?');
final RegExp _raiseRe = RegExp(
  r'^(.+?): raises \$?[\d.,]+ to \$?([\d.,]+)( and is all-in)?',
);
final RegExp _collectedRe = RegExp(r'^(.+?) collected \$?([\d.,]+) from');
final RegExp _summaryWonRe = RegExp(
  r'^Seat \d+: (.+?) (?:\([^)]+\) )?(?:collected \(\$?([\d.,]+)\)|showed \[[^\]]+\] and won \(\$?([\d.,]+)\))',
);

const List<Position> _orderHeadsUp = [Position.btn, Position.bb];
const List<Position> _orderRing = [
  Position.btn,
  Position.sb,
  Position.bb,
  Position.utg,
  Position.mp,
  Position.co,
  Position.mp,
  Position.mp,
  Position.co,
];

ImportedHand? _parseOne(String block, int? now) {
  final lines = block.split('\n').map((l) => l.trim()).toList();
  final header = lines.isNotEmpty ? lines[0] : '';
  final hm = _headerRe.firstMatch(header);
  if (hm == null) return null;
  final sb = _num(hm[2]!);
  final bb = _num(hm[3]!);
  final dm = _dateRe.firstMatch(header);
  final startedAt =
      dm != null
          ? DateTime(
            int.parse(dm[1]!),
            int.parse(dm[2]!),
            int.parse(dm[3]!),
            int.parse(dm[4]!),
            int.parse(dm[5]!),
            int.parse(dm[6]!),
          ).millisecondsSinceEpoch
          : (now ?? DateTime.now().millisecondsSinceEpoch);

  final tm = lines.length > 1 ? _buttonRe.firstMatch(lines[1]) : null;
  final buttonSeatNo = tm != null ? int.parse(tm[1]!) : 1;

  // Seats
  final seats = <_SeatDraft>[];
  for (final l in lines) {
    final m = _seatRe.firstMatch(l);
    if (m != null) {
      seats.add(_SeatDraft(int.parse(m[1]!) - 1, m[2]!.trim(), _num(m[3]!)));
    }
  }
  if (seats.length < 2) return null;
  final byName = <String, _SeatDraft>{for (final s in seats) s.name: s};

  // Blinds
  int sbSeat = -1;
  int bbSeat = -1;
  for (final l in lines) {
    var m = _sbRe.firstMatch(l);
    if (m != null && byName.containsKey(m[1]!)) sbSeat = byName[m[1]!]!.seat;
    m = _bbRe.firstMatch(l);
    if (m != null && byName.containsKey(m[1]!)) bbSeat = byName[m[1]!]!.seat;
  }

  // Hero
  final holes = <int, List<Card>?>{};
  String? heroName;
  for (final l in lines) {
    final m = _dealtRe.firstMatch(l);
    if (m != null && byName.containsKey(m[1]!)) {
      final cs = _parseCards(m[2]!);
      if (cs.length == 2) {
        heroName = m[1]!;
        final s = byName[m[1]!]!;
        s.isHero = true;
        holes[s.seat] = [cs[0], cs[1]];
      }
    }
  }

  // Streets + actions + board
  Street street = Street.preflop;
  List<Card> board = <Card>[];
  final actions = <HHAction>[];
  for (final l in lines) {
    var m = _flopRe.firstMatch(l);
    if (m != null) {
      street = Street.flop;
      board = _parseCards(m[1]!);
      continue;
    }
    m = _turnRe.firstMatch(l);
    if (m != null) {
      street = Street.turn;
      board = [...board.take(3), ..._parseCards(m[1]!)];
      continue;
    }
    m = _riverRe.firstMatch(l);
    if (m != null) {
      street = Street.river;
      board = [...board.take(4), ..._parseCards(m[1]!)];
      continue;
    }
    if (l.startsWith('*** SHOW DOWN') || l.startsWith('*** SUMMARY')) {
      street = Street.showdown;
      continue;
    }
    if (street == Street.showdown) {
      // Collect shown cards from summary/showdown lines.
      final sm = _shownRe.firstMatch(l);
      if (sm != null && byName.containsKey(sm[1]!)) {
        final cs = _parseCards(sm[2]!);
        if (cs.length == 2) holes[byName[sm[1]!]!.seat] = [cs[0], cs[1]];
      }
      continue;
    }
    // Action lines
    var am = _foldRe.firstMatch(l);
    if (am != null && byName.containsKey(am[1]!)) {
      actions.add(
        HHAction(
          street: street,
          seat: byName[am[1]!]!.seat,
          name: am[1]!,
          type: ActionType.fold,
          amount: 0,
          allIn: false,
        ),
      );
      continue;
    }
    am = _checkRe.firstMatch(l);
    if (am != null && byName.containsKey(am[1]!)) {
      actions.add(
        HHAction(
          street: street,
          seat: byName[am[1]!]!.seat,
          name: am[1]!,
          type: ActionType.check,
          amount: 0,
          allIn: false,
        ),
      );
      continue;
    }
    am = _callRe.firstMatch(l);
    if (am != null && byName.containsKey(am[1]!)) {
      actions.add(
        HHAction(
          street: street,
          seat: byName[am[1]!]!.seat,
          name: am[1]!,
          type: ActionType.call,
          amount: _num(am[2]!),
          allIn: am[3] != null,
        ),
      );
      continue;
    }
    am = _betRe.firstMatch(l);
    if (am != null && byName.containsKey(am[1]!)) {
      actions.add(
        HHAction(
          street: street,
          seat: byName[am[1]!]!.seat,
          name: am[1]!,
          type: ActionType.bet,
          amount: _num(am[2]!),
          allIn: am[3] != null,
        ),
      );
      continue;
    }
    am = _raiseRe.firstMatch(l);
    if (am != null && byName.containsKey(am[1]!)) {
      actions.add(
        HHAction(
          street: street,
          seat: byName[am[1]!]!.seat,
          name: am[1]!,
          type: ActionType.raise,
          amount: _num(am[2]!),
          allIn: am[3] != null,
        ),
      );
      continue;
    }
  }

  // Winners from summary "collected" / "won" lines.
  final collected = <int, num>{};
  for (final l in lines) {
    final m = _collectedRe.firstMatch(l) ?? _summaryWonRe.firstMatch(l);
    if (m != null) {
      final name = m[1]!.trim();
      final amt = _num(m[2] ?? m[3] ?? '0');
      if (byName.containsKey(name) && amt > 0) {
        final seat = byName[name]!.seat;
        final prev = collected[seat] ?? 0;
        collected[seat] = amt > prev ? amt : prev;
      }
    }
  }
  final potResults = [
    for (final e in collected.entries)
      PotResult(winners: [e.key], amount: e.value, potLabel: 'Pot'),
  ];

  // Positions (relative to the button), best-effort for 2-9 players.
  final n = seats.length;
  final order = n == 2 ? _orderHeadsUp : _orderRing;
  for (final s in seats) {
    // JS `%` keeps the dividend's sign; a negative offset indexes past the
    // array (undefined) and falls back to "MP" on the desktop.
    final off = (s.seat - (buttonSeatNo - 1) + n).remainder(n);
    final idx = min(off, order.length - 1);
    s.position = idx >= 0 && idx < order.length ? order[idx] : Position.mp;
  }

  _SeatDraft? heroSeat;
  for (final s in seats) {
    if (s.isHero) {
      heroSeat = s;
      break;
    }
  }
  // Net is approximate on import (winnings only) — imported hands never
  // touch play statistics anyway.
  final heroNet = heroSeat != null ? (collected[heroSeat.seat] ?? 0) : 0;

  final idStr = hm[1]!;
  return ImportedHand(
    id: int.parse(idStr.length > 6 ? idStr.substring(idStr.length - 6) : idStr),
    startedAt: startedAt,
    button: buttonSeatNo - 1,
    sb: sb,
    bb: bb,
    sbSeat: sbSeat >= 0 ? sbSeat : (buttonSeatNo % n),
    bbSeat: bbSeat >= 0 ? bbSeat : ((buttonSeatNo + 1) % n),
    seats: seats.map((s) => s.build()).toList(),
    holes: holes,
    actions: actions,
    board: board,
    potResults: potResults,
    heroNet: heroNet,
    heroName: heroName,
  );
}

/* ------------------------------------------------------------------
   Analyzer: flag questionable hero calls for the Review queue.
   Villain ranges are unknown in imports, so equity runs vs random
   hands (exact on the river) and only CLEAR mistakes are flagged.
   ------------------------------------------------------------------ */

/// Number of Monte-Carlo trials per reviewed call (desktop constant).
const int kImportEquityIters = 2500;

/// Margin added on top of the pessimistic-edge equity before a call is
/// called a clear mistake (desktop constant).
const double kImportMistakeMargin = 0.08;

/// Walk every imported hand's action list and flag hero calls whose equity
/// vs a random hand — even at the top of its confidence band — is still
/// well below the price. [now] (epoch ms) becomes each spot's `ts`.
ImportAnalysis analyzeImported(List<ImportedHand> hands, {int? now}) {
  final leaks = <LeakSpot>[];
  int reviewed = 0;

  for (final h in hands) {
    HHSeat? hero;
    for (final s in h.seats) {
      if (s.isHero) {
        hero = s;
        break;
      }
    }
    final hole = hero != null ? h.holes[hero.seat] : null;
    if (hero == null || hole == null || hole.length != 2) continue;

    // Walk actions, tracking pot and per-street committed.
    num pot = h.sb + h.bb;
    final committed = <int, num>{};
    committed[h.sbSeat] = h.sb;
    committed[h.bbSeat] = h.bb;
    Street street = Street.preflop;
    for (final a in h.actions) {
      if (a.street != street) {
        street = a.street;
        committed.updateAll((_, _) => 0);
      }
      final prev = committed[a.seat] ?? 0;
      if (a.type == ActionType.call) {
        if (a.seat == hero.seat && a.amount > 0) {
          reviewed++;
          final boardNow =
              street == Street.preflop
                  ? <Card>[]
                  : street == Street.flop
                  ? h.board.take(3).toList()
                  : street == Street.turn
                  ? h.board.take(4).toList()
                  : h.board.take(5).toList();
          final needed = a.amount / (pot + a.amount);
          final r = equityVsRandom(
            comboToInts((hole[0], hole[1])),
            boardNow.map(cardToInt).toList(),
            iters: kImportEquityIters,
            seed: hashSeed(
              'imp|${h.startedAt}|${street.label}|${_jsNumString(a.amount)}',
            ),
          );
          // Clear mistake only: pessimistic-edge equity still below price by a wide margin.
          if (r.equity + 2 * r.se + kImportMistakeMargin < needed) {
            final callBb = a.amount / h.bb;
            leaks.add(
              LeakSpot(
                id: 'imp-${h.startedAt}-${street.label}',
                street: street,
                heroPos: hero.position,
                hole: [hole[0], hole[1]],
                board: boardNow,
                pot: _jsNumber(pot / h.bb),
                toCall: _jsNumber(callBb),
                bb: 1,
                oppActive: [
                  for (final s in h.seats)
                    if (!s.isHero) s.position,
                ],
                options: [
                  const DrillOption(action: DrillAction.fold, label: 'Fold'),
                  DrillOption(
                    action: DrillAction.call,
                    label: 'Call ${jsToFixed(callBb.toDouble(), 1)} bb',
                    amount: callBb.toDouble(),
                  ),
                ],
                best: DrillAction.fold,
                rationale:
                    'Imported hand: you called ${jsToFixed(callBb.toDouble(), 1)} bb needing ${jsRound(needed * 100).toInt()}% but ${cardsToLabel(hole[0], hole[1])} wins only ~${jsRound(r.equity * 100).toInt()}% even against a random hand — real ranges make it worse.',
                equity: r.equity,
                potOdds: needed.toDouble(),
                ts: now ?? DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
        }
        committed[a.seat] = prev + a.amount;
        pot += a.amount;
      } else if (a.type == ActionType.bet || a.type == ActionType.raise) {
        pot += a.amount - prev;
        committed[a.seat] = a.amount;
      }
    }
  }
  return ImportAnalysis(reviewed: reviewed, leaks: leaks);
}

/* ------------------------------------------------------------------
   Import-result copy (desktop StatsView.onImportFile, verbatim)
   ------------------------------------------------------------------ */

/// Message shown when a file contained no PokerStars-style hands.
String importEmptyText(int skipped) =>
    "Couldn't find any PokerStars-style hands in that file${skipped != 0 ? ' ($skipped blocks unparseable)' : ''}.";

/// Message shown after a successful import.
String importSummaryText({
  required int hands,
  required int skipped,
  required int reviewed,
  required int leaks,
}) =>
    'Imported $hands hand${hands == 1 ? '' : 's'}${skipped != 0 ? ' ($skipped skipped)' : ''} · reviewed $reviewed of your calls · ${leaks != 0 ? '$leaks questionable one${leaks == 1 ? '' : 's'} added to the Review queue' : 'no clear mistakes found'}. Imported hands never count toward your play stats.';
