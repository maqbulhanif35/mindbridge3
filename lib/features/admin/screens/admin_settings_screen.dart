import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Feature flags
  bool _maintenanceMode = false;
  bool _allowRegistrations = true;
  bool _communityEnabled = true;
  bool _crisisAlertsEnabled = true;
  bool _aiChatEnabled = true;
  bool _streaksEnabled = true;
  bool _achievementsEnabled = true;
  bool _journalEnabled = true;
  bool _mindfulnessEnabled = true;
  bool _moodTrackingEnabled = true;

  // Alert thresholds
  late double _minMoodAlert;
  late int _maxFlaggedPosts;
  late int _crisisCountAlert;

  bool _loadingLog = true;
  bool _savingThresholds = false;
  List<AdminUserEntry> _adminUsers = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    final t = ref.read(adminProvider).thresholds;
    _minMoodAlert = t.minAvgMoodAlert;
    _maxFlaggedPosts = t.maxFlaggedPosts;
    _crisisCountAlert = t.crisisCountAlert;
    _loadModerationLog();
    _loadAdmins();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadModerationLog() async {
    await ref.read(adminProvider.notifier).loadModerationLog();
    if (mounted) setState(() => _loadingLog = false);
  }

  Future<void> _loadAdmins() async {
    final db = Supabase.instance.client;
    try {
      final data = await db
          .from('profiles')
          .select(
              'id, email, name, university, year_of_study, role, is_banned, onboarding_completed, created_at')
          .inFilter('role', ['admin', 'superadmin']).order('role');
      if (mounted) {
        setState(() {
          _adminUsers = (data as List)
              .map((e) => AdminUserEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  void _saveThresholds() {
    setState(() => _savingThresholds = true);
    ref.read(adminProvider.notifier).updateThresholds(
          AlertThresholds(
            minAvgMoodAlert: _minMoodAlert,
            maxFlaggedPosts: _maxFlaggedPosts,
            crisisCountAlert: _crisisCountAlert,
          ),
        );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _savingThresholds = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(LucideIcons.circleCheck, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text('Thresholds updated'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Column(
      children: [
        // ── Hero Header ───────────────────────────────────
        _SettingsHeroHeader(
          stats: state.stats,
          maintenanceMode: _maintenanceMode,
          isMobile: isMobile,
        ),

        // ── Tabs ──────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            isScrollable: isMobile,
            tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
            labelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(
                  icon: Icon(LucideIcons.toggleLeft, size: 14),
                  text: 'Features'),
              Tab(
                  icon: Icon(LucideIcons.slidersHorizontal, size: 14),
                  text: 'Thresholds'),
              Tab(
                  icon: Icon(LucideIcons.crown, size: 14),
                  text: 'Admins'),
              Tab(
                  icon: Icon(LucideIcons.history, size: 14),
                  text: 'Audit Log'),
              Tab(
                  icon: Icon(LucideIcons.triangleAlert, size: 14),
                  text: 'Danger Zone'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _FeaturesTab(
                flags: _buildFlags(),
                maintenanceMode: _maintenanceMode,
                isMobile: isMobile,
                stats: state.stats,
              ),
              _ThresholdsTab(
                minMoodAlert: _minMoodAlert,
                maxFlaggedPosts: _maxFlaggedPosts,
                crisisCountAlert: _crisisCountAlert,
                saving: _savingThresholds,
                onMoodChanged: (v) => setState(() => _minMoodAlert = v),
                onFlaggedChanged: (v) =>
                    setState(() => _maxFlaggedPosts = v),
                onCrisisChanged: (v) =>
                    setState(() => _crisisCountAlert = v),
                onSave: _saveThresholds,
                isMobile: isMobile,
              ),
              _AdminsTab(users: _adminUsers, onRefresh: _loadAdmins),
              _AuditLogTab(
                log: ref.watch(adminProvider).moderationLog,
                isLoading: _loadingLog,
                onRefresh: _loadModerationLog,
              ),
              _DangerZoneTab(
                maintenanceMode: _maintenanceMode,
                onMaintenanceToggle: _confirmMaintenance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_FeatureFlag> _buildFlags() => [
        _FeatureFlag(
          label: 'User Registrations',
          subtitle: 'Allow new users to sign up for MindBridge',
          icon: LucideIcons.userPlus,
          value: _allowRegistrations,
          color: AppColors.success,
          onChanged: (v) => setState(() => _allowRegistrations = v),
          category: 'Access',
        ),
        _FeatureFlag(
          label: 'Maya AI Chat',
          subtitle: 'Enable the Maya AI mental health companion',
          icon: LucideIcons.brain,
          value: _aiChatEnabled,
          color: AppColors.primary,
          onChanged: (v) => setState(() => _aiChatEnabled = v),
          category: 'Features',
        ),
        _FeatureFlag(
          label: 'Mood Tracking',
          subtitle: 'Users can log daily mood check-ins',
          icon: LucideIcons.heart,
          value: _moodTrackingEnabled,
          color: AppColors.secondary,
          onChanged: (v) => setState(() => _moodTrackingEnabled = v),
          category: 'Features',
        ),
        _FeatureFlag(
          label: 'Journal',
          subtitle: 'Private journaling feature for users',
          icon: LucideIcons.bookOpen,
          value: _journalEnabled,
          color: AppColors.tertiary,
          onChanged: (v) => setState(() => _journalEnabled = v),
          category: 'Features',
        ),
        _FeatureFlag(
          label: 'Mindfulness',
          subtitle: 'Breathing exercises and mindfulness content',
          icon: LucideIcons.wind,
          value: _mindfulnessEnabled,
          color: const Color(0xFF8B5CF6),
          onChanged: (v) => setState(() => _mindfulnessEnabled = v),
          category: 'Features',
        ),
        _FeatureFlag(
          label: 'Community Posts',
          subtitle: 'Peer support community — post and interact',
          icon: LucideIcons.messageSquare,
          value: _communityEnabled,
          color: AppColors.info,
          onChanged: (v) => setState(() => _communityEnabled = v),
          category: 'Community',
        ),
        _FeatureFlag(
          label: 'Streaks & XP',
          subtitle: 'Gamification — user streaks and experience points',
          icon: LucideIcons.flame,
          value: _streaksEnabled,
          color: AppColors.warning,
          onChanged: (v) => setState(() => _streaksEnabled = v),
          category: 'Engagement',
        ),
        _FeatureFlag(
          label: 'Achievements',
          subtitle: 'Badges and milestone rewards',
          icon: LucideIcons.trophy,
          value: _achievementsEnabled,
          color: const Color(0xFFF59E0B),
          onChanged: (v) => setState(() => _achievementsEnabled = v),
          category: 'Engagement',
        ),
        _FeatureFlag(
          label: 'Crisis Alerts',
          subtitle: 'Auto-detect and flag crisis messages',
          icon: LucideIcons.shieldAlert,
          value: _crisisAlertsEnabled,
          color: AppColors.error,
          onChanged: (v) => setState(() => _crisisAlertsEnabled = v),
          category: 'Safety',
        ),
      ];

  void _confirmMaintenance(bool newValue) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text(newValue
            ? 'Enable Maintenance Mode?'
            : 'Disable Maintenance Mode?'),
        content: Text(
          newValue
              ? 'All users will be locked out immediately. Only admins can still access the app.'
              : 'This will restore full access for all users immediately.',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(_);
              setState(() => _maintenanceMode = newValue);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    newValue ? AppColors.error : AppColors.success,
                foregroundColor: Colors.white),
            child: Text(newValue ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────

class _SettingsHeroHeader extends StatelessWidget {
  final AdminStats stats;
  final bool maintenanceMode;
  final bool isMobile;

  const _SettingsHeroHeader({
    required this.stats,
    required this.maintenanceMode,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlerts =
        stats.hasCrisisAlerts || stats.moodAlertActive || maintenanceMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: maintenanceMode
              ? [const Color(0xFF7F1D1D), AppColors.error]
              : [const Color(0xFF0D5C57), AppColors.primary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, isMobile ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(LucideIcons.settings,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Admin Settings',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(
                    maintenanceMode
                        ? 'MAINTENANCE MODE ACTIVE'
                        : 'Platform configuration & controls',
                    style: TextStyle(
                      fontSize: 12,
                      color: maintenanceMode
                          ? const Color(0xFFFFD166)
                          : Colors.white70,
                      fontWeight: maintenanceMode
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ]),
              ]),

              const SizedBox(height: 12),

              // System status strip
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _StatusChip(
                    label: 'Users',
                    value: '${stats.totalUsers}',
                    icon: LucideIcons.users,
                    ok: true,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Active Today',
                    value: '${stats.activeToday}',
                    icon: LucideIcons.zap,
                    ok: stats.activeToday > 0,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Avg Mood',
                    value: stats.avgMoodScore > 0
                        ? stats.avgMoodScore.toStringAsFixed(1)
                        : 'N/A',
                    icon: LucideIcons.heart,
                    ok: !stats.moodAlertActive,
                    alert: stats.moodAlertActive,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Crisis',
                    value: '${stats.crisisMessages}',
                    icon: LucideIcons.triangleAlert,
                    ok: stats.crisisMessages == 0,
                    alert: stats.crisisMessages > 0,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Flagged',
                    value: '${stats.flaggedPosts}',
                    icon: LucideIcons.flag,
                    ok: stats.flaggedPosts == 0,
                    alert: stats.flaggedPosts > 0,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool ok;
  final bool alert;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.icon,
    this.ok = true,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alert ? 0.2 : 0.12),
          borderRadius: AppRadius.smAll,
          border: Border.all(
              color: Colors.white.withValues(alpha: alert ? 0.5 : 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12,
              color: alert
                  ? const Color(0xFFFFD166)
                  : Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color:
                        alert ? const Color(0xFFFFD166) : Colors.white,
                    height: 1)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Colors.white60)),
          ]),
        ]),
      );
}

// ─── Features Tab ─────────────────────────────────────────

class _FeaturesTab extends StatelessWidget {
  final List<_FeatureFlag> flags;
  final bool maintenanceMode;
  final bool isMobile;
  final AdminStats stats;

  const _FeaturesTab({
    required this.flags,
    required this.maintenanceMode,
    required this.isMobile,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<_FeatureFlag>>{};
    for (final f in flags) {
      categories.putIfAbsent(f.category, () => []).add(f);
    }

    final enabledCount = flags.where((f) => f.value).length;
    final totalCount = flags.length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Maintenance banner
          if (maintenanceMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.smAll,
              ),
              child: const Row(children: [
                Icon(LucideIcons.triangleAlert,
                    size: 16, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                  'MAINTENANCE MODE ACTIVE — All users are locked out',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                )),
              ]),
            ).animate().fadeIn().shake(),

          // Feature health summary
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.sm,
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.smAll),
                child: const Icon(LucideIcons.toggleLeft,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('$enabledCount / $totalCount features active',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: AppRadius.xsAll,
                      child: LinearProgressIndicator(
                        value: totalCount > 0
                            ? enabledCount / totalCount
                            : 0,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary),
                        minHeight: 5,
                      ),
                    ),
                  ])),
            ]),
          ),

          ...categories.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryHeader(entry.key),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadow.sm,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entry.value.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (ctx, i) =>
                          _FlagTile(flag: entry.value[i]),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              )),
        ],
      ),
    );
  }
}

// ─── Thresholds Tab ───────────────────────────────────────

class _ThresholdsTab extends StatelessWidget {
  final double minMoodAlert;
  final int maxFlaggedPosts;
  final int crisisCountAlert;
  final bool saving;
  final ValueChanged<double> onMoodChanged;
  final ValueChanged<int> onFlaggedChanged;
  final ValueChanged<int> onCrisisChanged;
  final VoidCallback onSave;
  final bool isMobile;

  const _ThresholdsTab({
    required this.minMoodAlert,
    required this.maxFlaggedPosts,
    required this.crisisCountAlert,
    required this.saving,
    required this.onMoodChanged,
    required this.onFlaggedChanged,
    required this.onCrisisChanged,
    required this.onSave,
    required this.isMobile,
  });

  Color _moodColor(double score) {
    if (score >= 7) return AppColors.success;
    if (score >= 5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 14, color: AppColors.info),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'These thresholds determine when system alerts are triggered on the dashboard. Changes apply immediately.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.info),
                  )),
                ]),
          ),
          const SizedBox(height: 20),

          _ThresholdCard(
            icon: LucideIcons.heart,
            iconColor: AppColors.secondary,
            title: 'Minimum Avg Mood Alert',
            subtitle:
                'Alert when platform average mood drops below this score (1–10)',
            child: Column(children: [
              Row(children: [
                const Text('1',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                Expanded(
                  child: Slider(
                    value: minMoodAlert,
                    min: 1,
                    max: 10,
                    divisions: 18,
                    activeColor: _moodColor(minMoodAlert),
                    label: minMoodAlert.toStringAsFixed(1),
                    onChanged: onMoodChanged,
                  ),
                ),
                const Text('10',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _moodColor(minMoodAlert)
                        .withValues(alpha: 0.15),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    'Alert if avg < ${minMoodAlert.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _moodColor(minMoodAlert)),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          _ThresholdCard(
            icon: LucideIcons.triangleAlert,
            iconColor: AppColors.warning,
            title: 'Max Flagged Posts Before Alert',
            subtitle:
                'Trigger moderation alert when flagged posts exceed this count',
            child: Column(children: [
              Row(children: [
                const Text('1',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                Expanded(
                  child: Slider(
                    value: maxFlaggedPosts.toDouble(),
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: AppColors.warning,
                    label: maxFlaggedPosts.toString(),
                    onChanged: (v) => onFlaggedChanged(v.round()),
                  ),
                ),
                const Text('50',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    'Alert if flagged posts ≥ $maxFlaggedPosts',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          _ThresholdCard(
            icon: LucideIcons.shieldAlert,
            iconColor: AppColors.error,
            title: 'Crisis Count Alert',
            subtitle:
                'Alert when active crisis detections reach this number',
            child: Column(children: [
              Row(children: [
                const Text('1',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                Expanded(
                  child: Slider(
                    value: crisisCountAlert.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: AppColors.error,
                    label: crisisCountAlert.toString(),
                    onChanged: (v) => onCrisisChanged(v.round()),
                  ),
                ),
                const Text('20',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    'Alert if crisis count ≥ $crisisCountAlert',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smAll),
                elevation: 0,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.save, size: 16),
              label: Text(saving ? 'Saving…' : 'Save Thresholds'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admins Tab ───────────────────────────────────────────

class _AdminsTab extends StatelessWidget {
  final List<AdminUserEntry> users;
  final VoidCallback onRefresh;

  const _AdminsTab({required this.users, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.pillAll),
            child: Text('${users.length} privileged accounts',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw,
                size: 16, color: AppColors.textMuted),
            tooltip: 'Refresh',
          ),
        ]),
        const SizedBox(height: 12),
        if (users.isEmpty)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No admin accounts found',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ))
        else
          ...users.asMap().entries.map((e) => _AdminUserCard(
                user: e.value,
                delay: Duration(milliseconds: e.key * 60),
              )),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(LucideIcons.info, size: 13, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('Role Permissions',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ]),
              SizedBox(height: 10),
              _PermRow(
                  role: 'User',
                  permissions:
                      'App access, mood logging, journal, community'),
              _PermRow(
                  role: 'Admin',
                  permissions:
                      'User + moderation, broadcasts, view analytics'),
              _PermRow(
                  role: 'Superadmin',
                  permissions:
                      'Admin + settings, danger zone, role management'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  final AdminUserEntry user;
  final Duration delay;

  const _AdminUserCard({required this.user, required this.delay});

  @override
  Widget build(BuildContext context) {
    final color = user.role == 'superadmin'
        ? const Color(0xFF8B5CF6)
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadow.sm,
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
            borderRadius: AppRadius.pillAll,
          ),
          child: Center(
              child: Text(user.initials,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              Text(user.email,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis),
              if (user.university != null)
                Text(user.university!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
            ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(user.role.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text('Since ${DateFormat('MMM yyyy').format(user.createdAt)}',
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textMuted)),
        ]),
      ]),
    ).animate(delay: delay).fadeIn(duration: 200.ms).slideY(begin: 0.05);
  }
}

class _PermRow extends StatelessWidget {
  final String role, permissions;
  const _PermRow({required this.role, required this.permissions});

  @override
  Widget build(BuildContext context) {
    final color = role == 'Superadmin'
        ? const Color(0xFF8B5CF6)
        : role == 'Admin'
            ? AppColors.primary
            : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll),
          child: Text(role,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(permissions,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary))),
      ]),
    );
  }
}

// ─── Audit Log Tab ────────────────────────────────────────

class _AuditLogTab extends StatelessWidget {
  final List<ModerationAction> log;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AuditLogTab(
      {required this.log,
      required this.isLoading,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2));
    }
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: Row(children: [
          Text('${log.length} actions logged',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw,
                size: 16, color: AppColors.textMuted),
            tooltip: 'Refresh',
          ),
        ]),
      ),
      Expanded(
        child: log.isEmpty
            ? const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(LucideIcons.history,
                      size: 40, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No moderation actions yet',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ]))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: log.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) => _AuditLogTile(
                  action: log[i],
                  delay: Duration(milliseconds: i * 20),
                ),
              ),
      ),
    ]);
  }
}

class _AuditLogTile extends StatelessWidget {
  final ModerationAction action;
  final Duration delay;
  const _AuditLogTile({required this.action, required this.delay});

  Color get _color {
    switch (action.action) {
      case 'ban':
        return AppColors.error;
      case 'unban':
        return AppColors.success;
      case 'delete':
        return AppColors.secondary;
      case 'hide':
        return AppColors.warning;
      case 'pin':
        return AppColors.tertiary;
      case 'role_change':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.textMuted;
    }
  }

  IconData get _icon {
    switch (action.action) {
      case 'ban':
        return LucideIcons.ban;
      case 'unban':
        return LucideIcons.lockOpen;
      case 'delete':
        return LucideIcons.trash2;
      case 'hide':
        return LucideIcons.eyeOff;
      case 'pin':
        return LucideIcons.pin;
      case 'role_change':
        return LucideIcons.crown;
      default:
        return LucideIcons.settings;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final idShort = action.targetId.length > 8
        ? '${action.targetId.substring(0, 8)}…'
        : action.targetId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll),
          child: Icon(_icon, size: 14, color: _color),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.xsAll),
                  child: Text(action.action.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _color)),
                ),
                const SizedBox(width: 6),
                Text('${action.targetType}: $idShort',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
              if (action.reason != null && action.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(action.reason!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
            ])),
        const SizedBox(width: 8),
        Text(_timeAgo(action.createdAt),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
    ).animate(delay: delay).fadeIn(duration: 150.ms);
  }
}

// ─── Danger Zone Tab ──────────────────────────────────────

class _DangerZoneTab extends StatelessWidget {
  final bool maintenanceMode;
  final ValueChanged<bool> onMaintenanceToggle;

  const _DangerZoneTab({
    required this.maintenanceMode,
    required this.onMaintenanceToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.triangleAlert,
                      size: 16, color: AppColors.error),
                  SizedBox(width: 10),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Danger Zone',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error)),
                      SizedBox(height: 4),
                      Text(
                        'Actions here are irreversible or affect all users immediately. Proceed with extreme caution.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.error),
                      ),
                    ],
                  )),
                ]),
          ),
          const SizedBox(height: 20),

          // Maintenance Mode card
          _DangerCard(
            title: 'Maintenance Mode',
            description:
                'Locks all users out of the app immediately. Only admin accounts can still access MindBridge. Use during deployments or emergency situations.',
            icon: LucideIcons.wrench,
            iconColor: AppColors.warning,
            active: maintenanceMode,
            actionLabel:
                maintenanceMode ? 'Disable Maintenance' : 'Enable Maintenance',
            actionColor: maintenanceMode ? AppColors.success : AppColors.warning,
            onAction: () => onMaintenanceToggle(!maintenanceMode),
            confirmRequired: true,
          ),

          const SizedBox(height: 12),

          // Data operations
          _DangerCard(
            title: 'Export All User Data',
            description:
                'Generates a GDPR-compliant full data export. Includes all user profiles, mood logs, journal entries and chat history. Delivered to superadmin email.',
            icon: LucideIcons.download,
            iconColor: AppColors.info,
            actionLabel: 'Export Data',
            actionColor: AppColors.info,
            onAction: () {},
            confirmRequired: true,
          ),

          const SizedBox(height: 12),

          _DangerCard(
            title: 'Clear All Mood Logs',
            description:
                'Permanently deletes ALL mood entries from the database. This will also reset all mood analytics and trend data. Cannot be undone.',
            icon: LucideIcons.trash2,
            iconColor: AppColors.error,
            actionLabel: 'Clear Mood Logs',
            actionColor: AppColors.error,
            onAction: () {},
            confirmRequired: true,
          ),

          const SizedBox(height: 12),

          _DangerCard(
            title: 'Reset Leaderboard',
            description:
                'Resets all user streaks, XP points and achievement progress to zero. Users will keep their accounts but lose all gamification data.',
            icon: LucideIcons.refreshCw,
            iconColor: AppColors.warning,
            actionLabel: 'Reset Leaderboard',
            actionColor: AppColors.warning,
            onAction: () {},
            confirmRequired: true,
          ),

          const SizedBox(height: 12),

          _DangerCard(
            title: 'Ban All Unverified Users',
            description:
                'Bans all user accounts that have not completed email verification. This is a bulk operation affecting potentially many accounts.',
            icon: LucideIcons.userX,
            iconColor: AppColors.error,
            actionLabel: 'Ban Unverified',
            actionColor: AppColors.error,
            onAction: () {},
            confirmRequired: true,
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  final String title, description, actionLabel;
  final IconData icon;
  final Color iconColor, actionColor;
  final bool active;
  final VoidCallback onAction;
  final bool confirmRequired;

  const _DangerCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
    this.active = false,
    this.confirmRequired = false,
  });

  void _handleTap(BuildContext context) {
    if (!confirmRequired) {
      onAction();
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text(title),
        content: Text(description,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(_);
              onAction();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
              color: active
                  ? actionColor.withValues(alpha: 0.5)
                  : AppColors.border,
              width: active ? 1.5 : 1),
          boxShadow: AppShadow.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    if (active) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: AppRadius.xsAll),
                        child: const Text('ACTIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _handleTap(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: actionColor,
                      side: BorderSide(color: actionColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    icon: Icon(icon, size: 13),
                    label: Text(actionLabel,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ])),
          ],
        ),
      );
}

// ─── Supporting Widgets ───────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String label;
  const _CategoryHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.0),
        ),
      );
}

class _ThresholdCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget child;

  const _ThresholdCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.xsAll),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ])),
              ]),
              const SizedBox(height: 12),
              child,
            ]),
      );
}

// ─── Feature Flag Models ──────────────────────────────────

class _FeatureFlag {
  final String label, subtitle, category;
  final IconData icon;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final bool urgent;

  const _FeatureFlag({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.category,
    this.urgent = false,
  });
}

class _FlagTile extends StatelessWidget {
  final _FeatureFlag flag;
  const _FlagTile({required this.flag});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: flag.color.withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll),
          child: Icon(flag.icon, size: 18, color: flag.color),
        ),
        title: Row(children: [
          Expanded(
              child: Text(flag.label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          if (flag.urgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.error, borderRadius: AppRadius.xsAll),
              child: const Text('ON',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        subtitle: Text(flag.subtitle,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        trailing:
            Switch(value: flag.value, onChanged: flag.onChanged, activeColor: flag.color),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      );
}
