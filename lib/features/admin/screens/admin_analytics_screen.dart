import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

// ─── Period Selector ─────────────────────────────────────

enum _Period { week, month, quarter }

extension _PeriodX on _Period {
  String get label {
    switch (this) {
      case _Period.week:
        return '7 Days';
      case _Period.month:
        return '30 Days';
      case _Period.quarter:
        return '90 Days';
    }
  }
}

// ─── Screen ──────────────────────────────────────────────

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  _Period _period = _Period.month;
  Map<String, int> _featureUsage = {};
  Map<String, int> _universityBreakdown = {};
  Map<String, int> _moodDist = {};
  Map<String, int> _hourlyActivity = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
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
        _HeroHeader(
          stats: state.stats,
          period: _period,
          onPeriodChanged: (p) => setState(() => _period = p),
          onRefresh: _loadAnalytics,
          loading: _loading,
        ),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            isScrollable: true,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Engagement'),
              Tab(text: 'Mental Health'),
              Tab(text: 'Universities'),
              Tab(text: 'Retention'),
            ],
          ),
        ),
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
                    ),
                    _EngagementTab(
                      featureUsage: _featureUsage,
                      hourlyActivity: _hourlyActivity,
                      stats: state.stats,
                    ),
                    _MentalHealthTab(
                      moodDist: _moodDist,
                      moodTrend: state.moodTrend,
                      stats: state.stats,
                    ),
                    _UniversitiesTab(
                      universityBreakdown: _universityBreakdown,
                    ),
                    _RetentionTab(stats: state.stats),
                  ],
                ),
        ),
      ],
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final AdminStats stats;
  final _Period period;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onRefresh;
  final bool loading;

  const _HeroHeader({
    required this.stats,
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D5C57), Color(0xFF00BEB4)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Analytics',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Real-time insights & trends',
                          style:
                              TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onRefresh,
                    icon: Icon(
                      loading ? LucideIcons.loader : LucideIcons.refreshCw,
                      size: 18,
                      color: Colors.white70,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Period chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _Period.values
                      .map((p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => onPeriodChanged(p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: period == p
                                      ? Colors.white
                                      : Colors.white
                                          .withValues(alpha: 0.15),
                                  borderRadius: AppRadius.pillAll,
                                  border: Border.all(
                                      color: Colors.white.withValues(
                                          alpha: period == p ? 0 : 0.3)),
                                ),
                                child: Text(
                                  p.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: period == p
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              // Quick stats strip
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _HeroStat(
                        label: 'Total Users',
                        value: '${stats.totalUsers}',
                        icon: LucideIcons.users),
                    _HeroStatDivider(),
                    _HeroStat(
                        label: 'Active Today',
                        value: '${stats.activeToday}',
                        icon: LucideIcons.activity),
                    _HeroStatDivider(),
                    _HeroStat(
                        label: 'Mood Logs',
                        value: '${stats.moodLogsTotal}',
                        icon: LucideIcons.heart),
                    _HeroStatDivider(),
                    _HeroStat(
                        label: 'Crisis Cases',
                        value: '${stats.crisisMessages}',
                        icon: LucideIcons.triangleAlert,
                        alert: stats.crisisMessages > 0),
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

class _HeroStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool alert;

  const _HeroStat(
      {required this.label,
      required this.value,
      required this.icon,
      this.alert = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color:
                    alert ? const Color(0xFFFFD166) : Colors.white60),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: alert
                            ? const Color(0xFFFFD166)
                            : Colors.white)),
                Text(label,
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white60)),
              ],
            ),
          ],
        ),
      );
}

class _HeroStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        width: 1,
        color: Colors.white.withValues(alpha: 0.2),
      );
}

// ─── Tab 1: Overview ─────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final AdminStats stats;
  final List<UserGrowthPoint> userGrowth;
  final List<MoodTrendPoint> moodTrend;
  final Map<String, int> hourlyActivity;

  const _OverviewTab({
    required this.stats,
    required this.userGrowth,
    required this.moodTrend,
    required this.hourlyActivity,
  });

  String get _peakHour {
    if (hourlyActivity.isEmpty) return 'N/A';
    final peak =
        hourlyActivity.entries.reduce((a, b) => a.value > b.value ? a : b);
    final h = int.tryParse(peak.key) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${display}:00 $period';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI grid with delta badges
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth > 600;
              return GridView.count(
                crossAxisCount: wide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: wide ? 1.5 : 1.35,
                children: [
                  _KpiCard(
                    label: 'Total Users',
                    value: '${stats.totalUsers}',
                    icon: LucideIcons.users,
                    color: AppColors.primary,
                    delta: stats.userGrowthPercent,
                    deltaLabel: 'WoW',
                  ),
                  _KpiCard(
                    label: 'Active Today',
                    value: '${stats.activeToday}',
                    icon: LucideIcons.zap,
                    color: AppColors.info,
                    delta: stats.totalUsers > 0
                        ? (stats.activeToday / stats.totalUsers * 100)
                        : 0,
                    deltaLabel: 'DAU%',
                    isPercent: true,
                  ),
                  _KpiCard(
                    label: 'New This Week',
                    value: '${stats.newUsersThisWeek}',
                    icon: LucideIcons.userPlus,
                    color: AppColors.success,
                    delta: stats.newUsersLastWeek > 0
                        ? ((stats.newUsersThisWeek - stats.newUsersLastWeek) /
                            stats.newUsersLastWeek *
                            100)
                        : (stats.newUsersThisWeek > 0 ? 100.0 : 0.0),
                    deltaLabel: 'vs last wk',
                  ),
                  _KpiCard(
                    label: 'Peak Hour',
                    value: _peakHour,
                    icon: LucideIcons.clock,
                    color: AppColors.tertiary,
                    noArrow: true,
                  ),
                ],
              );
            }),

            const SizedBox(height: 16),

            // Growth + Mood dual panel
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth > 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _AnalyticsCard(
                      title: 'User Growth',
                      subtitle: '30-day registrations',
                      icon: LucideIcons.userPlus,
                      child: SizedBox(
                          height: 200,
                          child: userGrowth.isEmpty
                              ? const _NoData()
                              : _UserGrowthChart(points: userGrowth)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _AnalyticsCard(
                      title: 'Mood Trend',
                      subtitle: 'Platform avg (30 days)',
                      icon: LucideIcons.activity,
                      child: SizedBox(
                          height: 200,
                          child: moodTrend.isEmpty
                              ? const _NoData()
                              : _MoodTrendChart(points: moodTrend)),
                    )),
                  ],
                );
              }
              return Column(children: [
                _AnalyticsCard(
                  title: 'User Growth',
                  subtitle: '30-day registrations',
                  icon: LucideIcons.userPlus,
                  child: SizedBox(
                      height: 180,
                      child: userGrowth.isEmpty
                          ? const _NoData()
                          : _UserGrowthChart(points: userGrowth)),
                ),
                const SizedBox(height: 12),
                _AnalyticsCard(
                  title: 'Mood Trend',
                  subtitle: 'Platform avg (30 days)',
                  icon: LucideIcons.activity,
                  child: SizedBox(
                      height: 180,
                      child: moodTrend.isEmpty
                          ? const _NoData()
                          : _MoodTrendChart(points: moodTrend)),
                ),
              ]);
            }),

            const SizedBox(height: 16),

            // Activity summary + hourly split
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth > 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _AnalyticsCard(
                      title: 'Activity Summary',
                      subtitle: 'Platform-wide totals',
                      icon: LucideIcons.layoutGrid,
                      child: _ActivitySummaryGrid(stats: stats),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _AnalyticsCard(
                      title: 'Hourly Activity',
                      subtitle: 'When users are most active',
                      icon: LucideIcons.clock,
                      child: SizedBox(
                          height: 160,
                          child: hourlyActivity.isEmpty
                              ? const _NoData()
                              : _HourlyAreaChart(
                                  hourlyActivity: hourlyActivity)),
                    )),
                  ],
                );
              }
              return Column(children: [
                _AnalyticsCard(
                  title: 'Activity Summary',
                  subtitle: 'Platform-wide totals',
                  icon: LucideIcons.layoutGrid,
                  child: _ActivitySummaryGrid(stats: stats),
                ),
                const SizedBox(height: 12),
                _AnalyticsCard(
                  title: 'Hourly Activity',
                  subtitle: 'When users are most active',
                  icon: LucideIcons.clock,
                  child: SizedBox(
                      height: 160,
                      child: hourlyActivity.isEmpty
                          ? const _NoData()
                          : _HourlyAreaChart(
                              hourlyActivity: hourlyActivity)),
                ),
              ]);
            }),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
}

// ─── KPI Card ────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final double delta;
  final String? deltaLabel;
  final bool isPercent;
  final bool noArrow;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta = 0,
    this.deltaLabel,
    this.isPercent = false,
    this.noArrow = false,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: AppRadius.xsAll),
                  child: Icon(icon, size: 14, color: color),
                ),
                const Spacer(),
                if (!noArrow && deltaLabel != null)
                  _DeltaBadge(
                      delta: delta, label: deltaLabel!, isPercent: isPercent),
              ],
            ),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String label;
  final bool isPercent;

  const _DeltaBadge(
      {required this.delta, required this.label, this.isPercent = false});

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color = up ? AppColors.success : AppColors.error;
    final sign = up ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: AppRadius.xsAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              size: 9, color: color),
          const SizedBox(width: 2),
          Text('$sign${delta.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Activity Summary Grid ────────────────────────────────

class _ActivitySummaryGrid extends StatelessWidget {
  final AdminStats stats;
  const _ActivitySummaryGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityItem('Chat Sessions', stats.chatSessions,
          LucideIcons.messageSquare, AppColors.primary),
      _ActivityItem('Journal Entries', stats.journalEntries, LucideIcons.book,
          const Color(0xFF8B5CF6)),
      _ActivityItem('Mindfulness', stats.mindfulnessSessions, LucideIcons.brain,
          AppColors.success),
      _ActivityItem(
          'Community Posts', stats.communityPosts, LucideIcons.users, AppColors.info),
      _ActivityItem('Mood Logs Today', stats.moodLogsToday, LucideIcons.heart,
          AppColors.tertiary),
      _ActivityItem('Flagged Content', stats.flaggedPosts, LucideIcons.flag,
          AppColors.warning),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 400 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
        children: items
            .map((item) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.06),
                    borderRadius: AppRadius.smAll,
                    border:
                        Border.all(color: item.color.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 16, color: item.color),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${item.value}',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: item.color,
                                  height: 1)),
                          Text(item.label,
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      )),
                    ],
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _ActivityItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _ActivityItem(this.label, this.value, this.icon, this.color);
}

// ─── Hourly Area Chart ────────────────────────────────────

class _HourlyAreaChart extends StatelessWidget {
  final Map<String, int> hourlyActivity;
  const _HourlyAreaChart({required this.hourlyActivity});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(24,
        (i) => FlSpot(i.toDouble(), (hourlyActivity[i.toString()] ?? 0).toDouble()));
    return LineChart(LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.textPrimary,
          getTooltipItems: (spots) => spots.map((s) {
            final h = s.x.toInt();
            final period = h >= 12 ? 'PM' : 'AM';
            final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
            return LineTooltipItem(
                '$display:00 $period\n${s.y.toInt()}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600));
          }).toList(),
        ),
      ),
      gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1)),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          interval: 6,
          reservedSize: 20,
          getTitlesWidget: (v, _) => Text('${v.toInt()}h',
              style:
                  const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        )),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(),
              style:
                  const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        )),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.tertiary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.tertiary.withValues(alpha: 0.3),
                    AppColors.tertiary.withValues(alpha: 0.0)
                  ])),
        )
      ],
    ));
  }
}

// ─── User Growth Chart ────────────────────────────────────

class _UserGrowthChart extends StatefulWidget {
  final List<UserGrowthPoint> points;
  const _UserGrowthChart({required this.points});
  @override
  State<_UserGrowthChart> createState() => _UserGrowthChartState();
}

class _UserGrowthChartState extends State<_UserGrowthChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final spots = widget.points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.newUsers.toDouble()))
        .toList();
    return LineChart(LineChartData(
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
                    fontWeight: FontWeight.w600));
          }).toList(),
        ),
        touchCallback: (e, r) =>
            setState(() => _touched = r?.lineBarSpots?.first.x.toInt()),
      ),
      gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1)),
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
            if (i < 0 || i >= widget.points.length) return const SizedBox.shrink();
            return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('d/M').format(widget.points[i].date),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted)));
          },
        )),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(),
              style:
                  const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        )),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                  radius: _touched == i ? 5 : 2.5,
                  color: AppColors.info,
                  strokeWidth: 2,
                  strokeColor: Colors.white)),
          belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.info.withValues(alpha: 0.3),
                    AppColors.info.withValues(alpha: 0.0)
                  ])),
        )
      ],
    ));
  }
}

// ─── Mood Trend Chart ─────────────────────────────────────

class _MoodTrendChart extends StatefulWidget {
  final List<MoodTrendPoint> points;
  const _MoodTrendChart({required this.points});
  @override
  State<_MoodTrendChart> createState() => _MoodTrendChartState();
}

class _MoodTrendChartState extends State<_MoodTrendChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final spots = widget.points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgMood))
        .toList();
    return LineChart(LineChartData(
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
                    fontWeight: FontWeight.w600));
          }).toList(),
        ),
        touchCallback: (e, r) =>
            setState(() => _touched = r?.lineBarSpots?.first.x.toInt()),
      ),
      gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1)),
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
            if (i < 0 || i >= widget.points.length) return const SizedBox.shrink();
            return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('d/M').format(widget.points[i].date),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted)));
          },
        )),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 2,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(),
              style:
                  const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        )),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                  radius: _touched == i ? 5 : 2.5,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white)),
          belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primary.withValues(alpha: 0.0)
                  ])),
        )
      ],
    ));
  }
}

// ─── Tab 2: Engagement ────────────────────────────────────

class _EngagementTab extends StatefulWidget {
  final Map<String, int> featureUsage;
  final Map<String, int> hourlyActivity;
  final AdminStats stats;

  const _EngagementTab(
      {required this.featureUsage,
      required this.hourlyActivity,
      required this.stats});

  @override
  State<_EngagementTab> createState() => _EngagementTabState();
}

class _EngagementTabState extends State<_EngagementTab> {
  int? _touchedSection;

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

  IconData _featureIcon(String key) {
    switch (key.toLowerCase()) {
      case 'mood_tracking':
      case 'mood logs':
        return LucideIcons.heart;
      case 'journal':
        return LucideIcons.book;
      case 'ai_chat':
      case 'maya chat':
        return LucideIcons.messageSquare;
      case 'mindfulness':
        return LucideIcons.brain;
      case 'community':
        return LucideIcons.users;
      default:
        return LucideIcons.zap;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.featureUsage.values.fold(0, (a, b) => a + b);
    final sortedFeatures = widget.featureUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (ctx, c) {
        final wide = c.maxWidth > 650;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bars + Donut
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 2,
                      child: _AnalyticsCard(
                        title: 'Feature Usage',
                        subtitle: 'Activity breakdown (30 days)',
                        icon: LucideIcons.chartBar,
                        child: widget.featureUsage.isEmpty
                            ? const _NoData()
                            : Column(
                                children: sortedFeatures.map((e) {
                                  final pct =
                                      total > 0 ? e.value / total : 0.0;
                                  return _UsageRow(
                                    label: _featureLabel(e.key),
                                    icon: _featureIcon(e.key),
                                    value: e.value,
                                    percent: pct,
                                    color: _featureColor(e.key),
                                  );
                                }).toList(),
                              ),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _AnalyticsCard(
                    title: 'Distribution',
                    subtitle: 'Share by feature',
                    icon: LucideIcons.chartPie,
                    child: widget.featureUsage.isEmpty
                        ? const _NoData()
                        : SizedBox(
                            height: 230,
                            child: _FeatureDonut(
                              sections: sortedFeatures
                                  .map((e) => _DonutSection(
                                      label: _featureLabel(e.key),
                                      value: e.value.toDouble(),
                                      color: _featureColor(e.key)))
                                  .toList(),
                              touched: _touchedSection,
                              onTouch: (i) =>
                                  setState(() => _touchedSection = i),
                            ),
                          ),
                  )),
                ],
              )
            else ...[
              _AnalyticsCard(
                title: 'Feature Usage',
                subtitle: 'Activity breakdown (30 days)',
                icon: LucideIcons.chartBar,
                child: widget.featureUsage.isEmpty
                    ? const _NoData()
                    : Column(
                        children: sortedFeatures.map((e) {
                          final pct = total > 0 ? e.value / total : 0.0;
                          return _UsageRow(
                            label: _featureLabel(e.key),
                            icon: _featureIcon(e.key),
                            value: e.value,
                            percent: pct,
                            color: _featureColor(e.key),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),
              _AnalyticsCard(
                title: 'Feature Distribution',
                subtitle: 'Share by feature',
                icon: LucideIcons.chartPie,
                child: widget.featureUsage.isEmpty
                    ? const _NoData()
                    : SizedBox(
                        height: 200,
                        child: _FeatureDonut(
                          sections: sortedFeatures
                              .map((e) => _DonutSection(
                                  label: _featureLabel(e.key),
                                  value: e.value.toDouble(),
                                  color: _featureColor(e.key)))
                              .toList(),
                          touched: _touchedSection,
                          onTouch: (i) => setState(() => _touchedSection = i),
                        ),
                      ),
              ),
            ],

            const SizedBox(height: 16),

            _AnalyticsCard(
              title: 'Engagement Depth',
              subtitle: 'DAU / WAU / MAU ratios',
              icon: LucideIcons.layers,
              child: _EngagementDepthPanel(stats: widget.stats),
            ),

            const SizedBox(height: 16),

            _AnalyticsCard(
              title: 'Hourly Activity',
              subtitle: 'When users are most active (0–23h)',
              icon: LucideIcons.clock,
              child: SizedBox(
                height: wide ? 200 : 160,
                child: widget.hourlyActivity.isEmpty
                    ? const _NoData()
                    : _HourlyAreaChart(
                        hourlyActivity: widget.hourlyActivity),
              ),
            ),
          ],
        );
      }),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final double percent;
  final Color color;

  const _UsageRow(
      {required this.label,
      required this.icon,
      required this.value,
      required this.percent,
      required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            SizedBox(
                width: 90,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis)),
            Expanded(
                child: Stack(children: [
              Container(
                  height: 20,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.xsAll)),
              FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.6)
                        ]),
                        borderRadius: AppRadius.xsAll,
                      ))),
            ])),
            const SizedBox(width: 8),
            SizedBox(
                width: 36,
                child: Text('$value',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color))),
            const SizedBox(width: 4),
            SizedBox(
                width: 36,
                child: Text('${(percent * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted))),
          ],
        ),
      );
}

class _DonutSection {
  final String label;
  final double value;
  final Color color;
  const _DonutSection(
      {required this.label, required this.value, required this.color});
}

class _FeatureDonut extends StatelessWidget {
  final List<_DonutSection> sections;
  final int? touched;
  final ValueChanged<int?> onTouch;

  const _FeatureDonut(
      {required this.sections, required this.touched, required this.onTouch});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const _NoData();
    final total = sections.fold(0.0, (s, x) => s + x.value);
    return Column(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (e, r) =>
                  onTouch(r?.touchedSection?.touchedSectionIndex),
            ),
            sections: sections.asMap().entries.map((e) {
              final isTouched = touched == e.key;
              return PieChartSectionData(
                value: e.value.value,
                color: e.value.color,
                radius: isTouched ? 55 : 45,
                title: isTouched
                    ? '${(e.value.value / total * 100).toStringAsFixed(0)}%'
                    : '',
                titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              );
            }).toList(),
            centerSpaceRadius: 38,
            sectionsSpace: 2,
          )),
        ),
        // Legend
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: sections
              .map((s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(s.label,
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _EngagementDepthPanel extends StatelessWidget {
  final AdminStats stats;
  const _EngagementDepthPanel({required this.stats});

  double get _dauWau => stats.activeThisWeek > 0
      ? (stats.activeToday / stats.activeThisWeek).clamp(0.0, 1.0)
      : 0;
  double get _wauMau => stats.totalUsers > 0
      ? (stats.activeThisWeek / stats.totalUsers).clamp(0.0, 1.0)
      : 0;
  double get _onboardRatio => stats.totalUsers > 0
      ? ((stats.totalUsers - stats.pendingOnboarding) / stats.totalUsers)
          .clamp(0.0, 1.0)
      : 0;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _DepthMetric('DAU / WAU', '${(_dauWau * 100).toStringAsFixed(0)}%',
          _dauWau, AppColors.primary, 'Daily active vs weekly active'),
      _DepthMetric('WAU / MAU', '${(_wauMau * 100).toStringAsFixed(0)}%',
          _wauMau, AppColors.info, 'Weekly active vs total users'),
      _DepthMetric('Onboarded', '${(_onboardRatio * 100).toStringAsFixed(0)}%',
          _onboardRatio, AppColors.success, 'Completed onboarding'),
    ];
    return Column(
      children: metrics
          .map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                        width: 100,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              Text(m.sublabel,
                                  style: const TextStyle(
                                      fontSize: 9, color: AppColors.textMuted)),
                            ])),
                    Expanded(
                        child: ClipRRect(
                      borderRadius: AppRadius.xsAll,
                      child: LinearProgressIndicator(
                        value: m.ratio,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(m.color),
                        minHeight: 16,
                      ),
                    )),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 40,
                        child: Text(m.value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: m.color))),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _DepthMetric {
  final String label, value, sublabel;
  final double ratio;
  final Color color;
  const _DepthMetric(
      this.label, this.value, this.ratio, this.color, this.sublabel);
}

// ─── Tab 3: Mental Health ─────────────────────────────────

class _MentalHealthTab extends StatefulWidget {
  final Map<String, int> moodDist;
  final List<MoodTrendPoint> moodTrend;
  final AdminStats stats;

  const _MentalHealthTab(
      {required this.moodDist, required this.moodTrend, required this.stats});

  @override
  State<_MentalHealthTab> createState() => _MentalHealthTabState();
}

class _MentalHealthTabState extends State<_MentalHealthTab> {
  int? _touchedBar;

  double get _avgMood {
    final total = widget.moodDist.values.fold(0, (a, b) => a + b);
    if (total == 0) return 0;
    return widget.moodDist.entries.fold<double>(
            0, (s, e) => s + (int.tryParse(e.key) ?? 0) * e.value) /
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

  Color get _moodColor {
    final m = _avgMood;
    if (m >= 8.0) return AppColors.success;
    if (m >= 6.5) return AppColors.primary;
    if (m >= 5.0) return AppColors.tertiary;
    if (m >= 3.5) return AppColors.warning;
    return AppColors.error;
  }

  List<_InsightItem> get _insights {
    final items = <_InsightItem>[];
    final total = widget.moodDist.values.fold(0, (a, b) => a + b);
    if (total > 0) {
      final highMoods =
          [7, 8, 9, 10].fold(0, (s, i) => s + (widget.moodDist['$i'] ?? 0));
      final lowMoods =
          [1, 2, 3].fold(0, (s, i) => s + (widget.moodDist['$i'] ?? 0));
      final highPct = (highMoods / total * 100).round();
      final lowPct = (lowMoods / total * 100).round();
      items.add(_InsightItem('$highPct% of entries in the positive range (7–10)',
          AppColors.success, LucideIcons.trendingUp));
      if (lowMoods > 0) {
        items.add(_InsightItem(
            '$lowPct% in the critical range (1–3) — may need targeted outreach',
            AppColors.error,
            LucideIcons.triangleAlert));
      }
    }
    if (widget.moodTrend.length >= 2) {
      final first = widget.moodTrend.last.avgMood;
      final last = widget.moodTrend.first.avgMood;
      final delta = last - first;
      if (delta > 0.3) {
        items.add(_InsightItem(
            'Mood trending upward (+${delta.toStringAsFixed(1)}) over 7 days',
            AppColors.success,
            LucideIcons.trendingUp));
      } else if (delta < -0.3) {
        items.add(_InsightItem(
            'Mood declining (${delta.toStringAsFixed(1)}) — monitor platform wellness',
            AppColors.warning,
            LucideIcons.trendingDown));
      } else {
        items.add(_InsightItem('Platform mood is stable over the last 7 days',
            AppColors.info, LucideIcons.minus));
      }
    }
    if (widget.stats.crisisMessages > 0) {
      final rate = widget.stats.totalUsers > 0
          ? (widget.stats.crisisMessages / widget.stats.totalUsers * 100)
              .toStringAsFixed(2)
          : '0';
      items.add(_InsightItem(
          'Crisis rate: $rate% of users flagged (${widget.stats.crisisMessages} active cases)',
          AppColors.error,
          LucideIcons.bell));
    }
    if (items.isEmpty) {
      items.add(_InsightItem('Insufficient data to generate mood insights yet',
          AppColors.textMuted, LucideIcons.info));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avgMood;
    final sortedDist = List.generate(
        10, (i) => MapEntry('${i + 1}', widget.moodDist['${i + 1}'] ?? 0));
    final maxDist = sortedDist.fold(0, (m, e) => e.value > m ? e.value : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (ctx, c) {
        final wide = c.maxWidth > 650;
        return Column(
          children: [
            // Gauge + KPIs
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _AnalyticsCard(
                  title: 'Platform Mood Score',
                  subtitle: 'Average across all logged moods',
                  icon: LucideIcons.activity,
                  child: _MoodArcGauge(
                      avg: avg, label: _moodLabel, color: _moodColor),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _AnalyticsCard(
                  title: 'Mental Health KPIs',
                  subtitle: 'Key health indicators',
                  icon: LucideIcons.heart,
                  child: _MentalHealthKpis(
                      stats: widget.stats,
                      avgMood: avg,
                      moodColor: _moodColor),
                )),
              ])
            else ...[
              _AnalyticsCard(
                title: 'Platform Mood Score',
                subtitle: 'Average across all logged moods',
                icon: LucideIcons.activity,
                child: _MoodArcGauge(
                    avg: avg, label: _moodLabel, color: _moodColor),
              ),
              const SizedBox(height: 12),
              _AnalyticsCard(
                title: 'Mental Health KPIs',
                subtitle: 'Key health indicators',
                icon: LucideIcons.heart,
                child: _MentalHealthKpis(
                    stats: widget.stats, avgMood: avg, moodColor: _moodColor),
              ),
            ],

            const SizedBox(height: 16),

            // Mood distribution bar chart
            _AnalyticsCard(
              title: 'Mood Distribution',
              subtitle: 'Frequency per score (1–10)',
              icon: LucideIcons.chartBar,
              child: widget.moodDist.isEmpty
                  ? const _NoData()
                  : SizedBox(
                      height: wide ? 220 : 180,
                      child: BarChart(BarChartData(
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AppColors.textPrimary,
                            getTooltipItem: (group, gi, rod, ri) =>
                                BarTooltipItem(
                              'Score ${group.x}\n${rod.toY.toInt()} logs',
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          touchCallback: (e, r) => setState(() =>
                              _touchedBar =
                                  r?.spot?.touchedBarGroupIndex),
                        ),
                        barGroups: sortedDist.asMap().entries.map((e) {
                          final score = e.key + 1;
                          final count = e.value.value;
                          final isTouched = _touchedBar == e.key;
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
                                      topRight: Radius.circular(4)),
                                  backDrawRodData:
                                      BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxDist.toDouble(),
                                    color: AppColors.surfaceVariant,
                                  ),
                                )
                              ]);
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
                                    color: AppColors.textMuted)),
                          )),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textMuted)),
                          )),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(
                                color: AppColors.border, strokeWidth: 1)),
                        borderData: FlBorderData(show: false),
                      )),
                    ),
            ),

            const SizedBox(height: 16),

            // Insights
            _AnalyticsCard(
              title: 'Platform Insights',
              subtitle: 'Derived from mood and usage data',
              icon: LucideIcons.sparkles,
              child: Column(
                  children: _insights
                      .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: item.color
                                            .withValues(alpha: 0.1),
                                        borderRadius: AppRadius.xsAll),
                                    child: Icon(item.icon,
                                        size: 12, color: item.color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(item.text,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                              height: 1.4))),
                                ]),
                          ))
                      .toList()),
            ),
          ],
        );
      }),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _InsightItem {
  final String text;
  final Color color;
  final IconData icon;
  const _InsightItem(this.text, this.color, this.icon);
}

// ─── Mood Arc Gauge ───────────────────────────────────────

class _MoodArcGauge extends StatelessWidget {
  final double avg;
  final String label;
  final Color color;
  const _MoodArcGauge(
      {required this.avg, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _ArcPainter(
                  value: (avg / 10).clamp(0.0, 1.0), color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    Text(avg.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: color,
                            height: 1)),
                    Text('/ 10',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.pillAll),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: Container(
                height: 6,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                  Color(0xFFFF4757),
                  Color(0xFFFF8C42),
                  Color(0xFFFFD166),
                  Color(0xFF56CC99),
                  Color(0xFF10B981),
                ]))),
          ),
          const SizedBox(height: 4),
          const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1',
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('3',
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('5',
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('7',
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('10',
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
              ]),
        ],
      );
}

class _ArcPainter extends CustomPainter {
  final double value; // 0..1
  final Color color;
  const _ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final r = math.min(cx, cy) * 0.88;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = AppColors.surfaceVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepAngle * value,
      false,
      Paint()
        ..shader = LinearGradient(
                colors: [color.withValues(alpha: 0.6), color])
            .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    final angle = startAngle + sweepAngle * value;
    final kx = cx + r * math.cos(angle);
    final ky = cy + r * math.sin(angle);
    canvas.drawCircle(Offset(kx, ky), 7, Paint()..color = color);
    canvas.drawCircle(Offset(kx, ky), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}

class _MentalHealthKpis extends StatelessWidget {
  final AdminStats stats;
  final double avgMood;
  final Color moodColor;

  const _MentalHealthKpis(
      {required this.stats, required this.avgMood, required this.moodColor});

  @override
  Widget build(BuildContext context) {
    final crisisRate = stats.totalUsers > 0
        ? (stats.crisisMessages / stats.totalUsers * 100)
        : 0.0;
    final lowMoodAlert = avgMood < 4.5 && avgMood > 0;
    return Column(children: [
      _MhRow('Avg Mood Score', avgMood.toStringAsFixed(1), moodColor,
          LucideIcons.heart),
      _MhRow(
          'Crisis Cases',
          '${stats.crisisMessages}',
          stats.crisisMessages > 0 ? AppColors.error : AppColors.success,
          LucideIcons.triangleAlert),
      _MhRow(
          'Crisis Rate',
          '${crisisRate.toStringAsFixed(2)}%',
          crisisRate > 2
              ? AppColors.error
              : crisisRate > 0.5
                  ? AppColors.warning
                  : AppColors.success,
          LucideIcons.activity),
      _MhRow(
          'Mood Alert',
          lowMoodAlert ? 'Active' : 'Clear',
          lowMoodAlert ? AppColors.warning : AppColors.success,
          LucideIcons.bell),
      _MhRow(
          'Flagged Posts',
          '${stats.flaggedPosts}',
          stats.flaggedPosts > 5 ? AppColors.warning : AppColors.textMuted,
          LucideIcons.flag),
    ]);
  }
}

class _MhRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MhRow(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.xsAll),
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ]),
      );
}

// ─── Tab 4: Universities ──────────────────────────────────

class _UniversitiesTab extends StatefulWidget {
  final Map<String, int> universityBreakdown;
  const _UniversitiesTab({required this.universityBreakdown});
  @override
  State<_UniversitiesTab> createState() => _UniversitiesTabState();
}

class _UniversitiesTabState extends State<_UniversitiesTab> {
  int? _touchedPie;

  static const _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
    AppColors.tertiary,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];

  Color _colorFor(int i) => _palette[i % _palette.length];

  @override
  Widget build(BuildContext context) {
    final total =
        widget.universityBreakdown.values.fold(0, (a, b) => a + b);
    final sorted = widget.universityBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _DemoCard('Total Users', '$total', LucideIcons.users,
                AppColors.primary),
            const SizedBox(width: 10),
            _DemoCard('Universities', '${widget.universityBreakdown.keys.length}',
                LucideIcons.building2, AppColors.info),
            const SizedBox(width: 10),
            _DemoCard(
              'Top Share',
              sorted.isEmpty || total == 0
                  ? 'N/A'
                  : '${(sorted.first.value / total * 100).toStringAsFixed(0)}%',
              LucideIcons.trendingUp,
              AppColors.success,
            ),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth > 650;
            final listCard = _AnalyticsCard(
              title: 'University Distribution',
              subtitle: 'Ranked by user count',
              icon: LucideIcons.building2,
              child: sorted.length < 2
                  ? const _NoData()
                  : Column(
                      children: sorted.asMap().entries.map((entry) {
                        final rank = entry.key + 1;
                        final e = entry.value;
                        final pct = total > 0 ? e.value / total : 0.0;
                        final color = _colorFor(entry.key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: rank <= 3
                                    ? color.withValues(alpha: 0.15)
                                    : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                  child: Text('$rank',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: rank <= 3
                                              ? color
                                              : AppColors.textSecondary))),
                            ),
                            const SizedBox(width: 10),
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(e.key,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                      borderRadius: AppRadius.xsAll,
                                      child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor:
                                              AppColors.surfaceVariant,
                                          valueColor:
                                              AlwaysStoppedAnimation(color),
                                          minHeight: 5)),
                                ])),
                            const SizedBox(width: 10),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${e.value}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                  Text('${(pct * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted)),
                                ]),
                          ]),
                        );
                      }).toList(),
                    ),
            );

            if (sorted.length < 2) return listCard;

            final pieCard = _AnalyticsCard(
              title: 'Share',
              subtitle: 'University distribution',
              icon: LucideIcons.chartPie,
              child: SizedBox(
                  height: 220,
                  child: PieChart(PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (e, r) => setState(() => _touchedPie =
                          r?.touchedSection?.touchedSectionIndex),
                    ),
                    sections: sorted.asMap().entries.map((entry) {
                      final isTouched = _touchedPie == entry.key;
                      final color = _colorFor(entry.key);
                      final pct = total > 0
                          ? entry.value.value / total * 100
                          : 0.0;
                      return PieChartSectionData(
                        value: entry.value.value.toDouble(),
                        color: color,
                        radius: isTouched ? 55 : 45,
                        title: isTouched
                            ? '${pct.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      );
                    }).toList(),
                    centerSpaceRadius: 36,
                    sectionsSpace: 2,
                  ))),
            );

            if (wide) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: listCard),
                    const SizedBox(width: 12),
                    Expanded(child: pieCard),
                  ]);
            }
            return Column(children: [
              pieCard,
              const SizedBox(height: 12),
              listCard
            ]);
          }),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Tab 5: Retention ─────────────────────────────────────

class _RetentionTab extends StatelessWidget {
  final AdminStats stats;
  const _RetentionTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final dauWau = stats.activeThisWeek > 0
        ? stats.activeToday / stats.activeThisWeek
        : 0.0;
    final wauMau =
        stats.totalUsers > 0 ? stats.activeThisWeek / stats.totalUsers : 0.0;
    final onboardRate = stats.totalUsers > 0
        ? (stats.totalUsers - stats.pendingOnboarding) / stats.totalUsers
        : 0.0;
    final retentionRate =
        stats.totalUsers > 0 ? stats.activeThisWeek / stats.totalUsers : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Retention KPIs
          LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth > 600;
            return GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 1.55 : 1.4,
              children: [
                _RetentionKpi('DAU/WAU', '${(dauWau * 100).toStringAsFixed(0)}%',
                    dauWau, AppColors.primary, 'Stickiness'),
                _RetentionKpi('WAU/MAU', '${(wauMau * 100).toStringAsFixed(0)}%',
                    wauMau, AppColors.info, 'Weekly engagement'),
                _RetentionKpi(
                    'Onboard Rate',
                    '${(onboardRate * 100).toStringAsFixed(0)}%',
                    onboardRate,
                    AppColors.success,
                    'Completed setup'),
                _RetentionKpi(
                    'Week Retention',
                    '${(retentionRate * 100).toStringAsFixed(0)}%',
                    retentionRate,
                    AppColors.tertiary,
                    'Active this week'),
              ],
            );
          }),

          const SizedBox(height: 16),

          _AnalyticsCard(
            title: 'User Lifecycle Funnel',
            subtitle: 'From signup to daily active',
            icon: LucideIcons.funnel,
            child: _LifecycleFunnel(stats: stats),
          ),

          const SizedBox(height: 16),

          Row(children: [
            Expanded(
                child: _HealthCard(
              title: 'Growth Health',
              value: stats.userGrowthPercent,
              icon: LucideIcons.userPlus,
              maxGood: 10,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _HealthCard(
              title: 'Engagement Health',
              value: dauWau * 100,
              icon: LucideIcons.zap,
              maxGood: 30,
            )),
          ]),

          const SizedBox(height: 16),

          _AnalyticsCard(
            title: 'Weekly Cohort Retention',
            subtitle: 'Estimated retention by signup week',
            icon: LucideIcons.layoutGrid,
            child: _CohortGrid(retentionRate: retentionRate),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _RetentionKpi extends StatelessWidget {
  final String label, value, sublabel;
  final double ratio;
  final Color color;

  const _RetentionKpi(
      this.label, this.value, this.ratio, this.color, this.sublabel);

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
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.xsAll),
              child: Icon(LucideIcons.percent, size: 12, color: color),
            ),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            Text(sublabel,
                style:
                    const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: AppRadius.xsAll,
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
}

class _LifecycleFunnel extends StatelessWidget {
  final AdminStats stats;
  const _LifecycleFunnel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalUsers;
    final stages = [
      _FunnelRow('Signed Up', total, total, AppColors.primary),
      _FunnelRow('Onboarded', total - stats.pendingOnboarding, total, AppColors.info),
      _FunnelRow('Active This Week', stats.activeThisWeek, total, AppColors.success),
      _FunnelRow('Active Today', stats.activeToday, total, AppColors.tertiary),
    ];
    return Column(
        children: stages
            .map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    SizedBox(
                        width: 130,
                        child: Text(s.label,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary))),
                    Expanded(
                        child: Stack(children: [
                      Container(
                          height: 24,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppRadius.xsAll)),
                      FractionallySizedBox(
                          widthFactor: s.ratio.clamp(0.0, 1.0),
                          child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  s.color,
                                  s.color.withValues(alpha: 0.7)
                                ]),
                                borderRadius: AppRadius.xsAll,
                              ))),
                    ])),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 40,
                        child: Text('${s.count}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: s.color))),
                    SizedBox(
                        width: 42,
                        child: Text(' ${(s.ratio * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted))),
                  ]),
                ))
            .toList());
  }
}

class _FunnelRow {
  final String label;
  final int count, base;
  final Color color;
  double get ratio => base > 0 ? count / base : 0;
  const _FunnelRow(this.label, this.count, this.base, this.color);
}

class _HealthCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final double maxGood;

  const _HealthCard(
      {required this.title,
      required this.value,
      required this.icon,
      this.maxGood = 10});

  Color get _color {
    if (value >= maxGood) return AppColors.success;
    if (value >= maxGood * 0.3) return AppColors.warning;
    return AppColors.error;
  }

  String get _status {
    if (value >= maxGood) return 'Healthy';
    if (value >= maxGood * 0.3) return 'Fair';
    return 'Needs attention';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: _color.withValues(alpha: 0.3)),
          boxShadow: AppShadow.sm,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                Text(_status,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _color)),
                Text('${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ])),
        ]),
      );
}

class _CohortGrid extends StatelessWidget {
  final double retentionRate;
  const _CohortGrid({required this.retentionRate});

  @override
  Widget build(BuildContext context) {
    const weeks = ['Wk -4', 'Wk -3', 'Wk -2', 'Wk -1', 'This Wk'];
    const periods = ['W1', 'W2', 'W3', 'W4', 'W5'];
    final base = retentionRate.clamp(0.05, 0.95);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 60),
        ...periods.map((p) => Expanded(
              child: Center(
                  child: Text(p,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted))),
            )),
      ]),
      const SizedBox(height: 6),
      ...weeks.asMap().entries.map((row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(
                  width: 60,
                  child: Text(row.value,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted))),
              ...periods.asMap().entries.map((col) {
                if (col.key > row.key) {
                  return Expanded(child: Container(height: 28));
                }
                final decay = math.pow(base, col.key).toDouble();
                final alpha = decay.clamp(0.1, 1.0);
                final pct = (decay * 100).round();
                return Expanded(
                    child: Container(
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withValues(alpha: alpha * 0.7),
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Center(
                      child: Text('$pct%',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: pct > 40
                                  ? Colors.white
                                  : AppColors.textSecondary))),
                ));
              }),
            ]),
          )),
      const SizedBox(height: 10),
      Row(children: [
        const Text('Low',
            style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
        Expanded(
            child: Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillAll,
            gradient: LinearGradient(colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.primary
            ]),
          ),
        )),
        const Text('High',
            style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ]),
    ]);
  }
}

// ─── Shared Widgets ───────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget child;

  const _AnalyticsCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.sm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppRadius.xsAll),
              child: Icon(icon, size: 14, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ])),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class _DemoCard extends StatelessWidget {
  final String label, value;
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
      );
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Column(children: [
          Icon(LucideIcons.chartBar, size: 28, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text('No data available yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ])),
      );
}
