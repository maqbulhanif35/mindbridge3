import 'package:equatable/equatable.dart';

/// Types of streaks tracked in MindBridge.
enum StreakType {
  moodLogging,
  journalWriting,
  mindfulness,
  chatSession,
  overall, // composite streak (any daily action)
}

extension StreakTypeExtension on StreakType {
  String get displayName => switch (this) {
        StreakType.moodLogging => 'Mood Check-ins',
        StreakType.journalWriting => 'Journaling',
        StreakType.mindfulness => 'Mindfulness',
        StreakType.chatSession => 'Maya Chats',
        StreakType.overall => 'Daily Wellness',
      };

  String get emoji => switch (this) {
        StreakType.moodLogging => '😊',
        StreakType.journalWriting => '📖',
        StreakType.mindfulness => '🧘',
        StreakType.chatSession => '💬',
        StreakType.overall => '🔥',
      };

  String get toJson => switch (this) {
        StreakType.moodLogging => 'mood_logging',
        StreakType.journalWriting => 'journal_writing',
        StreakType.mindfulness => 'mindfulness',
        StreakType.chatSession => 'chat_session',
        StreakType.overall => 'overall',
      };

  static StreakType fromJson(String value) => switch (value) {
        'mood_logging' => StreakType.moodLogging,
        'journal_writing' => StreakType.journalWriting,
        'mindfulness' => StreakType.mindfulness,
        'chat_session' => StreakType.chatSession,
        _ => StreakType.overall,
      };
}

/// Represents a user's streak for a specific activity type.
class StreakModel extends Equatable {
  final String id;
  final String userId;
  final StreakType type;
  final int currentStreak;
  final int longestStreak;
  final int totalDays;
  final DateTime? lastActivityDate;
  final int freezesUsed;
  final int freezesAvailable;
  final DateTime updatedAt;

  const StreakModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDays,
    this.lastActivityDate,
    this.freezesUsed = 0,
    this.freezesAvailable = 1,
    required this.updatedAt,
  });

  bool get isActive {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      lastActivityDate!.year,
      lastActivityDate!.month,
      lastActivityDate!.day,
    );
    return today.difference(lastDay).inDays <= 1;
  }

  bool get completedToday {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      lastActivityDate!.year,
      lastActivityDate!.month,
      lastActivityDate!.day,
    );
    return today == lastDay;
  }

  bool get isOnFire => currentStreak >= 7;
  bool get isLegendary => currentStreak >= 30;

  /// Next milestone streak target.
  int get nextMilestone {
    const milestones = [3, 7, 14, 30, 60, 90, 180, 365];
    for (final m in milestones) {
      if (currentStreak < m) return m;
    }
    return ((currentStreak ~/ 100) + 1) * 100;
  }

  double get milestoneProgress {
    const milestones = [3, 7, 14, 30, 60, 90, 180, 365];
    int prevMilestone = 0;
    for (final m in milestones) {
      if (currentStreak < m) {
        return (currentStreak - prevMilestone) / (m - prevMilestone);
      }
      prevMilestone = m;
    }
    return 1.0;
  }

  factory StreakModel.fromMap(Map<String, dynamic> map) => StreakModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        type: StreakTypeExtension.fromJson(map['streak_type'] as String),
        currentStreak: map['current_streak'] as int? ?? 0,
        longestStreak: map['longest_streak'] as int? ?? 0,
        totalDays: map['total_days'] as int? ?? 0,
        lastActivityDate: map['last_activity_date'] != null
            ? DateTime.parse(map['last_activity_date'] as String)
            : null,
        freezesUsed: map['freezes_used'] as int? ?? 0,
        freezesAvailable: map['freezes_available'] as int? ?? 1,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'streak_type': type.toJson,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'total_days': totalDays,
        'last_activity_date': lastActivityDate?.toIso8601String(),
        'freezes_used': freezesUsed,
        'freezes_available': freezesAvailable,
        'updated_at': updatedAt.toIso8601String(),
      };

  StreakModel copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalDays,
    DateTime? lastActivityDate,
    int? freezesUsed,
    int? freezesAvailable,
    DateTime? updatedAt,
  }) =>
      StreakModel(
        id: id,
        userId: userId,
        type: type,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        totalDays: totalDays ?? this.totalDays,
        lastActivityDate: lastActivityDate ?? this.lastActivityDate,
        freezesUsed: freezesUsed ?? this.freezesUsed,
        freezesAvailable: freezesAvailable ?? this.freezesAvailable,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id, userId, type, currentStreak, longestStreak,
        totalDays, lastActivityDate, freezesUsed, freezesAvailable,
      ];
}
