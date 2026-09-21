import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_colors.dart';
import '../../core/app_themes.dart';
import '../../data/repositories/stats_repository.dart';
import '../../main.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsRepositoryProvider);
    final progress = ref.watch(progressRepositoryProvider);
    final themeColors = AppThemes.getThemeColors(progress.selectedTheme);

    final unlockedCount = StatsRepository.achievements
        .where((a) => stats.isUnlocked(a.id))
        .length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: themeColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      'Achievements',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$unlockedCount/${StatsRepository.achievements.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: themeColors.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: StatsRepository.achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = StatsRepository.achievements[index];
                    final isUnlocked = stats.isUnlocked(achievement.id);
                    return _AchievementCard(
                      achievement: achievement,
                      isUnlocked: isUnlocked,
                      themeColors: themeColors,
                      index: index,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final ThemeColors themeColors;
  final int index;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    required this.themeColors,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isUnlocked ? themeColors.accentColor : AppColors.textMuted;
    final titleColor =
        isUnlocked ? AppColors.textPrimary : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: isUnlocked ? 0.95 : 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? themeColors.accentColor.withValues(alpha: 0.5)
              : Colors.white10,
          width: 1.5,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: themeColors.accentColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? themeColors.accentColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: isUnlocked
                ? Icon(achievement.icon, color: iconColor, size: 24)
                : Icon(Icons.lock_outline, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            Icon(Icons.check_circle_rounded,
                color: themeColors.accentColor, size: 22),
        ],
      ),
    ).animate(delay: (index * 40).ms).fadeIn(duration: 250.ms).slideX(
          begin: 0.08,
          end: 0,
          duration: 250.ms,
          curve: Curves.easeOutQuad,
        );
  }
}
