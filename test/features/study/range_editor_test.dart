/// S6 · Range editor (DESIGN.md §6.5) — the full-screen painter that returns
/// its set with `pop(result)`, and the equity calculator's route to it.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/engine/notation.dart';
import 'package:allin/engine/ranges.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/study/screens/range_editor_screen.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('renders', () {
    for (final size in kStudySizes) {
      testWidgets('at ${size.width.toInt()} pt', (tester) async {
        await pumpStudyWidget(
          tester,
          const RangeEditorScreen(
            initialHands: <String>{'AA', 'AKs'},
            title: 'Your range',
          ),
          size: size,
        );
        expect(find.text('Your range'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.byType(RangeMatrix), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at 1.3x text scale', (tester) async {
      await pumpStudyWidget(
        tester,
        const RangeEditorScreen(title: "Opponent's range"),
        size: const Size(360, 780),
        textScale: 1.3,
      );
      expect(find.text("Opponent's range"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('counts the combos it opened with', (tester) async {
      await pumpStudyWidget(
        tester,
        const RangeEditorScreen(initialHands: <String>{'AA'}),
        size: const Size(430, 932),
      );
      expect(find.textContaining('${comboCount('AA')} combos'), findsOneWidget);
    });
  });

  testWidgets('a preset repaints the grid and Done returns it', (tester) async {
    Set<HandLabel>? result;
    await pumpStudyWidget(
      tester,
      Builder(
        builder:
            (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Set<HandLabel>>(
                    MaterialPageRoute<Set<HandLabel>>(
                      builder:
                          (_) => const RangeEditorScreen(title: 'Your range'),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
      ),
      size: const Size(430, 932),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // "Top 10 %" is the first chip of RangePresetRow.defaults().
    await tester.tap(find.text('Top 10 %'));
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result, topPercentRange(10));
  });

  testWidgets('Undo restores the previous set', (tester) async {
    await pumpStudyWidget(
      tester,
      const RangeEditorScreen(
        initialHands: <String>{'AA'},
        title: 'Your range',
      ),
      size: const Size(430, 932),
    );
    expect(find.text('Undo'), findsNothing);
    await tester.tap(find.text('Top 10 %'));
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.textContaining('${comboCount('AA')} combos'), findsOneWidget);
  });

  testWidgets('system back is Done and keeps the edits', (tester) async {
    Set<HandLabel>? result;
    await pumpStudyWidget(
      tester,
      Builder(
        builder:
            (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Set<HandLabel>>(
                    MaterialPageRoute<Set<HandLabel>>(
                      builder:
                          (_) => const RangeEditorScreen(
                            initialHands: <String>{'QQ'},
                            title: 'Your range',
                          ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
      ),
      size: const Size(430, 932),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // A system back gesture, routed through the screen's PopScope.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, <HandLabel>{'QQ'});
  });

  test('the editor path is the §16.1 root-level modal', () {
    expect(AllInRoutes.rangeEditorPath, '/study/range-editor');
  });
}
