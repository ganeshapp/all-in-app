/// P13 · Bet keypad (DESIGN.md §4.5).
///
/// The regression these tests exist for: the sheet used to hand its whole
/// content to `AllInSheet`'s own scroll view, so "Set · Raise to N" — the only
/// control that closes the sheet — opened below the fold at 390 and 430 pt.
/// The commit button is pinned; the keypad above it is what scrolls.
library;

import 'package:allin/engine/engine.dart';
import 'package:allin/features/play/widgets/bet_keypad_sheet.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const LegalActions _legal = LegalActions(
  toCall: 40,
  canFold: true,
  canCheck: false,
  canCall: true,
  callAmount: 40,
  canBet: false,
  canRaise: true,
  minRaiseTo: 80,
  maxRaiseTo: 2000,
  potSize: 90,
  bigBlind: 20,
);

/// Opens P13 at [size] and returns the value "Set" popped with, if tapped.
Future<int?> _open(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
  int value = 150,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  int? result;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AllInAppTheme.dark(),
      home: Builder(
        builder:
            (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: Center(
                  child: Builder(
                    builder:
                        (inner) => TextButton(
                          onPressed: () async {
                            result = await BetKeypadSheet.show(
                              inner,
                              legal: _legal,
                              currentBet: 40,
                              value: value,
                              enableHaptics: false,
                              reducedMotion: true,
                            );
                          },
                          child: const Text('open'),
                        ),
                  ),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Finder _commit() => find.textContaining('Set · Raise to');

void main() {
  for (final size in const [phone360, phone390, phone430]) {
    testWidgets(
      'the commit button is fully on screen on open at ${size.width.toInt()}',
      (tester) async {
        await _open(tester, size: size);

        expect(_commit(), findsOneWidget);
        final button = tester.getRect(_commit());
        expect(
          button.bottom,
          lessThanOrEqualTo(size.height),
          reason: 'the commit button ran off the bottom at ${size.width}',
        );
        expect(button.top, greaterThanOrEqualTo(0));
        // Not merely inside the window: inside the *sheet*, which is the
        // §2.4-capped box the user can actually see.
        final sheet = tester.getRect(find.byType(AllInSheet));
        expect(button.bottom, lessThanOrEqualTo(sheet.bottom + 0.5));
        expect(button.top, greaterThanOrEqualTo(sheet.top - 0.5));
      },
    );
  }

  for (final size in const [Size(390, 844), Size(411, 914), Size(430, 932)]) {
    testWidgets('every key and every preset is reachable without a scroll at '
        '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      // The flat 40 % detent gave 366 pt on a 914 pt screen and the keypad
      // needs ~428, so the last row (". 0 ⌫") was clipped by the pinned
      // commit button: you could have the seven size presets or the zero
      // key, never both. Typing 10 / 20 / 30 bb, or fixing a typo, cost an
      // extra scroll mid-hand.
      await _open(tester, size: size);

      final sheet = tester.getRect(find.byType(AllInSheet));
      for (final key in const ['0', '.', '⌫', '1', '5', '9']) {
        final finder = find.widgetWithText(Material, key);
        expect(finder, findsWidgets, reason: 'key "$key" at ${size.width}');
        final rect = tester.getRect(finder.first);
        expect(
          rect.bottom,
          lessThanOrEqualTo(sheet.bottom + 0.5),
          reason: 'key "$key" is clipped at ${size.width}',
        );
      }
      // …and the presets are still on screen at the same time.
      for (final preset in const ['Min', '1/3', '1/2']) {
        expect(find.text(preset), findsOneWidget, reason: preset);
        expect(
          tester.getRect(find.text(preset)).bottom,
          lessThanOrEqualTo(sheet.bottom + 0.5),
          reason: '$preset is clipped at ${size.width}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the commit button stays on screen at 1.3× text (§4.2.4)', (
    tester,
  ) async {
    await _open(tester, size: phone360, textScale: 1.3);

    final button = tester.getRect(_commit());
    final sheet = tester.getRect(find.byType(AllInSheet));
    expect(button.bottom, lessThanOrEqualTo(sheet.bottom + 0.5));
    expect(button.bottom, lessThanOrEqualTo(phone360.height));
  });

  testWidgets('the display and the commit button are pinned; the keys scroll', (
    tester,
  ) async {
    await _open(tester, size: phone390);

    final before = tester.getRect(_commit());
    final display = tester.getRect(find.text('7.5 bb'));

    await tester.drag(find.text('5'), const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(tester.getRect(_commit()), before, reason: 'the button moved');
    expect(tester.getRect(find.text('7.5 bb')), display);
  });

  testWidgets('the pinned button is tappable and labels the exact commit', (
    tester,
  ) async {
    await _open(tester, size: phone390, value: 2000);

    // 100 bb of a 2000 chip stack — the max; "Set" returns it unchanged.
    expect(find.text('Set · Raise to 100'), findsOneWidget);
    await tester.tap(_commit());
    await tester.pumpAndSettle();
    expect(find.byType(AllInSheet), findsNothing);
  });

  testWidgets('every key and stepper keeps a 44 pt hit target (§13)', (
    tester,
  ) async {
    await _open(tester, size: phone360);

    for (final key in const ['1', '5', '9', '0', '⌫']) {
      final rect = tester.getRect(find.widgetWithText(Material, key).first);
      expect(rect.height, greaterThanOrEqualTo(44));
    }
    for (final label in const ['−', '+']) {
      final rect = tester.getRect(find.widgetWithText(Material, label).first);
      expect(rect.width, greaterThanOrEqualTo(44), reason: label);
      expect(rect.height, greaterThanOrEqualTo(44), reason: label);
    }
  });
}
