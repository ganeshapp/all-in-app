/// Smoke test: the app boots to the Home tab with the tab bar in place.
/// Route-level coverage lives in `test/app/router_test.dart`.
library;

import 'package:allin/app/app.dart';
import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/home/screens/today_screen.dart';
import 'package:allin/features/onboarding/screens/onboarding_screen.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/persistence/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to Today with the five tabs', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Past §8's first-run gate: this is the returning-user boot.
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            MemoryKeyValueStore(const {kOnboardedKey: '1'}),
          ),
        ],
        child: const AllInApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Play', 'Drills', 'Study', 'Stats']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('first launch mounts the §8 tour over the shell', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    // Regression: `OnboardingGate` was never mounted in `AllInApp`, so a fresh
    // install went straight to Home and the tour never ran.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const AllInApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
