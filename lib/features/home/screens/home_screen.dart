import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/models/daily_article_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/daily_content_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/providers/mindfulness_provider.dart';
import '../../../core/providers/crisis_escalation_provider.dart';
import '../../../core/services/goal_plan_engine.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/personalization_engine.dart';
import '../../../core/services/trend_analyzer.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/skeleton_loaders.dart';

// ─── Local Providers ──────────────────────────────────────

final _completedChallengesProvider = StateProvider<Set<String>>((ref) => {});

final _insightsProvider = Provider.autoDispose<List<WellnessInsight>>((ref) {
  final moodState = ref.watch(moodProvider);
  if (moodState.entries.length < 3) return [];
  return InsightsService(apiKey: '').generateStaticInsights(
    moodEntries: moodState.entries,
    journalEntries: moodState.journalEntries,
  );
});

// ─── Helper ───────────────────────────────────────────────

bool _isToday(DateTime dt) {
  final n = DateTime.now();
  return dt.year == n.year && dt.month == n.month && dt.day == n.day;
}

// ─── HomeScreen ───────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still awake?';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  static String _greetingEmoji() {
    final h = DateTime.now().hour;
    if (h < 5) return '🌙';
    if (h < 12) return '☀️';
    if (h < 17) return '🌤';
    if (h < 21) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final moodState = ref.watch(moodProvider);
    final crisisState = ref.watch(crisisEscalationProvider);
    final streakState = ref.watch(streakProvider);

    final name = user == null
        ? ''
        : (user.preferredName ?? user.name.split(' ').first);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: moodState.isLoading && moodState.entries.isEmpty
            ? const HomeScreenSkeleton()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ─── Flat Header ─────────────────────────
                  SliverToBoxAdapter(
                    child: _MayaHeroHeader(
                      greeting: _greeting(),
                      emoji: _greetingEmoji(),
                      name: name,
                    ),
                  ),

                  // ─── Today's Activity Rings ──────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TodayActivityRings(
                        moodState: moodState,
                        streakState: streakState,
                      ),
                    ),
                  ),

                  // ─── Goal Focus Strip ────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _GoalFocusStrip(user: user),
                    ),
                  ),

                  // ─── Crisis Banner (if active) ──────────
                  if (crisisState.currentTier.requiresAction)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _CrisisBanner(tier: crisisState.currentTier),
                      ),
                    ),

                  // ─── Complete Profile Banner ─────────────
                  if (user != null &&
                      (user.university == null || user.goals.isEmpty))
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _CompleteProfileBanner(user: user),
                      ),
                    ),

                  // ─── Kenyan Academic Banner ──────────────
                  if (_KenyanAcademicBanner.bannerData() != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: const SliverToBoxAdapter(child: _KenyanAcademicBanner()),
                    ),

                  // ─── Maya Message Card (HERO) ────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MayaMessageCard(
                        moodState: moodState,
                        streakState: streakState,
                      ),
                    ),
                  ),

                  // ─── Personalized Threshold Alerts ──────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _PersonalizedAlertCard(
                        user: user,
                        moodState: moodState,
                      ),
                    ),
                  ),

                  // ─── 5-Min Rescue (when no check-in or low mood) ──
                  if (moodState.todayEntry == null ||
                      (moodState.todayEntry?.moodScore ?? 10) <= 4)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _FiveMinRescue(moodState: moodState),
                      ),
                    ),

                  // ─── Daily Affirmation ───────────────────
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(child: _DailyAffirmation()),
                  ),

                  // ─── Today's Focus CTA ───────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TodaysFocusCard(
                        user: user,
                        moodState: moodState,
                      ),
                    ),
                  ),

                  // ─── Quick Actions Grid ──────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _QuickActionsGrid(),
                    ),
                  ),

                  // ─── Smart Nudge (time-aware) ────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SmartNudgeCard(
                        moodState: moodState,
                        streakState: streakState,
                      ),
                    ),
                  ),

                  // ─── Trend Alert (if active) ─────────────
                  if (moodState.activeAlerts.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _TrendAlert(moodState: moodState),
                      ),
                    ),

                  // ─── Wellness Summary ────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _WellnessSummaryCard(moodState: moodState),
                    ),
                  ),

                  // ─── Momentum / Multi-Streak ─────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MomentumCard(streakState: streakState),
                    ),
                  ),

                  // ─── Goal Progress Card ──────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _GoalProgressCard(
                        user: user,
                        moodState: moodState,
                      ),
                    ),
                  ),

                  // ─── Maya's Observations (Insights) ─────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _InsightsRow(moodState: moodState),
                    ),
                  ),

                  // ─── Today's Challenges ──────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ChallengesSection(),
                    ),
                  ),

                  // ─── Community Preview ───────────────────
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(child: _CommunityPreviewCard()),
                  ),

                  // ─── For You Today ───────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ForYouSection(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
      ),
    );
  }
}

// ─── Maya Hero Header ─────────────────────────────────────

class _MayaHeroHeader extends ConsumerWidget {
  final String greeting;
  final String emoji;
  final String name;

  const _MayaHeroHeader({
    required this.greeting,
    required this.emoji,
    required this.name,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    final moodState = ref.watch(moodProvider);
    final streakState = ref.watch(streakProvider);
    final manualDone = ref.watch(_completedChallengesProvider);

    final today = moodState.todayEntry;
    final overallStreak =
        streakState.overall?.currentStreak ?? moodState.currentStreakDays;
    final breakdown = moodState.wellnessBreakdown;
    final score = breakdown?.totalScore ?? 0.0;
    final moodDone = today != null;
    final journalDone =
        moodState.journalEntries.any((e) => _isToday(e.createdAt));
    final breatheDone =
        (streakState.streak(StreakType.mindfulness)?.completedToday ?? false) ||
            manualDone.contains('breathe');
    final chatDone =
        (streakState.streak(StreakType.chatSession)?.completedToday ?? false) ||
            manualDone.contains('chat');
    final doneCount =
        [moodDone, journalDone, breatheDone, chatDone].where((b) => b).length;

    // Band-aware gradient — shifts from green (thriving) → amber (struggling) → red (critical)
    final gradColors = score >= 80
        ? [const Color(0xFF047857), const Color(0xFF059669), const Color(0xFF10B981)]
        : score >= 60
            ? [AppColors.primaryDark, AppColors.primary, const Color(0xFF0EA5E9)]
            : score >= 40
                ? [const Color(0xFF1D4ED8), const Color(0xFF2563EB), const Color(0xFF3B82F6)]
                : score >= 20
                    ? [const Color(0xFFB45309), const Color(0xFFD97706), const Color(0xFFF59E0B)]
                    : score > 0
                        ? [const Color(0xFFB91C1C), const Color(0xFFDC2626), const Color(0xFFEF4444)]
                        : [AppColors.primaryDark, AppColors.primary, const Color(0xFF0EA5E9)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date pill + SOS ──────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  DateFormat('EEE, MMMM d').format(DateTime.now()),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              _SosButton(),
            ],
          ),

          const SizedBox(height: 10),

          // ── Greeting ──────────────────────────────────
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$greeting${name.isNotEmpty ? ', $name' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
              

          const SizedBox(height: 18),

          // ── Glass stat tiles ──────────────────────────
          Row(
            children: [
              _HeroStatTile(
                emoji: today != null ? MoodTokens.emojiFor(today.moodScore) : null,
                icon: today != null ? null : LucideIcons.smile,
                value: today != null ? '${today.moodScore}/10' : '–',
                label: 'Mood',
                delay: 120,
              ),
              const SizedBox(width: 8),
              _HeroStatTile(
                icon: overallStreak >= 30 ? null : LucideIcons.flame,
                emoji: overallStreak >= 30 ? '🏆' : overallStreak >= 7 ? '🔥' : null,
                value: '$overallStreak',
                label: overallStreak >= 30
                    ? 'Legendary!'
                    : overallStreak >= 7
                        ? 'On Fire!'
                        : 'Day Streak',
                suffix: overallStreak < 7 ? 'd' : null,
                delay: 200,
              ),
              const SizedBox(width: 8),
              _HeroStatTile(
                emoji: score > 0
                    ? WellnessTokens.emojiFor(WellnessTokens.bandFor(score))
                    : null,
                icon: score > 0 ? null : LucideIcons.activity,
                value: score > 0 ? score.toInt().toString() : '–',
                label: WellnessTokens.labelFor(WellnessTokens.bandFor(score)),
                delay: 280,
              ),
              const SizedBox(width: 8),
              _HeroStatTile(
                emoji: doneCount == 4 ? '🎉' : null,
                icon: doneCount == 4 ? null : LucideIcons.zap,
                value: '$doneCount/4',
                label: 'Done',
                delay: 360,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Hero Stat Tile ───────────────────────────────────────

class _HeroStatTile extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String value;
  final String label;
  final String? suffix;
  final int delay;

  const _HeroStatTile({
    this.icon,
    this.emoji,
    required this.value,
    required this.label,
    this.suffix,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.zero,
          border:
              Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 15))
            else if (icon != null)
              Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    suffix!,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      )
    );
  }
}

// ─── SOS Button ───────────────────────────────────────────

class _SosButton extends StatefulWidget {
  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.93, end: 1.06)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.crisis);
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.error.withOpacity(0.35), width: 1.5),
          ),
          child: Icon(LucideIcons.phoneCall, color: AppColors.error, size: 18),
        ),
      ),
    );
  }
}

// ─── Maya Message Card (HERO) ─────────────────────────────

class _MayaMessageCard extends ConsumerWidget {
  final MoodState moodState;
  final StreakAchievementState streakState;

  const _MayaMessageCard({
    required this.moodState,
    required this.streakState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final streakDays = streakState.overall?.currentStreak ?? 0;
    final message = PersonalizationEngine.getMayaHeroMessage(
      user, moodState, streakDays,
    );
    final chips = PersonalizationEngine.getMayaChips(user, moodState);
    return _MayaMessageCardBody(
      moodState: moodState,
      message: message,
      chips: chips,
    );
  }
}

class _MayaMessageCardBody extends StatelessWidget {
  final MoodState moodState;
  final String message;
  final List<String> chips;

  const _MayaMessageCardBody({
    required this.moodState,
    required this.message,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go(AppRoutes.chat);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + Name row ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF009E95), Color(0xFF00BEB4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child:
                      const Icon(LucideIcons.bot, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Maya',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Your AI wellness companion',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Chat now',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(LucideIcons.arrowRight, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Message bubble ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.55,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Prompt chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map((chip) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.go(AppRoutes.chat);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(
                                    color:
                                        AppColors.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.messageCircle,
                                      size: 12, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    chip,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Quick Actions Grid ───────────────────────────────────

class _QuickActionsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sorted = PersonalizationEngine.prioritizeActions(user);

    // First action is always featured (Chat Maya or highest-priority goal action)
    final actions = sorted.take(9).toList();

    // Label the top action as featured
    final featured = [actions.first.copyWith(featured: true), ...actions.skip(1)];

    Widget buildRow(List<PersonalizedAction> row, int startDelay) {
      return Row(
        children: row.asMap().entries.map((e) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: e.key < row.length - 1 ? 10 : 0),
              child: _QGridCard(
                action: _QGrid(
                  icon: e.value.icon,
                  label: e.value.label,
                  color: e.value.color,
                  route: e.value.route,
                  featured: e.value.featured,
                ),
                delay: (startDelay + e.key) * 60,
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Your tools" label with goal context
        if (user != null && user.goals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(LucideIcons.layoutGrid, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Your Tools',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    'sorted for you',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        buildRow(featured.take(3).toList(), 0),
        const SizedBox(height: 10),
        buildRow(featured.skip(3).take(3).toList(), 3),
        const SizedBox(height: 10),
        buildRow(featured.skip(6).take(3).toList(), 6),
      ],
    );
  }
}

class _QGrid {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final bool featured;

  const _QGrid({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.featured = false,
  });
}

class _QGridCard extends StatelessWidget {
  final _QGrid action;
  final int delay;

  const _QGridCard({required this.action, required this.delay});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.go(action.route);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            gradient: action.featured
                ? const LinearGradient(
                    colors: [Color(0xFF009E95), Color(0xFF00BEB4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: action.featured ? null : Colors.white,
            borderRadius: BorderRadius.zero,
            border: action.featured
                ? null
                : Border.all(color: action.color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: action.featured
                    ? AppColors.primary.withOpacity(0.28)
                    : action.color.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.featured
                      ? Colors.white.withOpacity(0.2)
                      : action.color.withOpacity(0.12),
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(
                  action.icon,
                  color: action.featured ? Colors.white : action.color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: action.featured ? Colors.white : action.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Trend Alert ──────────────────────────────────────────

class _TrendAlert extends StatelessWidget {
  final MoodState moodState;
  const _TrendAlert({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final alerts = [
      ...moodState.criticalAlerts,
      ...moodState.warningAlerts,
      ...moodState.positiveAlerts,
    ];
    if (alerts.isEmpty) return const SizedBox.shrink();

    final alert = alerts.first;
    final isPositive = alert.severity == TrendSeverity.positive;
    final isCritical = alert.severity == TrendSeverity.critical;
    final color = isPositive
        ? AppColors.success
        : isCritical
            ? AppColors.error
            : AppColors.warning;
    final icon = isPositive
        ? LucideIcons.trendingUp
        : isCritical
            ? LucideIcons.circleAlert
            : LucideIcons.triangleAlert;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Color(0xFF4A5568),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wellness Summary Card ────────────────────────────────

class _WellnessSummaryCard extends ConsumerWidget {
  final MoodState moodState;
  const _WellnessSummaryCard({required this.moodState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = moodState.todayEntry;
    final breakdown = moodState.wellnessBreakdown;
    final score = breakdown?.totalScore ?? 0.0;
    final band = WellnessTokens.bandFor(score);
    final moodColor =
        today != null ? MoodTokens.colorFor(today.moodScore) : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: Mood left, Wellness ring right ──
          Row(
            children: [
              // Mood section
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.go(AppRoutes.moodTracker);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: moodColor.withOpacity(0.12),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Center(
                          child: today != null
                              ? Text(
                                  MoodTokens.emojiFor(today.moodScore),
                                  style: const TextStyle(fontSize: 26),
                                )
                              : Icon(LucideIcons.smile,
                                  color: moodColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              today != null
                                  ? MoodTokens.labelFor(today.moodScore)
                                  : 'Log mood',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: today != null
                                    ? AppColors.textPrimary
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              today != null
                                  ? today.emotions.isNotEmpty
                                      ? today.emotions.take(2).join(' · ')
                                      : 'Tap to update'
                                  : 'How are you today?',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                width: 1,
                height: 52,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),

              // Wellness ring
              Column(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 5,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          score > 0 ? score.toInt().toString() : '–',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score > 0
                        ? '${WellnessTokens.emojiFor(band)} ${WellnessTokens.labelFor(band)}'
                        : 'Wellness',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── 7-day mood strip ──
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          _MoodStrip7Day(moodState: moodState),

          // ── Breakdown bars ──
          if (breakdown != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            ...[
              ('Mood', breakdown.moodComponent, const Color(0xFF06D6A0)),
              ('Consistency', breakdown.consistencyComponent, AppColors.primary),
              ('Sleep', breakdown.sleepComponent, const Color(0xFF0EA5E9)),
            ].map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c.$1,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${c.$2.toInt()}',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: c.$3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: LinearProgressIndicator(
                        value: (c.$2 / 100).clamp(0.0, 1.0),
                        backgroundColor: c.$3.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(c.$3),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 7-Day Mood Strip ─────────────────────────────────────

class _MoodStrip7Day extends StatelessWidget {
  final MoodState moodState;
  const _MoodStrip7Day({required this.moodState});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final entry = moodState.entries.where((e) {
        return e.createdAt.year == day.year &&
            e.createdAt.month == day.month &&
            e.createdAt.day == day.day;
      }).firstOrNull;
      return (day: day, entry: entry);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Last 7 days',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go(AppRoutes.moodAnalytics),
              child: const Text(
                'See full history →',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((d) {
            final entry = d.entry;
            final isToday = d.day.day == now.day &&
                d.day.month == now.month &&
                d.day.year == now.year;
            final dayLabel = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.day.weekday - 1];

            return Expanded(
              child: Column(
                children: [
                  // Mood dot / emoji
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: entry != null
                          ? MoodTokens.colorFor(entry.moodScore).withOpacity(0.15)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.zero,
                      border: isToday
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: entry != null
                          ? Text(
                              MoodTokens.emojiFor(entry.moodScore),
                              style: const TextStyle(fontSize: 14),
                            )
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isToday ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Maya's Observations (Insights) ──────────────────────

class _InsightsRow extends ConsumerWidget {
  final MoodState moodState;
  const _InsightsRow({required this.moodState});

  IconData _iconFor(InsightType type) => switch (type) {
        InsightType.correlation => LucideIcons.gitMerge,
        InsightType.pattern => LucideIcons.calendarDays,
        InsightType.prediction => LucideIcons.sparkles,
        InsightType.weeklyReport => LucideIcons.chartBar,
        InsightType.recommendation => LucideIcons.lightbulb,
      };

  Color _colorFor(InsightType type) => switch (type) {
        InsightType.correlation => const Color(0xFF0EA5E9),
        InsightType.pattern => AppColors.tertiary,
        InsightType.prediction => const Color(0xFFF59E0B),
        InsightType.weeklyReport => AppColors.primary,
        InsightType.recommendation => const Color(0xFF10B981),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(_insightsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(LucideIcons.sparkles,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            const Text(
              "Maya's Observations",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (moodState.entries.length < 3)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.zero,
                ),
                child: const Text(
                  'Log more to unlock',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Insight cards
        if (insights.isEmpty)
          _InsightsEmpty(entryCount: moodState.entries.length)
        else
          Column(
            children: insights.take(3).toList().asMap().entries.map((e) {
              final i = e.key;
              final ins = e.value;
              return Padding(
                padding: EdgeInsets.only(bottom: i < insights.length - 1 ? 10 : 0),
                child: _InsightCard(
                  insight: ins,
                  color: _colorFor(ins.type),
                  icon: _iconFor(ins.type),
                )
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final WellnessInsight insight;
  final Color color;
  final IconData icon;

  const _InsightCard({
    required this.insight,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x09000000),
              blurRadius: 14,
              offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient icon circle
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.75), color],
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type label badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    insight.title,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                // Body
                Text(
                  insight.body,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsEmpty extends StatelessWidget {
  final int entryCount;
  const _InsightsEmpty({required this.entryCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(LucideIcons.chartBar,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insights unlock soon',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Log ${3 - entryCount.clamp(0, 3)} more mood${(3 - entryCount.clamp(0, 3)) == 1 ? '' : 's'} to unlock personalized insights.',
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

// ─── Challenges Section ───────────────────────────────────

class _ChallengesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final moodState = ref.watch(moodProvider);
    final streakState = ref.watch(streakProvider);
    final manualDone = ref.watch(_completedChallengesProvider);

    // Get personalized challenges from engine
    final engineChallenges = PersonalizationEngine.selectChallenges(user, max: 5);

    // Build completion map from all possible challenge IDs
    final completionMap = <String, bool>{
      'mood': moodState.todayEntry != null,
      'breathe_478': (streakState.streak(StreakType.mindfulness)?.completedToday ?? false) || manualDone.contains('breathe_478'),
      'journal_gratitude': moodState.journalEntries.any((e) => _isToday(e.createdAt)) || manualDone.contains('journal_gratitude'),
      'journal_vent': moodState.journalEntries.any((e) => _isToday(e.createdAt)) || manualDone.contains('journal_vent'),
      'chat_maya': (streakState.streak(StreakType.chatSession)?.completedToday ?? false) || manualDone.contains('chat_maya'),
      'sleep_wind_down': manualDone.contains('sleep_wind_down'),
      'community_post': manualDone.contains('community_post'),
      'body_scan': manualDone.contains('body_scan'),
      'resources_read': manualDone.contains('resources_read'),
      'study_pomodoro': manualDone.contains('study_pomodoro'),
      'affirmation_mirror': manualDone.contains('affirmation_mirror'),
      'analytics_review': manualDone.contains('analytics_review'),
      'wellness_goal': manualDone.contains('wellness_goal'),
    };

    final completedCount = engineChallenges
        .where((c) => completionMap[c.id] == true).length;
    final totalXp = engineChallenges.fold(0, (sum, c) => sum + c.xp);
    final earnedXp = engineChallenges
        .where((c) => completionMap[c.id] == true)
        .fold(0, (sum, c) => sum + c.xp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Row(
          children: [
            const Text(
              "Today's Challenges",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: completedCount == 5
                    ? const Color(0xFF10B981).withOpacity(0.12)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                completedCount == 5
                    ? '✓ All done!'
                    : '$earnedXp / $totalXp XP',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: completedCount == 5
                      ? const Color(0xFF10B981)
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── XP progress bar ──
        ClipRRect(
          borderRadius: BorderRadius.zero,
          child: LinearProgressIndicator(
            value: totalXp > 0 ? earnedXp / totalXp : 0,
            backgroundColor: AppColors.primaryContainer,
            valueColor: AlwaysStoppedAnimation<Color>(
              completedCount == 5
                  ? const Color(0xFF10B981)
                  : AppColors.primary,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),

        // ── Challenge tiles (personalized) ──
        ...List.generate(engineChallenges.length, (i) {
          final c = engineChallenges[i];
          final isDone = completionMap[c.id] ?? false;
          final autoCompleted = c.id == 'mood' || c.id == 'journal_gratitude' || c.id == 'journal_vent' || c.id == 'chat_maya';
          final canManualComplete = !autoCompleted;
          return _ChallengeTile(
            data: _ChallengeData(
              id: c.id,
              icon: c.icon,
              title: c.title,
              subtitle: c.subtitle,
              category: c.category,
              categoryColor: c.categoryColor,
              xp: c.xp,
              route: c.route,
            ),
            isDone: isDone,
            delay: 650 + i * 80,
            onComplete: canManualComplete && !isDone
                ? () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(_completedChallengesProvider.notifier)
                        .update((s) => {...s, c.id});
                  }
                : null,
            onTap: () => context.push(c.route),
          );
        }),
      ],
    );
  }
}

// ─── Complete Profile Banner ──────────────────────────────

class _CompleteProfileBanner extends StatelessWidget {
  final dynamic user; // UserModel
  const _CompleteProfileBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.profile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00BEB4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(
                LucideIcons.userRoundCog,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Help Maya personalise your experience',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Crisis Banner ────────────────────────────────────────

class _CrisisBanner extends ConsumerWidget {
  final CrisisTier tier;
  const _CrisisBanner({required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCritical = tier.isCritical;
    final color = isCritical ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isCritical ? LucideIcons.shieldAlert : LucideIcons.heartPulse,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tier.displayMessage,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push(AppRoutes.crisis),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.zero,
              ),
              child: const Text(
                'Get Help',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Challenge Data + Tile ────────────────────────────────

class _ChallengeData {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String category;
  final Color categoryColor;
  final int xp;
  final String route;

  const _ChallengeData({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.categoryColor,
    required this.xp,
    required this.route,
  });
}

class _ChallengeTile extends StatelessWidget {
  final _ChallengeData data;
  final bool isDone;
  final int delay;
  final VoidCallback? onComplete;
  final VoidCallback onTap;

  const _ChallengeTile({
    required this.data,
    required this.isDone,
    required this.delay,
    required this.onComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFFF0FFF6)
                : Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: isDone
                  ? AppColors.success.withOpacity(0.35)
                  : const Color(0xFFE8EDF2),
              width: isDone ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDone
                    ? AppColors.success.withOpacity(0.08)
                    : const Color(0x08000000),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDone
                        ? [const Color(0xFF34D399), AppColors.success]
                        : [
                            data.categoryColor.withOpacity(0.7),
                            data.categoryColor,
                          ],
                  ),
                  borderRadius: BorderRadius.zero,
                  boxShadow: [
                    BoxShadow(
                      color: (isDone ? AppColors.success : data.categoryColor)
                          .withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isDone ? LucideIcons.circleCheck : data.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDone
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF1A1A2E),
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: data.categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      data.category,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: data.categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (!isDone)
                    GestureDetector(
                      onTap: onComplete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: onComplete != null
                              ? AppColors.success.withOpacity(0.1)
                              : data.categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              onComplete != null
                                  ? LucideIcons.check
                                  : LucideIcons.arrowRight,
                              size: 10,
                              color: onComplete != null
                                  ? AppColors.success
                                  : data.categoryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '+${data.xp} XP',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: onComplete != null
                                    ? AppColors.success
                                    : data.categoryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Text(
                      'Done! ✓',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kenyan Academic Banner ────────────────────────────────

class _BannerData {
  final String emoji;
  final String title;
  final String body;
  final Color color;
  final Color bgColor;
  final String cta;
  final String route;

  const _BannerData({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
    required this.bgColor,
    required this.cta,
    required this.route,
  });
}

class _KenyanAcademicBanner extends StatelessWidget {
  const _KenyanAcademicBanner();

  static _BannerData? bannerData() {
    final m = DateTime.now().month;
    final d = DateTime.now().day;

    // Attachment / Internship season: July–August
    if (m == 7 || m == 8) {
      return const _BannerData(
        emoji: '🏢',
        title: 'Attachment Season',
        body: "Industrial attachment can be tough. Whether paid or unpaid — your mental health always comes first.",
        color: Color(0xFF0EA5E9),
        bgColor: Color(0xFFE0F4FF),
        cta: 'Talk to Maya',
        route: AppRoutes.chat,
      );
    }

    // HELB disbursement windows: Feb (Sem 2), Sep first 3 weeks (Sem 1)
    if (m == 2 || (m == 9 && d <= 21)) {
      return const _BannerData(
        emoji: '💸',
        title: 'HELB Disbursement Season',
        body: 'HELB funds are rolling out. Financial stress is valid — Maya is here whenever you need support.',
        color: Color(0xFFF59E0B),
        bgColor: Color(0xFFFFF8E1),
        cta: 'Talk to Maya',
        route: AppRoutes.chat,
      );
    }

    // Semester 2 CAT season: mid-March through April
    if ((m == 3 && d >= 14) || m == 4) {
      return const _BannerData(
        emoji: '📝',
        title: 'CAT Season',
        body: "Sem 2 CATs are here. Take it one paper at a time. You've prepared for this — Maya has your back.",
        color: Color(0xFFFF6B6B),
        bgColor: Color(0xFFFFEDED),
        cta: 'Get support',
        route: AppRoutes.chat,
      );
    }

    // Semester 2 end-of-semester exams: June
    if (m == 6) {
      return const _BannerData(
        emoji: '🎯',
        title: 'Semester 2 Exams',
        body: 'Final exams: rest well, eat, and remember — your worth is not defined by your grade.',
        color: Color(0xFFFF6B35),
        bgColor: Color(0xFFFFF0E8),
        cta: 'Breathe first',
        route: AppRoutes.mindfulness,
      );
    }

    // Semester 1 CAT season: mid-October through November
    if ((m == 10 && d >= 14) || m == 11) {
      return const _BannerData(
        emoji: '📝',
        title: 'CAT Season',
        body: "Sem 1 CATs are underway. Maya has study stress tips ready whenever you need them. You've got this.",
        color: Color(0xFFFF6B6B),
        bgColor: Color(0xFFFFEDED),
        cta: 'Get support',
        route: AppRoutes.chat,
      );
    }

    // Semester 1 end-of-semester exams: January
    if (m == 1) {
      return const _BannerData(
        emoji: '🎯',
        title: 'Semester 1 Exams',
        body: 'Exam time — balance revision with rest. Sleep matters as much as studying. You can do this.',
        color: Color(0xFFFF6B35),
        bgColor: Color(0xFFFFF0E8),
        cta: 'Study tips',
        route: AppRoutes.chat,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = bannerData()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: data.bgColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: data.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Text(data.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                ),
                Text(
                  data.body,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11.5,
                    color: Color(0xFF4A5568),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go(data.route),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                data.cta,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 5-Minute Rescue ──────────────────────────────────────

class _FiveMinRescue extends ConsumerWidget {
  final MoodState moodState;
  const _FiveMinRescue({required this.moodState});

  bool get _isLowMood =>
      moodState.todayEntry != null && moodState.todayEntry!.moodScore <= 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final rescueActions = PersonalizationEngine.getRescueActions(user);
    final headline = PersonalizationEngine.getRescueHeadline(
      user,
      isLowMood: _isLowMood,
      isNoCheckin: moodState.todayEntry == null,
    );

    // Color theme: anxiety=blue, sleep=indigo, depression=teal, default=primary
    final primary = user?.goals.isNotEmpty == true ? user!.goals.first : '';
    final accentColor = switch (primary) {
      'anxiety' => const Color(0xFF0EA5E9),
      'sleep' => const Color(0xFF6366F1),
      'depression' || 'grief' => const Color(0xFF06D6A0),
      'social' => const Color(0xFFFF6B6B),
      _ => AppColors.primary,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.08),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: accentColor.withOpacity(0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(headline.emoji,
                    style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      headline.subtitle,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: rescueActions.asMap().entries.map((e) {
              final a = e.value;
              return [
                if (e.key > 0) const SizedBox(width: 8),
                Expanded(
                  child: _RescueChip(
                    emoji: a.emoji,
                    label: a.label,
                    primary: a.primary,
                    onTap: () => context.go(a.route),
                  ),
                ),
              ];
            }).expand((w) => w).toList(),
          ),
        ],
      ),
    );
  }
}

class _RescueChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _RescueChip({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: primary
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── For You Today Section ────────────────────────────────

class _ForYouSection extends ConsumerStatefulWidget {
  const _ForYouSection();

  @override
  ConsumerState<_ForYouSection> createState() => _ForYouSectionState();
}

class _ForYouSectionState extends ConsumerState<_ForYouSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyContentProvider.notifier).loadIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(dailyContentProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(LucideIcons.sparkles, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For You Today',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Personalized by Maya',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!content.isLoading)
              GestureDetector(
                onTap: () => ref.read(dailyContentProvider.notifier).generate(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.refreshCw, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Refresh', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Content
        if (content.isLoading)
          _ArticleSkeletonList()
        else if (content.hasArticles)
          ...content.articles.asMap().entries.map(
            (e) => _ArticleCard(
              article: e.value,
              delay: e.key * 100,
            ),
          )
        else if (content.status == DailyContentStatus.error)
          _ArticleErrorCard(
            onRetry: () => ref.read(dailyContentProvider.notifier).generate(),
          )
        else
          _ArticleEmptyCard(
            onGenerate: () => ref.read(dailyContentProvider.notifier).generate(),
          ),
      ],
    );
  }
}

// ─── Article Card ─────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final DailyArticle article;
  final int delay;
  const _ArticleCard({required this.article, this.delay = 0});

  static const _categoryColors = {
    'Anxiety': Color(0xFFFF6B6B),
    'Stress': Color(0xFFFF8C42),
    'Sleep': Color(0xFF0EA5E9),
    'Focus': Color(0xFF10B981),
    'Motivation': Color(0xFFF59E0B),
    'Mindfulness': AppColors.primary,
    'Academic': Color(0xFF06D6A0),
    'Relationships': Color(0xFFFF6B6B),
    'Confidence': Color(0xFFF59E0B),
    'Energy': Color(0xFF10B981),
  };

  Color _catColor() =>
      _categoryColors[article.category] ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final color = _catColor();
    return GestureDetector(
      onTap: () => _showArticleSheet(context, article, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + read time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          article.category,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        article.readTime,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(article.emoji, style: const TextStyle(fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Summary
                  Text(
                    article.summary,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Why for you
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.07),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.sparkles, size: 12, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            article.whyForYou,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Read button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Read article', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            SizedBox(width: 4),
                            Icon(LucideIcons.arrowRight, size: 13, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArticleSheet(BuildContext context, DailyArticle article, Color color) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ArticleDetailSheet(article: article, color: color),
    );
  }
}

// ─── Article Detail Sheet ─────────────────────────────────

class _ArticleDetailSheet extends StatelessWidget {
  final DailyArticle article;
  final Color color;
  const _ArticleDetailSheet({required this.article, required this.color});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle + top bar
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.zero),
            ),
            // Accent bar
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  // Category + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(article.category, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const SizedBox(width: 10),
                      Text(article.readTime, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.textMuted)),
                      const Spacer(),
                      Text(article.emoji, style: const TextStyle(fontSize: 28)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    article.title,
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  // Why for you banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.sparkles, size: 14, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            article.whyForYou,
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600, color: color, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 14),
                  // Full content
                  Text(
                    article.content,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.75,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Center(
                        child: Text('Done', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton / Empty / Error states ─────────────────────

class _ArticleSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.zero,
        ),
      )
          ));
  }
}

class _ArticleEmptyCard extends StatelessWidget {
  final VoidCallback onGenerate;
  const _ArticleEmptyCard({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.bookOpen, size: 32, color: AppColors.primary),
          const SizedBox(height: 10),
          const Text('Get Your Daily Articles', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Maya will curate 3 personalized articles based on your profile and goals.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onGenerate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.zero),
              child: const Text('Generate Now', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ArticleErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.wifiOff, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          const Expanded(child: Text('Could not load articles. Tap to retry.', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textSecondary))),
          GestureDetector(
            onTap: onRetry,
            child: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Affirmation ─────────────────────────────────────

class _DailyAffirmation extends ConsumerWidget {
  const _DailyAffirmation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final idx = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final (quote, source) = PersonalizationEngine.getAffirmation(user, idx);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative quotation mark
          Positioned(
            top: -6,
            right: 6,
            child: Text(
              '\u201C',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 80,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.12),
                height: 1,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('✨', style: TextStyle(fontSize: 10)),
                        SizedBox(width: 4),
                        Text('Daily Affirmation',
                          style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 10,
                            fontWeight: FontWeight.w700, color: Colors.white,
                          )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '"$quote"',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '— $source',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Community Preview Card ────────────────────────────────

class _CommunityPreviewCard extends StatelessWidget {
  const _CommunityPreviewCard();

  static const _vibes = [
    '💬 Someone shared how they survived CAT week without burning out.',
    '🤝 Students are talking about HELB delays and how to cope.',
    '💪 Top post: "You are not your CGPA — and here\'s why."',
    '📚 Students forming study groups for finals. Find yours!',
    '🌟 Someone just shared their first week at attachment. Cheer them on!',
    '💙 A student opened up about campus loneliness. Show some love.',
    '🎉 Big wins being celebrated in the community today.',
  ];

  @override
  Widget build(BuildContext context) {
    final idx = DateTime.now().difference(DateTime(2024, 1, 1)).inDays %
        _vibes.length;
    final vibe = _vibes[idx];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go(AppRoutes.community);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F0), Color(0xFFFFF8F0)],
          ),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.25)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0AFF6B6B), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8C8C), Color(0xFFFF6B6B)],
                ),
                borderRadius: BorderRadius.zero,
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x30FF6B6B),
                      blurRadius: 8,
                      offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(LucideIcons.users, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Campus Community',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vibe,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.zero,
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x35FF6B6B),
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Join',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(LucideIcons.arrowRight, size: 12, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PERSONALIZED WIDGETS
// ─────────────────────────────────────────────────────────

// ─── Today's Focus Card ───────────────────────────────────

class _TodaysFocusCard extends StatelessWidget {
  final dynamic user; // UserModel?
  final MoodState moodState;

  const _TodaysFocusCard({required this.user, required this.moodState});

  @override
  Widget build(BuildContext context) {
    final focus = GoalPlanEngine.getTodaysFocus(user, moodState);
    final color = _goalColor(focus.goalId);

    return GestureDetector(
      onTap: () => context.push(focus.route),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.zero,
              ),
              child: Center(
                child: Text(focus.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          "TODAY'S FOCUS",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    focus.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.tokenTextPrimary,
                    ),
                  ),
                  Text(
                    focus.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokenTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    focus.ctaLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(LucideIcons.arrowRight, size: 12, color: color),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }

  Color _goalColor(String? goalId) => switch (goalId) {
        'anxiety' => const Color(0xFF4ECDC4),
        'depression' => const Color(0xFF6C63FF),
        'sleep' => const Color(0xFF6366F1),
        'focus' => const Color(0xFFF59E0B),
        'relationships' => const Color(0xFFEC4899),
        'self_esteem' => const Color(0xFF8B5CF6),
        'motivation' => const Color(0xFFFF6B6B),
        'grief' => const Color(0xFF64748B),
        _ => AppColors.primary,
      };
}

// ─── Goal Focus Strip ─────────────────────────────────────

class _GoalFocusStrip extends StatelessWidget {
  final dynamic user; // UserModel?
  const _GoalFocusStrip({required this.user});

  @override
  Widget build(BuildContext context) {
    final items = PersonalizationEngine.getFocusItems(user, max: 3);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.target, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 5),
            const Text(
              'Your focus today',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              return Padding(
                padding: EdgeInsets.only(right: e.key < items.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go(item.route);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.10),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: item.color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: item.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.arrowRight, size: 11, color: item.color),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Goal Progress Card ───────────────────────────────────

class _GoalProgressCard extends StatelessWidget {
  final dynamic user; // UserModel?
  final MoodState moodState;
  const _GoalProgressCard({required this.user, required this.moodState});

  @override
  Widget build(BuildContext context) {
    final items = PersonalizationEngine.computeGoalProgress(user, moodState);
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(LucideIcons.target, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Goal Progress',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Based on your mood, streaks & habits',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Goal bars
          ...items.asMap().entries.map((e) {
            final item = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.label,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${(item.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor: item.color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(item.color),
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.statusText,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── View My Wellness Plan CTA ──────────────────
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.wellnessPlan);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.sparkles, size: 15, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'View My Wellness Plan',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(LucideIcons.arrowRight, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Personalized Alert Card ──────────────────────────────

class _PersonalizedAlertCard extends StatelessWidget {
  final dynamic user; // UserModel?
  final MoodState moodState;
  const _PersonalizedAlertCard({required this.user, required this.moodState});

  @override
  Widget build(BuildContext context) {
    final alerts = PersonalizationEngine.computeThresholdAlerts(user, moodState);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((alert) {
        final (bgColor, iconColor, borderColor) = switch (alert.level) {
          PersonalizedAlertLevel.critical => (
              const Color(0xFFFF6B6B).withOpacity(0.08),
              const Color(0xFFFF6B6B),
              const Color(0xFFFF6B6B),
            ),
          PersonalizedAlertLevel.warning => (
              const Color(0xFFF59E0B).withOpacity(0.08),
              const Color(0xFFF59E0B),
              const Color(0xFFF59E0B),
            ),
          PersonalizedAlertLevel.info => (
              AppColors.primary.withOpacity(0.06),
              AppColors.primary,
              AppColors.primary,
            ),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: borderColor.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.14),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(alert.icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.message,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (alert.actionLabel != null && alert.actionRoute != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.go(alert.actionRoute!);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  alert.actionLabel!,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(LucideIcons.arrowRight, size: 11, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TODAY'S ACTIVITY RINGS
// Four animated circular rings for Mood / Journal / Mindfulness / Chat
// ─────────────────────────────────────────────────────────

class _TodayActivityRings extends ConsumerWidget {
  final MoodState moodState;
  final StreakAchievementState streakState;

  const _TodayActivityRings({
    required this.moodState,
    required this.streakState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manualDone = ref.watch(_completedChallengesProvider);

    final mindfulnessState = ref.watch(mindfulnessProvider);

    final moodDone = moodState.todayEntry != null;
    final journalDone = moodState.journalEntries.any((e) => _isToday(e.createdAt));
    final mindfulnessDone =
        mindfulnessState.hasSessionToday ||
            (streakState.streak(StreakType.mindfulness)?.completedToday ?? false) ||
            manualDone.contains('breathe') ||
            manualDone.contains('breathe_478') ||
            manualDone.contains('body_scan');
    final chatDone =
        (streakState.streak(StreakType.chatSession)?.completedToday ?? false) ||
            manualDone.contains('chat') ||
            manualDone.contains('chat_maya');

    final rings = [
      _RingData(
        label: 'Mood',
        emoji: moodDone
            ? MoodTokens.emojiFor(moodState.todayEntry!.moodScore)
            : '😊',
        done: moodDone,
        color: moodDone
            ? MoodTokens.colorFor(moodState.todayEntry!.moodScore)
            : const Color(0xFF06D6A0),
        route: AppRoutes.moodTracker,
        delay: 0,
      ),
      _RingData(
        label: 'Journal',
        emoji: '📖',
        done: journalDone,
        color: const Color(0xFFF59E0B),
        route: AppRoutes.journal,
        delay: 80,
      ),
      _RingData(
        label: 'Breathe',
        emoji: '🧘',
        done: mindfulnessDone,
        color: const Color(0xFF8B5CF6),
        route: AppRoutes.mindfulness,
        delay: 160,
      ),
      _RingData(
        label: 'Maya',
        emoji: '💬',
        done: chatDone,
        color: AppColors.primary,
        route: AppRoutes.chat,
        delay: 240,
      ),
    ];

    final doneCount = rings.where((r) => r.done).length;
    final allDone = doneCount == 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: allDone
              ? AppColors.success.withOpacity(0.4)
              : AppColors.border,
          width: allDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: allDone
                ? AppColors.success.withOpacity(0.08)
                : const Color(0x0A000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: allDone
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(
                  allDone ? LucideIcons.circleCheck : LucideIcons.zap,
                  size: 16,
                  color: allDone ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Today\'s Practice',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allDone
                      ? AppColors.success.withOpacity(0.12)
                      : doneCount > 0
                          ? AppColors.primaryContainer
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  allDone
                      ? '🎉 All done!'
                      : '$doneCount / 4 done',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: allDone
                        ? AppColors.success
                        : doneCount > 0
                            ? AppColors.primary
                            : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Ring Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rings.asMap().entries.map((entry) {
              final ring = entry.value;
              return _ActivityRingCell(
                data: ring,
              );
            }).toList(),
          ),

          // ── Completion bar ──
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              child: LinearProgressIndicator(
                value: doneCount / 4,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  allDone ? AppColors.success : AppColors.primary,
                ),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingData {
  final String label;
  final String emoji;
  final bool done;
  final Color color;
  final String route;
  final int delay;

  const _RingData({
    required this.label,
    required this.emoji,
    required this.done,
    required this.color,
    required this.route,
    required this.delay,
  });
}

class _ActivityRingCell extends StatelessWidget {
  final _RingData data;
  const _ActivityRingCell({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go(data.route);
      },
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer track
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: data.done ? 1.0 : 0.0,
                    strokeWidth: 5,
                    backgroundColor: data.color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      data.done ? data.color : data.color.withOpacity(0.3),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Inner circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: data.done
                        ? data.color.withOpacity(0.12)
                        : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      data.done ? '✓' : data.emoji,
                      style: TextStyle(
                        fontSize: data.done ? 20 : 22,
                        color: data.done ? data.color : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            data.label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: data.done ? data.color : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MOMENTUM CARD  — multi-type streak grid + milestone arc
// ─────────────────────────────────────────────────────────

class _MomentumCard extends ConsumerWidget {
  final StreakAchievementState streakState;
  const _MomentumCard({required this.streakState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = streakState.overall;
    final moodState = ref.watch(moodProvider);
    final mindfulnessState = ref.watch(mindfulnessProvider);

    // Compute today's completions to seed the display if no DB streak yet
    final todayCompletions = [
      moodState.todayEntry != null,
      moodState.journalEntries.any((e) => _isToday(e.createdAt)),
      mindfulnessState.hasSessionToday ||
          (streakState.streak(StreakType.mindfulness)?.completedToday ?? false),
      streakState.streak(StreakType.chatSession)?.completedToday ?? false,
    ].where((b) => b).length;

    final overallCount = overall != null
        ? overall.currentStreak
        : (todayCompletions > 0 ? 1 : 0);
    final milestone = overall?.nextMilestone ?? 7;
    final progress = overall != null
        ? overall.milestoneProgress
        : (todayCompletions / 4.0).clamp(0.0, 1.0);

    final types = [
      StreakType.moodLogging,
      StreakType.journalWriting,
      StreakType.mindfulness,
      StreakType.chatSession,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              const Text(
                '🔥',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Momentum',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(AppRoutes.wellness),
                child: const Text(
                  'See all →',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Overall streak hero ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: overallCount >= 30
                    ? [const Color(0xFF7C3AED), const Color(0xFFA855F7)]
                    : overallCount >= 7
                        ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
                        : [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              children: [
                // Big flame/trophy
                Text(
                  overallCount >= 30
                      ? '🏆'
                      : overallCount >= 7
                          ? '🔥'
                          : '⚡',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$overallCount',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'day streak',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Milestone progress
                      ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        overallCount >= milestone
                            ? '🎉 Milestone reached!'
                            : '${milestone - overallCount}d to $milestone-day milestone',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 4-type streak grid ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: types.map((type) {
              final streak = streakState.streak(type);
              final count = streak?.currentStreak ?? 0;
              final isOnFire = count >= 7;
              final isLegendary = count >= 30;
              final completedToday = streak?.completedToday ?? false;

              final color = switch (type) {
                StreakType.moodLogging => const Color(0xFF06D6A0),
                StreakType.journalWriting => const Color(0xFFF59E0B),
                StreakType.mindfulness => const Color(0xFF8B5CF6),
                StreakType.chatSession => AppColors.primary,
                _ => AppColors.primary,
              };

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: completedToday
                      ? color.withOpacity(0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: completedToday
                        ? color.withOpacity(0.3)
                        : AppColors.border,
                    width: completedToday ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      isLegendary
                          ? '🏆'
                          : isOnFire
                              ? '🔥'
                              : type.emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            type.displayName
                                .split(' ')
                                .first, // "Mood", "Journaling", etc.
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$count day${count == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: count > 0 ? color : AppColors.textMuted,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (completedToday)
                      Icon(LucideIcons.circleCheck,
                          size: 14, color: color),
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

// ─────────────────────────────────────────────────────────
// SMART NUDGE CARD — time-aware, pattern-based suggestion
// ─────────────────────────────────────────────────────────

class _SmartNudgeCard extends StatelessWidget {
  final MoodState moodState;
  final StreakAchievementState streakState;

  const _SmartNudgeCard({
    required this.moodState,
    required this.streakState,
  });

  /// Returns null if there's nothing worth nudging about right now.
  _NudgeContent? _compute() {
    final hour = DateTime.now().hour;
    final today = moodState.todayEntry;
    final overallStreak = streakState.overall?.currentStreak ?? 0;
    final moodStreak = streakState.streak(StreakType.moodLogging);
    final journalStreak = streakState.streak(StreakType.journalWriting);
    final mindfulStreak = streakState.streak(StreakType.mindfulness);

    // 1. Streak at risk (evening, streak > 0, not completed today)
    if (hour >= 20 && overallStreak > 0) {
      final notDoneToday = !(moodStreak?.completedToday ?? false);
      if (notDoneToday) {
        return _NudgeContent(
          emoji: '⚠️',
          title: 'Streak at risk!',
          body: 'You have a $overallStreak-day streak. Log your mood to keep it alive.',
          actionLabel: 'Log Mood',
          route: AppRoutes.moodTracker,
          color: const Color(0xFFF59E0B),
        );
      }
    }

    // 2. No mood check-in yet (morning/afternoon)
    if (hour >= 9 && hour < 16 && today == null) {
      return _NudgeContent(
        emoji: '😊',
        title: 'Morning check-in',
        body: 'How are you feeling today? Takes 10 seconds.',
        actionLabel: 'Log Now',
        route: AppRoutes.moodTracker,
        color: const Color(0xFF06D6A0),
      );
    }

    // 3. Low mood detected — suggest Maya chat
    if (today != null && today.moodScore <= 4) {
      return _NudgeContent(
        emoji: '💙',
        title: 'Tough day?',
        body: 'Maya is here to listen whenever you\'re ready.',
        actionLabel: 'Talk to Maya',
        route: AppRoutes.chat,
        color: AppColors.primary,
      );
    }

    // 4. Evening journal prompt
    if (hour >= 18 && hour < 23) {
      final hasJournaledToday =
          moodState.journalEntries.any((e) => _isToday(e.createdAt));
      if (!hasJournaledToday) {
        final streak = journalStreak?.currentStreak ?? 0;
        return _NudgeContent(
          emoji: '📖',
          title: 'Evening reflection',
          body: streak > 0
              ? 'Keep your $streak-day journal streak going.'
              : 'A few lines before bed can improve tomorrow.',
          actionLabel: 'Write',
          route: AppRoutes.journal,
          color: const Color(0xFFF59E0B),
        );
      }
    }

    // 5. Midday mindfulness (if no mindfulness yet and between 12-14)
    if (hour >= 12 && hour < 15) {
      final hasMindfulToday = mindfulStreak?.completedToday ?? false;
      if (!hasMindfulToday) {
        return _NudgeContent(
          emoji: '🧘',
          title: '5-min breathing break',
          body: 'A quick session now can refocus your afternoon.',
          actionLabel: 'Breathe',
          route: AppRoutes.mindfulness,
          color: const Color(0xFF8B5CF6),
        );
      }
    }

    // 6. Positive reinforcement (all done)
    final allDone = (moodStreak?.completedToday ?? false) &&
        moodState.journalEntries.any((e) => _isToday(e.createdAt)) &&
        (mindfulStreak?.completedToday ?? false);
    if (allDone) {
      return _NudgeContent(
        emoji: '🌟',
        title: 'You\'re doing great!',
        body: 'All daily practices complete. Keep this up — it makes a real difference.',
        actionLabel: 'View Progress',
        route: AppRoutes.moodAnalytics,
        color: AppColors.success,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nudge = _compute();
    if (nudge == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(nudge.route);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: nudge.color.withOpacity(0.07),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: nudge.color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Text(nudge.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nudge.title,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: nudge.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nudge.body,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: nudge.color,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                nudge.actionLabel,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      )
    );
  }
}

class _NudgeContent {
  final String emoji;
  final String title;
  final String body;
  final String actionLabel;
  final String route;
  final Color color;

  const _NudgeContent({
    required this.emoji,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.route,
    required this.color,
  });
}
