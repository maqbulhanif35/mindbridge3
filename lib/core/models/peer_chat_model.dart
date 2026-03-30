// ─── Peer Chat Models ─────────────────────────────────────

class PeerConversation {
  final String id;
  final String user1Id;
  final String? user2Id;
  final bool isAnonymous;
  final String? anonHandle;        // user1 anon handle (only used when isAnonymous)
  final String? user2AnonHandle;   // user2 anon handle (only used when isAnonymous)
  final String? user1Name;         // real display name from profile
  final String? user2Name;         // real display name from profile
  final String? user1Avatar;       // profile image URL
  final String? user2Avatar;       // profile image URL
  final String topic;
  final String status; // 'active' | 'ended'
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  const PeerConversation({
    required this.id,
    required this.user1Id,
    this.user2Id,
    this.isAnonymous = false,
    this.anonHandle,
    this.user2AnonHandle,
    this.user1Name,
    this.user2Name,
    this.user1Avatar,
    this.user2Avatar,
    this.topic = 'General',
    this.status = 'active',
    this.lastMessage,
    this.lastMessageAt,
    this.endedAt,
    required this.createdAt,
  });

  bool get isSelfReflect => topic == 'Self Reflect';
  bool get isEnded => status == 'ended';
  bool get isWaiting => !isSelfReflect && user2Id == null && !isEnded;
  bool get isConnected => !isSelfReflect && user2Id != null && !isEnded;
  bool get isStale => DateTime.now().difference(createdAt) > const Duration(hours: 2);

  /// Returns the OTHER user's display name for the given uid.
  /// If anonymous, uses the generated handle; otherwise uses real profile name.
  String peerHandle(String myUid) {
    if (myUid == user1Id) {
      // I am user1 — peer is user2
      if (isAnonymous) return user2AnonHandle ?? 'Anonymous Peer';
      return user2Name ?? user2AnonHandle ?? 'Peer';
    }
    // I am user2 — peer is user1
    if (isAnonymous) return anonHandle ?? 'Anonymous Peer';
    return user1Name ?? anonHandle ?? 'Peer';
  }

  /// Returns MY display name for the given uid.
  String myHandle(String myUid) {
    if (myUid == user1Id) {
      if (isAnonymous) return anonHandle ?? 'You';
      return user1Name ?? 'You';
    }
    if (isAnonymous) return user2AnonHandle ?? 'You';
    return user2Name ?? 'You';
  }

  /// Returns the OTHER user's avatar URL (null if anonymous or not set).
  String? peerAvatar(String myUid) {
    if (isAnonymous) return null;
    if (myUid == user1Id) return user2Avatar;
    return user1Avatar;
  }

  factory PeerConversation.fromJson(Map<String, dynamic> j) => PeerConversation(
    id: j['id'] as String,
    user1Id: j['user1_id'] as String,
    user2Id: j['user2_id'] as String?,
    isAnonymous: j['is_anonymous'] as bool? ?? false,
    anonHandle: j['anon_handle'] as String?,
    user2AnonHandle: j['user2_anon_handle'] as String?,
    user1Name: j['user1_name'] as String?,
    user2Name: j['user2_name'] as String?,
    user1Avatar: j['user1_avatar'] as String?,
    user2Avatar: j['user2_avatar'] as String?,
    topic: j['topic'] as String? ?? 'General',
    status: j['status'] as String? ?? 'active',
    lastMessage: j['last_message'] as String?,
    lastMessageAt: j['last_message_at'] != null
        ? DateTime.parse(j['last_message_at'] as String)
        : null,
    endedAt: j['ended_at'] != null
        ? DateTime.parse(j['ended_at'] as String)
        : null,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  PeerConversation copyWith({
    String? user2Id,
    String? user2AnonHandle,
    String? user2Name,
    String? user2Avatar,
    String? status,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? endedAt,
  }) => PeerConversation(
    id: id,
    user1Id: user1Id,
    user2Id: user2Id ?? this.user2Id,
    isAnonymous: isAnonymous,
    anonHandle: anonHandle,
    user2AnonHandle: user2AnonHandle ?? this.user2AnonHandle,
    user1Name: user1Name,
    user2Name: user2Name ?? this.user2Name,
    user1Avatar: user1Avatar,
    user2Avatar: user2Avatar ?? this.user2Avatar,
    topic: topic,
    status: status ?? this.status,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    endedAt: endedAt ?? this.endedAt,
    createdAt: createdAt,
  );

  String get timeAgo {
    final dt = lastMessageAt ?? createdAt;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Peer Message ─────────────────────────────────────────

class PeerMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isTemp;
  final String type; // 'text' | 'system' | 'image'
  final String? mediaUrl;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSender;
  final Map<String, List<String>> reactions; // emoji → [uid, ...]

  const PeerMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isTemp = false,
    this.type = 'text',
    this.mediaUrl,
    this.replyToId,
    this.replyToContent,
    this.replyToSender,
    this.reactions = const {},
  });

  bool get isSystem => type == 'system';
  bool get isImage => type == 'image';
  bool get hasReactions => reactions.isNotEmpty;

  PeerMessage copyWithReaction(String emoji, String uid) {
    final updated = Map<String, List<String>>.from(
      reactions.map((k, v) => MapEntry(k, List<String>.from(v))));
    final list = updated.putIfAbsent(emoji, () => []);
    if (list.contains(uid)) {
      list.remove(uid);
      if (list.isEmpty) updated.remove(emoji);
    } else {
      list.add(uid);
    }
    return PeerMessage(
      id: id, conversationId: conversationId, senderId: senderId,
      content: content, createdAt: createdAt, isTemp: isTemp,
      type: type, mediaUrl: mediaUrl, replyToId: replyToId,
      replyToContent: replyToContent, replyToSender: replyToSender,
      reactions: updated,
    );
  }

  /// Creates a synthetic system message (never persisted to DB).
  factory PeerMessage.system({
    required String conversationId,
    required String content,
  }) => PeerMessage(
    id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
    conversationId: conversationId,
    senderId: 'system',
    content: content,
    createdAt: DateTime.now(),
    type: 'system',
  );

  factory PeerMessage.fromJson(Map<String, dynamic> j) {
    // Parse reactions: stored as {emoji: [uid1, uid2]}
    Map<String, List<String>> reactions = {};
    final rawReactions = j['reactions'];
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        if (v is List) {
          reactions[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }
    return PeerMessage(
      id: j['id'] as String,
      conversationId: j['conversation_id'] as String,
      senderId: j['sender_id'] as String,
      content: j['content'] as String? ?? '',
      createdAt: DateTime.parse(j['created_at'] as String),
      type: j['type'] as String? ?? 'text',
      mediaUrl: j['media_url'] as String?,
      replyToId: j['reply_to_id'] as String?,
      replyToContent: j['reply_to_content'] as String?,
      replyToSender: j['reply_to_sender'] as String?,
      reactions: reactions,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─── Peer Queue Entry ─────────────────────────────────────

class PeerQueueEntry {
  final String id;
  final String userId;
  final String conversationId;
  final String topic;
  final bool isAnonymous;
  final String? anonHandle;
  final String status; // 'open' | 'matched' | 'cancelled'
  final DateTime createdAt;

  const PeerQueueEntry({
    required this.id,
    required this.userId,
    required this.conversationId,
    required this.topic,
    required this.isAnonymous,
    required this.createdAt,
    this.anonHandle,
    this.status = 'open',
  });

  bool get isExpired => DateTime.now().difference(createdAt) > const Duration(hours: 2);
  bool get isOpen => status == 'open' && !isExpired;
  String get displayHandle => anonHandle ?? 'Anonymous Peer';

  factory PeerQueueEntry.fromJson(Map<String, dynamic> j) => PeerQueueEntry(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    conversationId: j['conversation_id'] as String,
    topic: j['topic'] as String? ?? 'General',
    isAnonymous: j['is_anonymous'] as bool? ?? true,
    anonHandle: j['anon_handle'] as String?,
    status: j['status'] as String? ?? 'open',
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m waiting';
    return '${diff.inHours}h waiting';
  }
}
