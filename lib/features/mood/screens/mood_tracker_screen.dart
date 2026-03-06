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
import '../../../shared/widgets/custom_button.dart';

class MoodTrackerScreen extends ConsumerStatefulWidget {
  const MoodTrackerScreen({super.key});

  @override
  ConsumerState<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends ConsumerState<MoodTrackerScreen> {
  int _selectedMood = 0;
  final List<String> _selectedEmotions = [];
  final List<String> _selectedActivities = [];
  final TextEditingController _noteCtrl = TextEditingController();
  double _sleepHours = 7;
  int _step = 0; // 0=mood, 1=emotions, 2=activities, 3=details

  static const _stepLabels = [
    'Mood',
    'Emotions',
    'Activities',
    'Details',
  ];

  static const _stepQuestions = [
    'How are you feeling?',
    'Name your emotions',
    'What have you been doing?',
    'Final details',
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedMood == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your mood first'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.lgAll),
        ),
      );
      return;
    }

    final success = await ref.read(moodProvider.notifier).logMood(
          moodScore: _selectedMood,
          emotions: _selectedEmotions,
          activities: _selectedActivities,
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          sleepHours: _sleepHours,
        );

    if (success && mounted) {
      HapticFeedback.mediumImpact();
      // Record streak activity
      ref
          .read(streakProvider.notifier)
          .recordActivity(StreakType.moodLogging);
      _showSuccess();
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.moodEmojis[_selectedMood],
                style: const TextStyle(fontSize: 64),
              ).animate().scale(
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: Spacing.md),
              Text(
                'Mood Logged!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MoodTokens.colorFor(_selectedMood),
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: Spacing.xs),
              Text(
                'Feeling ${AppStrings.moodLabels[_selectedMood].toLowerCase()} today. '
                'Thank you for checking in with yourself.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(AppRoutes.moodAnalytics);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: Spacing.sm),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.lgAll),
                  ),
                  child: const Text(
                    'View Analytics',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(AppRoutes.home);
                },
                child: Text(
                  'Back to Home',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
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
    final moodColor = _selectedMood > 0
        ? MoodTokens.colorFor(_selectedMood)
        : AppColors.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.tokenBackground,
        body: Column(
          children: [
            // ─── Gradient Header ──────────────────────
            AnimatedContainer(
              duration: 400.ms,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _selectedMood > 0
                      ? [
                          moodColor.withOpacity(0.85),
                          moodColor,
                        ]
                      : [
                          AppColors.primaryDark,
                          AppColors.primary,
                        ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.xs, Spacing.lg, Spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mood Check-in',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _stepQuestions[_step],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (moodState.entries.isNotEmpty)
                            GestureDetector(
                              onTap: () => context.go(AppRoutes.moodAnalytics),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.sm, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: AppRadius.pillAll,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Analytics',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(LucideIcons.arrowRight,
                                        size: 12, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Spacing.md),

                      // Step progress bars
                      Row(
                        children: List.generate(4, (i) {
                          return Expanded(
                            child: AnimatedContainer(
                              duration: 300.ms,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.pillAll,
                                color: i <= _step
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Step ${_step + 1} of 4',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            _stepLabels[_step],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Step Content ─────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: 250.ms,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: [
                    _Step1Mood(
                      selectedMood: _selectedMood,
                      onMoodSelected: (m) {
                        setState(() => _selectedMood = m);
                        HapticFeedback.selectionClick();
                      },
                    ),
                    _Step2Emotions(
                      selectedEmotions: _selectedEmotions,
                      onToggle: (e) {
                        setState(() {
                          if (_selectedEmotions.contains(e)) {
                            _selectedEmotions.remove(e);
                          } else if (_selectedEmotions.length < 5) {
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
                      onSleepChanged: (h) => setState(() => _sleepHours = h),
                    ),
                  ][_step],
                ),
              ),
            ),

            // ─── Navigation ───────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.lg, 0),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        flex: 1,
                        child: SecondaryButton(
                          label: 'Back',
                          onTap: () => setState(() => _step--),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                    ],
                    Expanded(
                      flex: 2,
                      child: _step < 3
                          ? PrimaryButton(
                              label: 'Continue',
                              onTap: _selectedMood > 0 || _step > 0
                                  ? () => setState(() => _step++)
                                  : null,
                            )
                          : PrimaryButton(
                              label: 'Save Mood',
                              onTap: _save,
                              isLoading: moodState.isLoading,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Mood Selection ───────────────────────────────

class _Step1Mood extends StatelessWidget {
  final int selectedMood;
  final ValueChanged<int> onMoodSelected;

  const _Step1Mood({
    required this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        children: [
          // Big mood display
          AnimatedSwitcher(
            duration: 250.ms,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              selectedMood > 0 ? AppStrings.moodEmojis[selectedMood] : '🌟',
              key: ValueKey(selectedMood),
              style: const TextStyle(fontSize: 80),
            ),
          ),

          const SizedBox(height: Spacing.xs),

          AnimatedSwitcher(
            duration: 200.ms,
            child: Text(
              selectedMood > 0
                  ? AppStrings.moodLabels[selectedMood]
                  : 'Select your mood',
              key: ValueKey(selectedMood),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: selectedMood > 0
                    ? MoodTokens.colorFor(selectedMood)
                    : context.tokenTextMuted,
              ),
            ),
          ),

          const SizedBox(height: Spacing.xl),

          // Mood Grid (2x5)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 0.85,
            ),
            itemCount: 10,
            itemBuilder: (_, i) {
              final score = i + 1;
              final isSelected = selectedMood == score;
              final moodColor = MoodTokens.colorFor(score);

              return GestureDetector(
                onTap: () => onMoodSelected(score),
                child: AnimatedContainer(
                  duration: 200.ms,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? moodColor.withOpacity(0.12)
                        : context.tokenSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: isSelected ? moodColor : context.tokenBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: moodColor.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.15 : 1.0,
                        duration: 200.ms,
                        child: Text(
                          AppStrings.moodEmojis[score],
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? moodColor
                              : context.tokenTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: Spacing.md),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 — Terrible',
                style: TextStyle(
                  fontSize: 12,
                  color: MoodTokens.colorFor(1),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '10 — Amazing',
                style: TextStyle(
                  fontSize: 12,
                  color: MoodTokens.colorFor(10),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Emotions ─────────────────────────────────────

class _Step2Emotions extends StatelessWidget {
  final List<String> selectedEmotions;
  final ValueChanged<String> onToggle;

  const _Step2Emotions({
    required this.selectedEmotions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What emotions are you feeling?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokenTextPrimary,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Select up to 5 emotions that resonate.',
            style: TextStyle(fontSize: 14, color: context.tokenTextMuted),
          ),

          if (selectedEmotions.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.check,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    '${selectedEmotions.length} selected (max 5)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Spacing.lg),

          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: AppStrings.emotionTags.map((emotion) {
              final isSelected = selectedEmotions.contains(emotion);
              final color =
                  AppColors.emotionColors[emotion.toLowerCase()] ??
                      AppColors.primary;
              return GestureDetector(
                onTap: () => onToggle(emotion),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.12)
                        : context.tokenSurface,
                    borderRadius: AppRadius.pillAll,
                    border: Border.all(
                      color: isSelected ? color : context.tokenBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    emotion,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color:
                          isSelected ? color : context.tokenTextSecondary,
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

// ─── Step 3: Activities ───────────────────────────────────

class _Step3Activities extends StatelessWidget {
  final List<String> selectedActivities;
  final ValueChanged<String> onToggle;

  const _Step3Activities({
    required this.selectedActivities,
    required this.onToggle,
  });

  static const List<Map<String, String>> _activities = [
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
          const SizedBox(height: Spacing.xs),
          Text(
            'Track activities to find mood patterns.',
            style: TextStyle(fontSize: 14, color: context.tokenTextMuted),
          ),
          const SizedBox(height: Spacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  duration: 200.ms,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : context.tokenSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : context.tokenBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(activity['emoji']!,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 3),
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

// ─── Step 4: Details ──────────────────────────────────────

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
              borderRadius: AppRadius.xlAll,
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
                      '${sleepHours.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _sleepColor(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'hrs',
                      style: TextStyle(
                        fontSize: 16,
                        color: context.tokenTextMuted,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: _sleepColor(context).withOpacity(0.1),
                        borderRadius: AppRadius.pillAll,
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
                        _sleepColor(context).withOpacity(0.2),
                    thumbColor: _sleepColor(context),
                    overlayColor:
                        _sleepColor(context).withOpacity(0.1),
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
                            fontSize: 11, color: context.tokenTextMuted)),
                    Text('12 hrs',
                        style: TextStyle(
                            fontSize: 11, color: context.tokenTextMuted)),
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
              borderRadius: AppRadius.xlAll,
              border: Border.all(color: context.tokenBorder),
              boxShadow: AppShadow.sm,
            ),
            child: TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Add a note (optional)',
                hintText:
                    "What's on your mind? Any context for this mood?",
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
