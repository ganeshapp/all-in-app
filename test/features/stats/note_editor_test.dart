/// P12 · Hand note editor (DESIGN.md §7.6).
///
/// §7.6 asks for tag **chips** ("36 tall, hit 44"). A bare `Center` inside the
/// `Wrap` took `constraints.biggest`, so every chip was laid out full-width
/// and the five presets became five stacked rows — and the sheet body carried
/// no horizontal padding at all, running the title and the field flush into
/// both screen edges.
library;

import 'package:allin/features/stats/widgets/note_editor_sheet.dart';
import 'package:allin/services/persistence/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stats_harness.dart';

void main() {
  testWidgets('the preset tags lay out as chips, several to a row', (
    tester,
  ) async {
    final fixture = StatsFixture();
    await pumpStats(
      tester,
      const Scaffold(body: HandNoteEditor(startedAt: 1781838000000, handId: 7)),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    // The chip is the decorated box around the label, not the label itself:
    // the full-width bug stretched the box while the text stayed intrinsic.
    final chips = <String, Rect>{
      for (final tag in kPresetTags)
        tag: tester.getRect(
          find
              .ancestor(of: find.text(tag), matching: find.byType(Container))
              .first,
        ),
    };
    final wrap = tester.getRect(find.byType(Wrap));

    for (final entry in chips.entries) {
      expect(
        entry.value.width,
        lessThan(wrap.width),
        reason: '"${entry.key}" is laid out as a full-width row',
      );
      // §7.6: 36 tall inside a 44 pt target.
      expect(entry.value.height, 36);
    }
    // A chip is as wide as its own label, so the five are not all equal.
    expect(chips.values.map((r) => r.width).toSet().length, greaterThan(1));
  });

  testWidgets('the sheet body keeps its horizontal padding', (tester) async {
    final fixture = StatsFixture();
    await pumpStats(
      tester,
      const Scaffold(body: HandNoteEditor(startedAt: 1781838000000, handId: 7)),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField).first);
    expect(field.left, greaterThanOrEqualTo(12));
    final screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(field.right, lessThanOrEqualTo(screen - 12));
  });
}
