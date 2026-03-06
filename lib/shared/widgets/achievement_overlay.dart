import '../../core/constants/app_colors.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/models/achievement_model.dart';
import '../../core/providers/streak_provider.dart';
import '../../core/theme/design_tokens.dart';

/// Full-screen achievement unlock celebration overlay.
/// Automatically shown when a new achievement is unlocked.
class AchievementOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const AchievementOverlay({super.key, required this.child});

  @override
  ConsumerState<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends ConsumerState<AchievementOverlay> {
  late ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StreakAchievementState>(streakProvider, (prev, next) {
      if (next.justUnlocked != null && prev?.justUnlocked == null) {
        HapticFeedback.heavyImpact();
        _confettiCtrl.play();
      }
    });

    final justUnlocked = ref.watch(
      streakProvider.select((s) => s.justUnlocked),
    );

    return Stack(
      children: [
        widget.child,
        if (justUnlocked != null) ...[
          // Dim overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () =>
                  ref.read(streakProvider.notifier).dismissUnlockCelebration(),
              child: Container(color: Colors.black54),
            ).animate().fadeIn(duration: 300.ms),
          ),
          // Confetti
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiCtrl,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.07,
                  numberOfParticles: 20,
                  gravity: 0.2,
                  shouldLoop: false,
                  colors: const [
                    AppColors.primary, Color(0xFF4ECDC4), Color(0xFFFF6B9D),
                    Color(0xFFFFD166), Color(0xFF06D6A0), Color(0xFFFF8C42),
                  ],
                ),
              ),
            ),
          ),
          // Achievement card
          Positioned.fill(
            child: Center(
              child: _AchievementCard(
                achievement: justUnlocked,
                onDismiss: () => ref
                    .read(streakProvider.notifier)
                    .dismissUnlockCelebration(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final UserAchievement achievement;
  final VoidCallback onDismiss;

  const _AchievementCard({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final def = achievement.definition;
    if (def == null) return const SizedBox.shrink();

    final color = def.category.color;
    final rarityColor = def.rarity.color;

    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.xlAll,
          boxShadow: AppShadow.lg,
          border: Border.all(color: color.withOpacity(0.4), width: 2),
        ),
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: Spacing.xxs),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: rarityColor.withOpacity(0.4)),
              ),
              child: Text(
                '${def.rarity.displayName} Achievement',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rarityColor,
                  letterSpacing: 0.5,
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: Spacing.md),

            // Emoji
            Text(
              def.emoji,
              style: const TextStyle(fontSize: 72),
            )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 300.ms),

            const SizedBox(height: Spacing.sm),

            Text(
              'Achievement Unlocked!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tokenTextMuted,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: Spacing.xs),

            Text(
              def.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.tokenTextPrimary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: Spacing.xs),

            Text(
              def.description,
              style: TextStyle(
                fontSize: 14,
                color: context.tokenTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: Spacing.md),

            // XP reward
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                ),
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.zap, size: 16, color: Color(0xFFFFD166)),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    '+${def.xp} XP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFD166),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 700.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                  delay: 700.ms,
                ),

            const SizedBox(height: Spacing.lg),

            // Dismiss
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                ),
                child: const Text(
                  'Awesome! 🎉',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.7, 0.7),
            end: const Offset(1, 1),
            duration: 500.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 300.ms),
    );
  }
}
