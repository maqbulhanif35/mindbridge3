// ─── Community Data Models ─────────────────────────────────

class PollOption {
  final String option;
  final int votes;
  const PollOption({required this.option, required this.votes});

  factory PollOption.fromJson(Map<String, dynamic> j) =>
      PollOption(option: j['option'] as String, votes: (j['votes'] as int?) ?? 0);

  Map<String, dynamic> toJson() => {'option': option, 'votes': votes};

  PollOption copyWith({int? votes}) =>
      PollOption(option: option, votes: votes ?? this.votes);
}

class EventData {
  final String title;
  final String date;
  final String location;
  final int spotsTotal;
  final int spotsLeft;

  const EventData({
    required this.title,
    required this.date,
    required this.location,
    required this.spotsTotal,
    required this.spotsLeft,
  });

  factory EventData.fromJson(Map<String, dynamic> j) => EventData(
        title: j['title'] as String? ?? '',
        date: j['date'] as String? ?? '',
        location: j['location'] as String? ?? '',
        spotsTotal: (j['spots_total'] as int?) ?? 0,
        spotsLeft: (j['spots_left'] as int?) ?? 0,
      );
}

class CommunityPost {
  final String id;
  final String userId;
  final String content;
  final String tag;
  final String postType; // 'text' | 'mood' | 'poll' | 'event'
  final bool isAnonymous;
  final String? anonHandle;
  final String? authorName; // real name from profiles join
  final int? moodScore;
  final List<PollOption>? pollOptions;
  final EventData? eventData;
  final bool isPinned;
  final DateTime createdAt;

  // Aggregated
  final Map<String, int> reactions; // {love, relate, strong, hug}
  final int commentCount;

  // User-specific
  final String? userReaction;
  final bool isBookmarked;
  final int? userVoteIndex;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.tag,
    required this.postType,
    required this.isAnonymous,
    required this.createdAt,
    this.anonHandle,
    this.authorName,
    this.moodScore,
    this.pollOptions,
    this.eventData,
    this.isPinned = false,
    this.reactions = const {'love': 0, 'relate': 0, 'strong': 0, 'hug': 0},
    this.commentCount = 0,
    this.userReaction,
    this.isBookmarked = false,
    this.userVoteIndex,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    final List<PollOption>? polls = j['poll_options'] == null
        ? null
        : (j['poll_options'] as List)
            .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
            .toList();

    return CommunityPost(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      content: j['content'] as String,
      tag: j['tag'] as String? ?? 'General',
      postType: j['post_type'] as String? ?? 'text',
      isAnonymous: j['is_anonymous'] as bool? ?? false,
      anonHandle: j['anon_handle'] as String?,
      authorName: j['author_name'] as String?,
      moodScore: j['mood_score'] as int?,
      pollOptions: polls,
      eventData: j['event_data'] == null
          ? null
          : EventData.fromJson(j['event_data'] as Map<String, dynamic>),
      isPinned: j['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
      reactions: {
        'love': (j['love_count'] as int?) ?? 0,
        'relate': (j['relate_count'] as int?) ?? 0,
        'strong': (j['strong_count'] as int?) ?? 0,
        'hug': (j['hug_count'] as int?) ?? 0,
      },
      commentCount: (j['comment_count'] as int?) ?? 0,
    );
  }

  int get totalReactions =>
      (reactions['love'] ?? 0) +
      (reactions['relate'] ?? 0) +
      (reactions['strong'] ?? 0) +
      (reactions['hug'] ?? 0);

  /// Returns anonymous handle when posted anonymously,
  /// otherwise the real first name from profiles (or a safe fallback).
  String get displayName {
    if (isAnonymous) return anonHandle ?? 'Anonymous';
    if (authorName != null && authorName!.isNotEmpty) {
      return authorName!.split(' ').first;
    }
    return 'Peer';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  CommunityPost copyWith({
    String? userReaction,
    bool? isBookmarked,
    Map<String, int>? reactions,
    int? userVoteIndex,
    List<PollOption>? pollOptions,
    int? commentCount,
    bool clearReaction = false,
  }) {
    return CommunityPost(
      id: id,
      userId: userId,
      content: content,
      tag: tag,
      postType: postType,
      isAnonymous: isAnonymous,
      anonHandle: anonHandle,
      authorName: authorName,
      moodScore: moodScore,
      pollOptions: pollOptions ?? this.pollOptions,
      eventData: eventData,
      isPinned: isPinned,
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
      commentCount: commentCount ?? this.commentCount,
      userReaction: clearReaction ? null : (userReaction ?? this.userReaction),
      isBookmarked: isBookmarked ?? this.isBookmarked,
      userVoteIndex: userVoteIndex ?? this.userVoteIndex,
    );
  }
}

class CommunityComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final bool isAnonymous;
  final String? anonHandle;
  final String? authorName;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.isAnonymous,
    required this.createdAt,
    this.anonHandle,
    this.authorName,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> j) =>
      CommunityComment(
        id: j['id'] as String,
        postId: j['post_id'] as String,
        userId: j['user_id'] as String? ?? '',
        content: j['content'] as String,
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        anonHandle: j['anon_handle'] as String?,
        authorName: j['author_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get displayName {
    if (isAnonymous) return anonHandle ?? 'Anonymous';
    if (authorName != null && authorName!.isNotEmpty) {
      return authorName!.split(' ').first;
    }
    return 'Peer';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
