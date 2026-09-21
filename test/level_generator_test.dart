import 'package:flutter_test/flutter_test.dart';

import 'package:arrowescape/data/level_generator/level_generator.dart';
import 'package:arrowescape/data/level_generator/solver.dart';

void main() {
  test('level generation is deterministic for the same level', () {
    final first = LevelGenerator.generateLevel(37);
    final second = LevelGenerator.generateLevel(37);

    expect(first.toJson(), equals(second.toJson()));
  });

  test('representative generated levels are solvable', () {
    for (final levelNumber in [1, 5, 10, 25, 50, 100]) {
      final level = LevelGenerator.generateLevel(levelNumber);
      expect(
        level.arrows,
        isNotEmpty,
        reason: 'level $levelNumber has no arrows',
      );
      expect(
        LevelSolver.solve(level, 2000),
        isNotNull,
        reason: 'level $levelNumber is not solvable',
      );
    }
  });
}
