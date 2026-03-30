import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mindfulness_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/goal_plan_engine.dart';

// ─── Theme Constants  (rich deep-navy palette) ─────────────
const Color _kBg = Color(0xFF060D1F);         // deep navy
const Color _kSurface = Color(0xFF0D1B35);    // navy surface
const Color _kBorder = Color(0xFF1A3060);     // navy border
const Color _kTextPrimary = Colors.white;
const Color _kTextSecondary = Color(0xFF8BA4C8);

// ─── Exercise Data Model ───────────────────────────────────

class _ExData {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final int durationMin;
  final String difficulty;
  final IconData icon;
  final Color color;
  final bool isBreathing;
  final List<String> steps;

  const _ExData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.durationMin,
    required this.difficulty,
    required this.icon,
    required this.color,
    this.isBreathing = false,
    this.steps = const [],
  });
}

const _kExercises = [
  _ExData(
    id: 'box_breathing',
    title: 'Box Breathing',
    subtitle: 'Used by Navy SEALs for rapid stress relief',
    category: 'Breathing',
    durationMin: 5,
    difficulty: 'Beginner',
    icon: LucideIcons.square,
    color: Color(0xFF00BEB4),
    isBreathing: true,
  ),
  _ExData(
    id: '4_7_8',
    title: '4-7-8 Breathing',
    subtitle: 'Activates your parasympathetic nervous system',
    category: 'Breathing',
    durationMin: 7,
    difficulty: 'Beginner',
    icon: LucideIcons.activity,
    color: Color(0xFF4ECDC4),
    isBreathing: true,
  ),
  _ExData(
    id: 'deep_breathing',
    title: 'Deep Belly Breathing',
    subtitle: 'Diaphragmatic breathing for immediate calm',
    category: 'Breathing',
    durationMin: 5,
    difficulty: 'Beginner',
    icon: LucideIcons.circle,
    color: Color(0xFFFF6B9D),
    isBreathing: true,
  ),
  _ExData(
    id: 'body_scan',
    title: 'Body Scan',
    subtitle: 'Progressive relaxation from head to toe',
    category: 'Meditation',
    durationMin: 10,
    difficulty: 'Beginner',
    icon: LucideIcons.brain,
    color: Color(0xFF7C3AED),
    steps: [
      'Find a comfortable position, lying down or seated.',
      'Close your eyes and take 3 slow, deep breaths.',
      'Bring attention to the top of your head — notice any sensations without judgment.',
      'Slowly move awareness down to your forehead, eyes, and jaw. Release any tension.',
      'Continue through your neck, shoulders, arms, and hands. Let them soften.',
      'Move to your chest — notice your heartbeat and each breath rising and falling.',
      'Scan your abdomen, lower back, and hips. Allow them to relax completely.',
      'Continue through your thighs, knees, calves, feet, and toes.',
      'Now feel your entire body as one, heavy and relaxed.',
      'Take a final deep breath, wiggle your fingers, and slowly open your eyes.',
    ],
  ),
  _ExData(
    id: 'loving_kindness',
    title: 'Loving Kindness',
    subtitle: 'Cultivate compassion for yourself and others',
    category: 'Meditation',
    durationMin: 8,
    difficulty: 'Intermediate',
    icon: LucideIcons.heartHandshake,
    color: Color(0xFFEC4899),
    steps: [
      'Sit comfortably and close your eyes.',
      'Take a few slow, deep breaths to settle your mind.',
      'Bring yourself to mind. Silently repeat: "May I be happy. May I be safe. May I be healthy. May I live with ease."',
      'Feel these wishes genuinely — like warm sunlight filling your chest.',
      'Now bring someone you love to mind. Repeat the phrases for them.',
      'Extend to a neutral person — someone you see but don\'t know well.',
      'Now extend to someone difficult in your life. Offer them the same wishes.',
      'Finally, extend to all beings everywhere: "May all beings be happy and free."',
      'Rest in this feeling of open, warm compassion for a moment.',
      'Gently bring your awareness back and open your eyes.',
    ],
  ),
  _ExData(
    id: 'grounding_54321',
    title: '5-4-3-2-1 Grounding',
    subtitle: 'Anchor yourself in the present moment',
    category: 'Grounding',
    durationMin: 5,
    difficulty: 'Beginner',
    icon: LucideIcons.map,
    color: Color(0xFFF59E0B),
    steps: [
      'Find a comfortable seated position and take a slow breath in.',
      '5 THINGS YOU SEE — Look around. Name 5 things you can see right now.',
      '4 THINGS YOU FEEL — Notice 4 things you can physically feel (chair, floor, air on skin).',
      '3 THINGS YOU HEAR — Listen and identify 3 distinct sounds around you.',
      '2 THINGS YOU SMELL — Notice 2 scents in your environment (even subtle ones).',
      '1 THING YOU TASTE — Bring attention to any taste present in your mouth.',
      'Take a deep breath and notice how grounded and present you feel.',
      'Repeat the exercise if you need to ground yourself further.',
    ],
  ),
  _ExData(
    id: 'progressive_muscle',
    title: 'Progressive Muscle Relaxation',
    subtitle: 'Release physical tension systematically',
    category: 'Sleep',
    durationMin: 12,
    difficulty: 'Beginner',
    icon: LucideIcons.dumbbell,
    color: Color(0xFF6366F1),
    steps: [
      'Lie down comfortably and close your eyes.',
      'Take 3 slow, deep breaths to begin.',
      'FEET — Curl your toes tight for 5 seconds, then release. Feel the difference.',
      'CALVES — Flex your calf muscles for 5 seconds, then release.',
      'THIGHS — Tighten your thighs for 5 seconds, then let them go.',
      'ABDOMEN — Draw your stomach in tight for 5 seconds, then release.',
      'CHEST — Inhale deeply and hold for 5 seconds, then exhale fully.',
      'ARMS & HANDS — Clench your fists and tighten your arms for 5 seconds, release.',
      'SHOULDERS — Shrug them up to your ears for 5 seconds, then drop them.',
      'FACE — Scrunch all your facial muscles for 5 seconds, then release.',
      'Enjoy the wave of deep relaxation flowing through your entire body.',
      'Let yourself drift into peaceful, restful sleep.',
    ],
  ),
  _ExData(
    id: 'mindful_observation',
    title: 'Mindful Observation',
    subtitle: 'Train present-moment awareness with focus',
    category: 'Meditation',
    durationMin: 5,
    difficulty: 'Beginner',
    icon: LucideIcons.sparkles,
    color: Color(0xFF10B981),
    steps: [
      'Choose any natural object nearby (a plant, stone, candle flame, or cloud).',
      'Hold it or gaze at it gently — no agenda, no analysis.',
      'Simply observe it as if seeing it for the very first time.',
      'Notice its color, texture, shape, light and shadow.',
      'If your mind wanders, gently bring attention back to the object.',
      'Let yourself be fully absorbed in this single point of focus.',
      'After 5 minutes, take a breath and appreciate what you noticed.',
    ],
  ),
];

// ─── Sound Data ────────────────────────────────────────────

class _SoundData {
  final String label;
  final String emoji;
  final Color color;
  final String description;
  const _SoundData({
    required this.label,
    required this.emoji,
    required this.color,
    required this.description,
  });
}

const _kSounds = [
  _SoundData(label: 'Rain', emoji: '🌧️', color: Color(0xFF3B82F6), description: 'Gentle rainfall'),
  _SoundData(label: 'Forest', emoji: '🌲', color: Color(0xFF10B981), description: 'Birds & breeze'),
  _SoundData(label: 'Ocean', emoji: '🌊', color: Color(0xFF0EA5E9), description: 'Rolling waves'),
  _SoundData(label: 'Campfire', emoji: '🔥', color: Color(0xFFEF4444), description: 'Crackling fire'),
  _SoundData(label: 'White Noise', emoji: '〰️', color: Color(0xFF9CA3AF), description: 'Static calm'),
  _SoundData(label: 'Brown Noise', emoji: '🟤', color: Color(0xFF92400E), description: 'Deep hum'),
  _SoundData(label: 'Wind', emoji: '💨', color: Color(0xFF6366F1), description: 'Breezy gusts'),
  _SoundData(label: 'Birds', emoji: '🐦', color: Color(0xFFF59E0B), description: 'Morning chorus'),
];

const _kFocusPresets = [
  {'name': 'Deep Focus', 'sounds': 'Brown Noise + Rain', 'icon': '🎯', 'color': 0xFF6366F1},
  {'name': 'Sleep Ready', 'sounds': 'Ocean + White Noise', 'icon': '🌙', 'color': 0xFF3B82F6},
  {'name': 'Morning Calm', 'sounds': 'Birds + Forest', 'icon': '☀️', 'color': 0xFF10B981},
];

const _kCategories = ['All', 'Breathing', 'Meditation', 'Grounding', 'Sleep'];

// ─── Mindfulness Intelligence ───────────────────────────────

class _AdaptiveInfo {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _AdaptiveInfo({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  static _AdaptiveInfo resolve({
    required int minsToday,
    required int streakDays,
    required int? moodScore,
  }) {
    final hour = DateTime.now().hour;

    // 1. Streak about to break (evening + no practice)
    if (streakDays > 2 && minsToday == 0 && hour >= 19) {
      return _AdaptiveInfo(
        emoji: '🔥',
        title: 'Protect your $streakDays-day streak!',
        subtitle: 'A quick 5-minute session before midnight keeps it alive.',
        color: const Color(0xFFEF4444),
      );
    }

    // 2. Daily goal reached
    if (minsToday >= 10) {
      return _AdaptiveInfo(
        emoji: '🏆',
        title: 'Daily goal complete!',
        subtitle: '${minsToday} minutes of mindfulness today. Excellent work.',
        color: const Color(0xFF10B981),
      );
    }

    // 3. Low mood → breathing
    if (moodScore != null && moodScore <= 3) {
      return _AdaptiveInfo(
        emoji: '💙',
        title: 'Breathing can shift your state',
        subtitle: 'Box breathing activates your parasympathetic system in 4 minutes.',
        color: const Color(0xFF6366F1),
      );
    }

    // 4. High mood → channel it
    if (moodScore != null && moodScore >= 8) {
      return _AdaptiveInfo(
        emoji: '✨',
        title: "You're in a great state!",
        subtitle: 'Channel this energy into a loving kindness session for others.',
        color: const Color(0xFFF59E0B),
      );
    }

    // 5. Morning window
    if (hour >= 5 && hour < 10) {
      return _AdaptiveInfo(
        emoji: '🌅',
        title: 'Morning practice window',
        subtitle: 'Morning mindfulness reduces cortisol and improves focus all day.',
        color: const Color(0xFFF59E0B),
      );
    }

    // 6. Sleep wind-down
    if (hour >= 21 || hour < 5) {
      return _AdaptiveInfo(
        emoji: '🌙',
        title: 'Wind down for deeper sleep',
        subtitle: 'Progressive muscle relaxation reduces time to fall asleep by 20%.',
        color: const Color(0xFF6366F1),
      );
    }

    // 7. Afternoon slump
    if (hour >= 13 && hour < 16) {
      return _AdaptiveInfo(
        emoji: '⚡',
        title: 'Beat the afternoon slump',
        subtitle: '5 minutes of mindful breathing beats caffeine for energy and focus.',
        color: AppColors.primary,
      );
    }

    // Default
    return _AdaptiveInfo(
      emoji: '🧘',
      title: 'Take a mindful pause',
      subtitle: 'Even 3 minutes of stillness measurably reduces stress hormones.',
      color: AppColors.primary,
    );
  }
}

double _computeMindScore({
  required int minsToday,
  required int sessionsToday,
  required int streakDays,
  required int uniqueExercisesToday,
}) {
  // Daily goal component (0–40 pts): target 10 min
  final daily = min(minsToday / 10.0, 1.0) * 40;
  // Streak component (0–30 pts): target 7-day streak
  final streakPts = min(streakDays / 7.0, 1.0) * 30;
  // Variety component (0–20 pts): target 2+ unique exercises
  final variety = min(uniqueExercisesToday / 2.0, 1.0) * 20;
  // Engagement bonus (0–10 pts): at least 1 session
  final engage = sessionsToday > 0 ? 10.0 : 0.0;
  return (daily + streakPts + variety + engage).clamp(0.0, 100.0);
}

String _mindScoreLabel(double score) {
  if (score >= 80) return 'Thriving';
  if (score >= 60) return 'Growing';
  if (score >= 40) return 'Building';
  if (score >= 20) return 'Starting';
  return 'Begin Today';
}

Color _mindScoreColor(double score) {
  if (score >= 80) return const Color(0xFF10B981);
  if (score >= 60) return AppColors.primary;
  if (score >= 40) return const Color(0xFFF59E0B);
  if (score >= 20) return const Color(0xFF6366F1);
  return const Color(0xFF8B9DC3);
}

// Infer week practice from streak
bool _dayPracticed(int daysAgo, int streak, int sessionsToday) {
  if (daysAgo == 0) return sessionsToday > 0;
  if (daysAgo < 0) return false; // future
  // If today had a session, streak counts today too
  final streakOffset = sessionsToday > 0 ? 0 : 1;
  return daysAgo <= (streak - streakOffset);
}

// ─── Main Screen ───────────────────────────────────────────

class MindfulnessScreen extends ConsumerStatefulWidget {
  const MindfulnessScreen({super.key});

  @override
  ConsumerState<MindfulnessScreen> createState() => _MindfulnessScreenState();
}

class _MindfulnessScreenState extends ConsumerState<MindfulnessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mindState = ref.watch(mindfulnessProvider);
    final streakState = ref.watch(streakProvider);
    final moodState = ref.watch(moodProvider);
    final user = ref.watch(currentUserProvider);

    final mindStreak = streakState.streak(StreakType.mindfulness);
    final rec = GoalPlanEngine.getMindfulnessRecommendation(
      user,
      moodState.todayEntry?.moodScore,
    );

    final filtered = _category == 'All'
        ? _kExercises
        : _kExercises.where((e) => e.category == _category).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 152,
              pinned: true,
              backgroundColor: const Color(0xFF060D1F),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: AnimatedOpacity(
                opacity: innerBoxIsScrolled ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    const Icon(LucideIcons.brain, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Mindfulness Center',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _MindHeader(
                  mindState: mindState,
                  mindStreak: mindStreak,
                ),
              ),
              bottom: TabBar(
                controller: _tab,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: _kTextSecondary,
                labelStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: _kBorder,
                tabs: const [
                  Tab(text: 'Practice'),
                  Tab(text: 'Sounds'),
                  Tab(text: 'Stats'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tab,
            children: [
              _PracticeTab(
                mindState: mindState,
                rec: rec,
                filtered: filtered,
                category: _category,
                moodScore: moodState.todayEntry?.moodScore,
                onCategoryChanged: (c) => setState(() => _category = c),
                onGuideComplete: (ex, actualSeconds) {
                  ref.read(mindfulnessProvider.notifier).recordSession(
                        exerciseId: ex.id,
                        exerciseName: ex.title,
                        cyclesCompleted: ex.steps.length,
                        durationSeconds: actualSeconds > 0
                            ? actualSeconds
                            : ex.durationMin * 60,
                      );
                  ref.read(streakProvider.notifier).recordActivity(StreakType.mindfulness);
                },
              ),
              _SoundsTab(
                mindState: mindState,
                onToggleSound: (label) =>
                    ref.read(mindfulnessProvider.notifier).setActiveSound(label),
              ),
              _StatsTab(mindState: mindState, mindStreak: mindStreak),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────

class _MindHeader extends StatelessWidget {
  final MindfulnessState mindState;
  final StreakModel? mindStreak;

  const _MindHeader({
    required this.mindState,
    required this.mindStreak,
  });

  @override
  Widget build(BuildContext context) {
    final mins = mindState.totalMinutesToday;
    final sessions = mindState.totalSessionsToday;
    final streak = mindStreak?.currentStreak ?? 0;
    const goalMins = 10;
    final goalProgress = (mins / goalMins).clamp(0.0, 1.0);
    final goalDone = goalProgress >= 1.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B5A), Color(0xFF0A1C3E), Color(0xFF060D1F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title + goal badge ────────────────────────
              Row(
                children: [
                  const Text(
                    'Mindfulness Center',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: goalDone
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: goalDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : _kBorder,
                      ),
                    ),
                    child: Text(
                      goalDone ? '✓ Goal met!' : '${mins}/$goalMins min',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: goalDone ? const Color(0xFF10B981) : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── 3 stat chips in one row ───────────────────
              Row(
                children: [
                  _MiniStat(icon: LucideIcons.clock, value: '${mins}m', label: 'Today', color: AppColors.primary),
                  const SizedBox(width: 8),
                  _MiniStat(icon: LucideIcons.circleCheck, value: '$sessions', label: 'Sessions', color: const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _MiniStat(icon: LucideIcons.flame, value: '${streak}d', label: 'Streak', color: const Color(0xFFF59E0B)),
                ],
              ),

              const SizedBox(height: 10),

              // ── Thin goal bar ─────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: goalProgress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goalDone ? const Color(0xFF10B981) : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 9,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Practice Tab ──────────────────────────────────────────

class _PracticeTab extends StatelessWidget {
  final MindfulnessState mindState;
  final ({String exercise, String reason}) rec;
  final List<_ExData> filtered;
  final String category;
  final int? moodScore;
  final ValueChanged<String> onCategoryChanged;
  final void Function(_ExData ex, int actualSeconds) onGuideComplete;

  const _PracticeTab({
    required this.mindState,
    required this.rec,
    required this.filtered,
    required this.category,
    required this.onCategoryChanged,
    required this.onGuideComplete,
    this.moodScore,
  });

  @override
  Widget build(BuildContext context) {
    final adaptive = _AdaptiveInfo.resolve(
      minsToday: mindState.totalMinutesToday,
      streakDays: 0, // passed from parent but we use what's available
      moodScore: moodScore,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Adaptive State Banner ─────────────────────────
          _AdaptiveBanner(info: adaptive)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: -0.05, end: 0),

          const SizedBox(height: 14),

          // ── Recommendation Card ───────────────────────────
          _RecommendationCard(rec: rec, onGuideComplete: onGuideComplete).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // ── Category Filter ───────────────────────────────
          _SectionLabel(icon: LucideIcons.slidersHorizontal, label: 'Browse Exercises'),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kCategories.map((cat) {
                final sel = cat == category;
                Color catColor = AppColors.primary;
                if (cat == 'Breathing') catColor = AppColors.primary;
                if (cat == 'Meditation') catColor = const Color(0xFF7C3AED);
                if (cat == 'Grounding') catColor = const Color(0xFFF59E0B);
                if (cat == 'Sleep') catColor = const Color(0xFF6366F1);

                return GestureDetector(
                  onTap: () => onCategoryChanged(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? catColor : _kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? catColor : _kBorder,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _kTextSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // ── Exercise List ─────────────────────────────────
          ...filtered.asMap().entries.map((e) {
            final idx = e.key;
            final ex = e.value;
            return _ExerciseCard(
              ex: ex,
              isDoneToday: mindState.isCompletedToday(ex.id),
              onGuideComplete: (seconds) => onGuideComplete(ex, seconds),
            )
                .animate(delay: Duration(milliseconds: 60 * idx))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.05, end: 0);
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AdaptiveBanner extends StatelessWidget {
  final _AdaptiveInfo info;
  const _AdaptiveBanner({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: info.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.subtitle,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: _kTextSecondary,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final ({String exercise, String reason}) rec;
  final void Function(_ExData ex, int seconds) onGuideComplete;
  const _RecommendationCard({required this.rec, required this.onGuideComplete});

  @override
  Widget build(BuildContext context) {
    // Find matching exercise for navigation
    final match = _kExercises.where(
      (e) => e.title.toLowerCase().contains(rec.exercise.toLowerCase().split(' ').first.toLowerCase()),
    ).toList();
    final ex = match.isNotEmpty ? match.first : _kExercises.first;

    return GestureDetector(
      onTap: () {
        if (ex.isBreathing) {
          context.push(AppRoutes.breathing, extra: {'exerciseId': ex.id});
        } else {
          _showGuideSheet(context, ex, onComplete: (s) => onGuideComplete(ex, s));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.25),
              AppColors.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommended for You',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.exercise,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rec.reason,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: _kTextSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.play, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final _ExData ex;
  final bool isDoneToday;
  final void Function(int seconds)? onGuideComplete;

  const _ExerciseCard({required this.ex, required this.isDoneToday, this.onGuideComplete});

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(ex.category);

    return GestureDetector(
      onTap: () {
        if (ex.isBreathing) {
          context.push(AppRoutes.breathing, extra: {'exerciseId': ex.id});
        } else {
          _showGuideSheet(context, ex, onComplete: onGuideComplete);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDoneToday ? ex.color.withValues(alpha: 0.4) : _kBorder,
          ),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ex.color.withValues(alpha: 0.3),
                    ex.color.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: ex.color.withValues(alpha: 0.3)),
              ),
              child: Icon(ex.icon, color: ex.color, size: 22),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ex.title,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                      if (isDoneToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.circleCheck, size: 10, color: Color(0xFF10B981)),
                              SizedBox(width: 3),
                              Text(
                                'Done',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ex.subtitle,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: _kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _TagBadge(label: ex.category, color: catColor),
                      const SizedBox(width: 6),
                      _TagBadge(
                        label: '${ex.durationMin} min',
                        icon: LucideIcons.clock,
                        color: _kTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      _TagBadge(label: ex.difficulty, color: _diffColor(ex.difficulty)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              ex.isBreathing ? LucideIcons.play : LucideIcons.bookmarkCheck,
              size: 18,
              color: ex.color.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {
    return switch (cat) {
      'Breathing' => AppColors.primary,
      'Meditation' => const Color(0xFF7C3AED),
      'Grounding' => const Color(0xFFF59E0B),
      'Sleep' => const Color(0xFF6366F1),
      _ => _kTextSecondary,
    };
  }

  Color _diffColor(String diff) {
    return switch (diff) {
      'Beginner' => const Color(0xFF10B981),
      'Intermediate' => const Color(0xFFF59E0B),
      'Advanced' => const Color(0xFFEF4444),
      _ => _kTextSecondary,
    };
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _TagBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sounds Tab ────────────────────────────────────────────

class _SoundsTab extends StatelessWidget {
  final MindfulnessState mindState;
  final void Function(String label) onToggleSound;

  const _SoundsTab({required this.mindState, required this.onToggleSound});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: LucideIcons.music2, label: 'Ambient Sounds'),
          const SizedBox(height: 4),
          Text(
            'Tap to toggle · Multiple sounds can play together',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: _kTextSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // ── Sound Grid ─────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemCount: _kSounds.length,
            itemBuilder: (_, i) {
              final sound = _kSounds[i];
              final isActive = mindState.activeSound == sound.label && mindState.soundPlaying;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleSound(sound.label);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isActive
                        ? sound.color.withValues(alpha: 0.18)
                        : _kSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? sound.color : _kBorder,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Text(sound.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                sound.label,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? sound.color : _kTextPrimary,
                                ),
                              ),
                              Text(
                                sound.description,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  color: _kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          _PulsingDot(color: sound.color),
                      ],
                    ),
                  ),
                ),
              )
                  .animate(delay: Duration(milliseconds: 50 * i))
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
            },
          ),

          const SizedBox(height: 24),

          // ── Focus Presets ──────────────────────────────────
          _SectionLabel(icon: LucideIcons.zap, label: 'Focus Presets'),
          const SizedBox(height: 14),

          ..._kFocusPresets.asMap().entries.map((e) {
            final preset = e.value;
            final color = Color(preset['color'] as int);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        preset['icon'] as String,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset['name'] as String,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                          ),
                        ),
                        Text(
                          preset['sounds'] as String,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Play',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: Duration(milliseconds: 80 * e.key)).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
          }),

          const SizedBox(height: 24),

          // ── Coming Soon Card ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.headphones, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Guided Audio Sessions',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Full audio-guided meditations coming soon',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SOON',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Stats Tab ─────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final MindfulnessState mindState;
  final StreakModel? mindStreak;

  const _StatsTab({required this.mindState, required this.mindStreak});

  @override
  Widget build(BuildContext context) {
    final mins = mindState.totalMinutesToday;
    final sessions = mindState.totalSessionsToday;
    final streak = mindStreak?.currentStreak ?? 0;
    final longest = mindStreak?.longestStreak ?? 0;

    // Compute mindfulness score
    final uniqueExercises = mindState.todaySessions
        .map((s) => s.exerciseId)
        .toSet()
        .length;
    final score = _computeMindScore(
      minsToday: mins,
      sessionsToday: sessions,
      streakDays: streak,
      uniqueExercisesToday: uniqueExercises,
    );

    // Categories tried today
    final categoriesTried = mindState.todaySessions
        .map((s) => _kExercises.where((e) => e.id == s.exerciseId).isEmpty
            ? ''
            : _kExercises.firstWhere((e) => e.id == s.exerciseId).category)
        .where((c) => c.isNotEmpty)
        .toSet();

    // Weekly grid (Mon–Sun of current week)
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1=Mon, 7=Sun
    final weekGridData = List.generate(7, (i) {
      final dayNum = i + 1; // 1=Mon, 7=Sun
      final daysAgo = todayWeekday - dayNum;
      final isFuture = daysAgo < 0;
      final isToday = daysAgo == 0;
      final practiced = isFuture ? false : _dayPracticed(daysAgo, streak, sessions);
      final dayMins = isToday ? mins : (practiced ? 10 : 0);
      return (label: ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i], isToday: isToday, isFuture: isFuture, practiced: practiced, mins: dayMins);
    });

    // Milestone logic
    const milestones = [3, 7, 14, 30, 60, 100];
    final nextMilestone = milestones.firstWhere((m) => streak < m, orElse: () => 365);
    final prevMilestone = milestones.lastWhere((m) => m <= streak, orElse: () => 0);
    final milestoneProgress = nextMilestone > prevMilestone
        ? (streak - prevMilestone) / (nextMilestone - prevMilestone)
        : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mindfulness Score Card ─────────────────────────
          _MindScoreCard(score: score, minsToday: mins, streak: streak, sessions: sessions)
              .animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 20),

          // ── This Week Grid ────────────────────────────────
          _SectionLabel(icon: LucideIcons.calendarDays, label: 'This Week'),
          const SizedBox(height: 12),
          _WeekGrid(days: weekGridData, todayMins: mins)
              .animate().fadeIn(duration: 400.ms, delay: 80.ms),

          const SizedBox(height: 20),

          // ── Category Explorer ──────────────────────────────
          _SectionLabel(icon: LucideIcons.compass, label: 'Category Explorer'),
          const SizedBox(height: 8),
          const Text(
            'Try all 4 categories for a complete mindfulness practice',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: _kTextSecondary),
          ),
          const SizedBox(height: 12),
          _CategoryExplorer(categoriesTried: categoriesTried)
              .animate().fadeIn(duration: 400.ms, delay: 120.ms),

          const SizedBox(height: 20),

          // ── Today Summary ─────────────────────────────────
          _SectionLabel(icon: LucideIcons.sun, label: "Today's Practice"),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _BigStatCard(
                  value: '${mins}m',
                  label: 'Minutes',
                  icon: LucideIcons.clock,
                  color: AppColors.primary,
                  sublabel: mins >= 10 ? '🎯 Goal reached!' : '${10 - mins}m to goal',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigStatCard(
                  value: '$sessions',
                  label: 'Sessions',
                  icon: LucideIcons.circleCheck,
                  color: const Color(0xFF10B981),
                  sublabel: sessions == 0 ? 'Start your day' : sessions == 1 ? 'Great start!' : 'You\'re crushing it!',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Streak Card ───────────────────────────────────
          _SectionLabel(icon: LucideIcons.flame, label: 'Mindfulness Streak'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  const Color(0xFFF59E0B).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 8),
                            Text(
                              '$streak',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'days',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Current streak',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$longest',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                          ),
                        ),
                        const Text(
                          'Best streak',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Next milestone: $nextMilestone days',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: _kTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$streak/$nextMilestone',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: milestoneProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Session History ───────────────────────────────
          _SectionLabel(icon: LucideIcons.clipboardList, label: "Today's Sessions"),
          const SizedBox(height: 12),

          if (mindState.todaySessions.isEmpty)
            _EmptySessionCard()
          else
            ...mindState.todaySessions.reversed.toList().asMap().entries.map((e) {
              final session = e.value;
              final sessionMins = (session.durationSeconds / 60).floor();
              final secs = session.durationSeconds % 60;
              final timeStr = sessionMins > 0 ? '${sessionMins}m ${secs}s' : '${secs}s';
              final hour = session.completedAt.hour;
              final ampm = hour >= 12 ? 'PM' : 'AM';
              final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
              final timeLabel = '$h:${session.completedAt.minute.toString().padLeft(2, '0')} $ampm';
              final exMatch = _kExercises.where((ex) => ex.id == session.exerciseId);
              final exData = exMatch.isNotEmpty ? exMatch.first : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (exData?.color ?? AppColors.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        exData?.icon ?? LucideIcons.brain,
                        size: 18,
                        color: exData?.color ?? AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.exerciseName,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                          Text(
                            '${session.cyclesCompleted} steps · $timeStr · $timeLabel',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (exData != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: exData.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exData.category,
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w700, color: exData.color),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.circleCheck, size: 18, color: Color(0xFF10B981)),
                  ],
                ),
              ).animate(delay: Duration(milliseconds: 60 * e.key)).fadeIn(duration: 300.ms);
            }),

          const SizedBox(height: 20),

          // ── Tip Card ──────────────────────────────────────
          _TipCard(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Stats Widgets ──────────────────────────────────────────

class _MindScoreCard extends StatelessWidget {
  final double score;
  final int minsToday;
  final int streak;
  final int sessions;

  const _MindScoreCard({
    required this.score,
    required this.minsToday,
    required this.streak,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _mindScoreColor(score);
    final label = _mindScoreLabel(score);
    final dailyPct = min(minsToday / 10.0, 1.0);
    final streakPct = min(streak / 7.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withValues(alpha: 0.18),
            scoreColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Circular score ring
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.round()}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      'pts',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        color: scoreColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mindfulness Score',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                // Daily goal bar
                _ScoreBar(label: 'Daily goal', value: dailyPct, color: AppColors.primary),
                const SizedBox(height: 6),
                _ScoreBar(label: 'Streak (7d)', value: streakPct, color: const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ScoreBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 9, color: _kTextSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final List<({String label, bool isToday, bool isFuture, bool practiced, int mins})> days;
  final int todayMins;

  const _WeekGrid({required this.days, required this.todayMins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: days.asMap().entries.map((entry) {
              final day = entry.value;
              Color dotColor;
              if (day.isFuture) {
                dotColor = Colors.white.withValues(alpha: 0.06);
              } else if (day.isToday) {
                dotColor = day.practiced ? AppColors.primary : Colors.white.withValues(alpha: 0.06);
              } else {
                dotColor = day.practiced ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.06);
              }

              return Expanded(
                child: Column(
                  children: [
                    // Day dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: day.isToday
                              ? AppColors.primary
                              : day.practiced
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.08),
                          width: day.isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: day.isFuture
                            ? null
                            : day.practiced
                                ? Icon(
                                    day.isToday ? LucideIcons.flame : LucideIcons.check,
                                    size: day.isToday ? 14 : 12,
                                    color: Colors.white,
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      day.label,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w500,
                        color: day.isToday ? AppColors.primary : _kTextSecondary,
                      ),
                    ),
                    if (day.mins > 0)
                      Text(
                        '${day.mins}m',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: day.isToday ? AppColors.primary : const Color(0xFF10B981),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WeekLegend(color: const Color(0xFF10B981), label: 'Practiced'),
              const SizedBox(width: 16),
              _WeekLegend(color: AppColors.primary, label: 'Today'),
              const SizedBox(width: 16),
              _WeekLegend(color: Colors.white.withValues(alpha: 0.15), label: 'Missed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _WeekLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: _kTextSecondary)),
      ],
    );
  }
}

class _CategoryExplorer extends StatelessWidget {
  final Set<String> categoriesTried;
  const _CategoryExplorer({required this.categoriesTried});

  static const _categories = [
    ('Breathing', LucideIcons.wind, Color(0xFF00BEB4)),
    ('Meditation', LucideIcons.brain, Color(0xFF7C3AED)),
    ('Grounding', LucideIcons.map, Color(0xFFF59E0B)),
    ('Sleep', LucideIcons.moon, Color(0xFF6366F1)),
  ];

  @override
  Widget build(BuildContext context) {
    final done = categoriesTried.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: _categories.map((cat) {
              final tried = categoriesTried.contains(cat.$1);
              final color = cat.$3;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tried ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tried ? color : Colors.white.withValues(alpha: 0.08),
                          width: tried ? 1.5 : 1,
                        ),
                      ),
                      child: Icon(
                        cat.$2,
                        size: 20,
                        color: tried ? color : _kTextSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.$1,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tried ? color : _kTextSecondary.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (tried)
                      Text(
                        '✓',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 10, color: color, fontWeight: FontWeight.w900),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / 4.0,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                done == 4 ? const Color(0xFF10B981) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            done == 4
                ? '🏆 Full explorer — all 4 categories tried today!'
                : '$done/4 categories explored today',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: done == 4 ? const Color(0xFF10B981) : _kTextSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────

class _BigStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String sublabel;

  const _BigStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: _kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Text('🧘', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          const Text(
            'No sessions yet today',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete a breathing exercise or meditation to see your sessions here.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: _kTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  static final _tips = [
    ('Consistency beats intensity', 'Even 5 minutes daily is more powerful than one long session per week.'),
    ('Breath is your anchor', 'Whenever anxiety rises, return to your breath — it\'s always with you.'),
    ('Thoughts are not facts', 'In mindfulness, you observe thoughts without identifying with them.'),
    ('Progress, not perfection', 'Your mind will wander during meditation. That\'s normal and okay.'),
    ('The pause is power', 'A mindful pause before reacting can change the entire outcome of a situation.'),
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.15),
            const Color(0xFF7C3AED).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.$1,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.$2,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: _kTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Guided Session Bottom Sheet ───────────────────────────

void _showGuideSheet(BuildContext context, _ExData ex, {void Function(int seconds)? onComplete}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GuideSheet(ex: ex, onComplete: onComplete),
  );
}

class _GuideSheet extends StatefulWidget {
  final _ExData ex;
  final void Function(int seconds)? onComplete;
  const _GuideSheet({required this.ex, this.onComplete});

  @override
  State<_GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<_GuideSheet> {
  int _currentStep = 0;
  bool _started = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSession() {
    setState(() {
      _started = true;
      _currentStep = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String get _elapsedStr {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    final steps = ex.steps;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ex.color.withValues(alpha: 0.3),
                            ex.color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(ex.icon, color: ex.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ex.title,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _kTextPrimary,
                                  ),
                                ),
                              ),
                              if (_started)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ex.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: ex.color.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.timer, size: 10, color: ex.color),
                                      const SizedBox(width: 4),
                                      Text(
                                        _elapsedStr,
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: ex.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            '${ex.durationMin} min · ${ex.difficulty} · ${steps.length} steps',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Progress Bar ─────────────────────────────────
              if (_started)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Step ${_currentStep + 1} of ${steps.length}',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: _kTextSecondary,
                            ),
                          ),
                          Text(
                            '${((_currentStep / steps.length) * 100).round()}%',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ex.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _currentStep / steps.length,
                          minHeight: 5,
                          backgroundColor: _kBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(ex.color),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // ── Steps List ───────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: steps.length,
                  itemBuilder: (_, i) {
                    final isPast = _started && i < _currentStep;
                    final isCurrent = _started && i == _currentStep;

                    return GestureDetector(
                      onTap: _started ? () => setState(() => _currentStep = i) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? ex.color.withValues(alpha: 0.15)
                              : isPast
                                  ? _kBg.withValues(alpha: 0.5)
                                  : _kBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? ex.color : _kBorder,
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step number / check
                            Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPast
                                    ? const Color(0xFF10B981)
                                    : isCurrent
                                        ? ex.color
                                        : _kSurface,
                                border: Border.all(
                                  color: isPast
                                      ? const Color(0xFF10B981)
                                      : isCurrent
                                          ? ex.color
                                          : _kBorder,
                                ),
                              ),
                              child: Center(
                                child: isPast
                                    ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                                    : Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isCurrent ? Colors.white : _kTextSecondary,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                steps[i],
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                  color: isPast
                                      ? _kTextSecondary
                                      : isCurrent
                                          ? _kTextPrimary
                                          : _kTextSecondary.withValues(alpha: 0.6),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom Controls ──────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: _kSurface,
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: !_started
                    ? _SheetButton(
                        label: 'Start Guided Session',
                        icon: LucideIcons.play,
                        color: ex.color,
                        onTap: _startSession,
                      )
                    : Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: _SheetButton(
                                label: 'Back',
                                icon: LucideIcons.arrowLeft,
                                color: _kTextSecondary,
                                onTap: () => setState(() => _currentStep--),
                                filled: false,
                              ),
                            ),
                          if (_currentStep > 0) const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _currentStep < steps.length - 1
                                ? _SheetButton(
                                    label: 'Next Step',
                                    icon: LucideIcons.arrowRight,
                                    color: ex.color,
                                    onTap: () => setState(() => _currentStep++),
                                  )
                                : _SheetButton(
                                    label: 'Complete ✓',
                                    icon: LucideIcons.circleCheck,
                                    color: const Color(0xFF10B981),
                                    onTap: () {
                                      _timer?.cancel();
                                      widget.onComplete?.call(_elapsedSeconds);
                                      Navigator.pop(context);
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}
