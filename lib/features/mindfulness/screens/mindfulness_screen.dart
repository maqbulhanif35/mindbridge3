import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/mindfulness_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';

class MindfulnessScreen extends ConsumerWidget {
  const MindfulnessScreen({super.key});

  // Smart recommendation based on mood + time of day
  static String _getRecommendation(int? moodScore) {
    final h = DateTime.now().hour;
    if (moodScore != null && moodScore <= 3) return '4-7-8 Breathing';
    if (moodScore != null && moodScore <= 5) return 'Box Breathing';
    if (h < 9) return 'Box Breathing';
    if (h < 13) return '4-7-8 Breathing';
    if (h < 18) return 'Physiological Sigh';
    return '4-7-8 Breathing';
  }

  static String _getRecommendationReason(int? moodScore) {
    final h = DateTime.now().hour;
    if (moodScore != null && moodScore <= 3) return 'Based on your low mood today';
    if (moodScore != null && moodScore <= 5) return 'For moderate stress relief';
    if (h < 9) return 'Perfect morning focus starter';
    if (h < 13) return 'Mid-morning nervous system reset';
    if (h < 18) return 'Afternoon stress relief';
    return 'Wind-down for the evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodState = ref.watch(moodProvider);
    final streakState = ref.watch(streakProvider);
    final mindState = ref.watch(mindfulnessProvider);
    final topPad = MediaQuery.of(context).padding.top;

    final todayMood = moodState.todayEntry?.moodScore;
    final mindStreak = streakState.streak(StreakType.mindfulness);
    final recommendation = _getRecommendation(todayMood);
    final recommendationReason = _getRecommendationReason(todayMood);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            // ─── Hero Header ──────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                topPad: topPad,
                mindStreak: mindStreak,
                mindState: mindState,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Today's Progress ─────────────────
                  _TodayProgress(mindState: mindState, streakState: streakState)
                      .animate()
                      .fadeIn(delay: 80.ms),

                  const SizedBox(height: 20),

                  // ─── Recommended ─────────────────────
                  _RecommendedCard(
                    exercise: recommendation,
                    reason: recommendationReason,
                    exercises: AppStrings.breathingExercises,
                    onTap: (id) => context.push(AppRoutes.breathing,
                        extra: {'exerciseId': id}),
                  ).animate().fadeIn(delay: 120.ms),

                  const SizedBox(height: 24),

                  // ─── Quick Rescue (Micro-exercises) ──
                  const _SectionTitle(
                    title: 'Quick Rescue',
                    subtitle: '30 sec — 2 min resets for any moment',
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 12),

                  _MicroExerciseRow()
                      .animate()
                      .fadeIn(delay: 170.ms),

                  const SizedBox(height: 24),

                  // ─── Daily Sequence ───────────────────
                  _DailySequenceCard()
                      .animate()
                      .fadeIn(delay: 140.ms),

                  const SizedBox(height: 24),

                  // ─── Breathing Exercises ──────────────
                  const _SectionTitle(
                    title: 'Breathing Exercises',
                    subtitle: 'Activate your calm response',
                  ).animate().fadeIn(delay: 160.ms),

                  const SizedBox(height: 12),

                  ...AppStrings.breathingExercises.asMap().entries.map((e) {
                    final ex = e.value;
                    final done =
                        mindState.isCompletedToday(ex['id'] as String);
                    return _BreathingCard(
                      exercise: ex,
                      isDoneToday: done,
                      onTap: () => context.push(
                        AppRoutes.breathing,
                        extra: {'exerciseId': ex['id']},
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (160 + e.key * 70).ms)
                        .slideX(begin: 0.15);
                  }),

                  const SizedBox(height: 24),

                  // ─── Guided Meditation ────────────────
                  const _SectionTitle(
                    title: 'Guided Meditation',
                    subtitle: 'Find your inner stillness',
                  ).animate().fadeIn(delay: 340.ms),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 166,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _meditations.map((m) {
                        return _MeditationCard(
                          data: m,
                          onTap: () =>
                              _showMeditationPlayer(context, m),
                        );
                      }).toList(),
                    ),
                  ).animate().fadeIn(delay: 380.ms),

                  const SizedBox(height: 24),

                  // ─── Ambient Sounds ───────────────────
                  const _SectionTitle(
                    title: 'Ambient Sounds',
                    subtitle: 'Create your focus environment',
                  ).animate().fadeIn(delay: 420.ms),

                  const SizedBox(height: 12),

                  _AmbientSoundGrid(mindState: mindState)
                      .animate()
                      .fadeIn(delay: 460.ms),

                  const SizedBox(height: 24),

                  // ─── Grounding Techniques ─────────────
                  const _SectionTitle(
                    title: 'Grounding Techniques',
                    subtitle: 'For moments of overwhelm',
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 12),

                  ..._groundingTechniques.asMap().entries.map((e) {
                    return _GroundingCard(
                      data: e.value,
                      onTap: () =>
                          _showGroundingDetail(context, e.value),
                    )
                        .animate()
                        .fadeIn(delay: (500 + e.key * 60).ms)
                        .slideY(begin: 0.1);
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Meditation data ────────────────────────────────────

  static const _meditations = [
    _MeditationData(
      title: 'Body Scan',
      duration: '10 min',
      emoji: '🌊',
      color: AppColors.info,
      steps: [
        'Close your eyes and take 3 deep breaths.',
        'Bring attention to the top of your head. Notice any tension.',
        'Slowly move down to your face — jaw, eyes, forehead.',
        'Continue to your neck and shoulders. Let them drop.',
        'Move to your chest. Feel each breath expand your lungs.',
        'Scan your stomach, lower back, and hips.',
        'Move through your legs, knees, calves, and feet.',
        'Rest in whole-body awareness for a moment.',
        'Slowly open your eyes. Notice how you feel.',
      ],
    ),
    _MeditationData(
      title: 'Loving Kindness',
      duration: '12 min',
      emoji: '💝',
      color: AppColors.tertiary,
      steps: [
        'Sit comfortably and close your eyes.',
        'Think of someone you love easily — a pet, a child, a close friend.',
        'Feel the warmth in your chest. Let it grow.',
        'Silently repeat: "May you be happy. May you be safe."',
        'Now direct this warmth toward yourself: "May I be happy. May I be at peace."',
        'Extend it to a neutral person you know, maybe a neighbor.',
        'Now to someone difficult in your life. Send warmth without judgment.',
        'Finally expand to all beings: "May all beings be happy and free."',
        'Rest in this open, warm awareness. Breathe slowly.',
      ],
    ),
    _MeditationData(
      title: 'Anxiety Relief',
      duration: '8 min',
      emoji: '🌸',
      color: AppColors.primary,
      steps: [
        'Notice you are anxious. Name it: "This is anxiety."',
        'Take a slow breath in for 4 counts. Hold for 2.',
        'Exhale slowly for 6 counts. Repeat twice.',
        'Ground yourself — name 3 things you can see right now.',
        'Feel your feet on the floor. Press them down gently.',
        'Place one hand on your heart. Feel your heartbeat.',
        'Tell yourself: "I am safe right now, in this moment."',
        'Take 3 more slow breaths. Let each exhale release tension.',
        'When ready, gently open your eyes.',
      ],
    ),
    _MeditationData(
      title: 'Sleep Prep',
      duration: '15 min',
      emoji: '🌙',
      color: AppColors.primaryDark,
      steps: [
        'Lie down comfortably. Dim the lights if possible.',
        'Take a deep breath in. Exhale slowly and completely.',
        'Tense your feet for 5 seconds. Release. Feel them relax.',
        'Tense your calves for 5 seconds. Release.',
        'Continue up your body — thighs, stomach, hands, shoulders.',
        'Let your jaw go slack. Let your eyelids feel heavy.',
        'Visualize a calm place — a beach, a forest, a cozy room.',
        'With each exhale, let go a little more.',
        'Allow sleep to come naturally. You are safe.',
      ],
    ),
  ];

  // ─── Grounding data ─────────────────────────────────────

  static const _groundingTechniques = [
    _GroundingData(
      title: '5-4-3-2-1 Method',
      description: 'Use your 5 senses to anchor yourself to the present.',
      emoji: '✋',
      color: AppColors.tertiary,
      steps: [
        '5 things you can SEE right now',
        '4 things you can TOUCH right now',
        '3 things you can HEAR right now',
        '2 things you can SMELL right now',
        '1 thing you can TASTE right now',
      ],
      tip: 'Works best when anxiety spikes suddenly.',
    ),
    _GroundingData(
      title: 'Cold Water Reset',
      description: 'Activate the dive reflex to calm your nervous system.',
      emoji: '💧',
      color: Color(0xFF0EA5E9),
      steps: [
        'Fill a bowl or sink with cold water',
        'Take a deep breath in',
        'Submerge your face for 15–30 seconds (or splash face)',
        'Your heart rate slows within seconds',
        'Dry off. Take 3 slow breaths.',
      ],
      tip: 'Triggers the mammalian dive reflex — instant calm.',
    ),
    _GroundingData(
      title: 'Progressive Muscle Relaxation',
      description: 'Tense and release muscle groups to melt physical tension.',
      emoji: '💪',
      color: Color(0xFF10B981),
      steps: [
        'Start with your feet — tense for 5 seconds',
        'Release completely. Notice the difference.',
        'Move up: calves → thighs → stomach → hands → shoulders',
        'Each group: 5 seconds tension, full release',
        'End with your face — scrunch it up, then let go',
        'Breathe slowly and feel your whole body heavy and relaxed',
      ],
      tip: 'Particularly effective before sleep or during exam stress.',
    ),
    _GroundingData(
      title: 'Physiological Sigh',
      description: 'The fastest way to reduce stress in real time.',
      emoji: '🌬️',
      color: AppColors.primary,
      steps: [
        'Take a normal inhale through your nose',
        'At the top, take a SECOND short inhale (to fully inflate)',
        'Now exhale slowly and completely through your mouth',
        'Repeat 1–3 times',
        'Feel your heart rate and nervous system settle',
      ],
      tip: 'Used by Stanford neuroscientists — works in under 30 seconds.',
    ),
  ];
}

// ─── Hero Header ──────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final double topPad;
  final StreakModel? mindStreak;
  final MindfulnessState mindState;

  const _HeroHeader({
    required this.topPad,
    required this.mindStreak,
    required this.mindState,
  });

  @override
  Widget build(BuildContext context) {
    final streak = mindStreak?.currentStreak ?? 0;
    final totalSessions = mindState.totalSessionsToday;
    final totalMin = mindState.totalMinutesToday;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧘', style: TextStyle(fontSize: 44))
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 8),
          const Text(
            'Mindfulness Center',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ).animate().fadeIn(duration: 400.ms),
          Text(
            'Breathe. Be present. Heal.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatPill(
                icon: LucideIcons.flame,
                label: '$streak day streak',
                active: streak > 0,
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: LucideIcons.wind,
                label: totalSessions == 0
                    ? '0 sessions today'
                    : '$totalSessions session${totalSessions > 1 ? 's' : ''} today',
                active: totalSessions > 0,
              ),
              if (totalMin > 0) ...[
                const SizedBox(width: 10),
                _StatPill(
                  icon: LucideIcons.clock,
                  label: '${totalMin}m practiced',
                  active: true,
                ),
              ],
            ],
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    ).animate().slideY(begin: -0.1, end: 0, duration: 400.ms);
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _StatPill(
      {required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Today's Progress ─────────────────────────────────────

class _TodayProgress extends StatelessWidget {
  final MindfulnessState mindState;
  final StreakAchievementState streakState;
  const _TodayProgress(
      {required this.mindState, required this.streakState});

  @override
  Widget build(BuildContext context) {
    final sessions = mindState.todaySessions;
    final mindStreak = streakState.streak(StreakType.mindfulness);
    final streakDays = mindStreak?.currentStreak ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendarCheck,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                "Today's Activity",
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (streakDays > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.flame,
                          size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        '$streakDays day streak',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Text(
              'No sessions yet today. Start your first one! 🌟',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            )
          else ...[
            Text(
              '${sessions.length} session${sessions.length > 1 ? 's' : ''} · ${mindState.totalMinutesToday}m practiced',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ...sessions.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.check,
                          size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.exerciseName,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${s.cyclesCompleted} cycles',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Recommended Card ─────────────────────────────────────

class _RecommendedCard extends StatelessWidget {
  final String exercise;
  final String reason;
  final List<Map<String, dynamic>> exercises;
  final void Function(String id) onTap;

  const _RecommendedCard({
    required this.exercise,
    required this.reason,
    required this.exercises,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final match = exercises.firstWhere(
      (e) => (e['name'] as String) == exercise,
      orElse: () => exercises[0],
    );

    return GestureDetector(
      onTap: () => onTap(match['id'] as String),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.sparkles,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    exercise,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.arrowRight,
                size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ─── Breathing Card ───────────────────────────────────────

class _BreathingCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool isDoneToday;
  final VoidCallback onTap;

  const _BreathingCard({
    required this.exercise,
    required this.isDoneToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(exercise['color'] as int);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDoneToday
              ? AppColors.primaryContainer
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDoneToday
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDoneToday
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDoneToday
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                isDoneToday ? LucideIcons.circleCheck : LucideIcons.wind,
                color: isDoneToday ? AppColors.primary : color,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise['name'] as String,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isDoneToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Done ✓',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercise['description'] as String,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TimingChip(
                          label: '↑ ${exercise['inhale']}s',
                          color: isDoneToday ? AppColors.primary : color),
                      const SizedBox(width: 6),
                      if ((exercise['holdIn'] as int) > 0) ...[
                        _TimingChip(
                            label: '⏸ ${exercise['holdIn']}s',
                            color:
                                isDoneToday ? AppColors.primary : color),
                        const SizedBox(width: 6),
                      ],
                      _TimingChip(
                          label: '↓ ${exercise['exhale']}s',
                          color: isDoneToday ? AppColors.primary : color),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.circlePlay,
              color: isDoneToday ? AppColors.primary : color,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TimingChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Meditation Data + Card ───────────────────────────────

class _MeditationData {
  final String title;
  final String duration;
  final String emoji;
  final Color color;
  final List<String> steps;
  const _MeditationData({
    required this.title,
    required this.duration,
    required this.emoji,
    required this.color,
    required this.steps,
  });
}

class _MeditationCard extends StatelessWidget {
  final _MeditationData data;
  final VoidCallback onTap;
  const _MeditationCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [data.color, data.color.withValues(alpha: 0.65)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data.emoji, style: const TextStyle(fontSize: 32)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.play,
                      size: 12, color: Colors.white),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  data.duration,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
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

// ─── Ambient Sound Grid ───────────────────────────────────

class _AmbientSoundGrid extends ConsumerWidget {
  final MindfulnessState mindState;
  const _AmbientSoundGrid({required this.mindState});

  static const _sounds = [
    ('🌧️', 'Rain'),
    ('🌊', 'Ocean'),
    ('🌳', 'Forest'),
    ('🔥', 'Fire'),
    ('☕', 'Café'),
    ('🎵', 'Lo-Fi'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _sounds.length,
      itemBuilder: (_, i) {
        final (emoji, label) = _sounds[i];
        final isActive =
            mindState.activeSound == label && mindState.soundPlaying;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(mindfulnessProvider.notifier).setActiveSound(label);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryContainer
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 4),
                  // Animated playing indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        3,
                        (j) => _SoundBar(delay: j * 120)
                            .animate(
                                onPlay: (ctrl) => ctrl.repeat(reverse: true))
                            .scaleY(
                              begin: 0.3,
                              end: 1.0,
                              delay: Duration(milliseconds: j * 120),
                              duration: 400.ms,
                              curve: Curves.easeInOut,
                            )),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SoundBar extends StatelessWidget {
  final int delay;
  const _SoundBar({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Grounding Data + Card ────────────────────────────────

class _GroundingData {
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final List<String> steps;
  final String tip;
  const _GroundingData({
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.steps,
    required this.tip,
  });
}

class _GroundingCard extends StatelessWidget {
  final _GroundingData data;
  final VoidCallback onTap;
  const _GroundingCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(data.emoji,
                      style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.description,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 18, color: data.color),
          ],
        ),
      ),
    );
  }
}

// ─── Meditation Player Bottom Sheet ──────────────────────

void _showMeditationPlayer(BuildContext context, _MeditationData data) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MeditationPlayerSheet(data: data),
  );
}

class _MeditationPlayerSheet extends StatefulWidget {
  final _MeditationData data;
  const _MeditationPlayerSheet({required this.data});

  @override
  State<_MeditationPlayerSheet> createState() =>
      _MeditationPlayerSheetState();
}

class _MeditationPlayerSheetState extends State<_MeditationPlayerSheet> {
  int _step = 0;
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final totalSteps = d.steps.length;
    final progress = _started ? (_step + 1) / totalSteps : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [d.color, d.color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(d.emoji,
                      style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          d.duration,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress bar
            if (_started) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step ${_step + 1} of $totalSteps',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(d.color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Steps list
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: d.steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final isCurrent = _started && _step == i;
                  final isDone = _started && i < _step;
                  return GestureDetector(
                    onTap: _started
                        ? () => setState(() => _step = i)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? d.color.withValues(alpha: 0.08)
                            : isDone
                                ? AppColors.surfaceVariant
                                : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? d.color.withValues(alpha: 0.4)
                              : isDone
                                  ? AppColors.border
                                  : AppColors.border,
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.success
                                  : isCurrent
                                      ? d.color
                                      : AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(LucideIcons.check,
                                      size: 14, color: Colors.white)
                                  : Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isCurrent
                                            ? Colors.white
                                            : AppColors.textMuted,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.steps[i],
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: isDone
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                height: 1.5,
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

            // Controls
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: !_started
                  ? GestureDetector(
                      onTap: () =>
                          setState(() {
                            _started = true;
                            _step = 0;
                          }),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [d.color, d.color.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Begin Meditation',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _step = _step - 1),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(LucideIcons.arrowLeft,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              if (_step < d.steps.length - 1) {
                                setState(() => _step++);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    d.color,
                                    d.color.withValues(alpha: 0.8)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  _step < d.steps.length - 1
                                      ? 'Next Step'
                                      : 'Complete  ✓',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grounding Detail Bottom Sheet ───────────────────────

void _showGroundingDetail(BuildContext context, _GroundingData data) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroundingDetailSheet(data: data),
  );
}

class _GroundingDetailSheet extends StatefulWidget {
  final _GroundingData data;
  const _GroundingDetailSheet({required this.data});

  @override
  State<_GroundingDetailSheet> createState() =>
      _GroundingDetailSheetState();
}

class _GroundingDetailSheetState extends State<_GroundingDetailSheet> {
  int? _activeStep;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          d.description,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.lightbulb, size: 14, color: d.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.tip,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: d.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                itemCount: d.steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final isActive = _activeStep == i;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _activeStep = isActive ? null : i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? d.color.withValues(alpha: 0.08)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? d.color.withValues(alpha: 0.4)
                              : AppColors.border,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isActive ? d.color : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isActive ? d.color : AppColors.border),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.steps[i],
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                          Icon(
                            isActive
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Micro-Exercise Row ────────────────────────────────────────────────

const _kMicroExercises = [
  {'duration': '30s', 'title': 'Box Breath', 'desc': 'In 4 - Hold 4 - Out 4 - Hold 4', 'emoji': '📦', 'color': Color(0xFF0EA5E9)},
  {'duration': '60s', 'title': 'Cold Splash', 'desc': 'Calm your nervous system fast', 'emoji': '💧', 'color': Color(0xFF00BEB4)},
  {'duration': '2 min', 'title': '5-4-3-2-1', 'desc': 'Ground with your 5 senses', 'emoji': '✋', 'color': AppColors.tertiary},
  {'duration': '2 min', 'title': 'Power Pose', 'desc': 'Stand wide, breathe deep, reset', 'emoji': '🦸', 'color': Color(0xFFF59E0B)},
];

class _MicroExerciseRow extends StatelessWidget {
  const _MicroExerciseRow();

  void _showDetail(BuildContext context, Map ex) {
    final color = ex['color'] as Color;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Text(ex['emoji'] as String, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex['title'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: Text(ex['duration'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ])),
            ]),
            const SizedBox(height: 14),
            Text(ex['desc'] as String, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Got it', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _kMicroExercises.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final ex = _kMicroExercises[i];
          final color = ex['color'] as Color;
          return GestureDetector(
            onTap: () => _showDetail(context, ex),
            child: Container(
              width: 130, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(ex['emoji'] as String, style: const TextStyle(fontSize: 18)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: Text(ex['duration'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(ex['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(ex['desc'] as String, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.3)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Daily Sequence Card ────────────────────────────────────────────────

class _DailySequenceCard extends StatelessWidget {
  const _DailySequenceCard();

  static List<Map<String, dynamic>> _buildSequence() {
    final h = DateTime.now().hour;
    if (h < 12) {
      return [
        {'emoji': '🌅', 'label': 'Morning breath', 'sub': '4-7-8 3min', 'color': Color(0xFF0EA5E9)},
        {'emoji': '🧠', 'label': 'Set intention', 'sub': 'One word today', 'color': AppColors.tertiary},
        {'emoji': '✍', 'label': 'Gratitude', 'sub': 'Journal 2min', 'color': Color(0xFF00BEB4)},
      ];
    } else if (h < 17) {
      return [
        {'emoji': '📦', 'label': 'Box breathing', 'sub': '4-4-4-4 2min', 'color': Color(0xFF0EA5E9)},
        {'emoji': '🚶', 'label': 'Mindful walk', 'sub': '5 min outside', 'color': Color(0xFF10B981)},
        {'emoji': '📝', 'label': 'One win', 'sub': 'Quick note', 'color': Color(0xFFF59E0B)},
      ];
    } else {
      return [
        {'emoji': '🌬', 'label': 'Unwind breath', 'sub': 'Physiological sigh', 'color': AppColors.primary},
        {'emoji': '🧘', 'label': 'Body scan', 'sub': 'Release tension', 'color': AppColors.tertiary},
        {'emoji': '🌙', 'label': 'Sleep prep', 'sub': 'Progressive relax', 'color': Color(0xFF1D4ED8)},
      ];
    }
  }

  static String _seqTitle() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning sequence';
    if (h < 17) return 'Afternoon reset';
    return 'Evening wind-down';
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSequence();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF011A19), Color(0xFF012D2B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(_seqTitle(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
              child: const Text('~10 min', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            children: steps.asMap().entries.map((e) {
              final s = e.value;
              final isLast = e.key == steps.length - 1;
              final c = s['color'] as Color;
              return Expanded(
                child: Row(children: [
                  Expanded(child: Column(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: c.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: c.withOpacity(0.5))),
                      child: Center(child: Text(s['emoji'] as String, style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(height: 6),
                    Text(s['label'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
                    Text(s['sub'] as String, style: TextStyle(fontSize: 9.5, color: Colors.white.withOpacity(0.5)), textAlign: TextAlign.center),
                  ])),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Icon(LucideIcons.arrowRight, size: 14, color: Colors.white.withOpacity(0.3)),
                    ),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
