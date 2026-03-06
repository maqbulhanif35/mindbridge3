import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/providers/crisis_escalation_provider.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/trend_analyzer.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/skeleton_loaders.dart';

// ─── Local Providers ──────────────────────────────────────

final _completedChallengesProvider = StateProvider<Set<String>>((ref) => {});

final _insightsProvider = Provider.autoDispose<List<WellnessInsight>>((ref) {
  final moodState = ref.watch(moodProvider);
  if (moodState.entries.isEmpty) return [];
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

                  // ─── Crisis Banner (if active) ──────────
                  if (crisisState.currentTier.requiresAction)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _CrisisBanner(tier: crisisState.currentTier),
                      ),
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

                  // ─── At-a-Glance Stats ───────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _GlanceRow(
                        moodState: moodState,
                        streakState: streakState,
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

                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
      ),
    );
  }
}

// ─── Maya Hero Header ─────────────────────────────────────

class _MayaHeroHeader extends StatelessWidget {
  final String greeting;
  final String emoji;
  final String name;

  const _MayaHeroHeader({
    required this.greeting,
    required this.emoji,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$greeting${name.isNotEmpty ? ', $name' : ''}',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ).animate().fadeIn(delay: 80.ms),
              ],
            ),
          ),
          _SosButton(),
        ],
      ),
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

class _MayaMessageCard extends StatelessWidget {
  final MoodState moodState;
  final StreakAchievementState streakState;

  const _MayaMessageCard({
    required this.moodState,
    required this.streakState,
  });

  String _message() {
    if (moodState.criticalAlerts.isNotEmpty) {
      return "I've noticed you might be going through a really tough time. You're not alone in this — I'm here to listen whenever you're ready.";
    }
    final today = moodState.todayEntry;
    if (today == null) {
      final h = DateTime.now().hour;
      if (h < 12) {
        return "Good morning! How are you feeling as you start your day? A quick check-in helps me understand you better and give you the right support.";
      }
      if (h < 17) {
        return "How's your afternoon going? Your wellbeing matters — let's check in on how you're feeling today so I can be there for you.";
      }
      return "How has your day been? I'd love to hear about it. Logging your mood helps me tailor my support just for you.";
    }
    if (today.moodScore <= 3) {
      return "I see today has been tough (${today.moodScore}/10). You're brave for showing up anyway. Want to talk through what's going on?";
    }
    if (today.moodScore >= 8) {
      return "You're feeling great today (${today.moodScore}/10)! 🌟 I love seeing you thriving. Let's keep this positive momentum going together!";
    }
    if (moodState.positiveAlerts.isNotEmpty) {
      return "I've been tracking your progress and your mood has been improving — you've been doing really well lately. Keep up the great work!";
    }
    if (moodState.warningAlerts.isNotEmpty) {
      return "I've noticed your mood trending down lately. Would you like to explore some coping strategies or just talk things through?";
    }
    final streak = streakState.overall?.currentStreak ?? 0;
    if (streak >= 7) {
      return "You're on a $streak-day streak — that's incredible dedication to your wellness! Your consistency is truly making a difference.";
    }
    return "I'm here whenever you need support. Whether you want to reflect, vent, or learn new coping strategies — I've always got you.";
  }

  List<String> _chips() {
    final today = moodState.todayEntry;
    if (today == null) {
      return ["I'm feeling anxious", "How to sleep better?", "I need motivation"];
    }
    if (today.moodScore <= 4) {
      return ["Help me feel better", "I'm overwhelmed", "Breathing exercises"];
    }
    if (today.moodScore >= 7) {
      return ["Celebrate my progress", "Set wellness goals", "Morning routines"];
    }
    return ["Reflect on my day", "Stress management", "Talk through feelings"];
  }

  @override
  Widget build(BuildContext context) {
    final chips = _chips();
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go(AppRoutes.chat);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                    borderRadius: BorderRadius.circular(14),
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
                    borderRadius: BorderRadius.circular(20),
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
                _message(),
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
                                borderRadius: BorderRadius.circular(20),
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
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 500.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

// ─── At-a-Glance Row ──────────────────────────────────────

class _GlanceRow extends ConsumerWidget {
  final MoodState moodState;
  final StreakAchievementState streakState;

  const _GlanceRow({required this.moodState, required this.streakState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = moodState.todayEntry;
    final overallStreak =
        streakState.overall?.currentStreak ?? moodState.currentStreakDays;
    final breakdown = moodState.wellnessBreakdown;
    final score = breakdown?.totalScore ?? 0.0;
    final band = WellnessTokens.bandFor(score);
    final manualDone = ref.watch(_completedChallengesProvider);

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

    return Row(
      children: [
        _GlanceCell(
          emoji: today != null ? MoodTokens.emojiFor(today.moodScore) : null,
          icon: today != null ? null : LucideIcons.smile,
          value: today != null ? today.moodScore.toString() : '–',
          label: 'Mood',
          color: today != null
              ? MoodTokens.colorFor(today.moodScore)
              : AppColors.textMuted,
          delay: 200,
        ),
        const SizedBox(width: 10),
        _GlanceCell(
          icon: LucideIcons.flame,
          emoji: null,
          value: overallStreak.toString(),
          label: 'Streak',
          color: overallStreak >= 7
              ? const Color(0xFFFF6B35)
              : AppColors.primary,
          suffix: overallStreak >= 7 ? '🔥' : null,
          delay: 270,
        ),
        const SizedBox(width: 10),
        _GlanceCell(
          icon: LucideIcons.activity,
          emoji: score > 0 ? WellnessTokens.emojiFor(band) : null,
          value: score > 0 ? score.toInt().toString() : '–',
          label: WellnessTokens.labelFor(band),
          color: AppColors.primary,
          delay: 340,
        ),
        const SizedBox(width: 10),
        _GlanceCell(
          icon: LucideIcons.zap,
          emoji: doneCount == 4 ? '🎉' : null,
          value: '$doneCount/4',
          label: 'Today',
          color:
              doneCount == 4 ? const Color(0xFF10B981) : AppColors.primary,
          delay: 410,
        ),
      ],
    );
  }
}

class _GlanceCell extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String? suffix;
  final String value;
  final String label;
  final Color color;
  final int delay;

  const _GlanceCell({
    required this.icon,
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    required this.delay,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 16))
            else if (icon != null)
              Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 2),
                  Text(suffix!, style: const TextStyle(fontSize: 12)),
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
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(
              delay: Duration(milliseconds: delay), duration: 400.ms)
          .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack),
    );
  }
}

// ─── Quick Actions Grid ───────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  static const _actions = [
    _QGrid(
      icon: LucideIcons.bot,
      label: 'Chat Maya',
      color: AppColors.primary,
      route: AppRoutes.chat,
      featured: true,
    ),
    _QGrid(
      icon: LucideIcons.smile,
      label: 'Log Mood',
      color: Color(0xFF06D6A0),
      route: AppRoutes.moodTracker,
    ),
    _QGrid(
      icon: LucideIcons.penLine,
      label: 'Journal',
      color: Color(0xFF8B5CF6),
      route: AppRoutes.journal,
    ),
    _QGrid(
      icon: LucideIcons.wind,
      label: 'Breathe',
      color: Color(0xFF0EA5E9),
      route: AppRoutes.mindfulness,
    ),
    _QGrid(
      icon: LucideIcons.chartBar,
      label: 'Analytics',
      color: Color(0xFFF59E0B),
      route: AppRoutes.moodAnalytics,
    ),
    _QGrid(
      icon: LucideIcons.users,
      label: 'Community',
      color: Color(0xFFFF6B6B),
      route: AppRoutes.community,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(context, _actions.take(3).toList(), 0),
        const SizedBox(height: 10),
        _buildRow(context, _actions.skip(3).toList(), 3),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<_QGrid> row, int startDelay) {
    return Row(
      children: row.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: e.key < row.length - 1 ? 10 : 0),
            child:
                _QGridCard(action: e.value, delay: (startDelay + e.key) * 60),
          ),
        );
      }).toList(),
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
            borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
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
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 300 + delay), duration: 350.ms)
        .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            curve: Curves.easeOutBack);
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
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
    ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.05, end: 0);
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
        borderRadius: BorderRadius.circular(20),
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
                          borderRadius: BorderRadius.circular(14),
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

          // ── Breakdown bars ──
          if (breakdown != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            ...[
              ('Mood', breakdown.moodComponent, const Color(0xFF06D6A0)),
              ('Consistency', breakdown.consistencyComponent, AppColors.primary),
              ('Sleep', breakdown.sleepComponent, const Color(0xFF8B5CF6)),
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
                      borderRadius: BorderRadius.circular(100),
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
    )
        .animate()
        .fadeIn(delay: 350.ms, duration: 500.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
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
        InsightType.pattern => const Color(0xFF8B5CF6),
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
            if (moodState.entries.length < 7)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
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
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final ins = insights[i];
                return _InsightAccentCard(
                  insight: ins,
                  color: _colorFor(ins.type),
                  icon: _iconFor(ins.type),
                ).animate().fadeIn(delay: (200 + i * 80).ms, duration: 350.ms);
              },
            ),
          ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }
}

class _InsightAccentCard extends StatelessWidget {
  final WellnessInsight insight;
  final Color color;
  final IconData icon;

  const _InsightAccentCard({
    required this.insight,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left accent bar
          Container(width: 4, color: color),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          insight.title,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      insight.body,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
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
                  'Log ${7 - entryCount.clamp(0, 7)} more moods to see personalized patterns and AI-powered insights.',
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
  static const _challenges = [
    _ChallengeData(
      id: 'mood',
      icon: LucideIcons.smile,
      title: 'Log Your Mood',
      subtitle: 'Check in · Track how you feel today',
      category: 'Mood',
      categoryColor: AppColors.primary,
      xp: 50,
      route: AppRoutes.moodTracker,
    ),
    _ChallengeData(
      id: 'journal',
      icon: LucideIcons.penLine,
      title: 'Write in Your Journal',
      subtitle: '3 min · Reflect on your day',
      category: 'Journal',
      categoryColor: Color(0xFF8B5CF6),
      xp: 75,
      route: AppRoutes.journalEntry,
    ),
    _ChallengeData(
      id: 'breathe',
      icon: LucideIcons.wind,
      title: '4-7-8 Breathing',
      subtitle: '5 min · Calm your nervous system',
      category: 'Breathe',
      categoryColor: Color(0xFF0EA5E9),
      xp: 60,
      route: AppRoutes.breathing,
    ),
    _ChallengeData(
      id: 'chat',
      icon: LucideIcons.bot,
      title: 'Talk with Maya',
      subtitle: "Chat · Share what's on your mind",
      category: 'AI Chat',
      categoryColor: Color(0xFF06D6A0),
      xp: 40,
      route: AppRoutes.chat,
    ),
    _ChallengeData(
      id: 'analytics',
      icon: LucideIcons.chartBar,
      title: 'Review Your Progress',
      subtitle: 'Analytics · See your mood trends',
      category: 'Insights',
      categoryColor: AppColors.tertiary,
      xp: 30,
      route: AppRoutes.moodAnalytics,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodState = ref.watch(moodProvider);
    final streakState = ref.watch(streakProvider);
    final manualDone = ref.watch(_completedChallengesProvider);

    final completionMap = {
      'mood': moodState.todayEntry != null,
      'journal':
          moodState.journalEntries.any((e) => _isToday(e.createdAt)),
      'breathe':
          (streakState.streak(StreakType.mindfulness)?.completedToday ??
                  false) ||
              manualDone.contains('breathe'),
      'chat':
          (streakState.streak(StreakType.chatSession)?.completedToday ??
                  false) ||
              manualDone.contains('chat'),
      'analytics': manualDone.contains('analytics'),
    };

    final completedCount =
        completionMap.values.where((b) => b).length;
    final totalXp =
        _challenges.fold(0, (sum, c) => sum + c.xp);
    final earnedXp = _challenges
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
                borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(100),
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

        // ── Challenge tiles ──
        ...List.generate(_challenges.length, (i) {
          final c = _challenges[i];
          final isDone = completionMap[c.id] ?? false;
          final canManualComplete = c.id != 'mood' && c.id != 'journal';
          return _ChallengeTile(
            data: c,
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
            onTap: () {
              if (c.route != null) context.push(c.route!);
            },
          );
        }),
      ],
    ).animate().fadeIn(delay: 550.ms, duration: 400.ms);
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
        borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(10),
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
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
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
  final String? route;

  const _ChallengeData({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.categoryColor,
    required this.xp,
    this.route,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.success.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDone
                  ? AppColors.success.withOpacity(0.3)
                  : const Color(0xFFE8EDF2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success.withOpacity(0.12)
                      : data.categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDone ? LucideIcons.circleCheck : data.icon,
                  color: isDone ? AppColors.success : data.categoryColor,
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
                      borderRadius: BorderRadius.circular(20),
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
                          borderRadius: BorderRadius.circular(8),
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
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
