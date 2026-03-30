import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mindfulness_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/goal_plan_engine.dart';
import '../../../core/services/trend_analyzer.dart';
import '../../../core/services/wellness_engine.dart';
import '../../../core/theme/design_tokens.dart';

// ─── Helpers ──────────────────────────────────────────────

bool _isToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

// ─── Challenge Definitions ────────────────────────────────

class _ChallengeData {
  final IconData icon;
  final String title;
  final String description;
  final int xp;
  final Color color;
  final String category;
  final int durationMin;

  const _ChallengeData({
    required this.icon,
    required this.title,
    required this.description,
    required this.xp,
    required this.color,
    required this.category,
    required this.durationMin,
  });
}

const _kChallenges = [
  _ChallengeData(
    icon: LucideIcons.wind,
    title: 'Breathe',
    description: '5-minute breathing or mindfulness session',
    xp: 15,
    color: Color(0xFF4ECDC4),
    category: 'Mindfulness',
    durationMin: 5,
  ),
  _ChallengeData(
    icon: LucideIcons.penLine,
    title: 'Journal',
    description: 'Write about one good thing today',
    xp: 20,
    color: AppColors.primary,
    category: 'Reflection',
    durationMin: 10,
  ),
  _ChallengeData(
    icon: LucideIcons.sun,
    title: 'Gratitude',
    description: 'Name 3 things you\'re grateful for',
    xp: 10,
    color: Color(0xFFFFD166),
    category: 'Reflection',
    durationMin: 3,
  ),
  _ChallengeData(
    icon: LucideIcons.activity,
    title: 'Move',
    description: '10-minute mindful walk outside',
    xp: 25,
    color: Color(0xFF06D6A0),
    category: 'Movement',
    durationMin: 10,
  ),
  _ChallengeData(
    icon: LucideIcons.messageCircle,
    title: 'Connect',
    description: 'Check in with Maya about your day',
    xp: 15,
    color: Color(0xFFFF6B9D),
    category: 'Support',
    durationMin: 5,
  ),
  _ChallengeData(
    icon: LucideIcons.moon,
    title: 'Wind Down',
    description: 'Log your sleep hours for tonight',
    xp: 10,
    color: Color(0xFF818CF8),
    category: 'Sleep',
    durationMin: 2,
  ),
];

const _kCategories = ['All', 'Mindfulness', 'Reflection', 'Movement', 'Support', 'Sleep'];

// ─── Main Screen ───────────────────────────────────────────

class WellnessScreen extends ConsumerStatefulWidget {
  const WellnessScreen({super.key});

  @override
  ConsumerState<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends ConsumerState<WellnessScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late ConfettiController _confettiCtrl;

  // Only manual challenges (Move=3, Connect=4) need in-session tracking
  final Set<int> _manualCompleted = {};
  int? _lastCompletedXp;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  /// Derive challenge completion from real provider state
  bool _isCompleted(int idx, MoodState moodState, MindfulnessState mindState) {
    return switch (idx) {
      0 => mindState.totalSessionsToday > 0, // Breathe
      1 => moodState.journalEntries.any((e) => _isToday(e.createdAt)), // Journal
      2 => moodState.journalEntries.any((e) => _isToday(e.createdAt)), // Gratitude
      3 => _manualCompleted.contains(3), // Move (manual)
      4 => _manualCompleted.contains(4), // Connect (manual)
      5 => moodState.todayEntry?.sleepHours != null, // Wind Down
      _ => _manualCompleted.contains(idx),
    };
  }

  List<_ChallengeData> _personalizedChallenges(dynamic user) {
    final order = GoalPlanEngine.getChallengeOrder(user);
    return order.map((i) {
      final base = _kChallenges[i];
      final desc = GoalPlanEngine.getChallengeDescription(i, user);
      return _ChallengeData(
        icon: base.icon,
        title: base.title,
        description: desc,
        xp: base.xp,
        color: base.color,
        category: base.category,
        durationMin: base.durationMin,
      );
    }).toList();
  }

  int _sessionXp(List<_ChallengeData> challenges, MoodState moodState, MindfulnessState mindState) {
    int total = 0;
    for (int i = 0; i < challenges.length; i++) {
      if (_isCompleted(i, moodState, mindState)) total += challenges[i].xp;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final streakState = ref.watch(streakProvider);
    final moodState = ref.watch(moodProvider);
    final mindState = ref.watch(mindfulnessProvider);
    final overall = streakState.overall;

    final personalizedChallenges = _personalizedChallenges(user);
    final filtered = _selectedCategory == 'All'
        ? personalizedChallenges
        : personalizedChallenges.where((c) => c.category == _selectedCategory).toList();

    final sessionXp = _sessionXp(personalizedChallenges, moodState, mindState);
    final totalXp = streakState.totalXp + sessionXp;
    final wellnessScore = moodState.wellnessScore;
    final breakdown = moodState.wellnessBreakdown;

    return Scaffold(
      backgroundColor: context.tokenBackground,
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 268,
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
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.wellnessPlan);
                    },
                    icon: const Icon(LucideIcons.sparkles, size: 14, color: Colors.white),
                    label: const Text(
                      'My Plan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _WellnessHeader(
                  overallStreak: overall,
                  wellnessScore: wellnessScore,
                  totalXp: totalXp,
                  breakdown: breakdown,
                ),
              ),
              bottom: TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
              // ── Challenges Tab ───────────────────────────
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  _ChallengesTab(
                    allChallenges: personalizedChallenges,
                    filteredChallenges: filtered,
                    selectedCategory: _selectedCategory,
                    categories: _kCategories,
                    onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
                    isCompleted: (i) => _isCompleted(i, moodState, mindState),
                    onComplete: (origIdx) {
                      if (!_isCompleted(origIdx, moodState, mindState)) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _manualCompleted.add(origIdx);
                          _lastCompletedXp = personalizedChallenges[origIdx].xp;
                        });
                        _confettiCtrl.play();
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _lastCompletedXp = null);
                        });
                      }
                    },
                  ),
                  ConfettiWidget(
                    confettiController: _confettiCtrl,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 22,
                    maxBlastForce: 22,
                    minBlastForce: 5,
                    emissionFrequency: 0.05,
                    gravity: 0.2,
                    colors: const [
                      AppColors.primary, Color(0xFF0EA5E9),
                      Color(0xFFF59E0B), Color(0xFFFF6B6B), Color(0xFF10B981),
                    ],
                  ),
                  if (_lastCompletedXp != null)
                    Positioned(
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFFF8C42)],
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              '+$_lastCompletedXp XP earned!',
                              style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .scale(duration: 300.ms, curve: Curves.elasticOut, begin: const Offset(0.5, 0.5))
                          .then()
                          .fadeOut(delay: 1400.ms, duration: 400.ms),
                    ),
                ],
              ),

              // ── Journey Tab ──────────────────────────────
              _JourneyTab(
                streakState: streakState,
                moodState: moodState,
                mindState: mindState,
              ),

              // ── Badges Tab ───────────────────────────────
              _BadgesTab(streakState: streakState),
            ],
          ),
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
  final WellnessBreakdown? breakdown;

  const _WellnessHeader({
    required this.overallStreak,
    required this.wellnessScore,
    required this.totalXp,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final streak = overallStreak?.currentStreak ?? 0;
    final longest = overallStreak?.longestStreak ?? 0;
    final band = WellnessTokens.bandFor(wellnessScore);
    final gradient = WellnessTokens.gradientFor(band);
    final delta = breakdown?.scoreDelta ?? 0;
    final deltaStr = delta >= 0 ? '+${delta.toStringAsFixed(1)}' : delta.toStringAsFixed(1);
    final deltaColor = delta >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradient.colors.first, gradient.colors.last, AppColors.primary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
          child: Column(
            children: [
              // Score row
              Row(
                children: [
                  CircularPercentIndicator(
                    radius: 50,
                    lineWidth: 6,
                    percent: (wellnessScore / 100).clamp(0.0, 1.0),
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wellnessScore.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                          ),
                        ),
                        const Text(
                          'score',
                          style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    progressColor: Colors.white,
                    backgroundColor: Colors.white24,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: AppRadius.pillAll,
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Text(
                                WellnessTokens.labelFor(band),
                                style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (breakdown != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: deltaColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$deltaStr pts',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: deltaColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          WellnessTokens.encouragementFor(band),
                          style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              // 4-stat pills
              Row(
                children: [
                  Expanded(child: _HeaderStatPill(icon: LucideIcons.flame, value: '$streak', label: 'Streak', iconColor: const Color(0xFFFF8C42))),
                  const SizedBox(width: 6),
                  Expanded(child: _HeaderStatPill(icon: LucideIcons.zap, value: '$totalXp', label: 'XP', iconColor: const Color(0xFFFFD166))),
                  const SizedBox(width: 6),
                  Expanded(child: _HeaderStatPill(icon: LucideIcons.trophy, value: '$longest', label: 'Best', iconColor: const Color(0xFF86EFAC))),
                  const SizedBox(width: 6),
                  Expanded(child: _HeaderStatPill(icon: LucideIcons.brain, value: '${wellnessScore.toInt()}%', label: 'Wellness', iconColor: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _HeaderStatPill({required this.icon, required this.value, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.white60, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Challenges Tab ───────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  final List<_ChallengeData> allChallenges;
  final List<_ChallengeData> filteredChallenges;
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;
  final bool Function(int) isCompleted;
  final void Function(int origIdx) onComplete;

  const _ChallengesTab({
    required this.allChallenges,
    required this.filteredChallenges,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.isCompleted,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = List.generate(allChallenges.length, (i) => isCompleted(i)).where((v) => v).length;
    final total = allChallenges.length;
    final progress = total > 0 ? completed / total : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 100),
      children: [
        // ── Today's Activity Status ────────────────────────
        _TodayStatusGrid(
          allChallenges: allChallenges,
          isCompleted: isCompleted,
        ).animate().fadeIn(duration: 350.ms),

        const SizedBox(height: Spacing.sm),

        // ── Daily Progress Card ────────────────────────────
        _DailyProgress(completed: completed, total: total, progress: progress)
            .animate().fadeIn(duration: 400.ms, delay: 60.ms),

        const SizedBox(height: Spacing.md),

        // ── Real-time Status Banner ───────────────────────
        if (completed > 0)
          Container(
            margin: const EdgeInsets.only(bottom: Spacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.circleCheck, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    completed == total
                        ? '🎉 All done! You\'re crushing it today.'
                        : '$completed of $total challenges auto-detected from your activity today.',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

        // ── Category Filter ────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final sel = cat == selectedCategory;
              return GestureDetector(
                onTap: () => onCategoryChanged(cat),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : context.tokenSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppColors.primary : context.tokenBorder),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : context.tokenTextSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: Spacing.md),

        // ── Challenge Cards ────────────────────────────────
        ...filteredChallenges.asMap().entries.map((e) {
          final displayIdx = e.key;
          final challenge = e.value;
          // Find original index in allChallenges for completion tracking
          final origIdx = allChallenges.indexWhere((c) => c.title == challenge.title);
          final done = origIdx >= 0 ? isCompleted(origIdx) : false;

          return _ChallengeCard(
            challenge: challenge,
            isCompleted: done,
            isManual: origIdx == 3 || origIdx == 4,
            onTap: () {
              if (origIdx >= 0 && !done) onComplete(origIdx);
            },
          )
              .animate(delay: Duration(milliseconds: 60 * displayIdx))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.06, end: 0);
        }),
      ],
    );
  }
}

// ─── Today Status Grid ────────────────────────────────────

class _TodayStatusGrid extends ConsumerWidget {
  final List<_ChallengeData> allChallenges;
  final bool Function(int) isCompleted;

  const _TodayStatusGrid({required this.allChallenges, required this.isCompleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodState = ref.watch(moodProvider);
    final streakState = ref.watch(streakProvider);
    final hour = DateTime.now().hour;
    final streak = streakState.overall?.currentStreak ?? 0;
    final moodDone = moodState.todayEntry != null;
    final streakAtRisk = streak > 0 && !moodDone && hour >= 20;

    final today = moodState.todayEntry;
    final journalDone = moodState.journalEntries.any((e) => _isToday(e.createdAt));
    final mindDone = isCompleted(0); // Breathe
    final chatDone = isCompleted(4); // Connect
    final sleepDone = isCompleted(5); // Wind Down

    final items = [
      (
        icon: LucideIcons.smile,
        label: 'Mood',
        detail: today != null ? '${today.moodScore}/10' : 'Log now',
        done: moodDone,
        color: const Color(0xFF06D6A0),
        route: AppRoutes.moodTracker,
      ),
      (
        icon: LucideIcons.penLine,
        label: 'Journal',
        detail: journalDone ? 'Written' : 'Write',
        done: journalDone,
        color: AppColors.primary,
        route: AppRoutes.journal,
      ),
      (
        icon: LucideIcons.wind,
        label: 'Breathe',
        detail: mindDone ? 'Done' : 'Start',
        done: mindDone,
        color: const Color(0xFF4ECDC4),
        route: AppRoutes.mindfulness,
      ),
      (
        icon: LucideIcons.messageCircle,
        label: 'Maya',
        detail: chatDone ? 'Chatted' : 'Chat',
        done: chatDone,
        color: const Color(0xFFFF6B9D),
        route: AppRoutes.chat,
      ),
      (
        icon: LucideIcons.moon,
        label: 'Sleep',
        detail: sleepDone ? 'Logged' : 'Log',
        done: sleepDone,
        color: const Color(0xFF818CF8),
        route: AppRoutes.moodTracker,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Streak-at-risk banner
        if (streakAtRisk)
          Container(
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: GestureDetector(
              onTap: () => context.go(AppRoutes.moodTracker),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$streak-day streak at risk!',
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const Text(
                          'Log your mood before midnight to keep it going.',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Log now', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),

        // Today's check-in header
        Row(
          children: [
            const Icon(LucideIcons.calendarCheck, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text(
              "Today's Check-ins",
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const Spacer(),
            Text(
              '${items.where((i) => i.done).length}/${items.length} done',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: items.where((i) => i.done).length == items.length
                    ? const Color(0xFF10B981)
                    : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Status pills row
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go(it.route);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: it.done ? it.color.withOpacity(0.10) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: it.done ? it.color.withOpacity(0.4) : const Color(0xFFE2E8F0),
                      width: it.done ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: it.done ? it.color.withOpacity(0.12) : Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: it.done ? it.color.withOpacity(0.15) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          it.done ? LucideIcons.circleCheck : it.icon,
                          size: 15,
                          color: it.done ? it.color : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        it.label,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: it.done ? it.color : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        it.detail,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 8,
                          color: it.done ? it.color.withOpacity(0.8) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Daily Progress ────────────────────────────────────────

class _DailyProgress extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;

  const _DailyProgress({required this.completed, required this.total, required this.progress});

  int _totalXp() => _kChallenges.fold(0, (sum, c) => sum + c.xp);
  int _remainingXp() {
    final completedXp = _kChallenges.take(completed).fold(0, (sum, c) => sum + c.xp);
    return _totalXp() - completedXp;
  }

  @override
  Widget build(BuildContext context) {
    final allDone = completed == total;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: allDone
            ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
            : LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.08), context.tokenSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: allDone ? const Color(0xFF10B981) : context.tokenBorder,
          width: allDone ? 0 : 1,
        ),
        boxShadow: allDone ? AppShadow.sm : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    allDone ? LucideIcons.trophy : LucideIcons.target,
                    size: 16,
                    color: allDone ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allDone ? '🎉 All Challenges Done!' : 'Daily Progress',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: allDone ? Colors.white : context.tokenTextPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allDone ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$completed/$total',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: allDone ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: allDone ? Colors.white24 : context.tokenBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                allDone ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            allDone
                ? 'You\'ve completed all challenges. Incredible work!'
                : '${_remainingXp()} XP remaining • Keep going!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: allDone ? Colors.white70 : context.tokenTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final _ChallengeData challenge;
  final bool isCompleted;
  final bool isManual;
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.challenge,
    required this.isCompleted,
    required this.isManual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompleted
              ? challenge.color.withValues(alpha: 0.06)
              : context.tokenSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isCompleted
                ? challenge.color.withValues(alpha: 0.35)
                : context.tokenBorder,
            width: isCompleted ? 1.5 : 1,
          ),
          boxShadow: isCompleted ? AppShadow.sm : [],
        ),
        child: Row(
          children: [
            // Icon box
            AnimatedContainer(
              duration: 300.ms,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isCompleted
                      ? [challenge.color.withValues(alpha: 0.35), challenge.color.withValues(alpha: 0.15)]
                      : [challenge.color.withValues(alpha: 0.12), challenge.color.withValues(alpha: 0.06)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: challenge.color.withValues(alpha: 0.3)),
              ),
              child: isCompleted
                  ? Icon(LucideIcons.circleCheck, color: challenge.color, size: 24)
                  : Icon(challenge.icon, color: challenge.color, size: 22),
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
                          challenge.title,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isCompleted
                                ? challenge.color
                                : context.tokenTextPrimary,
                            decoration: isCompleted ? TextDecoration.none : null,
                          ),
                        ),
                      ),
                      // XP badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? challenge.color.withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.zap,
                              size: 9,
                              color: isCompleted ? challenge.color : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '+${challenge.xp}',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isCompleted ? challenge.color : const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    challenge.description,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: context.tokenTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      // Duration badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.tokenBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.tokenBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.clock, size: 9, color: context.tokenTextMuted),
                            const SizedBox(width: 3),
                            Text(
                              '${challenge.durationMin}m',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: context.tokenTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: challenge.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isManual ? '✓ Marked done' : '✓ Auto-detected',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: challenge.color,
                            ),
                          ),
                        )
                      else if (!isManual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '⚡ Auto-tracked',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action button
            if (!isCompleted && isManual)
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: challenge.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: challenge.color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(LucideIcons.check, size: 16, color: challenge.color),
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
  final MoodState moodState;
  final MindfulnessState mindState;

  const _JourneyTab({
    required this.streakState,
    required this.moodState,
    required this.mindState,
  });

  @override
  Widget build(BuildContext context) {
    final overall = streakState.overall;
    final breakdown = moodState.wellnessBreakdown;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 100),
      children: [
        // ── Wellness Score Card ───────────────────────────
        _WellnessScoreCard(moodState: moodState, breakdown: breakdown)
            .animate().fadeIn(duration: 400.ms),

        const SizedBox(height: Spacing.md),

        // ── Score Breakdown ───────────────────────────────
        if (breakdown != null) ...[
          _ComponentBreakdown(breakdown: breakdown)
              .animate().fadeIn(duration: 400.ms, delay: 80.ms),
          const SizedBox(height: Spacing.md),
        ],

        // ── Trend Alerts ──────────────────────────────────
        if (moodState.activeAlerts.isNotEmpty) ...[
          _AlertsSection(moodState: moodState)
              .animate().fadeIn(duration: 400.ms, delay: 120.ms),
          const SizedBox(height: Spacing.md),
        ],

        // ── Weekly Calendar ───────────────────────────────
        _WeeklyCalendar(moodState: moodState, mindState: mindState)
            .animate().fadeIn(duration: 400.ms, delay: 160.ms),

        const SizedBox(height: Spacing.md),

        // ── Streak Card ───────────────────────────────────
        _StreakCard(streakState: streakState, overall: overall)
            .animate().fadeIn(duration: 400.ms, delay: 200.ms),

        const SizedBox(height: Spacing.md),

        // ── All-time Stats ────────────────────────────────
        _AllTimeStats(moodState: moodState, mindState: mindState, streakState: streakState)
            .animate().fadeIn(duration: 400.ms, delay: 240.ms),
      ],
    );
  }
}

// ─── Wellness Score Card ──────────────────────────────────

class _WellnessScoreCard extends StatelessWidget {
  final MoodState moodState;
  final WellnessBreakdown? breakdown;

  const _WellnessScoreCard({required this.moodState, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final score = moodState.wellnessScore;
    final band = WellnessTokens.bandFor(score);
    final bandColor = WellnessTokens.colorFor(band);
    final delta = breakdown?.scoreDelta ?? 0;
    final hasData = moodState.last7Days.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: context.tokenBorder),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.brain, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'WELLNESS SCORE',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.tokenTextMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (!hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Log mood to activate',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toInt().toString(),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: bandColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        WellnessTokens.labelFor(band),
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: bandColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (breakdown != null)
                      Row(
                        children: [
                          Icon(
                            delta >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                            size: 12,
                            color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            breakdown!.trendDescription,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.tokenBackground,
              valueColor: AlwaysStoppedAnimation<Color>(bandColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            WellnessTokens.encouragementFor(band),
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: context.tokenTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Component Breakdown ──────────────────────────────────

class _ComponentBreakdown extends StatelessWidget {
  final WellnessBreakdown breakdown;

  const _ComponentBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final components = [
      (label: 'Mood', value: breakdown.moodComponent, weight: '35%', color: const Color(0xFFFF6B9D), icon: LucideIcons.heart),
      (label: 'Consistency', value: breakdown.consistencyComponent, weight: '20%', color: AppColors.primary, icon: LucideIcons.calendarDays),
      (label: 'Sleep', value: breakdown.sleepComponent, weight: '20%', color: const Color(0xFF818CF8), icon: LucideIcons.moon),
      (label: 'Activity', value: breakdown.activityComponent, weight: '15%', color: const Color(0xFF10B981), icon: LucideIcons.activity),
      (label: 'Engagement', value: breakdown.engagementComponent, weight: '10%', color: const Color(0xFFF59E0B), icon: LucideIcons.zap),
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: context.tokenBorder),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.chartBar, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'SCORE BREAKDOWN',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.tokenTextMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          ...components.asMap().entries.map((e) {
            final c = e.value;
            final pct = (c.value / 100).clamp(0.0, 1.0);
            final score = c.value.toInt();
            return Padding(
              padding: EdgeInsets.only(bottom: e.key < components.length - 1 ? 12 : 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(c.icon, size: 13, color: c.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.tokenTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        c.weight,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          color: context.tokenTextMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$score',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: context.tokenBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(c.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Alerts Section ───────────────────────────────────────

class _AlertsSection extends StatelessWidget {
  final MoodState moodState;
  const _AlertsSection({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final critical = moodState.criticalAlerts;
    final warnings = moodState.warningAlerts;
    final positives = moodState.positiveAlerts;
    final all = [...critical, ...warnings, ...positives];

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: context.tokenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.triangleAlert, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                'WELLNESS INSIGHTS',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.tokenTextMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${all.length} alert${all.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...all.take(4).toList().asMap().entries.map((e) {
            final alert = e.value;
            final isLast = e.key == (all.take(4).length - 1);
            final color = switch (alert.severity) {
              TrendSeverity.critical => const Color(0xFFEF4444),
              TrendSeverity.warning => const Color(0xFFF59E0B),
              TrendSeverity.positive => const Color(0xFF10B981),
              _ => AppColors.primary,
            };
            final icon = switch (alert.severity) {
              TrendSeverity.critical => LucideIcons.triangleAlert,
              TrendSeverity.warning => LucideIcons.triangleAlert,
              TrendSeverity.positive => LucideIcons.circleCheck,
              _ => LucideIcons.circle,
            };

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 13, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.tokenTextPrimary,
                          ),
                        ),
                        Text(
                          alert.message,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
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
          }),
        ],
      ),
    );
  }
}

// ─── Weekly Calendar ──────────────────────────────────────

class _WeeklyCalendar extends StatelessWidget {
  final MoodState moodState;
  final MindfulnessState mindState;

  const _WeeklyCalendar({required this.moodState, required this.mindState});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final heatmap = moodState.heatmapData;

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final mindSessions = mindState.todaySessions;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: context.tokenBorder),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendarDays, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'THIS WEEK',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.tokenTextMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${_loggedCount(weekStart, heatmap)}/7 days',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i));
              final dayKey = DateTime(day.year, day.month, day.day);
              final score = heatmap[dayKey];
              final isToday = _isToday(day);
              final isFuture = day.isAfter(now);
              final hasMind = isToday && mindSessions.isNotEmpty;

              Color dotColor = AppColors.primary;
              if (score != null) {
                dotColor = score >= 8
                    ? const Color(0xFF10B981)
                    : score >= 6
                        ? AppColors.primary
                        : score >= 4
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444);
              }

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      days[i],
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isToday ? AppColors.primary : context.tokenTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: 300.ms,
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: score != null
                            ? dotColor.withValues(alpha: 0.15)
                            : isFuture
                                ? Colors.transparent
                                : context.tokenBackground,
                        border: Border.all(
                          color: isToday
                              ? AppColors.primary
                              : score != null
                                  ? dotColor.withValues(alpha: 0.4)
                                  : context.tokenBorder,
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: score != null
                            ? Text(
                                '$score',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: dotColor,
                                ),
                              )
                            : isFuture
                                ? null
                                : Icon(LucideIcons.minus, size: 10, color: context.tokenBorder),
                      ),
                    ),
                    // Mindfulness dot below
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: 300.ms,
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasMind
                            ? const Color(0xFF4ECDC4)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            children: [
              _LegendDot(color: const Color(0xFF10B981), label: 'Great (8-10)'),
              const SizedBox(width: 10),
              _LegendDot(color: AppColors.primary, label: 'Good (6-7)'),
              const SizedBox(width: 10),
              _LegendDot(color: const Color(0xFFF59E0B), label: 'Low (4-5)'),
              const SizedBox(width: 10),
              _LegendDot(color: const Color(0xFF4ECDC4), label: 'Mindful'),
            ],
          ),
        ],
      ),
    );
  }

  int _loggedCount(DateTime weekStart, Map<DateTime, int> heatmap) {
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day);
      if (heatmap.containsKey(key)) count++;
    }
    return count;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 9,
            color: context.tokenTextMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Streak Card ──────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final StreakAchievementState streakState;
  final StreakModel? overall;

  const _StreakCard({required this.streakState, required this.overall});

  @override
  Widget build(BuildContext context) {
    final current = overall?.currentStreak ?? 0;
    final longest = overall?.longestStreak ?? 0;
    const milestones = [3, 7, 14, 30, 60, 100];
    final next = milestones.firstWhere((m) => current < m, orElse: () => 365);
    final prev = milestones.lastWhere((m) => m <= current, orElse: () => 0);
    final prog = next > prev ? (current - prev) / (next - prev) : 1.0;

    final mindStreak = streakState.streak(StreakType.mindfulness);
    final journalStreak = streakState.streak(StreakType.journalWriting);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.12),
            const Color(0xFFF59E0B).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Main streak
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 6),
                      Text(
                        '$current',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'days',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          color: context.tokenTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Overall wellness streak',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: context.tokenTextSecondary,
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
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.tokenTextPrimary,
                    ),
                  ),
                  Text(
                    'Personal best',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      color: context.tokenTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Milestone progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Next milestone: $next days',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: context.tokenTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$current/$next',
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
                  value: prog.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Sub-streaks row
          Row(
            children: [
              _SubStreak(
                emoji: '🧘',
                label: 'Mindfulness',
                days: mindStreak?.currentStreak ?? 0,
              ),
              const SizedBox(width: 8),
              _SubStreak(
                emoji: '📖',
                label: 'Journaling',
                days: journalStreak?.currentStreak ?? 0,
              ),
              const SizedBox(width: 8),
              _SubStreak(
                emoji: '😊',
                label: 'Mood Logs',
                days: streakState.streak(StreakType.moodLogging)?.currentStreak ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubStreak extends StatelessWidget {
  final String emoji;
  final String label;
  final int days;

  const _SubStreak({required this.emoji, required this.label, required this.days});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.tokenSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.tokenBorder),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              '$days',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF59E0B),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 8,
                color: context.tokenTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── All-time Stats ───────────────────────────────────────

class _AllTimeStats extends StatelessWidget {
  final MoodState moodState;
  final MindfulnessState mindState;
  final StreakAchievementState streakState;

  const _AllTimeStats({
    required this.moodState,
    required this.mindState,
    required this.streakState,
  });

  @override
  Widget build(BuildContext context) {
    final totalMoods = moodState.entries.length;
    final totalJournals = moodState.journalEntries.length;
    final totalXp = streakState.totalXp;
    final totalBadges = streakState.achievements.length;
    final avgMood = moodState.averageMood;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: context.tokenBorder),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trophy, size: 16, color: Color(0xFFFFD166)),
              const SizedBox(width: 6),
              Text(
                'ALL-TIME STATS',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.tokenTextMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(child: _StatTile(icon: LucideIcons.heart, label: 'Moods Logged', value: '$totalMoods', color: const Color(0xFFFF6B9D))),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(icon: LucideIcons.bookmarkCheck, label: 'Journal Entries', value: '$totalJournals', color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatTile(icon: LucideIcons.zap, label: 'Total XP', value: '$totalXp', color: const Color(0xFFFFD166))),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(icon: LucideIcons.star, label: 'Avg Mood', value: avgMood > 0 ? avgMood.toStringAsFixed(1) : '—', color: const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 8),
          _StatTile(
            icon: LucideIcons.trophy,
            label: 'Badges Earned',
            value: '$totalBadges',
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    color: context.tokenTextSecondary,
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

// ─── Badges Tab ───────────────────────────────────────────

class _BadgesTab extends ConsumerWidget {
  final StreakAchievementState streakState;

  const _BadgesTab({required this.streakState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedIds = streakState.achievements.map((a) => a.achievementId).toSet();
    final grouped = <AchievementCategory, List<AchievementDefinition>>{};

    for (final def in AchievementDefinition.all) {
      grouped.putIfAbsent(def.category, () => []).add(def);
    }

    final totalUnlocked = unlockedIds.length;
    final totalBadges = AchievementDefinition.all.length;
    final nextToUnlock = AchievementDefinition.all.where((d) => !unlockedIds.contains(d.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 100),
      children: [
        _UnlockedSummary(
          unlocked: totalUnlocked,
          total: totalBadges,
          totalXp: streakState.totalXp,
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: Spacing.md),

        if (nextToUnlock.isNotEmpty) ...[
          _NextBadgeCard(def: nextToUnlock.first).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),
          const SizedBox(height: Spacing.lg),
        ],

        ...grouped.entries.map((entry) {
          final category = entry.key;
          final defs = entry.value;
          final earnedInCategory = defs.where((d) => unlockedIds.contains(d.id)).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category.displayName,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: context.tokenTextPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$earnedInCategory/${defs.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tokenTextMuted),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: ClipRRect(
                          borderRadius: AppRadius.pillAll,
                          child: LinearProgressIndicator(
                            value: defs.isNotEmpty ? earnedInCategory / defs.length : 0,
                            minHeight: 5,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                    ],
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
                  childAspectRatio: 0.85,
                ),
                itemCount: defs.length,
                itemBuilder: (_, i) {
                  final def = defs[i];
                  final isEarned = unlockedIds.contains(def.id);
                  return _BadgeTile(def: def, isEarned: isEarned).animate().fadeIn(delay: (60 * i).ms);
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

class _NextBadgeCard extends StatelessWidget {
  final AchievementDefinition def;
  const _NextBadgeCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.12), const Color(0xFF0EA5E9).withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppShadow.sm),
            child: Center(child: Text(def.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: const Text(
                    'NEXT TO UNLOCK',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(def.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tokenTextPrimary)),
                Text(def.description, style: TextStyle(fontSize: 11, color: context.tokenTextSecondary)),
              ],
            ),
          ),
          const Icon(LucideIcons.lockOpen, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _UnlockedSummary extends StatelessWidget {
  final int unlocked;
  final int total;
  final int totalXp;

  const _UnlockedSummary({required this.unlocked, required this.total, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? unlocked / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadow.coloredMd(AppColors.primary),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 40, lineWidth: 5, percent: progress,
            center: Text('$unlocked', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            progressColor: const Color(0xFFFFD166),
            backgroundColor: Colors.white24,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Badges Collected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('$unlocked of $total achievements unlocked', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    const Icon(LucideIcons.zap, size: 13, color: Color(0xFFFFD166)),
                    const SizedBox(width: 3),
                    Text('$totalXp XP earned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFD166))),
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
    return Container(
      decoration: BoxDecoration(
        color: isEarned ? AppColors.primary.withValues(alpha: 0.06) : context.tokenBackground,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isEarned ? AppColors.primary.withValues(alpha: 0.25) : context.tokenBorder,
          width: isEarned ? 1.5 : 1,
        ),
        boxShadow: isEarned ? AppShadow.sm : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: 400.ms,
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isEarned ? AppColors.primary.withValues(alpha: 0.1) : context.tokenBackground,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isEarned ? def.emoji : '🔒',
                style: TextStyle(fontSize: 24, color: isEarned ? null : context.tokenTextMuted),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              def.title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isEarned ? context.tokenTextPrimary : context.tokenTextMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isEarned) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.pillAll,
              ),
              child: const Text('✓ Earned', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
