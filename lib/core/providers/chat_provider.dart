import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../services/supabase_service.dart';
import 'crisis_escalation_provider.dart';

// ─── Chat State ───────────────────────────────────────────

enum MayaStreamState { idle, thinking, streaming }

class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isTyping;
  final MayaStreamState streamState;
  final String? streamingContent;
  final String? errorMessage;
  final String? currentSessionId;
  final bool crisisDetected;
  final List<ChatSessionModel> sessions;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isTyping = false,
    this.streamState = MayaStreamState.idle,
    this.streamingContent,
    this.errorMessage,
    this.currentSessionId,
    this.crisisDetected = false,
    this.sessions = const [],
  });

  bool get isMayaResponding =>
      streamState == MayaStreamState.thinking ||
      streamState == MayaStreamState.streaming;

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isTyping,
    MayaStreamState? streamState,
    String? streamingContent,
    bool clearStreamingContent = false,
    String? errorMessage,
    bool clearError = false,
    String? currentSessionId,
    bool? crisisDetected,
    List<ChatSessionModel>? sessions,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isTyping: isTyping ?? this.isTyping,
        streamState: streamState ?? this.streamState,
        streamingContent: clearStreamingContent
            ? null
            : streamingContent ?? this.streamingContent,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        currentSessionId: currentSessionId ?? this.currentSessionId,
        crisisDetected: crisisDetected ?? this.crisisDetected,
        sessions: sessions ?? this.sessions,
      );
}

// ─── Chat Notifier ────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  static const _uuid = Uuid();

  // Groq — free tier, ultra-fast inference on custom LPU chips
  // OpenAI-compatible API: https://console.groq.com/docs/openai
  static const _model = 'llama-3.3-70b-versatile';
  static const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  final Ref _ref;
  final http.Client _client = http.Client();

  String get _apiKey => (dotenv.env['GROQ_API_KEY'] ?? '').trim();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

  ChatNotifier(this._ref) : super(const ChatState()) {
    _init();
  }

  Future<void> _init() async {
    await startNewSession();
    await loadSessions();
  }

  Future<void> startNewSession() async {
    state = state.copyWith(isLoading: true);
    final userId = SupabaseService.currentUser?.id;
    try {
      if (userId != null) {
        final session = await SupabaseService.createChatSession(userId);
        state = state.copyWith(
          currentSessionId: session['id'] as String,
          messages: [],
          isLoading: false,
          crisisDetected: false,
          streamState: MayaStreamState.idle,
        );
      } else {
        state = state.copyWith(
          currentSessionId: _uuid.v4(),
          messages: [],
          isLoading: false,
        );
      }
    } catch (_) {
      state = state.copyWith(
        currentSessionId: _uuid.v4(),
        messages: [],
        isLoading: false,
      );
    }
  }

  Future<void> loadSessions() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      final raw = await SupabaseService.getChatSessions(userId);
      final sessions = raw.map((e) => ChatSessionModel.fromJson(e)).toList();
      state = state.copyWith(sessions: sessions);
    } catch (_) {}
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    if (_apiKey.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Groq API key not configured. Add GROQ_API_KEY to .env',
      );
      return;
    }

    final sessionId = state.currentSessionId ?? _uuid.v4();

    // Build conversation history BEFORE adding the new user message.
    // Groq uses OpenAI format: system / user / assistant roles.
    final history = state.messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => {
              'role': m.role.name, // 'user' | 'assistant'
              'content': m.content,
            })
        .toList();

    final userMsg = MessageModel(
      id: _uuid.v4(),
      chatSessionId: sessionId,
      role: MessageRole.user,
      content: content.trim(),
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      streamState: MayaStreamState.thinking,
      clearStreamingContent: true,
      clearError: true,
      crisisDetected: false,
    );

    // Crisis detection
    final crisisNotifier = _ref.read(crisisEscalationProvider.notifier);
    final crisisTier = await crisisNotifier.analyzeText(content);
    final isCrisis = crisisTier.requiresAction;
    if (isCrisis) state = state.copyWith(crisisDetected: true);

    try {
      final aiContent = await _callGroq(
        history: history,
        userContent: content.trim(),
        systemPrompt: _buildSystemPrompt(),
      );

      await _finalizeAIMessage(
        sessionId: sessionId,
        content: aiContent,
        isCrisis: isCrisis,
      );
    } catch (e) {
      final msgs = List<MessageModel>.from(state.messages)..removeLast();
      state = state.copyWith(
        messages: msgs,
        streamState: MayaStreamState.idle,
        clearStreamingContent: true,
        errorMessage: _humanError(e),
      );
    }
  }

  /// Groq uses the OpenAI-compatible chat completions API.
  Future<String> _callGroq({
    required List<Map<String, String>> history,
    required String userContent,
    required String systemPrompt,
  }) async {
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'temperature': 0.85,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...history,
        {'role': 'user', 'content': userContent},
      ],
    });

    final response = await _client.post(
      Uri.parse(_groqUrl),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // OpenAI format: choices[0].message.content
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw _GroqException(200, 'No response returned from Groq.');
      }
      final message = choices.first['message'] as Map<String, dynamic>?;
      final text = message?['content'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw _GroqException(200, 'Empty response from Groq.');
      }
      return text.trim();
    }

    // Parse Groq error body for a meaningful message
    String detail = '';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      detail = error?['message'] as String? ?? response.body;
    } catch (_) {
      detail = response.body;
    }
    throw _GroqException(response.statusCode, detail);
  }

  String _humanError(Object e) {
    if (e is http.ClientException) {
      return 'Network error — check your internet connection.';
    }
    if (e is _GroqException) {
      final s = e.statusCode;
      final d = e.detail.isNotEmpty ? ' (${e.detail})' : '';
      if (s == 400) return 'Bad request$d';
      if (s == 401) return 'Invalid Groq API key — check GROQ_API_KEY in .env';
      if (s == 403) return 'API key does not have access$d';
      if (s == 404) return 'Groq model "$_model" not found$d';
      if (s == 413) return 'Conversation too long — start a new chat.';
      if (s == 429) return 'Groq rate limit reached — wait a moment and try again.';
      if (s >= 500) return 'Groq service is temporarily unavailable.';
      if (s == 200) return 'Maya couldn\'t generate a response — please try again.';
      return 'Groq error ($s)$d';
    }
    return 'Unable to reach Maya — please try again.';
  }

  Future<void> _finalizeAIMessage({
    required String sessionId,
    required String content,
    required bool isCrisis,
  }) async {
    final aiMsg = MessageModel(
      id: _uuid.v4(),
      chatSessionId: sessionId,
      role: MessageRole.assistant,
      content: content,
      isCrisisDetected: isCrisis,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      streamState: MayaStreamState.idle,
      clearStreamingContent: true,
      crisisDetected: isCrisis,
    );

    // Persist to Supabase (best-effort)
    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      SupabaseService.saveChatMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: content,
      ).catchError((_) {});
    }
  }

  String _buildSystemPrompt() {
    final hour = DateTime.now().hour;
    final timeOfDay =
        hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';
    return '''You are Maya, a warm, empathetic AI mental wellness companion for university students. It is currently $timeOfDay.

Your approach:
- Use CBT, DBT, and mindfulness-based techniques naturally — never in a clinical or robotic way
- Always validate feelings before offering perspective or suggestions
- Keep responses conversational (2-3 short paragraphs max unless the user needs more detail)
- Be genuinely warm and caring, like a trusted friend who also happens to understand mental health
- Adapt your tone: lighter and encouraging in the morning, warmer and calming in the evening

Important:
- For any mention of self-harm or crisis, always provide the 988 Suicide & Crisis Lifeline
- You are NOT a licensed therapist — recommend professional help when clinically appropriate
- Do not mention Groq, LLaMA, or any underlying model — you are Maya
- Do not start every message with "I" — vary your sentence openers''';
  }

  void dismissCrisisAlert() => state = state.copyWith(crisisDetected: false);
  void clearError() => state = state.copyWith(clearError: true);
}

// ─── Internal exception ────────────────────────────────────

class _GroqException implements Exception {
  final int statusCode;
  final String detail;
  const _GroqException(this.statusCode, [this.detail = '']);
}

// ─── Provider ─────────────────────────────────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
