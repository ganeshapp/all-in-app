import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/play/widgets/hand_read_copy.dart';
import 'package:allin/features/stats/widgets/hand_reading_card.dart';
import 'package:allin/services/persistence/hand_reads_store.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../play/hand_reads_test.dart' show prediction;

void main() {
  testWidgets(
    'actual-card results exclude unshown reads and disclose breadth',
    (tester) async {
      final kv = KeyValueStore.memory();
      await HandReadsStore(kv).save([
        prediction().finish(HandReadStatus.revealed, ['Ah', 'Ks']),
        prediction(
          hand: 2,
          selected: {'AA', 'KK', 'QQ', 'JJ'},
        ).finish(HandReadStatus.revealed, ['Ah', 'Ks']),
        prediction(hand: 3).finish(HandReadStatus.unshown),
        prediction(hand: 4).finish(HandReadStatus.abandoned),
      ]);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [keyValueStoreProvider.overrideWithValue(kv)],
          child: MaterialApp(
            theme: AllInAppTheme.dark(),
            home: Builder(
              builder:
                  (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: const Scaffold(
                      body: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: HandReadingCard(),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      );
      expect(find.text(HandReadCopy.summary(1, 2)), findsOneWidget);
      expect(
        find.textContaining('2.5 hand types selected on average'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 of 1 revealed single-hand predictions hit.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(HandReadCopy.recent));
      await tester.tap(find.text(HandReadCopy.recent));
      await tester.pumpAndSettle();
      expect(find.text('Called it · AKo'), findsOneWidget);
      expect(find.text('Read missed · AKo'), findsOneWidget);
      expect(find.text(HandReadCopy.unshown), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
