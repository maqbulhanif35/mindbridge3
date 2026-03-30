import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mood_model.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/trend_analyzer.dart';
import '../../../core/services/wellness_engine.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/mood_ring.dart';
import '../../../shared/widgets/skeleton_loaders.dart';

// ─── Screen ────────────────────────────────────────────────

class MoodAnalyticsScreen extends ConsumerStatefulWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  ConsumerState<MoodAnalyticsScreen> createState() =>
      _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends ConsumerState<MoodAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _periodIdx = 0; // 0=7d 1=14d 2=30d

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

  List<MoodEntry> _entriesForPeriod(MoodState s) {
    if (_periodIdx == 0) return s.last7Days;
    if (_periodIdx == 1) {
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      return s.entries
          .where((e) => e.createdAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return s.last30Days;
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodProvider);
    if (moodState.isLoading) {
      return const Scaffold(backgroundColor: Color(0xFFF5F7FA), body: _LoadingView());
    }

    final periodEntries = _entriesForPeriod(moodState);
    final score = moodState.wellnessScore;
    final delta = moodState.wellnessBreakdown?.scoreDelta ?? 0;
    final streak = moodState.currentStreakDays;
    final today = moodState.todayEntry;
    final avgMood = periodEntries.isEmpty
        ? 0.0
        : periodEntries.map((e) => e.moodScore).reduce((a, b) => a + b) /
            periodEntries.length;
    final uniqueDays30 = moodState.last30Days
        .map((e) =>
            '${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}')
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 268,
            pinned: true,
            backgroundColor: score >= 80
                ? const Color(0xFF047857)
                : score >= 40
                    ? AppColors.primary
                    : score >= 20
                        ? const Color(0xFFD97706)
                        : score > 0
                            ? const Color(0xFFDC2626)
                            : AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Mood Analytics',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _AnalyticsHeader(
                score: score,
                delta: delta,
                streak: streak,
                today: today,
                avgMood: avgMood,
                uniqueDays30: uniqueDays30,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: AppColors.primary,
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  tabs: const [
                    Tab(text: 'Trends'),
                    Tab(text: 'Patterns'),
                    Tab(text: 'Insights'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _TrendsTab(
              moodState: moodState,
              periodIdx: _periodIdx,
              onPeriodChanged: (i) => setState(() => _periodIdx = i),
              periodEntries: periodEntries,
            ),
            _PatternsTab(moodState: moodState, periodEntries: periodEntries),
            _InsightsTab(moodState: moodState),
          ],
        ),
      ),
    );
  }
}

// ─── Analytics Header ───────────────────────────────────────

class _AnalyticsHeader extends StatelessWidget {
  final double score;
  final double delta;
  final int streak;
  final MoodEntry? today;
  final double avgMood;
  final int uniqueDays30;

  const _AnalyticsHeader({
    required this.score,
    required this.delta,
    required this.streak,
    required this.today,
    required this.avgMood,
    required this.uniqueDays30,
  });

  @override
  Widget build(BuildContext context) {
    final band = WellnessTokens.bandFor(score);

    // Band-aware gradient — mirrors home screen logic
    final gradColors = score >= 80
        ? [const Color(0xFF047857), const Color(0xFF059669), const Color(0xFF10B981)]
        : score >= 60
            ? [const Color(0xFF006B64), AppColors.primary, const Color(0xFF00C4B8)]
            : score >= 40
                ? [const Color(0xFF1D4ED8), const Color(0xFF2563EB), const Color(0xFF3B82F6)]
                : score >= 20
                    ? [const Color(0xFFB45309), const Color(0xFFD97706), const Color(0xFFF59E0B)]
                    : score > 0
                        ? [const Color(0xFFB91C1C), const Color(0xFFDC2626), const Color(0xFFEF4444)]
                        : [const Color(0xFF006B64), AppColors.primary, const Color(0xFF00C4B8)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  MoodRing(score: score, size: 84),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            WellnessTokens.labelFor(band),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              score.toStringAsFixed(0),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const Text(
                              '/100',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: Colors.white60,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: delta >= 0
                                    ? const Color(0xFF86EFAC).withValues(alpha: 0.2)
                                    : const Color(0xFFFCA5A5).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                delta >= 0
                                    ? LucideIcons.trendingUp
                                    : LucideIcons.trendingDown,
                                size: 11,
                                color: delta >= 0
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs last week',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: delta >= 0
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      icon: LucideIcons.flame,
                      value: '$streak',
                      label: 'Streak',
                      iconColor: const Color(0xFFFF8C42),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      icon: LucideIcons.heart,
                      value: avgMood > 0 ? avgMood.toStringAsFixed(1) : '—',
                      label: 'Avg Mood',
                      iconColor: const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      icon: LucideIcons.calendarDays,
                      value: '$uniqueDays30',
                      label: '30D days',
                      iconColor: const Color(0xFF86EFAC),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      icon: today != null
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      value: today != null ? '${today!.moodScore}/10' : '—',
                      label: 'Today',
                      iconColor: today != null
                          ? const Color(0xFF86EFAC)
                          : Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9,
              color: Colors.white60,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period Selector ───────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final int selectedIdx;
  final ValueChanged<int> onChanged;

  const _PeriodSelector({required this.selectedIdx, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['7 Days', '14 Days', '30 Days'];
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadow.xs,
      ),
      child: Row(
        children: List.generate(3, (i) {
          final sel = selectedIdx == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: 220.ms,
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Trends Tab ────────────────────────────────────────────

class _TrendsTab extends StatelessWidget {
  final MoodState moodState;
  final int periodIdx;
  final ValueChanged<int> onPeriodChanged;
  final List<MoodEntry> periodEntries;

  const _TrendsTab({
    required this.moodState,
    required this.periodIdx,
    required this.onPeriodChanged,
    required this.periodEntries,
  });

  @override
  Widget build(BuildContext context) {
    if (periodEntries.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.trendingUp,
        title: 'No mood data yet',
        body: 'Start logging your mood daily to see your trends here.',
      );
    }

    final avgMood = periodEntries
            .map((e) => e.moodScore)
            .reduce((a, b) => a + b) /
        periodEntries.length;
    final uniqueDays = periodEntries
        .map((e) =>
            '${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}')
        .toSet();
    final withSleep =
        periodEntries.where((e) => e.sleepHours != null).toList();
    final avgSleep = withSleep.isEmpty
        ? 0.0
        : withSleep
                .map((e) => e.sleepHours!)
                .reduce((a, b) => a + b) /
            withSleep.length;

    // Momentum: compare first vs second half
    final mid = periodEntries.length ~/ 2;
    final first = periodEntries.take(mid).toList();
    final second = periodEntries.skip(mid).toList();
    final firstAvg = first.isEmpty
        ? avgMood
        : first.map((e) => e.moodScore).reduce((a, b) => a + b) / first.length;
    final secondAvg = second.isEmpty
        ? avgMood
        : second
                .map((e) => e.moodScore)
                .reduce((a, b) => a + b) /
            second.length;
    final momentum = secondAvg - firstAvg;

    // Volatility (std dev)
    final variance = periodEntries
            .map((e) => (e.moodScore - avgMood) * (e.moodScore - avgMood))
            .reduce((a, b) => a + b) /
        periodEntries.length;
    final stdDev = math.sqrt(variance);

    // Best/worst
    final sorted = [...periodEntries]
      ..sort((a, b) => b.moodScore.compareTo(a.moodScore));

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _PeriodSelector(
              selectedIdx: periodIdx, onChanged: onPeriodChanged),
        ),
        const SizedBox(height: 14),

        // 4 stat cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  value: avgMood.toStringAsFixed(1),
                  suffix: '/10',
                  label: 'Avg Mood',
                  icon: LucideIcons.heart,
                  color: MoodTokens.colorFor(avgMood.round().clamp(1, 10)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatCard(
                  value: '${uniqueDays.length}',
                  suffix: '',
                  label: 'Days Logged',
                  icon: LucideIcons.calendarDays,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatCard(
                  value: avgSleep > 0 ? avgSleep.toStringAsFixed(1) : '—',
                  suffix: avgSleep > 0 ? 'h' : '',
                  label: 'Avg Sleep',
                  icon: LucideIcons.moon,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatCard(
                  value: '${periodEntries.length}',
                  suffix: '',
                  label: 'Check-ins',
                  icon: LucideIcons.activity,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Area chart
        _SectionCard(
          icon: LucideIcons.trendingUp,
          title: 'Mood Over Time',
          subtitle: '${periodEntries.length} entries',
          child: _MoodAreaChart(entries: periodEntries),
        ),
        const SizedBox(height: 12),

        // Momentum + Volatility row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _MomentumCard(momentum: momentum)
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.06),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VolatilityCard(stdDev: stdDev)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 60.ms)
                    .slideY(begin: 0.06),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Best / Worst
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _DayHighlightCard(
                    label: 'Best Day', entry: sorted.first, isBest: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DayHighlightCard(
                    label: 'Toughest Day', entry: sorted.last, isBest: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Emotion frequency
        if (moodState.emotionFrequency.isNotEmpty)
          _SectionCard(
            icon: LucideIcons.sparkles,
            title: 'Top Emotions',
            subtitle: '${moodState.emotionFrequency.length} tracked',
            child: _EmotionFrequencyBars(
              frequency: moodState.emotionFrequency,
            ),
          ),
        const SizedBox(height: 12),

        // Heatmap
        _SectionCard(
          icon: LucideIcons.calendarDays,
          title: 'Mood Calendar',
          subtitle: 'past 4 weeks',
          child: _MoodHeatmap(heatmapData: moodState.heatmapData),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Patterns Tab ──────────────────────────────────────────

class _PatternsTab extends StatelessWidget {
  final MoodState moodState;
  final List<MoodEntry> periodEntries;

  const _PatternsTab(
      {required this.moodState, required this.periodEntries});

  @override
  Widget build(BuildContext context) {
    final entries = moodState.entries;
    if (entries.length < 3) {
      return const _EmptyState(
        icon: LucideIcons.chartBar,
        title: 'Not enough data yet',
        body: 'Log mood for at least 7 days to discover your patterns.',
      );
    }

    // Activity → avg mood
    final activityMoods = <String, List<int>>{};
    for (final e in entries) {
      for (final a in e.activities) {
        activityMoods.putIfAbsent(a, () => []).add(e.moodScore);
      }
    }
    final activityAvg = activityMoods.map(
      (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length),
    );
    final sortedActivities = activityAvg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Time of day buckets
    final timeOfDay = <String, List<int>>{
      'Morning': [],
      'Afternoon': [],
      'Evening': [],
    };
    for (final e in entries) {
      final h = e.createdAt.hour;
      if (h >= 5 && h < 12) {
        timeOfDay['Morning']!.add(e.moodScore);
      } else if (h >= 12 && h < 18) {
        timeOfDay['Afternoon']!.add(e.moodScore);
      } else {
        timeOfDay['Evening']!.add(e.moodScore);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const SizedBox(height: 16),

        // Day of week
        if (moodState.dayOfWeekAverages.isNotEmpty)
          _SectionCard(
            icon: LucideIcons.calendarDays,
            title: 'Best Day of the Week',
            subtitle: 'avg mood by weekday',
            child: _DayOfWeekChart(
                dayAverages: moodState.dayOfWeekAverages),
          ),
        const SizedBox(height: 12),

        // Time of day
        _SectionCard(
          icon: LucideIcons.sun,
          title: 'Time of Day',
          subtitle: 'when you feel your best',
          child: _TimeOfDayCard(buckets: timeOfDay),
        ),
        const SizedBox(height: 12),

        // Sleep & Mood
        if (entries.any((e) => e.sleepHours != null))
          _SectionCard(
            icon: LucideIcons.moon,
            title: 'Sleep & Mood',
            subtitle: 'how rest shapes your day',
            child: _SleepMoodMatrix(entries: entries),
          ),
        const SizedBox(height: 12),

        // Activity impact
        if (sortedActivities.isNotEmpty)
          _SectionCard(
            icon: LucideIcons.zap,
            title: 'Activity Impact',
            subtitle: 'avg mood per activity',
            child: _ActivityImpactList(
                activities: sortedActivities.take(8).toList()),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Insights Tab ──────────────────────────────────────────

class _InsightsTab extends StatelessWidget {
  final MoodState moodState;

  const _InsightsTab({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final insightsService =
        InsightsService(apiKey: const String.fromEnvironment('ANTHROPIC_API_KEY'));
    final staticInsights = insightsService.generateStaticInsights(
      moodEntries: moodState.entries,
      journalEntries: moodState.journalEntries,
    );
    final alerts = moodState.activeAlerts
        .where((a) => a.severity != TrendSeverity.positive)
        .toList();
    final positiveAlerts = moodState.positiveAlerts;

    if (staticInsights.isEmpty && alerts.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.lightbulb,
        title: 'Building your insights',
        body: 'Log mood for 14+ days to unlock personalized AI insights.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const SizedBox(height: 16),

        // Wellness breakdown
        if (moodState.wellnessBreakdown != null) ...[
          _SectionCard(
            icon: LucideIcons.activity,
            title: 'Wellness Breakdown',
            subtitle:
                '${moodState.wellnessScore.toStringAsFixed(0)}/100 overall',
            child: _WellnessBreakdownBars(
                breakdown: moodState.wellnessBreakdown!),
          ),
          const SizedBox(height: 12),
        ],

        // Week comparison
        if (moodState.wellnessBreakdown != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WeekComparisonCard(
              breakdown: moodState.wellnessBreakdown!,
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
          ),
          const SizedBox(height: 12),
        ],

        // Positive patterns
        if (positiveAlerts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _SectionHeader(
              icon: LucideIcons.sparkles,
              title: 'Positive Patterns',
              color: Color(0xFF06D6A0),
            ),
          ),
          ...positiveAlerts.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _AlertTile(alert: e.value)
                      .animate(delay: Duration(milliseconds: e.key * 60))
                      .fadeIn()
                      .slideY(begin: 0.06),
                ),
              ),
          const SizedBox(height: 4),
        ],

        // Maya's Observations
        if (staticInsights.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _SectionHeader(
              icon: LucideIcons.brain,
              title: "Maya's Observations",
            ),
          ),
          ...staticInsights.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _InsightCard(insight: e.value)
                      .animate(
                          delay: Duration(milliseconds: e.key * 80))
                      .fadeIn()
                      .slideY(begin: 0.06),
                ),
              ),
        ],

        // Pattern alerts
        if (alerts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: _SectionHeader(
              icon: LucideIcons.triangleAlert,
              title: 'Pattern Alerts',
              color: AppColors.warning,
            ),
          ),
          ...alerts.map(
            (a) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _AlertTile(alert: a),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Area Chart ────────────────────────────────────────────

class _MoodAreaChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const _MoodAreaChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox(height: 120);

    final avgMood =
        entries.map((e) => e.moodScore).reduce((a, b) => a + b) /
            entries.length;
    final chartColor = MoodTokens.colorFor(avgMood.round().clamp(1, 10));

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.moodScore.toDouble());
    }).toList();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 1,
          maxY: 10,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 3,
            getDrawingHorizontalLine: (v) => FlLine(
              color: const Color(0xFFE5E7EB),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 3,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: math.max(1, (entries.length / 5).ceilToDouble()),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final dt = entries[idx].createdAt;
                  return Text(
                    DateFormat('M/d').format(dt),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: chartColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: entries.length <= 14,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3.5,
                  color: chartColor,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    chartColor.withValues(alpha: 0.28),
                    chartColor.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                final entry = entries[s.x.toInt()];
                return LineTooltipItem(
                  '${entry.moodEmoji} ${entry.moodScore}/10\n${DateFormat('MMM d').format(entry.createdAt)}',
                  TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: chartColor,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Momentum Card ─────────────────────────────────────────

class _MomentumCard extends StatelessWidget {
  final double momentum;

  const _MomentumCard({required this.momentum});

  @override
  Widget build(BuildContext context) {
    final isUp = momentum > 0.3;
    final isDown = momentum < -0.3;
    final color = isUp
        ? const Color(0xFF06D6A0)
        : isDown
            ? const Color(0xFFFF6B6B)
            : const Color(0xFFF59E0B);
    final icon = isUp
        ? LucideIcons.trendingUp
        : isDown
            ? LucideIcons.trendingDown
            : LucideIcons.moveHorizontal;
    final label =
        isUp ? 'Rising' : isDown ? 'Declining' : 'Stable';
    final desc = isUp
        ? 'Your mood is improving this period'
        : isDown
            ? 'Your mood has dipped recently'
            : 'Your mood has been consistent';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                'Momentum',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Volatility Card ───────────────────────────────────────

class _VolatilityCard extends StatelessWidget {
  final double stdDev;

  const _VolatilityCard({required this.stdDev});

  @override
  Widget build(BuildContext context) {
    final label = stdDev < 1.0
        ? 'Very Stable'
        : stdDev < 2.0
            ? 'Stable'
            : stdDev < 3.0
                ? 'Variable'
                : 'Volatile';
    final color = stdDev < 1.0
        ? const Color(0xFF06D6A0)
        : stdDev < 2.0
            ? AppColors.primary
            : stdDev < 3.0
                ? const Color(0xFFF59E0B)
                : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.activity, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                'Volatility',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'σ = ${stdDev.toStringAsFixed(2)} pts',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Time of Day Card ──────────────────────────────────────

class _TimeOfDayCard extends StatelessWidget {
  final Map<String, List<int>> buckets;

  const _TimeOfDayCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final data = [
      ('Morning', '🌅', buckets['Morning'] ?? [], const Color(0xFFF59E0B)),
      ('Afternoon', '☀️', buckets['Afternoon'] ?? [], const Color(0xFF0EA5E9)),
      ('Evening', '🌙', buckets['Evening'] ?? [], const Color(0xFF7C3AED)),
    ];

    double bestAvg = 0;
    String bestTime = '';
    for (final d in data) {
      if (d.$3.isNotEmpty) {
        final avg = d.$3.reduce((a, b) => a + b) / d.$3.length;
        if (avg > bestAvg) {
          bestAvg = avg;
          bestTime = d.$1;
        }
      }
    }

    return Column(
      children: [
        Row(
          children: data.map((d) {
            final list = d.$3;
            final avg = list.isEmpty
                ? 0.0
                : list.reduce((a, b) => a + b) / list.length;
            final isBest = d.$1 == bestTime && list.isNotEmpty;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                    right: d.$1 != 'Evening' ? 8 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isBest
                      ? d.$4.withValues(alpha: 0.1)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isBest
                        ? d.$4.withValues(alpha: 0.5)
                        : const Color(0xFFE5E7EB),
                    width: isBest ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(d.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      d.$1,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isBest ? d.$4 : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      list.isEmpty ? '—' : avg.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: list.isEmpty ? AppColors.textMuted : d.$4,
                      ),
                    ),
                    Text(
                      '${list.length} logs',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: d.$4.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Best',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: d.$4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (bestTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.lightbulb,
                    size: 13, color: Color(0xFF06D6A0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You tend to feel your best in the $bestTime (avg ${bestAvg.toStringAsFixed(1)}/10)',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Day of Week Chart ─────────────────────────────────────

class _DayOfWeekChart extends StatelessWidget {
  final Map<int, double> dayAverages;

  const _DayOfWeekChart({required this.dayAverages});

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (dayAverages.isEmpty) return const SizedBox.shrink();

    final best =
        dayAverages.entries.reduce((a, b) => a.value > b.value ? a : b);

    final groups = List.generate(7, (i) {
      final dow = i + 1;
      final val = dayAverages[dow] ?? 0;
      final isBest = dow == best.key && val > 0;
      final color = isBest
          ? AppColors.primary
          : AppColors.primary.withValues(alpha: 0.35);
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: color,
            width: 22,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 10,
              color: const Color(0xFFF0F4F8),
            ),
          ),
        ],
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: 10,
              minY: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) => Text(
                      days[v.toInt()],
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              barGroups: groups,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, __, rod, ___) => BarTooltipItem(
                    '${days[group.x]}\n${rod.toY.toStringAsFixed(1)}/10',
                    const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (dayAverages.containsKey(best.key)) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.star,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][best.key - 1]} is your best day (avg ${best.value.toStringAsFixed(1)}/10)',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Sleep Mood Matrix ─────────────────────────────────────

class _SleepMoodMatrix extends StatelessWidget {
  final List<MoodEntry> entries;

  const _SleepMoodMatrix({required this.entries});

  @override
  Widget build(BuildContext context) {
    final withSleep = entries.where((e) => e.sleepHours != null).toList();
    if (withSleep.isEmpty) {
      return const Text('No sleep data logged yet.',
          style: TextStyle(fontFamily: 'Nunito', color: AppColors.textMuted));
    }

    final buckets = <String, List<int>>{
      '< 5h': [],
      '5–6h': [],
      '7–8h': [],
      '9h+': [],
    };
    for (final e in withSleep) {
      final h = e.sleepHours!;
      if (h < 5) {
        buckets['< 5h']!.add(e.moodScore);
      } else if (h < 7) {
        buckets['5–6h']!.add(e.moodScore);
      } else if (h <= 8) {
        buckets['7–8h']!.add(e.moodScore);
      } else {
        buckets['9h+']!.add(e.moodScore);
      }
    }

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFFF59E0B),
      const Color(0xFF06D6A0),
      const Color(0xFF0EA5E9),
    ];

    return Column(
      children: buckets.entries.toList().asMap().entries.map((entry) {
        final i = entry.key;
        final bucket = entry.value;
        final list = bucket.value;
        final avg = list.isEmpty
            ? 0.0
            : list.reduce((a, b) => a + b) / list.length;
        final color = colors[i];
        final barWidth = avg / 10;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  bucket.key,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: barWidth.clamp(0.0, 1.0),
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            list.isEmpty
                                ? 'No data'
                                : '${avg.toStringAsFixed(1)}/10  (${list.length} logs)',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: list.isEmpty
                                  ? AppColors.textMuted
                                  : Colors.white,
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
        );
      }).toList(),
    );
  }
}

// ─── Activity Impact ───────────────────────────────────────

class _ActivityImpactList extends StatelessWidget {
  final List<MapEntry<String, double>> activities;

  const _ActivityImpactList({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: activities.map((act) {
        final pct = act.value / 10.0;
        final color = MoodTokens.colorFor(act.value.round().clamp(1, 10));
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  act.key,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                act.value.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Emotion Frequency Bars ────────────────────────────────

class _EmotionFrequencyBars extends StatelessWidget {
  final Map<String, int> frequency;

  const _EmotionFrequencyBars({required this.frequency});

  @override
  Widget build(BuildContext context) {
    final top = frequency.entries.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxCount = top.first.value;

    // Assign colors by index cycling through palette
    const colors = [
      AppColors.primary,
      Color(0xFF0EA5E9),
      Color(0xFF7C3AED),
      Color(0xFFFF6B6B),
      Color(0xFFF59E0B),
      Color(0xFF06D6A0),
      Color(0xFFFF6B9D),
      Color(0xFF4ECDC4),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: top.asMap().entries.map((e) {
        final i = e.key;
        final emotion = e.value;
        final color = colors[i % colors.length];
        final pct = emotion.value / maxCount;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1 + pct * 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: color.withValues(alpha: 0.35 + pct * 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emotion.key,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '×${emotion.value}',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Mood Heatmap ──────────────────────────────────────────

class _MoodHeatmap extends StatelessWidget {
  final Map<DateTime, int> heatmapData;

  const _MoodHeatmap({required this.heatmapData});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(28, (i) {
      final d = today.subtract(Duration(days: 27 - i));
      return DateTime(d.year, d.month, d.day);
    });

    const cols = 7;
    final rows = (days.length / cols).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day headers
        Row(
          children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(cols, (col) {
                final idx = row * cols + col;
                if (idx >= days.length) {
                  return const Expanded(child: SizedBox(height: 28));
                }
                final day = days[idx];
                final score = heatmapData[day];
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

                Color cellColor;
                if (score == null) {
                  cellColor = const Color(0xFFF0F4F8);
                } else {
                  cellColor = MoodTokens.colorFor(score)
                      .withValues(alpha: 0.2 + score / 10 * 0.65);
                }

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 28,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(
                              color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: score != null
                        ? Center(
                            child: Text(
                              '$score',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: score >= 6
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          );
        }),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${heatmapData.length} days logged',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            ...List.generate(5, (i) {
              final score = (i + 1) * 2;
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: MoodTokens.colorFor(score)
                      .withValues(alpha: 0.2 + score / 10 * 0.65),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
            const SizedBox(width: 4),
            const Text(
              'low → high',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Wellness Breakdown Bars ───────────────────────────────

class _WellnessBreakdownBars extends StatelessWidget {
  final WellnessBreakdown breakdown;

  const _WellnessBreakdownBars({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final components = [
      (
        'Mood Quality',
        breakdown.moodComponent,
        35.0,
        LucideIcons.heart,
        const Color(0xFFFF6B6B)
      ),
      (
        'Consistency',
        breakdown.consistencyComponent,
        20.0,
        LucideIcons.calendarDays,
        AppColors.primary
      ),
      (
        'Sleep',
        breakdown.sleepComponent,
        20.0,
        LucideIcons.moon,
        const Color(0xFF7C3AED)
      ),
      (
        'Activity',
        breakdown.activityComponent,
        15.0,
        LucideIcons.activity,
        const Color(0xFF06D6A0)
      ),
      (
        'Engagement',
        breakdown.engagementComponent,
        10.0,
        LucideIcons.messageCircle,
        const Color(0xFF0EA5E9)
      ),
    ];

    return Column(
      children: components.map((c) {
        final pct = c.$3 > 0 ? (c.$2 / c.$3).clamp(0.0, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.$5.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(c.$4, size: 14, color: c.$5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.$1,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${c.$2.toStringAsFixed(1)} / ${c.$3.toStringAsFixed(0)} pts',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.$5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF0F4F8),
                  valueColor: AlwaysStoppedAnimation(c.$5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Week Comparison Card ──────────────────────────────────

class _WeekComparisonCard extends StatelessWidget {
  final WellnessBreakdown breakdown;

  const _WeekComparisonCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final delta = breakdown.scoreDelta;
    final isUp = delta > 0;
    final color = isUp ? const Color(0xFF06D6A0) : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Previous Week',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  breakdown.previousScore.toStringAsFixed(0),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  isUp ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                  color: color,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  breakdown.trendDescription.contains('Stable')
                      ? 'Stable'
                      : isUp
                          ? 'Improved'
                          : 'Declined',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  breakdown.totalScore.toStringAsFixed(0),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
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

// ─── Shared Section Card ───────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· $subtitle',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: c),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: c == AppColors.primary ? AppColors.textPrimary : c,
          ),
        ),
      ],
    );
  }
}

// ─── Mini Stat Card ────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String value;
  final String suffix;
  final String label;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.value,
    required this.suffix,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
  }
}

// ─── Day Highlight Card ────────────────────────────────────

class _DayHighlightCard extends StatelessWidget {
  final String label;
  final MoodEntry entry;
  final bool isBest;

  const _DayHighlightCard({
    required this.label,
    required this.entry,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBest ? const Color(0xFF06D6A0) : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBest ? LucideIcons.star : LucideIcons.arrowDown,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.moodEmoji,
            style: const TextStyle(fontSize: 24),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${entry.moodScore}',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                '/10',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          Text(
            DateFormat('EEE, MMM d').format(entry.createdAt),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          if (entry.emotions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.emotions.take(2).join(', '),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }
}

// ─── Insight Card ──────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final WellnessInsight insight;

  const _InsightCard({required this.insight});

  static const _typeConfig = <InsightType, (IconData, Color)>{
    InsightType.weeklyReport: (LucideIcons.chartBar, Color(0xFF0EA5E9)),
    InsightType.pattern: (LucideIcons.brain, AppColors.primary),
    InsightType.prediction: (LucideIcons.sparkles, Color(0xFF7C3AED)),
    InsightType.correlation: (LucideIcons.zap, Color(0xFFF59E0B)),
    InsightType.recommendation: (LucideIcons.lightbulb, Color(0xFF06D6A0)),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[insight.type] ??
        (LucideIcons.brain, AppColors.primary);
    final color = cfg.$2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadow.sm,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cfg.$1, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.body,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

// ─── Alert Tile ────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final TrendAlert alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (alert.severity) {
      case TrendSeverity.critical:
        color = const Color(0xFFFF6B6B);
        icon = LucideIcons.triangleAlert;
      case TrendSeverity.warning:
        color = const Color(0xFFF59E0B);
        icon = LucideIcons.circleAlert;
      case TrendSeverity.positive:
        color = const Color(0xFF06D6A0);
        icon = LucideIcons.sparkles;
      default:
        color = AppColors.primary;
        icon = LucideIcons.lightbulb;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadow.sm,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (alert.title.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading / Empty ───────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SkeletonBox(width: double.infinity, height: 260),
        const SizedBox(height: 16),
        ...List.generate(
            3, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 100,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                )),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
