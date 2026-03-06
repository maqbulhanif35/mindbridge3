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
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/mood_ring.dart';
import '../../../shared/widgets/skeleton_loaders.dart';

class MoodAnalyticsScreen extends ConsumerStatefulWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  ConsumerState<MoodAnalyticsScreen> createState() =>
      _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends ConsumerState<MoodAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

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

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodProvider);

    return Scaffold(
      backgroundColor: context.tokenBackground,
      appBar: AppBar(
        title: const Text('Mood Analytics'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: '7 Days'),
            Tab(text: '30 Days'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: moodState.isLoading
          ? const AnalyticsSkeleton()
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _AnalyticsTab(entries: moodState.last7Days, moodState: moodState),
                _AnalyticsTab(entries: moodState.last30Days, moodState: moodState),
                _InsightsTab(moodState: moodState),
              ],
            ),
    );
  }
}

// ─── Analytics Tab ────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  final List<MoodEntry> entries;
  final MoodState moodState;

  const _AnalyticsTab({required this.entries, required this.moodState});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyState();
    }

    final avgMood = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.moodScore).reduce((a, b) => a + b) /
            entries.length;

    return ListView(
      padding: Spacing.pagePadding.copyWith(bottom: 100),
      children: [
        const SizedBox(height: Spacing.md),

        // ─── Summary Stats ────────────────────────────
        _SummaryRow(entries: entries, avgMood: avgMood),
        const SizedBox(height: Spacing.md),

        // ─── Mood Line Chart ──────────────────────────
        _SectionHeader(
          icon: LucideIcons.trendingUp,
          title: 'Mood Over Time',
        ),
        const SizedBox(height: Spacing.sm),
        _MoodLineChart(entries: entries),
        const SizedBox(height: Spacing.md),

        // ─── Day of Week Pattern ──────────────────────
        if (entries.length >= 7) ...[
          _SectionHeader(
            icon: LucideIcons.calendarDays,
            title: 'Weekly Pattern',
          ),
          const SizedBox(height: Spacing.sm),
          _DayOfWeekChart(dayAverages: moodState.dayOfWeekAverages),
          const SizedBox(height: Spacing.md),
        ],

        // ─── Emotion Frequency ───────────────────────
        if (moodState.emotionFrequency.isNotEmpty) ...[
          _SectionHeader(
            icon: LucideIcons.tag,
            title: 'Top Emotions',
          ),
          const SizedBox(height: Spacing.sm),
          _EmotionFrequencyChart(frequency: moodState.emotionFrequency),
          const SizedBox(height: Spacing.md),
        ],

        // ─── Heatmap Calendar ────────────────────────
        _SectionHeader(
          icon: LucideIcons.calendarDays,
          title: 'Mood Calendar',
          subtitle: 'Darker = higher mood',
        ),
        const SizedBox(height: Spacing.sm),
        _MoodHeatmap(heatmapData: moodState.heatmapData),
      ],
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final List<MoodEntry> entries;
  final double avgMood;

  const _SummaryRow({required this.entries, required this.avgMood});

  @override
  Widget build(BuildContext context) {
    final withSleep = entries.where((e) => e.sleepHours != null).toList();
    final avgSleep = withSleep.isEmpty
        ? 0.0
        : withSleep.map((e) => e.sleepHours!).reduce((a, b) => a + b) /
            withSleep.length;

    final uniqueDays = entries.map((e) =>
        '${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}').toSet();

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: avgMood.toStringAsFixed(1),
            label: 'Avg Mood',
            suffix: '/10',
            color: MoodTokens.colorFor(avgMood.round().clamp(1, 10)),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatTile(
            value: uniqueDays.length.toString(),
            label: 'Days Logged',
            suffix: '',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatTile(
            value: avgSleep > 0 ? avgSleep.toStringAsFixed(1) : '–',
            label: 'Avg Sleep',
            suffix: avgSleep > 0 ? 'hr' : '',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String suffix;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.tokenTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mood Line Chart ──────────────────────────────────────

class _MoodLineChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const _MoodLineChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Group by day, take max mood
    final dayMap = <String, double>{};
    for (final e in entries) {
      final key =
          '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
      if (!dayMap.containsKey(key) || e.moodScore > dayMap[key]!) {
        dayMap[key] = e.moodScore.toDouble();
      }
    }

    final sorted = dayMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final spots = sorted.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.tokenBorder),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: context.tokenBorder,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: context.tokenTextMuted),
                ),
                reservedSize: 24,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: sorted.length <= 14,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.parse(sorted[idx].key);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: 9,
                        color: context.tokenTextMuted,
                      ),
                    ),
                  );
                },
                reservedSize: 22,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 1,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 14,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: MoodTokens.colorFor(spot.y.round().clamp(1, 10)),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }
}

// ─── Day of Week Chart ────────────────────────────────────

class _DayOfWeekChart extends StatelessWidget {
  final Map<int, double> dayAverages;

  const _DayOfWeekChart({required this.dayAverages});

  static const _dayLabels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    if (dayAverages.isEmpty) return const SizedBox.shrink();

    final groups = List.generate(7, (i) {
      final dow = i + 1;
      final avg = dayAverages[dow] ?? 0.0;
      final color = avg > 0
          ? MoodTokens.colorFor(avg.round().clamp(1, 10))
          : context.tokenBorder;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: avg,
            color: color,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    return Container(
      height: 160,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.tokenBorder),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: 10,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) => Text(
                  _dayLabels[value.toInt() + 1],
                  style: TextStyle(
                    fontSize: 10,
                    color: context.tokenTextMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }
}

// ─── Emotion Frequency ────────────────────────────────────

class _EmotionFrequencyChart extends StatelessWidget {
  final Map<String, int> frequency;

  const _EmotionFrequencyChart({required this.frequency});

  @override
  Widget build(BuildContext context) {
    final top = frequency.entries.take(6).toList();
    final maxCount = top.isEmpty ? 1 : top.first.value;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.tokenBorder),
      ),
      child: Column(
        children: top.map((entry) {
          final color = AppColors.emotionColors[entry.key.toLowerCase()] ??
              AppColors.primary;
          final ratio = entry.value / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _capitalize(entry.key),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.tokenTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Heatmap Calendar ─────────────────────────────────────

class _MoodHeatmap extends StatelessWidget {
  final Map<DateTime, int> heatmapData;

  const _MoodHeatmap({required this.heatmapData});

  @override
  Widget build(BuildContext context) {
    // Convert mood scores (1-10) to dataset values 1-100
    final dataset = <DateTime, int>{};
    for (final entry in heatmapData.entries) {
      dataset[entry.key] = (entry.value * 10).clamp(1, 100);
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.tokenBorder),
      ),
      child: _CustomMoodHeatmap(dataset: dataset),
    ).animate().fadeIn(duration: 500.ms, delay: 150.ms);
  }
}

class _CustomMoodHeatmap extends StatelessWidget {
  final Map<DateTime, int> dataset;
  const _CustomMoodHeatmap({required this.dataset});

  Color _colorFor(BuildContext context, int? value) {
    if (value == null) return context.tokenSurfaceVariant;
    if (value >= 80) return AppColors.primaryDark;
    if (value >= 60) return AppColors.primary;
    if (value >= 30) return AppColors.secondary.withOpacity(0.5);
    return AppColors.primary.withOpacity(0.2);
  }

  @override
  Widget build(BuildContext context) {
    const weeks = 15;
    const cellSize = 26.0;
    const gap = 3.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Start from Monday of the week `weeks-1` weeks ago
    final startDay = today.subtract(
      Duration(days: today.weekday - 1 + (weeks - 1) * 7),
    );

    const dayLabels = ['M', '', 'W', '', 'F', '', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day-of-week labels
            Column(
              children: List.generate(7, (d) {
                return SizedBox(
                  width: 14,
                  height: cellSize + gap,
                  child: Center(
                    child: Text(
                      dayLabels[d],
                      style: TextStyle(
                        fontSize: 9,
                        color: context.tokenTextMuted,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 4),
            // Week columns
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(weeks, (w) {
                    final weekDate = startDay.add(Duration(days: w * 7));
                    final showMonth = w == 0 || weekDate.day <= 7;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month label row
                        SizedBox(
                          height: 16,
                          width: cellSize + gap,
                          child: showMonth
                              ? Text(
                                  DateFormat('MMM').format(weekDate),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.tokenTextMuted,
                                  ),
                                )
                              : null,
                        ),
                        // Day cells
                        ...List.generate(7, (d) {
                          final date =
                              startDay.add(Duration(days: w * 7 + d));
                          final normalized =
                              DateTime(date.year, date.month, date.day);
                          final value =
                              date.isAfter(today) ? null : dataset[normalized];
                          return Container(
                            width: cellSize,
                            height: cellSize,
                            margin: const EdgeInsets.all(gap / 2),
                            decoration: BoxDecoration(
                              color: _colorFor(context, value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: TextStyle(fontSize: 9, color: context.tokenTextMuted),
            ),
            const SizedBox(width: 4),
            ...[
              context.tokenSurfaceVariant,
              AppColors.primary.withOpacity(0.2),
              AppColors.secondary.withOpacity(0.5),
              AppColors.primary.withOpacity(0.6),
              AppColors.primary,
              AppColors.primaryDark,
            ].map(
              (c) => Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'More',
              style: TextStyle(fontSize: 9, color: context.tokenTextMuted),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Insights Tab ─────────────────────────────────────────

class _InsightsTab extends StatelessWidget {
  final MoodState moodState;

  const _InsightsTab({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final entries = moodState.entries;
    final journalEntries = moodState.journalEntries;

    final insightsService = InsightsService(
      apiKey: const String.fromEnvironment('ANTHROPIC_API_KEY'),
    );

    final staticInsights = insightsService.generateStaticInsights(
      moodEntries: entries,
      journalEntries: journalEntries,
    );

    final alerts = moodState.activeAlerts
        .where((a) => a.severity != TrendSeverity.positive)
        .toList();

    if (staticInsights.isEmpty && alerts.isEmpty) {
      return _EmptyInsightsState();
    }

    return ListView(
      padding: Spacing.pagePadding.copyWith(bottom: 100),
      children: [
        const SizedBox(height: Spacing.md),

        // Wellness breakdown ring
        if (moodState.wellnessBreakdown != null) ...[
          _SectionHeader(icon: LucideIcons.activity, title: 'Wellness Score'),
          const SizedBox(height: Spacing.sm),
          Center(
            child: MoodRing(
              score: moodState.wellnessScore,
              size: 160,
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],

        // Static data insights
        ...staticInsights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _InsightCard(
                icon: _iconForInsightType(insight.type),
                title: insight.title,
                body: insight.body,
              ),
            )),

        // Trend alerts as insights
        if (alerts.isNotEmpty) ...[
          _SectionHeader(icon: LucideIcons.triangleAlert, title: 'Pattern Alerts'),
          const SizedBox(height: Spacing.sm),
          ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _AlertCard(alert: alert),
              )),
        ],
      ],
    );
  }

  IconData _iconForInsightType(InsightType type) => switch (type) {
        InsightType.weeklyReport => LucideIcons.calendarDays,
        InsightType.pattern => LucideIcons.trendingUp,
        InsightType.prediction => LucideIcons.lightbulb,
        InsightType.correlation => LucideIcons.activity,
        InsightType.recommendation => LucideIcons.sparkles,
      };
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.5),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokenTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

class _AlertCard extends StatelessWidget {
  final TrendAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isWarning = alert.severity == TrendSeverity.warning;
    final color = isWarning ? AppColors.warning : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, color: color, size: 18),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokenTextSecondary,
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

// ─── Section Header ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: Spacing.xs),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.tokenTextPrimary,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: Spacing.xs),
          Text(
            '· $subtitle',
            style: TextStyle(fontSize: 12, color: context.tokenTextMuted),
          ),
        ],
      ],
    );
  }
}

// ─── Empty States ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.chartBar, size: 56, color: AppColors.textMuted),
          const SizedBox(height: Spacing.md),
          Text(
            'No mood data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.tokenTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Start logging your mood to see patterns here.',
            style: TextStyle(color: context.tokenTextMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyInsightsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.lightbulb, size: 56, color: AppColors.textMuted),
          const SizedBox(height: Spacing.md),
          Text(
            'Building your insights',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.tokenTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Log mood for 14+ days to unlock personalized insights.',
            style: TextStyle(color: context.tokenTextMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
