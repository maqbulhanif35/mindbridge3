import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/models/streak_model.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants/app_colors.dart';

/// Displays a user's streak with flame icon and count.
/// Animates with a pulse when streak is active.
class StreakBadge extends StatelessWidget {
  final StreakModel streak;
  final bool compact;
  final VoidCallback? onTap;

  const StreakBadge({
    super.key,
    required this.streak,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    final isActive = streak.isActive;
    final isOnFire = streak.isOnFire;
    final color = isActive ? const Color(0xFFFF6B35) : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    const Color(0xFFFF6B35).withOpacity(0.15),
                    const Color(0xFFFFD166).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : context.tokenSurfaceVariant,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isActive
                ? const Color(0xFFFF6B35).withOpacity(0.3)
                : context.tokenBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlameIcon(size: 28, active: isActive, animate: isOnFire),
            const SizedBox(width: Spacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${streak.currentStreak} days',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isActive ? color : AppColors.textMuted,
                  ),
                ),
                Text(
                  streak.type.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            if (streak.currentStreak > 0) ...[
              const SizedBox(width: Spacing.sm),
              _buildMilestoneProgress(context),
            ],
          ],
        ),
      ).animate(
        onPlay: (controller) => isOnFire
            ? controller.repeat(reverse: true)
            : controller.forward(),
      ).scale(
        begin: const Offset(1, 1),
        end: const Offset(1.02, 1.02),
        duration: 1200.ms,
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final isActive = streak.isActive;
    final color = isActive ? const Color(0xFFFF6B35) : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FlameIcon(size: 18, active: isActive, animate: streak.isOnFire),
          const SizedBox(width: 4),
          Text(
            streak.currentStreak.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneProgress(BuildContext context) {
    final progress = streak.milestoneProgress;
    final next = streak.nextMilestone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Next: $next',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 48,
          child: ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlameIcon extends StatefulWidget {
  final double size;
  final bool active;
  final bool animate;

  const _FlameIcon({
    required this.size,
    required this.active,
    required this.animate,
  });

  @override
  State<_FlameIcon> createState() => _FlameIconState();
}

class _FlameIconState extends State<_FlameIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate && widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Icon(
        Icons.local_fire_department,
        size: widget.size,
        color: AppColors.textMuted,
      );
    }

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: widget.animate ? _scaleAnim.value : 1.0,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD166), Color(0xFFFF6B35), Color(0xFFFF4757)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Icon(
            Icons.local_fire_department,
            size: widget.size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Achievement Badge ────────────────────────────────────

/// Displays a single achievement badge tile.
class AchievementBadgeTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String? description;
  final Color color;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const AchievementBadgeTile({
    super.key,
    required this.emoji,
    required this.title,
    this.description,
    required this.color,
    this.isUnlocked = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isUnlocked ? 1.0 : 0.4,
        duration: AppDuration.normal,
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            gradient: isUnlocked
                ? LinearGradient(
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUnlocked ? null : context.tokenSurfaceVariant,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: isUnlocked ? color.withOpacity(0.3) : context.tokenBorder,
            ),
            boxShadow: isUnlocked ? AppShadow.coloredSm(color) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUnlocked ? emoji : '🔒',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUnlocked ? context.tokenTextPrimary : context.tokenTextMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description != null && isUnlocked) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.tokenTextMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Trend Arrow ──────────────────────────────────────────

/// Shows a colored up/down/stable trend indicator.
class TrendArrow extends StatelessWidget {
  final double delta;
  final bool showValue;
  final double size;

  const TrendArrow({
    super.key,
    required this.delta,
    this.showValue = true,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0.5;
    final isDown = delta < -0.5;
    final color = isUp
        ? AppColors.success
        : isDown
            ? AppColors.error
            : AppColors.textMuted;
    final icon = isUp
        ? Icons.trending_up_rounded
        : isDown
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: size + 4),
        if (showValue) ...[
          const SizedBox(width: 2),
          Text(
            delta.abs() < 0.5
                ? 'Stable'
                : '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}
