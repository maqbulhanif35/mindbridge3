import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mood_model.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';

// ─── Data Models ──────────────────────────────────────────

class _MoodData {
  final int score;
  final String emoji;
  final String label;
  final String sublabel;
  final Color color;
  final Color bg;

  const _MoodData({
    required this.score,
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bg,
  });
}

class _EmotionData {
  final String emoji;
  final String label;
  const _EmotionData(this.emoji, this.label);
}

class _ActivityData {
  final IconData icon;
  final String label;
  const _ActivityData(this.icon, this.label);
}

// ─── Constants ────────────────────────────────────────────

const _kMoods = [
  _MoodData(score: 2, emoji: '😭', label: 'Terrible', sublabel: 'Really struggling right now', color: Color(0xFFFF4757), bg: Color(0xFFFFF0F0)),
  _MoodData(score: 4, emoji: '😟', label: 'Low', sublabel: "Not great today", color: Color(0xFFFF8C42), bg: Color(0xFFFFF4EE)),
  _MoodData(score: 5, emoji: '😐', label: 'Okay', sublabel: 'Just getting by', color: Color(0xFFFFBB00), bg: Color(0xFFFFFBEE)),
  _MoodData(score: 7, emoji: '😊', label: 'Good', sublabel: 'Feeling pretty decent', color: Color(0xFF4ECDC4), bg: Color(0xFFEEFBFA)),
  _MoodData(score: 9, emoji: '🤩', label: 'Amazing', sublabel: 'On top of the world!', color: Color(0xFF06D6A0), bg: Color(0xFFEEFFF9)),
];

const _kEmotions = [
  _EmotionData('😰', 'Anxious'),
  _EmotionData('😤', 'Stressed'),
  _EmotionData('😢', 'Sad'),
  _EmotionData('😔', 'Lonely'),
  _EmotionData('😠', 'Angry'),
  _EmotionData('😵', 'Overwhelmed'),
  _EmotionData('😨', 'Scared'),
  _EmotionData('😞', 'Hopeless'),
  _EmotionData('😌', 'Calm'),
  _EmotionData('😊', 'Happy'),
  _EmotionData('🙏', 'Grateful'),
  _EmotionData('⚡', 'Energized'),
  _EmotionData('🎯', 'Focused'),
  _EmotionData('🌟', 'Hopeful'),
  _EmotionData('❤️', 'Loved'),
  _EmotionData('🎉', 'Excited'),
  _EmotionData('🤔', 'Confused'),
  _EmotionData('😴', 'Tired'),
  _EmotionData('😶', 'Numb'),
  _EmotionData('💪', 'Proud'),
  _EmotionData('🌸', 'Content'),
  _EmotionData('✨', 'Inspired'),
  _EmotionData('😬', 'Nervous'),
  _EmotionData('😑', 'Bored'),
];

const _kActivities = [
  _ActivityData(LucideIcons.bookOpen, 'Studying'),
  _ActivityData(LucideIcons.dumbbell, 'Exercise'),
  _ActivityData(LucideIcons.moon, 'Resting'),
  _ActivityData(LucideIcons.users, 'Socializing'),
  _ActivityData(LucideIcons.briefcase, 'Work/Class'),
  _ActivityData(LucideIcons.squarePen, 'Journaling'),
  _ActivityData(LucideIcons.brain, 'Meditation'),
  _ActivityData(LucideIcons.music2, 'Music'),
  _ActivityData(LucideIcons.bookmarkCheck, 'Reading'),
  _ActivityData(LucideIcons.map, 'Walking'),
  _ActivityData(LucideIcons.monitor, 'Gaming'),
  _ActivityData(LucideIcons.flame, 'Cooking'),
  _ActivityData(LucideIcons.heart, 'Self-care'),
  _ActivityData(LucideIcons.messageCircle, 'Therapy'),
  _ActivityData(LucideIcons.sun, 'Outdoors'),
  _ActivityData(LucideIcons.smartphone, 'Screen time'),
];

const _kSleepOpts = <double>[4, 5, 6, 7, 8, 9];

const _kPrompts = [
  "What's on my mind...",
  "I'm grateful for...",
  "Today's challenge was...",
];

// ─── Screen ────────────────────────────────────────────────

class MoodTrackerScreen extends ConsumerStatefulWidget {
  const MoodTrackerScreen({super.key});

  @override
  ConsumerState<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends ConsumerState<MoodTrackerScreen> {
  int _step = 0;
  int _moodIdx = -1;
  final List<String> _emotions = [];
  final List<String> _activities = [];
  double _sleepHours = 7;
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;

  late final ConfettiController _confetti;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  _MoodData? get _preset => _moodIdx >= 0 ? _kMoods[_moodIdx] : null;
  Color get _accentColor => _preset?.color ?? AppColors.primary;
  Color get _bgTop => _preset?.bg ?? const Color(0xFFF5F7FA);

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.jumpTo(
      step.toDouble(),
      // duration: const Duration(milliseconds: 380),
      // curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    final preset = _preset;
    if (preset == null) return;
    setState(() => _isSaving = true);
    final success = await ref.read(moodProvider.notifier).logMood(
          moodScore: preset.score,
          emotions: _emotions,
          activities: _activities,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          sleepHours: _sleepHours,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      HapticFeedback.mediumImpact();
      ref.read(streakProvider.notifier).recordActivity(StreakType.moodLogging);
      _confetti.play();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _showSuccess(preset);
    }
  }

  void _showSuccess(_MoodData preset) {
    final emotionSummary = _emotions.isNotEmpty
        ? _emotions.take(3).join(', ')
        : null;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadow.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: preset.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(preset.emoji, style: const TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Check-in saved!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You're feeling ${preset.label.toLowerCase()} today.${emotionSummary != null ? '\n$emotionSummary.' : ''}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: preset.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Wellness score: ${preset.score}/10 · Sleep: ${_sleepHours >= 9 ? "9h+" : "${_sleepHours.toInt()}h"}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: preset.color,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go(AppRoutes.moodAnalytics);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Insights',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go(AppRoutes.home);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: preset.color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14),
                      ),
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

  @override
  Widget build(BuildContext context) {
    // One mood log per day — if already logged, show the "done" screen
    final todayEntry = ref.watch(moodProvider).todayEntry;
    if (todayEntry != null) {
      return _AlreadyLoggedView(entry: todayEntry);
    }

    return Stack(
      children: [
        // Animated gradient background
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, Colors.white, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStepMood(),
                      _buildStepEmotions(),
                      _buildStepActivities(),
                      _buildStepBodyNote(),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
        // Confetti burst
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 35,
            gravity: 0.35,
            colors: const [
              AppColors.primary,
              Color(0xFFFF6B6B),
              Color(0xFFFFD166),
              Color(0xFF06D6A0),
              Color(0xFF4ECDC4),
              Color(0xFFF59E0B),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step > 0) {
                _goTo(_step - 1);
              } else {
                HapticFeedback.lightImpact();
                context.go(AppRoutes.home);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadow.xs,
              ),
              child: Icon(
                _step > 0 ? LucideIcons.arrowLeft : LucideIcons.x,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Progress bars
          Expanded(
            child: Row(
              children: List.generate(4, (i) {
                final isDone = i < _step;
                final isActive = i == _step;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    height: 5,
                    margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                    decoration: BoxDecoration(
                      color: (isDone || isActive)
                          ? _accentColor
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Step ${_step + 1} of 4',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 0: Mood ─────────────────────────────────────────

  Widget _buildStepMood() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'How are you feeling\nright now?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 36),

          // Big animated emoji
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
           // switchInCurve: Curves.elasticOut,
            //switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              _preset?.emoji ?? '🌀',
              key: ValueKey(_moodIdx),
              style: const TextStyle(fontSize: 88),
            ),
          ),
          const SizedBox(height: 14),

          // Label + sublabel
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(_moodIdx),
              children: [
                Text(
                  _preset?.label ?? 'Select a mood',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _preset?.sublabel ?? 'Tap a face to get started',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // 5 mood face cards
          Row(
            children: List.generate(_kMoods.length, (i) {
              final mood = _kMoods[i];
              final isSelected = _moodIdx == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _moodIdx = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                  //  curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? mood.color.withValues(alpha: 0.13)
                          : Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? mood.color : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: mood.color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5))]
                          : AppShadow.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.22 : 1.0,
                          duration: const Duration(milliseconds: 260),
                         // curve: Curves.easeOutBack,
                          child: Text(mood.emoji, style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mood.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected ? mood.color : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          // Score badge
          const SizedBox(height: 24),
          AnimatedOpacity(
            opacity: _moodIdx >= 0 ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: _moodIdx >= 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.trendingUp, size: 14, color: _accentColor),
                        const SizedBox(width: 7),
                        Text(
                          'Wellness score: ${_preset!.score}/10',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _accentColor,
                          ),
                        ),
                      ],
                    ),
                  )//.animate().fadeIn().scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack)
                : const SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Emotions ─────────────────────────────────────

  Widget _buildStepEmotions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tag your emotions',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),//.animate().fadeIn(delay: 60.ms).slideX(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 4),
              const Text(
                'Select all that apply — no wrong answers',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _emotions.isNotEmpty
                    ? Text(
                        '${_emotions.length} selected',
                        key: const ValueKey('count'),
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _accentColor,
                        ),
                      )
                    : const SizedBox(height: 16, key: ValueKey('empty')),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.88,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _kEmotions.length,
            itemBuilder: (_, i) {
              final e = _kEmotions[i];
              final isSelected = _emotions.contains(e.label);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _emotions.remove(e.label);
                    } else {
                      _emotions.add(e.label);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 210),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentColor.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _accentColor : const Color(0xFFE8EDF2),
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected ? [] : AppShadow.xs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 5),
                      Text(
                        e.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _accentColor : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              // ).animate(delay: Duration(milliseconds: i * 18)).fadeIn(duration: 250.ms).scale(
              //       begin: const Offset(0.82, 0.82),
              //       curve: Curves.easeOutBack,
              //     );
            },
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Activities ───────────────────────────────────

  Widget _buildStepActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What did you do today?',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),//.animate().fadeIn(delay: 60.ms).slideX(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 4),
              const Text(
                'Pick everything that fits your day',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _activities.isNotEmpty
                    ? Text(
                        '${_activities.length} selected',
                        key: const ValueKey('count'),
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _accentColor,
                        ),
                      )
                    : const SizedBox(height: 16, key: ValueKey('empty')),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.88,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _kActivities.length,
            itemBuilder: (_, i) {
              final a = _kActivities[i];
              final isSelected = _activities.contains(a.label);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _activities.remove(a.label);
                    } else {
                      _activities.add(a.label);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 210),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentColor.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _accentColor : const Color(0xFFE8EDF2),
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected ? [] : AppShadow.xs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        a.icon,
                        size: 24,
                        color: isSelected ? _accentColor : AppColors.textMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _accentColor : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              // ).animate(delay: Duration(milliseconds: i * 18)).fadeIn(duration: 250.ms).scale(
              //       begin: const Offset(0.82, 0.82),
              //       curve: Curves.easeOutBack,
              //     );
            },
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Body + Note ──────────────────────────────────

  Widget _buildStepBodyNote() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Almost done!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),//.animate().fadeIn(delay: 60.ms).slideX(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 4),
          const Text(
            'A couple more details to personalize your insights',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 22),

          // Sleep card
          _SleepCard(
            sleepHours: _sleepHours,
            onChanged: (v) => setState(() => _sleepHours = v),
          ),//.animate().fadeIn(delay: 140.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),

          // Note card
          _NoteCard(
            controller: _noteCtrl,
            accentColor: _accentColor,
          ),//.animate().fadeIn(delay: 200.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),

          // Summary card
          if (_moodIdx >= 0)
            _SummaryCard(
              preset: _preset!,
              emotions: _emotions,
              activities: _activities,
              sleepHours: _sleepHours,
            ),//.animate().fadeIn(delay: 260.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  // ─── Bottom Nav Bar ───────────────────────────────────────

  Widget _buildBottomBar() {
    final canNext = _step == 0 ? _moodIdx >= 0 : true;
    final isLast = _step == 3;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // Back button
          if (_step > 0) ...[
            SizedBox(
              width: 48,
              height: 52,
              child: OutlinedButton(
                onPressed: () => _goTo(_step - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Skip (steps 1 and 2 only)
          if (_step > 0 && _step < 3) ...[
            SizedBox(
              height: 52,
              child: TextButton(
                onPressed: () => _goTo(_step + 1),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Main CTA
          Expanded(
            child: SizedBox(
              height: 52,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: canNext
                      ? LinearGradient(
                          colors: [
                            _accentColor.withValues(alpha: 0.9),
                            _accentColor,
                          ],
                        )
                      : null,
                  color: canNext ? null : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canNext
                      ? [BoxShadow(color: _accentColor.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: canNext
                      ? () {
                          if (isLast) {
                            _save();
                          } else {
                            HapticFeedback.lightImpact();
                            _goTo(_step + 1);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: AppColors.textMuted,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Save Check-in' : 'Continue',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: canNext ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Icon(
                              isLast ? LucideIcons.check : LucideIcons.arrowRight,
                              size: 17,
                              color: canNext ? Colors.white : AppColors.textMuted,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sleep Card ────────────────────────────────────────────

class _SleepCard extends StatelessWidget {
  final double sleepHours;
  final ValueChanged<double> onChanged;

  const _SleepCard({required this.sleepHours, required this.onChanged});

  static const _sleepColor = Color(0xFF7C3AED);

  String get _label => sleepHours >= 9 ? '9h+' : '${sleepHours.toInt()}h';

  String get _quality {
    if (sleepHours < 5) return 'Very low — aim for more 🌙';
    if (sleepHours < 7) return 'Below recommended';
    if (sleepHours <= 9) return 'Great — well rested';
    return 'Excellent sleep!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _sleepColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(LucideIcons.moon, size: 20, color: _sleepColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep last night',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    Text(
                      _quality,
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _sleepColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _label,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _sleepColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(_kSleepOpts.length, (i) {
              final h = _kSleepOpts[i];
              final lbl = h >= 9 ? '9h+' : '${h.toInt()}h';
              final isSel = h == sleepHours;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(h);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 210),
                    margin: EdgeInsets.only(right: i < _kSleepOpts.length - 1 ? 5 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSel ? _sleepColor : const Color(0xFFF3F4F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lbl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isSel ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Note Card ─────────────────────────────────────────────

class _NoteCard extends StatefulWidget {
  final TextEditingController controller;
  final Color accentColor;

  const _NoteCard({required this.controller, required this.accentColor});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  void _setPrompt(String p) {
    if (widget.controller.text.isEmpty) {
      widget.controller.text = p;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: p.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(LucideIcons.squarePen, size: 20, color: widget.accentColor)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's on your mind?",
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Optional — takes 30 seconds',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _kPrompts.map((p) {
              return GestureDetector(
                onTap: () => _setPrompt(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.accentColor.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.accentColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: "Write anything — it's just for you...",
              hintStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.4), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ──────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final _MoodData preset;
  final List<String> emotions;
  final List<String> activities;
  final double sleepHours;

  const _SummaryCard({
    required this.preset,
    required this.emotions,
    required this.activities,
    required this.sleepHours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [preset.color.withValues(alpha: 0.08), preset.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: preset.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's summary",
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${preset.label} · Score ${preset.score}/10',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: preset.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (emotions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              icon: LucideIcons.heart,
              label: emotions.take(4).join(', '),
              color: preset.color,
            ),
          ],
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 6),
            _SummaryRow(
              icon: LucideIcons.zap,
              label: activities.take(4).join(', '),
              color: preset.color,
            ),
          ],
          const SizedBox(height: 6),
          _SummaryRow(
            icon: LucideIcons.moon,
            label: '${sleepHours >= 9 ? "9+" : sleepHours.toInt()} hours sleep',
            color: preset.color,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Already Logged View ──────────────────────────────────

class _AlreadyLoggedView extends StatelessWidget {
  final MoodEntry entry;
  const _AlreadyLoggedView({required this.entry});

  @override
  Widget build(BuildContext context) {
    final moodData = _kMoods.firstWhere(
      (m) => m.score == entry.moodScore,
      orElse: () => _kMoods[2],
    );

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final hoursLeft = diff.inHours;
    final minutesLeft = diff.inMinutes % 60;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mood Check-in',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Main Card ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Big mood emoji + pulse ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: moodData.color.withValues(alpha: 0.12),
                        ),
                      ),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: moodData.color.withValues(alpha: 0.2),
                        ),
                      ),
                      Text(moodData.emoji, style: const TextStyle(fontSize: 44)),
                    ],
                  ),
                      //.animate(onPlay: (c) => c.repeat(reverse: true))
                     // .scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04), duration: 1800.ms, curve: Curves.easeInOut),

                  const SizedBox(height: 24),

                  // "Already logged" pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.circleCheck, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text(
                          "Today's mood logged!",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'You\'re feeling ${moodData.label}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: moodData.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    moodData.sublabel,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // ── Countdown card ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.clock, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            const Text(
                              'Next check-in available in',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CountdownChip(value: hoursLeft.toString().padLeft(2, '0'), label: 'HRS'),
                            const SizedBox(width: 8),
                            const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(width: 8),
                            _CountdownChip(value: minutesLeft.toString().padLeft(2, '0'), label: 'MIN'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Come back tomorrow to log your next mood',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ── Entry summary ────────────────────────────
                  if (entry.emotions.isNotEmpty || entry.note != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: moodData.color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: moodData.color.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.emotions.isNotEmpty) ...[
                            _SummaryRow(
                              icon: LucideIcons.heart,
                              label: 'Emotions: ${entry.emotions.take(3).join(', ')}${entry.emotions.length > 3 ? '…' : ''}',
                              color: moodData.color,
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (entry.note != null && entry.note!.trim().isNotEmpty)
                            _SummaryRow(
                              icon: LucideIcons.fileText,
                              label: entry.note!.trim(),
                              color: moodData.color,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),

            const Spacer(),

            // ── Bottom Buttons ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _ActionButton(
                    label: 'View My Analytics',
                    icon: LucideIcons.chartBar,
                    color: AppColors.primary,
                    onTap: () => context.go(AppRoutes.moodAnalytics),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    label: 'Go to Home',
                    icon: LucideIcons.house,
                    color: const Color(0xFF6C63FF),
                    onTap: () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    label: 'Check Wellness',
                    icon: LucideIcons.sparkles,
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.go(AppRoutes.wellness),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  final String value;
  final String label;
  const _CountdownChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
