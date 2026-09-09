/// T0 · the 3 + 2 KPI block (DESIGN.md §7.1, §7.2) and the `StatTile` it is
/// built from (§10.1).
///
/// The regression: the tile reserved the ⓘ's whole 44 pt hit target beside a
/// single-line label, which left "WIN RATE" ~30 pt inside a 104 pt tile and it
/// rendered as "WIN R…". A stat whose name is truncated names nothing.
///
/// These tests measure with the **bundled Inter**, not the test framework's
/// 1-em-per-glyph fallback: the whole question is how wide the real label is.
library;

import 'dart:io';

import 'package:allin/features/stats/screens/progress_screen.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stats_harness.dart';

const Size _phone360 = Size(360, 780);
const Size _phone390 = Size(390, 844);
const Size _phone430 = Size(430, 932);

/// The five §7.2 labels, upper-cased the way the tile renders them.
const List<String> _kpiLabels = [
  'HANDS',
  'NET',
  'WIN RATE',
  'SHOWDOWN',
  'READ ACC.',
];

/// `Inter` — the family `pubspec.yaml` bundles and `AllInText` asks for.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _pumpProgress(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  await pumpStats(
    tester,
    const ProgressScreen(),
    fixture: StatsFixture(),
    size: size,
    textScale: textScale,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadInter);

  for (final size in [_phone360, _phone390, _phone430]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'every KPI label renders in full at ${size.width.toInt()} pt, '
        '${scale}x text',
        (tester) async {
          await _pumpProgress(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);

          for (final label in _kpiLabels) {
            final finder = find.text(label);
            expect(finder, findsOneWidget, reason: '$label is missing');
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '$label was truncated at ${size.width} / ${scale}x',
            );
          }
        },
      );
    }
  }

  testWidgets('no label runs under its ⓘ glyph at 360 pt', (tester) async {
    await _pumpProgress(tester, size: _phone360);

    for (final label in _kpiLabels) {
      final text = tester.getRect(find.text(label));
      final tile = tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(StatTile)),
      );
      // The glyph is centred in the 44 pt target pinned to the top-right.
      final glyphLeft =
          tile.right - (StatTile.infoTarget + StatTile.infoGlyph) / 2;
      expect(
        text.right,
        lessThanOrEqualTo(glyphLeft),
        reason: '$label collides with its ⓘ',
      );
    }
  });

  testWidgets('the ⓘ keeps its 44 pt target (§13) without eating the label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpProgress(tester, size: _phone360);

    final info = tester.getRect(find.bySemanticsLabel('About win rate'));
    expect(info.width, greaterThanOrEqualTo(44));
    expect(info.height, greaterThanOrEqualTo(44));

    // Only the glyph's footprint is reserved beside the label, not the whole
    // target — the target simply overlaps the label's dead space.
    expect(StatTile.infoReserve, lessThan(StatTile.infoTarget));
    semantics.dispose();
  });

  testWidgets('the tiles grow rather than clip at 1.3x text (§13)', (
    tester,
  ) async {
    await _pumpProgress(tester, size: _phone360, textScale: 1.3);
    final tile = tester.getRect(find.byType(StatTile).first);
    expect(tile.height, greaterThanOrEqualTo(StatTile.heightSmall));
  });

  // The label may wrap and the sub-line may ellipsise; the *value* may do
  // neither. At 360 pt × 1.3× a three-across KPI row is narrower than the
  // number, and "−10.5" rendered as "−10…" — the tile's whole reason to exist,
  // truncated.
  testWidgets('a KPI value is never truncated at 360 pt, 1.3x text', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await fixture.addHand(sixMaxHand(), netBb: -10.5);
    await pumpStats(
      tester,
      const ProgressScreen(),
      fixture: fixture,
      size: _phone360,
      textScale: 1.3,
    );
    await tester.pump(const Duration(milliseconds: 50));

    for (final tile in tester.widgetList<StatTile>(find.byType(StatTile))) {
      final finder = find.text(tile.value);
      if (finder.evaluate().isEmpty) continue;
      final paragraph = tester.renderObject<RenderParagraph>(finder.first);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '"${tile.value}" was truncated',
      );
      final box = tester.getRect(
        find.ancestor(of: finder.first, matching: find.byType(StatTile)).first,
      );
      final text = tester.getRect(finder.first);
      expect(
        text.right,
        lessThanOrEqualTo(box.right + 0.01),
        reason: '"${tile.value}" spills out of its tile',
      );
    }
  });
}
