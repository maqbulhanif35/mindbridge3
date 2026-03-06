import 'dart:math';
import '../models/mood_model.dart';
import '../theme/design_tokens.dart';

/// WellnessScore breakdown showing per-component contribution.
class WellnessBreakdown {
  final double totalScore;
  final double moodComponent;
  final double consistencyComponent;
  final double sleepComponent;
  final double activityComponent;
  final double engagementComponent;
  final WellnessBand band;
  final double previousScore;
  final double scoreDelta;

  const WellnessBreakdown({
    required this.totalScore,
    required this.moodComponent,
    required this.consistencyComponent,
    required this.sleepComponent,
    required this.activityComponent,
    required this.engagementComponent,
    required this.band,
    required this.previousScore,
    required this.scoreDelta,
  });

  bool get isImproving => scoreDelta > 0;
  bool get isDeclining => scoreDelta < 0;
  bool get isStable => scoreDelta.abs() < 2;

  String get trendDescription {
    if (isImproving) return '+${scoreDelta.toStringAsFixed(1)} pts this week';
    if (isDeclining) return '${scoreDelta.toStringAsFixed(1)} pts this week';
    return 'Stable this week';
  }
}

/// Engine that computes a holistic Wellness Score (0–100) from user data.
///
/// Score formula:
///   score = moodComponent(0.35) + consistencyComponent(0.20)
///         + sleepComponent(0.20) + activityComponent(0.15)
///         + engagementComponent(0.10)
class WellnessEngine {
  static const _moodWeight = 0.35;
  static const _consistencyWeight = 0.20;
  static const _sleepWeight = 0.20;
  static const _activityWeight = 0.15;
  static const _engagementWeight = 0.10;

  // Targets
  static const _targetSleepHours = 7.5;
  static const _targetStreakDays = 7;
  static const _positiveEmotions = {
    'happy', 'grateful', 'excited', 'hopeful', 'calm', 'proud', 'content',
    'energized', 'confident', 'peaceful', 'joyful', 'inspired',
  };

  /// Compute a full wellness breakdown from 7 days of mood entries
  /// and optional engagement counts (journal entries, chat sessions).
  static WellnessBreakdown compute({
    required List<MoodEntry> last7DayEntries,
    required List<MoodEntry> previousWeekEntries,
    int currentStreakDays = 0,
    int journalEntriesThisWeek = 0,
    int chatSessionsThisWeek = 0,
  }) {
    final mood = _computeMoodComponent(last7DayEntries);
    final consistency = _computeConsistencyComponent(
      last7DayEntries,
      currentStreakDays,
    );
    final sleep = _computeSleepComponent(last7DayEntries);
    final activity = _computeActivityComponent(last7DayEntries);
    final engagement = _computeEngagementComponent(
      journalEntriesThisWeek,
      chatSessionsThisWeek,
    );

    final total = (mood * _moodWeight +
            consistency * _consistencyWeight +
            sleep * _sleepWeight +
            activity * _activityWeight +
            engagement * _engagementWeight)
        .clamp(0.0, 100.0);

    // Compute previous week's score for delta
    final prevMood = _computeMoodComponent(previousWeekEntries);
    final prevConsistency = _computeConsistencyComponent(previousWeekEntries, 0);
    final prevSleep = _computeSleepComponent(previousWeekEntries);
    final prevActivity = _computeActivityComponent(previousWeekEntries);
    final prevTotal = (prevMood * _moodWeight +
            prevConsistency * _consistencyWeight +
            prevSleep * _sleepWeight +
            prevActivity * _activityWeight +
            50.0 * _engagementWeight)
        .clamp(0.0, 100.0);

    return WellnessBreakdown(
      totalScore: total,
      moodComponent: mood,
      consistencyComponent: consistency,
      sleepComponent: sleep,
      activityComponent: activity,
      engagementComponent: engagement,
      band: WellnessTokens.bandFor(total),
      previousScore: prevTotal,
      scoreDelta: total - prevTotal,
    );
  }

  // ─── Component Calculators ────────────────────────────

  /// Average mood score normalized 0–100. Weight recent days heavier.
  static double _computeMoodComponent(List<MoodEntry> entries) {
    if (entries.isEmpty) return 50.0; // neutral default

    // Weighted average — more recent entries count more
    double weightedSum = 0;
    double totalWeight = 0;
    for (int i = 0; i < entries.length; i++) {
      final weight = (i + 1).toDouble(); // older entries = lower index = lower weight
      weightedSum += entries[i].moodScore * weight;
      totalWeight += weight;
    }
    final avg = weightedSum / totalWeight;
    // Normalize: mood 1–10 → 0–100
    return ((avg - 1) / 9.0 * 100).clamp(0.0, 100.0);
  }

  /// Consistency: how regularly user has been logging (streak + coverage).
  static double _computeConsistencyComponent(
    List<MoodEntry> entries,
    int currentStreakDays,
  ) {
    if (entries.isEmpty) return 0.0;

    // Coverage: unique days with at least one entry out of last 7 days
    final days = entries.map((e) => _dayKey(e.createdAt)).toSet();
    final coverage = (days.length / 7.0).clamp(0.0, 1.0);

    // Streak bonus: streak normalized against 7-day target
    final streakRatio = (currentStreakDays / _targetStreakDays).clamp(0.0, 1.5);

    return ((coverage * 0.6 + min(streakRatio, 1.0) * 0.4) * 100)
        .clamp(0.0, 100.0);
  }

  /// Sleep component: average sleep hours vs 7.5hr target.
  static double _computeSleepComponent(List<MoodEntry> entries) {
    final withSleep = entries.where((e) => e.sleepHours != null).toList();
    if (withSleep.isEmpty) return 50.0; // no data → neutral

    final avgSleep =
        withSleep.map((e) => e.sleepHours!).reduce((a, b) => a + b) /
            withSleep.length;

    // Optimal: 7–9 hours → 100; penalize under/over
    if (avgSleep >= 7 && avgSleep <= 9) return 100.0;
    if (avgSleep < 4) return 0.0;
    if (avgSleep > 11) return 30.0;

    if (avgSleep < 7) {
      return ((avgSleep - 4) / 3.0 * 100).clamp(0.0, 100.0);
    } else {
      return (100.0 - (avgSleep - 9) / 2.0 * 30).clamp(0.0, 100.0);
    }
  }

  /// Activity component: frequency of positive emotions logged.
  static double _computeActivityComponent(List<MoodEntry> entries) {
    if (entries.isEmpty) return 50.0;

    int positiveCount = 0;
    int totalEmotions = 0;

    for (final entry in entries) {
      for (final emotion in entry.emotions) {
        totalEmotions++;
        if (_positiveEmotions.contains(emotion.toLowerCase())) {
          positiveCount++;
        }
      }
    }

    if (totalEmotions == 0) return 50.0;
    return (positiveCount / totalEmotions * 100).clamp(0.0, 100.0);
  }

  /// Engagement: using the app (journal + chat) as a self-care signal.
  static double _computeEngagementComponent(
    int journalEntries,
    int chatSessions,
  ) {
    // Target: 2 journal entries + 1 chat session per week = full marks
    final journalScore = (journalEntries / 2.0).clamp(0.0, 1.0) * 60;
    final chatScore = (chatSessions / 1.0).clamp(0.0, 1.0) * 40;
    return (journalScore + chatScore).clamp(0.0, 100.0);
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Compute a simplified score for display (no previous week comparison).
  static double quickScore({
    required List<MoodEntry> last7DayEntries,
    int streakDays = 0,
    int journalCount = 0,
    int chatCount = 0,
  }) {
    return compute(
      last7DayEntries: last7DayEntries,
      previousWeekEntries: [],
      currentStreakDays: streakDays,
      journalEntriesThisWeek: journalCount,
      chatSessionsThisWeek: chatCount,
    ).totalScore;
  }
}
