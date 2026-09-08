/// The typed key-value stores: settings, theme, table options, onboarding,
/// hints, goals, drill state and study progress
/// (docs/port/persistence-stats-settings.md §6; DESIGN.md §16.4).
///
/// Every key name and JSON shape here is the desktop's, so a desktop backup
/// round-trips.
library;

import 'dart:convert';

import 'package:allin/engine/engine.dart'
    show
        CoachSettings,
        CoachStrictness,
        SimQuality,
        baseItersFor,
        coachThresholds,
        kDefaultRating;
import 'package:allin/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  group('KeyValueStore', () {
    test('reads are total', () {
      expect(store.getString('nope'), isNull);
      expect(store.getJson('nope'), isNull);
      expect(store.getJsonMap('nope'), isEmpty);
      expect(store.getJsonList('nope'), isEmpty);
    });

    test('corrupt JSON reads as the default', () async {
      await store.setString('k', '{broken');
      expect(store.getJson('k'), isNull);
      expect(store.getJsonMap('k'), isEmpty);
      expect(store.getJsonList('k'), isEmpty);
    });

    test(
      'a read-only store reports failed writes instead of throwing',
      () async {
        final ro = MemoryKeyValueStore.readOnly({'a': '1'});
        expect(await ro.setString('a', '2'), isFalse);
        expect(await ro.setJson('b', {'x': 1}), isFalse);
        expect(await ro.remove('a'), isFalse);
        expect(ro.getString('a'), '1');
      },
    );

    test('clearAllInKeys only touches the allin. namespace', () async {
      await store.setString('allin.settings.v1', '{}');
      await store.setString('other', 'keep');
      await store.clearAllInKeys();
      expect(store.getString('allin.settings.v1'), isNull);
      expect(store.getString('other'), 'keep');
    });
  });

  group('SettingsStore', () {
    test('defaults match the desktop plus the mobile additions', () {
      final s = SettingsStore(store).load();
      expect(s.fourColorDeck, isFalse);
      expect(s.reducedMotion, isFalse);
      expect(s.coachStrictness, CoachStrictness.standard);
      expect(s.simQuality, SimQuality.standard);
      expect(s.realisticReveal, isFalse);
      expect(s.haptics, isTrue);
      expect(s.alwaysExpandMath, isFalse);
      expect(s.paceMode, PaceMode.manual);
      expect(s.speedMs, PaceSpeed.normalMs);
      expect(s.coachEnabled, isTrue);
      expect(s.autoDeal, isFalse);
    });

    test('round-trips every field under the desktop key', () async {
      final settings = SettingsStore(store);
      await settings.save(
        const AppSettings(
          fourColorDeck: true,
          reducedMotion: true,
          coachStrictness: CoachStrictness.strict,
          simQuality: SimQuality.high,
          realisticReveal: true,
          haptics: false,
          alwaysExpandMath: true,
          paceMode: PaceMode.auto,
          speedMs: PaceSpeed.slowMs,
          coachEnabled: false,
          autoDeal: true,
        ),
      );

      expect(store.getString(kSettingsKey), isNotNull);
      final raw = jsonDecode(store.getString(kSettingsKey)!) as Map;
      expect(raw['coachStrictness'], 'strict');
      expect(raw['simQuality'], 'high');
      expect(raw['paceMode'], 'auto');

      final back = settings.load();
      expect(back.fourColorDeck, isTrue);
      expect(back.coachStrictness, CoachStrictness.strict);
      expect(back.simQuality, SimQuality.high);
      expect(back.haptics, isFalse);
      expect(back.alwaysExpandMath, isTrue);
      expect(back.paceMode, PaceMode.auto);
      expect(back.speedMs, PaceSpeed.slowMs);
      expect(back.coachEnabled, isFalse);
      expect(back.autoDeal, isTrue);
      expect(back.coachSettings, isA<CoachSettings>());
      expect(back.coachSettings.strictness, CoachStrictness.strict);
      expect(back.coachSettings.baseIters, 4000);
    });

    test('a desktop settings blob merges over the defaults', () async {
      await store.setString(
        kSettingsKey,
        '{"fourColorDeck":true,"coachStrictness":"relaxed","futureFlag":7}',
      );
      final s = SettingsStore(store).load();
      expect(s.fourColorDeck, isTrue);
      expect(s.coachStrictness, CoachStrictness.relaxed);
      expect(s.haptics, isTrue, reason: 'missing keys keep their default');
      expect(s.extra['futureFlag'], 7);
    });

    test('unknown keys survive a save', () async {
      await store.setString(kSettingsKey, '{"futureFlag":7}');
      final settings = SettingsStore(store);
      await settings.save(settings.load());
      final raw = jsonDecode(store.getString(kSettingsKey)!) as Map;
      expect(raw['futureFlag'], 7);
      expect(raw['haptics'], true);
    });

    test('update mutates and persists', () async {
      final settings = SettingsStore(store);
      final next = await settings.update(
        (s) => s.copyWith(realisticReveal: true),
      );
      expect(next.realisticReveal, isTrue);
      expect(settings.load().realisticReveal, isTrue);
    });

    test('an unreadable blob falls back to the defaults', () async {
      await store.setString(kSettingsKey, 'nonsense');
      expect(
        SettingsStore(store).load().coachStrictness,
        CoachStrictness.standard,
      );
    });

    test('coach thresholds match the desktop table', () {
      expect(coachThresholds(CoachStrictness.relaxed).mistakeBb, -0.6);
      expect(coachThresholds(CoachStrictness.relaxed).foldFlagBb, 2.5);
      expect(coachThresholds(CoachStrictness.standard).mistakeBb, -0.3);
      expect(coachThresholds(CoachStrictness.standard).foldFlagBb, 1.5);
      expect(coachThresholds(CoachStrictness.strict).mistakeBb, -0.15);
      expect(coachThresholds(CoachStrictness.strict).foldFlagBb, 1.0);
      expect(baseItersFor(SimQuality.standard), 1600);
      expect(baseItersFor(SimQuality.high), 4000);
    });
  });

  group('ThemeStore', () {
    test('defaults to dark and stores a raw string', () async {
      final theme = ThemeStore(store);
      expect(theme.load(), AppThemeMode.dark);

      await theme.save(AppThemeMode.light);
      expect(store.getString(kThemeKey), 'light');
      expect(theme.load(), AppThemeMode.light);

      expect(await theme.toggle(), AppThemeMode.dark);
    });

    test('junk reads as dark', () async {
      await store.setString(kThemeKey, 'sepia');
      expect(ThemeStore(store).load(), AppThemeMode.dark);
    });
  });

  group('TableOptionsStore', () {
    test('defaults to 6-max with no ante', () {
      final o = TableOptionsStore(store).load();
      expect(o.seats, 6);
      expect(o.ante, 0);
      expect(o.seatsLabel, '6-max');
    });

    test('round-trips and sanitises', () async {
      final options = TableOptionsStore(store);
      await options.save(const TableOptions(seats: 9, ante: 5));
      expect(options.load().seats, 9);
      expect(options.load().ante, 5);
      expect(options.load().seatsLabel, '9-max');

      await store.setString(kTableOptionsKey, '{"seats":7,"ante":3}');
      expect(options.load().seats, 6);
      expect(options.load().ante, 0);

      await store.setString(kTableOptionsKey, '{"seats":2,"ante":5}');
      expect(options.load().seats, 2);
      expect(options.load().seatsLabel, 'Heads-up');
    });
  });

  group('OnboardingStore', () {
    test('absent means not onboarded; the flag is the string "1"', () async {
      final onboarding = OnboardingStore(store);
      expect(onboarding.hasOnboarded(), isFalse);

      await onboarding.markOnboarded();
      expect(store.getString(kOnboardedKey), '1');
      expect(onboarding.hasOnboarded(), isTrue);

      await onboarding.reset();
      expect(onboarding.hasOnboarded(), isFalse);
    });
  });

  group('HintsStore', () {
    test('counts the first-table coach marks', () async {
      final hints = HintsStore(store);
      expect(hints.load().showsFirstTableMarks, isTrue);

      for (var i = 0; i < kFirstHandsHintLimit; i++) {
        await hints.increment(HintKind.firstHands);
      }
      expect(hints.load().firstHands, kFirstHandsHintLimit);
      expect(hints.load().showsFirstTableMarks, isFalse);

      await hints.increment(HintKind.swipeHint);
      await hints.increment(HintKind.revealCollapse);
      expect(hints.load().swipeHint, 1);
      expect(hints.load().revealCollapse, 1);

      await hints.reset();
      expect(hints.load().showsFirstTableMarks, isTrue);
    });
  });

  group('GoalsStore', () {
    // A fixed local noon, so no test straddles midnight.
    final today = DateTime(2026, 9, 7, 12).millisecondsSinceEpoch;
    const dayMs = 86400000;

    test('dayKey is local and zero-padded', () {
      expect(
        dayKey(DateTime(2026, 3, 7, 23, 59).millisecondsSinceEpoch),
        '2026-03-07',
      );
      expect(
        dayKey(DateTime(2026, 12, 31).millisecondsSinceEpoch),
        '2026-12-31',
      );
    });

    test('records drills and hands under the desktop shape', () async {
      final goals = GoalsStore(store);
      await goals.record(ActivityKind.drill, nowMs: today);
      await goals.record(ActivityKind.hand, nowMs: today);
      await goals.record(ActivityKind.hand, nowMs: today);

      expect(goals.today(nowMs: today).drills, 1);
      expect(goals.today(nowMs: today).hands, 2);
      expect(goals.today(nowMs: today).total, 3);

      final raw = store.getJsonMap(kGoalsKey);
      expect(raw.keys.single, dayKey(today));
      expect((raw[dayKey(today)]! as Map)['drills'], 1);
      expect((raw[dayKey(today)]! as Map)['hands'], 2);
    });

    test('metGoal takes either target', () {
      expect(metGoal(null), isFalse);
      expect(metGoal(const DailyActivity(drills: 19, hands: 29)), isFalse);
      expect(metGoal(const DailyActivity(drills: 20)), isTrue);
      expect(metGoal(const DailyActivity(hands: 30)), isTrue);
    });

    test(
      'streak counts consecutive met days ending today or yesterday',
      () async {
        final goals = GoalsStore(store);
        Future<void> metOn(int ts) async {
          for (var i = 0; i < kDailyDrillGoal; i++) {
            await goals.record(ActivityKind.drill, nowMs: ts);
          }
        }

        await metOn(today - dayMs);
        await metOn(today - 2 * dayMs);
        expect(goals.streak(nowMs: today), 2, reason: 'today not yet met');

        await metOn(today);
        expect(goals.streak(nowMs: today), 3);

        expect(GoalsStore(MemoryKeyValueStore()).streak(nowMs: today), 0);
      },
    );

    test('the heatmap is 16 weeks ending today', () async {
      final goals = GoalsStore(store);
      await goals.record(ActivityKind.hand, nowMs: today);
      final cells = goals.heatmapCells(nowMs: today);

      expect(cells, hasLength(112));
      expect(cells.last.key, dayKey(today));
      expect(cells.last.count, 1);
      expect(cells.first.key, dayKey(today - 111 * dayMs));
      expect(GoalsStore.activeDays(cells), 1);
    });
  });

  group('DrillStore', () {
    test('defaults, and a blob without a numeric rating is ignored', () async {
      final drills = DrillStore(store);
      expect(drills.load().rating, kDefaultRating);
      expect(drills.load().solved, 0);

      await store.setString(kDrillStateKey, '{"rating":"high","solved":9}');
      expect(drills.load().rating, 1000);
      expect(drills.load().solved, 0);
    });

    test('round-trips the scoreboard', () async {
      final drills = DrillStore(store);
      await drills.save(
        const DrillState(
          rating: 1180,
          solved: 40,
          correct: 31,
          streak: 4,
          best: 9,
        ),
      );
      final s = drills.load();
      expect(s.rating, 1180);
      expect(s.solved, 40);
      expect(s.correct, 31);
      expect(s.streak, 4);
      expect(s.best, 9);
    });

    test('seedRating only moves the rating', () async {
      final drills = DrillStore(store);
      await drills.save(const DrillState(rating: 1000, solved: 12, best: 3));
      await drills.seedRating(DrillStore.placementRating(6));
      expect(drills.load().rating, 1250);
      expect(drills.load().solved, 12);
      expect(drills.load().best, 3);

      expect(DrillStore.placementRating(0), 900);
      expect(DrillStore.placementRating(2), 900);
      expect(DrillStore.placementRating(5), 1050);
      expect(DrillStore.placementRating(7), 1250);
    });

    test('the answer ring keeps the last 200', () async {
      final drills = DrillStore(store);
      for (var i = 0; i < kDrillAnswersCap + 20; i++) {
        await drills.recordAnswer(
          DrillAnswer(
            ts: i,
            mode: i.isEven ? 'mixed' : 'pushfold',
            kind: 'rfi',
            correct: i % 3 != 0,
            ratingAfter: 1000 + i.toDouble(),
          ),
        );
      }
      final ring = drills.loadAnswers();
      expect(ring, hasLength(kDrillAnswersCap));
      expect(ring.first.ts, 20);
      expect(ring.last.ratingAfter, (1000 + kDrillAnswersCap + 19).toDouble());

      final acc = drills.accuracyByMode();
      expect(acc.keys.toSet(), {'mixed', 'pushfold'});
      expect(acc['mixed'], inInclusiveRange(0, 1));

      await drills.clearAnswers();
      expect(drills.loadAnswers(), isEmpty);
    });
  });

  group('StudyProgressStore', () {
    test('writes the two desktop keys', () async {
      final study = StudyProgressStore(store);
      await study.complete('rules');
      await study.recordQuiz(
        StudyProgress.quizKey('Which beats which?'),
        true,
        nowMs: 42,
      );

      expect(jsonDecode(store.getString(StudyProgressStore.completedKey)!), [
        'rules',
      ]);
      final quiz =
          jsonDecode(store.getString(StudyProgressStore.quizKey)!) as Map;
      expect(quiz.keys.single, '1415407767', reason: 'hashSeed of the prompt');
      expect((quiz['1415407767']! as Map)['correct'], 1);
      expect((quiz['1415407767']! as Map)['lastCorrect'], true);
      expect((quiz['1415407767']! as Map)['ts'], 42);

      final back = study.load();
      expect(back.isComplete('rules'), isTrue);
      expect(back.completedCount, 1);
    });

    test('toggle removes a completed lesson', () async {
      final study = StudyProgressStore(store);
      await study.complete('rules');
      await study.toggle('rules');
      expect(study.load().isComplete('rules'), isFalse);
    });

    test('a desktop blob loads as-is', () async {
      await store.setString(
        StudyProgressStore.completedKey,
        '["rules","position"]',
      );
      await store.setString(
        StudyProgressStore.quizKey,
        '{"123":{"correct":2,"wrong":1,"lastCorrect":false,"ts":9}}',
      );
      final p = StudyProgressStore(store).load();
      expect(p.completed, ['rules', 'position']);
      expect(p.quizResults['123']!.correct, 2);
      expect(p.wasMissed('123'), isTrue);
    });
  });
}
