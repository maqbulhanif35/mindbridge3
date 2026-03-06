import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_tokens.dart';

/// Shimmer skeleton base — wrap any shape to get a loading shimmer effect.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A44) : const Color(0xFFE8E8F4),
      highlightColor:
          isDark ? const Color(0xFF3A3A5A) : const Color(0xFFF8F8FF),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A44) : const Color(0xFFE8E8F4),
          borderRadius: borderRadius ?? AppRadius.smAll,
        ),
      ),
    );
  }
}

// ─── Screen-specific Skeletons ────────────────────────────

/// Skeleton for the home screen dashboard.
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: Spacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          const SkeletonBox(width: 200, height: 28),
          const SizedBox(height: Spacing.xs),
          const SkeletonBox(width: 140, height: 16),
          const SizedBox(height: Spacing.xl),

          // Wellness score card
          _SkeletonCard(
            height: 140,
            child: Row(
              children: [
                const SkeletonBox(
                  width: 100,
                  height: 100,
                  borderRadius: BorderRadius.all(Radius.circular(50)),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SkeletonBox(width: 120, height: 18),
                      const SizedBox(height: Spacing.sm),
                      const SkeletonBox(width: 80, height: 14),
                      const SizedBox(height: Spacing.sm),
                      const SkeletonBox(width: 160, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Quick actions row
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? Spacing.sm : 0),
                  child: const _SkeletonCard(height: 80),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Mood check-in card
          const _SkeletonCard(height: 100),
          const SizedBox(height: Spacing.md),

          // Challenges
          const SkeletonBox(width: 140, height: 18),
          const SizedBox(height: Spacing.sm),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: Spacing.sm),
              child: _SkeletonCard(height: 64),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for mood tracker screen.
class MoodTrackerSkeleton extends StatelessWidget {
  const MoodTrackerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.pagePadding,
      child: Column(
        children: [
          // Mood slider area
          const _SkeletonCard(height: 160),
          const SizedBox(height: Spacing.md),

          // Emotion tags
          const SkeletonBox(width: 100, height: 16),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: List.generate(
              8,
              (_) => SkeletonBox(
                width: 70 + (20 * (_.isEven ? 1 : 0)),
                height: 36,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Notes area
          const _SkeletonCard(height: 100),
        ],
      ),
    );
  }
}

/// Skeleton for chat screen messages.
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.pagePadding,
      child: Column(
        children: [
          _buildMessage(fromUser: false),
          const SizedBox(height: Spacing.md),
          _buildMessage(fromUser: true),
          const SizedBox(height: Spacing.md),
          _buildMessage(fromUser: false, twoLines: true),
          const SizedBox(height: Spacing.md),
          _buildMessage(fromUser: true),
        ],
      ),
    );
  }

  Widget _buildMessage({required bool fromUser, bool twoLines = false}) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          crossAxisAlignment:
              fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SkeletonBox(
              width: 220,
              height: 16,
              borderRadius: AppRadius.mdAll,
            ),
            if (twoLines) ...[
              const SizedBox(height: 6),
              SkeletonBox(
                width: 180,
                height: 16,
                borderRadius: AppRadius.mdAll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for journal list.
class JournalListSkeleton extends StatelessWidget {
  final int count;

  const JournalListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.pagePadding,
      child: Column(
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: _SkeletonCard(
              height: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SkeletonBox(width: 160, height: 18),
                      const SkeletonBox(width: 60, height: 14),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  const SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 200, height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for analytics screen.
class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.pagePadding,
      child: Column(
        children: [
          // Chart area
          const _SkeletonCard(height: 220),
          const SizedBox(height: Spacing.md),

          // Stats row
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? Spacing.sm : 0),
                  child: const _SkeletonCard(height: 80),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Insight cards
          ...List.generate(
            2,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: Spacing.md),
              child: _SkeletonCard(height: 90),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Internal Helper ──────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  final double height;
  final Widget? child;

  const _SkeletonCard({required this.height, this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A44) : const Color(0xFFE8E8F4),
      highlightColor:
          isDark ? const Color(0xFF3A3A5A) : const Color(0xFFF8F8FF),
      child: Container(
        width: double.infinity,
        height: height,
        padding: Spacing.cardPadding,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A44) : const Color(0xFFE8E8F4),
          borderRadius: AppRadius.lgAll,
        ),
        child: child,
      ),
    );
  }
}
