import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:arrowescape/data/repositories/stats_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stats_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('stats_test');
    await tempDir.delete(recursive: true);
  });

  group('StatsRepository — level stats', () {
    test('records level completions, stars and perfect levels', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      await stats.recordLevelComplete(stars: 3, livesLost: 0, maxCombo: 2);
      await stats.recordLevelComplete(stars: 1, livesLost: 2, maxCombo: 4);

      expect(stats.totalLevelsCompleted, 2);
      expect(stats.totalStars, 4);
      expect(stats.perfectLevels, 1);
      expect(stats.totalLivesLost, 2);
      expect(stats.bestCombo, 4);
    });

    test('first_escape achievement unlocks on first completion', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      final unlocked = await stats.recordLevelComplete(
          stars: 3, livesLost: 0, maxCombo: 1);

      expect(stats.isUnlocked('first_escape'), isTrue);
      expect(unlocked.map((a) => a.id), contains('first_escape'));
    });

    test('achievements unlock only once', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      final first = await stats.recordLevelComplete(
          stars: 3, livesLost: 0, maxCombo: 1);
      final second = await stats.recordLevelComplete(
          stars: 3, livesLost: 0, maxCombo: 1);

      expect(first.map((a) => a.id), contains('first_escape'));
      expect(second.map((a) => a.id), isNot(contains('first_escape')));
    });

    test('state persists across repository instances', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');
      await stats.recordLevelComplete(stars: 2, livesLost: 1, maxCombo: 5);

      final reloaded = await StatsRepository.create(boxName: 'stats_test');
      expect(reloaded.totalLevelsCompleted, 1);
      expect(reloaded.totalStars, 2);
      expect(reloaded.bestCombo, 5);
      expect(reloaded.isUnlocked('combo_5'), isTrue);
    });
  });

  group('StatsRepository — daily streak', () {
    test('first completion starts a streak of 1', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      final streak =
          await stats.recordDailyComplete(now: DateTime(2026, 9, 21));

      expect(streak, 1);
      expect(stats.dailyStreak, 1);
      expect(stats.bestDailyStreak, 1);
    });

    test('consecutive days increment the streak', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      await stats.recordDailyComplete(now: DateTime(2026, 9, 20));
      final streak =
          await stats.recordDailyComplete(now: DateTime(2026, 9, 21));

      expect(streak, 2);
    });

    test('a gap resets the streak', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      await stats.recordDailyComplete(now: DateTime(2026, 9, 18));
      final streak =
          await stats.recordDailyComplete(now: DateTime(2026, 9, 21));

      expect(streak, 1);
      // Best streak is preserved.
      expect(stats.bestDailyStreak, 1);
    });

    test('completing twice on the same day does not double the streak',
        () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      await stats.recordDailyComplete(now: DateTime(2026, 9, 20));
      await stats.recordDailyComplete(now: DateTime(2026, 9, 21));
      final streak =
          await stats.recordDailyComplete(now: DateTime(2026, 9, 21));

      expect(streak, 2);
      expect(stats.bestDailyStreak, 2);
    });

    test('daily streak achievements unlock at 3 and 7 days', () async {
      final stats = await StatsRepository.create(boxName: 'stats_test');

      for (var day = 1; day <= 7; day++) {
        await stats.recordDailyComplete(now: DateTime(2026, 9, day));
      }

      expect(stats.bestDailyStreak, 7);
      expect(stats.isUnlocked('daily_streak_3'), isTrue);
      expect(stats.isUnlocked('daily_streak_7'), isTrue);
    });
  });

  group('dailyLevelFor', () {
    test('is deterministic for the same day', () {
      final a = StatsRepository.dailyLevelFor(DateTime(2026, 9, 21));
      final b = StatsRepository.dailyLevelFor(DateTime(2026, 9, 21));
      expect(a, equals(b));
    });

    test('falls in the expert range (501–700)', () {
      for (var day = 1; day <= 30; day++) {
        final level = StatsRepository.dailyLevelFor(DateTime(2026, 9, day));
        expect(level, inInclusiveRange(501, 700));
      }
    });

    test('changes across days', () {
      // 200-level cycle: adjacent days may rarely share a number, but a
      // week apart never does.
      final a = StatsRepository.dailyLevelFor(DateTime(2026, 9, 21));
      final b = StatsRepository.dailyLevelFor(DateTime(2026, 9, 28));
      expect(a, isNot(equals(b)));
    });
  });
}
