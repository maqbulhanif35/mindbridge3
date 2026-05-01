import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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
    String? name,
  }) =>
      _auth.signUp(
        email: email,
        password: password,
        // Store name in auth metadata so _loadProfile can recover it
        // even if the profiles table write fails before email verification.
        data: name != null && name.isNotEmpty ? {'full_name': name} : null,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );

  static Future<sb.AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => _auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email);

  /// Sends a 6-digit OTP via Magic Link — most reliable delivery method.
  static Future<void> sendVerificationOtp(String email) =>
      _auth.signInWithOtp(email: email, shouldCreateUser: false);

  static Future<void> resendVerificationEmail(String email) =>
      _auth.signInWithOtp(email: email, shouldCreateUser: false);

  static Future<sb.AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) =>
      _auth.verifyOTP(
        email: email,
        token: token,
        type: sb.OtpType.email, // matches Magic Link / signInWithOtp delivery
      );

  static Future<void> updatePassword(String newPassword) =>
      _auth.updateUser(sb.UserAttributes(password: newPassword));

  static Future<void> refreshSession() => _auth.refreshSession();

  static Future<void> signInWithGoogle() {
    // On web: redirect back to the app origin so supabase_flutter can
    // pick up the session from the URL hash automatically on reload.
    // IMPORTANT — add this origin to Supabase → Auth → URL Configuration → Redirect URLs.
    final redirectTo =
        kIsWeb ? '${Uri.base.origin}/' : 'com.mindbridge.app://login-callback';
    return _auth.signInWithOAuth(
      sb.OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb
          ? sb.LaunchMode.platformDefault // same-tab redirect on web
          : sb.LaunchMode.externalApplication,
    );
  }

  // ─── Admin API (requires service_role key) ─────────────

  static String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://fdkwqzeyrcvxgqlpbjnp.supabase.co';
  static String get _serviceRoleKey =>
      dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  /// Looks up a Supabase Auth user by email using the Admin API.
  /// Returns the user ID if found, null otherwise.
  static Future<String?> getUserIdByEmail(String email) async {
    if (_serviceRoleKey.isEmpty) {
      print('[SupabaseService] SUPABASE_SERVICE_ROLE_KEY not set');
      return null;
    }
    try {
      // The Admin API uses 'filter' param, not 'email'
      final encodedEmail = Uri.encodeComponent(email);
      final url = '$_supabaseUrl/auth/v1/admin/users?filter=$encodedEmail';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final users = body['users'] as List<dynamic>?;
        if (users != null && users.isNotEmpty) {
          for (final user in users) {
            final userEmail = (user['email'] as String?)?.toLowerCase();
            if (userEmail == email.toLowerCase()) {
              return user['id'] as String?;
            }
          }
        }
      }
      print(
          '[SupabaseService] getUserIdByEmail not found for $email (status: ${response.statusCode})');
      return null;
    } catch (e) {
      print('[SupabaseService] getUserIdByEmail error: $e');
      return null;
    }
  }

  /// Gets a user's display name from their profile.
  static Future<String?> getUserNameById(String userId) async {
    try {
      final profile = await getProfile(userId);
      return profile?.displayName;
    } catch (_) {
      return null;
    }
  }

  /// Updates a user's password via the Supabase Admin API.
  /// Verifies the user's email matches [expectedEmail] before updating.
  static Future<bool> updatePasswordViaAdmin(
      String userId, String expectedEmail, String newPassword) async {
    if (_serviceRoleKey.isEmpty) {
      print('[SupabaseService] SUPABASE_SERVICE_ROLE_KEY not set');
      return false;
    }
    try {
      final response = await http.put(
        Uri.parse('$_supabaseUrl/auth/v1/admin/users/$userId'),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': newPassword}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final responseEmail = (body['email'] as String?)?.toLowerCase();
        final normalizedExpected = expectedEmail.toLowerCase();
        if (responseEmail != normalizedExpected) {
          print(
              '[SupabaseService] updatePasswordViaAdmin email mismatch! response: $responseEmail, expected: $normalizedExpected');
          return false;
        }
        print(
            '[SupabaseService] ✓ Password updated for user $userId ($expectedEmail)');
        return true;
      }
      print(
          '[SupabaseService] updatePasswordViaAdmin failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('[SupabaseService] updatePasswordViaAdmin error: $e');
      return false;
    }
  }

  // ─── Profile CRUD ──────────────────────────────────────

  static Future<UserModel?> getProfile(String userId) async {
    final data =
        await _db.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  static Future<void> upsertProfile(UserModel user) async {
    await _db.from('profiles').upsert(
          user.toSupabaseJson(),
          onConflict: 'id',
          ignoreDuplicates: false,
        );
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

  static Future<Map<String, dynamic>> createChatSession(String userId) async {
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
      await _db.from('chat_sessions').update({
        'summary': summary,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', sessionId);
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
    final data = await _db
        .from('mood_logs')
        .insert({
          'user_id': userId,
          'mood_score': moodScore,
          'emotions': emotions,
          'activities': activities,
          'note': note,
          'sleep_hours': sleepHours,
        })
        .select()
        .single();
    return data;
  }

  static Future<List<Map<String, dynamic>>> getMoodLogs(String userId,
      {int? days}) async {
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
    final data = await _db
        .from('journal_entries')
        .insert({
          'user_id': userId,
          'title': title,
          'content': content,
          'mood_score': moodScore,
          'tags': tags ?? [],
          'is_private': isPrivate,
        })
        .select()
        .single();
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
