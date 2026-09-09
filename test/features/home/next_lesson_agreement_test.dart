/// Home's "Next up" card (DESIGN.md §3.2 card 3) and Study's Continue card
/// (§6.1) name the same lesson, always.
///
/// They used to disagree: Home applied §3.2's placement clause ("on the first
/// day the placement result's suggested lesson") while Study only ever took the
/// first incomplete lesson in path order, so a learner placed at 3-Bet Pots was
/// told to read two different lessons depending on which tab was open.
/// `studyContinueLessonProvider` is now the single rule and both screens read
/// it — these tests pin the agreement itself, not just each screen's answer.
library;

import 'package:allin/features/home/providers/plan_provider.dart';
import 'package:allin/features/study/content/curriculum.dart';
import 'package:allin/features/study/providers/study_providers.dart';
import 'package:allin/features/study/screens/study_screen.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../study/harness.dart' as study;
import 'home_harness.dart';

/// The lesson id Home's card routes to, or null on the "course complete" card.
String? _homeLessonId(ProviderContainer container) {
  final route = container.read(planProvider).entry(PlanCardKind.lesson)!.route!;
  const prefix = '/study/lesson/';
  return route.startsWith(prefix) ? route.substring(prefix.length) : null;
}

/// The lesson Study's Continue card shows.
String? _studyLessonId(ProviderContainer container) =>
    container.read(studyContinueLessonProvider)?.id;

Future<KeyValueStore> _placedAt(double rating) async {
  final store = KeyValueStore.memory();
  await DrillStore(store).save(DrillState(rating: rating));
  return store;
}

void main() {
  group('the two screens read one rule', () {
    test('un-placed: both take the first incomplete lesson in path order', () {
      final container = homeContainer();
      addTearDown(container.dispose);

      expect(_studyLessonId(container), kAllLessonIds.first);
      expect(_homeLessonId(container), _studyLessonId(container));
    });

    test('placed at 1250: both take the placement suggestion', () async {
      final container = homeContainer(store: await _placedAt(1250));
      addTearDown(container.dispose);

      expect(_studyLessonId(container), 'threebet-pots');
      expect(_homeLessonId(container), 'threebet-pots');
    });

    test('placed at 1050: both take the placement suggestion', () async {
      final container = homeContainer(store: await _placedAt(1050));
      addTearDown(container.dispose);

      expect(_studyLessonId(container), 'pot-odds');
      expect(_homeLessonId(container), 'pot-odds');
    });

    test('placed at 900: both take the placement suggestion', () async {
      final container = homeContainer(store: await _placedAt(900));
      addTearDown(container.dispose);

      expect(_studyLessonId(container), 'hand-rankings');
      expect(_homeLessonId(container), 'hand-rankings');
    });

    test('a rating from ordinary drilling is not a placement result', () async {
      final container = homeContainer(store: await _placedAt(1082));
      addTearDown(container.dispose);

      expect(_studyLessonId(container), kAllLessonIds.first);
      expect(_homeLessonId(container), kAllLessonIds.first);
    });

    test('after the first completion both fall back to path order', () async {
      final container = homeContainer(store: await _placedAt(1250));
      addTearDown(container.dispose);
      expect(_studyLessonId(container), 'threebet-pots');

      // §3.2's clause is "on the first day"; one completed lesson ends it.
      await container
          .read(studyProgressProvider.notifier)
          .complete(kAllLessonIds.first);

      expect(_studyLessonId(container), kAllLessonIds[1]);
      expect(_homeLessonId(container), kAllLessonIds[1]);
    });

    test('completing the suggestion still hands back to path order', () async {
      final container = homeContainer(store: await _placedAt(1250));
      addTearDown(container.dispose);

      await container
          .read(studyProgressProvider.notifier)
          .complete('threebet-pots');

      expect(_studyLessonId(container), kAllLessonIds.first);
      expect(_homeLessonId(container), kAllLessonIds.first);
    });

    test('course complete: null for Study, the §14 card for Home', () async {
      final container = homeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(studyProgressProvider.notifier);
      for (final id in kAllLessonIds) {
        await notifier.complete(id);
      }

      expect(_studyLessonId(container), isNull);
      expect(_homeLessonId(container), isNull);
      expect(
        container.read(planProvider).entry(PlanCardKind.lesson)!.route,
        '/study',
      );
    });
  });

  group('on screen', () {
    testWidgets('S0 offers the placement suggestion, like Home', (
      tester,
    ) async {
      final store = await _placedAt(1250);
      await study.pumpStudyApp(
        tester,
        overrides: [...study.studyOverrides(store: store)],
      );
      await tester.pump();

      expect(find.text('Continue: Playing 3-Bet Pots'), findsOneWidget);
      expect(find.byType(StudyScreen), findsOneWidget);

      // And the same string Home would print for its card.
      final container = homeContainer(store: store);
      addTearDown(container.dispose);
      expect(
        container.read(planProvider).entry(PlanCardKind.lesson)!.title,
        'Continue: Playing 3-Bet Pots',
      );
    });

    testWidgets('S0 falls back to path order when nothing placed it', (
      tester,
    ) async {
      await study.pumpStudyApp(tester);
      await tester.pump();

      expect(find.text('Continue: Hand Rankings'), findsOneWidget);
    });
  });
}
