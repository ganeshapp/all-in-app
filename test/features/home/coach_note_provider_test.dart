/// §3.4: which sentence the coach says, in which order, and the two layers
/// behind it.
library;

import 'package:allin/engine/engine.dart'
    show kLeakCallTooWide, kLeakCleanDiscipline, kLeakFoldTooOften;
import 'package:allin/features/home/home_copy.dart';
import 'package:allin/features/home/providers/coach_note_provider.dart';
import 'package:allin/features/play/providers/lobby_providers.dart';
import 'package:allin/features/stats/providers/stats_providers.dart';
import 'package:allin/services/persistence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_harness.dart';

Future<HomeCoachNote> noteOf(ProviderContainer container) async {
  await container.read(statsProvider.future);
  await container.read(recentSessionsProvider.future);
  return container.read(homeCoachNoteProvider);
}

void main() {
  test('nothing recorded: the no-data line, no lesson, no math', () async {
    final note = await noteOf(homeContainer());

    expect(note.source, CoachNoteSource.none);
    expect(note.sentence, HomeCopy.coachNoData);
    expect(note.math, isNull);
    expect(note.expert, isNull);
    expect(note.lessonId, isNull);
  });

  test('a fold leak wins, with the count and the rule behind it', () async {
    final store = KeyValueStore.memory();
    await seedDecisions(store, total: 10, folds: 3);
    final note = await noteOf(homeContainer(store: store));

    expect(note.source, CoachNoteSource.foldLeak);
    expect(note.sentence, kLeakFoldTooOften);
    expect(
      note.math,
      '3 of your last 10 coached decisions were folds the coach flagged — '
      '30%.',
    );
    expect(note.expert, contains('≥ 3 fold mistakes'));
    expect(note.lessonId, kLeakLessonId);
  });

  test('a call leak reads as calls, not folds', () async {
    final store = KeyValueStore.memory();
    await seedDecisions(store, total: 10, calls: 4);
    final note = await noteOf(homeContainer(store: store));

    expect(note.source, CoachNoteSource.callLeak);
    expect(note.sentence, kLeakCallTooWide);
    expect(note.math, contains('were calls the coach flagged'));
    expect(note.expert, contains('≥ 3 call mistakes'));
  });

  test('clean discipline is a leak line too', () async {
    final store = KeyValueStore.memory();
    await seedDecisions(store, total: 9);
    final note = await noteOf(homeContainer(store: store));

    expect(note.source, CoachNoteSource.discipline);
    expect(note.sentence, kLeakCleanDiscipline);
    expect(note.math, contains('Nothing was flagged'));
  });

  test('reads come next when no leak line applies', () async {
    final store = KeyValueStore.memory();
    final stats = StatsRepository(database: AppDatabase(), store: store);
    for (var i = 0; i < 5; i++) {
      await stats.persistGuess(
        GuessRecord(
          accuracy: 0.3,
          street: 'preflop',
          ts: homeNow().millisecondsSinceEpoch - i * 1000,
        ),
      );
    }
    final note = await noteOf(homeContainer(store: store));

    expect(note.source, CoachNoteSource.reads);
    expect(note.sentence, HomeCopy.coachReadLine);
    expect(note.math, contains('Your last 5 range reads'));
    expect(note.lessonId, kReadsLessonId);
  });

  test('then the last debrief, quoting the costliest decision', () async {
    final container = homeContainer(sessions: [endedSession()]);
    final note = await noteOf(container);

    expect(note.source, CoachNoteSource.debrief);
    expect(
      note.sentence,
      "Costliest: a river call (-3.1 bb) — it's in your Review queue.",
    );
    expect(note.expert, contains('spaced schedule'));
  });

  test('a session with nothing flagged does not invent a debrief', () async {
    final container = homeContainer(
      sessions: [endedSession(worstLabel: null, mistakes: 0)],
    );
    final note = await noteOf(container);

    expect(note.source, CoachNoteSource.none);
  });

  test('due spots travel with the note for H1s button', () async {
    final store = KeyValueStore.memory();
    await seedLeaks(store, [leakSpot(id: 'a'), leakSpot(id: 'b')]);
    final note = await noteOf(homeContainer(store: store));

    expect(note.dueSpots, 2);
  });
}
