import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/design_tokens.dart';

// ─── Profile Preferences (persisted via SharedPreferences) ──

class _ProfilePrefs {
  final bool notifications;
  final bool darkMode;
  final String language;
  const _ProfilePrefs({
    this.notifications = true,
    this.darkMode = false,
    this.language = 'English',
  });
  _ProfilePrefs copyWith({bool? notifications, bool? darkMode, String? language}) =>
      _ProfilePrefs(
        notifications: notifications ?? this.notifications,
        darkMode: darkMode ?? this.darkMode,
        language: language ?? this.language,
      );
}

class _ProfilePrefsNotifier extends StateNotifier<_ProfilePrefs> {
  _ProfilePrefsNotifier() : super(const _ProfilePrefs()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = _ProfilePrefs(
      notifications: p.getBool('pref_notifications') ?? true,
      darkMode: p.getBool('pref_dark_mode') ?? false,
      language: p.getString('pref_language') ?? 'English',
    );
  }

  Future<void> setNotifications(bool v) async {
    state = state.copyWith(notifications: v);
    (await SharedPreferences.getInstance()).setBool('pref_notifications', v);
  }

  Future<void> setDarkMode(bool v) async {
    state = state.copyWith(darkMode: v);
    (await SharedPreferences.getInstance()).setBool('pref_dark_mode', v);
  }

  Future<void> setLanguage(String v) async {
    state = state.copyWith(language: v);
    (await SharedPreferences.getInstance()).setString('pref_language', v);
  }
}

final _profilePrefsProvider =
    StateNotifierProvider<_ProfilePrefsNotifier, _ProfilePrefs>(
  (ref) => _ProfilePrefsNotifier(),
);

// ─── Profile Completeness ──────────────────────────────────

int _completenessScore(UserModel user) {
  int score = 20; // name + email always filled
  if (user.preferredName != null && user.preferredName!.isNotEmpty) score += 5;
  if (user.university != null && user.university!.isNotEmpty) score += 15;
  if (user.faculty != null && user.faculty!.isNotEmpty) score += 10;
  if (user.yearOfStudy != null) score += 10;
  if (user.goals.isNotEmpty) score += 15;
  if (user.stressors.isNotEmpty) score += 10;
  if (user.checkInTime != 'any') score += 5;
  if (user.therapyExperience != 'never') score += 5;
  if (user.mayaPersonality != 'warm') score += 5;
  return score.clamp(0, 100);
}

List<_MissingField> _missingFields(UserModel user) {
  final missing = <_MissingField>[];
  if (user.university == null || user.university!.isEmpty) {
    missing.add(_MissingField('University', LucideIcons.graduationCap));
  }
  if (user.faculty == null || user.faculty!.isEmpty) {
    missing.add(_MissingField('Faculty', LucideIcons.bookOpen));
  }
  if (user.yearOfStudy == null) {
    missing.add(_MissingField('Year of Study', LucideIcons.calendarDays));
  }
  if (user.goals.isEmpty) {
    missing.add(_MissingField('Wellness Goals', LucideIcons.target));
  }
  if (user.stressors.isEmpty) {
    missing.add(_MissingField('Current Stressors', LucideIcons.zap));
  }
  if (user.preferredName == null || user.preferredName!.isEmpty) {
    missing.add(_MissingField('Preferred Name', LucideIcons.circleUser));
  }
  return missing;
}

class _MissingField {
  final String label;
  final IconData icon;
  const _MissingField(this.label, this.icon);
}

// ─── Screen ───────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final streakState = ref.watch(streakProvider);
    final moodState = ref.watch(moodProvider);
    final prefs = ref.watch(_profilePrefsProvider);

    final overall = streakState.overall;
    final avgMood = moodState.entries.isEmpty
        ? 0.0
        : moodState.entries
                .take(30)
                .map((e) => e.moodScore)
                .fold(0, (a, b) => a + b) /
            moodState.entries.take(30).length;
    final totalEntries = moodState.entries.length;
    final completeness = user != null ? _completenessScore(user) : 0;
    final missing = user != null ? _missingFields(user) : <_MissingField>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.tokenBackground,
        body: CustomScrollView(
          slivers: [
            // ─── Hero Header ────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHero(user: user, ref: ref),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Completeness Banner ──────────────
                  if (completeness < 100 && user != null) ...[
                    _ProfileCompletenessCard(
                      user: user,
                      completeness: completeness,
                      missing: missing,
                      ref: ref,
                    ).animate().fadeIn(delay: 80.ms).slideY(begin: -0.05),
                    const SizedBox(height: Spacing.md),
                  ],

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

                  const SizedBox(height: Spacing.xl),

                  // ─── Personal Information ─────────────
                  _SectionHeader(icon: LucideIcons.circleUser, title: 'Personal Information')
                      .animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: Spacing.sm),
                  _PersonalInfoCard(user: user, ref: ref)
                      .animate().fadeIn(delay: 160.ms),

                  const SizedBox(height: Spacing.lg),

                  // ─── Academic ─────────────────────────
                  _SectionHeader(icon: LucideIcons.graduationCap, title: 'Academic')
                      .animate().fadeIn(delay: 170.ms),
                  const SizedBox(height: Spacing.sm),
                  _AcademicCard(user: user, ref: ref)
                      .animate().fadeIn(delay: 180.ms),

                  const SizedBox(height: Spacing.lg),

                  // ─── Wellness Profile ─────────────────
                  _SectionHeader(icon: LucideIcons.sparkles, title: 'Wellness Profile')
                      .animate().fadeIn(delay: 190.ms),
                  const SizedBox(height: Spacing.sm),
                  _WellnessProfileCard(user: user, ref: ref)
                      .animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: Spacing.lg),

                  // ─── Maya Personality ─────────────────
                  _MayaPersonalityCard(user: user)
                      .animate()
                      .fadeIn(delay: 210.ms),

                  const SizedBox(height: Spacing.lg),

                  // ─── Recent Achievements ──────────────
                  if (streakState.achievements.isNotEmpty) ...[
                    _RecentAchievements(streakState: streakState)
                        .animate()
                        .fadeIn(delay: 220.ms),
                    const SizedBox(height: Spacing.lg),
                  ],

                  // ─── Settings Sections ────────────────
                  _SettingsSection(
                    title: 'Preferences',
                    items: [
                      _SettingItem(
                        icon: LucideIcons.bell,
                        label: 'Notification Reminders',
                        color: const Color(0xFFFFD166),
                        onTap: () => ref
                            .read(_profilePrefsProvider.notifier)
                            .setNotifications(!prefs.notifications),
                        trailing: Switch(
                          value: prefs.notifications,
                          onChanged: (v) => ref
                              .read(_profilePrefsProvider.notifier)
                              .setNotifications(v),
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _SettingItem(
                        icon: LucideIcons.moon,
                        label: 'Dark Mode',
                        color: AppColors.primaryLight,
                        onTap: () => ref
                            .read(_profilePrefsProvider.notifier)
                            .setDarkMode(!prefs.darkMode),
                        trailing: Switch(
                          value: prefs.darkMode,
                          onChanged: (v) => ref
                              .read(_profilePrefsProvider.notifier)
                              .setDarkMode(v),
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _SettingItem(
                        icon: LucideIcons.globe,
                        label: 'Language',
                        color: const Color(0xFFFF6B9D),
                        onTap: () => _showLanguageSheet(context, ref),
                        value: prefs.language,
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
                        onTap: () => _showPrivacySettingsSheet(context, ref),
                      ),
                      _SettingItem(
                        icon: LucideIcons.keyRound,
                        label: 'Change Password',
                        color: const Color(0xFFFF8C42),
                        onTap: () => _showChangePasswordSheet(context, ref),
                      ),
                      _SettingItem(
                        icon: LucideIcons.download,
                        label: 'Export My Data',
                        color: AppColors.primary,
                        onTap: () => _showExportDataSheet(context, ref),
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
                        onTap: () => _showAboutSheet(context),
                      ),
                      _SettingItem(
                        icon: LucideIcons.fileText,
                        label: 'Terms of Service',
                        color: const Color(0xFF4ECDC4),
                        onTap: () => _showTermsSheet(context),
                      ),
                      _SettingItem(
                        icon: LucideIcons.shield,
                        label: 'Privacy Policy',
                        color: const Color(0xFF06D6A0),
                        onTap: () => _showPrivacyPolicySheet(context),
                      ),
                      _SettingItem(
                        icon: LucideIcons.messageSquare,
                        label: 'Send Feedback',
                        color: const Color(0xFFFFD166),
                        onTap: () => _showFeedbackSheet(context, ref),
                      ),
                    ],
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: Spacing.md),

                  // ─── Sign Out ─────────────────────────
                  _SignOutButton(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
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
                                  Navigator.pop(dialogCtx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogCtx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authProvider.notifier).logout();
                        // GoRouter redirect handles /login automatically
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

// ─── Section Header ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
}

// ─── Profile Completeness Card ──────────────────────────────

class _ProfileCompletenessCard extends StatelessWidget {
  final UserModel user;
  final int completeness;
  final List<_MissingField> missing;
  final WidgetRef ref;

  const _ProfileCompletenessCard({
    required this.user,
    required this.completeness,
    required this.missing,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final color = completeness >= 70
        ? AppColors.primary
        : completeness >= 40
            ? const Color(0xFFF59E0B)
            : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(LucideIcons.userCheck, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completeness < 40
                          ? 'Complete your profile'
                          : completeness < 70
                              ? 'Almost there!'
                              : 'Looking good!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '$completeness% complete · ${missing.length} field${missing.length == 1 ? '' : 's'} remaining',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completeness / 100,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 7,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing.map((f) => _MissingChip(f)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  final _MissingField field;
  const _MissingChip(this.field);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(field.icon, size: 10, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              field.label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted),
            ),
          ],
        ),
      );
}

// ─── Personal Info Card ─────────────────────────────────────

class _PersonalInfoCard extends StatelessWidget {
  final UserModel? user;
  final WidgetRef ref;
  const _PersonalInfoCard({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      children: [
        _EditableRow(
          icon: LucideIcons.user,
          label: 'Full Name',
          value: user?.name ?? '—',
          onTap: () => _showEditPersonalSheet(context, ref, user),
        ),
        _cardDivider(context),
        _EditableRow(
          icon: LucideIcons.smile,
          label: 'Preferred Name',
          value: (user?.preferredName != null && user!.preferredName!.isNotEmpty)
              ? user!.preferredName!
              : null,
          placeholder: 'Tap to add',
          onTap: () => _showEditPersonalSheet(context, ref, user),
        ),
        _cardDivider(context),
        _ReadOnlyRow(
          icon: LucideIcons.mail,
          label: 'Email',
          value: user?.email ?? '—',
        ),
      ],
    );
  }
}

// ─── Academic Card ──────────────────────────────────────────

class _AcademicCard extends StatelessWidget {
  final UserModel? user;
  final WidgetRef ref;
  const _AcademicCard({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final yearLabels = {
      1: '1st Year (Freshman)',
      2: '2nd Year (Sophomore)',
      3: '3rd Year (Junior)',
      4: '4th Year (Senior)',
      5: '5th Year',
      6: 'Graduate Student',
    };

    return _ProfileCard(
      children: [
        _EditableRow(
          icon: LucideIcons.graduationCap,
          label: 'University',
          value: user?.university,
          placeholder: 'Tap to add',
          onTap: () => _showEditAcademicSheet(context, ref, user),
        ),
        _cardDivider(context),
        _EditableRow(
          icon: LucideIcons.bookOpen,
          label: 'Faculty / Programme',
          value: user?.faculty,
          placeholder: 'Tap to add',
          onTap: () => _showEditAcademicSheet(context, ref, user),
        ),
        _cardDivider(context),
        _EditableRow(
          icon: LucideIcons.calendarDays,
          label: 'Year of Study',
          value: user?.yearOfStudy != null
              ? yearLabels[user!.yearOfStudy] ?? '${user!.yearOfStudy}th Year'
              : null,
          placeholder: 'Tap to add',
          onTap: () => _showEditAcademicSheet(context, ref, user),
        ),
      ],
    );
  }
}

// ─── Wellness Profile Card ──────────────────────────────────

class _WellnessProfileCard extends StatelessWidget {
  final UserModel? user;
  final WidgetRef ref;
  const _WellnessProfileCard({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final checkInLabels = {
      'morning': '🌅 Morning (7–9am)',
      'afternoon': '☀️ Afternoon (12–2pm)',
      'evening': '🌙 Evening (7–9pm)',
      'any': '🔄 Any time',
    };
    final therapyLabels = {
      'never': 'First time using an app like this',
      'apps': 'Used wellness apps before',
      'therapy': 'Has / had professional therapy',
    };

    return _ProfileCard(
      children: [
        // Goals row — shows chips inline
        _EditableChipRow(
          icon: LucideIcons.target,
          label: 'Wellness Goals',
          items: user?.goals ?? [],
          chipColor: AppColors.primary,
          placeholder: 'Tap to set goals',
          onTap: () => _showEditGoalsSheet(context, ref, user),
        ),
        _cardDivider(context),
        // Stressors row
        _EditableChipRow(
          icon: LucideIcons.zap,
          label: 'Current Stressors',
          items: user?.stressors ?? [],
          chipColor: AppColors.secondary,
          placeholder: 'Tap to add stressors',
          onTap: () => _showEditStressorsSheet(context, ref, user),
        ),
        _cardDivider(context),
        _EditableRow(
          icon: LucideIcons.clock,
          label: 'Check-in Time',
          value: checkInLabels[user?.checkInTime ?? 'any'],
          onTap: () => _showEditCheckInSheet(context, ref, user),
        ),
        _cardDivider(context),
        _EditableRow(
          icon: LucideIcons.heartHandshake,
          label: 'Therapy Background',
          value: therapyLabels[user?.therapyExperience ?? 'never'],
          onTap: () => _showEditTherapySheet(context, ref, user),
        ),
      ],
    );
  }
}

// ─── Card Container ─────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfileCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.tokenSurface,
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: context.tokenBorder),
          boxShadow: AppShadow.sm,
        ),
        child: Column(children: children),
      );
}

Widget _cardDivider(BuildContext context) =>
    Divider(height: 1, indent: 52, color: context.tokenBorder);

// ─── Editable Row ───────────────────────────────────────────

class _EditableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback onTap;

  const _EditableRow({
    required this.icon,
    required this.label,
    this.value,
    this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xlAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm + 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tokenTextMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : (placeholder ?? '—'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasValue
                          ? context.tokenTextPrimary
                          : context.tokenTextMuted,
                      fontStyle:
                          hasValue ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.pencil,
              size: 14,
              color: context.tokenTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Read-Only Row ──────────────────────────────────────────

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.08),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 16, color: AppColors.textMuted),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.tokenTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.tokenTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.08),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              'Fixed',
              style: TextStyle(
                  fontSize: 10,
                  color: context.tokenTextMuted,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Editable Chip Row ──────────────────────────────────────

class _EditableChipRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> items;
  final Color chipColor;
  final String placeholder;
  final VoidCallback onTap;

  const _EditableChipRow({
    required this.icon,
    required this.label,
    required this.items,
    required this.chipColor,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xlAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.08),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, size: 16, color: chipColor),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tokenTextMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (items.isEmpty)
                    Text(
                      placeholder,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: context.tokenTextMuted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: items
                          .take(5)
                          .map((g) => _MiniChip(g, color: chipColor))
                          .toList()
                        ..addAll(items.length > 5
                            ? [
                                _MiniChip('+${items.length - 5} more',
                                    color: AppColors.textMuted)
                              ]
                            : []),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.pencil,
                  size: 14, color: context.tokenTextMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

// ─── Wellness Snapshot ─────────────────────────────────────────

class _WellnessSnapshot extends StatelessWidget {
  final MoodState moodState;
  const _WellnessSnapshot({required this.moodState});

  @override
  Widget build(BuildContext context) {
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
                final s = entry.moodScore;
                final color = AppColors.moodColors[(s - 1).clamp(0, 9)];
                final barH = (s / 10 * 56).clamp(8.0, 56.0);
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final dayLabel = days[entry.createdAt.weekday - 1];
                return Expanded(
                  child: Column(
                    children: [
                      Text('$s',
                          style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color)),
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
                              color: AppColors.textMuted)),
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

// ─── Profile Hero ──────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final UserModel? user;
  final WidgetRef ref;
  const _ProfileHero({this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initials = (user?.displayName ?? 'U').isNotEmpty
        ? (user?.displayName ?? 'U')[0].toUpperCase()
        : 'U';
    final completeness = user != null ? _completenessScore(user!) : 0;

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

            // Avatar with completeness ring
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer completeness ring
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: completeness / 100,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    strokeCap: StrokeCap.round,
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

            const SizedBox(height: 6),
            // Completeness % under avatar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$completeness% complete',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: Spacing.sm),

            Text(
              user?.name ?? 'Student',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 150.ms),

            if (user?.preferredName != null &&
                user!.preferredName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '"${user!.preferredName}"',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),

            const SizedBox(height: Spacing.xs),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (user?.university != null ||
                    user?.yearLabel.isNotEmpty == true)
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
                    label:
                        '${user!.goals.length} goal${user!.goals.length == 1 ? '' : 's'}',
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
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.award, size: 16, color: Color(0xFFFFD166)),
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
                      Text(def.emoji, style: const TextStyle(fontSize: 24)),
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
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
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

// ─── Maya Personality Card ─────────────────────────────────

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
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.bot, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Maya's Style", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Tap a card to change how Maya talks to you', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                      color: isActive ? AppColors.primary.withOpacity(0.10) : AppColors.surfaceVariant,
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

// ─── 90-Day Mood Sparkline Card ────────────────────────────

class _MoodSparklineCard extends StatelessWidget {
  final MoodState moodState;
  const _MoodSparklineCard({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final entries = moodState.entries.take(90).toList().reversed.toList();
    final hasData = entries.isNotEmpty;

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

// ═══════════════════════════════════════════════════════════
// EDIT SHEETS
// ═══════════════════════════════════════════════════════════

// ─── Sheet Header Drag Handle ──────────────────────────────

Widget _sheetHandle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

// ─── Sheet Save Button ─────────────────────────────────────

Widget _saveButton({
  required BuildContext context,
  required String label,
  required Color color,
  required VoidCallback onPressed,
}) =>
    SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );

// ─── Edit Personal Info Sheet ──────────────────────────────

void _showEditPersonalSheet(BuildContext context, WidgetRef ref, UserModel? user) {
  final nameCtrl = TextEditingController(text: user?.name ?? '');
  final preferredCtrl = TextEditingController(text: user?.preferredName ?? '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.circleUser, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Text('Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          const Text('This is how you appear across MindBridge.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          _sheetTextField(
            controller: nameCtrl,
            label: 'Full Name',
            hint: 'Your legal or full name',
            icon: LucideIcons.user,
          ),
          const SizedBox(height: 12),
          _sheetTextField(
            controller: preferredCtrl,
            label: 'Preferred Name (optional)',
            hint: 'What Maya should call you',
            icon: LucideIcons.smile,
          ),
          const SizedBox(height: 6),
          const Text(
            '💡 Maya will use your preferred name in conversations.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _saveButton(
            context: ctx,
            label: 'Save Changes',
            color: AppColors.primary,
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(authProvider.notifier).updateProfile({
                'name': nameCtrl.text.trim(),
                'preferred_name': preferredCtrl.text.trim().isEmpty
                    ? null
                    : preferredCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

// ─── Edit Academic Sheet ───────────────────────────────────

void _showEditAcademicSheet(BuildContext context, WidgetRef ref, UserModel? user) {
  final uniCtrl = TextEditingController(text: user?.university ?? '');
  String? faculty = user?.faculty;
  int? yearOfStudy = user?.yearOfStudy;

  const faculties = [
    'Engineering & Technology',
    'Medicine & Health Sciences',
    'Business & Economics',
    'Arts & Humanities',
    'Natural Sciences',
    'Law',
    'Education',
    'Architecture & Design',
    'Social Sciences',
    'Computer Science',
    'Mathematics & Statistics',
    'Other',
  ];

  const years = [
    {'value': 1, 'label': '1st Year (Freshman)'},
    {'value': 2, 'label': '2nd Year (Sophomore)'},
    {'value': 3, 'label': '3rd Year (Junior)'},
    {'value': 4, 'label': '4th Year (Senior)'},
    {'value': 5, 'label': '5th Year'},
    {'value': 6, 'label': 'Graduate Student'},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.graduationCap, size: 16, color: Color(0xFF4ECDC4)),
                ),
                const SizedBox(width: 10),
                const Text('Academic Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 20),
              _sheetTextField(
                controller: uniCtrl,
                label: 'University / College',
                hint: 'e.g. University of Nairobi',
                icon: LucideIcons.building2,
              ),
              const SizedBox(height: 12),
              // Faculty dropdown
              DropdownButtonFormField<String>(
                value: faculty,
                hint: const Text('Select Faculty / Programme', style: TextStyle(fontSize: 14)),
                decoration: InputDecoration(
                  labelText: 'Faculty',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: faculties
                    .map((f) => DropdownMenuItem(
                        value: f, child: Text(f, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => faculty = v),
              ),
              const SizedBox(height: 12),
              // Year of study
              const Text('Year of Study',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: years.map((y) {
                  final val = y['value'] as int;
                  final isSelected = yearOfStudy == val;
                  return GestureDetector(
                    onTap: () => setState(() => yearOfStudy = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.12)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        y['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _saveButton(
                context: ctx,
                label: 'Save Academic Details',
                color: const Color(0xFF4ECDC4),
                onPressed: () async {
                  await ref.read(authProvider.notifier).updateProfile({
                    'university': uniCtrl.text.trim().isEmpty
                        ? null
                        : uniCtrl.text.trim(),
                    'faculty': faculty,
                    'year_of_study': yearOfStudy,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Edit Goals Sheet ──────────────────────────────────────

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
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              _sheetHandle(),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.target, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Wellness Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('Select all that apply — Maya will personalise her support.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  controller: ctrl,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.2,
                  children: allGoals.map((g) {
                    final id = g['id'] as String;
                    final active = selected.contains(id);
                    return GestureDetector(
                      onTap: () => setState(() {
                        active ? selected.remove(id) : selected.add(id);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active ? AppColors.primary : AppColors.border,
                              width: active ? 1.5 : 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          Text(g['emoji'] as String,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              g['label'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _saveButton(
                context: ctx,
                label: 'Save Goals${selected.isNotEmpty ? ' (${selected.length})' : ''}',
                color: AppColors.primary,
                onPressed: () async {
                  await ref.read(authProvider.notifier).updateProfile(
                      {'goals': selected.toList()});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Edit Stressors Sheet ──────────────────────────────────

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
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              _sheetHandle(),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(LucideIcons.zap, size: 16, color: AppColors.secondary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Current Stressors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text("What's weighing on you? Maya will be more attuned.",
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  controller: ctrl,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.2,
                  children: allStressors.map((s) {
                    final id = s['id'] as String;
                    final active = selected.contains(id);
                    return GestureDetector(
                      onTap: () => setState(() {
                        active ? selected.remove(id) : selected.add(id);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.secondary.withOpacity(0.10)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active ? AppColors.secondary : AppColors.border,
                              width: active ? 1.5 : 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          Text(s['emoji'] as String,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s['label'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? AppColors.secondary
                                      : AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _saveButton(
                context: ctx,
                label: 'Save Stressors${selected.isNotEmpty ? ' (${selected.length})' : ''}',
                color: AppColors.secondary,
                onPressed: () async {
                  await ref.read(authProvider.notifier).updateProfile(
                      {'stressors': selected.toList()});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Edit Check-in Time Sheet ──────────────────────────────

void _showEditCheckInSheet(BuildContext context, WidgetRef ref, UserModel? user) {
  const options = [
    {
      'id': 'morning',
      'emoji': '🌅',
      'label': 'Morning',
      'sub': 'Start the day grounded (7–9am)',
    },
    {
      'id': 'afternoon',
      'emoji': '☀️',
      'label': 'Afternoon',
      'sub': 'Mid-day reflection (12–2pm)',
    },
    {
      'id': 'evening',
      'emoji': '🌙',
      'label': 'Evening',
      'sub': 'Wind down & reflect (7–9pm)',
    },
    {
      'id': 'any',
      'emoji': '🔄',
      'label': 'Any Time',
      'sub': "Maya adapts to when you're active",
    },
  ];

  String selected = user?.checkInTime ?? 'any';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD166).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.clock, size: 16, color: Color(0xFFFFD166)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Preferred Check-in Time',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Maya will send reminders at this time.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            ...options.map((opt) {
              final id = opt['id'] as String;
              final isSelected = selected == id;
              return GestureDetector(
                onTap: () => setState(() => selected = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.08)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Text(opt['emoji'] as String,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(opt['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            )),
                        Text(opt['sub'] as String,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ]),
                    ),
                    if (isSelected)
                      const Icon(LucideIcons.circleCheck,
                          size: 20, color: AppColors.primary),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            _saveButton(
              context: ctx,
              label: 'Save Preference',
              color: AppColors.primary,
              onPressed: () async {
                await ref.read(authProvider.notifier).updateProfile(
                    {'check_in_time': selected});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Edit Therapy Background Sheet ────────────────────────

void _showEditTherapySheet(BuildContext context, WidgetRef ref, UserModel? user) {
  const options = [
    {
      'id': 'never',
      'emoji': '🌱',
      'label': 'Brand New to This',
      'sub': "First time using a mental wellness app — welcome!",
    },
    {
      'id': 'apps',
      'emoji': '📱',
      'label': 'Used Apps Before',
      'sub': 'You have tried wellness or meditation apps.',
    },
    {
      'id': 'therapy',
      'emoji': '🤝',
      'label': 'Therapy / Counselling',
      'sub': 'You have worked with a professional therapist.',
    },
  ];

  String selected = user?.therapyExperience ?? 'never';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF06D6A0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.heartHandshake, size: 16, color: Color(0xFF06D6A0)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Therapy Background',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Helps Maya calibrate her support style.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            ...options.map((opt) {
              final id = opt['id'] as String;
              final isSelected = selected == id;
              return GestureDetector(
                onTap: () => setState(() => selected = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF06D6A0).withOpacity(0.08)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF06D6A0)
                            : AppColors.border,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Text(opt['emoji'] as String,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(opt['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? const Color(0xFF06D6A0)
                                  : AppColors.textPrimary,
                            )),
                        Text(opt['sub'] as String,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ]),
                    ),
                    if (isSelected)
                      const Icon(LucideIcons.circleCheck,
                          size: 20, color: Color(0xFF06D6A0)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            _saveButton(
              context: ctx,
              label: 'Save',
              color: const Color(0xFF06D6A0),
              onPressed: () async {
                await ref.read(authProvider.notifier).updateProfile(
                    {'therapy_experience': selected});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Change Password Sheet ─────────────────────────────────

void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF8C42).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.keyRound, size: 16, color: Color(0xFFFF8C42)),
            ),
            const SizedBox(width: 10),
            const Text('Change Password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(LucideIcons.info, size: 14, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A password reset link will be sent to your registered email address.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryDark,
                      height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _saveButton(
            context: ctx,
            label: 'Send Reset Link',
            color: const Color(0xFFFF8C42),
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user != null) {
                try {
                  await SupabaseService.sendPasswordReset(user.email);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reset link sent to ${user.email}'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}

// ─── Shared Sheet TextField ────────────────────────────────

Widget _sheetTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  bool autofocus = false,
  TextInputType keyboardType = TextInputType.text,
}) =>
    TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

// ─── Language Sheet ────────────────────────────────────────

void _showLanguageSheet(BuildContext context, WidgetRef ref) {
  const languages = [
    {'code': 'English', 'flag': '🇺🇸', 'label': 'English'},
    {'code': 'Swahili', 'flag': '🇰🇪', 'label': 'Kiswahili'},
    {'code': 'French', 'flag': '🇫🇷', 'label': 'Français'},
    {'code': 'Arabic', 'flag': '🇸🇦', 'label': 'العربية'},
    {'code': 'Spanish', 'flag': '🇪🇸', 'label': 'Español'},
  ];

  final current = ref.read(_profilePrefsProvider).language;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.globe, size: 16, color: Color(0xFFFF6B9D)),
            ),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('App language (full support coming soon)',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ]),
          const SizedBox(height: 20),
          ...languages.map((lang) {
            final isSelected = current == lang['code'];
            final isAvailable = lang['code'] == 'English';
            return GestureDetector(
              onTap: isAvailable
                  ? () async {
                      await ref
                          .read(_profilePrefsProvider.notifier)
                          .setLanguage(lang['code']!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.08)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang['label']!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Soon',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted,
                              fontWeight: FontWeight.w600)),
                    )
                  else if (isSelected)
                    const Icon(LucideIcons.circleCheck, size: 20, color: AppColors.primary),
                ]),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

// ─── Privacy Settings Sheet ────────────────────────────────

void _showPrivacySettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PrivacySettingsSheet(),
  );
}

class _PrivacySettingsSheet extends StatefulWidget {
  @override
  State<_PrivacySettingsSheet> createState() => _PrivacySettingsSheetState();
}

class _PrivacySettingsSheetState extends State<_PrivacySettingsSheet> {
  bool _anonCommunity = true;
  bool _shareInsights = true;
  bool _showStreak = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _anonCommunity = p.getBool('priv_anon_community') ?? true;
        _shareInsights = p.getBool('priv_share_insights') ?? true;
        _showStreak = p.getBool('priv_show_streak') ?? true;
      });
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('priv_anon_community', _anonCommunity);
    await p.setBool('priv_share_insights', _shareInsights);
    await p.setBool('priv_show_streak', _showStreak);
  }

  Widget _toggle(String label, String sub, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3)),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF4ECDC4)),
            ),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Privacy Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('Control how your data is used', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ]),
          const SizedBox(height: 20),
          _toggle(
            'Post Anonymously by Default',
            'Your name won\'t be shown when you post in the community.',
            _anonCommunity,
            (v) => setState(() => _anonCommunity = v),
          ),
          _toggle(
            'Share Insights with Maya',
            'Allow Maya to use your mood trends to personalize conversations.',
            _shareInsights,
            (v) => setState(() => _shareInsights = v),
          ),
          _toggle(
            'Show Streak on Community Posts',
            'Display your streak badge when you interact in the community.',
            _showStreak,
            (v) => setState(() => _showStreak = v),
          ),
          const SizedBox(height: 8),
          _saveButton(
            context: context,
            label: 'Save Privacy Settings',
            color: const Color(0xFF4ECDC4),
            onPressed: () async {
              await _save();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Export My Data Sheet ──────────────────────────────────

void _showExportDataSheet(BuildContext context, WidgetRef ref) {
  final user = ref.read(currentUserProvider);
  final moodState = ref.read(moodProvider);
  final streakState = ref.read(streakProvider);

  final buffer = StringBuffer();
  buffer.writeln('MindBridge Data Export');
  buffer.writeln('Generated: ${DateTime.now().toLocal().toString().split('.').first}');
  buffer.writeln('──────────────────────────────────');
  buffer.writeln('PROFILE');
  buffer.writeln('Name: ${user?.name ?? '—'}');
  buffer.writeln('Email: ${user?.email ?? '—'}');
  buffer.writeln('University: ${user?.university ?? '—'}');
  buffer.writeln('Faculty: ${user?.faculty ?? '—'}');
  buffer.writeln('Year: ${user?.yearLabel ?? '—'}');
  buffer.writeln();
  buffer.writeln('WELLNESS');
  buffer.writeln('Goals: ${user?.goals.join(', ') ?? '—'}');
  buffer.writeln('Stressors: ${user?.stressors.join(', ') ?? '—'}');
  buffer.writeln('Check-in preference: ${user?.checkInTime ?? 'any'}');
  buffer.writeln();
  buffer.writeln('STATS');
  buffer.writeln('Mood entries: ${moodState.entries.length}');
  buffer.writeln(
      'Average mood (30d): ${moodState.entries.isEmpty ? '—' : (moodState.entries.take(30).map((e) => e.moodScore).reduce((a, b) => a + b) / moodState.entries.take(30).length).toStringAsFixed(1)}/10');
  buffer.writeln('Current streak: ${streakState.overall?.currentStreak ?? 0} days');
  buffer.writeln('Total days tracked: ${streakState.overall?.totalDays ?? 0}');
  buffer.writeln('Achievements: ${streakState.achievements.length}');

  final exportText = buffer.toString();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.download, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('A summary of your MindBridge data', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: Text(
                    exportText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _saveButton(
              context: ctx,
              label: 'Copy to Clipboard',
              color: AppColors.primary,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: exportText));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Data copied to clipboard'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── About MindBridge Sheet ────────────────────────────────

void _showAboutSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Icon(LucideIcons.brain, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text('MindBridge',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Version 1.0.0',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(height: 16),
          const Text(
            'MindBridge is a mental wellness companion built for university students. It combines AI-powered support, mood tracking, community connection, and evidence-based mindfulness tools — all in one place.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AboutPill(icon: LucideIcons.bot, label: 'Maya AI'),
            _AboutPill(icon: LucideIcons.users, label: 'Community'),
            _AboutPill(icon: LucideIcons.trendingUp, label: 'Insights'),
          ]),
          const SizedBox(height: 20),
          const Text(
            'Made with ❤️ for students, by students.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _AboutPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AboutPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      );
}

// ─── Terms of Service Sheet ────────────────────────────────

void _showTermsSheet(BuildContext context) {
  _showLegalSheet(
    context,
    title: 'Terms of Service',
    icon: LucideIcons.fileText,
    color: const Color(0xFF4ECDC4),
    content: '''MINDBRIDGE TERMS OF SERVICE
Last updated: March 2026

1. ACCEPTANCE
By using MindBridge you agree to these terms. If you do not agree, please discontinue use.

2. DESCRIPTION OF SERVICE
MindBridge is a mental wellness support application for university students. It provides mood tracking, AI conversation support (Maya), community features, journaling, and mindfulness tools.

3. NOT A SUBSTITUTE FOR PROFESSIONAL HELP
MindBridge is a wellness support tool and is NOT a substitute for professional mental health diagnosis, treatment, or therapy. If you are in crisis, please contact emergency services or a licensed mental health professional immediately.

4. USER ACCOUNTS
You are responsible for maintaining the security of your account credentials. You must be at least 16 years of age to use MindBridge.

5. COMMUNITY CONDUCT
You agree not to post content that is harmful, abusive, discriminatory, or that violates the rights of others. We reserve the right to remove content or suspend accounts that violate these guidelines.

6. DATA AND PRIVACY
Your wellness data is private by default. We do not sell your personal data to third parties. See our Privacy Policy for full details.

7. INTELLECTUAL PROPERTY
All content, features, and functionality of MindBridge are the intellectual property of MindBridge and its developers.

8. CHANGES TO TERMS
We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the new terms.

9. CONTACT
For questions about these terms, please use the "Send Feedback" option in the app.''',
  );
}

// ─── Privacy Policy Sheet ──────────────────────────────────

void _showPrivacyPolicySheet(BuildContext context) {
  _showLegalSheet(
    context,
    title: 'Privacy Policy',
    icon: LucideIcons.shield,
    color: const Color(0xFF06D6A0),
    content: '''MINDBRIDGE PRIVACY POLICY
Last updated: March 2026

1. INFORMATION WE COLLECT
• Account information: name, email address, university details
• Wellness data: mood logs, journal entries, mindfulness sessions
• Usage data: features used, session duration, in-app activity
• Device information: browser type, operating system

2. HOW WE USE YOUR DATA
• To provide and personalise the MindBridge experience
• To power Maya's AI responses (conversation context only)
• To generate your wellness insights and trends
• To send you wellness reminders (if enabled)

3. DATA STORAGE
Your data is stored securely using Supabase (a GDPR-compliant cloud platform). Mood and journal entries are stored encrypted and are only accessible to you.

4. DATA SHARING
We do NOT sell your personal data. We do not share your individual wellness data with third parties. Aggregated, anonymised data may be used for research to improve the app.

5. COMMUNITY PRIVACY
Posts marked anonymous do not display your name. However, MindBridge administrators can see all posts to moderate content and ensure safety.

6. YOUR RIGHTS
You have the right to:
• Access your data (use Export My Data)
• Correct inaccurate data (edit your profile)
• Delete your account and all associated data (contact us)
• Opt out of non-essential communications

7. COOKIES & LOCAL STORAGE
We use local storage to save your preferences (e.g., notification settings). No tracking cookies are used.

8. CHANGES TO THIS POLICY
We will notify you of significant changes via an in-app banner.

9. CONTACT
For privacy concerns, use the "Send Feedback" option in the app.''',
  );
}

void _showLegalSheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Color color,
  required String content,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Send Feedback Sheet ───────────────────────────────────

void _showFeedbackSheet(BuildContext context, WidgetRef ref) {
  final feedbackCtrl = TextEditingController();
  String category = 'General';

  const categories = ['General', 'Bug Report', 'Feature Request', 'Maya / AI', 'Community', 'Other'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD166).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.messageSquare, size: 16, color: Color(0xFFFFD166)),
              ),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Send Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Help us improve MindBridge', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ]),
            const SizedBox(height: 20),
            // Category chips
            const Text('Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categories.map((c) {
                final isSelected = category == c;
                return GestureDetector(
                  onTap: () => setState(() => category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFD166).withOpacity(0.15)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFD166) : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(c,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFFB45309) : AppColors.textSecondary,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: feedbackCtrl,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tell us what\'s on your mind...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD166), width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            _saveButton(
              context: ctx,
              label: 'Send Feedback',
              color: const Color(0xFFFFD166),
              onPressed: () async {
                final text = feedbackCtrl.text.trim();
                if (text.isEmpty) return;
                // Log feedback (would be sent to Supabase in production)
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Thanks for your feedback! 🙏'),
                    backgroundColor: const Color(0xFFFFD166),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
