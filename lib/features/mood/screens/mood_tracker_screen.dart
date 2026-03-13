import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';

class MoodTrackerScreen extends ConsumerStatefulWidget {
  const MoodTrackerScreen({super.key});

  @override
  ConsumerState<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends ConsumerState<MoodTrackerScreen> {
  int _selectedMood = 0;
  final List<String> _selectedEmotions = [];
  final List<String> _selectedActivities = [];
  final _noteCtrl = TextEditingController();
  double _sleepHours = 7;
  int _step = 0;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _moodColor =>
      _selectedMood > 0 ? MoodTokens.colorFor(_selectedMood) : AppColors.primary;

  Future<void> _save() async {
    if (_selectedMood == 0) return;
    final success = await ref.read(moodProvider.notifier).logMood(
          moodScore: _selectedMood,
          emotions: _selectedEmotions,
          activities: _selectedActivities,
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          sleepHours: _sleepHours,
        );
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      ref.read(streakProvider.notifier).recordActivity(StreakType.moodLogging);
      _showSuccess();
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.moodEmojis[_selectedMood],
                      style: const TextStyle(fontSize: 64))
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                'Mood Logged!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MoodTokens.colorFor(_selectedMood),
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Feeling ${AppStrings.moodLabels[_selectedMood].toLowerCase()} today. '
                'Thank you for checking in with yourself.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go(AppRoutes.moodAnalytics);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('View Analytics',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go(AppRoutes.chat);
                  },
                  icon: const Icon(LucideIcons.messageCircle, size: 15),
                  label: const Text('Talk to Maya about it',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go(AppRoutes.home);
                },
                child: const Text('Back to Home',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodProvider);
    final color = _moodColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF030F0E),
        body: Stack(
          children: [
            // ── Animated mood glow ──────────────────────
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 1.0,
                    colors: [
                      color.withValues(alpha: 0.24),
                      const Color(0xFF030F0E),
                    ],
                  ),
                ),
              ),
            ),

            // ── Main column ─────────────────────────────
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_step > 0) {
                              setState(() => _step--);
                            } else {
                              context.pop();
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.arrowLeft,
                                color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (_step + 1) / 4,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.09),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Step ${_step + 1} of 4',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.36),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              ['Mood', 'Emotions', 'Activities',
                                  'Details'][_step],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Step content ─────────────────────
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _step == 0
                            ? _Step1Mood(
                                selectedMood: _selectedMood,
                                onMoodSelected: (m) {
                                  setState(() => _selectedMood = m);
                                  HapticFeedback.selectionClick();
                                },
                              )
                            : _ContentCard(
                                child: [
                                  const SizedBox(), // step 0 handled above
                                  _Step2Emotions(
                                    selectedEmotions: _selectedEmotions,
                                    onToggle: (e) {
                                      setState(() {
                                        if (_selectedEmotions.contains(e)) {
                                          _selectedEmotions.remove(e);
                                        } else if (_selectedEmotions.length <
                                            5) {
                                          _selectedEmotions.add(e);
                                        }
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                  _Step3Activities(
                                    selectedActivities: _selectedActivities,
                                    onToggle: (a) {
                                      setState(() {
                                        if (_selectedActivities.contains(a)) {
                                          _selectedActivities.remove(a);
                                        } else {
                                          _selectedActivities.add(a);
                                        }
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                  _Step4Details(
                                    noteCtrl: _noteCtrl,
                                    sleepHours: _sleepHours,
                                    onSleepChanged: (h) =>
                                        setState(() => _sleepHours = h),
                                  ),
                                ][_step],
                              ),
                      ),
                    ),
                  ),

                  // ── Bottom nav ───────────────────────
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          if (_step > 0) ...[
                            GestureDetector(
                              onTap: () => setState(() => _step--),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.10)),
                                ),
                                child: const Icon(LucideIcons.arrowLeft,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: GestureDetector(
                              onTap: (_selectedMood > 0 || _step > 0)
                                  ? (_step < 3
                                      ? () => setState(() => _step++)
                                      : _save)
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 52,
                                decoration: BoxDecoration(
                                  color: (_selectedMood > 0 || _step > 0)
                                      ? color
                                      : Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: (_selectedMood > 0 || _step > 0)
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.35),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: moodState.isLoading && _step == 3
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : Text(
                                          _step < 3
                                              ? 'Continue'
                                              : 'Save Mood',
                                          style: TextStyle(
                                            color: (_selectedMood > 0 ||
                                                    _step > 0)
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.28),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

// ─── White card wrapper for steps 2-4 ────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  final Widget child;
  const _ContentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: child,
      ),
    );
  }
}

// ─── Step 1: Mood carousel ────────────────────────────────────────────────────

class _Step1Mood extends StatefulWidget {
  final int selectedMood;
  final ValueChanged<int> onMoodSelected;

  const _Step1Mood({
    required this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  State<_Step1Mood> createState() => _Step1MoodState();
}

class _Step1MoodState extends State<_Step1Mood> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    final page = widget.selectedMood > 0 ? widget.selectedMood - 1 : 4;
    _ctrl = PageController(viewportFraction: 0.25, initialPage: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedMood;
    final color =
        selected > 0 ? MoodTokens.colorFor(selected) : AppColors.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Big emoji
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(
                parent: anim, curve: Curves.elasticOut),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            selected > 0 ? AppStrings.moodEmojis[selected] : '✨',
            key: ValueKey(selected),
            style: const TextStyle(fontSize: 88),
          ),
        ),
        const SizedBox(height: 10),

        // Score + label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(selected),
            children: [
              if (selected > 0)
                Text(
                  '$selected / 10',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: color,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                selected > 0
                    ? AppStrings.moodLabels[selected]
                    : 'Swipe to choose your mood',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected > 0
                      ? Colors.white.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // Horizontal mood carousel
        SizedBox(
          height: 104,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => widget.onMoodSelected(i + 1),
            itemCount: 10,
            itemBuilder: (_, i) {
              final score = i + 1;
              final isSelected = selected == score;
              final moodColor = MoodTokens.colorFor(score);
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) {
                  double scale = 1.0;
                  if (_ctrl.position.hasContentDimensions) {
                    final page = _ctrl.page ?? i.toDouble();
                    scale =
                        (1.0 - (page - i).abs() * 0.22).clamp(0.72, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: GestureDetector(
                  onTap: () => _ctrl.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? moodColor.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: isSelected
                                ? moodColor
                                : Colors.white.withValues(alpha: 0.13),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: moodColor.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    spreadRadius: 0,
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.moodEmojis[score],
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? moodColor
                              : Colors.white.withValues(alpha: 0.26),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Endpoints
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 · Terrible',
                style: TextStyle(
                  fontSize: 11,
                  color: MoodTokens.colorFor(1),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '10 · Amazing',
                style: TextStyle(
                  fontSize: 11,
                  color: MoodTokens.colorFor(10),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Emotions (4-category tabbed grid) ────────────────────────────────

class _EmotionCategory {
  final String label;
  final String emoji;
  final Color color;
  final List<String> emotions;
  const _EmotionCategory({
    required this.label,
    required this.emoji,
    required this.color,
    required this.emotions,
  });
}

const _kEmotionCategories = [
  _EmotionCategory(
    label: 'Positive',
    emoji: '✨',
    color: Color(0xFF06D6A0),
    emotions: [
      'Happy', 'Grateful', 'Calm', 'Hopeful', 'Proud',
      'Confident', 'Excited', 'Loved', 'Peaceful', 'Content',
      'Energized', 'Inspired', 'Motivated', 'Joyful',
    ],
  ),
  _EmotionCategory(
    label: 'Difficult',
    emoji: '🌧',
    color: Color(0xFFFF6B6B),
    emotions: [
      'Anxious', 'Sad', 'Overwhelmed', 'Frustrated', 'Scared',
      'Angry', 'Lonely', 'Hopeless', 'Numb', 'Ashamed',
      'Irritated', 'Confused', 'Stressed', 'Drained', 'Jealous',
      'Helpless', 'Insecure',
    ],
  ),
  _EmotionCategory(
    label: 'Physical',
    emoji: '⚡',
    color: Color(0xFF0EA5E9),
    emotions: [
      'Tired', 'Restless', 'Tense', 'Sick', 'Sluggish',
      'Wired', 'Low Energy', 'Headachy', 'Jittery',
    ],
  ),
  _EmotionCategory(
    label: 'Social',
    emoji: '🤝',
    color: Color(0xFFF59E0B),
    emotions: [
      'Supported', 'Understood', 'Included', 'Connected',
      'Misunderstood', 'Disconnected', 'Pressured', 'Judged',
      'Excluded', 'Invisible',
    ],
  ),
];

class _Step2Emotions extends StatefulWidget {
  final List<String> selectedEmotions;
  final ValueChanged<String> onToggle;

  const _Step2Emotions({
    required this.selectedEmotions,
    required this.onToggle,
  });

  @override
  State<_Step2Emotions> createState() => _Step2EmotionsState();
}

class _Step2EmotionsState extends State<_Step2Emotions>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl =
        TabController(length: _kEmotionCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name your emotions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.tokenTextPrimary,
                      ),
                    ),
                    Text(
                      'Select up to 5 that feel true right now.',
                      style: TextStyle(
                          fontSize: 13, color: context.tokenTextMuted),
                    ),
                  ],
                ),
              ),
              if (widget.selectedEmotions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${widget.selectedEmotions.length}/5',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          indicator: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          ),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          dividerColor: Colors.transparent,
          tabs: _kEmotionCategories
              .map((c) => Tab(text: '${c.emoji} ${c.label}'))
              .toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _kEmotionCategories.map((cat) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
                child: Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: cat.emotions.map((emotion) {
                    final isSel =
                        widget.selectedEmotions.contains(emotion);
                    final canAdd = widget.selectedEmotions.length < 5;
                    return GestureDetector(
                      onTap: () {
                        if (isSel || canAdd) widget.onToggle(emotion);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md, vertical: 9),
                        decoration: BoxDecoration(
                          color: isSel
                              ? cat.color.withValues(alpha: 0.12)
                              : context.tokenSurface,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: isSel
                                ? cat.color
                                : (!canAdd
                                    ? context.tokenBorder
                                        .withValues(alpha: 0.4)
                                    : context.tokenBorder),
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSel) ...[
                              Icon(LucideIcons.check,
                                  size: 11, color: cat.color),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              emotion,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSel
                                    ? cat.color
                                    : (!canAdd
                                        ? context.tokenTextMuted
                                            .withValues(alpha: 0.5)
                                        : context.tokenTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
        if (widget.selectedEmotions.isNotEmpty)
          Container(
            color: context.tokenSurface,
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xs),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.selectedEmotions.map((e) {
                return GestureDetector(
                  onTap: () => widget.onToggle(e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            )),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.x,
                            size: 10, color: AppColors.primary),
                      ],
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

// ─── Step 3: Activities ───────────────────────────────────────────────────────

class _Step3Activities extends StatelessWidget {
  final List<String> selectedActivities;
  final ValueChanged<String> onToggle;

  const _Step3Activities({
    required this.selectedActivities,
    required this.onToggle,
  });

  static const _activities = [
    {'name': 'Studying', 'emoji': '📚'},
    {'name': 'Exercise', 'emoji': '🏋️'},
    {'name': 'Socializing', 'emoji': '🤝'},
    {'name': 'Gaming', 'emoji': '🎮'},
    {'name': 'Reading', 'emoji': '📖'},
    {'name': 'Music', 'emoji': '🎵'},
    {'name': 'Nature', 'emoji': '🌿'},
    {'name': 'Cooking', 'emoji': '🍳'},
    {'name': 'Sleep', 'emoji': '😴'},
    {'name': 'Work', 'emoji': '💼'},
    {'name': 'Family', 'emoji': '👨‍👩‍👧'},
    {'name': 'Dating', 'emoji': '❤️'},
    {'name': 'Meditation', 'emoji': '🧘'},
    {'name': 'Art', 'emoji': '🎨'},
    {'name': 'Sports', 'emoji': '⚽'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What have you been doing?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokenTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track activities to find mood patterns.',
            style:
                TextStyle(fontSize: 14, color: context.tokenTextMuted),
          ),
          const SizedBox(height: Spacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 1.4,
            ),
            itemCount: _activities.length,
            itemBuilder: (_, i) {
              final activity = _activities[i];
              final name = activity['name']!;
              final isSelected = selectedActivities.contains(name);
              return GestureDetector(
                onTap: () => onToggle(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : context.tokenSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : context.tokenBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(activity['emoji']!,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : context.tokenTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Details ──────────────────────────────────────────────────────────

class _Step4Details extends StatelessWidget {
  final TextEditingController noteCtrl;
  final double sleepHours;
  final ValueChanged<double> onSleepChanged;

  const _Step4Details({
    required this.noteCtrl,
    required this.sleepHours,
    required this.onSleepChanged,
  });

  String get _sleepFeedback {
    if (sleepHours < 5) return 'Not enough — aim for 7-9 hrs';
    if (sleepHours < 7) return 'Could be better';
    if (sleepHours <= 9) return 'Perfect range!';
    return 'A bit long — 7-9 hrs is ideal';
  }

  Color _sleepColor(BuildContext context) {
    if (sleepHours < 5) return AppColors.error;
    if (sleepHours < 7) return const Color(0xFFFFD166);
    if (sleepHours <= 9) return const Color(0xFF06D6A0);
    return const Color(0xFF4ECDC4);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A few more details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokenTextPrimary,
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // Sleep tracker
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: context.tokenSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.tokenBorder),
              boxShadow: AppShadow.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.moon,
                        size: 20, color: AppColors.primaryLight),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      'Sleep Duration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.tokenTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      sleepHours.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _sleepColor(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('hrs',
                        style: TextStyle(
                            fontSize: 16,
                            color: context.tokenTextMuted)),
                    const SizedBox(width: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: _sleepColor(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        _sleepFeedback,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _sleepColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _sleepColor(context),
                    inactiveTrackColor:
                        _sleepColor(context).withValues(alpha: 0.2),
                    thumbColor: _sleepColor(context),
                    overlayColor:
                        _sleepColor(context).withValues(alpha: 0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: sleepHours,
                    min: 0,
                    max: 12,
                    divisions: 24,
                    onChanged: onSleepChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 hrs',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.tokenTextMuted)),
                    Text('12 hrs',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.tokenTextMuted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.md),

          // Note
          Container(
            decoration: BoxDecoration(
              color: context.tokenSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.tokenBorder),
              boxShadow: AppShadow.sm,
            ),
            child: TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Add a note (optional)',
                hintText: "What's on your mind? Any context for this mood?",
                hintStyle: TextStyle(
                    fontSize: 14, color: context.tokenTextMuted),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Icon(LucideIcons.penLine,
                      size: 20, color: context.tokenTextMuted),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(Spacing.md),
              ),
              style: TextStyle(
                  fontSize: 15, color: context.tokenTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
