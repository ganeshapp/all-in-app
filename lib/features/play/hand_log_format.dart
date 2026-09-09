/// Rewrites the engine's hand log for the phone — the ticker (DESIGN.md §4.2),
/// the P2 Log (§4.11) and the "copy hand log" clipboard text.
///
/// The engine's log strings are the desktop's and are pinned by parity tests,
/// so `lib/engine` is never touched. They are wrong for this app in two ways:
///
/// * they are third person for every player, including the hero, whose name is
///   literally "You" — "You raises to 58", "You folds", "You wins 88";
/// * amounts are in **chips**, while every other surface on the phone speaks
///   big blinds (§4.4, §4.5, §10.3 all use `fmtBb`).
///
/// [HandLog] re-renders each [LogEntry] line: second-person verbs for the hero,
/// third person for the bots, and every amount through `fmtBb` with a " bb"
/// unit. Lines it does not recognise (mobile-authored ticker overrides, §14
/// states) pass through unchanged.
library;

import '../../engine/engine.dart';

/// One log line as the phone shows it.
class HandLogLine {
  const HandLogLine({
    required this.entry,
    required this.text,
    required this.isHero,
  });

  /// The engine entry this line was rendered from.
  final LogEntry entry;

  /// The rewritten text — what the ticker, P2 and the clipboard show.
  final String text;

  /// True when the hero is the (or a) subject: P2 renders those in `text`
  /// colour rather than the kind colour (§4.11).
  final bool isHero;

  LogKind get kind => entry.kind;
  Street get street => entry.street;
  int get id => entry.id;
}

abstract final class HandLog {
  /// The engine's hero player name (`hand_engine.dart`: `isHero ? 'You' : …`).
  static const String heroName = 'You';

  /// `Hand #3 · blinds 10/20 · ante 5`.
  static final RegExp _header = RegExp(
    r'^Hand #(\d+) · blinds ([\d.]+)/([\d.]+)(?: · ante ([\d.]+))?$',
  );

  /// `Dwan raises to 60 (all-in)` — one subject, one verb, an optional amount.
  static final RegExp _action = RegExp(
    r'^(.+?) '
    r'(folds|checks|calls|bets|raises to|'
    r'posts SB|posts BB|posts small blind|posts big blind|posts ante)'
    r'(?: ([\d.]+))?'
    r'( \(all-in\))?$',
  );

  /// `You, Ivey wins 520 (Pot)` / `Polk wins 88 (uncontested)`.
  static final RegExp _result = RegExp(r'^(.+?) wins ([\d.]+) \(([^()]*)\)$');

  /// Second-person form of every verb the engine writes.
  static const Map<String, String> _secondPerson = {
    'folds': 'fold',
    'checks': 'check',
    'calls': 'call',
    'bets': 'bet',
    'raises to': 'raise to',
    'posts SB': 'post SB',
    'posts BB': 'post BB',
    'posts small blind': 'post small blind',
    'posts big blind': 'post big blind',
    'posts ante': 'post ante',
  };

  /// Renders [entry] for a table whose big blind is [bigBlind] chips.
  static HandLogLine line(LogEntry entry, {required int bigBlind}) {
    final raw = entry.text;

    final header = _header.firstMatch(raw);
    if (header != null) {
      // The header carries its own blinds, so a line written at other stakes
      // still converts against the blinds it was written with.
      final sb = double.parse(header.group(2)!);
      final bb = double.parse(header.group(3)!);
      final unit = bb > 0 ? bb : bigBlind;
      final ante = header.group(4);
      final buf = StringBuffer(
        'Hand #${header.group(1)} · blinds '
        '${_stake(sb, unit)} / ${_stake(bb, unit)} bb',
      );
      if (ante != null) {
        buf.write(' · ante ${_stake(double.parse(ante), unit)} bb');
      }
      return HandLogLine(entry: entry, text: buf.toString(), isHero: false);
    }

    final action = _action.firstMatch(raw);
    if (action != null) {
      final name = action.group(1)!;
      final verb = action.group(2)!;
      final amount = action.group(3);
      final allIn = action.group(4) ?? '';
      final hero = name == heroName;
      final buf = StringBuffer(
        hero ? '$heroName ${_secondPerson[verb]}' : '$name $verb',
      );
      if (amount != null) {
        // A posted blind or ante is a stake, so it is printed like the ones in
        // the hand header; everything a player chooses to put in is `fmtBb`.
        final chips = double.parse(amount);
        buf.write(
          verb.startsWith('posts')
              ? ' ${_stake(chips, bigBlind)} bb'
              : ' ${_bb(chips, bigBlind)}',
        );
      }
      buf.write(allIn);
      return HandLogLine(entry: entry, text: buf.toString(), isHero: hero);
    }

    final result = _result.firstMatch(raw);
    if (result != null) {
      final names = result.group(1)!.split(', ');
      final hero = names.contains(heroName);
      final plural = hero || names.length > 1;
      final amount = _bb(double.parse(result.group(2)!), bigBlind);
      return HandLogLine(
        entry: entry,
        text:
            '${_join(names)} ${plural ? 'win' : 'wins'} $amount '
            '(${result.group(3)})',
        isHero: hero,
      );
    }

    // Street deals ("Flop — Ah Kd 7c"), the §14 ticker overrides and the
    // §4.2.1 heads-up hint: no name, no chips, nothing to rewrite.
    return HandLogLine(
      entry: entry,
      text: raw,
      isHero: raw.startsWith('$heroName '),
    );
  }

  /// `{name} calls 2.5 bb (all-in)` — a replay frame's action line.
  static final RegExp _frameAction = RegExp(
    r'^(.+?) (folds|checks|calls|bets|raises to)\b(.*)$',
  );

  /// `{names} win 39 bb.` — a replay frame's result line.
  static final RegExp _frameResult = RegExp(r'^(.+?) win (.*)\.$');

  /// A `buildReplayFrames` line in the phone's voice (§7.7).
  ///
  /// The engine's frames are the desktop's, and the desktop wrote every
  /// subject in the same person: third for actions ("You calls 2.5 bb") and
  /// plural for the result ("Dwan win 39 bb."). Both are wrong here for the
  /// same reasons the log was — so the replayer runs its frame text through
  /// the rules [line] already applies, and `lib/engine` stays untouched.
  static String replayFrame(String text) {
    final action = _frameAction.firstMatch(text);
    if (action != null) {
      final name = action.group(1)!;
      if (name != heroName) return text;
      return '$heroName ${_secondPerson[action.group(2)!]}${action.group(3)}';
    }

    final result = _frameResult.firstMatch(text);
    if (result != null) {
      final names = result.group(1)!.split(', ');
      final plural = names.contains(heroName) || names.length > 1;
      return '${result.group(1)} ${plural ? 'win' : 'wins'} ${result.group(2)}.';
    }
    return text;
  }

  /// [line] over a whole log.
  static List<HandLogLine> lines(
    Iterable<LogEntry> entries, {
    required int bigBlind,
  }) => [for (final e in entries) line(e, bigBlind: bigBlind)];

  /// What "copy the hand log" puts on the clipboard (§4.2, §4.11) — the same
  /// strings the user is looking at.
  static String clipboardText(
    Iterable<LogEntry> entries, {
    required int bigBlind,
  }) => lines(entries, bigBlind: bigBlind).map((l) => l.text).join('\n');

  /// The header's stakes. `fmtBb`'s single decimal rounds the §4.1 ante
  /// (a quarter blind) to "0.3", which would make the log and the lobby — the
  /// lobby calls the same setting "0.25 bb" — disagree about one number. A
  /// stake therefore keeps a second decimal when it needs one; every other
  /// amount in the log is plain `fmtBb`.
  static String _stake(double chips, num bb) {
    if (bb <= 0) return '$chips';
    final short = fmtBb(chips, bb);
    if (double.tryParse(short) == chips / bb) return short;
    final long = (chips / bb).toStringAsFixed(2);
    return long.endsWith('0') ? long.substring(0, long.length - 1) : long;
  }

  static String _bb(double chips, int bigBlind) =>
      bigBlind <= 0 ? '$chips' : '${fmtBb(chips, bigBlind)} bb';

  /// "You", "You and Ivey", "You, Ivey and Polk".
  /// "Ivey" · "You and Ivey" · "You, Ivey and Dwan" — the same list wording
  /// the P8 results card uses, so a split pot never reads "You, Ivey win".
  static String joinNames(List<String> names) => _join(names);

  static String _join(List<String> names) {
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}
