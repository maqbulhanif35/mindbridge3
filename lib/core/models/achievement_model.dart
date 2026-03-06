import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Categories of achievements in MindBridge.
enum AchievementCategory {
  consistency,
  wellness,
  selfCare,
  community,
  growth,
  special,
}

extension AchievementCategoryExt on AchievementCategory {
  String get displayName => switch (this) {
        AchievementCategory.consistency => 'Consistency',
        AchievementCategory.wellness => 'Wellness',
        AchievementCategory.selfCare => 'Self-Care',
        AchievementCategory.community => 'Community',
        AchievementCategory.growth => 'Growth',
        AchievementCategory.special => 'Special',
      };

  Color get color => switch (this) {
        AchievementCategory.consistency => AppColors.primary,
        AchievementCategory.wellness => AppColors.success,
        AchievementCategory.selfCare => AppColors.tertiary,
        AchievementCategory.community => AppColors.secondary,
        AchievementCategory.growth => AppColors.warning,
        AchievementCategory.special => const Color(0xFFFFD700),
      };
}

/// Rarity tier of an achievement.
enum AchievementRarity { common, uncommon, rare, epic, legendary }

extension AchievementRarityExt on AchievementRarity {
  String get displayName => switch (this) {
        AchievementRarity.common => 'Common',
        AchievementRarity.uncommon => 'Uncommon',
        AchievementRarity.rare => 'Rare',
        AchievementRarity.epic => 'Epic',
        AchievementRarity.legendary => 'Legendary',
      };

  Color get color => switch (this) {
        AchievementRarity.common => Colors.grey,
        AchievementRarity.uncommon => const Color(0xFF4CAF50),
        AchievementRarity.rare => const Color(0xFF2196F3),
        AchievementRarity.epic => const Color(0xFF9C27B0),
        AchievementRarity.legendary => const Color(0xFFFFD700),
      };

  int get xpReward => switch (this) {
        AchievementRarity.common => 10,
        AchievementRarity.uncommon => 25,
        AchievementRarity.rare => 50,
        AchievementRarity.epic => 100,
        AchievementRarity.legendary => 250,
      };
}

/// Static definition of an achievement (the blueprint).
class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final int xp;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.category,
    required this.rarity,
    int? xp,
  }) : xp = xp ?? 0; // computed in init if not provided

  static const all = <AchievementDefinition>[
    // ── Consistency ──────────────────────────────────
    AchievementDefinition(
      id: 'first_checkin',
      title: 'First Step',
      description: 'Log your first mood check-in',
      emoji: '🌱',
      category: AchievementCategory.consistency,
      rarity: AchievementRarity.common,
      xp: 10,
    ),
    AchievementDefinition(
      id: 'streak_3',
      title: 'Getting Started',
      description: '3-day mood logging streak',
      emoji: '🔥',
      category: AchievementCategory.consistency,
      rarity: AchievementRarity.common,
      xp: 25,
    ),
    AchievementDefinition(
      id: 'streak_7',
      title: 'Week Warrior',
      description: '7-day streak — a full week!',
      emoji: '🏆',
      category: AchievementCategory.consistency,
      rarity: AchievementRarity.uncommon,
      xp: 50,
    ),
    AchievementDefinition(
      id: 'streak_14',
      title: 'Fortnight Focus',
      description: '14-day streak — two weeks strong',
      emoji: '💪',
      category: AchievementCategory.consistency,
      rarity: AchievementRarity.rare,
      xp: 100,
    ),
    AchievementDefinition(
      id: 'streak_30',
      title: 'Monthly Maven',
      description: '30-day streak — a full month!',
      emoji: '🌟',
      category: AchievementCategory.consistency,
      rarity: AchievementRarity.epic,
      xp: 200,
    ),
    AchievementDefinition(
      id: 'streak_90',
      title: 'Quarterly Champion',
      description: '90-day streak — incredible dedication',
      emoji: '👑',
      category: AchievementCategory.consistency,
      rarity: AchievementRarity.legendary,
      xp: 500,
    ),

    // ── Wellness ──────────────────────────────────────
    AchievementDefinition(
      id: 'mood_improvement_week',
      title: 'Looking Up',
      description: 'Improve your average mood week over week',
      emoji: '📈',
      category: AchievementCategory.wellness,
      rarity: AchievementRarity.uncommon,
      xp: 30,
    ),
    AchievementDefinition(
      id: 'thriving_score',
      title: 'Thriving',
      description: 'Achieve a wellness score of 80+',
      emoji: '✨',
      category: AchievementCategory.wellness,
      rarity: AchievementRarity.rare,
      xp: 75,
    ),
    AchievementDefinition(
      id: 'perfect_sleep_week',
      title: 'Dream Week',
      description: 'Log 7–9 hours of sleep every day for a week',
      emoji: '😴',
      category: AchievementCategory.wellness,
      rarity: AchievementRarity.rare,
      xp: 60,
    ),

    // ── Self-Care ─────────────────────────────────────
    AchievementDefinition(
      id: 'first_journal',
      title: 'Inner Voice',
      description: 'Write your first journal entry',
      emoji: '📖',
      category: AchievementCategory.selfCare,
      rarity: AchievementRarity.common,
      xp: 10,
    ),
    AchievementDefinition(
      id: 'journal_10',
      title: 'Storyteller',
      description: 'Write 10 journal entries',
      emoji: '✍️',
      category: AchievementCategory.selfCare,
      rarity: AchievementRarity.uncommon,
      xp: 40,
    ),
    AchievementDefinition(
      id: 'breathing_5',
      title: 'Breath of Fresh Air',
      description: 'Complete 5 breathing exercises',
      emoji: '🌬️',
      category: AchievementCategory.selfCare,
      rarity: AchievementRarity.common,
      xp: 20,
    ),
    AchievementDefinition(
      id: 'breathing_50',
      title: 'Zen Master',
      description: 'Complete 50 breathing exercises',
      emoji: '🧘',
      category: AchievementCategory.selfCare,
      rarity: AchievementRarity.epic,
      xp: 150,
    ),

    // ── Growth ────────────────────────────────────────
    AchievementDefinition(
      id: 'all_features',
      title: 'Explorer',
      description: 'Use every feature in MindBridge',
      emoji: '🗺️',
      category: AchievementCategory.growth,
      rarity: AchievementRarity.rare,
      xp: 80,
    ),
    AchievementDefinition(
      id: 'challenges_5',
      title: 'Challenge Accepted',
      description: 'Complete 5 wellness challenges',
      emoji: '🎯',
      category: AchievementCategory.growth,
      rarity: AchievementRarity.uncommon,
      xp: 35,
    ),
    AchievementDefinition(
      id: 'insight_unlocked',
      title: 'Pattern Seeker',
      description: 'Receive your first AI wellness insight',
      emoji: '💡',
      category: AchievementCategory.growth,
      rarity: AchievementRarity.common,
      xp: 15,
    ),

    // ── Community ─────────────────────────────────────
    AchievementDefinition(
      id: 'first_community_post',
      title: 'Speak Up',
      description: 'Share your first post in the community',
      emoji: '🗣️',
      category: AchievementCategory.community,
      rarity: AchievementRarity.common,
      xp: 20,
    ),

    // ── Special ───────────────────────────────────────
    AchievementDefinition(
      id: 'crisis_survivor',
      title: 'Resilient',
      description: 'Reached out for support when you needed it most',
      emoji: '💙',
      category: AchievementCategory.special,
      rarity: AchievementRarity.legendary,
      xp: 50,
    ),
  ];

  static AchievementDefinition? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// A user's earned achievement instance.
class UserAchievement extends Equatable {
  final String id;
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;
  final bool isSeen;

  const UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
    this.isSeen = false,
  });

  AchievementDefinition? get definition =>
      AchievementDefinition.findById(achievementId);

  factory UserAchievement.fromMap(Map<String, dynamic> map) => UserAchievement(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        achievementId: map['achievement_id'] as String,
        unlockedAt: DateTime.parse(map['unlocked_at'] as String),
        isSeen: map['is_seen'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': unlockedAt.toIso8601String(),
        'is_seen': isSeen,
      };

  UserAchievement copyWith({bool? isSeen}) => UserAchievement(
        id: id,
        userId: userId,
        achievementId: achievementId,
        unlockedAt: unlockedAt,
        isSeen: isSeen ?? this.isSeen,
      );

  @override
  List<Object?> get props => [id, userId, achievementId, unlockedAt, isSeen];
}
