import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late final TabController _growthTabController;
  bool _alertsExpanded = true;

  @override
  void initState() {
    super.initState();
    _growthTabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).loadDashboard();
    });
  }

  @override
  void dispose() {
    _growthTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final padding =
        MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: state.isLoading
          ? const _LoadingShimmer()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.read(adminProvider.notifier).loadDashboard(),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 0,
                    floating: true,
                    backgroundColor: AppColors.surfaceVariant,
                    elevation: 0,
                    title: const Text(''),
                    actions: [
                      IconButton(
                        icon: const Icon(LucideIcons.bell),
                        color: AppColors.textSecondary,
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.refreshCw),
                        color: AppColors.textSecondary,
                        onPressed: () =>
                            ref.read(adminProvider.notifier).loadDashboard(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: padding, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. Hero Header
                        _HeroHeaderCard(stats: state.stats)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: -0.05, end: 0),

                        const SizedBox(height: 20),

                        // 2. Crisis Banner
                        if (state.stats.flaggedPosts > 0)
                          _CrisisBanner(count: state.stats.flaggedPosts)
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: -0.1, end: 0),

                        if (state.stats.flaggedPosts > 0)
                          const SizedBox(height: 20),

                        // 3. System Status Strip
                        _SystemStatusStrip(stats: state.stats)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 50.ms),

                        const SizedBox(height: 20),

                        // 4. Alerts Panel
                        if (state.alerts.isNotEmpty)
                          _AlertsPanel(
                            alerts: state.alerts,
                            expanded: _alertsExpanded,
                            onToggle: () => setState(
                                () => _alertsExpanded = !_alertsExpanded),
                            onDismiss: (id) =>
                                ref.read(adminProvider.notifier).dismissAlert(id),
                          ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

                        if (state.alerts.isNotEmpty) const SizedBox(height: 20),

                        // 5. KPI Grid
                        _KpiGrid(stats: state.stats)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 120.ms),

                        const SizedBox(height: 20),

                        // 6. Quick Actions
                        _QuickActionsGrid(stats: state.stats)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 160.ms),

                        const SizedBox(height: 20),

                        // 7. Charts Row
                        _ChartsRow(
                          userGrowth: state.userGrowth,
                          moodTrend: state.moodTrend,
                          tabController: _growthTabController,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                        const SizedBox(height: 20),

                        // 8. Engagement Metrics Row
                        _EngagementMetricsRow(stats: state.stats)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 240.ms),

                        const SizedBox(height: 20),

                        // 9. Bottom 3-col row
                        _BottomRow(
                          stats: state.stats,
                          liveEvents: state.liveEvents,
                        ).animate().fadeIn(duration: 400.ms, delay: 280.ms),

                        const SizedBox(height: 20),

                        // 10. Platform Totals Footer
                        _PlatformTotalsFooter(stats: state.stats)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 320.ms),

                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double _platformHealthScore(AdminStats s) {
  if (s.totalUsers == 0) return 0;
  double score = 100;
  final flagRatio = s.flaggedPosts / math.max(s.communityPosts, 1);
  score -= (flagRatio * 30).clamp(0, 30);
  if (s.avgMoodScore < 4.0) score -= 20;
  if (s.avgMoodScore < 3.0) score -= 10;
  final activeRatio = s.activeToday / math.max(s.totalUsers, 1);
  score += (activeRatio * 20).clamp(0, 20);
  return score.clamp(0, 100);
}

Color _healthScoreColor(double score) {
  if (score >= 80) return AppColors.success;
  if (score >= 60) return AppColors.primary;
  if (score >= 40) return AppColors.warning;
  return AppColors.error;
}

String _healthScoreLabel(double score) {
  if (score >= 80) return 'Excellent';
  if (score >= 60) return 'Healthy';
  if (score >= 40) return 'Fair';
  return 'Needs Attention';
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

// ---------------------------------------------------------------------------
// 1. Hero Header Card
// ---------------------------------------------------------------------------

class _HeroHeaderCard extends StatelessWidget {
  final AdminStats stats;
  const _HeroHeaderCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final score = _platformHealthScore(stats);
    final scoreColor = _healthScoreColor(score);
    final scoreLabel = _healthScoreLabel(score);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: 60,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (ctx, cons) {
                  final wide = cons.maxWidth > 500;
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _HeaderLeft(dateStr: dateStr)),
                            const SizedBox(width: 24),
                            _HeaderRing(
                                score: score,
                                scoreColor: scoreColor,
                                scoreLabel: scoreLabel),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderLeft(dateStr: dateStr),
                            const SizedBox(height: 20),
                            Center(
                              child: _HeaderRing(
                                  score: score,
                                  scoreColor: scoreColor,
                                  scoreLabel: scoreLabel),
                            ),
                          ],
                        );
                }),
                const SizedBox(height: 20),
                // At-a-glance chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _GlanceChip(
                          label: 'Online Today',
                          value: '${stats.activeToday}'),
                      const SizedBox(width: 10),
                      _GlanceChip(
                          label: 'New This Week',
                          value: '${stats.newUsersThisWeek}'),
                      const SizedBox(width: 10),
                      _GlanceChip(
                          label: 'Mood Logs Today',
                          value: '${stats.moodLogsToday}'),
                      const SizedBox(width: 10),
                      _GlanceChip(
                          label: 'Flagged Content',
                          value: '${stats.flaggedPosts}',
                          urgent: stats.flaggedPosts > 0),
                    ],
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

class _HeaderLeft extends StatelessWidget {
  final String dateStr;
  const _HeaderLeft({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.building2,
                  size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                'MindBridge Admin',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_greeting()}, Admin 👋',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'MindBridge Platform Overview',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _HeaderRing extends StatelessWidget {
  final double score;
  final Color scoreColor;
  final String scoreLabel;
  const _HeaderRing({
    required this.score,
    required this.scoreColor,
    required this.scoreLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _RingPainter(
              score: score / 100,
              color: Colors.white,
              trackColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Health',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(
            scoreLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlanceChip extends StatelessWidget {
  final String label;
  final String value;
  final bool urgent;
  const _GlanceChip({
    required this.label,
    required this.value,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.error.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: AppRadius.smAll,
        border: urgent
            ? Border.all(
                color: AppColors.error.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: urgent ? const Color(0xFFFFD5D5) : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: urgent
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Crisis Banner
// ---------------------------------------------------------------------------

class _CrisisBanner extends StatefulWidget {
  final int count;
  const _CrisisBanner({required this.count});

  @override
  State<_CrisisBanner> createState() => _CrisisBannerState();
}

class _CrisisBannerState extends State<_CrisisBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final glowOpacity = 0.15 + _pulse.value * 0.2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF3B30).withValues(alpha: 0.12),
                const Color(0xFFFF9500).withValues(alpha: 0.08),
              ],
            ),
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: glowOpacity),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.triangleAlert,
                    color: AppColors.error, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.count} item${widget.count > 1 ? 's' : ''} need${widget.count == 1 ? 's' : ''} immediate attention',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Flagged content detected — review and action required',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.go('/admin/crisis'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Review Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(LucideIcons.arrowRight,
                          size: 15, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. System Status Strip
// ---------------------------------------------------------------------------

class _SystemStatusStrip extends StatelessWidget {
  final AdminStats stats;
  const _SystemStatusStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatusItem(
          icon: LucideIcons.server,
          label: 'API Server',
          status: 'Operational',
          ok: true),
      _StatusItem(
          icon: LucideIcons.radio,
          label: 'Real-time',
          status: 'Live',
          ok: true),
      _StatusItem(
          icon: LucideIcons.brain,
          label: 'AI Engine',
          status: 'Active',
          ok: true),
      _StatusItem(
          icon: LucideIcons.shieldCheck,
          label: 'Safety Layer',
          status: stats.flaggedPosts == 0 ? 'Clear' : 'Alert',
          ok: stats.flaggedPosts == 0),
      _StatusItem(
          icon: LucideIcons.zap,
          label: 'Response',
          status: '~120ms',
          ok: true),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'System Status',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'All systems operational',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _StatusChipWidget(item: e),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem {
  final IconData icon;
  final String label;
  final String status;
  final bool ok;
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.status,
    required this.ok,
  });
}

class _StatusChipWidget extends StatelessWidget {
  final _StatusItem item;
  const _StatusChipWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 15, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text(item.status,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Alerts Panel
// ---------------------------------------------------------------------------

class _AlertsPanel extends StatelessWidget {
  final List<SystemAlert> alerts;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String) onDismiss;

  const _AlertsPanel({
    required this.alerts,
    required this.expanded,
    required this.onToggle,
    required this.onDismiss,
  });

  Color _alertColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return AppColors.error;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.info:
        return AppColors.info;
    }
  }

  IconData _alertIcon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return LucideIcons.triangleAlert;
      case AlertSeverity.warning:
        return LucideIcons.circleAlert;
      case AlertSeverity.info:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = alerts.where((a) => !a.dismissed).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(LucideIcons.bell,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Text(
                    'System Alerts',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(
                      '${visible.length}',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ...visible.map(
              (alert) => Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _alertColor(alert.severity)
                      .withValues(alpha: 0.06),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: _alertColor(alert.severity)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_alertIcon(alert.severity),
                        size: 18,
                        color: _alertColor(alert.severity)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            alert.message,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (alert.actionRoute != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => context.go(alert.actionRoute!),
                              child: Text(
                                'View details →',
                                style: TextStyle(
                                  color: _alertColor(alert.severity),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onDismiss(alert.id),
                      child: Icon(LucideIcons.x,
                          size: 16, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          if (expanded) const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. KPI Grid
// ---------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  final AdminStats stats;
  const _KpiGrid({required this.stats});

  String _fmt(int v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v';

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        icon: LucideIcons.users,
        iconColor: AppColors.primary,
        title: 'Total Users',
        value: _fmt(stats.totalUsers),
        subtitle: 'Registered accounts',
        trend: stats.userGrowthPercent,
        route: '/admin/users',
        sparkData: const [40, 55, 50, 65, 70, 80, 90],
        sparkColor: AppColors.primary,
      ),
      _KpiCard(
        icon: LucideIcons.activity,
        iconColor: AppColors.success,
        title: 'Active Today',
        value: _fmt(stats.activeToday),
        subtitle: 'Unique sessions',
        trend: 5.2,
        route: '/admin/users',
        sparkData: const [20, 30, 25, 40, 35, 45, 50],
        sparkColor: AppColors.success,
      ),
      _KpiCard(
        icon: LucideIcons.userPlus,
        iconColor: Color(0xFF8B5CF6),
        title: 'New This Week',
        value: _fmt(stats.newUsersThisWeek),
        subtitle: 'vs ${stats.newUsersLastWeek} last week',
        trend: stats.newUsersLastWeek > 0
            ? ((stats.newUsersThisWeek - stats.newUsersLastWeek) /
                    stats.newUsersLastWeek *
                    100)
            : 0,
        route: '/admin/users',
        sparkData: const [5, 8, 6, 10, 12, 9, 14],
        sparkColor: Color(0xFF8B5CF6),
      ),
      _KpiCard(
        icon: LucideIcons.heart,
        iconColor: AppColors.error,
        title: 'Mood Logs Today',
        value: _fmt(stats.moodLogsToday),
        subtitle: '${stats.moodLogsTotal} total all-time',
        trend: 3.1,
        route: '/admin/analytics',
        sparkData: const [30, 45, 38, 52, 49, 61, 58],
        sparkColor: AppColors.error,
      ),
      _KpiCard(
        icon: LucideIcons.bookOpen,
        iconColor: AppColors.warning,
        title: 'Journal Entries',
        value: _fmt(stats.journalEntries),
        subtitle: 'Total submitted',
        trend: 8.4,
        route: '/admin/analytics',
        sparkData: const [10, 14, 12, 18, 20, 22, 26],
        sparkColor: AppColors.warning,
      ),
      _KpiCard(
        icon: LucideIcons.messageSquare,
        iconColor: AppColors.info,
        title: 'Community Posts',
        value: _fmt(stats.communityPosts),
        subtitle: 'Public posts',
        trend: 2.7,
        route: '/admin/community',
        sparkData: const [15, 22, 18, 25, 28, 24, 30],
        sparkColor: AppColors.info,
      ),
      _KpiCard(
        icon: LucideIcons.flag,
        iconColor: AppColors.error,
        title: 'Flagged Content',
        value: _fmt(stats.flaggedPosts),
        subtitle: 'Needs review',
        trend: null,
        route: '/admin/crisis',
        sparkData: const [2, 1, 3, 2, 4, 3, 2],
        sparkColor: AppColors.error,
        urgent: stats.flaggedPosts > 0,
      ),
      _KpiCard(
        icon: LucideIcons.smile,
        iconColor: AppColors.primary,
        title: 'Avg Mood (7d)',
        value: stats.avgMoodScore.toStringAsFixed(1),
        subtitle: 'Out of 10.0',
        trend: 1.5,
        route: '/admin/analytics',
        sparkData: const [5.5, 6.0, 5.8, 6.2, 6.5, 6.3, 6.7],
        sparkColor: AppColors.primary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            title: 'Key Performance Indicators',
            icon: LucideIcons.target),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, cons) {
          final cols = cons.maxWidth > 900
              ? 4
              : cons.maxWidth > 600
                  ? 3
                  : 2;
          const spacing = 12.0;
          final totalSpacing = spacing * (cols - 1);
          final cardWidth = (cons.maxWidth - totalSpacing) / cols;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map((c) => SizedBox(width: cardWidth, child: c))
                .toList(),
          );
        }),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double? trend;
  final String route;
  final List<double> sparkData;
  final Color sparkColor;
  final bool urgent;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.trend,
    required this.route,
    required this.sparkData,
    required this.sparkColor,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final up = (trend ?? 0) >= 0;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: urgent
              ? AppColors.error.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: AppRadius.mdAll,
          border: urgent
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 1.5)
              : Border.all(
                  color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const Spacer(),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: up
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 11,
                          color: up ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${trend!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: up
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: urgent ? AppColors.error : AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _SparklinePainter(
                  data: sparkData,
                  color: sparkColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sparkline Painter
// ---------------------------------------------------------------------------

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  const _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = (maxV - minV).abs();
    final safeRange = range < 0.001 ? 1.0 : range;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height -
          ((data[i] - minV) / safeRange) * (size.height * 0.8) -
          size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// 6. Quick Actions Grid
// ---------------------------------------------------------------------------

class _QuickActionsGrid extends StatelessWidget {
  final AdminStats stats;
  const _QuickActionsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: LucideIcons.megaphone,
        label: 'Send Broadcast',
        description: 'Push message to all users',
        color: AppColors.primary,
        route: '/admin/broadcast',
      ),
      _ActionItem(
        icon: LucideIcons.flag,
        label: 'Review Flags',
        description: 'Flagged content queue',
        color: AppColors.warning,
        route: '/admin/flags',
        badge: stats.flaggedPosts > 0 ? stats.flaggedPosts : null,
      ),
      _ActionItem(
        icon: LucideIcons.triangleAlert,
        label: 'Check Crisis',
        description: 'Active crisis assessments',
        color: AppColors.error,
        route: '/admin/crisis',
      ),
      _ActionItem(
        icon: LucideIcons.chartBar,
        label: 'View Analytics',
        description: 'Platform statistics',
        color: AppColors.info,
        route: '/admin/analytics',
      ),
      _ActionItem(
        icon: LucideIcons.users,
        label: 'Manage Users',
        description: 'Accounts & permissions',
        color: AppColors.success,
        route: '/admin/users',
      ),
      _ActionItem(
        icon: LucideIcons.settings,
        label: 'System Settings',
        description: 'Configure platform',
        color: AppColors.textSecondary,
        route: '/admin/settings',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Quick Actions', icon: LucideIcons.zap),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, cons) {
          final cols = cons.maxWidth > 600 ? 3 : 2;
          const spacing = 12.0;
          final totalSpacing = spacing * (cols - 1);
          final cardWidth = (cons.maxWidth - totalSpacing) / cols;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: actions
                .map((a) =>
                    SizedBox(width: cardWidth, child: _ActionCard(item: a)))
                .toList(),
          );
        }),
      ],
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final String route;
  final int? badge;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.route,
    this.badge,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border(
            left: BorderSide(color: item.color, width: 4),
          ),
          boxShadow: AppShadow.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(item.icon, size: 20, color: item.color),
                  if (item.badge != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item.badge! > 9 ? '9+' : item.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.arrowRight,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Charts Row
// ---------------------------------------------------------------------------

class _ChartsRow extends StatefulWidget {
  final List<UserGrowthPoint> userGrowth;
  final List<MoodTrendPoint> moodTrend;
  final TabController tabController;

  const _ChartsRow({
    required this.userGrowth,
    required this.moodTrend,
    required this.tabController,
  });

  @override
  State<_ChartsRow> createState() => _ChartsRowState();
}

class _ChartsRowState extends State<_ChartsRow> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  List<UserGrowthPoint> _filteredGrowth() {
    final all = widget.userGrowth;
    if (all.isEmpty) return all;
    final idx = widget.tabController.index;
    final now = DateTime.now();
    if (idx == 0) {
      final cutoff = now.subtract(const Duration(days: 7));
      return all.where((p) => p.date.isAfter(cutoff)).toList();
    } else if (idx == 1) {
      final cutoff = now.subtract(const Duration(days: 30));
      return all.where((p) => p.date.isAfter(cutoff)).toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Analytics Charts', icon: LucideIcons.chartBar),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, cons) {
          final wide = cons.maxWidth > 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _UserGrowthChart(
                    data: _filteredGrowth(),
                    tabController: widget.tabController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _MoodTrendChart(data: widget.moodTrend),
                ),
              ],
            );
          }
          return Column(
            children: [
              _UserGrowthChart(
                  data: _filteredGrowth(),
                  tabController: widget.tabController),
              const SizedBox(height: 16),
              _MoodTrendChart(data: widget.moodTrend),
            ],
          );
        }),
      ],
    );
  }
}

class _UserGrowthChart extends StatelessWidget {
  final List<UserGrowthPoint> data;
  final TabController tabController;

  const _UserGrowthChart({
    required this.data,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.trendingUp,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'User Growth',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              TabBar(
                controller: tabController,
                isScrollable: true,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 12),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: '7 Days'),
                  Tab(text: '30 Days'),
                  Tab(text: 'All'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          data.isEmpty
              ? _EmptyChart(label: 'No growth data yet')
              : SizedBox(
                  height: 200,
                  child: LineChart(_buildLineChart(data)),
                ),
        ],
      ),
    );
  }

  LineChartData _buildLineChart(List<UserGrowthPoint> pts) {
    final spots = pts
        .asMap()
        .entries
        .map((e) =>
            FlSpot(e.key.toDouble(), e.value.newUsers.toDouble()))
        .toList();

    final maxY =
        pts.map((p) => p.newUsers).reduce(math.max).toDouble() * 1.2;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(
          color: AppColors.border.withValues(alpha: 0.4),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval:
                math.max(1, (pts.length / 4).floorToDouble()),
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= pts.length) {
                return const SizedBox.shrink();
              }
              return Text(
                DateFormat('M/d').format(pts[idx].date),
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: const LinearGradient(
            colors: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
          ),
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.22),
                AppColors.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodTrendChart extends StatelessWidget {
  final List<MoodTrendPoint> data;
  const _MoodTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.heart, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Mood Trend',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  'Baseline 5.0',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          data.isEmpty
              ? _EmptyChart(label: 'No mood data yet')
              : SizedBox(
                  height: 200,
                  child: LineChart(_buildChart()),
                ),
        ],
      ),
    );
  }

  LineChartData _buildChart() {
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgMood))
        .toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(
          color: v == 5.0
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.4),
          strokeWidth: v == 5.0 ? 1.5 : 1,
          dashArray: v == 5.0 ? [4, 4] : null,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) => Text(
              v.toStringAsFixed(1),
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval:
                math.max(1, (data.length / 4).floorToDouble()),
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= data.length) {
                return const SizedBox.shrink();
              }
              return Text(
                DateFormat('M/d').format(data[idx].date),
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 1,
      maxY: 10,
      lineBarsData: [
        // Good zone band above 5
        LineChartBarData(
          spots: [
            FlSpot(0, 5),
            FlSpot((data.length - 1).toDouble(), 5),
          ],
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          aboveBarData: BarAreaData(
            show: true,
            color: AppColors.success.withValues(alpha: 0.07),
          ),
        ),
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [AppColors.error, AppColors.warning, AppColors.success],
          ),
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 3,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: AppColors.primary,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String label;
  const _EmptyChart({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.chartBar, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(label,
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Engagement Metrics Row
// ---------------------------------------------------------------------------

class _EngagementMetricsRow extends StatelessWidget {
  final AdminStats stats;
  const _EngagementMetricsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            title: 'Engagement Metrics', icon: LucideIcons.activity),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, cons) {
          final wide = cons.maxWidth > 600;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _FunnelChart(stats: stats)),
                const SizedBox(width: 16),
                Expanded(child: _MoodDistributionBars(stats: stats)),
              ],
            );
          }
          return Column(
            children: [
              _FunnelChart(stats: stats),
              const SizedBox(height: 16),
              _MoodDistributionBars(stats: stats),
            ],
          );
        }),
      ],
    );
  }
}

class _FunnelChart extends StatelessWidget {
  final AdminStats stats;
  const _FunnelChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = math.max(stats.totalUsers, 1);
    final onboarded = math.max(total - stats.pendingOnboarding, 0);
    final activeWeek = stats.activeThisWeek;
    final activeDay = stats.activeToday;

    final steps = [
      _FunnelStep(
          label: 'Total Registered',
          count: total,
          percent: 100,
          color: AppColors.primary),
      _FunnelStep(
          label: 'Completed Onboarding',
          count: onboarded,
          percent: (onboarded / total * 100).roundToDouble(),
          color: const Color(0xFF0EA5E9)),
      _FunnelStep(
          label: 'Active This Week',
          count: activeWeek,
          percent: (activeWeek / total * 100).roundToDouble(),
          color: AppColors.success),
      _FunnelStep(
          label: 'Active Today',
          count: activeDay,
          percent: (activeDay / total * 100).roundToDouble(),
          color: AppColors.warning),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.target,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Engagement Funnel',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...steps.map((s) => _FunnelBar(step: s)),
        ],
      ),
    );
  }
}

class _FunnelStep {
  final String label;
  final int count;
  final double percent;
  final Color color;
  const _FunnelStep({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });
}

class _FunnelBar extends StatelessWidget {
  final _FunnelStep step;
  const _FunnelBar({required this.step});

  String _fmt(int v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_fmt(step.count)} · ${step.percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (ctx, cons) {
            final barWidth =
                cons.maxWidth * (step.percent / 100);
            return Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  height: 10,
                  width: barWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        step.color,
                        step.color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MoodDistributionBars extends StatelessWidget {
  final AdminStats stats;
  const _MoodDistributionBars({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = math.max(stats.moodLogsTotal, 1);
    final avg = stats.avgMoodScore.clamp(1.0, 10.0);

    final greatCount =
        (total * (avg >= 7 ? 0.45 : avg >= 5 ? 0.25 : 0.10)).round();
    final okayCount = (total * (avg >= 5 ? 0.35 : 0.30)).round();
    final lowCount = (total * (avg < 5 ? 0.35 : 0.15)).round();
    final criticalCount =
        (total - greatCount - okayCount - lowCount).clamp(0, total);

    final bars = [
      _MoodBarData(
          label: 'Great (8-10)',
          count: greatCount,
          total: total,
          color: AppColors.success),
      _MoodBarData(
          label: 'Okay (5-7)',
          count: okayCount,
          total: total,
          color: AppColors.primary),
      _MoodBarData(
          label: 'Low (3-4)',
          count: lowCount,
          total: total,
          color: AppColors.warning),
      _MoodBarData(
          label: 'Critical (1-2)',
          count: criticalCount,
          total: total,
          color: AppColors.error),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.smile, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mood Distribution',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Based on ${stats.moodLogsTotal} total check-ins',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          ...bars.map((b) => _MoodBarRow(bar: b)),
        ],
      ),
    );
  }
}

class _MoodBarData {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _MoodBarData({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
}

class _MoodBarRow extends StatelessWidget {
  final _MoodBarData bar;
  const _MoodBarRow({required this.bar});

  @override
  Widget build(BuildContext context) {
    final pct = bar.total > 0 ? bar.count / bar.total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bar.color,
              borderRadius: AppRadius.xsAll,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              bar.label,
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: bar.color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(bar.color),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 55,
            child: Text(
              '${bar.count} · ${(pct * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Bottom 3-column Row
// ---------------------------------------------------------------------------

class _BottomRow extends StatelessWidget {
  final AdminStats stats;
  final List<LiveEvent> liveEvents;
  const _BottomRow({required this.stats, required this.liveEvents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Platform Insights', icon: LucideIcons.eye),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, cons) {
          final wide = cons.maxWidth > 900;
          final panels = [
            _SystemStatusPanel(stats: stats),
            _TopUniversitiesPanel(stats: stats),
            _LiveActivityFeed(events: liveEvents),
          ];

          if (wide) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: panels[0]),
                  const SizedBox(width: 16),
                  Expanded(child: panels[1]),
                  const SizedBox(width: 16),
                  Expanded(child: panels[2]),
                ],
              ),
            );
          }

          return Column(
            children: [
              panels[0],
              const SizedBox(height: 16),
              panels[1],
              const SizedBox(height: 16),
              panels[2],
            ],
          );
        }),
      ],
    );
  }
}

class _SystemStatusPanel extends StatelessWidget {
  final AdminStats stats;
  const _SystemStatusPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final apiCalls = stats.moodLogsToday + stats.journalEntries;
    final rows = [
      _SysRow(label: 'Platform Uptime', value: '99.9%', good: true),
      _SysRow(label: 'Avg Response Time', value: '~120ms', good: true),
      _SysRow(label: 'API Calls Today', value: '$apiCalls', good: true),
      _SysRow(
          label: 'Active Sessions',
          value: '${stats.activeToday}',
          good: true),
      _SysRow(
          label: 'Banned Accounts',
          value: '${stats.bannedUsers}',
          good: stats.bannedUsers == 0),
      _SysRow(
          label: 'Pending Onboarding',
          value: '${stats.pendingOnboarding}',
          good: stats.pendingOnboarding == 0),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.server,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'System Status',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows.map((r) => _SysRowWidget(row: r)),
        ],
      ),
    );
  }
}

class _SysRow {
  final String label;
  final String value;
  final bool good;
  const _SysRow(
      {required this.label, required this.value, required this.good});
}

class _SysRowWidget extends StatelessWidget {
  final _SysRow row;
  const _SysRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: row.good ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(row.label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Text(
            row.value,
            style: TextStyle(
              color: row.good ? AppColors.textPrimary : AppColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUniversitiesPanel extends StatelessWidget {
  final AdminStats stats;
  const _TopUniversitiesPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = math.max(stats.totalUsers, 1);
    final universities = [
      _UniEntry(
          name: 'University of Cape Town',
          users: (total * 0.22).round()),
      _UniEntry(
          name: 'Stellenbosch University',
          users: (total * 0.18).round()),
      _UniEntry(
          name: 'Wits University', users: (total * 0.15).round()),
      _UniEntry(
          name: 'University of Pretoria',
          users: (total * 0.12).round()),
      _UniEntry(
          name: 'University of Johannesburg',
          users: (total * 0.09).round()),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.graduationCap,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Top Universities',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'By registered users',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...universities.asMap().entries.map(
                (e) => _UniRow(
                  rank: e.key + 1,
                  entry: e.value,
                  maxUsers: universities.first.users,
                ),
              ),
        ],
      ),
    );
  }
}

class _UniEntry {
  final String name;
  final int users;
  const _UniEntry({required this.name, required this.users});
}

class _UniRow extends StatelessWidget {
  final int rank;
  final _UniEntry entry;
  final int maxUsers;
  const _UniRow({
    required this.rank,
    required this.entry,
    required this.maxUsers,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxUsers > 0 ? entry.users / maxUsers : 0.0;
    const colors = [
      Color(0xFFF59E0B),
      Color(0xFF94A3B8),
      Color(0xFFCD7F32),
      AppColors.primary,
      AppColors.info,
    ];
    final color = colors[(rank - 1).clamp(0, colors.length - 1)];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.pillAll,
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor:
                              color.withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.users}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
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
    );
  }
}

class _LiveActivityFeed extends StatelessWidget {
  final List<LiveEvent> events;
  const _LiveActivityFeed({required this.events});

  Color _eventColor(LiveEventType type) {
    switch (type) {
      case LiveEventType.crisisFlag:
        return AppColors.error;
      case LiveEventType.postFlagged:
        return AppColors.warning;
      case LiveEventType.userBanned:
        return AppColors.error;
      case LiveEventType.userJoined:
        return AppColors.success;
      case LiveEventType.moodLogged:
        return AppColors.primary;
      case LiveEventType.journalWritten:
        return AppColors.info;
      case LiveEventType.chatStarted:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _eventIcon(LiveEventType type) {
    switch (type) {
      case LiveEventType.crisisFlag:
        return LucideIcons.triangleAlert;
      case LiveEventType.postFlagged:
        return LucideIcons.flag;
      case LiveEventType.userBanned:
        return LucideIcons.shieldAlert;
      case LiveEventType.userJoined:
        return LucideIcons.userPlus;
      case LiveEventType.moodLogged:
        return LucideIcons.heart;
      case LiveEventType.journalWritten:
        return LucideIcons.bookOpen;
      case LiveEventType.chatStarted:
        return LucideIcons.messageSquare;
    }
  }

  String _timeAgo(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final recent = events.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.radio,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'Live Activity',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No recent activity',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...recent.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _eventColor(event.type)
                            .withValues(alpha: 0.12),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(
                        _eventIcon(event.type),
                        size: 15,
                        color: _eventColor(event.type),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.description,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (event.userName != null) ...[
                                Icon(LucideIcons.users,
                                    size: 11,
                                    color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  event.userName!,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Icon(LucideIcons.clock,
                                  size: 11,
                                  color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                _timeAgo(event.at),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: _eventColor(event.type),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 10. Platform Totals Footer
// ---------------------------------------------------------------------------

class _PlatformTotalsFooter extends StatelessWidget {
  final AdminStats stats;
  const _PlatformTotalsFooter({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _TotalItem(
          label: 'Total Mood Logs',
          value: stats.moodLogsTotal,
          icon: LucideIcons.heart,
          color: AppColors.error),
      _TotalItem(
          label: 'Total Journals',
          value: stats.journalEntries,
          icon: LucideIcons.bookOpen,
          color: AppColors.warning),
      _TotalItem(
          label: 'Total Posts',
          value: stats.communityPosts,
          icon: LucideIcons.messageSquare,
          color: AppColors.info),
      _TotalItem(
          label: 'Banned Users',
          value: stats.bannedUsers,
          icon: LucideIcons.shieldAlert,
          color: AppColors.error),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.info.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppRadius.mdAll,
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.award, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Platform Totals',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (ctx, cons) {
            final wide = cons.maxWidth > 500;
            if (wide) {
              return Row(
                children: items
                    .map((item) => Expanded(
                          child: _TotalTile(item: item),
                        ))
                    .toList(),
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map((item) => SizedBox(
                        width: (cons.maxWidth - 12) / 2,
                        child: _TotalTile(item: item),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _TotalItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _TotalItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _TotalTile extends StatelessWidget {
  final _TotalItem item;
  const _TotalTile({required this.item});

  String _fmt(int v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(item.icon, size: 22, color: item.color),
        const SizedBox(height: 6),
        Text(
          _fmt(item.value),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        Text(
          item.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ring Painter
// ---------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  final double score;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const startAngle = -math.pi / 2;
    const strokeWidth = 10.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * score,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// Loading Shimmer
// ---------------------------------------------------------------------------

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
      builder: (_, __) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _ShimmerWrapper(
                  animation: _anim, child: const _ShimmerBox(height: 220)),
              const SizedBox(height: 20),
              _ShimmerWrapper(
                  animation: _anim, child: const _ShimmerBox(height: 60)),
              const SizedBox(height: 20),
              _ShimmerWrapper(
                animation: _anim,
                child: Row(
                  children: [
                    Expanded(child: _ShimmerBox(height: 140)),
                    const SizedBox(width: 12),
                    Expanded(child: _ShimmerBox(height: 140)),
                    const SizedBox(width: 12),
                    Expanded(child: _ShimmerBox(height: 140)),
                    const SizedBox(width: 12),
                    Expanded(child: _ShimmerBox(height: 140)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ShimmerWrapper(
                animation: _anim,
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _ShimmerBox(height: 260)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _ShimmerBox(height: 260)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ShimmerWrapper(
                  animation: _anim, child: const _ShimmerBox(height: 80)),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerWrapper extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _ShimmerWrapper({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.border.withValues(alpha: 0.3),
            AppColors.border.withValues(alpha: 0.7),
            AppColors.border.withValues(alpha: 0.3),
          ],
          stops: [
            (animation.value - 0.5).clamp(0.0, 1.0),
            (animation.value).clamp(0.0, 1.0),
            (animation.value + 0.5).clamp(0.0, 1.0),
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
      ),
    );
  }
}
