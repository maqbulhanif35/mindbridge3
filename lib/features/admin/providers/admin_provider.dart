import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Models ───────────────────────────────────────────────

class AdminStats {
  final int totalUsers;
  final int activeToday;
  final int activeThisWeek;
  final int moodLogsToday;
  final int moodLogsTotal;
  final int journalEntries;
  final int communityPosts;
  final int flaggedPosts;
  final int hiddenPosts;
  final int crisisMessages;
  final int mindfulnessSessions;
  final int chatSessions;
  final double avgMoodScore;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int newUsersLastWeek;
  final int bannedUsers;
  final int pendingOnboarding;
  final DateTime lastRefreshed;

  const AdminStats({
    this.totalUsers = 0,
    this.activeToday = 0,
    this.activeThisWeek = 0,
    this.moodLogsToday = 0,
    this.moodLogsTotal = 0,
    this.journalEntries = 0,
    this.communityPosts = 0,
    this.flaggedPosts = 0,
    this.hiddenPosts = 0,
    this.crisisMessages = 0,
    this.mindfulnessSessions = 0,
    this.chatSessions = 0,
    this.avgMoodScore = 0,
    this.newUsersToday = 0,
    this.newUsersThisWeek = 0,
    this.newUsersLastWeek = 0,
    this.bannedUsers = 0,
    this.pendingOnboarding = 0,
    DateTime? lastRefreshed,
  }) : lastRefreshed = lastRefreshed ?? const _Epoch();

  double get userGrowthPercent {
    if (newUsersLastWeek == 0) return newUsersThisWeek > 0 ? 100 : 0;
    return ((newUsersThisWeek - newUsersLastWeek) / newUsersLastWeek) * 100;
  }

  bool get hasCrisisAlerts => crisisMessages > 0 || flaggedPosts > 3;
  bool get moodAlertActive => avgMoodScore > 0 && avgMoodScore < 4.5;
}

// Workaround for const DateTime
class _Epoch implements DateTime {
  const _Epoch();
  @override dynamic noSuchMethod(Invocation i) => DateTime(2000);
}

// ─── System Alert ─────────────────────────────────────────

enum AlertSeverity { info, warning, critical }

class SystemAlert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final String? actionRoute;
  final DateTime createdAt;
  bool dismissed;

  SystemAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.actionRoute,
    DateTime? createdAt,
    this.dismissed = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ─── Live Activity Event ──────────────────────────────────

enum LiveEventType { userJoined, moodLogged, crisisFlag, postFlagged, userBanned, journalWritten, chatStarted }

class LiveEvent {
  final String id;
  final LiveEventType type;
  final String description;
  final String? userId;
  final String? userName;
  final DateTime at;

  const LiveEvent({
    required this.id,
    required this.type,
    required this.description,
    this.userId,
    this.userName,
    required this.at,
  });

  String get icon {
    switch (type) {
      case LiveEventType.userJoined: return '👤';
      case LiveEventType.moodLogged: return '💙';
      case LiveEventType.crisisFlag: return '🚨';
      case LiveEventType.postFlagged: return '🚩';
      case LiveEventType.userBanned: return '⛔';
      case LiveEventType.journalWritten: return '📓';
      case LiveEventType.chatStarted: return '🤖';
    }
  }
}

// ─── User Entry ───────────────────────────────────────────

class AdminUserEntry {
  final String id;
  final String email;
  final String name;
  final String? university;
  final int? yearOfStudy;
  final String? faculty;
  final String role;
  final bool isBanned;
  final bool onboardingCompleted;
  final DateTime createdAt;
  int moodCount;
  int journalCount;
  int streakDays;
  DateTime? lastActive;

  AdminUserEntry({
    required this.id,
    required this.email,
    required this.name,
    this.university,
    this.yearOfStudy,
    this.faculty,
    required this.role,
    required this.isBanned,
    required this.onboardingCompleted,
    required this.createdAt,
    this.moodCount = 0,
    this.journalCount = 0,
    this.streakDays = 0,
    this.lastActive,
  });

  factory AdminUserEntry.fromJson(Map<String, dynamic> j) => AdminUserEntry(
        id: j['id'] as String,
        email: j['email'] as String? ?? '',
        name: j['name'] as String? ?? 'Unknown',
        university: j['university'] as String?,
        yearOfStudy: j['year_of_study'] as int?,
        faculty: j['faculty'] as String?,
        role: j['role'] as String? ?? 'user',
        isBanned: j['is_banned'] as bool? ?? false,
        onboardingCompleted: j['onboarding_completed'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        moodCount: j['mood_count'] as int? ?? 0,
        journalCount: j['journal_count'] as int? ?? 0,
        streakDays: j['streak_days'] as int? ?? 0,
      );

  String get initials =>
      name.isNotEmpty ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase() : '?';

  bool get isAdmin => role == 'admin' || role == 'superadmin';
}

// ─── Community Post ───────────────────────────────────────

class CommunityPostAdmin {
  final String id;
  final String? userId;
  final String content;
  final String? tag;
  final String postType;
  final bool isAnonymous;
  final String? anonHandle;
  bool isPinned;
  bool isFlagged;
  bool isHidden;
  final String? authorName;
  final DateTime createdAt;
  int reactionCount;
  int commentCount;

  CommunityPostAdmin({
    required this.id,
    this.userId,
    required this.content,
    this.tag,
    required this.postType,
    required this.isAnonymous,
    this.anonHandle,
    required this.isPinned,
    required this.isFlagged,
    required this.isHidden,
    this.authorName,
    required this.createdAt,
    this.reactionCount = 0,
    this.commentCount = 0,
  });

  factory CommunityPostAdmin.fromJson(Map<String, dynamic> j) =>
      CommunityPostAdmin(
        id: j['id'] as String,
        userId: j['user_id'] as String?,
        content: j['content'] as String? ?? '',
        tag: j['tag'] as String?,
        postType: j['post_type'] as String? ?? 'text',
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        anonHandle: j['anon_handle'] as String?,
        isPinned: j['is_pinned'] as bool? ?? false,
        isFlagged: j['is_flagged'] as bool? ?? false,
        isHidden: j['is_hidden'] as bool? ?? false,
        authorName: j['author_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ─── Chart Point Models ───────────────────────────────────

class MoodTrendPoint {
  final DateTime date;
  final double avgMood;
  final int count;
  const MoodTrendPoint({required this.date, required this.avgMood, required this.count});
}

class UserGrowthPoint {
  final DateTime date;
  final int newUsers;
  final int cumulative;
  const UserGrowthPoint({required this.date, required this.newUsers, required this.cumulative});
}

// ─── Broadcast ────────────────────────────────────────────

class BroadcastRecord {
  final String id;
  final String title;
  final String body;
  final String target;
  final String? sentByName;
  final DateTime sentAt;
  final int recipientCount;
  final String channel; // 'inapp' | 'email' | 'both'

  const BroadcastRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.target,
    this.sentByName,
    required this.sentAt,
    required this.recipientCount,
    this.channel = 'inapp',
  });

  factory BroadcastRecord.fromJson(Map<String, dynamic> j) => BroadcastRecord(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        target: j['target'] as String? ?? 'all',
        sentByName: j['sent_by_name'] as String?,
        sentAt: DateTime.parse(j['sent_at'] as String),
        recipientCount: j['recipient_count'] as int? ?? 0,
        channel: j['channel'] as String? ?? 'inapp',
      );
}

// ─── Moderation Action ────────────────────────────────────

class ModerationAction {
  final String id;
  final String? adminName;
  final String action;
  final String targetType;
  final String targetId;
  final String? reason;
  final DateTime createdAt;

  const ModerationAction({
    required this.id,
    this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.reason,
    required this.createdAt,
  });

  factory ModerationAction.fromJson(Map<String, dynamic> j) => ModerationAction(
        id: j['id'] as String,
        adminName: j['admin_name'] as String?,
        action: j['action'] as String,
        targetType: j['target_type'] as String,
        targetId: j['target_id'] as String,
        reason: j['reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ─── Alert Thresholds Config ──────────────────────────────

class AlertThresholds {
  final double minAvgMoodAlert;     // below this → mood alert
  final int maxFlaggedPosts;        // above this → moderation alert
  final int crisisCountAlert;       // above this → crisis alert
  final int inactiveUsersDays;      // days without activity → inactive alert
  final int maxBannedPercent;       // % of banned users → alert

  const AlertThresholds({
    this.minAvgMoodAlert = 4.5,
    this.maxFlaggedPosts = 3,
    this.crisisCountAlert = 1,
    this.inactiveUsersDays = 7,
    this.maxBannedPercent = 5,
  });

  AlertThresholds copyWith({
    double? minAvgMoodAlert,
    int? maxFlaggedPosts,
    int? crisisCountAlert,
    int? inactiveUsersDays,
    int? maxBannedPercent,
  }) =>
      AlertThresholds(
        minAvgMoodAlert: minAvgMoodAlert ?? this.minAvgMoodAlert,
        maxFlaggedPosts: maxFlaggedPosts ?? this.maxFlaggedPosts,
        crisisCountAlert: crisisCountAlert ?? this.crisisCountAlert,
        inactiveUsersDays: inactiveUsersDays ?? this.inactiveUsersDays,
        maxBannedPercent: maxBannedPercent ?? this.maxBannedPercent,
      );
}

// ─── Admin State ──────────────────────────────────────────

class AdminState {
  final bool isLoading;
  final String? error;
  final AdminStats stats;
  final List<AdminUserEntry> users;
  final List<CommunityPostAdmin> posts;
  final List<MoodTrendPoint> moodTrend;
  final List<UserGrowthPoint> userGrowth;
  final List<BroadcastRecord> broadcasts;
  final List<ModerationAction> moderationLog;
  final List<SystemAlert> alerts;
  final List<LiveEvent> liveEvents;
  final int totalUsersCount;
  final String userSearchQuery;
  final String userRoleFilter;
  final bool showBannedOnly;
  final AlertThresholds thresholds;
  final bool realtimeConnected;

  const AdminState({
    this.isLoading = false,
    this.error,
    this.stats = const AdminStats(),
    this.users = const [],
    this.posts = const [],
    this.moodTrend = const [],
    this.userGrowth = const [],
    this.broadcasts = const [],
    this.moderationLog = const [],
    this.alerts = const [],
    this.liveEvents = const [],
    this.totalUsersCount = 0,
    this.userSearchQuery = '',
    this.userRoleFilter = 'all',
    this.showBannedOnly = false,
    this.thresholds = const AlertThresholds(),
    this.realtimeConnected = false,
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    AdminStats? stats,
    List<AdminUserEntry>? users,
    List<CommunityPostAdmin>? posts,
    List<MoodTrendPoint>? moodTrend,
    List<UserGrowthPoint>? userGrowth,
    List<BroadcastRecord>? broadcasts,
    List<ModerationAction>? moderationLog,
    List<SystemAlert>? alerts,
    List<LiveEvent>? liveEvents,
    int? totalUsersCount,
    String? userSearchQuery,
    String? userRoleFilter,
    bool? showBannedOnly,
    AlertThresholds? thresholds,
    bool? realtimeConnected,
    bool clearError = false,
  }) =>
      AdminState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        stats: stats ?? this.stats,
        users: users ?? this.users,
        posts: posts ?? this.posts,
        moodTrend: moodTrend ?? this.moodTrend,
        userGrowth: userGrowth ?? this.userGrowth,
        broadcasts: broadcasts ?? this.broadcasts,
        moderationLog: moderationLog ?? this.moderationLog,
        alerts: alerts ?? this.alerts,
        liveEvents: liveEvents ?? this.liveEvents,
        totalUsersCount: totalUsersCount ?? this.totalUsersCount,
        userSearchQuery: userSearchQuery ?? this.userSearchQuery,
        userRoleFilter: userRoleFilter ?? this.userRoleFilter,
        showBannedOnly: showBannedOnly ?? this.showBannedOnly,
        thresholds: thresholds ?? this.thresholds,
        realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      );
}

// ─── Admin Notifier ───────────────────────────────────────

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState());

  static SupabaseClient get _db => Supabase.instance.client;

  // Real-time channels
  RealtimeChannel? _profilesChannel;
  RealtimeChannel? _moodChannel;
  RealtimeChannel? _postsChannel;

  // ─── Real-time Setup ──────────────────────────────────

  void startRealtime() {
    _subscribeProfiles();
    _subscribeMoodLogs();
    _subscribePosts();
    state = state.copyWith(realtimeConnected: true);
  }

  void stopRealtime() {
    _profilesChannel?.unsubscribe();
    _moodChannel?.unsubscribe();
    _postsChannel?.unsubscribe();
    state = state.copyWith(realtimeConnected: false);
  }

  void _subscribeProfiles() {
    _profilesChannel = _db
        .channel('admin-profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final newRow = payload.newRecord;
            final name = newRow['name'] as String? ?? 'New User';
            _addLiveEvent(LiveEvent(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: LiveEventType.userJoined,
              description: '$name just joined MindBridge',
              userName: name,
              at: DateTime.now(),
            ));
            // Refresh stats
            loadDashboard();
          },
        )
        .subscribe();
  }

  void _subscribeMoodLogs() {
    _moodChannel = _db
        .channel('admin-moods')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mood_logs',
          callback: (payload) {
            final score = payload.newRecord['mood_score'] as int? ?? 5;
            _addLiveEvent(LiveEvent(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: score <= 3 ? LiveEventType.crisisFlag : LiveEventType.moodLogged,
              description: score <= 3
                  ? '⚠ Low mood logged (score: $score) — may need attention'
                  : 'Mood check-in logged (score: $score)',
              at: DateTime.now(),
            ));
            // Auto-refresh dashboard stats
            _refreshStatsCounts();
          },
        )
        .subscribe();
  }

  void _subscribePosts() {
    _postsChannel = _db
        .channel('admin-posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            final newRow = payload.newRecord;
            final isFlagged = newRow['is_flagged'] as bool? ?? false;
            if (isFlagged) {
              _addLiveEvent(LiveEvent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: LiveEventType.postFlagged,
                description: 'A community post was flagged for review',
                at: DateTime.now(),
              ));
              _checkThresholdsAndAlert();
            }
          },
        )
        .subscribe();
  }

  void _addLiveEvent(LiveEvent event) {
    final current = [event, ...state.liveEvents].take(50).toList();
    state = state.copyWith(liveEvents: current);
  }

  // ─── Dashboard Stats (via RPC — bypasses RLS) ────────────

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final raw = await _db.rpc('admin_get_dashboard_stats');
      final j = raw as Map<String, dynamic>;

      int _i(String k) => (j[k] as num?)?.toInt() ?? 0;
      double _d(String k) => (j[k] as num?)?.toDouble() ?? 0.0;

      final newStats = AdminStats(
        totalUsers: _i('total_users'),
        moodLogsToday: _i('mood_logs_today'),
        moodLogsTotal: _i('mood_logs_total'),
        journalEntries: _i('journal_entries'),
        communityPosts: _i('community_posts'),
        flaggedPosts: _i('flagged_posts'),
        hiddenPosts: _i('hidden_posts'),
        mindfulnessSessions: _i('mindfulness'),
        newUsersToday: _i('new_users_today'),
        newUsersThisWeek: _i('new_users_week'),
        newUsersLastWeek: _i('new_users_prev_week'),
        bannedUsers: _i('banned_users'),
        pendingOnboarding: _i('pending_onboarding'),
        chatSessions: _i('chat_sessions'),
        avgMoodScore: _d('avg_mood_7d'),
        activeToday: _i('active_today'),
        activeThisWeek: _i('active_week'),
        crisisMessages: 0,
        lastRefreshed: DateTime.now(),
      );

      state = state.copyWith(isLoading: false, stats: newStats);
      _checkThresholdsAndAlert();
      await Future.wait([loadMoodTrend(), loadUserGrowth()]);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load dashboard: $e');
    }
  }

  Future<void> _refreshStatsCounts() async {
    // Light refresh — re-use full dashboard RPC to keep counts accurate
    try {
      final raw = await _db.rpc('admin_get_dashboard_stats');
      final j = raw as Map<String, dynamic>;
      int _i(String k) => (j[k] as num?)?.toInt() ?? 0;
      double _d(String k) => (j[k] as num?)?.toDouble() ?? 0.0;
      state = state.copyWith(
        stats: AdminStats(
          totalUsers: _i('total_users'),
          moodLogsToday: _i('mood_logs_today'),
          moodLogsTotal: _i('mood_logs_total'),
          journalEntries: _i('journal_entries'),
          communityPosts: _i('community_posts'),
          flaggedPosts: _i('flagged_posts'),
          hiddenPosts: _i('hidden_posts'),
          mindfulnessSessions: _i('mindfulness'),
          newUsersToday: _i('new_users_today'),
          newUsersThisWeek: _i('new_users_week'),
          newUsersLastWeek: _i('new_users_prev_week'),
          bannedUsers: _i('banned_users'),
          pendingOnboarding: _i('pending_onboarding'),
          chatSessions: _i('chat_sessions'),
          avgMoodScore: _d('avg_mood_7d'),
          activeToday: _i('active_today'),
          activeThisWeek: _i('active_week'),
          crisisMessages: state.stats.crisisMessages,
          lastRefreshed: DateTime.now(),
        ),
      );
      _checkThresholdsAndAlert();
    } catch (_) {}
  }

  // ─── Threshold Alerts ─────────────────────────────────

  void _checkThresholdsAndAlert() {
    final t = state.thresholds;
    final s = state.stats;
    final newAlerts = <SystemAlert>[];

    // Mood below threshold
    if (s.avgMoodScore > 0 && s.avgMoodScore < t.minAvgMoodAlert) {
      newAlerts.add(SystemAlert(
        id: 'mood_low',
        title: 'Platform Mood Alert',
        message:
            'Average mood (${s.avgMoodScore.toStringAsFixed(1)}) is below threshold (${t.minAvgMoodAlert}). Users may be struggling.',
        severity: s.avgMoodScore < 3.5 ? AlertSeverity.critical : AlertSeverity.warning,
        actionRoute: '/admin/analytics',
      ));
    }

    // Too many flagged posts
    if (s.flaggedPosts >= t.maxFlaggedPosts) {
      newAlerts.add(SystemAlert(
        id: 'flagged_posts',
        title: 'Moderation Required',
        message: '${s.flaggedPosts} posts flagged and awaiting review.',
        severity: s.flaggedPosts >= t.maxFlaggedPosts * 3 ? AlertSeverity.critical : AlertSeverity.warning,
        actionRoute: '/admin/moderation',
      ));
    }

    // Low engagement
    if (s.totalUsers > 10 && s.activeToday == 0) {
      newAlerts.add(SystemAlert(
        id: 'zero_activity',
        title: 'Zero Activity Today',
        message: 'No users have logged mood today. Check for system issues.',
        severity: AlertSeverity.info,
        actionRoute: '/admin/analytics',
      ));
    }

    // High ban rate
    if (s.totalUsers > 0) {
      final banPct = (s.bannedUsers / s.totalUsers) * 100;
      if (banPct >= t.maxBannedPercent) {
        newAlerts.add(SystemAlert(
          id: 'high_bans',
          title: 'High Ban Rate',
          message: '${banPct.toStringAsFixed(1)}% of users are banned. Review moderation policies.',
          severity: AlertSeverity.warning,
        ));
      }
    }

    // Merge with existing, keep dismissed state
    final dismissed = {for (final a in state.alerts.where((a) => a.dismissed)) a.id};
    for (final a in newAlerts) {
      if (dismissed.contains(a.id)) a.dismissed = true;
    }

    state = state.copyWith(alerts: newAlerts);
  }

  void dismissAlert(String id) {
    final updated = state.alerts.map((a) {
      if (a.id == id) a.dismissed = true;
      return a;
    }).toList();
    state = state.copyWith(alerts: updated);
  }

  void updateThresholds(AlertThresholds t) {
    state = state.copyWith(thresholds: t);
    _checkThresholdsAndAlert();
  }

  // ─── Mood Trend (via RPC) ─────────────────────────────

  Future<void> loadMoodTrend() async {
    try {
      final data = await _db.rpc('admin_get_mood_trend');
      final points = (data as List).map((row) => MoodTrendPoint(
        date: DateTime.parse(row['day'] as String),
        avgMood: (row['avg_mood'] as num?)?.toDouble() ?? 0,
        count: (row['log_count'] as num?)?.toInt() ?? 0,
      )).toList();
      state = state.copyWith(moodTrend: points);
    } catch (_) {}
  }

  // ─── User Growth (via RPC) ────────────────────────────

  Future<void> loadUserGrowth() async {
    try {
      final data = await _db.rpc('admin_get_user_growth');
      int cumulative = state.stats.totalUsers;
      final points = (data as List).map((row) {
        final n = (row['new_users'] as num?)?.toInt() ?? 0;
        return UserGrowthPoint(
          date: DateTime.parse(row['day'] as String),
          newUsers: n,
          cumulative: cumulative,
        );
      }).toList();
      state = state.copyWith(userGrowth: points);
    } catch (_) {}
  }

  // ─── Users ────────────────────────────────────────────

  Future<void> loadUsers({int page = 0, bool reset = false}) async {
    if (reset) state = state.copyWith(users: []);
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _db.rpc('admin_get_profiles', params: {
        'search_query': state.userSearchQuery,
        'role_filter': state.userRoleFilter,
        'banned_only': state.showBannedOnly,
        'page_offset': page * 50,
        'page_limit': 50,
      });

      final users = (data as List)
          .map((e) => AdminUserEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        users: page == 0 ? users : [...state.users, ...users],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load users: $e');
    }
  }

  void setUserSearch(String q) {
    state = state.copyWith(userSearchQuery: q);
    loadUsers(reset: true);
  }

  void setRoleFilter(String role) {
    state = state.copyWith(userRoleFilter: role);
    loadUsers(reset: true);
  }

  void toggleBannedFilter() {
    state = state.copyWith(showBannedOnly: !state.showBannedOnly);
    loadUsers(reset: true);
  }

  // ─── User Actions ─────────────────────────────────────

  Future<bool> changeUserRole(String userId, String newRole) async {
    try {
      await _db.from('profiles').update({'role': newRole}).eq('id', userId);
      await _logModerationAction(action: 'role_change', targetType: 'user', targetId: userId, reason: 'Role changed to $newRole');
      _updateUserLocally(userId, role: newRole);
      _addLiveEvent(LiveEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: LiveEventType.userBanned,
        description: 'User role changed to $newRole',
        at: DateTime.now(),
      ));
      return true;
    } catch (_) { return false; }
  }

  Future<bool> banUser(String userId, String reason) async {
    try {
      await _db.from('profiles').update({'is_banned': true}).eq('id', userId);
      await _db.from('user_flags').insert({
        'user_id': userId,
        'flagged_by': _db.auth.currentUser?.id,
        'flag_type': 'ban',
        'reason': reason,
        'is_active': true,
      });
      await _logModerationAction(action: 'ban', targetType: 'user', targetId: userId, reason: reason);
      _updateUserLocally(userId, isBanned: true);
      _addLiveEvent(LiveEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: LiveEventType.userBanned,
        description: 'User banned: $reason',
        userId: userId,
        at: DateTime.now(),
      ));
      return true;
    } catch (_) { return false; }
  }

  Future<bool> unbanUser(String userId) async {
    try {
      await _db.from('profiles').update({'is_banned': false}).eq('id', userId);
      await _db.from('user_flags').update({'is_active': false})
          .eq('user_id', userId).eq('flag_type', 'ban');
      await _logModerationAction(action: 'unban', targetType: 'user', targetId: userId);
      _updateUserLocally(userId, isBanned: false);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> warnUser(String userId, String reason) async {
    try {
      // Try inserting into user_flags — table may not exist in all envs, so swallow errors
      try {
        await _db.from('user_flags').insert({
          'user_id': userId,
          'flagged_by': _db.auth.currentUser?.id,
          'flag_type': 'warn',
          'reason': reason,
          'is_active': true,
        });
      } catch (_) {}

      // Always log to moderation_actions (best-effort)
      await _logModerationAction(action: 'warn', targetType: 'user', targetId: userId, reason: reason);

      // Optionally send a warning email if we have the user's email
      try {
        final profile = await _db
            .from('profiles')
            .select('email, name')
            .eq('id', userId)
            .single();
        final email = profile['email'] as String? ?? '';
        final name  = profile['name']  as String? ?? 'Student';
        if (email.isNotEmpty) {
          await emailUser(
            toEmail: email,
            toName: name,
            subject: 'Important notice from MindBridge Support',
            message: reason,
            fromAdminName: 'MindBridge Admin',
          );
        }
      } catch (_) {}

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _db.from('profiles').delete().eq('id', userId);
      state = state.copyWith(users: state.users.where((u) => u.id != userId).toList());
      return true;
    } catch (_) { return false; }
  }

  void _updateUserLocally(String userId, {String? role, bool? isBanned}) {
    final updated = state.users.map((u) {
      if (u.id != userId) return u;
      return AdminUserEntry(
        id: u.id, email: u.email, name: u.name,
        university: u.university, yearOfStudy: u.yearOfStudy,
        faculty: u.faculty,
        role: role ?? u.role,
        isBanned: isBanned ?? u.isBanned,
        onboardingCompleted: u.onboardingCompleted,
        createdAt: u.createdAt,
        moodCount: u.moodCount,
      );
    }).toList();
    state = state.copyWith(users: updated);
  }

  // ─── Email User ───────────────────────────────────────

  Future<bool> emailUser({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
    required String fromAdminName,
  }) async {
    try {
      // 1. Send via backend SMTP
      final sent = await _postBackend('/api/email/admin_message', {
        'to_email': toEmail,
        'to_name': toName,
        'subject': subject,
        'message': message,
        'from_admin': fromAdminName,
      });

      // 2. Log to admin_broadcasts (best-effort — ignore if table missing columns)
      try {
        await _db.from('admin_broadcasts').insert({
          'title': subject,
          'body': message,
          'target': 'user:$toEmail',
          'sent_by': _db.auth.currentUser?.id,
          'recipient_count': 1,
        });
      } catch (_) {}

      // 3. Log moderation action (best-effort)
      await _logModerationAction(
        action: 'email',
        targetType: 'user',
        targetId: toEmail,
        reason: 'Email sent: $subject',
      );

      return sent;
    } catch (_) {
      return false;
    }
  }

  /// Real HTTP POST to the Dart Frog backend.
  Future<bool> _postBackend(String path, Map<String, dynamic> body) async {
    try {
      final base = dotenv.maybeGet('BACKEND_URL') ?? 'http://localhost:3001';
      final res = await http.post(
        Uri.parse('$base$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Community Moderation ─────────────────────────────

  Future<void> loadPosts({String filter = 'all'}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      dynamic query = _db.from('community_posts').select(
          'id, user_id, content, tag, post_type, is_anonymous, anon_handle, is_pinned, is_flagged, is_hidden, author_name, created_at');

      if (filter == 'flagged') query = query.eq('is_flagged', true);
      else if (filter == 'hidden') query = query.eq('is_hidden', true);
      else if (filter == 'anonymous') query = query.eq('is_anonymous', true);
      else if (filter == 'pinned') query = query.eq('is_pinned', true);

      final data = await (query as dynamic).order('created_at', ascending: false).limit(100);

      final posts = (data as List)
          .map((e) => CommunityPostAdmin.fromJson(e as Map<String, dynamic>))
          .toList();

      // Batch reaction + comment counts
      if (posts.isNotEmpty) {
        final ids = posts.map((p) => p.id).toList();
        final reactions = await _db.from('community_reactions').select('post_id').inFilter('post_id', ids);
        final comments = await _db.from('community_comments').select('post_id').inFilter('post_id', ids);
        final Map<String, int> rc = {}, cc = {};
        for (final r in reactions as List) rc[r['post_id'] as String] = (rc[r['post_id']] ?? 0) + 1;
        for (final c in comments as List) cc[c['post_id'] as String] = (cc[c['post_id']] ?? 0) + 1;
        for (final p in posts) { p.reactionCount = rc[p.id] ?? 0; p.commentCount = cc[p.id] ?? 0; }
      }

      state = state.copyWith(isLoading: false, posts: posts);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> hidePost(String postId, {bool hide = true}) async {
    try {
      await _db.from('community_posts').update({'is_hidden': hide}).eq('id', postId);
      await _logModerationAction(action: 'hide', targetType: 'post', targetId: postId);
      _updatePostLocally(postId, isHidden: hide);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> pinPost(String postId, {bool pin = true}) async {
    try {
      await _db.from('community_posts').update({'is_pinned': pin}).eq('id', postId);
      await _logModerationAction(action: 'pin', targetType: 'post', targetId: postId);
      _updatePostLocally(postId, isPinned: pin);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> unflagPost(String postId) async {
    try {
      await _db.from('community_posts').update({'is_flagged': false}).eq('id', postId);
      _updatePostLocally(postId, isFlagged: false);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _db.from('community_posts').delete().eq('id', postId);
      await _logModerationAction(action: 'delete', targetType: 'post', targetId: postId);
      state = state.copyWith(posts: state.posts.where((p) => p.id != postId).toList());
      return true;
    } catch (_) { return false; }
  }

  void _updatePostLocally(String postId, {bool? isHidden, bool? isPinned, bool? isFlagged}) {
    final updated = state.posts.map((p) {
      if (p.id != postId) return p;
      p.isHidden = isHidden ?? p.isHidden;
      p.isPinned = isPinned ?? p.isPinned;
      p.isFlagged = isFlagged ?? p.isFlagged;
      return p;
    }).toList();
    state = state.copyWith(posts: updated);
  }

  // ─── Broadcasts ───────────────────────────────────────

  Future<void> loadBroadcasts() async {
    try {
      final data = await _db
          .from('admin_broadcasts')
          .select('id, title, body, target, sent_at, recipient_count')
          .order('sent_at', ascending: false)
          .limit(50);
      final records = (data as List)
          .map((e) => BroadcastRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(broadcasts: records);
    } catch (_) {}
  }

  Future<bool> sendBroadcast({
    required String title,
    required String body,
    required String target,
    String channel = 'inapp',
  }) async {
    try {
      // Count recipients via stats (already loaded or use total)
      int count = state.stats.totalUsers;

      await _db.from('admin_broadcasts').insert({
        'title': title, 'body': body, 'target': target,
        'sent_by': _db.auth.currentUser?.id,
        'recipient_count': count,
        'channel': channel,
      });

      // If email broadcast, log intent (actual send would be via backend)
      if (channel == 'email' || channel == 'both') {
        await _logModerationAction(
          action: 'warn', targetType: 'user', targetId: 'broadcast:$target',
          reason: 'Email broadcast: $title',
        );
      }

      await loadBroadcasts();
      return true;
    } catch (_) { return false; }
  }

  // ─── Moderation Log ───────────────────────────────────

  Future<void> loadModerationLog() async {
    try {
      final data = await _db
          .from('moderation_actions')
          .select('id, action, target_type, target_id, reason, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      final log = (data as List)
          .map((e) => ModerationAction.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(moderationLog: log);
    } catch (_) {}
  }

  Future<void> _logModerationAction({
    required String action,
    required String targetType,
    required String targetId,
    String? reason,
  }) async {
    try {
      await _db.from('moderation_actions').insert({
        'admin_id': _db.auth.currentUser?.id,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
      });
    } catch (_) {}
  }

  // ─── Analytics ────────────────────────────────────────

  Future<Map<String, int>> loadFeatureUsage() async {
    try {
      final raw = await _db.rpc('admin_get_feature_usage');
      final j = raw as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    } catch (_) { return {}; }
  }

  Future<Map<String, int>> loadUniversityBreakdown() async {
    try {
      final data = await _db.rpc('admin_get_university_breakdown');
      final Map<String, int> counts = {};
      for (final row in data as List) {
        final uni = row['university'] as String? ?? 'Unknown';
        counts[uni] = (row['user_count'] as num?)?.toInt() ?? 0;
      }
      return Map.fromEntries(counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    } catch (_) { return {}; }
  }

  Future<Map<String, int>> loadMoodDistribution() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final data = await _db.from('mood_logs').select('mood_score').gte('created_at', since);
      final Map<String, int> dist = {for (int i = 1; i <= 10; i++) '$i': 0};
      for (final row in data as List) {
        final score = row['mood_score']?.toString() ?? '5';
        dist[score] = (dist[score] ?? 0) + 1;
      }
      return dist;
    } catch (_) { return {}; }
  }

  Future<Map<String, int>> loadHourlyActivity() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final data = await _db.from('mood_logs').select('created_at').gte('created_at', since);
      final Map<String, int> byHour = {for (int i = 0; i < 24; i++) '$i': 0};
      for (final row in data as List) {
        final dt = DateTime.parse(row['created_at'] as String).toLocal();
        byHour['${dt.hour}'] = (byHour['${dt.hour}'] ?? 0) + 1;
      }
      return byHour;
    } catch (_) { return {}; }
  }

  // ─── Create User ─────────────────────────────────────

  Future<Map<String, dynamic>?> createUser({
    required String name,
    required String email,
    String? university,
    String role = 'user',
  }) async {
    try {
      final raw = await _db.rpc('admin_create_user', params: {
        'p_email': email.trim().toLowerCase(),
        'p_name': name.trim(),
        'p_university': university?.trim(),
        'p_role': role,
      });
      final j = raw as Map<String, dynamic>;
      await loadUsers(reset: true);
      return j;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<bool> resetUserPassword(String email) async {
    try {
      await _db.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── User Detail ──────────────────────────────────────

  Future<Map<String, dynamic>> loadUserDetail(String userId) async {
    try {
      final raw = await _db.rpc('admin_get_user_detail', params: {'target_user_id': userId});
      final j = raw as Map<String, dynamic>;
      return {
        'profile': j['profile'],
        'moodLogs': j['mood_logs'] ?? [],
        'journalCount': (j['journal_count'] as num?)?.toInt() ?? 0,
        'chatSessions': j['chat_sessions'] ?? [],
        'streaks': j['streaks'] ?? [],
        'flags': j['flags'] ?? [],
        'achievements': j['achievements'] ?? [],
      };
    } catch (_) { return {}; }
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────

final adminProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) => AdminNotifier());
