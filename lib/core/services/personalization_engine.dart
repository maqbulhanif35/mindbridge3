import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../providers/mood_provider.dart';
import '../router/app_router.dart';

// ─── Data structs ─────────────────────────────────────────

class PersonalizedAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final bool featured;
  final int priority; // higher = show first
  final List<String> goalTags; // which goals trigger boosting this

  const PersonalizedAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.featured = false,
    this.priority = 0,
    this.goalTags = const [],
  });

  PersonalizedAction boost(int extra) => PersonalizedAction(
        icon: icon,
        label: label,
        color: color,
        route: route,
        featured: featured,
        priority: priority + extra,
        goalTags: goalTags,
      );

  PersonalizedAction copyWith({bool? featured}) => PersonalizedAction(
        icon: icon,
        label: label,
        color: color,
        route: route,
        featured: featured ?? this.featured,
        priority: priority,
        goalTags: goalTags,
      );
}

class PersonalizedChallenge {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String category;
  final Color categoryColor;
  final int xp;
  final String route;
  final List<String> goalTags;
  final List<String> stressorTags;
  final bool alwaysShow; // universal challenges always included

  const PersonalizedChallenge({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.categoryColor,
    required this.xp,
    required this.route,
    this.goalTags = const [],
    this.stressorTags = const [],
    this.alwaysShow = false,
  });
}

class RescueAction {
  final String emoji;
  final String label;
  final String route;
  final bool primary;

  const RescueAction({
    required this.emoji,
    required this.label,
    required this.route,
    this.primary = false,
  });
}

class GoalFocusItem {
  final String id;
  final String label;
  final String emoji;
  final String route;
  final Color color;

  const GoalFocusItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.route,
    required this.color,
  });
}

class GoalProgressItem {
  final String goalId;
  final String label;
  final String emoji;
  final double progress; // 0.0–1.0
  final String statusText;
  final Color color;

  const GoalProgressItem({
    required this.goalId,
    required this.label,
    required this.emoji,
    required this.progress,
    required this.statusText,
    required this.color,
  });
}

enum PersonalizedAlertLevel { info, warning, critical }

class PersonalizedAlert {
  final PersonalizedAlertLevel level;
  final String title;
  final String message;
  final String? actionLabel;
  final String? actionRoute;
  final IconData icon;

  const PersonalizedAlert({
    required this.level,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionRoute,
    required this.icon,
  });
}

// ─── Personalization Engine ───────────────────────────────

class PersonalizationEngine {
  PersonalizationEngine._();

  // ═══════════════════════════════════════════════════════
  // ACTION CATALOGUE — all available actions with base priorities
  // ═══════════════════════════════════════════════════════

  static const _allActions = <PersonalizedAction>[
    PersonalizedAction(
      icon: LucideIcons.bot,
      label: 'Chat Maya',
      color: AppColors.primary,
      route: AppRoutes.chat,
      featured: true,
      priority: 90,
      goalTags: ['anxiety', 'depression', 'grief', 'social', 'selfesteem', 'relationships'],
    ),
    PersonalizedAction(
      icon: LucideIcons.smile,
      label: 'Log Mood',
      color: Color(0xFF06D6A0),
      route: AppRoutes.moodTracker,
      priority: 85,
      goalTags: [],
    ),
    PersonalizedAction(
      icon: LucideIcons.penLine,
      label: 'Journal',
      color: Color(0xFFF59E0B),
      route: AppRoutes.journal,
      priority: 60,
      goalTags: ['depression', 'grief', 'selfesteem', 'anxiety', 'motivation'],
    ),
    PersonalizedAction(
      icon: LucideIcons.wind,
      label: 'Breathe',
      color: Color(0xFF0EA5E9),
      route: AppRoutes.mindfulness,
      priority: 55,
      goalTags: ['anxiety', 'stress', 'mindfulness', 'sleep'],
    ),
    PersonalizedAction(
      icon: LucideIcons.brain,
      label: 'Mindfulness',
      color: AppColors.primary,
      route: AppRoutes.mindfulness,
      priority: 50,
      goalTags: ['mindfulness', 'anxiety', 'stress', 'sleep'],
    ),
    PersonalizedAction(
      icon: LucideIcons.activity,
      label: 'Wellness',
      color: Color(0xFF06D6A0),
      route: AppRoutes.wellness,
      priority: 45,
      goalTags: ['sleep', 'motivation', 'selfesteem'],
    ),
    PersonalizedAction(
      icon: LucideIcons.users,
      label: 'Community',
      color: Color(0xFFFF6B6B),
      route: AppRoutes.community,
      priority: 40,
      goalTags: ['social', 'relationships', 'selfesteem'],
    ),
    PersonalizedAction(
      icon: LucideIcons.chartBar,
      label: 'Analytics',
      color: Color(0xFFF59E0B),
      route: AppRoutes.moodAnalytics,
      priority: 35,
      goalTags: ['motivation', 'stress'],
    ),
    PersonalizedAction(
      icon: LucideIcons.library,
      label: 'Resources',
      color: Color(0xFF8B5CF6),
      route: AppRoutes.resources,
      priority: 30,
      goalTags: ['anxiety', 'depression', 'relationships', 'grief'],
    ),
    PersonalizedAction(
      icon: LucideIcons.userRound,
      label: 'Profile',
      color: AppColors.primary,
      route: AppRoutes.profile,
      priority: 10,
      goalTags: [],
    ),
  ];

  // ═══════════════════════════════════════════════════════
  // CHALLENGE CATALOGUE
  // ═══════════════════════════════════════════════════════

  static const _allChallenges = <PersonalizedChallenge>[
    // Universal — always shown
    PersonalizedChallenge(
      id: 'mood',
      icon: LucideIcons.smile,
      title: 'Log Your Mood',
      subtitle: 'Check in · How are you feeling?',
      category: 'Mood',
      categoryColor: AppColors.primary,
      xp: 50,
      route: AppRoutes.moodTracker,
      alwaysShow: true,
    ),
    // Goal-specific
    PersonalizedChallenge(
      id: 'breathe_478',
      icon: LucideIcons.wind,
      title: '4-7-8 Breathing',
      subtitle: '5 min · Calm your nervous system',
      category: 'Breathe',
      categoryColor: Color(0xFF0EA5E9),
      xp: 60,
      route: AppRoutes.breathing,
      goalTags: ['anxiety', 'stress', 'mindfulness'],
      stressorTags: ['exams', 'performance', 'time'],
    ),
    PersonalizedChallenge(
      id: 'journal_gratitude',
      icon: LucideIcons.penLine,
      title: 'Write 3 Gratitudes',
      subtitle: '3 min · Shift your perspective',
      category: 'Journal',
      categoryColor: Color(0xFFF59E0B),
      xp: 75,
      route: AppRoutes.journalEntry,
      goalTags: ['depression', 'grief', 'selfesteem', 'motivation'],
    ),
    PersonalizedChallenge(
      id: 'chat_maya',
      icon: LucideIcons.bot,
      title: 'Talk with Maya',
      subtitle: "Chat · Share what's on your mind",
      category: 'AI Chat',
      categoryColor: Color(0xFF06D6A0),
      xp: 40,
      route: AppRoutes.chat,
      goalTags: ['anxiety', 'depression', 'grief', 'social', 'relationships'],
    ),
    PersonalizedChallenge(
      id: 'sleep_wind_down',
      icon: LucideIcons.moonStar,
      title: 'Sleep Wind-Down',
      subtitle: '10 min · Prepare your mind for rest',
      category: 'Sleep',
      categoryColor: Color(0xFF6366F1),
      xp: 80,
      route: AppRoutes.mindfulness,
      goalTags: ['sleep'],
      stressorTags: ['exams', 'time'],
    ),
    PersonalizedChallenge(
      id: 'community_post',
      icon: LucideIcons.users,
      title: 'Connect with Community',
      subtitle: '2 min · Share or support someone',
      category: 'Social',
      categoryColor: Color(0xFFFF6B6B),
      xp: 45,
      route: AppRoutes.community,
      goalTags: ['social', 'relationships', 'selfesteem'],
      stressorTags: ['loneliness'],
    ),
    PersonalizedChallenge(
      id: 'body_scan',
      icon: LucideIcons.activity,
      title: '5-Min Body Scan',
      subtitle: '5 min · Check in with your body',
      category: 'Mindfulness',
      categoryColor: AppColors.primary,
      xp: 55,
      route: AppRoutes.mindfulness,
      goalTags: ['mindfulness', 'anxiety', 'stress'],
    ),
    PersonalizedChallenge(
      id: 'resources_read',
      icon: LucideIcons.bookOpen,
      title: 'Read a Wellness Tip',
      subtitle: '3 min · Learn something new',
      category: 'Learn',
      categoryColor: Color(0xFF8B5CF6),
      xp: 30,
      route: AppRoutes.resources,
      goalTags: ['anxiety', 'depression', 'relationships', 'grief', 'selfesteem'],
    ),
    PersonalizedChallenge(
      id: 'study_pomodoro',
      icon: LucideIcons.timer,
      title: 'Pomodoro Study Break',
      subtitle: '5 min · Rest between study sessions',
      category: 'Academic',
      categoryColor: Color(0xFF10B981),
      xp: 35,
      route: AppRoutes.mindfulness,
      stressorTags: ['exams', 'career', 'time', 'performance'],
    ),
    PersonalizedChallenge(
      id: 'affirmation_mirror',
      icon: LucideIcons.sparkles,
      title: 'Mirror Affirmation',
      subtitle: '2 min · Say something kind to yourself',
      category: 'Self-Love',
      categoryColor: Color(0xFFF59E0B),
      xp: 40,
      route: AppRoutes.wellness,
      goalTags: ['selfesteem', 'depression', 'social'],
      stressorTags: ['identity'],
    ),
    PersonalizedChallenge(
      id: 'analytics_review',
      icon: LucideIcons.chartBar,
      title: 'Review Your Progress',
      subtitle: 'Analytics · See your mood trends',
      category: 'Insights',
      categoryColor: Color(0xFFF59E0B),
      xp: 30,
      route: AppRoutes.moodAnalytics,
      goalTags: ['motivation'],
    ),
    PersonalizedChallenge(
      id: 'journal_vent',
      icon: LucideIcons.penLine,
      title: 'Vent Without Judgement',
      subtitle: '5 min · Write anything, feel lighter',
      category: 'Journal',
      categoryColor: Color(0xFFF59E0B),
      xp: 65,
      route: AppRoutes.journalEntry,
      goalTags: ['stress', 'anxiety', 'grief'],
      stressorTags: ['family', 'finances', 'loneliness', 'relationships_stress'],
    ),
    PersonalizedChallenge(
      id: 'wellness_goal',
      icon: LucideIcons.target,
      title: 'Set a Micro-Goal',
      subtitle: '2 min · One small thing for today',
      category: 'Wellness',
      categoryColor: Color(0xFF06D6A0),
      xp: 45,
      route: AppRoutes.wellness,
      goalTags: ['motivation', 'selfesteem', 'depression'],
      stressorTags: ['career', 'identity'],
    ),
  ];

  // ═══════════════════════════════════════════════════════
  // GOAL → FOCUS ITEM MAPPING
  // ═══════════════════════════════════════════════════════

  static const _goalFocusMap = <String, GoalFocusItem>{
    'anxiety': GoalFocusItem(
      id: 'anxiety',
      label: 'Manage Anxiety',
      emoji: '😌',
      route: AppRoutes.mindfulness,
      color: Color(0xFF0EA5E9),
    ),
    'depression': GoalFocusItem(
      id: 'depression',
      label: 'Lift Your Mood',
      emoji: '💙',
      route: AppRoutes.journal,
      color: Color(0xFF6366F1),
    ),
    'stress': GoalFocusItem(
      id: 'stress',
      label: 'Reduce Stress',
      emoji: '📚',
      route: AppRoutes.breathing,
      color: Color(0xFFFF8C42),
    ),
    'sleep': GoalFocusItem(
      id: 'sleep',
      label: 'Better Sleep',
      emoji: '😴',
      route: AppRoutes.wellness,
      color: Color(0xFF6366F1),
    ),
    'social': GoalFocusItem(
      id: 'social',
      label: 'Social Confidence',
      emoji: '🤝',
      route: AppRoutes.community,
      color: Color(0xFFFF6B6B),
    ),
    'motivation': GoalFocusItem(
      id: 'motivation',
      label: 'Boost Motivation',
      emoji: '🚀',
      route: AppRoutes.moodAnalytics,
      color: Color(0xFFF59E0B),
    ),
    'mindfulness': GoalFocusItem(
      id: 'mindfulness',
      label: 'Mindfulness',
      emoji: '🧘',
      route: AppRoutes.mindfulness,
      color: AppColors.primary,
    ),
    'selfesteem': GoalFocusItem(
      id: 'selfesteem',
      label: 'Self-Esteem',
      emoji: '💪',
      route: AppRoutes.wellness,
      color: Color(0xFF10B981),
    ),
    'grief': GoalFocusItem(
      id: 'grief',
      label: 'Process Grief',
      emoji: '🌹',
      route: AppRoutes.journal,
      color: Color(0xFFEC4899),
    ),
    'relationships': GoalFocusItem(
      id: 'relationships',
      label: 'Relationships',
      emoji: '❤️',
      route: AppRoutes.resources,
      color: Color(0xFFFF6B6B),
    ),
  };

  // ═══════════════════════════════════════════════════════
  // GOAL → AFFIRMATION MAPPING
  // ═══════════════════════════════════════════════════════

  static const _goalAffirmations = <String, List<(String, String)>>{
    'anxiety': [
      ('Anxiety is not your identity — it is just a wave. You are the ocean.', 'MindBridge'),
      ('Your nervous system is trying to protect you. Thank it, then breathe.', 'MindBridge'),
      ('This feeling will pass. It always does. You always do.', 'MindBridge'),
      ('You have faced every anxious moment so far — and here you still are.', 'MindBridge'),
    ],
    'depression': [
      ('Small steps are still steps. Getting out of bed today is a win.', 'MindBridge'),
      ('The darkest nights produce the brightest stars.', 'African Proverb'),
      ('You deserve warmth, rest, and kindness — especially from yourself.', 'MindBridge'),
      ('Feeling low is not failing. It is being human.', 'MindBridge'),
    ],
    'stress': [
      ('One CAT at a time. One task at a time. You do not carry it all at once.', 'MindBridge'),
      ('Pressure creates diamonds. You are being shaped, not broken.', 'African Wisdom'),
      ('A rested mind works smarter than an exhausted one.', 'MindBridge'),
      ('You do not have to solve everything today.', 'MindBridge'),
    ],
    'sleep': [
      ('Rest is not laziness — it is how your brain consolidates learning.', 'MindBridge'),
      ('Pumzika kidogo. Rest a little — then rise again.', 'Swahili'),
      ('Sleep is your superpower. Protect it tonight.', 'MindBridge'),
      ('Your body heals while you sleep. You deserve that healing.', 'MindBridge'),
    ],
    'social': [
      ('Connection is a human need, not a weakness.', 'MindBridge'),
      ('Tunaenda pamoja. We go together — you were never meant to walk alone.', 'Swahili'),
      ('Putting yourself out there takes courage. You are braver than you think.', 'MindBridge'),
      ('Ubuntu — I am because we are. Your presence matters.', 'African Philosophy'),
    ],
    'motivation': [
      ('Progress over perfection, always.', 'MindBridge'),
      ('The spark you need is already inside you.', 'MindBridge'),
      ('Your future self will thank you for the effort you put in today.', 'MindBridge'),
      ('Even the tallest tree started as a seed. Keep growing.', 'African Proverb'),
    ],
    'mindfulness': [
      ('The present moment is the only place where life actually happens.', 'MindBridge'),
      ('A calm mind reflects clearly — like still water.', 'Kenyan Proverb'),
      ('Breathe. Right now, in this moment, you are okay.', 'MindBridge'),
      ('Slow down. The world will still be there after you breathe.', 'MindBridge'),
    ],
    'selfesteem': [
      ('Jipende kwanza. Love yourself first — everything else follows.', 'Swahili'),
      ('You are not your CGPA. You are not your HELB balance.', 'MindBridge'),
      ('You are enough, exactly as you are right now.', 'MindBridge'),
      ('Treat yourself with the same kindness you show your best friend.', 'MindBridge'),
    ],
    'grief': [
      ('Grief is the price of love — and love was worth it.', 'MindBridge'),
      ('You do not have to rush healing. Grief has its own timeline.', 'MindBridge'),
      ('Allow yourself to feel. Feelings do not break you — they move through you.', 'MindBridge'),
      ('Mourning is not weakness. It is the deepest form of love.', 'African Wisdom'),
    ],
    'relationships': [
      ('Healthy relationships start with the one you have with yourself.', 'MindBridge'),
      ('You deserve connections that feel safe and mutual.', 'MindBridge'),
      ('Communication is the bridge between confusion and clarity.', 'African Wisdom'),
      ('You are allowed to outgrow what no longer serves you.', 'MindBridge'),
    ],
  };

  // ═══════════════════════════════════════════════════════
  // STRESSOR → RESCUE ACTION MAPPING
  // ═══════════════════════════════════════════════════════

  static const _stressorRescueMap = <String, List<RescueAction>>{
    'exams': [
      RescueAction(emoji: '🌬', label: 'Box Breathe', route: AppRoutes.breathing, primary: true),
      RescueAction(emoji: '⏱', label: 'Pomodoro', route: AppRoutes.mindfulness),
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat),
    ],
    'finances': [
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat, primary: true),
      RescueAction(emoji: '📖', label: 'Resources', route: AppRoutes.resources),
      RescueAction(emoji: '✅', label: 'Check In', route: AppRoutes.moodTracker),
    ],
    'loneliness': [
      RescueAction(emoji: '🤝', label: 'Community', route: AppRoutes.community, primary: true),
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat),
      RescueAction(emoji: '✍', label: 'Journal', route: AppRoutes.journalEntry),
    ],
    'family': [
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat, primary: true),
      RescueAction(emoji: '✍', label: 'Journal', route: AppRoutes.journalEntry),
      RescueAction(emoji: '🌬', label: 'Breathe', route: AppRoutes.breathing),
    ],
    'performance': [
      RescueAction(emoji: '🌬', label: 'Breathe', route: AppRoutes.breathing, primary: true),
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat),
      RescueAction(emoji: '✅', label: 'Check In', route: AppRoutes.moodTracker),
    ],
  };

  static const _goalRescueMap = <String, List<RescueAction>>{
    'anxiety': [
      RescueAction(emoji: '🌬', label: 'Box Breathe', route: AppRoutes.breathing, primary: true),
      RescueAction(emoji: '🧘', label: 'Body Scan', route: AppRoutes.mindfulness),
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat),
    ],
    'sleep': [
      RescueAction(emoji: '🌙', label: 'Wind Down', route: AppRoutes.mindfulness, primary: true),
      RescueAction(emoji: '🌬', label: 'Breathe', route: AppRoutes.breathing),
      RescueAction(emoji: '✅', label: 'Check In', route: AppRoutes.moodTracker),
    ],
    'depression': [
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat, primary: true),
      RescueAction(emoji: '✍', label: 'Journal', route: AppRoutes.journalEntry),
      RescueAction(emoji: '🤝', label: 'Community', route: AppRoutes.community),
    ],
    'social': [
      RescueAction(emoji: '🤝', label: 'Community', route: AppRoutes.community, primary: true),
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat),
      RescueAction(emoji: '✅', label: 'Check In', route: AppRoutes.moodTracker),
    ],
    'grief': [
      RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat, primary: true),
      RescueAction(emoji: '✍', label: 'Write It Out', route: AppRoutes.journalEntry),
      RescueAction(emoji: '📖', label: 'Resources', route: AppRoutes.resources),
    ],
  };

  // Default rescue actions
  static const _defaultRescue = <RescueAction>[
    RescueAction(emoji: '🌬', label: 'Breathe', route: AppRoutes.mindfulness),
    RescueAction(emoji: '💬', label: 'Talk Maya', route: AppRoutes.chat, primary: true),
    RescueAction(emoji: '✅', label: 'Check In', route: AppRoutes.moodTracker),
  ];

  // ═══════════════════════════════════════════════════════
  // GOAL → MAYA CHAT CHIPS
  // ═══════════════════════════════════════════════════════

  static const _goalChipMap = <String, List<String>>{
    'anxiety': ["Help me calm down", "Why do I feel anxious?", "Breathing techniques"],
    'depression': ["I've been feeling low", "Help me find motivation", "I need some hope"],
    'stress': ["Stressed about CATs", "HELB hasn't dropped 😩", "I'm overwhelmed"],
    'sleep': ["I can't sleep", "Help me wind down", "Sleep hygiene tips"],
    'social': ["I feel lonely", "Help me connect", "Social confidence tips"],
    'motivation': ["I need motivation", "I keep procrastinating", "Set a goal with me"],
    'mindfulness': ["Let's do a body scan", "Help me stay present", "Mindfulness exercise"],
    'selfesteem': ["I doubt myself", "Build my confidence", "Self-compassion practice"],
    'grief': ["I'm grieving", "Help me process this", "I miss someone"],
    'relationships': ["Relationship stress", "I feel disconnected", "Help me communicate"],
  };

  // ═══════════════════════════════════════════════════════
  // STRESSOR SEASON DETECTION
  // ═══════════════════════════════════════════════════════

  /// Returns true during typical Kenyan university CAT/exam periods.
  static bool get isExamSeason {
    final now = DateTime.now();
    final m = now.month;
    final d = now.day;
    // Semester 1 CATs: Oct 15 – Nov 15 | Exams: Dec 1–20
    // Semester 2 CATs: Mar 15 – Apr 15 | Exams: May 1–31
    final s1Cat = (m == 10 && d >= 15) || (m == 11 && d <= 15);
    final s1Exam = m == 12 && d <= 20;
    final s2Cat = (m == 3 && d >= 15) || (m == 4 && d <= 15);
    final s2Exam = m == 5;
    return s1Cat || s1Exam || s2Cat || s2Exam;
  }

  /// Returns true during typical HELB disbursement delay windows.
  static bool get isHELBSeason {
    final now = DateTime.now();
    final m = now.month;
    // HELB typically delays Jan–Feb and Aug–Sep
    return m == 1 || m == 2 || m == 8 || m == 9;
  }

  /// Returns a contextual academic banner message if applicable.
  static String? get academicContextMessage {
    if (isExamSeason) return '📝 CAT/Exam season — remember to rest between sessions';
    if (isHELBSeason) return '💸 HELB delays this month are real. Financial stress is valid.';
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════

  /// Returns actions sorted by relevance to user's goals (highest priority first).
  static List<PersonalizedAction> prioritizeActions(UserModel? user) {
    if (user == null) return _allActions;
    final goals = user.goals;
    final stressors = user.stressors;

    return _allActions.map((action) {
      var extra = 0;
      for (final g in goals) {
        if (action.goalTags.contains(g)) extra += 25;
      }
      // Exam season boosts breathe + mindfulness
      if (isExamSeason && (stressors.contains('exams') || stressors.contains('performance'))) {
        if (action.route == AppRoutes.breathing || action.route == AppRoutes.mindfulness) {
          extra += 20;
        }
      }
      return extra > 0 ? action.boost(extra) : action;
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Returns up to [max] challenges relevant to the user's goals/stressors,
  /// always including the universal mood check-in first.
  static List<PersonalizedChallenge> selectChallenges(
    UserModel? user, {
    int max = 5,
  }) {
    final goals = user?.goals ?? [];
    final stressors = user?.stressors ?? [];
    final result = <PersonalizedChallenge>[];
    final used = <String>{};

    // 1. Always include mood check-in first
    final mood = _allChallenges.firstWhere((c) => c.id == 'mood');
    result.add(mood);
    used.add(mood.id);

    // 2. Score all other challenges
    final scored = _allChallenges.where((c) => !c.alwaysShow).map((c) {
      var score = 0;
      for (final g in goals) {
        if (c.goalTags.contains(g)) score += 10;
      }
      for (final s in stressors) {
        if (c.stressorTags.contains(s)) score += 8;
      }
      if (isExamSeason && (stressors.contains('exams') || goals.contains('stress'))) {
        if (c.id == 'breathe_478' || c.id == 'study_pomodoro') score += 15;
      }
      return (score, c);
    }).toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));

    // 3. Fill up to max
    for (final (_, challenge) in scored) {
      if (result.length >= max) break;
      if (used.contains(challenge.id)) continue;
      result.add(challenge);
      used.add(challenge.id);
    }

    return result;
  }

  /// Returns rescue actions based on user's top stressor, then top goal.
  static List<RescueAction> getRescueActions(UserModel? user) {
    if (user == null) return _defaultRescue;

    // Check stressors first (more urgent)
    for (final s in user.stressors) {
      if (_stressorRescueMap.containsKey(s)) return _stressorRescueMap[s]!;
    }

    // Then goals
    for (final g in user.goals) {
      if (_goalRescueMap.containsKey(g)) return _goalRescueMap[g]!;
    }

    return _defaultRescue;
  }

  /// Returns the current rescue title and subtitle based on state + goals.
  static ({String title, String subtitle, String emoji}) getRescueHeadline(
    UserModel? user, {
    required bool isLowMood,
    required bool isNoCheckin,
  }) {
    final primary = user?.goals.isNotEmpty == true ? user!.goals.first : '';
    if (!isLowMood && isNoCheckin) {
      return switch (primary) {
        'sleep' => (
            title: "Sleep matters — start with a check-in 🌙",
            subtitle: "Track your rest to see sleep patterns emerge",
            emoji: '🌙',
          ),
        'anxiety' => (
            title: "Ground yourself — a quick check-in helps 😌",
            subtitle: "Naming how you feel reduces anxiety's grip",
            emoji: '😌',
          ),
        'motivation' => (
            title: "Start your day with intention 🚀",
            subtitle: "One small check-in builds momentum",
            emoji: '🚀',
          ),
        _ => (
            title: "No check-in yet — try a 5-min reset",
            subtitle: "A quick mood lift before your day gets busy",
            emoji: '⚡',
          ),
      };
    }
    return switch (primary) {
      'anxiety' => (
          title: "Anxious? You have tools for this 😌",
          subtitle: "Breathing + grounding exercises work fast",
          emoji: '🌬',
        ),
      'sleep' => (
          title: "Tired body needs care right now 🌙",
          subtitle: "A quick wind-down practice can help tonight",
          emoji: '🌙',
        ),
      'depression' => (
          title: "Hard day — let's take it one breath at a time 💙",
          subtitle: "Even small actions create forward movement",
          emoji: '💙',
        ),
      'grief' => (
          title: "Grief is heavy — you don't carry it alone 🌹",
          subtitle: "Talking or writing it out eases the weight",
          emoji: '🌹',
        ),
      _ => (
          title: "Tough day? Here's your 5-min rescue 💙",
          subtitle: "Quick exercises that actually help right now",
          emoji: '💙',
        ),
    };
  }

  /// Returns up to 2 GoalFocusItems for the user's top goals.
  static List<GoalFocusItem> getFocusItems(UserModel? user, {int max = 3}) {
    if (user == null || user.goals.isEmpty) return [];
    return user.goals
        .where(_goalFocusMap.containsKey)
        .take(max)
        .map((g) => _goalFocusMap[g]!)
        .toList();
  }

  /// Returns the best affirmation for the user's primary goal.
  static (String, String) getAffirmation(UserModel? user, int dayIndex) {
    const _fallback = [
      ('Harambee — together we achieve more.', 'Kenyan National Motto'),
      ('You are not your CGPA. You are not your HELB balance.', 'MindBridge'),
      ('Your future self is proud of you for showing up today.', 'MindBridge'),
      ('Rest is not laziness. Rest is how you grow stronger.', 'MindBridge'),
      ('You belong here, even on the hard days.', 'MindBridge'),
      ('Breathe. You have survived every hard day so far.', 'MindBridge'),
      ('Jipende kwanza. Love yourself first.', 'Swahili'),
      ('Progress over perfection, always.', 'MindBridge'),
      ('Ubuntu — I am because we are.', 'African Philosophy'),
      ('Pole pole ndio mwendo. Slowly but surely.', 'Swahili Proverb'),
    ];

    if (user == null || user.goals.isEmpty) {
      return _fallback[dayIndex % _fallback.length];
    }

    final goal = user.goals.first;
    final goalList = _goalAffirmations[goal];
    if (goalList == null || goalList.isEmpty) {
      return _fallback[dayIndex % _fallback.length];
    }
    return goalList[dayIndex % goalList.length];
  }

  /// Returns chat chips tailored to user's goals / stressors.
  static List<String> getMayaChips(UserModel? user, MoodState? moodState) {
    if (user == null) {
      return ["Stressed about CATs?", "HELB hasn't dropped 😩", "I need motivation"];
    }

    final today = moodState?.todayEntry;
    // Low mood override
    if (today != null && today.moodScore <= 3) {
      return ["Help me feel better", "I'm overwhelmed", "I can't cope right now"];
    }

    // Stressor-specific chips first
    for (final s in user.stressors) {
      final stressorChips = <String, List<String>>{
        'exams': ["Stressed about CATs", "Help me study smarter", "I'm burning out"],
        'finances': ["HELB hasn't dropped 😩", "Financial stress is heavy", "Help me cope"],
        'loneliness': ["I feel really alone", "Help me connect", "I miss having friends nearby"],
        'family': ["Family stress is real", "Help me set boundaries", "I feel torn"],
        'career': ["Worried about my future", "Attachment anxiety", "Career pressure is heavy"],
        'identity': ["I don't know who I am", "Help me find my purpose", "I feel lost"],
        'health': ["My health is worrying me", "Help me take care of myself", "I'm exhausted"],
      };
      if (stressorChips.containsKey(s)) return stressorChips[s]!;
    }

    // Goal-specific chips
    for (final g in user.goals) {
      if (_goalChipMap.containsKey(g)) return _goalChipMap[g]!;
    }

    return ["How do I feel better?", "Reflect on my day", "Stress management"];
  }

  // ═══════════════════════════════════════════════════════
  // GOAL PROGRESS SCORING
  // ═══════════════════════════════════════════════════════

  /// Computes a 0.0–1.0 progress score per goal using mood trends,
  /// streaks, journal activity, and consistency.
  static List<GoalProgressItem> computeGoalProgress(
    UserModel? user,
    MoodState moodState,
  ) {
    if (user == null || user.goals.isEmpty) return [];

    final entries = moodState.entries;
    final streak = moodState.currentStreakDays;
    final journalCount = moodState.journalEntries.length;

    // 7-day mood average (0-10)
    double avg7 = 0;
    if (entries.isNotEmpty) {
      final last7 = entries.take(7).toList();
      avg7 = last7.map((e) => e.moodScore.toDouble()).reduce((a, b) => a + b) /
          last7.length;
    }

    // Mood trend direction
    double trend = 0;
    if (entries.length >= 6) {
      final older = entries.skip(3).take(3).map((e) => e.moodScore.toDouble()).reduce((a, b) => a + b) / 3;
      final newer = entries.take(3).map((e) => e.moodScore.toDouble()).reduce((a, b) => a + b) / 3;
      trend = newer - older; // positive = improving
    }

    return user.goals.take(4).map((goal) {
      double progress;
      String status;
      Color color;

      switch (goal) {
        case 'anxiety':
          // Progress: low anxiety = high mood avg + breathing streak
          final moodFactor = (avg7 / 10).clamp(0.0, 1.0);
          final streakFactor = (streak / 14).clamp(0.0, 0.4);
          progress = (moodFactor * 0.6 + streakFactor).clamp(0.0, 1.0);
          status = progress >= 0.7 ? 'Great progress!' : progress >= 0.4 ? 'Keep going' : 'Early days';
          color = const Color(0xFF0EA5E9);
          break;
        case 'depression':
        case 'selfesteem':
          final moodFactor = ((avg7 - 3) / 7).clamp(0.0, 1.0);
          final journalFactor = (journalCount / 10).clamp(0.0, 0.3);
          final trendFactor = trend > 0 ? 0.2 : 0.0;
          progress = (moodFactor * 0.5 + journalFactor + trendFactor).clamp(0.0, 1.0);
          status = trend > 0.5 ? 'Mood improving!' : progress >= 0.5 ? 'Steady progress' : 'Take it easy';
          color = const Color(0xFF6366F1);
          break;
        case 'stress':
          final consistencyFactor = (streak / 10).clamp(0.0, 0.5);
          final moodFactor = (avg7 / 10).clamp(0.0, 0.5);
          progress = (consistencyFactor + moodFactor).clamp(0.0, 1.0);
          status = isExamSeason ? 'Exam season — be kind to yourself' : progress >= 0.6 ? 'Managing well' : 'Keep at it';
          color = const Color(0xFFFF8C42);
          break;
        case 'sleep':
          final sleepEntries = entries.take(7).where((e) => e.sleepHours != null).toList();
          if (sleepEntries.isEmpty) {
            progress = 0.1;
            status = 'Log sleep to track';
          } else {
            final avgSleep = sleepEntries.map((e) => e.sleepHours!).reduce((a, b) => a + b) / sleepEntries.length;
            progress = ((avgSleep - 4) / 5).clamp(0.0, 1.0); // 4h=0, 9h=1
            status = avgSleep >= 7 ? 'Good sleep!' : avgSleep >= 6 ? 'Getting there' : 'Needs improvement';
          }
          color = const Color(0xFF6366F1);
          break;
        case 'motivation':
          final streakFactor = (streak / 7).clamp(0.0, 0.5);
          final trendFactor = trend > 0 ? 0.3 : 0.1;
          final moodFactor = (avg7 / 10).clamp(0.0, 0.3);
          progress = (streakFactor + trendFactor + moodFactor).clamp(0.0, 1.0);
          status = streak >= 5 ? '$streak-day streak! 🔥' : progress >= 0.5 ? 'Building momentum' : 'Start small';
          color = const Color(0xFFF59E0B);
          break;
        case 'social':
          // Proxy: community engagement + chat usage
          final streakFactor = (streak / 10).clamp(0.0, 0.4);
          progress = (streakFactor + 0.3).clamp(0.0, 1.0); // base 0.3 for being here
          status = 'Engage in community';
          color = const Color(0xFFFF6B6B);
          break;
        case 'mindfulness':
          final consistencyFactor = (streak / 7).clamp(0.0, 0.6);
          progress = (consistencyFactor + 0.2).clamp(0.0, 1.0);
          status = streak >= 3 ? 'Daily practice growing' : 'Start with 5 min';
          color = AppColors.primary;
          break;
        case 'grief':
          final journalFactor = (journalCount / 7).clamp(0.0, 0.5);
          progress = (journalFactor + 0.2).clamp(0.0, 1.0);
          status = 'Healing takes time';
          color = const Color(0xFFEC4899);
          break;
        case 'relationships':
          progress = 0.4 + (streak / 20).clamp(0.0, 0.4);
          status = 'Work in progress';
          color = const Color(0xFFFF6B6B);
          break;
        default:
          progress = (avg7 / 10).clamp(0.0, 1.0);
          status = 'Keep going';
          color = AppColors.primary;
      }

      final focusItem = _goalFocusMap[goal];
      return GoalProgressItem(
        goalId: goal,
        label: focusItem?.label ?? goal,
        emoji: focusItem?.emoji ?? '🎯',
        progress: progress,
        statusText: status,
        color: color,
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  // THRESHOLD ALERTS
  // ═══════════════════════════════════════════════════════

  /// Generates smart, goal-aware alerts when thresholds are crossed.
  static List<PersonalizedAlert> computeThresholdAlerts(
    UserModel? user,
    MoodState moodState,
  ) {
    if (user == null) return [];
    final alerts = <PersonalizedAlert>[];
    final entries = moodState.entries;
    final goals = user.goals;
    final stressors = user.stressors;

    // --- Threshold 1: 3+ consecutive days mood ≤ 4 with depression/grief goal
    if (entries.length >= 3) {
      final last3 = entries.take(3);
      final allLow = last3.every((e) => e.moodScore <= 4);
      if (allLow && (goals.contains('depression') || goals.contains('grief'))) {
        alerts.add(const PersonalizedAlert(
          level: PersonalizedAlertLevel.warning,
          title: 'Low mood for 3 days',
          message: "You've been struggling lately. Your goal is to feel better — Maya is here right now.",
          actionLabel: 'Talk to Maya',
          actionRoute: AppRoutes.chat,
          icon: LucideIcons.heartHandshake,
        ));
      }
    }

    // --- Threshold 2: Anxiety goal + no mindfulness/breathing in 5+ days
    if (goals.contains('anxiety') && moodState.currentStreakDays < 2) {
      alerts.add(const PersonalizedAlert(
        level: PersonalizedAlertLevel.info,
        title: 'Anxiety tools are here for you',
        message: "A 5-min breathing session can measurably lower cortisol. Give it a go today.",
        actionLabel: 'Breathe now',
        actionRoute: AppRoutes.breathing,
        icon: LucideIcons.wind,
      ));
    }

    // --- Threshold 3: Sleep goal + avg sleep < 6h over last 3 entries
    if (goals.contains('sleep') && entries.isNotEmpty) {
      final sleepEntries = entries.take(5).where((e) => e.sleepHours != null).toList();
      if (sleepEntries.length >= 3) {
        final avgSleep = sleepEntries.map((e) => e.sleepHours!).reduce((a, b) => a + b) / sleepEntries.length;
        if (avgSleep < 6.0) {
          alerts.add(PersonalizedAlert(
            level: PersonalizedAlertLevel.warning,
            title: 'Sleep deficit detected',
            message: "You're averaging ${avgSleep.toStringAsFixed(1)}h. Chronic sleep debt impairs focus and emotional regulation.",
            actionLabel: 'Wind-down routine',
            actionRoute: AppRoutes.mindfulness,
            icon: LucideIcons.moonStar,
          ));
        }
      }
    }

    // --- Threshold 4: Exam season + stress stressor
    if (isExamSeason && (stressors.contains('exams') || stressors.contains('performance'))) {
      alerts.add(const PersonalizedAlert(
        level: PersonalizedAlertLevel.info,
        title: 'CAT season — protect your mind',
        message: "Stress peaks during exam periods. Short breathing breaks between sessions improve retention.",
        actionLabel: 'Quick breathe',
        actionRoute: AppRoutes.breathing,
        icon: LucideIcons.bookOpen,
      ));
    }

    // --- Threshold 5: HELB season + finances stressor
    if (isHELBSeason && stressors.contains('finances')) {
      alerts.add(const PersonalizedAlert(
        level: PersonalizedAlertLevel.info,
        title: 'HELB delays are stressful',
        message: "Financial uncertainty is a real burden. You're not alone in this — talk to Maya about managing the pressure.",
        actionLabel: 'Talk to Maya',
        actionRoute: AppRoutes.chat,
        icon: LucideIcons.circleDollarSign,
      ));
    }

    // --- Threshold 6: Motivation goal + streak broken (was ≥3, now 0)
    if (goals.contains('motivation') && moodState.currentStreakDays == 0 &&
        entries.isNotEmpty) {
      alerts.add(const PersonalizedAlert(
        level: PersonalizedAlertLevel.info,
        title: 'Streak reset — restart today',
        message: "Missing a day doesn't erase your progress. One small action now gets momentum back.",
        actionLabel: 'Log mood now',
        actionRoute: AppRoutes.moodTracker,
        icon: LucideIcons.flame,
      ));
    }

    // Limit to 2 alerts max — most critical first
    alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
    return alerts.take(2).toList();
  }

  /// Returns a goal-aware Maya message for the hero card.
  static String getMayaHeroMessage(
    UserModel? user,
    MoodState moodState,
    int streakDays,
  ) {
    final goals = user?.goals ?? [];
    final today = moodState.todayEntry;
    final criticals = moodState.criticalAlerts;
    final warnings = moodState.warningAlerts;

    if (criticals.isNotEmpty) {
      return "I've noticed you might be going through a really tough time. You're not alone in this — I'm here to listen whenever you're ready.";
    }

    if (today == null) {
      if (goals.contains('anxiety')) return "Taking a moment to name how you feel is one of the most powerful anxiety tools there is. How are you doing right now?";
      if (goals.contains('sleep')) return "How did you sleep last night? Tracking your sleep is the first step toward better rest.";
      if (goals.contains('motivation')) return "Start your day with intention. A quick check-in keeps you connected to your goals.";
      if (goals.contains('depression')) return "I'm glad you're here. A small check-in today — even 30 seconds — can make a real difference.";
      final h = DateTime.now().hour;
      if (h < 12) return "Good morning! How are you feeling as you start your day?";
      if (h < 17) return "How's your afternoon going? Your wellbeing matters — let's check in.";
      return "How has your day been? I'd love to hear about it.";
    }

    if (today.moodScore <= 3) {
      if (goals.contains('depression')) return "I see today has been hard (${today.moodScore}/10). You showed up anyway — that takes courage. Want to talk?";
      if (goals.contains('anxiety')) return "A ${today.moodScore}/10 day — that's okay. When anxiety peaks, your breathing tools are right here.";
      return "I see today has been tough (${today.moodScore}/10). You're brave for showing up. Want to talk through it?";
    }

    if (today.moodScore >= 8) {
      if (goals.contains('motivation')) return "You're feeling great today (${today.moodScore}/10)! This is your momentum — let's use it.";
      return "You're feeling great today (${today.moodScore}/10)! 🌟 I love seeing you thriving. Let's keep it going!";
    }

    if (warnings.isNotEmpty) {
      return "I've noticed your mood trending down lately. Want to explore some coping strategies or just talk things through?";
    }

    if (streakDays >= 7) {
      return "You're on a $streakDays-day streak — that's incredible! Your consistency is genuinely making a difference to your wellbeing.";
    }

    if (goals.contains('mindfulness')) return "Every breath is a chance to come back to yourself. I'm here whenever you want to practise presence together.";
    if (goals.contains('social')) return "Connection is a core human need. The community is here for you — and so am I.";
    return "I'm here whenever you need support. Whether you want to reflect, vent, or learn — I've always got you.";
  }
}
