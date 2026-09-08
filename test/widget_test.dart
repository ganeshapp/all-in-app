/// Smoke test: the app boots to the Home tab with the tab bar in place.
/// Route-level coverage lives in `test/app/router_test.dart`.
library;

import 'package:allin/app/app.dart';
import 'package:allin/features/home/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to Today with the five tabs', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: AllInApp()));
    await tester.pumpAndSettle();

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Play', 'Drills', 'Study', 'Stats']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
