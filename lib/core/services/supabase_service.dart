import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';

// ─── Supabase Service ─────────────────────────────────────
// Single facade for all Supabase operations.

class SupabaseService {
  static sb.SupabaseClient get _db => sb.Supabase.instance.client;
  static sb.GoTrueClient get _auth => _db.auth;

  // ─── Auth ──────────────────────────────────────────────

  static sb.Session? get currentSession => _auth.currentSession;
  static sb.User? get currentUser => _auth.currentUser;
  static Stream<sb.AuthState> get authStream => _auth.onAuthStateChange;

  static Future<sb.AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _auth.signUp(email: email, password: password);

  static Future<sb.AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => _auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email);

  static Future<void> resendVerificationEmail(String email) =>
      _auth.resend(type: sb.OtpType.signup, email: email);

  static Future<sb.AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) =>
      _auth.verifyOTP(
        email: email,
        token: token,
        type: sb.OtpType.signup,
      );

  static Future<void> refreshSession() => _auth.refreshSession();

  // ─── Profile CRUD ──────────────────────────────────────

  static Future<UserModel?> getProfile(String userId) async {
    final data = await _db
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  static Future<void> upsertProfile(UserModel user) async {
    await _db.from('profiles').upsert(user.toSupabaseJson());
  }

  static Future<UserModel?> updateProfile(
      String userId, Map<String, dynamic> data) async {
    final updated = await _db
        .from('profiles')
        .update(data)
        .eq('id', userId)
        .select()
        .single();
    return UserModel.fromJson(updated);
  }

  // ─── Chat sessions ─────────────────────────────────────

  static Future<Map<String, dynamic>> createChatSession(
      String userId) async {
    final data = await _db
        .from('chat_sessions')
        .insert({'user_id': userId, 'title': 'New conversation'})
        .select()
        .single();
    return data;
  }

  static Future<List<Map<String, dynamic>>> getChatSessions(
      String userId) async {
    final data = await _db
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> saveChatMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    await _db.from('chat_messages').insert({
      'session_id': sessionId,
      'role': role,
      'content': content,
    });
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(
      String sessionId) async {
    final data = await _db
        .from('chat_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Stores a 2-3 sentence AI-generated summary for a session.
  static Future<void> updateSessionSummary(
      String sessionId, String summary) async {
    try {
      await _db
          .from('chat_sessions')
          .update({'summary': summary, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', sessionId);
    } catch (_) {}
  }

  /// Returns the [limit] most recent non-null session summaries for a user.
  static Future<List<String>> getRecentSummaries(String userId,
      {int limit = 3}) async {
    try {
      final data = await _db
          .from('chat_sessions')
          .select('summary')
          .eq('user_id', userId)
          .not('summary', 'is', null)
          .order('updated_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((e) => e['summary'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Mood logs ─────────────────────────────────────────

  static Future<Map<String, dynamic>> logMood({
    required String userId,
    required int moodScore,
    required List<String> emotions,
    required List<String> activities,
    String? note,
    double? sleepHours,
  }) async {
    final data = await _db.from('mood_logs').insert({
      'user_id': userId,
      'mood_score': moodScore,
      'emotions': emotions,
      'activities': activities,
      'note': note,
      'sleep_hours': sleepHours,
    }).select().single();
    return data;
  }

  static Future<List<Map<String, dynamic>>> getMoodLogs(
      String userId, {int? days}) async {
    var q = _db.from('mood_logs').select().eq('user_id', userId);

    if (days != null) {
      final from = DateTime.now().subtract(Duration(days: days));
      q = q.gte('created_at', from.toIso8601String());
    }

    final data = await q.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Journal entries ───────────────────────────────────

  static Future<Map<String, dynamic>> createJournalEntry({
    required String userId,
    String? title,
    required String content,
    int? moodScore,
    List<String>? tags,
    bool isPrivate = true,
  }) async {
    final data = await _db.from('journal_entries').insert({
      'user_id': userId,
      'title': title,
      'content': content,
      'mood_score': moodScore,
      'tags': tags ?? [],
      'is_private': isPrivate,
    }).select().single();
    return data;
  }

  static Future<List<Map<String, dynamic>>> getJournalEntries(
      String userId) async {
    final data = await _db
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> deleteJournalEntry(String entryId) async {
    await _db.from('journal_entries').delete().eq('id', entryId);
  }

  // ─── OTP via Supabase Auth email ───────────────────────

  /// Sends a 6-digit OTP to [email] using Supabase's own email delivery.
  static Future<void> sendOtpEmail(String email) =>
      _auth.signInWithOtp(email: email, shouldCreateUser: false);

  /// Verifies the 6-digit [token] for [email] (type = email OTP).
  static Future<sb.AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) =>
      _auth.verifyOTP(
        email: email,
        token: token,
        type: sb.OtpType.email,
      );
}
