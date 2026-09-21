import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/level_result.dart';
import '../../core/constants.dart';
import '../../core/app_themes.dart';
import '../../core/audio_haptic_helper.dart';

class ProgressRepository extends ChangeNotifier {
  late Box _box;
  late Box _resultsBox;

  int _currentLevel = 1;
  int _highestUnlockedLevel = 1;
  GameTheme _selectedTheme = GameTheme.classic;
  bool _skinsUnlocked = false;
  bool _hapticsEnabled = true;
  bool _heartRemover = false;
  bool _assistMode = false;
  bool _complexPaths = false;

  final Map<int, LevelResult> _levelResults = {};

  int get maxLives => AppConstants.maxLives;
  int get currentLevel => _currentLevel;
  int get highestUnlockedLevel => _highestUnlockedLevel;
  GameTheme get selectedTheme => _selectedTheme;
  bool get skinsUnlocked => _skinsUnlocked;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get heartRemover => _heartRemover;
  bool get assistMode => _assistMode;
  bool get complexPaths => _complexPaths;

  int getStarsForLevel(int level) => _levelResults[level]?.stars ?? 0;

  bool isLevelUnlocked(int level) {
    return level <= _highestUnlockedLevel;
  }

  bool isLevelCompleted(int level) => _levelResults.containsKey(level);

  ProgressRepository._();

  static Future<ProgressRepository> create() async {
    final repo = ProgressRepository._();
    await repo._init();
    return repo;
  }

  Future<void> _init() async {
    _box = await Hive.openBox('progress');
    _resultsBox = await Hive.openBox('levelResults');
    _load();
  }

  void _load() {
    _currentLevel = _readInt('currentLevel', 1);
    _highestUnlockedLevel = _readInt('highestUnlockedLevel', 1);
    final themeValue = _box.get('selectedTheme');
    final themeStr = themeValue is String ? themeValue : GameTheme.classic.name;
    _selectedTheme = GameTheme.values.firstWhere(
      (t) => t.name == themeStr,
      orElse: () => GameTheme.classic,
    );
    _skinsUnlocked = _readBool('skinsUnlocked', false);
    _hapticsEnabled = _readBool('hapticsEnabled', true);
    _heartRemover = _readBool('heartRemover', false);
    _assistMode = _readBool('assistMode', false);
    _complexPaths = _readBool('complexPaths', false);
    AudioHapticHelper.hapticsEnabled = _hapticsEnabled;

    for (final key in _resultsBox.keys) {
      final level = int.tryParse(key.toString());
      if (level != null) {
        final jsonStr = _resultsBox.get(key);
        if (jsonStr != null) {
          try {
            _levelResults[level] = LevelResult.fromJson(jsonDecode(jsonStr));
          } catch (e) {
            debugPrint('Error loading level result: $e');
          }
        }
      }
    }
  }

  int _readInt(String key, int fallback) {
    final value = _box.get(key);
    if (value is! int) return fallback;
    if (key == 'currentLevel' || key == 'highestUnlockedLevel') {
      return value < 1 ? 1 : value;
    }
    return value;
  }

  bool _readBool(String key, bool fallback) {
    final value = _box.get(key);
    return value is bool ? value : fallback;
  }

  Future<void> _save() async {
    await _box.putAll({
      'currentLevel': _currentLevel,
      'highestUnlockedLevel': _highestUnlockedLevel,
      'selectedTheme': _selectedTheme.name,
      'skinsUnlocked': _skinsUnlocked,
      'hapticsEnabled': _hapticsEnabled,
      'heartRemover': _heartRemover,
      'assistMode': _assistMode,
      'complexPaths': _complexPaths,
    });

    for (final entry in _levelResults.entries) {
      await _resultsBox.put(
        entry.key.toString(),
        jsonEncode(entry.value.toJson()),
      );
    }
  }

  Future<void> setTheme(GameTheme theme) async {
    _selectedTheme = theme;
    await _save();
    notifyListeners();
  }

  Future<void> toggleHaptics() async {
    _hapticsEnabled = !_hapticsEnabled;
    AudioHapticHelper.hapticsEnabled = _hapticsEnabled;
    await _save();
    notifyListeners();
  }

  Future<void> toggleHeartRemover() async {
    _heartRemover = !_heartRemover;
    await _save();
    notifyListeners();
  }

  Future<void> toggleAssistMode() async {
    _assistMode = !_assistMode;
    await _save();
    notifyListeners();
  }

  Future<void> toggleComplexPaths() async {
    _complexPaths = !_complexPaths;
    await _save();
    notifyListeners();
  }

  Future<bool> unlockSkins(String code) async {
    if (code.trim().toUpperCase() == 'THANKYOU') {
      final previousValue = _skinsUnlocked;
      _skinsUnlocked = true;
      try {
        await _save();
        notifyListeners();
        return true;
      } catch (e) {
        _skinsUnlocked = previousValue;
        debugPrint('Error saving unlocked skins: $e');
        notifyListeners();
        return false;
      }
    }
    return false;
  }

  Future<void> recordLevelComplete(LevelResult result) async {
    final existing = _levelResults[result.levelNumber];
    if (existing == null || result.stars > existing.stars) {
      _levelResults[result.levelNumber] = result;
    }
    if (result.levelNumber >= _currentLevel) {
      _currentLevel = result.levelNumber + 1;
    }
    if (result.levelNumber >= _highestUnlockedLevel) {
      _highestUnlockedLevel = result.levelNumber + 1;
    }
    await _save();
    notifyListeners();
  }

  Future<void> setCurrentLevel(int level) async {
    _currentLevel = level;
    await _save();
    notifyListeners();
  }

  static int calculateStars(int livesLost) {
    if (livesLost == 0) return 3;
    if (livesLost == 1) return 2;
    return 1;
  }
}
