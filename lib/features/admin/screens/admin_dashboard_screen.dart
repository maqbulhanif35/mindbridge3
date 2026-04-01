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

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(adminProvider).stats.totalUsers == 0) {
        ref.read(adminProvider.notifier).loadDashboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final activeAlerts = state.alerts.where((a) => !a.dismissed).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final padding = isWide ? 24.0 : 12.0;

        return RefreshIndicator(
          onRefresh: () => ref.read(adminProvider.notifier).loadDashboard(),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── System Status Strip ───────────────
                _SystemStatusStrip(
                  alerts: activeAlerts,
                  stats: state.stats,
                ),

                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header + Health Score Row ─────
                      _buildHeaderRow(context, state, isWide),
                      const SizedBox(height: 20),

                      // ── Alerts Panel ─────────────────
                      if (activeAlerts.isNotEmpty) ...[
                        _CollapsibleAlertsPanel(
                          alerts: activeAlerts,
                          onDismiss: (id) =>
                              ref.read(adminProvider.notifier).dismissAlert(id),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── KPI Cards ────────────────────
                      _KpiGrid(
                        stats: state.stats,
                        isLoading: state.isLoading,
                        isWide: isWide,
                      ),
                      const SizedBox(height: 24),

                      // ── Quick Actions ─────────────────
                      _QuickActionsRow(),
                      const SizedBox(height: 24),

                      // ── Charts Row ────────────────────
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _UserGrowthChart(
                                  points: state.userGrowth,
                                  isLoading: state.isLoading),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _MoodDistributionChart(
                                  points: state.moodTrend,
                                  isLoading: state.isLoading),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _UserGrowthChart(
                                points: state.userGrowth,
                                isLoading: state.isLoading),
                            const SizedBox(height: 16),
                            _MoodDistributionChart(
                                points: state.moodTrend,
                                isLoading: state.isLoading),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // ── Bottom Row ────────────────────
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _MoodTrendLineChart(
                                  points: state.moodTrend,
                                  isLoading: state.isLoading),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 300,
                              child: Column(
                                children: [
                                  _SystemStatusPanel(stats: state.stats),
                                  const SizedBox(height: 16),
                                  _LiveActivityFeed(events: state.liveEvents),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _MoodTrendLineChart(
                                points: state.moodTrend,
                                isLoading: state.isLoading),
                            const SizedBox(height: 16),
                            _SystemStatusPanel(stats: state.stats),
                            const SizedBox(height: 16),
                            _LiveActivityFeed(events: state.liveEvents),
                          ],
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(
      BuildContext context, AdminState state, bool isWide) {
    final score = _platformHealthScore(state.stats);
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _DashboardHeader(stats: state.stats)),
          const SizedBox(width: 24),
          _PlatformHealthCard(score: score, isLoading: state.isLoading),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardHeader(stats: state.stats),
        const SizedBox(height: 16),
        _PlatformHealthCard(score: score, isLoading: state.isLoading),
      ],
    );
  }
}

// ─── Platform Health Score ────────────────────────────────

double _platformHealthScore(AdminStats s) {
  final moodHealth = s.avgMoodScore > 0 ? (s.avgMoodScore / 10) * 40 : 20.0;
  final engagement = (s.activeToday / math.max(s.totalUsers, 1)) * 30;
  final communityHealth = (1 - s.bannedUsers / math.max(s.totalUsers, 1)) * 20;
  final moderation = (s.flaggedPosts == 0 ? 1.0 : 0.5) * 10;
  return (moodHealth + engagement + communityHealth + moderation)
      .clamp(0.0, 100.0);
}

Color _healthScoreColor(double score) {
  if (score >= 70) return AppColors.success;
  if (score >= 40) return AppColors.warning;
  return AppColors.error;
}

String _healthScoreLabel(double score) {
  if (score >= 80) return 'Excellent';
  if (score >= 70) return 'Healthy';
  if (score >= 55) return 'Good';
  if (score >= 40) return 'Fair';
  if (score >= 25) return 'At Risk';
  return 'Critical';
}

// ─── Platform Health Card ─────────────────────────────────

class _PlatformHealthCard extends StatefulWidget {
  final double score;
  final bool isLoading;
  const _PlatformHealthCard({required this.score, required this.isLoading});

  @override
  State<_PlatformHealthCard> createState() => _PlatformHealthCardState();
}

class _PlatformHealthCardState extends State<_PlatformHealthCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (!widget.isLoading) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_PlatformHealthCard old) {
    super.didUpdateWidget(old);
    if (!widget.isLoading && old.isLoading) {
      _anim = Tween<double>(begin: 0, end: widget.score / 100).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _healthScoreColor(widget.score);
    final label = _healthScoreLabel(widget.score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(80, 80),
                    painter: _RingPainter(
                      progress: _anim.value,
                      color: color,
                      trackColor: color.withValues(alpha: 0.1),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isLoading
                            ? '--'
                            : widget.score.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Platform Health',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _MiniScoreFactor(
                  label: 'Mood', color: AppColors.success),
              _MiniScoreFactor(
                  label: 'Engagement', color: AppColors.primary),
              _MiniScoreFactor(
                  label: 'Community', color: AppColors.info),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05);
  }
}

class _MiniScoreFactor extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniScoreFactor({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted)),
        ],
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── System Status Strip ──────────────────────────────────

class _SystemStatusStrip extends StatelessWidget {
  final List<SystemAlert> alerts;
  final AdminStats stats;

  const _SystemStatusStrip({required this.alerts, required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasCritical = alerts.any((a) => a.severity == AlertSeverity.critical);
    final hasWarning = alerts.any((a) => a.severity == AlertSeverity.warning);

    Color stripColor;
    IconData icon;
    String text;

    if (alerts.isEmpty) {
      stripColor = AppColors.success;
      icon = LucideIcons.circleCheck;
      text = 'All systems operational';
    } else if (hasCritical) {
      stripColor = AppColors.error;
      icon = LucideIcons.circleAlert;
      text = '${alerts.length} critical alert${alerts.length > 1 ? 's' : ''} — immediate attention needed';
    } else if (hasWarning) {
      stripColor = AppColors.warning;
      icon = LucideIcons.triangleAlert;
      text = '${alerts.length} active alert${alerts.length > 1 ? 's' : ''} — review recommended';
    } else {
      stripColor = AppColors.info;
      icon = LucideIcons.info;
      text = '${alerts.length} system notice${alerts.length > 1 ? 's' : ''}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: stripColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, size: 14, color: stripColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: stripColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Header ─────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final AdminStats stats;
  const _DashboardHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final growth = stats.userGrowthPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Last updated ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (stats.totalUsers > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: growth >= 0
                      ? AppColors.successContainer
                      : AppColors.errorContainer,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      growth >= 0
                          ? LucideIcons.trendingUp
                          : LucideIcons.trendingDown,
                      size: 12,
                      color: growth >= 0 ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}% this week',
                      style: TextStyle(
                        color: growth >= 0
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Collapsible Alerts Panel ─────────────────────────────

class _CollapsibleAlertsPanel extends StatefulWidget {
  final List<SystemAlert> alerts;
  final void Function(String) onDismiss;

  const _CollapsibleAlertsPanel(
      {required this.alerts, required this.onDismiss});

  @override
  State<_CollapsibleAlertsPanel> createState() =>
      _CollapsibleAlertsPanelState();
}

class _CollapsibleAlertsPanelState extends State<_CollapsibleAlertsPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _ctrl;
  late Animation<double> _sizeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _sizeAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final hasCritical =
        widget.alerts.any((a) => a.severity == AlertSeverity.critical);
    final headerColor =
        hasCritical ? AppColors.error : AppColors.warning;

    return Column(
      children: [
        // Header row
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.08),
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : AppRadius.mdAll,
              border: Border.all(
                  color: headerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  hasCritical
                      ? LucideIcons.circleAlert
                      : LucideIcons.triangleAlert,
                  size: 16,
                  color: headerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.alerts.length} Active Alert${widget.alerts.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.0 : -0.5,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(LucideIcons.chevronDown,
                      size: 16, color: headerColor),
                ),
              ],
            ),
          ),
        ),
        // Animated body
        SizeTransition(
          sizeFactor: _sizeAnim,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: headerColor.withValues(alpha: 0.3)),
                right:
                    BorderSide(color: headerColor.withValues(alpha: 0.3)),
                bottom:
                    BorderSide(color: headerColor.withValues(alpha: 0.3)),
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12)),
            ),
            child: Column(
              children: widget.alerts
                  .map((a) =>
                      _AlertTile(alert: a, onDismiss: widget.onDismiss))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Alert Tile ───────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final SystemAlert alert;
  final void Function(String) onDismiss;

  const _AlertTile({required this.alert, required this.onDismiss});

  Color get _bgColor {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return AppColors.errorContainer;
      case AlertSeverity.warning:
        return const Color(0xFFFFF7ED);
      case AlertSeverity.info:
        return const Color(0xFFEFF6FF);
    }
  }

  Color get _iconColor {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return AppColors.error;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.info:
        return AppColors.info;
    }
  }

  IconData get _icon {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return LucideIcons.circleAlert;
      case AlertSeverity.warning:
        return LucideIcons.triangleAlert;
      case AlertSeverity.info:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _bgColor,
      child: Row(
        children: [
          Icon(_icon, size: 18, color: _iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _iconColor,
                  ),
                ),
                Text(
                  alert.message,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (alert.actionRoute != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.go(alert.actionRoute!),
              child: Text(
                'View',
                style: TextStyle(
                    fontSize: 12,
                    color: _iconColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 14),
            color: AppColors.textMuted,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => onDismiss(alert.id),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }
}

// ─── KPI Grid ─────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final AdminStats stats;
  final bool isLoading;
  final bool isWide;
  const _KpiGrid(
      {required this.stats, required this.isLoading, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData(
        title: 'Total Users',
        value: stats.totalUsers.toString(),
        sub: '+${stats.newUsersThisWeek} this week',
        icon: LucideIcons.users,
        color: AppColors.primary,
        trend: stats.userGrowthPercent,
        route: '/admin/users',
      ),
      _KpiData(
        title: 'Active Today',
        value: stats.activeToday.toString(),
        sub: '${stats.activeThisWeek} this week',
        icon: LucideIcons.activity,
        color: AppColors.success,
        route: '/admin/users',
      ),
      _KpiData(
        title: 'New This Week',
        value: stats.newUsersThisWeek.toString(),
        sub: '${stats.newUsersToday} today',
        icon: LucideIcons.userPlus,
        color: AppColors.info,
        trend: stats.userGrowthPercent,
        route: '/admin/users',
      ),
      _KpiData(
        title: 'Mood Logs Today',
        value: stats.moodLogsToday.toString(),
        sub: '${stats.moodLogsTotal} all-time',
        icon: LucideIcons.heart,
        color: AppColors.tertiary,
        route: '/admin/analytics',
      ),
      _KpiData(
        title: 'Journal Entries',
        value: stats.journalEntries.toString(),
        sub: 'All users',
        icon: LucideIcons.bookOpen,
        color: const Color(0xFF8B5CF6),
        route: '/admin/analytics',
      ),
      _KpiData(
        title: 'Community Posts',
        value: stats.communityPosts.toString(),
        sub: '${stats.flaggedPosts} flagged',
        icon: LucideIcons.messageSquare,
        color: AppColors.primary,
        route: '/admin/moderation',
      ),
      _KpiData(
        title: 'Flagged Content',
        value: stats.flaggedPosts.toString(),
        sub: 'Needs review',
        icon: LucideIcons.shieldAlert,
        color: AppColors.error,
        urgent: stats.flaggedPosts > 0,
        route: '/admin/moderation',
      ),
      _KpiData(
        title: 'Avg Mood (7d)',
        value: stats.avgMoodScore.toStringAsFixed(1),
        sub: 'Scale 1–10',
        icon: LucideIcons.smile,
        color: _moodColor(stats.avgMoodScore),
        route: '/admin/analytics',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isWide ? 220 : 180,
        mainAxisExtent: 120,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) => _KpiCard(
        data: cards[i],
        isLoading: isLoading,
        delay: Duration(milliseconds: i * 60),
      ),
    );
  }

  Color _moodColor(double score) {
    if (score >= 7) return AppColors.success;
    if (score >= 5) return AppColors.tertiary;
    return AppColors.error;
  }
}

class _KpiData {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final double? trend;
  final bool urgent;
  final String route;

  const _KpiData({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.trend,
    this.urgent = false,
    required this.route,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final bool isLoading;
  final Duration delay;

  const _KpiCard({
    required this.data,
    required this.isLoading,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => context.go(data.route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: data.urgent
                  ? data.color.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
            boxShadow: AppShadow.sm,
          ),
          child: isLoading
              ? _LoadingShimmer()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: data.color.withValues(alpha: 0.12),
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Icon(data.icon, size: 18, color: data.color),
                        ),
                        const Spacer(),
                        if (data.trend != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                data.trend! >= 0
                                    ? LucideIcons.trendingUp
                                    : LucideIcons.trendingDown,
                                size: 13,
                                color: data.trend! >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${data.trend!.abs().toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: data.trend! >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        if (data.urgent)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: data.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      data.value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: data.urgent
                            ? data.color
                            : AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      data.sub,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    ).animate(delay: delay).fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }
}

// ─── Quick Actions Row ────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        label: 'Send Broadcast',
        icon: LucideIcons.megaphone,
        color: AppColors.primary,
        route: '/admin/broadcast',
      ),
      _QuickAction(
        label: 'Review Flags',
        icon: LucideIcons.flag,
        color: AppColors.warning,
        route: '/admin/moderation',
      ),
      _QuickAction(
        label: 'Check Crisis',
        icon: LucideIcons.triangleAlert,
        color: AppColors.error,
        route: '/admin/crisis',
      ),
      _QuickAction(
        label: 'View Analytics',
        icon: LucideIcons.chartBar,
        color: AppColors.info,
        route: '/admin/analytics',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: actions
                .asMap()
                .entries
                .map((e) => Padding(
                      padding: EdgeInsets.only(
                          right: e.key < actions.length - 1 ? 10 : 0),
                      child: _QuickActionCard(action: e.value),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: 0.08),
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: () => context.go(action.route),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: action.color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(action.icon, size: 18, color: action.color),
              ),
              const SizedBox(height: 10),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: action.color,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.05);
  }
}

// ─── User Growth Line Chart ───────────────────────────────

class _UserGrowthChart extends StatelessWidget {
  final List<UserGrowthPoint> points;
  final bool isLoading;
  const _UserGrowthChart({required this.points, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'User Growth',
      subtitle: 'New registrations (30 days)',
      icon: LucideIcons.trendingUp,
      iconColor: AppColors.primary,
      isLoading: isLoading || points.isEmpty,
      child: SizedBox(
        height: 200,
        child: points.isEmpty
            ? const Center(
                child: Text('No data',
                    style: TextStyle(color: AppColors.textMuted)))
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: points.length > 14
                            ? (points.length / 6).roundToDouble()
                            : 2,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('d/M').format(points[i].date),
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (val, _) => Text(
                          val.toInt().toString(),
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
                      spots: points
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                              e.key.toDouble(),
                              e.value.newUsers.toDouble()))
                          .toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.info],
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
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
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

// ─── Mood Distribution Bar Chart ──────────────────────────

class _MoodDistributionChart extends StatelessWidget {
  final List<MoodTrendPoint> points;
  final bool isLoading;
  const _MoodDistributionChart(
      {required this.points, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final bins = <String, int>{
      'Critical (1-3)': 0,
      'Low (4-5)': 0,
      'Okay (6-7)': 0,
      'Great (8-10)': 0,
    };
    for (final p in points) {
      if (p.avgMood <= 3) {
        bins['Critical (1-3)'] = (bins['Critical (1-3)']! + p.count);
      } else if (p.avgMood <= 5) {
        bins['Low (4-5)'] = (bins['Low (4-5)']! + p.count);
      } else if (p.avgMood <= 7) {
        bins['Okay (6-7)'] = (bins['Okay (6-7)']! + p.count);
      } else {
        bins['Great (8-10)'] = (bins['Great (8-10)']! + p.count);
      }
    }

    final total = bins.values.fold(0, (a, b) => a + b);

    return _ChartCard(
      title: 'Mood Distribution',
      subtitle: 'Last 30 days',
      icon: LucideIcons.chartPie,
      iconColor: AppColors.tertiary,
      isLoading: isLoading || points.isEmpty,
      child: total == 0
          ? const SizedBox(
              height: 200,
              child: Center(
                  child: Text('No mood data',
                      style: TextStyle(color: AppColors.textMuted))))
          : Column(
              children: [
                SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(
                          value: bins['Critical (1-3)']!.toDouble(),
                          color: AppColors.error,
                          title: bins['Critical (1-3)']! > 0
                              ? '${((bins['Critical (1-3)']! / total) * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          radius: 48,
                        ),
                        PieChartSectionData(
                          value: bins['Low (4-5)']!.toDouble(),
                          color: AppColors.warning,
                          title: bins['Low (4-5)']! > 0
                              ? '${((bins['Low (4-5)']! / total) * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          radius: 48,
                        ),
                        PieChartSectionData(
                          value: bins['Okay (6-7)']!.toDouble(),
                          color: AppColors.primary,
                          title: bins['Okay (6-7)']! > 0
                              ? '${((bins['Okay (6-7)']! / total) * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          radius: 48,
                        ),
                        PieChartSectionData(
                          value: bins['Great (8-10)']!.toDouble(),
                          color: AppColors.success,
                          title: bins['Great (8-10)']! > 0
                              ? '${((bins['Great (8-10)']! / total) * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          radius: 48,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _Legend('Critical', AppColors.error),
                    _Legend('Low', AppColors.warning),
                    _Legend('Okay', AppColors.primary),
                    _Legend('Great', AppColors.success),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

// ─── Mood Trend Area Chart ────────────────────────────────

class _MoodTrendLineChart extends StatelessWidget {
  final List<MoodTrendPoint> points;
  final bool isLoading;
  const _MoodTrendLineChart(
      {required this.points, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Mood Trend',
      subtitle: 'Average daily mood (30 days)',
      icon: LucideIcons.activity,
      iconColor: AppColors.success,
      isLoading: isLoading || points.isEmpty,
      child: SizedBox(
        height: 200,
        child: points.isEmpty
            ? const Center(
                child: Text('No data',
                    style: TextStyle(color: AppColors.textMuted)))
            : LineChart(
                LineChartData(
                  minY: 1,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 2,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: points.length > 14
                            ? (points.length / 5).roundToDouble()
                            : 2,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('d/M').format(points[i].date),
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Reference line at 5
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 5),
                        FlSpot((points.length - 1).toDouble(), 5),
                      ],
                      color: AppColors.border,
                      barWidth: 1,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: points
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                              e.key.toDouble(), e.value.avgMood))
                          .toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.success],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.success.withValues(alpha: 0.18),
                            AppColors.success.withValues(alpha: 0.0),
                          ],
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

// ─── System Status Panel ──────────────────────────────────

class _SystemStatusPanel extends StatelessWidget {
  final AdminStats stats;
  const _SystemStatusPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(LucideIcons.server,
                    size: 16, color: AppColors.success),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Infrastructure & services',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            _StatusRow('Database', true, 'Supabase PostgreSQL'),
            _StatusRow('Auth Service', true, 'Supabase Auth'),
            _StatusRow('Storage', true, 'Supabase Storage'),
            _StatusRow('AI (Maya)', true, 'Groq LLaMA 3.3'),
            _StatusRow(
                'Content Flagged',
                stats.flaggedPosts == 0,
                stats.flaggedPosts == 0
                    ? 'Clear'
                    : '${stats.flaggedPosts} pending review'),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatPill('${stats.totalUsers} users', AppColors.primary),
              _StatPill('${stats.moodLogsTotal} logs', AppColors.success),
              _StatPill(
                  '${stats.journalEntries} journals', AppColors.tertiary),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String name;
  final bool ok;
  final String detail;
  const _StatusRow(this.name, this.ok, this.detail);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: ok ? AppColors.success : AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(name,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            Text(detail,
                style: TextStyle(
                    fontSize: 11,
                    color: ok ? AppColors.textMuted : AppColors.error)),
          ],
        ),
      );
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.pillAll,
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      );
}

// ─── Live Activity Feed ───────────────────────────────────

class _LiveActivityFeed extends StatelessWidget {
  final List<LiveEvent> events;

  const _LiveActivityFeed({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(LucideIcons.activity,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Activity',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      'Real-time platform events',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(LucideIcons.radio,
                      size: 32,
                      color: AppColors.textMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  const Text(
                    'Listening for events…',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...events.take(10).map((e) => _LiveEventRow(event: e)),
        ],
      ),
    );
  }
}

class _LiveEventRow extends StatelessWidget {
  final LiveEvent event;
  const _LiveEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    switch (event.type) {
      case LiveEventType.crisisFlag:
        dotColor = AppColors.error;
        break;
      case LiveEventType.postFlagged:
        dotColor = AppColors.warning;
        break;
      case LiveEventType.userBanned:
        dotColor = AppColors.error;
        break;
      case LiveEventType.userJoined:
        dotColor = AppColors.success;
        break;
      default:
        dotColor = AppColors.primary;
    }

    final now = DateTime.now();
    final diff = now.difference(event.at);
    final timeLabel = diff.inSeconds < 60
        ? '${diff.inSeconds}s ago'
        : diff.inMinutes < 60
            ? '${diff.inMinutes}m ago'
            : '${diff.inHours}h ago';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (event.userName != null)
                  Text(
                    event.userName!,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeLabel,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Chart Card Wrapper ───────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final bool isLoading;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          isLoading
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : child,
        ],
      ),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────

class _LoadingShimmer extends StatefulWidget {
  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.8).animate(_ctrl);
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
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: _anim.value),
          borderRadius: AppRadius.smAll,
        ),
      ),
    );
  }
}
