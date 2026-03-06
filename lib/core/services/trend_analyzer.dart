import 'dart:math';
import '../models/mood_model.dart';

/// Severity of a detected mood trend.
enum TrendSeverity { positive, neutral, warning, critical }

/// Result of a specific trend detection check.
class TrendAlert {
  final String id;
  final String title;
  final String message;
  final TrendSeverity severity;
  final TrendAlertType type;
  final Map<String, dynamic> metadata;

  const TrendAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.type,
    this.metadata = const {},
  });
}

enum TrendAlertType {
  decliningTrend,
  positiveMomentum,
  highVolatility,
  sleepDeficit,
  consecutiveLow,
  weeklyPatternLow,
  criticalMoodEntry,
  streakRisk,
}

/// Configuration for detection thresholds (can be user-personalized over time).
class MoodThresholds {
  // Single-entry thresholds
  static const int criticalMoodScore = 3; // ≤3 → crisis check-in
  static const int lowMoodScore = 4; // ≤4 → concerning

  // Multi-day thresholds
  static const int decliningTrendDays = 3; // N consecutive declining days
  static const int consecutiveLowDays = 2; // N consecutive days ≤ lowMoodScore

  // Sleep thresholds
  static const double sleepDeficitHours = 5.0; // <5hr → alert
  static const double optimalSleepMin = 7.0;
  static const double optimalSleepMax = 9.0;

  // Statistical thresholds
  static const double volatilityThreshold =
      2.5; // Std dev > 2.5 → high volatility

  // Trend detection
  static const int positiveStreakDays = 3; // N consecutive improving days
  static const double significantDropPoints = 2.0; // Drop ≥2 per day

  // Wellness score thresholds
  static const double criticalScoreDrop = 15.0; // Drop >15 in 48hrs
}

/// Detects patterns in mood data and generates actionable alerts.
class TrendAnalyzer {
  /// Run all trend detections on the provided mood entries.
  /// Entries should be sorted ascending by date (oldest first).
  static List<TrendAlert> analyze({
    required List<MoodEntry> entries,
    double? userBaseline, // user's personal average mood
  }) {
    if (entries.isEmpty) return [];

    final alerts = <TrendAlert>[];
    final sorted = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final baseline = userBaseline ?? _computeBaseline(sorted);

    // Run all checks
    _checkCriticalMoodEntry(sorted, alerts);
    _checkConsecutiveLow(sorted, alerts);
    _checkDecliningTrend(sorted, alerts, baseline);
    _checkPositiveMomentum(sorted, alerts, baseline);
    _checkVolatility(sorted, alerts);
    _checkSleepDeficit(sorted, alerts);
    _checkWeeklyPattern(sorted, alerts);

    return alerts;
  }

  /// User's personal baseline mood (rolling 30-day average).
  static double computePersonalBaseline(List<MoodEntry> entries) {
    return _computeBaseline(entries);
  }

  // ─── Detection Checks ─────────────────────────────────

  /// Immediate: single entry with critically low mood.
  static void _checkCriticalMoodEntry(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
  ) {
    final recent = entries.isNotEmpty ? entries.last : null;
    if (recent == null) return;

    if (recent.moodScore <= MoodThresholds.criticalMoodScore) {
      alerts.add(TrendAlert(
        id: 'critical_entry_${recent.id}',
        title: 'How are you really doing?',
        message:
            'You logged a very low mood. We\'re here for you — would you like to talk to Maya or access support resources?',
        severity: TrendSeverity.critical,
        type: TrendAlertType.criticalMoodEntry,
        metadata: {'moodScore': recent.moodScore, 'entryId': recent.id},
      ));
    }
  }

  /// 2+ consecutive days with mood ≤4.
  static void _checkConsecutiveLow(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
  ) {
    final byDay = _groupByDay(entries);
    if (byDay.length < MoodThresholds.consecutiveLowDays) return;

    final days = byDay.keys.toList()..sort();
    int streak = 0;

    for (final day in days) {
      final avg = _dayAverage(byDay[day]!);
      if (avg <= MoodThresholds.lowMoodScore) {
        streak++;
      } else {
        streak = 0;
      }

      if (streak >= MoodThresholds.consecutiveLowDays) {
        alerts.add(TrendAlert(
          id: 'consecutive_low_$day',
          title: 'Checking in on you',
          message:
              'You\'ve had ${streak} consecutive days feeling low. That\'s hard — '
              'Maya is here to listen, or you can browse calming resources.',
          severity: TrendSeverity.warning,
          type: TrendAlertType.consecutiveLow,
          metadata: {'consecutiveDays': streak, 'lastDay': day},
        ));
        break; // one alert is enough
      }
    }
  }

  /// 3+ consecutive days with mood below user's baseline.
  static void _checkDecliningTrend(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
    double baseline,
  ) {
    final byDay = _groupByDay(entries);
    final days = byDay.keys.toList()..sort();
    if (days.length < MoodThresholds.decliningTrendDays) return;

    // Check last N days are all declining
    final recentDays = days.reversed.take(MoodThresholds.decliningTrendDays).toList().reversed.toList();
    final averages = recentDays.map((d) => _dayAverage(byDay[d]!)).toList();

    bool declining = true;
    for (int i = 1; i < averages.length; i++) {
      if (averages[i] >= averages[i - 1]) {
        declining = false;
        break;
      }
    }

    final allBelowBaseline = averages.every((a) => a < baseline);

    if (declining && allBelowBaseline) {
      final drop = averages.first - averages.last;
      alerts.add(TrendAlert(
        id: 'declining_trend_${days.last}',
        title: 'Mood trending down',
        message:
            'Your mood has been declining for ${MoodThresholds.decliningTrendDays} days '
            '(down ${drop.toStringAsFixed(1)} points). '
            'A breathing exercise or journal entry might help — want to try?',
        severity: drop >= 3 ? TrendSeverity.warning : TrendSeverity.neutral,
        type: TrendAlertType.decliningTrend,
        metadata: {
          'dropPoints': drop,
          'averages': averages,
          'days': recentDays,
        },
      ));
    }
  }

  /// 3+ consecutive days above baseline — positive momentum.
  static void _checkPositiveMomentum(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
    double baseline,
  ) {
    final byDay = _groupByDay(entries);
    final days = byDay.keys.toList()..sort();
    if (days.length < MoodThresholds.positiveStreakDays) return;

    final recentDays = days.reversed.take(MoodThresholds.positiveStreakDays).toList().reversed.toList();
    final averages = recentDays.map((d) => _dayAverage(byDay[d]!)).toList();

    final allAboveBaseline = averages.every((a) => a > baseline);
    bool improving = true;
    for (int i = 1; i < averages.length; i++) {
      if (averages[i] <= averages[i - 1]) {
        improving = false;
        break;
      }
    }

    if (allAboveBaseline && improving) {
      alerts.add(TrendAlert(
        id: 'positive_momentum_${days.last}',
        title: 'You\'re on a roll! 🌟',
        message:
            'Your mood has been improving for ${MoodThresholds.positiveStreakDays} days in a row! '
            'What\'s working for you? Consider journaling about it to remember.',
        severity: TrendSeverity.positive,
        type: TrendAlertType.positiveMomentum,
        metadata: {'averages': averages},
      ));
    }
  }

  /// High mood volatility (std dev > threshold).
  static void _checkVolatility(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
  ) {
    if (entries.length < 5) return;

    final scores = entries.map((e) => e.moodScore.toDouble()).toList();
    final stdDev = _standardDeviation(scores);

    if (stdDev > MoodThresholds.volatilityThreshold) {
      alerts.add(TrendAlert(
        id: 'high_volatility',
        title: 'Emotional ups and downs',
        message:
            'Your mood has been quite variable lately. Grounding exercises '
            'like breathing or journaling can help create stability.',
        severity: TrendSeverity.warning,
        type: TrendAlertType.highVolatility,
        metadata: {'standardDeviation': stdDev},
      ));
    }
  }

  /// Sleep deficit: recent average below threshold.
  static void _checkSleepDeficit(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
  ) {
    final withSleep = entries.where((e) => e.sleepHours != null).toList();
    if (withSleep.length < 2) return;

    final recent = withSleep.reversed.take(3).toList();
    final avgSleep = recent.map((e) => e.sleepHours!).reduce((a, b) => a + b) /
        recent.length;

    if (avgSleep < MoodThresholds.sleepDeficitHours) {
      alerts.add(TrendAlert(
        id: 'sleep_deficit',
        title: 'Sleep might be affecting you',
        message:
            'You\'ve been averaging ${avgSleep.toStringAsFixed(1)} hours of sleep — '
            'below the recommended 7–9 hours. Poor sleep can significantly impact mood. '
            'Try a wind-down breathing exercise tonight.',
        severity: TrendSeverity.warning,
        type: TrendAlertType.sleepDeficit,
        metadata: {'avgSleep': avgSleep},
      ));
    }
  }

  /// Identify recurring low-mood days of the week.
  static void _checkWeeklyPattern(
    List<MoodEntry> entries,
    List<TrendAlert> alerts,
  ) {
    if (entries.length < 14) return; // need at least 2 weeks

    // Group by day-of-week
    final byDow = <int, List<double>>{};
    for (final e in entries) {
      final dow = e.createdAt.weekday; // 1=Mon, 7=Sun
      byDow.putIfAbsent(dow, () => []).add(e.moodScore.toDouble());
    }

    const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (final entry in byDow.entries) {
      if (entry.value.length < 2) continue;
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (avg <= MoodThresholds.lowMoodScore + 0.5) {
        final dayName = dayNames[entry.key];
        // Only alert if today is the day before this hard day
        final tomorrow = DateTime.now().weekday % 7 + 1;
        if (tomorrow == entry.key) {
          alerts.add(TrendAlert(
            id: 'weekly_pattern_dow_${entry.key}',
            title: 'Tomorrow tends to be tough',
            message:
                '$dayName has historically been a lower mood day for you. '
                'Would you like to set a positive intention for tomorrow?',
            severity: TrendSeverity.neutral,
            type: TrendAlertType.weeklyPatternLow,
            metadata: {'dayOfWeek': entry.key, 'avgMood': avg},
          ));
        }
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────

  static double _computeBaseline(List<MoodEntry> entries) {
    if (entries.isEmpty) return 5.0;
    return entries.map((e) => e.moodScore).reduce((a, b) => a + b) /
        entries.length;
  }

  static Map<String, List<MoodEntry>> _groupByDay(List<MoodEntry> entries) {
    final map = <String, List<MoodEntry>>{};
    for (final e in entries) {
      final key = _dayKey(e.createdAt);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  static double _dayAverage(List<MoodEntry> entries) {
    if (entries.isEmpty) return 5.0;
    return entries.map((e) => e.moodScore).reduce((a, b) => a + b) /
        entries.length;
  }

  static double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Compute sleep-mood correlation coefficient (Pearson's r).
  /// Returns null if insufficient data.
  static double? sleepMoodCorrelation(List<MoodEntry> entries) {
    final paired = entries
        .where((e) => e.sleepHours != null)
        .map((e) => (e.sleepHours!, e.moodScore.toDouble()))
        .toList();

    if (paired.length < 5) return null;

    final sleepVals = paired.map((p) => p.$1).toList();
    final moodVals = paired.map((p) => p.$2).toList();

    final n = paired.length;
    final sleepMean = sleepVals.reduce((a, b) => a + b) / n;
    final moodMean = moodVals.reduce((a, b) => a + b) / n;

    double numerator = 0;
    double sleepDenominator = 0;
    double moodDenominator = 0;

    for (int i = 0; i < n; i++) {
      final sd = sleepVals[i] - sleepMean;
      final md = moodVals[i] - moodMean;
      numerator += sd * md;
      sleepDenominator += sd * sd;
      moodDenominator += md * md;
    }

    final denom = sqrt(sleepDenominator * moodDenominator);
    if (denom == 0) return null;

    return numerator / denom;
  }

  /// Generate a natural-language insight about the sleep-mood relationship.
  static String? sleepMoodInsight(List<MoodEntry> entries) {
    final r = sleepMoodCorrelation(entries);
    if (r == null) return null;

    final absR = r.abs();
    if (absR < 0.3) return null; // weak, not worth mentioning

    final direction = r > 0 ? 'more' : 'less';
    final strength = absR >= 0.7
        ? 'strongly'
        : absR >= 0.5
            ? 'moderately'
            : 'somewhat';

    final pct = (absR * 100).round();
    return 'Your sleep $strength correlates with your mood ($pct% relationship). '
        'When you sleep $direction, your mood tends to be ${r > 0 ? "higher" : "lower"}.';
  }
}
