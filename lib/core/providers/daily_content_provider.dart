import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/daily_article_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'mood_provider.dart';

// ─── State ────────────────────────────────────────────────

enum DailyContentStatus { idle, loading, loaded, error }

class DailyContentState {
  final DailyContentStatus status;
  final List<DailyArticle> articles;
  final String? error;
  final String? cachedDate; // 'YYYY-MM-DD' — skip regen if same day

  const DailyContentState({
    this.status = DailyContentStatus.idle,
    this.articles = const [],
    this.error,
    this.cachedDate,
  });

  DailyContentState copyWith({
    DailyContentStatus? status,
    List<DailyArticle>? articles,
    String? error,
    String? cachedDate,
  }) =>
      DailyContentState(
        status: status ?? this.status,
        articles: articles ?? this.articles,
        error: error ?? this.error,
        cachedDate: cachedDate ?? this.cachedDate,
      );

  bool get isLoading => status == DailyContentStatus.loading;
  bool get hasArticles => articles.isNotEmpty;
}

// ─── Notifier ─────────────────────────────────────────────

class DailyContentNotifier extends StateNotifier<DailyContentState> {
  final Ref _ref;
  final http.Client _client = http.Client();

  static const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  String get _apiKey => (dotenv.env['GROQ_API_KEY'] ?? '').trim();

  DailyContentNotifier(this._ref) : super(const DailyContentState());

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadIfNeeded() async {
    final today = _todayKey();
    if (state.cachedDate == today && state.hasArticles) return;
    await generate();
  }

  Future<void> generate() async {
    if (_apiKey.isEmpty) return;
    state = state.copyWith(status: DailyContentStatus.loading, error: null);

    try {
      final user = _ref.read(currentUserProvider);
      final moodState = _ref.read(moodProvider);
      final prompt = _buildPrompt(user, moodState);

      final response = await _client.post(
        Uri.parse(_groqUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 3000,
          'temperature': 0.75,
          'messages': [
            {'role': 'system', 'content': 'You are a mental wellness content curator. Always respond with valid JSON only — no markdown, no extra text.'},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode != 200) {
        state = state.copyWith(status: DailyContentStatus.error, error: 'Content unavailable right now.');
        return;
      }

      final body = jsonDecode(response.body);
      final raw = (body['choices'] as List).first['message']['content'] as String;

      // Strip markdown code fences if present
      final cleaned = raw
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final List<dynamic> list = jsonDecode(cleaned) as List;
      final now = DateTime.now();
      final articles = list
          .asMap()
          .entries
          .map((e) {
            final map = Map<String, dynamic>.from(e.value as Map);
            map['id'] = '${_todayKey()}_${e.key}';
            return DailyArticle.fromJson(map, now);
          })
          .toList();

      state = state.copyWith(
        status: DailyContentStatus.loaded,
        articles: articles,
        cachedDate: _todayKey(),
      );
    } catch (_) {
      state = state.copyWith(
        status: DailyContentStatus.error,
        error: 'Could not load personalized content.',
      );
    }
  }

  // ─── Prompt Builder ─────────────────────────────────────

  String _buildPrompt(UserModel? user, MoodState moodState) {
    final goals = user?.goals.isNotEmpty == true
        ? user!.goals.join(', ')
        : 'general wellness';
    final stressors = user?.stressors.isNotEmpty == true
        ? user!.stressors.join(', ')
        : 'academic stress';
    final year = user?.yearLabel.isNotEmpty == true ? user!.yearLabel : 'university student';
    final faculty = user?.faculty ?? '';
    final therapyExp = user?.therapyExperience ?? 'never';
    final therapyCtx = switch (therapyExp) {
      'therapy' => 'has prior therapy experience',
      'apps' => 'has used wellness apps before',
      _ => 'new to mental health support',
    };

    // Recent mood context
    String moodCtx = '';
    if (moodState.entries.isNotEmpty) {
      final recent = moodState.entries.take(3).map((l) => l.moodScore.toDouble()).toList();
      final avg = recent.reduce((a, b) => a + b) / recent.length;
      moodCtx = avg < 4
          ? 'Their recent mood has been low (avg ${avg.toStringAsFixed(1)}/10), so prioritize supportive, hopeful content.'
          : avg > 7
              ? 'Their recent mood has been positive (avg ${avg.toStringAsFixed(1)}/10), so include growth-oriented content.'
              : 'Their recent mood is moderate, balance coping strategies with growth content.';
    }

    final today = DateTime.now();
    final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][today.weekday - 1];

    return '''Generate exactly 3 personalized mental wellness articles for a $year student${faculty.isNotEmpty ? ' studying $faculty' : ''}.

Student profile:
- Wellness goals: $goals
- Current stressors: $stressors
- Therapy background: $therapyCtx
- Today: $dayName
${moodCtx.isNotEmpty ? '- Mood context: $moodCtx' : ''}

Requirements:
- Each article must directly address their specific goals or stressors
- Make them practical, evidence-based, and immediately actionable
- Vary the format: one strategy guide, one science explainer, one quick-win tips
- Avoid generic advice — be specific to their profile
- Content should be 250-350 words each

Return ONLY a JSON array (no markdown, no extra text):
[
  {
    "title": "specific catchy title",
    "category": "one of: Anxiety|Focus|Sleep|Relationships|Stress|Confidence|Energy|Motivation|Mindfulness|Academic",
    "emoji": "single relevant emoji",
    "readTime": "X min read",
    "summary": "2 sentences that hook the reader and preview the value",
    "content": "full article text (250-350 words), use short paragraphs, practical and warm tone",
    "whyForYou": "one sentence explaining exactly why this is relevant to them personally"
  },
  ...
]''';
  }
}

// ─── Provider ─────────────────────────────────────────────

final dailyContentProvider =
    StateNotifierProvider<DailyContentNotifier, DailyContentState>((ref) {
  return DailyContentNotifier(ref);
});
