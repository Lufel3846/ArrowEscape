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
    // Sample the whole difficulty range: normals, bosses (multiples of 5),
    // gods (multiples of 10) and the special-case levels 213/395/437.
    const levels = [
      1, 2, 3, 5, 7, 10, 14, 15, 20, 25, 30, 37, 50, 75, 100, 120, 150,
      200, 213, 250, 300, 350, 395, 437, 450, 500,
    ];
    for (final levelNumber in levels) {
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

  test('levels above 500 (random/expert range) are solvable', () {
    for (final levelNumber in [505, 550, 600, 700]) {
      final level = LevelGenerator.generateLevel(levelNumber);
      expect(
        LevelSolver.solve(level, 2000),
        isNotNull,
        reason: 'level $levelNumber is not solvable',
      );
    }
  });

  test('different levels produce different boards', () {
    final a = LevelGenerator.generateLevel(1);
    final b = LevelGenerator.generateLevel(2);
    expect(a.toJson(), isNot(equals(b.toJson())));
  });
}
