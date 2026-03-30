import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────
// unified_status_engine.dart
//
// Single computation layer that derives all "today's status"
// signals from raw provider data.  Keeps UI widgets free of
// business logic and ensures every screen shares one source
// of truth for bands, rings, nudges and priority actions.
// ─────────────────────────────────────────────────────────

// ── Activity Ring ─────────────────────────────────────────

class ActivityRing {
  final String id;
  final String label;
  final String emoji;
  final bool completed;
  final Color color;
  final String route;

  const ActivityRing({
    required this.id,
    required this.label,
    required this.emoji,
    required this.completed,
    required this.color,
    required this.route,
  });
}

// ── Daily Rings ───────────────────────────────────────────

class DailyRings {
  final List<ActivityRing> rings;

  const DailyRings(this.rings);

  int get completedCount => rings.where((r) => r.completed).length;
  double get completionRatio => rings.isEmpty ? 0.0 : completedCount / rings.length;
  bool get allDone => completedCount == rings.length;

  String get motivationText {
    if (allDone) return 'All done today! 🎉';
    final remaining = rings.length - completedCount;
    if (completedCount == 0) return 'Start your daily practice';
    if (remaining == 1) return '$completedCount/${rings.length} done · One more to go!';
    return '$completedCount/${rings.length} done · Keep going!';
  }

  ActivityRing? get nextIncomplete =>
      rings.firstWhereOrNull((r) => !r.completed);
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

// ── Wellness Band Info ────────────────────────────────────

class WellnessBandInfo {
  final String band;
  final double score;
  final List<Color> gradientColors;
  final String emoji;
  final String label;
  final String motivationalLine;

  const WellnessBandInfo({
    required this.band,
    required this.score,
    required this.gradientColors,
    required this.emoji,
    required this.label,
    required this.motivationalLine,
  });

  static WellnessBandInfo from(double score) {
    if (score >= 80) {
      return WellnessBandInfo(
        band: 'thriving',
        score: score,
        gradientColors: const [
          Color(0xFF047857),
          Color(0xFF059669),
          Color(0xFF10B981),
        ],
        emoji: '🌟',
        label: 'Thriving',
        motivationalLine: 'You\'re doing wonderfully. Keep it up!',
      );
    } else if (score >= 60) {
      return WellnessBandInfo(
        band: 'growing',
        score: score,
        gradientColors: const [
          Color(0xFF0D7377),
          Color(0xFF00BEB4),
          Color(0xFF2DD4BF),
        ],
        emoji: '💚',
        label: 'Growing',
        motivationalLine: 'Good momentum. Small steps add up.',
      );
    } else if (score >= 40) {
      return WellnessBandInfo(
        band: 'steady',
        score: score,
        gradientColors: const [
          Color(0xFF1D4ED8),
          Color(0xFF2563EB),
          Color(0xFF3B82F6),
        ],
        emoji: '🙂',
        label: 'Steady',
        motivationalLine: 'You\'re holding on. One good habit at a time.',
      );
    } else if (score >= 20) {
      return WellnessBandInfo(
        band: 'struggling',
        score: score,
        gradientColors: const [
          Color(0xFFB45309),
          Color(0xFFD97706),
          Color(0xFFF59E0B),
        ],
        emoji: '🌱',
        label: 'Struggling',
        motivationalLine: 'Rough patch. Maya is here whenever you need.',
      );
    } else if (score > 0) {
      return WellnessBandInfo(
        band: 'critical',
        score: score,
        gradientColors: const [
          Color(0xFFB91C1C),
          Color(0xFFDC2626),
          Color(0xFFEF4444),
        ],
        emoji: '❤️',
        label: 'Critical',
        motivationalLine: 'Please reach out. You don\'t have to face this alone.',
      );
    } else {
      // No data yet — default teal
      return WellnessBandInfo(
        band: 'new',
        score: 0,
        gradientColors: const [
          Color(0xFF0D7377),
          Color(0xFF00BEB4),
          Color(0xFF0EA5E9),
        ],
        emoji: '👋',
        label: 'Getting started',
        motivationalLine: 'Start tracking to see your wellness score.',
      );
    }
  }

  /// Accent color (mid-gradient) for use in non-gradient contexts.
  Color get accentColor => gradientColors[1];

  /// Whether this band requires immediate attention.
  bool get needsAttention => band == 'critical' || band == 'struggling';
}

// ── Priority Action ───────────────────────────────────────

class PriorityAction {
  final String label;
  final String emoji;
  final String subtitle;
  final String route;
  final Color color;

  const PriorityAction({
    required this.label,
    required this.emoji,
    required this.subtitle,
    required this.route,
    required this.color,
  });
}

// ── Unified Status Engine (static methods) ────────────────

abstract class UnifiedStatusEngine {
  // ── Build DailyRings ──────────────────────────────────
  static DailyRings computeRings({
    required bool moodDone,
    required bool journalDone,
    required bool mindfulnessDone,
    required bool chatDone,
  }) {
    return DailyRings([
      ActivityRing(
        id: 'mood',
        label: 'Mood',
        emoji: '😊',
        completed: moodDone,
        color: const Color(0xFF06D6A0),
        route: '/mood-tracker',
      ),
      ActivityRing(
        id: 'journal',
        label: 'Journal',
        emoji: '📖',
        completed: journalDone,
        color: const Color(0xFFF59E0B),
        route: '/journal',
      ),
      ActivityRing(
        id: 'mindfulness',
        label: 'Breathe',
        emoji: '🧘',
        completed: mindfulnessDone,
        color: const Color(0xFF8B5CF6),
        route: '/mindfulness',
      ),
      ActivityRing(
        id: 'chat',
        label: 'Maya',
        emoji: '💬',
        completed: chatDone,
        color: const Color(0xFF00BEB4),
        route: '/chat',
      ),
    ]);
  }

  // ── Compute Priority Action ───────────────────────────
  static PriorityAction computePriorityAction({
    required DailyRings rings,
    required double wellnessScore,
    required int hour,
  }) {
    // Critical score — push to chat immediately
    if (wellnessScore > 0 && wellnessScore < 20) {
      return const PriorityAction(
        label: 'Talk to Maya',
        emoji: '💙',
        subtitle: 'Maya is here for you right now',
        route: '/chat',
        color: Color(0xFF00BEB4),
      );
    }

    // All rings done — celebrate
    if (rings.allDone) {
      return const PriorityAction(
        label: 'Keep your streak!',
        emoji: '🔥',
        subtitle: 'All daily practices complete',
        route: '/wellness',
        color: Color(0xFF059669),
      );
    }

    // Time-based ordering of incomplete rings
    final incomplete = rings.rings.where((r) => !r.completed).toList();

    // Morning (6–11): mood first
    if (hour >= 6 && hour < 12) {
      final mood = incomplete.firstWhereOrNull((r) => r.id == 'mood');
      if (mood != null) {
        return PriorityAction(
          label: 'Morning check-in',
          emoji: mood.emoji,
          subtitle: 'How are you feeling today?',
          route: mood.route,
          color: mood.color,
        );
      }
    }

    // Afternoon (12–17): chat or journal
    if (hour >= 12 && hour < 18) {
      final chat = incomplete.firstWhereOrNull((r) => r.id == 'chat');
      final journal = incomplete.firstWhereOrNull((r) => r.id == 'journal');
      final target = chat ?? journal;
      if (target != null) {
        return PriorityAction(
          label: target.id == 'chat' ? 'Chat with Maya' : 'Write today\'s journal',
          emoji: target.emoji,
          subtitle: target.id == 'chat'
              ? 'Share what\'s on your mind'
              : 'Reflect on your afternoon',
          route: target.route,
          color: target.color,
        );
      }
    }

    // Evening (18–22): mindfulness or journal
    if (hour >= 18 && hour < 23) {
      final mind = incomplete.firstWhereOrNull((r) => r.id == 'mindfulness');
      final journal = incomplete.firstWhereOrNull((r) => r.id == 'journal');
      final target = mind ?? journal;
      if (target != null) {
        return PriorityAction(
          label: target.id == 'mindfulness'
              ? '5-min wind-down'
              : 'Evening journal',
          emoji: target.emoji,
          subtitle: target.id == 'mindfulness'
              ? 'Breathing exercise before bed'
              : 'End the day with reflection',
          route: target.route,
          color: target.color,
        );
      }
    }

    // Night (22+): mindfulness
    if (hour >= 22) {
      final mind = incomplete.firstWhereOrNull((r) => r.id == 'mindfulness');
      if (mind != null) {
        return PriorityAction(
          label: 'Sleep preparation',
          emoji: mind.emoji,
          subtitle: 'Body scan for better sleep',
          route: mind.route,
          color: mind.color,
        );
      }
    }

    // Fallback — first incomplete ring
    if (incomplete.isNotEmpty) {
      final first = incomplete.first;
      return PriorityAction(
        label: first.label,
        emoji: first.emoji,
        subtitle: 'Complete your daily practice',
        route: first.route,
        color: first.color,
      );
    }

    return const PriorityAction(
      label: 'Explore wellness',
      emoji: '🌿',
      subtitle: 'Check your progress',
      route: '/wellness',
      color: Color(0xFF00BEB4),
    );
  }

  // ── Smart Nudge Text ──────────────────────────────────
  /// Returns a nudge string based on usage pattern and current hour.
  /// [typicalHours] = list of hours when user typically does this activity.
  /// Returns empty string when no nudge is warranted.
  static String computeSmartNudge({
    required List<int> typicalHours,
    required bool activityDoneToday,
    required String activityName,
    required int currentHour,
  }) {
    if (activityDoneToday || typicalHours.isEmpty) return '';

    // Find the closest typical hour to now
    final closest = typicalHours.reduce(
      (a, b) => (a - currentHour).abs() < (b - currentHour).abs() ? a : b,
    );

    // Only nudge if we're within ±1 hour of the typical time
    if ((closest - currentHour).abs() <= 1) {
      final timeStr = closest < 12
          ? '$closest:00 AM'
          : closest == 12
              ? '12:00 PM'
              : '${closest - 12}:00 PM';
      return 'You usually $activityName around $timeStr — want to?';
    }

    return '';
  }

  // ── Band Gradient Helper ──────────────────────────────
  static List<Color> bandGradient(double score) =>
      WellnessBandInfo.from(score).gradientColors;

  // ── Threshold Checks ─────────────────────────────────

  /// True if the user has had 3+ consecutive low mood days (score ≤ 4).
  static bool hasConsecutiveLowDays(List<int> recentMoodScores, {int threshold = 3}) {
    if (recentMoodScores.length < threshold) return false;
    return recentMoodScores.take(threshold).every((s) => s <= 4);
  }

  /// Momentum score: streak health (40%) + wellness score (60%), 0–100.
  static double momentumScore({
    required int currentStreak,
    required double wellnessScore,
  }) {
    final streakScore = (currentStreak.clamp(0, 30) / 30 * 100) * 0.4;
    final wellnessContrib = wellnessScore * 0.6;
    return (streakScore + wellnessContrib).clamp(0.0, 100.0);
  }
}
