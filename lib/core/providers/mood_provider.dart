import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood_model.dart';
import '../models/streak_model.dart';
import '../services/supabase_service.dart';
import '../services/wellness_engine.dart';
import '../services/trend_analyzer.dart';

// ─── Mood State ───────────────────────────────────────────

class MoodState {
  final List<MoodEntry> entries;
  final List<JournalEntry> journalEntries;
  final bool isLoading;
  final String? errorMessage;
  final MoodEntry? todayEntry;
  final WellnessBreakdown? wellnessBreakdown;
  final List<TrendAlert> activeAlerts;
  final StreakModel? moodStreak;

  const MoodState({
    this.entries = const [],
    this.journalEntries = const [],
    this.isLoading = false,
    this.errorMessage,
    this.todayEntry,
    this.wellnessBreakdown,
    this.activeAlerts = const [],
    this.moodStreak,
  });

  MoodState copyWith({
    List<MoodEntry>? entries,
    List<JournalEntry>? journalEntries,
    bool? isLoading,
    String? errorMessage,
    MoodEntry? todayEntry,
    bool clearTodayEntry = false,
    WellnessBreakdown? wellnessBreakdown,
    List<TrendAlert>? activeAlerts,
    StreakModel? moodStreak,
  }) =>
      MoodState(
        entries: entries ?? this.entries,
        journalEntries: journalEntries ?? this.journalEntries,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        todayEntry: clearTodayEntry ? null : todayEntry ?? this.todayEntry,
        wellnessBreakdown: wellnessBreakdown ?? this.wellnessBreakdown,
        activeAlerts: activeAlerts ?? this.activeAlerts,
        moodStreak: moodStreak ?? this.moodStreak,
      );

  double get averageMood {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.moodScore).reduce((a, b) => a + b) /
        entries.length;
  }

  List<MoodEntry> get last7Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return entries.where((e) => e.createdAt.isAfter(cutoff)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<MoodEntry> get last30Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return entries.where((e) => e.createdAt.isAfter(cutoff)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<MoodEntry> get previousWeek {
    final start = DateTime.now().subtract(const Duration(days: 14));
    final end = DateTime.now().subtract(const Duration(days: 7));
    return entries
        .where((e) => e.createdAt.isAfter(start) && e.createdAt.isBefore(end))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Map<String, int> get emotionFrequency {
    final map = <String, int>{};
    for (final entry in entries) {
      for (final emotion in entry.emotions) {
        map[emotion] = (map[emotion] ?? 0) + 1;
      }
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Day-of-week mood averages (1=Mon...7=Sun).
  Map<int, double> get dayOfWeekAverages {
    final byDow = <int, List<int>>{};
    for (final e in entries) {
      byDow.putIfAbsent(e.createdAt.weekday, () => []).add(e.moodScore);
    }
    return byDow.map(
      (dow, scores) =>
          MapEntry(dow, scores.reduce((a, b) => a + b) / scores.length),
    );
  }

  /// Heatmap data: date string → mood score.
  Map<DateTime, int> get heatmapData {
    final map = <DateTime, int>{};
    for (final e in entries) {
      final day = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      // Use highest mood score if multiple entries in one day
      if (!map.containsKey(day) || e.moodScore > map[day]!) {
        map[day] = e.moodScore;
      }
    }
    return map;
  }

  double get wellnessScore => wellnessBreakdown?.totalScore ?? 0.0;
  int get currentStreakDays => moodStreak?.currentStreak ?? 0;

  List<TrendAlert> get criticalAlerts =>
      activeAlerts.where((a) => a.severity == TrendSeverity.critical).toList();
  List<TrendAlert> get warningAlerts =>
      activeAlerts.where((a) => a.severity == TrendSeverity.warning).toList();
  List<TrendAlert> get positiveAlerts =>
      activeAlerts.where((a) => a.severity == TrendSeverity.positive).toList();
}

// ─── Mood Notifier ────────────────────────────────────────

class MoodNotifier extends StateNotifier<MoodState> {
  static const _anthropicUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

  late final Dio _dio;

  MoodNotifier() : super(const MoodState()) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'x-api-key': _apiKey,
        // Required for Flutter Web — allows direct browser → Anthropic calls
        'anthropic-dangerous-direct-browser-access': 'true',
      },
    ));
    loadMoodEntries();
    loadJournalEntries();
  }

  Future<void> loadMoodEntries({int days = 90}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final raw = await SupabaseService.getMoodLogs(userId, days: days);
      final entries = raw.map(MoodEntry.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final today = DateTime.now();
      final todayEntry = entries.firstWhere(
        (e) =>
            e.createdAt.year == today.year &&
            e.createdAt.month == today.month &&
            e.createdAt.day == today.day,
        orElse: () => MoodEntry(
          id: '',
          userId: '',
          moodScore: 0,
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        entries: entries,
        isLoading: false,
        todayEntry: todayEntry.id.isNotEmpty ? todayEntry : null,
      );

      // Compute wellness score and trend alerts
      _computeWellnessData(entries);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _computeWellnessData(List<MoodEntry> entries) {
    final sorted = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final last7 = state.last7Days;
    final prevWeek = state.previousWeek;

    final breakdown = WellnessEngine.compute(
      last7DayEntries: last7,
      previousWeekEntries: prevWeek,
      currentStreakDays: state.currentStreakDays,
      journalEntriesThisWeek: state.journalEntries
          .where((j) => j.createdAt.isAfter(
              DateTime.now().subtract(const Duration(days: 7))))
          .length,
    );

    final alerts = TrendAnalyzer.analyze(entries: sorted);

    state = state.copyWith(
      wellnessBreakdown: breakdown,
      activeAlerts: alerts,
    );
  }

  Future<bool> logMood({
    required int moodScore,
    required List<String> emotions,
    required List<String> activities,
    String? note,
    double? sleepHours,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    try {
      final data = await SupabaseService.logMood(
        userId: userId,
        moodScore: moodScore,
        emotions: emotions,
        activities: activities,
        note: note,
        sleepHours: sleepHours,
      );
      final entry = MoodEntry.fromJson(data);
      state = state.copyWith(
        entries: [entry, ...state.entries],
        todayEntry: entry,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadJournalEntries() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      final raw = await SupabaseService.getJournalEntries(userId);
      final entries = raw.map(JournalEntry.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(journalEntries: entries);
    } catch (_) {}
  }

  Future<bool> createJournalEntry({
    String? title,
    required String content,
    int? moodScore,
    List<String>? tags,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    try {
      final data = await SupabaseService.createJournalEntry(
        userId: userId,
        title: title,
        content: content,
        moodScore: moodScore,
        tags: tags,
      );
      final entry = JournalEntry.fromJson(data);
      state = state.copyWith(
        journalEntries: [entry, ...state.journalEntries],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getJournalInsight(String content) async {
    if (_apiKey.isEmpty) return null;
    try {
      final response = await _dio.post(_anthropicUrl, data: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 512,
        'messages': [
          {
            'role': 'user',
            'content':
                'In 2-3 concise sentences, provide a compassionate psychological insight about this journal entry. Focus on patterns, strengths, or gentle suggestions.\n\nJournal entry:\n$content'
          }
        ],
      }));
      return response.data['content'][0]['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteJournalEntry(String entryId) async {
    try {
      await SupabaseService.deleteJournalEntry(entryId);
      state = state.copyWith(
        journalEntries:
            state.journalEntries.where((e) => e.id != entryId).toList(),
      );
    } catch (_) {}
  }
}

// ─── Provider ─────────────────────────────────────────────

final moodProvider = StateNotifierProvider<MoodNotifier, MoodState>((ref) {
  return MoodNotifier();
});
