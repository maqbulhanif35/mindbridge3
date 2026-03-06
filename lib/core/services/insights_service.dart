import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_model.dart';
import 'trend_analyzer.dart';

/// A generated insight from the AI.
class WellnessInsight {
  final String id;
  final String title;
  final String body;
  final InsightType type;
  final DateTime generatedAt;
  final Map<String, dynamic> metadata;

  const WellnessInsight({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.generatedAt,
    this.metadata = const {},
  });
}

enum InsightType {
  weeklyReport,
  pattern,
  prediction,
  correlation,
  recommendation,
}

/// Service that generates AI-powered personal wellness insights
/// using Claude as the intelligence layer.
class InsightsService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';
  final String _apiKey;
  final Dio _dio;

  InsightsService({required String apiKey})
      : _apiKey = apiKey,
        _dio = Dio();

  // ─── Weekly Wellness Report ───────────────────────────

  /// Generate a personalized weekly wellness summary (every Sunday).
  Future<WellnessInsight?> generateWeeklyReport({
    required List<MoodEntry> last7DayEntries,
    required List<MoodEntry> previousWeekEntries,
    required String userName,
    double? wellnessScore,
  }) async {
    if (last7DayEntries.isEmpty) return null;

    final now = DateTime.now();
    final cacheKey = 'weekly_report_${now.year}_${_weekNumber(now)}';
    final cached = await _getCached(cacheKey);
    if (cached != null) return cached;

    final avgMood = last7DayEntries.isEmpty
        ? 5.0
        : last7DayEntries.map((e) => e.moodScore).reduce((a, b) => a + b) /
            last7DayEntries.length;

    final prevAvg = previousWeekEntries.isEmpty
        ? avgMood
        : previousWeekEntries.map((e) => e.moodScore).reduce((a, b) => a + b) /
            previousWeekEntries.length;

    final topEmotions = _topEmotions(last7DayEntries, 3);
    final topActivities = _topActivities(last7DayEntries, 3);

    final prompt = '''
You are Maya, a compassionate AI mental wellness companion for university students.

Generate a brief, warm, personalized weekly wellness report for ${userName.isNotEmpty ? userName : "the user"}.

Data this week:
- Average mood: ${avgMood.toStringAsFixed(1)}/10 (previous week: ${prevAvg.toStringAsFixed(1)}/10)
- Trend: ${avgMood > prevAvg ? "improving" : avgMood < prevAvg ? "declining" : "stable"}
- Days logged: ${last7DayEntries.map((e) => e.createdAt.day).toSet().length}/7
- Wellness score: ${wellnessScore?.toStringAsFixed(0) ?? "N/A"}/100
- Most common emotions: ${topEmotions.isEmpty ? "not recorded" : topEmotions.join(", ")}
- Activities noted: ${topActivities.isEmpty ? "not recorded" : topActivities.join(", ")}

Write a 3-paragraph report:
1. Warm acknowledgment of the week (2 sentences)
2. Key observation about their patterns (2-3 sentences, be specific to their data)
3. One gentle, actionable suggestion for next week (2 sentences)

Keep it under 120 words total. Use "you" not third person. No markdown formatting.
''';

    final result = await _callClaude(prompt);
    if (result == null) return null;

    final insight = WellnessInsight(
      id: cacheKey,
      title: 'Your Week in Review',
      body: result,
      type: InsightType.weeklyReport,
      generatedAt: now,
      metadata: {
        'avgMood': avgMood,
        'prevAvgMood': prevAvg,
        'daysLogged': last7DayEntries.map((e) => e.createdAt.day).toSet().length,
      },
    );

    await _saveToCache(cacheKey, insight);
    return insight;
  }

  // ─── Pattern Insights ─────────────────────────────────

  /// Generate sleep-mood correlation insight if data shows a pattern.
  WellnessInsight? generateSleepMoodInsight(List<MoodEntry> entries) {
    final insight = TrendAnalyzer.sleepMoodInsight(entries);
    if (insight == null) return null;

    return WellnessInsight(
      id: 'sleep_mood_correlation',
      title: 'Sleep & Mood Connection',
      body: insight,
      type: InsightType.correlation,
      generatedAt: DateTime.now(),
    );
  }

  /// Generate day-of-week pattern insight.
  WellnessInsight? generateDayOfWeekInsight(List<MoodEntry> entries) {
    if (entries.length < 14) return null;

    final byDow = <int, List<double>>{};
    for (final e in entries) {
      byDow.putIfAbsent(e.createdAt.weekday, () => [])
          .add(e.moodScore.toDouble());
    }

    // Find best and worst days
    final dayAvgs = byDow.map(
      (dow, scores) =>
          MapEntry(dow, scores.reduce((a, b) => a + b) / scores.length),
    );

    if (dayAvgs.length < 4) return null;

    final sorted = dayAvgs.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    const dayNames = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final bestDay = dayNames[sorted.last.key];
    final worstDay = dayNames[sorted.first.key];
    final bestAvg = sorted.last.value;
    final worstAvg = sorted.first.value;

    if ((bestAvg - worstAvg) < 1.5) return null; // not enough variance

    return WellnessInsight(
      id: 'dow_pattern',
      title: 'Your Weekly Rhythm',
      body:
          'You tend to feel best on ${bestDay}s (avg ${bestAvg.toStringAsFixed(1)}/10) '
          'and find ${worstDay}s more challenging (avg ${worstAvg.toStringAsFixed(1)}/10). '
          'Knowing this helps you plan self-care on tougher days.',
      type: InsightType.pattern,
      generatedAt: DateTime.now(),
      metadata: {'bestDay': bestDay, 'worstDay': worstDay},
    );
  }

  /// Generate a journaling impact insight.
  WellnessInsight? generateJournalingImpactInsight(
    List<MoodEntry> moodEntries,
    List<JournalEntry> journalEntries,
  ) {
    if (journalEntries.length < 5 || moodEntries.length < 10) return null;

    // Find mood on days with/without journaling
    final journalDays = journalEntries.map((j) => _dayKey(j.createdAt)).toSet();
    final moodOnJournalDays = moodEntries
        .where((m) => journalDays.contains(_dayKey(m.createdAt)))
        .map((m) => m.moodScore.toDouble())
        .toList();
    final moodOnOtherDays = moodEntries
        .where((m) => !journalDays.contains(_dayKey(m.createdAt)))
        .map((m) => m.moodScore.toDouble())
        .toList();

    if (moodOnJournalDays.isEmpty || moodOnOtherDays.isEmpty) return null;

    final journalAvg = moodOnJournalDays.reduce((a, b) => a + b) /
        moodOnJournalDays.length;
    final otherAvg = moodOnOtherDays.reduce((a, b) => a + b) /
        moodOnOtherDays.length;

    final diff = journalAvg - otherAvg;
    if (diff.abs() < 0.5) return null;

    final direction = diff > 0 ? 'higher' : 'lower';
    final directionAbs = diff.abs().toStringAsFixed(1);

    return WellnessInsight(
      id: 'journaling_impact',
      title: 'Journaling Effect',
      body:
          'On days you journal, your mood is $directionAbs points $direction on average '
          '(${journalAvg.toStringAsFixed(1)} vs ${otherAvg.toStringAsFixed(1)}). '
          '${diff > 0 ? "Writing seems to positively impact your wellbeing!" : "Journaling may help you process difficult days."}',
      type: InsightType.correlation,
      generatedAt: DateTime.now(),
      metadata: {'journalAvg': journalAvg, 'otherAvg': otherAvg},
    );
  }

  // ─── Predictive Suggestions ───────────────────────────

  /// Generate a proactive suggestion based on upcoming patterns.
  WellnessInsight? generatePredictiveSuggestion(List<MoodEntry> entries) {
    if (entries.length < 14) return null;

    final alerts = TrendAnalyzer.analyze(entries: entries);
    final weeklyPattern = alerts
        .where((a) => a.type == TrendAlertType.weeklyPatternLow)
        .toList();

    if (weeklyPattern.isEmpty) return null;

    final alert = weeklyPattern.first;
    return WellnessInsight(
      id: 'predictive_${alert.id}',
      title: 'Heads Up for Tomorrow',
      body: alert.message,
      type: InsightType.prediction,
      generatedAt: DateTime.now(),
      metadata: alert.metadata,
    );
  }

  // ─── Compile All Insights ─────────────────────────────

  /// Generate all available static insights from user data.
  List<WellnessInsight> generateStaticInsights({
    required List<MoodEntry> moodEntries,
    required List<JournalEntry> journalEntries,
  }) {
    final insights = <WellnessInsight>[];

    final sleep = generateSleepMoodInsight(moodEntries);
    if (sleep != null) insights.add(sleep);

    final dow = generateDayOfWeekInsight(moodEntries);
    if (dow != null) insights.add(dow);

    final journaling = generateJournalingImpactInsight(moodEntries, journalEntries);
    if (journaling != null) insights.add(journaling);

    final predictive = generatePredictiveSuggestion(moodEntries);
    if (predictive != null) insights.add(predictive);

    return insights;
  }

  // ─── Claude API ───────────────────────────────────────

  Future<String?> _callClaude(String prompt) async {
    try {
      final response = await _dio.post(
        _apiUrl,
        options: Options(
          headers: {
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
            'anthropic-dangerous-direct-browser-access': 'true',
            'content-type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: jsonEncode({
          'model': _model,
          'max_tokens': 300,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>;
        if (content.isNotEmpty) {
          return (content.first as Map<String, dynamic>)['text'] as String?;
        }
      }
    } catch (e) {
      debugPrint('InsightsService: Claude API error: $e');
    }
    return null;
  }

  // ─── Cache ────────────────────────────────────────────

  Future<WellnessInsight?> _getCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('insight_$key');
      if (json == null) return null;
      final map = jsonDecode(json) as Map<String, dynamic>;
      final generatedAt = DateTime.parse(map['generatedAt'] as String);
      // Cache valid for 7 days
      if (DateTime.now().difference(generatedAt).inDays >= 7) return null;
      return WellnessInsight(
        id: map['id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        type: InsightType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => InsightType.pattern,
        ),
        generatedAt: generatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(String key, WellnessInsight insight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'insight_$key',
        jsonEncode({
          'id': insight.id,
          'title': insight.title,
          'body': insight.body,
          'type': insight.type.name,
          'generatedAt': insight.generatedAt.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  // ─── Helpers ──────────────────────────────────────────

  List<String> _topEmotions(List<MoodEntry> entries, int n) {
    final counts = <String, int>{};
    for (final e in entries) {
      for (final emotion in e.emotions) {
        counts[emotion] = (counts[emotion] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  List<String> _topActivities(List<MoodEntry> entries, int n) {
    final counts = <String, int>{};
    for (final e in entries) {
      for (final activity in e.activities) {
        counts[activity] = (counts[activity] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    return date.difference(firstDayOfYear).inDays ~/ 7;
  }

  String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
