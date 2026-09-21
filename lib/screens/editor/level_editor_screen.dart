import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/app_themes.dart';
import '../../core/audio_haptic_helper.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../../data/repositories/custom_level_codec.dart';
import '../../data/level_generator/solver.dart';
import '../../main.dart';
import '../game/game_screen.dart';

/// Builds custom 1-cell-arrow puzzles on a small grid, validates them with
/// the solver, and shares them as compact codes.
class LevelEditorScreen extends ConsumerStatefulWidget {
  const LevelEditorScreen({super.key});

  @override
  ConsumerState<LevelEditorScreen> createState() => _LevelEditorScreenState();
}

class _LevelEditorScreenState extends ConsumerState<LevelEditorScreen> {
  int _gridSize = 7;
  ArrowDirection _selectedDirection = ArrowDirection.right;
  final List<ArrowModel> _arrows = [];
  int _nextArrowId = 1;

  // --- editing --------------------------------------------------------------

  void _onCellTap(int row, int col) {
    AudioHapticHelper.playClick();
    setState(() {
      final existingIndex =
          _arrows.indexWhere((a) => a.row == row && a.col == col);
      if (existingIndex == -1) {
        _arrows.add(ArrowModel(
          id: 'a${_nextArrowId++}',
          row: row,
          col: col,
          direction: _selectedDirection,
        ));
      } else {
        // Rotate the existing arrow clockwise.
        final existing = _arrows[existingIndex];
        _arrows[existingIndex] =
            existing.copyWith(direction: existing.direction.turnRight);
      }
    });
  }

  void _onCellLongPress(int row, int col) {
    final existingIndex =
        _arrows.indexWhere((a) => a.row == row && a.col == col);
    if (existingIndex == -1) return;
    AudioHapticHelper.playClick();
    setState(() => _arrows.removeAt(existingIndex));
  }

  void _clearAll() {
    AudioHapticHelper.playClick();
    setState(() => _arrows.clear());
  }

  // --- level build / validation / share ------------------------------------

  LevelModel _buildLevel() => LevelModel(
        levelNumber: 1, // 'normal' type — safe defaults for rendering
        gridSize: _gridSize,
        arrows: List.of(_arrows),
      );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _testLevel() {
    if (_arrows.isEmpty) {
      _showMessage('Place at least one arrow first.');
      return;
    }
    final level = _buildLevel();
    final solution = LevelSolver.solve(level, 50000);
    if (solution == null) {
      _showMessage('This puzzle has no solution yet. Adjust the arrows.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(level: 1, customLevel: level),
      ),
    );
  }

  Future<void> _shareLevel() async {
    if (_arrows.isEmpty) {
      _showMessage('Place at least one arrow first.');
      return;
    }
    final level = _buildLevel();
    final code = CustomLevelCodec.encode(level);
    if (code == null) {
      _showMessage('This puzzle has no solution yet. Adjust the arrows.');
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Share Code',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send this code to a friend. They can paste it in the editor to play your puzzle.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                code,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              _showMessage('Code copied to clipboard!');
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _loadCode() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Load Code',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '$kCustomLevelCodePrefix...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final error = _applyCode(controller.text);
              Navigator.pop(ctx);
              if (error != null) {
                _showMessage(error);
              } else {
                _showMessage('Puzzle loaded!');
              }
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  /// Returns null on success or an error message.
  String? _applyCode(String raw) {
    final level = CustomLevelCodec.decode(raw);
    if (level == null) return 'Could not read this code.';
    setState(() {
      _gridSize = level.gridSize;
      _arrows
        ..clear()
        ..addAll(level.arrows);
      _nextArrowId = _arrows.length + 1;
    });
    return null;
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressRepositoryProvider);
    final themeColors = AppThemes.getThemeColors(progress.selectedTheme);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: themeColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_back,
                            color: AppColors.textPrimary, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Level Editor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Tap an empty cell to place an arrow, tap an arrow to rotate it, long-press to remove.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final dir in ArrowDirection.values) ...[
                    _DirectionChip(
                      direction: dir,
                      selected: dir == _selectedDirection,
                      accent: themeColors.accentColor,
                      onTap: () => setState(() => _selectedDirection = dir),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Grid',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Slider(
                    value: _gridSize.toDouble(),
                    min: 5,
                    max: 10,
                    divisions: 5,
                    label: '$_gridSize x $_gridSize',
                    activeColor: themeColors.accentColor,
                    onChanged: (value) {
                      final newSize = value.round();
                      setState(() {
                        _gridSize = newSize;
                        _arrows.removeWhere(
                            (a) => a.row >= newSize || a.col >= newSize);
                      });
                    },
                  ),
                  Text('$_gridSize x $_gridSize',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridSize,
                      ),
                      itemCount: _gridSize * _gridSize,
                      itemBuilder: (context, index) {
                        final row = index ~/ _gridSize;
                        final col = index % _gridSize;
                        ArrowModel? arrow;
                        for (final a in _arrows) {
                          if (a.row == row && a.col == col) {
                            arrow = a;
                            break;
                          }
                        }
                        return _EditorCell(
                          arrow: arrow,
                          accent: themeColors.accentColor,
                          onTap: () => _onCellTap(row, col),
                          onLongPress: () => _onCellLongPress(row, col),
                        );
                      },
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _EditorAction(
                      icon: Icons.delete_outline,
                      label: 'Clear',
                      onTap: _clearAll,
                    ),
                    const SizedBox(width: 10),
                    _EditorAction(
                      icon: Icons.download_rounded,
                      label: 'Load Code',
                      onTap: _loadCode,
                    ),
                    const SizedBox(width: 10),
                    _EditorAction(
                      icon: Icons.ios_share_rounded,
                      label: 'Share',
                      onTap: _shareLevel,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _EditorAction(
                        icon: Icons.play_arrow_rounded,
                        label: 'Test',
                        highlighted: true,
                        accent: themeColors.accentColor,
                        onTap: _testLevel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForDirection(ArrowDirection dir) {
  switch (dir) {
    case ArrowDirection.up:
      return Icons.arrow_upward_rounded;
    case ArrowDirection.down:
      return Icons.arrow_downward_rounded;
    case ArrowDirection.left:
      return Icons.arrow_back_rounded;
    case ArrowDirection.right:
      return Icons.arrow_forward_rounded;
  }
}

class _DirectionChip extends StatelessWidget {
  final ArrowDirection direction;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _DirectionChip({
    required this.direction,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Icon(
          _iconForDirection(direction),
          color: selected ? accent : AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}

class _EditorCell extends StatelessWidget {
  final ArrowModel? arrow;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EditorCell({
    required this.arrow,
    required this.accent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: arrow != null ? onLongPress : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: arrow != null
              ? accent.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: arrow != null
                ? accent.withValues(alpha: 0.6)
                : Colors.white10,
            width: 1,
          ),
        ),
        child: arrow != null
            ? Icon(
                _iconForDirection(arrow!.direction),
                color: accent,
                size: 20,
              )
            : null,
      ),
    );
  }
}

class _EditorAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final Color? accent;

  const _EditorAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioHapticHelper.playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                highlighted ? (accent ?? AppColors.primary) : Colors.white24,
            width: 1.5,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: highlighted
                    ? (accent ?? AppColors.primary)
                    : AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: highlighted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
