import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/streak_model.dart';
import '../models/achievement_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

// ─── State ────────────────────────────────────────────────

class StreakAchievementState {
  final Map<StreakType, StreakModel> streaks;
  final List<UserAchievement> achievements;
  final UserAchievement? justUnlocked; // for celebration overlay
  final bool isLoading;

  const StreakAchievementState({
    this.streaks = const {},
    this.achievements = const [],
    this.justUnlocked,
    this.isLoading = false,
  });

  StreakModel? streak(StreakType type) => streaks[type];
  StreakModel? get overall => streaks[StreakType.overall];
  int get totalXp =>
      achievements.fold(0, (sum, a) => sum + (a.definition?.xp ?? 0));
  int get unseenCount =>
      achievements.where((a) => !a.isSeen).length;

  StreakAchievementState copyWith({
    Map<StreakType, StreakModel>? streaks,
    List<UserAchievement>? achievements,
    UserAchievement? justUnlocked,
    bool clearJustUnlocked = false,
    bool? isLoading,
  }) =>
      StreakAchievementState(
        streaks: streaks ?? this.streaks,
        achievements: achievements ?? this.achievements,
        justUnlocked: clearJustUnlocked ? null : justUnlocked ?? this.justUnlocked,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ─── Notifier ─────────────────────────────────────────────

class StreakAchievementNotifier
    extends StateNotifier<StreakAchievementState> {
  static const _uuid = Uuid();
  final SupabaseClient _client = Supabase.instance.client;

  StreakAchievementNotifier() : super(const StreakAchievementState()) {
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([_loadStreaks(userId), _loadAchievements(userId)]);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadStreaks(String userId) async {
    try {
      final rows = await _client
          .from('user_streaks')
          .select()
          .eq('user_id', userId);
      final map = <StreakType, StreakModel>{};
      for (final row in rows as List) {
        final m = StreakModel.fromMap(row as Map<String, dynamic>);
        map[m.type] = m;
      }
      state = state.copyWith(streaks: map);
    } catch (_) {}
  }

  Future<void> _loadAchievements(String userId) async {
    try {
      final rows = await _client
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .order('unlocked_at', ascending: false);
      final list = (rows as List)
          .map((r) => UserAchievement.fromMap(r as Map<String, dynamic>))
          .toList();
      state = state.copyWith(achievements: list);
    } catch (_) {}
  }

  /// Record an activity and update streak + check achievements.
  Future<void> recordActivity(StreakType type) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final existing = state.streak(type);

      int newCurrent;
      int newLongest;
      int newTotal;

      if (existing == null) {
        // First ever activity
        newCurrent = 1;
        newLongest = 1;
        newTotal = 1;
      } else if (existing.completedToday) {
        return; // Already recorded today
      } else if (existing.isActive) {
        // Continuing streak
        newCurrent = existing.currentStreak + 1;
        newLongest = newCurrent > existing.longestStreak
            ? newCurrent
            : existing.longestStreak;
        newTotal = existing.totalDays + 1;
      } else {
        // Broken streak — reset
        newCurrent = 1;
        newLongest = existing.longestStreak;
        newTotal = existing.totalDays + 1;
      }

      final updatedStreak = StreakModel(
        id: existing?.id ?? _uuid.v4(),
        userId: userId,
        type: type,
        currentStreak: newCurrent,
        longestStreak: newLongest,
        totalDays: newTotal,
        lastActivityDate: now,
        freezesAvailable: existing?.freezesAvailable ?? 1,
        freezesUsed: existing?.freezesUsed ?? 0,
        updatedAt: now,
      );

      // Persist
      await _client.from('user_streaks').upsert(updatedStreak.toMap());

      final newStreaks = Map<StreakType, StreakModel>.from(state.streaks)
        ..[type] = updatedStreak;
      state = state.copyWith(streaks: newStreaks);

      // Also update overall streak
      await recordActivity(StreakType.overall);

      // Check milestone notifications
      const milestones = [3, 7, 14, 30, 60, 90];
      if (milestones.contains(newCurrent) && type == StreakType.moodLogging) {
        NotificationService().notifyStreakMilestone(newCurrent);
      }

      // Check achievements
      await _checkAndUnlockAchievements(userId, type, newCurrent, newTotal);
    } catch (_) {}
  }

  Future<void> _checkAndUnlockAchievements(
    String userId,
    StreakType type,
    int currentStreak,
    int totalDays,
  ) async {
    final unlocked = state.achievements.map((a) => a.achievementId).toSet();
    final toUnlock = <String>[];

    // Streak-based achievements
    if (type == StreakType.moodLogging) {
      if (totalDays == 1 && !unlocked.contains('first_checkin')) {
        toUnlock.add('first_checkin');
      }
      if (currentStreak >= 3 && !unlocked.contains('streak_3')) {
        toUnlock.add('streak_3');
      }
      if (currentStreak >= 7 && !unlocked.contains('streak_7')) {
        toUnlock.add('streak_7');
      }
      if (currentStreak >= 14 && !unlocked.contains('streak_14')) {
        toUnlock.add('streak_14');
      }
      if (currentStreak >= 30 && !unlocked.contains('streak_30')) {
        toUnlock.add('streak_30');
      }
      if (currentStreak >= 90 && !unlocked.contains('streak_90')) {
        toUnlock.add('streak_90');
      }
    }

    if (type == StreakType.journalWriting) {
      if (totalDays == 1 && !unlocked.contains('first_journal')) {
        toUnlock.add('first_journal');
      }
      if (totalDays >= 10 && !unlocked.contains('journal_10')) {
        toUnlock.add('journal_10');
      }
    }

    if (type == StreakType.mindfulness) {
      if (totalDays >= 5 && !unlocked.contains('breathing_5')) {
        toUnlock.add('breathing_5');
      }
      if (totalDays >= 50 && !unlocked.contains('breathing_50')) {
        toUnlock.add('breathing_50');
      }
    }

    if (toUnlock.isEmpty) return;

    for (final achievementId in toUnlock) {
      final achievement = UserAchievement(
        id: _uuid.v4(),
        userId: userId,
        achievementId: achievementId,
        unlockedAt: DateTime.now(),
        isSeen: false,
      );

      try {
        await _client
            .from('user_achievements')
            .insert(achievement.toMap());

        final definition = AchievementDefinition.findById(achievementId);
        if (definition != null) {
          NotificationService().notifyAchievementUnlocked(
            definition.title,
            definition.emoji,
          );
        }

        state = state.copyWith(
          achievements: [achievement, ...state.achievements],
          justUnlocked: achievement,
        );
      } catch (_) {}
    }
  }

  void dismissUnlockCelebration() {
    state = state.copyWith(clearJustUnlocked: true);
  }

  Future<void> markAllSeen() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('user_achievements')
          .update({'is_seen': true})
          .eq('user_id', userId)
          .eq('is_seen', false);
      state = state.copyWith(
        achievements:
            state.achievements.map((a) => a.copyWith(isSeen: true)).toList(),
      );
    } catch (_) {}
  }

  Future<void> refresh() => _load();
}

// ─── Provider ─────────────────────────────────────────────

final streakProvider =
    StateNotifierProvider<StreakAchievementNotifier, StreakAchievementState>(
  (ref) => StreakAchievementNotifier(),
);
