import '../providers/hand_reads_provider.dart';

abstract final class HandReadCopy {
  static const title = 'Hand reading';
  static const saved = 'Read saved';
  static const waiting =
      'Your selection is locked for this street. When the hand ends, revealed cards will tell you whether your read hit.';
  static const unshown = 'Cards not shown';
  static const unshownBody =
      'This read is unscored because the opponent’s cards were not revealed.';
  static const abandoned = 'Hand not completed';
  static const abandonedBody =
      'This read is unscored because the session ended before the reveal.';
  static const noRead = 'No read saved';
  static const noReadBody =
      'Make a prediction during the hand to check it against the revealed cards.';
  static const typeHint =
      'A square predicts a hand type: AKs means suited, AKo means different suits. It does not predict the exact suits.';
  static const comparisonHint =
      'Range overlap compares your selection with the coach’s estimate. A narrow read can hit the actual hand with low overlap. The estimate can be wrong.';
  static const empty =
      'Tap an opponent during a hand and save a read. Your results appear here after the cards are revealed.';
  static const sampleHint =
      'Hit rate counts revealed reads, one per opponent per street. Wider selections are easier to hit; compare selection size as well as hit rate. Up to 500 completed reads are kept on this device.';
  static const recent = 'Recent reads';
  static const yourSelection = 'Your selection';
  static const latestTwenty = 'Latest 20 reads';
  static String overlap(double score) =>
      'Range overlap · ${(score * 100).round()}%';
  static String selected(int n) =>
      '$n hand ${n == 1 ? 'type' : 'types'} selected';
  static String selection(HandRead read) =>
      'Your selection: ${(read.selected.toList()..sort()).join(', ')}';
  static String heading(HandRead read) => switch (read.status) {
    HandReadStatus.pending => saved,
    HandReadStatus.unshown => unshown,
    HandReadStatus.abandoned => abandoned,
    HandReadStatus.revealed =>
      read.hit == true
          ? (read.selected.length == 1
              ? 'Called it · ${read.actualHand}'
              : 'Read hit · ${read.actualHand}')
          : 'Read missed · ${read.actualHand}',
  };
  static String body(HandRead read) => switch (read.status) {
    HandReadStatus.pending => waiting,
    HandReadStatus.unshown => unshownBody,
    HandReadStatus.abandoned => abandonedBody,
    HandReadStatus.revealed =>
      read.hit == true
          ? '${read.playerName} held ${read.actualHand}, ${read.selected.length == 1 ? 'the hand type you predicted' : 'one of your ${read.selected.length} selected hand types'}.'
          : '${read.playerName} held ${read.actualHand}, which was outside your selection.',
  };
  static String badge(HandRead read) => switch (read.status) {
    HandReadStatus.revealed =>
      '${read.hit == true ? 'Read hit' : 'Read missed'} · ${read.selected.length} ${read.selected.length == 1 ? 'type' : 'types'}',
    HandReadStatus.pending => saved,
    _ => 'Read unscored',
  };
  static String context(HandRead read) =>
      '${read.playerName} · Hand ${read.handNumber} · ${read.street.label}';
  static String summary(int hits, int count) =>
      '$hits of $count revealed reads hit';
  static String breadth(double mean, int singleHits, int singles) =>
      '${mean.toStringAsFixed(1)} hand types selected on average. $singleHits of $singles revealed single-hand predictions hit.';
  static String pending(int count) =>
      '$count ${count == 1 ? 'read awaiting' : 'reads awaiting'} a reveal';
}
