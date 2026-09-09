/// Every tab root scrolls behind the shell's own chrome (DESIGN.md §2.1).
///
/// `TabScaffold` publishes the tab bar + Session-pill height as the body's
/// `MediaQuery.padding.bottom`, and `AllInScaffold` keeps `SafeArea(bottom:
/// false)` — so a root's scroll view has to reserve that inset itself. The
/// Play lobby and Stats did not, which put the last rows of "Recent sessions"
/// and of the Data card (Import hands · Reset all progress) underneath the
/// pill with no scroll extent left to reach them.
library;

import 'package:allin/app/shell/tab_scaffold.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/play/harness.dart';

/// The scroll view a tab root hands to `AllInScaffold.body`.
Finder _rootList() => find.byType(ListView).first;

double _reserved(WidgetTester tester) {
  final list = tester.widget<ListView>(_rootList());
  return (list.padding as EdgeInsets?)?.bottom ?? 0;
}

double _chrome(WidgetTester tester) =>
    MediaQuery.paddingOf(tester.element(_rootList())).bottom;

void main() {
  for (final location in const ['/play', '/stats']) {
    testWidgets('$location reserves the shell chrome under its list', (
      tester,
    ) async {
      final container = makeContainer(seed: 3);
      addTearDown(container.dispose);
      // A live session puts the 56 pt pill above the 68 pt bar — the worst
      // case the compact-height rule of §2.1 allows.
      container
          .read(sessionProvider.notifier)
          .newSession(const TableOptions(seats: 6));
      await settleWidgets(tester);

      await pumpApp(tester, container: container, location: location);
      await tester.pump(const Duration(milliseconds: 400));

      final chrome = _chrome(tester);
      expect(
        chrome,
        greaterThan(TabScaffold.pillHeight),
        reason: 'the pill should be showing at 390×844',
      );
      expect(
        _reserved(tester),
        greaterThanOrEqualTo(chrome),
        reason: '$location scrolls its last rows under the tab bar and pill',
      );
    });
  }

  // §2.1: above 1.15× the pill is gated out and the Play item carries the
  // session ("Play · +4.5"). At 360 that label wraps, and inside a fixed
  // 68 pt bar its second line was painted through the active-indicator pill.
  testWidgets('the tab bar grows for a two-line label at 1.3x', (tester) async {
    final container = makeContainer(seed: 3);
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .newSession(const TableOptions(seats: 6));
    await settleWidgets(tester);

    await pumpApp(
      tester,
      container: container,
      location: '/play',
      size: const Size(360, 780),
      textScale: 1.3,
    );
    await tester.pump(const Duration(milliseconds: 400));

    final bar = tester.getRect(find.byType(NavigationBar));
    final base =
        NavigationBarTheme.of(
          tester.element(find.byType(NavigationBar)),
        ).height!;
    // The bar grew by a whole scaled label line, and the shell's chrome inset
    // is computed from the same number so routes still budget correctly.
    expect(bar.height, greaterThan(base));
    expect(bar.height, closeTo(base + 11.5 * 1.3 * 1.35, 0.5));
    expect(_chrome(tester), greaterThanOrEqualTo(bar.height));
    expect(tester.takeException(), isNull);
  });
}
