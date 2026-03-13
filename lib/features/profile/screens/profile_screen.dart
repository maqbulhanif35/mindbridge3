import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final streakState = ref.watch(streakProvider);
    final moodState = ref.watch(moodProvider);

    final overall = streakState.overall;
    final avgMood = moodState.entries.isEmpty
        ? 0.0
        : moodState.entries
                .take(30)
                .map((e) => e.moodScore)
                .fold(0, (a, b) => a + b) /
            moodState.entries.take(30).length;
    final totalEntries = moodState.entries.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.tokenBackground,
        body: CustomScrollView(
          slivers: [
            // ─── Hero Header ────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHero(user: user),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Stats Row ────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        icon: LucideIcons.calendarDays,
                        value: '${overall?.totalDays ?? 0}',
                        label: 'Days',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: Spacing.sm),
                      _StatCard(
                        icon: LucideIcons.smile,
                        value: avgMood > 0 ? avgMood.toStringAsFixed(1) : '—',
                        label: 'Avg Mood',
                        color: const Color(0xFF4ECDC4),
                      ),
                      const SizedBox(width: Spacing.sm),
                      _StatCard(
                        icon: LucideIcons.bookOpen,
                        value: '$totalEntries',
                        label: 'Entries',
                        color: const Color(0xFFFF6B9D),
                      ),
                      const SizedBox(width: Spacing.sm),
                      _StatCard(
                        icon: LucideIcons.flame,
                        value: '${overall?.currentStreak ?? 0}',
                        label: 'Streak',
                        color: const Color(0xFFFF8C42),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: Spacing.md),

                  // ─── Wellness Snapshot ────────────────
                  _WellnessSnapshot(moodState: moodState)
                      .animate()
                      .fadeIn(delay: 130.ms),

                  const SizedBox(height: Spacing.md),

                  // ─── 90-Day Mood Sparkline ────────────
                  _MoodSparklineCard(moodState: moodState)
                      .animate()
                      .fadeIn(delay: 140.ms),

                  const SizedBox(height: Spacing.md),

                  // ─── Profile Data Card ────────────────
                  _ProfileDataCard(user: user, ref: ref)
                      .animate()
                      .fadeIn(delay: 143.ms),

                  const SizedBox(height: Spacing.md),

                  // ─── Maya Personality Card ────────────
                  _MayaPersonalityCard(user: user)
                      .animate()
                      .fadeIn(delay: 145.ms),

                  const SizedBox(height: Spacing.lg),

                  // ─── Recent Achievements ──────────────
                  if (streakState.achievements.isNotEmpty) ...[
                    _RecentAchievements(streakState: streakState)
                        .animate()
                        .fadeIn(delay: 150.ms),
                    const SizedBox(height: Spacing.lg),
                  ],

                  // ─── Settings Sections ────────────────
                  _SettingsSection(
                    title: 'Account',
                    items: [
                      _SettingItem(
                        icon: LucideIcons.circleUser,
                        label: 'Personal Information',
                        color: AppColors.primary,
                        value: user?.name ?? '',
                        onTap: () => _showEditNameSheet(context, ref, user),
                      ),
                      _SettingItem(
                        icon: LucideIcons.graduationCap,
                        label: 'University & Faculty',
                        color: const Color(0xFF4ECDC4),
                        value: user?.university ?? '',
                        onTap: () => _showEditUniversitySheet(context, ref, user),
                      ),
                      _SettingItem(
                        icon: LucideIcons.target,
                        label: 'My Wellness Goals',
                        color: const Color(0xFF06D6A0),
                        value: user?.goals.isEmpty == true ? '' : '${user!.goals.length} selected',
                        onTap: () => _showEditGoalsSheet(context, ref, user),
                      ),
                      _SettingItem(
                        icon: LucideIcons.bolt,
                        label: 'Current Stressors',
                        color: AppColors.secondary,
                        value: user?.stressors.isEmpty == true ? '' : '${user!.stressors.length} selected',
                        onTap: () => _showEditStressorsSheet(context, ref, user),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: Spacing.sm),

                  _SettingsSection(
                    title: 'Preferences',
                    items: [
                      _SettingItem(
                        icon: LucideIcons.bell,
                        label: 'Notification Settings',
                        color: const Color(0xFFFFD166),
                        onTap: () {},
                        trailing: Switch(
                          value: true,
                          onChanged: (_) {},
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _SettingItem(
                        icon: LucideIcons.moon,
                        label: 'Dark Mode',
                        color: AppColors.primaryLight,
                        onTap: () {},
                        trailing: Switch(
                          value: false,
                          onChanged: (_) {},
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _SettingItem(
                        icon: LucideIcons.globe,
                        label: 'Language',
                        color: const Color(0xFFFF6B9D),
                        onTap: () {},
                        value: 'English',
                      ),
                    ],
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: Spacing.sm),

                  _SettingsSection(
                    title: 'Privacy & Security',
                    items: [
                      _SettingItem(
                        icon: LucideIcons.shieldCheck,
                        label: 'Privacy Settings',
                        color: const Color(0xFF4ECDC4),
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.keyRound,
                        label: 'Change Password',
                        color: const Color(0xFFFF8C42),
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.download,
                        label: 'Export My Data',
                        color: AppColors.primary,
                        onTap: () {},
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: Spacing.sm),

                  _SettingsSection(
                    title: 'About MindBridge',
                    items: [
                      _SettingItem(
                        icon: LucideIcons.info,
                        label: 'About',
                        color: AppColors.primary,
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.fileText,
                        label: 'Terms of Service',
                        color: const Color(0xFF4ECDC4),
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.shield,
                        label: 'Privacy Policy',
                        color: const Color(0xFF06D6A0),
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.messageSquare,
                        label: 'Send Feedback',
                        color: const Color(0xFFFFD166),
                        onTap: () {},
                      ),
                    ],
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: Spacing.md),

                  // ─── Sign Out ─────────────────────────
                  _SignOutButton(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.xlAll),
                          title: const Text(
                            'Sign Out?',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          content: const Text(
                            'You will need to sign in again to access your data.',
                            style: TextStyle(height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go(AppRoutes.login);
                      }
                    },
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: Spacing.md),

                  Center(
                    child: Text(
                      'MindBridge v1.0.0 · Made with ❤️ for students',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokenTextMuted,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wellness Snapshot ─────────────────────────────────────

class _WellnessSnapshot extends StatelessWidget {
  final MoodState moodState;
  const _WellnessSnapshot({required this.moodState});

  @override
  Widget build(BuildContext context) {
    // Last 7 mood entries (most recent first → reverse for chart)
    final last7 = moodState.entries.take(7).toList().reversed.toList();
    final breakdown = moodState.wellnessBreakdown;
    final score = breakdown?.totalScore ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingUp, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Wellness Snapshot',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${score.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (last7.isEmpty)
            Container(
              height: 56,
              alignment: Alignment.center,
              child: const Text(
                'Track your mood to see trends here',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: last7.asMap().entries.map((e) {
                final entry = e.value;
                final score = entry.moodScore;
                final color = AppColors.moodColors[(score - 1).clamp(0, 9)];
                final barH = (score / 10 * 56).clamp(8.0, 56.0);
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final dayLabel = days[entry.createdAt.weekday - 1];
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: barH,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayLabel,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            color: AppColors.textMuted,
                          )),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Profile Hero ──────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final UserModel? user;
  const _ProfileHero({this.user});

  @override
  Widget build(BuildContext context) {
    final initials = (user?.displayName ?? 'U').isNotEmpty
        ? (user?.displayName ?? 'U')[0].toUpperCase()
        : 'U';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF4ECDC4)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: Spacing.lg),

            // Avatar with ring
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 2),
                  ),
                ),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), AppColors.primaryContainer],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

            const SizedBox(height: Spacing.md),

            Text(
              user?.name ?? 'Student',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: Spacing.xs),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (user?.university != null || user?.yearLabel.isNotEmpty == true)
                  _HeroPill(
                    icon: LucideIcons.graduationCap,
                    label: [
                      if (user?.yearLabel.isNotEmpty == true) user!.yearLabel,
                      if (user?.university != null) user!.university!,
                    ].join(' · '),
                  ),
                if (user?.faculty != null)
                  _HeroPill(icon: LucideIcons.bookOpen, label: user!.faculty!),
                if (user?.goals.isNotEmpty == true)
                  _HeroPill(
                    icon: LucideIcons.target,
                    label: '${user!.goals.length} goal${user!.goals.length == 1 ? '' : 's'}',
                  ),
              ],
            ).animate().fadeIn(delay: 250.ms),

            const SizedBox(height: Spacing.lg),

            // Wave cutout
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: context.tokenBackground,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Spacing.xl)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: context.tokenSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: Spacing.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.tokenTextMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Achievements ───────────────────────────────────

class _RecentAchievements extends StatelessWidget {
  final StreakAchievementState streakState;

  const _RecentAchievements({required this.streakState});

  @override
  Widget build(BuildContext context) {
    final recent = streakState.achievements.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadow.sm,
        border: Border.all(
            color: const Color(0xFFFFD166).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.award,
                      size: 16, color: Color(0xFFFFD166)),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    'Recent Badges',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.tokenTextPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.1),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  '${streakState.achievements.length} total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFD166),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: recent.map((a) {
              final def = a.definition;
              if (def == null) return const SizedBox.shrink();
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: Spacing.xs),
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: def.category.color.withOpacity(0.08),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                        color: def.category.color.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(def.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 3),
                      Text(
                        def.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: def.category.color,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Section ──────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: Spacing.xs),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.tokenTextMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.tokenSurface,
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: context.tokenBorder),
            boxShadow: AppShadow.sm,
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 64,
                      color: context.tokenBorder,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;
  final String? value;

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.trailing,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: AppRadius.smAll,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: context.tokenTextPrimary,
        ),
      ),
      trailing: trailing ??
          (value != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value!,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.tokenTextMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight,
                        color: context.tokenTextMuted, size: 16),
                  ],
                )
              : Icon(LucideIcons.chevronRight,
                  color: context.tokenTextMuted, size: 16)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 2),
    );
  }
}

// ─── Sign Out Button ───────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.06),
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.logOut, color: AppColors.error, size: 20),
            const SizedBox(width: Spacing.sm),
            const Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Hero Pill ─────────────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─── Profile Data Card ─────────────────────────────────────

class _ProfileDataCard extends StatelessWidget {
  final UserModel? user;
  final WidgetRef ref;
  const _ProfileDataCard({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    final checkInLabels = {'morning': '🌅 Morning', 'afternoon': '☀️ Afternoon', 'evening': '🌙 Evening', 'any': '🔄 Any time'};
    final therapyLabels = {'never': 'First time user', 'apps': 'Used apps before', 'therapy': 'Has/had therapy'};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.userRound, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Your Profile',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Goals
          if (user!.goals.isNotEmpty) ...[
            _DataRow(
              icon: LucideIcons.target,
              label: 'Goals',
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: user!.goals.map((g) => _Chip(g)).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Stressors
          if (user!.stressors.isNotEmpty) ...[
            _DataRow(
              icon: LucideIcons.zap,
              label: 'Stressors',
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: user!.stressors.map((s) => _Chip(s, color: AppColors.secondary)).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Check-in time + therapy experience
          Row(
            children: [
              Expanded(
                child: _DataRow(
                  icon: LucideIcons.clock,
                  label: 'Check-in',
                  child: Text(
                    checkInLabels[user!.checkInTime] ?? user!.checkInTime,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DataRow(
                  icon: LucideIcons.heartHandshake,
                  label: 'Background',
                  child: Text(
                    therapyLabels[user!.therapyExperience] ?? user!.therapyExperience,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _DataRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 5),
          child,
        ],
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip(this.label, {this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: (color ?? AppColors.primary).withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.primary)),
      );
}

// ─── Edit Sheet Functions ──────────────────────────────────

void _showEditNameSheet(BuildContext context, WidgetRef ref, UserModel? user) {
  final ctrl = TextEditingController(text: user?.name ?? '');
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Full Name',
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                await ref.read(authProvider.notifier).updateProfile({'name': ctrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showEditUniversitySheet(BuildContext context, WidgetRef ref, UserModel? user) {
  final uniCtrl = TextEditingController(text: user?.university ?? '');
  String? faculty = user?.faculty;
  const faculties = ['Engineering & Technology', 'Medicine & Health Sciences', 'Business & Economics', 'Arts & Humanities', 'Natural Sciences', 'Law', 'Education', 'Architecture & Design', 'Social Sciences', 'Computer Science', 'Mathematics & Statistics', 'Other'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('University & Faculty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: uniCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'University',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: faculty,
              hint: const Text('Select Faculty'),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: faculties.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => faculty = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  await ref.read(authProvider.notifier).updateProfile({
                    'university': uniCtrl.text.trim().isEmpty ? null : uniCtrl.text.trim(),
                    'faculty': faculty,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEditGoalsSheet(BuildContext context, WidgetRef ref, UserModel? user) {
  const allGoals = [
    {'id': 'anxiety', 'label': 'Manage Anxiety', 'emoji': '😌'},
    {'id': 'depression', 'label': 'Cope with Low Mood', 'emoji': '💙'},
    {'id': 'stress', 'label': 'Academic Stress', 'emoji': '📚'},
    {'id': 'sleep', 'label': 'Better Sleep', 'emoji': '😴'},
    {'id': 'social', 'label': 'Social Confidence', 'emoji': '🤝'},
    {'id': 'motivation', 'label': 'Boost Motivation', 'emoji': '🚀'},
    {'id': 'mindfulness', 'label': 'Mindfulness', 'emoji': '🧘'},
    {'id': 'selfesteem', 'label': 'Self-Esteem', 'emoji': '💪'},
    {'id': 'grief', 'label': 'Process Grief', 'emoji': '🌹'},
    {'id': 'relationships', 'label': 'Relationships', 'emoji': '❤️'},
  ];
  final selected = Set<String>.from(user?.goals ?? []);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            children: [
              const Text('My Wellness Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  controller: ctrl,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.0,
                  children: allGoals.map((g) {
                    final id = g['id'] as String;
                    final active = selected.contains(id);
                    return GestureDetector(
                      onTap: () => setState(() { active ? selected.remove(id) : selected.add(id); }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          Text(g['emoji'] as String, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(g['label'] as String,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: active ? AppColors.primary : AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).updateProfile({'goals': selected.toList()});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Goals'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showEditStressorsSheet(BuildContext context, WidgetRef ref, UserModel? user) {
  const allStressors = [
    {'id': 'exams', 'label': 'Exams & Deadlines', 'emoji': '📝'},
    {'id': 'finances', 'label': 'Financial Pressure', 'emoji': '💰'},
    {'id': 'loneliness', 'label': 'Loneliness', 'emoji': '🌧️'},
    {'id': 'family', 'label': 'Family Issues', 'emoji': '🏠'},
    {'id': 'relationships_stress', 'label': 'Relationship Stress', 'emoji': '💔'},
    {'id': 'career', 'label': 'Career / Future', 'emoji': '🎯'},
    {'id': 'identity', 'label': 'Identity & Purpose', 'emoji': '🔍'},
    {'id': 'health', 'label': 'Physical Health', 'emoji': '🏥'},
    {'id': 'performance', 'label': 'Performance Anxiety', 'emoji': '😰'},
    {'id': 'time', 'label': 'Time Management', 'emoji': '⏰'},
  ];
  final selected = Set<String>.from(user?.stressors ?? []);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            children: [
              const Text('Current Stressors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text("What's weighing on you right now?",
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  controller: ctrl,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.0,
                  children: allStressors.map((s) {
                    final id = s['id'] as String;
                    final active = selected.contains(id);
                    return GestureDetector(
                      onTap: () => setState(() { active ? selected.remove(id) : selected.add(id); }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: active ? AppColors.secondary.withValues(alpha: 0.10) : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AppColors.secondary : AppColors.border, width: active ? 1.5 : 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          Text(s['emoji'] as String, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s['label'] as String,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: active ? AppColors.secondary : AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).updateProfile({'stressors': selected.toList()});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Stressors'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── 90-Day Mood Sparkline Card ────────────────────────────────────────────────

class _MoodSparklineCard extends StatelessWidget {
  final MoodState moodState;
  const _MoodSparklineCard({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final entries = moodState.entries.take(90).toList().reversed.toList();
    final hasData = entries.isNotEmpty;

    // Compute 7-day blocks for bar chart
    final List<double> weeklyAvgs = [];
    for (var week = 0; week < 13; week++) {
      final start = week * 7;
      final end = start + 7;
      if (start >= entries.length) break;
      final slice = entries.sublist(start, end.clamp(0, entries.length));
      if (slice.isEmpty) continue;
      final avg = slice.map((e) => e.moodScore.toDouble()).reduce((a, b) => a + b) / slice.length;
      weeklyAvgs.add(avg);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.trendingUp, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
            const Expanded(child: Text('90-Day Mood Trend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            if (hasData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Avg ${moodState.averageMood.toStringAsFixed(1)}/10',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Log moods to see your trend', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
            )
          else
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weeklyAvgs.asMap().entries.map((e) {
                  final pct = (e.value / 10).clamp(0.1, 1.0);
                  final isRecent = e.key == weeklyAvgs.length - 1;
                  final color = e.value >= 7 ? const Color(0xFF06D6A0) : e.value >= 5 ? AppColors.primary : const Color(0xFFFF6B6B);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 300 + e.key * 40),
                            curve: Curves.easeOutCubic,
                            height: 60 * pct,
                            decoration: BoxDecoration(
                              color: isRecent ? color : color.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (hasData) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${entries.length} days ago', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              Text('Today', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Maya Personality Card ────────────────────────────────────────────────────

class _MayaPersonalityCard extends ConsumerWidget {
  final UserModel? user;
  const _MayaPersonalityCard({required this.user});

  static const _personalities = [
    {'id': 'warm', 'emoji': '🤗', 'label': 'Warm & Supportive', 'sub': 'Gentle, empathetic validation'},
    {'id': 'direct', 'emoji': '🎯', 'label': 'Direct & Practical', 'sub': 'Concise, solution-focused'},
    {'id': 'playful', 'emoji': '✨', 'label': 'Playful & Light', 'sub': 'Casual, uses gentle humour'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = user?.mayaPersonality ?? 'warm';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.bot, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Maya's Style", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Tap to change how Maya talks to you', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          Row(
            children: _personalities.map((p) {
              final isActive = current == p['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (isActive) return;
                    await ref.read(authProvider.notifier).updateProfile(
                      {'maya_personality': p['id']},
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? AppColors.primary : AppColors.border, width: isActive ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Text(p['emoji']!, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(p['label']!.split('&').first.trim(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: isActive ? AppColors.primary : AppColors.textSecondary),
                            textAlign: TextAlign.center),
                        if (isActive)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
