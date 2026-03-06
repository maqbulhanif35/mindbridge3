import 'package:equatable/equatable.dart';

enum MessageRole { user, assistant, system }

enum MessageStatus { sending, sent, error }

class MessageModel extends Equatable {
  final String id;
  final String chatSessionId;
  final MessageRole role;
  final String content;
  final MessageStatus status;
  final bool isCrisisDetected;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.chatSessionId,
    required this.role,
    required this.content,
    this.status = MessageStatus.sent,
    this.isCrisisDetected = false,
    this.metadata,
    required this.createdAt,
  });

  bool get isFromUser => role == MessageRole.user;
  bool get isFromAI => role == MessageRole.assistant;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        chatSessionId: json['chat_session_id'] as String,
        role: MessageRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => MessageRole.user,
        ),
        content: json['content'] as String,
        status: MessageStatus.sent,
        isCrisisDetected: json['is_crisis_detected'] as bool? ?? false,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_session_id': chatSessionId,
        'role': role.name,
        'content': content,
        'is_crisis_detected': isCrisisDetected,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };

  MessageModel copyWith({
    String? id,
    String? chatSessionId,
    MessageRole? role,
    String? content,
    MessageStatus? status,
    bool? isCrisisDetected,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) =>
      MessageModel(
        id: id ?? this.id,
        chatSessionId: chatSessionId ?? this.chatSessionId,
        role: role ?? this.role,
        content: content ?? this.content,
        status: status ?? this.status,
        isCrisisDetected: isCrisisDetected ?? this.isCrisisDetected,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props =>
      [id, chatSessionId, role, content, status, isCrisisDetected, createdAt];
}

class ChatSessionModel extends Equatable {
  final String id;
  final String userId;
  final String? title;
  final List<MessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSessionModel({
    required this.id,
    required this.userId,
    this.title,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayTitle => title ?? 'Conversation';
  MessageModel? get lastMessage => messages.isNotEmpty ? messages.last : null;

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) =>
      ChatSessionModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String?,
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  ChatSessionModel copyWith({
    String? id,
    String? userId,
    String? title,
    List<MessageModel>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ChatSessionModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        messages: messages ?? this.messages,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, userId, title, messages, createdAt, updatedAt];
}
