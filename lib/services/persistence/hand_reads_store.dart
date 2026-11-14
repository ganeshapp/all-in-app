import '../../engine/engine.dart'
    show HandLabel, Street, allLabels, cardsToLabel;
import 'key_value_store.dart';

const kHandReadsKey = 'allin.hand_reads.v1';

enum HandReadStatus { pending, revealed, unshown, abandoned }

/// A prediction locked before seeing the cards. Range overlap and the actual
/// hand are separate results; no opponent hole cards are stored while pending.
class HandRead {
  HandRead({
    required this.sessionId,
    required this.handNumber,
    required this.seat,
    required this.playerName,
    required this.street,
    required Set<HandLabel> selected,
    required Set<HandLabel> estimatedRange,
    required this.rangeOverlap,
    required this.submittedAt,
    this.status = HandReadStatus.pending,
    List<String> shownCards = const [],
  }) : selected = Set.unmodifiable(selected),
       estimatedRange = Set.unmodifiable(estimatedRange),
       shownCards = List.unmodifiable(
         status == HandReadStatus.revealed ? shownCards : const <String>[],
       );

  final int sessionId;
  final int handNumber;
  final int seat;
  final String playerName;
  final Street street;
  final Set<HandLabel> selected;
  final Set<HandLabel> estimatedRange;
  final double rangeOverlap;
  final int submittedAt;
  final HandReadStatus status;
  final List<String> shownCards;

  String get id => '$sessionId:$handNumber:$seat:${street.label}';
  String? get actualHand =>
      status == HandReadStatus.revealed && shownCards.length == 2
          ? cardsToLabel(shownCards[0], shownCards[1])
          : null;
  bool? get hit => actualHand == null ? null : selected.contains(actualHand);

  HandRead finish(HandReadStatus status, [List<String> cards = const []]) =>
      HandRead(
        sessionId: sessionId,
        handNumber: handNumber,
        seat: seat,
        playerName: playerName,
        street: street,
        selected: selected,
        estimatedRange: estimatedRange,
        rangeOverlap: rangeOverlap,
        submittedAt: submittedAt,
        status: status,
        shownCards: cards,
      );

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'handNumber': handNumber,
    'seat': seat,
    'playerName': playerName,
    'street': street.name,
    'selected': selected.toList(),
    'estimatedRange': estimatedRange.toList(),
    'rangeOverlap': rangeOverlap,
    'submittedAt': submittedAt,
    'status': status.name,
    'shownCards': shownCards,
  };

  static HandRead? fromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final valid = allLabels().toSet();
      Set<HandLabel> labels(Object? list) =>
          list is List
              ? list.whereType<String>().where(valid.contains).toSet()
              : {};
      final selected = labels(value['selected']);
      if (selected.isEmpty) return null;
      final status = HandReadStatus.values.byName(value['status'] as String);
      final cards =
          (value['shownCards'] as List? ?? []).whereType<String>().toList();
      final validCards =
          cards.length == 2 &&
          cards[0] != cards[1] &&
          cards.every((c) => RegExp(r'^[2-9TJQKA][cdhs]$').hasMatch(c));
      return HandRead(
        sessionId: value['sessionId'] as int,
        handNumber: value['handNumber'] as int,
        seat: value['seat'] as int,
        playerName: value['playerName'] as String,
        street: Street.values.byName(value['street'] as String),
        selected: selected,
        estimatedRange: labels(value['estimatedRange']),
        rangeOverlap: (value['rangeOverlap'] as num).toDouble().clamp(0, 1),
        submittedAt: value['submittedAt'] as int,
        status:
            status == HandReadStatus.revealed && !validCards
                ? HandReadStatus.unshown
                : status,
        shownCards:
            status == HandReadStatus.revealed && validCards ? cards : const [],
      );
    } catch (_) {
      return null;
    }
  }
}

class HandReadsStore {
  HandReadsStore(this.store);
  final KeyValueStore store;
  static const historyLimit = 500;

  List<HandRead> load() => [
    for (final value in store.getJsonList(kHandReadsKey))
      if (HandRead.fromJson(value) case final HandRead read) read,
  ];

  Future<bool> save(List<HandRead> reads) =>
      store.setJson(kHandReadsKey, [for (final read in reads) read.toJson()]);
}
