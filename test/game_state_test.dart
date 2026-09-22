import 'package:flutter_test/flutter_test.dart';

import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/core/app_themes.dart';
import 'package:arrowescape/core/constants.dart';
import 'package:arrowescape/core/game_mode.dart';
import 'package:arrowescape/game/game_state.dart';

/// Builds a 1x1-cell arrow whose body occupies [cells]; the head is the
/// first cell and points in [direction].
ArrowModel arrow(
  String id,
  List<List<int>> cells,
  ArrowDirection direction, [
  ArrowState state = ArrowState.idle,
]) =>
    ArrowModel(
      id: id,
      row: cells.last[0],
      col: cells.last[1],
      direction: direction,
      state: state,
      path: cells,
    );

LevelModel level({
  int gridSize = 5,
  List<ArrowModel> arrows = const [],
  List<OrphanDot> orphanDots = const [],
}) =>
    LevelModel(
      levelNumber: 1,
      gridSize: gridSize,
      arrows: arrows,
      orphanDots: orphanDots,
    );

GameState buildState(
  LevelModel lvl, {
  GameMode gameMode = GameMode.classic,
  bool heartRemover = false,
  void Function()? onLevelComplete,
  void Function()? onGameOver,
  void Function()? onLifeLost,
  void Function()? onDeadlock,
  void Function()? onCombo,
}) =>
    GameState(
      level: lvl,
      theme: GameTheme.classic,
      gameMode: gameMode,
      heartRemover: heartRemover,
      onLevelComplete: onLevelComplete ?? () {},
      onGameOver: onGameOver ?? () {},
      onLifeLost: onLifeLost ?? () {},
      onDeadlock: onDeadlock,
      onCombo: onCombo,
    );

void main() {
  group('tapArrow — exits', () {
    test('a free arrow exits the board', () {
      // Arrow at row 0 pointing up leaves immediately.
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      expect(state.tapArrow('a'), TapResult.exited);
      expect(state.stateForArrow('a'), ArrowState.sliding);
      expect(state.lives, AppConstants.maxLives);
    });

    test('exit consumes neutral orphan dots without redirecting', () {
      // Head at (0,1) pointing right walks over the dot at (0,2).
      final lvl = level(arrows: [
        arrow('a', [[0, 1]], ArrowDirection.right),
      ], orphanDots: [
        const OrphanDot(row: 0, col: 2, type: OrphanDotType.neutral),
      ]);
      final state = buildState(lvl);

      expect(state.tapArrow('a'), TapResult.exited);
      expect(state.getConsumedDotsForArrow('a'), hasLength(1));
      expect(state.orphanDots.containsKey('0,2'), isFalse);
    });

    test('directional orphan dot redirects the path', () {
      // Head at (2,2) pointing left; the dot at (2,1) turns the walk up.
      final lvl = level(arrows: [
        arrow('a', [[2, 2]], ArrowDirection.left),
      ], orphanDots: [
        const OrphanDot(row: 2, col: 1, type: OrphanDotType.up),
      ]);
      final state = buildState(lvl);

      expect(state.tapArrow('a'), TapResult.exited);
      // Without the dot the arrow exits via column 0; with it, the path
      // turns up at (2,1) and consumes that dot.
      expect(state.getConsumedDotsForArrow('a').first.key, '2,1');
    });

    test('last arrow leaving completes the level', () {
      var completed = false;
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.up),
      ]);
      final state = buildState(lvl, onLevelComplete: () => completed = true);

      state.tapArrow('a');
      expect(state.isComplete, isFalse);

      // The Flame side signals the exit animation finished.
      state.handleArrowExitCompleted('a');
      expect(state.isComplete, isTrue);
      expect(completed, isTrue);
    });
  });

  group('tapArrow — blocked', () {
    test('blocked arrow loses a life and resets to idle after shake', () async {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      // 'a' walks down into 'b'.
      expect(state.tapArrow('a'), TapResult.blocked);
      expect(state.stateForArrow('a'), ArrowState.blocked);
      expect(state.lives, AppConstants.maxLives - 1);
      expect(state.livesLost, 1);

      await Future.delayed(const Duration(milliseconds: 500));
      expect(state.stateForArrow('a'), ArrowState.idle);
    });

    test('two arrows blocked in sequence each reset independently', () async {
      // Regression: the single shared reset timer meant blocking arrow 'b'
      // cancelled the pending reset of arrow 'a', leaving 'a' permanently
      // grey and immovable.
      final lvl = level(arrows: [
        arrow('a', [[0, 0]], ArrowDirection.down),
        arrow('c', [[2, 0]], ArrowDirection.up),
        arrow('b', [[0, 4]], ArrowDirection.down),
        arrow('d', [[2, 4]], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      expect(state.tapArrow('a'), TapResult.blocked);
      expect(state.tapArrow('b'), TapResult.blocked);
      expect(state.stateForArrow('a'), ArrowState.blocked);
      expect(state.stateForArrow('b'), ArrowState.blocked);

      await Future.delayed(const Duration(milliseconds: 500));

      // Both arrows must recover — b's block must not swallow a's timer.
      expect(state.stateForArrow('a'), ArrowState.idle);
      expect(state.stateForArrow('b'), ArrowState.idle);
    });

    test('losing all lives triggers game over and blocks further taps', () async {
      var gameOver = false;
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl, onGameOver: () => gameOver = true);

      for (var i = 0; i < AppConstants.maxLives; i++) {
        state.tapArrow('a');
        // Wait for the shake timer to reset the arrow to idle before
        // attempting the next tap.
        if (i < AppConstants.maxLives - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      expect(gameOver, isTrue);
      expect(state.isGameOver, isTrue);
      expect(state.lives, 0);
      expect(state.tapArrow('a'), TapResult.ignored);
    });

    test('zen mode never loses lives', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl, gameMode: GameMode.zen);

      expect(state.tapArrow('a'), TapResult.blocked);
      expect(state.livesLost, 0);
      expect(state.isGameOver, isFalse);
    });

    test('heartRemover never loses lives', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl, heartRemover: true);

      expect(state.tapArrow('a'), TapResult.blocked);
      expect(state.livesLost, 0);
      expect(state.isGameOver, isFalse);
    });
  });

  group('restoreLife', () {
    test('restores a lost life and clears game over', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a');
      expect(state.lives, AppConstants.maxLives - 1);

      state.restoreLife();
      expect(state.lives, AppConstants.maxLives);
    });

    test('does not exceed max lives', () {
      final lvl = level();
      final state = buildState(lvl);

      state.restoreLife();
      state.restoreLife();
      expect(state.lives, AppConstants.maxLives);
    });
  });

  group('deadlock', () {
    test('detects deadlock when every arrow is blocked', () {
      // Two horizontal arrows facing each other, each blocking the other.
      final lvl = level(arrows: [
        arrow('a', [
          [2, 0]
        ], ArrowDirection.right),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.left),
      ]);
      final state = buildState(lvl);

      expect(state.checkDeadlock(), isTrue);
      expect(state.isArrowBlocked('a'), isTrue);
      expect(state.isArrowBlocked('b'), isTrue);
    });

    test('a free arrow means no deadlock', () {
      final lvl = level(arrows: [
        arrow('a', [
          [2, 0]
        ], ArrowDirection.right),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.left),
        // 'c' can still leave downwards.
        arrow('c', [
          [0, 4]
        ], ArrowDirection.down),
      ]);
      final state = buildState(lvl);

      expect(state.checkDeadlock(), isFalse);
    });
  });

  group('combo', () {
    test('rapid consecutive exits build a combo', () async {
      var combos = 0;
      final lvl = level(arrows: [
        arrow('a', [[0, 0]], ArrowDirection.up),
        arrow('b', [[0, 2]], ArrowDirection.up),
        arrow('c', [[0, 4]], ArrowDirection.up),
      ]);
      final state = buildState(lvl, onCombo: () => combos++);

      state.tapArrow('a');
      state.tapArrow('b');
      state.tapArrow('c');

      expect(state.comboCount, 3);
      expect(combos, 2); // fires from the 2nd consecutive exit on
    });
  });

  group('resetLevel', () {
    test('restores arrows, dots and lives', () async {
      final lvl = level(arrows: [
        arrow('a', [[0, 1]], ArrowDirection.right),
      ], orphanDots: [
        const OrphanDot(row: 0, col: 2, type: OrphanDotType.neutral),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a');
      expect(state.orphanDots.containsKey('0,2'), isFalse);

      state.resetLevel();

      expect(state.stateForArrow('a'), ArrowState.idle);
      expect(state.orphanDots.containsKey('0,2'), isTrue);
      expect(state.isComplete, isFalse);
      expect(state.isGameOver, isFalse);
      expect(state.lives, AppConstants.maxLives);
      expect(state.livesLost, 0);
    });
  });

  group('undo', () {
    test('undoes a wrong exit and restores arrows, dots and combo', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 1]], ArrowDirection.right),
        arrow('b', [[2, 4]], ArrowDirection.up),
      ], orphanDots: [
        const OrphanDot(row: 0, col: 2, type: OrphanDotType.neutral),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a'); // exit; consumes (0,2)
      state.handleArrowExitCompleted('a'); // simulate animation end
      expect(state.orphanDots.containsKey('0,2'), isFalse);

      expect(state.undo(), isTrue);
      expect(state.stateForArrow('a'), ArrowState.idle);
      expect(state.orphanDots.containsKey('0,2'), isTrue);
      expect(state.undosLeft, 0);
      expect(state.canUndo, isFalse);
    });

    test('arrows stuck as sliding in a snapshot are restored to idle', () {
      // Reproduces the "stuck arrow after undo" bug:
      // 1. Tap arrow 'a' — it starts sliding (animation in flight).
      // 2. Tap arrow 'b' before 'a' finishes — the snapshot captures 'a'
      //    as sliding.
      // 3. Both animations complete and both arrows leave the board.
      // 4. Undo — 'a' must come back as idle (movable), not sliding.
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.up),
        arrow('b', [[0, 4]], ArrowDirection.up),
        arrow('c', [[2, 2]], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a'); // sliding, animation in flight
      state.tapArrow('b'); // snapshot captures 'a' as sliding
      state.handleArrowExitCompleted('a');
      state.handleArrowExitCompleted('b');

      expect(state.undo(), isTrue);
      expect(state.stateForArrow('a'), ArrowState.idle);
      expect(state.stateForArrow('b'), ArrowState.idle);

      // Both arrows must be movable again.
      expect(state.tapArrow('a'), TapResult.exited);
      state.handleArrowExitCompleted('a');
      expect(state.tapArrow('b'), TapResult.exited);
    });

    test('undo restores a life lost by a blocked tap', () {      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a'); // blocked, -1 life
      expect(state.lives, AppConstants.maxLives - 1);

      expect(state.undo(), isTrue);
      expect(state.lives, AppConstants.maxLives);
      expect(state.livesLost, 0);
      expect(state.stateForArrow('a'), ArrowState.idle);
    });

    test('only one undo per level', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
        arrow('c', [[0, 0]], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('c');
      state.handleArrowExitCompleted('c');
      expect(state.undo(), isTrue);

      // No snapshot after the first undo until a new tap happens.
      expect(state.undo(), isFalse);

      state.tapArrow('c');
      state.handleArrowExitCompleted('c');
      expect(state.undo(), isFalse); // undos exhausted
    });

    test('undo is not possible mid-slide', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a'); // sliding
      expect(state.undo(), isFalse);
    });

    test('resetLevel restores the undo budget', () {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a');
      state.resetBlockStateForTest();
      expect(state.undo(), isTrue);
      expect(state.undosLeft, 0);

      state.resetLevel();
      expect(state.undosLeft, GameState.maxUndos);
    });
  });

  group('lifecycle', () {
    test('pending block-reset timer does not fire after dispose', () async {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a'); // schedules the reset timer
      state.dispose();

      await Future.delayed(const Duration(milliseconds: 500));
      // No exception should be thrown from the cancelled timer callback.
      expect(state.stateForArrow('a'), ArrowState.blocked);
    });

    test('resetLevel cancels the pending block-reset timer', () async {
      final lvl = level(arrows: [
        arrow('a', [[0, 2]], ArrowDirection.down),
        arrow('b', [
          [2, 2]
        ], ArrowDirection.up),
      ]);
      final state = buildState(lvl);

      state.tapArrow('a'); // schedules the reset timer
      state.resetLevel(); // cancels it

      await Future.delayed(const Duration(milliseconds: 500));
      expect(state.stateForArrow('a'), ArrowState.idle);
    });
  });
}
