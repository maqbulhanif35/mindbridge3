// ─── In-App Banner Provider ───────────────────────────────
// Manages a queue of transient notification banners shown
// at the top of the screen inside the shell.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

enum BannerType { peerRequest, newPost, moodReminder, achievement, streakAlert }

class AppBanner {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final BannerType type;
  final VoidCallback? onTap;

  const AppBanner({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.type,
    this.onTap,
  });

  static AppBanner moodReminder() => AppBanner(
        id: 'mood_reminder_${DateTime.now().day}',
        title: 'How are you feeling?',
        message: 'You haven\'t logged your mood today. Take 10 seconds ✨',
        icon: LucideIcons.smile,
        color: const Color(0xFF00BEB4),
        type: BannerType.moodReminder,
      );

  static AppBanner peerRequest(String peerName) => AppBanner(
        id: 'peer_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Peer connected!',
        message: '$peerName joined your support chat 💙',
        icon: LucideIcons.users,
        color: const Color(0xFF6366F1),
        type: BannerType.peerRequest,
      );

  static AppBanner achievement(String badge, int xp) => AppBanner(
        id: 'ach_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Badge unlocked! 🏅',
        message: '$badge  •  +$xp XP',
        icon: LucideIcons.trophy,
        color: const Color(0xFFF59E0B),
        type: BannerType.achievement,
      );

  static AppBanner streakAtRisk(int streakDays) => AppBanner(
        id: 'streak_risk_${DateTime.now().day}',
        title: 'Streak at risk! 🔥',
        message: '$streakDays-day streak — log mood before midnight to keep it!',
        icon: LucideIcons.flame,
        color: const Color(0xFFEF4444),
        type: BannerType.streakAlert,
      );

  static AppBanner newPosts(int count) => AppBanner(
        id: 'posts_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Community is active',
        message: '$count new post${count > 1 ? "s" : ""} in your feed 👥',
        icon: LucideIcons.messageSquare,
        color: const Color(0xFF0EA5E9),
        type: BannerType.newPost,
      );
}

class BannerNotifier extends StateNotifier<List<AppBanner>> {
  BannerNotifier() : super([]);

  final Set<String> _shown = {};

  void show(AppBanner banner) {
    if (_shown.contains(banner.id)) return; // deduplicate
    _shown.add(banner.id);
    state = [banner, ...state]; // newest on top
    Future.delayed(const Duration(seconds: 5), () => dismiss(banner.id));
  }

  void dismiss(String id) {
    state = state.where((b) => b.id != id).toList();
  }

  void dismissAll() => state = [];
}

final bannerProvider =
    StateNotifierProvider<BannerNotifier, List<AppBanner>>(
  (ref) => BannerNotifier(),
);
