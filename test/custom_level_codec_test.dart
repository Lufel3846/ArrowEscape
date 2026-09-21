import 'package:flutter_test/flutter_test.dart';

import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/data/level_generator/solver.dart';
import 'package:arrowescape/data/repositories/custom_level_codec.dart';

LevelModel _solvableLevel() => LevelModel(
      levelNumber: 1,
      gridSize: 5,
      arrows: [
        ArrowModel(id: 'a', row: 0, col: 0, direction: ArrowDirection.up),
        ArrowModel(id: 'b', row: 0, col: 2, direction: ArrowDirection.left),
      ],
    );

void main() {
  test('encode/decode round-trip preserves the level', () {
    final level = _solvableLevel();

    final code = CustomLevelCodec.encode(level);
    expect(code, isNotNull);
    expect(code!.startsWith('ARW-'), isTrue);

    final decoded = CustomLevelCodec.decode(code);
    expect(decoded, isNotNull);
    expect(decoded!.gridSize, level.gridSize);
    expect(decoded.arrows.length, level.arrows.length);
    expect(
      {for (final a in decoded.arrows) a.id: [a.row, a.col, a.direction]},
      {for (final a in level.arrows) a.id: [a.row, a.col, a.direction]},
    );
  });

  test('rejects unsolvable levels', () {
    // Two horizontal arrows facing each other block each other forever.
    final level = LevelModel(
      levelNumber: 1,
      gridSize: 5,
      arrows: [
        ArrowModel(
            id: 'a', row: 2, col: 0, direction: ArrowDirection.right),
        ArrowModel(
            id: 'b', row: 2, col: 2, direction: ArrowDirection.left),
      ],
    );
    expect(CustomLevelCodec.encode(level), isNull);
  });

  test('rejects invalid codes', () {
    expect(CustomLevelCodec.decode(''), isNull);
    expect(CustomLevelCodec.decode('not-a-code'), isNull);
    expect(CustomLevelCodec.decode('ARW-!!!invalid-base64!!!'), isNull);
  });

  test('encoded code passes the solver after decoding', () {
    final code = CustomLevelCodec.encode(_solvableLevel())!;
    final decoded = CustomLevelCodec.decode(code)!;
    expect(LevelSolver.solve(decoded), isNotNull);
  });
}
