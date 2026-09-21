import '../data/models/arrow.dart';
import '../data/models/level.dart';

/// Result of simulating an arrow's exit path across the board.
class ExitSimulation {
  /// Whether the arrow cannot leave the board (hit another arrow or a cycle).
  final bool blocked;

  /// Keys ("r,c") of orphan dots consumed along the way.
  final List<String> consumedDotKeys;

  const ExitSimulation(this.blocked, [this.consumedDotKeys = const []]);
}

/// Single source of truth for the "walk an arrow off the board" simulation.
///
/// The arrow walks from its head in its current direction. When it passes
/// over an orphan dot of a directional type, its direction is redirected.
/// It is blocked when it hits a cell occupied by another arrow (see
/// [blockedCells]) or when it enters a cycle. Neutral dots are simply
/// consumed without redirecting.
///
/// IMPORTANT: gameplay ([GameState]), the solver ([LevelSolver]) and the
/// rendering/preview logic must all agree with this simulation. If you
/// change the rules here, update those call sites accordingly.
class PathSimulation {
  PathSimulation._();

  static ExitSimulation simulateExit({
    required ArrowModel arrow,
    required int gridSize,
    required Set<String> blockedCells,
    required Map<String, OrphanDotType> orphanDots,
  }) {
    ArrowDirection currentDir = arrow.direction;
    final head = arrow.path[0];
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final consumed = <String>[];
    final visited = <String>{};

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) return const ExitSimulation(true);
      visited.add(key);

      final dotType = orphanDots[key];
      if (dotType != null) {
        consumed.add(key);
        switch (dotType) {
          case OrphanDotType.up:
            currentDir = ArrowDirection.up;
          case OrphanDotType.down:
            currentDir = ArrowDirection.down;
          case OrphanDotType.left:
            currentDir = ArrowDirection.left;
          case OrphanDotType.right:
            currentDir = ArrowDirection.right;
          case OrphanDotType.neutral:
            break;
        }
      } else if (blockedCells.contains(key)) {
        return ExitSimulation(true, consumed);
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return ExitSimulation(false, consumed);
  }
}
