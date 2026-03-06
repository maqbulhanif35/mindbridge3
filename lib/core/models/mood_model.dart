import 'package:equatable/equatable.dart';

class MoodEntry extends Equatable {
  final String id;
  final String userId;
  final int moodScore; // 1-10
  final List<String> emotions;
  final List<String> activities;
  final String? note;
  final double? sleepHours;
  final DateTime createdAt;

  const MoodEntry({
    required this.id,
    required this.userId,
    required this.moodScore,
    this.emotions = const [],
    this.activities = const [],
    this.note,
    this.sleepHours,
    required this.createdAt,
  });

  String get moodLabel {
    const labels = [
      '',
      'Terrible',
      'Very Bad',
      'Bad',
      'Poor',
      'Neutral',
      'Okay',
      'Good',
      'Great',
      'Excellent',
      'Amazing'
    ];
    return moodScore >= 1 && moodScore <= 10 ? labels[moodScore] : 'Unknown';
  }

  String get moodEmoji {
    const emojis = ['', '😭', '😢', '😞', '😟', '😐', '🙂', '😊', '😄', '😁', '🤩'];
    return moodScore >= 1 && moodScore <= 10 ? emojis[moodScore] : '😐';
  }

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        moodScore: json['mood_score'] as int,
        emotions: (json['emotions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        activities: (json['activities'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        note: json['note'] as String?,
        sleepHours: json['sleep_hours'] != null
            ? (json['sleep_hours'] as num).toDouble()
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'mood_score': moodScore,
        'emotions': emotions,
        'activities': activities,
        'note': note,
        'sleep_hours': sleepHours,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        moodScore,
        emotions,
        activities,
        note,
        sleepHours,
        createdAt
      ];
}

class JournalEntry extends Equatable {
  final String id;
  final String userId;
  final String? title;
  final String content;
  final int? moodScore;
  final List<String> tags;
  final bool isPrivate;
  final String? aiInsight;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    required this.userId,
    this.title,
    required this.content,
    this.moodScore,
    this.tags = const [],
    this.isPrivate = true,
    this.aiInsight,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayTitle => title?.isNotEmpty == true
      ? title!
      : content.length > 40
          ? '${content.substring(0, 40)}...'
          : content;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String?,
        content: json['content'] as String,
        moodScore: json['mood_score'] as int?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        isPrivate: json['is_private'] as bool? ?? true,
        aiInsight: json['ai_insight'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'mood_score': moodScore,
        'tags': tags,
        'is_private': isPrivate,
        'ai_insight': aiInsight,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    int? moodScore,
    List<String>? tags,
    bool? isPrivate,
    String? aiInsight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      JournalEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        content: content ?? this.content,
        moodScore: moodScore ?? this.moodScore,
        tags: tags ?? this.tags,
        isPrivate: isPrivate ?? this.isPrivate,
        aiInsight: aiInsight ?? this.aiInsight,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, userId, title, content, moodScore, tags, isPrivate, createdAt];
}
