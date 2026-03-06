import 'package:flutter/material.dart';

/// MindBridge "Clarity" Color System — Teal-first, clean and consistent.
abstract class AppColors {
  // ─── Primary Palette (Teal) ───────────────────────────
  static const Color primary = Color(0xFF00BEB4);
  static const Color primaryLight = Color(0xFF33CBC2);
  static const Color primaryDark = Color(0xFF009E95);
  static const Color primaryContainer = Color(0xFFE0F8F7);

  // ─── Secondary Palette (Coral / Alert) ────────────────
  static const Color secondary = Color(0xFFFF6B6B);
  static const Color secondaryLight = Color(0xFFFF9B9B);
  static const Color secondaryDark = Color(0xFFCC4444);
  static const Color secondaryContainer = Color(0xFFFFEEEE);

  // ─── Tertiary / Accent (Amber) ────────────────────────
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color tertiaryLight = Color(0xFFFBBF24);
  static const Color tertiaryDark = Color(0xFFD97706);
  static const Color tertiaryContainer = Color(0xFFFFF8E7);

  // ─── Semantic Colors ──────────────────────────────────
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFFF8E7);
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorContainer = Color(0xFFFFEEEE);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoContainer = Color(0xFFE0F2FE);

  // ─── Backgrounds ──────────────────────────────────────
  static const Color background = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariant = Color(0xFFF0F4F8);
  static const Color surfaceVariantDark = Color(0xFF273344);

  // ─── Text ─────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // ─── Borders & Dividers ───────────────────────────────
  static const Color border = Color(0xFFE8EDF2);
  static const Color borderDark = Color(0xFF334155);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color dividerDark = Color(0xFF1E293B);

  // ─── Mood Scale Colors (1-10) ─────────────────────────
  static const List<Color> moodColors = [
    Color(0xFFFF4757), // 1 - Terrible
    Color(0xFFFF6B6B), // 2 - Very Bad
    Color(0xFFFF8C42), // 3 - Bad
    Color(0xFFFFB347), // 4 - Poor
    Color(0xFFFFD166), // 5 - Neutral
    Color(0xFFA8E063), // 6 - Okay
    Color(0xFF56CC99), // 7 - Good
    Color(0xFF4ECDC4), // 8 - Great
    Color(0xFF00BEB4), // 9 - Excellent
    Color(0xFF10B981), // 10 - Amazing
  ];

  // ─── Gradient Definitions ─────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00BEB4), Color(0xFF33CBC2)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFF6B6B)],
  );

  static const LinearGradient calmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F7FA), Color(0xFFE0F8F7)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA)],
  );

  // ─── Emotion Category Colors ──────────────────────────
  static const Map<String, Color> emotionColors = {
    'happy': Color(0xFFF59E0B),
    'sad': Color(0xFF0EA5E9),
    'anxious': Color(0xFFFF8C42),
    'angry': Color(0xFFFF6B6B),
    'calm': Color(0xFF00BEB4),
    'excited': Color(0xFFF59E0B),
    'tired': Color(0xFF9CA3AF),
    'grateful': Color(0xFF10B981),
    'lonely': Color(0xFF0EA5E9),
    'hopeful': Color(0xFF56CC99),
    'overwhelmed': Color(0xFFFF8C42),
    'proud': Color(0xFF00BEB4),
  };

  // ─── Shadow Colors ────────────────────────────────────
  static const Color shadowSm = Color(0x0F000000);   // 6% black
  static const Color shadowMd = Color(0x1A000000);   // 10% black
  static const Color shadowLg = Color(0x26000000);   // 15% black
  // Legacy alias kept for backward compat
  static Color shadowPrimary = primary.withValues(alpha: 0.15);
  static Color shadowCard = const Color(0xFF000000).withValues(alpha: 0.06);
  static Color shadowDark = const Color(0xFF000000).withValues(alpha: 0.15);
}
