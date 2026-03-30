import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peer_chat_model.dart';

// ─── Anon Handle Generator ───────────────────────────────

const _adjectives = [
  'Starry', 'Cloudy', 'Brave', 'Gentle', 'Swift', 'Silent', 'Calm',
  'Bright', 'Misty', 'Cozy', 'Daring', 'Quiet', 'Bold', 'Tender', 'Keen',
];
const _animals = [
  'Panda', 'Otter', 'Owl', 'Fox', 'Wolf', 'Deer', 'Crane', 'Seal', 'Lynx',
  'Hare', 'Hawk', 'Bear', 'Finch', 'Moth', 'Wren',
];

String generatePeerHandle() {
  final rng = Random();
  final adj = _adjectives[rng.nextInt(_adjectives.length)];
  final animal = _animals[rng.nextInt(_animals.length)];
  final num = 1000 + rng.nextInt(9000);
  return '$adj$animal#$num';
}

// ─── State ───────────────────────────────────────────────

class PeerChatState {
  final List<PeerConversation> conversations;
  final List<PeerQueueEntry> openRequests;
  final bool isLoading;
  final String? error;

  const PeerChatState({
    this.conversations = const [],
    this.openRequests = const [],
    this.isLoading = false,
    this.error,
  });

  PeerConversation? get selfReflect =>
      conversations.where((c) => c.isSelfReflect).firstOrNull;

  List<PeerConversation> get peerConversations =>
      conversations.where((c) => !c.isSelfReflect && !c.isEnded).toList();

  List<PeerConversation> get endedConversations =>
      conversations.where((c) => !c.isSelfReflect && c.isEnded).toList();

  int get unreadCount => peerConversations.length;

  PeerChatState copyWith({
    List<PeerConversation>? conversations,
    List<PeerQueueEntry>? openRequests,
    bool? isLoading,
    String? error,
  }) => PeerChatState(
    conversations: conversations ?? this.conversations,
    openRequests: openRequests ?? this.openRequests,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

// ─── Notifier ────────────────────────────────────────────

class PeerChatNotifier extends AsyncNotifier<PeerChatState> {
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  // Broadcast channels for typing (keyed by convId)
  final _broadcastChannels = <String, RealtimeChannel>{};

  @override
  Future<PeerChatState> build() async {
    return _loadAll();
  }

  Future<PeerChatState> _loadAll() async {
    final uid = _uid;
    if (uid == null) return const PeerChatState();
    try {
      final convFuture = _sb
          .from('peer_conversations')
          .select()
          .or('user1_id.eq.$uid,user2_id.eq.$uid')
          .order('last_message_at', ascending: false, nullsFirst: false);

      final queueFuture = _sb
          .from('peer_queue')
          .select()
          .or('status.eq.open,user_id.eq.$uid')
          .order('created_at', ascending: false);

      final results = await Future.wait([convFuture, queueFuture]);

      final convos = (results[0] as List)
          .map((j) => PeerConversation.fromJson(j as Map<String, dynamic>))
          .toList();
      final requests = (results[1] as List)
          .map((j) => PeerQueueEntry.fromJson(j as Map<String, dynamic>))
          .toList();

      debugPrint('[PeerChat] loaded ${convos.length} convos, ${requests.length} queue entries');
      return PeerChatState(conversations: convos, openRequests: requests);
    } catch (e) {
      debugPrint('[PeerChat] _loadAll error: $e');
      return PeerChatState(error: e.toString());
    }
  }

  /// Fetches the display name + avatar URL for a user from the profiles table.
  Future<({String? name, String? avatar})> _fetchProfile(String uid) async {
    try {
      final data = await _sb
          .from('profiles')
          .select('name, preferred_name, profile_image_url')
          .eq('id', uid)
          .maybeSingle();
      if (data == null) return (name: null, avatar: null);
      final preferred = data['preferred_name'] as String?;
      final full = data['name'] as String?;
      final displayName = (preferred != null && preferred.isNotEmpty)
          ? preferred
          : (full ?? '').split(' ').first;
      return (
        name: displayName.isEmpty ? null : displayName,
        avatar: data['profile_image_url'] as String?,
      );
    } catch (_) {
      return (name: null, avatar: null);
    }
  }

  // ── Self-reflect ──────────────────────────────────────

  Future<String?> ensureSelfReflect() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final existing = await _sb
          .from('peer_conversations')
          .select('id')
          .eq('user1_id', uid)
          .eq('topic', 'Self Reflect')
          .isFilter('user2_id', null)
          .maybeSingle();

      if (existing != null) return existing['id'] as String;

      final resp = await _sb.from('peer_conversations').insert({
        'user1_id': uid,
        'user2_id': null,
        'topic': 'Self Reflect',
        'status': 'active',
      }).select('id').single();

      final id = resp['id'] as String;
      await refresh();
      return id;
    } catch (_) {
      return null;
    }
  }

  // ── Open Request Board ────────────────────────────────

  Future<void> loadOpenRequests() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final resp = await _sb
          .from('peer_queue')
          .select()
          .or('status.eq.open,user_id.eq.$uid')
          .order('created_at', ascending: false);
      final requests = (resp as List)
          .map((j) => PeerQueueEntry.fromJson(j as Map<String, dynamic>))
          .toList();
      final current = state.value ?? const PeerChatState();
      state = AsyncData(current.copyWith(openRequests: requests));
    } catch (_) {}
  }

  /// Creates a peer conversation + queue entry. Returns the queue entry.
  Future<PeerQueueEntry?> postOpenRequest({
    required String topic,
    required bool isAnonymous,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final handle = isAnonymous ? generatePeerHandle() : null;

      // Fetch real profile name + avatar
      final profile = await _fetchProfile(uid);

      // 1. Create the conversation (user2_id stays null = waiting)
      final convResp = await _sb.from('peer_conversations').insert({
        'user1_id': uid,
        'topic': topic,
        'is_anonymous': isAnonymous,
        'anon_handle': handle,
        'status': 'active',
        if (!isAnonymous && profile.name != null) 'user1_name': profile.name,
        if (!isAnonymous && profile.avatar != null) 'user1_avatar': profile.avatar,
      }).select('id').single();
      final convId = convResp['id'] as String;

      // 2. Create the queue entry
      final queueResp = await _sb.from('peer_queue').insert({
        'user_id': uid,
        'conversation_id': convId,
        'topic': topic,
        'is_anonymous': isAnonymous,
        'anon_handle': handle,
        'status': 'open',
      }).select().single();

      await refresh();
      return PeerQueueEntry.fromJson(queueResp as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Joins an open request as user2. Returns the updated conversation, or null
  /// if the slot is already taken (race condition) or an error occurred.
  Future<PeerConversation?> joinRequest(PeerQueueEntry entry) async {
    final uid = _uid;
    if (uid == null) return null;
    if (entry.userId == uid) return null;
    try {
      final myHandle = entry.isAnonymous ? generatePeerHandle() : null;

      // Fetch real profile name + avatar for joiner
      final profile = await _fetchProfile(uid);

      // Atomic join: only succeeds if user2_id is still null and status=active.
      final convRows = await _sb
          .from('peer_conversations')
          .update({
            'user2_id': uid,
            if (myHandle != null) 'user2_anon_handle': myHandle,
            if (!entry.isAnonymous && profile.name != null) 'user2_name': profile.name,
            if (!entry.isAnonymous && profile.avatar != null) 'user2_avatar': profile.avatar,
          })
          .eq('id', entry.conversationId)
          .eq('status', 'active')
          .isFilter('user2_id', null)
          .select();

      if ((convRows as List).isEmpty) {
        return null; // Genuine race — someone else joined first
      }

      // Mark queue entry as matched (non-critical)
      try {
        await _sb
            .from('peer_queue')
            .update({'status': 'matched'})
            .eq('id', entry.id);
      } catch (_) {}

      await refresh();
      return PeerConversation.fromJson(convRows.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PeerChat] joinRequest error: $e');
      return null;
    }
  }

  Future<void> cancelRequest(String queueId) async {
    try {
      final entry = state.value?.openRequests
          .where((e) => e.id == queueId)
          .firstOrNull;

      await _sb
          .from('peer_queue')
          .update({'status': 'cancelled'})
          .eq('id', queueId);

      if (entry != null) {
        await _sb
            .from('peer_conversations')
            .update({'status': 'ended'})
            .eq('id', entry.conversationId);
      }

      await refresh();
    } catch (_) {}
  }

  // ── End conversation ──────────────────────────────────

  Future<void> endConversation(String conversationId) async {
    final current = state.value;
    if (current == null) return;

    // Optimistic
    final updated = current.conversations
        .map((c) => c.id == conversationId ? c.copyWith(status: 'ended') : c)
        .toList();
    state = AsyncData(current.copyWith(conversations: updated));

    try {
      await _sb
          .from('peer_conversations')
          .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  // ── Messages ──────────────────────────────────────────

  Future<List<PeerMessage>> loadMessages(String conversationId) async {
    try {
      final resp = await _sb
          .from('peer_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at');
      return (resp as List)
          .map((j) => PeerMessage.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<PeerMessage?> sendMessage(
    String conversationId,
    String content, {
    String? mediaUrl,
    String? mediaType,
    String? replyToId,
    String? replyToContent,
    String? replyToSender,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final payload = <String, dynamic>{
        'conversation_id': conversationId,
        'sender_id': uid,
        'content': content,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'type': mediaType,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToSender != null) 'reply_to_sender': replyToSender,
      };

      final resp = await _sb.from('peer_messages').insert(payload).select().single();

      await _sb.from('peer_conversations').update({
        'last_message': mediaUrl != null
            ? '📷 Photo'
            : (content.length > 60 ? '${content.substring(0, 60)}…' : content),
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);

      await refresh();
      return PeerMessage.fromJson(resp as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Uploads an image to Supabase Storage and returns the public URL.
  Future<String?> uploadImage(String conversationId, File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final path =
          'peer-chat/$conversationId/${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _sb.storage.from('peer-chat-media').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: false),
          );

      return _sb.storage.from('peer-chat-media').getPublicUrl(path);
    } catch (e) {
      debugPrint('[PeerChat] uploadImage error: $e');
      return null;
    }
  }

  /// Optimistically toggles an emoji reaction on a message (local only;
  /// server persistence requires a `toggle_peer_reaction` RPC or reactions column).
  Future<void> toggleReaction(String messageId, String emoji) async {
    // Best-effort — silently ignored if RPC not configured
    try {
      final uid = _uid;
      if (uid == null) return;
      await _sb.rpc('toggle_peer_reaction', params: {
        'p_message_id': messageId,
        'p_emoji': emoji,
        'p_uid': uid,
      });
    } catch (_) {}
  }

  // ── Realtime Subscriptions ────────────────────────────

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(PeerMessage) onNew,
  ) {
    final channel = _sb.channel('peer_messages:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'peer_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            try {
              final msg = PeerMessage.fromJson(
                  payload.newRecord as Map<String, dynamic>);
              onNew(msg);
            } catch (_) {}
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToConversation(
    String conversationId,
    void Function(PeerConversation) onUpdate,
  ) {
    final channel = _sb.channel('conv_update:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'peer_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: conversationId,
          ),
          callback: (payload) {
            try {
              final conv = PeerConversation.fromJson(
                  payload.newRecord as Map<String, dynamic>);
              onUpdate(conv);
            } catch (_) {}
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToQueue(void Function() onChange) {
    final channel = _sb.channel('peer_queue_board');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'peer_queue',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'peer_queue',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  // ── Typing Broadcast ──────────────────────────────────

  RealtimeChannel _getBroadcastChannel(String convId) {
    return _broadcastChannels.putIfAbsent('typing:$convId', () {
      final ch = _sb.channel('typing:$convId');
      ch.subscribe();
      return ch;
    });
  }

  void listenTyping(
    String convId,
    void Function(String uid, bool isTyping) onEvent,
  ) {
    _getBroadcastChannel(convId).onBroadcast(
      event: 'typing',
      callback: (payload) {
        final uid = payload['uid'] as String? ?? '';
        final isTyping = payload['is_typing'] as bool? ?? false;
        onEvent(uid, isTyping);
      },
    );
  }

  Future<void> sendTyping(String convId, bool isTyping) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _getBroadcastChannel(convId).sendBroadcastMessage(
        event: 'typing',
        payload: {'uid': uid, 'is_typing': isTyping},
      );
    } catch (_) {}
  }

  void disposeBroadcastChannel(String convId) {
    final ch = _broadcastChannels.remove('typing:$convId');
    if (ch != null) _sb.removeChannel(ch);
  }

  // ── Refresh ───────────────────────────────────────────

  Future<void> refresh() async {
    final s = await _loadAll();
    state = AsyncData(s);
  }
}

// ─── Provider ────────────────────────────────────────────

final peerChatProvider =
    AsyncNotifierProvider<PeerChatNotifier, PeerChatState>(
  PeerChatNotifier.new,
);
