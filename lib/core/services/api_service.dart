import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:8080/api';
  static const String _anthropicUrl = 'https://api.anthropic.com/v1';

  late final Dio _dio;
  late final Dio _anthropicDio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _anthropicDio = Dio(BaseOptions(
      baseUrl: _anthropicUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'x-api-key': const String.fromEnvironment('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'),
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _refreshToken();
        }
        return handler.next(error);
      },
    ));
  }

  // ─── Auth Endpoints ───────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? university,
    int? yearOfStudy,
    List<String>? goals,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'university': university,
      'year_of_study': yearOfStudy,
      'goals': goals ?? [],
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    await _storage.deleteAll();
  }

  Future<void> _refreshToken() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return;
    final response = await _dio.post('/auth/refresh', data: {
      'refresh_token': refresh,
    });
    final newToken = response.data['access_token'] as String;
    await _storage.write(key: 'auth_token', value: newToken);
  }

  // ─── Chat Endpoints ───────────────────────────────────

  Future<Map<String, dynamic>> createChatSession() async {
    final response = await _dio.post('/chat/sessions');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChatSessions() async {
    final response = await _dio.get('/chat/sessions');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage({
    required String sessionId,
    required String content,
    required List<Map<String, String>> history,
  }) async {
    // Call Anthropic Claude API directly for real-time response
    final messages = [
      ...history,
      {'role': 'user', 'content': content},
    ];

    final response = await _anthropicDio.post('/messages', data: {
      'model': 'claude-haiku-4-5-20251001',
      'max_tokens': 1024,
      'system': _buildSystemPrompt(),
      'messages': messages,
    });

    final aiContent = response.data['content'][0]['text'] as String;

    // Save to backend
    await _dio.post('/chat/sessions/$sessionId/messages', data: {
      'user_message': content,
      'ai_message': aiContent,
    });

    return {
      'content': aiContent,
      'is_crisis_detected': _detectCrisis(content),
    };
  }

  bool _detectCrisis(String message) {
    final crisisKeywords = [
      'suicide',
      'kill myself',
      'want to die',
      'end my life',
      'self-harm',
      'hurt myself',
      "can't go on",
      'no reason to live',
      'better off dead',
      'overdose',
      'cutting myself',
    ];
    final lower = message.toLowerCase();
    return crisisKeywords.any((keyword) => lower.contains(keyword));
  }

  String _buildSystemPrompt() {
    return '''
You are Maya, an empathetic AI mental wellness companion for university students.
Use CBT, DBT, and mindfulness techniques. Be warm and non-judgmental.
Always recommend professional help for clinical concerns.
For crisis situations, always provide 988 Suicide & Crisis Lifeline information.
You are NOT a licensed therapist. Keep responses conversational and focused (2-4 paragraphs max).
''';
  }

  // ─── Mood Endpoints ───────────────────────────────────

  Future<Map<String, dynamic>> logMood({
    required int moodScore,
    required List<String> emotions,
    required List<String> activities,
    String? note,
    double? sleepHours,
  }) async {
    final response = await _dio.post('/mood', data: {
      'mood_score': moodScore,
      'emotions': emotions,
      'activities': activities,
      'note': note,
      'sleep_hours': sleepHours,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMoodEntries({int? days}) async {
    final response = await _dio.get('/mood', queryParameters: {
      if (days != null) 'days': days,
    });
    return response.data as List<dynamic>;
  }

  // ─── Journal Endpoints ────────────────────────────────

  Future<Map<String, dynamic>> createJournalEntry({
    String? title,
    required String content,
    int? moodScore,
    List<String>? tags,
    bool isPrivate = true,
  }) async {
    final response = await _dio.post('/journal', data: {
      'title': title,
      'content': content,
      'mood_score': moodScore,
      'tags': tags ?? [],
      'is_private': isPrivate,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJournalAiInsight(String entryId) async {
    final response = await _dio.post('/journal/$entryId/insight');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getJournalEntries() async {
    final response = await _dio.get('/journal');
    return response.data as List<dynamic>;
  }

  Future<void> deleteJournalEntry(String entryId) async {
    await _dio.delete('/journal/$entryId');
  }

  // ─── Resources Endpoints ──────────────────────────────

  Future<List<dynamic>> getResources({String? category}) async {
    final response = await _dio.get('/resources', queryParameters: {
      if (category != null) 'category': category,
    });
    return response.data as List<dynamic>;
  }

  // ─── Community Endpoints ──────────────────────────────

  Future<List<dynamic>> getCommunityPosts({String? category}) async {
    final response = await _dio.get('/community', queryParameters: {
      if (category != null) 'category': category,
    });
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCommunityPost({
    required String content,
    bool isAnonymous = true,
    String? category,
    List<String>? tags,
  }) async {
    final response = await _dio.post('/community', data: {
      'content': content,
      'is_anonymous': isAnonymous,
      'category': category,
      'tags': tags ?? [],
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> likePost(String postId) async {
    await _dio.post('/community/$postId/like');
  }

  // ─── User Profile ─────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/users/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final response = await _dio.patch('/users/me', data: data);
    return response.data as Map<String, dynamic>;
  }
}
