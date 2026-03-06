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
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.graduationCap,
                        label: 'University Settings',
                        color: const Color(0xFF4ECDC4),
                        onTap: () {},
                      ),
                      _SettingItem(
                        icon: LucideIcons.target,
                        label: 'My Wellness Goals',
                        color: const Color(0xFF06D6A0),
                        onTap: () {},
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

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.graduationCap,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    user?.university ?? 'University Student',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
