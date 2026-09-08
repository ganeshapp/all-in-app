import 'dart:convert';

import 'package:allin/engine/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mobile app and the desktop app must be able to read each other's
/// backups, so the JSON these value types produce has to match what
/// `JSON.stringify` produces on the desktop — same key names, and no key at
/// all where the desktop has `undefined`.
void main() {
  group('SrsState JSON matches the desktop shape', () {
    test('writes the counter as "reps" and integral numbers without ".0"', () {
      const s = SrsState(
        due: 1750000000000,
        intervalDays: 3,
        ease: 2.3,
        wins: 2,
        lapses: 1,
      );
      final json = s.toJson();
      expect(json.containsKey('reps'), isTrue);
      expect(json.containsKey('wins'), isFalse);
      expect(json['reps'], 2);
      expect(
        jsonEncode(json),
        '{"due":1750000000000,"intervalDays":3,"ease":2.3,"reps":2,"lapses":1}',
      );
    });

    test('reads desktop "reps" and legacy mobile "wins"', () {
      const base = {
        'due': 1750000000000,
        'intervalDays': 3.0,
        'ease': 2.3,
        'lapses': 1,
      };
      expect(SrsState.fromJson({...base, 'reps': 2}).wins, 2);
      expect(SrsState.fromJson({...base, 'wins': 5}).wins, 5);
    });

    test('round-trips', () {
      const s = SrsState(
        due: 42,
        intervalDays: 12.5,
        ease: 1.9,
        wins: 3,
        lapses: 4,
      );
      final r = SrsState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
      );
      expect(r.due, s.due);
      expect(r.intervalDays, s.intervalDays);
      expect(r.ease, s.ease);
      expect(r.wins, s.wins);
      expect(r.lapses, s.lapses);
    });
  });

  group('LeakSpot JSON omits absent optional fields', () {
    LeakSpot spot({
      double? equity,
      double? potOdds,
      SrsState? srs,
      double? amount,
    }) => LeakSpot(
      id: 'h1-flop-1',
      street: Street.flop,
      heroPos: Position.co,
      hole: const ['As', 'Kd'],
      board: const ['Qh', '7c', '2d'],
      pot: 120,
      toCall: 40,
      bb: 20,
      oppActive: const [Position.bb],
      options: [
        DrillOption(action: DrillAction.fold, label: 'Fold', amount: amount),
      ],
      best: DrillAction.fold,
      rationale: 'Calling costs about 1.2 bb.',
      equity: equity,
      potOdds: potOdds,
      ts: 1750000000000,
      srs: srs,
    );

    test('null equity, potOdds and srs produce no keys at all', () {
      final json = spot().toJson();
      expect(json.containsKey('equity'), isFalse);
      expect(json.containsKey('potOdds'), isFalse);
      expect(json.containsKey('srs'), isFalse);
      expect(jsonEncode(json).contains('null'), isFalse);
    });

    test('a null option amount produces no key', () {
      final json = spot().toJson()['options'] as List;
      expect((json.first as Map).containsKey('amount'), isFalse);
    });

    test('present values are written', () {
      final json =
          spot(
            equity: 0.31,
            potOdds: 0.25,
            amount: 2.5,
            srs: const SrsState(
              due: 1,
              intervalDays: 1,
              ease: 2.3,
              wins: 0,
              lapses: 0,
            ),
          ).toJson();
      expect(json['equity'], 0.31);
      expect(json['potOdds'], 0.25);
      expect((json['srs']! as Map)['reps'], 0);
      expect(((json['options']! as List).first as Map)['amount'], 2.5);
    });

    test('round-trips with and without the optional fields', () {
      for (final s in [
        spot(),
        spot(
          equity: 0.4,
          potOdds: 0.3,
          amount: 1.5,
          srs: const SrsState(
            due: 9,
            intervalDays: 3,
            ease: 2.1,
            wins: 1,
            lapses: 0,
          ),
        ),
      ]) {
        final r = LeakSpot.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
        );
        expect(r.id, s.id);
        expect(r.equity, s.equity);
        expect(r.potOdds, s.potOdds);
        expect(r.srs?.wins, s.srs?.wins);
        expect(r.options.first.amount, s.options.first.amount);
      }
    });
  });
}
