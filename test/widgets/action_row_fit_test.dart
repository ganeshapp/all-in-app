/// §4.5's commit labels, measured: **"Raise to 2.7 bb" is never ellipsised.**
///
/// `table_test.dart` pins the row's states and the 1.3× fallback; this file
/// pins the geometry below 1.3×, and — like `hero_strip_fit_test.dart` — it
/// does so with the **bundled Inter** rather than the test framework's
/// 1-em-per-glyph fallback. A width promise measured in the wrong font is not
/// a width promise: the fallback makes "Call 2 bb" look 40 pt wider than it
/// renders on a device.
///
/// The labels carry their unit ("Raise to 2.7 bb", not "Raise to 2.7") because
/// a beginner reading "2.7" has no idea 2.7 of what — which is exactly the
/// change that made this measurement worth pinning.
library;

import 'dart:io';

import 'package:allin/engine/engine.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Inter');
  for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/Inter-$weight.ttf');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

/// The row's own width at each supported screen: §4.2.3's page margins removed.
/// 379 is the 411 pt Pixel the device sweep runs on.
final Map<double, double> _rowWidths = <double, double>{
  360: 328,
  390: 358,
  411: 379,
  430: 390,
};

const LegalActions _facingRaise = LegalActions(
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

Future<void> _pumpRow(
  WidgetTester tester, {
  required double width,
  required double scale,
  required int raiseTo,
}) async {
  tester.view.physicalSize = Size(width + 32, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AllInAppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ActionRow(
                state: ActionRowState.heroToAct,
                legal: _facingRaise,
                raiseTo: raiseTo,
                heroStack: 2000,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectNothingClipped(WidgetTester tester, String where) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data == null || data.isEmpty) continue;
    for (final element in find.text(data).evaluate()) {
      final para = element.renderObject! as RenderParagraph;
      expect(
        para.didExceedMaxLines,
        isFalse,
        reason: '"$data" is clipped at $where',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  // bb = 20, so 54 chips is "2.7 bb" — three glyphs plus the unit, the widest
  // ordinary pre-flop raise. 1975 is "98.8 bb", a near-shove.
  const raises = <int>[54, 150, 1975];

  for (final entry in _rowWidths.entries) {
    for (final scale in const <double>[1.0, 1.15]) {
      testWidgets(
        'every commit label fits at ${entry.key.toInt()} pt, ${scale}x text',
        (tester) async {
          for (final raiseTo in raises) {
            await _pumpRow(
              tester,
              width: entry.value,
              scale: scale,
              raiseTo: raiseTo,
            );
            expect(tester.takeException(), isNull);
            _expectNothingClipped(
              tester,
              '${entry.key.toInt()} pt, ${scale}x, raise to $raiseTo',
            );
          }
        },
      );
    }
  }

  testWidgets('the amount keeps its unit below the 1.3x fallback', (
    tester,
  ) async {
    await _pumpRow(tester, width: 328, scale: 1.0, raiseTo: 54);
    expect(find.text('Raise to 2.7 bb'), findsOneWidget);
    expect(find.text('Call 2 bb'), findsOneWidget);
  });
}
