import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

// ─── Main Screen ──────────────────────────────────────────

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, int> _featureUsage = {};
  Map<String, int> _universityBreakdown = {};
  Map<String, int> _moodDist = {};
  Map<String, int> _hourlyActivity = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    final notifier = ref.read(adminProvider.notifier);
    final results = await Future.wait([
      notifier.loadFeatureUsage(),
      notifier.loadUniversityBreakdown(),
      notifier.loadMoodDistribution(),
      notifier.loadHourlyActivity(),
    ]);
    if (mounted) {
      setState(() {
        _featureUsage = results[0];
        _universityBreakdown = results[1];
        _moodDist = results[2];
        _hourlyActivity = results[3];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────
        Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform Analytics',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          'Last 30 days',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _loadAnalytics,
                      icon: const Icon(LucideIcons.refreshCw,
                          size: 16, color: AppColors.textMuted),
                      tooltip: 'Refresh analytics',
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                isScrollable: true,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Engagement'),
                  Tab(text: 'Universities'),
                  Tab(text: 'Mental Health'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab Content ─────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(
                      stats: state.stats,
                      userGrowth: state.userGrowth,
                      moodTrend: state.moodTrend,
                      hourlyActivity: _hourlyActivity,
                      universityBreakdown: _universityBreakdown,
                    ),
                    _EngagementTab(
                      featureUsage: _featureUsage,
                      hourlyActivity: _hourlyActivity,
                      stats: state.stats,
                    ),
                    _UniversitiesTab(
                      universityBreakdown: _universityBreakdown,
                    ),
                    _MentalHealthTab(
                      moodDist: _moodDist,
                      moodTrend: state.moodTrend,
                      stats: state.stats,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ─── Tab 1: Overview ─────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final AdminStats stats;
  final List<UserGrowthPoint> userGrowth;
  final List<MoodTrendPoint> moodTrend;
  final Map<String, int> hourlyActivity;
  final Map<String, int> universityBreakdown;

  const _OverviewTab({
    required this.stats,
    required this.userGrowth,
    required this.moodTrend,
    required this.hourlyActivity,
    required this.universityBreakdown,
  });

  String get _peakHour {
    if (hourlyActivity.isEmpty) return 'N/A';
    final peak = hourlyActivity.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    final h = int.tryParse(peak.key) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${display}:00 $period';
  }

  String get _topUniversity {
    if (universityBreakdown.isEmpty) return 'N/A';
    return universityBreakdown.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary Cards ────────────────────────────
            LayoutBuilder(
              builder: (ctx, constraints) {
                final wide = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: wide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: wide ? 1.4 : 1.3,
                  children: [
                    _SummaryCard(
                      label: 'Total Sessions',
                      value: '${stats.chatSessions}',
                      icon: LucideIcons.messageSquare,
                      color: AppColors.primary,
                    ),
                    _SummaryCard(
                      label: 'Avg Session',
                      value: '12 min',
                      icon: LucideIcons.clock,
                      color: AppColors.info,
                    ),
                    _SummaryCard(
                      label: 'Peak Hour',
                      value: _peakHour,
                      icon: LucideIcons.trendingUp,
                      color: AppColors.tertiary,
                    ),
                    _SummaryCard(
                      label: 'Top University',
                      value: _topUniversity.length > 14
                          ? '${_topUniversity.substring(0, 12)}…'
                          : _topUniversity,
                      icon: LucideIcons.building2,
                      color: AppColors.success,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // ── User Growth Line Chart ────────────────────
            _AnalyticsCard(
              title: 'User Growth',
              subtitle: '30-day registrations',
              icon: LucideIcons.userPlus,
              child: userGrowth.isEmpty
                  ? const _NoData()
                  : LayoutBuilder(
                      builder: (ctx, c) => SizedBox(
                        height: c.maxWidth > 600 ? 250 : 200,
                        child: _UserGrowthChart(points: userGrowth),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // ── Mood Trend Line Chart ─────────────────────
            _AnalyticsCard(
              title: 'Mood Trend',
              subtitle: 'Platform avg mood score (30 days)',
              icon: LucideIcons.activity,
              child: moodTrend.isEmpty
                  ? const _NoData()
                  : LayoutBuilder(
                      builder: (ctx, c) => SizedBox(
                        height: c.maxWidth > 600 ? 250 : 200,
                        child: _MoodTrendChart(points: moodTrend),
                      ),
                    ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
}

// ─── User Growth Line Chart ───────────────────────────────

class _UserGrowthChart extends StatefulWidget {
  final List<UserGrowthPoint> points;

  const _UserGrowthChart({required this.points});

  @override
  State<_UserGrowthChart> createState() => _UserGrowthChartState();
}

class _UserGrowthChartState extends State<_UserGrowthChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final spots = widget.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.newUsers.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt();
              if (i < 0 || i >= widget.points.length) return null;
              return LineTooltipItem(
                '+${s.y.toInt()} users\n${DateFormat('MMM d').format(widget.points[i].date)}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          touchCallback: (e, r) {
            setState(() =>
                _touchedIndex = r?.lineBarSpots?.first.x.toInt());
          },
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: widget.points.length > 20
                  ? (widget.points.length / 5).roundToDouble()
                  : 5,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= widget.points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d/M').format(widget.points[i].date),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textMuted),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.info,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
                radius: _touchedIndex == index ? 5 : 2.5,
                color: AppColors.info,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.info.withValues(alpha: 0.3),
                  AppColors.info.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mood Trend Line Chart ────────────────────────────────

class _MoodTrendChart extends StatefulWidget {
  final List<MoodTrendPoint> points;

  const _MoodTrendChart({required this.points});

  @override
  State<_MoodTrendChart> createState() => _MoodTrendChartState();
}

class _MoodTrendChartState extends State<_MoodTrendChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final spots = widget.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.avgMood);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt();
              if (i < 0 || i >= widget.points.length) return null;
              return LineTooltipItem(
                'Avg: ${s.y.toStringAsFixed(1)}\n${DateFormat('MMM d').format(widget.points[i].date)}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          touchCallback: (e, r) {
            setState(() =>
                _touchedIndex = r?.lineBarSpots?.first.x.toInt());
          },
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: widget.points.length > 20
                  ? (widget.points.length / 5).roundToDouble()
                  : 5,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= widget.points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d/M').format(widget.points[i].date),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textMuted),
              ),
              interval: 2,
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
                radius: _touchedIndex == index ? 5 : 2.5,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Engagement ────────────────────────────────────

class _EngagementTab extends StatefulWidget {
  final Map<String, int> featureUsage;
  final Map<String, int> hourlyActivity;
  final AdminStats stats;

  const _EngagementTab({
    required this.featureUsage,
    required this.hourlyActivity,
    required this.stats,
  });

  @override
  State<_EngagementTab> createState() => _EngagementTabState();
}

class _EngagementTabState extends State<_EngagementTab> {
  int? _touchedBarIndex;

  Color _featureColor(String key) {
    switch (key.toLowerCase()) {
      case 'mood_tracking':
      case 'mood logs':
        return AppColors.tertiary;
      case 'journal':
        return const Color(0xFF8B5CF6);
      case 'ai_chat':
      case 'maya chat':
        return AppColors.primary;
      case 'mindfulness':
        return AppColors.success;
      case 'community':
        return AppColors.info;
      case 'breathing':
        return const Color(0xFF06B6D4);
      default:
        return AppColors.textMuted;
    }
  }

  String _featureLabel(String key) {
    switch (key.toLowerCase()) {
      case 'mood_tracking':
        return 'Mood Tracking';
      case 'ai_chat':
        return 'Maya Chat';
      default:
        return key
            .split('_')
            .map((w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1)}'
                : w)
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.featureUsage.values.fold(0, (a, b) => a + b);
    final sortedFeatures = widget.featureUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Build hourly bar chart data
    final hourSpots = List.generate(24, (i) {
      final v = widget.hourlyActivity[i.toString()] ?? 0;
      return FlSpot(i.toDouble(), v.toDouble());
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Feature Usage Horizontal Bars ───────────
              _AnalyticsCard(
                title: 'Feature Usage',
                subtitle: 'Activity counts (last 30 days)',
                icon: LucideIcons.chartBar,
                child: widget.featureUsage.isEmpty
                    ? const _NoData()
                    : Column(
                        children: sortedFeatures.map((e) {
                          final pct =
                              total > 0 ? e.value / total : 0.0;
                          return _HorizUsageBar(
                            label: _featureLabel(e.key),
                            value: e.value,
                            percent: pct,
                            color: _featureColor(e.key),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 16),

              // ── Hourly Activity ─────────────────────────
              _AnalyticsCard(
                title: 'Hourly Activity',
                subtitle: 'When users are most active (0–23h)',
                icon: LucideIcons.clock,
                child: SizedBox(
                  height: wide ? 220 : 180,
                  child: widget.hourlyActivity.isEmpty
                      ? const _NoData()
                      : LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) =>
                                    AppColors.textPrimary,
                                getTooltipItems: (spots) =>
                                    spots.map((s) {
                                  final h = s.x.toInt();
                                  final period =
                                      h >= 12 ? 'PM' : 'AM';
                                  final display = h > 12
                                      ? h - 12
                                      : (h == 0 ? 12 : h);
                                  return LineTooltipItem(
                                    '$display:00 $period\n${s.y.toInt()} sessions',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  );
                                }).toList(),
                              ),
                            ),
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) =>
                                  const FlLine(
                                      color: AppColors.border,
                                      strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 4,
                                  reservedSize: 20,
                                  getTitlesWidget: (v, _) {
                                    final h = v.toInt();
                                    return Text(
                                      '${h}h',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textMuted),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (v, _) => Text(
                                    v.toInt().toString(),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: hourSpots,
                                isCurved: true,
                                color: AppColors.tertiary,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.tertiary
                                          .withValues(alpha: 0.3),
                                      AppColors.tertiary
                                          .withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Engagement Funnel ───────────────────────
              _AnalyticsCard(
                title: 'Engagement Funnel',
                subtitle: 'User journey stages',
                icon: LucideIcons.users,
                child: _EngagementFunnel(stats: widget.stats),
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _HorizUsageBar extends StatelessWidget {
  final String label;
  final int value;
  final double percent;
  final Color color;

  const _HorizUsageBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.xsAll,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        borderRadius: AppRadius.xsAll,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 38,
              child: Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
}

class _EngagementFunnel extends StatelessWidget {
  final AdminStats stats;

  const _EngagementFunnel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final stages = [
      _FunnelStage(
          'Registered', stats.totalUsers, AppColors.primary, 1.0),
      _FunnelStage(
        'Onboarded',
        stats.totalUsers - stats.pendingOnboarding,
        AppColors.info,
        stats.totalUsers > 0
            ? (stats.totalUsers - stats.pendingOnboarding) /
                stats.totalUsers
            : 0,
      ),
      _FunnelStage(
        'Active This Week',
        stats.activeThisWeek,
        AppColors.success,
        stats.totalUsers > 0
            ? stats.activeThisWeek / stats.totalUsers
            : 0,
      ),
      _FunnelStage(
        'Active Today',
        stats.activeToday,
        AppColors.tertiary,
        stats.totalUsers > 0 ? stats.activeToday / stats.totalUsers : 0,
      ),
    ];

    return Column(
      children: stages.asMap().entries.map((e) {
        final stage = e.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  stage.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.xsAll,
                  child: LinearProgressIndicator(
                    value: stage.ratio.clamp(0.0, 1.0),
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor:
                        AlwaysStoppedAnimation(stage.color),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${stage.count}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: stage.color),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  ' ${(stage.ratio * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FunnelStage {
  final String label;
  final int count;
  final Color color;
  final double ratio;

  const _FunnelStage(this.label, this.count, this.color, this.ratio);
}

// ─── Tab 3: Universities ──────────────────────────────────

class _UniversitiesTab extends StatelessWidget {
  final Map<String, int> universityBreakdown;

  const _UniversitiesTab({required this.universityBreakdown});

  @override
  Widget build(BuildContext context) {
    final total =
        universityBreakdown.values.fold(0, (a, b) => a + b);
    final sorted = universityBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats
          Row(
            children: [
              _DemoCard(
                  'Total Users', '${total}',
                  LucideIcons.users, AppColors.primary),
              const SizedBox(width: 10),
              _DemoCard(
                  'Universities',
                  '${universityBreakdown.keys.length}',
                  LucideIcons.building2,
                  AppColors.info),
              const SizedBox(width: 10),
              _DemoCard(
                  'Top Share',
                  sorted.isEmpty || total == 0
                      ? 'N/A'
                      : '${(sorted.first.value / total * 100).toStringAsFixed(0)}%',
                  LucideIcons.trendingUp,
                  AppColors.success),
            ],
          ),

          const SizedBox(height: 16),

          // University list
          _AnalyticsCard(
            title: 'University Distribution',
            subtitle: 'Ranked by user count',
            icon: LucideIcons.building2,
            child: sorted.length < 3
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.building2,
                              size: 32, color: AppColors.textMuted),
                          SizedBox(height: 8),
                          Text('Insufficient data',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          SizedBox(height: 4),
                          Text('At least 3 universities needed for chart',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: sorted.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final e = entry.value;
                      final pct = total > 0 ? e.value / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            // Rank badge
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: rank == 1
                                    ? AppColors.tertiary
                                    : rank == 2
                                        ? AppColors.surfaceVariant
                                        : rank == 3
                                            ? const Color(0xFFCD7F32)
                                                .withValues(alpha: 0.2)
                                            : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: rank == 1
                                          ? Colors.white
                                          : AppColors.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: AppRadius.xsAll,
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor:
                                          AppColors.surfaceVariant,
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              AppColors.primary),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${e.value}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _DemoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DemoCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}

// ─── Tab 4: Mental Health ─────────────────────────────────

class _MentalHealthTab extends StatefulWidget {
  final Map<String, int> moodDist;
  final List<MoodTrendPoint> moodTrend;
  final AdminStats stats;

  const _MentalHealthTab({
    required this.moodDist,
    required this.moodTrend,
    required this.stats,
  });

  @override
  State<_MentalHealthTab> createState() => _MentalHealthTabState();
}

class _MentalHealthTabState extends State<_MentalHealthTab> {
  int? _touchedBarIndex;

  double get _avgMood {
    final total = widget.moodDist.values.fold(0, (a, b) => a + b);
    if (total == 0) return 0;
    return widget.moodDist.entries
            .fold<double>(0,
                (s, e) => s + (int.tryParse(e.key) ?? 0) * e.value) /
        total;
  }

  String get _moodLabel {
    final m = _avgMood;
    if (m >= 8.0) return 'Excellent';
    if (m >= 6.5) return 'Good';
    if (m >= 5.0) return 'Fair';
    if (m >= 3.5) return 'Struggling';
    return 'Critical';
  }

  Color get _moodLabelColor {
    final m = _avgMood;
    if (m >= 8.0) return AppColors.success;
    if (m >= 6.5) return AppColors.primary;
    if (m >= 5.0) return AppColors.tertiary;
    if (m >= 3.5) return AppColors.warning;
    return AppColors.error;
  }

  List<String> get _moodInsights {
    final insights = <String>[];

    if (widget.moodDist.isNotEmpty) {
      final total = widget.moodDist.values.fold(0, (a, b) => a + b);
      final highMoods = (widget.moodDist['7'] ?? 0) +
          (widget.moodDist['8'] ?? 0) +
          (widget.moodDist['9'] ?? 0) +
          (widget.moodDist['10'] ?? 0);
      final lowMoods = (widget.moodDist['1'] ?? 0) +
          (widget.moodDist['2'] ?? 0) +
          (widget.moodDist['3'] ?? 0);

      if (total > 0) {
        final highPct = (highMoods / total * 100).toStringAsFixed(0);
        insights.add('$highPct% of mood entries are rated 7+ (positive range)');
        final lowPct = (lowMoods / total * 100).toStringAsFixed(0);
        if (lowMoods > 0) {
          insights.add('$lowPct% of entries are in the low range (1–3) — may indicate users needing support');
        }
      }
    }

    if (widget.moodTrend.isNotEmpty) {
      final recentTrend = widget.moodTrend.take(7).toList();
      if (recentTrend.length >= 2) {
        final first = recentTrend.last.avgMood;
        final last = recentTrend.first.avgMood;
        final delta = last - first;
        if (delta > 0.3) {
          insights.add('Mood trending upward (+${delta.toStringAsFixed(1)}) over the last 7 days');
        } else if (delta < -0.3) {
          insights.add('Mood trending downward (${delta.toStringAsFixed(1)}) over the last 7 days — monitor closely');
        } else {
          insights.add('Platform mood has been stable over the last 7 days');
        }
      }
    }

    if (insights.isEmpty) {
      insights.add('Insufficient data to generate mood insights yet');
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avgMood;

    final sortedDist = List.generate(10, (i) {
      final key = '${i + 1}';
      return MapEntry(key, widget.moodDist[key] ?? 0);
    });
    final maxDist =
        sortedDist.fold(0, (m, e) => e.value > m ? e.value : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Mood Score Gauge ────────────────────────────
          _AnalyticsCard(
            title: 'Platform Mood Score',
            subtitle: 'Average across all logged moods',
            icon: LucideIcons.activity,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      Text(
                        avg.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: _moodLabelColor,
                            height: 1),
                      ),
                      const Text(
                        '/ 10',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _moodLabelColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          _moodLabel,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _moodLabelColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Gradient bar scale
                ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF4757),
                          Color(0xFFFF8C42),
                          Color(0xFFFFD166),
                          Color(0xFF56CC99),
                          Color(0xFF10B981),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Critical',
                        style: TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                    Text('Struggling',
                        style: TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                    Text('Fair',
                        style: TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                    Text('Good',
                        style: TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                    Text('Excellent',
                        style: TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Mood Distribution Bar Chart ──────────────────
          _AnalyticsCard(
            title: 'Mood Score Distribution',
            subtitle: 'Frequency per score (1–10)',
            icon: LucideIcons.chartBar,
            child: widget.moodDist.isEmpty
                ? const _NoData()
                : LayoutBuilder(
                    builder: (ctx, c) => SizedBox(
                      height: c.maxWidth > 600 ? 220 : 180,
                      child: BarChart(
                        BarChartData(
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) =>
                                  AppColors.textPrimary,
                              getTooltipItem: (group, gi, rod, ri) =>
                                  BarTooltipItem(
                                'Score ${group.x}\n${rod.toY.toInt()} logs',
                                const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            touchCallback: (e, r) {
                              setState(() {
                                _touchedBarIndex =
                                    r?.spot?.touchedBarGroupIndex;
                              });
                            },
                          ),
                          barGroups: sortedDist.asMap().entries.map((e) {
                            final score = e.key + 1;
                            final count = e.value.value;
                            final isTouched =
                                _touchedBarIndex == e.key;
                            return BarChartGroupData(
                              x: score,
                              barRods: [
                                BarChartRodData(
                                  toY: count.toDouble(),
                                  color: isTouched
                                      ? AppColors.moodColors[e.key]
                                      : AppColors.moodColors[e.key]
                                          .withValues(alpha: 0.8),
                                  width: 18,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxDist.toDouble(),
                                    color: AppColors.surfaceVariant,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 20,
                                getTitlesWidget: (v, _) => Text(
                                  v.toInt().toString(),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (v, _) => Text(
                                  v.toInt().toString(),
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textMuted),
                                ),
                              ),
                            ),
                            rightTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) =>
                                const FlLine(
                                    color: AppColors.border,
                                    strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // ── Mood Insights ───────────────────────────────
          _AnalyticsCard(
            title: 'Mood Insights',
            subtitle: 'AI-derived observations',
            icon: LucideIcons.sparkles,
            child: Column(
              children: _moodInsights.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Shared Widgets ───────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Icon(icon, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.xsAll,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      );
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(LucideIcons.chartBar, size: 28, color: AppColors.textMuted),
              SizedBox(height: 8),
              Text(
                'No data available yet',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
}
