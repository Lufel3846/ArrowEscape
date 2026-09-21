import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// A single achievement definition.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Persisted player statistics, achievements and daily-challenge streak.
class StatsRepository extends ChangeNotifier {
  late Box _box;

  int _totalLevelsCompleted = 0;
  int _totalStars = 0;
  int _perfectLevels = 0;
  int _totalLivesLost = 0;
  int _bestCombo = 0;
  int _dailyStreak = 0;
  int _bestDailyStreak = 0;
  String? _lastDailyCompletedDate; // 'yyyy-MM-dd' (local)
  final Set<String> _unlockedAchievements = {};

  int get totalLevelsCompleted => _totalLevelsCompleted;
  int get totalStars => _totalStars;
  int get perfectLevels => _perfectLevels;
  int get totalLivesLost => _totalLivesLost;
  int get bestCombo => _bestCombo;
  int get dailyStreak => _dailyStreak;
  int get bestDailyStreak => _bestDailyStreak;
  Set<String> get unlockedAchievementIds => Set.unmodifiable(_unlockedAchievements);

  StatsRepository._();

  /// [boxName] is injectable for tests.
  static Future<StatsRepository> create({String boxName = 'stats'}) async {
    final repo = StatsRepository._();
    repo._box = await Hive.openBox(boxName);
    repo._load();
    return repo;
  }

  void _load() {
    _totalLevelsCompleted = _readInt('totalLevelsCompleted');
    _totalStars = _readInt('totalStars');
    _perfectLevels = _readInt('perfectLevels');
    _totalLivesLost = _readInt('totalLivesLost');
    _bestCombo = _readInt('bestCombo');
    _dailyStreak = _readInt('dailyStreak');
    _bestDailyStreak = _readInt('bestDailyStreak');
    final lastDaily = _box.get('lastDailyCompletedDate');
    _lastDailyCompletedDate = lastDaily is String ? lastDaily : null;
    final unlocked = _box.get('unlockedAchievements');
    if (unlocked is List) {
      _unlockedAchievements.addAll(unlocked.cast<String>());
    }
  }

  int _readInt(String key) {
    final value = _box.get(key);
    return value is int ? value : 0;
  }

  Future<void> _save() async {
    await _box.putAll({
      'totalLevelsCompleted': _totalLevelsCompleted,
      'totalStars': _totalStars,
      'perfectLevels': _perfectLevels,
      'totalLivesLost': _totalLivesLost,
      'bestCombo': _bestCombo,
      'dailyStreak': _dailyStreak,
      'bestDailyStreak': _bestDailyStreak,
      'lastDailyCompletedDate': _lastDailyCompletedDate,
      'unlockedAchievements': _unlockedAchievements.toList(),
    });
  }

  /// Records a completed level and evaluates achievements.
  /// Returns the achievements unlocked by this completion.
  Future<List<Achievement>> recordLevelComplete({
    required int stars,
    required int livesLost,
    required int maxCombo,
  }) async {
    _totalLevelsCompleted++;
    _totalStars += stars;
    _totalLivesLost += livesLost;
    if (stars == 3) _perfectLevels++;
    if (maxCombo > _bestCombo) _bestCombo = maxCombo;

    final newlyUnlocked = _evaluateAchievements();
    await _save();
    notifyListeners();
    return newlyUnlocked;
  }

  /// Records today's daily challenge completion and advances the streak.
  /// Returns the current streak after the update.
  Future<int> recordDailyComplete({DateTime? now}) async {
    final today = _dateKey(now ?? DateTime.now());
    if (_lastDailyCompletedDate == today) return _dailyStreak;

    final yesterday = _dateKey((now ?? DateTime.now())
        .subtract(const Duration(days: 1)));
    _dailyStreak =
        _lastDailyCompletedDate == yesterday ? _dailyStreak + 1 : 1;
    _lastDailyCompletedDate = today;
    if (_dailyStreak > _bestDailyStreak) _bestDailyStreak = _dailyStreak;

    final newlyUnlocked = _evaluateAchievements();
    await _save();
    notifyListeners();
    if (newlyUnlocked.isNotEmpty) {
      debugPrint('Achievements unlocked: ${newlyUnlocked.map((a) => a.id)}');
    }
    return _dailyStreak;
  }

  bool get isDailyCompletedToday =>
      _lastDailyCompletedDate == _dateKey(DateTime.now());

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// Deterministic daily level number for the given date (UTC so every
  /// player worldwide gets the same puzzle on the same day).
  static int dailyLevelFor(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final epochDay = utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return (epochDay % 200) + 501; // expert range: 501–700
  }

  // --- Achievements -------------------------------------------------------

  static const List<Achievement> achievements = [
    Achievement(
      id: 'first_escape',
      title: 'First Escape',
      description: 'Complete your first level',
      icon: Icons.emoji_events_outlined,
    ),
    Achievement(
      id: 'getting_hooked',
      title: 'Getting Hooked',
      description: 'Complete 10 levels',
      icon: Icons.anchor_outlined,
    ),
    Achievement(
      id: 'dedicated',
      title: 'Dedicated',
      description: 'Complete 50 levels',
      icon: Icons.fitness_center_outlined,
    ),
    Achievement(
      id: 'obsessed',
      title: 'Obsessed',
      description: 'Complete 150 levels',
      icon: Icons.psychology_outlined,
    ),
    Achievement(
      id: 'star_collector',
      title: 'Star Collector',
      description: 'Earn 50 stars in total',
      icon: Icons.star_border_rounded,
    ),
    Achievement(
      id: 'star_master',
      title: 'Star Master',
      description: 'Earn 200 stars in total',
      icon: Icons.star_rounded,
    ),
    Achievement(
      id: 'perfectionist',
      title: 'Perfectionist',
      description: 'Complete 10 levels with 3 stars',
      icon: Icons.verified_outlined,
    ),
    Achievement(
      id: 'combo_5',
      title: 'Chain Reaction',
      description: 'Reach a 5x combo',
      icon: Icons.bolt_outlined,
    ),
    Achievement(
      id: 'combo_10',
      title: 'Unstoppable',
      description: 'Reach a 10x combo',
      icon: Icons.flash_on_outlined,
    ),
    Achievement(
      id: 'daily_streak_3',
      title: 'Warming Up',
      description: 'Complete the Daily Challenge 3 days in a row',
      icon: Icons.local_fire_department_outlined,
    ),
    Achievement(
      id: 'daily_streak_7',
      title: 'On Fire',
      description: 'Complete the Daily Challenge 7 days in a row',
      icon: Icons.whatshot_outlined,
    ),
    Achievement(
      id: 'zen_master',
      title: 'Zen Master',
      description: 'Complete 25 levels with zero mistakes',
      icon: Icons.spa_outlined,
    ),
  ];

  bool isUnlocked(String id) => _unlockedAchievements.contains(id);

  List<Achievement> _evaluateAchievements() {
    final newlyUnlocked = <Achievement>[];
    for (final a in achievements) {
      if (_unlockedAchievements.contains(a.id)) continue;
      if (_check(a.id)) {
        _unlockedAchievements.add(a.id);
        newlyUnlocked.add(a);
      }
    }
    return newlyUnlocked;
  }

  bool _check(String id) {
    switch (id) {
      case 'first_escape':
        return _totalLevelsCompleted >= 1;
      case 'getting_hooked':
        return _totalLevelsCompleted >= 10;
      case 'dedicated':
        return _totalLevelsCompleted >= 50;
      case 'obsessed':
        return _totalLevelsCompleted >= 150;
      case 'star_collector':
        return _totalStars >= 50;
      case 'star_master':
        return _totalStars >= 200;
      case 'perfectionist':
        return _perfectLevels >= 10;
      case 'combo_5':
        return _bestCombo >= 5;
      case 'combo_10':
        return _bestCombo >= 10;
      case 'daily_streak_3':
        return _bestDailyStreak >= 3;
      case 'daily_streak_7':
        return _bestDailyStreak >= 7;
      case 'zen_master':
        return _perfectLevels >= 25;
      default:
        return false;
    }
  }
}
