import 'dart:async';

import 'package:flutter/material.dart';
import '../data/models/arrow.dart';
import '../data/models/level.dart';
import '../core/constants.dart';
import '../core/app_themes.dart';
import '../core/game_mode.dart';
import 'path_simulation.dart';

class GameState extends ChangeNotifier {
  bool _disposed = false;
  Timer? _blockResetTimer;

  late LevelModel _currentLevel;
  late List<ArrowModel> _arrows;
  int _lives = AppConstants.maxLives;
  int _livesLost = 0;
  bool _isComplete = false;
  bool _isGameOver = false;
  bool _isDeadlocked = false;
  final GameTheme theme;
  final GameMode gameMode;
  final bool heartRemover;
  final bool assistMode;

  late Map<String, OrphanDotType> _orphanDots;

  final Map<String, ArrowState> _stateById = {};

  final Map<String, List<OrphanDot>> _consumedDotsByArrow = {};

  final void Function() onLevelComplete;
  final void Function() onGameOver;
  final void Function() onLifeLost;
  final void Function()? onDeadlock;
  final void Function()? onCombo;
  final void Function(Offset globalPos, Color color)? onParticleBurst;
  final void Function()? onCameraShake;
  
  DateTime? _lastExitTime;
  int _comboCount = 0;
  
  int get comboCount => _comboCount;

  GameState({
    required LevelModel level,
    required this.theme,
    required this.onLevelComplete,
    required this.onGameOver,
    required this.onLifeLost,
    this.onDeadlock,
    this.gameMode = GameMode.classic,
    this.heartRemover = false,
    this.assistMode = false,
    this.onCombo,
    this.onParticleBurst,
    this.onCameraShake,
  }) {
    _currentLevel = level;
    _arrows = level.arrows.map((a) => a.copyWith()).toList();
    _stateById
      ..clear()
      ..addEntries([for (final a in _arrows) MapEntry(a.id, a.state)]);
    _orphanDots = {for (final od in level.orphanDots) od.key: od.type};
    _lives = (gameMode == GameMode.zen || gameMode == GameMode.timeAttack || heartRemover) ? 999 : AppConstants.maxLives;
  }

  List<ArrowModel> get arrows => _arrows;
  int get lives => _lives;
  int get livesLost => _livesLost;
  bool get isComplete => _isComplete;
  bool get isGameOver => _isGameOver;
  bool get isDeadlocked => _isDeadlocked;
  LevelModel get level => _currentLevel;
  
  Map<String, OrphanDotType> get orphanDots => _orphanDots;

  ArrowState? stateForArrow(String arrowId) {
    return _stateById[arrowId];
  }

  void handleArrowExitCompleted(String arrowId) {
    _arrows.removeWhere((a) => a.id == arrowId);
    _stateById.remove(arrowId);
    _consumedDotsByArrow.remove(arrowId);

    if (_arrows.isEmpty) {
      _isComplete = true;
      onLevelComplete();
    } else {
      if (checkDeadlock()) {
        _isDeadlocked = true;
        onDeadlock?.call();
      }
    }
    notifyListeners();
  }

  bool checkDeadlock() {
    if (_arrows.isEmpty) return false;

    final blockers = _blockedCellsFor();
    for (final arrow in _arrows) {
      final exit = _computeExitInfo(arrow, blockers);
      if (!exit.blocked) {
        return false;
      }
    }
    return true;
  }

  bool isArrowBlocked(String arrowId) {
    final index = _arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return true;
    final arrow = _arrows[index];
    return _computeExitInfo(arrow).blocked;
  }

  List<OrphanDot> getConsumedDotsForArrow(String arrowId) {
    return _consumedDotsByArrow[arrowId] ?? [];
  }

  void _recordConsumedDots(String arrowId, List<String> consumedKeys) {
    final dots = <OrphanDot>[];
    for (final key in consumedKeys) {
      final match = _currentLevel.orphanDots.firstWhere(
        (od) => od.key == key,
        orElse: () {
          final parts = key.split(',');
          return OrphanDot(
            row: int.parse(parts[0]),
            col: int.parse(parts[1]),
            type: OrphanDotType.neutral,
          );
        },
      );
      dots.add(match);
    }
    _consumedDotsByArrow[arrowId] = dots;
  }

  static const int maxUndos = 1;
  int _undosLeft = maxUndos;
  _UndoSnapshot? _undoSnapshot;

  int get undosLeft => _undosLeft;
  bool get canUndo =>
      !_isComplete &&
      !_isGameOver &&
      _undosLeft > 0 &&
      _undoSnapshot != null &&
      !_arrows.any((a) => a.state == ArrowState.sliding);

  /// When true, player taps are ignored (used by solution replay).
  bool inputLocked = false;

  void _captureUndoSnapshot() {
    _undoSnapshot = _UndoSnapshot(
      arrows: [for (final a in _arrows) a.copyWith()],
      orphanDots: Map.of(_orphanDots),
      lives: _lives,
      livesLost: _livesLost,
      lastExitTime: _lastExitTime,
      comboCount: _comboCount,
    );
  }

  /// Restores the board to the state before the last tap (one per level).
  /// Returns true if the undo was applied.
  bool undo() {
    if (!canUndo) return false;
    if (_arrows.any((a) => a.state == ArrowState.sliding)) return false;

    final snap = _undoSnapshot!;
    _blockResetTimer?.cancel();
    _blockResetTimer = null;
    // Sliding/blocked are transient states owned by in-flight animations.
    // A snapshot can legitimately contain them (e.g. an arrow that was
    // still animating when the next tap happened). Restoring them as-is
    // would leave the arrow permanently stuck — its animation component
    // is already gone, so nothing would ever set it back to idle.
    _arrows = [
      for (final a in snap.arrows) a.copyWith(state: ArrowState.idle)
    ];
    _stateById
      ..clear()
      ..addEntries([for (final a in _arrows) MapEntry(a.id, a.state)]);
    _orphanDots = Map.of(snap.orphanDots);
    _consumedDotsByArrow.clear();
    _lives = snap.lives;
    _livesLost = snap.livesLost;
    _lastExitTime = snap.lastExitTime;
    _comboCount = snap.comboCount;
    _undoSnapshot = null;
    _undosLeft--;
    notifyListeners();
    return true;
  }

  TapResult tapArrow(String arrowId, {bool force = false}) {
    if (_isComplete || _isGameOver) return TapResult.ignored;
    if (inputLocked && !force) return TapResult.ignored;

    final index = _arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return TapResult.ignored;

    final arrow = _arrows[index];
    if (arrow.state != ArrowState.idle) {
      return TapResult.ignored;
    }

    _captureUndoSnapshot();

    final exitInfo = _computeExitInfo(arrow);
    if (exitInfo.blocked) {
      _comboCount = 0;
      onCameraShake?.call();
      return _handleBlocked(index, arrow, arrowId);
    }

    final now = DateTime.now();
    if (_lastExitTime != null && now.difference(_lastExitTime!).inMilliseconds < 1500) {
      _comboCount++;
      if (_comboCount >= 2) {
        onCombo?.call();
      }
    } else {
      _comboCount = 1;
    }
    _lastExitTime = now;

    _arrows[index] = arrow.copyWith(state: ArrowState.sliding);
    _stateById[arrowId] = ArrowState.sliding;
    _recordConsumedDots(arrowId, exitInfo.consumed);
    
    for (final k in exitInfo.consumed) {
      _orphanDots.remove(k);
    }
    notifyListeners();

    return TapResult.exited;
  }

  TapResult _handleBlocked(int index, ArrowModel arrow, String arrowId) {
    _arrows[index] = arrow.copyWith(state: ArrowState.blocked);
    _stateById[arrowId] = ArrowState.blocked;
    if (gameMode != GameMode.zen && gameMode != GameMode.timeAttack && !heartRemover) {
      _lives--;
      _livesLost++;
      onLifeLost();
    }
 
    _blockResetTimer?.cancel();
    _blockResetTimer = Timer(AppConstants.arrowShakeDuration, () {
      if (_disposed) return;
      final idx = _arrows.indexWhere((a) => a.id == arrowId);
      if (idx != -1 && _arrows[idx].state == ArrowState.blocked) {
        _arrows[idx] = _arrows[idx].copyWith(state: ArrowState.idle);
        _stateById[arrowId] = ArrowState.idle;
        notifyListeners();
      }
    });
 
    if (gameMode != GameMode.zen && gameMode != GameMode.timeAttack && !heartRemover && _lives <= 0) {
      _isGameOver = true;
      onGameOver();
      notifyListeners();
      return TapResult.blocked;
    }
 
    notifyListeners();
    return TapResult.blocked;
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _blockResetTimer?.cancel();
    _blockResetTimer = null;
    super.dispose();
  }

  _ExitInfo _computeExitInfo(ArrowModel arrow, [Set<String>? blockedCells]) {
    final blockers =
        blockedCells ?? _blockedCellsFor(excludeId: arrow.id);
    final sim = PathSimulation.simulateExit(
      arrow: arrow,
      gridSize: _currentLevel.gridSize,
      blockedCells: blockers,
      orphanDots: _orphanDots,
    );
    return _ExitInfo(sim.blocked, sim.consumedDotKeys);
  }

  /// Cells occupied by arrows that still physically block movement
  /// (every arrow except the excluded one and any already sliding).
  Set<String> _blockedCellsFor({String? excludeId}) {
    final cells = <String>{};
    for (final other in _arrows) {
      if (other.id == excludeId) continue;
      if (other.state == ArrowState.sliding) continue;
      for (final pt in other.path) {
        cells.add('${pt[0]},${pt[1]}');
      }
    }
    return cells;
  }

  void resetLevel() {
    _blockResetTimer?.cancel();
    _blockResetTimer = null;
    _undoSnapshot = null;
    _undosLeft = maxUndos;
    _arrows = _currentLevel.arrows.map((a) => a.copyWith(state: ArrowState.idle)).toList();
    _stateById
      ..clear()
      ..addEntries([for (final a in _arrows) MapEntry(a.id, a.state)]);
    _orphanDots = {for (final od in _currentLevel.orphanDots) od.key: od.type};
    _consumedDotsByArrow.clear();
    _lives = (gameMode == GameMode.zen || gameMode == GameMode.timeAttack || heartRemover) ? 999 : AppConstants.maxLives;
    _livesLost = 0;
    _isComplete = false;
    _isGameOver = false;
    _isDeadlocked = false;
    notifyListeners();
  }

  void restoreLife() {
    if (_disposed) return;
    if (_lives < AppConstants.maxLives) {
      _lives++;
      if (_isGameOver && _lives > 0) {
        _isGameOver = false;
      }
      notifyListeners();
    }
  }

  /// Immediately returns blocked arrows to idle without waiting for the
  /// shake animation (used by tests to reach deterministic states).
  void resetBlockStateForTest() {
    for (var i = 0; i < _arrows.length; i++) {
      if (_arrows[i].state == ArrowState.blocked) {
        _arrows[i] = _arrows[i].copyWith(state: ArrowState.idle);
        _stateById[_arrows[i].id] = ArrowState.idle;
      }
    }
  }

  void forceGameOver() {    _isGameOver = true;
    onGameOver();
    notifyListeners();
  }

  void resumeFromTimeout() {
    _isGameOver = false;
    notifyListeners();
  }
}

enum TapResult { exited, blocked, ignored }

class _UndoSnapshot {
  final List<ArrowModel> arrows;
  final Map<String, OrphanDotType> orphanDots;
  final int lives;
  final int livesLost;
  final DateTime? lastExitTime;
  final int comboCount;

  const _UndoSnapshot({
    required this.arrows,
    required this.orphanDots,
    required this.lives,
    required this.livesLost,
    required this.lastExitTime,
    required this.comboCount,
  });
}

class _ExitInfo {
  final bool blocked;
  final List<String> consumed; 
  const _ExitInfo(this.blocked, [this.consumed = const []]);
}
