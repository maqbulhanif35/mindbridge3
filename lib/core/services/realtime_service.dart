import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event types emitted by the RealtimeService.
enum RealtimeEventType { insert, update, delete }

class RealtimeEvent<T> {
  final RealtimeEventType type;
  final T? newRecord;
  final T? oldRecord;

  const RealtimeEvent({
    required this.type,
    this.newRecord,
    this.oldRecord,
  });
}

/// Manages all Supabase real-time channel subscriptions.
/// Provides typed streams for live data updates across the app.
class RealtimeService {
  final SupabaseClient _client;

  // Stream controllers
  final _moodController =
      StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();
  final _journalController =
      StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();
  final _chatController =
      StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();
  final _streakController =
      StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();
  final _achievementController =
      StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();
  final _communityController =
      StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();

  // Active channels
  final _channels = <String, RealtimeChannel>{};
  bool _initialized = false;

  RealtimeService(this._client);

  // ─── Public Streams ───────────────────────────────────
  Stream<RealtimeEvent<Map<String, dynamic>>> get moodStream =>
      _moodController.stream;
  Stream<RealtimeEvent<Map<String, dynamic>>> get journalStream =>
      _journalController.stream;
  Stream<RealtimeEvent<Map<String, dynamic>>> get chatStream =>
      _chatController.stream;
  Stream<RealtimeEvent<Map<String, dynamic>>> get streakStream =>
      _streakController.stream;
  Stream<RealtimeEvent<Map<String, dynamic>>> get achievementStream =>
      _achievementController.stream;
  Stream<RealtimeEvent<Map<String, dynamic>>> get communityStream =>
      _communityController.stream;

  /// Initialize all real-time subscriptions for the authenticated user.
  Future<void> initialize(String userId) async {
    if (_initialized) await dispose();

    try {
      await _subscribeMoodLogs(userId);
      await _subscribeJournalEntries(userId);
      await _subscribeChatMessages(userId);
      await _subscribeUserStreaks(userId);
      await _subscribeAchievements(userId);
      await _subscribeCommunity();
      _initialized = true;
      debugPrint('RealtimeService: All channels active for user $userId');
    } catch (e) {
      debugPrint('RealtimeService: Initialization error: $e');
    }
  }

  // ─── Channel Subscriptions ────────────────────────────

  Future<void> _subscribeMoodLogs(String userId) async {
    final channel = _client.channel('mood_logs_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mood_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _moodController.add(RealtimeEvent(
            type: RealtimeEventType.insert,
            newRecord: payload.newRecord,
          )),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mood_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _moodController.add(RealtimeEvent(
            type: RealtimeEventType.update,
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          )),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'mood_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _moodController.add(RealtimeEvent(
            type: RealtimeEventType.delete,
            oldRecord: payload.oldRecord,
          )),
        )
        .subscribe();
    _channels['mood_logs'] = channel;
  }

  Future<void> _subscribeJournalEntries(String userId) async {
    final channel = _client.channel('journal_entries_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'journal_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _journalController.add(RealtimeEvent(
            type: RealtimeEventType.insert,
            newRecord: payload.newRecord,
          )),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'journal_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _journalController.add(RealtimeEvent(
            type: RealtimeEventType.update,
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          )),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'journal_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _journalController.add(RealtimeEvent(
            type: RealtimeEventType.delete,
            oldRecord: payload.oldRecord,
          )),
        )
        .subscribe();
    _channels['journal_entries'] = channel;
  }

  Future<void> _subscribeChatMessages(String userId) async {
    final channel = _client.channel('chat_messages_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _chatController.add(RealtimeEvent(
            type: RealtimeEventType.insert,
            newRecord: payload.newRecord,
          )),
        )
        .subscribe();
    _channels['chat_messages'] = channel;
  }

  Future<void> _subscribeUserStreaks(String userId) async {
    final channel = _client.channel('user_streaks_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_streaks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _streakController.add(RealtimeEvent(
            type: _eventType(payload.eventType),
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          )),
        )
        .subscribe();
    _channels['user_streaks'] = channel;
  }

  Future<void> _subscribeAchievements(String userId) async {
    final channel = _client.channel('user_achievements_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_achievements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _achievementController.add(RealtimeEvent(
            type: RealtimeEventType.insert,
            newRecord: payload.newRecord,
          )),
        )
        .subscribe();
    _channels['user_achievements'] = channel;
  }

  Future<void> _subscribeCommunity() async {
    final channel = _client.channel('community_messages');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_messages',
          callback: (payload) => _communityController.add(RealtimeEvent(
            type: RealtimeEventType.insert,
            newRecord: payload.newRecord,
          )),
        )
        .subscribe();
    _channels['community_messages'] = channel;
  }

  RealtimeEventType _eventType(PostgresChangeEvent event) =>
      switch (event) {
        PostgresChangeEvent.insert => RealtimeEventType.insert,
        PostgresChangeEvent.update => RealtimeEventType.update,
        PostgresChangeEvent.delete => RealtimeEventType.delete,
        _ => RealtimeEventType.update,
      };

  /// Unsubscribe all channels and close streams.
  Future<void> dispose() async {
    for (final channel in _channels.values) {
      await _client.removeChannel(channel);
    }
    _channels.clear();
    _initialized = false;
  }

  /// Re-subscribe (e.g., after reconnect).
  Future<void> reconnect(String userId) async {
    await dispose();
    await initialize(userId);
  }
}
