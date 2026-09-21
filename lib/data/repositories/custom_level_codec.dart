import 'dart:convert';

import '../models/level.dart';
import '../level_generator/solver.dart';

const String kCustomLevelCodePrefix = 'ARW-';

/// Encodes/decodes custom levels to compact share codes
/// ("ARW-" + base64 of the level JSON).
class CustomLevelCodec {
  CustomLevelCodec._();

  /// Returns null if the level is not shareable (empty or unsolvable).
  static String? encode(LevelModel level, {int solverLimit = 50000}) {
    if (level.arrows.isEmpty) return null;
    if (LevelSolver.solve(level, solverLimit) == null) return null;
    final json = jsonEncode(level.toJson());
    return '$kCustomLevelCodePrefix${base64Url.encode(utf8.encode(json))}';
  }

  /// Returns the decoded level or null if the code is invalid/unsolvable.
  static LevelModel? decode(String raw, {int solverLimit = 50000}) {
    final code = raw.trim();
    if (!code.startsWith(kCustomLevelCodePrefix)) return null;
    try {
      final bytes =
          base64Url.decode(code.substring(kCustomLevelCodePrefix.length));
      final level =
          LevelModel.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      if (level.gridSize < 4 || level.gridSize > 12) return null;
      if (level.arrows.isEmpty) return null;
      if (LevelSolver.solve(level, solverLimit) == null) return null;
      return level;
    } catch (_) {
      return null;
    }
  }
}
