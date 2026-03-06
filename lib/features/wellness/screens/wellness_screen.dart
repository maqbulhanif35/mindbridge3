import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/theme/design_tokens.dart';

class WellnessScreen extends ConsumerStatefulWidget {
  const WellnessScreen({super.key});

  @override
  ConsumerState<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends ConsumerState<WellnessScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  final Set<int> _completedChallenges = {};

  static const _challenges = [
    _ChallengeData(
      icon: LucideIcons.wind,
      title: 'Breathe',
      description: '5-minute breathing exercise',
      xp: 15,
      color: Color(0xFF4ECDC4),
      category: 'Mindfulness',
    ),
    _ChallengeData(
      icon: LucideIcons.penLine,
      title: 'Journal',
      description: 'Write about one good thing today',
      xp: 20,
      color: AppColors.primary,
      category: 'Reflection',
    ),
    _ChallengeData(
      icon: LucideIcons.sun,
      title: 'Gratitude',
      description: 'Name 3 things you\'re grateful for',
      xp: 10,
      color: Color(0xFFFFD166),
      category: 'Gratitude',
    ),
    _ChallengeData(
      icon: LucideIcons.activity,
      title: 'Move',
      description: '10-minute mindful walk',
      xp: 25,
      color: Color(0xFF06D6A0),
      category: 'Movement',
    ),
    _ChallengeData(
      icon: LucideIcons.messageCircle,
      title: 'Connect',
      description: 'Check in with Maya about your day',
      xp: 15,
      color: Color(0xFFFF6B9D),
      category: 'Support',
    ),
    _ChallengeData(
      icon: LucideIcons.moon,
      title: 'Wind Down',
      description: 'Log your sleep intention tonight',
      xp: 10,
      color: AppColors.primaryLight,
      category: 'Sleep',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  int get _totalXpEarned => _completedChallenges
      .map((i) => _challenges[i].xp)
      .fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final streakState = ref.watch(streakProvider);
    final moodState = ref.watch(moodProvider);
    final overall = streakState.overall;
    final wellnessScore = moodState.wellnessScore;

    return Scaffold(
      backgroundColor: context.tokenBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: AppColors.primary,
            surfaceTintColor: Colors.transparent,
            title: AnimatedOpacity(
              opacity: innerBoxIsScrolled ? 1 : 0,
              duration: 200.ms,
              child: const Text(
                'Wellness',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _WellnessHeader(
                overallStreak: overall,
                wellnessScore: wellnessScore,
                totalXp: streakState.totalXp + _totalXpEarned,
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Challenges'),
                Tab(text: 'Journey'),
                Tab(text: 'Badges'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _ChallengesTab(
              challenges: _challenges,
              completedChallenges: _completedChallenges,
              onComplete: (i) {
                if (!_completedChallenges.contains(i)) {
                  HapticFeedback.mediumImpact();
                  setState(() => _completedChallenges.add(i));
                }
              },
            ),
            _JourneyTab(
              streakState: streakState,
              wellnessScore: wellnessScore,
            ),
            _BadgesTab(streakState: streakState),
          ],
        ),
      ),
    );
  }
}

// ─── Wellness Header ──────────────────────────────────────

class _WellnessHeader extends StatelessWidget {
  final StreakModel? overallStreak;
  final double wellnessScore;
  final int totalXp;

  const _WellnessHeader({
    required this.overallStreak,
    required this.wellnessScore,
    required this.totalXp,
  });

  @override
  Widget build(BuildContext context) {
    final streak = overallStreak?.currentStreak ?? 0;
    final band = WellnessTokens.bandFor(wellnessScore);
    final gradient = WellnessTokens.gradientFor(band);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradient.colors.first,
            gradient.colors.last,
            AppColors.primary,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
          child: Row(
            children: [
              // Wellness ring
              CircularPercentIndicator(
                radius: 48,
                lineWidth: 6,
                percent: (wellnessScore / 100).clamp(0.0, 1.0),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wellnessScore.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'score',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                progressColor: Colors.white,
                backgroundColor: Colors.white24,
                circularStrokeCap: CircularStrokeCap.round,
              ),

              const SizedBox(width: Spacing.lg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        WellnessTokens.labelFor(band),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      WellnessTokens.encouragementFor(band),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        _HeaderStat(
                          icon: LucideIcons.flame,
                          value: '$streak',
                          label: 'streak',
                          iconColor: const Color(0xFFFF8C42),
                        ),
                        const SizedBox(width: Spacing.md),
                        _HeaderStat(
                          icon: LucideIcons.zap,
                          value: '$totalXp',
                          label: 'XP',
                          iconColor: const Color(0xFFFFD166),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─── Challenges Tab ───────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  final List<_ChallengeData> challenges;
  final Set<int> completedChallenges;
  final void Function(int) onComplete;

  const _ChallengesTab({
    required this.challenges,
    required this.completedChallenges,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = completedChallenges.length;
    final total = challenges.length;
    final progress = completed / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.lg, Spacing.lg, 100),
      children: [
        // Daily progress
        _DailyProgress(
          completed: completed,
          total: total,
          progress: progress,
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: Spacing.lg),

        // Challenge cards
        ...challenges.asMap().entries.map((e) {
          final i = e.key;
          final ch = e.value;
          final isCompleted = completedChallenges.contains(i);
          return _ChallengeCard(
            data: ch,
            isCompleted: isCompleted,
            onTap: () => onComplete(i),
          )
              .animate()
              .fadeIn(delay: (80 * i).ms, duration: 350.ms)
              .slideX(begin: 0.08, end: 0);
        }),
      ],
    );
  }
}

class _DailyProgress extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;

  const _DailyProgress({
    required this.completed,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Progress",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.tokenTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  '$completed / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.tokenBackground,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          if (completed == total && total > 0) ...[
            const SizedBox(height: Spacing.xs),
            Row(
              children: [
                const Icon(LucideIcons.circleCheck,
                    size: 14, color: Color(0xFF06D6A0)),
                const SizedBox(width: 4),
                Text(
                  'All challenges complete! Great job today!',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokenTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final _ChallengeData data;
  final bool isCompleted;
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.data,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: isCompleted
              ? data.color.withOpacity(0.08)
              : context.tokenSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isCompleted
                ? data.color.withOpacity(0.4)
                : context.tokenBorder,
            width: isCompleted ? 1.5 : 1,
          ),
          boxShadow: isCompleted ? [] : AppShadow.sm,
        ),
        child: Row(
          children: [
            // Icon container
            AnimatedContainer(
              duration: 300.ms,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted
                    ? data.color.withOpacity(0.15)
                    : data.color.withOpacity(0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                isCompleted ? LucideIcons.circleCheck : data.icon,
                color: data.color,
                size: 22,
              ),
            ),

            const SizedBox(width: Spacing.md),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: data.color.withOpacity(0.1),
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          data.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: data.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? context.tokenTextSecondary
                          : context.tokenTextPrimary,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    data.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokenTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            // XP pill
            AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF06D6A0).withOpacity(0.15)
                    : const Color(0xFFFFD166).withOpacity(0.15),
                borderRadius: AppRadius.pillAll,
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF06D6A0).withOpacity(0.4)
                      : const Color(0xFFFFD166).withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? LucideIcons.check : LucideIcons.zap,
                    size: 12,
                    color: isCompleted
                        ? const Color(0xFF06D6A0)
                        : const Color(0xFFFFD166),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isCompleted ? 'Done' : '+${data.xp}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? const Color(0xFF06D6A0)
                          : const Color(0xFFFFD166),
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

// ─── Journey Tab ──────────────────────────────────────────

class _JourneyTab extends StatelessWidget {
  final StreakAchievementState streakState;
  final double wellnessScore;

  const _JourneyTab({
    required this.streakState,
    required this.wellnessScore,
  });

  @override
  Widget build(BuildContext context) {
    final band = WellnessTokens.bandFor(wellnessScore);
    final color = WellnessTokens.colorFor(band);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.lg, Spacing.lg, 100),
      children: [
        // Wellness score card
        _WellnessScoreCard(
          score: wellnessScore,
          color: color,
          band: band,
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: Spacing.md),

        // Streak cards
        Text(
          'Active Streaks',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.tokenTextPrimary,
          ),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: Spacing.sm),

        ...StreakType.values
            .where((t) => t != StreakType.overall)
            .map((type) {
          final streak = streakState.streak(type);
          return _StreakRow(
            type: type,
            streak: streak,
          )
              .animate()
              .fadeIn(delay: (150 * StreakType.values.indexOf(type)).ms)
              .slideX(begin: 0.05, end: 0);
        }),

        const SizedBox(height: Spacing.md),

        // All-time stats
        _AllTimeStats(streakState: streakState)
            .animate()
            .fadeIn(delay: 400.ms),
      ],
    );
  }
}

class _WellnessScoreCard extends StatelessWidget {
  final double score;
  final Color color;
  final WellnessBand band;

  const _WellnessScoreCard({
    required this.score,
    required this.color,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadow.sm,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 52,
            lineWidth: 7,
            percent: (score / 100).clamp(0.0, 1.0),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toInt().toString(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 10,
                    color: context.tokenTextMuted,
                  ),
                ),
              ],
            ),
            progressColor: color,
            backgroundColor: color.withOpacity(0.1),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    WellnessTokens.labelFor(band),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Wellness Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.tokenTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  WellnessTokens.encouragementFor(band),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokenTextSecondary,
                    height: 1.3,
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

class _StreakRow extends StatelessWidget {
  final StreakType type;
  final StreakModel? streak;

  const _StreakRow({required this.type, required this.streak});

  static const _typeData = {
    StreakType.moodLogging: (
      icon: LucideIcons.smile,
      label: 'Mood Logging',
      color: AppColors.primary,
    ),
    StreakType.journalWriting: (
      icon: LucideIcons.bookOpen,
      label: 'Journaling',
      color: Color(0xFF4ECDC4),
    ),
    StreakType.mindfulness: (
      icon: LucideIcons.wind,
      label: 'Mindfulness',
      color: Color(0xFF06D6A0),
    ),
    StreakType.chatSession: (
      icon: LucideIcons.messageCircle,
      label: 'Chat Sessions',
      color: Color(0xFFFF6B9D),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final data = _typeData[type];
    if (data == null) return const SizedBox.shrink();

    final current = streak?.currentStreak ?? 0;
    final isOnFire = streak?.isOnFire ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.tokenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(data.icon, size: 20, color: data.color),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.tokenTextPrimary,
                  ),
                ),
                Text(
                  current > 0
                      ? '$current day${current != 1 ? 's' : ''} in a row'
                      : 'Start your streak today',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokenTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOnFire) ...[
                const Icon(LucideIcons.flame,
                    size: 16, color: Color(0xFFFF8C42)),
                const SizedBox(width: 3),
              ],
              Text(
                '$current',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: current > 0 ? data.color : context.tokenTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllTimeStats extends StatelessWidget {
  final StreakAchievementState streakState;

  const _AllTimeStats({required this.streakState});

  @override
  Widget build(BuildContext context) {
    final overall = streakState.overall;
    final longestStreak = overall?.longestStreak ?? 0;
    final totalDays = overall?.totalDays ?? 0;
    final achievements = streakState.achievements.length;
    final totalXp = streakState.totalXp;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All-Time Stats',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.tokenTextPrimary,
            ),
          ),
          const SizedBox(height: Spacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: Spacing.sm,
            crossAxisSpacing: Spacing.sm,
            childAspectRatio: 2.4,
            children: [
              _StatTile(
                icon: LucideIcons.flame,
                value: '$longestStreak',
                label: 'Best streak',
                color: const Color(0xFFFF8C42),
              ),
              _StatTile(
                icon: LucideIcons.calendarCheck,
                value: '$totalDays',
                label: 'Total check-ins',
                color: AppColors.primary,
              ),
              _StatTile(
                icon: LucideIcons.award,
                value: '$achievements',
                label: 'Badges earned',
                color: const Color(0xFFFFD166),
              ),
              _StatTile(
                icon: LucideIcons.zap,
                value: '$totalXp',
                label: 'Total XP',
                color: const Color(0xFF06D6A0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Spacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: context.tokenTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Badges Tab ───────────────────────────────────────────

class _BadgesTab extends ConsumerWidget {
  final StreakAchievementState streakState;

  const _BadgesTab({required this.streakState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedIds =
        streakState.achievements.map((a) => a.achievementId).toSet();
    final grouped = <AchievementCategory, List<AchievementDefinition>>{};

    for (final def in AchievementDefinition.all) {
      grouped.putIfAbsent(def.category, () => []).add(def);
    }

    final totalUnlocked = unlockedIds.length;
    final totalBadges = AchievementDefinition.all.length;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 100),
      children: [
        // Summary
        _UnlockedSummary(
          unlocked: totalUnlocked,
          total: totalBadges,
          totalXp: streakState.totalXp,
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: Spacing.lg),

        // Category sections
        ...grouped.entries.map((entry) {
          final category = entry.key;
          final defs = entry.value;
          final earnedInCategory =
              defs.where((d) => unlockedIds.contains(d.id)).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.tokenTextPrimary,
                    ),
                  ),
                  Text(
                    '$earnedInCategory/${defs.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokenTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: Spacing.sm,
                  crossAxisSpacing: Spacing.sm,
                  childAspectRatio: 0.88,
                ),
                itemCount: defs.length,
                itemBuilder: (_, i) {
                  final def = defs[i];
                  final isEarned = unlockedIds.contains(def.id);
                  return _BadgeTile(def: def, isEarned: isEarned)
                      .animate()
                      .fadeIn(delay: (60 * i).ms);
                },
              ),
              const SizedBox(height: Spacing.lg),
            ],
          );
        }),
      ],
    );
  }
}

class _UnlockedSummary extends StatelessWidget {
  final int unlocked;
  final int total;
  final int totalXp;

  const _UnlockedSummary({
    required this.unlocked,
    required this.total,
    required this.totalXp,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? unlocked / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadow.coloredMd(AppColors.primary),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 40,
            lineWidth: 5,
            percent: progress,
            center: Text(
              '$unlocked',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            progressColor: const Color(0xFFFFD166),
            backgroundColor: Colors.white24,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Badges Collected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$unlocked of $total achievements unlocked',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    const Icon(LucideIcons.zap,
                        size: 13, color: Color(0xFFFFD166)),
                    const SizedBox(width: 3),
                    Text(
                      '$totalXp XP earned',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD166),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AchievementDefinition def;
  final bool isEarned;

  const _BadgeTile({required this.def, required this.isEarned});

  @override
  Widget build(BuildContext context) {
    final color = def.category.color;
    final rarityColor = def.rarity.color;

    return GestureDetector(
      onTap: () => _showBadgeSheet(context),
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: isEarned ? color.withOpacity(0.08) : context.tokenSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isEarned ? color.withOpacity(0.3) : context.tokenBorder,
          ),
          boxShadow: isEarned ? AppShadow.sm : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rarity dot
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isEarned ? rarityColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Text(
              isEarned ? def.emoji : '🔒',
              style: TextStyle(
                fontSize: isEarned ? 30 : 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              def.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isEarned ? color : context.tokenTextMuted,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '+${def.xp} XP',
              style: TextStyle(
                fontSize: 9,
                color: isEarned
                    ? rarityColor
                    : context.tokenTextMuted.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeSheet(BuildContext context) {
    final color = def.category.color;
    final rarityColor = def.rarity.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Spacing.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: AppRadius.pillAll,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              isEarned ? def.emoji : '🔒',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: rarityColor.withOpacity(0.4)),
              ),
              child: Text(
                '${def.rarity.displayName} · ${def.category.displayName}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rarityColor,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              def.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              def.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166).withOpacity(0.1),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                    color: const Color(0xFFFFD166).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.zap,
                      size: 16, color: Color(0xFFFFD166)),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    '+${def.xp} XP',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFD166),
                    ),
                  ),
                ],
              ),
            ),
            if (!isEarned) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                'Complete the challenge to unlock this badge',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4),
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────

class _ChallengeData {
  final IconData icon;
  final String title;
  final String description;
  final int xp;
  final Color color;
  final String category;

  const _ChallengeData({
    required this.icon,
    required this.title,
    required this.description,
    required this.xp,
    required this.color,
    required this.category,
  });
}
