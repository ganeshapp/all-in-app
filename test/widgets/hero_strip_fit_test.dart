/// §4.4's hard promise, measured: **the price line is never ellipsised and
/// never truncated.**
///
/// `test/widgets/table_test.dart` pins the two forms and the left segment's
/// collapse; this file pins the geometry, and it does so with the **bundled
/// Inter and JetBrains Mono** rather than the test framework's
/// 1-em-per-glyph fallback — a width promise measured in the wrong font is
/// not a width promise.
///
/// The matrix is §4.2.3's three widths × §4.2.4's three text scales × the
/// worst amounts a hand can produce, for 6-max and heads-up, with and without
/// the dealer disc.
library;

import 'dart:io';

import 'package:allin/engine/engine.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// §4.2.3: 16 pt of page margin, 20 at 430.
double _marginFor(double width) => width >= 430 ? 20 : 16;

Future<void> _loadFonts() async {
  const families = <String, String>{
    'Inter': 'Inter',
    'JetBrains Mono': 'JetBrainsMono',
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final file = File('assets/fonts/${family.value}-$weight.ttf');
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

/// Pumps the strip exactly as `TableScreen` does: inside the page margin, at
/// the screen's own width and text scale.
Future<void> _pumpStrip(
  WidgetTester tester, {
  required double width,
  required double scale,
  required String priceLine,
  int seats = 6,
  bool isButton = false,
  int stack = 2000,
  Position position = Position.bb,
}) async {
  final size = Size(width, 800);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AllInAppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: _marginFor(width)),
            child: HeroStrip(
              position: position,
              stack: stack,
              seats: seats,
              isButton: isButton,
              priceLine: priceLine,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Fails when [text] does not fit the box it was laid out in — an ellipsis, a
/// clip or a paint that spills over a neighbour all show up here.
void _expectFits(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget, reason: 'the price line is missing');
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(
    paragraph.getMaxIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(paragraph.size.width + 0.01),
    reason: '"$text" does not fit its box',
  );
  expect(paragraph.didExceedMaxLines, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  // 2 bb is the ordinary case; 37.5 bb is §4.4's own worst example; 98.8 bb
  // is a near-shove call, the widest amount the string can carry. 1 in 1.5
  // is the widest "need" tail (`fmtNeed`'s half-step form).
  const amounts = <int>[40, 750, 1975];
  const potOdds = <double>[0.25, 0.31, 0.67];

  for (final width in const [360.0, 390.0, 430.0]) {
    for (final scale in const [1.0, 1.15, 1.3]) {
      testWidgets(
        'the price line fits at ${width.toInt()} pt, ${scale}x text',
        (tester) async {
          for (final toCall in amounts) {
            for (final odds in potOdds) {
              final short = HeroStrip.useShortForm(
                width: width,
                seats: 6,
                textScaler: TextScaler.linear(scale),
              );
              final price = HeroStrip.priceLineFor(
                toCall: toCall,
                bigBlind: 20,
                potOdds: odds,
                short: short,
              );
              await _pumpStrip(
                tester,
                width: width,
                scale: scale,
                priceLine: price,
              );
              expect(tester.takeException(), isNull);
              _expectFits(tester, price);
            }
          }
        },
      );
    }
  }

  testWidgets('§4.4: the left segment gives way, the price line does not', (
    tester,
  ) async {
    const price = 'To call 98.8 bb · need 1 in 1.5';
    await _pumpStrip(tester, width: 360, scale: 1.3, priceLine: price);

    _expectFits(tester, price);
    // The stack is dropped; the bare position pill stays.
    expect(find.text('100 bb'), findsNothing);
    expect(find.text('BB'), findsOneWidget);

    // And the price never paints over what is left of the left segment.
    expect(
      tester.getRect(find.text(price)).left,
      greaterThanOrEqualTo(tester.getRect(find.text('BB')).right),
    );
  });

  testWidgets('heads-up keeps the pill when the price leaves room for it', (
    tester,
  ) async {
    const price = 'To call 2 bb · need 1 in 4';
    await _pumpStrip(
      tester,
      width: 360,
      scale: 1.3,
      priceLine: price,
      seats: 2,
      isButton: true,
      position: Position.btn,
    );

    _expectFits(tester, price);
    expect(find.text('BTN/SB'), findsOneWidget);
    expect(
      tester.getRect(find.text(price)).left,
      greaterThanOrEqualTo(tester.getRect(find.text('BTN/SB')).right),
    );
  });

  testWidgets('the last rung: the pill goes too rather than clip the price', (
    tester,
  ) async {
    // §4.4 stops at "the bare position pill", but heads-up's wider BTN/SB
    // pill plus a near-shove call at 360 pt and 1.3× text is past even that.
    // The promise is unconditional, so the pill goes.
    const price = 'To call 98.8 bb · need 1 in 1.5';
    await _pumpStrip(
      tester,
      width: 360,
      scale: 1.3,
      priceLine: price,
      seats: 2,
      isButton: true,
      position: Position.btn,
    );

    _expectFits(tester, price);
    expect(find.text('BTN/SB'), findsNothing);
    expect(find.text('100 bb'), findsNothing);
  });

  testWidgets('the dealer disc does not squeeze the price line', (
    tester,
  ) async {
    const price = 'To call 98.8 bb · need 1 in 1.5';
    await _pumpStrip(
      tester,
      width: 360,
      scale: 1.3,
      priceLine: price,
      isButton: true,
    );
    _expectFits(tester, price);
  });

  testWidgets('the hand label — not the price — may still ellipsise', (
    tester,
  ) async {
    // §4.4 protects the price line only: a long made-hand name is allowed to
    // truncate rather than spill off the screen.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AllInAppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(size: Size(360, 800)),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: HeroStrip(
                position: Position.bb,
                stack: 2000,
                handLabel: 'Two pair, queens and sevens, with an ace kicker',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
