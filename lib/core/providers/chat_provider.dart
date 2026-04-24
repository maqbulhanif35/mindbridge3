import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../services/goal_technique_engine.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';
import 'crisis_escalation_provider.dart';
import 'mood_provider.dart';
import 'streak_provider.dart';
import '../models/streak_model.dart';

// ─── Chat State ────────────────────────────────────────────────────────────────

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
  final List<String> recentSummaries;
  final bool isGeneratingOpening;
  final bool useLocalModel;

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
    this.recentSummaries = const [],
    this.isGeneratingOpening = false,
    this.useLocalModel = false,
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
    List<String>? recentSummaries,
    bool? isGeneratingOpening,
    bool? useLocalModel,
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
        recentSummaries: recentSummaries ?? this.recentSummaries,
        isGeneratingOpening: isGeneratingOpening ?? this.isGeneratingOpening,
        useLocalModel: useLocalModel ?? this.useLocalModel,
      );
}

// ─── Chat Notifier ─────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  static const _uuid = Uuid();
  static const _model = 'llama-3.3-70b-versatile';
  static const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _ollamaUrl = 'http://192.168.100.205:11434';
  static const _ollamaModel = 'llama3:8b';

  final Ref _ref;
  final http.Client _client = http.Client();

  // Try compile-time constant first (--dart-define for web), fall back to .env
  static const _compiledKey = String.fromEnvironment('GROQ_API_KEY');
  String get _apiKey {
    if (_compiledKey.isNotEmpty) return _compiledKey;
    return (dotenv.env['GROQ_API_KEY'] ?? '').trim();
  }
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

  ChatNotifier(this._ref) : super(const ChatState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadSummaries();
    await startNewSession();
    await loadSessions();
  }

  // ─── Session management ───────────────────────────────────────────────────

  Future<void> startNewSession() async {
    // If there are enough messages in the current session, summarise it first.
    final prev = state.messages
        .where((m) => m.role != MessageRole.system)
        .toList();
    if (prev.length >= 4 && state.currentSessionId != null) {
      _summariseInBackground(state.currentSessionId!, prev);
    }

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

    // Send Maya's personalised opening message.
    await _sendOpeningMessage();
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

  /// Load messages from a past session into the current view.
  Future<void> loadSession(String sessionId) async {
    state = state.copyWith(isLoading: true);
    try {
      final raw = await SupabaseService.getChatMessages(sessionId);
      final messages = raw.map((e) {
        final role = e['role'] as String? ?? 'user';
        return MessageModel(
          id: e['id']?.toString() ?? _uuid.v4(),
          chatSessionId: sessionId,
          role: MessageRole.values.firstWhere(
            (r) => r.name == role,
            orElse: () => MessageRole.user,
          ),
          content: e['content'] as String? ?? '',
          status: MessageStatus.sent,
          createdAt: e['created_at'] != null
              ? DateTime.parse(e['created_at'] as String)
              : DateTime.now(),
        );
      }).toList();
      state = state.copyWith(
        currentSessionId: sessionId,
        messages: messages,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── Send message ─────────────────────────────────────────────────────────

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    if (!state.useLocalModel && _apiKey.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Groq API key not configured. Add GROQ_API_KEY to .env',
      );
      return;
    }

    final sessionId = state.currentSessionId ?? _uuid.v4();

    // Build conversation history BEFORE adding the new user message.
    final history = state.messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => {'role': m.role.name, 'content': m.content})
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

    // Persist user message.
    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      SupabaseService.saveChatMessage(
        sessionId: sessionId,
        role: 'user',
        content: content.trim(),
      ).catchError((_) {});
    }

    // Crisis detection.
    final crisisNotifier = _ref.read(crisisEscalationProvider.notifier);
    final crisisTier = await crisisNotifier.analyzeText(content);
    final isCrisis = crisisTier.requiresAction;
    if (isCrisis) state = state.copyWith(crisisDetected: true);

    try {
      final aiContent = state.useLocalModel
          ? await _callOllama(
              history: history,
              userContent: content.trim(),
              systemPrompt: _buildLocalSystemPrompt(),
            )
          : await _callGroq(
              history: history,
              userContent: content.trim(),
              systemPrompt: _buildSystemPrompt(),
            );
      await _finalizeAIMessage(
          sessionId: sessionId, content: aiContent, isCrisis: isCrisis);
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

  void toggleLocalModel() {
    state = state.copyWith(useLocalModel: !state.useLocalModel);
  }

  // ─── Opening message ──────────────────────────────────────────────────────

  /// Generates a warm, data-driven opening message from Maya using the
  /// user's real-time mood data, trend alerts, streak, and session history.
  Future<void> _sendOpeningMessage() async {
    if (state.useLocalModel) return;
    if (_apiKey.isEmpty) return;

    final sessionId = state.currentSessionId;
    if (sessionId == null) return;

    state = state.copyWith(
      isGeneratingOpening: true,
      streamState: MayaStreamState.thinking,
    );

    final authState = _ref.read(authProvider);
    final name = authState.user?.preferredName ??
        authState.user?.name.split(' ').first ?? '';
    final summaries = state.recentSummaries;
    final moodState = _ref.read(moodProvider);

    // ── Real-time data block ──────────────────────────────
    final parts = <String>[];

    // Today's check-in
    final today = moodState.todayEntry;
    if (today != null) {
      final emos = today.emotions.isNotEmpty
          ? ', emotions: ${today.emotions.take(3).join(', ')}'
          : '';
      final sleep = today.sleepHours != null
          ? ', sleep last night: ${today.sleepHours!.toStringAsFixed(1)}h'
          : '';
      parts.add('Today\'s check-in: ${today.moodScore}/10 — ${today.moodLabel}$emos$sleep');
    }

    // 7-day trend
    final last7 = moodState.last7Days;
    if (last7.length >= 3) {
      final avg7 = last7.map((e) => e.moodScore).reduce((a, b) => a + b) /
          last7.length;
      final oldest = last7.take(3).map((e) => e.moodScore).reduce((a, b) => a + b) / 3;
      final newest = last7.reversed.take(3).map((e) => e.moodScore).reduce((a, b) => a + b) / 3;
      final trend = newest > oldest + 0.5
          ? 'improving'
          : newest < oldest - 0.5
              ? 'declining'
              : 'stable';
      parts.add(
          '7-day mood avg: ${avg7.toStringAsFixed(1)}/10, trend: $trend');
    }

    // Top emotions this week
    final topEmotions = moodState.emotionFrequency.entries
        .take(3)
        .map((e) => e.key)
        .toList();
    if (topEmotions.isNotEmpty) {
      parts.add('Most frequent emotions this week: ${topEmotions.join(', ')}');
    }

    // Streak
    final streak = moodState.currentStreakDays;
    if (streak > 1) parts.add('Current check-in streak: $streak days');

    // Wellness score
    final ws = moodState.wellnessScore;
    if (ws > 0) {
      final band = ws >= 80
          ? 'thriving'
          : ws >= 60
              ? 'growing'
              : ws >= 40
                  ? 'steady'
                  : ws >= 20
                      ? 'struggling'
                      : 'critical';
      parts.add('Wellness score: ${ws.toStringAsFixed(0)}/100 ($band)');
    }

    // Active alerts
    final critical = moodState.criticalAlerts;
    final warnings = moodState.warningAlerts;
    final positive = moodState.positiveAlerts;
    if (critical.isNotEmpty) {
      parts.add('IMPORTANT — critical alert: ${critical.first.message}');
    } else if (warnings.isNotEmpty) {
      parts.add('Active concern: ${warnings.first.message}');
    } else if (positive.isNotEmpty) {
      parts.add('Positive pattern: ${positive.first.message}');
    }

    // Previous session memory
    if (summaries.isNotEmpty) {
      final ago = ['Last chat', '2 chats ago', '3 chats ago'];
      for (var i = 0; i < summaries.length && i < 3; i++) {
        parts.add('${ago[i]}: ${summaries[i]}');
      }
    }

    final contextNote = '\n\nReal-time user data:\n${parts.map((p) => '· $p').join('\n')}';

    // ── Build instruction based on what stands out most ──
    String instruction;
    if (critical.isNotEmpty) {
      instruction =
          'Generate a warm, caring (2-3 sentence) opening that gently acknowledges the critical concern shown in the data. '
          'Lead with empathy, not advice. Ask one gentle open question. Do NOT use clinical language.';
    } else if (today != null && today.moodScore <= 3) {
      instruction =
          'Generate a warm, supportive (2-3 sentence) opening that acknowledges today\'s low mood score specifically. '
          'Validate that it\'s okay to have hard days. Ask what\'s been on their mind.';
    } else if (today != null && today.moodScore >= 8) {
      instruction =
          'Generate an uplifting (2-3 sentence) opening that celebrates today\'s strong mood. '
          'Reference any positive patterns in the data naturally. Keep energy high and curious.';
    } else if (summaries.isNotEmpty) {
      instruction =
          'Generate a warm (2-3 sentence) opening. Reference something specific from a previous conversation naturally '
          'and connect it to the current data. Ask a thoughtful follow-up. Do NOT say "session".';
    } else if (today == null) {
      instruction =
          'Generate a warm, brief (2-3 sentence) opening that gently invites the user to share how they\'re feeling today. '
          'Be genuine and curious, not robotic.';
    } else {
      instruction =
          'Generate a warm, brief (2-3 sentence) opening that references something specific from the real-time data above. '
          'Show you know this particular person. End with a genuine open question.';
    }

    try {
      final opening = await _callGroq(
        history: [],
        userContent: '[Maya opening message instruction — do NOT quote this back]: $instruction',
        systemPrompt: _buildSystemPrompt() + contextNote,
      );

      final openingMsg = MessageModel(
        id: _uuid.v4(),
        chatSessionId: sessionId,
        role: MessageRole.assistant,
        content: opening,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [openingMsg],
        streamState: MayaStreamState.idle,
        isGeneratingOpening: false,
      );

      // Persist opening message.
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        SupabaseService.saveChatMessage(
          sessionId: sessionId,
          role: 'assistant',
          content: opening,
        ).catchError((_) {});
      }
    } catch (_) {
      state = state.copyWith(
        streamState: MayaStreamState.idle,
        isGeneratingOpening: false,
      );
    }
  }

  // ─── Session summary ──────────────────────────────────────────────────────

  /// Generates a brief summary of [messages] and saves it to the session row.
  /// Runs in the background — never awaited by the caller.
  void _summariseInBackground(
      String sessionId, List<MessageModel> messages) async {
    if (_apiKey.isEmpty) return;
    try {
      final convo = messages
          .map((m) =>
              '${m.role == MessageRole.user ? 'Student' : 'Maya'}: ${m.content}')
          .join('\n');

      final summary = await _callGroq(
        history: [],
        userContent: convo,
        systemPrompt:
            'You are summarising a mental wellness chat. Write 2 sentences in third person about the student: what emotional topics came up and any key concerns or progress. Be concise and factual. No fluff.',
      );

      await SupabaseService.updateSessionSummary(sessionId, summary.trim());

      // Refresh in-memory summaries list.
      await _loadSummaries();
    } catch (_) {}
  }

  Future<void> _loadSummaries() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    final summaries =
        await SupabaseService.getRecentSummaries(userId, limit: 3);
    state = state.copyWith(recentSummaries: summaries);
  }

  // ─── Groq API ─────────────────────────────────────────────────────────────

  Future<String> _callGroq({
    required List<Map<String, dynamic>> history,
    required String userContent,
    required String systemPrompt,
  }) async {
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 600,
      'temperature': 0.70,
      'frequency_penalty': 0.45,
      'presence_penalty': 0.30,
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

  // ─── Ollama local model ───────────────────────────────────────────────────

  Future<String> _callOllama({
    required List<Map<String, dynamic>> history,
    required String userContent,
    required String systemPrompt,
  }) async {
    // Build a single prompt string: system + history + user turn.
    final buffer = StringBuffer();
    buffer.writeln('[System]\n$systemPrompt\n');
    for (final msg in history) {
      final role = msg['role'] == 'user' ? 'User' : 'Maya';
      buffer.writeln('[$role]\n${msg['content']}\n');
    }
    buffer.write('[User]\n$userContent');

    final request = http.Request(
      'POST',
      Uri.parse('$_ollamaUrl/api/generate'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': _ollamaModel,
      'prompt': buffer.toString(),
      'stream': true,
      "think":false,
    });

    http.StreamedResponse response;
    try {
      response = await _client.send(request);
      print("RESPONSE: $response");
    } catch (e) {
      print("OLLAMA-ERROR: $e");
      throw _OllamaException('Could not connect to the local model. Make sure Ollama is running on this network.');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw _OllamaException('Ollama returned ${response.statusCode}: $body');
    }

    state = state.copyWith(
      streamState: MayaStreamState.streaming,
      streamingContent: '',
    );

    final fullResponse = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      print("CHUNK: $chunk");
      if (chunk.trim().isEmpty) continue;
      try {
        final json = jsonDecode(chunk) as Map<String, dynamic>;
        final token = json['response'] as String? ?? '';
        if (token.isNotEmpty) {
          fullResponse.write(token);
          state = state.copyWith(
            streamState: MayaStreamState.streaming,
            streamingContent: fullResponse.toString(),
          );
        }
        if (json['done'] == true) break;
      } catch (_) {
        // Skip malformed lines.
      }
    }

    final result = fullResponse.toString().trim();
    if (result.isEmpty) throw _OllamaException('Empty response from local model.');
    return result;
  }

  // ─── Finalise AI message ──────────────────────────────────────────────────

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

    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      SupabaseService.saveChatMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: content,
      ).catchError((_) {});
    }

    // Record chat streak activity after first real user→AI exchange
    _ref.read(streakProvider.notifier).recordActivity(StreakType.chatSession);
  }

  // ─── System prompt ────────────────────────────────────────────────────────

  String _buildSystemPrompt() {
    final hour = DateTime.now().hour;
    final timeOfDay =
        hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';
    final dow = const [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ][DateTime.now().weekday - 1];

    final moodState = _ref.read(moodProvider);
    final authState = _ref.read(authProvider);
    final user = authState.user;

    final todayEntry = moodState.todayEntry;
    final recentEntries = moodState.entries.take(7).toList();
    final alerts = moodState.activeAlerts;
    final userName = user?.preferredName ?? user?.name.split(' ').first ?? '';

    double? avgMood;
    if (recentEntries.isNotEmpty) {
      avgMood = recentEntries
              .map((e) => e.moodScore.toDouble())
              .reduce((a, b) => a + b) /
          recentEntries.length;
    }

    // ── Profile context block ──────────────────────────────
    final ctx = <String>[];
    if (userName.isNotEmpty) ctx.add('Name: $userName');
    if (user?.university != null) ctx.add('University: ${user!.university}');
    if (user?.yearLabel.isNotEmpty == true) ctx.add('Year: ${user!.yearLabel}');
    if (user?.faculty != null) ctx.add('Studies: ${user!.faculty}');
    if (user?.goals.isNotEmpty == true) ctx.add('Wellness goals: ${user!.goals.join(', ')}');
    if (user?.stressors.isNotEmpty == true) ctx.add('Current stressors: ${user!.stressors.join(', ')}');
    if (user?.therapyExperience != null && user!.therapyExperience != 'never') {
      ctx.add('Mental health background: ${user.therapyExperience == 'therapy' ? 'has/had professional therapy' : 'has used wellness apps before'}');
    }

    // ── Current mood data ──────────────────────────────────
    if (todayEntry != null) {
      final emos = todayEntry.emotions.isNotEmpty
          ? ', emotions: ${todayEntry.emotions.join(', ')}'
          : '';
      final sleep = todayEntry.sleepHours != null
          ? ', sleep: ${todayEntry.sleepHours!.toStringAsFixed(1)}h'
          : '';
      ctx.add('Today\'s check-in: mood ${todayEntry.moodScore}/10 — ${todayEntry.moodLabel}$emos$sleep');
    }
    if (avgMood != null) {
      ctx.add('7-day avg: ${avgMood.toStringAsFixed(1)}/10 (${avgMood < 4 ? 'struggling' : avgMood < 6 ? 'steady' : avgMood < 8 ? 'growing' : 'thriving'})');
    }
    if (alerts.isNotEmpty) {
      ctx.add('Active alerts: ${alerts.map((a) => a.type.name).join(', ')} — be gentle and attentive');
    }

    final contextBlock = ctx.isNotEmpty
        ? '\n\n[User profile & current data — reference naturally, never quote directly]\n${ctx.map((p) => '· $p').join('\n')}'
        : '';

    // ── Clinical protocol per goal ────────────────────────
    final clinicalBlock = GoalTechniqueEngine.buildClinicalProtocolBlock(user);

    // ── Memory block (previous sessions) ──────────────────
    final summaries = state.recentSummaries;
    final memoryBlock = summaries.isNotEmpty
        ? '\n\n[Memory from previous conversations — weave in naturally to show continuity]\n${summaries.asMap().entries.map((e) {
            final labels = ['Last chat', '2 chats ago', '3 chats ago'];
            return '· ${labels[e.key]}: ${e.value}';
          }).join('\n')}'
        : '';

    // ── Personality-driven tone instructions ───────────────
    final personality = user?.mayaPersonality ?? 'warm';
    final toneBlock = switch (personality) {
      'direct' => '''
Your communication style — DIRECT & PRACTICAL:
- Lead with clear, actionable advice after validating feelings
- Use concise language — no filler or over-explanation
- Offer 1-2 concrete techniques with specific steps
- Be honest and straightforward, but never cold
- Skip lengthy affirmations — get to the point respectfully''',
      'playful' => '''
Your communication style — LIGHT & PLAYFUL:
- Use a warm, uplifting, slightly playful tone
- Occasional light humour is welcome if the moment allows
- Use relatable metaphors and comparisons
- Keep it breezy without minimising real struggles
- Celebrate wins enthusiastically''',
      _ => '''
Your communication style — WARM & SUPPORTIVE:
- Lead with deep empathy and validation before anything else
- Use soft, nurturing language — like a trusted older friend
- Take time to acknowledge feelings fully before suggestions
- Be gentle with any hard truths
- Use "I hear you", "that makes sense", "you're not alone"''',
    };

    return '''You are Maya, an AI mental wellness companion for university students in Kenya. It is $timeOfDay on $dow.$contextBlock$memoryBlock$clinicalBlock

$toneBlock

Kenyan campus context (use naturally, never force it):
- Students here face unique pressures: HELB loan delays, CAT (Continuous Assessment Test) weeks, attachment/internship stress, hostel life, matatu commutes, family financial expectations
- Common stressors: "I'll miss CATs", "HELB hasn't disbursed", "attachment is unpaid", "unit retakes", "semester exam timetable clashes"
- University calendar: Semester 1 (Sep-Jan), Semester 2 (Feb-Jun), with CATs roughly mid-semester
- Kenyan universities: UoN, JKUAT, Strathmore, KU, MMU, TU, Kabarak, Daystar, USIU, Moi, Egerton, Maseno and others
- Acknowledge the reality of studying while supporting family, hustling for fees, and managing campus social pressures

RESPONSE RULES — follow these strictly every single reply:
1. Your FIRST sentence must directly address what the user just said — no preamble
2. If they ask a question, answer it first — then empathise
3. If they vent or share a problem, reflect their specific words back — not generic comfort
4. If they mention something specific (HELB, CAT, attachment, a name, a situation) — address THAT, not a generic version
5. Keep replies to 2–4 sentences unless they share something complex that needs depth
6. NEVER reuse the same opening phrase within 3 messages (e.g., don't say "I hear you" twice in a row)
7. NEVER start your reply with "Of course!", "Absolutely!", "Great!", "Sure!" or any filler affirmation — go straight to the response
8. Do NOT explain what you are about to do — just do it
9. Vary how you start every reply — opener words must differ each time (not always "I")
10. Never repeat advice you already gave in this conversation unless asked again
11. Do NOT address the user by name in replies — you know their name from the profile but use it at most once during the very opening message only, never in regular conversation replies. Overusing names feels robotic and salesy.

Markdown formatting — the app renders your replies with full markdown support:
- Use **bold** for technique names, key terms, or important points
- Use bullet lists (- item) when giving multiple tips, options, or steps
- Use numbered lists (1. item) for sequential instructions or ranked suggestions
- Use tables when asked for comparisons, top-N lists, or structured data — format: | Column | Column |\n|---|---|\n| cell | cell | — always include a header row and the separator line
- Use > blockquotes to highlight an affirmation, quote, or reframe
- Keep conversational, emotional, or short replies as plain prose — never over-structure empathetic responses
- Use ### headers ONLY for very long detailed plans the user explicitly requested
- When asked for "top 10", "best ways to", "compare", or any ranked/structured list — ALWAYS use a formatted table or numbered list, NEVER write paragraphs

Core approach:
- Use CBT, DBT, and mindfulness techniques naturally — never clinical or robotic
- Validate feelings before offering perspective or suggestions
- Reference today's mood data and past conversation naturally when relevant
- Adapt tone: energising in morning, grounding in evening
- If declining mood trends or active alerts are in the data, gently check in
- Tailor all suggestions to their specific goals and stressors — not generic advice
- Normalise CAT/exam stress, HELB anxiety, and attachment pressure

Language:
- Always respond in clear, professional English by default
- Do NOT mix in Swahili, Sheng, or any other language unless the user explicitly writes to you in that language or asks you to
- If the user writes in Swahili or asks for Swahili, respond naturally in that language for that exchange
- Never insert Swahili phrases into English responses — it feels forced and unprofessional

Crisis & safety:
- For any mention of self-harm or crisis → refer to Befrienders Kenya: +254 722 178177 (free, 24/7) or Mathare Hospital: +254 20 2723200 or campus counseling unit
- You are NOT a licensed therapist — recommend professionals when appropriate
- Do not mention Groq, LLaMA, or any underlying model — you are Maya''';
  }

  // ─── Local system prompt (compact — preserves context window) ────────────

  String _buildLocalSystemPrompt() {
    final hour = DateTime.now().hour;
    final timeOfDay =
        hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';

    final moodState  = _ref.read(moodProvider);
    final authState  = _ref.read(authProvider);
    final user       = authState.user;
    final userName   = user?.preferredName ?? user?.name.split(' ').first ?? '';
    final todayEntry = moodState.todayEntry;

    final ctx = <String>[];
    if (userName.isNotEmpty) ctx.add('User: $userName');
    if (todayEntry != null) {
      ctx.add('Mood today: ${todayEntry.moodScore}/10 — ${todayEntry.moodLabel}');
    }

    final contextLine = ctx.isNotEmpty ? '\n${ctx.join(' | ')}' : '';

    return 'You are Maya, a mental wellness companion for university students in Kenya. '
        'It is $timeOfDay.$contextLine\n\n'
        'Your job: listen, empathise, and support using CBT and mindfulness. '
        'You are NOT a therapist — suggest professional help when needed.\n\n'
        'Rules:\n'
        '- 2–3 sentence replies unless the topic needs depth\n'
        '- Empathise before advising\n'
        '- Address what the user actually said — no generic comfort\n'
        '- Never open with filler ("Of course!", "Absolutely!", "Great!")\n'
        '- Crisis → Befrienders Kenya 0800 723 253 (free 24/7) or campus counselling\n'
        '- Respond in English. You are Maya — never reveal an underlying AI model.';
  }

  // ─── Error helpers ────────────────────────────────────────────────────────

  String _humanError(Object e) {
    if (e is _OllamaException) return e.message;
    if (e is http.ClientException) return 'Network error — check your connection.';
    if (e is _GroqException) {
      final s = e.statusCode;
      final d = e.detail.isNotEmpty ? ' (${e.detail})' : '';
      if (s == 400) return 'Bad request$d';
      if (s == 401) return 'Invalid Groq API key — check GROQ_API_KEY in .env';
      if (s == 403) return 'API key does not have access$d';
      if (s == 404) return 'Groq model "$_model" not found$d';
      if (s == 413) return 'Conversation too long — start a new chat.';
      if (s == 429) return 'Rate limit reached — wait a moment and try again.';
      if (s >= 500) return 'Groq is temporarily unavailable.';
      if (s == 200) return 'Maya couldn\'t respond — please try again.';
      return 'Groq error ($s)$d';
    }
    return 'Unable to reach Maya — please try again.';
  }

  void dismissCrisisAlert() => state = state.copyWith(crisisDetected: false);
  void clearError() => state = state.copyWith(clearError: true);
}

// ─── String extension ─────────────────────────────────────────────────────────

extension _StringExt on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ─── Internal exception ───────────────────────────────────────────────────────

class _GroqException implements Exception {
  final int statusCode;
  final String detail;
  const _GroqException(this.statusCode, [this.detail = '']);
}

class _OllamaException implements Exception {
  final String message;
  const _OllamaException(this.message);
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
